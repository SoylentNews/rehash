#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

# For now this just gathers data.  The actual reweighting will come
# later. - Jamie 2004/11/10

use strict;

use Time::HiRes;

use Slash;
use Slash::Constants ':slashd';
use Slash::Display;
use Slash::Utility;

use vars qw(
	%task	$me	$task_exit_flag
);

$task{$me}{timespec} = '* * * * *';
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;

	my $start_time = time;
	my $readers = get_readers();

	# This task isn't necessary unless there are two or more readers.
	my $n_readers = scalar(keys %$readers);
	if ($n_readers < 2) {
		# Don't quit, since the task will just restart.  Sleep
		# until the parent slashd quits.
		slashdLog("Only $n_readers reader(s), so this task would not be useful -- sleeping permanently");
		sleep 5 while !$task_exit_flag;
		return ;
	}

	my $delay = $constants->{dbs_reader_adjust_delay} || 5;
	my $next_delete_time = time + 60;
	my $next_adjust_time = time;
	while (!$task_exit_flag) {
		my $reader_info = check_readers($slashdb, $readers);
		log_reader_info($slashdb, $reader_info);
		adjust_readers($slashdb, $reader_info);
		$next_delete_time = delete_old_logs($slashdb, $next_delete_time);
		$next_adjust_time = get_next_adjust_time($next_adjust_time, $delay);
		sleep_until($next_adjust_time);
	}

	return sprintf("exiting after %d seconds", time - $start_time);
};

sub sleep_until {
	my($next_adjust_time) = @_;
	while (!$task_exit_flag && Time::HiRes::time < $next_adjust_time) {
		# Sleep until just before the next adjustment time arrives.
		my $sleep_time = $next_adjust_time - Time::HiRes::time;
		$sleep_time -= 0.05;
		$sleep_time = 0.01 if $sleep_time < 0.01;
		Time::HiRes::sleep($sleep_time);
	}
}

{ # cheap closure cache
my $reader_dbid;
sub get_reader_dbid {
	my($slashdb, $vu) = @_;
	if (!$reader_dbid) {
		$reader_dbid = $slashdb->sqlSelectAllKeyValue(
			"virtual_user, id",
			"dbs",
			"type='reader'");
	}
	return $reader_dbid->{$vu};
}
} # end closure

sub get_readers {
	my $slashdb = getCurrentDB();
	my $readers = { };
	my $vus = $slashdb->sqlSelectColArrayref(
		"virtual_user", "dbs", "type='reader'");
	for my $vu (@$vus) {
		$readers->{$vu} = getObject("Slash::DB", $vu);
	}
	return $readers;
}

sub check_readers {
	my($slashdb, $readers) = @_;

	my $reader_info = { };

	# Weed out readers that are isalive='no'
	my $vu_alive_hr = $slashdb->sqlSelectAllKeyValue(
		"virtual_user, IF(isalive='yes',1,0)", "dbs", "type='reader'");
	my @alive_vus = grep { $vu_alive_hr->{$_} } sort keys %$readers;

	# Note dead readers so they can be marked as dead when we return.
	my @dead_vus = grep { !$vu_alive_hr->{$_} } sort keys %$readers;
	for my $vu (@dead_vus) {
		$reader_info->{$vu}{dead} = 1;
	}

	# Get data from alive readers and consolidate it.
	my %process = ( );
	my %slave_sql_id = ( );
	for my $vu (@alive_vus) {

		# Connect to this reader (this will also attempt to ping it
		# and make sure it's reachable).  If we can't, mark it as
		# unreachable.
		my $db = $readers->{$vu};
		my $connected = $db->sqlConnect();
		if (!$connected) {
			$reader_info->{$vu}{unreachable} = 1;
			next;
		}

		# Get the processlist for this virtual user.
		my $sth = $db->{_dbh}->prepare("SHOW FULL PROCESSLIST");
		$sth->execute();
#		my $n_sleeping = 0;
		while (my $hr = $sth->fetchrow_hashref()) {
			if ($hr->{Command} && $hr->{Command} eq 'Sleep') {
#				# Count the number of sleeping processes.
#				++$n_sleeping;
				# Skip sleeping processes.
				next;
			}
#use Data::Dumper;
#my $hr_d = Dumper($hr);
#$hr_d =~ s/\s+/ /g;
#slashdLog("vu '$vu' process id $hr->{Id}: $hr_d");

			# I believe this is a bug in MySQL starting
			# somewhere around or before 4.0.12, and fixed
			# by 4.0.21 -- the Time field on some processes
			# can be the unsigned version of a small
			# negative number.  Call it zero.
			$hr->{Time} = 0 if $hr->{Time} > 4_200_000_000;

			# Store the record of what this process is doing.
			$process{$vu}{$hr->{Id}} = \%{ $hr };

			# Find the system user that does the slave SQL.
			# There may be a well-defined way to tell the two
			# slave processes apart but I don't know it,
			# so I'm figuring this out as I go.
			if ($hr->{User} eq 'system user') {
				if (
					   $hr->{State} =~ /Reading master update/
					|| $hr->{State} =~ /Waiting for master to send event/
					|| $hr->{State} =~ /Queueing master event to the relay log/
					|| $hr->{State} =~ /Queueing event from master/
				) {
					# This is the I/O process, skip it.
					next;
				} elsif (
					   $hr->{State} =~ /waiting for binlog update/
					|| $hr->{State} =~ /Processing master log event/
					|| $hr->{State} =~ /Has read all relay log/
					|| $hr->{State} =~ /Reading event from the relay log/
					|| $hr->{State} =~ /Updating/
					|| $hr->{State} =~ /freeing items/
					|| $hr->{State} eq 'update'
					|| $hr->{State} eq 'end'
				) {
					# This is the SQL process, it's the
					# one we want.
					$slave_sql_id{$vu} = $hr->{Id};
					next;
				} else {
					# Don't know what this one is, log an error.
					my $state = substr($hr->{State}, 0, 200);
					slashdLog("Process id $hr->{Id} on vu '$vu' has unknown system user state '$state'");
				}
			}

			# Consolidate similar or identical queries into an
			# array of how long each has been running.
			next unless $hr->{Info};
			my $query = query_consolidate($hr->{Info});
			$process{$vu}{query}{$query} ||= [ ];
			push @{ $process{$vu}{query}{$query} }, $hr->{Time};
		}
#		$process{$vu}{n_sleeping} = $n_sleeping;
		$sth->finish();
	}

	for my $vu (@alive_vus) {

		$reader_info->{$vu}{slave_lag_secs}	= undef;
		$reader_info->{$vu}{bog_query}		= undef;
		$reader_info->{$vu}{query_bog_secs}	= undef;

		# If this DB couldn't be reached, skip the rest.
		next if $reader_info->{$vu}{unreachable};

		# Determine the two big numbers we care about:  how far
		# behind its slave sql thread is, and what's its worst
		# repeated bogged-down query.

		# First check to be sure it has a slave sql thread running.
		my $slave_sql_id = $slave_sql_id{$vu};
		if (!$slave_sql_id) {
			# If not, its slave is stopped and we can't calculate
			# its lag.
			$reader_info->{$vu}{stopped} = 1;
		} else {
			# If so, pull the lag of that process in seconds.
			my $slave_sql_lag = $process{$vu}{$slave_sql_id}{Time};
			$reader_info->{$vu}{slave_lag_secs} = $slave_sql_lag;
		}

		# Now find the query that's the most bogged-down, and how
		# bogged it is.  The "most bogged-down" is the query that,
		# of its processes running it that have been running for
		# 3 seconds or more, has the largest sum of times.
		my $bog_query = undef;
		my @queries = sort keys %{ $process{$vu}{query} };
		my $max_bog_time = 0;
		my $max_bog_sum = 0;
		for my $query (@queries) {
			my @bog_times =
				sort { $a <=> $b }
				grep { $_ >= 3 }
				@{ $process{$vu}{query}{$query} };
			# There must be at least 3 similar queries for us
			# to care about it.
			next unless @bog_times;
			# OK, sum them up and see if we beat the record.
			my $bog_sum = 0;
			for my $t (@bog_times) { $bog_sum += $t }
			if ($max_bog_sum < $bog_sum) {
				$bog_query = $query;
				$max_bog_sum = $bog_sum;
				$max_bog_time = $bog_times[-1];
			}
		}
		$reader_info->{$vu}{bog_query} = $bog_query;
		$reader_info->{$vu}{query_bog_secs} = $max_bog_time;
	}

	return $reader_info;
}

# Canonicalize and consolidate a query.  We're trying to map all queries
# such that similar requests will be assigned the same string.  To do
# this we strip whitespace to a single space, convert all numbers of
# two digits or more to "_N_" (like mysqldumpslow does), and then
# truncate the string to 40 chars.  The 40 really should be a var but
# it's hardcoded for now because I'm not sure yet to what extent I want
# to fiddle around with this.  It might make sense to also convert all
# lists of numbers (like 1,2,3 or '1','2','3') to a token like _NL_,
# but probably truncating to 40 chars will make that unnecessary.

sub query_consolidate {
	my($query) = @_;
	$query =~ s/\s+/ /g;
	$query = substr($query, 0, 100);
	$query =~ s/\b(\d{2,})\b/_N_/g;
	$query = substr($query, 0, 40);
	return $query;
}

{
# closure for a cheap cache
my %bog_query_id = ( );
sub log_reader_info {
	my($slashdb, $reader_info) = @_;
	for my $vu (sort keys %$reader_info) {
		my $info = $reader_info->{$vu};

		# Whether the reader was alive or dead is boolean.  The
		# other two values are tri-state (if one of the earlier
		# value(s) was false, the later value was not even
		# checked, so we don't know the answer and fill in NULL).
		my $was_alive		= !$info->{dead};
		my $was_reachable	= undef;
		$was_reachable		= !$info->{unreachable}	if $was_alive;
		my $was_running		= undef;
		$was_running		= !$info->{stopped}	if $was_alive && $was_reachable;

		# Determine the bog_query's id from the
		# dbs_readerstatus_queries table.
		my $bog_rsqid = undef;
		if (defined $info->{bog_query}) {
			my $query = $info->{bog_query};
			$bog_query_id{$query} ||= $slashdb->getDBReaderStatusQueryId($query);
			$bog_rsqid = $bog_query_id{$query};
		}

		my $log_hr = {
			-ts		=> 'NOW()',
			dbid		=> get_reader_dbid($slashdb, $vu),
			was_alive	=> $was_alive			? 'yes' : 'no',
			was_reachable	=> defined($was_reachable)
						? ($was_reachable	? 'yes' : 'no')
						: undef,
			was_running	=> defined($was_running)
						? ($was_running	? 'yes' : 'no')
						: undef,
			slave_lag_secs	=> $info->{slave_lag_secs},
			query_bog_secs	=> $info->{query_bog_secs},
			bog_rsqid	=> $bog_rsqid,
		};
		$slashdb->createDBReaderStatus($log_hr);
	}
}
}

sub adjust_readers {
	my($slashdb, $reader_info) = @_;
	# Not coded yet.
}

sub delete_old_logs {
	my($slashdb, $next_delete_time) = @_;
	return $next_delete_time if time < $next_delete_time;
	my $constants = getCurrentStatic();
	my $secs_back = $constants->{dbs_reader_expire_secs} || 86400*7;
	$slashdb->deleteOldDBReaderStatus($secs_back);
	# How long before we do this again?  Depends on how much log
	# we're keeping around.  Anywhere from 5 minutes to 8 hours.
	my $pause = $secs_back / 60;
	$pause = 300 if $pause < 300;
	$pause = 14400 if $pause > 28800;
	return time + $pause;
}

sub get_next_adjust_time {
	my($next_adjust_time, $delay) = @_;
	# If we missed more than one cycle, don't try to catch up.
	if ($next_adjust_time + $delay*2 < time) {
		$next_adjust_time = time + $delay;
	} else {
		$next_adjust_time += $delay;
	}
	return $next_adjust_time;
}

1;


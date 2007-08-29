#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
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

# This should be in Static/MySQL.pm
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

# This should be in Static/MySQL.pm
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
	# This should be in Static/MySQL.pm
	my $vu_hr = $slashdb->sqlSelectAllHashref(
		"virtual_user",
		"virtual_user, IF(isalive='yes',1,0) AS isalive, weight, weight_adjust",
		"dbs", "type='reader'");
	my $vu_alive_hr = {( map {( $_, $vu_hr->{$_}{isalive} )} keys %$vu_hr )};
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

		# Copy across the data from the dbs table.
		$reader_info->{$vu}{had_weight}		= $vu_hr->{$vu}{weight};
		$reader_info->{$vu}{had_weight_adjust}	= $vu_hr->{$vu}{weight_adjust};

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
		# This requires Process_priv for the mysql user, which
		# may not have been granted at install time (it wasn't
		# in the docs until August 2007).  If you are seeing
		# isalive='no' in your dbs table, was_running='no' in
		# your dbs_reader status table, and "STOPPED!" even
		# when you know your slave is running, you need a
		# GRANT PROCESS ON yourdb.* TO 'user'@'machine'
		# IDENTIFIED BY '(passwd)'.
		# XXX This code needs to be updated anyway to use the
		# simpler "Seconds_Behind_Master" from "SHOW SLAVE STATUS"
		# where available.  I'm not sure what version that field
		# was added (between 4.0.12 and 5.0.26 is all I know) but
		# at some point the simpler algorithm should be added and
		# this kludgy algorithm either removed or used as a backup
		# for older versions.
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
			$hr->{Time} = 0 if !$hr->{Time} || $hr->{Time} > 4_200_000_000;

			# Store the record of what this process is doing.
			$process{$vu}{$hr->{Id}} = \%{ $hr };

			# Find the system user that does the slave SQL.
			if ($hr->{User} eq 'system user') {
				my $type = get_sql_type_from_state($hr->{State});
				if ($type eq 'io') {
					# This is the I/O process, skip it.
					next;
				} elsif ($type eq 'sql') {
					# This is the SQL process, it's the
					# one we want.
					$slave_sql_id{$vu} = $hr->{Id};
					next;
				} else {
					# Don't know what this one is, log an error.
					my $state = substr($hr->{State}, 0, 200);
					slashdLog("Process id $hr->{Id} on vu '$vu'"
						. " has unknown system user state"
						. " '$state'");
				}
			} else {
				# It's not one of the SQL processes.  Consolidate
				# similar or identical queries into an array of
				# how long each has been running.
				next unless $hr->{Info};
				my $query = query_consolidate($hr->{Info});
				$process{$vu}{query}{$query} ||= [ ];
				push @{ $process{$vu}{query}{$query} }, $hr->{Time};
			}
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
		# 1 second or more, has the largest sum of times.
		my $bog_query = undef;
		my @queries = sort keys %{ $process{$vu}{query} };
		my $max_bog_time = 0;
		my $max_bog_sum = 0;
		for my $query (@queries) {
			my @bog_times =
				sort { $a <=> $b }
				grep { $_ >= 1 }
				@{ $process{$vu}{query}{$query} };
			# There must be at least 3 similar queries for us
			# to care about it.  Otherwise we assume it's a
			# backend task, or perhaps a rare (admin?) function
			# that doesn't come up much.
			next unless @bog_times >= 3;
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

# There may be a well-defined way to tell the two slave processes apart
# but I don't know it, so I'm figuring this out as I go.

sub get_sql_type_from_state {
	my($state) = @_;
	if (
		   $state =~ /Queueing event from master/
		|| $state =~ /Queueing master event to the relay log/
		|| $state =~ /Reading master update/
		|| $state =~ /Waiting for master to send event/
	) {
		return 'io';
	} elsif (
		   $state =~ /freeing items/
		|| $state =~ /Has read all relay log/
		|| $state =~ /Opening table/
		|| $state =~ /Processing master log event/
		|| $state =~ /Reading event from the relay log/
		|| $state =~ /Searching rows for update/
		|| $state =~ /Sending data/
		|| $state =~ /System lock/
		|| $state =~ /^copy to/
		|| $state =~ /^updat(e|ing)/i
		|| $state =~ /waiting for binlog update/
		|| $state eq 'init'
		|| $state eq 'creating table'
		|| $state eq 'Locked'
		|| $state eq 'preparing'
		|| $state eq 'removing tmp table'
		|| $state eq 'rename result table'
		|| $state eq 'query end'
		|| $state eq 'end'
	) {
		return 'sql';
	}
	return 'unknown';
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
			had_weight	=> $info->{had_weight},
			had_weight_adjust => $info->{had_weight_adjust},
		};
		$slashdb->createDBReaderStatus($log_hr);
	}
}
}

sub adjust_readers {
	my($slashdb, $reader_info) = @_;

	my $constants = getCurrentStatic();
	my $reduce_max   = $constants->{dbs_reader_weight_reduce_max};
	my $increase_max = $constants->{dbs_reader_weight_increase_max};
	my $weight_adjust = { };

	VU: for my $vu (sort keys %$reader_info) {

		# If this DB is marked as isalive='no', it's not our
		# responsibility, skip it.
		next VU if $reader_info->{dead};

		# If this DB was not reachable, set its weight to 0
		# immediately.
		if ($reader_info->{unreachable}) {
			set_reader_weight_adjust($slashdb, $vu, 0);
			next VU;
		}

		# Get how lagged this slave DB's slave process is.
		# If we did indeed reach the reader DB and found that
		# its slave process was not running, that counts as a
		# very high lag (which it will be, shortly, unless
		# the slave process gets restarted!).
		my $lag = $reader_info->{$vu}{slave_lag_secs};
		$lag = 9999 if $reader_info->{$vu}{stopped};

		# Get the weight_adjust fraction for lag.
		my $wa_lag = get_adjust_fraction($lag,
			$constants->{dbs_reader_lag_secs_start},
			$constants->{dbs_reader_lag_secs_end},
			$constants->{dbs_reader_lag_weight_min});

		# Get how bogged the DB is.
		my $bog = $reader_info->{$vu}{query_bog_secs};

		# Get the weight_adjust fraction for bog.
		my $wa_bog = get_adjust_fraction($bog,
			$constants->{dbs_reader_bog_secs_start},
			$constants->{dbs_reader_bog_secs_end},
			$constants->{dbs_reader_bog_weight_min});

		# Decide what the total fraction we're going to use is.
		# (For now, let's just do the min of those two.  We may
		# want to combine them in a synergistic way later or
		# something.)
		my $wa_total = $wa_lag;
		$wa_total = $wa_bog if $wa_bog < $wa_total;
		set_reader_weight_adjust($slashdb, $vu, $wa_total);
	}
}

sub get_adjust_fraction {
	my($secs, $secs_start, $secs_end, $weight_min) = @_;
	if ($secs < $secs_start) {
		# This one's as good as it gets :)
		return 1;
	}
	if ($secs >= $secs_end) {
		# This one's as bad as it gets :(
		return $weight_min;
	}
	# This one's somewhere in the middle.  Scale
	# linearly to find out where.
	return 1 - ($secs-$secs_start)*(1-$weight_min)/($secs_end-$secs_start);
}

# Set the weight for this virtual user to the new value given --
# but, do not increase it or reduce it more than the amount given,
# nor make it larger than 1 or smaller than 0.  We do this with
# some clever SQL.
sub set_reader_weight_adjust {
	my($slashdb, $vu, $new_wa) = @_;

	my $dbid = get_reader_dbid($slashdb, $vu);
	my $constants = getCurrentStatic();
	my $delay = $constants->{dbs_reader_adjust_delay} || 5;
	my $reduce_max = $constants->{dbs_reader_weight_reduce_max}*$delay/60;
	my $increase_max = $constants->{dbs_reader_weight_increase_max}*$delay/60;

	# This should be in Static/MySQL.pm
	$slashdb->sqlUpdate("dbs",
		{ -weight_adjust	=> "GREATEST(0, weight_adjust-$reduce_max,
						LEAST(1, weight_adjust+$increase_max,
							$new_wa))" },
		"id=$dbid");
}

sub delete_old_logs {
	my($slashdb, $next_delete_time) = @_;
	return $next_delete_time if time < $next_delete_time;
	my $constants = getCurrentStatic();
	my $secs_back = $constants->{dbs_reader_expire_secs} || 86400*7;
	$slashdb->deleteOldDBReaderStatus($secs_back);
	# How long before we do this again?  Depends on how much log
	# we're keeping around.  Anywhere from 5 minutes to 4 hours.
	my $pause = $secs_back / 60;
	$pause = 300 if $pause < 300;
	$pause = 14400 if $pause > 14400;
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


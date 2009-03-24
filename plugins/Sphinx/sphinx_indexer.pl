#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2009 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

use strict;

use Time::HiRes;

use Slash;
use Slash::Constants ':slashd';

use vars qw(
	%task	$me	$task_exit_flag
	$sphinxdb	$children_running
);

$task{$me}{timespec} = '* * * * *';
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;

	my $num_runs = 0;
	$children_running = 0;

	# We expect this dbh to connect directly to the Sphinx database,
	# which we will be writing to although it is a reader slave.
	# This is because the indexer task also writes to it:  see the
	# sql_query_pre and sql_query_post_index queries.
	$sphinxdb = getObject('Slash::Sphinx', { db_type => 'sphinx' });

	if (!$sphinxdb) {
		main::slashdLog('sphinx apparently not installed -- sleeping permanently');
		sleep 5 while !$task_exit_flag;
	}

	my $src_info = load_index_info();

	while (!$task_exit_flag) {
		my($next_index, $run_at, $asynch) = get_next_index();
		sleep_until($run_at);
		run_index($next_index, $asynch);
		++$num_runs;
		sleep 1;
	}

	wait_for_all_children();

	return "ran indexer $num_runs times";
};

sub load_index_info {
	my $src_info = { prev => { }, freq => { } };
	$src_info->{prev} = $sphinxdb->sqlSelectAllKeyValue(
		'name, UNIX_TIMESTAMP(laststart)', 'sphinx_index');
	$src_info->{freq} = $sphinxdb->sqlSelectAllKeyValue(
		'name, frequency', 'sphinx_index');
	$src_info->{asynch} = $sphinxdb->sqlSelectAllKeyValue(
		'name, asynch', 'sphinx_index');
	$src_info;
}

sub set_laststart_now {
	my($name) = @_;
	$sphinxdb->sqlUpdate('sphinx_index',
		{ -laststart => "NOW()" },
		"name='$name'");
}

sub get_next_index {
	my($src_info) = @_;
	my $name = undef;
	my $run_at = 2**32-1;
	for my $n (keys %{$src_info->{prev}}) {
		my $t = $src_info->{prev}{$n} + $src_info->{freq}{$n};
		next if $run_at < $t;
		$run_at = $t;
		$name = $n;
	}
	return($name, $run_at, $src_info->{asynch}{$name});
}

sub sleep_until {
	my($wake_time) = @_;
	SI_REAPER();
	my $sleep_dur = $wake_time - Time::HiRes::time;
	return if $sleep_dur <= 0;
	Time::HiRes::sleep($sleep_dur);
}

sub run_next_index {
	my($name, $asynch) = @_;
	set_laststart_now($name);
	if (!$asynch) {
		do_system();
	} else {
		local $SIG{CHLD} = sub { };
		SI_FORK: {
			my $pid = fork();
			if ($pid) {
				# Parent.
				++$children_running;
			} elsif (defined $pid) {
				# Child.
				do_system();
			} else {
				# Error.
				Time::HiRes::sleep(0.1);
				redo SI_FORK;
			}
		}
		Time::HiRes::sleep(0.1);
	}
}

sub do_system {
	my($name) = @_;
	system(join(' ',
		"/usr/local/sphinx/bin/indexer",
		"--config /usr/local/slash/site/banjo.slashdot.org/misc/sphinx01.conf",
		"--rotate",
		"--quiet",
		"idx_firehose_$name",
		"> /dev/null"));
}

sub wait_for_all_children {
	while ($children_running) {
		SI_REAPER();
		Time::HiRes::sleep(0.5);
	}
}

sub SI_REAPER {
	return if !$children_running;
	while (my $pid = waitpid(-1, WNOHANG)) {
		last if $pid < 1;
		main::slashdLog("REAPER in parent $$ found reaped pid $pid"); # XXX
		--$children_running;
	}
}

1;


#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2009 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

use strict;

use POSIX ':sys_wait_h';
use Time::HiRes;

use Slash;
use Slash::Constants ':slashd';

use vars qw(
	%task	$me	$task_exit_flag
	$conffile
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

	my $writedir = catdir($constants->{datadir}, 'misc');
	$conffile = catfile($writedir, 'sphinx01.conf');

	my $src_info = load_index_info();

	while (!$task_exit_flag) {
		my($next_index, $run_at, $asynch) = get_next_index($src_info);
		sleep_until($run_at);
		run_next_index($src_info, $next_index, $asynch);
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
	$src_info->{order} = $sphinxdb->sqlSelectAllKeyValue(
		'name, src', 'sphinx_index');
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
	my $cur_time = time;
	for my $n (sort keys %{$src_info->{prev}}) {
		my $t = $src_info->{prev}{$n} + $src_info->{freq}{$n};
#print STDERR "gni checking $n next_time=$t run_at=$run_at time=" . time . " freq=$src_info->{freq}{$n}\n";
		if ($t <= $cur_time) {
			# This one needs to run ASAP.  It's probably next.
			# But if the current-next item also needs to run ASAP,
			# this one is only next if its order comes first.
			if ($run_at == $cur_time) {
				if ($src_info->{order}{$n} < $src_info->{order}{$name}) {
					$run_at = $cur_time;
					$name = $n;
#print STDERR "gni found A $n $t\n";
				}
			} else {
				$run_at = $cur_time;
				$name = $n;
#print STDERR "gni found B $n $t\n";
			}
		} elsif ($t < $run_at) {
			# This one needs to run sooner than the best-known
			# other alternative.
			$run_at = $t;
			$name = $n;
#print STDERR "gni found C $n $t\n";
		}
        }
#print STDERR "gni returning $name $run_at $src_info->{asynch}{$name}\n";
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
	my($src_info, $name, $asynch) = @_;
	set_laststart_now($name);
	if (!$asynch) {
		do_system($name);
	} else {
		local $SIG{CHLD} = sub { };
		SI_FORK: {
			my $pid = fork();
			if ($pid) {
				# Parent.
				++$children_running;
			} elsif (defined $pid) {
				# Child.
				do_system($name);
				exit 0;
			} else {
				# Error.
				Time::HiRes::sleep(0.1);
				redo SI_FORK;
			}
		}
		Time::HiRes::sleep(0.1);
	}
	$src_info->{prev}{$name} = time;
}

sub do_system {
	my($name) = @_;

	# Only pass indexer the --rotate option if there is something
	# there to rotate.  Otherwise searchd refuses to drop the new
	# files into place.
	my $constants = getCurrentStatic();
	my $vardir = $constants->{sphinx_01_vardir} || '/srv/sphinx/var';
	my $do_rotate = -e catfile($vardir, 'data', "firehose_$name.spm") ? 1 : 0;

	main::slashdLog("sphinx_indexer indexing($do_rotate) $name pid $$");
	my @args = (
		'/usr/local/sphinx/bin/indexer',
		"--config $conffile",
	);
	push @args, '--rotate' if $do_rotate;
	push @args, (
		'--quiet',
		"idx_firehose_$name",
		'> /dev/null',
	);
	system(join(' ', @args));
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
		main::slashdLog("REAPER in parent $$ found reaped pid $pid");
		--$children_running;
	}
}

1;


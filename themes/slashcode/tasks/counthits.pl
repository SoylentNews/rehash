#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

# Counts hits from accesslog and updates stories.hits columns.

use strict;
use vars qw( %task $me $minutes_run $maxrows %timehash );
use Time::HiRes;
use Slash::DB;
use Slash::Display;
use Slash::Utility;
use Slash::Constants ':slashd';

(my $VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# Change this var to change how often the task runs.
$minutes_run = 10;

# Adjust this to maximize how big of a SELECT we'll do on the log DB.
# (5000 per minute (above) is probably safe, 10000 per minute just to
# be sure, get much over 500000 total and we *might* bog the log slave
# DB.)
$maxrows = 150000;

$task{$me}{timespec} = "1-59/$minutes_run * * * *";
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{fork} = SLASHD_NOWAIT;

$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	_init_timehash();

	# Find out where in the accesslog we need to start scanning from.
	# Don't start scanning from too far back.
	my $logdb = getObject('Slash::DB', { db_type => "log_slave" });
	my $lastmaxid = ($slashdb->getVar('counthits_lastmaxid', 'value', 1) || 0) + 1;
	my $newmaxid = $logdb->sqlSelect("MAX(id)", "accesslog");
	$lastmaxid = $newmaxid - $maxrows if $lastmaxid < $newmaxid - $maxrows;
        if ($lastmaxid > $newmaxid) {
                slashdLog("Nothing to do, lastmaxid '$lastmaxid', newmaxid '$newmaxid'");
                return "";
        }

        _update_timehash("misc");

	# Do the select on accesslog, and pull the sids that have been hit
	# into a counting hash.
	my %sid_count = ( );
	my $sth = $logdb->sqlSelectMany("dat", "accesslog",
		"id BETWEEN $lastmaxid AND $newmaxid
			AND status=200 AND op='article'");
	while (my($dat) = $sth->fetchrow_array()) {
		next unless $dat =~ m{^\d+/\d+/\d}; # got 3 sets of digits? good enough
		$sid_count{$dat}++;
	}
	$sth->finish();

	_update_timehash("select");

	# Update the stories table, hits columns.
	my $successes = 0;
	my $total_hits = 0;
	for my $sid (keys %sid_count) {
		my $sid_q = $slashdb->sqlQuote($sid);
		$successes += $slashdb->sqlUpdate(
			"stories",
			{ -hits => "hits + $sid_count{$sid}" },
			"sid = $sid_q",
		);
		$total_hits += $sid_count{$sid};
		_update_timehash("update");
		Time::HiRes::sleep(0.1);
		_update_timehash("sleep");
	}

	$slashdb->setVar("counthits_lastmaxid", $newmaxid);

	# And log the summary of what we did.
	my $elapsed = 0;
	for my $key (grep !/^_/, keys %timehash) { $elapsed += $timehash{$key} }
	my $report = sprintf("%d of %d sids updated for %d more hits in %.2f secs: ",
		$successes, scalar(keys %sid_count), $total_hits, $elapsed);
	my $short_report = $report;
	if (verbosity() >= 2) {
		for my $key (sort grep !/^_/, keys %timehash) {
			$report .= sprintf(" $key=%.2f", $timehash{$key});
		}
		slashdLog($report);
	}
	return $short_report;
};

sub _init_timehash {
	%timehash = ( _last => Time::HiRes::time );
}

sub _update_timehash {
	return if verbosity() < 2;
	my($field) = @_;
	my $now = Time::HiRes::time;
	my $elapsed = $now - $timehash{_last};
	$timehash{$field} ||= 0;
	$timehash{$field} += $elapsed;
	$timehash{_last} = $now;
}

1;


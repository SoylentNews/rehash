#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;

use Fcntl;
use Slash::Constants ':slashd';

use vars qw( %task $me );

# This task slowly delete the accesslog on an hourly basis.
# The concept is to keep the table small and only delete from it a few rows at a time
# to keep locking to a minimum. Load determines how long this runs.
# If you notice any issues, decrease LIMIT.
# -Brian

$task{$me}{timespec} = '22 * * * *'; # Normally run once an hour
$task{$me}{timespec_panic_1} = '20 1,2,3,4,5,6 * * *'; # Just run at night if an issue pops up
$task{$me}{timespec_panic_2} = ''; # In a pinch don't do anything
$task{$me}{resource_locks} = { logdb => 1 };
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;
	my $logdb = getObject('Slash::DB', { db_type => 'log' } );
	my $counter = 0;
	my $hoursback = $constants->{accesslog_hoursback} || 60;
	my $failures = 10; # This is probably related to a lock failure
	my $id = $logdb->sqlSelect('MAX(id)',
		'accesslog',
		"ts < DATE_SUB(NOW(), INTERVAL $hoursback HOUR)");

	if (!$id) {
		slashdLog("no accesslog rows older than $hoursback hours");
		return "nothing to do";
	}

	my $rows;
	my $total = 0;
	my $limit = 100_000;

	my $last_err = "";
	my $done = 0;
	MAINLOOP: while (!$done) {
		while ($rows = $logdb->sqlDelete("accesslog", "id < $id", $limit)) {
			$total += $rows;
			last if $rows eq "0E0";
			slashdLog("deleted so far $total of $limit rows");
			sleep 10;
		}
		my $err = "";
		if ( $counter >= $failures || !($err = $logdb->sqlError()) ) {
			# If either we're giving up because there are too many
			# failures, or the last attempt was successful, then
			# break out of the loop, we're done.
			$done = 1;
		} else {
			# We had an error but we haven't reached our max
			# number of failures yet;  keep trying.
			$last_err = "sql error: '$err'";
			slashdLog($last_err);
			sleep 5;
			$counter++;
		}
	}

	if ($counter >= $failures) {
		my $err = "more than $failures errors occured, accesslog is probably locked, last_err '$last_err'";
		slashdLog($err);
		slashdErrnote($err);
		return "failures, accesslog probably locked, $total rows deleted";
	}
	return "success, $total rows deleted";
};

1;


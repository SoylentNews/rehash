#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use utf8;

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
$task{$me}{resource_locks} = { logdb => 1, log_slave => 1 };
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;
	my $log_slave = getObject('Slash::DB', { db_type => 'log_slave' } );
	my $logdb = getObject('Slash::DB', { db_type => 'log' } );
	my $counter = 0;
	my $done = 0; 
	my $hoursback = $constants->{accesslog_hoursback} || 60;
	my $failures = 10; # This is probably related to a lock failure
	my $id = $log_slave->sqlSelectNumericKeyAssumingMonotonic(
		'accesslog', 'max', 'id',
		"ts < DATE_SUB(NOW(), INTERVAL $hoursback HOUR)");
	if (!$id) {
		slashdLog("no accesslog rows older than $hoursback hours");
		$done = 1;
		#return "nothing to do"; # We don't want to return here, need to process accesslog_admin as well.
	}

	# If the log master is ENGINE=BLACKHOLE, we can't delete from there;
	# delete from the log slave instead.
	my $delete_db = $logdb;
	if (! $logdb->sqlSelect('id', 'accesslog', "id=$id")) {
		$delete_db = $log_slave;
	}

	my $rows;
	my $total_accesslog = 0;
	my $limit = 100_000;

	my $last_err = "";
	MAINLOOP: while (!$done) {
		while ($rows = $delete_db->sqlDelete("accesslog", "id < $id", $limit)) {
			$total_accesslog += $rows;
			last if $rows eq "0E0";
			slashdLog("deleted so far $total_accesslog of $limit accesslog rows");
			sleep 10;
		}
		my $err = "";
		if ( $counter >= $failures || !($err = $delete_db->sqlError()) ) {
			# If either we're giving up because there are too many
			# failures, or the last attempt was successful, then
			# break out of the loop, we're done.
			$done = 1;
		} else {
			# We had an error but we haven't reached our max
			# number of failures yet;  keep trying.
			$last_err = "accesslog sql error: '$err'";
			slashdLog($last_err);
			sleep 5;
			$counter++;
		}
	}
	$done = 0;

	if ($counter >= $failures) {
		my $err = "more than $failures errors occured, accesslog is probably locked, last_err '$last_err'";
		slashdLog($err);
		slashdErrnote($err);
		#return "failures, accesslog probably locked, $total_accesslog accesslog rows deleted"; # no return yet, go on with the rest
	}
	$counter = 0;

	$id = $log_slave->sqlSelectNumericKeyAssumingMonotonic(
		'pagemark', 'max', 'id',
		"ts < DATE_SUB(NOW(), INTERVAL $hoursback HOUR)");
	if (!$id) {
		slashdLog("no pagemark rows older than $hoursback hours");
		$done = 1;
	}

	my $total_pagemark = 0;

	$last_err = "";
	MAINLOOP: while (!$done) {
		while ($rows = $delete_db->sqlDelete("pagemark", "id < $id", $limit)) {
			$total_pagemark += $rows;
			last if $rows eq "0E0";
			slashdLog("deleted so far $total_pagemark of $limit pagemark rows");
			sleep 10;
		}
		my $err = "";
		if ( $counter >= $failures || !($err = $delete_db->sqlError()) ) {
			# If either we're giving up because there are too many
			# failures, or the last attempt was successful, then
			# break out of the loop, we're done.
			$done = 1;
		} else {
			# We had an error but we haven't reached our max
			# number of failures yet;  keep trying.
			$last_err = "pagemark sql error: '$err'";
			slashdLog($last_err);
			sleep 5;
			$counter++;
		}
	}
	$done = 0;

	if ($counter >= $failures) {
		my $err = "more than $failures errors occured, pagemark is probably locked, last_err '$last_err'";
		slashdLog($err);
		slashdErrnote($err);
		#return "failures, accesslog probably locked, $total_accesslog accesslog rows deleted"; # no return yet, go on with the rest
	}
	$counter = 0;

	# Now handle accesslog_admin table

	$hoursback = $constants->{accesslog_admin_hoursback} || 720; # Default to keeping one month of entries

	$id = $log_slave->sqlSelectNumericKeyAssumingMonotonic(
		'accesslog_admin', 'max', 'id',
		"ts < DATE_SUB(NOW(), INTERVAL $hoursback HOUR)");
	if (!$id) {
		slashdLog("no accesslog_admin rows older than $hoursback hours");
	}

	$last_err = "";
	my $total_adminlog = 0;

	MAINLOOP: while (!$done) {
		while ($rows = $delete_db->sqlDelete("accesslog_admin", "id < $id", $limit)) {
			$total_adminlog += $rows;
			last if $rows eq "0E0";
			slashdLog("deleted so far $total_adminlog of $limit accesslog_admin rows");
			sleep 10;
		}
		my $err = "";
		if ( $counter >= $failures || !($err = $delete_db->sqlError()) ) {
			# If either we're giving up because there are too many
			# failures, or the last attempt was successful, then
			# break out of the loop, we're done.
			$done = 1;
		} else {
			# We had an error but we haven't reached our max
			# number of failures yet;  keep trying.
			$last_err = "accesslog_admin sql error: '$err'";
			slashdLog($last_err);
			sleep 5;
			$counter++;
		}
	}

	if ($counter >= $failures) {
		my $err = "more than $failures errors occured, accesslog_admin is probably locked, last_err '$last_err'";
		slashdLog($err);
		slashdErrnote($err);
		#return "failures, accesslog probably locked, $total_accesslog accesslog rows deleted"; # no return yet, go on with the rest
	}
	

	return "success, $total_accesslog accesslog rows deleted, $total_pagemark pagemark rows deleted, $total_adminlog accesslog_admin rows deleted";
};

1;


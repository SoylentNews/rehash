#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use vars qw( %task $me );
use Safe;
use Slash;
use Slash::DB;
use Slash::Display;
use Slash::Utility;
use Slash::Constants ':slashd';
use Time::HiRes;

(my $VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

$task{$me}{timespec} = '46 * * * *';
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{fork} = SLASHD_NOWAIT;

# Log queries per second and qpp hourly 
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;
	my $db_stats = {};

	my $stats = getObject('Slash::Stats::Writer');
	my $sleep_time = $constants->{qps_sample_time} || 15;
	my $vus = $slashdb->getDBVirtualUsers();
	push @$vus, $slashdb->{virtual_user} unless scalar grep { $_ eq $slashdb->{virtual_user} } @$vus;

	my @dbs = ();
	
	for my $vu (@$vus) {
		my $db = getObject("Slash::DB", $vu);
		push @dbs, {
			vu => $vu,
			db => $db
		};
	}

	if (!@dbs) {
		@dbs = ( {
			vu => $slashdb->{virtual_user},
			db => $slashdb
		});
	}

	my $time_start = Time::HiRes::time;

	# Need to hit the actual accesslog if we're going to get a meaningful correlation
	# between queries performed and pages.  For a busy site you can lower the qps_sample_time
	# to lower the hit on the log db, for lower traffic sites  you might want to raise that
	# number to make this a more meaningful statistic

	my $logdb = getObject('Slash::DB', { db_type => "log" });
	my $start_accesslog_id = $logdb->sqlSelect("MAX(id)", "accesslog");
	my $queries = 0;

	for my $db (@dbs) {
		$db_stats->{$db->{vu}}{start_q} = $db->{db}->showQueryCount();
	}
	Time::HiRes::sleep($sleep_time);	
	
	for my $db (@dbs) {
		$db_stats->{$db->{vu}}{end_q} = $db->{db}->showQueryCount();
		$db_stats->{$db->{vu}}{diff_q} = $db_stats->{$db->{vu}}{end_q} - $db_stats->{$db->{vu}}{start_q};
	}
	my $end_accesslog_id = $logdb->sqlSelect("MAX(id)", "accesslog");


	my $time_end = Time::HiRes::time;
	my $pages = $logdb->sqlCount("accesslog", "id BETWEEN " . ($start_accesslog_id +1) . " AND $end_accesslog_id" . " AND op != 'image'") || 1;

	my $elapsed = $time_end - $time_start;
	$elapsed ||= 1;
	
	my $time = $slashdb->getTime();
	
	my ($hour) = $time =~/^\d{4}-\d{2}-\d{2} (\d{2}):\d{2}:\d{2}/;
	slashdLog("$time | $hour\n");

	for my $db (@dbs) {
		$queries += $db_stats->{$db->{vu}}{diff_q};
		$db_stats->{$db->{vu}}{qps} = $db_stats->{$db->{vu}}{diff_q} / $elapsed;
		$stats->createStatDaily("qps_$db->{vu}_$hour", $db_stats->{$db->{vu}}{qps});
	}
	my $qpp = $queries / $pages;
	$stats->createStatDaily("qpp_$hour", $qpp);
	return "q: $queries p: $pages e: $elapsed qpp: $qpp";
};

1;


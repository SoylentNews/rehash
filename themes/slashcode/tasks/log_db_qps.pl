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

$task{$me}{timespec} = '57 * * * *';
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{fork} = SLASHD_NOWAIT;

# Log queries per second and qpp hourly 
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;
	my $db_stats = {};
	my $save_vars = {};

	my $stats = getObject('Slash::Stats::Writer');
	my $vus = $slashdb->getDBVirtualUsers();
	push @$vus, $slashdb->{virtual_user}
		unless scalar grep { $_ eq $slashdb->{virtual_user} } @$vus;

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

	my $queries = 0;

	
	my $last_time = $slashdb->getVar("db_questions_lasttime", "value", 1);
	for my $db (@dbs) {
		$save_vars->{"db_questions_last_$db->{vu}"} = $db->{db}->showQueryCount();
	}

	my $new_last_time = time;
	
	my $logdb = getObject('Slash::DB', { db_type => "log" });
	my $accesslog_last = $slashdb->getVar('db_questions_accesslog_last','value', 1);
	my $new_accesslog_last =
		$save_vars->{db_questions_accesslog_last} =
			$logdb->sqlSelect("MAX(id)", "accesslog");
	$save_vars->{db_questions_lasttime} = $new_last_time;

	my $time = $slashdb->getTime();	
	my ($hour) = $time =~/^\d{4}-\d{2}-\d{2} (\d{2}):\d{2}:\d{2}/;

	my $elapsed = 0;
	my $pages = 0;

	$elapsed = $new_last_time - $last_time if $last_time;
	if ($accesslog_last && $new_accesslog_last) {
		if ($constants->{accesslog_imageregex} eq 'NONE') {
			$pages = $new_accesslog_last - $accesslog_last;
		} else {
			$pages = $logdb->sqlCount("accesslog",
				"id BETWEEN $accesslog_last AND $new_accesslog_last
				 AND op != 'image'");
		}
	}

	if ($elapsed && $elapsed > 0) {
		for my $db (@dbs) {
			my $vu = $db->{vu};
			my $last = $slashdb->getVar("db_questions_last_$vu", "value", 1 );
			my $new_last = $save_vars->{"db_questions_last_$vu"};
			my $diff = $new_last - $last;
			if($elapsed > 0 && $diff > 0) {
				$queries += $diff;
				my $qps = $diff / $elapsed;
				$stats->createStatDaily("qps_$db->{vu}_$hour", $qps);
			}
		}
	}
	
	foreach my $varname (keys %$save_vars) {
		my $cur_val = $slashdb->getVar($varname, 'value', 1);
		if (!defined $cur_val) {
			$slashdb->createVar($varname, $save_vars->{$varname});
		} else {
			$slashdb->setVar($varname, $save_vars->{$varname});
		}
	}

	my $qpp = 0;
	if ($pages > 0) {
		$qpp = $queries / $pages;
		$stats->createStatDaily("qpp_$hour", $qpp);
	}
	return "q: $queries p: $pages e: $elapsed qpp: $qpp";
};

1;


#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;

use Slash::Constants ':slashd';

use vars qw( %task $me );
use Time::HiRes qw(tv_interval gettimeofday);
# Remember that timespec goes by the database's time, which should be
# GMT if you installed everything correctly.  So 6:07 AM GMT is a good
# sort of midnightish time for the Western Hemisphere.  Adjust for
# your audience and admins.
$task{$me}{timespec} = '0-59/1 * * * *';
$task{$me}{timespec_panic_2} = ''; # if major panic, this can wait
$task{$me}{on_startup} = 1;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $logdb = getObject("Slash::DB", { db_type => 'log' });
	
	my $weeks_back = $constants->{cur_performance_stats_weeks} || 4;
	my $secs_per_week = 60 * 60 * 24 * 7;

	my $ops = [ @{$constants->{cur_performance_stat_ops}} ];

	
	my $cur_time =  $slashdb->getTime();
	my ($cur_hour) = $cur_time =~/^\d{4}-\d{2}-\d{2} (\d{2})/;

	my @dates;
	
	for (1..$weeks_back) {
		my $time = $slashdb->getTime({ add_secs => -$secs_per_week * $_});
		my ($date) = $time =~/^(\d{4}-\d{2}-\d{2})/;
		push @dates, $date;
	}
	
	my $start_id = $slashdb->getVar('cur_performance_stats_lastid','value', 1) || 0;
	my ($cur_results, $hist_results);

	
	my ($start_id) = $logdb->sqlSelect("MAX(id)","accesslog") || 0;
	my $t0 = [gettimeofday];
	Time::HiRes::sleep(5);
	my ($max_id) = $logdb->sqlSelect("MAX(id)", "accesslog") || 0;
	my $elapsed = tv_interval($t0, [gettimeofday]);
	my $pages = $logdb->sqlCount("accesslog", "id > $start_id AND id<= $max_id AND op!='image'");
	my $pps;
	if ($pages and $elapsed) {
		$pps = sprintf("%4.2f", $pages / $elapsed );
	} else {
		$pps = "0";
	}
	
	$slashdb->setVar("cur_performance_pps", $pps);
	
	if ($start_id) {
		$hist_results = $slashdb->avgDynamicDurationForHour($ops, \@dates, $cur_hour);
		$cur_results  = $logdb->avgDynamicDurationForMinutesBack($ops, 1, $start_id);
	}
	$slashdb->setVar("cur_performance_stats_lastid", $max_id);
	return if !$start_id;
	

	my @results;

	my $sum_cur_duration = 0;
	my $sum_hist_duration = 0;

	foreach my $op (sort keys %$cur_results) {
		my $hist_duration  = $hist_results->{"duration_dy\_$op\_$cur_hour\_mean"}{avg};
		my $cur_duration   = $cur_results->{$op}{avg};
		my $sec     = $cur_duration ? sprintf("%.2f", $cur_duration) : "N/A";
		my $percent = $hist_duration ? int((100 * $cur_duration / $hist_duration ) - 100)."%" : "N/A";
		$percent = "+$percent" if $percent=~/^[^N-]/;
		if ($cur_duration && $hist_duration) {
			$sum_cur_duration  += $cur_duration;
			$sum_hist_duration += $hist_duration;
		}
		push @results, $op, $sec, $percent;
	}

	my $percent_diff;
	my $abs_percent_diff;
	my $type;

	if ($sum_hist_duration) {
		$percent_diff = int(100 * $sum_cur_duration / $sum_hist_duration) - 100;
		$abs_percent_diff = abs($percent_diff);
		$type = $percent_diff <= 0 ? "fast" : "slow";
		push @results, $percent_diff, $abs_percent_diff, $type;
		
	} else {
		push @results, "", "No past performance data for comparison";
	}

	
	$slashdb->setVar('cur_performance_stats', join('|', @results));

};

1;


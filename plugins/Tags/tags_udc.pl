#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

# Tags Upvote/Downvote Count
#
# Count the sum of clouts of upvote and downvote tags each hour.

# XXX should reupdate when tags are deactivated
# XXX should reupdate when user clouts change

use strict;
use vars qw( %task $me $task_exit_flag
	$proportion_hourofday $proportion_dayofweek
	$upid $dnid );
use Time::HiRes;
use Slash::DB;
use Slash::Display;
use Slash::Utility;
use Slash::Constants ':slashd';

(my $VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

$task{$me}{timespec} = '2-59/5 * * * *';
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{fork} = SLASHD_NOWAIT;

$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $updated = 0;

	my $start_time = time();
	my $max_run_time = 10*60;

	my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });
	$upid = $tags_reader->getTagnameidCreate($constants->{tags_upvote_tagname}   || 'nod');
	$dnid = $tags_reader->getTagnameidCreate($constants->{tags_downvote_tagname} || 'nix');
	$proportion_hourofday = $tags_reader->sqlSelectAllKeyValue('hour, proportion', 'tags_hourofday');
	$proportion_dayofweek = $tags_reader->sqlSelectAllKeyValue('day,  proportion', 'tags_dayofweek');

	my $lookback_hours = 6;
	my $curhour_ut = int(time()/3600) * 3600;
	my $cloutsum_hourback = { };

	# First, set in the DB and populate %$cloutsum_hourback with the
	# actual cloutsum values for the past completed $lookback_hours.
	for my $hoursback (1..$lookback_hours) {
		$cloutsum_hourback->{$hoursback} = populate_tags_udc($curhour_ut, $hoursback);
		++$updated;
	}

	# Then, using those values, generate projected values for the
	# current hour and the hour after that.  (And store those values
	# into %$cloutsum_hourback for handy debugging if necessary.)
	for my $hoursback (-1..0) {
		$cloutsum_hourback->{$hoursback} = project_tags_udc($curhour_ut, $hoursback,
			$lookback_hours, $cloutsum_hourback);
		++$updated;
	}

	my $min_tag_hour_ut = $slashdb->sqlSelect(
		'FLOOR(UNIX_TIMESTAMP(MIN(created_at))/3600)*3600', 'tags');
	my $min_pop_hour_ut = $slashdb->sqlSelect(
		'FLOOR(UNIX_TIMESTAMP(MIN(hourtime  ))/3600)*3600', 'tags_udc');
	my $hour_ut = $min_pop_hour_ut - 3600;
	while ($hour_ut >= $min_tag_hour_ut && time() < $start_time + $max_run_time && !$task_exit_flag) {
		populate_tags_udc($hour_ut);
		$hour_ut -= 3600;
		Time::HiRes::sleep(0.1);
		++$updated;
	}

	sleep 5;

	update_hourofday();
	update_dayofweek();

	return $updated;
};

sub populate_tags_udc {
	my($cur_hour, $hoursback) = @_;

	warn "populate_tags_udc doesn't work for the current hour or later: '$cur_hour' '$hoursback' '" . time() . "'"
		if $hoursback < 1;

	my $hour = $cur_hour - 3600*$hoursback;
	my $hour_next = $hour + 3600;
	my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });
	my $tags_ar = $tags_reader->sqlSelectAllHashrefArray(
		'*',
		'tags',
		"created_at BETWEEN FROM_UNIXTIME($hour) AND DATE_ADD(FROM_UNIXTIME($hour), INTERVAL 3599 SECOND)
		 AND tagnameid IN ($dnid, $upid)
		 AND inactivated IS NULL");
	$tags_reader->addCloutsToTagArrayref($tags_ar);

	my $cloutsum = 0;
	for my $tag_hr (@$tags_ar) {
		$cloutsum += $tag_hr->{total_clout};
	}

	my $slashdb = getCurrentDB();
	$slashdb->sqlReplace('tags_udc',
		{ -hourtime => "FROM_UNIXTIME($hour)", udc => $cloutsum });
	return $cloutsum;
}

sub project_tags_udc {
	my($cur_hour, $hoursback, $lookback_hours, $cloutsum_hourback) = @_;

	warn "project_tags_udc is unnecessary for past hours: '$cur_hour' '$hoursback' '" . time() . "'"
		if $hoursback > 0;
	warn "project_tags_udc won't work looking back fewer than 1 hour: '$lookback_hours'"
		if $lookback_hours < 1;

	my $slashdb = getCurrentDB();
	my $hour = $cur_hour - 3600*$hoursback;
	my $hour_next = $hour + 3600;

	my $hour_weight_sum = 0;
	my $hour_weight = { };
	my $period_ratio = { };
	for my $h (1 .. $lookback_hours) {
		# XXX use a very simple formula for weighting hourly lookback:
		# the previous hour gets weight n, the hour before that n-1,
		# and so on down to the oldest hour which gets weight 1.
		# I could make this more complicated, but I don't know if that
		# would make it better.
		$hour_weight->{$h} = 1 + $lookback_hours-$h;
		$hour_weight_sum += $hour_weight->{$h};
	}
	for my $h ($hoursback .. $lookback_hours) {
		# Now load up the periodic ratios for all involved hours.
		my $this_hour_ut = $cur_hour - 3600*$h;
		my($this_hourofday, $this_dayofweek) =
			$slashdb->sqlSelect("HOUR(FROM_UNIXTIME($this_hour_ut)), DAYOFWEEK(FROM_UNIXTIME($this_hour_ut))");
		my $this_hour_ratio = $proportion_hourofday->{$this_hourofday}*24;
		my $this_day_ratio  = $proportion_dayofweek->{$this_dayofweek}*7;
		$period_ratio->{$h} = $this_hour_ratio * $this_day_ratio;
print STDERR "period ratio for $this_hour_ut ($cur_hour - $h): $period_ratio->{$h} (day $this_dayofweek hour $this_hourofday hour_ratio $this_hour_ratio day_ratio $this_day_ratio)\n";
	}
	# the formula is:
	# predictedudc =
	#	sum( hourweight(hour) * actualudc(old) / periodratio(old) )
	#	* periodratio(next)
	#	/ sumhourweight
	my $proj_sum = 0;
	for my $h (1 .. $lookback_hours) {
		$proj_sum += $hour_weight->{$h} * $cloutsum_hourback->{$h} / $period_ratio->{$h};
	}
	$proj_sum *= $period_ratio->{$hoursback} / $hour_weight_sum;
print STDERR "sum for $hoursback: $proj_sum\n";

	$slashdb->sqlReplace('tags_udc',
		{ -hourtime => "FROM_UNIXTIME($hour)", udc => $proj_sum });
	return $proj_sum;
}

sub update_hourofday {
	my $tags = getObject('Slash::Tags');
	my $constants = getCurrentStatic();
	my $daysback = $constants->{tags_udc_daysback} || 182;
	my $hoursback = $daysback*24 + 1;
	my $hour_udc = $tags->sqlSelectAllKeyValue(
		'HOUR(hourtime) AS h, SUM(udc)',
		'tags_udc',
		"hourtime BETWEEN DATE_SUB(NOW(), INTERVAL $hoursback HOUR) AND DATE_SUB(NOW(), INTERVAL 1 HOUR)",
		'GROUP BY h');
	my $total = 0;
	for my $hour (keys %$hour_udc) {
		$total += $hour_udc->{$hour};
	}
	if (!$total) {
		slashdLog("cannot calculate hourofday, total is 0");
		return;
	}
	for my $hour (sort { $a <=> $b } keys %$hour_udc) {
		$tags->sqlReplace('tags_hourofday',
			{ hour => $hour, proportion => $hour_udc->{$hour}/$total });
	}
}

sub update_dayofweek {
	my $tags = getObject('Slash::Tags');
	my $constants = getCurrentStatic();
	my $daysback = $constants->{tags_udc_daysback} || 182;
	my $hoursback = $daysback*24 + 1;
	my $day_udc = $tags->sqlSelectAllKeyValue(
		'DAYOFWEEK(hourtime) AS d, SUM(udc)',
		'tags_udc',
		"hourtime BETWEEN DATE_SUB(NOW(), INTERVAL $hoursback HOUR) AND DATE_SUB(NOW(), INTERVAL 1 HOUR)",
		'GROUP BY d');
	my $total = 0;
	for my $day (keys %$day_udc) {
		$total += $day_udc->{$day};
	}
	if (!$total) {
		slashdLog("cannot calculate dayofweek, total is 0");
		return;
	}
	for my $day (sort { $a <=> $b } keys %$day_udc) {
		$tags->sqlReplace('tags_dayofweek',
			{ day => $day, proportion => $day_udc->{$day}/$total });
	}
}

1;


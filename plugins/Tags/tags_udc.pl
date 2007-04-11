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
	$upid $dnid );
use Time::HiRes;
use Slash::DB;
use Slash::Display;
use Slash::Utility;
use Slash::Constants ':slashd';

(my $VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

$task{$me}{timespec} = '25,55 * * * *';
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

	my $nexthour_ut = int(time()/3600 + 1) * 3600;
	for my $hoursback (0..6) {
		populate_tags_udc($nexthour_ut - $hoursback*3600);
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
	my($hour) = @_;
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


#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;

use Time::HiRes;

use Slash;
use Slash::Constants ':slashd';
use Slash::Display;
use Slash::Utility;

use vars qw(
	%task	$me	$task_exit_flag
);

$task{$me}{timespec} = '18 * * * *';
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;

	return 'task is no longer used';

	my @slices = split(/\|/,$constants->{firehose_color_slices});
	my $pops = $slashdb->sqlSelectColArrayref("popularity", "firehose", "createtime > DATE_SUB(NOW(),INTERVAL 1 DAY) and popularity > 0", "order by popularity desc");

	my $total = scalar(@$pops);

	# Not enough entries to calculate a new value
	return unless @$pops > 40;
	my($fixed_total, $unfixed_total);
        foreach (@slices) {
        	$fixed_total += $_ if $_ >= 1;
	}

	$unfixed_total = $total - $fixed_total;
	@slices = map { $_ = $unfixed_total * $_ if $_ < 1; $_} @slices;

	my $slice_point = 0;
	my @slice_points;

	foreach (@slices) {
		$slice_point += $_;
		push @slice_points, $pops->[int($slice_point - 1)];
	}

	# Add large negative number for everything that falls below lowest thresh
	push @slice_points, "-99999";
	
	my $last = -100000;
	
	# ensure there's at least a gap of 3 between each slice point
	@slice_points = reverse map { $_ = $last + 3 if $_ < ($last + 3); $last = $_; $_ } reverse @slice_points;


	my $slice_point_str = join '|', @slice_points;
	$slashdb->setVar("firehose_slice_points", $slice_point_str);
	slashdLog("set slice points to: $slice_point_str");
};

1;


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

$task{$me}{timespec} = '1 1,7,13,19 * * *';
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;

	my $firehose = getObject("Slash::FireHose");
	my $skins = $slashdb->getSkins();

	foreach my $skid (%$skins) {
		my $skid_lookup = $skid == $constants->{mainpage_skid} ? 0 : $skid;
		my $story_vol = $firehose->genFireHoseWeeklyVolume({
			type => "story",
			color => "black",
			primaryskid => $skid_lookup
		});

		my $other_vol = $firehose->genFireHoseWeeklyVolume({
			not_type => "story",
			color => "indigo",
			primaryskid => $skid_lookup
		});
		$firehose->setSkinVolume({ skid => $skid, story_vol => $story_vol, other_vol => $other_vol });
	}
};

1;


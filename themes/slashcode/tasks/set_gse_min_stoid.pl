#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

# Does the most common getStoriesEssentials call, determines the
# minimum stoid returned, and writes it to a var.

use strict;
use vars qw( %task $me );
use Time::HiRes;
use Slash::DB;
use Slash::Display;
use Slash::Utility;
use Slash::Constants ':slashd';

(my $VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

$task{$me}{on_startup} = 1;
$task{$me}{timespec} = "59 10 * * *";
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{fork} = SLASHD_NOWAIT;

$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	# We should be on the mainpage skin anyway, but just to be sure.
	# Since this is the whole point!
	setCurrentSkin($constants->{mainpage_skid});
	my $gSkin = getCurrentSkin();

	# Normally gSE will pad the returned value with this much.
	my $limit_extra = int(($gSkin->{artcount_min} + $gSkin->{artcount_max})/2);
	# But for a safety margin, we want more.
	$limit_extra = $limit_extra * 3 + 100;

	# Normally gSE will look this far in the future for stories.
	my $future_secs = $constants->{subscribe_future_secs};
	# But again for a safety margin, we want more.
	$future_secs = $future_secs * 3 + 86400;

	my $min_stoid = $slashdb->getStoriesEssentials({
		return_min_stoid_only	=> 1,
		try_future		=> 1,
		limit_extra		=> $limit_extra,
		future_secs		=> $future_secs,
	});

	# More safety margin.
	$min_stoid -= 100;

	# This optimization won't help us if it includes a significant
	# fraction of the rows in the stories table -- write a zero.
	$min_stoid = 0 if $min_stoid < 500;

	$slashdb->setVar("gse_min_stoid", $min_stoid);
	return "wrote $min_stoid";
};

1;


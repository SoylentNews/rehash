#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;

use Slash::Constants ':slashd';

use vars qw( %task $me );


$task{$me}{timespec} = '0-59/10 * * * 6';
$task{$me}{timespec_panic_1} = ''; # if panic, this can wait
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtualuser, $constants, $slashdb, $user, $info, $gSkin) = @_;

	my $ratings_reader = getObject('Slash::Ratings', { db_type => 'reader' });
	my $ratings_writer = getObject('Slash::Ratings');

	my $last_max = $slashdb->getVar('set_disc_rating_last_cid', 'value', 1) || 0;
	my $this_min = $last_max + 1; # don't count the last-counted vote twice
	my $this_max = $slashdb->sqlSelect("MAX(cid)", "comment_vote") || $last_max;
	return "no new comments" if $this_max < $this_min;

	my $discussions  = $ratings_reader->getUniqueDiscussionsBetweenCids($this_min, $this_max);
	my $num_replaces = $ratings_writer->updateDiscussionRatingStats($discussions);

	$slashdb->setVar("set_disc_rating_last_cid", $this_max);

	return "$num_replaces ratings updated";
};

1;


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
	my $last_max = $slashdb->getVar('set_disc_rating_last_id', 'value', 1) || 0;
	my $this_max = $slashdb->sqlSelect("MAX(vote_id)", "comment_vote") || $last_max;

	my $discussions = $slashdb->sqlSelectColArrayref(
		"DISTINCT(discussion)",
		"comment_vote",
		"vote_id BETWEEN " . ($last_max+1) . " AND $this_max");

	if (@$discussions) {
		my $discussion_clause = "discussion IN (" . join(",", @$discussions) . ")";
		my $summary = $slashdb->sqlSelectAllHashref(
			"discussion", 
			"discussion, COUNT(*) AS active_votes, AVG(val) AS rating",
			"comment_vote",
			"$discussion_clause AND active = 'yes'",
			"GROUP BY discussion"
		);

		my $votes = $slashdb->sqlSelectAllHashref(
			"discussion", 
			"discussion, COUNT(*) AS votes",
			"comment_vote",
			"$discussion_clause",
			"GROUP BY discussion"
		);

		foreach my $discussion (@$discussions) {
			my $avg_rating = $summary->{$discussion}{rating}; # undef/NULL is OK here
			my $active_votes = $summary->{$discussion}{active_votes} || 0;
			my $total_votes = $votes->{$discussion}{votes} || 0;

			$slashdb->sqlReplace(
				"discussion_rating",
				{
					discussion => $discussion,
					total_votes => $total_votes,
					active_votes => $active_votes,
					avg_rating => $avg_rating
				
				}
			)
		}
	}

	my $num = @$discussions;
	$slashdb->setVar("set_disc_rating_last_id", $this_max);

	slashdLog("$num ratings updated");

};

1;


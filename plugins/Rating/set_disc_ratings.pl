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
	my $this_max = $slashdb->sqlSelect("MAX(vote_id)", "comment_vote",) || $last_max;
	
	my $sids = $slashdb->sqlSelectColArrayref("DISTINCT(sid)", "comment_vote", "vote_id > $last_max");
	
	if (@$sids) {
		my $sid_clause = "sid IN (".( join ",", @$sids ).")";
		my $summary = $slashdb->sqlSelectAllHashref("sid", 
						"sid, count(*) as active_votes, avg(val) as rating",
						"comment_vote",
						"$sid_clause AND active = 1",
						"GROUP BY sid"
		);
	
		my $votes = $slashdb->sqlSelectAllHashref("sid", 
						"sid, count(*) as votes",
						"comment_vote",
						"$sid_clause",
						"GROUP BY sid"
		);
		
		foreach my $sid (@$sids) {
			my $avg_rating = $summary->{$sid}{rating} || 0;
			my $active_votes = $summary->{$sid}{active_votes} || 0;
			my $total_votes = $votes->{$sid}{votes} || 0;
			
			$slashdb->sqlReplace(
				"discussion_rating",
				{
					sid => $sid,
					total_votes => $total_votes,
					active_votes => $active_votes,
					avg_rating => $avg_rating
				
				}
			)
		}
	}

	my $num = @$sids;
	$slashdb->setVar("set_disc_rating_last_id", $this_max);
	
	slashdLog("$num Ratings updated");

};

1;


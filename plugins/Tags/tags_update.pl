#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

# Performs periodic updates for any new tags added.

use strict;
use vars qw( %task $me $minutes_run $tags_reader );
use Time::HiRes;
use Slash::DB;
use Slash::Display;
use Slash::Utility;
use Slash::Constants ':slashd';

(my $VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# Change this var to change how often the task runs.
$minutes_run = 1;

$task{$me}{timespec} = "0-59/$minutes_run * * * *";
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{resource_locks} = { };
$task{$me}{fork} = SLASHD_NOWAIT;

$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	$tags_reader = getObject("Slash::Tags", { db_type => 'reader' });

	# Find out which tag we need to start scanning from.
	my $lastmaxid = ($slashdb->getVar('tags_stories_lastscanned', 'value', 1) || 0) + 1;
	my $newmaxid = $tags_reader->sqlSelect("MAX(tagid)", "tags");
        if ($lastmaxid > $newmaxid) {
                slashdLog("Nothing to do, lastmaxid '$lastmaxid', newmaxid '$newmaxid'");
		if ($lastmaxid > $newmaxid + 2) {
			# Something odd is going on... this ID is off.
			slashdErrnote("tags_stories_lastscanned '$lastmaxid' is higher than it should be '$newmaxid'");
		}
                return "";
        }

	# Record what we're about to do.
	$slashdb->setVar('tags_stories_lastscanned', $newmaxid);

	# First pass:  find which stoid's have been touched since
	# the last run.
	my $stories_gtid = $slashdb->getGlobjTypes()->{stories};
	my $stoids = $tags_reader->sqlSelectColArrayref(
		'DISTINCT target_id',
		'globjs, tags',
		"tags.globjid = globjs.globjid
		 AND tagid >= $lastmaxid
		 AND gtid = $stories_gtid");
	if (!$stoids || !@$stoids) {
		return "no new stories tagged '$lastmaxid' '$newmaxid'";
	}

	# Second pass:  for each of those stories, tally up the "top n"
	# tags and store a text string listing them into a param.
	my $userdata_cache = { };
	my $tagname_param_cache = { };
	my $tagname_cmds_cache = { };
	my $n_stories_updated = 0;
	for my $stoid (@$stoids) {
		my $tag_ar = $tags_reader->getTagsByNameAndIdArrayref('stories', $stoid);
		my @top_5 = getTop5($tag_ar, $stoid,
			$userdata_cache, $tagname_param_cache, $tagname_cmds_cache);
		warn "no top_5 for $stoid" if !@top_5;
		$n_stories_updated += $slashdb->setStory($stoid,
			{ tags_top => join(" ", @top_5) });
	}

	return "$n_stories_updated updated";
};

# Very crude info-summarization function that will change.

sub getTop5 {
	my($tag_ar, $stoid, $users, $tagname_params, $tagname_admincmds) = @_;

	return ( ) unless $tag_ar && @$tag_ar;

	my $globjid = $tags_reader->getGlobjidFromTargetIfExists('stories', $stoid);
	return ( ) unless $globjid;

	my %uids_unique = map { ( $_->{uid}, 1 ) } @$tag_ar;
	my @uids = keys %uids_unique;
	$users ||= { };
	for my $uid (@uids) {
		$users->{$uid} ||= $tags_reader->getUser($uid);
	}

	my %tagnameids_unique = map { ( $_->{tagnameid}, 1 ) } @$tag_ar;
	my @tagnameids = keys %tagnameids_unique;
	$tagname_params ||= { };
	for my $tagnameid (@tagnameids) {
		$tagname_params->{$tagnameid} ||= $tags_reader->getTagnameParams($tagnameid);
	}

	$tagname_admincmds ||= { };
	for my $tagnameid (@tagnameids) {
		$tagname_admincmds->{$tagnameid} ||= $tags_reader->getTagnameAdmincmds($tagnameid);
	}
#use Data::Dumper; print STDERR "tagname_admincmds: " . Dumper($tagname_admincmds);

	my %tagids_unique = map { ( $_->{tagid}, 1 ) } @$tag_ar;
	my @tagids = sort { $a <=> $b } keys %tagids_unique;
	my $tagids_str = join(',', @tagids);
	my $tag_params = $tags_reader->sqlSelectAllHashref(
		[qw( tagid name )],
		'tagid, name, value',
		'tag_params',
		"tagid IN ($tagids_str)");
#use Data::Dumper; print STDERR "tagids='@tagids' tag_params: " . Dumper($tag_params);

	my %scores = ( );
	for my $tag (@$tag_ar) {
		# Very crude weighting algorithm that will change.
		my $user = $users->{$tag->{uid}};
		my $tagid = $tag->{tagid};
		my $tagnameid = $tag->{tagnameid};
		my $tagname = $tag->{tagname};
		$scores{$tagname} ||= 0;

		my $user_clout = $user->{karma} >= -3 ? log($user->{karma}+10) : 0;
		$user_clout += 5 if $user->{seclev} > 1;
		$user_clout *= $user->{tag_clout};
		my $tag_global_clout = defined($tag_params->{$tagid}{tag_clout})
			? $tag_params->{$tagid}{tag_clout} : 1;
		my $tag_story_clout = getTagStoryClout($tagname_admincmds->{$tagnameid}, $globjid, $tag);
		my $tagname_clout = $tagname_params->{$tagnameid}{tag_clout} || 1;
		$scores{$tagname} += $user_clout * $tag_global_clout * $tag_story_clout * $tagname_clout;
	}

	my @opposite_tagnames =
		map { $tags_reader->getOppositeTagname($_) }
		grep { $_ !~ /^!/ && $scores{$_} > 0 }
		keys %scores;
	for my $opp (@opposite_tagnames) {
		next unless $scores{$opp};
		# Both $opp and its opposite exist in %scores.  Subtract
		# $opp's score from its opposite and vice versa.
		my $orig = $tags_reader->getOppositeTagname($opp);
		my $orig_score = $scores{$orig};
		$scores{$orig} -= $scores{$opp};
		$scores{$opp} -= $orig_score;
	}

	my @top = sort {
		$scores{$b} <=> $scores{$a}
		||
		$a cmp $b
	} keys %scores;

	my $constants = getCurrentStatic();
	my $minscore = $constants->{tags_stories_top_minscore} || 2;
print STDERR scalar(localtime) . " minscore=$minscore top tags for $stoid: " . join(" ", map { sprintf("%s=%.3f", $_, $scores{$_}) } @top ) . "\n";
	@top = grep { $scores{$_} >= $minscore } @top;

	$#top = 4 if $#top > 4;
	return @top;
}

sub getTagStoryClout {
	my($tagname_admincmd_ar, $globjid, $tag) = @_;
	# Walk thru the list of all admin commands applied to this
	# tagname, on all stories, and globally.  If any of these
	# commands send that tag (on this story or globally) to 0,
	# return 0 immediately.
	for my $hr (@$tagname_admincmd_ar) {
		if ($hr->{cmdtype} eq '^') {
			# If this tagname was marked invalid for this one
			# story up to a point in time, and this tag was
			# before that time, this tag has no clout.
			if (($hr->{globjid} eq 'all' || $hr->{globjid} == $globjid)
				&& $tag->{created_at} lt $hr->{created_at}) {
				return 0;
			}
		} else {
			# If this tagname was marked invalid for this one
			# story, it has no clout.  Or if it was marked for
			# all stories -- but in that case it should have
			# been caught by tag_global_clout already...
			if ($hr->{globjid} eq 'all' || $hr->{globjid} == $globjid) {
				return 0;
			}
		}
	}
	return 1;
}

1;


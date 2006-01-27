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
$minutes_run = 3;

$task{$me}{timespec} = "0-59/$minutes_run * * * *";
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{resource_locks} = { log_slave => 1 };
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
	my $n_stories_updated = 0;
	for my $stoid (@$stoids) {
		my $tags = $tags_reader->getTagsByNameAndIdArrayref('stories', $stoid);
		my @top_5 = getTop5($tags, $userdata_cache);
		warn "no top_5 for $stoid" if !@top_5;
		$n_stories_updated += $slashdb->setStory($stoid,
			{ tags_top => join(" ", @top_5) });
	}

	# Record that we did this.
	$slashdb->setVar('tags_stories_lastscanned', $newmaxid);

	return "$n_stories_updated updated";
};

# Very crude info-summarization function that will change.

sub getTop5 {
	my($tags, $users) = @_;
	
	my %uids_unique = map { ( $_->{uid}, 1 ) } @$tags;
	my @uids = keys %uids_unique;
	$users ||= { };
	for my $uid (@uids) {
		$users->{$uid} ||= $tags_reader->getUser($uid);
	}

	my %scores = ( );
	for my $tag (@$tags) {
#use Data::Dumper; print STDERR "tag $tag->{tagname}: " . Dumper($tag);
		# Very crude weighting algorithm that will change.
		my $user = $users->{$tag->{uid}};
#print STDERR "user $tag->{uid}: " . Dumper($user);
		my $tagname = $tag->{tagname};
		$scores{$tagname} ||= 0;
		$scores{$tagname} += $user->{karma} >= -3 ? log($user->{karma}+10) : 0;
		$scores{$tagname} += 5 if $user->{seclev} > 1;
	}

	my @top = sort {
		$scores{$b} <=> $scores{$a}
		||
		$a cmp $b
	} keys %scores;

	$#top = 4 if $#top > 4;
	return @top;
}

1;


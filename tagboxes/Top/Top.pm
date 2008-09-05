#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Tagbox::Top;

=head1 NAME

Slash::Tagbox::Top - update the top n tags on a globj

=head1 SYNOPSIS

	my $tagbox_tcu = getObject("Slash::Tagbox::Top");
	my $feederlog_ar = $tagbox_tcu->feed_newtags($users_ar);
	$tagbox_tcu->run($affected_globjid);

=cut

use strict;

use Slash;

our $VERSION = $Slash::Constants::VERSION;

use base 'Slash::Tagbox';

sub init_tagfilters {
	my($self) = @_;
	$self->{filter_activeonly} = 1;
	$self->{filter_publiconly} = 1;
}

sub get_affected_type	{ 'globj' }
sub get_clid		{ 'describe' }
sub get_userchanges_regex { qr{^tag_clout$} }

sub feed_newtags_process {
	my($self, $tags_ar) = @_;
	my $constants = getCurrentStatic();

	my $ret_ar = [ ];
	for my $tag_hr (@$tags_ar) {
		# affected_id and importance work the same whether this is
		# "really" newtags or deactivatedtags.
		my $days_old = (time - $tag_hr->{created_at_ut}) / 86400;
		my $importance =  $days_old <  1	? 1
				: $days_old < 14	? 1.1**-$days_old
				: 1.1**-14;
		my $ret_hr = {
			affected_id =>	$tag_hr->{globjid},
			importance =>	$importance,
		};
		if ($tag_hr->{tdid})	{ $ret_hr->{tdid}  = $tag_hr->{tdid}  }
		else			{ $ret_hr->{tagid} = $tag_hr->{tagid} }
		push @$ret_ar, $ret_hr;
	}

	return $ret_ar;
}

sub run_process {
	my($self, $affected_id, $tags_ar) = @_;
	my $constants = getCurrentStatic();
	my $tagsdb = getObject('Slash::Tags');
	my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });

	my($type, $target_id) = $tagsdb->getGlobjTarget($affected_id);

	# Get the list of tags applied to this object.  If we're doing
	# URL popularity, that's only the tags within the past few days.
	# For stories, it's all tags.

	my $options = { };
	if ($type eq 'urls') {
		my $days_back = $constants->{bookmark_popular_days} || 3;
		$options->{days_back} = $days_back;
	}
	$tagsdb->addCloutsToTagArrayref($tags_ar);

	# Generate the space-separated list of the top 5 scoring tags.

	# Now set the data accordingly.  For a story, set the
	# tags_top field to that list.

	# Using the total_clout calculated in addCloutsToTagArrayref(),
	# and counting opposite tags against ordinary tags, calculate
	# %scores, the hash of tagnames and their scores.  Note that
	# due to the presence of opposite tags, there may be many
	# entries in %scores with negative values.

	my %scores = ( );
	for my $tag (@$tags_ar) {
		$scores{$tag->{tagname}} += $tag->{total_clout};
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

	# Eliminate tagnames in a given list, and their opposites.
	my %nontop = ( map { ($_, 1) }
		grep { $_ }
		map { ($_, $tags_reader->getOppositeTagname($_)) }
		@{$tags_reader->getExcludedTags}
	);
	# Eliminate tagnames that are just the author's name.
	my @names = map { lc } @{ $tags_reader->getAuthorNames() };
	for my $name (@names) { $nontop{$name} = 1 }

	# Eliminate tagnames below the minimum score required, and
	# those that didn't make it to the top 5
	# XXX the "4" below (aka "top 5") is hardcoded currently, should be a var
	my $minscore1 = $constants->{tagbox_top_minscore_urls};
	my $minscore2 = $constants->{tagbox_top_minscore_stories};

	my $plugin = getCurrentStatic('plugin');
	if ($plugin->{FireHose}) {
		my $firehose = getObject('Slash::FireHose');
		my $fhid = $firehose->getFireHoseIdFromGlobjid($affected_id);
		my @top = ( );
		if ($fhid) {
			@top =  grep { $scores{$_} >= $minscore1 }
				grep { !$nontop{$_} }
				sort {
					$scores{$b} <=> $scores{$a}
					||
					$a cmp $b
				} keys %scores;
			$#top = 4 if $#top > 4;
			$firehose->setFireHose($fhid, { toptags => join(' ', @top) });
			main::tagboxLog("Top->run $affected_id with " . scalar(@$tags_ar) . " tags, setFireHose $fhid to '@top' >= $minscore1");
		}
	}

	if ($type eq 'stories') {

		my @top = grep { $scores{$_} >= $minscore2 }
			grep { !$nontop{$_} }
			sort {
				$scores{$b} <=> $scores{$a}
				||
				$a cmp $b
			} keys %scores;
		$#top = 4 if $#top > 4;
		$self->setStory($target_id, { tags_top => join(' ', @top) });
		main::tagboxLog("Top->run $affected_id with " . scalar(@$tags_ar) . " tags, setStory $target_id to '@top'");

	} elsif ($type eq 'urls') {

		# For a URL, calculate a numeric popularity score based
		# on (most of) its tags and store that in the popularity
		# field.
		#
		# (I think this code is obsolete...? - Jamie 2006/11/29)

		my %tags_pos = map { $_, 1 } split(/\|/, $constants->{tagbox_top_urls_tags_pos} || "");
		my %tags_neg = map { $_, 1 } split(/\|/, $constants->{tagbox_top_urls_tags_neg} || "");

		my $pop = 0;
		for my $tag (@$tags_ar) {
			my $tagname = $tag->{tagname};
			my $is_pos = $tags_pos{$tagname};
			my $is_neg = $tags_neg{$tagname};
			my $mult = 1;
			$mult =  1.5 if $is_pos && !$is_neg;
			$mult = -1.0 if $is_neg && !$is_pos;
			$mult =  0   if $is_pos &&  $is_neg;
			$pop += $mult * $tag->{total_clout};
		}

		$self->setUrl($target_id, { popularity => $pop });
		main::tagboxLog("Top->run $affected_id with " . scalar(@$tags_ar) . " tags, setUrl $target_id to pop=$pop");

	}

}

1;


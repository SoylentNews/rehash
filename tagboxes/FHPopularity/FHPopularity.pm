#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

# This tagbox is outdated, superceded by FireHoseScores

package Slash::Tagbox::FHPopularity;

=head1 NAME

Slash::Tagbox::FHPopularity - keep track of popularity of firehose entries

=head1 SYNOPSIS

	my $tagbox_tcu = getObject("Slash::Tagbox::FHPopularity");
	my $feederlog_ar = $tagbox_tcu->feed_newtags($users_ar);
	$tagbox_tcu->run($affected_globjid);

=cut

use strict;

use Slash;

our $VERSION = $Slash::Constants::VERSION;

use base 'Slash::Tagbox';

sub init {
	my($self) = @_;
	$self->SUPER::init();
	my $tagsdb = getObject('Slash::Tags');
	$self->{maybeid} = $tagsdb->getTagnameidCreate('maybe');
        my $admins = $self->getAdmins();
	$self->{admins} = {
		map { ($_, 1) }
		grep { $tagsdb->getUser($_, 'seclev') >= 100 }
		keys %$admins
	};
}

sub get_affected_type	{ 'globj' }
sub get_clid		{ 'vote' }

sub init_tagfilters {
	my($self) = @_;

	$self->{filter_activeonly}	= 1;
	$self->{filter_firehoseonly}	= 1;
	$self->{filter_tagnameid}	= [ @{$self}{qw( nodid nixid maybeid )} ];
}

sub feed_newtags_process {
	my($self, $tags_ar) = @_;
	my $constants = getCurrentStatic();

	my $ret_ar = [ ];
	for my $tag_hr (@$tags_ar) {
		my $ret_hr = {
			affected_id =>	$tag_hr->{globjid},
			importance =>	1,
		};
		if ($tag_hr->{tdid})	{ $ret_hr->{tdid}  = $tag_hr->{tdid}  }
		else			{ $ret_hr->{tagid} = $tag_hr->{tagid} }
		push @$ret_ar, $ret_hr;
	}

	return $ret_ar;
}

sub run {
	my($self, $affected_id, $tags_ar, $options) = @_;
	my $constants = getCurrentStatic();
	my $tagsdb = getObject('Slash::Tags');
	my $tagboxdb = getObject('Slash::Tagbox');
	my $firehose = getObject('Slash::FireHose');

	# All firehose entries start out with popularity 1.
	my $popularity = 1;

	# Some target types gain popularity.
	my($type, $target_id) = $tagsdb->getGlobjTarget($affected_id);
	my $target_id_q = $self->sqlQuote($target_id);

	my($color_level, $extra_pop) = (0, 0);
	if ($type eq "submissions") {
		$color_level = 5;
	} elsif ($type eq "journals") {
		my $journal = getObject("Slash::Journal");
		my $j = $journal->get($target_id);
		$color_level = $j->{promotetype} && $j->{promotetype} eq 'publicize'
			? 5  # requested to be publicized
			: 6; # not requested
	} elsif ($type eq 'urls') {
		$extra_pop = $self->sqlCount('bookmarks', "url_id=$target_id_q") || 0;
		$color_level = $self->sqlCount("firehose", "type='feed' AND url_id=$target_id")
			? 6  # feed
			: 7; # nonfeed
	} elsif ($type eq "stories") {
		my $story = $self->getStory($target_id);
		my $str_hr = $story->{story_topics_rendered};
		$color_level = 3;
		for my $nexus_tid (keys %$str_hr) {
			my $this_color_level = 999;
			my $param = $self->getTopicParam($nexus_tid, 'colorlevel') || undef;
			if (defined $param) {
				# Stories in this nexus get this specific color level.
				$this_color_level = $param;
			} else {
				# Stories in any nexus without a colorlevel specifically
				# defined in topic_param get a color level of 2.
				$this_color_level = 2;
			}
			# Stories on the mainpage get a color level of 1.
			$this_color_level = 1 if $nexus_tid == $constants->{mainpage_nexus_tid};
			# This firehose entry gets the minimum color level of
			# all its nexuses.
			$color_level = $this_color_level if $this_color_level < $color_level;
		}
	} elsif ($type eq "comments") {
		my $comment = $self->getComment($target_id);
		my $score = constrain_score($comment->{points} + $comment->{tweak});
		   if ($score >= 3) {   $color_level = 4 }
		elsif ($score >= 2) {   $color_level = 5 }
		elsif ($score >= 1) {   $color_level = 6 }
		else {                  $color_level = 7 }
	}
	$popularity = $firehose->getEntryPopularityForColorLevel($color_level) + $extra_pop;

	# Add up nods and nixes.
	# XXX make an option?
	$tagsdb->addCloutsToTagArrayref($tags_ar, 'vote');

	my($n_admin_maybes, $n_admin_nixes, $maybe_pop_delta) = (0, 0, 0);
	for my $tag_hr (@$tags_ar) {
		next if $options->{starting_only};
		my $sign = 0;
		$sign =  1 if $tag_hr->{tagnameid} == $self->{nodid} && !$options->{downvote_only};
		$sign = -1 if $tag_hr->{tagnameid} == $self->{nixid} && !$options->{upvote_only};
		next unless $sign;
		my $is_admin = $self->{admins}{ $tag_hr->{uid} } || 0;
		my $extra_pop = $tag_hr->{total_clout} * $sign;
		if ($is_admin && $sign == 1) {
			# If this admin nod comes with a 'maybe', don't change
			# popularity yet;  save it up and wait to see if any
			# admins end up 'nix'ing.
			if (grep {
				     $_->{tagnameid} == $self->{maybeid}
				&&   $_->{uid}       == $tag_hr->{uid}
				&&   $_->{globjid}   == $tag_hr->{globjid}
			} @$tags_ar) {
				++$n_admin_maybes;
				$maybe_pop_delta += $extra_pop;
				$extra_pop = 0;
			}
		} elsif ($is_admin && $sign == -1) {
			++$n_admin_nixes;
		}
		$popularity += $extra_pop;
	}
	if ($n_admin_maybes > 0) {
		if ($n_admin_nixes) {
			# If any admin nixes, then all the admin nod+maybes are
			# ignored.  The nixes have already been counted normally.
		} else {
			# No admin nixes, so the maybes boost editor popularity by
			# some fraction of the usual amount.
			my $frac = $constants->{tagbox_fhpopularity_maybefrac} || 1.0;
			$popularity += $maybe_pop_delta * $frac;
		}
	}

	# Set the corresponding firehose row to have this popularity.
	my $affected_id_q = $self->sqlQuote($affected_id);
	my $fhid = $self->sqlSelect('id', 'firehose', "globjid = $affected_id_q");
	my $firehose_db = getObject('Slash::FireHose');
	warn "Slash::Tagbox::FHPopularity->run bad data, fhid='$fhid' db='$firehose_db'" if !$fhid || !$firehose_db;
	if ($options->{return_only}) {
		return $popularity;
	}
	$self->info_log('setting %d (%d) to %f', $fhid, $affected_id, $popularity);
	$firehose_db->setFireHose($fhid, { popularity => $popularity });
}

1;


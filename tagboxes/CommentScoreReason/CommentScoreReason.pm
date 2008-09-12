#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

# Requires TagModeration plugin (not (just) Moderation)

# XXX add comments gtid as nosy

package Slash::Tagbox::CommentScoreReason;

=head1 NAME

Slash::Tagbox::CommentScoreReason - track comment score and reason

=head1 SYNOPSIS

	my $tagbox_tcu = getObject("Slash::Tagbox::CommentScoreReason");
	my $feederlog_ar = $tagbox_tcu->feed_newtags($users_ar);
	$tagbox_tcu->run($affected_globjid);

=cut

use strict;

use Digest::MD5 'md5_hex';

use Slash;

our $VERSION = $Slash::Constants::VERSION;

use base 'Slash::Tagbox';

sub isInstalled {
	my($self) = @_;
	my $constants = getCurrentStatic();
	return 0 if ! $constants->{plugin}{TagModeration};
	return $self->SUPER::isInstalled();
}

sub init {
	my($self) = @_;

	return 0 if ! $self->SUPER::init();

	# Initialize reason-related fields:
	#
	# $self->{reasons}{$id} is a hashref of the modreasons row with
	# that id, for all reasons including Normal.
	# $self->{reason_ids} is an arrayref of only the reasons with
	# a nonzero val (i.e. excluding Normal).
	# $self->{reason_tagnameid}{$id} is a hashref of the modreasons
	# row with that _tagnameid_, for nonzero vals.

	my $tagsdb = getObject('Slash::Tags');
	my $moddb = getObject('Slash::TagModeration');
	$self->{reasons} = $moddb->getReasons();
	$self->{reason_tagnameid} = { };
	$self->{reason_ids} = [
		grep { $self->{reasons}{$_}{val} != 0 }
		keys %{$self->{reasons}}
	];
	for my $id (@{$self->{reason_ids}}) {
		my $name = lc $self->{reasons}{$id}{name};
		my $tagnameid = $tagsdb->getTagnameidCreate($name);
		$self->{reason_tagnameid}{$tagnameid} = $self->{reasons}{$id};
	}

	# Initialize $self->{metamod} and {metanix}.

	for my $tagname (qw( metanod metanix )) {
		my $tagnameid = $tagsdb->getTagnameidCreate($tagname);
		$self->{"${tagname}id"} = $tagnameid;
	}

	1;
}

sub get_affected_type	{ 'globj' }
sub get_clid		{ 'moderate' }

	# CommentScoreReason wants to know about each comment globj as
	# soon as it is created, not waiting until the first tag is
	# applied to it.
sub get_nosy_gtids	{ 'comments' }

sub init_tagfilters {
	my($self) = @_;

	# CommentScoreReason only cares about active tags.

	$self->{filter_activeonly} = 1;

	# CommentScoreReason only cares about tags on comments.

	$self->{filter_gtid} = $self->getGlobjTypes()->{comments};

	# CommentScoreReason only cares about tagnames that are
	# (non-0-val) moderation reasons, plus nod, nix,
	# metanod and metanix.

	$self->{filter_tagnameid} = [ ];
	for my $tagnameid (keys %{ $self->{reason_tagnameid} }) {
		push @{ $self->{filter_tagnameid} }, $tagnameid;
	}
	for my $tagname (qw( nod nix metanod metanix )) {
		push @{ $self->{filter_tagnameid} }, $self->{"${tagname}id"};
	}

}

sub run_process {
	my($self, $affected_id, $tags_ar) = @_;
	my $constants = getCurrentStatic();
	my $tagsdb = getObject('Slash::Tags');
	my $tagboxdb = getObject('Slash::Tagbox');

	# Sanity check.

	my($type, $cid) = $self->getGlobjTarget($affected_id);
	if ($type ne 'comments') {
		my $comments_gtid = $self->getGlobjTypes()->{comments};
		$self->info_log("ERROR - run invoked for non-comment globj %d, type='%s' comments_gtid=%d",
			$affected_id, $type, $comments_gtid);
		return;
	}

	my($keep_karma_bonus, $karma_bonus_downmods_left) = (1, $constants->{mod_karma_bonus_max_downmods});
	my $current_reason_mode = 0;
	my $base_neediness = $constants->{tagbox_csr_baseneediness} || 60;
	my $neediness = $base_neediness;

	# First scan: neediness (comments.f3).
	my($up_rnf, $down_rnf) = (0, 0);
	for my $tag (@$tags_ar) {
		# If this was a moderation _or_ a nod/nix (indicating dis/agreement),
		# neediness changes.  If this was done by an admin, neediness
		# changes a lot.
		my $tagnameid = $tag->{tagnameid};
		my $reason = $self->{reason_tagnameid}{$tagnameid};
		my $dir = 0;
		if ($reason && $reason->{val} > 0
			|| $tagnameid == $self->{nodid} || $tagnameid == $self->{metanodid}) {
			$dir = 1;
		} elsif ($reason && $reason->{val} < 0
			|| $tagnameid == $self->{nixid} || $tagnameid == $self->{metanixid}) {
			$dir = -1;
		}
		if (!$dir) {
			$self->info_log("ERROR - tagid=$tag->{tagid} has no dir");
			next;
		}
		my $mod_user = $self->getUser($tag->{uid});
		my $net_fairs = $mod_user->{up_fair} + $mod_user->{down_fair}
			- ($mod_user->{up_unfair} + $mod_user->{down_unfair});
		my $root_net_fairs = ($net_fairs <= 1) ? 1 : ($net_fairs ** 0.5);
		if ($dir > 0) { $up_rnf += $root_net_fairs }
		else { $down_rnf += $root_net_fairs }
		$neediness -= 1000 if $mod_user->{seclev} > 1;
	}
	$neediness -= abs($up_rnf - $down_rnf);
	# Scale neediness to match the firehose color range.
	my $top_entry_score = 290;
	my $firehose = getObject('Slash::FireHose');
	if ($firehose) {
		$top_entry_score = $firehose->getEntryPopularityForColorLevel(1);
	}
	$neediness *= $top_entry_score/$base_neediness;
	# If we are only doing a certain percentage of neediness here,
	# this would be the place to hash the comment cid with salt and
	# drop its score to -50 unless it randomly qualified.
	# Minimum neediness is -50.
	$neediness = -50 if $neediness < -50;

	# Second scan: overall reason (comments.f2), and traditional
	# comment score (comments.f1).
	my $mod_score_sum = 0;
	my $moddb = getObject('Slash::TagModeration');
	my $reasons = $moddb->getReasons();
	my $allreasons_hr = {( %{$reasons} )};
	for my $id (keys %$allreasons_hr) {
		$allreasons_hr->{$id} = { reason => $id, c => 0 };
	}
	for my $tag (@$tags_ar) {
		# Currently, only actual moderations (not nod/nixes) change a
		# comment's score (and reason).  Only continue processing if
		# this is an actual moderation.
		my $tagnameid = $tag->{tagnameid};
		my $reason = $self->{reason_tagnameid}{$tagnameid};
		next unless $reason;
		if ($reason->{val} < 0) {
			$keep_karma_bonus = 0 if --$karma_bonus_downmods_left < 0;
		}
		$mod_score_sum += $reason->{val};
		$allreasons_hr->{$reason->{id}}{c}++;
		$current_reason_mode = $moddb->getCommentMostCommonReason($cid,
			$allreasons_hr, $reason->{id}, $current_reason_mode);
	}

	my($points_orig, $karma_bonus) = $self->sqlSelect(
		'pointsorig, karma_bonus', 'comments', "cid='$cid'");

	my $new_score = $points_orig + $mod_score_sum;
	my $new_karma_bonus = ($karma_bonus eq 'yes' && $keep_karma_bonus) ? 1 : 0;

	$self->info_log("cid %d to score: %d, %s kb %d->%d, neediness %.1f",
		$cid, $new_score, $reasons->{$current_reason_mode}{name}, ($karma_bonus eq 'yes' ? 1 : 0), $new_karma_bonus, $neediness);

	if ($firehose) {
		# If it's already in the hose, don't try to re-create it --
		# that may cause unnecessary score recalculations.
		my $fhid = $firehose->getFireHoseIdFromGlobjid($affected_id);
		if (!$fhid) {
			$fhid = $self->addCommentToHoseIfAppropriate($firehose,
				$affected_id, $cid, $neediness, $new_score);
		}
		$firehose->setFireHose($fhid, { neediness => $neediness }) if $fhid;
	}

	$self->sqlUpdate('comments', {
			f1 =>	$new_score,
			f2 =>	$current_reason_mode,
			f3 =>	$neediness,
		}, "cid='$cid'");
}

# XXX hex_percent should be a library function, it's used by FHEditorPop too

sub addCommentToHoseIfAppropriate {
	my($self, $firehose, $globjid, $cid, $neediness, $score) = @_;
	my $constants = getCurrentStatic();

	my $fhid = 0;

	# If neediness exceeds a threshold, the comment has a chance of appearing.
	my $min = $constants->{tagbox_csr_minneediness} || 138;
	return 0 if $neediness < $min;

	# Hash its cid;  if the last 4 hex digits interpreted as a fraction are
	# within the range determined, add it to the hose.
	my $percent = $constants->{tagbox_csr_needinesspercent} || 5;
	my $hex_percent = int(hex(substr(md5_hex($cid), -4)) * 100 / 65536);
	return 0 if $hex_percent >= $percent;

	$fhid = $firehose->createItemFromComment($cid);

	return $fhid;
}

1;


#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

# Requires TagModeration plugin (not (just) Moderation)

package Slash::Tagbox::DiscussionScore;

=head1 NAME

Slash::Tagbox::DiscussionScore - track comment scores within discussions

=head1 SYNOPSIS

	my $tagbox_tcu = getObject("Slash::Tagbox::DiscussionScore");
	my $feederlog_ar = $tagbox_tcu->feed_newtags($users_ar);
	$tagbox_tcu->run($affected_globjid);

=cut

use strict;

use Slash;

our $VERSION = $Slash::Constants::VERSION;

use base 'Slash::Tagbox';

sub isInstalled {
	my($self) = @_;
	return 0; # XXX not functional yet
	my $constants = getCurrentStatic();
	return 0 if ! $constants->{plugin}{TagModeration};
	return $self->SUPER::isInstalled();
}

sub init {
	my($self) = @_;

	$self->SUPER::init() if $self->can('SUPER::init');

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

sub get_affected_type   { 'globj' }
sub get_clid            { 'moderate' }

	# DiscussionScore wants to know about each comment globj as
	# soon as it is created, not waiting until the first tag is
	# applied to it.
sub get_nosy_gtids      { 'comments' }

sub init_tagfilters {
	my($self) = @_;

	# DiscussionScore only cares about active tags.

	$self->{filter_activeonly} = 1;

	# DiscussionScore only cares about tags on comments.

	$self->{filter_gtid} = $self->getGlobjTypes()->{comments};

	# DiscussionScore only cares about tagnames that are
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

# For now (and the near future) all users' moderation clouts are '1',
# so this method no longer does anything that the superclass's doesn't.

#sub feed_newtags {
#	my($self, $tags_ar) = @_;
#	my $constants = getCurrentStatic();
#
#	my $user_cache = { };
#
#	my $ret_ar = [ ];
#	for my $tag_hr (@$tags_ar) {
#		# This tag was applied to a comment.  Get the globjid of the
#		# discussion of that comment.
#		my $cidglobjid = $tag_hr->{globjid};
#		my $discglobjid = $cidglobjid_to_discglobjid_hr->{ $cidglobjid };
#		next unless $discglobjid;
#
#		# Find the moderation clout of the tagging user.
#		my $uid = $tag_hr->{uid};
#		if (!$user_cache->{$uid}) {
#			$user_cache->{$uid} = $self->getUser($uid);
#		}
#		my $user = $user_cache->{$uid};
#
#		my $ret_hr = {
#			affected_id =>	$discglobjid,
#			importance =>	$user->{clout}{moderation},
#		};
#		# We identify this little chunk of importance by either
#		# tagid or tdid depending on whether the source data had
#		# the tdid field (which tells us whether feed_newtags was
#		# "really" called via feed_deactivatedtags).
#		if ($tag_hr->{tdid})	{ $ret_hr->{tdid}  = $tag_hr->{tdid}  }
#		else			{ $ret_hr->{tagid} = $tag_hr->{tagid} }
#		push @$ret_ar, $ret_hr;
#	}
#	return [ ] if !@$ret_ar;
#
#	main::tagboxLog("DiscussionScore->feed_newtags returning " . scalar(@$ret_ar));
#	return $ret_ar;
#}

sub run_process {
	my($self, $affected_id) = @_;
	my $constants = getCurrentStatic();
	my $moddb = getObject('Slash::TagModeration');

#	$self->sqlUpdate('comments', {
#			f4 =>	$new_serious_score,
#			f5 =>	$new_funny_score,
#		}, "cid='$cid'");
}

sub get_cidglobjid_to_discglobjid_hr {
	my($self, $globjids_ar) = @_;
	my $comments_gtid = $self->getGlobjTypes()->{comments};

	my $all_globjids_str = join(',', sort { $a <=> $b } @$globjids_ar);
	return [ ] if !$comments_gtid || !$all_globjids_str;

	# Get the list of all the comment.cid's tagged, as a map
	# from each cid to its globjid.
	my $cid_to_cidglobjid_hr = $self->sqlSelectAllKeyValue(
		'target_id, globjid',
		'globjs',
		"globjid IN ($all_globjids_str) AND gtid=$comments_gtid");
	return [ ] if !keys %$cid_to_cidglobjid_hr;
	# Convert that to a list of their discussions.
	my $cids_wanted_str = join(',', sort { $a <=> $b } keys %$cid_to_cidglobjid_hr);
	my $cid_to_discid_hr = $self->sqlSelectAllKeyValue(
		'cid, sid',
		'comments',
		"cid IN ($cids_wanted_str)");
	# Get the globjid for each discussion id, creating it if necessary..
	my $discs_wanted_ar = [ sort { $a <=> $b } values %$cid_to_discid_hr ];
	my $discid_to_discglobjid_hr = { };
	for my $discid (@$discs_wanted_ar) {
		$discid_to_discglobjid_hr->{$discid} = $self->getGlobjidCreate(
			'discussions', $discid, { reader_ok => 1 });
	}

	# Match up each cid's globjid to its discussion's globjid.
	my $cidglobjid_to_discglobjid_hr = { };
	for my $cid (keys %$cid_to_cidglobjid_hr) {
		my $cidglobjid =  $cid_to_cidglobjid_hr->{     $cid        };
		my $discid =      $cid_to_discid_hr->{         $cid        };
		my $discglobjid = $discid_to_discglobjid_hr->{ $discid     };
		$cidglobjid_to_discglobjid_hr->{$cidglobjid} = $discglobjid;
	}
	return $cid_to_cidglobjid_hr;
}

1;


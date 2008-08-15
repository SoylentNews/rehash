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
use Slash::DB;
use Slash::Utility::Environment;
use Slash::Tagbox;

use Data::Dumper;

our $VERSION = $Slash::Constants::VERSION;

use base 'Slash::Tagbox';

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

sub feed_newtags {
	my($self, $tags_ar) = @_;
	my $constants = getCurrentStatic();
	if (scalar(@$tags_ar) < 9) {
		main::tagboxLog("DiscussionScore->feed_newtags called for tags '" . join(' ', map { $_->{tagid} } @$tags_ar) . "'");
	} else {
		main::tagboxLog("DiscussionScore->feed_newtags called for " . scalar(@$tags_ar) . " tags " . $tags_ar->[0]{tagid} . " ... " . $tags_ar->[-1]{tagid});
	}
	my $tagsdb = getObject('Slash::Tags');

	# Only tags on comments matter to this tagbox.  Get the mapping from
	# each comment's globjid to its discussion's globjid.
	my $cidglobjid_to_discglobjid_hr = $self->get_cidglobjid_to_discglobjid_hr([
		map { $_->{globjid} } @$tags_ar
	]);

	my $user_cache = { };

	my $ret_ar = [ ];
	for my $tag_hr (@$tags_ar) {
		# This tag was applied to a comment.  Get the globjid of the
		# discussion of that comment.
		my $cidglobjid = $tag_hr->{globjid};
		my $discglobjid = $cidglobjid_to_discglobjid_hr->{ $cidglobjid };
		next unless $discglobjid;

		# Find the moderation clout of the tagging user.
		my $uid = $tag_hr->{uid};
		if (!$user_cache->{$uid}) {
			$user_cache->{$uid} = $self->getUser($uid);
		}
		my $user = $user_cache->{$uid};

		my $ret_hr = {
			affected_id =>	$discglobjid,
			importance =>	$user->{clout}{moderation},
		};
		# We identify this little chunk of importance by either
		# tagid or tdid depending on whether the source data had
		# the tdid field (which tells us whether feed_newtags was
		# "really" called via feed_deactivatedtags).
		if ($tag_hr->{tdid})	{ $ret_hr->{tdid}  = $tag_hr->{tdid}  }
		else			{ $ret_hr->{tagid} = $tag_hr->{tagid} }
		push @$ret_ar, $ret_hr;
	}
	return [ ] if !@$ret_ar;

	main::tagboxLog("DiscussionScore->feed_newtags returning " . scalar(@$ret_ar));
	return $ret_ar;
}

sub feed_deactivatedtags {
	my($self, $tags_ar) = @_;
	main::tagboxLog("DiscussionScore->feed_deactivatedtags called: tags_ar='" . join(' ', map { $_->{tagid} } @$tags_ar) .  "'");
	my $ret_ar = $self->feed_newtags($tags_ar);
	main::tagboxLog("DiscussionScore->feed_deactivatedtags returning " . scalar(@$ret_ar));
	return $ret_ar;
}

sub feed_userchanges {
	my($self, $users_ar) = @_;

	# XXX Fix this to take user moderation clout changes into account.

	return [ ];
}

sub run {
	my($self, $affected_id) = @_;
	my $constants = getCurrentStatic();
	my $moddb = getObject('Slash::TagModeration');

#	$self->sqlUpdate('comments', {
#			f4 =>	$new_serious_score,
#			f5 =>	$new_funny_score,
#		}, "cid='$cid'");
}

1;


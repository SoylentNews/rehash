#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

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
use Slash::DB;
use Slash::Utility::Environment;
use Slash::Tagbox;

use Data::Dumper;

use vars qw( $VERSION );
$VERSION = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

use base 'Slash::DB::Utility';	# first for object init stuff, but really
				# needs to be second!  figure it out. -- pudge
use base 'Slash::DB::MySQL';

sub new {
	my($class, $user) = @_;

	my $plugin = getCurrentStatic('plugin');
	return undef if !$plugin->{Tags} || !$plugin->{FireHose};
	my($tagbox_name) = $class =~ /(\w+)$/;
	my $tagbox = getCurrentStatic('tagbox');
	return undef if !$tagbox->{$tagbox_name};

	# Note that getTagboxes() would call back to this new() function
	# if the tagbox objects have not yet been created -- but the
	# no_objects option prevents that.  See getTagboxes() for details.
	my %self_hash = %{ getObject('Slash::Tagbox')->getTagboxes($tagbox_name, undef, { no_objects => 1 }) };
	my $self = \%self_hash;
	return undef if !$self || !keys %$self;

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect();

	return $self;
}

sub feed_newtags {
	my($self, $tags_ar) = @_;
	my $constants = getCurrentStatic();
	if (scalar(@$tags_ar) < 9) {
		main::tagboxLog("FHPopularity->feed_newtags called for tags '" . join(' ', map { $_->{tagid} } @$tags_ar) . "'");
	} else {
		main::tagboxLog("FHPopularity->feed_newtags called for " . scalar(@$tags_ar) . " tags " . $tags_ar->[0]{tagid} . " ... " . $tags_ar->[-1]{tagid});
	}
	my $tagsdb = getObject('Slash::Tags');

	# The algorithm of the importance of tags to this tagbox is simple.
	# 'nod' and 'nix' are important.  Other tags are not.
	my $upvoteid   = $tagsdb->getTagnameidCreate($constants->{tags_upvote_tagname}   || 'nod');
	my $downvoteid = $tagsdb->getTagnameidCreate($constants->{tags_downvote_tagname} || 'nix');

	my $ret_ar = [ ];
	for my $tag_hr (@$tags_ar) {
		next unless $tag_hr->{tagnameid} == $upvoteid || $tag_hr->{tagnameid} == $downvoteid;
		my $ret_hr = {
			affected_id =>	$tag_hr->{globjid},
			importance =>	1,
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

	# Tags applied to globjs that have a firehose entry associated
	# are important.  Other tags are not.
	my %globjs = ( map { $_->{affected_id}, 1 } @$ret_ar );
	my $globjs_str = join(', ', sort keys %globjs);
	my $fh_globjs_ar = $self->sqlSelectColArrayref(
		'globjid',
		'firehose',
		"globjid IN ($globjs_str)");
	return [ ] if !@$fh_globjs_ar; # if no affected globjs have firehose entries, short-circuit out
	my %fh_globjs = ( map { $_, 1 } @$fh_globjs_ar );
	$ret_ar = [ grep { $fh_globjs{ $_->{affected_id} } } @$ret_ar ];

	main::tagboxLog("FHPopularity->feed_newtags returning " . scalar(@$ret_ar));
	return $ret_ar;
}

sub feed_deactivatedtags {
	my($self, $tags_ar) = @_;
	main::tagboxLog("FHPopularity->feed_deactivatedtags called: tags_ar='" . join(' ', map { $_->{tagid} } @$tags_ar) .  "'");
	my $ret_ar = $self->feed_newtags($tags_ar);
	main::tagboxLog("FHPopularity->feed_deactivatedtags returning " . scalar(@$ret_ar));
	return $ret_ar;
}

sub feed_userchanges {
	my($self, $users_ar) = @_;
	my $constants = getCurrentStatic();
	main::tagboxLog("FHPopularity->feed_userchanges called: users_ar='" . join(' ', map { $_->{tuid} } @$users_ar) .  "'");

	# XXX need to fill this in, and check FirstMover feed_userchanges too

	return [ ];
}

sub run {
	my($self, $affected_id, $options) = @_;
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
	}
	$popularity = $firehose->getEntryPopularityForColorLevel($color_level) + $extra_pop;

	# Add up nods and nixes.
	my $upvoteid   = $tagsdb->getTagnameidCreate($constants->{tags_upvote_tagname}   || 'nod');
	my $downvoteid = $tagsdb->getTagnameidCreate($constants->{tags_downvote_tagname} || 'nix');
	my $tags_ar = $tagboxdb->getTagboxTags($self->{tbid}, $affected_id, 0, $options);
	$tagsdb->addCloutsToTagArrayref($tags_ar);
	for my $tag_hr (@$tags_ar) {
		next if $options->{starting_only};
		my $sign = 0;
		$sign =  1 if $tag_hr->{tagnameid} == $upvoteid   && !$options->{downvote_only};
		$sign = -1 if $tag_hr->{tagnameid} == $downvoteid && !$options->{upvote_only};
		next unless $sign;
		$popularity += $tag_hr->{total_clout} * $sign;
	}

	# Set the corresponding firehose row to have this popularity.
	my $affected_id_q = $self->sqlQuote($affected_id);
	my $fhid = $self->sqlSelect('id', 'firehose', "globjid = $affected_id_q");
	my $firehose_db = getObject('Slash::FireHose');
	warn "Slash::Tagbox::FHPopularity->run bad data, fhid='$fhid' db='$firehose_db'" if !$fhid || !$firehose_db;
	if ($options->{return_only}) {
		return $popularity;
	}
	main::tagboxLog("FHPopularity->run setting $fhid ($affected_id) to $popularity");
	$firehose_db->setFireHose($fhid, { popularity => $popularity });
}

1;


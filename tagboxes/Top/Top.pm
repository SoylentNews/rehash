#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

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
	return undef if !$plugin->{Tags};
	my($tagbox_name) = $class =~ /(\w+)$/;
	# (this code is for once Install.pm actually installs tagboxes and getSlashConf loads this constant)
	# my $tagbox = getCurrentStatic('tagbox');
	# return undef if !$tagbox->{$tagbox_name};

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
if (scalar(@$tags_ar) < 4) {
print STDERR "Slash::Tagbox::Top->feed_newtags called for tags '" . join(' ', map { $_->{tagid} } @$tags_ar) . "'\n";
} else {
print STDERR "Slash::Tagbox::Top->feed_newtags called for " . scalar(@$tags_ar) . " tags " . $tags_ar->[0]{tagid} . " ... " . $tags_ar->[-1]{tagid} . "\n";
}

	my $ret_ar = [ ];
	for my $tag_hr (@$tags_ar) {
		# These two values are the same whether this is "really"
		# newtags or deactivatedtags.
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

	return $ret_ar;
}

sub feed_deactivatedtags {
	my($self, $tags_ar) = @_;
print STDERR "Slash::Tagbox::Top->feed_deactivatedtags called: tags_ar='" . join(' ', map { $_->{tagid} } @$tags_ar) .  "'\n";
	my $ret_ar = $self->feed_newtags($tags_ar);
print STDERR "Slash::Tagbox::Top->feed_deactivatedtags returning " . scalar(@$ret_ar) . "\n";
	return $ret_ar;
}

sub feed_userchanges {
	my($self, $users_ar) = @_;
	my $constants = getCurrentStatic();
	my $tagsdb = getObject('Slash::Tags');
print STDERR "Slash::Tagbox::Top->feed_userchanges called: users_ar='" . join(' ', map { $_->{tuid} } @$users_ar) .  "'\n";

	my %uid_change_sum = ( );
	my %globj_change = ( );
	for my $hr (@$users_ar) {
		next unless $hr->{user_key} eq 'tag_clout';
		$globj_change{$hr->{globjid}}{max_tuid} ||= $hr->{tuid};
		$globj_change{$hr->{globjid}}{max_tuid} = $hr->{tuid}
			if $globj_change{$hr->{globjid}}{max_tuid} < $hr->{tuid};
		$uid_change_sum{$hr->{uid}} ||= 0;
		$uid_change_sum{$hr->{uid}} += abs(($hr->{value_old} || 1) - $hr->{value_new});
	}
	for my $uid (keys %uid_change_sum) {
		my $tags_ar = $tagsdb->getAllTagsFromUser($uid);
		for my $tag_hr (@$tags_ar) {
			$globj_change{$tag_hr->{globj}}{sum} ||= 0;
			$globj_change{$tag_hr->{globj}}{sum} += $uid_change_sum{$uid};
		}
	}
	my $ret_ar = [ ];
	for my $globjid (sort { $a <=> $b } keys %globj_change) {
		push @$ret_ar, {
			tuid =>		$globj_change{$globjid}{max_tuid},
			affected_id =>	$globjid,
			importance =>	$globj_change{$globjid}{sum},
		};
	}

print STDERR "Slash::Tagbox::Top->feed_userchanges returning " . scalar(@$ret_ar) . "\n";
	return $ret_ar;
}

sub run {
	my($self, $affected_id) = @_;
	my $constants = getCurrentStatic();
	my $tagsdb = getObject('Slash::Tags');
	my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });
	my $tagboxdb = getObject('Slash::Tagbox');

	my($type, $target_id) = $tagsdb->getGlobjTarget($affected_id);
	return unless $type eq 'stories' || $type eq 'urls';

	# Get the list of tags applied to this object.  If we're doing
	# URL popularity, that's only the tags within the past few days.
	# For stories, it's all tags.

	my $options = { };
	if ($type eq 'urls') {
		my $days_back = $constants->{bookmark_popular_days} || 3;
		$options->{days_back} = $days_back;
	}
	my $tag_ar = $tagsdb->getTagsByGlobjid($affected_id, $options);
	$tagsdb->addCloutsToTagArrayref($tag_ar);
print STDERR "Slash::Tagbox::Top->run called for $affected_id, " . scalar(@$tag_ar) . " tags\n";

	# Now set the data accordingly.  For a story, set the
	# tags_top field to the space-separated list of the
	# top 5 scoring tags.

	if ($type eq 'stories') {

		# Using the total_clout calculated in addCloutsToTagArrayref(),
		# and counting opposite tags against ordinary tags, calculate
		# %scores, the hash of tagnames and their scores.  Note that
		# due to the presence of opposite tags, there may be many
		# entries in %scores with negative values.

		my %scores = ( );
		for my $tag (@$tag_ar) {
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

		# Eliminate tagnames below the minimum score required, and
		# those that didn't make it to the top 5
		# XXX the "5" is hardcoded currently, should be a var
		my $minscore = $constants->{"tagbox_top_minscore_stories"};
		@top = grep { $scores{$_} >= $minscore } @top;
		$#top = 4 if $#top > 4;

		$self->setStory($target_id, { tags_top => join(' ', @top) });
print STDERR "Slash::Tagbox::Top->run $affected_id with " . scalar(@$tag_ar) . " tags, setStory $target_id to '@top'\n";

	} elsif ($type eq 'urls') {

		# For a URL, calculate a numeric popularity score based
		# on (most of) its tags and store that in the popularity
		# field.

		my %tags_pos = map { $_, 1 } split(/\|/, $constants->{tagbox_top_urls_tags_pos} || "");
		my %tags_neg = map { $_, 1 } split(/\|/, $constants->{tagbox_top_urls_tags_neg} || "");

		my $pop = 0;
		for my $tag (@$tag_ar) {
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

	}

}

1;


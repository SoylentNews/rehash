#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Tagbox::RecentTags;

=head1 NAME

Slash::Tagbox::RecentTags - update the Recent Tags slashbox

=head1 SYNOPSIS

	my $tagbox_tcu = getObject("Slash::Tagbox::RecentTags");
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

	return undef if !$class->isInstalled();

	# Note that getTagboxes() would call back to this new() function
	# if the tagbox objects have not yet been created -- but the
	# no_objects option prevents that.  See getTagboxes() for details.
	my($tagbox_name) = $class =~ /(\w+)$/;
	my %self_hash = %{ getObject('Slash::Tagbox')->getTagboxes($tagbox_name, undef, { no_objects => 1 }) };
	my $self = \%self_hash;
	return undef if !$self || !keys %$self;

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect();

	return $self;
}

sub isInstalled {
	my($class) = @_;
	my $constants = getCurrentStatic();
	my($tagbox_name) = $class =~ /(\w+)$/;
	return $constants->{plugin}{Tags} && $constants->{tagbox}{$tagbox_name} || 0;
}

sub feed_newtags {
	my($self, $tags_ar) = @_;
	my $constants = getCurrentStatic();
	my $tagsdb = getObject('Slash::Tags');
	my $secondsback = $constants->{tagbox_recenttags_secondsback};
	my $exclude_tagnames = $constants->{tagbox_top_excludetagnames} || 'yes no';
	my %exclude_tagnameid = (
		map { ($tagsdb->getTagnameidCreate($_), 1) }
		split / /, $exclude_tagnames
	);
	if (scalar(@$tags_ar) < 4) {
		main::tagboxLog("RecentTags->feed_newtags called for tags '" . join(' ', map { $_->{tagid} } @$tags_ar) . "'");
	} else {
		main::tagboxLog("RecentTags->feed_newtags called for " . scalar(@$tags_ar) . " tags " . $tags_ar->[0]{tagid} . " ... " . $tags_ar->[-1]{tagid});
	}

	my $ret_ar = [ ];
	for my $tag_hr (@$tags_ar) {
		# Tags outside the window aren't important (maybe this tagbox
		# is running through a backlog)
		my $seconds_old = time - $tag_hr->{created_at_ut};
		next if $seconds_old > $secondsback;
		# Tags that the Top tagbox excludes aren't important.
		next if $exclude_tagnameid{ $tag_hr->{tagnameid} };
		# Tags on a hose item under the minslice aren't important.
		my $minslice = $constants->{tagbox_recenttags_minslice} || 4;
		my $firehosedb = getObject('Slash::FireHose', { db_type => 'reader' });
		my $firehose_id = $firehosedb->getFireHoseIdFromGlobjid($tag_hr->{globjid});
		next unless $firehose_id;
		my $firehose = $firehosedb->getFireHose($firehose_id);
		my $pop = $firehose->{popularity} || 0;
		my $minpop = $firehosedb->getMinPopularityForColorLevel($minslice);
		next if $pop < $minpop;
		# We could here reduce importance if the tag is not Descriptive
		# or has a reduced clout.  XXX
		my $importance = 1;
		my $ret_hr = {
			affected_id =>	$tag_hr->{globjid},
			importance =>	$importance,
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
	main::tagboxLog("RecentTags->feed_deactivatedtags called: tags_ar='" . join(' ', map { $_->{tagid} } @$tags_ar) .  "'");
	my $ret_ar = $self->feed_newtags($tags_ar);
	main::tagboxLog("RecentTags->feed_deactivatedtags returning " . scalar(@$ret_ar));
	return $ret_ar;
}

sub feed_userchanges {
	my($self, $users_ar) = @_;
	my $constants = getCurrentStatic();
	my $tagsdb = getObject('Slash::Tags');
	main::tagboxLog("RecentTags->feed_userchanges called (oddly); returning blank");
	return [ ];
}

sub run {
	my($self, $affected_id) = @_;
	my $constants = getCurrentStatic();
	my $tagsdb = getObject('Slash::Tags');
	my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });

	my $exclude_tagnames = $constants->{tagbox_top_excludetagnames} || 'yes no';
	my %exclude_tagname = (
		map { ($_, 1) }
		split / /, $exclude_tagnames
	);
	my $num_wanted = $constants->{tagbox_recenttags_num} || 5;
	my $max_num = $num_wanted + scalar(keys %exclude_tagname);
	my $tagnames_ar = $tags_reader->listTagnamesActive({ max_num => $max_num, seconds => 3600 });

	# Strip out tagnames we want to exclude.
	@$tagnames_ar = grep { !$exclude_tagname{$_} } @$tagnames_ar;

	# Max of 5 or whatever.
	$#$tagnames_ar = 4 if scalar(@$tagnames_ar) > $num_wanted;

	if (scalar(@$tagnames_ar) < $num_wanted) {
		# If we don't get as many as we wanted, leave up
		# whatever was there before.
		main::tagboxLog("RecentTags->run only " . scalar(@$tagnames_ar) . " so not changing");
		return;
	}
	# XXX this should be a template
	my $block = '<ul>';
	for my $tagname (@$tagnames_ar) {
		$block .= qq{<li><a href="/tags/$tagname">$tagname</a></li>};
	}
	$block .= '</ul>';
	main::tagboxLog("RecentTags->run setting Recent Tags to '@$tagnames_ar' (" . length($block) . " chars)");
	setblock('activetags', $block);
}

1;


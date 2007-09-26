#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Tagbox::FHActivity;

=head1 NAME

Slash::Tagbox::FHActivity - keep track of activity of firehose entries

=head1 SYNOPSIS

	my $tagbox_tcu = getObject("Slash::Tagbox::FHActivity");
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
		main::tagboxLog("FHActivity->feed_newtags called for tags '" . join(' ', map { $_->{tagid} } @$tags_ar) . "'");
	} else {
		main::tagboxLog("FHActivity->feed_newtags called for " . scalar(@$tags_ar) . " tags " . $tags_ar->[0]{tagid} . " ... " . $tags_ar->[-1]{tagid});
	}
	my $tagsdb = getObject('Slash::Tags');

	# The algorithm of the importance of tags to this tagbox is simple.
	# Each unique user-globjid pair adds 1 to importance of that globjid.

	my $ret_ar = [ ];
	my %seen = ( );
	for my $tag_hr (@$tags_ar) {
		next if $seen{$tag_hr->{uid}}{$tag_hr->{globjid}};
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
		$seen{$tag_hr->{uid}}{$tag_hr->{globjid}} = 1;
	}
	return [ ] if !@$ret_ar;

	# Tags applied to globjs that have a firehose entry associated
	# are important.  Other tags are not.
	my %globjs = ( map { ($_->{affected_id}, 1) } @$ret_ar );
	my $globjs_str = join(', ', sort keys %globjs);
	my $fh_globjs_ar = $self->sqlSelectColArrayref(
		'globjid',
		'firehose',
		"globjid IN ($globjs_str)");
	return [ ] if !@$fh_globjs_ar; # if no affected globjs have firehose entries, short-circuit out
	my %fh_globjs = ( map { ($_, 1) } @$fh_globjs_ar );
	$ret_ar = [ grep { $fh_globjs{ $_->{affected_id} } } @$ret_ar ];

	main::tagboxLog("FHActivity->feed_newtags returning " . scalar(@$ret_ar));
	return $ret_ar;
}

sub feed_deactivatedtags {
	my($self, $tags_ar) = @_;
	main::tagboxLog("FHActivity->feed_deactivatedtags called: tags_ar='" . join(' ', map { $_->{tagid} } @$tags_ar) .  "'");
	my $ret_ar = $self->feed_newtags($tags_ar);
	main::tagboxLog("FHActivity->feed_deactivatedtags returning " . scalar(@$ret_ar));
	return $ret_ar;
}

sub feed_userchanges {
	my($self, $users_ar) = @_;
	my $constants = getCurrentStatic();
	main::tagboxLog("FHActivity->feed_userchanges called: users_ar='" . join(' ', map { $_->{tuid} } @$users_ar) .  "'");

	# XXX need to fill this in, and check FirstMover feed_userchanges too

	return [ ];
}

sub run {
	my($self, $affected_id) = @_;
	my $constants = getCurrentStatic();
	my $tagsdb = getObject('Slash::Tags');
	my $tagboxdb = getObject('Slash::Tagbox');

	# All firehose entries start out with activity 1.
	my $activity = 1;

	# Some target types gain activity.
	my($type, $target_id) = $tagsdb->getGlobjTarget($affected_id);
	my $target_id_q = $self->sqlQuote($target_id);
	if ($type eq 'journals') {
		# One user journaled this which basically counts as good as
		# a bookmark, so that gets it an extra point.
		$activity++;
	} elsif ($type eq 'urls') {
		# One or more users bookmarked this.  Find out how many and
		# give it that many extra points.
		my $count = $self->sqlCount('bookmarks', "url_id=$target_id_q");
		$activity += $count;
	}
	# There's also 'feed' and 'submission' which don't get additions.

	# Add up unique users who have tagged this globjid.
	my $tags_ar = $tagboxdb->getTagboxTags($self->{tbid}, $affected_id, 0);
	$tagsdb->addCloutsToTagArrayref($tags_ar, 'vote');
	my %user_clout = ( map { ($_->{uid}, $_->{user_clout}) } @$tags_ar );
	for my $uid (keys %user_clout) {
		$activity += $user_clout{$uid};
	}

	# Set the corresponding firehose row to have this activity.
	my $affected_id_q = $self->sqlQuote($affected_id);
	my $fhid = $self->sqlSelect('id', 'firehose', "globjid = $affected_id_q");
	my $firehose_db = getObject('Slash::FireHose');
	warn "Slash::Tagbox::FHActivity->run bad data, fhid='$fhid' db='$firehose_db'" if !$fhid || !$firehose_db;
	main::tagboxLog("FHActivity->run setting $fhid ($affected_id) to $activity");
	$firehose_db->setFireHose($fhid, { activity => $activity });
}

1;


#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Tagbox::TagCountUser;

=head1 NAME

Slash::Tagbox::TagCountUser - simple tagbox to count users' active tags

=head1 SYNOPSIS

	my $tagbox_tcu = getObject("Slash::Tagbox::TagCountUser");
	my $feederlog_ar = $tagbox_tcu->feed_newtags($tags_ar);
	$tagbox_tcu->run($affected_uid);

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

	return unless if !$class->isInstalled();

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
	if (scalar(@$tags_ar) < 9) {
		main::tagboxLog("TagCountUser->feed_newtags called for tags '" . join(' ', map { $_->{tagid} } @$tags_ar) . "'");
	} else {
		main::tagboxLog("TagCountUser->feed_newtags called for " . scalar(@$tags_ar) . " tags " . $tags_ar->[0]{tagid} . " ... " . $tags_ar->[-1]{tagid});
	}
	my $ret_ar = [ ];
	for my $tag_hr (@$tags_ar) {
                # affected_id and importance work the same whether this is
		# "really" newtags or deactivatedtags.
		my $days_old = (time - $tag_hr->{created_at_ut}) / 86400;
		my $importance =  $days_old <  1	? 1
				: $days_old < 14	? 1.1**-$days_old
				: 1.1**-14;
		my $ret_hr = {
			affected_id =>  $tag_hr->{uid},
			importance =>   $importance,
		};
		# We identify this little chunk of importance by either
		# tagid or tdid depending on whether the source data had
		# the tdid field (which tells us whether feed_newtags was
		# "really" called via feed_deactivatedtags).
		if ($tag_hr->{tdid})    { $ret_hr->{tdid}  = $tag_hr->{tdid}  }
		else                    { $ret_hr->{tagid} = $tag_hr->{tagid} }
		push @$ret_ar, $ret_hr;
	}
	return $ret_ar;
}

sub feed_deactivatedtags {
	my($self, $tags_ar) = @_;
	if (scalar(@$tags_ar) < 9) {
		main::tagboxLog("TagCountUser->feed_deactivatedtags called for tags '" . join(' ', map { $_->{tdid} } @$tags_ar) . "'");
	} else {
		main::tagboxLog("TagCountUser->feed_deactivatedtags called for " . scalar(@$tags_ar) . " tags " . $tags_ar->[0]{tdid} . " ... " . $tags_ar->[-1]{tdid});
	}
	return $self->feed_newtags($tags_ar);
}

sub feed_userchanges {
	my($self, $users_ar) = @_;
	if (scalar(@$users_ar) < 9) {
		main::tagboxLog("TagCountUser->feed_userchanges called for changes '" . join(' ', map { $_->{tuid} } @$users_ar) . "'");
	} else {
		main::tagboxLog("TagCountUser->feed_userchanges called for " . scalar(@$users_ar) . " changes " . $users_ar->[0]{tuid} . " ... " . $users_ar->[-1]{tuid});
	}
	return [ ];
}

sub run {
	my($self, $affected_id) = @_;
	my $tagboxdb = getObject('Slash::Tagbox');
	my $user_tags_ar = $tagboxdb->getTagboxTags($self->{tbid}, $affected_id, 0);
	main::tagboxLog("TagCountUser->run called for $affected_id, ar count " . scalar(@$user_tags_ar));
	my $count = grep { !defined $_->{inactivated} } @$user_tags_ar;
	$self->setUser($affected_id, { tag_count => $count });
}

1;


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
if (scalar(@$tags_ar) < 9) {
print STDERR "Slash::Tagbox::TagCountUser->feed_newtags called for tags '" . join(' ', map { $_->{tagid} } @$tags_ar) . "'\n";
} else {
print STDERR "Slash::Tagbox::TagCountUser->feed_newtags called for " . scalar(@$tags_ar) . " tags " . $tags_ar->[0]{tagid} . " ... " . $tags_ar->[-1]{tagid} . "\n";
}
	my $ret_ar = [ ];
	for my $tag_hr (@$tags_ar) {
		push @$ret_ar, {
			tagid =>	$tag_hr->{tagid},
			affected_id =>	$tag_hr->{uid},
			importance =>	1,
		};
	}
	return $ret_ar;
}

sub feed_deactivatedtags {
	my($self, $tags_ar) = @_;
if (scalar(@$tags_ar) < 9) {
print STDERR "Slash::Tagbox::TagCountUser->feed_deactivatedtags called for tags '" . join(' ', map { $_->{tdid} } @$tags_ar) . "'\n";
} else {
print STDERR "Slash::Tagbox::TagCountUser->feed_deactivatedtags called for " . scalar(@$tags_ar) . " tags " . $tags_ar->[0]{tdid} . " ... " . $tags_ar->[-1]{tdid} . "\n";
}
	return $self->feed_newtags($tags_ar);
}

sub feed_userchanges {
	my($self, $users_ar) = @_;
if (scalar(@$users_ar) < 9) {
print STDERR "Slash::Tagbox::TagCountUser->feed_userchanges called for changes '" . join(' ', map { $_->{tuid} } @$users_ar) . "'\n";
} else {
print STDERR "Slash::Tagbox::TagCountUser->feed_userchanges called for " . scalar(@$users_ar) . " changes " . $users_ar->[0]{tuid} . " ... " . $users_ar->[-1]{tuid} . "\n";
}
	return [ ];
}

sub run {
	my($self, $affected_id) = @_;
	my $tagboxdb = getObject('Slash::Tagbox');
	my $user_tags_ar = $tagboxdb->getTagboxTags($self->{tbid}, $affected_id, 0);
print STDERR "Slash::Tagbox::TagCountUser->run called for $affected_id, ar count " . scalar(@$user_tags_ar) . "\n";
	my $count = grep { !defined $_->{inactivated} } @$user_tags_ar;
	$self->setUser($affected_id, { tag_count => $count });
}

1;


#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

# This goes by seclev right now but perhaps should define "editor"
# to be more about author than admin seclev.  In which case the
# getAdmins() calls should be getAuthors().

package Slash::Tagbox::FHEditorPop;

=head1 NAME

Slash::Tagbox::FHEditorPop - keep track of popularity of firehose for editors

=head1 SYNOPSIS

	my $tagbox_tcu = getObject("Slash::Tagbox::FHEditorPop");
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
print STDERR "Slash::Tagbox::FHEditorPop->feed_newtags called for tags '" . join(' ', map { $_->{tagid} } @$tags_ar) . "'\n";
} else {
print STDERR "Slash::Tagbox::FHEditorPop->feed_newtags called for " . scalar(@$tags_ar) . " tags " . $tags_ar->[0]{tagid} . " ... " . $tags_ar->[-1]{tagid} . "\n";
}
	my $tagsdb = getObject('Slash::Tags');

	# The algorithm of the importance of tags to this tagbox is simple.
	# 'nod' and 'nix', esp. from editors, are important.  Other tags are not.
	my $upvoteid   = $tagsdb->getTagnameidCreate($constants->{tags_upvote_tagname}   || 'nod');
	my $downvoteid = $tagsdb->getTagnameidCreate($constants->{tags_downvote_tagname} || 'nix');
	my $admins = $self->getAdmins();

	my $ret_ar = [ ];
	for my $tag_hr (@$tags_ar) {
		next unless $tag_hr->{tagnameid} == $upvoteid || $tag_hr->{tagnameid} == $downvoteid;
		my $seclev = exists $admins->{ $tag_hr->{uid} }
			? $admins->{ $tag_hr->{uid} }{seclev}
			: 1;
		my $ret_hr = {
			affected_id =>	$tag_hr->{globjid},
			importance =>	$seclev >= 100 ? ($constants->{tagbox_fheditorpop_edmult} || 10) : 1,
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

print STDERR "Slash::Tagbox::FHEditorPop->feed_newtags returning " . scalar(@$ret_ar) . "\n";
	return $ret_ar;
}

sub feed_deactivatedtags {
	my($self, $tags_ar) = @_;
print STDERR "Slash::Tagbox::FHEditorPop->feed_deactivatedtags called: tags_ar='" . join(' ', map { $_->{tagid} } @$tags_ar) .  "'\n";
	my $ret_ar = $self->feed_newtags($tags_ar);
print STDERR "Slash::Tagbox::FHEditorPop->feed_deactivatedtags returning " . scalar(@$ret_ar) . "\n";
	return $ret_ar;
}

sub feed_userchanges {
	my($self, $users_ar) = @_;
	my $constants = getCurrentStatic();
print STDERR "Slash::Tagbox::FHEditorPop->feed_userchanges called: users_ar='" . join(' ', map { $_->{tuid} } @$users_ar) .  "'\n";

	# XXX need to fill this in, and check FirstMover feed_userchanges too

	return [ ];
}

sub run {
	my($self, $affected_id) = @_;
	my $constants = getCurrentStatic();
	my $tagsdb = getObject('Slash::Tags');
	my $tagboxdb = getObject('Slash::Tagbox');

	# All firehose entries start out with popularity 1.
	my $popularity = 1;

	# Some target types gain popularity.
	my($type, $target_id) = $tagsdb->getGlobjTarget($affected_id);
	my $target_id_q = $self->sqlQuote($target_id);
	if ($type =~ /^(journals|submissions)$/) {
		# One user either journaled this or submitted it.  Either
		# basically counts as good as a bookmark, so that gets it
		# an extra point.
		$popularity++;
	} elsif ($type eq 'urls') {
		# One or more users bookmarked this.  Find out how many and
		# give it that many extra points.  (The bookmarks table has
		# a unique key on url_id,uid so this gets us the count of
		# distinct users and it's not a table scan.)
		# XXX Does the Tagbox plugin require the Bookmarks plugin?
		# If not, is there any way this code could be reached
		# with the bookmarks table not existing?  I don't think so
		# but should probably doublecheck.
		$popularity += $self->sqlCount('bookmarks', "url_id=$target_id_q");
	}
	# There's also 'feed' which doesn't get extra points (starts at 1).

	# Add up nods and nixes.
	my $upvoteid   = $tagsdb->getTagnameidCreate($constants->{tags_upvote_tagname}   || 'nod');
	my $downvoteid = $tagsdb->getTagnameidCreate($constants->{tags_downvote_tagname} || 'nix');
	my $admins = $self->getAdmins();
	my $tags_ar = $tagboxdb->getTagboxTags($self->{tbid}, $affected_id, 0);
	$tagsdb->addCloutsToTagArrayref($tags_ar);
	for my $tag_hr (@$tags_ar) {
		my $sign = 0;
		$sign =  1 if $tag_hr->{tagnameid} == $upvoteid;
		$sign = -1 if $tag_hr->{tagnameid} == $downvoteid;
		next unless $sign;
		my $seclev = exists $admins->{ $tag_hr->{uid} }
			? $admins->{ $tag_hr->{uid} }{seclev}
			: 1;
		my $editor_mult = $seclev >= 100 ? ($constants->{tagbox_fheditorpop_edmult} || 10) : 1;
		$popularity += $tag_hr->{total_clout} * $editor_mult * $sign;
	}

	# Set the corresponding firehose row to have this popularity.
	my $affected_id_q = $self->sqlQuote($affected_id);
	my $fhid = $self->sqlSelect('id', 'firehose', "globjid = $affected_id_q");
	my $firehose_db = getObject('Slash::FireHose');
	warn "Slash::Tagbox::FHEditorPop->run bad data, fhid='$fhid' db='$firehose_db'" if !$fhid || !$firehose_db;
print STDERR "Slash::Tagbox::FHEditorPop->run setting $fhid ($affected_id) to $popularity\n";
	$firehose_db->setFireHose($fhid, { editorpop => $popularity });
}

1;


#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

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

our $VERSION = $Slash::Constants::VERSION;

use base 'Slash::Tagbox';

sub get_affected_type	{ 'globj' }
sub get_clid		{ 'vote' }

sub init_tagfilters {
	my($self) = @_;

	$self->{filter_firehoseonly} = 1;
}

sub run_process {
	my($self, $affected_id, $tags_ar) = @_;
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
#	my $tags_ar = $tagboxdb->getTagboxTags($self->{tbid}, $affected_id, 0);
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
	$self->info_log("setting %d (%d) to %f", $fhid, $affected_id, $activity);
	$firehose_db->setFireHose($fhid, { activity => $activity });
}

1;


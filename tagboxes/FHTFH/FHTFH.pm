#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2009 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

# "Tagged for hose" is an unwieldly verb coinage, but one we've
# decided to stick with for better or worse.
#
# If a user has tagged-for-hose a globj, it means that user has
# applied a set of one or more tags to it in such a way that we
# deem that user wants that globj to appear in their own hose.
#
# There is a little bit of handwaving in that phrase "we deem,"
# and it is in this tagbox module that the handwaving is
# explicitly defined in code.

package Slash::Tagbox::FHTFH;

=head1 NAME

Slash::Tagbox::FHTFH - Track firehose items users have "tagged for hose"

=head1 SYNOPSIS

	my $tagbox_tcu = getObject("Slash::Tagbox::FHTFH");
	my $feederlog_ar = $tagbox_tcu->feed_newtags($users_ar);
	$tagbox_tcu->run($affected_globjid);

=cut

use strict;

use Slash;

our $VERSION = $Slash::Constants::VERSION;

use base 'Slash::Tagbox';

sub init {
	my($self) = @_;
	return 0 if ! $self->SUPER::init();

	my $tagsdb = getObject('Slash::Tags');

	my $tnid_pos_ar    = $tagsdb->getTagnameidsByParam('posneg',     '+');
	my $tnid_neg_ar    = $tagsdb->getTagnameidsByParam('posneg',     '-');
	my $tnid_excl_ar   = $tagsdb->getTagnameidsByParam('exclude',    '1');
	my $tnid_fhexcl_ar = $tagsdb->getTagnameidsByParam('fh_exclude', '1');

	# $self->{nodid} and {nixid} are set by Slash::Tagbox::init()

	$self->{tagnod} = {( map { ( $_, 1 ) } ( $self->{nodid} ) )};
	$self->{tagnix} = {( map { ( $_, 1 ) } ( $self->{nixid} ) )};
	$self->{tagpos} = {( map { ( $_, 1 ) } @$tnid_pos_ar      )};
	$self->{tagneg} = {( map { ( $_, 1 ) } @$tnid_neg_ar, @$tnid_excl_ar, @$tnid_fhexcl_ar )};
	for my $tnid (keys %{$self->{tagneg}}) {
		# Make sure tagnames marked negative can't be also positive.
		delete $self->{tagpos}{$tnid};
	}

	1;
}

sub init_tagfilters {
	my($self) = @_;
	$self->{filter_firehoseonly} = 1;
}

sub get_affected_type	{ 'globj' }
sub get_clid		{ 'vote' }

sub run_process {
	my($self, $affected_id, $tags_ar, $options) = @_;

	# We start by building the list of uid's who have tagged this globj,
	# and default their values to 1, meaning that they _have_
	# "tagged_for_hose" it.
	my %uids = ( map { ( $_->{uid}, 1 ) } @$tags_ar );
	my @uids = sort { $a <=> $b } keys %uids;

	for my $uid (@uids) {
		my @tnids = ( map { $_->{tagnameid} }
			grep { $_->{uid} == $uid && ! $_->{inactivated} }
			@$tags_ar );
		# We now have the list of tagnames that user $uid has applied
		# to globj $affected_id.  If this user has tagged this globj
		# for hose, we leave $uids{$uid} as 1 and continue to the
		# next user.  Otherwise we set it to 0.  We do this by
		# applying rules in order.

		# To start with, if the user has not tagged this item at all,
		# it's not in their hose.  (This could happen if they tagged
		# it previously, and have now deactivated that tag, requiring
		# this recalculation to remove it from their hose.)
		if (                           ! @tnids) { $uids{$uid} = 0; next }
		# If the user has tagged "nod", it's in their hose.
		if (grep { $self->{tagnod}{$_} } @tnids) {                  next }
		# If the user has tagged "nix", it's out.
		if (grep { $self->{tagnix}{$_} } @tnids) { $uids{$uid} = 0; next }
		# If the user has tagged anything positive, it's in.
		if (grep { $self->{tagpos}{$_} } @tnids) {                  next }
		# If the user has tagged anything negative, it's out.
		if (grep { $self->{tagneg}{$_} } @tnids) { $uids{$uid} = 0; next }
	}

	my @uids_tfh = grep { $uids{$_} } @uids;
	$self->sqlDo('START TRANSACTION') if @uids_tfh;
	$self->sqlDelete('firehose_tfh', "globjid=$affected_id");
	for my $uid (@uids_tfh) {
		$self->sqlInsert('firehose_tfh',
			{ globjid => $affected_id, uid => $uid });
	}
	$self->sqlDo('COMMIT') if @uids_tfh;
	$self->info_log("globjid %d is tagged_for_hose by %d users", $affected_id, scalar(@uids_tfh));
}

1;


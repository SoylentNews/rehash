#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Tagbox::TagnameProcess;

=head1 NAME

Slash::Tagbox::TagnameProcess - Process admin tags applied to tagnames

=head1 SYNOPSIS

	my $tagbox_tcu = getObject("Slash::Tagbox::TagnameProcess");
	my $feederlog_ar = $tagbox_tcu->feed_newtags($tags_ar);
	$tagbox_tcu->run($affected_globjid);

=cut

use strict;

use Slash::Utility;

our $VERSION = $Slash::Constants::VERSION;

use base 'Slash::Tagbox';

sub init {
	my($self) = @_;
	return 0 if ! $self->SUPER::init();
	my $constants = getCurrentStatic();

	my $tagsdb = getObject('Slash::Tags');
	$self->{descriptiveid} = $tagsdb->getTagnameidCreate('descriptive');

	1;
}

# To be clear, the tags this tagbox cares about are those applied to
# globjs which happen to be tagname items.
sub get_affected_type	{ 'globj' }

# This is basically irrelevant, I'm just picking something.
sub get_clid		{ 'describe' }

sub init_tagfilters {
	my($self) = @_;

	# Only care about active tags on firehose items.
	$self->{filter_activeonly} = 1;
	$self->{filter_firehoseonly} = 1;

	# Only care about two tags at present: "descriptive" and "nod".
	# These are the only tags that affect a tagname item.
	$self->{filter_tagnameid} = [ $self->{descriptiveid}, $self->{nodid} ];

	# Only care about tags on tagname items.
	$self->{filter_gtid} = $self->getGlobjTypes()->{tagnames};

	# Only care about tags from admins.
	my $admins = $self->getAdmins();
	$self->{filter_uid} = [ sort { $a <=> $b } keys %$admins ];
}

sub run_process {
	my($self, $affected_id, $tags_ar) = @_;

	# A kind of off-switch for this tagbox, just in case.
	my $constants = getCurrentStatic();
	return if !$constants->{tagbox_tnp_enable};

	my @params = ( );
	if (grep { $_->{tagnameid} == $self->{descriptiveid} } @$tags_ar) {
		push @params, 'descriptive';
	} elsif (grep { $_->{tagnameid} == $self->{nodid} } @$tags_ar) {
		push @params, 'admin_ok';
	}
	return unless @params;

	my($table, $id) = $self->getGlobjTarget($affected_id);
	if ($table ne 'tagnames') {
		$self->info_log("logic error, should not be asked to process $affected_id '$table'");
		return ;
	}
	my $tagsdb = getObject('Slash::Tags');
	my $tagname = $tagsdb->getTagnameDataFromId($id)->{tagname};
	if (!$tagname) {
		$self->info_log("logic error, globjid $affected_id not valid tagname");
		return ;
	}
	my $retval = $tagsdb->setTagname($id, {( map {( $_, 1 )} @params )});
	$self->info_log("set '$tagname' to '@params': $retval");
}

1;


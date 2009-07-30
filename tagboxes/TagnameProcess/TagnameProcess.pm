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
	for my $i (0..5) {
		$self->{"pound${i}id"} = $tagsdb->getTagnameidCreate("pound$i");
	}

	1;
}

# To be clear, the tags this tagbox cares about are those applied to
# globjs which happen to be tagname items.
sub get_affected_type	{ 'globj' }

# This is basically irrelevant, I'm just picking something.
sub get_clid		{ 'describe' }

sub get_nosy_gtids	{ 'tagnames' }

sub init_tagfilters {
	my($self) = @_;

	# Only care about active tags on firehose items.
	$self->{filter_activeonly} = 1;
	$self->{filter_firehoseonly} = 1;

	# Only care about, at present, "descriptive" and "nod" as positive tags,
	# "pound0" thru "pound5" as negative.
	# These are the only tags that affect a tagname item.
	$self->{filter_tagnameid} = [ $self->{descriptiveid}, $self->{nodid} ];
	for my $i (0..5) {
		push @{ $self->{filter_tagnameid} }, $self->{"pound${i}id"};
	}

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

	# Decide what to do with the tagname specified by this globjid.
	# Note that descriptive overrides admin_ok, and both override
	# any punishments.
	my $done = 0;
	my $admin_command = '';
	my $admin_command_uid = 0;
	my @params = ( );
	if (grep { $_->{tagnameid} == $self->{descriptiveid} } @$tags_ar) {
		push @params, 'descriptive';
	} elsif (grep { $_->{tagnameid} == $self->{nodid} } @$tags_ar) {
		push @params, 'admin_ok';
	} else {
		for my $i (0..5) {
			my @pounds = grep { $_->{tagnameid} == $self->{"pound{$i}id"} } @$tags_ar;
			if (@pounds) {
				if ($i == 0) {
					$admin_command = '$_';
				} else {
					$admin_command = '$' . ('#' x $i);
				}
				$admin_command_uid = $pounds[0]{uid};
			}
		}
		$done = 1 unless $admin_command;
	}
	return if $done;

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
	if (@params) {
		my $retval = $tagsdb->setTagname($id, {( map {( $_, 1 )} @params )});
		$self->info_log("set '$tagname' to '@params': $retval");
	}
	if ($admin_command) {
		my $c = "$admin_command$tagname";
		my $tagnameid = $tagsdb->processAdminCommand($c, undef, undef, { adminuid => $admin_command_uid });
		$self->info_log("set '$tagname' admin_command '$c' from uid=$admin_command_uid: $tagnameid");
	}
}

1;


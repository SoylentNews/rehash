#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

#################################################################
sub main {
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $op = getCurrentForm('op');
	my $section = $slashdb->getSection($form->{section});

	header(getData('header'), $section->{section}) or return;

	if (!$constants->{allow_moderation}) {
		print getData('no_moderation');
	} elsif (!$slashdb->metamodEligible($user)) {
		print getData('not-eligible');
	} elsif ($op eq 'MetaModerate') {
		metaModerate();
	} else {
		displayTheComments();
	}

	writeLog($op);
	footer();
}

#################################################################
sub metaModerate {
	my($id) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	# The user is only allowed to metamod the mods they were given.
	my @mods_saved = $slashdb->getModsSaved();
	my %mods_saved = map { ( $_, 1 ) } @mods_saved;

	# %m2s is the data structure we'll be building.
	my %m2s = ( );

	for my $key (keys %{$form}) {
		# Metamod form data can only be a '+' or a '-'.
		next unless $form->{$key} =~ /^[+-]$/;
		# We're only looking for the metamod inputs.
		next unless $key =~ /^mm(\d+)$/;
		my $mmid = $1;
		# Only the user's given mods can be used.
		next unless $mods_saved{$mmid};
		# This one's valid.  Store its data in %m2s.
		$m2s{$mmid}{is_fair} = ($form->{$key} eq '+') ? 1 : 0;
	}

	# The createMetaMod() method does all the heavy lifting here.
	# Re m2_multicount:  if this var is set, then our vote for
	# reason r on cid c applies potentially to *all* mods of
	# reason r on cid c.
	$slashdb->createMetaMod($user, \%m2s, $constants->{m2_multicount});

	print getData('thanks');
}

#################################################################
sub displayTheComments {
	my($id) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	my $reasons = $slashdb->getReasons();
	my $comments = $slashdb->getMetamodsForUser(
		$user, $constants->{m2_comments}
	);

	# We set this to prevent the "Reply" and "Parent" links from
	# showing up. If the metamoderator needs context, they can use
	# the CID link.
	$user->{mode} = 'metamod';

	slashDisplay('dispTheComments', {
		comments 	=> $comments,
		reasons		=> $reasons,
	});
}

#################################################################
createEnvironment();
main();


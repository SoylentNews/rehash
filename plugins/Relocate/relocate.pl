#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::Relocate;
use Slash::Utility;

#################################################################
sub main {
	my $form = getCurrentForm();
	my $relocateDB = getObject("Slash::Relocate", { db_type => 'reader' });

	my $link = $relocateDB->get($form->{id});
	if (!$link) {
		my $gSkin = getCurrentSkin();
		redirect("$gSkin->{rootdir}/404.pl");
	} elsif ($link->{is_alive} eq 'no') {
		header("D'Oh") or return; # Needs to be templated -Brian
		printDeadPage($link);
		footer();
	} else {
		if (getCurrentStatic("relocate_keep_count")) {
			my $relocate_writer = getObject("Slash::Relocate");
			my $success = $relocate_writer->increment_count($link->{id});
			if (!$success) {
				warn "did not increment links_for_stories.count for id '$link->{id}'";
			}
		}
		redirect($link->{url});
	}
}

main();

sub printDeadPage {
	my($link) = @_;
	slashDisplay("deadPage", { link => $link });
}

#################################################################
1;

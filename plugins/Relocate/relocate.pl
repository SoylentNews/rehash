#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
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
		my $constants = getCurrentStatic();
		redirect("$constants->{rootdir}/404.pl");
	} elsif ($link->{is_alive} eq 'no') {
		header("D'Oh") or return; # Needs to be templated -Brian
		printDeadPage($link);
		footer();
	} else {
		redirect($link->{url});
	}
}

main();

sub printDeadPage {
	my ($link) = @_;
	slashDisplay("deadPage", { link => $link });
}

#################################################################
1;

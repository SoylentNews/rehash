#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

sub main {
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $form      = getCurrentForm();

	my $section = $slashdb->getSection($form->{section});
	my $list    = $slashdb->getAuthorDescription();

	header("$constants->{sitename}: Authors", $section->{section});
	slashDisplay('main', {
		list	=> $list,
		title	=> "The Authors",
		admin	=> getCurrentUser('seclev') >= 1000,
		'time'	=> timeCalc(scalar localtime),
	});

	footer($form->{ssi});
}

createEnvironment();
main();

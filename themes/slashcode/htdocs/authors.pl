#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

sub main {
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $form      = getCurrentForm();

	my $section = $reader->getSection($form->{section});
	my $list    = $reader->getAuthorDescription();

	header("$constants->{sitename}: Authors", $section->{section}) or return;
	slashDisplay('main', {
		list	=> $list,
		title	=> "The Authors",
		admin	=> getCurrentUser('seclev') >= 1000,
		'time'	=> timeCalc(scalar localtime),
	});

	footer();
}

createEnvironment();
main();

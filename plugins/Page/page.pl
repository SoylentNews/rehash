#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;
use Slash::Page;
use Data::Dumper;

sub main {
	my $slashdb	= getCurrentDB();
	my $constants	= getCurrentStatic();
	my $user	= getCurrentUser();
	my $form	= getCurrentForm();
	my $index	= getObject('Slash::Page');

	if ($form->{op} eq 'userlogin' && !$user->{is_anon}) {
		my $refer = $form->{returnto} || $ENV{SCRIPT_NAME};
		redirect($refer);
		return;
	}

	my $skin_name = $form->{section};
	my $skid = $skin_name
		? $slashdb->getSkidFromName($skin_name)
		: determineCurrentSkin();
	setCurrentSkin($skid);
	my $gSkin = getCurrentSkin();
	$skin_name = $gSkin->{name};

	my $title = getData('head', { section => $skin_name });
	header($title, $skin_name) or return;
	slashDisplay('index', { 'index' => $index, section => $skin_name });

	footer();

	writeLog();
}
#################################################################
createEnvironment();
main();

1;

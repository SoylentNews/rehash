#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

##################################################################
sub main {
	my $form	= getCurrentForm();
	my $constants	= getCurrentStatic();

	header(getData('head')) or return;

	my $dilemma_reader = getObject('Slash::Dilemma', { db_type => 'reader' });
	my $dilemma_db = getObject('Slash::Dilemma');

	my $info = $dilemma_reader->getDilemmaInfo();

	slashDisplay('maininfo', {
		info		=> $info,
	});

	footer();
}

#################################################################
createEnvironment();
main();

1;

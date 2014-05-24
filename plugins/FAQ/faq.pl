#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
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
	my $form      = getCurrentForm();

	header(getData('head'), '', { Page => 'index2' }) or return;

	my $op = $form->{op} || 'faq';


	slashDisplay($op);

	footer({ Page => 'index2' });
}

#################################################################
createEnvironment();
main();

1;

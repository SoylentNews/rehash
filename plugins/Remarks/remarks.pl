#!/usr/bin/perl
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use warnings;

use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants qw(:web);
use Slash::Display;
use Slash::Utility;
use Slash::XML;
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;


sub main {
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();
	my $gSkin     = getCurrentSkin();
	my $remarks   = getObject('Slash::Remarks');

	if (! $user->{is_admin}) {
		redirect("$gSkin->{rootdir}/");
		return;
	}

	my %ops = (
		display		=> \&display,
		save_prefs	=> \&save_prefs,

		default		=> \&display
	);

	my $op = $form->{op};
	if (!$op || !exists $ops{$op}) {
		$op = 'default';
	}

	header('Remarks', '', { admin => 1 }) or return;

	$ops{$op}->($slashdb, $constants, $user, $form, $gSkin, $remarks);

	footer();
}


sub display {
	my($slashdb, $constants, $user, $form, $gSkin, $remarks) = @_;
	print $remarks->displayRemarksTable({ max => 30, print_whole => 1 });
}

sub save_prefs {
	my($slashdb, $constants, $user, $form, $gSkin) = @_;

}

createEnvironment();
main();

1;

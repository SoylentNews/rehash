#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::Utility;
use SOAP::Transport::HTTP;

#################################################################
sub main {

	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $r = Apache->request;

	my $action;
	if ($action = $r->header_in('SOAPAction')) {
		# security problem previous to 0.55
		if (SOAP::Lite->VERSION >= 0.55) {
			if ($user->{state}{post}) {
				$r->method('POST');
			}
			# Do some security checking here
			$user->{state}{packagename} = __PACKAGE__;
			return SOAP::Transport::HTTP::Apache->dispatch_to
				($action)->handle;
		}
	}
}

main();
1;

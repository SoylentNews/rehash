#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

# NOTE: package Slash::SOAP will be in its own .pm file later,
# the SQL at the bottom will be in the schema and dump files,
# and the Users code is just there temporarily for testing.

use strict;
use Slash;
use Slash::Utility;

#use SOAP::Lite 'trace';
require SOAP::Transport::HTTP;

#################################################################
sub main {
	my $r = Apache->request;

	if (my $action = $r->header_in('SOAPAction')) {
		# check access controls, get proper dispatch name
		my $soap = getObject('Slash::SOAP');
		my $newaction = $soap->handleMethod($action);

		# this messes us up inside SOAP::Lite
		my $user = getCurrentUser();
		$r->method('POST') if $user->{state}{post};

		# log error
		errorLog($Slash::SOAP::ERROR) if !$newaction;

		my $dispatch = SOAP::Transport::HTTP::Apache->dispatch_to($newaction);
		return $dispatch->handle;
	}
}

main();

1 if $Slash::SOAP::ERROR;

1;

#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

# NOTE: package Slash::SOAP will be in its own .pm file later,
# the SQL at the bottom will be in the schema and dump files,
# and the Users code is just there temporarily for testing.

use strict;
use SOAP::Transport::HTTP;
use Slash;
use Slash::Utility;

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

		# this doesn't currently work ... working on it -- pudge
		# default to error handler that returns value of
		# global variable $Slash::SOAP::ERROR
		unless ($newaction) {
			$newaction ||= 'Slash::SOAP::returnError';
			errorLog($Slash::SOAP::ERROR);
		}

		my $dispatch = SOAP::Transport::HTTP::Apache->dispatch_to($newaction);
		return $dispatch->handle;
	}
}

main();

1;

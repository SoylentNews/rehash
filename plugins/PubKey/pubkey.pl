#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash 2.001;	# require Slash 2.1
use Slash::Display;
use Slash::Utility;
use Slash::XML;
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub main {
	my $slashdb   = getCurrentDB();
	my $user      = getCurrentUser();
	my $r = Apache->request;
	$r->header_out('Cache-Control', 'private');
	$r->content_type('text/plain');
	$r->status(200);
	$r->send_http_header;
	$r->rflush;
	my $nick = getCurrentForm('nick');
	unless ($nick) {
			$r->print(getData('no_nick'));
			return 1;
	}
	my $uid = $slashdb->getUserUID($nick);
	my $content = $slashdb->getUser($uid, 'pubkey');

	if($content) {
		$content = strip_nohtml($content);
		$r->print($content);
	} else {
		$r->print(getData('no_key'));
	}

	return 1;
}


createEnvironment();
main();
1;

#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

sub main {
	my $constants = getCurrentStatic();
	$ENV{REQUEST_URI} ||= '';

	# catch old .shtml links ... need to check for other schemes, too?
        if ($ENV{REQUEST_URI} =~ m|^/?\w+/(\d\d/\d\d/\d\d/\d+)\.shtml$|) {
		redirect("$constants->{rootdir}/article.pl?sid=$1");
		return;
        }

	my $url = strip_literal(substr($ENV{REQUEST_URI}, 1));
	my $admin = $constants->{adminmail};

	header('404 File Not Found');

	my($new_url, $errnum) = fixHref($url, 1);

	if ($errnum && $errnum !~ /^\d+$/) {
		slashDisplay('main', {
			url	=> $new_url,
			origin	=> $url,
			message	=> $errnum,
		});
	} else {
		slashDisplay('main', {
			error	=> $errnum,
			url	=> $new_url,
			origin	=> $url,
		});
	}

	writeLog('404');
	footer();
}

createEnvironment();
main();

1;

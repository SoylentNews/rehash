#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;

use Slash::Constants ':slashd';

use vars qw( %task $me );

$task{$me}{timespec} = '2 7 * * *';
$task{$me}{timespec_panic_1} = ''; # if panic, this can wait
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtualuser, $constants, $slashdb, $user) = @_;
	my $forgotten1 = $slashdb->forgetCommentIPs();
	my $forgotten2 = $slashdb->forgetSubmissionIPs();
	my $forgotten3 = $slashdb->forgetOpenProxyIPs();
	return "forgot approx $forgotten1 comment IPs, $forgotten2 submission IPs, $forgotten3 open proxy IPs";
};

1;


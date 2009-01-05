#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
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
	my @forgotten = (
		$slashdb->forgetCommentIPs,
		$slashdb->forgetSubmissionIPs,
		$slashdb->forgetOpenProxyIPs,
		$slashdb->forgetUsersLogtokens,
		$slashdb->forgetUsersLastLookTime,
		$slashdb->forgetUsersMailPass,
		$slashdb->forgetRemarks,
		$slashdb->forgetStoryTextRendered,
		$slashdb->forgetErrnotes,
		$slashdb->forgetNewPasswds,
	);
	return "forgotten: '@forgotten'";
};

1;


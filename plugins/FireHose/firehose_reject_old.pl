#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;

use Time::HiRes;

use Slash;
use Slash::Constants ':slashd';
use Slash::Display;
use Slash::Utility;

use vars qw(
	%task	$me	$task_exit_flag
);

$task{$me}{timespec} = '18 3 * * *';
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;
	my $firehose = getObject("Slash::FireHose");
	my $old = $slashdb->sqlSelectColArrayref("id", "firehose", "createtime < DATE_SUB(NOW(),INTERVAL 7 DAY) and category ='' and rejected='no'");
	foreach (@$old) {
		$firehose->reject($_);
	}

	slashdLog("rejected " . scalar(@$old) . " items\n");
};

1;


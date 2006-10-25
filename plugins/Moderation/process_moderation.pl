#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash::Utility;
use Slash::Constants qw( :messages :slashd );

use vars qw( %task $me $task_exit_flag );

$task{$me}{timespec} = '28 0-23 * * *';
$task{$me}{timespec_panic_1} = '';
$task{$me}{resource_locks} = { log_slave => 1, moderatorlog => 1 };
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {

	my($virtual_user, $constants, $slashdb, $user) = @_;

	if (!$constants->{m1}) {
		slashdLog("$me - moderation inactive") if verbosity() >= 2;
		return ;
	}

	# do stuff here

	return ;
};

1;


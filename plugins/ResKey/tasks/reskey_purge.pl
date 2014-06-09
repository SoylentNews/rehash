#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use utf8;

use Slash::Constants qw(:slashd :reskey);

use vars qw( %task $me );

$task{$me}{timespec} = '3 * * * *';
$task{$me}{timespec_panic_1} = ''; # if panic, this can wait
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;

	if (my $reskey = getObject('Slash::ResKey')) {
		my $count = $reskey->purge_old || 0;
		slashdLog("Purged $count reskeys\n");
		$reskey->update_salts;
	}
};

1;

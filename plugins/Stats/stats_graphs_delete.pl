#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash::Utility;

my $me = 'stats_graphs_delete.pl';

use vars qw( %task );

$task{$me}{timespec} = '5 6 * * *';
$task{$me}{timespec_panic_2} = ''; # if major panic, dailyStuff can wait
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $stats = getObject('Slash::Stats');

	unless ($stats) {
		slashdLog("$me: could not instantiate Slash::Stats object");
		return;
	}

	my $count = $stats->cleanGraphs;
	return sprintf "%d old graph%s deleted.", $count, ($count == 1 ? '' : 's');
};

1;

#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use File::Spec::Functions;
use Slash::Constants ':slashd';
use Slash::Utility;

my $me = 'journal_fix.pl';

use vars qw( %task );

$task{$me}{timespec} = '0-59 * * * *'; # should happen every minute?
$task{$me}{timespec_panic_1} = '1-59/10 * * * *';
$task{$me}{timespec_panic_2} = '';
$task{$me}{on_startup} = 1;
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $journal = getObject('Slash::Journal');
	$journal->updateTransferredJournalDiscussions;

};

1;

#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

# This task is now defunct, replaced by the Top tagbox.

use strict;
use vars qw( %task $me $task_exit_flag );
use Slash::DB;
use Slash::Display;
use Slash::Utility;
use Slash::Constants ':slashd';

(my $VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

$task{$me}{timespec} = "5 0 1 1 *";
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{fork} = SLASHD_NOWAIT;

$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;
	return 'This task is defunct, exiting';
};

1;


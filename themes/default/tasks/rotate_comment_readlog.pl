#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use utf8;
use Slash;
use Slash::Constants ':slashd';
use vars qw( %task $me %redirects );

$task{$me}{timespec} = '30 1 * * *';
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;

	my $days = int($constants->{comment_read_max_age}) || 14;
	$slashdb->sqlDo("DELETE FROM users_comments_read_log where ts < DATE_SUB(NOW(), INTERVAL $days DAY)");
	
	return;
}

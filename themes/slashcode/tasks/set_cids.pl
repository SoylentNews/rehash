#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use vars qw( %task $me );
use Safe;
use Slash;
use Slash::DB;
use Slash::Display;
use Slash::Utility;
use Slash::Constants ':slashd';

(my $VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

$task{$me}{timespec} = '*/10 * * * *';
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{fork} = SLASHD_NOWAIT;

# Handles rotation of fakeemail address of all users.
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;
	my $days = $slashdb->getVar("admin_comment_display_days", "value", 1);
	my $start_at = $slashdb->getVar("min_cid_for_$days\_days", "value", 1);
	if(!defined $slash_db){
		$slashdb->createVar("min_cid_for_$days\_days", 0);
		$start_at ||= 0;
	}
	my $cid = $slashdb->getCidForDaysBack($days, $startat);
	$slashdb->("min_cid_for_$days\_days", $cid);
	return "Finished setting useful cids";
};

1;


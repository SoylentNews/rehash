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

# Handles saving useful cids so we can speed up certain selects later.
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;
	my $days = $slashdb->getVar("admin_comment_display_days", "value", 1) || 30;

	# Get the old value for this var, or if it hasn't been
	# defined, create it at the default 0.
	my $start_at = $slashdb->getVar("min_cid_last_$days\_days", "value", 1);
	if (!defined($start_at)){
		$slashdb->createVar("min_cid_last_$days\_days", 0);
		$start_at ||= 0;
	}

	# Now get the new value for this var;  if the method
	# doesn't return a new value, then there were no new
	# comments posted during that period several days ago,
	# so we just keep using the old value.
	my $cid = $slashdb->getCidForDaysBack($days, $start_at) || $start_at;
	my $success = $slashdb->setVar("min_cid_last_$days\_days", $cid);

	if ($success) {
		return "min_cid_last_$days\_days is $cid";
	} else {
		return "could not set min_cid_last_$days\_days to $cid";
	}
};

1;


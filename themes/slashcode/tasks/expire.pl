#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use vars qw( %task $me );
use Slash;
use Slash::DB;
use Slash::Display;
use Slash::Utility;
use Slash::Constants ':slashd';

(my $VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

$task{$me}{timespec} = '2 6 * * *';
$task{$me}{timespec_panic_2} = ''; # if major panic, this can wait
$task{$me}{fork} = SLASHD_NOWAIT;

# Handles mail and administrivia necessary for RECENTLY expired users.
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	# We only perform the check if any of the following are turned on.
	# the logic below, should probably be moved into Slash::Utility.
	if (!allowExpiry()) {
		return "user expiration disabled";
	}

	# This may need to go into a template somewhere.
	my $reg_subj = "Your $constants->{sitename} password has expired.";
	# Loop over all about-to-expire users.
	my @users_to_expire = @{$slashdb->checkUserExpiry()};
	for my $e_user (@users_to_expire) {
		# Put user in read-only mode for all forms and other 'pages' that
		# should be. This should also send the appropriate email. This
		# is better off in the API, as it is used in users.pl, as well.
		setUserExpired($e_user, 1);
	}

	return "expired " . scalar(@users_to_expire) . " users";
};

1;


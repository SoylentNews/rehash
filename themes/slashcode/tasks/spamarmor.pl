#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use vars qw( %task $me );
use Safe;
use Slash;
use Slash::DB;
use Slash::Display;
use Slash::Utility;

(my $VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

$task{$me}{timespec} = '30 0 * * *';
$task{$me}{timespec_panic_1} = ''; # not that important

# Handles rotation of fakeemail address of all users.
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

#	# Loop over all users. The call to iterateUsers gets a block of 
#	# users and iterates over that. As opposed to trying to grab all
#	# of the ENTIRE USERBASE at once. Since a statement handle would
#	# be the best way to get this data, but the API doesn't return 
#	# statement handles, we'll have to use a few tricks.
#	my ($count, $usr_block) = (0, 0);
#	do {
#		my $usr_block = $slashdb->iterateUsers(1000);
#
#		for my $user (@{$usr_block}) {
#	# Should be a constant somewhere, probably. The naked '1' below
#	# refers to the code in $users->{emaildisplay} corresponding to
#	# random rotation of $users->{fakeemail}.
#			next if !defined($user->{emaildisplay})
#				or $user->{emaildisplay} != 1;
#
#	# Randomize the email armor.
#			$user->{fakeemail} = getArmoredEmail($_);
#
#	# If executed properly, $user->{fakeemail} should have a value.
#	# If so, save the result.
#			if ($user->{fakeemail}) {
#				$slashdb->setUser($user->{uid}, {
#					fakeemail	=> $user->{fakeemail},
#				});
#				$count++;
#			}
#		}
#	} while $usr_block;

	my $count = 0;
	my $hr = $slashdb->getTodayArmorList();
	for my $uid (sort { $a <=> $b } keys %$hr) {
		my $fakeemail = getArmoredEmail($uid, $hr->{$uid}{realemail});
		$slashdb->setUser($uid, { fakeemail => $fakeemail });
		++$count;
		sleep 1 if ($count % 20) == 0;
	}

	return "rotated armoring for $count users";
};

1;


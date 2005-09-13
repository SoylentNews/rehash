# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::ResKey::Checks::User;

use warnings;
use strict;

use Slash::Utility;
use Slash::Constants ':reskey';

use base 'Slash::ResKey::Key';

our($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub _Check {
	my($self) = @_;

	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	if ($constants->{"reskey_checks_adminbypass_$self->{resname}"} && $user->{is_admin}) {
		return RESKEY_SUCCESS;
	}

	for my $check (qw(is_admin seclev is_subscriber karma)) {
		my $value = $constants->{"reskey_checks_user_${check}_$self->{resname}"};
		if (defined $value && length $value && $user->{$check} < $value) {
			return(RESKEY_DEATH, ["$check too low", { needed => $value }]);
		}
	}

	return RESKEY_SUCCESS;
}

1;

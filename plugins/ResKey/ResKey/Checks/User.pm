# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::ResKey::Checks::User;

use warnings;
use strict;

use Slash::Utility;
use Slash::Constants ':reskey';

use base 'Slash::ResKey::Key';

our $VERSION = $Slash::Constants::VERSION;

sub doCheck {
	my($self) = @_;

	my $user = getCurrentUser();
	my $check_vars = $self->getCheckVars;

	if ($check_vars->{adminbypass} && $user->{is_admin}) {
		return RESKEY_SUCCESS;
	}

	for my $check (qw(is_admin seclev is_subscriber karma tags_canread_stories tags_canwrite_stories)) {
		my $value = $check_vars->{"user_${check}"};
		if (defined $value && length $value && (! defined $user->{$check} || $user->{$check} < $value)) {
			return(RESKEY_DEATH, ["$check too low", { needed => $value }]);
		}
	}

	return RESKEY_SUCCESS;
}

1;

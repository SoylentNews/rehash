# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::ResKey::Checks::Post;

use warnings;
use strict;

use Slash::Utility;
use Slash::Constants ':reskey';

use base 'Slash::ResKey::Key';

our $VERSION = $Slash::Constants::VERSION;

sub doCheck {
	my($self) = @_;

	return RESKEY_NOOP unless $ENV{GATEWAY_INTERFACE};

	my $user = getCurrentUser();

	if (!$user->{state}{post}) {
		return(RESKEY_FAILURE, ['post method required']);
	}

	return RESKEY_SUCCESS;
}


1;

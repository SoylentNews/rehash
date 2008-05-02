# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::ResKey::Checks::ProxyScan;

use warnings;
use strict;

use Slash::Utility;
use Slash::Constants ':reskey';

use base 'Slash::ResKey::Key';

our $VERSION = $Slash::Constants::VERSION;

sub doCheck {
	my($self) = @_;

	if (!$ENV{GATEWAY_INTERFACE}) {
		return RESKEY_SUCCESS;
	}

	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $user = getCurrentUser();
	my $check_vars = $self->getCheckVars;

	if ($check_vars->{adminbypass} && $user->{is_admin}) {
		return RESKEY_SUCCESS;
	}

	unless ($reader->checkAL2($user->{srcids}, 'trusted')) {
		my $is_proxy = $reader->checkForOpenProxy($user->{srcids}{ip});
		if ($is_proxy) {
			return(RESKEY_DEATH, ['open proxy', {
				unencoded_ip	=> $ENV{REMOTE_ADDR},
				port		=> $is_proxy,
			}]);
		}
	}

	return RESKEY_SUCCESS;
}


1;

# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::ResKey::Checks::ACL;

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

	my $acl    = $check_vars->{acl};
	my $acl_no = $check_vars->{acl_no};

	# is_admin is an exception to lack of ACL if adminbypass set
	my $acl_nobypass_admin = (!$user->{is_admin} || (
		$user->{is_admin} && !$check_vars->{adminbypass}
	));

	if ($acl && !$user->{acl}{$acl} && $acl_nobypass_admin) {
		return(RESKEY_DEATH, [ 'has no acl', { acl => $acl } ]);
	}

	# is_admin does not bypass acl_no
	if ($acl_no && $user->{acl}{$acl_no}) {
		return(RESKEY_DEATH, [ 'has acl_no', { acl => $acl_no } ]);
	}

	return RESKEY_SUCCESS;
}

1;

# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::ResKey::Checks::ACL;

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

	my $acl = $constants->{"reskey_checks_acl_$self->{resname}"};
	my $acl_no = $constants->{"reskey_checks_acl_no_$self->{resname}"};

	# by default, is_admin is an automatic exception to no ACL
	my $acl_nobypass_admin = (!$user->{is_admin} || (
		$user->{is_admin} &&
		$constants->{"reskey_checks_acl_nobypass_admin_$self->{resname}"}
	));

	if ($acl && !$user->{acl}{$acl} && $acl_nobypass_admin) {
		return(RESKEY_DEATH, [ 'has no acl', { acl => $acl } ]);
	}

	if ($acl_no && $user->{acl}{$acl_no}) {
		return(RESKEY_DEATH, [ 'has acl_no', { acl => $acl_no } ]);
	}

	return RESKEY_SUCCESS;
}

1;

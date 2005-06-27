# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::ResKey::Checks::AL2::AnonNoPost;

use warnings;
use strict;

use Slash::Utility;
use Slash::Constants ':reskey';

use base 'Slash::ResKey::Checks::AL2';

our($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub _Check {
	my($self) = @_;

	my $user = getCurrentUser();

	if ($user->{is_anon}) {
		return $self->AL2Check(
			{ uid => getCurrentAnonymousCoward('uid') },
			'nopost'
		);
	} else {
		return RESKEY_NOOP;
	}
}

1;

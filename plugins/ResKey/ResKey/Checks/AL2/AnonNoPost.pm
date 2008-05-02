# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::ResKey::Checks::AL2::AnonNoPost;

use warnings;
use strict;

use Slash::ResKey::Checks::AL2;
use Slash::Utility;
use Slash::Constants ':reskey';

use base 'Slash::ResKey::Key';

our $VERSION = $Slash::Constants::VERSION;

sub doCheck {
	my($self) = @_;

	my $user = getCurrentUser();
	my $form = getCurrentForm();

	# this check assumes only one AC uid, and doesn't accept any
	# other UIDs to be provided

	if ($user->{is_anon} || $form->{postanon}) {
		return AL2Check(
			$self, 'nopost',
			{ uid => getCurrentAnonymousCoward('uid') },
		);
	} else {
		return RESKEY_NOOP;
	}
}

1;

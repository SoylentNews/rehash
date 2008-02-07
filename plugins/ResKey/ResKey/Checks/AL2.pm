# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::ResKey::Checks::AL2;

use warnings;
use strict;

use Exporter;

use Slash::Utility;
use Slash::Constants ':reskey';

our($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;
our @ISA    = qw(Exporter);
our @EXPORT = qw(AL2Check);

# simple AL2 check that others can inherit; returns death if check returns true
sub AL2Check {
	my($self, $check, $srcids) = @_;

	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();

	$srcids ||= $user->{srcids};

	if ($slashdb->checkAL2($srcids, $check)) {
		return(RESKEY_DEATH, ["$check al2 failure"]);
	}

	return RESKEY_SUCCESS;
}

1;

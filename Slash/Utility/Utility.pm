# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Utility;

=head1 NAME

Slash::Utility - Generic Perl routines for Slash


=head1 SYNOPSIS

	use Slash::Utility;


=head1 DESCRIPTION

Slash::Utility comprises methods that are safe
to call both within and without Apache.


=head1 FUNCTIONS

Unless otherwise noted, they are publically available functions.

=cut

use strict;
use Slash::Utility::Access;
use Slash::Utility::Anchor;
use Slash::Utility::Data;
use Slash::Utility::Display;
use Slash::Utility::Environment;
use Slash::Utility::System;

use base 'Exporter';
use vars qw($VERSION @EXPORT);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;
@EXPORT = (
	@Slash::Utility::Access::EXPORT,
	@Slash::Utility::Anchor::EXPORT,
	@Slash::Utility::Data::EXPORT,
	@Slash::Utility::Display::EXPORT,
	@Slash::Utility::Environment::EXPORT,
	@Slash::Utility::System::EXPORT,
);

# LEELA: We're going to deliver this crate like professionals.
# FRY: Aww, can't we just dump it in the sewer and say we delivered it?
# BENDER: Too much work!  I say we burn it, then *say* we dumped it in the sewer!

1;

__END__

=head1 SEE ALSO

Slash(3).

=cut

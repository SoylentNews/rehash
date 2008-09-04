# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Utility;

=head1 NAME

Slash::Utility - Generic Perl routines for Slash


=head1 SYNOPSIS

	use Slash::Utility;


=head1 DESCRIPTION

The Slash::Utility::Xyz classes all EXPORT their own functions.  For
example, 'package main; use Slash::Utility::Environment;' will allow
Slash::Utility::Environment::getCurrentStatic() to be called as
main::getCurrentStatic(), effectively making it a global function.

And unlike what some might consider "best practices," Slash exports
quite a few functions, over 170 at current count.  Since Slash is an
application, not a library, we consider this to be best.  We find
	if (isAnon($comment->{uid}))
more readable than
	if (Slash::Utility::Environment::isAnon($comment->{uid}))
and it seems appropriate to us.

So, 'use Slash::Utility;' is nothing but a convenient way to import
_all_ the Slash::Utility::Xyz functions into the 'use'rs namespace.

These functions are safe to call either within mod_perl/Apache or not.

Note that 'use Slash;' will pull in a few of the most commonly used
functions such as getCurrentStatic(), so if your code is simple,
maybe you won't need to specify 'use Slash::Utility;'.

(Query to pudge:  would it make sense to you to push the @EXPORT
groupings up from Slash::Utility to Slash and just eliminate
Slash::Utility altogether?  I don't much care either way. -Jamie)

=head1 FUNCTIONS

Unless otherwise noted, they are publically available functions.

=cut

use strict;
use Slash::Utility::Access;
use Slash::Utility::Anchor;
use Slash::Utility::Comments;
use Slash::Utility::Data;
use Slash::Utility::Display;
use Slash::Utility::Environment;
use Slash::Utility::System;
use Slash::Constants ();

use base 'Exporter';

our $VERSION = $Slash::Constants::VERSION;
our @EXPORT = (
	@Slash::Utility::Access::EXPORT,
	@Slash::Utility::Anchor::EXPORT,
	@Slash::Utility::Comments::EXPORT,
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

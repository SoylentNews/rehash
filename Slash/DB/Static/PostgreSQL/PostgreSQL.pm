# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::DB::Static::PostgreSQL;
use strict;
use Slash::DB::Utility;
use Slash::Utility;
use URI ();
use vars qw(@ISA $VERSION);

@ISA = qw( Slash::DB::Utility );
($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# BENDER: I hate people who love me.  And they hate me.

1;

__END__

=head1 NAME

Slash::DB::Static::PostgreSQL - PostgreSQL Interface for Slash

=head1 SYNOPSIS

  use Slash::DB::Static::PostgreSQL;

=head1 DESCRIPTION

No documentation yet. Sue me.

=head1 SEE ALSO

Slash(3), Slash::DB(3).

=cut

# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::DB::Static::PostgreSQL;
use strict;
use Slash::Utility;

use base 'Slash::DB::PostgreSQL';
use base 'Slash::DB::Static::MySQL';

our $VERSION = $Slash::Constants::VERSION;

# FRY: Whoa, slow down. You're going a mile a minute.

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

# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

# this merely overrides a "broken" method in Apache::SSI,
# where include directives don't work for mixing with Apache::Compress
# patch comes from author of Apache::SSI and Apache::Compress

package Slash::Custom::ApacheRegistryFilter;

use strict;
use base 'Apache::RegistryFilter';
use vars qw($VERSION);

use Apache::Constants qw(:common);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub handler ($$) {
  my ($class, $r) = @_ > 1 ? (shift, shift) : (__PACKAGE__, shift);
  my $status = $class->SUPER::handler($r);
  $r->status($status);
  return OK;
}

1;

__END__

# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

# this merely overrides a "broken" method in Apache::SSI,
# where include directives don't work for mixing with Apache::Compress
# patch comes from author of Apache::SSI and Apache::Compress

# this also overrides run() so it sets content_type!
# and to get rid of warnings.

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

sub run {
  my $pr = shift;
  my $r = $pr->{r};

  # If the script was read & compiled in this child in a previous run,
  # we won't have called filter_input().  Call it now.
  unless ($r->notes('FilterRead') eq 'this_time') {
    $r->filter_input(handle => {}) 
  }

  # We temporarily override the header-sending routines to make them
  # noops.  This lets people leave these methods in their scripts.
  no warnings 'redefine';
  local *Apache::send_http_header = sub {
	$r->content_type($_[0]) if @_;
  };
  local *Apache::send_cgi_header = sub {};

  $pr->SUPER::run(@_);
}

1;

__END__

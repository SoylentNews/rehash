# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

# this merely overrides a "broken" method in Apache::SSI,
# where include directives don't work for mixing with Apache::Compress
# -- patch comes from author of Apache::SSI and Apache::Compress

# also fudges the Slash ssi directives to not print, but merely return


package Slash::Custom::ApacheCompress;

use strict;
use base 'Apache::Compress';
use vars qw($VERSION);

use Compress::Zlib 1.0;
use Apache::File;
use Apache::Constants qw(:common);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub handler {
  my $r = shift;

  my $can_gzip = $r->header_in('Accept-Encoding') =~ /gzip/;
  my $filter   = lc $r->dir_config('Filter') eq 'on';
  #warn "can_gzip=$can_gzip, filter=$filter";
  return DECLINED unless $can_gzip or $filter;
  
  # Other people's eyes need to check this 1.1 stuff.
  if ($r->protocol =~ /1\.1/) {
    my %vary = map {$_,1} qw(Accept-Encoding User-Agent);
    if (my @vary = $r->header_out('Vary')) {
      @vary{@vary} = ();
    }
    $r->header_out('Vary' => join ',', keys %vary);
  }
  
  my $fh;
  if ($filter) {
    $r = $r->filter_register;
    $fh = $r->filter_input();
  } else {
    my $filename = $r->filename;
    return NOT_FOUND unless -e $filename;
    $fh = Apache::File->new($filename);
  }
  unless ($fh) {
    warn "Cannot open file";
    return SERVER_ERROR;
  }
  
  if ($can_gzip) {
    $r->content_encoding('gzip');
    $r->send_http_header;
    local $/;
    print Compress::Zlib::memGzip(<$fh>);
  } else {
    $r->send_http_header;
    $r->send_fd($fh);
  }
  
  return OK;
}

1;

1;

__END__

# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

# this merely overrides a "broken" method in Apache::SSI,
# where include directives don't work for mixing with Apache::Compress
# -- patch comes from author of Apache::SSI and Apache::Compress

# also fudges the Slash ssi directives to not print, but merely return


package Slash::Custom::ApacheCompress;

use strict;
use base 'Apache::Compress';
use vars qw($VERSION);

use Compress::Zlib 1.0;
use Date::Format;
use Date::Parse;
use Apache::File;
use Apache::Constants qw(:common :http);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub handler {
  my $r = shift;
  
  my $can_gzip = can_gzip($r);

  my $filter   = lc $r->dir_config('Filter') eq 'on';
  #warn "can_gzip=$can_gzip, filter=$filter";
  return DECLINED unless $can_gzip or $filter;
  
  # Other people's eyes need to check this 1.1 stuff.
  if ($r->protocol =~ /1\.1/) {
    my %vary = map {$_,1} qw(Accept-Encoding User-Agent);
    if (my $vary = $r->header_out('Vary')||0) {
      $vary{$vary} = 1;
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
    my @stat = stat(_);
    my $time = $stat[9];

    if ($r->header_in('If-Modified-Since')) {
    	my $ltime = str2time($r->header_in('If-Modified-Since'));
    	if ($ltime >= $time) {
    		$r->status(HTTP_NOT_MODIFIED);
    		$r->send_http_header;
    		return OK;
    	}
    }

    $r->header_out('Last-Modified' => time2str("%a, %d %h %Y %X %Z", $time));
    $fh = Apache::File->new($filename);
  }
  unless ($fh) {
    warn "Cannot open file: $!";
    return SERVER_ERROR;
  }
  
  if ($can_gzip) {
    $r->content_encoding('gzip');
    $r->send_http_header;
#    $r->print( Compress::Zlib::memGzip(do {local $/; <$fh>}) );
    print( Compress::Zlib::memGzip(do {local $/; <$fh>}) );
  } else {
    $r->send_http_header;
    $r->send_fd($fh);
  }
  
  return OK;
}

sub can_gzip {
  my $r = shift;

  my $how_decide = $r->dir_config('CompressDecision');
  if (!defined($how_decide) || lc($how_decide) eq 'header') {
    return +($r->header_in('Accept-Encoding')||'') =~ /gzip/;
  } elsif (lc($how_decide) eq 'user-agent') {
    return guess_by_user_agent($r->header_in('User-Agent'));
  }
  
  die "Unrecognized value '$how_decide' specified for CompressDecision";
}
  
sub guess_by_user_agent {
  # This comes from Andreas' Apache::GzipChain.  It's very out of
  # date, though, I'd like it if someone sent me a better regex.

  my $ua = shift;
  return $ua =~  m{
		   ^Mozilla/            # They all start with Mozilla...
		   \d+\.\d+             # Version string
		   [\s\[\]\w\-]+        # Language
		   (?:
		    \(X11               # Any unix browser should work
		    |             
		    Macint.+PPC,\sNav   # Does this match anything??
		   )
		  }x;
}


1;


# Verbose version:
#    my $content = do {local $/; <$fh>};
#    my $content_size = length($content);
#    $content = Compress::Zlib::memGzip(\$content);
#    my $compressed_size = length($content);
#    my $ratio = int(100*$compressed_size/$content_size) if $content_size;
#    print STDERR "GzipCompression $content_size/$compressed_size ($ratio%)\n";
#    print $content;

__END__

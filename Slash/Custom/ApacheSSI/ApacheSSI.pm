# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

# this merely overrides a "broken" method in Apache::SSI,
# where include directives don't work for mixing with Apache::Compress
# -- patch comes from author of Apache::SSI and Apache::Compress

# also fudges the Slash ssi directives to not print, but merely return


package Slash::Custom::ApacheSSI;

use strict;
use base 'Apache::SSI';
use vars qw($VERSION);

use Apache::Constants qw(:common OPT_INCNOEXEC);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub ssi_perl {
  my($self, $args, $margs) = @_;
  $args->{'sub'} =~ s/print Slash::getAd/Slash::getAd/;
  $margs = [ %$args ];
  $self->SUPER::ssi_perl($args, $margs);
}

sub ssi_include {
  my ($self, $args) = @_;
  unless (exists $args->{file} or exists $args->{virtual}) {
    return $self->error("No 'file' or 'virtual' attribute found in SSI 'include' tag");
  }
  my $subr = $self->find_file($args);
  if (lc($self->{_r}->dir_config('ASSI_Subrequests')) eq 'off') {
    if (my $fh = Apache::File->new($subr->filename())) {
      $subr->dir_config->add('ASSI_Subrequests' => 'off');
      do {local $/; ref($self)->new( scalar(<$fh>), $subr )}->output;
    } else {
      $self->error("Include of ", $subr->filename, " failed: $!");
    }
  } else {
    unless ($subr->run == OK) {
      $self->error("Include of '@{[$subr->filename()]}' failed: $!");
    }
  }
  
  ## Make sure that all of the variables set in the include are present here.
  #my $env = $subr->subprocess_env();
  #foreach ( keys %$env ) {
  #  $self->{_r}->subprocess_env($_, $env->{$_});
  #}
  
  return '';
}

1;

__END__

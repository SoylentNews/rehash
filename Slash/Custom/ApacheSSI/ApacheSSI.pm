# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

# this merely overrides a "broken" method in Apache::SSI,
# where include directives don't work for mixing with Apache::Compress
# -- patch comes from author of Apache::SSI and Apache::Compress

# also fudges the Slash ssi directives to not print, but merely return


package Slash::Custom::ApacheSSI;

use strict;
use base 'Apache::SSI';
use vars qw($VERSION);

use Apache::Constants qw(:common :http OPT_INCNOEXEC);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub output {
    my $self = shift;
    
    my @parts = split m/(<!--#.*?-->)/s, $self->{'text'};
    while (@parts) {
#        $self->{_r}->print( ('', shift @parts)[1-$self->{'suspend'}[0]] );
        print( ('', shift @parts)[1-$self->{'suspend'}[0]] );
        last unless @parts;
        my $ssi = shift @parts;
        if ($ssi =~ m/^<!--#(.*)-->$/s) {
#            $self->{_r}->print( $self->output_ssi($1) );
            print( $self->output_ssi($1) );
        } else { die 'Parse error' }
    }
}

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
    if ( $subr->status == HTTP_OK ) {
      # Subrequests can fuck up %ENV, make sure it's restored upon exit.
      # Unfortunately 'local(%ENV)=%ENV' reportedly causes segfaults.
      my %save_ENV = %ENV;
      $subr->run == OK
        or $self->error("Include of '@{[$subr->filename()]}' failed: $!");
      %ENV = %save_ENV;
    }
  }
  
  return '';
}

1;

__END__

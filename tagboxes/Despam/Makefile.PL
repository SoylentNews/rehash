use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
# $Id$
WriteMakefile(
    'NAME'	=> 'Slash::Tagbox::Despam',
    'VERSION_FROM' => 'Despam.pm', # finds $VERSION
    'PM'	=> { 'Despam.pm' =>   '$(INST_LIBDIR)/Despam.pm' },
);

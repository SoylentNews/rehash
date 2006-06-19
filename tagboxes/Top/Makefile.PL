use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
# $Id$
WriteMakefile(
    'NAME'	=> 'Slash::Tagbox::Top',
    'VERSION_FROM' => 'Top.pm', # finds $VERSION
    'PM'	=> { 'Top.pm' =>   '$(INST_LIBDIR)/Top.pm' },
);

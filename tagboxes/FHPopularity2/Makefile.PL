use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
# $Id$
WriteMakefile(
    'NAME'	=> 'Slash::Tagbox::FHPopularity2',
    'VERSION_FROM' => 'FHPopularity2.pm', # finds $VERSION
    'PM'	=> { 'FHPopularity2.pm' =>   '$(INST_LIBDIR)/FHPopularity2.pm' },
);

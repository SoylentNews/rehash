use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
# $Id$
WriteMakefile(
    'NAME'	=> 'Slash::Tagbox::FHActivity',
    'VERSION_FROM' => 'FHActivity.pm', # finds $VERSION
    'PM'	=> { 'FHActivity.pm' =>   '$(INST_LIBDIR)/FHActivity.pm' },
);

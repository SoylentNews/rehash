use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Tagbox::FHActivity',
    'PM'	=> { 'FHActivity.pm' =>   '$(INST_LIBDIR)/FHActivity.pm' },
);

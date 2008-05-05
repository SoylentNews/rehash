use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Tagbox::Top',
    'PM'	=> { 'Top.pm' =>   '$(INST_LIBDIR)/Top.pm' },
);

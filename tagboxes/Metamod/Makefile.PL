use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Tagbox::Metamod',
    'PM'	=> { 'Metamod.pm' =>   '$(INST_LIBDIR)/Metamod.pm' },
);

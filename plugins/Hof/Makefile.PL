use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Hof',
    'VERSION_FROM' => 'Hof.pm', # finds $VERSION
    'PM'	=> { 'Hof.pm' => '$(INST_LIBDIR)/Hof.pm' },
);

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Dilemma',
    'VERSION_FROM' => 'Dilemma.pm', # finds $VERSION
    'PM'	=> { 'Dilemma.pm' => '$(INST_LIBDIR)/Dilemma.pm' },
);

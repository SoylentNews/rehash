use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Daypass',
    'VERSION_FROM' => 'Daypass.pm', # finds $VERSION
    'PM'	=> { 'Daypass.pm' => '$(INST_LIBDIR)/Daypass.pm' },
);

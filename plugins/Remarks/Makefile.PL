use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Remarks',
    'VERSION_FROM' => 'Remarks.pm', # finds $VERSION
    'PM'	=> { 'Remarks.pm' => '$(INST_LIBDIR)/Remarks.pm' },
);

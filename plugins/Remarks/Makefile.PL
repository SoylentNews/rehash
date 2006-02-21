use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Console',
    'VERSION_FROM' => 'Console.pm', # finds $VERSION
    'PM'	=> { 'Console.pm' => '$(INST_LIBDIR)/Console.pm' },
);

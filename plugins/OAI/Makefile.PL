use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::XML::OAI',
    'VERSION_FROM' => 'OAI.pm', # finds $VERSION
    'PM'	=> { 'OAI.pm' => '$(INST_LIBDIR)/OAI.pm' },
);

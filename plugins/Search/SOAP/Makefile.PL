use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Search::SOAP',
    'VERSION_FROM' => 'SOAP.pm', # finds $VERSION
    'PM'	=> { 'SOAP.pm' => '$(INST_LIBDIR)/SOAP.pm' },
);

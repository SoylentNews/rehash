use ExtUtils::MakeMaker;
use DBIx::Password;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::SOAP',
    'PM'	=> { 'SOAP.pm' => '$(INST_LIBDIR)/SOAP.pm',
    		     'Test.pm' => '$(INST_LIBDIR)/SOAP/Test.pm' },
);

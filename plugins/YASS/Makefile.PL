use ExtUtils::MakeMaker;
use DBIx::Password;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::YASS',
    'VERSION_FROM' => 'YASS.pm', # finds $VERSION
    'PM'	=> { 'YASS.pm' => '$(INST_LIBDIR)/YASS.pm' },
);

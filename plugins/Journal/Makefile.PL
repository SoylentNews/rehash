use ExtUtils::MakeMaker;
use DBIx::Password;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Journal',
    'VERSION_FROM' => 'Journal.pm', # finds $VERSION
    'PM'	=> { 'Journal.pm' => '$(INST_LIBDIR)/Journal.pm' },
);

use ExtUtils::MakeMaker;
use DBIx::Password;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Relocate',
    'VERSION_FROM' => 'Relocate.pm', # finds $VERSION
    'PM'	=> { 'Relocate.pm' => '$(INST_LIBDIR)/Relocate.pm' },
);

use ExtUtils::MakeMaker;
use DBIx::Password;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Zoo',
    'VERSION_FROM' => 'Zoo.pm', # finds $VERSION
    'PM'	=> { 'Zoo.pm' => '$(INST_LIBDIR)/Zoo.pm' },
);

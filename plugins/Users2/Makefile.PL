use ExtUtils::MakeMaker;
use DBIx::Password;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Users2',
    'VERSION_FROM' => 'Users2.pm', # finds $VERSION
    'PM'	=> { 'Users2.pm' => '$(INST_LIBDIR)/Users2.pm' },
);

use ExtUtils::MakeMaker;
use DBIx::Password;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Admin',
    'VERSION_FROM' => 'Admin.pm', # finds $VERSION
    'PM'	=> { 'Admin.pm' => '$(INST_LIBDIR)/Admin.pm' },
);

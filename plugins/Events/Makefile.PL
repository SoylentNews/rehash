use ExtUtils::MakeMaker;
use DBIx::Password;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Events',
    'VERSION_FROM' => 'Events.pm', # finds $VERSION
    'PM'	=> { 'Events.pm' => '$(INST_LIBDIR)/Events.pm' },
);

use ExtUtils::MakeMaker;
use DBIx::Password;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Page',
    'VERSION_FROM' => 'Page.pm', # finds $VERSION
    'PM'	=> { 'Page.pm' => '$(INST_LIBDIR)/Page.pm' },
);

use ExtUtils::MakeMaker;
use DBIx::Password;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Stats::Writer',
    'VERSION_FROM' => 'Writer.pm', # finds $VERSION
    'PM'	=> { 'Writer.pm' => '$(INST_LIBDIR)/Writer.pm' },
);

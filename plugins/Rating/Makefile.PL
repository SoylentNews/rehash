use ExtUtils::MakeMaker;
use DBIx::Password;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Rating',
    'VERSION_FROM' => 'Rating.pm', # finds $VERSION
    'PM'	=> { 'Rating.pm' => '$(INST_LIBDIR)/Rating.pm' },
);

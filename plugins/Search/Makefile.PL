use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Search',
    'VERSION_FROM' => 'Search.pm', # finds $VERSION
    'PM'	=> { 'Search.pm' => '$(INST_LIBDIR)/Search.pm' },
);

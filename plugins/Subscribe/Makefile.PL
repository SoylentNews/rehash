use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'      => 'Slash::Subscribe',
    'VERSION_FROM' => 'Subscribe.pm', # finds $VERSION
    'PM'        => { 'Subscribe.pm' => '$(INST_LIBDIR)/Subscribe.pm' },
);

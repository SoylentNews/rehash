use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'      => 'Slash::Ajax',
    'VERSION_FROM' => 'ajax.pl', # finds $VERSION
    'PM'        => { 'ajax.pl' => '$(INST_LIBDIR)/ajax.pl' },
);

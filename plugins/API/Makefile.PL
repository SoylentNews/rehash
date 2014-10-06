use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'      => 'Slash::API',
    'PM'        => { 'API.pm' => '$(INST_LIBDIR)/API.pm' },
);


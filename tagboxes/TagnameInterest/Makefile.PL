use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Tagbox::TagnameInterest',
    'PM'	=> { 'TagnameInterest.pm' =>   '$(INST_LIBDIR)/TagnameInterest.pm' },
);

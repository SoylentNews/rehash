use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'PM'	=> {
    	'Classic.pm'				=> '$(INST_LIBDIR)/Slash/SearchToo/Classic.pm',
    	'Plucene.pm'				=> '$(INST_LIBDIR)/Slash/SearchToo/Plucene.pm',
    },
);

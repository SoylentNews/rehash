use ExtUtils::MakeMaker;
use DBIx::Password;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Email',
    'PM'	=> {
    	'Email.pm'			=> '$(INST_LIBDIR)/Email.pm',
    },
);

use ExtUtils::MakeMaker;
use DBIx::Password;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Metamod',
    'VERSION_FROM' => 'Metamod.pm', # finds $VERSION
    'PM'	=> {
    	'Metamod.pm' => '$(INST_LIBDIR)/Metamod.pm',
    },
);

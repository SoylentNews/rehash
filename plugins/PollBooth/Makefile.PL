use ExtUtils::MakeMaker;
use DBIx::Password;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::PollBooth',
    'VERSION_FROM' => 'PollBooth.pm', # finds $VERSION
    'PM'	=> {
	'PollBooth.pm' => '$(INST_LIBDIR)/PollBooth.pm',
	'ResKey.pm'    => '$(INST_LIBDIR)/PollBooth/ResKey.pm',
    },
);

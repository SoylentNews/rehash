use ExtUtils::MakeMaker;
use DBIx::Password;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'      => 'Slash::TagModeration',
    'VERSION_FROM' => 'TagModeration.pm', # finds $VERSION
    'PM'        => {
	'TagModeration.pm' => '$(INST_LIBDIR)/TagModeration.pm',
    },
);

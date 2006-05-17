use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Tagbox::TagCountUser',
    'VERSION_FROM' => 'TagCountUser.pm', # finds $VERSION
    'PM'	=> { 'TagCountUser.pm' =>   '$(INST_LIBDIR)/TagCountUser.pm' },
);

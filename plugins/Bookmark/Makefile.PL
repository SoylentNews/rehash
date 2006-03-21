use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Bookmark',
    'VERSION_FROM' => 'Bookmark.pm', # finds $VERSION
    'PM'	=> { 'Bookmark.pm' => '$(INST_LIBDIR)/Bookmark.pm' },
);

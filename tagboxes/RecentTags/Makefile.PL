use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
# $Id$
WriteMakefile(
    'NAME'	=> 'Slash::Tagbox::RecentTags',
    'VERSION_FROM' => 'RecentTags.pm', # finds $VERSION
    'PM'	=> { 'RecentTags.pm' =>   '$(INST_LIBDIR)/RecentTags.pm' },
);

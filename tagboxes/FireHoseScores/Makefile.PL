use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
# $Id$
WriteMakefile(
    'NAME'	=> 'Slash::Tagbox::FireHoseScores',
    'VERSION_FROM' => 'FireHoseScores.pm', # finds $VERSION
    'PM'	=> { 'FireHoseScores.pm' =>   '$(INST_LIBDIR)/FireHoseScores.pm' },
);

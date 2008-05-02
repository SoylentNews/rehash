use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Tagbox::FHEditorPop',
    'PM'	=> { 'FHEditorPop.pm' =>   '$(INST_LIBDIR)/FHEditorPop.pm' },
);

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::Tags',
    'VERSION_FROM' => 'Tags.pm', # finds $VERSION
    'PM'	=>
    	{
		'Tags.pm' =>   '$(INST_LIBDIR)/Tags.pm',
		'Tagbox.pm' => '$(INST_LIBDIR)/Tagbox.pm',
    	},
);

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::WoW',
    'PM'	=>
	{
		'WoW.pm' =>   '$(INST_LIBDIR)/WoW.pm',
	},
);

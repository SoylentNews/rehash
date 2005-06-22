use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'	=> 'Slash::ResKey',
    'VERSION_FROM' => 'ResKey.pm', # finds $VERSION
#    'PM'	=> {
#    	'ResKey.pm' => '$(INST_LIBDIR)/ResKey.pm',
#    	'ResKey/Checks/User.pm' => '$(INST_LIBDIR)/ResKey/Checks/User.pm',
#    },
);

use ExtUtils::MakeMaker;

WriteMakefile(
	'NAME'		=> 'Slash::Client',
	'VERSION_FROM'	=> 'lib/Slash/Client.pm',
	'clean'	=> {
		'FILES'	=> 'Slash-Client-*'
	},
	'NO_META'		=> 1,
	'PREREQ_PM'	=> {
		'SOAP::Lite'	=> 0,
	},
);

use ExtUtils::MakeMaker;

WriteMakefile(
	'NAME'		=> 'Slash::Client',
	'clean'	=> {
		'FILES'	=> 'Slash-Client-*'
	},
	'NO_META'		=> 1,
	'PREREQ_PM'	=> {
		'SOAP::Lite'	=> 0,
	},
);

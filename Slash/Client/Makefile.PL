use ExtUtils::MakeMaker;

WriteMakefile(
	'NAME'		=> 'Slash::Client',
	'VERSION_FROM'	=> 'Client.pm',
	'clean'	=> {
		'FILES'	=> 'Slash-Client-*'
	},
	'NO_META'		=> 1,
);

use ExtUtils::MakeMaker;

WriteMakefile(
	'NAME'		=> 'Bundle::Slash',
	'VERSION_FROM'	=> 'Slash.pm',
	'clean'	=> {
		'FILES'	=> 'Bundle-Slash-*'
	},
	'NO_META'		=> 1,
);

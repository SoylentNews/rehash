package Slash::Apache::Shtml;
use ExtUtils::MakeMaker;

use Apache::ExtUtils;
use Apache::src ();

WriteMakefile(
	'NAME'	=> 'Slash::Apache::Shtml',
	'VERSION_FROM' => 'Shtml.pm',
	'INC'       => Apache::src->new->inc,
);

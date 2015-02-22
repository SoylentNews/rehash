package Slash::Apache;
use ModPerl::MM ();

#Kinda weird looking ain't it? -Brian

ModPerl::MM::WriteMakefile(
    'NAME'	=> 'Slash::Apache',
    'VERSION_FROM' => 'Apache.pm',
);

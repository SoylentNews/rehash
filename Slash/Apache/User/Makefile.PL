package Slash::Apache::User;
use ExtUtils::MakeMaker;

use Apache::ExtUtils qw (command_table);
use Apache::src ();

my @directives = (
	{ name      => 'SlashEnableENV',
		errmsg      => 'Takes a flag that is either on or off (off by default)',
		args_how    => 'FLAG',
		req_override => 'RSRC_CONF'
	},
	{ name      => 'SlashAuthAll',
		errmsg      => 'Takes a flag that is either on or off (off by default)',
		args_how    => 'FLAG',
		req_override => 'RSRC_CONF'
	}

);

command_table(\@directives);


WriteMakefile(
	'NAME'	=> 'Slash::Apache::User',
	'VERSION_FROM' => 'User.pm',
	'INC'       => Apache::src->new->inc,
);

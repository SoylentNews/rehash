package Slash::Apache;
use ExtUtils::MakeMaker;

#Kinda weird looking ain't it? -Brian

use Apache::ExtUtils qw (command_table);
use Apache::src ();
use Apache::Constants;

my @directives = (
	{ name			=> 'SlashVirtualUser',
	errmsg			=> 'Takes a DBIx::Password virtual name',
	args_how		=> 'TAKE1',
	req_overrive => 'ACCESS_CONF'
	},
	{ name			=> 'SlashSetVar',
	errmsg			=> 'Takes a key and a value that will override the var values in the DB',
	args_how		=> 'TAKE2',
	req_overrive => 'ACCESS_CONF'
	},
	{ name			=> 'SlashSetForm',
	errmsg			=> 'Takes a key and a value that will be applied to each form object',
	args_how		=> 'TAKE2',
	req_overrive => 'ACCESS_CONF'
	},
	{ name			=> 'SlashSetVarHost',
	errmsg			=> 'Takes a key, a value, and a hostname that will override the var values in the DB for a specific hostname',
	args_how		=> 'TAKE3',
	req_overrive => 'ACCESS_CONF'
	},
	{ name			=> 'SlashSetFormHost',
	errmsg			=> 'Takes a key, a value, and a hostname that will be applied to each form object for a specific hostname',
	args_how		=> 'TAKE3',
	req_overrive => 'ACCESS_CONF'
	},
	{ name			=> 'SlashCompileTemplates',
	errmsg			=> 'Turn precompiling templates on or off',
	args_how		=> 'FLAG',
	req_overrive => 'ACCESS_CONF'
	},
	{ name			=> 'SlashSectionHost',
	errmsg			=> 'Associate a host with a given section name',
	args_how		=> 'TAKE2',
	req_overrive => 'ACCESS_CONF'
	}
);

command_table(\@directives);

WriteMakefile(
    'NAME'	=> 'Slash::Apache',
    'VERSION_FROM' => 'Apache.pm',
    'INC'	=> Apache::src->new->inc, 
);

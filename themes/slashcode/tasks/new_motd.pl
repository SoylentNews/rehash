#!/usr/bin/perl -w

use strict;

use Slash::Constants ':slashd';

use vars qw( %task $me );

$task{$me}{timespec} = '12 * * * *';
$task{$me}{timespec_panic_1} = ''; # not important
$task{$me}{code} = sub {

	my($virtual_user, $constants, $slashdb, $user) = @_;

	return unless -x '/usr/games/fortune';
	chomp(my $t = `/usr/games/fortune -s`);

	if ($t) {
		my $tpid = $slashdb->getTemplateByName("motd", "tpid");
		$slashdb->setTemplate($tpid, { template => $t });
	}

	return ;
};

1;


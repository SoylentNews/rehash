#!/usr/bin/perl -w

use strict;

use vars qw( %task $me );

$task{$me}{timespec} = '37 * * * *';
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{code} = sub {

	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $portald = "$constants->{sbindir}/portald";
	if (-e $portald and -x _) {
		system("$portald $virtual_user");
	} else {
		slashdLog("$me cannot find $portald or not executable");
	}

	return ;
};

1;


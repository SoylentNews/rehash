#!/usr/bin/perl -w

use strict;

use Slash::Constants ':slashd';

use vars qw( %task $me );

$task{$me}{timespec} = '56 0-23/2 * * *';
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{code} = sub {

	my($virtual_user, $constants, $slashdb, $user) = @_;
	my $args = "ssi=yes virtual_user=$virtual_user";

	my $bd = $constants->{basedir}; # convenience
	for my $name (qw( hof topics authors )) {
		prog2file(
			"$bd/$name.pl", 
			"$bd/$name.shtml", {
				args =>		$args,
				verbosity =>	verbosity(),
				handle_err =>	0
		});
	}

	return ;
};

1;


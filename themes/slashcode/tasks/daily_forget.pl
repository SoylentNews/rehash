#!/usr/bin/perl -w

use strict;

use vars qw( %task $me );

$task{$me}{timespec} = '2 7 * * *';
$task{$me}{timespec_panic_1} = ''; # if panic, this can wait
$task{$me}{code} = sub {
	my($virtualuser, $constants, $slashdb, $user) = @_;
	my $forgotten = $slashdb->forgetCommentIPs();
	return "approx $forgotten forgotten";
};

1;


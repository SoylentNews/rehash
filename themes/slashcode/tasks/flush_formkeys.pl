#!/usr/bin/perl -w

use strict;
use Slash;
my $me = 'flush_formkeys.pl';

use vars qw( %task );

$task{$me}{timespec} = '3 * * * *';
$task{$me}{timespec_panic_1} = ''; # this can wait, hopefully not wait too long
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	$slashdb->deleteOldFormkeys($constants->{formkey_timeframe});
};

1;

#!/usr/bin/perl -w

use strict;

use vars qw( %task $me );

$task{$me}{timespec} = '50 0,6,12,18 * * *';
$task{$me}{timespec_panic_1} = ''; # if panic, we can wait
$task{$me}{on_startup} = 1;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	$slashdb->refreshUncommonStoryWords();
};

1;


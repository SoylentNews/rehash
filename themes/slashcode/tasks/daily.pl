#!/usr/bin/perl -w

use strict;

use vars qw( %task $me );

# Remember that timespec goes by the database's time, which should be
# GMT if you installed everything correctly.  So 2:00 AM GMT is a good
# sort of midnightish time for the Western Hemisphere.  Adjust for
# your audience and admins.
$task{$me}{timespec} = '0 2 * * *';
$task{$me}{timespec_panic_2} = ''; # if major panic, dailyStuff can wait
$task{$me}{code} = sub {

	my($virtual_user, $constants, $slashdb, $user) = @_;

	system("$constants->{sbindir}/dailyStuff $virtual_user &");

	return ;
};

1;


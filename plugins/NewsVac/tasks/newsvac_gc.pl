#!/usr/bin/perl -w
#
# $Id$
#
# SlashD Task (c) OSDN 2001
#
# Description: Performs garbage collection on NewsVac data.
#

use strict;

use vars qw( %task $me );

# We run spiders, periodically depending 
# on this cron timespec.
$task{$me}{timespec} = '5 4 * * Sat,Sun';	# @ 4:05am on the weekends.

$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $oldPage = $user->{currentPage};
	$user->{currentPage} = 'newsvac';

	# Get our plugin.
	my $newsvac = getObject('Slash::NewsVac');
	slashdLogDie("NewsVac Plugin failed to load, correctly!") 
		unless $newsvac;

	# Count out the pieces of trash.
	my @init = (
		$slashdb->sqlCount('url_info'), 
		$slashdb->sqlCount('rel'),
		$slashdb->sqlCount('url_message_body')
	);

	# Now take out the garbage.
	$newsvac->garbage_collect();

	# How much is left?
	my @fin = (
		$slashdb->sqlCount('url_info'), 
		$slashdb->sqlCount('rel'),
		$slashdb->sqlCount('url_message_body')
	);

	$user->{currentPage} = $oldPage;

	return sprintf <<EOT, map { $_ = $init[$_] - $fin[$_]; } (0 .. $#fin);
Garbage collection completed. Cleaned %d urls, %d rels and %d mbs.
EOT


};



1;

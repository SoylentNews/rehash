#!/usr/bin/perl -w

use strict;
use Slash::Constants qw( :messages :slashd :people );
use Slash::Display;

use vars qw( %task $me );

# Rewritten
$task{$me}{timespec} = '27 * * * *';
$task{$me}{timespec_panic_2} = ''; # if major panic, dailyStuff can wait
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;
	my($friends_cache, @deletions);

	my $zoo = getObject('Slash::Zoo');

	my @today = localtime();
	my $today = sprintf "%4d-%02d-%02d", 
		$today[5] + 1900, $today[4] + 1, $today[3];

	my $stats = getObject('Slash::Stats::Writer', '', { day => $today  });
	$stats->createStatDaily("zoo_counts", "0");	

	slashdLog('Zoo fof/eof Begin');
	my $people = $zoo->getZooUsersForProcessing();
	slashdLog('Zoo fof/eof Processing ' . scalar(@$people) . ' people');
	# Each job represents someone who has added or removed someone as a friend/foe. -Brian
	for my $person (@$people) {
		my $new_people = $zoo->rebuildUser($person);
		$slashdb->setUser($person, { people => $new_people, people_status => 'ok'});
	}
	$stats->updateStatDaily("zoo_counts", "value+" . @$people);	
	slashdLog('Zoo fof/eof End');

	return ;
};

1;

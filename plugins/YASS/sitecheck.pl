#!/usr/local/bin/perl -w

use strict;
use LWP::Simple;

use vars qw( %task $me );

# Remember that timespec goes by the database's time, which should be
# GMT if you installed everything correctly.  So 6:07 AM GMT is a good
# sort of midnightish time for the Western Hemisphere.  Adjust for
# your audience and admins.
$task{$me}{timespec} = '7 6 * * *';
$task{$me}{timespec_panic_2} = ''; # if major panic, dailyStuff can wait
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;
	my($stats, $backupdb);

	my $yass = getObject('Slash::YASS');

	unless($yass) {
		slashdLog('No database to run sitecheck against');
		return;
	}

	slashdLog('Checking YASS sites Begin');
	my $sids = $yass->getSidsURLs();
	for (@$sids) {
		my $value = $yass->exists($_->[0], $_->[1]);
		if ($value == 1) {
		} elsif ($value) {
			my $rdf = $slashdb->getStory($_->[0], 'rdf');
			$yass->setURL($value, $_->[1], $rdf);
		} else {
			my $rdf = $slashdb->getStory($_->[0], 'rdf');
			my $time = $slashdb->getStory($_->[0], 'time');
			$yass->create({
										 sid => $_->[0],
										 url => $_->[1],
										 rdf => $rdf,
										 created => $time,
										 });
		}
	}
#	my $junk;
#	for (@$sids) {
#		if(is_success(getstore($_->[0] . "/index.pl", $junk)))	{
#			$slashdb->setStory($_->[1], { active => 'yes'});
#			print "active\t$_->[0]\n";
#		} else {
#			$slashdb->setStory($_->[1], { active => 'no'});
#			print "dead\t$_->[0]\n";
#		}
#	}
	slashdLog('Checking YASS sites End');

	return ;
};

1;


#!/usr/bin/perl -w

use strict;
use LWP::UserAgent;

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

	unless ($yass) {
		slashdLog('No database to run sitecheck against');
		return;
	}

	slashdLog('Checking YASS sites Begin');
	my $sids = $yass->getSidsURLs();
	for (@$sids) {
		print "checking \t$_->[1]\n";
		my $value = $yass->exists($_->[0], $_->[1]);
		if ($value == 1) {
			print "\texists\n";
		} elsif ($value) {
			my $rdf = $slashdb->getStory($_->[0], 'rdf');
			$yass->setURL($value, $_->[1], $rdf);
			print "\tupdating\n";
		} else {
			my $rdf = $slashdb->getStory($_->[0], 'rdf');
			my $time = $slashdb->getStory($_->[0], 'time');
			my $return = $yass->create({
				 sid => $_->[0],
				 url => $_->[1],
				 rdf => $rdf ? $rdf : '',
				 created => $time,
			 });
			print "\tadding\n";
		}
	}
	my $sites = $yass->getActive();
	my $junk;
	my $ua = LWP::UserAgent->new();
	my($winners, $losers);
	for (@$sites) {
		print "$_->{id}\t$_->{url}";
		my $response = $ua->get($_->{url} . $constants->{yass_extra});
		if ($response->is_success) {
			$yass->success($_->{id});
			print "\tactive\n";
			$winners++;
		} else {
			$yass->failed($_->{id});
			print "\tdead\n";
			$losers++;
		}
	}
	my $total = $winners + $losers;
	slashdLog("Total sites $total\tActive Sites $winners\tFailed sites $losers");
	slashdLog('Checking YASS sites End');

	return ;
};

1;


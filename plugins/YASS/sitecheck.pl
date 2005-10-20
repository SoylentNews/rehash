#!/usr/bin/perl -w

# $Id$

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
	for my $duple (@$sids) {
		my($sid, $url) = @$duple;
		my $logentry;
		$logentry = "checking sid='$sid' url='$url'...";
		my $value = $yass->exists($sid, $url);
		if ($value == -1) {
			$logentry .= " ok.";
		} elsif ($value) {
			my $rdf = $slashdb->getStory($sid, 'rdf');
			$yass->setURL($value, $url, $rdf);
			$logentry .= " updated.";
		} else {
			my $rdf = $slashdb->getStory($sid, 'rdf');
			my $time = $slashdb->getStory($sid, 'time');
			my $return = $yass->create({
				 sid => $sid,
				 url => $url,
				 rdf => $rdf ? $rdf : '',
				 created => $time,
			});
			$logentry .= " added.";
		}
		slashdLog($logentry);
	}
	my $sites = $yass->getActive();
	my $junk;
	my $ua = LWP::UserAgent->new();
	my($winners, $losers);
	for my $hr (@$sites) {
		my $logentry;
		$logentry = "checking id=$hr->{id} url='$hr->{url}'...";
		my $response = $ua->get($hr->{url} . $constants->{yass_extra});
		if ($response->is_success) {
			$yass->success($hr->{id});
			$logentry .= " active.";
			$winners++;
		} else {
			$yass->failed($hr->{id});
			$logentry .= " dead.";
			$losers++;
		}
		slashdLog($logentry);
	}
	my $total = $winners + $losers;
	slashdLog('Checking YASS sites End');

	return "$total sites, $winners active, $losers dead";
};

1;


#!/usr/bin/perl -w

use strict;
use Slash::Constants qw( :messages :slashd );
use Slash::Display;

use vars qw( %task $me );

# We have no transactions going on in here so the information is not 100% correct -Brian
$task{$me}{timespec} = '27 * * * *';
$task{$me}{timespec_panic_2} = ''; # if major panic, dailyStuff can wait
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;
	my($friends_cache, @deletions);

	my $zoo = getObject('Slash::Zoo');

	slashdLog('Zoo fof/eof Begin');
	for (1..$constants->{zoo_process_limit}) {
		my $jobs = $zoo->getZooJobs(1);
		for my $job (@$jobs) {
			my $friends = $friends_cache->{$job->{uid}} ? $friends_cache->{$job->{uid}} : $zoo->getFriendsConsideredUIDs($job->{uid});
			for(@$friends) {
				if ($job->{type} eq 'friend') {
					if ($job->{action} eq 'add') {
						$zoo->addFof($_, $job->{person}, $job->{uid});
					} else {
						$zoo->deleteFof($_, $job->{person}, $job->{uid});
					}
				} else {
					if ($job->{action} eq 'add') {
						$zoo->addEof($_, $job->{person}, $job->{uid});
					} else {
						$zoo->deleteEof($_, $job->{person}, $job->{uid});
					}
				}
			}
			$zoo->deleteZooJobs($job->{id})
		}
	}
	slashdLog('Zoo fof/eof End');

	return ;
};

1;

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
	my $jobs = $zoo->getZooJobs($constants->{zoo_process_limit});
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
		push @deletions, $job->{id};
	}
	$zoo->deleteZooJobs(\@deletions)
		if @deletions;
	slashdLog('Zoo fof/eof End');

	return ;
};

1;

#!/usr/bin/perl -w

use strict;

use File::Path;
use Slash::Constants ':slashd';

use vars qw( %task $me );

my $total_freshens = 0;

$task{$me}{timespec} = '1-59/3 * * * *';
$task{$me}{timespec_panic_1} = '1-59/10 * * * *';
$task{$me}{timespec_panic_2} = '';
$task{$me}{on_startup} = 1;
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;
	my %updates;
	return 0
		unless $constants->{rss_store};

	my @time_long_ago = localtime(time-86400*$constants->{rss_expire_days});
	my $weekago = sprintf "%4d-%02d-%02d", 
		$time_long_ago[5] + 1900, $time_long_ago[4] + 1, $time_long_ago[3];

	my $added_submissions = 0;
	# First, we grab as many possible submissions as possible
	my $rss = $slashdb->getRSSNotProcessed($constants->{rss_process_number});
	for my $rss (@$rss) {
		my $subid;
		my $block = $slashdb->getBlock($rss->{bid});
		my $description = $rss->{description} ? $rss->{description} : $rss->{title};
		if ($block->{'autosubmit'} eq 'yes') {
			print "getting rss\ntitle $rss->{title}\ndescription\n$description\n";
			my $submission = {
				email	=> $rss->{link},
				name	=> $block->{title},
				story	=> $description,
				subj	=> $rss->{title},
				section	=> $block->{section},
			};
			$subid = $slashdb->createSubmission($submission);
			$added_submissions++;
		}
		$slashdb->setRSS($rss->{id}, { processed => 'yes', subid => $subid });	
	}

	$slashdb->expireRSS($constants->{rss_process_number});

	return $added_submissions ?
		"totaladded Submissions $added_submissions" : '';
};

1;

#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

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
	my $non_autosubmit = 0;
	# First, we grab as many submissions as possible
	my $rss_ar = $slashdb->getRSSNotProcessed($constants->{rss_process_number});
	my $num_not_processed = $rss_ar ? scalar(@$rss_ar) : 0;
	for my $rss (@$rss_ar) {
		my $subid;
		my $block = $slashdb->getBlock($rss->{bid});
		my $description = $rss->{description} ? $rss->{description} : $rss->{title};
		if ($block->{autosubmit} eq 'no') {
			++$non_autosubmit;
		} else {
			my $blockskin = $slashdb->getSkin($block->{skin});
			my $submission = {
				email	=> $rss->{link},
				name	=> $block->{title},
				story	=> $description,
				subj	=> $rss->{title},
				primaryskid => $blockskin->{skid},
			};
			$subid = $slashdb->createSubmission($submission);
			if (!$subid) {
				slashdLog("failed to createSubmission, rss title '$rss->{title}' from bid '$block->{bid}'");
			} else {
				$added_submissions++;
			}
		}
		$slashdb->setRSS($rss->{id}, { processed => 'yes', subid => $subid });	
	}

	$slashdb->expireRSS($constants->{rss_process_number});

	my $ret = "";
	if ($added_submissions || $non_autosubmit) {
		$ret = "totaladded Submissions $added_submissions; non-autosubmits $non_autosubmit; of $num_not_processed not processed";
	}
	return $ret;
};

1;

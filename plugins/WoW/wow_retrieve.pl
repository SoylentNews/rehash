#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2009 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

use strict;

use Slash;
use Slash::Constants ':slashd';

use vars qw(
	%task	$me	$task_exit_flag
	$last_retrieval
);

$task{$me}{timespec} = '* * * * *';
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;

	my $wowdb = getObject("Slash::WoW");
	if (!$wowdb) {
		main::slashdLog('WoW apparently not installed, sleeping permanently');
		sleep 5 while !$task_exit_flag;
		return ;
	}

	my $num_retrievals = 0;
	while (!$task_exit_flag) {
		my $charids_ar = $wowdb->getCharidsNeedingRetrieval();
		for my $id (@$charids_ar) {
			sleep_until_next_retrieval();
			last if $task_exit_flag;
			my($armory_hr, $raw_content) = $wowdb->retrieveArmoryData($id);
			sleep 30 if !$armory_hr; # if the armory is down, slow down requests
			$last_retrieval = Time::HiRes::time;
			if ($armory_hr) {
				$wowdb->logArmoryData($id, $armory_hr, $raw_content);
				++$num_retrievals;
			}
			main::slashdLog("char $id retrieval " . ($armory_hr ? 'succeeded' : 'failed'));
		}
		sleep 3;
	}
	return "$num_retrievals successful retrievals";
};

sub sleep_until_next_retrieval {
	$last_retrieval ||= 0;
	return if !$last_retrieval;
	my $constants = getCurrentStatic();
	my $sleep_until = $last_retrieval + ($constants->{wow_retrieval_pause} || 3);
	while (time < $sleep_until) {
		return if $task_exit_flag;
		my $minisleep_time = $sleep_until - Time::HiRes::time;
		$minisleep_time = 9 if $minisleep_time > 10;
		$minisleep_time = 0 if $minisleep_time < 0;
		last if $minisleep_time < 0.002;
		Time::HiRes::sleep($minisleep_time);
	}
}

1;


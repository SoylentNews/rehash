#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash::Utility;
use Slash::Constants qw( :messages :slashd );

use vars qw( %task $me $task_exit_flag );

$task{$me}{timespec} = '28 0-23 * * *';
$task{$me}{timespec_panic_1} = '';
$task{$me}{resource_locks} = { log_slave => 1, moderatorlog => 1 };
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {

	my($virtual_user, $constants, $slashdb, $user) = @_;

	if (!$constants->{m1} || $constants->{m1_pluginname} ne 'Moderation') {
		slashdLog("$me - Moderation inactive") if verbosity() >= 2;
		return ;
	}

	give_out_points();
	delete_old_mod_rows();

	return ;
};

############################################################

sub moderatordLog {
	doLog('slashd', \@_);
}

sub give_out_points {
	my $constants = getCurrentStatic();
	my $moddb = getObject('Slash::Moderation');

	moderatordLog(getData('moderatord_log_header'));

	my $newcomments = get_num_new_comments();
	if ($newcomments > 0) {

		# Here are the two functions that actually do the work.

		my $needed = give_out_tokens($newcomments);
		my $granted = $moddb->convert_tokens_to_points($needed);

		# Log what we did and tally it up in stats.
		my @lt = localtime();
		my $today = sprintf "%4d-%02d-%02d", $lt[5] + 1900, $lt[4] + 1, $lt[3];
		my @grantees = sort { $a <=> $b }
			grep { $granted->{$_} == 1 }
			keys %$granted;
		my $n_grantees = scalar @grantees;
		slashdLog("Giving points to $n_grantees users: '@grantees'");

		# Store stats about what we just did.
		if ($n_grantees and my $statsSave = getObject('Slash::Stats::Writer')) {
			my $maxpoints = $constants->{maxpoints} || 5;
			my $points_gained = $n_grantees * $maxpoints;
			$statsSave->addStatDaily("mod_points_gain_granted",
				$points_gained);
			# Reverse-engineer how many tokens that was.
			my $tokperpt = $constants->{tokensperpoint} || 8;
			my $tokens_converted = $points_gained * $tokperpt;
			$statsSave->addStatDaily("mod_tokens_lost_converted",
				$tokens_converted);
		}
	}

	moderatordLog(getData('moderatord_log_footer'));

}

sub get_num_new_comments {
	my $slashdb = getCurrentDB();

	my $tc = $slashdb->getVar('totalComments', 'value', 1);
	my $lc = $slashdb->getVar('lastComments', 'value', 1);

	# Maybe we should think about adding in a minimum
	# value here which would affect the minimum # of
	# tokens/points distributed per execution. It would
	# be a way of injecting a certain amount of points
	# into the system without requiring the need to have
	# comments. Something a site admin might want to
	# consider with a small pool of moderators...
	#
	# $newcomments += $constants->{moderatord_minnewcomments}
	# $newcomments += $constants->{moderatord_mintokens} /
	#				 $constants->{tokenspercomment}
	#
	# - 5/8/01 Cliff (attempting to make sense of old Slash comments)

	my $newcomments = $tc - $lc;
	moderatordLog("newcomments: $newcomments");
	$slashdb->setVar('lastComments', $tc) if $newcomments;

	return $newcomments;
}

sub give_out_tokens {
	my($comments) = @_;
	my $constants = getCurrentStatic();
	my $moddb = getObject('Slash::Moderation');
	my $mod_reader = getObject('Slash::Moderation', { db_type => 'reader' });
	my $log_reader = getObject('Slash::Moderation', { db_type => 'log_slave' });
	my $statsSave = getObject('Slash::Stats::Writer', '');

	my $needed = 0;

	my $tokperpt = $constants->{tokensperpoint} || 8;
	my $maxpoints = $constants->{maxpoints} || 5;

	my $num_tokens = $comments * $constants->{tokenspercomment};
	$statsSave->addStatDaily("mod_tokens_gain_clicks_random", $num_tokens);
	my $stirredpoints = $moddb->stirPool();
	my $recycle_fraction = $constants->{mod_stir_recycle_fraction} || 1.0;
	my $recycled_tokens = int($stirredpoints * $tokperpt * $recycle_fraction + 0.5);
	$num_tokens += $recycled_tokens;

	if ($stirredpoints and my $statsSave = getObject('Slash::Stats::Writer')) {
		$statsSave->addStatDaily("mod_points_lost_stirred", $stirredpoints);
		# Unfortunately, we reverse-engineer how many tokens
		# were lost in the stirring.
		$statsSave->addStatDaily("mod_tokens_lost_stirred", $stirredpoints * ($constants->{mod_stir_token_cost}||0));
		$statsSave->addStatDaily("mod_tokens_gain_clicks_stirred", $num_tokens);
	}

	# fetchEligibleModerators() returns a list of uids sorted in the
	# order of how many clicks each user has made, from the minimum
	# (the var m1_eligible_hitcount) up to however many the most
	# clicks is.  At some time in the future, it might be interesting
	# to weight token assignment by click count, but for now we just
	# chop off the top and bottom and assign tokens randomly to
	# whoever's left in the middle.
	# Note:  this is a large array -- on Slashdot, at least tens of
	# thousands of elements.

	my $count_hr = $log_reader->fetchEligibleModerators_accesslog_read();

	my @eligible_uids = @{$mod_reader->fetchEligibleModerators_users($count_hr)};
	my $eligible = scalar @eligible_uids;

	if (!$eligible) {
		# Don't hand out any tokens, and don't give any points.
		return 0;
	}

	# Chop off the least and most clicks.
	my $start = int(($eligible-1) * $constants->{m1_pointgrant_start});
	my $end   = int(($eligible-1) * $constants->{m1_pointgrant_end});
	@eligible_uids = @eligible_uids[$start..$end];

	# Pull off some useful data for logging tidbits.
	my $startuid = $eligible_uids[0][0];
	my $enduid = $eligible_uids[-1][0];
	my $least = $eligible_uids[0][1];
	my $most = $eligible_uids[-1][1];
	my %info = ( );

	# Ignore count now, we only want uid.
	@eligible_uids = map { $_ = $_->[0] } @eligible_uids;

	# If the appropriate vars are set, give tokens preferentially to
	# users who are better-qualified to have them.
	my $wtf = { };
	$wtf->{upfairratio} = $constants->{m1_pointgrant_factor_upfairratio} || 0;
	$wtf->{downfairratio} = $constants->{m1_pointgrant_factor_downfairratio} || 0;
	$wtf->{fairtotal} = $constants->{m1_pointgrant_factor_fairtotal} || 0;
	$wtf->{stirratio} = $constants->{m1_pointgrant_factor_stirratio} || 0;
	if ($wtf->{fairratio} || $wtf->{fairtotal} || $wtf->{stirratio}) {
		my @orig_uids = @eligible_uids;
		@eligible_uids = @{$mod_reader->factorEligibleModerators(
			\@orig_uids, $wtf, \%info)
		};
	}

	# Decide who's going to get the tokens.
	my $maxtokens_add = $constants->{maxtokens_add} || 3;
	my %update_uids = ( );
	for (my $x = 0; $x < $num_tokens; $x++) {
		my $uid = $eligible_uids[rand @eligible_uids];
		next if ($update_uids{$uid} ||= 0) >= $maxtokens_add;
		$update_uids{$uid}++;
	}
	my $n_update_uids = scalar(keys %update_uids);

	# Log info about what we're about to do.
	moderatordLog(getData('moderatord_tokenmsg', {
		new_comments	=> $comments,
		stirredpoints	=> $stirredpoints,
		last_user	=> $mod_reader->countUsers({ max => 1}),
		num_tokens	=> $num_tokens,
		recycled_tokens	=> $recycled_tokens,
		eligible	=> $eligible,
		start		=> $start,
		end		=> $end,
		startuid	=> $startuid,
		enduid		=> $enduid,
		least		=> $least,
		most		=> $most,
		num_updated	=> $n_update_uids,
		factor_lowest	=> sprintf("%.3f", $info{factor_lowest} || 0),
		factor_highest	=> sprintf("%.3f", $info{factor_highest} || 0),
	}));

	# Give each user her or his tokens.
	my $sleep_time = $constants->{mod_token_assignment_delay} || 2;
	$moddb->updateTokens(\%update_uids, { sleep_time => $sleep_time });

	# And keep a running tally of how many tokens we've given out due
	# to users who clicked the right number of times and got lucky.
	$statsSave->addStatDaily("mod_tokens_gain_clicks", $n_update_uids);

	# We need to return the number of users we should give points to.
	# If fractional, round up or down randomly (so if a site gives out
	# 1 token each time, each time there will be a 1 in 40 chance that
	# someone will get them cashed in for points).
	return int($n_update_uids / ($tokperpt*$maxpoints) + rand(1));
}

sub delete_old_mod_rows {
	my $moddb = getObject('Slash::Moderation');
	$moddb->deleteOldModRows({ sleep_between => 30 });
}

1;


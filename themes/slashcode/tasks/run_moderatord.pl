#!/usr/bin/perl -w
#
# $Id$
# 
# This task is called run_moderatord for historical reasons;  it used
# to run a separate script called "moderatord" but now is contained
# all in this task script.

use strict;

use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants qw(:messages);
use Slash::DB;
use Slash::Utility;
use Slash::Constants ':slashd';
use Data::Dumper;

use vars qw( %task $me );

$task{$me}{timespec} = '18 0-23 * * *';
$task{$me}{timespec_panic_1} = '18 0-10/2 * * *';	# night only
$task{$me}{timespec_panic_2} = '';			# don't run
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {

	my($virtual_user, $constants, $slashdb, $user) = @_;

	if (! $constants->{allow_moderation}) {
		slashdLog("$me - moderation inactive") if verbosity() >= 2;
		return ;
	}

#	doLogInit('moderatord');

	update_modlog_ids($virtual_user, $constants, $slashdb, $user);
	give_out_points($virtual_user, $constants, $slashdb, $user);
	reconcile_m2($virtual_user, $constants, $slashdb, $user);
	update_modlog_ids($virtual_user, $constants, $slashdb, $user);

#	doLogExit('moderatord');

	return ;
};

############################################################

sub moderatordLog {
#	doLog('moderatord', \@_);
	doLog('slashd', \@_);
}

sub update_modlog_ids {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $days_back = $constants->{archive_delay_mod};
	my $days_back_cushion = int($days_back/10);
	$days_back_cushion = $constants->{m2_min_daysbackcushion} || 2
		if $days_back_cushion < ($constants->{m2_min_daysbackcushion} || 2);
	$days_back -= $days_back_cushion;

	# XXX I'm considering adding a 'WHERE m2status=0' clause to the
	# MIN/MAX selects below.  This might help choose mods more
	# smoothly and make failure (as archive_delay_mod is approached)
	# less dramatic too.  On the other hand it might screw things
	# up, making older mods at N-1 M2's never make it to N.  I've
	# run tests on changes like this before and there's almost no
	# way to predict accurately what it will do on a live site
	# without doing it... -Jamie 2002/11/16

	my($min_old) = $slashdb->sqlSelect("MIN(id)", "moderatorlog");
	my($max_old) = $slashdb->sqlSelect("MAX(id)", "moderatorlog",
		"ts < DATE_SUB(NOW(), INTERVAL $days_back DAY)");
	$min_old = 0 if !$min_old;
	$max_old = 0 if !$max_old;
	my($min_new) = $slashdb->sqlSelect("MIN(id)", "moderatorlog",
		"ts >= DATE_SUB(NOW(), INTERVAL $days_back_cushion DAY)");
	my($max_new) = $slashdb->sqlSelect("MAX(id)", "moderatorlog");
	$min_new = 0 if !$min_new;
	$max_new = 0 if !$max_new;

	$slashdb->setVar("m2_modlogid_min_old", $min_old);
	$slashdb->setVar("m2_modlogid_max_old", $max_old);
	$slashdb->setVar("m2_modlogid_min_new", $min_new);
	$slashdb->setVar("m2_modlogid_max_new", $max_new);
}

sub give_out_points {

	my($virtual_user, $constants, $slashdb, $user) = @_;

	moderatordLog(getData('moderatord_log_header'));

	my $backup_db = getObject('Slash::DB', { db_type => 'reader' });
	my $log_db = getObject('Slash::DB', 'log_slave');

	my $newcomments = get_num_new_comments($constants, $slashdb);
	if ($newcomments > 0) {

		# Here are the two functions that actually do the work.

		my $needed = give_out_tokens($newcomments, $constants,
			$slashdb, $backup_db, $log_db);
		my $granted = $slashdb->convert_tokens_to_points($needed);

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
	my($constants, $slashdb) = @_;

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
	my($comments, $constants, $slashdb, $backup_db, $log_db) = @_;
	$backup_db = $slashdb if !defined($backup_db);
	$log_db = $slashdb if !defined($log_db);
	my $statsSave = getObject('Slash::Stats::Writer', '');

	my $needed = 0;

	my $tokperpt = $constants->{tokensperpoint} || 8;
	my $maxpoints = $constants->{maxpoints} || 5;

	my $num_tokens = $comments * $constants->{tokenspercomment};
	$statsSave->addStatDaily("mod_tokens_gain_clicks_random", $num_tokens);
	my $stirredpoints = $slashdb->stirPool();
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

	my $count_hr = $log_db->fetchEligibleModerators_accesslog();
	my @eligible_uids = @{$backup_db->fetchEligibleModerators_users($count_hr)};
	my $eligible = scalar @eligible_uids;

	# Chop off the least and most clicks.
	my $start = int($eligible * $constants->{m1_pointgrant_start});
	my $end   = int($eligible * $constants->{m1_pointgrant_end});
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
	$wtf->{fairratio} = $constants->{m1_pointgrant_factor_fairratio} || 0;
	$wtf->{fairtotal} = $constants->{m1_pointgrant_factor_fairtotal} || 0;
	$wtf->{stirratio} = $constants->{m1_pointgrant_factor_stirratio} || 0;
	if ($wtf->{fairratio} || $wtf->{fairtotal} || $wtf->{stirratio}) {
		my @orig_uids = @eligible_uids;
		@eligible_uids = @{$backup_db->factorEligibleModerators(
			\@orig_uids, $wtf, \%info)
		};
	}

	# Decide who's going to get the tokens.
	my %update_uids = ( );
	for (my $x = 0; $x < $num_tokens; $x++) {
		my $uid = $eligible_uids[rand @eligible_uids];
		$update_uids{$uid} = 1;
	}
	my @update_uids = sort keys %update_uids;
	my $n_update_uids = scalar(@update_uids);

	# Log info about what we're about to do.
	moderatordLog(getData('moderatord_tokenmsg', {
		new_comments	=> $comments,
		stirredpoints	=> $stirredpoints,
		last_user	=> $backup_db->countUsers({ max => 1}),
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
	$slashdb->updateTokens(\@update_uids);

	# And keep a running tally of how many tokens we've given out due
	# to users who clicked the right number of times and got lucky.
	$statsSave->addStatDaily("mod_tokens_gain_clicks", $n_update_uids);

	# We need to return the number of users we should give points to.
	# If fractional, round up or down randomly (so if a site gives out
	# 1 token each time, each time there will be a 1 in 40 chance that
	# someone will get them cashed in for points).
	return int($n_update_uids / ($tokperpt*$maxpoints) + rand(1));
}

############################################################

sub reconcile_m2 {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $consensus = $constants->{m2_consensus};
	my $reasons = $slashdb->getReasons();
	my $sql;

	# %m2_results is a hash whose keys are uids.  Its values are
	# hashrefs with the keys "change" (an int) and "m2" (an array of
	# hashrefs with values title, url, subject, vote, reason).
	my %m2_results = ( );

	# We load the optional plugin object here.
	my $messages = getObject('Slash::Messages');
	my $statsSave = getObject('Slash::Stats::Writer');

	# $mod_ids is an arrayref of moderatorlog IDs which need to be
	# reconciled.
	my $mods_ar = $slashdb->getModsNeedingReconcile();

	my %newstats = ( );
	for my $mod_hr (@$mods_ar) {

		# Get data about every M2 done to this moderation.
		my $m2_ar = $slashdb->getMetaModerations($mod_hr->{id});

		my $nunfair = scalar(grep { $_->{active} && $_->{val} == -1 } @$m2_ar);
		my $nfair   = scalar(grep { $_->{active} && $_->{val} ==  1 } @$m2_ar);

		# Sanity-checking... what could go wrong?
		if (!$mod_hr->{uid}) {
			print STDERR "no uid in \$mod_hr: " . Dumper($mod_hr);
			next;
		}
		if ($nunfair+$nfair == 0) {
			print STDERR "M2 fair,unfair both 0 for mod id $mod_hr->{id}\n";
			next;
		}
		if (($nunfair+$nfair) % 2 == 0) {
			print STDERR "M2 fair+unfair=" . ($nunfair+$nfair) . ","
				. " consensus=$consensus"
				. " for mod id $mod_hr->{id}\n";
		}

		my $winner_val = 0;
		   if ($nfair > $nunfair) {	$winner_val =  1 }
		elsif ($nunfair > $nfair) {	$winner_val = -1 }
		my $fair_frac = $nfair/($nunfair+$nfair);

		# Get the token and karma consequences of this vote.
		# This uses a complex algorithm to return a fairly
		# complex data structure but at least its fields are
		# named reasonably well.
		my $csq = $slashdb->getM2Consequences($fair_frac);

		# First update the moderator's tokens.
		my $use_possible = $csq->{m1_tokens}{num}
			&& rand(1) < $csq->{m1_tokens}{chance};
		$sql = $use_possible
			? $csq->{m1_tokens}{sql_possible}
			: $csq->{m1_tokens}{sql_base};
		if ($sql) {
			$slashdb->setUser(
				$mod_hr->{uid},
				{ -tokens => $sql },
				{ and_where => $csq->{m1_tokens}{sql_and_where} }
			);
			if ($statsSave) {
				my $token_change = $use_possible
					? $csq->{m1_tokens}{num_possible}
					: $csq->{m1_tokens}{num_base};
				if ($token_change > 0) {
					$newstats{mod_tokens_gain_m1fair} += $token_change;
				} elsif ($token_change < 0) {
					$newstats{mod_tokens_lost_m1unfair} -= $token_change;
				}
			}
		}

		# Now update the moderator's karma.
		$sql = ($csq->{m1_karma}{num}
				&& rand(1) < $csq->{m1_karma}{chance})
			? $csq->{m1_karma}{sql_possible}
			: $csq->{m1_karma}{sql_base};
		my $m1_karma_changed = 0;
		$m1_karma_changed = $slashdb->setUser(
			$mod_hr->{uid},
			{ -karma => $sql },
			{ and_where => $csq->{m1_karma}{sql_and_where} }
		) if $sql;

		# Now update the moderator's m2info.
		my $old_m2info = $slashdb->getUser($mod_hr->{uid}, 'm2info');
		my $new_m2info = add_m2info($old_m2info, $nfair, $nunfair);
		$slashdb->setUser(
			$mod_hr->{uid},
			{ m2info => $new_m2info }
		) if $new_m2info ne $old_m2info;

		# Now update the tokens of each M2'er.
		for my $m2 (@$m2_ar) {
			if (!$m2->{uid}) {
				print STDERR "no uid in \$m2: " . Dumper($m2);
				next;
			}
			my $key = "m2_fair_tokens";
			$key = "m2_unfair_tokens" if $m2->{val} == -1;
			my $use_possible = $csq->{$key}{num}
				&& rand(1) < $csq->{$key}{chance};
			$sql = $use_possible
				? $csq->{$key}{sql_possible}
				: $csq->{$key}{sql_base};
			if ($sql) {
				$slashdb->setUser(
					$m2->{uid},
					{ -tokens => $sql },
					{ and_where => $csq->{$key}{sql_and_where} }
				);
			}
			if ($statsSave) {
				my $token_change = $use_possible
					? $csq->{$key}{num_possible}
					: $csq->{$key}{num_base};
				if ($token_change > 0) {
					$newstats{mod_tokens_gain_m2majority} += $token_change;
				} elsif ($token_change < 0) {
					$newstats{mod_tokens_lost_m2minority} -= $token_change;
				}
			}
		}

		if ($statsSave) {
			my $reason_name = $reasons->{$mod_hr->{reason}}{name};
			$newstats{"m2_${reason_name}_fair"} += $nfair;
			$newstats{"m2_${reason_name}_unfair"} += $nunfair;
			$newstats{"m2_${reason_name}_${nfair}_${nunfair}"}++;
		}

		# Store data for the message we may send.
		if ($messages) {

			# Get discussion metadata without caching it.
			my $discuss = $slashdb->getDiscussion(
				$mod_hr->{sid}
			);

			# Get info on the comment.
			my $comment_subj = ($slashdb->getComments(
				$mod_hr->{sid}, $mod_hr->{cid}
			))[2];
			my $comment_url =
				fudgeurl(	# inserts scheme if necessary
					join("",
						$constants->{rootdir},
						"/comments.pl?sid=", $mod_hr->{sid},
						"&cid=", $mod_hr->{cid}
				)	);

			$m2_results{$mod_hr->{uid}}{change} ||= 0;
			$m2_results{$mod_hr->{uid}}{change} += $csq->{m1_karma}{sign}
				if $m1_karma_changed;

			push @{$m2_results{$mod_hr->{uid}}{m2}}, {
				title	=> $discuss->{title},
				url	=> $comment_url,
				subj	=> $comment_subj,
				vote	=> $winner_val,
				reason  => $reasons->{$mod_hr->{reason}}
			};
		}

		# This mod has been reconciled.
		$slashdb->sqlUpdate("moderatorlog", {
			-m2status => 2,
		}, "id=$mod_hr->{id}");

	}

	# Update stats to reflect all the token and M2-judgment
	# information we just learned.
	if ($statsSave) {
		for my $key (keys %newstats) {
			$statsSave->addStatDaily($key, $newstats{$key});
		}
	}

	# Optional: Send message to original moderator indicating that
	# metamoderation has occured.
	if ($messages && scalar(keys %m2_results)) {
		# Unfortunately, the template must be aware
		# of the valid states of $mod_hr->{val}, but
		# for default Slashcode (and Slashdot), this
		# isn't a problem.
		my $data = {
			template_name	=> 'msg_m2',
			template_page	=> 'messages',
			subject		=> {
				template_name	=> 'msg_m2_subj',
			},
		};

		# Sends the actual message, varying M2 results by user.
		for (keys %m2_results) {
			my $msg_user = 
				$messages->checkMessageCodes(MSG_CODE_M2, [$_]);
			if (@{$msg_user}) {
				$data->{m2} = $m2_results{$_}{m2};
				$data->{change} = $m2_results{$_}{change};
				$messages->create($_, MSG_CODE_M2, $data, 0, '', 'collective');
			}
		}
	}

}

sub add_m2info {
	my($old, $nfair, $nunfair) = @_;

	my @lt = localtime;
	my $thismonth = sprintf("%02d%02d", $lt[5] % 100, $lt[4]+1);
	my @old = split /\s*;\s*/, $old;
	my %val = ( );
	for my $item (@old, "$thismonth $nfair$nunfair") {
		my($date, $more) = $item =~ /^(\w+)\s+(.+)$/;
		$val{$date} = [ ] if !defined($val{$date});
		push @{$val{$date}}, $more;
	}
	my @combined = sort { $b cmp $a } keys %val;
	my $combined = "";
	for my $item (@combined) {
		$combined .= "; " if $combined;
		$combined .= "$item @{$val{$item}}";
		if (length($combined) > 63) {
			$combined = substr($combined, 0, 63);
			last;
		}
	}
	return $combined;
}

sub reconcile_stats {
	my($statsSave, $stats_created, $today,
		$reason, $nfair, $nunfair) = @_;
	return unless $statsSave;

	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $consensus = $constants->{m2_consensus};
	my $reasons = $slashdb->getReasons();
	my @reasons_m2able =
		sort map { $reasons->{$_}{name} }
		grep { $reasons->{$_}{m2able} }
		keys %$reasons;
	my $reason_name = $reasons->{$reason}{name};

	# Update the stats.

	# We could just use addStatDaily() for these values.  But
	# this function may be called many times (hundreds) in
	# quick succession and we will save many pointless
	# INSERT IGNOREs if we cache some information about which
	# values have already been added.

	# First create the rows if necessary.
	if (!$stats_created) {
		# Test... has this first item has been created
		# already today?
		$stats_created = 1 if $slashdb->sqlSelect(
			"id",
			"stats_daily",
			"day='$today'
			 AND name='m2_${reason_name}_fair'
			 AND section='all'"
		);
	}
	if (!$stats_created) {
		for my $r (@reasons_m2able) {
			$statsSave->createStatDaily("m2_${r}_fair", 0);
			$statsSave->createStatDaily("m2_${r}_unfair", 0);
			for my $f (0..$consensus) {
				$statsSave->createStatDaily(
					"m2_${r}_${f}_" . ($consensus-$f),
					0);
			}
		}
	}

	# Now increment the stats values appropriately.
	$statsSave->updateStatDaily(
		"m2_${reason_name}_fair",
		"value + $nfair") if $nfair;
	$statsSave->updateStatDaily(
		"m2_${reason_name}_unfair",
		"value + $nunfair") if $nunfair;
	$statsSave->updateStatDaily(
		"m2_${reason_name}_${nfair}_${nunfair}",
		"value + 1");
}

1;


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
$task{$me}{timespec_panic_1} = '18 1,10 * * *';		# night only
$task{$me}{timespec_panic_2} = '';			# don't run
$task{$me}{resource_locks} = { log_slave => 1 };
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {

	my($virtual_user, $constants, $slashdb, $user) = @_;

	if (! $constants->{allow_moderation}) {
		slashdLog("$me - moderation inactive") if verbosity() >= 2;
		return ;
	}

	update_modlog_ids($virtual_user, $constants, $slashdb, $user);
	give_out_points($virtual_user, $constants, $slashdb, $user);
	reconcile_m2($virtual_user, $constants, $slashdb, $user);
	update_modlog_ids($virtual_user, $constants, $slashdb, $user);
	mark_m2_oldzone($virtual_user, $constants, $slashdb, $user);
	adjust_m2_freq($virtual_user, $constants, $slashdb, $user) if $constants->{adjust_m2_freq};
	return ;
};

############################################################

sub moderatordLog {
	doLog('slashd', \@_);
}

sub update_modlog_ids {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $reader = getObject("Slash::DB", { db_type => "reader" });
	my $days_back = $constants->{archive_delay_mod};
	my $days_back_cushion = int($days_back/10);
	$days_back_cushion = $constants->{m2_min_daysbackcushion} || 2
		if $days_back_cushion < ($constants->{m2_min_daysbackcushion} || 2);
	$days_back -= $days_back_cushion;

	my $reasons = $reader->getReasons();
	my $m2able_reasons = join(",",
	       sort grep { $reasons->{$_}{m2able} }
	       keys %$reasons);
	return if !$m2able_reasons;

	# XXX I'm considering adding a 'WHERE m2status=0' clause to the
	# MIN/MAX selects below.  This might help choose mods more
	# smoothly and make failure (as archive_delay_mod is approached)
	# less dramatic too.  On the other hand it might screw things
	# up, making older mods at N-1 M2's never make it to N.  I've
	# run tests on changes like this before and there's almost no
	# way to predict accurately what it will do on a live site
	# without doing it... -Jamie 2002/11/16

	my($min_old) = $reader->sqlSelect("MIN(id)", "moderatorlog",
		"m2status=0 AND active=1 AND reason IN ($m2able_reasons)");
	my($max_old) = $reader->sqlSelect("MAX(id)", "moderatorlog",
		"ts < DATE_SUB(NOW(), INTERVAL $days_back DAY)
		 AND m2status=0 AND active=1 AND reason IN ($m2able_reasons)");
	$min_old = 0 if !$min_old;
	$max_old = $min_old if !$max_old;
	my($min_new) = $reader->sqlSelect("MIN(id)", "moderatorlog",
		"ts >= DATE_SUB(NOW(), INTERVAL $days_back_cushion DAY)
		 AND m2status=0 AND active=1 AND reason IN ($m2able_reasons)");
	my($max_new) = $reader->sqlSelect("MAX(id)", "moderatorlog",
		"m2status=0 AND active=1 AND reason IN ($m2able_reasons)");
	$min_new = 0 if !$min_new;
	$max_new = $min_new if !$max_new;

	$slashdb->setVar("m2_modlogid_min_old", $min_old);
	$slashdb->setVar("m2_modlogid_max_old", $max_old);
	$slashdb->setVar("m2_modlogid_min_new", $min_new);
	$slashdb->setVar("m2_modlogid_max_new", $max_new);
}

sub give_out_points {

	my($virtual_user, $constants, $slashdb, $user) = @_;

	moderatordLog(getData('moderatord_log_header'));

	my $backup_db = getObject('Slash::DB', { db_type => 'reader' });
	my $log_db = getObject('Slash::DB', { db_type => 'log_slave' });

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

	my $count_hr = $log_db->fetchEligibleModerators_accesslog_read();

	my @eligible_uids = @{$backup_db->fetchEligibleModerators_users($count_hr)};
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
		@eligible_uids = @{$backup_db->factorEligibleModerators(
			\@orig_uids, $wtf, \%info)
		};
	}

	# Decide who's going to get the tokens.
	my $maxtokens_add = $constants->{maxtokens_add} || 3;
	my %update_uids = ( );
	for (my $x = 0; $x < $num_tokens; $x++) {
		my $uid = $eligible_uids[rand @eligible_uids];
		next if $update_uids{$uid} >= $maxtokens_add;
		$update_uids{$uid}++;
	}
	my $n_update_uids = scalar(keys %update_uids);

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
	$slashdb->updateTokens(\%update_uids, { sleep_time => 0.5 });

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

	# We load the optional plugin objects here.
	my $messages = getObject('Slash::Messages');
	my $statsSave = getObject('Slash::Stats::Writer');

	# $mod_ids is an arrayref of moderatorlog IDs which need to be
	# reconciled.
	my $mods_ar = $slashdb->getModsNeedingReconcile();

	my $both0 = { };
	my $tievote = { };
	my %newstats = ( );
	for my $mod_hr (@$mods_ar) {

		# Get data about every M2 done to this moderation.
		my $m2_ar = $slashdb->getMetaModerations($mod_hr->{id});

		my $nunfair = scalar(grep { $_->{active} && $_->{val} == -1 } @$m2_ar);
		my $nfair   = scalar(grep { $_->{active} && $_->{val} ==  1 } @$m2_ar);

		# Sanity-checking... what could go wrong?
		next unless rec_sanity_check({
			mod_hr =>	$mod_hr,
			nunfair =>	$nunfair,
			nfair =>	$nfair,
			both0 =>	$both0,
			tievote =>	$tievote,
		});

		my $winner_val = 0;
		   if ($nfair > $nunfair) {	$winner_val =  1 }
		elsif ($nunfair > $nfair) {	$winner_val = -1 }
		my $fair_frac = $nfair/($nunfair+$nfair);
		my $lonedissent_val =
			scalar(grep { $_->{active} && $_->{val} == -$winner_val } @$m2_ar) <= 1
			? -$winner_val : 0;

		# Get the token and karma consequences of this vote.
		# This uses a complex algorithm to return a fairly
		# complex data structure but at least its fields are
		# named reasonably well.
		my $csq = $slashdb->getM2Consequences($fair_frac, $mod_hr);

		########################################
		# We should wrap this in a transaction to make it faster.
		# XXX START TRANSACTION
		
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

		# Now update the moderator's tally of csq bonuses/penalties.
		my $csqtc = $csq->{csq_token_change}{num};
		my $val = sprintf("csq_bonuses %+0.3f", $csqtc);
		$slashdb->setUser(
			$mod_hr->{uid},
			{ -csq_bonuses => $val },
		) if $csqtc;

		# Now update the tokens of each M2'er.
		for my $m2 (@$m2_ar) {
			if (!$m2->{uid}) {
				slashdLog("no uid in \$m2: " . Dumper($m2));
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
			if ($m2->{val} == $winner_val) {
				$slashdb->setUser($m2->{uid},
					{ -m2voted_majority	=> "m2voted_majority + 1" });
			} elsif ($m2->{val} == $lonedissent_val) {
				$slashdb->setUser($m2->{uid},
					{ -m2voted_lonedissent	=> "m2voted_lonedissent + 1" });
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
			# Only send message if the moderation was deemed unfair
			if ($winner_val < 0) {
				# Get discussion metadata without caching it.
				my $discuss = $slashdb->getDiscussion(
					$mod_hr->{sid}
				);

				# Get info on the comment.
				my $comment_subj = ($slashdb->getComments(
					$mod_hr->{sid}, $mod_hr->{cid}
				))[2];
				my $comment_url = "/comments.pl?sid=$mod_hr->{sid}&cid=$mod_hr->{cid}";
	
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
		}

		# This mod has been reconciled.
		$slashdb->sqlUpdate("moderatorlog", {
			-m2status => 2,
		}, "id=$mod_hr->{id}");

		# XXX END TRANSACTION
		########################################

	}

	if ($both0 && %$both0) {
		slashdLog("$both0->{num} mods had both fair and unfair 0, ids $both0->{minid} to $both0->{maxid}");
	}
	if ($tievote && %$tievote) {
		slashdLog("$tievote->{num} mods had a tie fair-unfair vote, ids $tievote->{minid} to $tievote->{maxid}");
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
				$data->{m2_summary} = $slashdb->getModResolutionSummaryForUser($_, 20);
				$messages->create($_, MSG_CODE_M2, $data, 0, '', 'collective');
			}
		}
	}

}

sub rec_sanity_check {
	my($args) = @_;
	my($mod_hr, $nunfair, $nfair, $both0, $tievote) = (
		$args->{mod_hr}, $args->{nunfair}, $args->{nfair},
		$args->{both0}, $args->{tievote}
	);
	if (!$mod_hr->{uid}) {
		slashdLog("no uid in \$mod_hr: " . Dumper($mod_hr));
		return 0;
	}
	if ($nunfair+$nfair == 0) {
		$both0->{num}++;
		$both0->{minid} = $mod_hr->{id} if !$both0->{minid} || $mod_hr->{id} < $both0->{minid};
		$both0->{maxid} = $mod_hr->{id} if !$both0->{maxid} || $mod_hr->{id} > $both0->{maxid};
		if (verbosity() >= 3) {
			slashdLog("M2 fair,unfair both 0 for mod id $mod_hr->{id}");
		}
		return 0;
	}
	if (($nunfair+$nfair) % 2 == 0) {
		$tievote->{num}++;
		$tievote->{minid} = $mod_hr->{id} if !$tievote->{minid} || $mod_hr->{id} < $tievote->{minid};
		$tievote->{maxid} = $mod_hr->{id} if !$tievote->{maxid} || $mod_hr->{id} > $tievote->{maxid};
		if (verbosity() >= 3) {
			my $constants = getCurrentStatic();
			slashdLog("M2 fair+unfair=" . ($nunfair+$nfair) . ","
				. " consensus=$constants->{m2_consensus}"
				. " for mod id $mod_hr->{id}");
		}
	}
	return 1;
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

############################################################

sub mark_m2_oldzone {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $reasons = $slashdb->getReasons();
        my $m2able_reasons = join(",",
               sort grep { $reasons->{$_}{m2able} }
               keys %$reasons);
	my $count_oldzone_clause = "";
	if ($m2able_reasons) {
		$count_oldzone_clause = "active=1 AND m2status=0 AND reason IN ($m2able_reasons)";
	}

	my $prev_oldzone = $slashdb->getVar('m2_oldzone', 'value', 1);
	my $prev_oldzone_count = 0;
	if ($prev_oldzone && $count_oldzone_clause) {
		$prev_oldzone_count = $slashdb->sqlCount("moderatorlog",
			"id <= $prev_oldzone AND $count_oldzone_clause");
	}
	$prev_oldzone = "undef" if !defined($prev_oldzone);

	set_new_m2_oldzone($virtual_user, $constants, $slashdb, $user);

	my $new_oldzone = $slashdb->getVar('m2_oldzone', 'value', 1);
	my $new_oldzone_count = 0;
	if ($new_oldzone && $count_oldzone_clause) {
		$new_oldzone_count = $slashdb->sqlCount("moderatorlog",
			"id <= $new_oldzone AND $count_oldzone_clause");
	}
	$new_oldzone = "undef" if !defined($new_oldzone);

	slashdLog("m2_oldzone was $prev_oldzone ($prev_oldzone_count mods) now $new_oldzone ($new_oldzone_count mods)");
}

sub set_new_m2_oldzone {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $reasons = $slashdb->getReasons();
        my $m2able_reasons = join(",",
               sort grep { $reasons->{$_}{m2able} }
               keys %$reasons);
        return if !$m2able_reasons;
	my $archive_delay_mod =
		   $constants->{archive_delay_mod}
		|| $constants->{archive_delay}
		|| 14;
	my $m2_oldest_wanted = $constants->{m2_oldest_wanted}
		|| int($archive_delay_mod * 0.9);

	my $need_m2_clause = "active=1 AND m2status=0 AND reason IN ($m2able_reasons)";
	my $m2_oldest_id = $slashdb->sqlSelect("MIN(id)",
		"moderatorlog", $need_m2_clause);
	if (!$m2_oldest_id) {
		# If there's nothing to M2, we're good.
		$slashdb->setVar('m2_oldzone', 0);
		return ;
	}

	my $oldest_time_days = $slashdb->sqlSelect(
		"( UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(ts) ) / 86400",
		"moderatorlog",
		"id=$m2_oldest_id");
	if ($oldest_time_days < $m2_oldest_wanted) {
		# If the oldest unM2'd mod is younger than
		# the limit set in the m2_oldest_wanted var,
		# we're good.
		$slashdb->setVar('m2_oldzone', 0);
                return ;
	}

	# OK, the oldest mods are too old.  We're going to call
	# the "oldzone" the nth percentile:  everything older
	# than the oldest n% of mods.  Find the id of that mod
	# and write it.  A percentile of 2 gives us overhead
	# of about a factor of 10 on Slashdot without having to
	# worry about running out past the "oldzone" before the
	# next run of run_moderatord.
	my $percentile = $constants->{m2_oldest_zone_percentile} || 2;
	my $modlog_size = $slashdb->sqlCount("moderatorlog", $need_m2_clause);
	my $oldzone_size = int($modlog_size * $percentile / 100 + 0.5);
	if (!$oldzone_size) {
		# We probably shouldn't get here except on a site which
		# has _very_ little moderation... but if we do, then
		# we're good.
		$slashdb->setVar('m2_oldzone', 0);
		return ;
        }
	my $oldzone_id = $slashdb->sqlSelect(
		"id",
		"moderatorlog",
		"$need_m2_clause",
		"ORDER BY id LIMIT $oldzone_size, 1");
	$slashdb->setVar('m2_oldzone', $oldzone_id);
}

############################################################

sub adjust_m2_freq {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	# Decide how far back we're going to look for the
	# "roughly weekly" factor.  Earlier, this maxxed out at
	# 10 days but I think it might be better to try 7,
	# to smooth out any fluctuations from weekday to
	# weekend.
	my $t = $constants->{archive_delay};
	$t = 3 if $t < 3;
	$t = 7 if $t > 7;

	my $avg_consensus_t = $slashdb->sqlSelect("avg(m2needed)", "moderatorlog",
		"active=1 AND ts > DATE_SUB(NOW(), INTERVAL $t DAY)");
	my $avg_consensus_day = $slashdb->sqlSelect("avg(m2needed)", "moderatorlog",
		"active=1 AND ts > DATE_SUB(NOW(), INTERVAL  1 DAY)");

	my $m2count_t = $slashdb->sqlCount("metamodlog",
		"active=1 AND ts > DATE_SUB(NOW(), INTERVAL $t day)");
	my $m1count_t = $slashdb->sqlCount("moderatorlog",
		"active=1 AND ts > DATE_SUB(NOW(), INTERVAL $t day)");

	my $m2count_day = $slashdb->sqlCount("metamodlog",
		"active=1 AND ts > DATE_SUB(NOW(), INTERVAL  1 day)");
	my $m1count_day = $slashdb->sqlCount("moderatorlog",
		"active=1 AND ts > DATE_SUB(NOW(), INTERVAL  1 day)");

	# If this site gets very little moderation/metamoderation,
	# don't bother adjusting m2_freq.
	return 1 unless $m1count_t >= 50 && $m2count_t >= 50;

	my $x = $m2count_t / ($m1count_t * $avg_consensus_t);
	my $y = $m2count_day / ($m1count_day * $avg_consensus_day);
	my $z = ($y * 2 + $x) / 3;
	slashdLog(sprintf("m2_freq vars: x: %0.6f y: %0.6f z: %0.6f\n", $x, $y, $z));

	# If the daily and the roughly-weekly factors do not agree, we
	# still adjust the m2_freq, but not nearly as much.  This may
	# help avoid oscillations where the daily factor can get very
	# far away from 1.0 while the weekly factor creeps toward it,
	# causing a sudden change when the weekly factor crosses 1.0
	# to be on the same side as the daily factor.
	my $dampen = ($x > 1 && $y < 1) || ($x < 1 && $y > 1) ? 0.2 : 1.0;

	$z = 3/4 if $z < 3/4;
	$z = 4/3 if $z > 4/3;
	$z = ($z-1)*$dampen + 1;
	slashdLog(sprintf("m2_freq: adjusted  z: %0.6f\n", $z));

	my $cur_m2_freq = $slashdb->getVar('m2_freq', 'value', 1) || 86400;
	my $new_m2_freq = int($cur_m2_freq * $z ** (1/24) + 0.5);

	$new_m2_freq = $constants->{m2_freq_min}
		if defined $constants->{m2_freq_min} && $new_m2_freq < $constants->{m2_freq_min};
	$new_m2_freq = $constants->{m2_freq_max}
		if defined $constants->{m2_freq_max} && $new_m2_freq > $constants->{m2_freq_max};
	slashdLog("adjusting m2_freq from $cur_m2_freq to $new_m2_freq");	
	$slashdb->setVar('m2_freq', $new_m2_freq);
}

1;


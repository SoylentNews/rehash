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

$task{$me}{timespec} = '18 0-23/2 * * *';
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

	give_out_points($virtual_user, $constants, $slashdb, $user);
	reconcile_m2($virtual_user, $constants, $slashdb, $user);

#	doLogExit('moderatord');

	return ;
};

############################################################

sub moderatordLog {
#	doLog('moderatord', \@_);
	doLog('slashd', \@_);
}

sub give_out_points {

	my($virtual_user, $constants, $slashdb, $user) = @_;

	moderatordLog(getData('moderatord_log_header'));

	my $read_db = $slashdb;

	# If a backup DB is defined, we use that one.
	my $backup_user = $constants->{backup_db_user} || '';
	if ($backup_user) {
		$read_db = get_backup_db($backup_user, $constants, $slashdb);
		if ($read_db) {
			moderatordLog("Using replicated database '$backup_user'");
		} else {
			moderatordLog("Skipping run, replicated DB not avail");
			return ;
		}
	}

	my $newcomments = get_num_new_comments($constants, $slashdb);
	if ($newcomments > 0) {

		# Here are the two functions that actually do the work.

		give_out_tokens($newcomments, $constants, $slashdb, $read_db);
		my $granted = $slashdb->convert_tokens_to_points();

		my %g_msg = (
			0 => 'moderatord_tokennotgrantmsg',
			1 => 'moderatord_tokengrantmsg',
		);
		for my $uid (keys %$granted) {
			my $g = $granted->{$uid};
			my $logline = getData($g_msg{$g}, { uid => $uid });
			moderatordLog($logline);
		}
	}

	moderatordLog(getData('moderatord_log_footer'));

}

sub get_backup_db {
	my($backup_user, $constants, $slashdb) = @_;

	my $read_db = undef;

	# How many times we loop.
	my $count = $constants->{moderatord_catchup_count} || 2;
	# The number of updates behind, the read database can be.
	my $lag = $constants->{moderatord_lag_threshold} || 100_000;
	# How long to wait between loops.
	my $sleep_time = $constants->{moderatord_catchup_sleep};

	while ($count--) {
		$read_db = new Slash::DB($backup_user);
		if (!$read_db) {
			moderatordLog("Cannot open read DB: '$backup_user'");
			return undef;
		}
		my $master_stat = ($slashdb->sqlShowMasterStatus())->[0];
		my $slave_stat = ($read_db->sqlShowSlaveStatus())->[0];
		if (lc($slave_stat->{Slave_running}) eq 'no') {
			moderatordLog('Replication requested but not active');
			return undef;
		}
		if ($master_stat->{Position} - $slave_stat->{'pos'} > $lag) {
			# The slave is lagging too much to use;  let's wait
			# a bit for it to hopefully catch up.
			$read_db = undef;
			sleep $sleep_time;
		}
		sleep $sleep_time if !$read_db;
	}
	return $read_db;
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
	my($comments, $constants, $slashdb, $read_db) = @_;
	my $num_tokens = $comments * $constants->{tokenspercomment};
	my $stirredpoints = $slashdb->stirPool();
	$num_tokens += $stirredpoints * $constants->{tokensperpoint};

	# fetchEligibleModerators() returns a list of uids sorted in the
	# order of how many clicks each user has made, from the minimum
	# (the var m1_eligible_hitcount) up to however many the most
	# clicks is.  At some time in the future, it might be interesting
	# to weight token assignment by click count, but for now we just
	# chop off the top and bottom and assign tokens randomly to
	# whoever's left in the middle.

	my @eligible_uids = @{$read_db->fetchEligibleModerators()};
	my $eligible = scalar @eligible_uids;

	# Chop off the least and most clicks.

	my $start = int($eligible * $constants->{m1_pointgrant_start});
	my $end   = int($eligible * $constants->{m1_pointgrant_end});
	@eligible_uids = @eligible_uids[$start..$end];
	my $least = $eligible_uids[0][0];
	my $most  = $eligible_uids[-1][0];
	@eligible_uids =
		map { $_ = $_->[0] } # ignore count, we only want uid
		@eligible_uids;

	# Now add tokens.

	my %update_uids = ( );
	for (my $x = 0; $x < $num_tokens; $x++) {
		my $uid = $eligible_uids[rand @eligible_uids];
		$update_uids{$uid} = 1;
	}
	my @update_uids = sort keys %update_uids;

	# Log info about what we're about to do.

	moderatordLog(getData('moderatord_tokenmsg', {
		new_comments	=> $comments,
		stirredpoints	=> $stirredpoints,
		last_user	=> $read_db->getLastUser(),
		num_tokens	=> $num_tokens,
		eligible	=> $eligible,
		start		=> $start,
		end		=> $end,
		least		=> $least,
		most		=> $most,
		num_updated	=> scalar @update_uids,
	}));

	# Finally, give each user her or his tokens.

	$slashdb->updateTokens(\@update_uids);
}

############################################################

sub reconcile_m2 {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $consensus = $constants->{m2_consensus};
	my $reasons = $slashdb->getReasons();
	my $sql;

	# %m2_results is a hash whose keys are uids.  Its values are
	# hashrefs with the keys "change" (an int), "m2" (an array of
	# hashrefs with values title, url, subject, vote, reason), and
	# "m2_count" (a hashref whose keys are other uids).
	my %m2_results = ( );

	# We load the optional plugin objects here, so we save a few cycles.
	my $messages = getObject('Slash::Messages');
	my $stats = getObject('Slash::Stats');
	my $stats_created = 0;
	my @lt = localtime();
	my $today = sprintf "%4d-%02d-%02d", $lt[5] + 1900, $lt[4] + 1, $lt[3];

	# $mod_ids is an arrayref of moderatorlog IDs which need to be
	# reconciled.
	my $mods_ar = $slashdb->getModsNeedingReconcile();

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
			print STDERR "M2 fair,unfair both 0 for mod id '$mod_hr->{id}'\n";
			next;
		}
		if (int(($nunfair+$nfair)/2) == ($nunfair+$nfair)/2) {
			print STDERR "M2 fair+unfair is even, for mod id '$mod_hr->{id}'\n";
			next;
		}
		if ($nunfair+$nfair != $consensus) {
			print STDERR "M2 fair+unfair=" . ($nunfair+$nfair) . ","
				. " consensus=$consensus\n";
			# this is unexpected, atomicity must have failed in
			# setMetaMod(), but we can cope, so this is just a
			# warning
		}

		my $winner_val = 1; $winner_val = -1 if $nunfair > $nfair;
		my $fair_frac = $nfair/($nunfair+$nfair);

		# Get the token and karma consequences of this vote.
		my $csq = $slashdb->getM2Consequences($fair_frac);
#print STDERR "fair_frac $fair_frac mod_hr->id $mod_hr->{id} csq " . Dumper($csq);

		# First update the moderator's tokens.
		$sql = ($csq->{m1_tokens}{num}
				&& rand(1) < $csq->{m1_tokens}{chance})
			? $csq->{m1_tokens}{sql_possible}
			: $csq->{m1_tokens}{sql_base};
		$slashdb->setUser(
			$mod_hr->{uid},
			{ -tokens => $sql },
			{ and_where => $csq->{m1_tokens}{sql_and_where} }
		) if $sql;

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

		# Now update the tokens of each M2'er.
		for my $m2 (@$m2_ar) {
			if (!$m2->{uid}) {
				print STDERR "no uid in \$m2: " . Dumper($m2);
				next;
			}
			my $key = "m2_fair_tokens";
			$key = "m2_unfair_tokens" if $m2->{val} == -1;
			$sql = ($csq->{$key}{num}
					&& rand(1) < $csq->{$key}{chance})
				? $csq->{$key}{sql_possible}
				: $csq->{$key}{sql_base};
			$slashdb->setUser(
				$m2->{uid},
				{ -tokens => $sql },
				{ and_where => $csq->{$key}{sql_and_where} }
			) if $sql;
		}

		# Store these stats into the stats_daily table.
		reconcile_stats($stats, $stats_created, $today,
			$mod_hr->{reason}, $nfair, $nunfair);
		$stats_created = 1;

		# Store data for the message we may send.
		if ($messages) {
			my $comment_subj = ($slashdb->getComments(
				$mod_hr->{sid}, $mod_hr->{cid}
			))[2];

			# Get discussion metadata without caching it.
			my $discuss = $slashdb->getDiscussion(
				$mod_hr->{sid}
			);

			$m2_results{$mod_hr->{uid}}{change} ||= 0;
			$m2_results{$mod_hr->{uid}}{change} += $csq->{m1_karma}{sign}
				if $m1_karma_changed;

			push @{$m2_results{$mod_hr->{uid}}{m2}}, {
				title	=> $discuss->{title},
				url	=> $discuss->{url},
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
				$data->{num_metamods} =
					scalar
					keys %{$m2_results{$_}{m2_count}};
				$messages->create($_, MSG_CODE_M2, $data);
			}
		}
	}

}

sub reconcile_stats {
	my($stats, $stats_created, $today,
		$reason, $nfair, $nunfair) = @_;
	return unless $stats;

	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $consensus = $constants->{m2_consensus};
	my $reasons = $slashdb->getReasons();
	my @reasons_m2able =
		sort map { $reasons->{$_}{name} }
		grep { $reasons->{$_}{m2able} }
		keys %$reasons;
	my $reason_name = $reasons->{$reason}{name};

	# Update the stats.  First create the rows if necessary.
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
			$stats->createStatDaily($today,
				"m2_${r}_fair", 0);
			$stats->createStatDaily($today,
				"m2_${r}_unfair", 0);
			for my $f (0..$consensus) {
				$stats->createStatDaily($today,
					"m2_${r}_${f}_" . ($consensus-$f),
					0);
			}
		}
	}

	# Now increment the stats values appropriately.
	$stats->updateStatDaily($today,
		"m2_${reason_name}_fair",
		"value + $nfair") if $nfair;
	$stats->updateStatDaily($today,
		"m2_${reason_name}_unfair",
		"value + $nunfair") if $nunfair;
	$stats->updateStatDaily($today,
		"m2_${reason_name}_${nfair}_${nunfair}",
		"value + 1");
}

1;


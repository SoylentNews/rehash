#!/usr/bin/perl -w

use strict;

use vars qw( %task $me );

$task{$me}{timespec} = '8 6 * * *';
$task{$me}{timespec_panic_2} = ''; # if major panic, this can wait
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $backupdb;
	if ($constants->{backup_db_user}) {
		$backupdb = getObject('Slash::DB',
			$constants->{backup_db_user});
	} else {
		$backupdb = $slashdb;
	}
	my $sub_static = getObject("Slash::Subscribe::Static", { db_type => 'reader' });

	slashdLog('Send Subscribe Mail Begin');

	# The below should be in a Static module.

	my $num_total_subscribers = $sub_static->countTotalSubs();
	my $num_current_subscribers = $sub_static->countCurrentSubs();
	my $num_total_renewing_subscribers = $sub_static->countTotalRenewingSubs();
	my $num_current_renewing_subscribers = $sub_static->countCurrentRenewingSubs();

	my $new_subscriptions_hr = $sub_static->getSubscriberList();
	my $num_new_subscriptions = scalar(keys %$new_subscriptions_hr);

	my $subscribers_hr = { };

	my $transaction_list = "";
	my($total_gross, $total_net, $total_pages_bought, $total_karma) = (0, 0, 0, 0);
	my %gross_count = ( );
	if ($num_new_subscriptions > 0) {
		$transaction_list = sprintf(
			"%7s %3s %6s %6s %6s %5s %6s %-20s\n", qw(
			 uid kma $gros $net  today  used  total nickname )
		);
		my @spids = sort { $a <=> $b } keys %$new_subscriptions_hr;

		# First go thru and find out which users are new subscribers
		# and which are renewals.
		for my $spid (@spids) {
			my $spid_hr = $new_subscriptions_hr->{$spid};
			$subscribers_hr->{$spid_hr->{uid}}{payment_gross} += $spid_hr->{payment_gross};
			$subscribers_hr->{$spid_hr->{uid}}{pages} += $spid_hr->{pages};
		}
		for my $uid (keys %$subscribers_hr) {
			$subscribers_hr->{$uid}{is_new} =
				($subscribers_hr->{$uid}{pages}
					== $slashdb->getUser($uid, 'hits_paidfor'))
				? 1 : 0;
		}

		for my $spid (@spids) {
			my $spid_hr = $new_subscriptions_hr->{$spid};
			$gross_count{$spid_hr->{payment_gross}}++;
			$total_gross += $spid_hr->{payment_gross};
			$total_net += $spid_hr->{payment_net};
			$total_pages_bought += $spid_hr->{pages};
			$total_karma += $spid_hr->{karma};
			$transaction_list .= sprintf(
				"%7d %3d %6.2f %6.2f %6d %5d %6d %-20s %s\n",
				@{$spid_hr}{qw(
					uid karma payment_gross payment_net
					pages hits_bought hits_paidfor nickname
				)},
				($subscribers_hr->{$spid_hr->{uid}}{is_new} ? "NEW" : "renew"),
			);
		}
		$transaction_list .= sprintf(
			"%-10s %7.2f %6.2f %6d\n",
			"total:",
			$total_gross,
			$total_net,
			$total_pages_bought
		);
		$transaction_list .= sprintf(
			"%-7s %3d %6.2f %6.2f %6d\n\n",
			"mean:",
			$total_karma/$num_new_subscriptions,
			$total_gross/$num_new_subscriptions,
			$total_net/$num_new_subscriptions,
			$total_pages_bought/$num_new_subscriptions
		);
		my $running_total_gross = 0;
		for my $gross (sort { $a <=> $b } keys %gross_count) {
			$running_total_gross += $gross*$gross_count{$gross};
			$transaction_list .= sprintf(
				"subscriptions at \$%6.2f: %4d ( %4.1f  %4.1f  %5.1f)\n",
				$gross,
				$gross_count{$gross},
				100*$gross_count{$gross}/$num_new_subscriptions,
				100*$gross*$gross_count{$gross}/$total_gross,
				100*$running_total_gross/$total_gross
			);
		}

	}

	my @yesttime = localtime(time-86400);
	my $yesterday = sprintf "%4d-%02d-%02d",
		$yesttime[5] + 1900, $yesttime[4] + 1, $yesttime[3];
	if (my $statsSave = getObject('Slash::Stats::Writer', '', { day => $yesterday })) {
		my($new_count, $sum_new_pages, $sum_new_payments) = (0, 0, 0);
		my($renew_count, $sum_renew_pages, $sum_renew_payments) = (0, 0, 0);
		for my $uid (keys %$subscribers_hr) {
			if ($subscribers_hr->{$uid}{is_new}) {
				++$new_count;
				$sum_new_pages += $subscribers_hr->{$uid}{pages};
				$sum_new_payments += $subscribers_hr->{$uid}{payment_gross};
			} else {
				++$renew_count;
				$sum_renew_pages += $subscribers_hr->{$uid}{pages};
				$sum_renew_payments += $subscribers_hr->{$uid}{payment_gross};
			}
		}
		$statsSave->createStatDaily("subscribe_new_users",	$new_count);
		$statsSave->createStatDaily("subscribe_new_pages",	$sum_new_pages);
		$statsSave->createStatDaily("subscribe_new_payments",	$sum_new_payments);
		$statsSave->createStatDaily("subscribe_renew_users",	$renew_count);
		$statsSave->createStatDaily("subscribe_renew_pages",	$sum_renew_pages);
		$statsSave->createStatDaily("subscribe_renew_payments",	$sum_renew_payments);
		# If the runout stat doesn't already exist for yesterday, create it.
		$statsSave->createStatDaily("subscribe_runout", 0);

		$statsSave->createStatDaily("subscribers_total", $num_total_subscribers);
		$statsSave->createStatDaily("subscribers_current", $num_current_subscribers);
		$statsSave->createStatDaily("subscribers_renewing_total", $num_total_renewing_subscribers);
		$statsSave->createStatDaily("subscribers_renewing_current", $num_current_renewing_subscribers);
	}

	my @numbers = (
		$num_current_subscribers,
		$num_current_renewing_subscribers,
		$num_total_subscribers - $num_current_subscribers,
		$num_total_renewing_subscribers - $num_current_renewing_subscribers,
		$num_total_subscribers,
		$num_total_renewing_subscribers,
		$num_new_subscriptions,
	);

	my($report_link, $monthly_stats) = ("", "");
	if ($constants->{plugin}{Stats}) {
		$report_link = "\n$constants->{absolutedir_secure}/stats.pl?op=report&report=subscribe&stats_days=7\n";
		if (my $stats = getObject('Slash::Stats')) {
			my @stats = ( );
			push @stats, $stats->getStatLastNDays("subscribe_new_users",		30) || 0;
			push @stats, $stats->getStatLastNDays("subscribe_new_pages",		30) || 0;
			push @stats, $stats->getStatLastNDays("subscribe_new_payments",		30) || 0;
			push @stats, $stats->getStatLastNDays("subscribe_renew_users",		30) || 0;
			push @stats, $stats->getStatLastNDays("subscribe_renew_pages",		30) || 0;
			push @stats, $stats->getStatLastNDays("subscribe_renew_payments",	30) || 0;
			push @stats, $stats[0]+$stats[3];
			push @stats, $stats[1]+$stats[4];
			push @stats, $stats[2]+$stats[5];
			push @stats, $stats->getStatLastNDays("subscribe_runout",		30) || 0;
			$monthly_stats = sprintf(<<EOT, @stats);
   Monthly Stats (Average Per Day)
   -------------------------------
            Users   Pages   Payments
New:        %5.2f   %5d   \$%7.2f
Renew:      %5.2f   %5d    %7.2f
Total:      %5.2f   %5d   \$%7.2f
Ran out:    %5.2f
EOT
		}
	}

	my $email = sprintf(<<"EOT", @numbers);
$constants->{sitename} Subscriber Info for yesterday
$report_link
$monthly_stats

   Today
   -----
current subscribers: %6d
  of which renewing:      %6d
 former subscribers: %6d
  of which renewing:      %6d
  total subscribers: %6d
  of which renewing:      %6d

today subscriptions: %6d

$transaction_list
EOT

	if ($constants->{subscribe_secretword} eq 'changemenow') {
		$email .= <<EOT;

*** You have not yet changed your subscribe secret word!    ***
*** Change it now or sneaky users will be able to buy pages ***
*** without actually buying them!  It's the var named:      ***
***                  subscribe_secretword                   ***
*** (See plugins/Subscribe/README for details on using it.) ***

EOT
	}

	$email .= "\n-----------------------\n";

	# Send a message to the site admin.
	for (@{$constants->{stats_reports}}) {
		sendEmail($_,
			"$constants->{sitename} Subscriber Info",
			$email, 'bulk');
	}
	slashdLog('Send Subscribe Mail End');

	return ;
};

1;


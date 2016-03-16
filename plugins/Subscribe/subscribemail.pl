#!/usr/bin/perl -w


# $Id$

use strict;
use utf8;
use Slash::Constants qw(:messages);

use vars qw( %task $me );

$task{$me}{timespec} = '8 6 * * *';
$task{$me}{timespec_panic_2} = ''; # if major panic, this can wait
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;

	my $backupdb = getObject('Slash::DB', { db_type => 'reader' });
	my $sub_static = getObject("Slash::Subscribe::Static", { db_type => 'reader' });
	my $subscribe = getObject('Slash::Subscribe', { db_type => 'reader' });

	slashdLog('Send Subscribe Mail Begin');

	# The below should be in a Static module.

	my $num_total_subscribers = $sub_static->countTotalSubs();
	my $num_current_subscribers = $sub_static->countCurrentSubs();
	

	my $num_total_gift_subscribers = $sub_static->countTotalGiftSubs();
	my $num_current_gift_subscribers = $sub_static->countCurrentGiftSubs();

        
	my $new_subscriptions_hr = $sub_static->getSubscriberList();
	my $num_new_subscriptions = scalar(keys %$new_subscriptions_hr);
	my $num_gift_subscriptions = 0 ;

	my $subscribers_hr = { };

	my $transaction_list = "";
	
	my($total_gross, $total_net, $total_days_bought, $total_karma) = (0, 0, 0, 0);
	my($gift_gross, $gift_days, $gift_users, $gift_karma, $gift_net) = (0, 0, 0, 0, 0);
	my %gross_count = ( );
	
	
	if ($num_new_subscriptions > 0) {
		$transaction_list = sprintf(
			"%7s %6s %3s %6s %6s %6s %-35s %5s %7s %s\n", qw(
			 uid method kma $gros $net days nickname type puid purchaser)
		);
		
		
		my @spids = sort { $a <=> $b } keys %$new_subscriptions_hr;

		# Get details on gift subs
		for my $spid (@spids) {
			my $spid_hr = $new_subscriptions_hr->{$spid};
			$subscribers_hr->{$spid_hr->{uid}}{payment_gross} += $spid_hr->{payment_gross};
			$subscribers_hr->{$spid_hr->{uid}}{days} += $spid_hr->{days};
			
			if($spid_hr->{payment_type} eq "gift"){
				$subscribers_hr->{$spid_hr->{uid}}{gift}++;
				$gift_gross += $spid_hr->{payment_gross};
				$gift_days += $spid_hr->{days};
				$gift_karma += $spid_hr->{karma};
				$gift_net += $spid_hr->{payment_net};
				$num_gift_subscriptions++;
			}  
		}
		
		for my $uid (keys %$subscribers_hr) {
			$gift_users++ if($subscribers_hr->{$uid}{gift}); 
		}


		for my $spid (@spids) {
			my $spid_hr = $new_subscriptions_hr->{$spid};
			$gross_count{$spid_hr->{payment_gross}}++;
			$total_gross += $spid_hr->{payment_gross};
			$total_net += $spid_hr->{payment_net};
			$total_days_bought += $spid_hr->{days};
			$total_karma += $spid_hr->{karma};
			$transaction_list .= sprintf(
				"%7d %6s %3d %6.2f %6.2f %6d %-35s %-5s %7d %s\n",
				@{$spid_hr}{qw( uid method karma payment_gross payment_net days nickname payment_type )},
				$spid_hr->{uid} != $spid_hr->{puid} ? $spid_hr->{puid} : "",
				$spid_hr->{uid} != $spid_hr->{puid} ? $slashdb->getUser($spid_hr->{puid}, "nickname") : ""
			);
		}
		$transaction_list .= sprintf(
			"\n%-17s %7.2f %6.2f %6d\n",
			"total:",
			$total_gross,
			$total_net,
			$total_days_bought
		);
		$transaction_list .= sprintf(
			"%-7s %6s %3d %6.2f %6.2f %6d\n\n",
			"mean:",
			" ", # placeholder for the "method" column
			$total_karma/$num_new_subscriptions,
			$total_gross/$num_new_subscriptions,
			$total_net/$num_new_subscriptions,
			$total_days_bought/$num_new_subscriptions
		);

		if($num_gift_subscriptions){
			$transaction_list .= sprintf(
				"%-17s %7.2f %6.2f %6d\n",
				"gift total:",
				$gift_gross,
				$gift_net,
				$gift_days
			);
			$transaction_list .= sprintf(
				"%-14s %3d %6.2f %6.2f %6d\n\n",
				"gift mean:",
				$gift_karma/$num_gift_subscriptions,
				$gift_gross/$num_gift_subscriptions,
				$gift_net/$num_gift_subscriptions,
				$gift_days/$num_gift_subscriptions
			);
		}
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
	my $statsSave = getObject('Slash::Stats::Writer', '', { day => $yesterday });
	if ($statsSave) {

		my($new_count, $sum_new_days, $sum_new_payments) = (0, 0, 0);
		my($new_gift_count, $sum_new_gift_days, $sum_new_gift_payments) = (0, 0, 0);
		my($renew_count, $sum_renew_days, $sum_renew_payments) = (0, 0, 0);


		$statsSave->createStatDaily("subscribe_new_users",	$num_new_subscriptions);
		$statsSave->createStatDaily("subscribe_new_days",	$total_days_bought);
		$statsSave->createStatDaily("subscribe_new_payments",	$total_gross);

		$statsSave->createStatDaily("subscribe_gift_users",    $gift_users);
		$statsSave->createStatDaily("subscribe_gift_days",    $gift_days);
		$statsSave->createStatDaily("subscribe_gift_payments", $gift_gross);


		$statsSave->createStatDaily("subscribers_total", $num_total_subscribers);
		$statsSave->createStatDaily("subscribers_current", $num_current_subscribers);

		$statsSave->createStatDaily("subscribers_gift_total", $num_total_gift_subscribers);
		$statsSave->createStatDaily("subscribers_gift_current", $num_current_gift_subscribers);

	}

	my @numbers = (
		$num_current_subscribers,
		$num_total_subscribers - $num_current_subscribers,
		$num_total_subscribers,
		$num_new_subscriptions,
	);

	my @gift_numbers = (
		$num_current_gift_subscribers,
		$num_total_gift_subscribers - $num_current_gift_subscribers,
		$num_total_gift_subscribers,
		$gift_users
	);

	my($report_link, $monthly_stats) = ("", "");
	if ($constants->{plugin}{Stats}) {
		$report_link = "\n$gSkin->{absolutedir_secure}/stats.pl?op=report&report=subscribe&stats_days=7\n";
		if ($statsSave and my $stats = getObject('Slash::Stats')) {

			# For a series of stats, calculate the last 30 days'
			# mean value of each stat, pushing them onto our
			# @stats array as we go.  The @stats array order is
			# important because it is fed to a sprintf() which
			# formats it for the email.  Each value is also
			# stored in stats_daily with "_last30" appended to
			# its name.

			my @stats = ( );

			for my $name (qw(
				subscribe_gift_users	subscribe_gift_days	subscribe_gift_payments
				subscribe_new_users	subscribe_new_days	subscribe_new_payments
			)) {
				_do_last30($stats, $statsSave, \@stats, $name);
			}


			$monthly_stats = sprintf(<<EOT, @stats);
   Monthly Stats (Average Per Day)
   -------------------------------
            Users   Days   Payments
Gift:       %5.2f   %5d   \$%7.2f
Total:      %5.2f   %5d   \$%7.2f
EOT

		}
	}
	my $email = sprintf(<<"EOT", @numbers, @gift_numbers);
$constants->{sitename} Subscriber Info for $yesterday
$report_link
$monthly_stats

   Today
   -----
current subscribers    : %6d
former subscribers     : %6d
total subscribers      : %6d
today's subscriptions  : %6d
   
Gift Subscriptions Today
   -----
current gift subscribers    : %6d
former gift subscribers     : %6d
total gift subscribers      : %6d
today's gift subscriptions  : %6d

$transaction_list
EOT


	$email .= "\n-----------------------\n";

	# Send a message to the site admin.
	for (@{$constants->{stats_reports}}) {
		sendEmail($_,
			"$constants->{sitename} Subscriber Info for $yesterday",
			$email, 'bulk');
	}
	slashdLog('Send Subscribe Mail End');

	slashdLog("Low Subscription and Expiration Warnings Begin");
	my $low_run    = $sub_static->getLowRunningSubs();
	my $expire_sub = $sub_static->getExpiredSubs();
	my $messages = getObject("Slash::Messages");
	if ($messages) {
		foreach my $uid (@$low_run) {
			my $low_user = $slashdb->getUser($uid);

			my $last_warn = $low_user->{subscription_low_last_ts} || 0;
			my $last_payment = $slashdb->sqlSelect("MAX(UNIX_TIMESTAMP(ts))",
				"subscribe_payments", "uid=$uid");

			# Users who were gifted subscriptions (perhaps
			# by admins) get the warning too.
			$last_payment = 0 if !$last_payment; 

			# Under no circumstances send this message more
			# than once a week.
			next if $last_warn + 86400*6.5 > time;

			# Send this warning only once per payment.
			# If the user already got this warning once
			# since the time they last subscribed,
			# don't send them another.  Note this can
			# fail to send a 2nd warning if a user gets
			# multiple gifted subscriptions, but that's
			# not a big deal.
			next if $last_payment < $last_warn;

			# send message
			my $users = $messages->checkMessageCodes(
				MSG_CODE_SUBSCRIPTION_LOW, [$uid]	
			);
			if (@$users) {
				my $data = {
					template_name 	=> 'sub_low_msg',
					subject 	=> 'Subscription Running Low',
				};
				$messages->create($users->[0], MSG_CODE_SUBSCRIPTION_LOW, $data, 0, '', 'now');
			}
			$slashdb->setUser($uid, { subscription_low_last_ts => time() });
		}
	
		foreach my $uid (@$expire_sub) {
			my $expire_user = $slashdb->getUser($uid);
	
			my $last_expire = $expire_user->{subscription_expire_last_ts} || 0;
			my $last_payment = $slashdb->sqlSelect("MAX(UNIX_TIMESTAMP(ts))", "subscribe_payments", "uid=$uid");
			# Users who were gifted subscriptions (perhaps
			# by admins) get the message too.
			$last_payment = 0 if !$last_payment; 

			# Under no circumstances send this message more
			# than once a week.
			next if $last_expire + 86400*6.5 > time;

			# Send this warning only once per payment.
			# (See above.)
			next if $last_payment < $last_expire;

			# send message
			my $users = $messages->checkMessageCodes(
				MSG_CODE_SUBSCRIPTION_OUT, [$uid]	
			);
			if (@$users) {
				my $data = {
					template_name 	=> 'sub_out_msg',
					subject 	=> 'Subscription Expired'
				};
				$messages->create($users->[0], MSG_CODE_SUBSCRIPTION_OUT, $data, 0, '', 'now');
			}
			$slashdb->setUser($uid, { subscription_expire_last_ts => time() });
		}
	}
	slashdLog("Low Subscription and Expiration Warnings End");

	return ;
};



###########################################################
sub _do_last30 {
	my($stats, $statsSave, $stats_ar, $name, $value) = @_;
	$value ||= $stats->getStatLastNDays($name, 30) || 0;
	$statsSave->createStatDaily("${name}_last30", $value);
	push @$stats_ar, $value;
}

1;


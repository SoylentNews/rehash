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
	my $subscribe = getObject("Slash::Subscribe");

	slashdLog('Send Subscribe Mail Begin');

	my $num_total_subscribers = $slashdb->sqlCount('users_hits', 'hits_paidfor > 0');
	my $new_subscriptions_hr = $subscribe->getSubscriberList();
{ use Data::Dumper; print STDERR Dumper($new_subscriptions_hr) }
	my $num_new_subscriptions = scalar(keys %$new_subscriptions_hr);

	my $transaction_list = "";
	my($total_gross, $total_net, $total_pages_bought, $total_karma) = (0, 0, 0, 0);
	if ($num_new_subscriptions > 0) {
		$transaction_list = sprintf(
			"%7s %3s %6s %6s %6s %5s %6s %-20s\n", qw(
			 uid kma $gros $net  today  used  total nickname )
		);
		my @spids = sort { $a <=> $b } keys %$new_subscriptions_hr;
		for my $spid (@spids) {
			my $spid_hr = $new_subscriptions_hr->{$spid};
			$total_gross += $spid_hr->{payment_gross};
			$total_net += $spid_hr->{payment_net};
			$total_pages_bought += $spid_hr->{pages};
			$total_karma += $spid_hr->{karma};
			$transaction_list .= sprintf(
				"%7d %3d %6.2f %6.2f %6d %5d %6d %-20s\n",
				@{$spid_hr}{qw(
					uid karma payment_gross payment_net
					pages hits_bought hits_paidfor nickname
				)}
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
			"%-7s %3d %6.2f %6.2f %6d",
			"mean:",
			$total_karma/$num_new_subscriptions,
			$total_gross/$num_new_subscriptions,
			$total_net/$num_new_subscriptions,
			$total_pages_bought/$num_new_subscriptions
		);
	}

	my @numbers = (
		$num_total_subscribers,
		$num_new_subscriptions
	);

	my $email = sprintf(<<"EOT", @numbers);
$constants->{sitename} Subscriber Info for yesterday

total subscribers: %8d
new subscriptions: %8d

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


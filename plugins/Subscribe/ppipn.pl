#!/usr/bin/perl -w

use strict;
use Slash;
use Slash::Utility;
use Slash::Subscribe;
use Slash::Subscribe::IPN;

sub main {
	my $pp_host = getCurrentStatic('paypal_host');
	$Slash::Subscribe::IPN::GTW = "https://$pp_host/cgi-bin/webscr";
	my $subscribe = getObject('Slash::Subscribe');

	
	# get incoming transaction. the 'new' method validates each transaction, we don't need to.
	# Variables do not need to be accessed through $ipn->vars()
	# Each possible response variable will have its own method.
	# i.e. $ipn->payment_type(), $ipn->first_name(), or $ipn->txn_id()
	my $ipn = new Slash::Subscribe::IPN() or print STDERR "IPN Error ".Slash::Subscribe::IPN->error() and exit;

	# may as well log it first. there's no situation where we wouldn't want to.
	# We use the vars method here because ppAddLog wants a hash.
	$subscribe->ppAddLog($ipn->vars);
	my $paypal = $ipn->vars();

	if($ipn->completed){
		my $status = $subscribe->paymentExists($ipn->txn_id);
		if(!$status){
			my $days = $subscribe->convertDollarsToDays($paypal->{payment_gross});
			my $payment_net = $paypal->{payment_gross} - $paypal->{payment_fee};
			
			my ($puid, $payment_type, $from);
			if ($paypal->{custom}){
				$puid = $paypal->{custom};
				$payment_type = 'gift';
				$from = $paypal->{option_selection1};
			} else {
				$puid = $paypal->{item_number};
				$payment_type = 'user';
			}
			
			my $payment = {
				days => $days,
				uid	=> $paypal->{item_number},
				payment_net   => $payment_net,
				payment_gross => $paypal->{payment_gross},
				payment_type  => $payment_type,
				transaction_id => $paypal->{txn_id},
				method => 'paypal',
				email => $from,
				raw_transaction  => $subscribe->convertToText($paypal),
				puid => $puid
			};
			
			
			my ($rows, $result, $warning);
			$rows = $subscribe->insertPayment($payment);
			if ($rows && $rows == 1) {
				$result =  $subscribe->addDaysToSubscriber($payment->{uid}, $days);
				if ($result && $result == 1){
					send_gift_msg($payment->{uid}, $payment->{puid}, $payment->{days}, $from) if $payment->{payment_type} eq "gift";
				} else {
					$warning = "DEBUG: Payment accepted but user subscription not updated!\n" . Dumper($payment);
					print STDERR $warning;
				}
			} else {
				$warning = "DEBUG: Payment accepted but record not added to payment table!\n" . Dumper($payment);
				print STDERR $warning;
			}
		}
	}
	# Now for other statuses
	elsif($ipn->denied || $ipn->failed){
		# This should probably be brought to the attention of the user. Myabe via email.
		# Save this for later -- paulej72 2014/08/01
	}
	elsif($ipn->expired || $ipn->voided){
		# This means OUR account key is either expired or has been canceled.
		# It needs to go to the attention of an admin ASAFP by whatever means necessary.
		# Save this for later -- paulej72 2014/08/01
	}
	elsif($ipn->reversed){
		# The dillhole reversed payment on us. Remove any previously paid for days and the transaction.
		my $uid = my $subscribe->txnToUID($ipn->parent_txn_id);
		my $days = $subscribe->getDaysByTxn($ipn->txn_id);
		$subscribe->removeDaysFromUID($days, $uid);
		$subscribe->removePayment($ipn->parent_txn_id);
	}
	else{
		# Do nothing but the logging we've already done.
	}

	# give the expected empty 200 response
	print "Content-type: text/html\n\n";
}

main();
1;
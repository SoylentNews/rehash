# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Subscribe;

use strict;
use Slash;
use Slash::Utility;
use DateTime;
use DateTime::Format::MySQL;
use JSON;
use LWP::UserAgent 6;
use URI;


use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

sub init {
	my($self) = @_;

	$self->{defpage} = {
		map { ( $_, 1 ) }
		split / /, (
			getCurrentStatic("subscribe_defpages")
			|| "index"
		)
	};
	$self->{defpage}{index} ||= 0;
	$self->{defpage}{article} ||= 0;
	$self->{defpage}{comments} ||= 0;
	$self->{defpage}{_any} =
		   $self->{defpage}{index}
		|| $self->{defpage}{article}
		|| $self->{defpage}{comments};
	$self->{key} = getCurrentStatic("bitpay_token");
	$self->{gateway} = getCurrentStatic("bitpay_host");
	$self->{ua}      = LWP::UserAgent->new;

	1;
}

########################################################
# Internal.
#
# There are three separate boolean subscriber-related decisions that
# must be made for each page delivered to someone who has paid for 1
# or more pages:
#
#		 - Is this page ad-free?		 adlessPage()
#		 - Is this page bought?		  buyingThisPage()
#		 - Does this page get plums?	 plummyPage()
#
# The decisions are separate.  But they are related, so the logic is
# all handled here in _subscribeDecisionPage.  Users get to control
# whether they want to see ads on three types of pages, plus implicit
# control over a fourth type of "all others" (which are adless but
# don't use up a subscription).  Users get to control the maximum
# number of pages per day that they will buy.  Beyond that point they
# start seeing ads on bought page types, but as long as their max is
# at least the default, those bought page types are still considered
# "plumworthy" or (and this is an ugly term but it's short) "plummy."
# And image hits are their own thing.
#
# So:
#
# adless = A && (B || C) && D	  && !I
# buying = A &&  B	   && D	  && !I
# plummy = A && (B || C)	  && E
#
# Where:
#
# [A] User is a subscriber, i.e.:
#		 1. subscription plugin is installed and turned on
#		 2. user is logged in
#		 3. user has more paidfor pages than bought pages
# [B] User has stated they want this type of page bought
#		 EXPLICITLY (it's one of the "big three" types and that
#		 checkbox is checked for this user)
# [C] User wants this type of page bought IMPLICITLY (it's
#		 not one of the "big three" but the user has at least
#		 one of those checkboxes checked)
# [D] User has pages remaining for today before hitting the max
# [E] User's max pages per day to buy is set >= the default (10)
# [I] This hit is an image, not an actual page.
#
sub _subscribeDecisionPage {
	my($self, $trueOnOther, $useMaxNotToday, $r, $user) = @_;

	$user ||= getCurrentUser();
	my $uid = $user->{uid} || 0;
	return 0 if !$user
		||  !$uid
		||   $user->{is_anon};

	# At this point, if we're asking about buying a page, we may know
	# the answer already.
	if (!$trueOnOther && !$useMaxNotToday) {
		# If the user hasn't paid for any pages, or has already bought
		# (used up) all the pages they've paid for, then they are not
		# buying this one.
		return 0 if !$user->{hits_paidfor}
			|| ( $user->{hits_bought}
				&& $user->{hits_bought} >= $user->{hits_paidfor} );
	}

	# If we're asking whether to show an ad, there may be a simple
	# short-circuit here.
	my $constants = getCurrentStatic();
	if ($trueOnOther && !$useMaxNotToday) {
		# If ads aren't on, we're not going to show this one.
		return 0 if !$constants->{run_ads};
		# Otherwise, if the user is not a subscriber, this page
		# is not adless (though it may not actually have an ad,
		# that logic is elsewhere).
		return 0 if !$user->{hits_paidfor}
			|| ( $user->{hits_bought}
				&& $user->{hits_bought} >= $user->{hits_paidfor} );
	}

	# If we're on an image hit, not a page, then there may be
	# a simple answer.
	if (!$useMaxNotToday) {
		my($status, $uri) = ($r->status, $r->uri);
		my($op) = getOpAndDatFromStatusAndURI($status, $uri);
		return 0 if $op eq 'image';
	}

	my $today_max_def = $constants->{subscribe_hits_btmd} || 10;
	if ($useMaxNotToday) {
		# If the user has set their maximum number of pages to a
		# nonzero number under the default, then no, this page is
		# not "plummy".
		if ($user->{hits_bought_today_max}
			&& $user->{hits_bought_today_max} < $today_max_def) {
			return 0;
		}
	} else {
		# Has the user exceeded the maximum number of pages they want
		# to buy *today*?  (Here is where the algorithm decides that
		# "today" is a GMT day.)
		my @gmt = gmtime;
		my $today = sprintf("%04d%02d%02d", $gmt[5]+1900, $gmt[4]+1, $gmt[3]);
		if ($today eq substr($user->{lastclick}, 0, 8)) {
			# This is not the first click of the day, so the today_max
			# may indeed apply.
			my $today_max = $constants->{subscribe_hits_btmd} || 10;
			$today_max = $user->{hits_bought_today_max}
				if defined($user->{hits_bought_today_max});
			# If this value ends up 0 (whether because the user set it to 0,
			# or the site var is 0 and the user didn't override) then there
			# is no daily maximum.
			if ($today_max) {
				return 0 if $user->{hits_bought_today} >= $today_max;
			}
		}
	}

	# We should use $user->{currentPage} instead of parsing $r->uri
	# separately here.  But first we'll need to audit the code and
	# make sure this method is never called before that field is set.
	# Update 2003/04/25:  Now things have been rearranged a bit and
	# _subscribeDecisionPage is always called at the same point,
	# within prepareUser(), after currentPage has been set.  So we
	# can almost certainly switch to using currentPage.
	my $decision = 0;
	$r ||= Apache->request;
	my $uri = $r->uri;
	if ($uri eq '/') {
		$uri = 'index';
	} else {
		$uri =~ s{^.*/([^/]+)\.pl$}{$1};
	}
		# We check to see if the user has saved preferences for
		# which page types they want to buy.  This assumes the
		# data like $user->{buypage_index} is stored in
		# users_param;  we spot-check a page listed in the var,
		# and if there's no param for it, the user has never
		# clicked Save so we use the default values.
	my $test_defpage = "index"; # could do something fancy here, but eh, forget it
	if ($uri =~ /^(index|article|comments)$/) {
		# Check this specific page (either in the user's prefs
		# or in the default values).
		if (exists $user->{"buypage_$test_defpage"}) {
			$decision = 1 if $user->{"buypage_$uri"};
		} else {
			$decision = 1 if $self->{defpage}{$uri};
		}
	} elsif ($trueOnOther) {
		# There won't be an entry for this specific pages,
		# so check to see if any of the user's prefs or any
		# of the default values apply.
		if (exists $user->{"buypage_$test_defpage"}) {
			$decision = 1 if $user->{buypage_index}
				|| $user->{buypage_article}
				|| $user->{buypage_comments};
		} else {
			$decision = 1 if $self->{defpage}{_any};
		}
	}
	if ($constants->{subscribe_debug}) {
		print STDERR "_subscribeDecisionPage $trueOnOther $decision $user->{uid}"
			. " $user->{hits_bought} $user->{hits_paidfor}"
			. " uri '$uri'\n";
	}
	return $decision;
}

sub adlessPage {
	my($self, $r, $user) = @_;
	return $self->_subscribeDecisionPage(1, 0, $r, $user);
}

sub buyingThisPage {
	my($self, $r, $user) = @_;
	return $self->_subscribeDecisionPage(0, 0, $r, $user);
}

sub plummyPage {
	my($self, $r, $user) = @_;
	return $self->_subscribeDecisionPage(1, 1, $r, $user);
}

# By default, allow readers to buy x pages for $y, 2x pages for $2y,
# etc.  If you want to have n-for-the-price-of-m sales or whatever,
# change the logic here.
# Also, if someone hacks the HTML to purchase a fraction of a 
# subscription, they get nothing.
sub convertDollarsToDays {
	my($self, $amount, $prefix) = @_;
	my $constants = getCurrentStatic();
	my $prefixed_amt = $constants->{$prefix."_amount"};
	$amount = 0 if !$prefixed_amt || ($amount / $prefixed_amt) != int($amount / $prefixed_amt);
	return int($amount*$constants->{$prefix."_num_days"}/$constants->{$prefix."_amount"});
}


# When readers cancel a subscription, how much money to refund?
sub convertDaysToDollars {
	my($self, $days) = @_;
	my $constants = getCurrentStatic();
	return sprintf("%0.02f", $days*$constants->{paypal_amount}/$constants->{paypal_num_days});
}


sub addDaysToSubscriber {
	my($self, $uid, $days) = @_;
	return 0 unless $uid;
	return 0 unless $days;
	my $slashdb = getCurrentDB();
	my $subscriber_until = $slashdb->getUser($uid, 'subscriber_until');
	
	$days =~ /(\d+)/;
	if ($days) {
		my $dt_today = DateTime->today;
		my $dt_sub = DateTime::Format::MySQL->parse_date($subscriber_until);
		if ($dt_sub < $dt_today){$dt_sub = $dt_today};
		$dt_sub->add( days => $days );
		$subscriber_until =	DateTime::Format::MySQL->format_date($dt_sub);
		return $slashdb->setUser($uid, {subscriber_until => $subscriber_until});
	}

	return 0	
	
}


########################################################
# Keys expected in the $payment hashref are:
#	uid		user id
#	email		user email address, or blank
#	payment_gross	total payment before fees
#	payment_net	payment received by site after fees
#	days		number of days user will receive
#	transaction_id	(optional) any ID you'd use to identify this payment
#	method		(optional) string representing payment method
#	data		(optional) any additional data
#	memo		(optional) subscriber's memo
#	payment_type	(optional) defaults to "user" 
#					other options are "gift"  or "grant"
#	puid		(optional) purchaser uid for gifts or grants this
#				   will be different than the uid.  If
#				   none is provided it defaults to uid

sub insertPayment {
	my($self, $payment) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $t_id_len  = $constants->{subscribe_gen_transaction_id_length} || 17;
	
	$payment->{payment_type} ||= "user";
	$payment->{puid} ||= $payment->{uid};

	# Can't buy pages for an Anonymous Coward.
	return 0 if isAnon($payment->{uid});

	my $success = 1; # set to 0 on insert failure

	# If no transaction id was given, we'll be making up one of our own.
	# We'll have to make up our own and retry it if it fails.
	my $create_trans = !defined($payment->{transaction_id});
	my $num_retries = 10;

	while (1) {
		if ($create_trans) {	
			$payment->{transaction_id} = substr( Digest::MD5::md5_hex(join(":", $payment->{uid}, $payment->{data}, time, $$, rand(2**30))), 0, $t_id_len);
		}
		$success = $slashdb->sqlInsert("subscribe_payments", $payment);
		last if $success || !$create_trans || --$num_retries <= 0;
	}

	return $success;
}
	
	
sub ppDoPDT {
	my($self, $txid) = @_;
	use Encode qw(decode_utf8);
	my $constants = getCurrentStatic();
	my $token = $constants->{paypal_token};
	my $user = getCurrentUser();
	 
	##########
	# This is debug. It means we got something at the callback but were unable to read the txid for some reason.
	# It probably means we wrote getTxId wrong.
	unless($txid){
		print STDERR "Transaction id: $txid not found\n";
		return 0;
	}
	 
	my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 1, SSL_ca_path => $constants->{pp_SSL_ca_path} });
	my $req = new HTTP::Request('POST', "https://$constants->{paypal_host}/cgi-bin/webscr");
	$req->content_type("application/x-www-form-urlencoded");
	$req->header(Host => "$constants->{paypal_host}");
	$req->content(
		'&cmd=_notify-synch'.
		"&tx=$txid".
		"&at=$token"
	);

	my $result = $ua->request($req);

	##########
	# This is debug. It triggers if we get a 404 or some such from paypal.
	if($result->is_error){
		print STDERR $result->error_as_HTML."\n";
		return -1;
	}

	my $res_encoded = $result->content;
	$res_encoded =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
	$res_encoded =~ s/\+/ /g;
	my @content = split("\n", $res_encoded);
	my $status = shift(@content);

	 my %transaction;

	if($status eq 'SUCCESS'){
		foreach (@content){
			my ($key, $value) = split("=", $_);	    
			#$transaction{$key} = decode_utf8($value);
			$transaction{$key} = $value;
		}
		$transaction{remote_address} = 'PDT';
		
		$self->ppAddLog(\%transaction);
		return \%transaction;
	}
	else{
		return -2;
	}
}

sub stripeDoCharge {
	my ($self, $tx) = @_;
	my $ua = LWP::UserAgent->new();
	my $constants = getCurrentStatic();
        $ua->default_header( 'Authorization' => "Bearer $constants->{stripe_private_key}");
	
        my $response = $ua->post("https://api.stripe.com/v1/charges", $tx);
	
	if($response->is_success) {
		return decode_json($response->decoded_content);
	} else {
		print STDERR "\n".$response->status_line."\n".$response->decoded_content."\n";
		return 0;
	}
}

sub getSubscriptionsForUser {
	my($self, $uid) = @_;
	my $slashdb = getCurrentDB();
	my $uid_q = $slashdb->sqlQuote($uid);
	my $sp = $slashdb->sqlSelectAll(
		"ts, email, payment_gross, days, method, transaction_id, puid, payment_type",
		"subscribe_payments",
		"uid = $uid_q",
		"ORDER BY spid",
	);
	$sp ||= [ ];
	formatDate($sp, 0, 0, "%m-%d-%y @%I:%M %p");
	return $sp;
}

sub getSubscriptionsPurchasedByUser {
	my($self, $puid, $options) = @_;
	my $slashdb = getCurrentDB();
	my $restrict;
	if ($options->{only_types}) {
		if (ref($options->{only_types}) eq "ARRAY") {
			$restrict .= " AND payment_type IN ("
				. join(',', map { $slashdb->sqlQuote($_) }
					@{$options->{only_types}}
				)
				. ")";
		} 
	}
	my $puid_q = $slashdb->sqlQuote($puid);
	my $sp = $slashdb->sqlSelectAll(
		"ts, email, payment_gross, days, method, transaction_id, uid, payment_type",
		"subscribe_payments",
		"puid = $puid_q $restrict",
		"ORDER BY spid",
	);
	$sp ||= [ ];
	formatDate($sp, 0, 0, "%m-%d-%y @%I:%M %p");
	return $sp;
}


sub paymentExists {
	my ($self, $txn_id) = @_;
	my $slashdb = getCurrentDB();
	my $txn_q = $slashdb->sqlQuote($txn_id);
	my $txn_count = $slashdb->sqlSelect(
		'COUNT(transaction_id)',
		'subscribe_payments',
		"transaction_id = $txn_q"
	);
	return $txn_count;
}

sub getDaysByTxn {
	my ($self, $txn_id) = @_;
	my $slashdb = getCurrentDB();
	my $txn_q = $slashdb->sqlQuote($txn_id);
	my $days = $slashdb->sqlSelect(
		'days',
		'subscribe_payments',
		"transaction_id = $txn_q"
	);
	return $days;
}

sub removeDaysFromSubscriber {
	my ($self, $uid, $days) = @_;
	return 0 unless $uid && $days;
  my $slashdb = getCurrentDB();
  my $subscriber_until = $slashdb->getUser($uid, 'subscriber_until');

  $days =~ /(\d+)/;
  if ($days) {
		my $dt_sub = DateTime::Format::MySQL->parse_date($subscriber_until);
		$dt_sub->subtract( days => $days );
    $subscriber_until = DateTime::Format::MySQL->format_date($dt_sub);
		return $slashdb->setUser($uid, {subscriber_until => $subscriber_until});
	}
	return 0;
}

# Simply sets the subscriber_until date to yesterday given $uid
sub removeSubscription {
	my ($self, $uid) = @_;
	return 0 unless $uid;
	my $slashdb = getCurrentDB();
	my $dt_today = DateTime->today;
	$dt_today->subtract( days => 1 );
  my $subscriber_until = DateTime::Format::MySQL->format_date($dt_today);
	return $slashdb->setUser($uid, {subscriber_until => $subscriber_until});
}

sub removePayment {
	my ($self, $txn_id) = @_;
	my $slashdb = getCurrentDB();
	my $rows = $slashdb->sqlDelete(
		"subscribe_payments",
		"transaction_id = '$txn_id'"
	);
	return $rows;
}

sub txnToUID {
	my ($self, $txn_id) = @_;
	my $slashdb = getCurrentDB();
	my $txn_q = $slashdb->sqlQuote($txn_id);
	my $uid = $slashdb->sqlSelect(
		'uid',
		'subscribe_payments',
		"transaction_id = $txn_q"
	);
	return $uid;
}

sub ppAddLog {
	my ($self, $logthis) = @_;
	my $slashdb = getCurrentDB();
	my $data = {
		transaction_id		=> $logthis->{txn_id},
		transaction_type	=> $logthis->{txn_type},
		raw_transaction		=> encode_json($logthis)
	};

	$data->{email} = $logthis->{payer_email} if $logthis->{payer_email};
	if($logthis->{first_name} && $logthis->{last_name}){$data->{name} = $logthis->{first_name}." ".$logthis->{last_name};}
	$data->{payment_gross} = $logthis->{payment_gross} if $logthis->{payment_gross};
	$data->{payment_status} = $logthis->{payment_status} if $logthis->{payment_status};
	$data->{parent_transaction_id} = $logthis->{parent_txn_id} if $logthis->{parent_txn_id};

	my $txn_id = defined $logthis->{parent_txn_id} ? $logthis->{parent_txn_id} : $logthis->{txn_id};
	my $uid = txnToUID($txn_id);
	$data->{uid} = $uid if $uid;
	
	my $success = $slashdb->sqlInsert('paypal_log', $data);
	$slashdb->sqlErrorLog unless $success;
}

sub stripeAddLog {
	my ($self, $logthis) = @_;
	my $slashdb = getCurrentDB();
	my $data = {
		raw_transaction		=> encode_json($logthis),
		remote_address		=> $logthis->{source},
                event_id              => $logthis->{data}->{object}->{id},
	};
	
	my $success = $slashdb->sqlInsert('stripe_log', $data);
        $slashdb->sqlErrorLog($success) unless $success;
}

sub stripeFee {
	my ($self, $gross, $submethod) = @_;
	my $fee;
	if($submethod eq "BTC") {
		# BTC
		$fee = $gross * 0.008;
		if($fee > 5) {
			$fee = 5;
		}
		$fee = sprintf("%.2f", $fee);
	}
	elsif($submethod eq "CC") {
		# CC
		$fee = ($gross * 0.029) + 0.3;
		$fee = sprintf("%.2f", $fee);
	}
	else {
		# Placeholder for future transaction types
		$fee = "0.00";
	}
	return $fee;
}
1;

__END__

# Below is the stub of documentation.

=head1 NAME

Slash::Subscribe - Let users support the site by purchasing an intangible

=head1 SYNOPSIS

	use Slash::Subscribe;

=head1 DESCRIPTION

This plugin lets users purchase subscription at /subscribe.pl, with
built-in (but optional) support for using Paypal.


=head1 AUTHOR

Jamie McCarthy, jamie@mccarthy.vg

=head1 SEE ALSO

perl(1).

=cut

# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Subscribe;

use strict;
use Slash;
use Slash::Utility;

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

	1;
}

########################################################
# Internal.
#
# There are three separate boolean subscriber-related decisions that
# must be made for each page delivered to someone who has paid for 1
# or more pages:
#
#         - Is this page ad-free?         adlessPage()
#         - Is this page bought?          buyingThisPage()
#         - Does this page get plums?     plummyPage()
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
# adless = A && (B || C) && D      && !I
# buying = A &&  B       && D      && !I
# plummy = A && (B || C)      && E
#
# Where:
#
# [A] User is a subscriber, i.e.:
#         1. subscription plugin is installed and turned on
#         2. user is logged in
#         3. user has more paidfor pages than bought pages
# [B] User has stated they want this type of page bought
#         EXPLICITLY (it's one of the "big three" types and that
#         checkbox is checked for this user)
# [C] User wants this type of page bought IMPLICITLY (it's
#         not one of the "big three" but the user has at least
#         one of those checkboxes checked)
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
sub convertDollarsToPages {
	my($self, $amount) = @_;
	my $constants = getCurrentStatic();
	my $paypal_amt = $constants->{paypal_amount};
	$amount = 0 if !$paypal_amt || ($amount / $paypal_amt) != int($amount / $paypal_amt);
	return sprintf("%0.0f", $amount*$constants->{paypal_num_pages}/
		$constants->{paypal_amount});
}

# When readers cancel a subscription, how much money to refund?
sub convertPagesToDollars {
	my($self, $pages) = @_;
	my $constants = getCurrentStatic();
	return sprintf("%0.02f", $pages*$constants->{paypal_amount}/
		$constants->{paypal_num_pages});
}

########################################################
# Keys expected in the $payment hashref are:
#	uid		user id
#	email		user email address, or blank
#	payment_gross	total payment before fees
#	payment_net	payment received by site after fees
#	pages		number of pages user will receive
#	transaction_id	(optional) any ID you'd use to identify this payment
#	method		(optional) string representing payment method
#	data		(optional) any additional data
#	memo		(optional) subscriber's memo
#	payment_type    (optional) defaults to "user" 
#                                  other options are "gift"  or "grant"
#       puid		(optional) purchaser uid for gifts or grants this
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
			$payment->{transaction_id} = substr(
				Digest::MD5::md5_hex(join(":",
					$payment->{uid}, $payment->{data},
					time, $$, rand(2**30)
				)), 0, $t_id_len
			);
		}
		$success = $slashdb->sqlInsert("subscribe_payments", $payment);
		last if $success || !$create_trans || --$num_retries <= 0;
	}

	return $success;
}

sub grantPagesToUID {
	my ($self, $pages, $uid) = @_;
	my $user = getCurrentUser();
	my $slashdb = getCurrentDB();
	my $grant = {
		pages	      => $pages,
		uid	      => $uid,
		payment_net   => 0,
		payment_gross => 0,
		payment_type  => "grant",
		puid	      => $user->{uid}		

	};
	my $rows = $self->insertPayment($grant);
	if ($rows == 1) {
		$slashdb->setUser($uid, {
			"-hits_paidfor" => "hits_paidfor + $pages"
		});
	}
	return $rows;
}

sub getSubscriptionsForUser {
	my($self, $uid) = @_;
	my $slashdb = getCurrentDB();
	my $uid_q = $slashdb->sqlQuote($uid);
	my $sp = $slashdb->sqlSelectAll(
		"ts, email, payment_gross, pages, method, transaction_id, puid, payment_type",
		"subscribe_payments",
		"uid = $uid_q",
		"ORDER BY spid",
	);
	$sp ||= [ ];
	formatDate($sp, 0, 0, "%m-%d-%y @%I:%M %p");
	return $sp;
}

sub getSubscriptionsPurchasedByUser {
	my($self, $puid,$options) = @_;
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
		"ts, email, payment_gross, pages, method, transaction_id, uid, payment_type",
		"subscribe_payments",
		"puid = $puid_q $restrict",
		"ORDER BY spid",
	);
	$sp ||= [ ];
	formatDate($sp, 0, 0, "%m-%d-%y @%I:%M %p");
	return $sp;
}


1;

__END__

# Below is the stub of documentation.

=head1 NAME

Slash::Subscribe - Let users buy adless pages

=head1 SYNOPSIS

	use Slash::Subscribe;

=head1 DESCRIPTION

This plugin lets users purchase adless pages at /subscribe.pl, with
built-in (but optional) support for using Paypal.

Understanding its code will be easier after recognizing that one of its
design goals was to distinguish the act of "paying for" adless pages,
in which money (probably) trades hands, from the act of "buying," in
which adless pages are actually viewed.  After "paying for" a page, you
can still get your money back, but after you "bought" it, no refund.

=head1 AUTHOR

Jamie McCarthy, jamie@mccarthy.vg

=head1 SEE ALSO

perl(1).

=cut

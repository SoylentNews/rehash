# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Subscribe;

use strict;
use Slash;
use Slash::Utility;
use Slash::DB::Utility;

use vars qw($VERSION);

use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub new {
        my($class) = @_;
        my $self = { };

	my $slashdb = getCurrentDB();
        my $plugins = $slashdb->getDescriptions('plugins');
        return unless $plugins->{Subscribe};

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

        bless($self, $class);

        return $self;
}

########################################################
# Internal.
sub _subscribeDecisionPage {
	my($self, $trueOnOther, $r) = @_;

        my $user = getCurrentUser();
	my $uid = $user->{uid} || 0;
        return 0 if !$user
                ||  !$uid
                ||   $user->{is_anon};

	# Any part of the code can set this user state variable at any time.
	return 1 if $user->{state}{buyingpage};

	# If the user hasn't paid for any pages, or has already bought
	# (used up) all the pages they've paid for, then they are not
	# buying this one.

	return 0 if !$user->{hits_paidfor}
                || ( $user->{hits_bought}
			&& $user->{hits_bought} >= $user->{hits_paidfor} );

	# If ads aren't on, the user isn't buying this one.
	my $constants = getCurrentStatic();
	return 0 if !$constants->{run_ads};

	# Has the user exceeded the maximum number of pages they want
	# to buy *today*?  (Here is where the algorithm decides that
	# "today" is a GMT day.)
	my @gmt = gmtime;
	my $today = sprintf("%04d%02d%02d", $gmt[5]+1900, $gmt[4]+1, $gmt[3]);
	if ($today eq substr($user->{lastclick}, 0, 8)) {
		# This is not the first click of the day, so the today_max may
		# indeed apply.
		my $today_max = $constants->{subscribe_hits_btmd} || 10;
		$today_max = $user->{hits_bought_today_max}
			if defined($user->{hits_bought_today_max});
		# If this value ends up 0 (whether because the user set it to 0, or
		# the site var is 0 and the user didn't override) then there is no
		# daily maximum.
		if ($today_max) {
			return 0 if $user->{hits_bought_today} >= $today_max;
		}
	}

	# The user has paid for pages and may be buying this one.

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
	my($self, $r) = @_;
	return $self->_subscribeDecisionPage(1, $r);
}

sub buyingThisPage {
	my($self, $r) = @_;
	return $self->_subscribeDecisionPage(0, $r);
}

# By default, allow readers to buy x pages for $y, 2x pages for $2y,
# etc.  If you want to have n-for-the-price-of-m sales or whatever,
# change the logic here.
sub convertDollarsToPages {
	my($self, $amount) = @_;
	my $constants = getCurrentStatic();
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
sub insertPayment {
	my($self, $payment) = @_;
	my $slashdb = getCurrentDB();

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
				)), 0, 17
			);
		}
		$success = $slashdb->sqlInsert("subscribe_payments", $payment);
		last if $success || !$create_trans || --$num_retries <= 0;
	}

	return $success;
}

sub getSubscriptionsForUser {
	my($self, $uid) = @_;
	my $slashdb = getCurrentDB();
	my $uid_q = $slashdb->sqlQuote($uid);
	my $sp = $slashdb->sqlSelectAll(
		"ts, email, payment_gross, pages, method, transaction_id",
		"subscribe_payments",
		"uid = $uid_q",
		"ORDER BY spid",
	);
	$sp ||= [ ];
	formatDate($sp, 0);
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

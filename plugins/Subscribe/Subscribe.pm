# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
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

	return 0 if !$user->{hits_paidfor}
                || ( $user->{hits_bought}
			&& $user->{hits_bought} >= $user->{hits_paidfor} );

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
	if (getCurrentStatic('subscribe_debug')) {
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

########################################################
# Pass in start and end dates in TIMESTAMP format, i.e.,
# YYYYMMDDhhmmss.  The hhmmss is optional.  The end date is
# optional.  Thus pass the single argument "20010101" to get
# only subscribers who signed up on Jan. 1, 2001.  The start
# date is optional too;  no arguments means start and end
# dates are the beginning and end of yesterday (in MySQL's
# timezone, which means GMT).
sub getSubscriberList {
	my($self, $start, $end) = @_;
	my $slashdb = getCurrentDB();
	$start = $slashdb->sqlSelect(
		'DATE_FORMAT(DATE_SUB(NOW(), INTERVAL 1 DAY), "%Y%m%d")'
	) if !$start;
	$start .= '0' while length($start) < 14;
	$end = substr($start, 0, 8) . "235959" if !$end;
	$end   .= '0' while length($end)   < 14;
	# Just return all the columns that might be useful;  probably not all
	# of them will actually be used, oh well.
	return $slashdb->sqlSelectAllHashref(
		"spid",
		"spid,
		 subscribe_payments.uid as uid,
		 email, ts, payment_gross, payment_net, pages, transaction_id, data,
		 nickname, realemail, seclev, author,
		 karma, m2fair, m2unfair, upmods, downmods, created_at,
		 users_hits.hits as hits, hits_bought, hits_paidfor",
		"subscribe_payments, users, users_info, users_hits",
		"ts BETWEEN '$start' AND '$end'
		 AND subscribe_payments.uid = users.uid
		 AND subscribe_payments.uid = users_info.uid
		 AND subscribe_payments.uid = users_hits.uid"
	);
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

# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Subscribe::Static;

use strict;
use Slash;
use Slash::Utility;
use Slash::DB::Utility;

use base 'Exporter';
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';
use DateTime;
use DateTime::Format::MySQL;

our $VERSION = $Slash::Constants::VERSION;

sub new {
	my($class, $vuser) = @_;
	my $self = { };

	my $slashdb = getCurrentDB();
	my $plugins = $slashdb->getDescriptions('plugins');
	return unless $plugins->{Subscribe};

	bless($self, $class);

	my $constants = getCurrentStatic();
	$self->{virtual_user} = $vuser;
	$self->sqlConnect();

	return $self;
}

sub countTotalSubs {
	my($self) = @_;
	return $self->sqlCount('users_info',
		"subscriber_until > '1970-01-01'");
}

sub countCurrentSubs {
	my($self) = @_;
	return $self->sqlCount('users_info',
		"subscriber_until >= CURDATE()");
}

sub countTotalGiftSubs {
	my($self) = @_;
	my @gift_uids = $self->_getUidsForPaymentType("gift");
	return 0 unless @gift_uids;
	return $self->sqlSelect("count(DISTINCT uid)","subscribe_payments","payment_type='gift' and uid in(".join(',',@gift_uids).")");
}

sub countCurrentGiftSubs {
	my($self) = @_;
	my @gift_uids = $self->_getUidsForPaymentType("gift");
	return 0 unless @gift_uids;
	return $self->sqlCount('users_info',
		'subscriber_until >= CURDATE() AND uid in('.join(',',@gift_uids).')');
}

sub getLowRunningSubs {
	my ($self) = @_;
	my $low_val = getCurrentStatic('subscribe_low_val');
	return $self->sqlSelectColArrayref(
		'users_info.uid',
		'users_info',
		"users_info.subscriber_until < DATE_ADD(CURDATE(), INTERVAL $low_val DAY) and subscriber_until >= CURDATE()"
	);
}

sub getExpiredSubs {
	my ($self) = @_;
	return $self->sqlSelectColArrayref(
		'users_info.uid',
		'users_info',
		"users_info.subscriber_until > '1970-01-01' and subscriber_until < CURDATE()"
	);
}


sub _getUidsForPaymentType {
	my ($self, $type) = @_;
	my $ar = $self->sqlSelectColArrayref("DISTINCT uid", "subscribe_payments","payment_type = ".$self->sqlQuote($type));
	return @$ar;
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
	$end .= '0' while length($end) < 14;
	# Just return all the columns that might be useful;  probably not all
	# of them will actually be used, oh well.
	return $slashdb->sqlSelectAllHashref(
		"spid",
		"spid,
		 subscribe_payments.uid as uid,
		 email, ts, payment_gross, payment_net, days,
		 method, transaction_id, data, memo,
		 nickname, realemail, seclev, author,
		 karma, upmods, downmods, created_at,
		 subscriber_until, payment_type, puid, hide_subscription",
		"subscribe_payments, users, users_info",
		"ts BETWEEN '$start' AND '$end'
		 AND subscribe_payments.uid = users.uid
		 AND subscribe_payments.uid = users_info.uid"
	);
}

1;


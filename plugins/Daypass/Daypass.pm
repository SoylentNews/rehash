# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Daypass;

use strict;
use Slash::Utility;
use Slash::DB::Utility;
use vars qw($VERSION);
use base 'Slash::DB::Utility';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# FRY: And where would a giant nerd be? THE LIBRARY!

#################################################################
sub new {
	my($class, $user) = @_;
	my $self = {};

	my $plugin = getCurrentStatic('plugin');
	return unless $plugin->{Daypass};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect();

	return $self;
}

#################################################################
{ # closure
my $_getDA_cache;
my $_getDA_cached_nextcheck;
sub getDaypassesAvailable {
	my($self) = @_;
	my $constants = getCurrentStatic();

	if (!$_getDA_cache
		|| !$_getDA_cached_nextcheck
		|| $_getDA_cached_nextcheck <= time()) {

		# (Re)load the cache from a reader DB.
		my $reader = getObject('Slash::DB', { db_type => 'reader' });
		$_getDA_cache = $reader->sqlSelectAllHashrefArray(
			"daid, adnum, UNIX_TIMESTAMP(starttime) AS startts, UNIX_TIMESTAMP(endtime) AS endts",
			"daypass_available");
		$_getDA_cached_nextcheck = time() + ($constants->{daypass_cache_expire} || 300);

	}

	return $_getDA_cache;
}
} # end closure

sub getDaypassAdnum {
	my($self) = @_;

	my $constants = getCurrentStatic();
	return 0 unless $constants->{daypass};

	my $da_ar = $self->getDaypassesAvailable();
	return 0 if !$da_ar || !@$da_ar;

	# There are one or more rows in the table, which might mean there
	# are one or more daypass ads that we can show.
	my @ads_available = ( );
	my $time = time();
	for my $hr (@$da_ar) {
		next unless $hr->{startts} <= $time;
		next unless $time <= $hr->{endts};
		# If we want to test the daypass by requiring a user ACL,
		# here's the place to add a restriction. - Jamie
		push @ads_available, $hr->{adnum};
	}

	return 0 unless @ads_available;

	# Return a random one.
	return $ads_available[rand(@ads_available)];
}

sub createDaypasskey {
	my($self) = @_;

	my $user = getCurrentUser();
	# Daypasses are not available to anonymous users (yet).
	return "" if $user->{is_anon};

	my $key = getAnonId(1);
	my $rows = $self->sqlInsert('daypass_keys', {
		uid		=> $user->{uid},
		daypasskey	=> $key,
		-key_given	=> 'NOW()',
		key_confirmed	=> undef,
	});
	if ($rows < 1) {
		return "";
	} else {
		return $key;
	}
}

sub confirmDaypasskey {
	my($self, $key) = @_;
	my $constants = getCurrentStatic();

	my $user = getCurrentUser();
	# Daypasses are not available to anonymous users (yet).
	return "" if $user->{is_anon};

	my $uid = $user->{uid};
	my $key_q = $self->sqlQuote($key);

	my $rows = $self->sqlUpdate(
		"daypass_keys",
		{ -key_confirmed => "NOW()" },
		"uid=$uid AND daypasskey=$key_q");
	
	if ($rows > 0) {
		my $hr = {
			uid	=> $uid,
			goodon	=> $self->getGoodonDay(),
		};
		$rows = $self->sqlInsert('daypass_keys', $hr);
	}

	$rows = 0 if $rows < 1;
	return $rows;
}

sub getGoodonDay {
	my($self) = @_;
	my $slashdb = getCurrentDB();
	my $db_time = $slashdb->getTime();
	# Cheesy (and easy) way of doing this.  Yank the seconds and
	# just return the (GMT) date.
	return substr($db_time, 0, 10);
}

sub userHasDaypass {
	my($self, $user) = @_;
	my $slashdb = getCurrentDB();
	# Anonymous users can't have a daypass.
	return 0 if $user->{is_anon};
	my $goodonday = $self->getGoodonDay();
	# Really should memcached this, here.
	my $uid = $user->{uid};
	my $goodonday_q = $self->sqlQuote($goodonday);
	return 1 if $self->sqlCount("daypass_users", "uid=$uid AND goodon=$goodonday_q");
}

sub doOfferDaypass {
	my($self) = @_;
	# If daypasses are entirely turned off, or the var indicating whether
	# to offer daypasses is set to false, then no.
	my $constants = getCurrentStatic();
	return 0 unless $constants->{daypass} && $constants->{daypass_offer};
	# If the user is not logged-in, or is a subscriber, then no.
	my $user = getCurrentUser();
	return 0 if $user->{is_anon} || $user->{is_subscriber};
	# If the user already has a daypass, then no.
	return 0 if $self->userHasDaypass($user);
	# If there are no ads available for this user, then no.
	my $adnum = $self->getDaypassAdnum();
	return 0 unless $adnum;
	# Otherwise, yes.
	return 1;
}

sub getOfferText {
	my($self) = @_;
	return Slash::getData('offertext', {}, 'daypass');
}

#################################################################
sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if $self->{_dbh} && !$ENV{GATEWAY_INTERFACE};
}

1;

=head1 NAME

Slash::Daypass - Slash Daypass module

=head1 SYNOPSIS

	use Slash::Daypass;

=head1 DESCRIPTION

This contains all of the routines currently used by Daypass.

=head1 SEE ALSO

Slash(3).

=cut

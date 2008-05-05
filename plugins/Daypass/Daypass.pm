# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Daypass;

use strict;
use Slash::Utility;
use Slash::DB::Utility;
use Apache::Cookie;
use base 'Slash::DB::Utility';

our $VERSION = $Slash::Constants::VERSION;

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

		$_getDA_cached_nextcheck = time() + ($constants->{daypass_cache_expire} || 300);
		if (!$constants->{daypass_offer_method}) {
			# (Re)load the cache from a reader DB.
			my $reader = getObject('Slash::DB', { db_type => 'reader' });
			$_getDA_cache = $reader->sqlSelectAllHashrefArray(
				"daid, adnum, minduration,
				 UNIX_TIMESTAMP(starttime) AS startts, UNIX_TIMESTAMP(endtime) AS endts,
				 aclreq",
				"daypass_available");
		} else {
			my $pos = $constants->{daypass_offer_method1_adpos} || 31;
			my $regex = $constants->{daypass_offer_method1_regex} || '!placeholder';
			my $acl = $constants->{daypass_offer_method1_acl} || '';
			my $minduration = $constants->{daypass_offer_method1_minduration} || 10;
			my $avail = $self->checkAdposRegex($pos, $regex);
			if ($avail) {
				my $adnum = $constants->{daypass_adnum} || 13;
				$_getDA_cache = [ {
					daid =>		999, # dummy placeholder, not used
					adnum =>	$adnum,
					minduration =>	$minduration,
					startts =>	time - 60,
					endts =>	time + 3600,
					aclreq =>	$acl,
				} ];
			} else {
				$_getDA_cache = [ ];
			}
		}

	}

	return $_getDA_cache;
}
} # end closure

sub checkAdposRegex {
	my($self, $pos, $regex) = @_;
	my $ad_text = getAd($pos);
	return 0 if !$ad_text;
	my $neg = 0;
	if (substr($regex, 0, 1) eq '!') {
		# Strip off leading char.
		$neg = 1;
		$regex = substr($regex, 1);
	}
	my $avail = ($ad_text =~ /$regex/) ? 1 : 0;
	$avail = !$avail if $neg;
	return $avail;
}

sub getDaypass {
	my($self) = @_;

	my $constants = getCurrentStatic();
	return undef unless $constants->{daypass};

	my $da_ar = $self->getDaypassesAvailable();
	return undef if !$da_ar || !@$da_ar;

	# There are one or more rows in the table, which might mean there
	# are one or more daypass ads that we can show.
	my @ads_available = ( );
	my $time = time();
	my $user = undef;
	for my $hr (@$da_ar) {
		next unless $hr->{startts} <= $time;
		next unless $time <= $hr->{endts};
		if ($constants->{daypass_offer_onlytologgedin}) {
			$user ||= getCurrentUser();
			next unless $user && !$user->{is_anon};
		}
		if ($hr->{aclreq}) {
			$user ||= getCurrentUser();
			print STDERR scalar(localtime) . " $$ cannot get user in getDaypass\n" if !$user;
			next unless $user && !$user->{is_anon}
				&& $user->{acl}{ $hr->{aclreq} };
		}
		push @ads_available, $hr;
	}

	return undef unless @ads_available;

	# Return a random one.
	return $ads_available[rand(@ads_available)];
}

sub createDaypasskey {
	my($self, $dp_hr) = @_;

	# If no daypass was available, we can't return a key.
	return "" if !$dp_hr;

	# How far in the future before this daypass can be confirmed?
	# I.e. how much of the ad do we insist the user watch?
	my $secs_ahead = $dp_hr->{minduration} || 0;
	# Give the user a break of 1 second, to allow for clock drift
	# or what-have-you.
	$secs_ahead -= 1;

	my $key = getAnonId(1, 20);
	my $rows = $self->sqlInsert('daypass_keys', {
		daypasskey		=> $key,
		-key_given		=> 'NOW()',
		-earliest_confirmable	=> "DATE_ADD(NOW(), INTERVAL $secs_ahead SECOND)",
		key_confirmed		=> undef,
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

	my $key_q = $self->sqlQuote($key);

	my $rows = $self->sqlUpdate(
		"daypass_keys",
		{ -key_confirmed => "NOW()" },
		"daypasskey = $key_q
		 AND earliest_confirmable <= NOW()
		 AND key_confirmed IS NULL");

	my $confcode = "";
	if ($rows > 0) {
		$confcode = getAnonId(1, 20);
		my $hr = {
			confcode =>	$confcode,
			gooduntil =>	$self->getGoodUntil(),
		};
		$rows = $self->sqlInsert('daypass_confcodes', $hr);
	}

	$rows = 0 if $rows < 1;
	return $rows ? $confcode : 0;
}

sub getDaypassTZOffset {
	my($self) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	my $dptz = $constants->{daypass_tz} || 'GMT';
	return 0 if $dptz eq 'GMT';

	my $timezones = $slashdb->getTZCodes();
	return 0 unless $timezones && $timezones->{$dptz};
	return $timezones->{$dptz}{off_set} || 0;
}

sub getGoodUntil {
	my($self) = @_;
	my $slashdb = getCurrentDB();

	# The business decision made here is that all daypasses expire
	# at the same time, midnight in some timezone.  This seems to
	# make more sense than having different users' daypasses expire
	# at different times.  I'm not really happy about putting
	# business logic in this .pm file but I doubt this decision
	# will change.  But if it does, here's the line of code that
	# needs to change.
	my $off_set = $self->getDaypassTZOffset() || 0;

	# Determine the final second on the day for the timezone in
	# question, expressed in GMT time.  If the timezone is EST, for
	# which the offset is -18000 seconds, we determine this by bumping
	# the current GMT datetime -18000 seconds, taking the GMT date,
	# appending the time 23:59:59 to it, and re-adding +18000 to
	# that time.
	my $gmt_end_of_tz_day =
		$off_set
		? $slashdb->sqlSelect("DATE_SUB(
				CONCAT(
					SUBSTRING(
						DATE_ADD( NOW(), INTERVAL $off_set SECOND ),
						1, 10
					),
					' 23:59:59'
				),
			INTERVAL $off_set SECOND)")
		: $slashdb->sqlSelect("CONCAT(SUBSTRING(NOW(), 1, 10), ' 23:59:59')");
	# If there was an error of some kind, note it and at least
	# return a legal value.
	if (!$gmt_end_of_tz_day) {
		errorLog("empty gmt_end_of_tz_day '$off_set' " . time);
		$gmt_end_of_tz_day = '0000-00-00 00:00:00';
	}
	return $gmt_end_of_tz_day;
}

sub userHasDaypass {
	my($self, $user) = @_;
	my $form = getCurrentForm();
	return 0 unless $ENV{GATEWAY_INTERFACE};
	my $cookies = Apache::Cookie->fetch;
	return 0 unless $cookies && $cookies->{daypassconfcode};
	my $confcode = $cookies->{daypassconfcode}->value();
	my $confcode_q = $self->sqlQuote($confcode);

	# We really should memcached this.  But the query cache
	# will take a lot of the sting out of it.
	my $gooduntil = $self->sqlSelect(
		'UNIX_TIMESTAMP(gooduntil)',
		'daypass_confcodes',
		"confcode=$confcode_q");
	# If it's expired, it's no good.
	$gooduntil = 0 if $gooduntil && $gooduntil < time();
	return $gooduntil ? 1 : 0;
}

sub doOfferDaypass {
	my($self) = @_;
	# If daypasses are entirely turned off, or the var indicating whether
	# to offer daypasses is set to false, then no.
	my $constants = getCurrentStatic();
	return 0 unless $constants->{daypass} && $constants->{daypass_offer};
	# If the user is a subscriber, then no.
	my $user = getCurrentUser();
	return 0 if $user->{is_subscriber};
	# If the user already has a daypass, then no.
	return 0 if $self->userHasDaypass($user);
	# If there are no ads available for this user, then no.
	my $dp_hr = $self->getDaypass();
	return 0 unless $dp_hr;
	# Otherwise, yes. Return its daid.
	return $dp_hr->{daid};
}

sub getOfferText {
	my($self) = @_;
	my $constants = getCurrentStatic();
	my $text = "";
	if (!$constants->{daypass_offer_method}) {
		$text = Slash::getData('offertext', {}, 'daypass');
	} else {
		my $pos = $constants->{daypass_offer_method1_adpos} || 31;
		$text = getAd($pos);
	}
	return $text;
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

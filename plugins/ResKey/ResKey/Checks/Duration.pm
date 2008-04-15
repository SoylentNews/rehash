# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::ResKey::Checks::Duration;

use warnings;
use strict;

use Slash::Utility;
use Slash::Constants ':reskey';

use base 'Slash::ResKey::Key';

our($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;


sub doCheckCreate {
	my($self) = @_;

	my $user = getCurrentUser();
	my $check_vars = $self->getCheckVars;

	if ($check_vars->{adminbypass} && $user->{is_admin}) {
		return RESKEY_SUCCESS;
	}

	setMaxDuration($self);

	my @return = maxUsesPerTimeframe($self);
	return @return if @return;

	return RESKEY_SUCCESS;
}

sub doCheckTouch {
	my($self) = @_;

	my $user = getCurrentUser();
	my $check_vars = $self->getCheckVars;

	if ($check_vars->{adminbypass} && $user->{is_admin}) {
		return RESKEY_SUCCESS;
	}

	setMaxDuration($self);

	my $reskey_obj = $self->get;

	my @return = maxUsesPerTimeframe($self, $reskey_obj);
	return @return if @return;

	@return = maxFailures($self, $reskey_obj);
	return @return if @return;

	return RESKEY_SUCCESS;
}

sub doCheckUse {
	my($self) = @_;

	my $user = getCurrentUser();
	my $check_vars = $self->getCheckVars;

	if ($check_vars->{adminbypass} && $user->{is_admin}) {
		return RESKEY_SUCCESS;
	}

	my $reskey_obj = $self->get;

	my @return = maxUsesPerTimeframe($self, $reskey_obj);
	return @return if @return;

	@return = maxFailures($self, $reskey_obj);
	return @return if @return;

	# we only check these on use, not create or touch, because the limits
	# are so short that there's no point in checking them until use, so
	# as not to increase the chance of giving users a rather spurious error

	@return = minDurationBetweenUses($self, $reskey_obj);
	if (@return) {
		setMaxDuration($self);
		return @return;
	}

	if ($self->origtype ne 'createuse') {
		@return = minDurationBetweenCreateAndUse($self, $reskey_obj);
		if (@return) {
			setMaxDuration($self);
			return @return;
		}
	}

	return RESKEY_SUCCESS;
}

sub maxFailures {
	my($self, $reskey_obj) = @_;
	$reskey_obj ||= {};

	my $slashdb = getCurrentDB();

	my($max_failures) = duration($self);
	if ($max_failures && $reskey_obj->{rkid}) {
		my $where = "rkid=$reskey_obj->{rkid} AND failures > $max_failures";
		my $rows = $slashdb->sqlCount('reskeys', $where);
		if ($rows) {
			return(RESKEY_DEATH, ['too many failures', {
				max_failures	=> $max_failures,
				uses		=> $rows
			}]);
		}
	}

	return;
}

sub maxUsesPerTimeframe {
	my($self, $reskey_obj) = @_;
	$reskey_obj ||= {};

	my $slashdb = getCurrentDB();

	my($max_uses, $limit) = duration($self);
	if ($max_uses && $limit) {
		my $where = $self->getWhereUserClause;
		$where .= ' AND rkrid=' . $self->rkrid;
		$where .= ' AND is_alive="no" AND ';
		$where .= "rkid != '$reskey_obj->{rkid}' AND " if $reskey_obj->{rkid};
		$where .= "submit_ts > DATE_SUB(NOW(), INTERVAL $limit SECOND)";

		my $rows = $slashdb->sqlCount('reskeys', $where);
		if ($rows >= $max_uses) {
			return(RESKEY_DEATH, ['too many uses', {
				timeframe	=> $limit,
				max_uses	=> $max_uses,
				uses		=> $rows
			}]);
		}
	}

	return;
}

sub minDurationBetweenUses {
	my($self, $reskey_obj) = @_;

	my $slashdb = getCurrentDB();

	my($limit) = duration($self);
	if ($limit) {
		my $where = $self->getWhereUserClause;
		$where .= ' AND rkrid=' . $self->rkrid;
		$where .= ' AND is_alive="no" AND ';
		$where .= "rkid != '$reskey_obj->{rkid}' AND " if $reskey_obj->{rkid};
		$where .= "submit_ts > DATE_SUB(NOW(), INTERVAL $limit SECOND)";

		my $rows = $slashdb->sqlCount('reskeys', $where);
		if ($rows) {
			return(RESKEY_FAILURE, ['use duration too short',
				{ duration => $limit }
			]);
		}
	}

	return;
}

sub minDurationBetweenCreateAndUse {
	my($self, $reskey_obj) = @_;

	my $slashdb = getCurrentDB();

	my($limit) = duration($self);
	if ($limit && $reskey_obj->{rkid}) {
		my $where = "rkid=$reskey_obj->{rkid} AND ";
		$where .= "create_ts > DATE_SUB(NOW(), INTERVAL $limit SECOND)";

		my $rows = $slashdb->sqlCount('reskeys', $where);
		if ($rows) {
			return(RESKEY_FAILURE, ['creation-use duration too short',
				{ duration => $limit }
			]);
		}
	}

	return;
}

sub duration {
	# $do is a flag that tells the code to actually check the interval
	# using DB calls if necessary -- pudge
	my($self, $caller, $do) = @_;
	($caller = (caller(1))[3]) =~ s/^.*:(\w+)$/$1/ unless $caller;

	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $user = getCurrentUser();

	my $check_vars = $self->getCheckVars;
	my $timeframe = $constants->{reskey_timeframe};
	my @duration;

	if ($caller eq 'minDurationBetweenUses') {
		my $duration_name      = 'duration_uses';
		my $duration_name_anon = "$duration_name-anon";
		# this is kinda ugly ... i'd like a better way to know anon, and
		# this constant should be a reskey constant i think -- pudge 2008.03.21
		my $is_anon = $user->{is_anon} || $form->{postanon} || $user->{karma} < $constants->{formkey_minloggedinkarma};
		$duration[0] = $check_vars->{$is_anon ? $duration_name_anon : $duration_name} || 0;

		# If this user has access modifiers applied, check for possible
		# different speed limits based on those.  First match, if any,
		# wins. (taken from MySQL::checkPostInterval()
		my $al2_hr = $user->{srcids} ? $reader->getAL2($user->{srcids}) : { };
		my $al2_name_used = "_none_"; # for debugging
		for my $al2_name (sort keys %$al2_hr) {
			my $sl_name_al2 = $is_anon
				? "$duration_name_anon-$al2_name"
				: "$duration_name-$al2_name";
			if (defined $check_vars->{$sl_name_al2}) {
				$al2_name_used = $al2_name;
				$duration[0] = $check_vars->{$sl_name_al2};
				last;
			}
		}

		if ($self->resname eq 'comments' && $is_anon) {
			my $multiplier = $check_vars->{"$duration_name_anon-mult"};
			if ($multiplier && $multiplier != 1) {
				my $num_comm = $reader->getNumCommPostedAnonByIPID($user->{ipid});
				$duration[0] *= ($multiplier ** $num_comm);
				$duration[0] = int($duration[0] + 0.5);
			}
		}

		if ($do && $duration[0]) {
			my $reskey_obj = $self->get;
			my $slashdb = getCurrentDB();
			# see minDurationBetweenUses()
			my $where = $self->getWhereUserClause;
			$where .= ' AND rkrid=' . $self->rkrid;
			$where .= ' AND is_alive="no" AND ';
			$where .= "rkid != '$reskey_obj->{rkid}' AND " if $reskey_obj->{rkid};
			$where .= "submit_ts > DATE_SUB(NOW(), INTERVAL $duration[0] SECOND)";
			my $seconds_left = $slashdb->sqlSelect(
				"($duration[0] - (TIME_TO_SEC(NOW()) - TIME_TO_SEC(submit_ts))) AS diff",
				'reskeys', $where, "ORDER BY submit_ts DESC LIMIT 1"
			);
			$duration[0] = $seconds_left || 0;
		}

	} elsif ($caller eq 'minDurationBetweenCreateAndUse') {
		my $duration_name = 'duration_creation-use';
		$duration[0] = $check_vars->{$duration_name} || 0;

		if ($do && $duration[0]) {
			my $reskey_obj = $self->get;
			if ($reskey_obj) {
				my $slashdb = getCurrentDB();
				# see minDurationBetweenCreateAndUse()
				my $where = "rkid=$reskey_obj->{rkid} AND ";
				$where .= "create_ts > DATE_SUB(NOW(), INTERVAL $duration[0] SECOND)";
				my $seconds_left = $slashdb->sqlSelect(
					"($duration[0] - (TIME_TO_SEC(NOW()) - TIME_TO_SEC(create_ts))) AS diff",
					'reskeys', $where
				);
				$duration[0] = $seconds_left || 0;
			}
		}

	} elsif ($caller eq 'maxUsesPerTimeframe') {
		my $duration_name = 'duration_max-uses';
		$duration[0] = $check_vars->{$duration_name} || 0;
		$duration[1] = $timeframe; 

	} elsif ($caller eq 'maxFailures') {
		my $duration_name = 'duration_max-failures';
		$duration[0] = $check_vars->{$duration_name} || 0;
	}


	return(@duration);
}

sub setMaxDuration {
	my($self) = @_;
	my $check_vars = $self->getCheckVars;

	(my $caller = lc((caller(1))[3])) =~ s/^.*:docheck(\w+)$/$1/;
	$caller ||= '';
	return unless ($check_vars->{max_duration} ||
		($caller && $check_vars->{"max_duration_$caller"})
	);

	my @durations;
	push @durations, (duration($self, 'minDurationBetweenUses', 1))[0];
	push @durations, (duration($self, 'minDurationBetweenCreateAndUse', 1))[0];

	my($max_duration) = sort { $b <=> $a } @durations;
	$self->max_duration($max_duration);
}

1;

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

	my @return = maxUsesPerTimeframe($self);
	return @return || RESKEY_SUCCESS;
}

sub doCheckTouch {
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
	return @return if @return;

	if ($self->origtype ne 'createuse') {
		@return = minDurationBetweenCreateAndUse($self, $reskey_obj);
		return @return if @return;
	}

	return RESKEY_SUCCESS;
}

sub maxFailures {
	my($self, $reskey_obj) = @_;
	$reskey_obj ||= {};

	my $slashdb = getCurrentDB();
	my $check_vars = $self->getCheckVars;

	my $max_failures = $check_vars->{'duration_max-failures'};
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

	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();
	my $check_vars = $self->getCheckVars;

	my $max_uses = $check_vars->{'duration_max-uses'};
	my $limit = $constants->{reskey_timeframe};
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

	my $limit = &duration;
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
	my $check_vars = $self->getCheckVars;

	my $limit = $check_vars->{'duration_creation-use'};
	if ($limit && $reskey_obj->{rkid}) {
		my $where = "rkid=$reskey_obj->{rkid}";
		$where .= ' AND rkrid=' . $self->rkrid;
		$where .= ' AND is_alive="no" AND ';
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
	my($self, $reskey_obj) = @_;
	(my $caller = (caller(1))[3]) =~ s/^.*:(\w+)$/$1/;

	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $user = getCurrentUser();

	my $check_vars = $self->getCheckVars;
	my $limit = $constants->{reskey_timeframe};
	my $duration = 0;

	if ($caller eq 'minDurationBetweenUses') {
		my $duration_name      = 'duration_uses';
		my $duration_name_anon = "$duration_name-anon";
		# this is kinda ugly ... i'd like a better way to know anon, and
		# this constant should be a reskey constant i think -- pudge 2008.03.21
		my $is_anon = $user->{is_anon} || $form->{postanon} || $user->{karma} < $constants->{formkey_minloggedinkarma};
		$duration = $check_vars->{$is_anon ? $duration_name_anon : $duration_name} || 0;

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
				$duration = $check_vars->{$sl_name_al2};
				last;
			}
		}

		if ($self->resname eq 'comments' && $is_anon) {
			my $multiplier = $check_vars->{"$duration_name_anon-mult"};
			if ($multiplier && $multiplier != 1) {
				my $num_comm = $reader->getNumCommPostedAnonByIPID($user->{ipid});
				$duration *= ($multiplier ** $num_comm);
				$duration = int($duration + 0.5);
			}
		}
	}


	return $duration;
}


1;

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

	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	if ($constants->{'reskey_checks_adminbypass_' . $self->resname} && $user->{is_admin}) {
		return RESKEY_SUCCESS;
	}

	my @return = maxUsesPerTimeframe($self);
	return @return || RESKEY_SUCCESS;
}

sub doCheckTouch {
	my($self) = @_;

	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	if ($constants->{'reskey_checks_adminbypass_' . $self->resname} && $user->{is_admin}) {
		return RESKEY_SUCCESS;
	}

	my @return = maxUsesPerTimeframe($self, $self->get);
	return @return || RESKEY_SUCCESS;
}

sub doCheckUse {
	my($self) = @_;

	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	if ($constants->{'reskey_checks_adminbypass_' . $self->resname} && $user->{is_admin}) {
		return RESKEY_SUCCESS;
	}

	my $reskey_obj = $self->get;

	my @return = maxUsesPerTimeframe($self, $reskey_obj);
	return @return if @return;

	# we only check these on use, not create or touch, because the limits
	# are so short that there's no point in checking them until use, so
	# as not to increase the chance of giving users a rather spurious error

	@return = minDurationBetweenUses($self, $reskey_obj);
	return @return if @return;

	@return = minDurationBetweenCreateAndUse($self, $reskey_obj);
	return @return if @return;

	return RESKEY_SUCCESS;
}



sub maxUsesPerTimeframe {
	my($self, $reskey_obj) = @_;
	$reskey_obj ||= {};

	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();

	my $max_uses = $constants->{'reskey_checks_duration_max-uses_' . $self->resname};
	my $limit = $constants->{reskey_timeframe};
	if ($max_uses && $limit) {
		my $where = $self->whereUser;
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

	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();

	my $limit = $constants->{'reskey_checks_duration_uses_' . $self->resname};
	if ($limit) {
		my $where = $self->whereUser;
		$where .= ' AND is_alive="no" AND ';
		$where .= "rkid != '$reskey_obj->{rkid}' AND ";
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

	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();

	my $limit = $constants->{'reskey_checks_duration_creation-use_' . $self->resname};
	if ($limit) {
		my $where = "rkid=$reskey_obj->{rkid}";
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


1;

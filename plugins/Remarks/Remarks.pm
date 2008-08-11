# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Remarks;

=head1 NAME

Slash::Remarks - Perl extension for Remarks


=head1 SYNOPSIS

	use Slash::Remarks;


=head1 DESCRIPTION

LONG DESCRIPTION.


=head1 EXPORTED FUNCTIONS

=cut

use strict;
use Slash;
use Slash::Display;

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

########################################################
sub getRemarks {
	my($self, $options) = @_;

	my $max = $options->{max} || 100;

	my @where;
	if ($options->{min_priority}) {
		push @where, 'priority >= ' . $self->sqlQuote($options->{min_priority});
	}
	if ($options->{string}) {
		push @where, 'remark LIKE ' . $self->sqlQuote('%' . $options->{string} . '%');
	}

	my $remarks = $self->sqlSelectAllHashrefArray(
		'rid, uid, stoid, time, remark, type, priority',
		'remarks',
		join(' AND ', @where),
		"ORDER BY rid DESC LIMIT $max"
	);

	return $remarks || [];
}

########################################################
sub createRemark {
	my($self, $remark, $options) = @_;

	my $remark_t = $self->truncateStringForCharColumn($remark, 'remarks', 'remark');
	$remark_t =~ s/[^[:ascii:]]+//g;
	$remark_t =~ s/[^[:print:]]+//g;

	$self->sqlInsert('remarks', {
		uid		=> $options->{uid}	|| getCurrentAnonymousCoward('uid'),
		stoid		=> $options->{stoid}	|| 0,
		type 		=> $options->{type}	|| 'user',
		priority	=> $options->{priority}	|| 0,
		-time		=> 'NOW()',
		remark		=> $remark_t,
	});
}

########################################################
sub getRemarksStarting {
	my($self, $starting, $options) = @_;
	return [ ] unless $starting;

	my $starting_q = $self->sqlQuote($starting);
	my $type_clause = $options->{type}
		? ' AND type=' . $self->sqlQuote($options->{type})
		: '';

	return $self->sqlSelectAllHashrefArray(
		'rid, stoid, remarks.uid, remark, karma, remarks.type',
		'remarks, users_info',
		"remarks.uid=users_info.uid AND rid >= $starting_q $type_clause"
	);
}

########################################################
sub getUserRemarkCount {
	my($self, $uid, $secs_back) = @_;
	return 0 unless $uid && $secs_back;

	return $self->sqlCount(
		'remarks',
		"uid = $uid
		 AND time >= DATE_SUB(NOW(), INTERVAL $secs_back SECOND)"
	);
}


########################################################
sub displayRemarksTable {
	my($self, $options) = @_;
	my $user = getCurrentUser();
	$self           ||= getObject('Slash::Remarks');
	$options        ||= {};
	$options->{string}       = $user->{remarks_filter}       if $user->{remarks_filter};
	$options->{min_priority} = $user->{remarks_min_priority} if $user->{min_priority};
	$options->{max}          = $user->{remarks_limit} || 10;

	my $remarks_ref = $self->getRemarks($options);
	return slashDisplay('display', {
		remarks_ref	=> $remarks_ref,
		print_whole	=> $options->{print_whole},
		print_div	=> $options->{print_div},
		remarks_max	=> $options->{max},
	}, { Page => 'remarks', Return => 1 });
}

########################################################
sub ajaxFetch {
	my($slashdb, $constants, $user, $form) = @_;
	my $self = getObject('Slash::Remarks');
	my $options = {};

	$options->{max} = $form->{limit} || 30;

	if ($form->{op} eq 'remarks_create') {
		$options->{print_div} = 1;
		$self->createRemark($form->{remark}, {
			uid	=> $user->{uid},
			type	=> 'system',
		});
	}

	return $self->displayRemarksTable($options);
}

sub ajaxFetchConfigPanel {
	my($slashdb, $constants, $user, $form) = @_;
	slashDisplay('config_remarks', {}, { Return => 1 });
}

sub ajaxConfigSave {
	my($slashdb, $constants, $user, $form) = @_;
	my $data = {};
	if (defined $form->{limit}) {
		$data->{remarks_limit} = $form->{limit}
	}
	if (defined $form->{filter}) {
		$data->{remarks_filter} = $form->{filter};
	}
	if (defined $form->{min_priority}) {
		$data->{remarks_min_priority} = $form->{min_priority};
	}
	$slashdb->setUser($user->{uid}, $data) if keys %$data;
	# this should be in a template -- pudge
	return "<a href=\"#\" onclick=\"closePopup('remarksconfig-popup', 1)\">Close</a>";
}

1;

__END__


=head1 SEE ALSO

Slash(3).

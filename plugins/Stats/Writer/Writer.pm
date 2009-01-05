# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Stats::Writer;

use strict;
use DBIx::Password;
use Slash;
use Slash::Stats;
use Slash::Utility;
use Slash::DB::Utility;

use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

our $VERSION = $Slash::Constants::VERSION;

sub init {
	my($self, $options) = @_;

	return 0 if ! $self->SUPER::init();

	# Might want to use Slash::Stats::init, not sure, there's some
	# duplication and a whole lot of other code too.  For now just
	# skip that class entirely.

	my @time = localtime();
	$self->{_day} = $options->{day}
		? $options->{day}
		: sprintf "%4d-%02d-%02d", $time[5] + 1900, $time[4] + 1, $time[3];
	$self->{_overwrite} = 1 if $options->{overwrite};

	1;
}

sub isInstalled {
	my($class) = @_;
	return Slash::Stats->isInstalled();
}

########################################################
sub createStatDaily {
	my($self, $name, $value, $options) = @_;
	$value = 0 unless $value;
	$options ||= {};
	my $day = $options->{day} || $self->{_day};

	my $skid = $options->{skid} || 0;
	my $insert = {
		'day'	=> $day,
		'name'	=> $name,
		'value'	=> $value,
	};
	$insert->{skid} = $skid;

	my $overwrite = $self->{_overwrite} || $options->{overwrite};
	if ($overwrite) {
		my $where = "day=" . $self->sqlQuote($day)
			. " AND name=" . $self->sqlQuote($name);
		$where .= " AND skid=" . $self->sqlQuote($skid);
#		$self->{_dbh}{AutoCommit} = 0;
		$self->sqlDo("SET AUTOCOMMIT=0");
		$self->sqlDelete('stats_daily', $where);
	}

	$self->sqlInsert('stats_daily', $insert, { ignore => 1 });

	if ($overwrite) {
#		$self->{_dbh}->commit;
#		$self->{_dbh}{AutoCommit} = 1;
		$self->sqlDo("COMMIT");
		$self->sqlDo("SET AUTOCOMMIT=1");
	}
}

########################################################
sub updateStatDaily {
	my($self, $name, $update_clause, $options) = @_;

	my $where = "day = " . $self->sqlQuote($self->{_day});
	$where .= " AND name = " . $self->sqlQuote($name);
	my $skid = $options->{skid} || 0;
	$where .= " AND skid = " . $self->sqlQuote($skid);

	return $self->sqlUpdate('stats_daily', {
		-value =>	$update_clause,
	}, $where);
}

########################################################
sub addStatDaily {
	my($self, $name, $add) = @_;
	$add += 0;
	return 0 if !$add;
	$add = "+$add" if $add !~ /^[-+]/;
	$self->createStatDaily($name, 0);
	return $self->updateStatDaily($name, "value $add");
}


sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if !$ENV{GATEWAY_INTERFACE} && $self->{_dbh};
}


1;

__END__

# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Slash::Stats - Stats system splace

=head1 SYNOPSIS

	use Slash::Stats;

=head1 DESCRIPTION

This is the Slash stats system.

Blah blah blah.

=head1 AUTHOR

Brian Aker, brian@tangent.org

=head1 SEE ALSO

perl(1).

=cut

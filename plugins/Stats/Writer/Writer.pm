# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Stats::Writer;

use strict;
use DBIx::Password;
use Slash;
use Slash::Utility;
use Slash::DB::Utility;

use vars qw($VERSION);
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# On a side note, I am not sure if I liked the way I named the methods either.
# -Brian
sub new {
	my($class, $user, $options) = @_;
	my $self = {};

	my $slashdb = getCurrentDB();
	my $plugins = $slashdb->getDescriptions('plugins');
	return unless $plugins->{'Stats'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	my @time = localtime();
	$self->{_day} = $options->{day} ? $options->{day} : sprintf "%4d-%02d-%02d", $time[5] + 1900, $time[4] + 1, $time[3];
	$self->sqlConnect;

	return $self;
}

########################################################
sub createStatDaily {
	my($self, $name, $value, $options) = @_;
	$value = 0 unless $value;
	$options ||= {};

	my $insert = {
		'day'	=> $self->{_day},
		'name'	=> $name,
		'value'	=> $value,
	};

	$insert->{section} = $options->{section} if $options->{section};
	$insert->{section} ||= 'all';

	$self->sqlInsert('stats_daily', $insert, { ignore => 1 });
}

########################################################
sub updateStatDaily {
	my($self, $name, $update_clause, $options) = @_;

	my $where = "day = " . $self->sqlQuote($self->{_day});
	$where .= " AND name = " . $self->sqlQuote($name);
	my $section = $options->{section} || 'all';
	$where .= " AND section = " . $self->sqlQuote($section);

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

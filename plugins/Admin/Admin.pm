# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Admin;

use strict;
use DBIx::Password;
use Slash;
use Slash::Utility;

use vars qw($VERSION);
use base 'Exporter';
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# On a side note, I am not sure if I liked the way I named the methods either.
# -Brian
sub new {
	my($class, $user) = @_;
	my $self = {};

	my $slashdb = getCurrentDB();
	my $plugins = $slashdb->getDescriptions('plugins');
	return unless $plugins->{'Admin'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;

	return $self;
}

sub getAccesslogMaxID {
	my ($self) = @_;
	return  $self->sqlSelect("max(id)", "accesslog");
}

sub getAccesslogAbusersByID {
	my($self, $id, $threshold) = @_;
	$threshold ||= 20;
	my $limit = 500;
	my $ar = $self->sqlSelectAllHashrefArray(
		"COUNT(id) AS c, host_addr AS ipid, op,
		 MIN(ts) AS mints, MAX(ts) AS maxts",
		"accesslog",
		"id > $id",
		"GROUP BY host_addr,op HAVING c >= $threshold ORDER BY c DESC LIMIT $limit"
	);
	return $ar;
}


sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if !$ENV{GATEWAY_INTERFACE} && $self->{_dbh};
}


1;

__END__

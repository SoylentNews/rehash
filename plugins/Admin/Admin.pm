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
	my($self, $options) = @_;
	my $min_id = $options->{min_id} || 0;
	my $thresh_count = $options->{thresh_count} || 100;
	my $thresh_secs = $options->{thresh_secs} || 5;
	my $thresh_hps = $options->{thresh_hps} || 0.1;
	my $limit = 500;
	my $ar = $self->sqlSelectAllHashrefArray(
		"COUNT(*) AS c, host_addr AS ipid, op,
		 MIN(ts) AS mints, MAX(ts) AS maxts,
		 UNIX_TIMESTAMP(MAX(ts))-UNIX_TIMESTAMP(MIN(ts)) AS secs,
		 COUNT(*)/GREATEST(UNIX_TIMESTAMP(MAX(ts))-UNIX_TIMESTAMP(MIN(ts)),1) AS hps",
		"accesslog",
		"id >= $min_id",
		"GROUP BY host_addr,op
		 HAVING c >= $thresh_count
			AND secs >= $thresh_secs
			AND hps >= $thresh_hps
		 ORDER BY maxts DESC, c DESC
		 LIMIT $limit"
	);
	return $ar;
}


sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if !$ENV{GATEWAY_INTERFACE} && $self->{_dbh};
}


1;

__END__

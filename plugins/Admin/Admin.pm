# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
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

	my $plugin = getCurrentStatic('plugin');
	return unless $plugin->{'Admin'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;

	return $self;
}

sub getAccesslogMaxID {
	my($self) = @_;
	return $self->sqlSelect("MAX(id)", "accesslog");
}

sub getRecentSubs {
	my($self, $startat) = @_;
	my $slashdb = getCurrentDB();
	my $subs = $slashdb->sqlSelectAllHashrefArray(
		"spid, subscribe_payments.uid,
		 nickname,
		 email, ts, payment_gross, pages,
		 transaction_id, method",
		"subscribe_payments, users",
		"subscribe_payments.uid=users.uid",
		"ORDER BY spid DESC
		 LIMIT $startat, 30");
	return $subs;
}

sub getRecentWebheads {
	my($self, $max_num_mins, $max_num_ids) = @_;
	# Pick reasonable defaults.  max_num_minds is passed directly into an
	# SQL statement so it gets extra syntax checking.
	$max_num_mins ||= 10;
	$max_num_mins   = 10   if $max_num_mins !~ /^\d+$/;
	$max_num_ids ||= 25000;

	my $max_id = $self->getAccesslogMaxID();
	my $min_id = $max_id - $max_num_ids;
	$min_id = 0 if $min_id < 0;

	my $data_hr = $self->sqlSelectAllHashref(
		[qw( minute local_addr )],
		"DATE_FORMAT(ts, '%m-%d %H:%i') AS minute, local_addr, AVG(duration) AS dur, COUNT(*) AS c",
		"accesslog",
		"id >= $min_id AND ts >= DATE_SUB(NOW(), INTERVAL $max_num_mins MINUTE)",
		"GROUP BY minute, local_addr");

	return $data_hr;
}

sub getAccesslogAbusersByID {
	my($self, $options) = @_;
	my $slashdb = $options->{slashdb} || $self;
	my $logdb = $options->{logdb} || $self;
	my $min_id = $options->{min_id} || 0;
	my $thresh_count = $options->{thresh_count} || 100;
	my $thresh_hps = $options->{thresh_hps} || 0.1;
	my $limit = 500;

	my $ar = $logdb->sqlSelectAllHashrefArray(
		"COUNT(*) AS c, host_addr AS ipid, op,
		 MIN(ts) AS mints, MAX(ts) AS maxts,
		 UNIX_TIMESTAMP(MAX(ts))-UNIX_TIMESTAMP(MIN(ts)) AS secs,
		 COUNT(*)/GREATEST(UNIX_TIMESTAMP(MAX(ts))-UNIX_TIMESTAMP(MIN(ts)),1) AS hps",
		"accesslog",
		"id >= $min_id",
		"GROUP BY host_addr,op
		 HAVING c >= $thresh_count
			AND hps >= $thresh_hps
		 ORDER BY maxts DESC, c DESC
		 LIMIT $limit"
	);
	return [ ] if !$ar || !@$ar;

	# If we're returning data, find any IPIDs which are already listed
	# as banned and put the reason in too.
	my @ipids = map { $self->sqlQuote($_->{ipid}) } @$ar;
	my $ipids = join(",", @ipids);
	my $hr = $slashdb->sqlSelectAllHashref(
		"ipid",
		"ipid, ts, reason",
		"accesslist",
		"ipid IN ($ipids) AND now_ban = 'yes' AND reason != ''"
	);
	for my $row (@$ar) {
		next unless exists $hr->{$row->{ipid}};
		$row->{bannedts}     = $hr->{$row->{ipid}}{ts};
		$row->{bannedreason} = $hr->{$row->{ipid}}{reason};
	}
	return $ar;
}


sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if !$ENV{GATEWAY_INTERFACE} && $self->{_dbh};
}


1;

__END__

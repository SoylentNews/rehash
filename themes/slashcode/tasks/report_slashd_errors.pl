#!/usr/bin/perl -w
## This code is a part of Slash, and is released under the GPL.
## Copyright 1997-2004 by Open Source Development Network. See README
## and COPYING for more information, or see http://slashcode.com/.
## $Id$

use strict;
use Slash::Constants qw( :messages :slashd );

use vars qw( %task $me );

$task{$me}{timespec} = '23 * * * *';
$task{$me}{timespec_panic_1} = ''; # not important
$task{$me}{on_startup} = 0;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;
	my %data;

	my($now, $lastrun) = updateLastRun($virtual_user, $constants, $slashdb, $user);

	$data{errors} = $slashdb->sqlSelectAllHashref('taskname', 'count(ts) as num, taskname, line, errnote, moreinfo', 'slashd_errnotes', "ts BETWEEN $lastrun AND $now','GROUP BY taskname");

	my $messages = getObject('Slash::Messages');
	
	if ($messages && keys %{$data{errors}}) {
		$data{template_name} = 'display';
		$data{subject} = 'slashd Error Alert';
		$data{template_page} = 'slashderrnote';
		my $admins = $messages->getMessageUsers(MSG_CODE_ADMINMAIL);

		for (@$admins) {
			$messages->create($_, MSG_CODE_ADMINMAIL, \%data);
		}
	}

	expireOldErrors($virtual_user, $constants, $slashdb, $user);

	return;
};

sub updateLastRun {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $lastrun = $slashdb->getVar('slashd_errnote_lastrun', 'value', 1) || 0;
	my $now = $slashdb->sqlSelect('now()');A
	$slashdb->setVar('slashd_errnote_lastrun', $now);

	return($now, $lastrun);
}

sub expireOldErrors {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $interval = $constants->{slashd_errnote_expire} || 90;

	$slashdb->sqlDelete('slashd_errnotes', "ts < DATE_SUB(now(), INTERVAL $interval DAY");
}

1;

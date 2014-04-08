#!/usr/bin/perl -w
## This code is a part of Slash, and is released under the GPL.
## Copyright 1997-2005 by Open Source Technology Group. See README
## and COPYING for more information, or see http://slashcode.com/.
## $Id$

use strict;
use Slash::Constants qw( :messages :slashd );

use vars qw( %task $me );

$task{$me}{timespec} = '0-59/5 * * * *';
$task{$me}{timespec_panic_1} = ''; # not important
$task{$me}{on_startup} = 0;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;
	my %data;

	my($now, $lastrun) = updateLastRun($virtual_user, $constants, $slashdb, $user);

	$data{errors} = $slashdb->sqlSelectAllHashrefArray(
		'COUNT(ts) AS num, taskname, line, errnote, moreinfo',
		'slashd_errnotes',
		"ts BETWEEN '$lastrun' AND '$now'",
		'GROUP BY taskname, line ORDER BY taskname, line');
	my $num_errors = $data{errors} ? scalar(@{$data{errors}}) : 0;

	my $messages = getObject('Slash::Messages');

	if ($messages && $num_errors) {
		$data{template_name} = 'display';
		$data{subject} = 'slashd Error Alert';
		$data{template_page} = 'slashderrnote';
		my $admins = $messages->getMessageUsers(MSG_CODE_ADMINMAIL);
		$messages->create($admins, MSG_CODE_ADMINMAIL, \%data) if @$admins;
	}

	return $num_errors;
};

sub updateLastRun {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $lastrun = $slashdb->getVar('slashd_errnote_lastrun', 'value', 1)
		|| '2004-01-01 00:00:00';
	my $now = $slashdb->sqlSelect('NOW()');
	$slashdb->setVar('slashd_errnote_lastrun', $now);

	return($now, $lastrun);
}

1;

#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use File::Spec::Functions;
use Slash::Utility;
use Slash::Constants ':slashd';

my $me = 'message_delivery.pl';

use vars qw( %task );

$task{$me}{timespec} = '5-59/5 * * * *';
$task{$me}{timespec_panic_1} = '5-59/15 * * * *'; # less often
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $messages = getObject('Slash::Messages');
	unless ($messages) {
		slashdLog("$me: could not instantiate Slash::Messages object");
		return;
	}

	messagedLog("$me begin");

	my @time = localtime();
	$time[5] += 1900;
	$time[4] += 1;
	my $now = sprintf "%04d-%02d-%02d", @time[5, 4, 3];
	my $last_deferred = $slashdb->getVar('messages_last_deferred', 'value') || 0;

	my($successes, $failures) = (0, 0);
	my $count = $constants->{message_process_count} || 10;

	my $msgs;
	if ($last_deferred != $now) {
		$msgs = $messages->gets($count);
		$slashdb->setVar('messages_last_deferred', $now);
	} else {
		$msgs = $messages->gets($count, { 'send' => 'now' });
	}

	my @good  = $messages->process(@$msgs);

	my %msgs  = map { ($_->{id}, $_) } @$msgs;

	for (@good) {
		messagedLog("msg \#$_ sent successfully.");
		delete $msgs{$_};
		++$successes;
	}

	for (sort { $a <=> $b } keys %msgs) {
		messagedLog("Error: msg \#$_ not sent successfully.");
		++$failures;
	}

	messagedLog("$me end");
	if ($successes or $failures) {
		return "sent $successes ok, $failures failed";
	} else {
		return;
	}
};

my $errsub = sub {
	doLog('messaged', \@_);
};

*messagedLog = $errsub unless defined &messagedLog;

1;

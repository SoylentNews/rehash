#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use File::Spec::Functions;
use Slash::Utility;
use Slash::Constants qw(:slashd :messages);

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
	my $date = sprintf "%04d%02d%02d%02d%02d%02d", @time[5, 4, 3, 2, 1, 0];
	my $now  = sprintf "%04d-%02d-%02d", @time[5, 4, 3];
	my $last_deferred = $slashdb->getVar('message_last_deferred', 'value', 1) || 0;

	my($successes, $failures) = (0, 0);
	my $count = $constants->{message_process_count} || 10;

	my $msgs;
	if ($constants->{task_options}{all} || $last_deferred ne $now) {
		$msgs = $messages->gets();  # do it all, baby
		$slashdb->setVar('message_last_deferred', $now);
	} else {
		$msgs = $messages->gets($count, { 'send' => 'now' });
	}

	# handle collective msgs
	my(%collective, %to_delete, %codes);
	my $c = 0;
	for my $msg (@$msgs) {
		my $code = $msg->{code};
		$codes{$code} ||= $messages->getMessageCode($code);
		if ($codes{$code}{'send'} eq 'collective') {
			push @{ $collective{ $code }{ $msg->{user}{uid} } }, $msg;
			$msgs->[$c] = undef;
		}
		$c++;
	}

	for my $code (keys %collective) {
		my $type = $messages->getDescription('messagecodes', $code);

		for my $uid (keys %{$collective{ $code }}) {
			my $coll = $collective{ $code }{ $uid };
			my $msg  = $coll->[0];
			my $mode = $messages->getMode($msg);
			my $message;

			# perhaps put these formatting things in templates?
			if ($mode == MSG_MODE_EMAIL) {
				$message = join "\n\n" . ('=' x 80) . "\n\n", map {
					$_->{message}
				} @$coll;

			} elsif ($mode == MSG_MODE_WEB) {
				$message = join "\n\n<P><HR><P>\n\n", map {
					$_->{message}
				} @$coll;

			} else {
				next;
			}

			$to_delete{ $msg->{id} } = [ map {
					$_->{id}
				} @{$coll}[1 .. $#{$coll}]
			];

			$msg->{message} = $message;
			$msg->{subject} = $type;
			$msg->{date}    = $date;
			push @$msgs, $msg;
		}
	}

	@$msgs = grep { $_ } @$msgs;
	my @good = $messages->process(@$msgs);

	my %msgs = map { ($_->{id}, $_) } @$msgs;

	for my $id (@good) {
		messagedLog("msg \#$id sent successfully.");
		delete $msgs{$id};
		if (exists $to_delete{$id}) {
			for my $nid (@{ $to_delete{$id} }) {
				if ($messages->delete($nid)) {
					messagedLog("msg \#$nid sent successfully.");
					++$successes;
				}
			}
		}
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

#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;

use Net::IRC;
use Data::Dumper;

use Slash;
use Slash::Constants ':slashd';
use Slash::Display;
use Slash::Utility;

use vars qw(
	%task	$me	$task_exit_flag
	$irc	$conn	$nick	$channel
);

$task{$me}{timespec} = '0-59/5 * * * *';
$task{$me}{on_startup} = 1;
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;
	return unless $constants->{ircslash};
	my $start_time = time;

	ircinit();

	while (!$task_exit_flag) {
		$irc->do_one_loop();
		sleep 2;
		handleRemarks();
	}

	ircshutdown();

	return sprintf("got SIGUSR1, exiting after %d seconds", time - $start_time);
};

sub ircinit {
	my $constants = getCurrentStatic();
	my $server =	$constants->{ircslash_server}
				|| 'irc.slashnet.org';
	my $port =	$constants->{ircslash_port}
				|| 6667;
	my $ircname =	$constants->{ircslash_ircname}
				|| "$constants->{sitename} slashd";
	my $username =	$constants->{ircslash_username}
				|| ( map { s/\W+//g; $_ } $ircname )[0];
	$nick =		$constants->{ircslash_nick}
				|| substr($username, 0, 9);
	my $ssl =	$constants->{ircslash_ssl}
				|| 0;
	$irc = new Net::IRC;
	$conn = $irc->newconn(	Nick =>		$nick,
				Server =>	$server,
				Port =>		$port,
				Ircname =>	$ircname,
				Username =>	$username,
				SSL =>		$ssl		);

	$conn->add_global_handler(376,	\&on_connect);
	$conn->add_global_handler(433,	\&on_nick_taken);
	$conn->add_handler('msg',	\&on_msg);
	$conn->add_handler('public',	\&on_public);
}

sub ircshutdown {
	slashdLog("got SIGUSR1, quitting");
	$conn->quit("slashd exiting");
	$conn->disconnect();
}

sub on_connect {
	my($self) = @_;
	my $constants = getCurrentStatic();
	$channel = $constants->{ircslash_channel} || '#ircslash';
	slashdLog("joining $channel");
	$self->join($channel);
}

sub on_nick_taken {
	my($self) = @_;
	my $constants = getCurrentStatic();
	$nick = $constants->{ircslash_nick} if $constants->{ircslash_nick};
	$nick .= int(rand(10));
	$self->nick($nick);
}

# The only response right now to a private message is to "pong" it
# if it is a "ping".

sub on_msg {
	my($self, $event) = @_;

	my($arg) = $event->args();
	if ($arg =~ /ping/i) {
		$self->privmsg($nick, "pong");
	}
}

sub on_public {
	my($self, $event) = @_;
	my $constants = getCurrentStatic();

	my($arg) = $event->args();
	if ($arg =~ /^$nick\b/) {
		$self->privmsg($channel, "I don't respond intelligently yet.");
	}
}

sub handleRemarks {
	my $slashdb = getCurrentDB();
	my $lastremarktime = $slashdb->getVar('ircslash_lastremarktime', 'value', 1) || "";
	my $remarks_ar = $slashdb->getRemarksSince($lastremarktime);
	$lastremarktime = $slashdb->sqlSelect('NOW()');
	for my $remark_hr (@$remarks_ar) {
		my $stoid = $remark_hr->{stoid};
		my $uid = $remark_hr->{uid};
		my $remark = $remark_hr->{remark};
		$conn->privmsg($channel, "Subscriber Remark: $stoid $uid $remark");
	}
	$slashdb->setVar('ircslash_lastremarktime', $lastremarktime);
}

1;


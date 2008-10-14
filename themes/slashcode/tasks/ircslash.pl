#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;

use Data::Dumper;

use Slash;
use Slash::Constants ':slashd';
use Slash::Display;
use Slash::Utility;

use vars qw(
        %task   $me     $task_exit_flag $parent_pid $has_proc_processtable
        $hushed %stoid  $clean_exit_flag %success
        $irc    $conn   $nick   $channel
        $jname  $jnick  $jabber $jconn  $jtime  $jid $juserserver $jserver $jchannel $jchanserver
        $remarks_active $next_remark_id $next_handle_remarks
        $shifts
);

$! = 0;
$task{$me}{timespec} = '* * * * *';
$task{$me}{on_startup} = 1;
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;
	return unless $constants->{ircslash} || $constants->{jabberslash};

	$has_proc_processtable ||= eval { require Proc::ProcessTable };

	my $start_time = time;
	$parent_pid = $info->{parent_pid};
	$remarks_active = $constants->{ircslash_remarks} || 0;
	$hushed = 0;

	$success{irc}    = ircinit();
	$success{jabber} = jabberinit();
	unless (grep $_, values %success) {
		# Probably the network is down and we can't establish
		# a connection.  Exit the task;  the next invocation
		# from slashd will try again.
		return "cannot connect, exiting to let slashd retry later";
	}

	$clean_exit_flag = 0;

	# Set the remark delay (how often we check the DB for new remarks).
	# If remarks are not wanted, we can check less frequently.
	$next_handle_remarks = 0;
	my $remark_delay = $constants->{ircslash_remarks_delay} || 5;
	# let me control this manually KTHX
	#$remark_delay = 180 if $remark_delay < 180 && !$remarks_active;

	while (!$task_exit_flag && !$clean_exit_flag) {
		if ($success{irc}) {
			$irc->do_one_loop();
			if ($@ && $@ =~ /No active connections left/) {
				return "IRC connection lost, exiting to let slashd retry later";
			}
		}
		if ($success{jabber}) {
			my $status = $jabber->Process(1);
			if (!defined $status) {
				$jabber->Disconnect;
				return "Jabber connection lost, exiting to let slashd retry later";
			}
		}

		Time::HiRes::sleep(0.5); # don't waste CPU
		if (time() >= $next_handle_remarks) {
			$next_handle_remarks = time() + $remark_delay;
			handle_remarks();
		}
		possible_check_slashd();
		possible_check_dbs();
	}

	ircshutdown();
	jabbershutdown();

	return "exiting";
};

sub ircinit {
	my $constants = getCurrentStatic();
	return 0 unless $constants->{ircslash};

	require Net::IRC;

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
	$conn = $irc->newconn(
		Nick		=> $nick,
		Server		=> $server,
		Port		=> $port,
		Ircname		=> $ircname,
		Username	=> $username,
		SSL		=> $ssl
	);
	
	if (!$conn) {
		# Probably the network is down and we can't establish
		# a connection.  Exit the task;  the next invocation
		# from slashd will try again.
		return 0;
	}
	slashdLog("logging in to IRC server $server");

	$conn->add_global_handler(376,	\&on_connect);
	$conn->add_global_handler(433,	\&on_nick_taken);
	$conn->add_handler('msg',	\&on_msg);
	$conn->add_handler('public',	\&on_public);

	return 1;
}

sub jabberinit {
	my $constants = getCurrentStatic();
	return 0 unless $constants->{jabberslash};

	require Net::Jabber;

	$jserver =      $constants->{jabberslash_server}
				|| 'jabber.org';
	$juserserver =  $constants->{jabberslash_user_server}
				|| $jserver;
	my $port =      $constants->{jabberslash_port}
				|| 5222;
	$jname =        $constants->{jabberslash_ircname}
				|| "$constants->{sitename} slashd";
	$jnick =        $constants->{jabberslash_nick}
				|| $constants->{ircslash_nick}
				|| ( map { s/\W+//g; $_ } $jname )[0];
	my $password =  $constants->{jabberslash_password}
				|| '';
	my $tls =       $constants->{jabberslash_tls}
				|| 0;

	$jtime = timeCalc(scalar(localtime(time())), '%Y-%m-%d %H:%M:%S', 0);

	$jabber = new Net::Jabber::Client (
#		debuglevel	=> 2,
#		debugfile	=> 'stdout',
#		debugtime	=> 1,
	);
#	$jabber->{DEBUG}{HANDLE} = \*STDOUT;

	$jabber->SetCallBacks(
		onauth		=> \&j_on_auth,
		message		=> \&j_on_msg,
	);

	$jconn = $jabber->Execute(
		hostname	=> $jserver,
		tls		=> $tls,
		username	=> $jname,
		password	=> $password,
		resource	=> $jnick,
	);

	if (!$jconn) {
		# Probably the network is down and we can't establish
		# a connection.  Exit the task;  the next invocation
		# from slashd will try again.
		return 0;
	}
	slashdLog("logging in to Jabber server $jserver");

	return 1;
}

sub ircshutdown {
	return 0 unless getCurrentStatic('ircslash') && $conn;

	$conn->quit("exiting");
	# The disconnect seems to be unnecessary, and throws an error
	# in my testing, but just to be sure let's call it anyway.
	eval { $conn->disconnect() };
	if ($@ && $@ !~ /No active connections left/) {
		slashdLog("unexpected error on disconnect: $@");
	}
}

sub jabbershutdown {
	return 0 unless getCurrentStatic('jabberslash') && $jabber;

	$jabber->Disconnect if $jabber->Connected;
}

sub on_connect {
	my($self) = @_;
	my $constants = getCurrentStatic();
	$channel = $constants->{ircslash_channel} || '#ircslash';
	my $password = $constants->{ircslash_channel_password} || '';
	slashdLog("joining $channel" . ($password ? " (with password)" : ""));
	$self->join($channel, $password);
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
	if (my($cmd) = $arg =~ /^(?:\.|$nick\b\S*\s*)(\w.+)/) {
		handle_cmd('irc', $cmd, $event);
	}
}

sub j_on_auth {
	my $constants = getCurrentStatic();
	$jchannel    = $constants->{jabberslash_channel} or return;
	$jchanserver = $constants->{jabberslash_channel_server}
			|| $constants->{jabberslash_server};
	my $password = $constants->{jabberslash_channel_password}
			|| '';
	slashdLog("joining $jchannel\@$jchanserver" . ($password ? " (with password)" : ""));

	# we want to msg ourselves to catch the current time from the
	# Jabber server, so we can skip messages from the channel log
	# when we enter the channel
# 	my $to = "$jchannel\@$jchanserver/$jnick";
# 	slashdLog("sending to: $to");
# 	$jabber->MessageSend(
# 		to		=> $to,
# 		type		=> 'chat',
# 		body		=> 'timestamp',
# 	);

	# XXX: this will silently fail on a nick collision ...
	$jabber->MUCJoin(
		room		=> $jchannel,
		server		=> $jchanserver,
		nick		=> $jnick,
		password	=> $password
	);
}


sub j_on_msg {
	my($sid, $message) = @_;

	my $fromJID = $message->GetFrom('jid');
	my $from = $fromJID->GetResource;
	my $body = $message->GetBody;
	#slashdLog("msg: [$from] $body");

	return if !$from || !$body;

	### SKIP OLD MESSAGES, AND MESSAGES FROM SELF
	my $time;
	eval { $time = $message->GetTimeStamp };
	if ($time) {
		$time = timeCalc($time, '%Y-%m-%d %H:%M:%S', 0);
		#slashdLog("time: $time");

		# save time we enter the channel, if timestamp message
		if ($from eq $jnick && $body eq 'timestamp') {
			slashdLog("Setting timestamp to $time");
			$jtime = $time;
			return;
		}

		return if $time lt $jtime;
	}

	# ignore self
	return if $from eq $jnick;

	# private
	# since we are on private network, we don't really need such
	# protections; we could also whitelist users in ircslash_jabber_users
=pod
	if ($fromJID->GetUserID ne $jchannel) {
		if ($body =~ /ping/i) {
			$jabber->MessageSend(
				to		=> $fromJID,
				type		=> 'chat',
				body		=> 'pong',
			);
		}
		return;
	}
=cut

	my $event = { nick => $from };
	if (my($cmd) = $body =~ /^(?:\.|$jnick\b\S*\s*)(\w.+)/) {
		handle_cmd('jabber', $cmd, $event);
	}
}



############################################################

sub getIRCData {
	my($value, $hashref) = @_;
	return getData($value, $hashref, 'ircslash');
}

############################################################

{
my %cmds = (
	help		=> \&cmd_help,
	hush		=> \&cmd_hush,
	unhush		=> \&cmd_unhush,
	'exit'		=> \&cmd_exit,
	ignore		=> \&cmd_ignore,
	unignore	=> \&cmd_unignore,
	whois		=> \&cmd_whois,
	excuse		=> \&cmd_excuse,
	daddypants	=> \&cmd_daddypants,
	dp		=> \&cmd_daddypants,
	slashd		=> \&cmd_slashd,
	dbs		=> \&cmd_dbs,
	quote		=> \&cmd_quote,
	quot		=> \&cmd_quote,
	lcr		=> \&cmd_lcr,
	lcrset		=> \&cmd_lcrset,
	re		=> \&cmd_re,
	d		=> \&cmd_roll,

	amiherenow	=> \&cmd_ha,
	amibacknow	=> \&cmd_ha,
);
sub handle_cmd {
	my($service, $cmd, $event) = @_;
	my $responded = 0;
	for my $key (sort keys %cmds) {
		if (my($text) = $cmd =~ /\b$key\b\S*\s*(.*)/i) {
			my $func = $cmds{$key};
			$func->($service, {
				text	=> $text,
				key	=> $key,
				event	=> $event,
			});
			$responded = 1;
			last;
		}
	}
	# OK, none of those commands matched.  Try the template, or
	# our default response.
	if (!$responded) {
		# See if the template wants to field this.
		my $cmd_lc = lc($cmd);
		my $text = slashDisplay('responses',
			{ value => $cmd_lc },
			{ Page => 'ircslash', Return => 1, Nocomm => 1 });
		$text =~ s/^\s+//; $text =~ s/\s+$//;
		if ($text) {
			send_msg($text, { $service => 1 });
		}
	}
}
}

sub send_msg {
	my($msg, $services) = @_;
	# 1 is send regular msg to channel, 2 is send to individual users
	$services ||= { jabber => 2, irc => 2 };

	if ($success{irc} && $services->{irc}) {
		$conn->privmsg($channel, $msg);
	}

	if ($success{jabber} && $services->{jabber}) {
		my($type, @to);
		# send to individual users ...
		if ($services->{jabber} > 1) {
			my $constants = getCurrentStatic();
			$type = 'chat';

			my %users = map { $_ => 1 } split /\|/, $constants->{ircslash_jabber_users};

			$shifts ||= getObject('Slash::ScheduleShifts', { db_type => 'reader' });
			if ($shifts) {
				my $reader = getObject('Slash::DB', { db_type => 'reader' });
				my $daddy = $shifts->getDaddy;
				my $daddy_user = $reader->getUser($daddy->[0]{uid});
				my $id = $daddy_user->{ircslash_jabber_id};
				if ($id) {
					# only add it if not already there, either alone
					# or with a "resource"
					unless (grep m{^\Q$id\E(?:$|/.)}, keys %users) {
						$users{$id} = 1;
					}
				}
			}

			for my $to (keys %users) {
				if ($to =~ m|(\w+)/(\w+)|) {
					$to = "$1\@$juserserver/$2";
				} else {
					$to = "$to\@$juserserver";
				}
				push @to, $to;
			}
			# append bot nick to msg, else if two bots sharing
			# same account, we don't know which is which,
			# in privmsg
			$msg = "[$jnick] $msg";
		# ... or the channel
		} else {
			$type = 'groupchat';
			@to = ("$jchannel\@$jchanserver");
		}

		for my $to (@to) {
			$jabber->MessageSend(
				to		=> $to,
				type		=> $type,
				body		=> $msg,
			);
		}
	}
}

sub change_nick {
	my($newnick, $services) = @_;
	$services ||= { jabber => 1, irc => 1 };

	if ($success{irc} && $services->{irc}) {
		$conn->nick($newnick);
	}

	if ($success{jabber} && $services->{jabber}) {
		# XXX dunno how to change nicks
#		$jid->SetResource($newnick);
	}
}

sub cmd_ha {
	my($service, $info) = @_;
	send_msg("No, $info->{event}{nick}, you're not.", { $service => 1 });
}

sub cmd_help {
	my($service, $info) = @_;
	send_msg(getIRCData('help'), { $service => 1 });
}

sub cmd_hush {
	my($service, $info) = @_;
	if (!$hushed) {
		$hushed = 1;
		slashdLog("hushed by $info->{event}{nick}");
		change_nick("$nick-hushed");
	}
}

sub cmd_unhush {
	my($service, $info) = @_;
	if ($hushed) {
		$hushed = 0;
		slashdLog("unhushed by $info->{event}{nick}");
		change_nick($nick);
	}
}

sub cmd_exit {
	my($service, $info) = @_;
	slashdLog("got exit from $info->{event}{nick}");
	send_msg(getIRCData('exiting'), { jabber => 1, irc => 1 });
	$clean_exit_flag = 1;
}

sub cmd_re {
	my($service, $info) = @_;
	send_msg(getIRCData('re', {
		nickname	=> $info->{text} || $info->{event}{nick},
	}), { $service => 1 });
}

sub cmd_roll {
	my($service, $info) = @_;
	my($n) = $info->{text} =~ /(\d+)/;
	$n ||= 100;
	send_msg(getIRCData('roll', {
		num       => int(rand $n)+1,
		nickname  => $info->{event}{nick},
	}), { $service => 1 });
}

sub cmd_ignore {
	my($service, $info) = @_;
	my $slashdb = getCurrentDB();

	my($uid) = $info->{text} =~ /(\d+)/;
	my $user = $slashdb->getUser($uid);

	if (!$user || !$user->{uid}) {
		send_msg(getIRCData('nosuchuser', { uid => $uid }), { $service => 1 });
	} elsif ($user->{noremarks}) {
		send_msg(getIRCData('alreadyignoring',
			{ nickname => $user->{nickname}, uid => $uid }), { $service => 1 });
	} else {
		$slashdb->setUser($uid, { noremarks => 1 });
		send_msg(getIRCData('ignoring',
			{ nickname => $user->{nickname}, uid => $uid }), { $service => 1 });
		slashdLog("ignoring $uid, cmd from $info->{event}{nick}");
	}
}

sub cmd_unignore {
	my($service, $info) = @_;
	my $slashdb = getCurrentDB();

	my($uid) = $info->{text} =~ /(\d+)/;
	my $user = $slashdb->getUser($uid);

	if (!$user || !$user->{uid}) {
		send_msg(getIRCData('nosuchuser', { uid => $uid }), { $service => 1 });
	} elsif (!$user->{noremarks}) {
		send_msg(getIRCData('wasntignoring',
			{ nickname => $user->{nickname}, uid => $uid }), { $service => 1 });
	} else {
		$slashdb->setUser($uid, { noremarks => undef });
		send_msg(getIRCData('unignored',
			{ nickname => $user->{nickname}, uid => $uid }), { $service => 1 });
		slashdLog("unignored $uid, cmd from $info->{event}{nick}");
	}
}

sub cmd_whois {
	my($service, $info) = @_;
	my $slashdb = getCurrentDB();

	my $uid;
	if ($info->{text} =~ /^(\d+)$/) {
		$uid = $1;
	} else {
		$uid = $slashdb->getUserUID($info->{text});
	}
	my $user = $slashdb->getUser($uid) if $uid;

	if (!$uid || !$user || !$user->{uid}) {
		send_msg(getIRCData('nosuchuser', { uid => $uid }), { $service => 1 });
	} else {
		send_msg(getIRCData('useris',
			{ nickname => $user->{nickname}, uid => $uid }), { $service => 1 });
	}
}

sub cmd_excuse {
	my($service, $info) = @_;
	require Net::Telnet;
	my $host = 'bob.bob.bofh.org';
	my $port = 666;
	my $t = Net::Telnet->new(
		Host	=> $host,
		Errmode	=> "return",
		Port	=> $port
	);  
	if (defined $t) {
		$t->waitfor("/Your excuse is: /"); 
		my $reply = $t->get;
		$reply =~ s/^.*Your excuse is: //s;
		send_msg($reply, { $service => 1 });
	} else { 
		send_msg("The server at $host (port $port) appears to be down.", { $service => 1 });
	}
}

sub cmd_daddypants {
	my($service, $info) = @_;

	my $daddy = eval { require Slash::DaddyPants };
	return unless $daddy;

	my %args = ( name => 1 );

	if ($info->{text} =~ /^\s*([a-zA-Z]+)/) {
		$args{when} = $1;
	} elsif ($info->{text} =~ /^\s*(-?\d+\s+(?:minute|hour|day)s?)/) {
		$args{when} = $1;
	} elsif ($info->{text} && $info->{text} =~ /^(-?\d+)/) {
		$args{time} = $info->{text};
	}

	my $result = Slash::DaddyPants::daddypants(\%args);
	send_msg($result, { $service => 1 });
	slashdLog("daddypants: $result, cmd from $info->{event}{nick}");
}

sub cmd_lcr {
	my($service, $info, $topic) = @_;
	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();

	my @lcrs;
	if (!$topic && $info->{text} =~ /^(\w+)/) {
		my $site = $1;
		if ($site =~ /^($constants->{ircslash_lcr_sites})$/i) {
			my $val = $slashdb->getVar("ircslash_lcr_$site", 'value', 1) || '';
			my($date, $tag) = split /\|/, $val, 2;
			slashdLog("lcr: $val, $date, $tag");
			push @lcrs, { site => $site, date => $date, tag => $tag };
		} else {
			send_msg(getIRCData('lcr_not_found', { site => $site }), { $service => 1 });
			return;
		}
	} else {
		for my $site (split /\|/, $constants->{ircslash_lcr_sites}) {
			my $val = $slashdb->getVar("ircslash_lcr_$site", 'value', 1);
			my($date, $tag) = split /\|/, $val, 2;
			my %lcrs = ( $site =>  { date => $date, tag => $tag } );
			push @lcrs, { site => $site, date => $date, tag => $tag };
		}
	}
	send_msg(getIRCData('lcr_ok', { lcrs => \@lcrs, topic => $topic }), { $service => 1 });
}

sub cmd_lcrset {
	my($service, $info) = @_;
	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();

	my %lcrs;
	if ($info->{text} =~ /^(\w+) (\w+)/) {
		my($site, $tag) = ($1, $2);
		if ($site =~ /^($constants->{ircslash_lcr_sites})$/i) {
			my $time = $slashdb->getTime;
			if (defined $slashdb->getVar("ircslash_lcr_$site", 'value', 1)) {
				$slashdb->setVar("ircslash_lcr_$site", "$time|$tag");
			} else {
				$slashdb->sqlInsert('vars', {
					name		=> "ircslash_lcr_$site",
					value		=> "$time|$tag",
					description	=> "LCR time and tag for $site"
				});
			}
			cmd_lcr($service, $info);
			# /topic not yet supported
			# cmd_lcr($service, $info, 1);
		} else {
			send_msg(getIRCData('lcr_not_found', { site => $site }), { $service => 1 });
			return;
		}
	} else {
		send_msg(getIRCData('na', { lcrs => \%lcrs }), { $service => 1 });
	}
}


{ # closure
my %exchange = ( );
sub cmd_quote {
	my($service, $info) = @_;

	my $symbol = $info->{text};
	return unless $symbol;
	$symbol = uc($symbol);

	my $fq = eval { require Finance::Quote };
	return unless $fq;

	$fq = Finance::Quote->new();
	$fq->set_currency('USD');

	my %stock_raw = ( );

	my $exchange = $exchange{$symbol} || '';
	if ($exchange) {
		%stock_raw = $fq->fetch($exchange, $symbol);
	} else {
		TRY: for my $try (qw( nasdaq nyse europe canada )) {
			%stock_raw = $fq->fetch($try, $symbol);
			if (!%stock_raw) {
				# Nope, didn't get it.  Try again.
				next TRY;
			}
			# OK, we got it.
			$exchange{$symbol} = $try;
			last TRY;
		}
	}

	# Finance::Quote returns its data in a goofy format, not nested
	# hashrefs, but with the symbol name preceding the field name,
	# separated by the $; character.  Pull out the data for just the
	# one symbol we asked about.
	my %stock = ( );
	for my $key (keys %stock_raw) {
		my($dummy, $realfieldname) = split /$;/, $key;
		$stock{$realfieldname} = $stock_raw{$key};
	}

	# Add more useful data to that hash.
	if ($stock{year_range} =~ /^\s*([\d.]+)\D+([\d.]+)/) {
		($stock{year_low}, $stock{year_high}) = ($1, $2);
	}
	for my $key (qw( open close last high low year_high year_low )) {
		$stock{$key} = sprintf( '%.2f', $stock{$key}) if $stock{$key};
	}
	for my $key (qw( net p_change )) {
		$stock{$key} = sprintf('%+.2f', $stock{$key}) if $stock{$key};
	}
	$stock{symbol} = $symbol;

	# Generate and emit the response.
	my $response = getIRCData('quote_response', { stock => \%stock });
	send_msg($response, { $service => 1 });
	slashdLog("quote: $response, cmd from $info->{event}{nick}");
}
} # end closure

sub cmd_slashd {
	my($service, $info) = @_;
	my $slashdb = getCurrentDB();
	my $st = $slashdb->getSlashdStatuses();
	my @lc_tasks =
		sort { $st->{$b}{last_completed_secs} <=> $st->{$a}{last_completed_secs} }
		keys %$st;
	my $last_task = $st->{ $lc_tasks[0] };
	$last_task->{last_completed_secs_ago} = time - $last_task->{last_completed_secs};

	my @response_strs = (
		getIRCData('slashd_lasttask', { task => $last_task })
	);

	my @cur_running_tasks = map { $st->{$_} }
		sort grep { $st->{$_}{in_progress} } keys %$st;
	push @response_strs, getIRCData('slashd_curtasks', { tasks => \@cur_running_tasks });

	my($slashd_not_ok, $check_slashd_data) = check_slashd();
	if ($slashd_not_ok) {
		push @response_strs, getIRCData('slashd_parent_gone');
	} elsif ($check_slashd_data) {
		push @response_strs, $check_slashd_data;
	}

	my $result = join ' -- ', @response_strs;
	send_msg($result, { $service => 1 });
	slashdLog("slashd: $result, cmd from $info->{event}{nick}");
}

{ # closure
# first checks come after 1 minute, so we are sure we joined the
# IRC channel OK.
my $next_check_slashd = $^T + 60;
sub possible_check_slashd {
	if (!$task_exit_flag && time() >= $next_check_slashd) {
		$next_check_slashd = time() + 20;
		my($not_ok, $response) = check_slashd();
		if ($not_ok) {
			# Parent slashd process seems to be gone.  Maybe
			# it just got killed and sent us the SIGUSR1 and
			# our $task_exit_flag is already set.  Pause a
			# moment and check that.
			sleep 1;
			if ($task_exit_flag) {
				# OK, forget this warning, just exit
				# normally.
				$not_ok = 0;
			}
		}
		if ($not_ok) {
			# Parent slashd process is gone, that's not good,
			# but the channel doesn't need to hear about it
			# every 20 seconds.
			$next_check_slashd = time() + 30 * 60;
			send_msg(getIRCData('slashd_parent_gone'));
		}
	}
}
} # end closure

sub check_slashd {
	my $parent_pid_str = "";
	if (!$has_proc_processtable) {
		# Don't know whether slashd is still present, can't check.
		# Return 0 meaning slashd is not not OK [sic], and a blank
		# string.
		return(0, '');
	}
	my $processtable = new Proc::ProcessTable;
	my $table = $processtable->table();
	my $response = '';
	for my $p (@$table) {
		next unless $p->{pid} == $parent_pid && $p->{fname} eq 'slashd';
		$response = getIRCData('slashd_parentpid', { process => $p });
		last;
	}
	my $ok = $response ? 1 : 0;
	return(!$ok, $response);
}

sub cmd_dbs {
	my($service, $info) = @_;
	my $slashdb = getCurrentDB();
	my $dbs = $slashdb->getDBs();
	my $dbs_data = $slashdb->getDBsReaderStatus(60);
	my $response;
	if (%$dbs_data) {
		for my $dbid (keys %$dbs_data) {
			$dbs_data->{$dbid}{virtual_user} = $dbs->{$dbid}{virtual_user};
			$dbs_data->{$dbid}{lag} = defined($dbs_data->{$dbid}{lag})
				? sprintf('%4.1f', $dbs_data->{$dbid}{lag} || 0)
				: '?';
			$dbs_data->{$dbid}{bog} = sprintf('%4.1f', $dbs_data->{$dbid}{bog} || 0);
		}
		my @dbids =
			sort { $dbs->{$a}{virtual_user} cmp $dbs->{$b}{virtual_user} }
			keys %$dbs_data;
		$response = getIRCData('dbs_response', { dbids => \@dbids, dbs => $dbs_data });
	} else {
		$response = getIRCData('dbs_nodata');
	}
	chomp $response;
	my @responses = split /\n/, $response;
	for my $r (@responses) {
		sleep 1;
		send_msg($r, { $service => 1 });
	}
	slashdLog("dbs: cmd from $info->{event}{nick}");
}

{ # closure
# first checks come after 1 minute, so we are sure we joined the
# IRC channel OK.
my $next_check_dbs = $^T + 60;
my $next_report_bad_dbs = 0;
sub possible_check_dbs {
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	return if $hushed;
	if (!$task_exit_flag && time() >= $next_check_dbs) {
		$next_check_dbs = time() + 20;
		my $dbs = $slashdb->getDBs();
		my $dbs_data = $slashdb->getDBsReaderStatus(60);
		my $ok = 1;
		for my $dbid (keys %$dbs_data) {
			$ok = 0 if !$dbs_data->{$dbid}{was_alive}
				|| !$dbs_data->{$dbid}{was_reachable}
				|| !$dbs_data->{$dbid}{was_running};
			$ok = 0 if $ok && $dbs_data->{$dbid}{lag} > ($constants->{ircslash_dbalert_lagthresh} || 30);
			$ok = 0 if $ok && $dbs_data->{$dbid}{bog} > ($constants->{ircslash_dbalert_bogthresh} || 30);
		}
		# "Great" means good enough to clear out a previously
		# reported alert.
		my $great = 1;
		for my $dbid (keys %$dbs_data) {
			$great = 0 if !$dbs_data->{$dbid}{was_alive}
				|| !$dbs_data->{$dbid}{was_reachable}
				|| !$dbs_data->{$dbid}{was_running};
			$great = 0 if $great && $dbs_data->{$dbid}{lag} > ($constants->{ircslash_dbalert_lagthresh} || 30)/2;
			$great = 0 if $great && $dbs_data->{$dbid}{bog} > ($constants->{ircslash_dbalert_bogthresh} || 30)/2;
		}
		if (!$ok) {
			# There's something about the DBs that we
			# should tell the IRC channel.
			sleep 1;
			if ($task_exit_flag) {
				# OK, forget this alert, just exit
				# normally.
				$ok = 1;
			}
		}
		if ($great) {
			# The DBs are fine, so reset the next-report time.
			if ($next_report_bad_dbs) {
				# They were previously reported as bad,
				# so now give an all-clear.
				my $all_clear = getIRCData('dbalert_allclear');
				send_msg($all_clear);
			}
			$next_report_bad_dbs = 0;
		}
		if (!$ok) {
			# One or more DBs are wonky, that's not good,
			# but the channel doesn't need to hear about it
			# every 20 seconds.
			if (time() >= $next_report_bad_dbs) {
				$next_report_bad_dbs = time() + 10 * 60;
				for my $dbid (keys %$dbs_data) {
					$dbs_data->{$dbid}{virtual_user} = $dbs->{$dbid}{virtual_user};
					$dbs_data->{$dbid}{lag} = defined($dbs_data->{$dbid}{lag})
						? sprintf('%4.1f', $dbs_data->{$dbid}{lag} || 0)
						: '?';
					$dbs_data->{$dbid}{bog} = sprintf('%4.1f', $dbs_data->{$dbid}{bog} || 0);
				}
				my @dbids =
					sort { $dbs->{$a}{virtual_user} cmp $dbs->{$b}{virtual_user} }
					keys %$dbs_data;
				my $response = getIRCData('dbs_response', { dbids => \@dbids, dbs => $dbs_data });
				chomp $response;
				my @responses = split /\n/, $response;
				my $prefix = getIRCData('dbalert_prefix');
#				if ($prefix && $prefix =~ /\S/) {
#					send_msg($prefix);
#				}
#				for my $r (@responses) {
#					sleep 1;
#					send_msg($r);
#				}
			}
		}
	}
}
} # end closure

############################################################

sub handle_remarks {
	my $slashdb = getCurrentDB();
	my $remarks = getObject('Slash::Remarks');
	return if $hushed || !$remarks;

	my $constants = getCurrentStatic();
	$next_remark_id ||= $slashdb->getVar('ircslash_nextremarkid', 'value', 1) || 1;
	my $system_remarks_ar = $remarks->getRemarksStarting($next_remark_id, { type => 'system' });

	my $sidprefix = "$constants->{absolutedir_secure}/article.pl?sid=";

	my $max_rid = 0;
	for my $system_remarks_hr (@$system_remarks_ar) {
		my $remark = $system_remarks_hr->{remark};
		if ($system_remarks_hr->{stoid}) {
			my $story = $slashdb->getStory($system_remarks_hr->{stoid});
			$remark .= " <$sidprefix$story->{sid}>";
		}
		send_msg($remark);
		$max_rid = $system_remarks_hr->{rid} if $system_remarks_hr->{rid} > $max_rid;
	}

	if ($max_rid) {
		$next_remark_id = $max_rid + 1;
		$slashdb->setVar('ircslash_nextremarkid', $next_remark_id);
	}
	
	my $remarks_ar = $remarks->getRemarksStarting($next_remark_id, { type => 'user' });
	return unless $remarks_ar && @$remarks_ar;

	my %story = ( );
	my %stoid_count = ( );
	my %uid_count = ( );
	for my $remark_hr (@$remarks_ar) {
		my $stoid = $remark_hr->{stoid};
		$stoid_count{$stoid}++;
		$story{$stoid} = $slashdb->getStory($stoid);
		$story{$stoid}{time_unix} = timeCalc($story{$stoid}{time}, "%s", "");
		my $uid = $remark_hr->{uid};
		$uid_count{$uid}++;
		$max_rid = $remark_hr->{rid} if $remark_hr->{rid} > $max_rid;
	}

	# If remarks are not active, just mark these as read and continue.
	if (!$remarks_active) {
		$next_remark_id = $max_rid + 1;
		$slashdb->setVar('ircslash_nextremarkid', $next_remark_id);
		return ;
	}

	# First pass:  outright strip out remarks from abusive users
	my %uid_blocked = ( );
	for my $uid (keys %uid_count) {
		# If a user's been ignored, block it.
		my $remark_user = $slashdb->getUser($uid);
		if ($remark_user->{noremarks}) {
			$uid_blocked{$uid} = 1;
		}
		# Or if a user has sent more than this many remarks in a day.
		elsif ($remarks->getUserRemarkCount($uid, 86400      ) > $constants->{ircslash_remarks_max_day}) {
			$uid_blocked{$uid} = 1;
		}
		# Or if a user has sent more than this many remarks in a month.
		elsif ($remarks->getUserRemarkCount($uid, 86400 *  30) > $constants->{ircslash_remarks_max_month}) {
			$uid_blocked{$uid} = 1;
		}
		# Or if a user has sent more than this many remarks in a year.
		elsif ($remarks->getUserRemarkCount($uid, 86400 * 365) > $constants->{ircslash_remarks_max_year}) {
			$uid_blocked{$uid} = 1;
		}
	}

	# We should have a second pass in here to delay/join up remarks
	# about stories that are getting lots of remarks, so we don't
	# hear over and over about the same story.
	my $regex = regexSid();
	STORY: for my $stoid (sort { $stoid_count{$a} <=> $stoid_count{$b} } %stoid_count) {
		# Skip a story that has already been live for a while.
		my $time_unix = $story{$stoid}{time_unix};
		next STORY if $time_unix < time - 600;

		my $url = "$sidprefix$story{$stoid}{sid}";
		my $remarks = "<$url>";
		my $do_send_msg = 0;
		my @stoid_remarks =
			grep { $_->{stoid} == $stoid }
			grep { ! $uid_blocked{$_->{uid}} }
			@$remarks_ar;
		REMARK: for my $i (0..$#stoid_remarks) {
			my $remark_hr = $stoid_remarks[$i];
			next if $uid_blocked{$remark_hr->{uid}};
			if ($i >= 3) {
				# OK, that's enough about this one story.
				# Summarize the rest.
				$remarks .= " (and " . (@stoid_remarks-$i) . " more)";
				last REMARK;
			}
			$do_send_msg = 1;
			$remarks .= " $remark_hr->{uid}:";
			if ($remark_hr->{remark} =~ $regex) {
				$remarks .= qq{<$sidprefix$remark_hr->{remark}>};
			} else {
				$remarks .= qq{"$remark_hr->{remark}"};
			}
		}
		if ($do_send_msg) {
			send_msg($remarks);
			# Every time we post remarks into the channel, we
			# wait a little longer before checking and sending
			# again.  This is so we don't flood.
			$next_handle_remarks += 20;
		}
	}
	$next_remark_id = $max_rid + 1;
	$slashdb->setVar('ircslash_nextremarkid', $next_remark_id);
}

# swiped from Net::XMPP::Connection
sub Net::Jabber::Client::Execute
{
    my $self = shift;
    my %args;
    while($#_ >= 0) { $args{ lc pop(@_) } = pop(@_); }

    $args{connectiontype} = "tcpip" unless exists($args{connectiontype});
    $args{connectattempts} = -1 unless exists($args{connectattempts});
    $args{connectsleep} = 5 unless exists($args{connectsleep});
    $args{register} = 0 unless exists($args{register});

    my %connect = $self->_connect_args(%args);

    $self->{DEBUG}->Log1("Execute: begin");

    my $connectAttempt = $args{connectattempts};

#    while(($connectAttempt == -1) || ($connectAttempt > 0))
    {

        $self->{DEBUG}->Log1("Execute: Attempt to connect ($connectAttempt)");

        my $status = $self->Connect(%connect);

        if (!(defined($status)))
        {
            $self->{DEBUG}->Log1("Execute: Server is not answering.  (".$self->GetErrorCode().")");
            $self->{CONNECTED} = 0;

            $connectAttempt-- unless ($connectAttempt == -1);
            sleep($args{connectsleep});
            next;
        }

        $self->{DEBUG}->Log1("Execute: Connected...");
        &{$self->{CB}->{onconnect}}() if exists($self->{CB}->{onconnect});

        my @result = $self->_auth(%args);

        if (@result && $result[0] ne "ok")
        {
            $self->{DEBUG}->Log1("Execute: Could not auth with server: ($result[0]: $result[1])");
            &{$self->{CB}->{onauthfail}}()
                if exists($self->{CB}->{onauthfail});
            
            if (!$self->{SERVER}->{allow_register} || $args{register} == 0)
            {
                $self->{DEBUG}->Log1("Execute: Register turned off.  Exiting.");
                $self->Disconnect();
                &{$self->{CB}->{ondisconnect}}()
                    if exists($self->{CB}->{ondisconnect});
                $connectAttempt = 0;
            }
            else
            {
                @result = $self->_register(%args);

                if ($result[0] ne "ok")
                {
                    $self->{DEBUG}->Log1("Execute: Register failed.  Exiting.");
                    &{$self->{CB}->{onregisterfail}}()
                        if exists($self->{CB}->{onregisterfail});
            
                    $self->Disconnect();
                    &{$self->{CB}->{ondisconnect}}()
                        if exists($self->{CB}->{ondisconnect});
                    $connectAttempt = 0;
                }
                else
                {
                    &{$self->{CB}->{onauth}}()
                        if exists($self->{CB}->{onauth});
                }
            }
        }
        else
        {
            &{$self->{CB}->{onauth}}()
                if exists($self->{CB}->{onauth});
        }
     } 

     1;
#         while($self->Connected())
#         {
# 
#             while(defined($status = $self->Process($args{processtimeout})))
#             {
#                 &{$self->{CB}->{onprocess}}()
#                     if exists($self->{CB}->{onprocess});
#             }
# 
#             if (!defined($status))
#             {
#                 $self->Disconnect();
#                 $self->{DEBUG}->Log1("Execute: Connection to server lost...");
#                 &{$self->{CB}->{ondisconnect}}()
#                     if exists($self->{CB}->{ondisconnect});
# 
#                 $connectAttempt = $args{connectattempts};
#                 next;
#             }
#         }
# 
#         last if $self->{DISCONNECTED};
#     }
# 
#     $self->{DEBUG}->Log1("Execute: end");
#     &{$self->{CB}->{onexit}}() if exists($self->{CB}->{onexit});
}

1;

__END__

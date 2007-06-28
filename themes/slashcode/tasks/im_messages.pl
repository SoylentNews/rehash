#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;

use Slash;
use Slash::Constants ':slashd';
use Slash::Utility;
use Net::OSCAR ':standard';
use Digest::MD5;

use vars qw(%task $me $task_exit_flag $password);

$task{$me}{timespec} = '* * * * *';
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $screenname = $constants->{im_screenname} || '';
	if (!length($screenname)) {
		slashdLog("No im_screenname, so this task would not be useful -- sleeping permanently");
		sleep 5 while !$task_exit_flag;
		return;
	}

	$password = $constants->{im_password} || '';
	if (!length($password)) {
		slashdLog("No im_password, so this task would not be useful -- sleeping permanently");
		sleep 5 while !$task_exit_flag;
		return;
	}

	# Pull out IM message info, system message info, and admins.
	my $code_in_str = join ',', map { "'$_'" } getMessageCodesByType('IM');
	my $im_mode = getMessageDeliveryByName("IM");
	my $messages_obj = getObject("Slash::Messages");
	my $sysmessage_code = $messages_obj->getDescription("messagecodes", "System Messages");
	my $sysmessage_ops = $messages_obj->getMessageCode($sysmessage_code);
	my $admins = $slashdb->getAdmins();
	my $sidprefix = "$constants->{absolutedir_secure}/article.pl?sid=";

	my $online = 0;
	my $oscar = Net::OSCAR->new();
	$oscar->set_callback_auth_challenge(\&auth_challenge);
	$oscar->set_callback_signon_done(sub { ++$online; });
	$oscar->set_callback_error(\&error);
	$oscar->signon(screenname => $screenname, password => undef);
	$oscar->timeout(40);

	my $retry_counter = 0;
	my $max_remark_id = 0;
	my $start_time = time();
	until ($task_exit_flag) {
		$oscar->do_one_loop();

		# Wait until we're fully online (signon_done() is called).
		# Try to connect once per second for 25 iterations.
		if (!$online) {
			if ($retry_counter++ == 25) {
				slashdLog("Exceeded 25 connect retries. -- exiting.");
				return;
			}
			sleep(1);
			next;
		}

		my %messages;
		# Pull out all IM compatible messages < 10 minutes old. Cache the message text.
		$messages{'message_drop'} = $slashdb->sqlSelectAllHashref(
			"id", "id, user, code", "message_drop",
			"(code IN ($code_in_str)) and
			(UNIX_TIMESTAMP(date) > (UNIX_TIMESTAMP(now()) - 600))");
		
		foreach my $id (sort keys %{$messages{'message_drop'}}) {
			my $message = $messages_obj->get($messages{'message_drop'}->{$id}{'id'});
			$messages{'message_drop'}->{$id}{'message'} = $message->{'message'};
			$slashdb->sqlDelete("message_drop", "id = " . $messages{'message_drop'}->{$id}{'id'});
		}
		
		# Pull out remarks and record the last remark seen (if this feature is active).
		if ($code_in_str =~ /$sysmessage_code/) {
			$messages{'remarks'} = $slashdb->sqlSelectAllHashref(
				"rid", "rid, stoid, remark", "remarks",
				"(type = 'system') and
				(UNIX_TIMESTAMP(time) >= $start_time) and
				(rid > $max_remark_id)");

			$max_remark_id = $slashdb->sqlSelect("max(rid)", "remarks") || 0;
		}
		
		foreach my $message_type (keys %messages) {
			foreach my $id (sort keys %{$messages{$message_type}}) {
				# Admin
				if ($message_type eq "remarks") {
					if ($messages{$message_type}->{$id}{'stoid'}) {
						my $story = $slashdb->getStory($messages{$message_type}->{$id}{'stoid'});
						$messages{$message_type}->{$id}{'remark'} .= " $sidprefix$story->{sid}";
					}

					foreach my $admin (keys %$admins) {
						next if getUserMessageDeliveryPref(
							$admins->{$admin}{'uid'},
							$sysmessage_code) != $im_mode;

						my $nick = $slashdb->getUser($admins->{$admin}{'uid'}, 'aim');
						next if !$nick;

						$oscar->send_im($nick, $messages{$message_type}->{$id}{'remark'});
						sleep(4);
					}
				}

				# User
				if ($message_type eq "message_drop") {
					next if getUserMessageDeliveryPref(
						$messages{$message_type}->{$id}{'user'},
						$messages{$message_type}->{$id}{'code'}) != $im_mode;

					my $nick = $slashdb->getUser($messages{$message_type}->{$id}{'user'}, 'aim');
					next if !$nick;

					$oscar->send_im($nick, $messages{'message_drop'}->{$id}{'message'});
					sleep(4);
				}
			}
		}
	}

	$oscar->signoff();

	return;
};


sub getMessageCodesByType {
	my($type) = @_;
	my @message_codes = ();

	my $slashdb = getCurrentDB();
	my $type_q = $slashdb->sqlQuote($type);
	my $code = $slashdb->sqlSelect("bitvalue", "message_deliverymodes", "name = $type_q");
	my $delivery_codes =
		$slashdb->sqlSelectAllHashref("code", "code, delivery_bvalue", "message_codes", "delivery_bvalue >= $code");
	foreach my $delivery_code (keys %$delivery_codes) {
		push(@message_codes, $delivery_codes->{$delivery_code}{"code"})
			if ($delivery_codes->{$delivery_code}{"delivery_bvalue"} & $code);
	}

	return(@message_codes);
}


sub getMessageDeliveryByName {
	my($name) = @_;

	my $slashdb = getCurrentDB();
	my $name_q = $slashdb->sqlQuote($name);
	my $code = $slashdb->sqlSelect("code", "message_deliverymodes", "name = $name_q");

	return($code);
}


sub getUserMessageDeliveryPref {
	my($uid, $code) = @_;

	my $slashdb = getCurrentDB();
	my $pref = $slashdb->sqlSelect("mode", "users_messages", "uid = $uid and code = $code");

	return($pref || 0);
}

sub auth_challenge {
	my($oscar, $challenge, $hash) = @_;

	my $md5 = Digest::MD5->new;
	$md5->add($challenge);
	$md5->add($password);
	$md5->add($hash);
	$oscar->auth_response($md5->digest, 1);
}


sub error {
	my($oscar, $connection, $errno, $error, $fatal) = @_;

	slashdLog("Received error '$error'");
	$task_exit_flag = 1 if $fatal;
}

1;

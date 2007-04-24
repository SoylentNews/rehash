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

	my ($virtual_user, $constants, $slashdb, $user) = @_;
	
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

	
	my $code_in_str = join ',', map { "'$_'" } getMessageCodesByType('IM');
	
	my $im_mode = getMessageDeliveryByName("IM");
	
	# Pull out admins for system messages
	my $sysmessage_code = getMessageCodeByName("System Messages");
	my $admin_users =
                $slashdb->sqlSelectColArrayref("uid", "users", "seclev >= '" . $sysmessage_code->{"seclev"} . "'");

	my $online = 0;	
	my $oscar = Net::OSCAR->new();
	$oscar->set_callback_auth_challenge(\&auth_challenge);
	$oscar->set_callback_signon_done(sub { ++$online; });
	$oscar->set_callback_error(\&error);
	$oscar->signon(screenname => $screenname, password => undef);
	$oscar->timeout(35);
	
	my $retry_counter = 0;
	my $max_remark_id = 0;
	my $start_time = time();
	until ($task_exit_flag) {
		$oscar->do_one_loop();

		if (!$online) {
			# Wait until we're fully online (signon_done() is called).
			# Try to connect once per second for 15 iterations.
			if ($retry_counter++ == 15) {
				slashdLog("Exceeded 15 connect retries. -- exiting.");
				return;
			}
			sleep(1);
			next;
		}

		my %messages;
		# Pull out all IM compatible messages < 10 minutes old.
		$messages{'message_drop'} = $slashdb->sqlSelectAllHashref(
			"id", "id, user, code, message", "message_drop",
			"(code IN ($code_in_str)) and
			(UNIX_TIMESTAMP(date) > (UNIX_TIMESTAMP(now()) - 600))");
		
		# Pull out remarks and record the last remark seen.
		$messages{'remarks'} = $slashdb->sqlSelectAllHashref(
			"rid", "rid, remark", "remarks",
			"(type = 'system') and
			(UNIX_TIMESTAMP(time) >= $start_time) and
			(rid > $max_remark_id)");

		$max_remark_id = $slashdb->sqlSelect("max(rid)", "remarks");
		
		foreach my $message_type (keys %messages) {
			foreach my $id (sort keys %{$messages{$message_type}}) {
				if ($message_type eq "remarks") {
					foreach my $admin_user (@$admin_users) {
						next if(getUserMessageDeliveryPref($admin_user, $sysmessage_code->{'code'}) != $im_mode);

						my $nick = getImNick($admin_user);
						next if !$nick;
						$oscar->send_im($nick, $messages{$message_type}->{$id}->{'remark'});
						sleep(2);
						
					}
				}

				if ($message_type eq "message_drop") {
					next if(getUserMessageDeliveryPref(
						$messages{$message_type}->{$id}->{'user'},
						$messages{$message_type}->{$id}->{'code'}) != $im_mode);

					my $nick = getImNick($messages{$message_type}->{$id}->{'user'});
					next if !$nick;

					#$oscar->send_im($nick, $messages{$message_type}->{$id}->{'message'});
					#sleep(2);
					
					#$slashdb->sqlDelete("message_drop", "id = " . $messages{$message_type}->{$id}->{'id'});
				}
			}
		}
	}

	$oscar->signoff();
	
	return;

};


sub getMessageCodesByType {

my $type = shift;
my @message_codes = ();

	my $slashdb = getCurrentDB();
	my $code = $slashdb->sqlSelect("bitvalue", "message_deliverymodes", "name = '$type'");
	my $delivery_codes =
		$slashdb->sqlSelectAllHashref("code", "code, delivery_bvalue", "message_codes", "delivery_bvalue >= $code");
	foreach my $delivery_code (keys %$delivery_codes) {
		push(@message_codes, $delivery_codes->{$delivery_code}->{"code"})
			if ($delivery_codes->{$delivery_code}->{"delivery_bvalue"} & $code);
	}

	return(@message_codes);

}


sub getMessageCodeByName {

my $name = shift;

	my $slashdb = getCurrentDB();
	my $code = $slashdb->sqlSelectHashref("code, seclev", "message_codes", "type = '$name'");

	return($code);

}


sub getMessageDeliveryByName {

my $name = shift;

	my $slashdb = getCurrentDB();
	my $code = $slashdb->sqlSelect("code", "message_deliverymodes", "name = '$name'");

	return($code);

}


sub getUserMessageDeliveryPref {

my ($uid, $code) = @_;

	my $slashdb = getCurrentDB();
	my $pref = $slashdb->sqlSelect("mode", "users_messages", "uid = '$uid' and code = '$code'");

	return($pref);

}

sub getImNick {

my $uid = shift;

	my $slashdb = getCurrentDB();
	my $nick = $slashdb->sqlSelect("value", "users_param", "uid = '" . $uid . "' and name = 'aim'");

	return($nick);

}


sub auth_challenge {

my ($oscar, $challenge, $hash) = @_;

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

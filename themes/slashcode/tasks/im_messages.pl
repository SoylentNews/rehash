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

use vars qw(%task $me);

$! = 0;
$task{$me}{timespec} = '* * * * *';
$task{$me}{on_startup} = 1;
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {

my($virtual_user, $constants, $slashdb, $user) = @_;
my ($pid, $oscar, $exit_flag, $delay, $online);
my $online_ready = 25;


	$SIG{INT} = $SIG{TERM} = sub { ++$exit_flag; };

	my $in;
	map { $in .= "'$_',"; } getMessageCodesByType("IM");
	chop($in);
	
	my $sysmessage_code = getMessageCodeByName("System Messages");
	
	# Username/password retrieval here
	#$oscar = Net::OSCAR->new();
	#$oscar->signon();
	#$oscar->timeout(10);

	$exit_flag  = 0;
	$delay  = 0;
	$online = 0;
	until($exit_flag) {
		#$oscar->do_one_loop();
		# This is a kludge to prevent do_one_loop() from tripping over itself.
		# One would think sleep() should work. do_one_loop() is probabably
		# implemented with alarm()
		++$delay if ($delay < $online_ready);
		$online = 1 if ($delay == $online_ready);
	
		# remove once the connection code is enabled
		sleep(40);
		
		my $messages = $slashdb->sqlSelectAllHashref(
			"id",
			"id, user, code, date, message",
			"message_drop",
			"code IN($in)"
		);
		foreach my $id (keys %$messages) {
			my $im_names;
			# If it's System Message, pull out admins. Exclusive to forwarding Jabber messages.
			if ($messages->{$id}->{"code"} eq $sysmessage_code->{"code"}) {
				$im_names = $slashdb->sqlSelectColArrayref(
					"uid",
					"users",
					"seclev >= '" . $sysmessage_code->{"seclev"} . "'"
				);
			}
			else {
				# Single user
				push(@$im_names, $messages->{$id}->{"user"});
			}

			foreach my $name (@$im_names) {
				# Look up IM nick for this uid
				my $im_name = $slashdb->sqlSelect(
					"value",
					"users_param",
					"uid = '" . $name . "' and name = 'aim'"
				);
				push(@{$messages->{$id}->{"im_name"}}, $im_name) if $im_name;
			}
			
			foreach my $name (@{$messages->{$id}->{"im_name"}}) {
				print "sending $name " . $messages->{$id}->{"message"} . "\n";
				#$oscar->send_im($name, $messages->{$id}->{"message"});
			}
			
			#$slashdb->sqlDelete("message_drop", "id = " . $messages->{$id}->{"id"});
		}
	}

	return;

};

# Modularize me at some point
sub getMessageCodesByType {

my ($type) = @_;
my @message_codes = ();

	my $slashdb = getCurrentDB();
	my $code = $slashdb->sqlSelect("bitvalue", "message_deliverymodes", "name = '$type'");
	my $delivery_codes = $slashdb->sqlSelectAllHashref(
		"code",
		"code, delivery_bvalue",
		"message_codes",
		"delivery_bvalue >= $code"
	);
	foreach my $delivery_code (keys %$delivery_codes) {
		push(@message_codes, $delivery_codes->{$delivery_code}->{"code"})
			if ($delivery_codes->{$delivery_code}->{"delivery_bvalue"} & $code);
	}

	return(@message_codes);

}


# Modularize me at some point
sub getMessageCodeByName {

my ($name) = @_;

	my $slashdb = getCurrentDB();
	my $code = $slashdb->sqlSelectHashref("code, seclev", "message_codes", "type = '$name'");
	return($code);

}

1;

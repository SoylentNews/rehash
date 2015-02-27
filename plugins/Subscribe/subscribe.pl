#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use utf8;

use Slash;
use Slash::Display;
use Slash::Utility;
use DateTime;
use DateTime::Format::MySQL;
use Slash::Constants qw(:web :messages);
use JSON;

sub main {
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	# lc just in case
	my $op = lc($form->{op});

	my($tbtitle);

	my $ops = {
		default		=> {
			function	=> \&edit,
			seclev		=> 1,
		},
		save		=> {
			function	=> \&save,
			seclev		=> 1,
		},
		paypal		=> {
			function	=> \&paypal,
			seclev		=> 1,
		},
		grant		=> {
			function	=> \&grant,
			seclev		=> 100
		},
		confirm 	=> {
			function	=> \&confirm,
			seclev		=> 1
		},
	};
	
	# Duplicating code because the redirect page needs to skip the
	# standard header and footer.
	$op = 'pause' if $form->{merchant_return_link};
	$user->{state}{page_adless} = 1 if $op eq 'pause';

	if (($user->{is_anon} && $op !~ /^(paypal|acsub|confirm)$/) ||
	   (!$user->{is_admin} && $constants->{subscribe_admin_only} == 1)) {
		my $rootdir = getCurrentSkin('rootdir');
		redirect("$rootdir/users.pl");
		return;
	}

	$op = 'default' unless $ops->{$op};

	header("subscribe") or return;

	my $retval = $ops->{$op}{function}->($form, $slashdb, $user, $constants);

	footer();
	writeLog($user->{uid}, $op);
}

##################################################################
# Edit options
sub edit {
	my($form, $slashdb, $user, $constants, $note) = @_;
	
	
	my $admin_flag = ($user->{is_admin}) ? 1 : 0;
	my $user_edit;
	if ($admin_flag && $form->{userfield}) {
		my $id = $form->{userfield};
		if ($id =~ /^\d+$/) {
			$user_edit = $slashdb->getUser($id);
		} else {
			$user_edit = $slashdb->getUser($slashdb->getUserUID($id));
		}
	} else {
		$user_edit = $user;
	}
	
	my $admin_block = 	slashDisplay('getUserAdmin', {
			field=> $user_edit->{uid},
			useredit => $user_edit
			}, { Return => 1, Page => 'users' }) if $admin_flag;

	my $title ='Configuring Subscription for '.strip_literal($user_edit->{nickname}).' ('.$user_edit->{uid}.')';
	
	my $dt_today = DateTime->today;
	my $dt_sub = DateTime::Format::MySQL->parse_date($user_edit->{subscriber_until});
	my $dt_epoch = DateTime->new( year => 1970, month => 1, day => 1 );
		
	my $was_sub = 0;
	my $subscriber = 0;
	
	if ( $dt_sub > $dt_epoch ){
			$was_sub = 1;
	}
	
	if ( $dt_sub >= $dt_today ){
			$subscriber = 1;
	}
	
	my $subscriber_until = $dt_sub->ymd;
	
	my $messages  = getObject('Slash::Messages');
	my $prefs = $messages->getPrefs($user_edit->{uid});
	my $deliverymodes   = $messages->getDescriptions('deliverymodes');
	my $bvdeliverymodes = $messages->getDescriptions('bvdeliverymodes');
	my $bvmessagecodes  = $messages->getDescriptions('bvmessagecodes');
	
	foreach my $bvmessagecode (keys %$bvmessagecodes) {
		$bvmessagecodes->{$bvmessagecode}->{'valid_bvdeliverymodes'} = [];
		foreach my $bvdeliverymode (keys %$bvdeliverymodes) {
			# skip if we have no valid delivery modes (i.e. off)
			if (!$bvmessagecodes->{$bvmessagecode}->{'delivery_bvalue'}) {
				delete $bvmessagecodes->{$bvmessagecode};
				last;
			}
			# skip all but Subscription messages.
			if (index($bvmessagecodes->{$bvmessagecode}->{'type'}, 'Subscription') == -1) {
				delete $bvmessagecodes->{$bvmessagecode};
				last;
			}
			# build our list of valid delivery modes
			if (($bvdeliverymodes->{$bvdeliverymode}->{'bitvalue'} & $bvmessagecodes->{$bvmessagecode}->{'delivery_bvalue'}) ||
			    ($bvdeliverymodes->{$bvdeliverymode}->{'bitvalue'} == 0)) {
				push(@{$bvmessagecodes->{$bvmessagecode}->{'valid_bvdeliverymodes'}}, $bvdeliverymodes->{$bvdeliverymode}->{'code'});
			}
		}
	}
	
	my $hs_check = $user_edit->{hide_subscription}	? $constants->{markup_checked_attribute} : '';
	
	my $prefs_titlebar = slashDisplay('prefs_titlebar', {
		tab_selected =>		'subscription',
		title  => $title
	}, { Return => 1 });
		
	slashDisplay("edit", {
		note => $note,
		user_edit => $user_edit,
		userfield =>$form->{userfield},
		prefs_titlebar	=> $prefs_titlebar,
		admin_flag => $admin_flag,
		admin_block  => $admin_block,
		was_sub => $was_sub,
		subscriber => $subscriber,
		subscriber_until => $subscriber_until,
		hs_check => $hs_check,
		prefs	=> $prefs,
		deliverymodes	=> $deliverymodes,
		bvmessagecodes  => $bvmessagecodes,
		bvdeliverymodes => $bvdeliverymodes
	});
	1;
}

##################################################################
# Save options
sub save {
	my($form, $slashdb, $user, $constants) = @_;
	my $user_edit;
	if ($form->{uid}
		&& $user->{is_admin}
		&& $form->{uid} =~ /^\d+$/
		&& !isAnon($form->{uid})) {
		$user_edit = $slashdb->getUser($form->{uid});
	}
	$user_edit ||= $user;

	my $has_buying_permission = 0;
	$has_buying_permission = 1 if $form->{secretword} eq $constants->{subscribe_secretword} or $user->{seclev} >= 100;
	
	my $user_update = { };
	$user_update->{"hide_subscription"} = $form->{hide_subscription} ? 1 : 0,

	my $messages  = getObject('Slash::Messages');
	my $messagecodes_sub = $messages->getDescriptions('messagecodes_sub');
	my %params;
	for my $code (keys %$messagecodes_sub) {
		if (!exists($form->{"deliverymodes_$code"}) || !$messages->checkMessageUser($code, $user_edit )) {
			$params{$code} = MSG_MODE_NONE;
		} else {
			$params{$code} = fixint($form->{"deliverymodes_$code"});
		}
	}
	$messages->setPrefsSub($user_edit->{uid}, \%params);
	
	$slashdb->setUser($user_edit->{uid}, $user_update);

	my $note = "<p><b>Subscription options saved.</b></p>";
	edit(@_, $note);
	1;
}


sub paypal {
	my($form, $slashdb, $user, $constants) = @_;
	my $txid = getCurrentForm('tx');
	my $subscribe = getObject('Slash::Subscribe');
	my ($error, $note);
	my $puid = $constanst->{anonymous_coward_uid};
	
	if (!$subscribe->paymentExists($txid)){
		#	IPN may have gotten the payment first.
		
		my $pp_pdt = $subscribe->ppDoPDT($txid);
		# use Data::Dumper; print STDERR Dumper($pp_pdt);
		
		$pp_pdt->{custom} = decode_json($pp_pdt->{custom}) || "";
		
		if (ref($pp_pdt) eq "HASH") {
			my $payment_net = $pp_pdt->{payment_gross} - $pp_pdt->{payment_fee};
			
			$puid = $pp_pdt->{custom}{puid};
			
			my $payment = {
				days => $pp_pdt->{custom}{days},
				uid	=> $pp_pdt->{custom}{uid},
				payment_net   => $payment_net,
				payment_gross => $pp_pdt->{payment_gross},
				payment_type  => $pp_pdt->{custom}{type},
				transaction_id => $pp_pdt->{txn_id},
				method => 'paypal',
				email => $pp_pdt->{custom}{from},
				raw_transaction  => encode_json($pp_pdt),
				puid => $pp_pdt->{custom}{puid}
			};
			
			if (!$subscribe->paymentExists($txid)){
				#	IPN can be fast so check again.
				
				my ($rows, $result, $warning);
				$rows = $subscribe->insertPayment($payment);
				if ($rows && $rows == 1) {
					$result =  $subscribe->addDaysToSubscriber($payment->{uid}, $payment->{days});
					if ($result && $result == 1){
						send_gift_msg($payment->{uid}, $payment->{puid}, $payment->{days}, $payment->{email}) if $payment->{payment_type} eq "gift";
					} else {
						$warning = "DEBUG: Payment accepted but user subscription not updated!\n" . Dumper($payment);
						print STDERR $warning;
						$error = "<p class='error'>Subscription not updated for transaction $txid.</p>";
					}
				} elsif (!$subscribe->paymentExists($txid)){
					#	IPN can be REAL fast, what have I told you.
					
					$warning = "DEBUG: Payment accepted but record not added to database!\n" . Dumper($payment);
					print STDERR $warning;
					$error = "<p class='error'>Payment transaction $txid already recorded or other error.</p>";
				}
			}
		} else {
			$error = "<p class='error'>PayPal PDT failed for transaction $txid.</p>";
		}
	}	
		
	if ($error){
		$note = $error . "<p class='error'>Transaction may still complete in the background. Please contact $constants->{adminmail} if you do not see your transaction complete.</p>";
	} else {
		$note = "<p><b>Transaction $txid completed.  Thank you for supporting $constants->{sitename}.</b></p>";
		
	}
	
	my $puid_user = $slashdb->getUser($puid);
	if ($puid_user->{is_anon}){
		acsub(@_, $note);
	} else {
		edit(@_, $note);
	}
	
}


sub grant {
	my($form, $slashdb, $user, $constants) = @_;
	my $subscribe = getObject('Slash::Subscribe');
	
	my $user_edit;
	if ($form->{uid} && $user->{is_admin} && $form->{uid} =~ /^\d+$/ && !isAnon($form->{uid})) {
		$user_edit = $slashdb->getUser($form->{uid});
	}
	$user_edit ||= $user;

	if (!$user->{is_admin}){
		my $note = "<p class='error'>Insufficient permission -- you aren't an admin</p>";
		edit(@_, $note);
	}

	my ($error, $note);
	my $user_update = { };
	my($days) = $form->{days} =~ /(\d+)/;
	
	my $payment = {
		days => $days,
		uid	=> $user_edit->{uid},
		payment_net   => '0',
		payment_gross => '0',
		payment_type  => 'grant',
		puid => $user->{uid},
	};

	my $rows = $subscribe->insertPayment($payment);
	if ($rows == 1) {
		my $result =  $subscribe->addDaysToSubscriber($payment->{uid}, $days);
		if ($result != 1){
			$error = "<p class='error'>Subscription not updated.</p>";
		}
	} else {
		my $warning = "DEBUG: Grant record not added to database! rows='$rows'\n" . Dumper($payment);
		print STDERR $warning;
		$error = "<p class='error'>Grant record not added to database.</p>";
	}

	if ($error){
		$note = $error;
	} else {
		$note = "<p><b>Grant Successful</b></p>";
	}

	edit(@_, $note);

}

sub confirm {
	my($form, $slashdb, $user, $constants) = @_;

	my $type = $form->{subscription_type};
	my $days = $form->{subscription_days};
	my $amount;

	if ($days == $constants->{subscribe_monthly_days}) {
		if ($form->{monthly_amount} >= $constants->{subscribe_monthly_amount}) {
			$amount = $form->{monthly_amount};
		} else {
			$amount = $constants->{subscribe_monthly_amount};
		}
	} elsif ($days == $constants->{subscribe_semiannual_days}) {
		if ($form->{semiannual_amount} >= $constants->{subscribe_semiannual_amount}) {
			$amount = $form->{semiannual_amount};
		} else {
			$amount = $constants->{subscribe_semiannual_amount};
		}
	} else {
		if ($form->{annual_amount} >= $constants->{subscribe_annual_amount}) {
			$amount = $form->{annual_amount};
		} else {
			$amount = $constants->{subscribe_annual_amount};
		}
	}

	my $uid = $form->{uid} || $user->{uid};
	my $sub_user = $slashdb->getUser($uid);
	my $puid = $user->{uid};
	my $title ="Confirm subscription and choose payment type";
	my $prefs_titlebar = slashDisplay('prefs_titlebar', {
		tab_selected =>		'subscription',
		title  => $title
	}, { Return => 1 });
	
	my $custom = encode_json({
		type           => $type,
		days           => $days,
		uid            => $uid,
		puid           => $puid,
		from           => $form->{from}
	});
	
	slashDisplay("confirm", {
		prefs_titlebar => $prefs_titlebar,
		type           => $type,
		days           => $days,
		amount         => $amount,
		uid            => $uid,
		puid           => $puid,
		sub_user       => $sub_user,
		user           => $user,
		custom         => $custom,
		from           => $form->{from}
	});
}

sub send_gift_msg {
	my ($uid, $puid, $days, $from) = @_;
	
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	my $receiving_user  = $slashdb->getUser($uid);
	my $purchasing_user = $slashdb->getUser($puid);

	my $message = slashDisplay('gift_msg', {
			receiving_user  => $receiving_user,
			purchasing_user => $purchasing_user,
			days 		=> $days,
			from		=> $from	
		}, { Return => 1, Nocomm => 1 } );
	my $title = "Gift subscription to $constants->{sitename}\n";
	doEmail($uid, $title, $message);
}


##################################################################
# AC sub
sub acsub {
	my($form, $slashdb, $user, $constants, $note) = @_;

	my $title ='Purcase Gift Subscription';
	
		
	slashDisplay("acsub", {
		note => $note,
		title	=> $title,
	});
	1;
}

createEnvironment();
main();
1;

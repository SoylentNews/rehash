#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants qw(:web);
use Slash::Display;
use Slash::Utility;
use Slash::XML;
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub main {
	my $slashdb   = getCurrentDB();
	my $reader    = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();

	my $post_ok   = $user->{state}{post};
	my $user_ok   = !$user->{is_anon};

	# possible value of "op" parameter in form
	my %ops = (
		userlogin	=> [ 1,				\&loginForm		],
		userclose	=> [ $user_ok,			\&loginForm		],
		mailpasswdform	=> [ 1,				\&mailPasswdForm	],
		mailpasswd	=> [ $post_ok,			\&mailPasswd		],
		changeprefs	=> [ $user_ok,			\&changePrefs		],
		saveprefs	=> [ $post_ok && $user_ok,	\&savePrefs		],
	);

	my $op = $form->{op};
	if (!$op || !exists $ops{$op} || !$ops{$op}[ALLOWED]) {
		$form->{op} = $op = 'userlogin';
	}

	# you are logged in, just go to your prefs (you were authenticated
	# in Slash::Apache::User, before you got here)
	if ($op eq 'userlogin' && $user_ok) {
		redirect(cleanRedirectUrl($form->{returnto}));
		return;
	}

	$ops{$op}[FUNCTION]->($slashdb, $reader, $constants, $user, $form);
	writeLog($user->{nickname});
}


#################################################################
sub loginForm {
	my($slashdb, $reader, $constants, $user, $form) = @_;

	header(getData('loginhead')) or return;
	slashDisplay('loginForm');
	footer();
}

#################################################################
sub mailPasswdForm {
	my($slashdb, $reader, $constants, $user, $form, $note) = @_;

	_validFormkey('generate_formkey') or return;

	header(getData('mailpasswdhead')) or return;
	slashDisplay('sendPasswdForm', { note => $note });
	footer();
}

#################################################################
sub mailPasswd {
	my($slashdb, $reader, $constants, $user, $form) = @_;

	_validFormkey(qw(max_post_check valid_check interval_check formkey_check))
		or return;

	my $error = 0;
	my @note;
	my $uid = $user->{uid};

	if ($form->{unickname}) {
		if ($form->{unickname} =~ /\@/) {
			$uid = $reader->getUserEmail($form->{unickname});

		} elsif ($form->{unickname} =~ /^\d+$/) {
			my $tmpuser = $reader->getUser($form->{unickname}, ['nickname', 'uid']);
			$uid = $tmpuser->{uid};

		} else {
			$uid = $reader->getUserUID($form->{unickname});
		}
	}

	if (!$uid || isAnon($uid)) {
		push @note, getData('mail_nonickname');
		$error++;
	}

	my $user_send = $reader->getUser($uid);

	if (!$error) {
		if ($reader->checkReadOnly('ipid') || $reader->checkReadOnly('subnetid')) {
			### the above methods are *wrong*
			push @note, getData('mail_readonly');
			$error++;

		} elsif ($reader->checkMaxMailPasswords($user_send)) {
			push @note, getData('mail_toooften');
			$error++;
		}
	}

	if ($error) {
		my $note = join ' ', @note;
#		$slashdb->resetFormkey($form->{formkey});
		return mailPasswdForm(@_, $note);
	}

	my $newpasswd = $slashdb->getNewPasswd($uid);
	my $tempnick  = fixparam($user_send->{nickname});
	my $subject   = getData('mail_subject', { nickname => $user_send->{nickname} });

	# Pull out some data passed in with the request.  Only the IP
	# number is actually trustworthy, the others could be forged.
	# Note that we strip the forgeable ones to make sure there
	# aren't any "<>" chars which could fool a stupid mail client
	# into parsing a plaintext email as HTML.
	my $r = Apache->request;
	my $remote_ip = $r->connection->remote_ip;

	my $xff = $r->header_in('X-Forwarded-For') || '';
	$xff =~ s/\s+/ /g;
	$xff = substr(strip_notags($xff), 0, 20);

	my $ua = $r->header_in('User-Agent') || '';
	$ua =~ s/\s+/ /g;
	$ua = substr(strip_attribute($ua), 0, 60);

	my $msg = getData('mail_msg', {
		newpasswd	=> $newpasswd,
		tempnick	=> $tempnick,
		remote_ip	=> $remote_ip,
		x_forwarded_for	=> $xff,
		user_agent	=> $ua,
	});

	doEmail($uid, $subject, $msg);
	$slashdb->setUserMailPasswd($user_send);
	mailPasswdForm(@_, getData('mail_mailed_note', { name => $user_send->{nickname} }));
}


#################################################################
sub changePrefs {
	my($slashdb, $reader, $constants, $user, $form, $note) = @_;

	# I am not going to add admin-modification right now,
	# because they way it is currently done sucks.  we should
	# handle that in one place only, not duplicate the same
	# damned code everywhere, and i will not be a party to
	# such madness.

	_validFormkey('generate_formkey') or return;

	header(getData('prefshead')) or return;
	slashDisplay('changePasswd', { note => $note });
	footer();
}


#################################################################
sub savePrefs {
	my($slashdb, $reader, $constants, $user, $form) = @_;

	_validFormkey(qw(max_post_check valid_check formkey_check))
		or return;

	my $error = 0;
	my @note;
	my $uid = $user->{uid};

	my $changepass = 0;
	if ($form->{pass1} || $form->{pass2} || length($form->{pass1}) || length($form->{pass2})) {
		$changepass = 1;
	}

	if ($changepass) {
		if ($form->{pass1} ne $form->{pass2}) {
			push @note, getData('passnomatch');
			$error++;
		}

		if (!$form->{pass1} || length $form->{pass1} < 6) {
			push @note, getData('passtooshort');
			$error++;
		}

		if ($form->{pass1} && length $form->{pass1} >= 20) {
			push @note, getData('passtoolong');
			$error++;
		}

		my $return_uid = $reader->getUserAuthenticate($uid, $form->{oldpass}, 1);
		if (!$return_uid || $return_uid != $uid) {
			push @note, getData('oldpassbad');
			$error++;
		}
	}

	my $note;
	if ($error) {
		push @note, getData('notchanged');
		$note = join ' ', @note;
#		$slashdb->resetFormkey($form->{formkey});
	} else {
		my $user_save = {};
		$user_save->{passwd} = $form->{pass1} if $changepass;
		$user_save->{session_login} = $form->{session_login};
		$user_save->{cookie_location} = $form->{cookie_location};

		# changed pass, so delete all logtokens
		$slashdb->deleteLogToken($user->{uid}, 1);

		if ($user->{admin_clearpass}
			&& !$user->{state}{admin_clearpass_thisclick}) {
			# User is an admin who sent their password in the clear
			# some time ago; now that it's been changed, we'll forget
			# about that incident, unless this click was sent in the
			# clear as well.
			$user_save->{admin_clearpass} = '';
		}

		$slashdb->setUser($user->{uid}, $user_save);
		$note = getData('passchanged');

		my $value  = $slashdb->getLogToken($uid, 1);
		my $cookie = bakeUserCookie($uid, $slashdb->getLogToken($uid, 1));
		setCookie('user', $cookie, $user_save->{session_login});
	}
	changePrefs(@_, $note);
}

sub _validFormkey {
	my(@checks) = @_;
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $op = $form->{op};

	# eventually change s/users/login/g
	my $formname = $op =~ /^mailpasswd(?:form)?$/ ? 'users/mp' : 'users'; 

	my $options = {};
	if (   !$constants->{plugin}{HumanConf}
	    || !$constants->{hc}
	    || (!$constants->{hc_sw_mailpasswd} && $op eq 'mailpasswdform')
	) {
		$options->{no_hc} = 1;
	}

	Slash::Utility::Anchor::getSectionColors();

	my $error;
	for (@checks) {
		warn "$op: $formname: $_\n";
		my $err = formkeyHandler($_, $formname, 0, \$error, $options);
	}
	warn "\n";

	if ($error) {
		header() or return;
		print $error;
		return 0;
	} else {
		# why does anyone care the length?
		getCurrentDB()->updateFormkey(0, length($ENV{QUERY_STRING}));
		return 1;
	}
}


createEnvironment();
main();
1;

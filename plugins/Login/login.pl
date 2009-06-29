#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash 2.003;
use Slash::Constants qw(:web :messages);
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
		userlogin       => [ 1,                         \&loginForm        ],
		userclose       => [ $user_ok,                  \&loginForm        ],
		newuserform     => [ 1,                         \&newUserForm      ],
		newuser         => [ $post_ok,                  \&newUser          ],
		mailpasswdform  => [ 1,                         \&mailPasswdForm   ],
		mailpasswd      => [ $post_ok,                  \&mailPasswd       ],
		changeprefs     => [ $user_ok,                  \&changePrefs      ],
		saveprefs       => [ $post_ok && $user_ok,      \&savePrefs        ],
		claim_openid    => [ 1,                         \&claimOpenID      ],
		verify_openid   => [ 1,                         \&verifyOpenID     ],
		delete_openid   => [ 1,                         \&deleteOpenID     ],
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

	my $login = getObject('Slash::Login');

	$ops{$op}[FUNCTION]->($slashdb, $reader, $constants, $user, $form, $login);
	writeLog($user->{nickname}, $op);
}

#################################################################
sub newUserForm {
	my($slashdb, $reader, $constants, $user, $form, $login, $note) = @_;

	_validFormkey('generate_formkey') or return;

	header(getData('newuserformhead')) or return;
	
	# This reskey is for the form's nickname availability button.
	my $reskey = getObject('Slash::ResKey');
	my $reskey_resource = 'ajax_base_modal_misc';
	my $rkey = $reskey->key($reskey_resource, { nostate => 1 });
	$rkey->create;

	slashDisplay('newUserForm', { note => $note, nick_rkey => $rkey, params => $form });
	
	footer();
}

#################################################################
sub newUser {
	my($slashdb, $reader, $constants, $user, $form) = @_;

	if (my $error =	_validFormkey(qw(max_post_check valid_check formkey_check), 1)) {
		return newUserForm(@_, $error);
	}

	my $plugins = $slashdb->getDescriptions('plugins');

	my @note;
	my $error = 0;

	# check if new nick is OK and if user exists
	my $newnick = nickFix($form->{newusernick});
	my $matchname = nick2matchname($newnick);
	if (!$newnick) {
		push @note, getData('nick_invalid');
		$error = 1;
	} elsif ($slashdb->getUserUIDWithMatchname($form->{newusernick})) {
		push @note, getData('duplicate_user', { nick => $newnick });
		$error = 1;
	} elsif (!$form->{email} || !emailValid($form->{email})) {
		push @note, getData('email_invalid');
		$error = 1;
	} elsif ($form->{email} ne $form->{email2}) {
		push @note, getData('email_do_not_match');
		$error = 1;
	} elsif ($slashdb->existsEmail($form->{email})) {
		push @note, getData('email_exists');
		$error = 1;
	} elsif ($matchname ne '' && $newnick ne '') {
		if ($constants->{newuser_portscan}) {
			my $is_trusted = $slashdb->checkAL2($user->{srcids}, 'trusted');
			if (!$is_trusted) {
				my $is_proxy = $slashdb->checkForOpenProxy($user->{hostip});
				if ($is_proxy) {
					push @note, getData('new_user_open_proxy', {
						unencoded_ip	=> $ENV{REMOTE_ADDR},
						port		=> $is_proxy,
					});
					$error = 1;
				}
			}
		}
	} else {
		push @note, getData('nick_invalid');
		$error = 1;
	}

	if (!$error) {
		my $uid = $slashdb->createUser(
			$matchname, $form->{email}, $newnick
		);
		if ($uid) {
			my $data = {};
			getOtherUserParams($data);

			$data->{tzcode} = $form->{tzcode} if defined $form->{tzcode};
			$data->{creation_ipid} = $user->{ipid};

			$slashdb->setUser($uid, $data) if keys %$data;

			$form->{pubkey} = $plugins->{'Pubkey'}
				? strip_nohtml($form->{pubkey}, 1)
				: '';

			# Default message preferences
			my $messages  = getObject('Slash::Messages');
			my %params;

			# We are defaulting these to webmail. If you're adding a new default,
			# make sure that type can handle MSG_MODE_WEB.
			my @default_types = (
				'Comment Moderation',
                                'Comment Reply',
                                'Journal Entry by Friend',
                                'Subscription Running Low',
                                'Subscription Expired',
                                'Achievement',
                                'Relationship Change'
                        );

			foreach my $type (@default_types) {
                                my $code = $messages->getDescription('messagecodes', $type);
                                $params{$code} = MSG_MODE_WEB() if $code;
                        }

			$params{MSG_CODE_NEWSLETTER()} = MSG_MODE_EMAIL();
			$params{MSG_CODE_HEADLINES()} = MSG_MODE_EMAIL();

			$messages->setPrefs($uid, \%params);

			my $user_send = $slashdb->getUser($uid);
			_sendMailPasswd(@_, $user_send);
			header(getData('newuserhead')) or return;
			my $thanksblock = $slashdb->getBlock('subscriber_plug', 'block');
			slashDisplay('newuser_msg', { thanksblock => $thanksblock });
			footer();
			return;
		} else {
#			$slashdb->resetFormkey($form->{formkey});	
			push @note, getData('duplicate_user', { 
				nick => $newnick,
			});
			$error = 1;
		}
	}

	if ($error) {
		my $note = join ' ', @note;
#		$slashdb->resetFormkey($form->{formkey});
		return newUserForm(@_, $note);
	}
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
	my($slashdb, $reader, $constants, $user, $form, $login, $note) = @_;

	_validFormkey('generate_formkey') or return;

	header(getData('mailpasswdhead')) or return;
	slashDisplay('sendPasswdForm', { note => $note });
	footer();
}

#################################################################
sub mailPasswd {
	my($slashdb, $reader, $constants, $user, $form) = @_;

	if (my $error =	_validFormkey(qw(max_post_check valid_check interval_check formkey_check), 1)) {
		return mailPasswdForm(@_, $error);
	}

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
		$error = 1;
	}

	my $user_send = $reader->getUser($uid);

	if ($user->{acl}{nopasswd}) {
		push @note, getData('mail_acl_nopasswd');
		$error = 1;
	}

	if (!$error) {
		# A user coming from a srcid that's been marked as not
		# acceptable for posting from also does not get to
		# mail a password to anyone.

		## XXX: we added uid to srcids, so now this is broken;
		## anywhere else we need to address this?
		my %srcids;
		@srcids{keys %{$user->{srcids}}} = values %{$user->{srcids}};
		delete $srcids{uid};

		if ($reader->checkAL2(\%srcids, [qw( nopost nopostanon spammer openproxy )])) {
			push @note, getData('mail_readonly');
			$error = 1;

		} elsif ($reader->checkMaxMailPasswords($user_send)) {
			push @note, getData('mail_toooften');
			$error = 1;
		}
	}

	if ($error) {
		my $note = join ' ', @note;
#		$slashdb->resetFormkey($form->{formkey});
		return mailPasswdForm(@_, $note);
	}

	_sendMailPasswd(@_, $user_send);
	mailPasswdForm(@_, getData('mail_mailed_note', { name => $user_send->{nickname} }));
}

#################################################################
sub _sendMailPasswd {
	my($slashdb, $reader, $constants, $user, $form, $login, $user_send) = @_;

	my $uid       = $user_send->{uid};
	my $newpasswd = $slashdb->getNewPasswd($uid);
	my $tempnick  = $user_send->{nickname};
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
}

#################################################################
sub changePrefs {
	my($slashdb, $reader, $constants, $user, $form, $login, $note) = @_;

	# I am not going to add admin-modification right now,
	# because they way it is currently done sucks.  we should
	# handle that in one place only, not duplicate the same
	# damned code everywhere, and i will not be a party to
	# such madness. -- pudge

	_validFormkey('generate_formkey') or return;

	header(getData('prefshead')) or return;
	slashDisplay('changePasswd', { note => $note });
	footer();
}

#################################################################
sub savePrefs {
	my($slashdb, $reader, $constants, $user, $form) = @_;

	_validFormkey(qw(max_post_check valid_check formkey_check regen_formkey))
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
			$error = 1;
		}

		if (!$form->{pass1} || length $form->{pass1} < 6) {
			push @note, getData('passtooshort');
			$error = 1;
		}

		if ($form->{pass1} && length $form->{pass1} > 20) {
			push @note, getData('passtoolong');
			$error = 1;
		}

		my $return_uid = $slashdb->getUserAuthenticate($uid, $form->{oldpass}, 1);
		if (!$return_uid || $return_uid != $uid) {
			push @note, getData('oldpassbad');
			$error = 1;
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

		my $cookie = bakeUserCookie($uid, $slashdb->getLogToken($uid, 1));
		setCookie('user', $cookie, $user_save->{session_login});
	}
	changePrefs(@_, $note);
}

#################################################################
sub _validFormkey {
	my(@checks, $return) = @_;
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $op = $form->{op};

	$return = pop @checks if $checks[-1] eq '1';

	# eventually change s/users/login/g
	my $formname = $op =~ /^mailpasswd(?:form)?$/ ? 'login/mp'
		     : $op =~ /^newuser(?:form)?$/ ? 'login/nu'
		     : 'login'; 

	my $options = {};
	if (   !$constants->{plugin}{HumanConf}
	    || !$constants->{hc}
	    || (!$constants->{hc_sw_mailpasswd} && $op eq 'mailpasswdform')
	    || (!$constants->{hc_sw_newuser}    && $op eq 'newuserform')
	) {
		$options->{no_hc} = 1;
	}

	Slash::Utility::Anchor::getSkinColors();

	$options->{fk_bare_errors} = 1;

	my $error;
	for (@checks) {
		my $err = formkeyHandler($_, $formname, 0, \$error, $options);
		last if $err || $error;
	}

	if ($error) {
		if ($return) {
			return $error;
		} else {
			header() or return;
			print $error;
			footer();
			return;
		}
	} else {
		if (!$options->{no_hc}) {
			my $hc = getObject("Slash::HumanConf");
			$hc->reloadFormkeyHC($formname) if $hc;
		}
		if ($return) {
			return;
		} else {
			getCurrentDB()->updateFormkey(0, length($ENV{QUERY_STRING}));
			return 1;
		}
	}
}

#################################################################
### this should maybe be somewhere else ... Slash::DB?
# this is to allow alternate parameters to be specified.  pass in
# your hash reference to be passed to setUser(), and this will
# add in those extra parameters.  add the parameters to string_param,
# type = otherusersparam, code = name of the param.  they will
# be checked for the main user prefs editing screens, and on
# user creation -- pudge
sub getOtherUserParams {
	my($data) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	my $user    = getCurrentUser();
	my $form    = getCurrentForm();
	my $params  = $reader->getDescriptions('otherusersparam');

	for my $param (keys %$params) {
		# set user too for output in this request
		$data->{$param} = $user->{$param} = defined($form->{$param})
			? $form->{$param}
			: $params->{$param};
	}
}

sub printOpenID {
	header("OpenID");
	print @_;
	footer();
}

sub allowOpenID {
	my($slashdb, $reader, $constants, $user, $form) = @_;

	if (!$constants->{openid_consumer_allow}) {
		printOpenID(getData("openid_not_enabled"));
		return;
	}

	# no more checks needed if we're logging in
	return 1 if $form->{openid_login};

	if ($user->{is_anon}) {
		printOpenID(getData("openid_not_logged_in"));
		return;
	}

	return 1;	
}

sub deleteOpenID {
	my($slashdb, $reader, $constants, $user, $form, $login) = @_;

	my $claimed_identity = $form->{openid_url};

	my $form_reskey = $form->{reskey};
	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('openid');
	if (!$form_reskey) {
		$rkey->create;
		printOpenID(
			slashDisplay('deleteOpenID',
				{ openid_url => $claimed_identity },
				{ Return => 1, Page => 'login' }
			)
		);
		return;
	}

	if (!$rkey->use) {
		return getLoginData("openid_reskey_failure_verify");
	}

	my $return = $login->deleteOpenID($claimed_identity) or return;
	changePrefs(@_, $return);
}

sub claimOpenID {
	my($slashdb, $reader, $constants, $user, $form, $login) = @_;

	return unless $login->allowOpenID;

	# slightly different behavior if we are logging in rather than
	# merely claiming an OpenID
	my $openid_login = $form->{openid_login} ? '&openid_login=1' : '';
	if ($openid_login && !$user->{is_anon}) {
		printOpenID(getData("openid_already_logged_in"));
		return;
	}

	my $csr = $login->getOpenID;
	my $identity = $csr->claimed_identity($form->{openid_url});
	unless ($identity) {
		printOpenID(getData("openid_invalid_identity"));
		return;
	}

	my $claimed_identity = $identity->claimed_url;
	# because google returns my identity as some generic openid.net URL,
	# we look at the server itself for a clue here; we save this generic
	# ID as the claimed ID, since all we really need it for is to just
	# tell us to use the returned OpenID later anyway, after sending it
	# through normalizeOpenID() -- pudge
	if ($identity->identity_server eq 'https://www.google.com/accounts/o8/ud') {
		# ooooooh, how i love google
		# ooooooh, how i love google
		# ooooooh, how i love google
		# because they first loved me
		$claimed_identity = $identity->identity_server;
	}
	my $claimed_uid = $slashdb->getUIDByOpenID($claimed_identity);
	if (!$openid_login && $claimed_uid) {
		# we do these checks in the DB anyway, but best to try them up front;
		# don't worry, there's no atomicity problems, as these checks are not
		# actually necessary; worse, we don't necessarily record this particular
		# OpenID anyway, so it might not match anything in the DB even if
		# it's already been added -- pudge
		if ($claimed_uid == $user->{uid}) {
			printOpenID(getData("openid_already_claimed_self", { claimed_identity => normalizeOpenID($claimed_identity) }));
		} else {
			printOpenID(getData("openid_already_claimed_other", { claimed_identity => normalizeOpenID($claimed_identity) }));
		}
		return;
	}

	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('openid', { nostate => 1 });
	$rkey->create;
	my $reskey_text = $rkey->reskey;
	$slashdb->setOpenIDResKey($claimed_identity, $reskey_text);

	my $slash_returnto = $form->{slash_returnto} ? ('&slash_returnto=' . fixparam($form->{slash_returnto})) : '';
	my $abs = root2abs();

	$identity->set_extension_args(
	        'http://openid.net/extensions/sreg/1.1', {
			required => '',
			optional => 'email,fullname,nickname,timezone',
		}
	);
	my $check_url = $identity->check_url(
		delayed_return => 1,
		return_to      => "$abs/login.pl?op=verify_openid$openid_login$slash_returnto&reskey=$reskey_text",
		trust_root     => "$abs/"
	);

	if ($check_url) {
		redirect($check_url);
		return;
	} else {
		printOpenID(getData("openid_error"));
		return;
	}
}

sub verifyOpenID {
	my($slashdb, $reader, $constants, $user, $form, $login) = @_;
	my @args = @_;

	return unless $login->allowOpenID;

	# slightly different behavior if we are logging in rather than
	# merely claiming an OpenID
	my $openid_login = $form->{openid_login} ? '&openid_login=1' : '';
	if ($openid_login && !$user->{is_anon}) {
		printOpenID(getData("openid_already_logged_in"));
		return;
	}

	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('openid', { nostate => 1, reskey => $form->{reskey} });

	my $csr = $login->getOpenID($form);

	$csr->handle_server_response(
		cancelled => sub {
			$rkey->use;
			printOpenID(getData("openid_verify_cancel"));
		},
		setup_required => sub {
			my($setup_url) = @_;
			if (!$rkey->touch) {
				printOpenID(getData("openid_reskey_failure_redirect"));
				return;
			}
			redirect($setup_url);
		},
		verified => sub {
			my($vident) = @_;
			if (!$rkey->use) {
				printOpenID(getData("openid_reskey_failure_verify"));
				return;
			}

			my $openid_url = $slashdb->checkOpenIDResKey($rkey->reskey);
			my $normalized_openid_url = normalizeOpenID($openid_url);
			if ($openid_url ne $normalized_openid_url) {
				# if different, it's because it's a site like Yahoo or Google
				# that doesn't actually check the identity we send to them,
				# but they still return a reliable, unique, (and very ugly)
				# OpenID URL, and we'll save that one, and never display it -- pudge
				$openid_url = $vident->{identity};
			} elsif ($openid_url ne $vident->{identity}) {
				printOpenID(getData("openid_verify_no_match", { openid_url => $openid_url }));
				return;
			}
			if ($openid_login) {
				my $claimed_uid = $slashdb->getUIDByOpenID($openid_url);
				if ($claimed_uid) {
					my $cookvalue = $slashdb->getLogToken($claimed_uid, 1);
					setCookie('user', bakeUserCookie($claimed_uid, $cookvalue), $slashdb->getUser($claimed_uid, 'session_login'));
					my $return_to = $form->{slash_returnto} || (root2abs() . '/');
					redirect($return_to);
				} else {
					# XXX find way to attach this OpenID automatically after logging in? for now, no.
					printOpenID(getData("openid_verify_no_login", { normalized_openid_url => $normalized_openid_url }));
				}
			} else {
				# XXX we do need error checking here ...
				$slashdb->setOpenID($user->{uid}, $openid_url);
				changePrefs(@args,
					getData("openid_verify_attach", { normalized_openid_url => $normalized_openid_url })
				);
			}
		},
		not_openid => sub {
			$rkey->use;
			printOpenID(getData("openid_not_openid"));
		},
		error => sub {
			my($err) = @_;
			$rkey->use;
			printOpenID(getData("openid_openid_error", { err => $err }));
		},
	);
}

createEnvironment();
main();
1;

#generate_formkey changeprefs (?) mailpasswdform
#max_post_check saveprefs mailpasswd newuser
#valid_check saveprefs mailpasswd newuser
#formkey_check saveprefs mailpasswd newuser
#interval_check mailpasswd
#regen_formkey saveprefs

#formname newuser users/nu
#formname mailpasswd users/mp

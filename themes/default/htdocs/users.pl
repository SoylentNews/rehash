#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use utf8;
use Digest::MD5 'md5_hex';
use Slash;
use Slash::Display;
use Slash::Utility;
use Slash::Constants qw(:messages);

#################################################################
sub main {
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $gSkin = getCurrentSkin();
	my $formname = $0;
	$formname =~ s/.*\/(\w+)\.pl/$1/;

	my $error_flag = 0;
	my $formkey = $form->{formkey};

	my $suadmin_flag = $user->{seclev} >= 10000 ? 1 : 0 ;
	my $postflag = $user->{state}{post};
	my $op = $form->{op} || '';
	$op  = lc($op);

	# savepasswd is a special case, because once it's called, you
	# have to reload the form, and you don't want to do any checks if
	# you've just saved.
	my $savepass_flag = $op eq 'savepasswd' ? 1 : 0 ;

	my $ops = {
		admin		=>  {
			function 	=> \&adminDispatch,
			seclev		=> 10000,	# if this should be lower,
							# then something else is
							# broken, because it allows
							# anyone with this seclev
							# to change their own seclev
			formname	=> $formname,
			# just in case we need it for something else, we have it ...
			checks		=> [ qw (generate_formkey) ],
		},
#		userlogin	=>  {
#			function	=> \&showInfo,
#			seclev		=> 1,
#			formname	=> $formname,
#			checks		=> [],
#			tab_selected_1	=> 'me',
#		},
		no_user	=>  {
			function	=> \&noUser,
			seclev		=> 0,
			formname	=> $formname,
			checks		=> [],
		},
		userinfo	=>  {
			function	=> \&showInfo,
			#I made this change, not all sites are going to care. -Brian
			seclev		=> $constants->{users_show_info_seclev},
			formname	=> $formname,
			checks		=> [],
			tab_selected_1	=> 'me',
			tab_selected_2	=> 'info',
		},
		usersubmissions	=>  {
			function	=> \&showSubmissions,
			#I made this change, not all sites are going to care. -Brian
			seclev		=> $constants->{users_show_info_seclev},
			checks		=> [],
			tab_selected_1	=> 'me',
		},
		usercomments	=>  {
			function	=> \&showComments,
			#I made this change, not all sites are going to care. -Brian
			seclev		=> $constants->{users_show_info_seclev},
			checks		=> [],
			tab_selected_1	=> 'me',
		},
		display	=>  {
			function	=> \&showInfo,
			#I made this change, not all sites are going to care. -Brian
			seclev		=> $constants->{users_show_info_seclev},
			formname	=> $formname,
			checks		=> [],
			tab_selected_1	=> 'me',
			tab_selected_2	=> 'info',
		},
#		savepasswd	=> {
#			function	=> \&savePasswd,
#			seclev		=> 1,
#			post		=> 1,
#			formname	=> $formname,
#			checks		=> [ qw (max_post_check valid_check
#						formkey_check regen_formkey) ],
#			tab_selected_1	=> 'preferences',
#			tab_selected_2	=> 'password',
#		},
		saveuseradmin	=> {
			function	=> \&saveUserAdmin,
			seclev		=> 10000,
			post		=> 1,
			formname	=> $formname,
			checks		=> [],
		},
		savehome	=> {
			function	=> \&saveHome,
			seclev		=> 1,
			post		=> 1,
			formname	=> $formname,
			checks		=> [ qw (valid_check
						formkey_check regen_formkey) ],
			tab_selected_1	=> 'preferences',
			tab_selected_2	=> 'home',
		},
		savecomm	=> {
			function	=> \&saveComm,
			seclev		=> 1,
			post		=> 1,
			formname	=> $formname,
			checks		=> [ qw (valid_check
						formkey_check regen_formkey) ],
			tab_selected_1	=> 'preferences',
			tab_selected_2	=> 'comments',
		},
		saveuser	=> {
			function	=> \&saveUser,
			seclev		=> 1,
			post		=> 1,
			formname	=> $formname,
			checks		=> [ qw (valid_check
						formkey_check regen_formkey) ],
			tab_selected_1	=> 'preferences',
			tab_selected_2	=> 'user',
		},
#		changepasswd	=> {
#			function	=> \&changePasswd,
#			seclev		=> 1,
#			formname	=> $formname,
#			checks		=> $savepass_flag ? [] :
#						[ qw (generate_formkey) ],
#			tab_selected_1	=> 'preferences',
#			tab_selected_2	=> 'password',
#		},
		editmiscopts	=> {
			function	=> \&editMiscOpts,
			seclev		=> 1,
			formname	=> $formname,
			checks		=> [ ],
			tab_selected_1	=> 'preferences',
			tab_selected_2	=> 'misc',
		},
		savemiscopts	=> {
			function	=> \&saveMiscOpts,
			seclev		=> 1,
			formname	=> $formname,
			checks		=> [ ],
			tab_selected_1	=> 'preferences',
			tab_selected_2	=> 'misc',
		},
		edituser	=> {
			function	=> \&editUser,
			seclev		=> 1,
			formname	=> $formname,
			checks		=> [ qw (generate_formkey) ],
			tab_selected_1	=> 'preferences',
			tab_selected_2	=> 'user',
		},
		authoredit	=> {
			function	=> \&editUser,
			seclev		=> 10000,
			formname	=> $formname,
			checks		=> [],
		},
		edithome	=> {
			function	=> \&editHome,
			seclev		=> 1,
			formname	=> $formname,
			checks		=> [ qw (generate_formkey) ],
			tab_selected_1	=> 'preferences',
			tab_selected_2	=> 'home',
		},
		editcomm	=> {
			function	=> \&editComm,
			seclev		=> 1,
			formname	=> $formname,
			checks		=> [ qw (generate_formkey) ],
			tab_selected_1	=> 'preferences',
			tab_selected_2	=> 'comments',
		},
#		newuser		=> {
#			function	=> \&newUser,
#			seclev		=> 0,
#			formname	=> "${formname}/nu",
#			checks		=> [ qw (max_post_check valid_check
#						formkey_check regen_formkey) ],
#		},
		newuseradmin	=> {
			function	=> \&newUserForm,
			seclev		=> 10000,
			formname	=> "${formname}/nu",
			checks		=> [],
		},
		previewbox	=> {
			function	=> \&previewSlashbox,
			seclev		=> 0,
			formname	=> $formname,
			checks		=> [],
		},
#		mailpasswd	=> {
#			function	=> \&mailPasswd,
#			seclev		=> 0,
#			formname	=> "${formname}/mp",
#			checks		=> [ qw (max_post_check valid_check
#						interval_check formkey_check ) ],
#			tab_selected_1	=> 'preferences',
#			tab_selected_2	=> 'password',
#		},
		validateuser	=> {
			function	=> \&validateUser,
			seclev		=> 1,
			formname	=> $formname,
			checks		=> ['regen_formkey'],
		},
#		userclose	=>  {
#			function	=> \&displayForm,
#			seclev		=> 0,
#			formname	=> $formname,
#			checks		=> [],
#		},
#		newuserform	=> {
#			function	=> \&displayForm,
#			seclev		=> 0,
#			formname	=> "${formname}/nu",
#			checks		=> [ qw (max_post_check
#						generate_formkey) ],
#		},
#		mailpasswdform 	=> {
#			function	=> \&displayForm,
#			seclev		=> 0,
#			formname	=> "${formname}/mp",
#			checks		=> [ qw (max_post_check
#						generate_formkey) ],
#			tab_selected_1	=> 'preferences',
#			tab_selected_2	=> 'password',
#		},
		displayform	=> {
			function	=> \&displayForm,
			seclev		=> 0,
			formname	=> $formname,
			checks		=> [ qw (generate_formkey) ],
			tab_selected_1	=> 'me',
		},
		listreadonly => {
			function	=> \&listReadOnly,
			seclev		=> 100,
			formname	=> $formname,
			checks		=> [],
			adminmenu	=> 'security',
			tab_selected	=> 'readonly',
		},
		listbanned => {
			function	=> \&listBanned,
			seclev		=> 100,
			formname	=> $formname,
			checks		=> [],
			adminmenu	=> 'security',
			tab_selected	=> 'banned',
		},
		topabusers 	=> {
			function	=> \&topAbusers,
			seclev		=> 100,
			formname	=> $formname,
			checks		=> [],
			adminmenu	=> 'security',
			tab_selected	=> 'abusers',
		},
		listabuses 	=> {
			function	=> \&listAbuses,
			seclev		=> 100,
			formname	=> $formname,
			checks		=> [],
		},
		force_acct_verify => {
			function	=> \&forceAccountVerify,
			seclev		=> 100,
			post		=> 1,
			formname 	=> $formname,
			checks		=> []
		},
		sendumessage => {
			function	=> \&sendUserMessage,
			seclev		=> 100,
			post		=> 1,
			formname 	=> $formname,
			checks		=> []
		}
	
	} ;

	
	# Note this is NOT the default op.  "userlogin" or "userinfo" is
	# the default op, and it's set either 5 lines down or about 100
	# lines down, depending.  Yes, that's dumb.  Yes, we should
	# change it.  It would require tracing through a fair bit of logic
	# though and I don't have the time right now. - Jamie
	$ops->{default} = $ops->{displayform};
	for (qw(newuser newuserform mailpasswd mailpasswdform changepasswd savepasswd userlogin userclose)) {
		$ops->{$_} = $ops->{default};
	}
	
	# Setup redirects for admin_block before page draws
	# Password
	if ($op eq 'admin' &&  $form->{changepasswd}){
		redirect("$constants->{real_rootdir}/login.pl?op=changeprefs&userfield=$form->{userfield}", "301");
	}
	# Messages
	if ($op eq 'admin' &&  $form->{messages}){
		redirect("$constants->{real_rootdir}/messages.pl?op=display_prefs&userfield=$form->{userfield}", "301");
	}
	# Submissions
	if ($op eq 'admin' &&  $form->{subscription}){
		redirect("$constants->{real_rootdir}/subscribe.pl?userfield=$form->{userfield}", "301");
	}

	my $errornote = "";
	if ($form->{op} && ! defined $ops->{$op}) {
		$errornote .= getError('bad_op', { op => $form->{op}}, 0, 1);
		$op = $user->{is_anon} ? 'userlogin' : 'userinfo'; 
	}

	if ($op eq 'userlogin' && ! $user->{is_anon}) {
		redirect(cleanRedirectUrl($form->{returnto} || ''));
		return;

	# this will only redirect if it is a section-based rootdir with
	# its rootdir different from real_rootdir
	} elsif ($op eq 'userclose' && $gSkin->{rootdir} ne $constants->{real_rootdir}) {
		redirect($constants->{real_rootdir} . '/login.pl?op=userclose');
		return;

	} elsif ($op =~ /^(?:newuser|newuserform|mailpasswd|mailpasswdform|changepasswd|savepasswd|userlogin|userclose|displayform)$/) {
		my $op = $form->{op};
		$op = 'changeprefs' if $op eq 'changepasswd';
		$op = 'saveprefs'   if $op eq 'savepasswd';
		redirect($constants->{real_rootdir} . '/login.pl?op=' . $op);
		return;

	# never get here now
	} elsif ($op eq 'savepasswd') {
		my $error_flag = 0;
		if ($user->{seclev} < 100) {
			for my $check (@{$ops->{savepasswd}{checks}}) {
				# the only way to save the error message is to pass by ref
				# $errornote and add the message to note (you can't print
				# it out before header is called)
				$error_flag = formkeyHandler($check, $formname, $formkey, \$errornote);
				last if $error_flag;
			}
		}

		if (! $error_flag) {
			$error_flag = savePasswd({ noteref => \$errornote }) ;
		}
		# change op to edituser and let fall through;
		# we need to have savePasswd set the cookie before
		# header() is called -- pudge
		if ($user->{seclev} < 100 && ! $error_flag) {
			$slashdb->updateFormkey($formkey, length($ENV{QUERY_STRING}));
		}
		$op = $error_flag ? 'changepasswd' : 'userinfo';
		$form->{userfield} = $user->{uid};
	}

	# Figure out what the op really is.
	$op = 'userinfo' if (! $form->{op} && ($form->{uid} || $form->{nick}));
	$op ||= $user->{is_anon} ? 'userlogin' : 'userinfo';
	if ($user->{is_anon} && ( ($ops->{$op}{seclev} > 0) || ($op =~ /^newuserform|mailpasswdform|displayform$/) )) {
		redirect($constants->{real_rootdir} . '/login.pl');
		return;
	} elsif ($user->{seclev} < $ops->{$op}{seclev}) {
		$op = 'userinfo';
	}
	if ($ops->{$op}{post} && !$postflag) {
		$op = $user->{is_anon} ? 'default' : 'userinfo';
	}

	if ($op eq 'sendumessage') {
		if($user->{seclev} >= 100) {
			$ops->{$op}{function}->({
			op		=> $op,
			tab_selected_1	=> $ops->{$op}{tab_selected_1} || "",
			note		=> $errornote,
			});
		}
		my $useredit = $slashdb->getUser($form->{touid});
		redirect($constants->{real_rootdir}."/~".$useredit->{nickname});
		return;
	}

	if($op eq "savehome") {
		$ops->{$op}->{function}->();
		if($user->{is_admin} && $form->{uid} != $user->{uid}) {
			redirect($constants->{real_rootdir}."/users.pl?op=admin&uid=$form->{uid}");
		}
		else {
			redirect($constants->{real_rootdir}."/my/homepage");
		}
		return;
	}

	# Print the header and very top stuff on the page.  We have
	# three ops that (may) end up routing into showInfo(), which
	# needs to do some stuff before it calls header(), so for
	# those three, don't bother.
	my $header;
	if ($op !~ /^(userinfo|display|saveuseradmin|admin$)/) {
		my $data = {
			adminmenu => $ops->{$op}{adminmenu} || 'admin',
			tab_selected => $ops->{$op}{tab_selected},
		};
		header(getMessage('user_header'), '', $data) or return;
		# This is a hardcoded position, bad idea and should be fixed -Brian
		# Yeah, we should pull this into a template somewhere...
		print getMessage('note', { note => $errornote }) if defined $errornote;
		$header = 1;
	}

	if ($constants->{admin_formkeys} || $user->{seclev} < 100) {

		my $done = 0;
		$done = 1 if $op eq 'savepasswd'; # special case
		$formname = $ops->{$op}{formname};

		# No need for HumanConf if the constant for it is not
		# switched on, or if the user's karma is high enough
		# to get out of it.  (But for "newuserform," the current
		# user's karma doesn't get them out of having to prove
		# they're a human for creating a *new* user.)
		my $options = {};
		if (	   !$constants->{plugin}{HumanConf}
			|| !$constants->{hc}
			|| !$constants->{hc_sw_newuser}
			   	&& ($formname eq 'users/nu' || $op eq 'newuserform')
			|| !$constants->{hc_sw_mailpasswd}
			   	&& ($formname eq 'users/mp' || $op eq 'mailpasswdform')
			|| $user->{karma} > $constants->{hc_maxkarma}
				&& !$user->{is_anon}
				&& !($op eq 'newuser' || $op eq 'newuserform')
		) {
			$options->{no_hc} = 1;
		}

		DO_CHECKS: while (!$done) {
			for my $check (@{$ops->{$op}{checks}}) {
				$ops->{$op}{update_formkey} = 1 if $check eq 'formkey_check';
				$error_flag = formkeyHandler($check, $formname, $formkey,
					undef, $options);
				if ($error_flag == -1) {
					# Special error:  HumanConf failed.  Go
					# back to the previous op, start over.
					if ($op =~ /^(newuser|mailpasswd)$/) {
						$op .= "form";
						$error_flag = 0;
						next DO_CHECKS;
					}
				} elsif ($error_flag) {
					$done = 1;
					last;
				}
			}
			$done = 1;
		}

		if (!$error_flag && !$options->{no_hc}) {
			my $hc = getObject("Slash::HumanConf");
			$hc->reloadFormkeyHC($formname) if $hc;
		}

	}

	errorLog("users.pl error_flag '$error_flag'") if $error_flag;

	# call the method
	my $retval;
	$retval = $ops->{$op}{function}->({
		op		=> $op,
		tab_selected_1	=> $ops->{$op}{tab_selected_1} || "",
		note		=> $errornote,
	}) if !$error_flag;

	return if !$retval;

	if ($op eq 'mailpasswd' && $retval) {
		$ops->{$op}{update_formkey} = 0;
	}

	if ($ops->{$op}{update_formkey} && $user->{seclev} < 100 && ! $error_flag) {
		# successful save action, no formkey errors, update existing formkey
		# why assign to an unused variable? -- pudge
		my $updated = $slashdb->updateFormkey($formkey, length($ENV{QUERY_STRING}));
	}
	# if there were legit error levels returned from the save methods
	# I would have it clear the formkey in case of an error, but that
	# needs to be sorted out later
	# else { resetFormkey($formkey); }

	writeLog($user->{nickname});
	footer();
}

#################################################################
sub checkList {
	my($string, $len) = @_;
	my $constants = getCurrentStatic();

	$string =~ s/[^\w,-]//g;
	my @items = grep { $_ } split /,/, $string;
	$string = join ",", @items;

	$len ||= $constants->{checklist_length} || 255;
	if (length($string) > $len) {
		print getError('checklist_err');
		$string = substr($string, 0, $len);
		$string =~ s/,?\w*$//g;
	} elsif (length($string) < 1) {
		$string = '';
	}

	return $string;
}

#################################################################
sub previewSlashbox {
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	my $block = $reader->getBlock($form->{bid}, ['title', 'block', 'url']);
	my $is_editable = $user->{seclev} >= 1000;

	my $title = getTitle('previewslashbox_title', { blocktitle => $block->{title} });
	slashDisplay('previewSlashbox', {
		width		=> '100%',
		title		=> $title,
		block 		=> $block,
		is_editable	=> $is_editable,
	});

	print portalbox($constants->{fancyboxwidth}, $block->{title},
		$block->{block}, '', $block->{url});
}

#################################################################
sub newUserForm {
	my $user = getCurrentUser();
	my $suadmin_flag = $user->{seclev} >= 10000;
	my $title = getTitle('newUserForm_title');

	slashDisplay('newUserForm', {
		title 		=> $title, 
		suadmin_flag 	=> $suadmin_flag,
	});
}

#################################################################
sub newUser {
	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	
	my $plugins = $slashdb->getDescriptions('plugins');
	my $title;
	my $suadmin_flag = $user->{seclev} >= 10000 ? 1 : 0;

	# Check if User Exists
	$form->{newusernick} = nickFix($form->{newusernick});
	my $matchname = nick2matchname($form->{newusernick});

	if (!$form->{email} || $form->{email} !~ /\@/) {
		print getError('email_invalid', 0, 1);
		return;
	} elsif ($form->{email} ne $form->{email2}) {
		print getError('email_do_not_match', 0, 1);
		return;	
	} elsif ($slashdb->existsEmail($form->{email})) {
		print getError('emailexists_err', 0, 1);
		return;
	} elsif ($matchname ne '' && $form->{newusernick} ne '') {
		if ($constants->{newuser_portscan}) {
			my $is_trusted = $slashdb->checkAL2($user->{srcids}, 'trusted');
			if (!$is_trusted) {
				my $is_proxy = $slashdb->checkForOpenProxy($user->{hostip});
				if ($is_proxy) {
					print getError('new user open proxy', {
						unencoded_ip	=> $ENV{REMOTE_ADDR},
						port		=> $is_proxy,
					});
					return;
				}
			}
		}
		my $uid;
		my $rootdir = getCurrentSkin('rootdir');

		$uid = $slashdb->createUser(
			$matchname, $form->{email}, $form->{newusernick}
		);
		if ($uid) {
			my $data = {};
			getOtherUserParams($data);

			for (qw(tzcode)) {
				$data->{$_} = $form->{$_} if defined $form->{$_};
			}
			$data->{creation_ipid} = $user->{ipid};

			$slashdb->setUser($uid, $data) if keys %$data;
			$title = getTitle('newUser_title');

			$form->{pubkey} = $plugins->{'Pubkey'} ?
				strip_nohtml($form->{pubkey}, 1) : '';
			print getMessage('newuser_msg', { 
				suadmin_flag	=> $suadmin_flag, 
				title		=> $title, 
				uid		=> $uid
			});

			if ($form->{newsletter} || $form->{comment_reply} || $form->{headlines}) {
				my $messages  = getObject('Slash::Messages');
				my %params;
				$params{MSG_CODE_COMMENT_REPLY()} = MSG_MODE_EMAIL()
					if $form->{comment_reply};
				$params{MSG_CODE_NEWSLETTER()}  = MSG_MODE_EMAIL()
					if $form->{newsletter};
				$params{MSG_CODE_HEADLINES()}   = MSG_MODE_EMAIL()
					if $form->{headlines};
				$messages->setPrefs($uid, \%params);
			}

			mailPasswd({ uid => $uid });

			return;
		} else {
			$slashdb->resetFormkey($form->{formkey});	
			print getError('duplicate_user', { 
				nick => $form->{newusernick},
			});
			return;
		}

	} else {
		print getError('duplicate_user', { 
			nick => $form->{newusernick},
		});
		return;
	}
}

#################################################################
sub mailPasswd {
	my($hr) = @_;
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	
	my $uid = $hr->{uid} || 0;

	my $slashdb = getCurrentDB();
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $form = getCurrentForm();

	print createMenu("users", {
		style		=> 'tabbed',
		justify		=> 'right',
		color		=> 'colored',
		tab_selected	=> $hr->{tab_selected_1} || "",
	});

	if (! $uid) {
		if ($form->{unickname} =~ /\@/) {
			$uid = $slashdb->getUserEmail($form->{unickname});

		} elsif ($form->{unickname} =~ /^\d+$/) {
			my $tmpuser = $slashdb->getUser($form->{unickname}, ['uid']);
			$uid = $tmpuser->{uid};

		} else {
			$uid = $slashdb->getUserUID($form->{unickname});
		}
	}

	my $user_edit;
	my $err_name = '';
	my $err_opts = {};
	if (!$uid || isAnon($uid)) {
		$err_name = 'mailpasswd_notmailed_err';
	}
	if (!$err_name) {
		# Check permissions of _this_ user, not the target
		# user, to determine whether this IP is OK'd to
		# send the mail to the target user.
		# XXXSRCID This should check a separate field like
		# 'openproxy' instead of piggybacking off of the
		# existing nopost and spammer
		my $srcids_to_check = $user->{srcids};
		$err_name = 'mailpasswd_readonly_err'
			if $reader->checkAL2($srcids_to_check, 'nopost');
	}
	if (!$err_name) {
		$err_name = 'mailpasswd_toooften_err'
			if $slashdb->checkMaxMailPasswords($user_edit);
	}
	
	if (!$err_name) {
		if ($constants->{mailpasswd_portscan}) {
			my $is_trusted = $slashdb->checkAL2($user->{srcids}, 'trusted');
			if (!$is_trusted) {
				my $is_proxy = $slashdb->checkForOpenProxy($user->{hostip});
				if ($is_proxy) {
					$err_name = 'mailpasswd open proxy';
					$err_opts = { unencoded_ip => $ENV{REMOTE_ADDR}, port => $is_proxy }; 
				}
			}

		}
	}

	if ($err_name) {
		print getError($err_name, $err_opts);
		$slashdb->resetFormkey($form->{formkey});	
		$form->{op} = 'mailpasswdform';
		displayForm();
		return(1);
	}

	my $newpasswd = $slashdb->getNewPasswd($uid);
	my $tempnick = $user_edit->{nickname};

	my $emailtitle = getTitle('mailPassword_email_title', {
		nickname	=> $user_edit->{nickname}
	}, 1);

	# Pull out some data passed in with the request.  Only the IP
	# number is actually trustworthy, the others could be forged.
	# Note that we strip the forgeable ones to make sure there
	# aren't any "<>" chars which could fool a stupid mail client
	# into parsing a plaintext email as HTML.
	my $r = Apache2::RequestUtil->request;
	my $remote_ip = $r->connection->remote_ip;
	my $xff = $r->headers_in->{'X-Real-IP'} || '';
	$xff =~ s/\s+/ /g;
	$xff = substr(strip_notags($xff), 0, 20);
	my $ua = $r->headers_in->{'User-Agent'} || '';
	$ua =~ s/\s+/ /g;
	$ua = substr(strip_attribute($ua), 0, 60);

	my $msg = getMessage('mailpasswd_msg', {
		newpasswd	=> $newpasswd,
		tempnick	=> $tempnick,
		remote_ip	=> $remote_ip,
		x_forwarded_for	=> $xff,
		user_agent	=> $ua,
	}, 1);

	doEmail($uid, $emailtitle, $msg) if $user_edit->{nickname};
	print getMessage('mailpasswd_mailed_msg', { name => $user_edit->{nickname} });
	$slashdb->setUserMailPasswd($user_edit);
}


#################################################################
sub showSubmissions {
	my($hr) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my($uid, $nickname);
	my $admin_flag = ($user->{is_admin}) ? 1 : 0;
	

	if ($form->{uid} or $form->{nick}) {
		$uid		= $form->{uid} || $reader->getUserUID($form->{nick});
		$nickname	= $reader->getUser($uid, 'nickname');
	} else {
		$nickname	= $user->{nickname};
		$uid		= $user->{uid};
	}
					
	my $title = "Submissions of " . getTitle('userInfo_user_title', { nick => $nickname, uid => $uid });
	
	my $submissions = "";
	my $pages = 0;
	my $page = $form->{page} || 1;
	my $count = ((($admin_flag || $user->{uid} == $uid) ? $constants->{submissions_all_page_size} : $constants->{submissions_accepted_only_page_size}) || "");
	
	my $sub_options->{accepted_only} = 1 if !$admin_flag && $user->{uid} != $uid;

	my $subcount = $reader->countSubmissionsByUID($uid, $sub_options);
	
	if ($subcount) {
		$pages = int($subcount/$count) + 1;
		my $sub_limit = (($page - 1) * $count) . ", " . $count;
		$submissions = $reader->getSubmissionsByUID($uid, $sub_limit, $sub_options);
	}
	

	slashDisplay('userSub', {
		nick							=> $nickname,
		admin_flag				=> $admin_flag,
		uid								=> $uid,
		nickmatch_flag		=> ($user->{uid} == $uid ? 1 : 0),
		submissions				=> $submissions,
		subcount					=> $subcount,
		page							=> $page,
		pages							=> $pages,
		title							=> $title,
	});
}

#################################################################
sub showComments {
	my($hr) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $commentstruct = [];
	my($uid, $nickname);

	my $user_edit;
	if ($form->{uid} || $form->{nick}) {
		$uid = $form->{uid} || $reader->getUserUID($form->{nick});
		$user_edit = $reader->getUser($uid);
	} else {
		$uid = $user->{uid};
		$user_edit = $user;
	}
	$nickname = $user_edit->{nickname};

	print createMenu("users", {
		style		=> 'tabbed',
		justify		=> 'right',
		color		=> 'colored',
		tab_selected	=> $user_edit->{uid} == $user->{uid} ? 'me' : 'otheruser',
	});

	my $min_comment = $form->{min_comment} || 0;
	$min_comment = 0 unless $user->{seclev} > $constants->{comments_more_seclev}
		|| $constants->{comments_more_seclev} == 2 && $user->{is_subscriber};
	my $comments_wanted = $user->{show_comments_num}
		|| $constants->{user_comment_display_default};
	my $commentcount = $reader->countCommentsByUID($uid);
	my $comments = $reader->getCommentsByUID(
		$uid, $comments_wanted, $min_comment
	) if $commentcount;

	if (ref($comments) eq 'ARRAY') {
		my $kinds = $reader->getDescriptions('discussion_kinds');
		for my $comment (@$comments) {
			# This works since $sid is numeric.
			$comment->{replies} = $reader->countCommentsBySidPid($comment->{sid}, $comment->{cid});

			# This is ok, since with all luck we will not be hitting the DB
			# ...however, the "sid" parameter here must be the string
			# based SID from either the "stories" table or from
			# pollquestions.
			my $discussion = $reader->getDiscussion($comment->{sid});

			if ($kinds->{ $discussion->{dkid} } =~ /^journal(?:-story)?$/) {
				$comment->{type} = 'journal';
			} elsif ($kinds->{ $discussion->{dkid} } eq 'poll') {
				$comment->{type} = 'poll';
			} else {
				$comment->{type} = 'story';
			}
			$comment->{disc_title}	= $discussion->{title};
			$comment->{url}	= $discussion->{url};
		}
	}

	my $mod_reader = getObject("Slash::$constants->{m1_pluginname}", { db_type => 'reader' });
	slashDisplay('userCom', {
		nick			=> $nickname,
		useredit		=> $user_edit,
		nickmatch_flag		=> ($user->{uid} == $uid ? 1 : 0),
		commentstruct		=> $comments,
		commentcount		=> $commentcount,
		min_comment		=> $min_comment,
		reasons			=> $mod_reader->getReasons(),
		karma_flag		=> 0,
		admin_flag		=> $user->{is_admin},
	});
}

sub noUser {
	print getData("no_user");
}

#################################################################
# arhgghgh. I love torture. I love pain. This subroutine satisfies
# these needs of mine
sub showInfo {
	my($hr) = @_;
	my $id = $hr->{uid} || 0;

	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();


	my $admin_flag = ($user->{is_admin}) ? 1 : 0;
	my $suadmin_flag = $user->{seclev} >= 10000 ? 1 : 0;
	my($title, $admin_block, $fieldkey) = ('', '', '');
	my $comments = undef;
	my $commentcount = 0;
	my $commentcount_time = 0;
	my $commentstruct = [];
	my $requested_user = {};
	my $time_period = $constants->{admin_comment_display_days} || 30;
	my $cid_for_time_period = $reader->getVar("min_cid_last_$time_period\_days",'value', 1) || 0;
	my $admin_time_period_limit = $constants->{admin_daysback_commentlimit} || 100;
	my $admin_non_time_limit    = $constants->{admin_comment_subsequent_pagesize} || 24;
	
	my($points, $nickmatch_flag, $uid, $nick);
	my($mod_flag, $karma_flag, $n) = (0, 0, 0);

	if ($admin_flag
		&& (defined($form->{show_m2s}) || defined($form->{show_m1s}) || defined($form->{m2_listing})))
	 {
		my $update_hr = {};
		$update_hr->{mod_with_comm} = $form->{show_m1s}
			if defined $form->{show_m1s};
		$update_hr->{m2_with_mod} =	($constants->{m2} ? $form->{show_m2s} : undef)
			if defined $form->{show_m2s};
		$update_hr->{show_m2_listing} =	($constants->{m2} ? $form->{m2_listing} : undef)
			if defined $form->{m2_listing};
		$slashdb->setUser($user->{uid}, $update_hr);
	}

	if (!$id && !$form->{userfield}) {
		if ($form->{uid} && ! $id) {
			$fieldkey = 'uid';
			($uid, $id) = ($form->{uid}, $form->{uid});
			$requested_user = isAnon($uid) ? $user : $reader->getUser($id);
			$nick = $requested_user->{nickname};
			$form->{userfield} = $nick if $admin_flag;

		} elsif ($form->{nick} && ! $id) {
			$fieldkey = 'nickname';
			($nick, $id) = ($form->{nick}, $form->{nick});
			$uid = $reader->getUserUID($id);
			if (isAnon($uid)) {
				$requested_user = $user;
				($nick, $uid, $id) = @{$user}{qw(nickname uid nickname)};
			} else {
				$requested_user = $reader->getUser($uid);
			}
			$form->{userfield} = $uid if $admin_flag;

		} else {
			$fieldkey = 'uid';
			($id, $uid) = ($user->{uid}, $user->{uid});
			$requested_user = $reader->getUser($uid);
			$form->{userfield} = $uid if $admin_flag;
		}

	} elsif ($user->{is_admin}) {
		$id ||= $form->{userfield} || $user->{uid};
		if ($id =~ /^[0-9a-f]{16}$/) {
			$requested_user->{nonuid} = 1;
			$fieldkey = "srcid";
			$requested_user->{$fieldkey} = $id;
		} elsif ($id =~ /^\d+$/) {
			# If it's longer than a uid could possibly be, it
			# must be a srcid.  The uid column right now is a
			# MEDIUMINT (max 16M) but at most might someday
			# be an INT (max 4G).
			if (length($id) > 11) {
				$requested_user->{nonuid} = 1;
				$fieldkey = "srcid";
				$requested_user->{$fieldkey} = $id;
			} else {
				$fieldkey = 'uid';
				$requested_user = $reader->getUser($id);
				$uid = $requested_user->{uid};
				$nick = $requested_user->{nickname};
				if ((my $conflict_id = $reader->getUserUID($id)) && $form->{userinfo}) {
					slashDisplay('showInfoConflict', {
						op		=> 'userinfo',
						id		=> $uid,
						nick		=> $nick,
						conflict_id	=> $conflict_id
					});
					return 1;
				}
			}

		} elsif (length($id) == 32) {
			$requested_user->{nonuid} = 1;
			if ($form->{fieldname}
				&& $form->{fieldname} =~ /^(ipid|subnetid)$/) {
				$fieldkey = $form->{fieldname};
			} else {
				$fieldkey = 'md5id';
			}
			$requested_user->{$fieldkey} = $id;
		} elsif ($id =~ /^(\d{1,3}\.\d{1,3}.\d{1,3}\.0)$/ 
				|| $id =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3})\.?$/) {
			$fieldkey = 'subnetid';
			$requested_user->{subnetid} = $1; 
			$requested_user->{subnetid} .= '.0' if $requested_user->{subnetid} =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}$/; 
			$requested_user->{nonuid} = 1;
			$requested_user->{subnetid} = md5_hex($requested_user->{subnetid});

		} elsif ($id =~ /^([\d+\.]+)$/) {
			$fieldkey = 'ipid';
			$requested_user->{nonuid} = 1;
			$id ||= $1;
			$requested_user->{ipid} = md5_hex($1);

		} elsif ($id =~ /^(.*@.*\..*?)$/) {
			# check for email addy, but make it by uid
			$fieldkey = 'uid';
			$id = $uid = $reader->getUserEmail($id);
			$requested_user = $reader->getUser($uid);
			$nick = $requested_user->{nickname};

		} else {  # go by nickname, but make it by uid
			$fieldkey = 'uid';
			$id = $uid = $reader->getUserUID($id);
			$requested_user = $reader->getUser($uid);
			$nick = $requested_user->{nickname};
		}
		
	} else {
		$fieldkey = 'uid';
		($id, $uid) = ($user->{uid}, $user->{uid});
		$requested_user = $reader->getUser($uid);
	}

	# Can't get user data for the anonymous user.
	if ($fieldkey eq 'uid' && isAnon($uid)) {
		header(getMessage('user_header')) or return;
		return displayForm();
	}

	my $user_change = { };
	if ($fieldkey eq 'uid' && !$user->{is_anon}
		&& $uid != $user->{uid} && !isAnon($uid)) {
		# Store the fact that this user last looked at that user.
		# For maximal convenience in stalking.
		$user_change->{lastlookuid} = $uid;
		$user_change->{lastlooktime} = time;
		$user->{lastlookuid} = $uid;
		$user->{lastlooktime} = time;
		$hr->{tab_selected_1} = 'otheruser';
	}

	# showInfo's header information is delayed until here, because
	# the target user's info is not available until here.
	vislenify($requested_user);
	header(getMessage('user_header', { useredit => $requested_user, fieldkey => $fieldkey })) or return;
	# This is a hardcoded position, bad idea and should be fixed -Brian
	# Yeah, we should pull this into a template somewhere...
	print getMessage('note', { note => $hr->{note} }) if defined $hr->{note};

	print createMenu("users", {
		style		=> 'tabbed',
		justify		=> 'right',
		color		=> 'colored',
		tab_selected	=> $hr->{tab_selected_1} || "",
	});

	my $comments_wanted = $user->{show_comments_num}
		|| $constants->{user_comment_display_default};
	my $min_comment = $form->{min_comment} || 0;
	$min_comment = 0 unless $user->{seclev} > $constants->{comments_more_seclev}
		|| $constants->{comments_more_seclev} == 2 && $user->{is_subscriber};

	my($netid, $netid_vis) = ('', '');

	my $comment_time;
	my $non_admin_limit = $comments_wanted;

	if ($requested_user->{nonuid}) {
		$requested_user->{fg} = $user->{fg};
		$requested_user->{bg} = $user->{bg};

		if ($requested_user->{ipid}) {
			$netid = $requested_user->{ipid} ;

		} elsif ($requested_user->{md5id}) {
			$netid = $requested_user->{md5id} ;

		} elsif ($requested_user->{srcid}) {
			$netid = $requested_user->{srcid} ;
		} else {
			$netid = $requested_user->{subnetid} ;
		}

		my $data = {
			id => $id,
			md5id => $netid,
		};
		vislenify($data); # add $data->{md5id_vis}
		$netid_vis = $data->{md5id_vis};

		$title = getTitle('user_netID_user_title', $data);

		$admin_block = getUserAdmin($netid, $fieldkey, 0) if $admin_flag;

		if ($form->{fieldname}) {
			if ($form->{fieldname} eq 'ipid') {
				$commentcount 		= $reader->countCommentsByIPID($netid);
				$commentcount_time 	= $reader->countCommentsByIPID($netid, { cid_at_or_after => $cid_for_time_period });
				$comments = getCommentListing("ipid", $netid,
					$min_comment, $time_period, $commentcount, $commentcount_time, $cid_for_time_period, 
					$non_admin_limit, $admin_time_period_limit, $admin_non_time_limit)
						if $commentcount;
			} elsif ($form->{fieldname} eq 'subnetid') {
				$commentcount 		= $reader->countCommentsBySubnetID($netid);
				$commentcount_time	= $reader->countCommentsBySubnetID($netid, { cid_at_or_after => $cid_for_time_period });
				$comments = getCommentListing("subnetid", $netid,
					$min_comment, $time_period, $commentcount, $commentcount_time, $cid_for_time_period,
					$non_admin_limit, $admin_time_period_limit, $admin_non_time_limit)
						if $commentcount;

			} else {
				delete $form->{fieldname};
			}
		}
		if (!defined($comments)) {
			# Last resort; here for backwards compatibility mostly.
			my $type;
			($commentcount,$type) = $reader->countCommentsByIPIDOrSubnetID($netid);
			$commentcount_time = $reader->countCommentsByIPIDOrSubnetID($netid, { cid_at_or_after => $cid_for_time_period });
			if ($type eq "ipid") {
				$comments = getCommentListing("ipid", $netid,
					$min_comment, $time_period, $commentcount, $commentcount_time, $cid_for_time_period,
					$non_admin_limit, $admin_time_period_limit, $admin_non_time_limit)
						if $commentcount;
			} elsif ($type eq "subnetid") {
				$comments = getCommentListing("subnetid", $netid,
					$min_comment, $time_period, $commentcount, $commentcount_time,  $cid_for_time_period,
					$non_admin_limit, $admin_time_period_limit, $admin_non_time_limit)
						if $commentcount;
			}
		}	
	} else {
		$admin_block = getUserAdmin($id, $fieldkey, 1) if $admin_flag;

		$commentcount      = $reader->countCommentsByUID($requested_user->{uid});
		$commentcount_time = $reader->countCommentsByUID($requested_user->{uid}, { cid_at_or_after => $cid_for_time_period });
		$comments = getCommentListing("uid", $requested_user->{uid},
			$min_comment, $time_period, $commentcount, $commentcount_time, $cid_for_time_period,
			$non_admin_limit, $admin_time_period_limit, $admin_non_time_limit,
			{ use_uid_cid_cutoff => 1 })
				if $commentcount;
		$netid = $requested_user->{uid};
	}

	# Grab the nicks of the uids we have, we're going to be adding them
	# into the struct.
	my @users_extra_cols_wanted       = qw( nickname );
	my @discussions_extra_cols_wanted = qw( type );
	my $uid_hr = { };
	my $sid_hr = { };
	if ($comments && @$comments) {
		my %uids = ();
		my %sids = ();
		for my $c (@$comments) {
			$uids{$c->{uid}}++;
			$sids{$c->{sid}}++;
		}
		my $uids = join(", ", sort { $a <=> $b } keys %uids);
		my $sids = join(", ", sort { $a <=> $b } keys %sids);
		$uid_hr = $reader->sqlSelectAllHashref(
			"uid",
			"uid, " . join(", ", @users_extra_cols_wanted),
			"users",
			"uid IN ($uids)"
		);
		
		$sid_hr = $reader->sqlSelectAllHashref(
			"id",
			"id, " . join(", ", @discussions_extra_cols_wanted),
			"discussions",
			"id IN ($sids)"
		);
		
	}

	my $cids_seen = {};
	my $kinds = $slashdb->getDescriptions('discussion_kinds');
	for my $comment (@$comments) {
		$cids_seen->{$comment->{cid}}++;
		my $type;
		# This works since $sid is numeric.
		my $replies = $reader->countCommentsBySidPid($comment->{sid}, $comment->{cid});

		# This is cached.
		my $discussion = $reader->getDiscussion($comment->{sid});
#use Data::Dumper; if ($discussion && !$discussion->{dkid}) { print STDERR scalar(gmtime) . " users.pl discussion but no dkid: " . Dumper($discussion) }
		if (!$discussion || !$discussion->{dkid}) {
			# A comment with no accompanying discussion;
			# basically we pretend it doesn't exist.
			next;
		} elsif ($kinds->{ $discussion->{dkid} } =~ /^journal(?:-story)?$/) {
			$type = 'journal';
		} elsif ($kinds->{ $discussion->{dkid} } eq 'poll') {
			$type = 'poll';
		} else {
			$type = 'story';
		}

		$comment->{points} += $user->{karma_bonus}
			if $user->{karma_bonus} && $comment->{karma_bonus} eq 'yes';
		$comment->{points} += $user->{subscriber_bonus}
			if $user->{subscriber_bonus} && $comment->{subscriber_bonus} eq 'yes';

		# fix points in case they are out of bounds
		$comment->{points} = $constants->{comment_minscore} if $comment->{points} < $constants->{comment_minscore};
		$comment->{points} = $constants->{comment_maxscore} if $comment->{points} > $constants->{comment_maxscore};
		vislenify($comment);
		my $data = {
			pid 		=> $comment->{pid},
			url		=> $discussion->{url},
			disc_type 	=> $type,
			disc_title	=> $discussion->{title},
			disc_time	=> $discussion->{ts},
			sid 		=> $comment->{sid},
			cid 		=> $comment->{cid},
			subj		=> $comment->{subject},
			cdate		=> $comment->{date},
			pts		=> $comment->{points},
			reason		=> $comment->{reason},
			uid		=> $comment->{uid},
			replies		=> $replies,
			ipid		=> $comment->{ipid},
			ipid_vis	=> $comment->{ipid_vis},
			karma		=> $comment->{karma},
			tweak		=> $comment->{tweak},
			tweak_orig	=> $comment->{tweak_orig},
		
		};
		#Karma bonus time

		for my $col (@users_extra_cols_wanted) {
			$data->{$col} = $uid_hr->{$comment->{uid}}{$col} if defined $uid_hr->{$comment->{uid}}{$col};
		}
		for my $col(@discussions_extra_cols_wanted) {
			$data->{$col} = $sid_hr->{$comment->{sid}}{$col} if defined $sid_hr->{$comment->{sid}}{$col};
		}
		push @$commentstruct, $data;
	}
#	if (grep { !defined($_->{disc_time}) || !defined($_->{sid}) } @$commentstruct) { use Data::Dumper; print STDERR "showInfo undef in commentstruct for id=$id: " . Dumper($commentstruct) }
	# Sort so the chosen group of comments is sorted by discussion
	@$commentstruct = sort {
		$b->{disc_time} cmp $a->{disc_time} || $b->{sid} <=> $a->{sid}
	} @$commentstruct
		unless $user->{user_comment_sort_type} && $user->{user_comment_sort_type} == 1;

	my $cid_list = [ keys %$cids_seen ];
	my $cids_to_mods = {};
	my $mod_reader = getObject("Slash::$constants->{m1_pluginname}", { db_type => 'reader' });
	if ($constants->{m1} && $admin_flag && $constants->{show_mods_with_comments}) {
		my $comment_mods = $mod_reader->getModeratorCommentLog("DESC",
			$constants->{mod_limit_with_comments}, "cidin", $cid_list);
	
		# Loop through mods and group them by the sid they're attached to
		while (my $mod = shift @$comment_mods) {
			push @{$cids_to_mods->{$mod->{cid}}}, $mod;
		}
	}

	my $sub_limit = ((($admin_flag || $user->{uid} == $requested_user->{uid}) ? $constants->{submissions_all_page_size} : $constants->{submissions_accepted_only_page_size}) || "");
	
	my $sub_options = { limit_days => 365 };
	$sub_options->{accepted_only} = 1 if !$admin_flag && $user->{uid} != $requested_user->{uid};

	my $sub_field = $form->{fieldname};
	
	my ($subcount, $ret_field) = $reader->countSubmissionsByNetID($netid, $sub_field)
		if $requested_user->{nonuid};
	my $submissions = $reader->getSubmissionsByNetID($netid, $ret_field, $sub_limit, $sub_options)
		if $requested_user->{nonuid};

        my $ipid_hoursback = $constants->{istroll_ipid_hours} || 72;
	my $uid_hoursback = $constants->{istroll_uid_hours} || 72;

	if ($requested_user->{nonuid}) {
		slashDisplay('netIDInfo', {
			title			=> $title,
			id			=> $id,
			useredit		=> $requested_user,
			commentstruct		=> $commentstruct || [],
			commentcount		=> $commentcount,
			min_comment		=> $min_comment,
			admin_flag		=> $admin_flag,
			admin_block		=> $admin_block,
			netid			=> $netid,
			netid_vis		=> $netid_vis,
			reasons			=> $mod_reader->getReasons(),
			ordered			=> $mod_reader->getReasonsOrder(),
			subcount		=> $subcount,
			submissions		=> $submissions,
			hr_hours_back		=> $ipid_hoursback,
			cids_to_mods		=> $cids_to_mods,
			comment_time		=> $comment_time
		});

	} else {
		if (! $requested_user->{uid}) {
			print getError('userinfo_idnf_err', { id => $id, fieldkey => $fieldkey});
			return 1;
		}

		$karma_flag = 1 if $admin_flag;
		$requested_user->{nick_plain} = $nick ||= $requested_user->{nickname};
		$nick = strip_literal($nick);

		if ($requested_user->{uid} == $user->{uid}) {
			$karma_flag = 1;
			$nickmatch_flag = 1;
			$points = $requested_user->{points};

			$mod_flag = 1 if $points > 0;

			$title = getTitle('userInfo_main_title', { nick => $nick, uid => $uid });

		} else {
			$title = getTitle('userInfo_user_title', { nick => $nick, uid => $uid });
		}

		my $lastjournal = _get_lastjournal($uid);
		
		my $metamods;
		if ($constants->{m2} && $admin_flag) {
			my $metamod_reader = getObject('Slash::Metamod', { db_type => 'reader' });
			$metamods = $metamod_reader->getMetamodlogForUser($uid, 30);
		}


		slashDisplay('userInfo', {
			title			=> $title,
			uid			=> $uid,
			useredit		=> $requested_user,
			points			=> $points,
			commentstruct		=> $commentstruct || [],
			commentcount		=> $commentcount,
			min_comment		=> $min_comment,
			nickmatch_flag		=> $nickmatch_flag,
			mod_flag		=> $mod_flag,
			karma_flag		=> $karma_flag,
			admin_block		=> $admin_block,
			admin_flag 		=> $admin_flag,
			suadmin_flag 		=> $suadmin_flag,
			reasons			=> $mod_reader->getReasons(),
			lastjournal		=> $lastjournal,
			hr_hours_back		=> $ipid_hoursback,
			cids_to_mods		=> $cids_to_mods,
			comment_time		=> $comment_time,
			submissions		=> "",
			subcount		=> 0,
			metamods		=> $metamods,
		});
	}

	if ($user_change && %$user_change) {
		$slashdb->setUser($user->{uid}, $user_change);
	}

	return 1;
}

sub sendUserMessage {
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $useredit = $slashdb->getUser($form->{touid});

	unless($useredit && $constants->{plugin}{Messages}){ return; }
	if($form->{usermessage}) {
		my $message = getObject("Slash::Messages");
		my $htmlmessage = $form->{usermessage};
		$htmlmessage =~ s/</&lt;/g;
		$htmlmessage =~ s/>/&gt;/g;
		$htmlmessage =~ s#\n#<br />\n#g;
		my $data = {
			template_name	=> 'admin_to_user_msg',
			subject		=> "Message from $user->{nickname}:",
			message		=> $form->{usermessage},
			htmlmessage	=> $htmlmessage
		};
		
		$message->create($useredit->{uid}, MSG_CODE_ADMIN_TO_USER, $data);
	}
	
	return 1;
}

sub _get_lastjournal {
	my($uid) = @_;
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $lastjournal = undef;
	if (my $journal = getObject('Slash::Journal', { db_type => 'reader' })) {
		my $j = $journal->getsByUid($uid, 0, 1);
		if ($j && @$j) {
			# Yep, there are 1 or more journals... get the first.
			$j = $j->[0];
		}
		if ($j && @$j) {
			# Yep, that first journal exists and has entries...
			# convert from stupid numeric array to a hashref.
			my @field = qw(	date article description id
					posttype tid discussion		);
			$lastjournal = { };
			for my $i (0..$#field) {
				$lastjournal->{$field[$i]} = $j->[$i];
			}
		}
	}

	if ($lastjournal) {

		# Strip the article field for display.
		$lastjournal->{article} = strip_mode($lastjournal->{article},
			$lastjournal->{posttype});

		# For display, include a reduced-size version, where the
		# size is based on the user's maxcomment size (which
		# defaults to 4K) and can't have too many line-breaking
		# tags.
		my $art_shrunk = $lastjournal->{article};
		my $maxsize = int($constants->{default_maxcommentsize} / 25);
		$maxsize =  80 if $maxsize <  80;
		$maxsize = 600 if $maxsize > 600;
		$art_shrunk = chopEntity($art_shrunk, $maxsize);

		my $approvedtags_break = $constants->{approvedtags_break} || [];
		my $break_tag = join '|', @$approvedtags_break;
		if (scalar(() = $art_shrunk =~ /<(?:$break_tag)>/gi) > 2) {
			$art_shrunk =~ s/\A
			(
				(?: <(?:$break_tag)> )?
				.*?   <(?:$break_tag)>
				.*?
			)	<(?:$break_tag)>.*
			/$1/six;
			if (length($art_shrunk) < 15) {
				# This journal entry has too much whitespace
				# in its first few chars;  scrap it.
				undef $art_shrunk;
			}
			$art_shrunk = chopEntity($art_shrunk) if defined($art_shrunk);
		}

		if (defined $art_shrunk) {
			if (length($art_shrunk) < length($lastjournal->{article})) {
				$art_shrunk .= " ...";
			}
			$art_shrunk = strip_html($art_shrunk);
			$art_shrunk = balanceTags($art_shrunk);
		}

		$lastjournal->{article_shrunk} = $art_shrunk;

		if ($lastjournal->{discussion}) {
			$lastjournal->{commentcount} = $reader->getDiscussion(
				$lastjournal->{discussion}, 'commentcount');
		}
	}
	return $lastjournal;
}

#####################################################################
sub validateUser {
	my($hr) = @_;
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	# If we aren't expiring accounts in some way, we don't belong here.
	if (! allowExpiry()) {
		displayForm();
		return;
	}

	print createMenu("users", {
		style		=> 'tabbed',
		justify		=> 'right',
		color		=> 'colored',
		tab_selected	=> $hr->{tab_selected_1} || "",
	});

	# Since we are here, if the minimum values for the comment trigger and
	# the day trigger are -1, then they should be reset to 1.
	$constants->{min_expiry_comm} = $constants->{min_expiry_days} = 1
		if $constants->{min_expiry_comm} <= 0 ||
		   $constants->{min_expiry_days} <= 0;

	if ($user->{is_anon} || $user->{registered}) {
		if ($user->{is_anon}) {
			print getError('anon_validation_attempt');
			displayForm();
			return;
		} else {
			print getMessage('no_registration_needed')
				if !$user->{reg_id};
			showInfo({ uid => $user->{uid} });
			return;
		}
	# Maybe this should be taken care of in a more centralized location?
	} elsif ($user->{reg_id} eq $form->{id}) {
		# We have a user and the registration IDs match. We are happy!
		my($maxComm, $maxDays) = ($constants->{max_expiry_comm},
					  $constants->{max_expiry_days});
		my($userComm, $userDays) =
			($user->{user_expiry_comm}, $user->{user_expiry_days});

		# Ensure both $userComm and $userDays aren't -1 (expiry has
		# just been turned on).
		$userComm = $constants->{min_expiry_comm}
			if $userComm < $constants->{min_expiry_comm};
		$userDays = $constants->{min_expiry_days}
			if $userDays < $constants->{min_expiry_days};

		my $exp = $constants->{expiry_exponent};

		# Increment only the trigger that was used.
		my $new_comment_expiry = ($maxComm > 0 && $userComm > $maxComm)
			? $maxComm
			: $userComm * (($user->{expiry_comm} < 0)
				? $exp
				: 1
		);
		my $new_days_expiry = ($maxDays > 0 && $userDays > $maxDays)
			? $maxDays
			: $userDays * (($user->{expiry_days} < 0)
				? $exp
				: 1
		);

		# Reset re-registration triggers for user.
		$slashdb->setUser($user->{uid}, {
			'expiry_comm'		=> $new_comment_expiry,
			'expiry_days'		=> $new_days_expiry,
			'user_expiry_comm'	=> $new_comment_expiry,
			'user_expiry_days'	=> $new_days_expiry,
		});

		# Handles rest of re-registration process.
		setUserExpired($user->{uid}, 0);
	}

	slashDisplay('regResult');
}

#################################################################
sub editKey {
	my($uid) = @_;

	my $slashdb = getCurrentDB();

	my $pubkey = $slashdb->getUser($uid, 'pubkey');
	my $editkey = slashDisplay('editKey', { pubkey => $pubkey }, 1);
	return $editkey;
}

#################################################################
# We arrive here without header() having been called.  Some of the
# functions we dispatch to call it, some do not.
sub adminDispatch {
	my($hr) = @_;
	my $form = getCurrentForm();
	my $op = $hr->{op} || $form->{op};

	if ($op eq 'authoredit') {
		# editUser() does not call header(), so we DO need to.
		header(getMessage('user_header'), '', {}) or return;
		editUser($hr);

	} elsif ($form->{saveuseradmin}) {
		# saveUserAdmin() tail-calls showInfo(), which calls
		# header(), so we need to NOT.
		saveUserAdmin($hr);

	} elsif ($form->{userinfo}) {
		# showInfo() calls header(), so we need to NOT.
		showInfo($hr);

	} elsif ($form->{userfield}) {
		# none of these calls header(), so we DO need to.
		header(getMessage('user_header'), '', {}) or return;
		if ($form->{edituser}) {
			editUser($hr);

		} elsif ($form->{edithome}) {
			editHome($hr);

		} elsif ($form->{editcomm}) {
			editComm($hr);

		} elsif ($form->{changepasswd}) {
			changePasswd($hr);
		}

	} else {
		# showInfo() calls header(), so we need to NOT.
		showInfo($hr);
	}
}

#################################################################
sub tildeEd {
	my($user_edit) = @_;

	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();

	my %story023_default = (
		author	=> { },
		nexus	=> { },
		topic	=> { },
	);

	my %prefs = ( );
	for my $field (qw(
		story_never_topic	story_never_author	story_never_nexus
		story_always_topic	story_always_author	story_always_nexus	story_brief_always_nexus
		story_full_brief_nexus	story_full_best_nexus	story_brief_best_nexus
	)) {
		for my $id (
			grep /^\d+$/,
			split /,/,
			($user_edit->{$field} || "")
		) {
			$prefs{$field}{$id} = 1;
		}
	}
#print STDERR scalar(localtime) . " prefs: " . Dumper(\%prefs);

	# Set up $author_hr, @aid_order, and $story023_default{author}.

	my $author_hr = $reader->getDescriptions('authors');
	my @aid_order = sort { lc $author_hr->{$a} cmp lc $author_hr->{$b} } keys %$author_hr;
	for my $aid (@aid_order) {
		     if ($prefs{story_never_author}{$aid}) {
			$story023_default{author}{$aid} = 0;
		} elsif ($prefs{story_always_author}{$aid}) {
			$story023_default{author}{$aid} = 3;
		} else {
			$story023_default{author}{$aid} = 2;
		}
	}

	# Set up $topic_hr, @topictid_order, and $story023_default{topic}.

	my $topic_hr = $reader->getDescriptions('non_nexus_topics-storypickable');
	my @topictid_order = sort { lc $topic_hr->{$a} cmp lc $topic_hr->{$b} } keys %$topic_hr;
	for my $tid (@topictid_order) {
		     if ($prefs{story_never_topic}{$tid}) {
			$story023_default{topic}{$tid} = 0;
		} elsif ($prefs{story_always_topic}{$tid}) {
			$story023_default{topic}{$tid} = 3;
		} else {
			$story023_default{topic}{$tid} = 2;
		}
	}

	# Set up $nexus_hr, @nexustid_order, and $story023_default{nexus}.
	my $topic_tree = $reader->getTopicTree();
	my $nexus_tids_ar = $reader->getStorypickableNexusChildren($constants->{mainpage_nexus_tid}, 1);
	my $nexus_hr = { };
	
	for my $tid (@$nexus_tids_ar) {
		$nexus_hr->{$tid} = $topic_tree->{$tid}{textname};
	}
	my @nexustid_order = sort {($b == $constants->{mainpage_nexus_tid}) <=> ($a == $constants->{mainpage_nexus_tid}) || 
				    lc $nexus_hr->{$a} cmp lc $nexus_hr->{$b} } keys %$nexus_hr;

	my $mp_disp_nexuses = $reader->getMainpageDisplayableNexuses();
	my %mp_disp_nexus = ( map { ($_, 1) } @$mp_disp_nexuses );
	for my $tid (@nexustid_order) {
		     if ($prefs{story_never_nexus}{$tid}) {
			$story023_default{nexus}{$tid} = 0;
		} elsif ($prefs{story_always_nexus}{$tid}) {
			$story023_default{nexus}{$tid} = 5;
		} elsif ($prefs{story_full_brief_nexus}{$tid}) {
			$story023_default{nexus}{$tid} = 4;
		} elsif ($prefs{story_brief_always_nexus}{$tid}) {
			$story023_default{nexus}{$tid} = 3;
		} elsif ($prefs{story_full_best_nexus}{$tid}) {
			$story023_default{nexus}{$tid} = 2;
		} elsif ($prefs{story_brief_best_nexus}{$tid}) {
			$story023_default{nexus}{$tid} = 1;
		} else {
			# If brief_sectional_mainpage is set, then all
			# nexuses in getMainpageDisplayableNexuses are,
			# by default, shown as brief on the mainpage.
			if ($constants->{brief_sectional_mainpage}
				&& $mp_disp_nexus{$tid}
			) {
				$story023_default{nexus}{$tid} = 4;
			} else {
				$story023_default{nexus}{$tid} = 2;
			}
		}
	}

	# Set up $section_descref and $box_order, used to decide which
	# slashboxes appear.  Really this doesn't seem to have anything
	# to do with sections, so I'm not sure why it's called
	# "section"_descref.

	my $section_descref = { };
	my $box_order;
	my $sections_description = $reader->getSectionBlocks();

	# the names of all the boxes in @{$skinBoxes->{$constants->{mainpage_skid}}}
	# should be unioned into sections_description.  whether the
	# values are 0 or 1 is calculated correctly, but we're
	# missing some 0's that should appear, I think, under
	# some circumstances.  ah heck, the whole concept of
	# sectional slashboxes should be redone (why the heck
	# do we have skinname_more instead of just a block
	# called olderstories?)

	my $slashboxes_hr = { };
	my $slashboxes_textlist = $user_edit->{slashboxes};
	if (!$slashboxes_textlist) {
		# Use the default.
		my($boxes, $skinBoxes) = $reader->getPortalsCommon();
		$slashboxes_textlist = join ",", @{$skinBoxes->{$constants->{mainpage_skid}}};
	}
	for my $bid ( map { /^'?([^']+)'?$/; $1 } split /,/, $slashboxes_textlist) {
		$slashboxes_hr->{$bid} = 1;
	}
	for my $ary (@$sections_description) {
		my($bid, $title, $always_on) = @$ary;
		push @$box_order, $bid;
		$section_descref->{$bid}{checked} = $slashboxes_hr->{$bid} ? $constants->{markup_checked_attribute} : '';
		$section_descref->{$bid}{checked} = $constants->{markup_checked_attribute} if $always_on;
		$title =~ s/<(.*?)>//g;
		$section_descref->{$bid}{title} = $title;
		$section_descref->{$bid}{always_on} = $always_on;
	}
	


	# Userspace.
	my $userspace = $user_edit->{mylinks} || "";

	# Titles of stuff.
	my $tildeEd_title = getTitle('tildeEd_title');
	my $criteria_msg = getMessage('tilded_criteria_msg');
	my $customize_title = getTitle('tildeEd_customize_title');
	my $tilded_customize_msg = getMessage('tilded_customize_msg',
		{ userspace => $userspace });
	my $tilded_box_msg = getMessage('tilded_box_msg');

	my $tilde_ed = slashDisplay('tildeEd', {
		user_edit		=> $user_edit,
		title			=> $tildeEd_title,
		criteria_msg		=> $criteria_msg,
		customize_title		=> $customize_title,
		tilded_customize_msg	=> $tilded_customize_msg,
		tilded_box_msg		=> $tilded_box_msg,

		story023_default	=> \%story023_default,
		authorref		=> $author_hr,
		aid_order		=> \@aid_order,
		topicref		=> $topic_hr,
		topictid_order		=> \@topictid_order,
		nexusref		=> $nexus_hr,
		nexustid_order		=> \@nexustid_order,

		section_descref		=> $section_descref,
		box_order		=> $box_order,

		userspace		=> $userspace,

	}, 1);

	return $tilde_ed;
}

#################################################################
sub changePasswd {
	my($hr) = @_;
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	print createMenu("users", {
		style		=> 'tabbed',
		justify		=> 'right',
		color		=> 'colored',
		tab_selected	=> $hr->{tab_selected_1} || "",
	});

	my $user_edit = {};
	my $title;
	my $suadmin_flag = ($user->{seclev} >= 10000) ? 1 : 0;

	my $admin_flag = ($user->{is_admin}) ? 1 : 0;
	my $admin_block = '';

	my $id = '';
	if ($admin_flag) {
		if ($form->{userfield}) {
			$id ||= $form->{userfield};
			if ($id =~ /^\d+$/) {
				$user_edit = $slashdb->getUser($id);
			} else {
				$user_edit = $slashdb->getUser($slashdb->getUserUID($id));
			}
		} else {
			$user_edit = $id eq '' ? $user : $slashdb->getUser($id);
			$id = $user_edit->{uid};
		}
	} else {
		$id = $user->{uid};
		$user_edit = $user;
	}

	$admin_block = getUserAdmin($id, 'uid', 1) if $admin_flag;

	# print getMessage('note', { note => $form->{note}}) if $form->{note};

	$title = getTitle('changePasswd_title', { user_edit => $user_edit });

	my $session = $slashdb->getDescriptions('session_login');
	my $session_select = createSelect('session_login', $session, $user_edit->{session_login}, 1);

	my $got_oldpass = 0;
	if ($form->{oldpass}) {
		my $return_uid = $slashdb->getUserAuthenticate($id, $form->{oldpass}, 1);
		$got_oldpass = 1 if $return_uid && $id == $return_uid;
	}

	slashDisplay('changePasswd', {
		useredit 		=> $user_edit,
		admin_flag		=> $suadmin_flag,
		title			=> $title,
		session 		=> $session_select,
		admin_block		=> $admin_block,
		got_oldpass		=> $got_oldpass
	});
}

#################################################################
sub editUser {
	my($hr) = @_;
	my $id = $hr->{uid} || '';
	my $note = $hr->{note} || '';

	print createMenu("users", {
		style		=> 'tabbed',
		justify		=> 'right',
		color		=> 'colored',
		tab_selected	=> $hr->{tab_selected_1} || "",
	});

	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $plugins = $slashdb->getDescriptions('plugins');

	my $user_edit = {};
	my($admin_block, $title);
	my $admin_flag = ($user->{is_admin}) ? 1 : 0;
	my $fieldkey;

	if ($admin_flag && $form->{userfield}) {
		$id ||= $form->{userfield};
		if ($form->{userfield} =~ /^\d+$/) {
			$user_edit = $slashdb->getUser($id);
			$fieldkey = 'uid';
		} else {
			$user_edit = $slashdb->getUser($slashdb->getUserUID($id));
			$fieldkey = 'nickname';
		}
	} else {
		$user_edit = $id eq '' ? $user : $slashdb->getUser($id);
		$fieldkey = 'uid';
		$id = $user_edit->{uid};
	}
	return if isAnon($user_edit->{uid}) && ! $admin_flag;

	$admin_block = getUserAdmin($id, $fieldkey, 1) if $admin_flag;
	$user_edit->{homepage} ||= "http://";

	# Remove domain tags, they'll be added back in, in saveUser.
	for my $dat (@{$user_edit}{qw(sig bio)}) {
		$dat = parseDomainTags($dat, 0, 1);
	}

	$title = getTitle('editUser_title', { user_edit => $user_edit});

	my $editkey = "";
	$editkey = editKey($user_edit->{uid}) if $fieldkey eq 'uid' && $plugins->{PubKey};

	slashDisplay('editUser', {
		useredit 		=> $user_edit,
		admin_flag		=> $admin_flag,
		title			=> $title,
		editkey 		=> $editkey,
		admin_block		=> $admin_block,
		note			=> $note,
	});
}

#################################################################
sub editHome {
	my($hr) = @_;
	my $id = $hr->{uid} || '';
	my $note = $hr->{note} || '';

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	print createMenu("users", {
		style		=> 'tabbed',
		justify		=> 'right',
		color		=> 'colored',
		tab_selected	=> $hr->{tab_selected_1} || "",
	});

	my($formats, $title, $tzformat_select);
	my $user_edit = {};
	my $fieldkey;

	my $admin_flag = ($user->{is_admin}) ? 1 : 0;
	my $admin_block = '';

	if ($admin_flag && $form->{userfield}) {
		$id ||= $form->{userfield};
		if ($form->{userfield} =~ /^\d+$/) {
			$user_edit = $slashdb->getUser($id);
			$fieldkey = 'uid';
		} else {
			$user_edit = $slashdb->getUser($slashdb->getUserUID($id));
			$fieldkey = 'nickname';
		}
	} else {
		$user_edit = $id eq '' ? $user : $slashdb->getUser($id);
		$fieldkey = 'uid';
	}
#use Data::Dumper; $Data::Dumper::Sortkeys = 1; print STDERR scalar(localtime) . " user_edit: " . Dumper($user_edit);

	return if isAnon($user_edit->{uid}) && ! $admin_flag;
	$admin_block = getUserAdmin($id, $fieldkey, 1) if $admin_flag;

	$title = getTitle('editHome_title', { user_edit => $user_edit});

	return if $user->{seclev} < 100 && isAnon($user_edit->{uid});

	$formats = $slashdb->getDescriptions('dateformats');
	$tzformat_select = createSelect('tzformat', $formats, $user_edit->{dfid}, 1);

	my $lb_check = $user_edit->{lowbandwidth} ? $constants->{markup_checked_attribute} : '';
	my $sd_check = $user_edit->{simpledesign} ? $constants->{markup_checked_attribute} : '';
	my $i_check = $user_edit->{noicons}	? $constants->{markup_checked_attribute} : '';
	my $w_check = $user_edit->{willing}	? $constants->{markup_checked_attribute} : '';
	my $vote_check = $user_edit->{willing_to_vote}	? $constants->{markup_checked_attribute} : '';
	my $classic_check = $user_edit->{index_classic} ? $constants->{markup_checked_attribute} : '';

	my $tilde_ed = tildeEd($user_edit);

	slashDisplay('editHome', {
		title			=> $title,
		admin_block		=> $admin_block,
		user_edit		=> $user_edit,
		tzformat_select		=> $tzformat_select,
		i_check			=> $i_check,
		w_check			=> $w_check,
		vote_check		=> $vote_check,
		lb_check		=> $lb_check,
		sd_check		=> $sd_check,
		classic_check		=> $classic_check,
		tilde_ed		=> $tilde_ed,
		note			=> $note,
	});
}

#################################################################
sub editComm {
	my($hr) = @_;
	my $id = $hr->{uid} || '';
	my $note = $hr->{note} || '';

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $user_edit = {};
	my($formats, $commentmodes_select, $commentsort_select, $title,
		$uthreshold_select, $highlightthresh_select, $posttype_select,
		$bytelimit_select);

	my $admin_block = '';
	my $fieldkey;

	print createMenu("users", {
		style		=> 'tabbed',
		justify		=> 'right',
		color		=> 'colored',
		tab_selected	=> $hr->{tab_selected_1} || "",
	});

	my $admin_flag = $user->{is_admin} ? 1 : 0;

	if ($admin_flag && $form->{userfield}) {
		$id ||= $form->{userfield};
		if ($form->{userfield} =~ /^\d+$/) {
			$user_edit = $slashdb->getUser($id);
			$fieldkey = 'uid';
		} else {
			$user_edit = $slashdb->getUser($slashdb->getUserUID($id));
			$fieldkey = 'nickname';
		}
	} else {
		$user_edit = $id eq '' ? $user : $slashdb->getUser($id);
		$fieldkey = 'uid';
	}

	my $hi = $constants->{comment_maxscore} - $constants->{comment_minscore};
	my $lo = -$hi;
	my @range = map { $_ > 0 ? "+$_" : $_ } ($lo .. $hi);

	my @reasons = ( );
	my %reason_select = ( );
	if ($constants->{m1}) {
		my $mod_reader = getObject("Slash::$constants->{m1_pluginname}", { db_type => 'reader' });
		my $reasons = $mod_reader->getReasons();
		for my $id (sort { $a <=> $b } keys %$reasons) {
			push @reasons, $reasons->{$id}{name};
		}
		# Reason modifiers
		foreach my $reason_name (@reasons) {
			my $key = "reason_alter_$reason_name";
			$reason_select{$reason_name} = createSelect(
				$key, \@range, 
				$user_edit->{$key} || 0, 1, 1
			);
		}
	}

	# Zoo relation modifiers
	my %people_select;
	my @people =  qw(friend foe anonymous fof eof freak fan);
	for (@people) {
		my $key = "people_bonus_$_";
		$people_select{$_} = createSelect($key, \@range, 
			$user_edit->{$key} || 0, 1, 1
		);
	}

	# New-user modifier
	my $new_user_bonus_select = createSelect('new_user_bonus', \@range, 
			$user_edit->{new_user_bonus} || 0, 1, 1);
	my $new_user_percent_select = createSelect('new_user_percent',
			[( 1..15, 20, 25, 30, 35, 40, 45, 50, 55,
			  60, 65, 70, 75, 80, 85, 90, 95 )], 
			$user_edit->{new_user_percent} || 100, 1, 1);
	# Karma modifier
	my $karma_bonus = createSelect('karma_bonus', \@range, 
			$user_edit->{karma_bonus} || 0, 1, 1);
	# Subscriber modifier
	my $subscriber_bonus = createSelect('subscriber_bonus', \@range, 
			$user_edit->{subscriber_bonus} || 0, 1, 1);

	# Length modifier
	my $small_length_bonus_select = createSelect('clsmall_bonus', \@range, 
			$user_edit->{clsmall_bonus} || 0, 1, 1);
	my $long_length_bonus_select = createSelect('clbig_bonus', \@range, 
			$user_edit->{clbig_bonus} || 0, 1, 1);

	return if isAnon($user_edit->{uid}) && ! $admin_flag;
	$admin_block = getUserAdmin($id, $fieldkey, 1) if $admin_flag;

	$title = getTitle('editComm_title', { user_edit => $user_edit});

	$formats = $slashdb->getDescriptions('commentmodes');
	$commentmodes_select=createSelect('umode', $formats, $user_edit->{mode}, 1);

	$formats = $slashdb->getDescriptions('sortcodes');
	$commentsort_select = createSelect(
		'commentsort', $formats, $user_edit->{commentsort}, 1
	);

	$formats = $slashdb->getDescriptions('threshcodes');
	$uthreshold_select = createSelect(
		'uthreshold', $formats, $user_edit->{threshold}, 1
	);

	$formats = $slashdb->getDescriptions('threshcodes');
	$highlightthresh_select = createSelect(
		'highlightthresh', $formats, $user_edit->{highlightthresh}, 1
	);
	
	$user_edit->{bytelimit} = $constants->{defaultbytelimit}
		if !defined($user_edit->{bytelimit}) || $user_edit->{bytelimit} < 0 || $user_edit->{bytelimit} > 7;
	my $bytelimit_desc = $user_edit->{is_subscriber} ? 'bytelimit' : 'bytelimit_sub';
	$formats = $slashdb->getDescriptions($bytelimit_desc);
	$bytelimit_select = createSelect(
		'bytelimit', $formats, $user_edit->{bytelimit}, 1
	);

	my $n_check  = $user_edit->{noscores}		 ? $constants->{markup_checked_attribute} : '';
	my $s_check  = $user_edit->{nosigs}		 ? $constants->{markup_checked_attribute} : '';
	my $b_check  = $user_edit->{nobonus}		 ? $constants->{markup_checked_attribute} : '';
	my $p_check  = $user_edit->{postanon}		 ? $constants->{markup_checked_attribute} : '';
	my $new_check = $user_edit->{highnew}            ? $constants->{markup_checked_attribute} : '';
	my $dim_check = $user_edit->{dimread}            ? $constants->{markup_checked_attribute} : '';
	my $nospell_check = $user_edit->{no_spell}	 ? $constants->{markup_checked_attribute} : '';
	my $s_mod_check = $user_edit->{mod_with_comm}	 ? $constants->{markup_checked_attribute} : '';
	my $s_m2_check = $user_edit->{m2_with_mod}	 ? $constants->{markup_checked_attribute} : '';
	my $s_m2c_check = $user_edit->{m2_with_comm_mod} ? $constants->{markup_checked_attribute} : '';

	$formats = $slashdb->getDescriptions('postmodes');
	$posttype_select = createSelect(
		'posttype', $formats, $user_edit->{posttype}, 1
	);

	slashDisplay('editComm', {
		title			=> $title,
		admin_block		=> $admin_block,
		user_edit		=> $user_edit,
		n_check			=> $n_check,
		s_check			=> $s_check,
		b_check			=> $b_check,
		p_check			=> $p_check,
		new_check   => $new_check,
		dim_check		=> $dim_check,
		s_mod_check		=> $s_mod_check,
		s_m2_check		=> $s_m2_check,
		s_m2c_check		=> $s_m2c_check,
		nospell_check		=> $nospell_check,
		commentmodes_select	=> $commentmodes_select,
		commentsort_select	=> $commentsort_select,
		highlightthresh_select	=> $highlightthresh_select,
		uthreshold_select	=> $uthreshold_select,
		posttype_select		=> $posttype_select,
		reasons			=> \@reasons,
		reason_select		=> \%reason_select,
		people			=> \@people,
		people_select		=> \%people_select,
		new_user_percent_select	=> $new_user_percent_select,
		new_user_bonus_select	=> $new_user_bonus_select,
		note			=> $note,
		karma_bonus		=> $karma_bonus,
		subscriber_bonus	=> $subscriber_bonus,
		small_length_bonus_select => $small_length_bonus_select,
		long_length_bonus_select => $long_length_bonus_select,
		bytelimit_select	=> $bytelimit_select,
	});
}

#################################################################
sub saveUserAdmin {
	my($hr) = @_;
	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	my($user_edits_table, $user_edit) = ({}, {});
	my $author_flag;
	my $note = '';
	my $srcid;
	my $id;
	my $user_editfield_flag;
	my $banned = 0;
	my $banref;
	if ($form->{uid}) {
		$user_editfield_flag = 'uid';
		$id = $form->{uid};
		$user_edit = $slashdb->getUser($id);
		$srcid = $id;

	} elsif ($form->{subnetid}) {
		$user_editfield_flag = 'subnetid';
		($id, $user_edit->{subnetid})  = ($form->{subnetid}, $form->{subnetid});
		$user_edit->{nonuid} = 1;
		$srcid = convert_srcid(subnetid => $id);

	} elsif ($form->{ipid}) {
		$user_editfield_flag = 'ipid';
		($id, $user_edit->{ipid})  = ($form->{ipid}, $form->{ipid});
		$user_edit->{nonuid} = 1;
		$srcid = convert_srcid(ipid => $id);

	} elsif ($form->{md5id}) {
		$user_editfield_flag = 'md5id';
		my $fieldname = $form->{fieldname} || 'md5id';
		($id, $user_edit->{$fieldname})
			= ($form->{md5id}, $form->{md5id});
		warn "form field md5id specified, no srcid saving possible";
	
	} elsif ($form->{srcid}) {
		$user_editfield_flag = 'srcid';
		my $fieldname = $form->{fieldname} || 'srcid';
		($id, $user_edit->{$fieldname})
			= ($form->{srcid}, $form->{srcid});
		$srcid = $id;

	} else {
		# If we were not fed valid data, don't do anything.
		return ;
	}

	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $all_al2types = $reader->getAL2Types;
	my $al2_change = { };

	# First, get a hash of what aclams (AL2's and ACLs) this user
	# had when the previous admin page was loaded.
	# XXXSRCID Right now acl_old is just calculated for debugging
	# printing purposes, not actually used.
	my @al2_old = ( );
	@al2_old =
		@{ $form->{al2_old_multiple}   } if $form->{al2_old_multiple};
	my %al2_old = ( map { ($_, 1) } @al2_old );
	my @acl_old = ( );
	@acl_old =
		@{ $form->{acl_old_multiple}   } if $form->{acl_old_multiple};
	my %acl_old = ( map { ($_, 1) } @acl_old );

	# Next, get the list of the new data submitted.  Separate
	# it out into AL2's which are legitimate.  Anything left
	# over is an ACL.
	my @al2_new_formfields = ( );
	@al2_new_formfields = @{ $form->{aclams_new_multiple} } if ($form->{aclams_new_multiple} && ref($form->{aclams_new_multiple}) eq "ARRAY");
        push(@al2_new_formfields, $form->{aclams_new_multiple}) if ref($form->{aclams_new_multiple}) eq "SCALAR";
	my @al2_new_submitted = map { s/^aclam_//; $_ } @al2_new_formfields;
	my @al2_new = grep { exists $all_al2types->{$_} } @al2_new_submitted;
	my %al2_new = ( map { ($_, 1) } @al2_new );
	my @acl_new = grep { !$al2_new{$_} } @al2_new_submitted;
	my %acl_new = ( map { ($_, 1) } @acl_new );

	# Find out what changed for AL2's.
	for my $al2 (@al2_old, @al2_new) {
		next if defined($al2_old{$al2}) && defined($al2_new{$al2})
			&& $al2_old{$al2} == $al2_new{$al2};
		$al2_change->{$al2} = $al2_new{$al2} ? 1 : 0;
	}
#print STDERR "al2_change for '$srcid': " . Dumper($al2_change);
	# If there's a comment, throw that in.
	if ($form->{al2_new_comment}) {
		$al2_change->{comment} = $form->{al2_new_comment};
	}
	$al2_change = undef if !keys %$al2_change;

	# Find out what changed for ACL's.
	my $acl_change = { };
	for my $acl (@acl_old, @acl_new) {
		next if $acl_old{$acl} == $acl_new{$acl};
		$acl_change->{$acl} = $acl_new{$acl} ? 1 : 0;
	}
	$acl_change = undef if !keys %$acl_change;

	if ($user->{is_admin} && $srcid) {
		$slashdb->setAL2($srcid, $al2_change);
	}
	if ($user->{is_admin} && ($user_editfield_flag eq 'uid' ||
		$user_editfield_flag eq 'nickname')) {

		# This admin user cannot assign a seclev higher than he/she
		# already has.
		my $seclev = $form->{seclev};
		$seclev = $user->{seclev} if $seclev > $user->{seclev};
		$user_edits_table->{seclev} = $seclev;

		$user_edits_table->{section} = $form->{section};
		$user_edits_table->{author} = $form->{author} ? 1 : 0 ;
		$user_edits_table->{defaultpoints} = $form->{defaultpoints};
		$user_edits_table->{tokens} = $form->{tokens};
		$user_edits_table->{tag_clout} = $form->{tag_clout};
		$user_edits_table->{m2info} = $form->{m2info};
		$user_edits_table->{acl} = $acl_change if $acl_change;
		$user_edits_table->{shill_static_marquee} = $form->{shill_static_marquee} ? 1 : undef;
		$user_edits_table->{u2_friends_bios} = $form->{u2_friends_bios} ? 1 : undef;
		$user_edits_table->{shill_rss_url} = $form->{shill_rss_url} ? $form->{shill_rss_url} : undef;
		$user_edits_table->{mod_banned} = isValidDate($form->{mod_banned}) ? $form->{mod_banned} : "1000-01-01";

		my $author = $slashdb->getAuthor($id);
		my $was_author = ($author && $author->{author}) ? 1 : 0;

		$slashdb->setUser($id, $user_edits_table);

		$note .= getMessage('saveuseradmin_saveduser', { field => $user_editfield_flag, id => $id });

		if ($was_author xor $user_edits_table->{author}) {
			# A frequently-asked question for new Slash admins is
			# why their authors aren't showing up immediately.
			# Give them some help here with an informative message.
			$note .= getMessage('saveuseradmin_authorchg', {
				basedir =>	$slashdb->getDescriptions("site_info")
					->{base_install_directory},
				virtuser =>	$slashdb->{virtual_user},
			});
					
		}
	}

	if (!$user_edit->{nonuid}) {
		if ($form->{expired} && $form->{expired} eq 'on') {
#			$slashdb->setExpired($user_edit->{uid});

		} else {
#			$slashdb->setUnexpired($user_edit->{uid});
		}
	}

	my $data = { uid => $id };
	$data->{note} = $note if defined $note;
	showInfo($data);
}


#################################################################
sub isValidDate {
  my $input = shift;
  if ($input =~ m!^((?:10|20|21)\d\d)[-](0[1-9]|1[012])[-](0[1-9]|[12][0-9]|3[01])$!) {
    # At this point, $1 holds the year, $2 the month and $3 the day of the date entered
    if ($3 == 31 and ($2 == 4 or $2 == 6 or $2 == 9 or $2 == 11)) {
      return 0; # 31st of a month with 30 days
    } elsif ($3 >= 30 and $2 == 2) {
      return 0; # February 30th or 31st
    } elsif ($2 == 2 and $3 == 29 and not ($1 % 4 == 0 and ($1 % 100 != 0 or $1 % 400 == 0))) {
      return 0; # February 29th outside a leap year
    } else {
      return 1; # Valid date
    }
  } else {
    return 0; # Not a date
  }
}


#################################################################
sub savePasswd {
	my($hr) = @_;
	my $note = $hr->{noteref} || undef;

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	my $error_flag = 0;
	my $user_edit = {};
	my $uid;

	my $user_edits_table = {};

	if ($user->{is_admin}) {
		$uid = $form->{uid} || $user->{uid};
	} else {
		$uid = ($user->{uid} == $form->{uid}) ? $form->{uid} : $user->{uid};
	}

	$user_edit = $slashdb->getUser($uid);

	if (!$user_edit->{nickname}) {
		$$note .= getError('cookie_err', { titlebar => 0 }, 0, 1)
			if $note;
		$error_flag++;
	}

	if ($form->{pass1} ne $form->{pass2}) {
		$$note .= getError('saveuser_passnomatch_err', { titlebar => 0 }, 0, 1)
			if $note;
		$error_flag++;
	}

	if (!$form->{pass1} || length $form->{pass1} < 6) {
		$$note .= getError('saveuser_passtooshort_err', { titlebar => 0 }, 0, 1)
			if $note;
		$error_flag++;
	}

	if (!$user->{is_admin}){
		# not an admin -- check old password before changing passwd
		my $return_uid = $slashdb->getUserAuthenticate($uid, $form->{oldpass}, 1);
		if (!$return_uid || $return_uid != $uid) {
			$$note .= getError('saveuser_badoldpass_err', { titlebar => 0 }, 0, 1) 
				if $note;
			$error_flag++;

		}
	}

	if (! $error_flag) {
		$user_edits_table->{passwd} = $form->{pass1} if $form->{pass1};
		$user_edits_table->{session_login} = $form->{session_login};

		# changed pass, so delete all logtokens
		$slashdb->deleteLogToken($form->{uid}, 1);

		if ($user->{admin_clearpass}
			&& !$user->{state}{admin_clearpass_thisclick}) {
			# User is an admin who sent their password in the clear
			# some time ago; now that it's been changed, we'll forget
			# about that incident, unless this click was sent in the
			# clear as well.
			$user_edits_table->{admin_clearpass} = '';
		}

		getOtherUserParams($user_edits_table);
		$slashdb->setUser($uid, $user_edits_table) ;
		$$note .= getMessage('saveuser_passchanged_msg',
			{ nick => $user_edit->{nickname}, uid => $user_edit->{uid} },
		0, 1) if $note;

		# only set cookie if user is current user
		if ($form->{uid} eq $user->{uid}) {
			$user->{logtoken} = bakeUserCookie($uid, $slashdb->getLogToken($form->{uid}, 1));
			setCookie('user', $user->{logtoken}, $user_edits_table->{session_login});
		}
	}

	return $error_flag;
}

#################################################################
sub saveUser {
	my($hr) = @_;
	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $gSkin = getCurrentSkin();
	my $plugins = $slashdb->getDescriptions('plugins');
	my $uid;
	my $user_editfield_flag;

	$uid = $user->{is_admin} && $form->{uid} ? $form->{uid} : $user->{uid};
	my $user_edit = $slashdb->getUser($uid);

	my($note, $formname);

	$note .= getMessage('savenickname_msg', {
		nickname => $user_edit->{nickname},
	}, 1);

	if (!$user_edit->{nickname}) {
		$note .= getError('cookie_err', 0, 1);
	}

	# Check to ensure that if a user is changing his email address, that
	# it doesn't already exist in the userbase.
	if ($user_edit->{realemail} ne $form->{realemail}) {
		if ($slashdb->existsEmail($form->{realemail})) {
			$note .= getError('emailexists_err', 0, 1);
			$form->{realemail} = $user_edit->{realemail}; # can't change!
		}
	}

	my(%extr, $err_message, %limit);
	$limit{sig} = 120;  # schema is 200, give an extra buffer for domain tags
	$limit{bio} = $constants->{users_bio_length} || 1024; # can be up to 2^16

	for my $key (keys %limit) {
		my $dat = chopEntity($form->{$key}, $limit{$key});
		$dat = strip_html($dat);
		$dat = balanceTags($dat, { deep_nesting => 2, deep_su => 1, length => $limit{$key} });
		$dat = addDomainTags($dat) if $dat;

		# If the sig becomes too long to fit (domain tagging causes
		# string expansion and tag balancing can too), warn the user to
		# use shorter domain names and don't save their change.
		if ($key eq 'sig' && defined($dat) && length($dat) > 200) {
			print getError('sig_too_long_err');
			$extr{sig} = undef;
		}

		# really, comment filters should ignore short length IMO ... oh well.
		if (length($dat) > 1 && ! filterOk('comments', 'postersubj', $dat, \$err_message)) {
			print getError('filter message', {
				err_message	=> $err_message,
				item		=> $key,
			});
			$extr{$key} = undef;
		} elsif (! compressOk('comments', 'postersubj', $dat)) {
			print getError('compress filter', {
				ratio		=> 'postersubj',
				item		=> $key,
			});
			$extr{$key} = undef;
		} else {
			$extr{$key} = $dat;
		}
	}

	# We should do some conformance checking on a user's pubkey,
	# make sure it looks like one of the known types of public
	# key.  Until then, just make sure it doesn't have HTML.
	$form->{pubkey} = $plugins->{'PubKey'} ? strip_nohtml($form->{pubkey}, 1) : '';

	my $homepage = $form->{homepage};
	$homepage = '' if $homepage eq 'http://';
	$homepage = fudgeurl($homepage);
	$homepage = URI->new_abs($homepage, $gSkin->{absolutedir})
			->canonical
			->as_iri if $homepage ne '';
	$homepage = substr($homepage, 0, 100) if $homepage ne '';

	my $calendar_url = $form->{calendar_url};
	if (length $calendar_url) {
		# fudgeurl() doesn't like webcal; will remove later anyway
		$calendar_url =~ s/^webcal/http/i;
		$calendar_url = fudgeurl($calendar_url);
		$calendar_url = URI->new_abs($calendar_url, $gSkin->{absolutedir})
			->canonical
			->as_iri if $calendar_url ne '';

		$calendar_url =~ s|^http://||i;
		$calendar_url = substr($calendar_url, 0, 200) if $calendar_url ne '';
	}

	# for the users table
	my $user_edits_table = {
		homepage	=> $homepage,
		realname	=> $form->{realname},
		pubkey		=> $form->{pubkey},
		copy		=> $form->{copy},
		quote		=> $form->{quote},
		calendar_url	=> $calendar_url,
		yahoo		=> $form->{yahoo},
		jabber		=> $form->{jabber},
		aim		=> $form->{aim},
		aimdisplay	=> $form->{aimdisplay},
		icq		=> $form->{icq},
		playing		=> $form->{playing},
		mobile_text_address => $form->{mobile_text_address},
	};

	if ($constants->{wow}) {
		my $wowdb = getObject("Slash::WoW");
		if ($wowdb) {
			$user_edits_table->{wow_main_name} = "\L\u$form->{wow_main_name}";
			$user_edits_table->{wow_main_realm} = $form->{wow_main_realm};
			my $charid = $wowdb->getCharidCreate($user_edits_table->{wow_main_realm},
				$user_edits_table->{wow_main_name});
			$wowdb->setChar($charid, { uid => $uid }, { if_unclaimed => 1 }) if $charid;
		}
	}

	for (keys %extr) {
		$user_edits_table->{$_} = $extr{$_} if defined $extr{$_};
	}

	# don't want undef, want to be empty string so they
	# will overwrite the existing record
	for (keys %$user_edits_table) {
		$user_edits_table->{$_} = '' unless defined $user_edits_table->{$_};
	}

	if ($user_edit->{realemail} ne $form->{realemail}) {
		$user_edits_table->{realemail} =
			chopEntity($form->{realemail}, 50);
		my $new_fakeemail = ''; # at emaildisplay 0, don't show any email address
		if ($user->{emaildisplay}) {
			$new_fakeemail = getArmoredEmail($uid, $user_edits_table->{realemail})
				if $user->{emaildisplay} == 1;
			$new_fakeemail = $user_edits_table->{realemail}
				if $user->{emaildisplay} == 2;
		}
		$user_edits_table->{fakeemail} = $new_fakeemail;

		$note .= getMessage('changeemail_msg', {
			realemail => $user_edit->{realemail}
		}, 1);

		my $saveuser_emailtitle = getTitle('saveUser_email_title', {
			nickname  => $user_edit->{nickname},
			realemail => $form->{realemail}
		}, 1);
		my $saveuser_email_msg = getMessage('saveuser_email_msg', {
			nickname  => $user_edit->{nickname},
			realemail => $form->{realemail}
		}, 1);

		sendEmail($form->{realemail}, $saveuser_emailtitle, $saveuser_email_msg);
		doEmail($uid, $saveuser_emailtitle, $saveuser_email_msg);
	}

	getOtherUserParams($user_edits_table);
	$slashdb->setUser($uid, $user_edits_table);

	editUser({ uid => $uid, note => $note });
}


#################################################################
sub saveComm {
	my($hr) = @_;
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();
	my($uid, $user_fakeemail);

	if ($user->{is_admin}) {
		$uid = $form->{uid} || $user->{uid};
	} else {
		$uid = ($user->{uid} == $form->{uid}) ?
			$form->{uid} : $user->{uid};
	}

	# Do the right thing with respect to the chosen email display mode
	# and the options that can be displayed.
	my $user_edit = $slashdb->getUser($uid);
	my $new_fakeemail = '';		# at emaildisplay 0, don't show any email address
	if ($form->{emaildisplay}) {
		$new_fakeemail = getArmoredEmail($uid)		if $form->{emaildisplay} == 1;
		$new_fakeemail = $user_edit->{realemail}	if $form->{emaildisplay} == 2;
	}

	my $name = $user->{seclev} && $form->{name} ?
		$form->{name} : $user->{nickname};

	my $note = getMessage('savenickname_msg',
		{ nickname => $name });

	print getError('cookie_err') if isAnon($uid) || !$name;

	# Take care of the lists
	# Enforce Ranges for variables that need it
	$form->{commentlimit} = 1 if $form->{commentlimit} < 1;
	my $cl_max = $constants->{comment_commentlimit} || 0;
	$form->{commentlimit} = $cl_max if $cl_max > 0 && $form->{commentlimit} > $cl_max;
	$form->{commentspill} = 0 if $form->{commentspill} < 1;

	# For some of these values, namely the ones that we happen to
	# know get stored in users_param, we change them to 'undef'
	# if they are the default value.  This deletes them from the
	# users_param table, which has the same effect as storing the
	# default except it's faster all around.  If we ever change
	# the schema to promote these fields from params into a
	# proper users_* table, then this will no longer be correct.
	# See prepareUser().
	my $max = $constants->{comment_maxscore} - $constants->{comment_minscore};
	my $min = -$max;
	my $karma_bonus = ($form->{karma_bonus} !~ /^[\-+]?\d+$/) ? "+1" : $form->{karma_bonus};
	my $subscriber_bonus = ($form->{subscriber_bonus} !~ /^[\-+]?\d+$/) ? "+1" : $form->{subscriber_bonus};
	my $new_user_bonus = ($form->{new_user_bonus} !~ /^[\-+]?\d+$/) ? 0 : $form->{new_user_bonus};
	my $new_user_percent = (($form->{new_user_percent} <= 100 && $form->{new_user_percent} >= 0) 
			? $form->{new_user_percent}
			: 100); 
	my $clsmall_bonus = ($form->{clsmall_bonus} !~ /^[\-+]?\d+$/) ? 0 : $form->{clsmall_bonus};
	my $clbig_bonus = ($form->{clbig_bonus} !~ /^[\-+]?\d+$/) ? 0 : $form->{clbig_bonus};

	# plum
	$form->{d2_comment_q} = (isSubscriber($user_edit) || $user_edit->{seclev} >= 100)
		? $form->{d2_comment_q}
		: ($form->{d2_comment_q} eq '0')
			? 1
			: $form->{d2_comment_q};

	my $user_edits_table = {
		clsmall			=> $form->{clsmall},
		clsmall_bonus		=> ($clsmall_bonus || undef),
		clbig			=> $form->{clbig},
		clbig_bonus		=> ($clbig_bonus || undef),
		commentlimit		=> $form->{commentlimit},
		bytelimit		=> $form->{bytelimit},
		commentsort		=> $form->{commentsort},
		commentspill		=> $form->{commentspill},
		domaintags		=> ($form->{domaintags} != 3 ? $form->{domaintags} : "3"),
		emaildisplay		=> $form->{emaildisplay} || undef,
		fakeemail		=> $new_fakeemail,
		highlightthresh		=> $form->{highlightthresh},
		mode			=> $form->{umode},
		posttype		=> $form->{posttype},
		threshold		=> $form->{uthreshold},
		nosigs			=> ($form->{nosigs}     ? 1 : 0),
		highnew			=> ($form->{new}	? 1 : 0),
		dimread			=> ($form->{dimmed}	? 1 : 0),
		noscores		=> ($form->{noscores}   ? 1 : 0),
		no_spell		=> ($form->{no_spell}   ? 1 : undef),
		nobonus			=> ($form->{nobonus} ? 1 : undef),
		postanon		=> ($form->{postanon} ? 1 : undef),
		new_user_percent	=> ($new_user_percent && $new_user_percent != 100
						? $new_user_percent : undef),
		new_user_bonus		=> ($new_user_bonus || undef),
		karma_bonus		=> ($karma_bonus ne '+1' ? $karma_bonus : undef),
		subscriber_bonus	=> ($subscriber_bonus || undef),
		textarea_rows		=> ($form->{textarea_rows} != $constants->{textarea_rows}
						? $form->{textarea_rows} : undef),
		textarea_cols		=> ($form->{textarea_cols} != $constants->{textarea_cols}
						? $form->{textarea_cols} : undef),
		user_comment_sort_type	=> ($form->{user_comment_sort_type} != 2
						? $form->{user_comment_sort_type} : undef ),
		mod_with_comm		=> ($form->{mod_with_comm} ? 1 : undef),
		m2_with_mod		=> ($form->{m2_with_mod} ? 1 : undef),
        	m2_with_comm_mod		=> ($form->{m2_with_mod_on_comm} ? 1 : undef),

	};
	
	# set our default values for the items where an empty-string won't do 
	my $defaults = {
		posttype        => 2,
		highlightthresh => 4,
		reparent        => 1,
		commentlimit    => 100,
		commentspill    => 50,
		mode            => 'thread'
	};

	my $mod_reader = getObject("Slash::$constants->{m1_pluginname}", { db_type => 'reader' });
	my @reasons = ( );
	my $reasons = $mod_reader->getReasons();
	for my $id (sort { $a <=> $b } keys %$reasons) {
		push @reasons, $reasons->{$id}{name};
	}

	for my $reason_name (@reasons) {
		my $key = "reason_alter_$reason_name";
		my $answer = $form->{$key} || 0;
		$answer = 0 if !$answer || $answer !~ /^[\-+]?\d+$/;
		$user_edits_table->{$key} = ($answer == 0) ? '' : $answer;
	}

	for (qw| friend foe anonymous fof eof freak fan |) {
		my $answer = $form->{"people_bonus_$_"};
		$answer = 0 if $answer !~ /^[\-+]?\d+$/;
		$user_edits_table->{"people_bonus_$_"} = ($answer == 0) ? '' : $answer;
	}
	getOtherUserParams($user_edits_table);
	setToDefaults($user_edits_table, {}, $defaults) if $form->{restore_defaults};
	$slashdb->setUser($uid, $user_edits_table);

	editComm({ uid => $uid, note => $note });
}

#################################################################
sub saveHome {
	my($hr) = @_;
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();
	my($uid, $error);

	if ($user->{is_admin}) {
		$uid = $form->{uid} || $user->{uid} ;
	} else {
		$uid = ($user->{uid} == $form->{uid}) ?
			$form->{uid} : $user->{uid};
	}
	my $edit_user = $slashdb->getUser($uid);

	my $name = $user->{seclev} && $form->{name} ?
		$form->{name} : $user->{nickname};
	$name = substr($name, 0, 20);

	my $note = getMessage('savenickname_msg',
		{ nickname => $name });

	if (isAnon($uid) || !$name) {
		my $cookiemsg = getError('cookie_err');
		print $cookiemsg;
	}

	# Using the existing list of slashboxes and the set of
	# what's checked and not, build up the new list.
	# (New arrivals go at the end.)
	my $slashboxes = $edit_user->{slashboxes};
	# Only go through all this if the user clicked save,
	# not "Restore Slashbox Defaults"!
	my($boxes, $skinBoxes) = $slashdb->getPortalsCommon();
	my $default_slashboxes_textlist = join ",", @{$skinBoxes->{$constants->{mainpage_skid}}};
	
	
	if (!$form->{restore_slashbox_defaults}) {
		my @new_boxes;
		my @box_order;
		my $sections_description = $slashdb->getSectionBlocks();
		for my $ary (@$sections_description) {
			push @box_order, @$ary[0];
		}
	
		# Add new boxes in.
		for my $bid (@box_order) {
			my $sb = "showbox_" . $bid;
			next if length($bid) < 1 || length($bid) > 30 || $bid !~ /^\w+$/ || !$form->{$sb};
			push @new_boxes, $bid;
		}

		$slashboxes = join ",", @new_boxes;
	}
	# If we're right back to the default, that means the
	# empty string.
	if ($slashboxes eq $default_slashboxes_textlist) {
		$slashboxes = "";
	}

	# Set the story_never and story_always fields.
	my $author_hr = $slashdb->getDescriptions('authors');
	my $tree = $slashdb->getTopicTree();
	my $topic_hr = $slashdb->getDescriptions('non_nexus_topics-storypickable');
	
	
	my(@story_never_topic,  @story_never_author,  @story_never_nexus);
	my(@story_always_topic, @story_always_author);
	my(@story_always_nexus, @story_full_brief_nexus, @story_brief_always_nexus, @story_full_best_nexus, @story_brief_best_nexus);
	my($story_topic_all, $story_author_all, $story_nexus_all) = (0, 0, 0);
	
	# Topics are either present (value=2) or absent (value=0).  If absent,
	# push them onto the never list.  Otherwise, do nothing.  (There's no
	# way to have an "always" topic, at the moment.)  If the hidden
	# field topictids_present is false, then there are no topic tids,
	# skip this.
	if ($form->{topictids_present}) {
		for my $tid (
			sort { $a <=> $b }
			grep { !$tree->{$_}{nexus} }
			keys %$topic_hr
		) {
			my $key = "topictid$tid";
			$story_topic_all++;
			if (!$form->{$key}) {		push @story_never_topic, $tid	}
		}
	}
	# Authors are either present (value=2) or absent (value=0).  If
	# absent, push them onto the never list.  Otherwise, do nothing.
	# (There's no way to have an "always" author, at the moment.)
	for my $aid (sort { $a <=> $b } keys %$author_hr) {
		my $key = "aid$aid";
		##########
		# TMB only add author to story_never_author if they are in the hidden list
		# and are not in the list of checked authors.
		my $check = "hid$aid";
		$story_author_all++;
		if ( (!$form->{$key}) && ($form->{$check}) ) {push @story_never_author, $aid;}
	}
	# Nexuses can have value 0, 1, 2, 3, 4, 5.  
	# 0 means the never list,
	# 1 means brief view of mainpage articles only
	# 2 means full view of mainpage articles only
	# 3 means brief view of all content
	# 4 means full view of mainpage content, brief view of sectional
	# 5 means full view of all content
	for my $tid (
		sort { $a <=> $b }
		map { /^nexustid(\d+)$/; $1 }
		grep { /^nexustid\d+$/ }
		keys %$form
	) {
		my $key = "nexustid$tid";
		next unless $tid && $tree->{$tid} && $tree->{$tid}{nexus};
		$story_nexus_all++;
		   if (!$form->{$key}) {		push @story_never_nexus, $tid	}
		elsif ($form->{$key} == 5 ) {		push @story_always_nexus, $tid	}
		elsif ($form->{$key} == 4 ) {		push @story_full_brief_nexus, $tid }
		elsif ($form->{$key} == 3 ) {		push @story_brief_always_nexus, $tid }
		elsif ($form->{$key} == 2 ) {		push @story_full_best_nexus, $tid }
		elsif ($form->{$key} == 1 ) {		push @story_brief_best_nexus, $tid }
		
						
	}
#use Data::Dumper; $Data::Dumper::Sortkeys = 1; print STDERR scalar(localtime) . " s_n_t '@story_never_topic' s_n_a '@story_never_author' s_n_n '@story_never_nexus' s_a_n '@story_always_nexus' form: " . Dumper($form);
	# Sanity check.
	$#story_never_topic		= 299 if $#story_never_topic   > 299;
	$#story_never_author		= 299 if $#story_never_author  > 299;
	$#story_never_nexus 		= 299 if $#story_never_nexus   > 299;
	$#story_always_topic		= 299 if $#story_always_topic  > 299;
	$#story_always_author 		= 299 if $#story_always_author > 299;
	$#story_always_nexus 		= 299 if $#story_always_nexus  > 299;
	$#story_full_brief_nexus 	= 299 if $#story_full_brief_nexus > 299;
	$#story_brief_always_nexus	= 299 if $#story_brief_always_nexus > 299;
	$#story_brief_best_nexus 	= 299 if $#story_brief_best_nexus > 299;
	$#story_full_best_nexus		= 299 if $#story_full_best_nexus > 299;
	
	my $story_never_topic   = join ",", @story_never_topic;
	$story_never_topic = ($constants->{subscribe} && $user->{is_subscriber})
		? checkList($story_never_topic, 1024)
		: checkList($story_never_topic);
	my $story_never_author  	= checkList(join ",", @story_never_author);
	my $story_never_nexus   	= checkList(join ",", @story_never_nexus);
	my $story_always_topic  	= checkList(join ",", @story_always_topic);
	$story_always_topic = ($constants->{subscribe} && $user->{is_subscriber})
		? checkList($story_always_topic, 1024)
		: checkList($story_always_topic);
	my $story_always_author 	= checkList(join ",", @story_always_author);

	my $story_always_nexus  	= checkList(join ",", @story_always_nexus);
	my $story_full_brief_nexus	= checkList(join ",", @story_full_brief_nexus);
	my $story_brief_always_nexus    = checkList(join ",", @story_brief_always_nexus);
	my $story_brief_best_nexus	= checkList(join ",", @story_brief_best_nexus);
	my $story_full_best_nexus	= checkList(join ",", @story_full_best_nexus);
	

	my $user_edits_table = {
		story_never_topic		=> $story_never_topic,
		story_never_author		=> $story_never_author,
		story_never_nexus		=> $story_never_nexus,
		story_always_topic		=> $story_always_topic,
		story_always_author		=> $story_always_author,
		story_always_nexus		=> $story_always_nexus,
		story_brief_always_nexus	=> $story_brief_always_nexus,
		story_full_brief_nexus 		=> $story_full_brief_nexus,
		story_full_best_nexus		=> $story_full_best_nexus,
		story_brief_best_nexus		=> $story_brief_best_nexus,

		slashboxes	=> checkList($slashboxes, 1024),

		maxstories	=> 30, # XXXSKIN fix this later
		noboxes		=> ($form->{useslashboxes} ? 0 : 1),
		lowbandwidth	=> ($form->{lowbandwidth} ? 1 : 0),
		simpledesign	=> ($form->{simpledesign} ? 1 : 0),
		noicons		=> ($form->{noicons} ? 1 : 0),
		willing		=> ($form->{willing} ? 1 : 0),
		willing_to_vote	=> ($form->{willing_to_vote} ? 1 : 0),
		index_classic	=> ($form->{index_classic} ? 1 : undef),
	};

	if (defined $form->{tzcode} && defined $form->{tzformat}) {
		$user_edits_table->{tzcode} = $form->{tzcode};
		$user_edits_table->{dfid}   = $form->{tzformat};
		$user_edits_table->{dst}    = $form->{dst};
	}

	if (defined $form->{skin} && defined $form->{skin}) {
		$user_edits_table->{skin} = $form->{skin};
	}

	# Force the User Space area to contain only known-good HTML tags.
	# Unfortunately the cookie login model makes it just too risky
	# to allow scripts in here;  CSS's steal passwords.  There are
	# no known vulnerabilities at this time, but a combination of the
	# social engineering taking place (inviting users to put Javascript
	# from websites in here, and making available script URLs for that
	# purpose), plus the fact that this could be used to amplify the
	# seriousness of any future vulnerabilities, means it's way past
	# time to shut this feature down.  - Jamie 2002/03/06

	# it's a VARCHAR ...
	my $mylinks_limit = 255;
	$user_edits_table->{mylinks} = balanceTags(strip_html(
		chopEntity($form->{mylinks} || '', $mylinks_limit)
	), { deep_nesting => 2, deep_su => 1, length => $mylinks_limit });

	$user_edits_table->{mylinks} = '' unless defined $user_edits_table->{mylinks};

	$error = 1;
	# must select at least 1/4 of topics, authors
	if      ( scalar(@story_never_author) > ($story_author_all * 3/4) ) {
		$note = getError('editHome_too_many_disabled');
	} elsif ( scalar(@story_never_topic) > ($story_topic_all * 3/4) ) {
		$note = getError('editHome_too_many_disabled');
	} else {
		$error = 0;
	}

	unless ($error) {
		# If a user is unwilling to moderate, we should cancel all points, lest
		# they be preserved when they shouldn't be.
		if (!isAnon($uid) && !$form->{willing}) {
			$slashdb->setUser($uid, { points => 0 });
		}

		getOtherUserParams($user_edits_table);
		if ($form->{restore_defaults}) {
			setToDefaults($user_edits_table, {}, {
				maxstories	=> 30,
				tzcode		=> "EST",
				willing => 1
			});
		}
		if ($form->{restore_slashbox_defaults}) {
			setToDefaults($user_edits_table, {
				'story_never_topic' => 1,
				'story_never_author' => 1,
				'story_never_nexus' => 1,
				'story_always_topic' => 1,
				'story_always_author' => 1,
				'story_always_nexus' => 1,
				'story_full_brief_nexus' => 1,
				'story_brief_always_nexus' => 1,
				'story_full_best_nexus' => 1,
				'story_brief_best_nexus' => 1,
				'maxstories' => 1,
				'tzcode' => 1,
				'noboxes' => 1,
				'simpledesign' => 1,
				'lowbandwidth' =>1,
				'noicons' => 1,
				'willing' => 1,
				'willing_to_vote' => 1,
				'skin' => 1
			}, { slashboxes => "" });
	}

#print scalar(localtime) . " uet: " . Dumper($user_edits_table);
		$slashdb->setUser($uid, $user_edits_table);
	}

	#editHome({ uid => $uid, note => $note });
}

#################################################################
# A generic way for a site to allow users to edit data about themselves.
# Most useful when your plugin or theme wants to let the user change
# minor settings but you don't want to write a whole new version
# of users.pl to provide a user interface.  The user can save any
# param of the format "opt_foo", as long as "foo" shows up in
# getMiscUserOpts which lists all the misc opts that this user can edit.
# This is *not* protected by formkeys (yet), so assume attackers can make
# users click and accidentally edit their own settings: no really important
# data should be stored in this way.
sub editMiscOpts {
	my($hr) = @_;
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser(); 
	my $constants = getCurrentStatic();
	my $note = $hr->{note} || "";

	return if $user->{is_anon}; # shouldn't be, but can't hurt to check

	print createMenu("users", {
		style		=> 'tabbed',
		justify		=> 'right',
		color		=> 'colored',
		tab_selected	=> $hr->{tab_selected_1} || "",
	});

	my $edit_user = $slashdb->getUser($user->{uid});
	my $title = getTitle('editMiscOpts_title');

	my $opts = $slashdb->getMiscUserOpts();
	for my $opt (@$opts) {
		my $opt_name = "opt_" . $opt->{name};
		$opt->{checked} = $edit_user->{$opt_name} ? 1 : 0;
	}

	slashDisplay('editMiscOpts', {
#		useredit	=> $user_edit,
		title		=> $title,
		opts		=> $opts,
		note		=> $note,
	});
}

#################################################################
#
sub saveMiscOpts {
	my($hr) = @_;
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();

	return if $user->{is_anon}; # shouldn't be, but can't hurt to check

	my $edit_user = $slashdb->getUser($user->{uid});
	my %opts_ok_hash = ( );
	my $opts = $slashdb->getMiscUserOpts();
	for my $opt (@$opts) {
		$opts_ok_hash{"opt_$opt->{name}"} = 1;
	}

	my $update = { };
	for my $opt (grep /^opt_/, keys %$form) {
		next unless $opts_ok_hash{$opt};
		$update->{$opt} = $form->{$opt} ? 1 : 0;
	}

	# Make the changes.
	$slashdb->setUser($edit_user->{uid}, $update);

	# Inform the user the change was made.  Since we don't
	# require formkeys, we always want to print a message to
	# make sure the user sees what s/he did.  This is done
	# by passing in a note which ends up passed to the
	# editMiscOpts template, which displays it.
	editMiscOpts({ note => getMessage('savemiscopts_msg') });
}

#################################################################
sub listReadOnly {
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	my $readonlylist = $reader->getAL2List('nopost');

	slashDisplay('listReadOnly', {
		readonlylist => $readonlylist,
	});

}

#################################################################
sub listBanned {
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	my $bannedlist = $reader->getAL2List('ban');

	slashDisplay('listBanned', {
		bannedlist => $bannedlist,
	});

}

#################################################################
sub topAbusers {
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	my $topabusers = $reader->getTopAbusers();

	slashDisplay('topAbusers', {
		topabusers => $topabusers,
	});
}

#################################################################
sub listAbuses {
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();

	my $abuses = $reader->getAbuses($form->{key}, $form->{abuseid});

	slashDisplay('listAbuses', {
		abuseid	=> $form->{abuseid},
		abuses	=> $abuses,
	});
}

#################################################################
sub forceAccountVerify {
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	my $uid = $form->{uid};
	my $useredit = $slashdb->getUser($uid);
	
	if ($useredit->{uid}) {
		my $newpasswd = $slashdb->resetUserAccount($uid);
		$slashdb->deleteLogToken($uid, 1);
		my $emailtitle = getTitle('reset_acct_email_title', {
			nickname	=> $useredit->{nickname}
		}, 1);

		my $msg = getMessage('reset_acct_msg', {
			newpasswd	=> $newpasswd,
			tempnick	=> $useredit->{nickname},
		}, 1);
		
		$slashdb->setUser($useredit->{uid}, {
			waiting_for_account_verify => 1,
			account_verify_request_time => $slashdb->getTime()
		});
		
		doEmail($useredit->{uid}, $emailtitle, $msg) if $useredit->{uid};
	}
	
	print getMessage("reset_acct_complete", { useredit => $useredit }, 1);	
}

#################################################################
sub displayForm {
	my($hr) = @_;

	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	my $suadmin_flag = $user->{seclev} >= 10000 ? 1 : 0;

	print createMenu("users", {
		style		=> 'tabbed',
		justify		=> 'right',
		color		=> 'colored',
		tab_selected	=> $hr->{tab_selected_1} || "",
	});

	my $op = $hr->{op} || $form->{op} || 'displayform';

	my $ops = {
		displayform 	=> 'loginForm',
		edithome	=> 'loginForm',
		editcomm	=> 'loginForm',
		edituser	=> 'loginForm',
#		mailpasswdform 	=> 'sendPasswdForm',
#		newuserform	=> 'newUserForm',
		userclose	=> 'loginForm',
		userlogin	=> 'loginForm',
		editmiscopts	=> 'loginForm',
		savemiscopts	=> 'loginForm',
		default		=> 'loginForm'
	};

	$op = 'default' if !defined($ops->{$op});

	my($title, $title2, $msg1, $msg2) = ('', '', '', '');

	if ($op eq 'userclose') {
		$title = getMessage('userclose');

	} elsif ($op eq 'displayForm') {
		$title = $form->{unickname}
			? getTitle('displayForm_err_title')
			: getTitle('displayForm_title');
	} elsif ($op eq 'mailpasswdform') {
		$title = getTitle('mailPasswdForm_title');
	} elsif ($op eq 'newuserform') {
		$title = getTitle('newUserForm_title');
	} else {
		$title = getTitle('displayForm_title');
	}

	$form->{unickname} ||= $form->{newusernick};

	if ($form->{newusernick}) {
		$title2 = getTitle('displayForm_dup_title');
	} else {
		$title2 = getTitle('displayForm_new_title');
	}

	$msg1 = getMessage('dispform_new_msg_1');
	if (! $form->{newusernick} && $op eq 'newuserform') {
		$msg2 = getMessage('dispform_new_msg_2');
	} elsif ($op eq 'displayform' || $op eq 'userlogin') {
		$msg2 = getMessage('newuserform_msg');
	}

	slashDisplay($ops->{$op}, {
		newnick		=> nickFix($form->{newusernick}),
		suadmin_flag 	=> $suadmin_flag,
		title 		=> $title,
		title2 		=> $title2,
		logged_in	=> $user->{is_anon} ? 0 : 1,
		msg1 		=> $msg1,
		msg2 		=> $msg2
	});
}

#################################################################
# this groups all the messages together in
# one template, called "messages;users;default"
sub getMessage {
	my($value, $hashref, $nocomm) = @_;
	$hashref ||= {};
	$hashref->{value} = $value;
	return slashDisplay('messages', $hashref,
		{ Return => 1, Nocomm => $nocomm });
}

#################################################################
# this groups all the errors together in
# one template, called "errors;users;default"
sub getError {
	my($value, $hashref, $nocomm) = @_;
	$hashref ||= {};
	$hashref->{value} = $value;
	return slashDisplay('errors', $hashref,
		{ Return => 1, Nocomm => $nocomm });
}

#################################################################
# this groups all the titles together in
# one template, called "users-titles"
sub getTitle {
	my($value, $hashref, $nocomm) = @_;
	$hashref ||= {};
	$hashref->{value} = $value;
	return slashDisplay('titles', $hashref,
		{ Return => 1, Nocomm => $nocomm });
}

#################################################################
# getUserAdmin - returns a block of HTML text that provides
# information and editing capabilities for admin users.
# Most of this data is already in the getUserAdmin template,
# but really, we should try to get more of this logic into
# that template.
sub getUserAdmin {
	my($id, $field, $seclev_field) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $logdb = getObject('Slash::DB', { db_type => 'log_slave' });


	my $user	= getCurrentUser();
	my $form	= getCurrentForm();
	my $constants	= getCurrentStatic();
	my $slashdb	= getCurrentDB();
	$id ||= $user->{uid};

	my($expired, $uidstruct, $readonly);
	my($user_edit, $user_editfield, $ipstruct, $ipstruct_order, $authors, $author_flag, $topabusers, $thresh_select,$section_select);
	my $srcid;
	my $proxy_check = {};
	my @accesshits;
	my $user_editinfo_flag = (!$form->{op} || $form->{op} eq 'userinfo'
		|| $form->{userinfo} || $form->{saveuseradmin}
		) ? 1 : 0;
	my $authoredit_flag = ($user->{seclev} >= 10000) ? 1 : 0;
	my $sectionref = $reader->getDescriptions('skins');
	$sectionref->{''} = getData('all_sections');

	$field ||= 'uid';
	if ($field eq 'uid') {
		$user_edit = $slashdb->getUser($id);
		$user_editfield = $user_edit->{uid};
		$srcid = convert_srcid( uid => $id );
		#$expired = $slashdb->checkExpired($user_edit->{uid}) ? $constants->{markup_checked_attribute} : '';
		$ipstruct = $slashdb->getNetIDStruct($user_edit->{uid});
		@accesshits = $logdb->countAccessLogHitsInLastX($field, $user_edit->{uid}) if defined($logdb);
		$section_select = createSelect('section', $sectionref, $user_edit->{section}, 1);

	} elsif ($field eq 'nickname') {
		$user_edit = $slashdb->getUser($slashdb->getUserUID($id));
		$user_editfield = $user_edit->{nickname};
		#$expired = $slashdb->checkExpired($user_edit->{uid}) ? $constants->{markup_checked_attribute} : '';
		$ipstruct = $slashdb->getNetIDStruct($user_edit->{uid});
		@accesshits = $logdb->countAccessLogHitsInLastX('uid', $user_edit->{uid}) if defined($logdb);
		$section_select = createSelect('section', $sectionref, $user_edit->{section}, 1);

	} elsif ($field eq 'md5id') {
		$user_edit->{nonuid} = 1;
		$user_edit->{md5id} = $id;
		if ($form->{fieldname} && $form->{fieldname} =~ /^(ipid|subnetid)$/) {
			$uidstruct = $slashdb->getUIDStruct($form->{fieldname}, $user_edit->{md5id});
			@accesshits = $logdb->countAccessLogHitsInLastX($form->{fieldname}, $user_edit->{md5id}) if defined($logdb);
		} else {
			$uidstruct = $slashdb->getUIDStruct('md5id', $user_edit->{md5id});
			@accesshits = $logdb->countAccessLogHitsInLastX($field, $user_edit->{md5id}) if defined($logdb);
		}

	} elsif ($field eq 'ipid') {
		$user_edit->{nonuid} = 1;
		$user_edit->{ipid} = $id;
		$srcid = convert_srcid( ipid => $id );
		$user_editfield = $id;
		$uidstruct = $slashdb->getUIDStruct('ipid', $user_edit->{ipid});
		@accesshits = $logdb->countAccessLogHitsInLastX('host_addr', $user_edit->{ipid}) if defined($logdb);

		if ($form->{userfield} =~/^\d+\.\d+\.\d+\.(\d+)$/) {
			if ($1 ne "0"){
				$proxy_check->{available} = 1;
				$proxy_check->{results} = $slashdb->checkForOpenProxy($form->{userfield}) if $form->{check_proxy};
			}
		}

	} elsif ($field eq 'subnetid') {
		$user_edit->{nonuid} = 1;
		$srcid = convert_srcid( ipid => $id );
		if ($id =~ /^(\d+\.\d+\.\d+)(?:\.\d)?/) {
			$id = $1 . ".0";
			$user_edit->{subnetid} = $id;
		} else {
			$user_edit->{subnetid} = $id;
		}

		$user_editfield = $id;
		$uidstruct = $slashdb->getUIDStruct('subnetid', $user_edit->{subnetid});
		@accesshits = $logdb->countAccessLogHitsInLastX($field, $user_edit->{subnetid}) if defined($logdb);

	} elsif ($field eq "srcid") {
		$user_edit->{nonuid} = 1;
		$user_edit->{srcid}  = $id;
		$srcid = $id;
		
	} else {
		$user_edit = $id ? $slashdb->getUser($id) : $user;
		$user_editfield = $user_edit->{uid};
		$ipstruct = $slashdb->getNetIDStruct($user_edit->{uid});
		@accesshits = $logdb->countAccessLogHitsInLastX('uid', $user_edit->{uid}) if defined($logdb);
	}

	##########
	# Put together the array and hashref that the template will need
	# to construct the list for display to the admin.
	# Note that currently a srcid which is not a uid (i.e. which
	# represents an IP address or masked IP network) cannot have
	# any ACLs assigned to it.  This may change in the future.
	# The term "aclam" is used because it has a field set for both
	# every ACL and every access modifier (i.e. AL2 bit) that is set
	# for this user or srcid.
	# For now, ACLs will be listed for IPs as well.
	# First get the list of ACLs that can be used.
	my $all_acls_ar = $reader->getAllACLNames();
	my $all_acls_hr = { map { ( $_, 1 ) } @$all_acls_ar };
	# Add in any ACLs selected for this user (just in case
	# getAllACLNames is cached and stale).
	for my $acl (keys %{$user_edit->{acl}}) {
		$all_acls_hr->{$acl} = 1;
	}
	# Start creating the $all_aclam_hr data, in which the keys are
	# the HTML selection names that all begin with aclam_ and the
	# the values are their names/descriptions shown to the admin.
	# First put all the ACLs into the hash, if we're editing a user.
	my $all_aclam_hr = { };
	if (!$user_edit->{nonuid}) {
		$all_aclam_hr = { map { ( "aclam_$_", "ACL: $_" ) } keys %$all_acls_hr };
	}
	# Next put in all the al2 types.
	my $all_al2types = $reader->getAL2Types;
	for my $key (keys %$all_al2types) {
		next if $key eq 'comment'; # skip the 'comment' type
		$all_aclam_hr->{"aclam_$key"} = $all_al2types->{$key}{title};
	}
	# Finally, sort the keys of the hash into the order that we
	# want them displayed to the admin (ACLs first).
	my $all_acls_longkeys_hr = { map { ( "aclam_$_", 1 ) } keys %$all_acls_hr };
	my $all_aclam_ar = [
		sort {
			(exists($all_acls_longkeys_hr->{$a}) ? -1 : 1) <=> (exists($all_acls_longkeys_hr->{$b}) ? -1 : 1)
			||
			$all_aclam_hr->{$a} cmp $all_aclam_hr->{$b}
		} keys %$all_aclam_hr
	];
	# Now put together the hashref that identifies which of those
	# items are selected for this user.
	my $user_aclam_hr = { };
	for my $acl (keys %{ $user_edit->{acl} }) {
		$user_aclam_hr->{"aclam_$acl"} = 1;
	}
	my $al2_tid_comment = $all_al2types->{comment}{al2tid} || 0;
	my $al2_log_ar = [ ];
	my $al2_hr = { };
	# XXXSRCID Once we get rid of the silly 'md5id' field and all the
	# other bizarre backward-compatibility code paths early in this
	# function, this won't be necessary, but until then we need this
	# sanity check...
	if ($srcid) {
		# getAL2 works with either a srcids hashref or a single srcid
		$al2_hr = $slashdb->getAL2($srcid);
		for my $al2 (keys %{ $al2_hr }) {
			$user_aclam_hr->{"aclam_$al2"} = 1;
		}
		$al2_log_ar = $slashdb->getAL2Log($srcid);
	}
	# Generate al2_nick_hr, which will be populated with keys of all
	# the (presumably) admin uids who have logged rows for this al2,
	# and values of their nicks.
	my $al2_nick_hr = { };
	for my $al2_log (@$al2_log_ar) {
		my $uid = $al2_log->{adminuid};
		next if !$uid; # odd error, might want to flag this
		$al2_nick_hr->{$uid} ||= $slashdb->getUser($uid, 'nickname');
	}
	##########

	$user_edit->{author} = ($user_edit->{author} && $user_edit->{author} == 1)
		? $constants->{markup_checked_attribute} : '';
	if (! $user->{nonuid}) {
		my $threshcodes = $reader->getDescriptions('threshcode_values','',1);
		$thresh_select = createSelect('defaultpoints', $threshcodes, $user_edit->{defaultpoints}, 1);
	}

	if (!ref $ipstruct) {
		undef $ipstruct;
	} else {
		@$ipstruct_order = sort { $ipstruct->{$b}{dmin} cmp $ipstruct->{$a}{dmin} } keys %$ipstruct;
	}

	my $m2total = ($user_edit->{m2fair} || 0) + ($user_edit->{m2unfair} || 0);
	if ($m2total) {
		$user_edit->{m2unfairpercent} = sprintf("%.2f",
			$user_edit->{m2unfair}*100/$m2total);
	}
	my $mod_total = ($user_edit->{totalmods} || 0) + ($user_edit->{stirred} || 0);
	if ($mod_total) {
		$user_edit->{stirredpercent} = sprintf("%.2f",
			$user_edit->{stirred}*100/$mod_total);
	}
	if ($constants->{subscribe} and my $subscribe = getObject('Slash::Subscribe')) {
		$user_edit->{subscribe_payments} =
			$subscribe->getSubscriptionsForUser($user_edit->{uid});
		$user_edit->{subscribe_purchases} =
			$subscribe->getSubscriptionsPurchasedByUser($user_edit->{uid},{ only_types => [ "grant", "gift" ] });
	}
	my $ipid = $user_edit->{ipid};
	my $subnetid = $user_edit->{subnetid};
	my $post_restrictions = {};
	my ($subnet_karma, $ipid_karma);

	if ($ipid && !$subnetid) {
		$ipid = md5_hex($ipid) if length($ipid) != 32;
		$proxy_check->{ipid} = $ipid;
		$proxy_check->{currently} = $slashdb->getKnownOpenProxy($ipid, "ipid");
		# This next call is very slow.
		$subnetid = $reader->getSubnetFromIPIDBasedOnComments($ipid);
	}

	if ($subnetid) {
		$subnetid = md5_hex($subnetid) if length($subnetid) != 32;
		# These next three calls can be very slow.  In fact, getNetIDKarma
		# is actually called twice on the same subnetid;  if we can cache
		# that data somehow that wouldn't be a bad idea.
		$post_restrictions = $reader->getNetIDPostingRestrictions("subnetid", $subnetid);
		$subnet_karma = $reader->getNetIDKarma("subnetid", $subnetid);
		$ipid_karma = $reader->getNetIDKarma("ipid", $ipid) if $ipid;
	}

	my $clout_types_ar = [ sort grep /\D/, keys %{$slashdb->getCloutTypes} ];

	return slashDisplay('getUserAdmin', {
		field			=> $field,
		useredit		=> $user_edit,
		srcid			=> $srcid,
		all_aclam_ar		=> $all_aclam_ar,
		all_aclam_hr		=> $all_aclam_hr,
		user_aclam_hr		=> $user_aclam_hr,
		al2_old			=> $al2_hr,
		al2_log			=> $al2_log_ar,
		al2_tid_comment		=> $al2_tid_comment,
		al2_nick		=> $al2_nick_hr,

		userinfo_flag		=> $user_editinfo_flag,
		userfield		=> $user_editfield,
		ipstruct		=> $ipstruct,
		ipstruct_order		=> $ipstruct_order,
		uidstruct		=> $uidstruct,
		accesshits		=> \@accesshits,
		seclev_field		=> $seclev_field,
		expired 		=> $expired,
		topabusers		=> $topabusers,
		readonly		=> $readonly,
		thresh_select		=> $thresh_select,
		authoredit_flag 	=> $authoredit_flag,
		section_select		=> $section_select,
		all_acls		=> $all_acls_hr,
		proxy_check		=> $proxy_check,
		subnet_karma		=> $subnet_karma,
		ipid_karma		=> $ipid_karma,
		post_restrictions	=> $post_restrictions,

		clout_types_ar		=> $clout_types_ar,
	}, 1);
}

#################################################################
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
		if (exists $form->{$param}) {
			# set user too for output in this request
			$data->{$param} = $user->{$param} = $form->{$param} || undef;
		}
	}
}

###############################################################
# This modifies a hashref to default values -- if nothing
# else we assume the empty string which clears items in the
# user_param table 
#
# takes 3 hashrefs currently
# $data     - hashref to change to defaults
# $skip     - hashref of keys to skip modifying
# $defaults - hashref of defaults to set to something other 
#             than the empty string
sub setToDefaults {
	my($data, $skip, $defaults) = @_;
	foreach my $key (keys %$data) {
		next if $skip->{$key};
		$data->{$key} = exists $defaults->{$key} ? $defaults->{$key} : "";
 	}
}

#################################################################
sub getCommentListing {
	my ($type, $value,
		$min_comment, $time_period, $cc_all, $cc_time_period, $cid_for_time_period,
		$non_admin_limit, $admin_time_limit, $admin_non_time_limit,
		$options) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $store_cutoff = $options->{use_uid_cid_cutoff} ? $constants->{store_com_page1_min_cid_for_user_com_cnt} : 0;
	
	my $s_opt = {};
	my $num_wanted = 0;
	if ($min_comment) {
		if ($user->{is_admin}) {
			$num_wanted = $admin_non_time_limit;
		} else {
			$num_wanted = $non_admin_limit;
		}
	} else {
	
		if ($user->{is_admin}) {
			if ($cc_time_period >= $admin_non_time_limit) {
				$s_opt->{cid_at_or_after} = $cid_for_time_period;
				$num_wanted = $admin_time_limit;
			} else {
				$num_wanted = $admin_non_time_limit;
				if($store_cutoff){
					my $min_cid = $reader->getUser($value,
						"com_num_".$num_wanted."_at_or_after_cid");
					$s_opt->{cid_at_or_after} = $min_cid
						if $min_cid && $min_cid =~ /^\d+$/;
				}
			}
		} else {
			if ($cc_time_period >= $non_admin_limit ) {
				$s_opt->{cid_at_or_after} = $cid_for_time_period;
				$num_wanted = $non_admin_limit;
			} else {
				$num_wanted = $non_admin_limit;
				if($store_cutoff){
					my $min_cid = $reader->getUser($value,
						"com_num_".$num_wanted."_at_or_after_cid");
					$s_opt->{cid_at_or_after} = $min_cid
						if $min_cid && $min_cid =~ /^\d+$/;
				}
			}
		}
	}
	if ($type eq "uid") {

		my $comments = $reader->getCommentsByUID($value, $num_wanted, $min_comment, $s_opt) if $cc_all;
		if ($store_cutoff
			&& $comments && $cc_all >= $store_cutoff && $min_comment == 0 
			&& scalar(@$comments) == $num_wanted) {
			my $min_cid = 0;
			for my $comment (@$comments) {
				$min_cid = $comment->{cid}
					if !$min_cid || ($comment->{cid} < $min_cid); 
			}
			if ($min_cid && $min_cid =~/^\d+$/) {
				$slashdb->setUser($value, {
					"com_num_".$num_wanted."_at_or_after_cid" => $min_cid
				});
			}
			
		}
		return $comments;
	} elsif ($type eq "ipid"){
		return $reader->getCommentsByIPID($value, $num_wanted, $min_comment, $s_opt) if $cc_all;
	} elsif ($type eq "subnetid"){
		return $reader->getCommentsBySubnetID($value, $num_wanted, $min_comment, $s_opt) if $cc_all;
	} else {
		return $reader->getCommentsByIPIDOrSubnetID($value, $num_wanted, $min_comment, $s_opt) if $cc_all;
	}
}
createEnvironment();
main();

1;


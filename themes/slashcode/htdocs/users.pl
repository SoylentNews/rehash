#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
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
	my $formname = $0;
	$formname =~ s/.*\/(\w+)\.pl/$1/;

	my $error_flag = 0;
	my $formkey = $form->{formkey};

	my $suadmin_flag = $user->{seclev} >= 10000 ? 1 : 0 ;
	my $postflag = $user->{state}{post};
	my $op = lc($form->{op});

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
			checks		=> [],
		},
		userlogin	=>  {
			function	=> \&showInfo,
			seclev		=> 1,
			formname	=> $formname,
			checks		=> [],
			tab_selected_1	=> 'me',
		},
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
		savepasswd	=> {
			function	=> \&savePasswd,
			seclev		=> 1,
			post		=> 1,
			formname	=> $formname,
			checks		=> [ qw (max_post_check valid_check
						formkey_check regen_formkey) ],
			tab_selected_1	=> 'preferences',
			tab_selected_2	=> 'password',
		},
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
		changepasswd	=> {
			function	=> \&changePasswd,
			seclev		=> 1,
			formname	=> $formname,
			checks		=> $savepass_flag ? [] :
						[ qw (generate_formkey) ],
			tab_selected_1	=> 'preferences',
			tab_selected_2	=> 'password',
		},
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
		newuser		=> {
			function	=> \&newUser,
			seclev		=> 0,
			formname	=> "${formname}/nu",
			checks		=> [ qw (max_post_check valid_check
						formkey_check regen_formkey) ],
		},
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
		mailpasswd	=> {
			function	=> \&mailPasswd,
			seclev		=> 0,
			formname	=> "${formname}/mp",
			checks		=> [ qw (max_post_check valid_check
						interval_check formkey_check ) ],
			tab_selected_1	=> 'preferences',
			tab_selected_2	=> 'password',
		},
		validateuser	=> {
			function	=> \&validateUser,
			seclev		=> 1,
			formname	=> $formname,
			checks		=> ['regen_formkey'],
		},
		userclose	=>  {
			function	=> \&displayForm,
			seclev		=> 0,
			formname	=> $formname,
			checks		=> [],
		},
		newuserform	=> {
			function	=> \&displayForm,
			seclev		=> 0,
			formname	=> "${formname}/nu",
			checks		=> [ qw (max_post_check
						generate_formkey) ],
		},
		mailpasswdform 	=> {
			function	=> \&displayForm,
			seclev		=> 0,
			formname	=> "${formname}/mp",
			checks		=> [ qw (max_post_check
						generate_formkey) ],
			tab_selected_1	=> 'preferences',
			tab_selected_2	=> 'password',
		},
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
			adminmenu	=> 'me',
			page		=> 'readonly',
		},
		listbanned => {
			function	=> \&listBanned,
			seclev		=> 100,
			formname	=> $formname,
			checks		=> [],
			adminmenu	=> 'me',
			page		=> 'banned',
		},
		topabusers 	=> {
			function	=> \&topAbusers,
			seclev		=> 100,
			formname	=> $formname,
			checks		=> [],
			adminmenu	=> 'me',
			page		=> 'abusers',
		},
		listabuses 	=> {
			function	=> \&listAbuses,
			seclev		=> 100,
			formname	=> $formname,
			checks		=> [],
		},
	} ;
	$ops->{default} = $ops->{displayform};

	my $errornote = "";
	if ($form->{op} && ! defined $ops->{$op}) {
		$errornote .= getError('bad_op', { op => $form->{op}}, 0, 1);
		$op = $user->{is_anon} ? 'userlogin' : 'userinfo'; 
	}

	if ($op eq 'userlogin' && ! $user->{is_anon}) {
		# We absolutize the return-to URL to our homepage just to
		# be sure nobody can use the site as a redirection service.
		# We decide whether to use the secure homepage or not
		# based on whether the current page is secure.
		my $abs_dir =
			( $constants->{absolutedir_secure}
				&& Slash::Apache::ConnectionIsSSL() )
			? $constants->{absolutedir_secure}
			: $constants->{absolutedir};
		my $refer = URI->new_abs($form->{returnto} || $constants->{rootdir},
			$abs_dir);

		# Tolerate redirection with or without a "www.", this is a
		# little sloppy but it may help avoid a subtle misbehavior
		# someday. -- Jamie
		# What misbehavior? It looks to me like it could break a
		# site.  www.foo.com is not necessarily the same as foo.com.
		# Please explain.  -- pudge
		# The only question here is whether it's allowed to
		# redirect the user to a particular URL.  The business
		# logic here is that we don't bounce the user to foreign
		# sites (otherwise innocuous-looking URLs at foo.com can be
		# constructed that send the user anywhere on the internet).
		# But any site on the same domain is considered safe/OK.
		# If it is, we still redirect the user to the same $refer.
		# If www.foo.com really thinks it's unsafe to redirect the
		# user to a URL at foo.com, they need to change this logic
		# (or find a new web host!) -- Jamie
		# So you're saying SourceForge.net domains are
		# messed up?  :)  -- pudge
		# I have no comment at this time -- Jamie

		my $site_domain = $constants->{basedomain};
		$site_domain =~ s/^www\.//;
		$site_domain =~ s/:.+$//;	# strip port, if available

		my $refer_host = $refer->can("host") ? $refer->host() : "";
		$refer_host =~ s/^www\.//;

		if ($site_domain eq $refer_host) {
			# Cool, it goes to our site.  Send the user there.
			$refer = $refer->as_string;
		} else {
			# Bogus, it goes to another site.  op=userlogin is not a
			# URL redirection service, sorry.
			$refer = $constants->{rootdir};
		}
		redirect($refer);
		return;

	# this will only redirect if it is a section-based rootdir, and
	# NOT an isolated section (which has the same rootdir as real_rootdir)
	} elsif ($op eq 'userclose' && $constants->{rootdir} ne $constants->{real_rootdir}) {
		redirect($constants->{real_rootdir}, '/users.pl?op=userclose');

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

	# Print the header and very top stuff on the page.
	header(getMessage('user_header'));
	# This is a hardcoded position, bad idea and should be fixed -Brian
	# Yeah, we should pull this into a template somewhere...
	print getMessage('note', { note => $errornote }) if defined $errornote;

	# Figure out what the op really is.
	$op = 'userinfo' if (! $form->{op} && ($form->{uid} || $form->{nick}));
	$op ||= $user->{is_anon} ? 'userlogin' : 'userinfo';
	if ($user->{is_anon} && $ops->{$op}{seclev} > 0) {
		$op = 'default';
	} elsif ($user->{seclev} < $ops->{$op}{seclev}) {
		$op = 'userinfo';
	}
	if ($ops->{$op}{post} && !$postflag) {
		$op = $user->{is_anon} ? 'default' : 'userinfo';
	}

	# Print the top tabbed menu.  The op is responsible for printing
	# its own titlebar (and, usually, second-level tabbed menu).
print "\n<!-- users.pl main() op='$op' ts1='$ops->{$op}{tab_selected_1}' -->\n";
	print createMenu($formname, {
		style =>	'tabbed',
		justify =>	'right',
		color =>	'colored',
		tab_selected =>	$ops->{$op}{tab_selected_1} || "",
	});

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
		if (	   !$constants->{hc_sw_newuser}
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
	my $retval = $ops->{$op}{function}->({ op => $op }) if ! $error_flag;
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
	my $string = shift;
	my $constants = getCurrentStatic();
	# what is this supposed to be for? -- pudge
	$string = substr($string, 0, -1);

	$string =~ s/[^\w,-]//g;
	my @e = split m/,/, $string;
	$string = sprintf "'%s'", join "','", @e;
	my $len = $constants->{checklist_length} || 255;

	if (length($string) > $len) {
		print getError('checklist_err');
		$string = substr($string, 0, $len);
		$string =~ s/,'??\w*?$//g;
	} elsif (length($string) < 3) {
		$string = '';
	}

	return $string;
}

#################################################################
sub previewSlashbox {
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	my $block = $slashdb->getBlock($form->{bid}, ['title', 'block', 'url']);
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
	my $plugins = $slashdb->getDescriptions('plugins');
	my $title;
	my $suadmin_flag = $user->{seclev} >= 10000 ? 1 : 0;

	# Check if User Exists
	$form->{newusernick} = fixNickname($form->{newusernick});
	(my $matchname = lc $form->{newusernick}) =~ s/[^a-zA-Z0-9]//g;

	if (!$form->{email} || $form->{email} !~ /\@/) {
		print getError('email_invalid', 0, 1);
		return;
	} elsif ($slashdb->existsEmail($form->{email})) {
		print getError('emailexists_err', 0, 1);
		return;
	} elsif ($matchname ne '' && $form->{newusernick} ne '') {
		my $uid;
		my $rootdir = getCurrentStatic('rootdir', 'value');

		$uid = $slashdb->createUser(
			$matchname, $form->{email}, $form->{newusernick}
		);
		if ($uid) {
			my $data = {};
			getOtherUserParams($data);
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
				$params{MSG_CODE_NEW_COMMENT()} = MSG_MODE_EMAIL()
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
	my $uid = $hr->{uid} || 0;

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();

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

	if (!$uid || isAnon($uid)) {
		print getError('mailpasswd_notmailed_err');
		$slashdb->resetFormkey($form->{formkey});	
		$form->{op} = 'mailpasswdform';
		displayForm();
		return(1);
	}

	my $user_edit = $slashdb->getUser($uid, ['nickname', 'realemail']);
	my $newpasswd = $slashdb->getNewPasswd($uid);
	my $tempnick = fixparam($user_edit->{nickname});

	my $emailtitle = getTitle('mailPassword_email_title', {
		nickname	=> $user_edit->{nickname}
	}, 1);

	my $msg = getMessage('mailpasswd_msg', {
		newpasswd	=> $newpasswd,
		tempnick	=> $tempnick
	}, 1);

	doEmail($uid, $emailtitle, $msg) if $user_edit->{nickname};
	print getMessage('mailpasswd_mailed_msg', { name => $user_edit->{nickname} });
}

#################################################################
sub showSubmissions {
	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my($uid, $nickname);

	if ($form->{uid} or $form->{nick}) {
		$uid		= $form->{uid} || $slashdb->getUserUID($form->{nick});
		$nickname	= $slashdb->getUser($uid, 'nickname');
	} else {
		$nickname	= $user->{nickname};
		$uid		= $user->{uid};
	}

	my $storycount = $slashdb->countStoriesBySubmitter($uid);
	my $stories = $slashdb->getStoriesBySubmitter(
		$uid,
		$constants->{user_submitter_display_default}
	) unless !$storycount;

	slashDisplay('userSub', {
		nick			=> $nickname,
		uid			=> $uid,
		nickmatch_flag		=> ($user->{uid} == $uid ? 1 : 0),
		stories 		=> $stories,
		storycount 		=> $storycount,
	});
}

#################################################################
sub showComments {
	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $commentstruct = [];
	my($uid, $nickname);

	if ($form->{uid} or $form->{nick}) {
		$uid		= $form->{uid} || $slashdb->getUserUID($form->{nick});
		$nickname	= $slashdb->getUser($uid, 'nickname');
	} else {
		$nickname	= $user->{nickname};
		$uid		= $user->{uid};
	}

	my $min_comment = $form->{min_comment} || 0;
	$min_comment = 0 unless $user->{is_admin};
	my $comments_wanted = $user->{show_comments_num}
		|| $constants->{user_comment_display_default};
	my $commentcount = $slashdb->countCommentsByUID($uid);
	my $comments = $slashdb->getCommentsByUID(
		$uid, $comments_wanted, $min_comment
	) if $commentcount;

	for (@$comments) {
		my($pid, $sid, $cid, $subj, $cdate, $pts, $uid) = @$_;
		$uid ||= 0;

		my $type;
		# This works since $sid is numeric.
		my $replies = $slashdb->countCommentsBySidPid($sid, $cid);

		# This is ok, since with all luck we will not be hitting the DB
		# ...however, the "sid" parameter here must be the string
		# based SID from either the "stories" table or from
		# pollquestions.
		my($discussion) = $slashdb->getDiscussion($sid);

		if ($discussion->{url} =~ /journal/i) {
			$type = 'journal';
		} elsif ($discussion->{url} =~ /poll/i) {
			$type = 'poll';
		} else {
			$type = 'story';
		}

		push @$commentstruct, {
			pid 		=> $pid,
			url		=> $discussion->{url},
			type 		=> $type,
			disc_title	=> $discussion->{title},
			sid 		=> $sid,
			cid 		=> $cid,
			subj		=> $subj,
			cdate		=> $cdate,
			pts		=> $pts,
			uid		=> $uid,
			replies		=> $replies,
		};
	}

	slashDisplay('userCom', {
		nick			=> $nickname,
		uid			=> $uid,
		nickmatch_flag		=> ($user->{uid} == $uid ? 1 : 0),
		points			=> $slashdb->getUser($uid, 'points'),
		lastgranted		=> $slashdb->getUser($uid, 'lastgranted'),
		commentstruct		=> $commentstruct || [],
		commentcount		=> $commentcount,
		min_comment		=> $min_comment,
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

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	my $admin_flag = ($user->{is_admin}) ? 1 : 0;
	my($title, $admin_block, $fieldkey) = ('', '', '');
	my $comments = undef;
	my $commentcount = 0;
	my $commentstruct = [];
	my $requested_user = {};

	my($points, $lastgranted, $nickmatch_flag, $uid, $nick);
	my($mod_flag, $karma_flag, $n) = (0, 0, 0);

	if (! $id && ! $form->{userfield}) {
		if ($form->{uid} && ! $id) {
			$fieldkey = 'uid';
			($uid, $id) = ($form->{uid}, $form->{uid});
			$requested_user = isAnon($uid) ? $user : $slashdb->getUser($id);
			$nick = $requested_user->{nickname};
			$form->{userfield} = $nick if $admin_flag;

		} elsif ($form->{nick} && ! $id) {
			$fieldkey = 'nickname';
			($nick, $id) = ($form->{nick}, $form->{nick});
			$uid = $slashdb->getUserUID($id);
			if (isAnon($uid)) {
				$requested_user = $user;
				($nick, $uid, $id) = @{$user}{qw(nickname uid nickname)};
			} else {
				$requested_user = $slashdb->getUser($uid);
			}
			$form->{userfield} = $uid if $admin_flag;

		} else {
			$fieldkey = 'uid';
			($id, $uid) = ($user->{uid}, $user->{uid});
			$requested_user = $slashdb->getUser($uid);
			$form->{userfield} = $uid if $admin_flag;
		}

		# no can do boss-man
		if (isAnon($uid)) {
			return displayForm();
		}

	} elsif ($user->{is_admin}) {
		$id ||= $form->{userfield} || $user->{uid};
		if ($id =~ /^\d+$/) {
			$fieldkey = 'uid';
			$requested_user = $slashdb->getUser($id);
			$uid = $requested_user->{uid};
			$nick = $requested_user->{nickname};
			if ((my $conflict_id = $slashdb->getUserUID($id)) && $form->{userinfo}) {
				slashDisplay('showInfoConflict', {
					op		=> 'userinfo',
					id		=> $uid,
					nick		=> $nick,
					conflict_id	=> $conflict_id
				});
				return 1;
			}

		} elsif (length($id) == 32) {
			$fieldkey = 'md5id';
			$requested_user->{nonuid} = 1;
			$requested_user->{md5id} = $id;

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

		} else {  # go by nickname, but make it by uid
			$fieldkey = 'uid';
			$id = $uid = $slashdb->getUserUID($id);
			$requested_user = $slashdb->getUser($uid);
			$nick = $requested_user->{nickname};
		}
		
	} else {
		$fieldkey = 'uid';
		($id, $uid) = ($user->{uid}, $user->{uid});
		$requested_user = $slashdb->getUser($uid);
	}

	my $user_change = { };
	if ($fieldkey eq 'uid' && $uid != $user->{uid}) {
		# Store the fact that this user last looked at that user.
		# For maximal convenience in stalking.
		$user_change->{lastlookuid} = $uid;
	}

	my $comments_wanted = $user->{show_comments_num}
		|| $constants->{user_comment_display_default};
	my $min_comment = $form->{min_comment} || 0;
	# haven't decided whether ordinary users get this yet
	$min_comment = 0 unless $admin_flag;

	my($netid, $netid_vis) = ('', '');
	if ($requested_user->{nonuid}) {
		$requested_user->{fg} = $user->{fg};
		$requested_user->{bg} = $user->{bg};

		if ($requested_user->{ipid}) {
			$netid = $requested_user->{ipid} ;

		} elsif ($requested_user->{md5id}) {
			$netid = $requested_user->{md5id} ;

		} else {
			$netid = $requested_user->{subnetid} ;
		}
		$netid_vis = $netid;
		$netid_vis = substr($netid, 0, $constants->{id_md5_vislength})
			if $constants->{id_md5_vislength};

		$title = getTitle('user_netID_user_title', {
			id => $id,
			md5id => $netid,
			md5id_vis => $netid_vis,
		});

		
		$admin_block = getUserAdmin($netid, $fieldkey, 1, 0) if $admin_flag;

		if ($form->{fieldname}) {
			if ($form->{fieldname} eq 'ipid') {
				$commentcount = $slashdb->countCommentsByIPID(
					$netid, $comments_wanted, $min_comment);
				$comments = $slashdb->getCommentsByIPID(
					$netid, $comments_wanted, $min_comment);
			} elsif ($form->{fieldname} eq 'subnetid') {
				$commentcount = $slashdb->countCommentsBySubnetID(
					$netid, $comments_wanted, $min_comment);
				$comments = $slashdb->getCommentsBySubnetID(
					$netid, $comments_wanted, $min_comment);
			} else {
				delete $form->{fieldname};
			}
		}
		if (!defined($comments)) {
			# Last resort; here for backwards compatibility mostly.
			$commentcount = $slashdb->countCommentsByIPIDOrSubnetID(
				$netid, $comments_wanted, $min_comment);
			$comments = $slashdb->getCommentsByIPIDOrSubnetID(
				$netid, $comments_wanted, $min_comment
			);
		}

	} else {
		$admin_block = getUserAdmin($id, $fieldkey, 1, 1) if $admin_flag;

		$commentcount =
			$slashdb->countCommentsByUID($requested_user->{uid});
		$comments = $slashdb->getCommentsByUID(
			$requested_user->{uid}, $comments_wanted, $min_comment
		) if $commentcount;
		$netid = $requested_user->{uid};
	}

	for (@$comments) {
		my($pid, $sid, $cid, $subj, $cdate, $pts, $uid) = @$_;
		$uid ||= 0;

		my $type;
		# This works since $sid is numeric.
		my $replies = $slashdb->countCommentsBySidPid($sid, $cid);

		# This is ok, since with all luck we will not be hitting the DB
		# ...however, the "sid" parameter here must be the string
		# based SID from either the "stories" table or from
		# pollquestions.
		my($discussion) = $slashdb->getDiscussion($sid);

		if ($discussion->{url} =~ /journal/i) {
			$type = 'journal';
		} elsif ($discussion->{url} =~ /poll/i) {
			$type = 'poll';
		} else {
			$type = 'story';
		}

		push @$commentstruct, {
			pid 		=> $pid,
			url		=> $discussion->{url},
			type 		=> $type,
			disc_title	=> $discussion->{title},
			sid 		=> $sid,
			cid 		=> $cid,
			subj		=> $subj,
			cdate		=> $cdate,
			pts		=> $pts,
			uid		=> $uid,
			replies		=> $replies,
		};
	}
	my $storycount =
		$slashdb->countStoriesBySubmitter($requested_user->{uid})
	unless $requested_user->{nonuid};
	my $stories = $slashdb->getStoriesBySubmitter(
		$requested_user->{uid},
		$constants->{user_submitter_display_default}
	) unless !$storycount || $requested_user->{nonuid};

	if ($requested_user->{nonuid}) {
		slashDisplay('netIDInfo', {
			title			=> $title,
			id			=> $id,
			user			=> $requested_user,
			commentstruct		=> $commentstruct || [],
			commentcount		=> $commentcount,
			min_comment		=> $min_comment,
			admin_flag		=> $admin_flag,
			admin_block		=> $admin_block,
			netid			=> $netid,
			netid_vis		=> $netid_vis,
		});

	} else {
		if (! $requested_user->{uid}) {
			
			print getError('userinfo_idnf_err', { id => $id, fieldkey => $fieldkey});
			return;
		}

		$karma_flag = 1 if $admin_flag;
		$requested_user->{nick_plain} = $nick ||= $requested_user->{nickname};
		$nick = strip_literal($nick);

		if ($requested_user->{uid} == $user->{uid}) {
			$karma_flag = 1;
			$nickmatch_flag = 1;
			$points = $requested_user->{points};

			$mod_flag = 1 if $points > 0;

			if ($points) {
				$mod_flag = 1;
				$lastgranted = $slashdb->getUser($uid, 'lastgranted');
				if ($lastgranted) {
					my $hours = $constants->{mod_stir_hours}
						|| $constants->{stir}*24;
					$requested_user->{points_expire} = timeCalc(
						$lastgranted,
						"%Y-%m-%d",
						$user->{off_set} + $hours*3600
					);
# Older and much slower way of doing this; required Date::Manip, ick!
#					$requested_user->{points_expire} = timeCalc(
#						UnixDate(DateCalc($lastgranted, "+ $hours hours"),
#							"%C"),
#						'%Y-%m-%d'
#					);
				}
			}

			$title = getTitle('userInfo_main_title', { nick => $nick, uid => $uid });

		} else {
			$title = getTitle('userInfo_user_title', { nick => $nick, uid => $uid });
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
			stories 		=> $stories,
			storycount 		=> $storycount,
		});
	}

	if ($user_change && %$user_change) {
		$slashdb->setUser($user->{uid}, $user_change);
	}
}

#####################################################################
sub validateUser {
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	# If we aren't expiring accounts in some way, we don't belong here.
	if (! allowExpiry()) {
		displayForm();
		return;
	}

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
sub adminDispatch {
	my($hr) = @_;
	my $form = getCurrentForm();
	my $op = $hr->{op} || $form->{op};

	if ($op eq 'authoredit') {
		editUser({ uid => $form->{authoruid} });

	} elsif ($form->{saveuseradmin}) {
		saveUserAdmin();

	} elsif ($form->{userinfo}) {
		showInfo();

	} elsif ($form->{userfield}) {
		if ($form->{edituser}) {
			editUser();

		} elsif ($form->{edithome}) {
			editHome();

		} elsif ($form->{editcomm}) {
			editComm();

		} elsif ($form->{changepasswd}) {
			changePasswd();
		}

	} else {
		showInfo();
	}
}

#################################################################
sub tildeEd {
	my($extid, $exsect, $exaid, $exboxes, $userspace) = @_;

	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my($aidref, $aid_order, $tidref, $tid_order, $sectionref, $section_descref, $box_order, $tilde_ed, $tilded_msg_box);

	# users_tilded_title
	my $title = getTitle('tildeEd_title');

	# Customizable Authors Thingee
	my $aids = $slashdb->getDescriptions('all-authors'); #$slashdb->getAuthorNames();
	my $n = 0;

	@$aid_order = sort { lc $aids->{$a} cmp lc $aids->{$b} } keys %$aids;

	for my $aid (keys %$aids) { #(@$aids) {
		$aidref->{$aid}{checked}  = ($exaid =~ /'\Q$aid\E'/) ? ' CHECKED' : '';
		$aidref->{$aid}{nickname} = $aids->{$aid};
	}

	my $topics = $slashdb->getDescriptions('topics');

	@$tid_order = sort { lc $topics->{$a} cmp lc $topics->{$b} } keys %$topics;

	while (my($tid, $alttext) = each %$topics) {
		$tidref->{$tid}{checked} = ($extid =~ /'\Q$tid\E'/) ?
			' CHECKED' : '';
		$tidref->{$tid}{alttext} = $alttext;
	}

	my $sections = $slashdb->getDescriptions('sections-contained');
	while (my($section, $title) = each %$sections) {
		next if !$section;
		$sectionref->{$section}{checked} =
			($exsect =~ /'\Q$section\E'/) ? ' CHECKED' : '';
		$sectionref->{$section}{title} = $title;
	}

	my $customize_title = getTitle('tildeEd_customize_title');

	my $tilded_customize_msg = getMessage('users_tilded_customize_msg',
		{ userspace => $userspace });

	my $sections_description = $slashdb->getSectionBlocks();

	# repeated from above?
	$customize_title = getTitle('tildeEd_customize_title');

	for (sort { lc $b->[1] cmp lc $a->[1]} @$sections_description) {
		my($bid, $title, $boldflag) = @$_;

		unshift(@$box_order, $bid);
		$section_descref->{$bid}{checked} = ($exboxes =~ /'$bid'/) ?
			' CHECKED' : '';
		$section_descref->{$bid}{boldflag} = $boldflag > 0;
		$title =~ s/<(.*?)>//g;
		$section_descref->{$bid}{title} = $title;
	}

	my $tilded_box_msg = getMessage('tilded_box_msg');
	$tilde_ed = slashDisplay('tildeEd', {
		title			=> $title,
		customize_title		=> $customize_title,
		tilded_customize_msg	=> $tilded_customize_msg,
		tilded_box_msg		=> $tilded_box_msg,
		aidref			=> $aidref,
		aid_order		=> $aid_order,
		tidref			=> $tidref,
		tid_order		=> $tid_order,
		sectionref		=> $sectionref,
		section_descref		=> $section_descref,
		box_order		=> $box_order,
		userspace		=> $userspace,
	}, 1);

	return($tilde_ed);
}

#################################################################
sub changePasswd {
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	my $user_edit = {};
	my $title;
	my $suadmin_flag = ($user->{seclev} >= 10000) ? 1 : 0;

	my $id = '';
	if ($user->{is_admin}) {
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

	# print getMessage('note', { note => $form->{note}}) if $form->{note};

	$title = getTitle('changePasswd_title', { user_edit => $user_edit });

	my $session = $slashdb->getDescriptions('session_login');
	my $session_select = createSelect('session_login', $session, $user_edit->{session_login}, 1);

	slashDisplay('changePasswd', {
		useredit 		=> $user_edit,
		admin_flag		=> $suadmin_flag,
		title			=> $title,
		session 		=> $session_select,
	});
}

#################################################################
sub editUser {
	my($hr) = @_;
	my $id = $hr->{uid} || '';
	my $note = $hr->{note} || '';

	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $plugins = $slashdb->getDescriptions('plugins');

	my $user_edit = {};
	my($admin_block, $title);
	my $admin_flag = ($user->{is_admin}) ? 1 : 0;
	my $fieldkey;

	if ($form->{userfield}) {
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

	$admin_block = getUserAdmin($id, $fieldkey, 1, 1) if $admin_flag;
	$user_edit->{homepage} ||= "http://";

	# Remove domain tags, they'll be added back in, in saveUser.
	for my $dat (@{$user_edit}{qw(sig bio)}) {
		$dat = parseDomainTags($dat, 0, 1);
	}

	$title = getTitle('editUser_title', { user_edit => $user_edit});

	slashDisplay('editUser', {
		useredit 		=> $user_edit,
		admin_flag		=> $admin_flag,
		title			=> $title,
		editkey 		=> $plugins->{'PubKey'} ? editKey($user_edit->{uid}) : '',
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

	my($formats, $title, $tzformat_select);
	my $user_edit = {};
	my $fieldkey;

	my $admin_flag = ($user->{is_admin}) ? 1 : 0;
	my $admin_block = '';

	if ($form->{userfield}) {
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

	return if isAnon($user_edit->{uid}) && ! $admin_flag;
	$admin_block = getUserAdmin($id, $fieldkey, 1, 1) if $admin_flag;

	$title = getTitle('editHome_title');

	return if $user->{seclev} < 100 && isAnon($user_edit->{uid});

	$formats = $slashdb->getDescriptions('dateformats');
	$tzformat_select = createSelect('tzformat', $formats, $user_edit->{dfid}, 1);

	my $l_check = $user_edit->{light}		? ' CHECKED' : '';
	my $b_check = $user_edit->{noboxes}		? ' CHECKED' : '';
	my $i_check = $user_edit->{noicons}		? ' CHECKED' : '';
	my $w_check = $user_edit->{willing}		? ' CHECKED' : '';
	my $s_check = $user_edit->{sectioncollapse}	? ' CHECKED' : '';

	my $tilde_ed = tildeEd(
		$user_edit->{extid}, $user_edit->{exsect},
		$user_edit->{exaid}, $user_edit->{exboxes}, $user_edit->{mylinks}
	);

	slashDisplay('editHome', {
		title			=> $title,
		admin_block		=> $admin_block,
		user_edit		=> $user_edit,
		tzformat_select		=> $tzformat_select,
		l_check			=> $l_check,
		b_check			=> $b_check,
		i_check			=> $i_check,
		w_check			=> $w_check,
		s_check			=> $s_check,
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
		$uthreshold_select, $highlightthresh_select, $posttype_select);

	my $admin_block = '';
	my $fieldkey;

	my $admin_flag = $user->{is_admin} ? 1 : 0;

	if ($form->{userfield}) {
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

	my @reasons = ( );
	my $reasons = $slashdb->getReasons();
	for my $id (sort { $a <=> $b } keys %$reasons) {
		push @reasons, $reasons->{$id}{name};
	}

	my %reason_select;

	my $hi = $constants->{comment_maxscore} - $constants->{comment_minscore};
	my $lo = -$hi;
	my @range = map { $_ > 0 ? "+$_" : $_ } ($lo .. $hi);

	for my $reason_name (@reasons) {
		my $key = "reason_alter_$reason_name";
		$reason_select{$reason_name} = createSelect(
			$key, \@range, 
			$user_edit->{$key} || 0, 1, 1
		);
	}

	my %people_select;
	my @people =  qw(friend foe anonymous fof eof freak fan);
	for (@people) {
		my $key = "people_bonus_$_";
		$people_select{$_} = createSelect($key, \@range, 
			$user_edit->{$key} || 0, 1, 1
		);
	}
	# For New User bonus stuff
	my $new_user_bonus_select = createSelect('new_user_bonus', \@range, 
			$user_edit->{new_user_bonus} || 0, 1, 1);
	my $new_user_percent_select = createSelect('new_user_percent',
			[( 1..19, 20, 25, 30, 35, 40, 45, 50, 55,
				  60, 65, 70, 75, 80, 85, 90, 95 )], 
			$user_edit->{new_user_percent} || 100, 1, 1);

	return if isAnon($user_edit->{uid}) && ! $admin_flag;
	$admin_block = getUserAdmin($id, $fieldkey, 1, 1) if $admin_flag;

	$title = getTitle('editComm_title');

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

	my $h_check = $user_edit->{hardthresh}		? ' CHECKED' : '';
	my $r_check = $user_edit->{reparent}		? ' CHECKED' : '';
	my $n_check = $user_edit->{noscores}		? ' CHECKED' : '';
	my $s_check = $user_edit->{nosigs}		? ' CHECKED' : '';
	my $d_check = $user_edit->{sigdash}		? ' CHECKED' : '';
	my $b_check = $user_edit->{nobonus}		? ' CHECKED' : '';
	my $p_check = $user_edit->{postanon}		? ' CHECKED' : '';
	my $nospell_check = $user_edit->{no_spell}	? ' CHECKED' : '';

	$formats = $slashdb->getDescriptions('postmodes');
	$posttype_select = createSelect(
		'posttype', $formats, $user_edit->{posttype}, 1
	);

	slashDisplay('editComm', {
		title			=> $title,
		admin_block		=> $admin_block,
		user_edit		=> $user_edit,
		h_check			=> $h_check,
		r_check			=> $r_check,
		n_check			=> $n_check,
		s_check			=> $s_check,
		d_check			=> $d_check,
		b_check			=> $b_check,
		p_check			=> $p_check,
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
	});
}

#################################################################
sub saveUserAdmin {
	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	my($user_edits_table, $user_edit) = ({}, {});
	my $save_success = 0;
	my $author_flag;
	my $note = '';
	my $id;
	my $user_editfield_flag;
	my $banned = 0;
	my $banref;

	if ($form->{uid}) {
		$user_editfield_flag = 'uid';
		$id = $form->{uid};
		$user_edit = $slashdb->getUser($id);

	} elsif ($form->{subnetid}) {
		$user_editfield_flag = 'subnetid';
		$user_edit->{uid} = $constants->{anonymous_coward_uid};
		($id, $user_edit->{subnetid})  = ($form->{subnetid}, $form->{subnetid});
		$user_edit->{nonuid} = 1;

	} elsif ($form->{ipid}) {
		$user_editfield_flag = 'ipid';
		($id, $user_edit->{ipid})  = ($form->{ipid}, $form->{ipid});
		$user_edit->{subnetid} = $1 . "0" ;
		$user_edit->{subnetid} = md5_hex($user_edit->{subnetid});
		$user_edit->{uid} = $constants->{anonymous_coward_uid};
		$user_edit->{nonuid} = 1;

	} elsif ($form->{md5id}) {
		$user_editfield_flag = 'md5id';
		#($id, $user_edit->{ipid}, $user_edit->{subnetid})
		($id, $user_edit->{$form->{fieldname}})
			= ($form->{md5id}, $form->{md5id});

	} else { # a bit redundant, I know
		$user_edit = $user;
	}

	for my $formname ('comments', 'submit') {
		my $aclinfo =
			$slashdb->getAccessListInfo(
				$formname, 'readonly', $user_edit
			);
		my $existing_reason = $aclinfo->{reason};
		my $is_readonly_now =
			$slashdb->checkReadOnly($formname, $user_edit) ? 1 : 0;

		my $keyname = "readonly_" . $formname;
		my $reason_keyname = $formname . "_ro_reason";
		$form->{$keyname} = $form->{$keyname} eq 'on' ? 1 : 0 ;
		$form->{$reason_keyname} ||= '';

		if ($form->{$keyname} != $is_readonly_now) {
			if ($existing_reason ne $form->{$reason_keyname}) {
				$slashdb->setAccessList(
					$formname, 
					$user_edit, 
					$form->{$keyname}, 
					'readonly', 
					$form->{$reason_keyname}
				);
			} else {
				$slashdb->setAccessList(
					$formname, 
					$user_edit, 
					$form->{$keyname}, 
					'readonly'
				);
			}
		} elsif ($existing_reason ne $form->{$reason_keyname}) {
			$slashdb->setAccessList(
				$formname, 
				$user_edit, 
				$form->{$keyname}, 
				'readonly', 
				$form->{$reason_keyname}
			);
		}

		# $note .= getError('saveuseradmin_notsaved', { field => $user_editfield_flag, id => $id });
	}

	$banref = $slashdb->getBanList(1);
	$banned = $banref->{$id} ? 1 : 0;
	$form->{banned} = $form->{banned} eq 'on' ? 1 : 0 ;
	if ($banned) {
		if ($form->{banned} == 0) {
			$slashdb->setAccessList('', $user_edit, 0, 'isbanned', $form->{banned_reason});
			$slashdb->getBanList(1);
		}
	} else {
		if ($form->{banned} == 1) {
			$slashdb->setAccessList('', $user_edit, $form->{banned}, 'isbanned', $form->{banned_reason});
			$slashdb->getBanList(1);
		}
	}

	$note .= getMessage('saveuseradmin_saved', { field => $user_editfield_flag, id => $id}) if $save_success;

	if ($user->{is_admin} && ($user_editfield_flag eq 'uid' ||
		$user_editfield_flag eq 'nickname')) {

		$user_edits_table->{seclev} = $form->{seclev};
		$user_edits_table->{section} = $form->{section};
		$user_edits_table->{author} = $form->{author} ? 1 : 0 ;
		$user_edits_table->{defaultpoints} = $form->{defaultpoints};
		$user_edits_table->{tokens} = $form->{tokens};
		$user_edits_table->{m2info} = $form->{m2info};

		my $was_author = ($slashdb->getAuthor($id)->{author}) ? 1 : 0;

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
		if ($form->{expired} eq 'on') {
			$slashdb->setExpired($user_edit->{uid});

		} else {
			$slashdb->setUnexpired($user_edit->{uid});
		}
	}

	print getMessage('note', { note => $note }) if defined $note;

	showInfo({ uid => $id });
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

	if (length $form->{pass1} < 6 && $form->{pass1} && $form->{pass1} ne "") {
		$$note .= getError('saveuser_passtooshort_err', { titlebar => 0 }, 0, 1)
			if $note;
		$error_flag++;
	}

	if (! $error_flag) {
		$user_edits_table->{passwd} = $form->{pass1} if $form->{pass1};
		$user_edits_table->{session_login} = $form->{session_login};
		my $pass = bakeUserCookie($uid,
			$user_edits_table->{passwd}
				? encryptPassword($user_edits_table->{passwd})
				: $user_edit->{passwd}
		);

		if ($form->{uid} eq $user->{uid}) {
			setCookie('user', $pass, $user_edits_table->{session_login});
		}

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
	}

	return $error_flag;
}

#################################################################
sub saveUser {
	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
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

	# The schema is 160 chars but we limit their input to 120.
	my(%extr, $err_message);
	$extr{sig} = chopEntity($form->{sig}, 120);
	$extr{bio} = chopEntity($form->{bio}, $constants->{users_bio_length} || 1024);

	for my $key (keys %extr) {
		my $dat = $extr{$key};
		$dat = strip_html($dat);
		$dat = balanceTags($dat, 1); # only 1 nesting tag (UL, OL, BLOCKQUOTE) allowed
		$dat = addDomainTags($dat) if $dat;

		# If the sig becomes too long to fit (domain tagging causes
		# string expansion and tag balancing can too), warn the user to
		# use shorter domain names and don't save their change.
		if ($key eq 'sig' && defined($dat) && length($dat) > 160) {
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
	$homepage = URI->new_abs($homepage, $constants->{absolutedir})
			->canonical
			->as_string if $homepage ne '';
	$homepage = substr($homepage, 0, 100) if $homepage ne '';

	# for the users table
	my $user_edits_table = {
		homepage	=> $homepage,
		realname	=> $form->{realname},
		pubkey		=> $form->{pubkey},
		copy		=> $form->{copy},
		quote		=> $form->{quote},
	};
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
		$new_fakeemail = getArmoredEmail($uid)	if $form->{emaildisplay} == 1;
		$new_fakeemail = $user_edit->{realemail}	if $form->{emaildisplay} == 2;
	}

	my $name = $user->{seclev} && $form->{name} ?
		$form->{name} : $user->{nickname};

	my $note = getMessage('savenickname_msg',
		{ nickname => $name });

	print getError('cookie_err') if isAnon($uid) || !$name;

	# Take care of the lists
	# Enforce Ranges for variables that need it
	$form->{commentlimit} = 0 if $form->{commentlimit} < 1;
	$form->{commentspill} = 0 if $form->{commentspill} < 1;

	my $max = $constants->{comment_maxscore} - $constants->{comment_minscore};
	my $min = -$max;
	my $new_user_bonus = ($form->{new_user_bonus} !~ /^[\-+]?\d+$/) ? 0 : $form->{new_user_bonus};
	my $new_user_percent = (($form->{new_user_percent} <= 100 && $form->{new_user_percent} >= 0) 
			? $form->{new_user_percent}
			: 100); 

	# This has NO BEARING on the table the data goes into now.
	# setUser() does the right thing based on the key name.
	my $users_comments_table = {
		clbig		=> $form->{clbig},
		clsmall		=> $form->{clsmall},
		commentlimit	=> $form->{commentlimit},
		commentsort	=> $form->{commentsort},
		commentspill	=> $form->{commentspill},
		domaintags	=> ($form->{domaintags} != 2 ? $form->{domaintags} : undef),
		emaildisplay	=> $form->{emaildisplay} ? $form->{emaildisplay} : undef,
		fakeemail	=> $new_fakeemail,
		highlightthresh	=> $form->{highlightthresh},
		maxcommentsize	=> $form->{maxcommentsize},
		mode		=> $form->{umode},
		posttype	=> $form->{posttype},
		threshold	=> $form->{uthreshold},
		nosigs		=> ($form->{nosigs}     ? 1 : 0),
		reparent	=> ($form->{reparent}   ? 1 : 0),
		noscores	=> ($form->{noscores}   ? 1 : 0),
		hardthresh	=> ($form->{hardthresh} ? 1 : 0),
		no_spell	=> ($form->{no_spell}   ? 1 : undef),
		sigdash		=> ($form->{sigdash} ? 1 : undef),
		nobonus		=> ($form->{nobonus} ? 1 : undef),
		postanon	=> ($form->{postanon} ? 1 : undef),
		new_user_percent => ($new_user_percent && $new_user_percent != 100
					? $new_user_percent : undef),
		new_user_bonus	=> ($new_user_bonus
					? $new_user_bonus : undef),
		textarea_rows	=> ($form->{textarea_rows} != $constants->{textarea_rows}
					? $form->{textarea_rows} : undef),
		textarea_cols	=> ($form->{textarea_cols} != $constants->{textarea_cols}
					? $form->{textarea_cols} : undef),
	};

	my @reasons = ( );
	my $reasons = $slashdb->getReasons();
	for my $id (sort { $a <=> $b } keys %$reasons) {
		push @reasons, $reasons->{$id}{name};
	}

	for my $reason_name (@reasons) {
		my $key = "reason_alter_$reason_name";
		my $answer = $form->{$key};
		$answer = 0 if $answer !~ /^[\-+]?\d+$/;
		$users_comments_table->{$key} = ($answer == 0) ? '' : $answer;
	}

	for (qw| friend foe anonymous fof eof freak fan |) {
		my $answer = $form->{"people_bonus_$_"};
		$answer = 0 if $answer !~ /^[\-+]?\d+$/;
		$users_comments_table->{"people_bonus_$_"} = ($answer == 0) ? '' : $answer;
	}

	getOtherUserParams($users_comments_table);
	$slashdb->setUser($uid, $users_comments_table);

	editComm({ uid => $uid, note => $note });
}

#################################################################
sub saveHome {
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $uid;
	my($extid, $exaid, $exsect) = '';

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

	my $exboxes = $edit_user->{exboxes};

	$exboxes =~ s/'//g;
	my @b = split m/,/, $exboxes;

	foreach (@b) {
		$_ = '' unless $form->{"exboxes_$_"};
	}

	$exboxes = sprintf "'%s',", join "','", @b;
	$exboxes =~ s/'',//g;

	for my $k (keys %{$form}) {
		if ($k =~ /^extid_(.*)/)	{ $extid  .= "'$1'," }
		if ($k =~ /^exaid_(.*)/)	{ $exaid  .= "'$1'," }
		if ($k =~ /^exsect_(.*)/)	{ $exsect .= "'$1'," }
		if ($k =~ /^exboxes_(.*)/) {
			# Only Append a box if it doesn't exist
			my $box = $1;
			$exboxes .= "'$box'," unless $exboxes =~ /'$box'/;
		}
	}

	$form->{maxstories} = 66 if $form->{maxstories} > 66;
	$form->{maxstories} = 1 if $form->{maxstories} < 1;

	my $users_index_table = {
		extid		=> checkList($extid),
		exaid		=> checkList($exaid),
		exsect		=> checkList($exsect),
		exboxes		=> checkList($exboxes),
		maxstories	=> $form->{maxstories},
		noboxes		=> ($form->{noboxes} ? 1 : 0),
		light		=> ($form->{light} ? 1 : 0),
		noicons		=> ($form->{noicons} ? 1 : 0),
		willing		=> ($form->{willing} ? 1 : 0),
		sectioncollapse	=> ($form->{sectioncollapse} ? 1 : 0),
	};

	if (defined $form->{tzcode} && defined $form->{tzformat}) {
		$users_index_table->{tzcode} = $form->{tzcode};
		$users_index_table->{dfid}   = $form->{tzformat};
		$users_index_table->{dst}    = $form->{dst};
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
	$users_index_table->{mylinks} = strip_html($form->{mylinks} || '');
	$users_index_table->{mylinks} = '' unless defined $users_index_table->{mylinks};

	# If a user is unwilling to moderate, we should cancel all points, lest
	# they be preserved when they shouldn't be.
	my $users_comments = { points => 0 };
	unless (isAnon($uid)) {
		$slashdb->setUser($uid, $users_comments)
			unless $form->{willing};
	}

	getOtherUserParams($users_index_table);
	$slashdb->setUser($uid, $users_index_table);

	editHome({ uid => $uid, note => $note });
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
	my $slashdb = getCurrentDB();

	my $readonlylist = $slashdb->getAccessList(0, 'readonly');

	slashDisplay('listReadOnly', {
		readonlylist => $readonlylist,
	});

}

#################################################################
sub listBanned {
	my $slashdb = getCurrentDB();

	my $bannedlist = $slashdb->getAccessList(0, 'isbanned');

	slashDisplay('listBanned', {
		bannedlist => $bannedlist,
	});

}

#################################################################
sub topAbusers {
	my $slashdb = getCurrentDB();

	my $topabusers = $slashdb->getTopAbusers();

	slashDisplay('topAbusers', {
		topabusers => $topabusers,
	});
}

#################################################################
sub listAbuses {
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	my $abuses = $slashdb->getAbuses($form->{key}, $form->{abuseid});

	slashDisplay('listAbuses', {
		abuseid	=> $form->{abuseid},
		abuses	=> $abuses,
	});
}

#################################################################
sub displayForm {
	my($hr) = @_;

	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	my $suadmin_flag = $user->{seclev} >= 10000 ? 1 : 0;

	my $op = $hr->{op} || $form->{op} || 'displayform';

	my $ops = {
		displayform 	=> 'loginForm',
		edithome	=> 'loginForm',
		editcomm	=> 'loginForm',
		edituser	=> 'loginForm',
		mailpasswdform 	=> 'sendPasswdForm',
		newuserform	=> 'newUserForm',
		userclose	=> 'loginForm',
		userlogin	=> 'loginForm',
		editmiscopts	=> 'loginForm',
		savemiscopts	=> 'loginForm',
		default		=> 'loginForm'
	};

	my($title, $title2, $msg1, $msg2) = ('', '', '', '');

	if ($form->{op} eq 'userclose') {
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
		newnick		=> fixNickname($form->{newusernick}),
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
# getUserAdmin - returns a block of text
# containing fields for admin users
sub getUserAdmin {
	my($id, $field, $form_flag, $seclev_field) = @_;

	my $slashdb	= getCurrentDB();
	my $user	= getCurrentUser();
	my $form	= getCurrentForm();
	my $constants	= getCurrentStatic();
	$id ||= $user->{uid};

	my($checked, $uidstruct, $readonly, $readonly_reasons);
	my($user_edit, $user_editfield, $uidlist, $iplist, $authors, $author_flag, $topabusers, $thresh_select,$section_select);
	my $user_editinfo_flag = ($form->{op} eq 'userinfo' || ! $form->{op} || $form->{userinfo} || $form->{saveuseradmin}) ? 1 : 0;
	my $authoredit_flag = ($user->{seclev} >= 10000) ? 1 : 0;
	my($banned, $banned_reason, $banned_time);
	my $sectionref = $slashdb->getDescriptions('sections-contained');
	$sectionref->{''} = getData('all_sections');

	$field ||= 'uid';
	if ($field eq 'uid') {
		$user_edit = $slashdb->getUser($id);
		$user_editfield = $user_edit->{uid};
		$checked->{expired} = $slashdb->checkExpired($user_edit->{uid}) ? ' CHECKED' : '';
		$iplist = $slashdb->getNetIDList($user_edit->{uid});
		$section_select = createSelect('section', $sectionref, $user_edit->{section}, 1);

	} elsif ($field eq 'nickname') {
		$user_edit = $slashdb->getUser($slashdb->getUserUID($id));
		$user_editfield = $user_edit->{nickname};
		$checked->{expired} = $slashdb->checkExpired($user_edit->{uid}) ? ' CHECKED' : '';
		$iplist = $slashdb->getNetIDList($user_edit->{uid});
		$section_select = createSelect('section', $sectionref, $user_edit->{section}, 1);

	} elsif ($field eq 'md5id') {
		$user_edit->{nonuid} = 1;
		$user_edit->{md5id} = $id;
		if ($form->{fieldname} and $form->{fieldname} =~ /^(ipid|subnetid)$/) {
			$uidlist = $slashdb->getUIDList($form->{fieldname}, $user_edit->{md5id});
		} else {
			$uidlist = $slashdb->getUIDList('md5id', $user_edit->{md5id});
		}

	} elsif ($field eq 'ipid') {
		$user_edit->{nonuid} = 1;
		$user_edit->{ipid} = $id;
		$user_editfield = $id;
		$uidlist = $slashdb->getUIDList('ipid', $user_edit->{ipid});

	} elsif ($field eq 'subnetid') {
		$user_edit->{nonuid} = 1;
		if ($id =~ /^(\d+\.\d+\.\d+\.)\.?\d+?/) {
			$id = $1 . ".0";
			$user_edit->{subnetid} = $id;
		} else {
			$user_edit->{subnetid} = $id;
		}

		$user_editfield = $id;
		$uidlist = $slashdb->getUIDList('subnetid', $user_edit->{subnetid});

	} else {
		$user_edit = $id ? $slashdb->getUser($id) : $user;
		$user_editfield = $user_edit->{uid};
		$iplist = $slashdb->getNetIDList($user_edit->{uid});
	}

	for my $formname ('comments', 'submit') {
		$readonly->{$formname} =
			$slashdb->checkReadOnly($formname, $user_edit) ? 
				' CHECKED' : '';

		# This is WACKY, but it should fix the problem.
		my $user_chk = $user_edit->{md5id} ? 
			{ $form->{fieldname} => $user_edit->{md5id} } : 
			$user_edit;

		if ($readonly->{$formname}) {
			my $aclinfo = $slashdb->getAccessListInfo(
                                	$formname, 'readonly', $user_chk);
			$readonly_reasons->{$formname} = $aclinfo->{reason};
		}
	}
	
	my $banref = $slashdb->getBanList(1);

	$banned = $banref->{$id} ? ' CHECKED' : '';
	my $aclinfo = $slashdb->getAccessListInfo('', 'isbanned', $user_edit);
	$banned_reason = $aclinfo->{reason};
	$banned_time = $aclinfo->{datetime};

	for (@$uidlist) {
		$uidstruct->{$_->[0]} = $slashdb->getUser($_->[0], 'nickname');
	}

	$user_edit->{author} = ($user_edit->{author} == 1) ? ' CHECKED' : '';
	if (! $user->{nonuid}) {
		my $threshcodes = $slashdb->getDescriptions('threshcode_values','',1);
		$thresh_select = createSelect('defaultpoints', $threshcodes, $user_edit->{defaultpoints}, 1);
	}

	if (!ref $iplist or scalar(@$iplist) < 1) {
		undef $iplist;
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

	return slashDisplay('getUserAdmin', {
		field			=> $field,
		useredit		=> $user_edit,
		banned 			=> $banned,
		banned_reason		=> $banned_reason,
		banned_time		=> $banned_time,
		userinfo_flag		=> $user_editinfo_flag,
		userfield		=> $user_editfield,
		iplist			=> $iplist,
		uidstruct		=> $uidstruct,
		seclev_field		=> $seclev_field,
		checked 		=> $checked,
		topabusers		=> $topabusers,
		form_flag		=> $form_flag,
		readonly		=> $readonly,
		thresh_select		=> $thresh_select,
		readonly_reasons 	=> $readonly_reasons,
		authoredit_flag 	=> $authoredit_flag,
		section_select		=> $section_select,
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
	my $slashdb = getCurrentDB();
	my $user    = getCurrentUser();
	my $form    = getCurrentForm();
	my $params = $slashdb->getDescriptions('otherusersparam');

	for my $param (keys %$params) {
		if (exists $form->{$param}) {
			# set user too for output in this request
			$data->{$param} = $user->{$param} = $form->{$param} || undef;
		}
	}
}

#################################################################
sub fixNickname {
	local($_) = @_;
	s/\s+/ /g;
	s/[^ a-zA-Z0-9\$_.+!*'(),-]+//g;
	$_ = substr($_, 0, 20);
	return $_;
}

createEnvironment();
main();

1;

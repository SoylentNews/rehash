#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Date::Manip;
use Slash;
use Slash::Display;
use Slash::Utility;

#################################################################
sub main {
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	my $op = $form->{op};
	my $uid = $user->{uid};

	if ($op eq 'userlogin' && !$user->{is_anon}) {
		my $refer = $form->{returnto} || $constants->{rootdir};
		redirect($refer);
		return;
	} elsif ($op eq 'saveuser') {
		my $note = saveUser($form->{uid});
		redirect($ENV{SCRIPT_NAME} . "?op=edituser&note=$note");
		return;
	}

	my $note = [ split /\n+/, $form->{note} ] if defined $form->{note};
	header("$constants->{sitename} Users");  # this needs to be in a template
	print getMessage('note', { note => $note } ) if defined $note;

	if (!$user->{is_anon} && $op ne 'userclose') {
		print createMenu('users');
	}

	# and now the carnage begins
	if ($op eq 'newuser') {
		newUser();

	} elsif ($op eq 'newuseradmin' and $user->{seclev} >= 10000) {
		newUserForm();

	} elsif ($form->{authoredit} && $user->{seclev} >= 10000) {
		editUser($form->{authoruid});

	} elsif ($form->{useredit} && $user->{seclev} >= 10000) {
		if ($form->{userfield_flag} eq 'nickname') {
			editUser($slashdb->getUserUID($form->{userfield}));
		} else {
			editUser($form->{userfield});
		}

	} elsif ($op eq 'edituser') {
		# the users_prefs table
		if (!$user->{is_anon}) {
			editUser($user->{uid});
		} else {
			displayForm(); 
		}

	} elsif ($op eq 'edithome' || $op eq 'preferences') {
		# also known as the user_index table
		if (!$user->{is_anon}) {
			editHome($user->{uid});
		} else {
			displayForm(); 
		}

	} elsif ($op eq 'editcomm') {
		# also known as the user_comments table
		if (!$user->{is_anon}) {
			editComm($user->{uid});
		} else {
			displayForm(); 
		}

	} elsif ($op eq 'userinfo' || !$op) {
		if ($form->{nick}) {
			userInfo($slashdb->getUserUID($form->{nick}), $form->{nick});
		} elsif ($user->{is_anon}) {
			displayForm();
		} else {
			userInfo($user->{uid}, $user->{nickname});
		}

	} elsif ($op eq 'savecomm') {
		saveComm($user->{uid});
		userInfo($user->{uid}, $user->{nickname});

	} elsif ($op eq 'savehome') {
		saveHome($user->{uid});
		userInfo($user->{uid}, $user->{nickname});

	} elsif ($op eq 'sendpw') {
		mailPassword($user->{uid});

	} elsif ($op eq 'mailpasswd') {
		mailPassword($slashdb->getUserUID($form->{unickname}));

	} elsif ($op eq 'suedituser' && $user->{seclev} > 100) {
		editUser($slashdb->getUserUID($form->{name}));

	} elsif ($op eq 'susaveuser' && $user->{seclev} > 100) {
		saveUser($form->{uid}); 

	} elsif ($op eq 'sudeluser' && $user->{seclev} > 100) {
		delUser($form->{uid});

	} elsif ($op eq 'userclose') {
		print 'ok bubbye now.';  # why is this here?
		displayForm();

	} elsif ($op eq 'userlogin' && !$user->{is_anon}) {
		userInfo($user->{uid}, $user->{nickname});

	} elsif ($op eq 'preview') {
		previewSlashbox();

	} elsif (!$user->{is_anon}) {
		userInfo($slashdb->getUserUID($form->{nick}), $form->{nick});

	} else {
		displayForm();
	}

	# miniAdminMenu() if $user->{seclev} > 100;
	writeLog($user->{nickname});

	footer();
}


#################################################################
sub checkList {
	my $string = shift;
	$string = substr($string, 0, -1);

	$string =~ s/[^\w,-]//g;
	my @e = split m/,/, $string;
	$string = sprintf "'%s'", join "','", @e;

	if (length($string) > 254) {
		print getMessage('checklist_msg');
		$string = substr($string, 0, 255);
		$string =~ s/,'??\w*?$//g;
	} elsif (length $string < 3) {
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
	my $is_editable = $user->{seclev} > 999;

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
sub miniAdminMenu {
	slashDisplay('miniAdminMenu');
}

#################################################################
sub newUserForm {
	slashDisplay('newUserForm')
}

#################################################################
sub newUser {
	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $title;

	# Check if User Exists
	$form->{newuser} = fixNickname($form->{newuser});
	(my $matchname = lc $form->{newuser}) =~ s/[^a-zA-Z0-9]//g;

	if ($matchname ne '' && $form->{newuser} ne '' && $form->{email} =~ /\@/) {
		my $uid;
		my $rootdir = getCurrentStatic('rootdir','value');
		if ($uid = $slashdb->createUser($matchname, $form->{email}, $form->{newuser})) {
			$title = getTitle('newUser_title');

			$form->{pubkey} = strip_html($form->{pubkey}, 1);
			print getMessage('newuser_msg', { title => $title, uid => $uid });
			mailPassword($uid);

			return;
		}
	} 
	# Duplicate User
	displayForm();
}


#################################################################
sub mailPassword {
	my($uid) = @_;

	my $slashdb = getCurrentDB();

	my $user_email = $slashdb->getUser($uid, ['nickname','realemail']);

	unless ($uid) {
		print getMessage('mailpasswd_notmailed_msg');
		return;
	}

	my $newpasswd = $slashdb->getNewPasswd($uid);
	my $tempnick = fixparam($user_email->{nickname});

	my $emailtitle = getTitle('mailPassword_email_title', {
		nickname	=> $user_email->{nickname}
	}, 1);

	my $msg = getMessage('mailpasswd_msg', {
		newpasswd	=> $newpasswd,
		tempnick	=> $tempnick
	}, 1);

	sendEmail($user_email->{realemail}, $emailtitle, $msg) if $user_email->{nickname};
	print getMessage('mailpasswd_mailed_msg', { name => $user_email->{nickname} });
}

#################################################################
sub userInfo {
	my($uid, $orignick) = @_;
	my $nick = strip_literal($orignick);

	if (! defined $uid) {
		print getMessage('userinfo_nicknf_msg', { nick => $nick });
		return;
	}

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	my $admin_block = '';

	my $userbio = $slashdb->getUser($uid);

	my $admin_flag = ($user->{seclev} >= 100) ? 1 : 0;

	$admin_block = getUserAdmin($userbio->{uid}, 1, 0) if $admin_flag;

	my($title, $commentstruct, $points, $lastgranted, $nickmatch_flag);
	my($mod_flag, $karma_flag, $n) = (0, 0, 0);

	$form->{min} = 0 unless $form->{min};

 	$karma_flag = 1 if $userbio->{seclev} || $userbio->{uid} == $uid;

	my $public_key = $userbio->{pubkey};
	$public_key = strip_html($public_key, 1) if $public_key;

#	if ($userbio->{nickname} eq $orignick) {
#	wouldn't this be better?
# slower comparison (and we already have both) -Brian
	if ($userbio->{uid} == $user->{uid}) {
		$nickmatch_flag = 1;
		$points = $userbio->{points};
		if ($points) {
			$lastgranted = $slashdb->getUser($uid, 'lastgranted');
			if ($lastgranted) {
				$lastgranted = timeCalc(
					DateCalc($lastgranted,
					'+ ' . ($constants->{stir}+1) . ' days'),
					'%Y-%m-%d'
				);
			}
		}
		$mod_flag = 1 if $userbio->{uid} == $uid && $points > 0;
		$title = getTitle('userInfo_main_title', { nick => $nick, uid => $uid });
	} else {
		$title = getTitle('userInfo_user_title', { nick => $nick, uid => $uid });
	}

	my $comments = $slashdb->getCommentsByUID($uid, $form->{min}, $userbio);

	for (@$comments) {
		my($pid, $sid, $cid, $subj, $cdate, $pts) = @$_;

		my $replies = $slashdb->countCommentsBySidPid($sid, $cid);

		# This is ok, since with all luck we will not be hitting the DB
		my $story = $slashdb->getStory($sid);
		my $question = $slashdb->getPollQuestion($sid, 'question');

		push @$commentstruct, {
			pid 		=> $pid,
			sid 		=> $sid,
			cid 		=> $cid,
			subj		=> $subj,
			cdate		=> $cdate,
			pts		=> $pts,
			story		=> $story,
			question	=> $question,
			replies		=> $replies,
		};
	}

	slashDisplay('userInfo', {
		title			=> $title,
		uid			=> $uid,
		nick			=> $nick,
		fakeemail		=> $userbio->{fakeemail},
		homepage		=> $userbio->{homepage},
		bio			=> $userbio->{bio},
		points			=> $points,
		lastgranted		=> $lastgranted,
		public_key		=> $public_key,
		commentstruct		=> $commentstruct || [],
		nickmatch_flag		=> $nickmatch_flag,
		mod_flag		=> $mod_flag,
		karma_flag		=> $karma_flag,
		admin_block		=> $admin_block,
		admin_flag 		=> $admin_flag,
	});
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
sub editUser {
	my($uid) = @_;

	my $slashdb = getCurrentDB();
	my $user_edit = $slashdb->getUser($uid);
	my $user = getCurrentUser();

	my($author_select, $admin_block);

	$user_edit->{homepage} ||= "http://";

	return if isAnon($user_edit->{uid});

	my $title = getTitle('editUser_title', { user_edit => $user_edit });

	my $tempnick = fixparam($user_edit->{nickname});
	my $temppass = fixparam($user_edit->{passwd});
 
	my $description = $slashdb->getDescriptions('maillist');
	my $maillist = createSelect('maillist', $description, $user_edit->{maillist}, 1);

	my $session = $slashdb->getDescriptions('session_login');
	my $session_select = createSelect('session_login', $session, $user_edit->{session_login}, 1);

	my $admin_flag = ($user->{seclev} >= 100) ? 1 : 0; 
	$admin_block = getUserAdmin($user_edit->{uid}, 0, 1) if $admin_flag;

	slashDisplay('editUser', { 
		user_edit 		=> $user_edit, 
		admin_flag		=> $admin_flag,
		author_select		=> $author_select,
		title			=> $title,
		editkey 		=> editKey($user_edit->{uid}),
		maillist 		=> $maillist,
		session 		=> $session_select,
		admin_block		=> $admin_block
	});
}

#################################################################
sub tildeEd {
	my($extid, $exsect, $exaid, $exboxes, $userspace) = @_;
	
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my($aidref, $tidref, $sectionref, $section_descref, $tilde_ed, $tilded_msg_box);

	# users_tilded_title
	my $title = getTitle('tildeEd_title');

	# Customizable Authors Thingee
	my $aids = $slashdb->getAuthorNames();
	my $n = 0;
	for my $aid (@$aids) {
		$aidref->{$aid}{checked} = ($exaid =~ /'$aid'/) ? ' CHECKED' : '';
	}

	my $topics = $slashdb->getDescriptions('topics');
	while (my($tid, $alttext) = each %$topics) {
		$tidref->{$tid}{checked} = ($extid =~ /'$tid'/) ? ' CHECKED' : '';
		$tidref->{$tid}{alttext} = $alttext;
	}

	my $sections = $slashdb->getDescriptions('sections');
	while (my($section,$title) = each %$sections) {
		$sectionref->{$section}{checked} = ($exsect =~ /'$section'/) ? ' CHECKED' : '';
		$sectionref->{$section}{title} = $title;
	}

	my $customize_title = getTitle('tildeEd_customize_title');

	my $tilded_customize_msg = getMessage('users_tilded_customize_msg',
		{ userspace => $userspace });

	my $sections_description = $slashdb->getSectionBlocks();

	$customize_title = getTitle('tildeEd_customize_title');  # repeated from above?

	for (@$sections_description) {
		my($bid, $title, $boldflag) = @$_;

		$section_descref->{$bid}{checked} = ($exboxes =~ /'$bid'/) ? ' CHECKED' : '';
		$section_descref->{$bid}{boldflag} = $boldflag > 0;
		$title =~ s/<(.*?)>//g;
		$section_descref->{$bid}{title} = $title;
	}

	my $tilded_box_msg = getMessage('tilded_box_msg');
	$tilde_ed = slashDisplay('tildeEd', { 
		title			=> $title,
		tilded_box_msg		=> $tilded_box_msg,
		aidref			=> $aidref,
		tidref			=> $tidref,
		sectionref		=> $sectionref,
		section_descref		=> $section_descref,
		userspace		=> $userspace,
		customize_title		=> $customize_title,
	}, 1);

	return($tilde_ed);
}

#################################################################
sub editHome {
	my($uid) = @_;

	my $slashdb = getCurrentDB();
	return if isAnon(getCurrentUser('uid'));

	my $user_edit = $slashdb->getUser($uid);
	my $title = getTitle('editHome_title'); 

	my $formats;
	$formats = $slashdb->getDescriptions('dateformats');
	my $tzformat_select = createSelect('tzformat', $formats, $user_edit->{dfid}, 1);

	$formats = $slashdb->getDescriptions('tzcodes');
	$formats = { map { ($_ => uc($_)) } keys %$formats };
	my $tzcode_select = createSelect('tzcode', $formats, $user_edit->{tzcode}, 1);

	my $l_check = $user_edit->{light}	? ' CHECKED' : '';
	my $b_check = $user_edit->{noboxes}	? ' CHECKED' : '';
	my $i_check = $user_edit->{noicons}	? ' CHECKED' : '';
	my $w_check = $user_edit->{willing}	? ' CHECKED' : '';

	my $tilde_ed = tildeEd(
		$user_edit->{extid}, $user_edit->{exsect},
		$user_edit->{exaid}, $user_edit->{exboxes}, $user_edit->{mylinks}
	);

	slashDisplay('editHome', {
		title			=> $title,
		user_edit		=> $user_edit,
		tzformat_select		=> $tzformat_select,
		tzcode_select		=> $tzcode_select,
		l_check			=> $l_check,			
		b_check			=> $b_check,			
		i_check			=> $i_check,			
		w_check			=> $w_check,			
		tilde_ed		=> $tilde_ed
	});
}

#################################################################
sub editComm {
	my($uid) = @_;

	my $slashdb = getCurrentDB();
	my($formats, $commentmodes_select, $commentsort_select,
		$uthreshold_select, $highlightthresh_select, $posttype_select);

	my $user_edit = $slashdb->getUser($uid);
	my $title = getTitle('editComm_title');

	$formats = $slashdb->getDescriptions('commentmodes');
	$commentmodes_select = createSelect('umode', $formats, $user_edit->{mode}, 1);

	$formats = $slashdb->getDescriptions('sortcodes');
	$commentsort_select = createSelect('commentsort', $formats, $user_edit->{commentsort}, 1);

	$formats = $slashdb->getDescriptions('threshcodes');
	$uthreshold_select = createSelect('uthreshold', $formats, $user_edit->{threshold}, 1);

	$formats = $slashdb->getDescriptions('threshcodes');
	$highlightthresh_select = createSelect('highlightthresh', $formats, $user_edit->{highlightthresh}, 1);

	my $h_check = $user_edit->{hardthresh}	? ' CHECKED' : '';
	my $r_check = $user_edit->{reparent}	? ' CHECKED' : '';
	my $n_check = $user_edit->{noscores}	? ' CHECKED' : '';
	my $s_check = $user_edit->{nosigs}	? ' CHECKED' : '';

	$formats = $slashdb->getDescriptions('postmodes');
	$posttype_select = createSelect('posttype', $formats, $user_edit->{posttype}, 1);

	slashDisplay('editComm', {
		title			=> $title,
		user_edit		=> $user_edit,
		h_check			=> $h_check,			
		r_check			=> $r_check,			
		n_check			=> $n_check,			
		s_check			=> $s_check,			
		commentmodes_select	=> $commentmodes_select,
		commentsort_select	=> $commentsort_select,
		highlightthresh_select	=> $highlightthresh_select,
		uthreshold_select	=> $uthreshold_select,
		posttype_select		=> $posttype_select,
	});
}

#################################################################
sub saveUser {
	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	# we need to come up with a new seclev system. What seclev
	# should allow an admin user to save another user on 
	# the system?  -- pat (?)
	# the highest one.  -- pudge
	my $uid = $user->{seclev} >= 100 ? shift : $user->{uid};
	my $user_email  = $slashdb->getUser($uid, ['nickname', 'realemail']);
	my ($note, $author_flag);

	$user_email->{nickname} = substr($user_email->{nickname}, 0, 20);
	return if isAnon($uid);

	$note = getMessage('savenickname_msg', { nickname => $user_email->{nickname} }, 1);

	if (!$user_email->{nickname}) {
		$note .= getMessage('cookiemsg', 0, 1);
	}

	# strip_mode _after_ fitting sig into schema, 120 chars
	$form->{sig}	 	= strip_html(substr($form->{sig}, 0, 120));
	$form->{fakeemail} 	= chopEntity(strip_attribute($form->{fakeemail}), 50);
	$form->{homepage}	= '' if $form->{homepage} eq 'http://';
	$form->{homepage}	= fixurl($form->{homepage});
	$author_flag		= $form->{author} ? 1 : 0;

	# for the users table
	my $users_table = {
		sig		=> $form->{sig},
		homepage	=> $form->{homepage},
		fakeemail	=> $form->{fakeemail},
		maillist	=> $form->{maillist},
		realname	=> $form->{realname},
		bio		=> $form->{bio},
		pubkey		=> $form->{pubkey},
		copy		=> $form->{copy},
		quote		=> $form->{quote},
		session_login	=> $form->{session_login},
	};

	if ($user->{seclev} >= 100) {
		$users_table->{seclev} = $form->{seclev}; 
		$users_table->{author} = $author_flag; 
	}

	if ($user_email->{realemail} ne $form->{realemail}) {
		$users_table->{realemail} = chopEntity(strip_attribute($form->{realemail}), 50);

		$note .= getMessage('changeemail_msg', { realemail => $user_email->{realemail} }, 1);

		my $saveuser_emailtitle = getTitle('saveUser_email_title', { nickname => $user_email->{nickname} }, 1);
		my $saveuser_email_msg = getMessage('saveuser_email_msg', { nickname => $user_email->{nickname} }, 1);
		sendEmail($user_email->{realemail}, $saveuser_emailtitle, $saveuser_email_msg);
	}

	delete $users_table->{passwd};
	if ($form->{pass1} eq $form->{pass2} && length($form->{pass1}) > 5) {
		$note .= getMessage('saveuser_passchanged_msg');

		$users_table->{passwd} = $form->{pass1};
		setCookie('user', bakeUserCookie($uid, encryptPassword($users_table->{passwd})));

	} elsif ($form->{pass1} ne $form->{pass2}) {
		$note .= getMessage('saveuser_passnomatch_msg');

	} elsif (length $form->{pass1} < 6 && $form->{pass1}) {
		$note .= getMessage('saveuser_passtooshort_msg');
	}

	$slashdb->setUser($uid, $users_table);

	return fixparam($note);
}

#################################################################
sub saveComm {
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	my $uid  = $user->{seclev} ? shift : $user->{uid};
	my $name = $user->{seclev} && $form->{name} ? $form->{name} : $user->{nickname};

	$name = substr($name, 0, 20);
	return if isAnon($uid);

	my $savename = getMessage('savename_msg', { name => $name });
	print $savename;

	if (isAnon($uid) || !$name) {
		print getMessage('cookiemsg');
	}

	# Take care of the lists
	# Enforce Ranges for variables that need it
	$form->{commentlimit} = 0 if $form->{commentlimit} < 1;
	$form->{commentspill} = 0 if $form->{commentspill} < 1;

	# for users_comments
	my $users_comments_table = {
		clbig		=> $form->{clbig},
		clsmall		=> $form->{clsmall},
		mode		=> $form->{umode},
		posttype	=> $form->{posttype},
		commentsort	=> $form->{commentsort},
		threshold	=> $form->{uthreshold},
		commentlimit	=> $form->{commentlimit},
		commentspill	=> $form->{commentspill},
		maxcommentsize	=> $form->{maxcommentsize},
		highlightthresh	=> $form->{highlightthresh},
		nosigs		=> ($form->{nosigs}     ? 1 : 0),
		reparent	=> ($form->{reparent}   ? 1 : 0),
		noscores	=> ($form->{noscores}   ? 1 : 0),
		hardthresh	=> ($form->{hardthresh} ? 1 : 0),
	};

	# Update users with the $users_comments_table hash ref 
	$slashdb->setUser($uid, $users_comments_table);
}

#################################################################
sub saveHome {
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	my $uid  = $user->{seclev} ? shift : $user->{uid};
	my $name = $user->{seclev} && $form->{name} ? $form->{name} : $user->{nickname};

	$name = substr($name, 0, 20);
	return if isAnon($uid);

	# users_cookiemsg
	if (isAnon($uid) || !$name) {
		my $cookiemsg = getMessage('cookiemsg');
		print $cookiemsg;
	}

	my($extid, $exaid, $exsect) = '';
	my $exboxes = $slashdb->getUser($uid, ['exboxes']);

	$exboxes =~ s/'//g;
	my @b = split m/,/, $exboxes;

	foreach (@b) {
		$_ = '' unless $form->{"exboxes_$_"};
	}

	$exboxes = sprintf "'%s',", join "','", @b;
	$exboxes =~ s/'',//g;

	foreach my $k (keys %{$form}) {
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
	};
	
	if (defined $form->{tzcode} && defined $form->{tzformat}) {
		$users_index_table->{tzcode} = $form->{tzcode};
		$users_index_table->{dfid}   = $form->{tzformat};
	}

	$users_index_table->{mylinks} = $form->{mylinks} if $form->{mylinks};

	# If a user is unwilling to moderate, we should cancel all points, lest
	# they be preserved when they shouldn't be.
	my $users_comments = { points => 0 };
	unless (isAnon($uid)) {
		$slashdb->setUser($uid, $users_comments)
			unless $form->{willing};
	}

	# Update users with the $users_index_table thing we've been playing with for this whole damn sub
	$slashdb->setUser($uid, $users_index_table);
}

#################################################################
sub displayForm {
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	my($title, $title2);

	$title = $form->{unickname}
		? getTitle('displayForm_err_title')
		: getTitle('displayForm_title');

	$form->{unickname} ||= $form->{newuser};

	if ($form->{newuser}) {
		$title2 = getTitle('displayForm_dup_title');
	} else {
		$title2 = getTitle('displayForm_new_title');
	}

	my $msg = getMessage('dispform_new_msg_1');
	$msg .= getMessage('dispform_new_msg_2') if ! $form->{newuser};

	slashDisplay('displayForm', {
		newnick		=> fixNickname($form->{newuser}),
		title 		=> $title,
		title2 		=> $title2,
		msg 		=> $msg
	});
}

#################################################################
# this groups all the messages together in
# one template, called "users-messages"
sub getMessage {
	my($value, $hashref, $nocomm) = @_;
	$hashref ||= {};
	$hashref->{value} = $value;
	return slashDisplay('messages', $hashref,
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
	my($uid, $form_flag, $seclev_field) = @_;

	my $slashdb	= getCurrentDB();
	my $user	= getCurrentUser();
	my $form	= getCurrentForm();	

	my $edituser = $slashdb->getUser($uid);

	my($uid_checked, $nickname_checked) = ('','');

	if ($form->{userfield_flag} eq 'userid') {
		$uid_checked = ' CHECKED';
	} else {
		$nickname_checked = ' CHECKED';
	}		

	my $author_select;
	my $author_flag = ($edituser->{author} == 1) ? ' CHECKED' : ''; 
	my $authoredit_flag = ($user->{seclev} >= 10000) ? 1 : 0; 

	my $authors = $slashdb->getDescriptions('authors');

	$author_select = createSelect('authoruid', $authors, $uid, 1) if $authoredit_flag;
	$author_select =~ s/\s{2,}//g;

	return slashDisplay('getUserAdmin', { 
		edituser		=> $edituser,
		seclev_field		=> $seclev_field,
		uid_checked 		=> $uid_checked,
		nickname_checked 	=> $nickname_checked,
		author_select		=> $author_select,
		author_flag 		=> $author_flag, 
		form_flag		=> $form_flag,
		authoredit_flag 	=> $authoredit_flag }, 
		{ Return 		=> 1 }
	);
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

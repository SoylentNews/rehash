#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
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
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();

	my $post_ok   = $user->{state}{post};
	my $user_ok   = !$user->{is_anon};

	# possible value of "op" parameter in form
	my %ops = (
		userlogin	=> [ 1,				\&userLogin	],
		changeprefs	=> [ $user_ok,			\&changePrefs	],
		saveprefs	=> [ $post_ok && $user_ok,	\&savePrefs	],
	);

	my $op = $form->{'op'};
	if (!$op || !exists $ops{$op} || !$ops{$op}[ALLOWED]) {
		$op = 'userlogin';
	}

	# you are logged in, just go to your prefs (you were authenticated
	# in Slash::Apache::User, before you got here)
	if ($op eq 'userlogin' && $user_ok) {
		redirect(cleanRedirectUrl($form->{returnto}));
		return;
	}

	$ops{$op}[FUNCTION]->($slashdb, $constants, $user, $form);
	writeLog($user->{nickname});
}


#################################################################
sub changePrefs {
	my($slashdb, $constants, $user, $form) = @_;

	# I am not going to add admin-modification right now,
	# because they way it is currently done sucks.  we should
	# handle that in one place only, not duplicate the same
	# damned code everywhere, and i will not be a party to
	# such madness.

	header(getData('prefs'));
	slashDisplay('changePasswd');
	footer();
}


#################################################################
sub savePrefs {
	my($slashdb, $constants, $user, $form) = @_;

	my $error = 0;
	my $note;

	my $changepass = 0;
	if ($form->{pass1} || $form->{pass2} || length($form->{pass1}) || length($form->{pass2})) {
		$changepass = 1;
	}

	if ($changepass) {
		if ($form->{pass1} ne $form->{pass2}) {
			$note .= getData('passnomatch');
			$error++;
		}

		if (!$form->{pass1} || length $form->{pass1} < 6) {
			$note .= getData('passtooshort');
			$error++;
		}

		if ($form->{pass1} && length $form->{pass1} >= 20) {
			$note .= getData('passtoolong');
			$error++;
		}

		my $return_uid = $slashdb->getUserAuthenticate($uid, $form->{oldpass}, 1);
		if (!$return_uid || $return_uid != $uid) {
			$note .= getData('oldpassbad');
			$error++;
		}
	}

	if ($error) {
		$form->{note} = $note;
	} else {
		my $user_save = {};
		$user_save->{passwd} = $form->{pass1} if $changepass;
		$user_save->{session_login}   = $form->{session_login};
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

		getOtherUserParams($user_save);
		$slashdb->setUser($user->{uid}, $user_save) ;
		$form->{note} = getData('passchanged');

		my $value  = $slashdb->getLogToken($uid, 1);
		my $cookie = bakeUserCookie($uid, $slashdb->getLogToken($uid, 1));
		setCookie('user', $cookie, $user_save->{session_login});
	}
	changePrefs(@_);
}

createEnvironment();
main();
1;

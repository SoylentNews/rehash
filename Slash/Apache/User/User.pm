# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Apache::User;

use strict;
use utf8;
use Digest::MD5 'md5_hex';
use Time::HiRes;
use Apache2::Cookie;
use Apache2::Const -compile => qw( :http );
use Apache2::Module;
use Apache2::Request;
use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Slash::Apache ();
use Slash::Display;
use Slash::Utility;
use URI ();
use vars qw($VERSION @ISA @QUOTES $USER_MATCH $request_start_time);

$VERSION   	= '2.003000';  # v2.3.0


# BENDER: Oh, so, just 'cause a robot wants to kill humans
# that makes him a radical?
my @directives = (
	{ name      => 'SlashEnableENV',
		errmsg      => 'Takes a flag that is either on or off (off by default)',
		args_how    => 'FLAG',
		req_override => 'RSRC_CONF'
	},
	{ name      => 'SlashAuthAll',
		errmsg      => 'Takes a flag that is either on or off (off by default)',
		args_how    => 'FLAG',
		req_override => 'RSRC_CONF'
	}

);

Apache2::Module::add(__PACKAGE__, \@directives);


$USER_MATCH = $Slash::Apache::USER_MATCH;

sub SlashEnableENV ($$$) {
	my($cfg, $params, $flag) = @_;
	$cfg->{env} = $flag;
}

sub SlashAuthAll ($$$) {
	my($cfg, $params, $flag) = @_;
	$cfg->{auth} = $flag;
}

# see below for more info on this var
my $srand_called;

# handler method
sub handler {
	my($r) = @_;

	return Apache2::Const::DECLINED unless !$r->main;

	my $uri = $r->uri;

	# Exclude any URL that matches the environment variable regex
	if ($ENV{SLASH_EXCLUDE_URL_USERHANDLER}) {
		return Apache2::Const::OK if $uri =~ /$ENV{SLASH_EXCLUDE_URL_USERHANDLER}/;
	}

	$request_start_time ||= Time::HiRes::time;

	my $cfg = Apache2::Module::get_config(__PACKAGE__, $r->server, $r->per_dir_config);
	my $dbcfg = Apache2::Module::get_config('Slash::Apache', $r->server, $r->per_dir_config);
	my $constants = getCurrentStatic();

	# Ok, this will make it so that we can reliably use Apache->request
	Apache2::RequestUtil->request($r);

	my $slashdb = $dbcfg->{slashdb};
	my $apr = Apache2::Request->new($r);
	my $gSkin = getCurrentSkin();
	my $method = $r->method;

	my $reader_user = $slashdb->getDB('reader');
	my $reader = getObject('Slash::DB', { virtual_user => $reader_user });

	my $version_code = "rehash";
	$version_code .= " $Slash::VERSION";
	if ($constants->{cvs_tag_currentcode_emit}
		&& $constants->{cvs_tag_currentcode}
		&& $constants->{cvs_tag_currentcode} =~ /_(\d+)$/) {
		$version_code .= sprintf("%03d", $1);
	}
	$r->headers_out->set('X-Powered-By', $version_code);

	add_random_quote($r);

	# let pass unless / or .pl
	#
	# MC: This seems broken; if we don't deal with cookies
	# on every page, we get inconsistent behavior *at best*
	#
	#if ($gSkin->{rootdir}) {
	#	my $path = URI->new($gSkin->{rootdir})->path;
	#	$uri =~ s/^\Q$path//;
	#}

	my $is_ssl = Slash::Apache::ConnectionIsSSL();

	$slashdb->sqlConnect;
	$reader->sqlConnect;


	my $form = filter_params($apr);

	@{$form}{keys  %{$constants->{form_override}}} =
		values %{$constants->{form_override}};

	my $cookies = Apache2::Cookie->fetch;

	# So we are either going to pick the user up from
	# the form, a cookie, or they will be anonymous
	my $uid;
	my $op = $form->{op} || '';

	# we know this is not the current user yet, but we only
	# want to save one bit of information there, and retrieve it
	# later -- pudge
	my $user_temp = getCurrentUser();
	$user_temp->{state}{login_public}        = 'no';
	$user_temp->{state}{login_temp}          = 'no';
	$user_temp->{state}{login_failed_reason} = 0;

	if ((($op eq 'userlogin' || $form->{rlogin}) && length($form->{upasswd}) > 1)
		||
	     ($op eq 'userlogin' && $form->{logtoken})
	) {
		# this is only allowed to be set by user on login attempt
		$user_temp->{state}{login_temp} = 'yes' if $form->{login_temp} eq 'yes';

		my $tmpuid = $slashdb->getUserUID($form->{unickname});
		my $passwd = $form->{upasswd};
		my $logtoken;
		if (!$tmpuid && $form->{logtoken}) {
			($tmpuid, $passwd) = eatUserCookie($form->{logtoken});
			$logtoken = $form->{logtoken};
		}

		# Don't allow login attempts from IPIDs that have been
		# marked as "nopost" or "nopostanon" -- those are mostly
		# open proxies.	Check both the ipid and the subnetid (we
		# can't use values in $user because that doesn't get set
		# up until prepareUser is called, later in this function).
		my $read_only = 0;
		my $hostip = $r->connection->remote_ip;
		my $srcids = get_srcids({ ip => $hostip });
		$read_only = 1 if $reader->checkAL2($srcids,
			[qw( nopost nopostanon openproxy )]);

		my $newpass;
		if ($read_only || !$tmpuid) {
			# We know we can't log in, don't even try.
			# We should provide a way here for the loginForm template
			# to emit a more informative error message than its
			# standard "Danger, Will Robinson".  That error assumes
			# that if a unickname is specified, the only way a login
			# could fail is if the unickname doesn't exist (!$tmpuid)
			# or the password is wrong.  That's no longer the case
			# since $read_only can bring us here..  Maybe set a flag
			# in $user->{state} that the template reads? - Jamie
			$uid = 0;
			$user_temp->{state}{login_failed_reason} = $read_only ? 'nopost' : 1;
		} else {
			($uid, $newpass) = userLogin($tmpuid, $passwd, $logtoken);
			$slashdb->clearAccountVerifyNeededFlags($uid) if $uid;
		}

		# here we want to redirect only if the user has requested via
		# GET, and the user has logged in successfully

		if ($method eq 'GET' && $uid && ! isAnon($uid)) {
			$form->{returnto} =~ s/%3D/=/;
			$form->{returnto} =~ s/%3F/?/;
			my $absolutedir = $is_ssl
				? $gSkin->{absolutedir_secure}
				: $gSkin->{absolutedir};
			$form->{returnto} = url2abs(($newpass
				? "$gSkin->{rootdir}/login.pl?op=changeprefs" .
					# XXX This "note" field is ignored now...
					# right?  - Jamie 2002/09/17
					# YYY I made it so it is just a silly code,
					# so it can be picked up by the form, and
					# actual text is not passed in.
					# For now, the code is just this text; later,
					# I can change it to something else.
					# -- pudge
				  "&amp;note=Please+change+your+password+now!&amp;oldpass=" .
				  fixparam($form->{upasswd})
				: $form->{returnto}
					? $form->{returnto}
					: $uri),
				$absolutedir
			);
			# not working ... move out into users.pl and index.pl
			# I may know why this is the case, we may need
			# to send a custom errormessage. -Brian
#			$r->err_headers_out->set('Location' => $newurl);
#			return REDIRECT;
		}

	} elsif ($form->{logtoken} || ($cookies->{user} && $cookies->{user}->value)) {
		# $form->{logtoken} overrides the cookie under some circumstances,
		# but is NOT used here to log user in with a cookie, it is only for
		# one-shot requests, unless coupled with userlogin op, as above
		my $logtoken = '';
		if ($form->{logtoken}) {
			# only allow this for certain pages/ops etc.
			# and that page must doublecheck for permissions etc., still,
			# redirecting user back to a main page upon failure
			# ... it would be nice to have a way to set this in a table
			# or vars or somesuch, but how?  is there danger in
			# opening it up to everything instead of closing it off?
			# NOTE: this is only for "public" logtokens that are
			# separate from regular login logtokens right now;
			# it can be changed if necessary, it just happens that
			# way, so we use it to set login_public
			if (
				($constants->{rss_allow_index} && $form->{content_type} =~ $constants->{feed_types} && $uri =~ m{^/index\.pl$})
					||
				($constants->{plugin}{ScheduleShifts} && $uri =~ m{^/shifts\.pl$})
					||
				# hmmm ... journal.pl no work, because can be called as /journal/
				($constants->{journal_rdfitemdesc_html}
					&& $form->{content_type} =~ $constants->{feed_types}
					&& $uri =~ m{\b(?:journal|messages|inbox)\b}
				)
			) {
				$logtoken = $form->{logtoken};
				$user_temp->{state}{login_public} = 'yes';
			} else {
				delete $form->{logtoken};
			}
		}

		my($tmpuid, $value) = eatUserCookie(($cookies->{slashdot_user} && $cookies->{slashdot_user}->value)
			|| $logtoken
			|| ($cookies->{user} && $cookies->{user}->value)
		);
		my $cookvalue;
		if ($tmpuid && $tmpuid > 0 && !isAnon($tmpuid)) {
			# if it's not a temp logtoken it's a regular logtoken
			my $kind = $user_temp->{state}{login_public} eq 'yes' ? 4 : 3;
			($uid, $cookvalue) =
				$slashdb->getUserAuthenticate($tmpuid, $value, $kind, 1);
		}

		# we don't want to set a cookie etc. if user is using a $logtoken,
		# as that is just for RSS etc.
		if (!$logtoken) {
			if ($uid && $op ne 'userclose') {
				# set cookie every time, in case session_login
				# value changes, or time is almost expired on
				# saved cookie, or password changes, or ...

				# can't set it every time, it upsets people.
				# we need to set it only if password or
				# session_login changes. -- pudge

				# if existing cookie is not a logtoken cookie, make it one
				if ($value !~ m|^[A-Za-z0-9/+]{22}$|) {
	 				setCookie('user', bakeUserCookie($uid, $cookvalue),
	 					$slashdb->getUser($uid, 'session_login')
	 				);

				# always set cookie for "temp" logins, on every request
		 		} elsif ($user_temp->{state}{login_temp} eq 'yes') {
 					setCookie('user', bakeUserCookie($uid, $cookvalue), 2);
	 			}

			# blank out user cookie and make anon if user wants
			# to log out, or uses a bad cookie
			} elsif (dbAvailable()) {
				if ($op eq 'userclose' && $uid) {
					$slashdb->deleteLogToken($uid);
				}

				$uid = $constants->{anonymous_coward_uid};
				#delete $cookies->{user};

				# if you are here, chances are your cookie is bad,
				# so we blank it out for you.  you're welcome.
				setCookie('user', '');
			}
		}

	} elsif ($op eq 'userclose') {
		#delete $cookies->{user};
		setCookie('user', '');
	}

	# can't use after login
	delete $form->{login_temp};

	# This has happened to me a couple of times.
	#delete $cookies->{user} if $cookies->{user} && !$cookies->{user}->value;

	if (!$uid) {
		if ($gSkin && $gSkin->{ac_uid}) {
			$uid = $gSkin->{ac_uid};
		} else {
			$uid = $constants->{anonymous_coward_uid};
		}
	}
#print STDERR scalar(localtime) . " $$ User handler uid=$uid gSkin->skid=$gSkin->{skid}\n";

	# Ok, yes we could use %ENV here, but if we did and
	# if someone ever wrote a module in another language
	# or just a cheesy CGI, they would never see it.
	$r->subprocess_env(SLASH_USER => $uid);

	# This is only used if you have used the directive
	# to disallow logins to your site.
	# I need to complete this as a feature. -Brian
	# This is not the way to abort processing... we can take a look
	# at this later maybe. -Jamie 2002/10/02
#	return DECLINED if $cfg->{auth} && isAnon($uid);

	# this needs to get called once per child ... might as well
	# have it called here. -- pudge
	# Note that (and this may be new starting in perl 5.6 or so)
	# if you call srand() with no arguments, perl will try hard
	# to find random data to seed with, using /dev/urandom if
	# possible.  This is almost certainly better than any seed
	# we could cobble together with time() and $$ and so on.
	srand() unless $srand_called;
	$srand_called ||= 1;

	# If this uid is marked as banned, deny them access.
	my $banlist = $reader->getBanList;
	if ($banlist->{$uid}) {
		# The global current user hasn't been created yet, so the
		# template expects uid just passed in as the var named "uid".
		$r->custom_response( Apache2::Const::FORBIDDEN,
			slashDisplay('bannedtext_uid', { uid => $uid }, { Return => 1 } )
		);
		# Now we need to create a user hashref for that global
		# current user, so these fields of accesslog get written
		# correctly when we log this attempted hit.  We do this
		# dummy hashref with the bare minimum of values that we need,
		# instead of going through prepareUser(), because this is
		# much, much faster.
		my $hostip = $r->connection->remote_ip;

		#my($ipid, $subnetid) = get_ipids($hostip);
		# I *really* depise perl's multiple returns
		my @ipids = get_ipids($hostip);
		
		my $user = {
			uid		=> $uid,
			ipid		=> $ipids[0],
			subnetid	=> $ipids[1],
			networktype	=> $ipids[5]
		};
		createCurrentUser($user);
		return Apache2::Const::FORBIDDEN;
	}

	my $user = prepareUser($uid, $form, $uri, $cookies, $method);
	# Reload $uri because prepareUser() may have changed it.
	$uri = $r->uri;

	# "_dynamic_page" or any hash key name beginning with _ or .
	# cannot be accessed from templates -- pudge
	if ($uri =~ /\.pl$/ || $uri =~ /\.tmpl$/) {
		$user->{state}{_dynamic_page} = 1;
	}
	$user->{state}{login_public}        = $user_temp->{state}{login_public};
	$user->{state}{login_temp}          = $user_temp->{state}{login_temp};
	$user->{state}{login_failed_reason} = $user_temp->{state}{login_failed_reason};
	$user->{state}{ssl} = $is_ssl;
	createCurrentUser($user);
	createCurrentForm($form);

	if ($gSkin->{require_acl} && !$user->{acl}{$gSkin->{require_acl}}) {
		$r->err_headers_out->set('Location' =>
			URI->new_abs('/', $constants->{absolutedir})
		);
		return Apache2::Const::REDIRECT;
	}

	# If the user is connecting over SSL, make sure this is allowed.
	# If allow_nonadmin_ssl is 0, then only admins are allowed in.
	# If allow_nonadmin_ssl is 1, then anyone is allowed in.
	# If allow_nonadmin_ssl is 2, then admins and subscribers are allowed in.
	my $redirect_to_nonssl = 0;
	if ($is_ssl && !(
			# If the user is trying to log in, they are always
			# allowed to make the attempt on the SSL server.
			# Logging in means the users.pl script and either
			# an empty op or the 'userlogin' op.
			(
			$uri =~ m{^/osdn-test/}
			||
			$uri =~ m{^/(?:users|login)\.pl}
			) && (!$form->{op} || $form->{op} eq 'userlogin' || $form->{openid_login})
		)
	) {
		my $ans = $constants->{allow_nonadmin_ssl};
		if ($ans == 1) {
			# It's OK, anyone is allowed to use the SSL server.
		} elsif ($ans == 0) {
			# Only admins are allowed in -- but note the special
			# case where this is an admin who has lost privs due
			# to a cleartext password having been sent.  Those
			# admin accounts are allowed in over SSL even though
			# the rest of the system might not consider them
			# "admins" right now.
			if ($user->{seclev} > 1 || $user->{state}{lostprivs}) {
				# It's an admin, this is fine.
			} else {
				# Not an admin, SSL access forbidden.
				$redirect_to_nonssl = 1;
			}
		} elsif ($ans == 2) {
			# Admins are allowed in, per the above case, but
			# also subscribers are allowed in.
			if ($user->{seclev} > 1 || $user->{state}{lostprivs}
				|| $user->{is_subscriber}) {
				# It's an admin or a subscriber, this is fine.
			} else {
				# Not an admin or subscriber, SSL access forbidden.
				$redirect_to_nonssl = 1;
			}
		}
	}
	if ($redirect_to_nonssl) {
		# User is not authorized to connect to the SSL webserver,
		# so redirect them to the non-SSL URL.
		my $newloc = $uri;
		$newloc .= "?" . $r->args if $r->args;
		$r->err_headers_out->set('Location' =>
			URI->new_abs($newloc, $gSkin->{absolutedir}));
		return Apache2::Const::REDIRECT;
	}

	createCurrentCookie($cookies);
	createEnv($r) if $cfg->{env};
	# These next two lines set a CSP for users, unless they are an admin who needs inline scripts for the admin bells and whistles
	# This next line is correct. Changing it temporarily until we can get all the resources coming from the domain requested instead of the base domain
	#if(!$user->{is_admin}) { $r->headers_out->set('Content-Security-Policy', "default-src 'none'; script-src https://checkout.stripe.com; frame-src https://checkout.stripe.com; connect-src https://checkout.stripe.com; img-src 'self' https://www.paypalobjects.com https://q.stripe.com; style-src 'unsafe-inline' 'self' https://checkout.stripe.com");}
	if(!$user->{is_admin}) { $r->headers_out->set('Content-Security-Policy', "default-src 'none'; script-src 'self' https://soylentnews.org https://www.soylentnews.org http://7rmath4ro2of2a42.onion https://checkout.stripe.com; frame-src https://checkout.stripe.com; connect-src https://checkout.stripe.com; img-src 'self' https://soylentnews.org https://www.soylentnews.org http://7rmath4ro2of2a42.onion https://www.paypalobjects.com https://q.stripe.com; style-src 'unsafe-inline' 'self' https://soylentnews.org https://www.soylentnews.org http://7rmath4ro2of2a42.onion https://checkout.stripe.com");}
        else{ $r->headers_out->unset('Content-Security-Policy');}
	add_author_quotes($r) if $form->{slashcode_authors};

	# a special test mode for getting a new template
	# object (hence, fresh cache) for each request
	if ($constants->{template_cache_request}) {
		undef $dbcfg->{template};
	}

	# Weird hack for getCurrentCache() till I can code up proper logic for it
	{
		my $cache = getCurrentCache();

		if (!$cache->{_cache_time} || ((time() - $cache->{_cache_time}) > ($constants->{apache_cache} || 0))) {
			# we can't do $cache = {}, because that won't
			# overwrite the actual ref stored in $cfg->{cache}
			%{$cache} = ();
			$cache->{_cache_time} = time();
		}
	}

	return Apache2::Const::OK;
}

########################################################
sub createEnv {
	my($r) = @_;

	my $user = getCurrentUser();
	my $form = getCurrentForm();

	while (my($key, $val) = each %$user) {
		$r->subprocess_env("USER_$key" => $val);
	}

	while (my($key, $val) = each %$form) {
		$r->subprocess_env("FORM_$key" => $val);
	}

}

########################################################
# These are very important, do not delete these
sub add_random_quote {
	my($r) = @_;
	my $quote = $QUOTES[int(rand(@QUOTES))];
	(my($who), $quote) = split(/: */, $quote, 2);
	$r->headers_out->set("X-$who", $quote);
}

sub add_author_quotes {
	my($r) = @_;
	$r->headers_out->set('X-Author-Krow',"You can't grep a dead tree.");
	$r->headers_out->set('X-Author-Pudge', "Bite me.");
	$r->headers_out->set('X-Author-CaptTofu', "I like Tofu.");
	$r->headers_out->set('X-Author-Jamie', "I also enjoy tofu.");
}

########################################################
sub userLogin {
	my($uid_try, $passwd, $logtoken) = @_;
	my $slashdb = getCurrentDB();
	my($user) = getCurrentUser();

	# only allow plain text passwords, unless logtoken is passed,
	# then only allow that
	# my($EITHER, $PLAIN, $ENCRYPTED, $LOGTOKEN) = (0, 1, 2, 3);
	my $kind = $logtoken ? 3 : 1;

	my($uid, $cookvalue, $newpass) =
		$slashdb->getUserAuthenticate($uid_try, $passwd, $kind);

	if (!isAnon($uid)) {
		setCookie('user', bakeUserCookie($uid, $cookvalue),
			$user->{state}{login_temp} eq 'yes'
				? 2
				: $slashdb->getUser($uid, 'session_login')
		);
		return($uid, $newpass);
	} else {
		my $gSkin = getCurrentSkin();
		return $gSkin && $gSkin->{ac_uid}
			? $gSkin->{ac_uid}
			: getCurrentStatic('anonymous_coward_uid');
	}
}


{
my %ops_my = (
	inbox           => { args => 'op=show', uri => 'messages.pl' },
	# XXX change messages to be same as /inbox, move this to /my/preferences/messages
	submissions     => { args => 'op=usersubmissions' },
	messages        => { args => 'op=display_prefs', uri => 'messages.pl' },
	comments        => { args => 'op=editcomm' },
	homepage        => { args => 'op=edithome' },
	password        => { args => 'op=changeprefs', uri => 'login.pl' },
	logout          => { args => 'op=userclose', uri => 'login.pl' },
	misc            => { args => 'op=editmiscopts' },
	amigos          => { args => 'op=friendview', uri => 'journal.pl' },
	bookmarks       => { args => 'op=showbookmarks' },
	preferences     => { args => 'op=displayprefs', uri => 'preferences.pl' },
	tags            => { args => 'op=showtags' },
	journal         => { args => 'op=list', uri => 'journal.pl' },

	friends         => { args => 'op=friends', uri  => 'zoo.pl' },
	fans            => { args => 'op=fans', uri  => 'zoo.pl' },
	freaks          => { args => 'op=freaks', uri  => 'zoo.pl' },
	foes            => { args => 'op=foes', uri  => 'zoo.pl' },
	zoo             => { args => 'op=all', uri  => 'zoo.pl' },

	default         => { args => 'op=edituser' }
);
$ops_my{$_}{uri} ||= 'users.pl' for (keys %ops_my);

my %ops_u = (
	pubkey          => { args => 'nick=__NICK__&amp;uid=__UID__', uri  => 'pubkey.pl' },
	submissions     => { args => 'nick=__NICK__&amp;uid=__UID__&amp;op=usersubmissions' },
	comments        => { args => 'nick=__NICK__&amp;uid=__UID__&amp;op=usercomments' },
	amigos          => { args => 'nick=__NICK__&amp;uid=__UID__&amp;op=friendview', uri  => 'journal.pl' },
	bookmarks       => { args => 'nick=__NICK__&amp;uid=__UID__&amp;op=showbookmarks' },
	journal         => { args => 'nick=__NICK__&amp;uid=__UID__&amp;op=display', uri => 'journal.pl' },
	tags            => { args => 'nick=__NICK__&amp;uid=__UID__&amp;op=showtags' },

	friends         => { args => 'nick=__NICK__&amp;uid=__UID__&amp;op=friends', uri  => 'zoo.pl' },
	fans            => { args => 'nick=__NICK__&amp;uid=__UID__&amp;op=fans', uri  => 'zoo.pl' },
	freaks          => { args => 'nick=__NICK__&amp;uid=__UID__&amp;op=freaks', uri  => 'zoo.pl' },
	foes            => { args => 'nick=__NICK__&amp;uid=__UID__&amp;op=foes', uri  => 'zoo.pl' },
	zoo             => { args => 'nick=__NICK__&amp;uid=__UID__&amp;op=all', uri  => 'zoo.pl' },

	default         => { args => 'nick=__NICK__&amp;uid=__UID__' },
);
$ops_u{$_}{uri} ||= 'users.pl' for (keys %ops_u);

my %ops_u2 = (
	submissions     => { args => 'nick=__NICK__&amp;uid=__UID__&amp;dp=submissions' },
	comments        => { args => 'nick=__NICK__&amp;uid=__UID__&amp;dp=comments' },
	amigos          => { args => 'nick=__NICK__&amp;uid=__UID__&amp;dp=journalfriends' },
	bookmarks       => { args => 'nick=__NICK__&amp;uid=__UID__&amp;dp=bookmarks' },
	admin           => { args => 'nick=__NICK__&amp;uid=__UID__&amp;dp=admin' },
	journal         => { args => 'nick=__NICK__&amp;uid=__UID__&amp;dp=journal' },
	tags            => { args => 'nick=__NICK__&amp;uid=__UID__&amp;dp=tags&amp;op=userinfo' },

	friends         => { args => 'nick=__NICK__&amp;uid=__UID__&amp;dp=friends' },
	fans            => { args => 'nick=__NICK__&amp;uid=__UID__&amp;dp=fans' },
	freaks          => { args => 'nick=__NICK__&amp;uid=__UID__&amp;dp=freaks' },
	foes            => { args => 'nick=__NICK__&amp;uid=__UID__&amp;dp=foes' },
	zoo             => { args => 'nick=__NICK__&amp;uid=__UID__&amp;dp=all' },

	default         => { args => 'nick=__NICK__&amp;uid=__UID__' }
);
$ops_u2{$_}{uri} ||= 'users2.pl' for (keys %ops_u2);

my %ops_my_ac = (
	newuser         => { args => 'op=newuserform' },
	mailpassword    => { args => 'op=mailpasswdform' },
	login           => { args => 'op=userlogin' },

	default         => { args => 'op=userlogin' }
);
$ops_my_ac{$_}{uri} ||= 'login.pl' for (keys %ops_my_ac);

########################################################
# XXX May want to rename this, since it's being used for a user's
# prefs/info pages (/my/foo) and for the global handlers too (/foo).
# Of course renaming requires editing a .conf file (see
# bin/install-slashsite PerlTransHandler).
sub userdir_handler {
	my($class, $r) = @_;

	return Apache2::Const::DECLINED unless $r->is_initial_req;

	my $constants = getCurrentStatic();
	my $gSkin = getCurrentSkin();

	# note that, contrary to the RFC, a + in this handler
	# will be treated as a space; the only way to get a +
	# is to encode it, such as %2B
	my $uri = $r->the_request;
	$uri =~ s/^\S+\s+//;
	$uri =~ s/\s+\S+$//;
	$uri =~ s/\+/ /g;

	my $logtoken;
	if ($uri =~ s{(?:^|/)?(\d+(?::|%3[aA]){2}\w+)$}{}) {
		$logtoken = $1;
	}

	my $saveuri = $uri;
	$uri =~ s/%([a-fA-F0-9]{2})/pack('C', hex($1))/ge;

	if ($gSkin->{rootdir}) {
		my $path = URI->new($gSkin->{rootdir})->path;
		$uri =~ s/^\Q$path//;
	}
	# URIs like /tags and /tags/foo and /tags/foo?type=bar are special cases.
	if ($uri =~ m[^/tags? (?: /([^?]*) | /? ) (?: \?(.*) )? $]x) {
		my($word, $query) = ($1, $2);
		my @args = ( );
		if ($word =~ /^(active|recent|all)$/) {
			push @args, "type=$word";
		} else {
			push @args, "tagname=$word";
		}
		push @args, $query if defined $query;
		$r->args(join('&', @args));
		$r->uri('/tags.pl');
		$r->filename($constants->{basedir} . '/tags.pl');
		return Apache2::Const::OK;
	}

	# for self-references (/~/ and /my/)
	if (($saveuri =~ m[^/(?:%7[eE]|~)] && $uri =~ m[^/~ (?: /(.*) | /? ) $]x)
		# /my/ or /my can match, but not /mything
		|| $uri =~ m[^/my (?: /(.*) | /? ) $]x
	) {
		my($string, $query) = ($1, '');
		if ($string =~ s/\?(.+)$//) {
			# This seems to have no effect, right? since $query
			# is redeclared in a different scope below -Jamie
			# This is in case something in this scope wants it -- pudge
			$query = $1;
		}
		
		my($op, $extra) = split /\//, $string, 2;
		$extra ||= '';

		my $logged_in = $r->headers_in->{'Cookie'} =~ $USER_MATCH;
		my $try_login = !$logged_in && $logtoken;

		my($r_args, $r_uri);

		if ($logged_in || $try_login) {
			my $r_op = $ops_my{$op};
			$r_op ||= $ops_my{default};
			($r_args, $r_uri) = @{$r_op}{qw(args uri)};

			if ($op eq 'inbox') {
				if ($extra =~ m{^ (rss|atom) /? $}x) {
					$r_args .= '_rss';
					$r_args .= "&amp;logtoken=$logtoken" if $try_login;
					$r_args .= "&amp;content_type=$1";
				}

			} elsif ($logged_in) {
				if ($op eq 'journal') {
					$extra .= '/';
					if ($extra =~ /^(\d+)\/$/) {
						$r_args = "id=$1&amp;op=edit";
					} elsif ($extra =~ s/^friends\///) {
						$r_args = "op=friendview";
					}

				} elsif ($op =~ /^(?:friends|fans|freaks|foes|zoo)$/) {
					$extra .= '/';
					if ($op eq 'friends') {
						if ($extra =~ s/^friends\///) {
							$r_args =~ s/friends/fof/;
						} elsif ($extra =~ s/^foes\///) {
							$r_args =~ s/friends/eof/;
						}
					}

				} elsif ($op eq 'submissions') {
					$r_args .= "&amp;page=$extra" if $extra;
				}
			}

		} else {
			# XXX I'll remove these soon -cbrown
			#undef $r_args;
			#$r_uri = 'login.pl';

			my $r_op = $ops_my_ac{$op};
			$r_op ||= $ops_my_ac{default};
			($r_args, $r_uri) = @{$r_op}{qw(args uri)};			
		}

		$r->args($r_args) if defined($r_args);
		$r->uri('/' . $r_uri);
		$r->filename($constants->{basedir} . '/' . $r_uri);

		return Apache2::Const::OK;

	} elsif ($uri =~ m[^/bookmarks (?: /(.*) | /? ) $]x) {
		$r->args('op=showbookmarks');
		$r->uri('/bookmark.pl');
		$r->filename($constants->{basedir} . '/bookmark.pl');
		return Apache2::Const::OK;
	}

	# assuming Apache/mod_perl is decoding the URL in ->uri before
	# returning it, we have to re-encode it with fixparam().  that
	# will change if somehow Apache/mod_perl no longer decodes before
	# returning the data. -- pudge
	if (($saveuri =~ m[^/(?:%7[eE]|~)(.+)]) || ($saveuri =~ m[^/(?:%5[eE]|\^)(.+)])) {
		my($string, $query) = ($1, '');
		if ($string =~ s/\?(.+)$//) {
			$query = $1;
		}
		my($nick, $op, $extra, $more) = split /\//, $string, 4;
		for ($nick, $op, $extra, $more) {
			s/%([a-fA-F0-9]{2})/pack('C', hex($1))/ge;
		}


		my $slashdb = getCurrentDB();
		my $reader_user = $slashdb->getDB('reader');
		my $reader = getObject('Slash::DB', { virtual_user => $reader_user });
		my $uid = $reader->getUserUID($nick);
		my $nick_orig = $nick;
		$nick = fixparam($nick);	# make safe to pass back to script

		my($r_args, $r_uri);

		if (!$uid) {
			$r_args = 'op=no_user';
			$r_uri  = 'users.pl';

		} else {
			my $r_op = $ops_u{$op};
			my $u2 = 0;
			if ($constants->{u2} || $saveuri =~ m[^/(?:%5[eE]|\^)(.+)]) {
				$r_op = $ops_u2{$op} if $ops_u2{$op};
				$u2 = 1;
			}
			$r_op ||= $u2 ? $ops_u2{default} : $ops_u{default};
			($r_args, $r_uri) = @{$r_op}{qw(args uri)};

			# special cases for handling $extra
			if ($op eq 'journal') {
				$extra .= '/' . $more;
				if ($u2 && !($extra =~ m{ (?:rss|atom) /?$}x || $extra =~ /^(\d+)\/$/)) {
					# show hose in friend view (op=journalfriends)
					$r_args .= 'friends' if $extra =~ /^friends\//;
				} else {
					 # override u2 for rss|atom and \d
					($r_args, $r_uri) = @{ $ops_u{journal} }{ qw(args uri) };

					if ($extra =~ /^(\d+)\/$/) {
						$r_args .= "&amp;id=$1";
					} elsif ($extra =~ s/^friends\///) {
						$r_args =~ s/display/friendview/;
					}
					if ($extra =~ m{^ (rss|atom) / ? $}x) {
						$r_args .= "&amp;logtoken=$logtoken" if $logtoken;
						$r_args .= "&amp;content_type=$1";
					}

					$r_args .= "&amp;$query";
				}

			} elsif ($op =~ /^(?:friends|fans|freaks|foes|zoo)$/) {
				$extra .= '/' . $more;
				if ($u2 && $extra =~ m{ (?:rss|atom) /?$}x) {
					 # override u2 for rss|atom and \d
					($r_args, $r_uri) = @{ $ops_u{journal} }{ qw(args uri) };
				}

				if ($op eq 'friends') {
					if ($extra =~ s/^friends\///) {
						$r_args =~ s/friends/fof/;
					} elsif ($extra =~ s/^foes\///) {
						$r_args =~ s/friends/eof/;
					}
				}

				if ($extra =~ m{^ (rss|atom) /?$}x) {
					$r_args .= "&amp;content_type=$1";
				}


			} elsif ($op eq 'tags') {
				$r_args =~ s/dp=tags/dp=usertag/ if $u2 && $extra;
				# XXX "!" is a 'reserved' char in URI, escape it here?
				$r_args .= "&amp;tagname=$extra" if $extra;
			} elsif ($u2 && ($op eq 'bookmarks' || $op eq 'default' || $op eq 'journal')) {
				if ($extra && $extra ne "rss") {
					$r_args .= "&amp;addfilter=$extra" if $extra;
				}
			} elsif ($op eq 'submissions') {
					$r_args .= "&amp;page=$extra" if $extra;
				}
		}

		$r_args =~ s/__NICK__/$nick/;
		$r_args =~ s/__UID__/$uid/;

		$r->args($r_args) if defined($r_args);
		$r->uri('/' . $r_uri);
		$r->filename($constants->{basedir} . '/' . $r_uri);

		return Apache2::Const::OK;
	}

	return Apache2::Const::DECLINED;
} }



########################################################
#
sub DESTROY { }

@QUOTES = split(/\n/, <<'EOT');
Bender:Fry, of all the friends I've had ... you're the first.
Bender:I hate people who love me. And they hate me.
Bender:Oh no! Not the magnet!
Bender:Bender's a genius!
Bender:Well I don't have anything else planned for today, let's get drunk!
Bender:Oh, so, just 'cause a robot wants to kill humans that makes him a radical?
Bender:Bite my shiny, metal ass!
Bender:Lick my frozen, metal ass!
Bender:Life is hilariously cruel.
Bender:The laws of science be a harsh mistress.
Bender:In the event of an emergency, my ass can be used as a flotation device.
Bender:Like most of life's problems, this one can be solved with bending.
Bender:A woman like that you gotta romance first!
Bender:OK, but I don't want anyone thinking we're robosexuals.
Bender:Hey Fry, I'm steering with my ass!
Bender:Care to contribute to the Anti-Mugging-You Fund?
Bender:Want me to smack the corpse around a little?
Bender:My full name is Bender Bending Rodriguez.
Bender:My life, and by extension everyone else's, is meaningless.
Bender:I'm tired of this room and everyone in it!
Bender:Wait! My cheating unit malfunctioned! You gotta give me a do-over!
Bender:Gimme your biggest, strongest, cheapest drink.
Bender:I'm a fraud. A poor, lazy, sexy fraud.
Bender:Ahhh, functional.
Bender:Since I love you all so much, I'd like to give everyone hugs.
Bender:There! That oughtta convert a few tailgaters.
Bender:But-- those girls don't wear cases! You can see their bare circuits!
Bender:They're tormenting me with uptempo singing and dancing!
Bender:Comedy's a dead art form. Now tragedy -- THAT'S funny.
Bender:Nothing like a warm fire and a super-soaker of fine cognac.
Bender:Yes! I got the most! I win X-Mas!
Bender:I'm one of those lazy, homeless bums I've been hearing about.
Bender:Shooting DNA at each other to make babies. I find it offensive!
Bender:We're both expressible as the sum of two cubes!
Bender:Stupid anti-pimping laws!
Bender:Float like a floatbox, sting like an automatic stingin' machine.
Bender:Crippling pain? That's not covered by my insurance fraud.
Bender:Let's commence preparations for rumbling!
Bender:Woohoo, I'm popular!
Bender:Ah crap, I'm some sort of robot!
Bender:When will man learn that all races are equally inferior to robots?
Bender:Curse my natural showmanship!
Bender:I'm not allowed to sing. Court order.
Bender:Boy, who knew a cooler could also make a handy wang coffin?
Bender:I'm so embarrassed. I wish everybody else was dead.
Bender:Professor! Make a woman out of me!
Bender:Would we have donkeys?
Bender:Emotions are dumb and should be hated.
Bender:An upgrade? I thought we all agreed I was perfect.
Bender:Curse you, merciful Poseidon!
Bender:I am a hideous triumph of form and function.
Bender:I'm an outdated piece of junk.
Bender:The modern world can bite my splintery, wooden ass!
Bender:Whoever's directing this is a master of suspense!
Bender:Fathero!
Bender:Now that's hospital dancing.
Bender:Try this, kids at home!
Bender:I've gone too far! Who does that guy think I am?
Bender:Down with Bender!
Bender:Listen up, cause I got a climactic speech.
Bender:I choose to not understand these signs!
Bender:Aw, this bends!
Bender:Farewell, big blue ball of idiots!
Bender:This guy's not making any sense. Can I kill him? Please?
Bender:Hooray, we don't have to do anything!
Bender:I only speak enough binary to ask where the bathroom is.
Bender:nogoodlawsprotectingtheinnocent--
Bender:Senseless death! The folk singer's best friend!
Bender:Alright! Closure!
Bender:You just lost five dollars.
Bender:That's not my gold-plated 25-pin connector.
Bender:I only know enough binary to ask where the bathroom is.
Bender:Why would God think in binary?
Bender:You can't count on God for jack! He pretty much told me so himself.
Bender:Stop doing the right thing, you jerk!
Bender:Are you familiar with the old robot saying "does not compute"?
Bender:The sparks keep me warm.
Bender:Boy, were we suckers!
Bender:Whaddya say, folks? Hot or not?
Bender:Bender knows when to use finesse.
Bender:And I bet it's gonna get a lot more confusing.
Fry:There's a lot about my face you don't know.
Fry:These new hands are great. I'm gonna break them in tonight.
Fry:I refuse to testify on the grounds that my organs will be chopped up into a patty.
Fry:Leela, there's nothing wrong with anything.
Fry:Leela, Bender, we're going grave-robbing.
Fry:Where's Captain Bender? Off catastrophizing some other planet?
Fry:People said I was dumb but I proved them!
Fry:It's like a party in my mouth and everyone's throwing up.
Fry:I don't regret this, but I both rue and lament it.
Fry:You'll barely regret this.
Fry:I'm never gonna get used to the thirty-first century. Caffeinated bacon?
Fry:They're great! They're like sex except I'm having them.
Fry:No, no, I was just picking my nose.
Fry:How can I live my life if I can't tell good from evil?
Fry:That's a chick show. I prefer programs of the genre: World's Blankiest Blank.
Fry:But this is HDTV. It's got better resolution than the real world.
Fry:I'm gonna be a science fiction hero, just like Uhura, or Captain Janeway, or Xena!
Fry:Make up some feelings and tell her you have them.
Fry:I'm not a robot like you -- I don't like having disks crammed into me. Unless they're Oreos. And then only in the mouth.
Fry:Sweet justice! Sweet, juicy justice!
Fry:I must be a robot. Why else would human women refuse to date me?
Fry:Hey look, it's that guy you are!
Fry:That doesn't look like an "L", unless you count lower case.
Fry:Hardy Boys: too easy. Nancy Drew: too hard!
Fry:I'm going to continue never washing this cheek again.
Fry:I haven't had time off since I was twenty-one through twenty-four.
Fry:The spoon's in the foot powder.
Fry:You mean Bender is the evil Bender? I'm shocked! Shocked! Well not that shocked.
Fry:I'm literally angry with rage!
Fry:The butter in my pocket is melting!
Fry:Stop abducting me!
Fry:What kind of bozos would start a Bender protest group?
Fry:I can burp the alphabet. A, B, D ... no, wait ...
Fry:Why use my own legs like an idiot when I can use a Chickenwalker?
Fry:Hooray, we don't have to do anything!
Fry:Prepare to be thought at!
Fry:I did it! And it's all thanks to the books at my local library.
Fry:Existing is basically all I do!
Fry:It's a widely-believed fact!
Fry:My hands! My horrible, human hands!
Fry:How about me? I'm human, and I've always wanted to see the future!
Fry:The less fortunate get all the breaks!
Fry:Please, Mr. Nixon! We're appealing to your sense of decency!
Fry:I have more important things to do today than laugh and clap my hands.
Fry:I'll be whatever I wanna do.
Fry:There's a political debate on. Quick, change the channel!
Fry:It's all there, in the macaroni.
Fry:Can I pull up my pants now?
Fry:Robots don't go to heaven.
Leela:There's a political debate on. Quick, change the channel!
Leela:You did the best you could, I guess, and some of these gorillas are okay.
Leela:This wangs chung.
Leela:This toads the wet sprocket.
Leela:He opened up relations with China. He doesn't want to hear about your ding-dong.
Leela:This is by a wide margin the least likely thing that has ever happened.
Leela:I'm a millionaire! Suddenly I have an opinion about the capital gains tax.
Leela:Do you have idiots on your planet?
Leela:My old life wasn't as glamorous as my webpage made it look.
Leela:No, Leela will show you out.
Hermes:Without my body, I'm a nobody.
Zoidberg:Friends, help! A guinea pig tricked me! 
Zoidberg:If only it'd worked, you could go back and not waste your time on it. 
Zoidberg:Hello? I'll take eight!
Zoidberg:Once again, the conservative, sandwich-heavy portfolio pays off for the hungry investor!
Zoidberg:One art please!
Zoidberg:There's no part of that sentence I didn't like!
Zoidberg:The box, says no.
Zoidberg:I wasn't wearing it. I was eating it!
EOT

1;

__END__

=head1 NAME

Slash::Apache::User - Apache Authenticate for Slash user

=head1 SYNOPSIS

	use Slash::Apache::User;

=head1 DESCRIPTION

This is the user authenication system for Slash. This is
where you want to be if you want to modify slashcode's
method of authentication. The rest of Slash depends
on finding the UID of the user in the SLASH_USER
environmental variable.

=head1 SEE ALSO

Slash(3), Slash::Apache(3).

=cut

# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Apache::User;

use strict;
use Digest::MD5 'md5_hex';
use Time::HiRes;
use Apache;
use Apache::Constants qw(:common M_GET REDIRECT);
use Apache::Cookie;
use Apache::Request ();
use Apache::File;
use Apache::ModuleConfig;
use AutoLoader ();
use DynaLoader ();
use Slash::Apache ();
use Slash::Display;
use Slash::Utility;
use URI ();
use vars qw($REVISION $VERSION @ISA @QUOTES $USER_MATCH $request_start_time);

@ISA		= qw(DynaLoader);
$VERSION   	= '2.003000';  # v2.3.0
($REVISION)	= ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

bootstrap Slash::Apache::User $VERSION;

# BENDER: Oh, so, just 'cause a robot wants to kill humans
# that makes him a radical?

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

	return DECLINED unless $r->is_main;

	$request_start_time ||= Time::HiRes::time;

	# Ok, this will make it so that we can reliably use Apache->request
	Apache->request($r);

	my $cfg = Apache::ModuleConfig->get($r);
	my $dbcfg = Apache::ModuleConfig->get($r, 'Slash::Apache');
	my $constants = getCurrentStatic();
	my $slashdb = $dbcfg->{slashdb};
	my $apr = Apache::Request->new($r);
	my $gSkin = getCurrentSkin();

	$r->header_out('X-Powered-By' => "Slash $Slash::VERSION");
	random($r);

	# let pass unless / or .pl
	my $uri = $r->uri;
	if ($gSkin->{rootdir}) {
		my $path = URI->new($gSkin->{rootdir})->path;
		$uri =~ s/^\Q$path//;
	}

	my $is_ssl = Slash::Apache::ConnectionIsSSL();

	$slashdb->sqlConnect;

	##################################################
	# Don't remove this. This solves a known bug in Apache -- brian
	# i really wish we knew WHAT bug, and how this solves it -- pudge
	#
	# OK, let's try to clear this up. See:
	# http://www.apache.org/dist/perl/mod_perl-1.28/faq/mod_perl_api.pod
	# The issue is that we use Apache::Request's methods to parse an
	# incoming POST request;  it reads Content-length bytes from STDIN
	# and converts them into params which we assign into a form hash in
	# filter_params().  If another module later tries to do the same
	# thing, it will hang forever waiting to read Content-length more
	# bytes from STDIN when of course none are left to read.  The main
	# danger is that someone will 'use CGI' along with Slash -- CGI.pm
	# automatically parses that data and so will hang.  There is no
	# good way to share that data between the two modules, so what we
	# do instead is munge what Apache::Request considers the incoming
	# data to be, so no later code will try to read from it.  Maybe we
	# should do this in filter_params itself, but for now it's here.
	# -- jamie
	# And gee it sure looks like this makes this handler get executed
	# twice and the second time through it comes as a GET with no
	# parameters because they've been nuked.  But when I comment
	# those three lines out, it at least works, so that's what I'm
	# doing for now.  We'll figure it out better later.  -- jamie

	my $method = $r->method;

	my $form = filter_params($apr);

#	$r->method('GET');
#	$r->method_number(M_GET);
#	$r->headers_in->unset('Content-length');

	# And now the request is safe for CGI.pm or anything else to try
	# to work with -- or at least it won't hang.
	##################################################

	$form->{query_apache} = $apr;
	@{$form}{keys  %{$constants->{form_override}}} =
		values %{$constants->{form_override}};
	my $cookies = Apache::Cookie->fetch;

	# So we are either going to pick the user up from
	# the form, a cookie, or they will be anonymous
	my $uid;
	my $op = $form->{op} || '';

	# we know this is not the current user yet, but we only
	# want to save one bit of information there, and retrieve it
	# later -- pudge
	my $user_temp = getCurrentUser();
	$user_temp->{state}{login_temp} = 'no';
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

		# Don't allow login attempts from IPIDs that have been marked
		# as "nopost" -- those are mostly open proxies.  Check both
		# the ipid and the subnetid (we can't use values in $user
		# because that doesn't get set up until prepareUser is called,
		# later in this function).  Note we don't have to MD5 the
		# values, checkReadOnly() knows how to do that.
		my $read_only = 0;
		my $hostip = $r->connection->remote_ip;
		my($ip, $subnet) = get_ipids($hostip, 1);
		if ($slashdb->checkReadOnly('nopost', { ipid => $ip })) {
			$read_only = 1;
		} else {
			$read_only = 1 if $slashdb->checkReadOnly('nopost', {
				subnetid => $subnet });
		}

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
				  "&note=Please+change+your+password+now!&oldpass=" . fixparam($form->{upasswd})
				: $form->{returnto}
					? $form->{returnto}
					: $uri),
				$absolutedir
			);
			# not working ... move out into users.pl and index.pl
			# I may know why this is the case, we may need
			# to send a custom errormessage. -Brian
#			$r->err_header_out(Location => $newurl);
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
			if ($constants->{rss_allow_index} && $form->{content_type} eq 'rss' && $uri =~ m{^/index\.pl$}) {
				$logtoken = $form->{logtoken};
			} else {
				delete $form->{logtoken};
			}
		}

		my($tmpuid, $value) = eatUserCookie($logtoken || ($cookies->{user} && $cookies->{user}->value));
		my $cookvalue;
		if ($tmpuid && $tmpuid > 0 && $tmpuid != $constants->{anonymous_coward_uid}) {
			($uid, $cookvalue) =
				$slashdb->getUserAuthenticate($tmpuid, $value, 0, 1);
		}

		# we don't want to set a cookie etc. if user is using a $logtoken,
		# as that is just for RSS etc.
		if (!$logtoken && $uid && $op ne 'userclose') {
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

		# blank out user cookie and make anon if user wants to log out, or
		# uses a bad cookie
		} elsif (!$logtoken && dbAvailable()) {
			if ($op eq 'userclose') {
				$slashdb->deleteLogToken($uid);
			}

			$uid = $constants->{anonymous_coward_uid};
			delete $cookies->{user};
			# if you are here, chances are your cookie is bad,
			# so we blank it out for you.  you're welcome.
			setCookie('user', '');
		}

	} elsif ($op eq 'userclose') {
		# When did we comment out this? This means that even
		# if an author logs out, the other authors will
		# not know about it. Bad....
		#$slashdb->deleteSession(); #  if $slashdb->getUser($uid, 'seclev') >= 99;
		delete $cookies->{user};
		setCookie('user', '');
	}

	# can't use after login
	delete $form->{login_temp};

	# This has happened to me a couple of times.
	delete $cookies->{user} if $cookies->{user} && !$cookies->{user}->value;

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
	my $banlist = $slashdb->getBanList();
	if ($banlist->{$uid}) {
		# The global current user hasn't been created yet, so the
		# template expects uid just passed in as the var named "uid".
		$r->custom_response(FORBIDDEN,
			slashDisplay('bannedtext_uid', { uid => $uid }, { Return => 1 } )
		);
		# Now we need to create a user hashref for that global
		# current user, so the "uid" field of accesslog gets written
		# correctly when we log this attempted hit.  We do this
		# dummy hashref with the bare minimum of values that we need,
		# instead of going through prepareUser(), because this is
		# much, much faster.
		my $hostip = $r->connection->remote_ip;
		my($ipid, $subnetid) = get_ipids($hostip);
		my $user = {
			uid		=> $uid,
			ipid		=> $ipid,
			subnetid	=> $subnetid,
		};
		createCurrentUser($user);
		return FORBIDDEN;
	}

	my $user = prepareUser($uid, $form, $uri, $cookies, $method);
	# "_dynamic_page" or any hash key name beginning with _ or .
	# cannot be accessed from templates -- pudge
	if ($uri =~ /\.pl$/ || $uri =~ /\.tmpl$/) {
		$user->{state}{_dynamic_page} = 1;
	}
	$user->{state}{login_temp} = $user_temp->{state}{login_temp};
	$user->{state}{login_failed_reason} = $user_temp->{state}{login_failed_reason};
	$user->{state}{ssl} = $is_ssl;
	createCurrentUser($user);
	createCurrentForm($form);

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
			) && (!$form->{op} || $form->{op} eq 'userlogin')
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
		# User is not authorized to connect to the SSL webserver.
		# Redirect them to the non-SSL URL.
		my $newloc = $uri;
		$newloc .= "?" . $r->args if $r->args;
		$r->err_header_out(Location =>
			URI->new_abs($newloc, $gSkin->{absolutedir}));
		return REDIRECT;
	}

	createCurrentCookie($cookies);
	createEnv($r) if $cfg->{env};
	authors($r) if $form->{'slashcode_authors'};

	# a special test mode for getting a new template
	# object (hence, fresh cache) for each request
	if ($constants->{template_cache_request}) {
		undef $dbcfg->{template};
	}

	# Weird hack for getCurrentCache() till I can code up proper logic for it
	{
		my $cache = getCurrentCache();
		if (!$cache->{_cache_time} || ((time() - $cache->{_cache_time}) > $constants->{apache_cache})) {
			# we can't do $cache = {}, because that won't
			# overwrite the actual ref stored in $cfg->{cache}
			%{$cache} = ();
			$cache->{_cache_time} = time();
		}
	}

	return OK;
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
# These are very import, do not delete these
sub random {
	my($r) = @_;
	my $quote = $QUOTES[int(rand(@QUOTES))];
	(my($who), $quote) = split(/: */, $quote, 2);
	$r->header_out("X-$who" => $quote);
}

sub authors {
	my($r) = @_;
	$r->header_out('X-Author-Krow' => "You can't grep a dead tree.");
	$r->header_out('X-Author-Pudge' => "Bite me.");
	$r->header_out('X-Author-CaptTofu' => "I like Tofu.");
	$r->header_out('X-Author-Jamie' => "I also enjoy tofu.");
}

########################################################
sub userLogin {
	my($uid_try, $passwd, $logtoken) = @_;
	my $slashdb = getCurrentDB();

	# only allow plain text passwords, unless logtoken is passed,
	# then only allow that
	# my($EITHER, $PLAIN, $ENCRYPTED, $LOGTOKEN) = (0, 1, 2, 3);
	## this is disabled for now; some people still using saved URLs
	## with encrypted passwords etc. ... come back to it later -- pudge
	my $kind = 0; #$logtoken ? 3 : 1;

	my($uid, $cookvalue, $newpass) =
		$slashdb->getUserAuthenticate($uid_try, $passwd, $kind);

	if (!isAnon($uid)) {
		setCookie('user', bakeUserCookie($uid, $cookvalue),
			$slashdb->getUser($uid, 'session_login'));
		return($uid, $newpass);
	} else {
		my $gSkin = getCurrentSkin();
		return $gSkin && $gSkin->{ac_uid}
			? $gSkin->{ac_uid}
			: getCurrentStatic('anonymous_coward_uid');
	}
}

########################################################
sub userdir_handler {
	my($r) = @_;

	return DECLINED unless $r->is_initial_req;

	my $constants = getCurrentStatic();
	my $gSkin = getCurrentSkin();

	# note that, contrary to the RFC, a + in this handler
	# will be treated as a space; the only way to get a +
	# is to encode it, such as %2B
	my $uri = $r->the_request;
	$uri =~ s/^\S+\s+//;
	$uri =~ s/\s+\S+$//;
	$uri =~ s/\+/ /g;
	my $saveuri = $uri;
	$uri =~ s/%([a-fA-F0-9]{2})/pack('C', hex($1))/ge;

	if ($gSkin->{rootdir}) {
		my $path = URI->new($gSkin->{rootdir})->path;
		$uri =~ s/^\Q$path//;
	}

	# for self-references (/~/ and /my/)
	if (($saveuri =~ m[^/(?:%7[eE]|~)] && $uri =~ m[^/~ (?: /(.*) | /? ) $]x)
		# /my/ or /my can match, but not /mything
		or ($uri =~ m[^/my (?: /(.*) | /? ) $]x)
	) {
		my $match = $1;
		if ($r->header_in('Cookie') =~ $USER_MATCH) {
			my($op, $extra) = split /\//, $match, 2;
			if ($op eq 'journal') {
				my $args;
				if ($extra && $extra =~ /^\d+$/) {
					$args = "id=$extra&op=edit";
				} elsif ($extra && $extra eq 'friends') {
					$args = "op=friendview";
				} else {
					$args = "op=list";
				}
				$r->args($args);
				$r->uri('/journal.pl');
				$r->filename($constants->{basedir} . '/journal.pl');
			} elsif ($op eq 'discussions') {
				$r->args("op=personal_index");
				$r->uri('/comments.pl');
				$r->filename($constants->{basedir} . '/comments.pl');
			} elsif ($op eq 'inbox') {
				$r->args("op=list");
				$r->uri('/messages.pl');
				$r->filename($constants->{basedir} . '/messages.pl');
			} elsif ($op eq 'messages') { # XXX change to be same as /inbox, move this to /my/preferences/messages
				$r->args("op=display_prefs");
				$r->uri('/messages.pl');
				$r->filename($constants->{basedir} . '/messages.pl');
			} elsif ($op eq 'friends') {
				if ($extra eq 'friends') {
					$r->args("op=fof");
					$r->uri('/zoo.pl');
					$r->filename($constants->{basedir} . '/zoo.pl');
				} elsif ($extra eq 'foes') {
					$r->args("op=eof");
					$r->uri('/zoo.pl');
					$r->filename($constants->{basedir} . '/zoo.pl');
				} else {
					$r->args("op=friends");
					$r->uri('/zoo.pl');
					$r->filename($constants->{basedir} . '/zoo.pl');
				}
			} elsif ($op eq 'foes') {
				$r->args("op=foes");
				$r->uri('/zoo.pl');
				$r->filename($constants->{basedir} . '/zoo.pl');
			} elsif ($op eq 'fans') {
				$r->args("op=fans");
				$r->uri('/zoo.pl');
				$r->filename($constants->{basedir} . '/zoo.pl');
			} elsif ($op eq 'freaks') {
				$r->args("op=freaks");
				$r->uri('/zoo.pl');
				$r->filename($constants->{basedir} . '/zoo.pl');
			} elsif ($op eq 'zoo') {
				$r->args("op=all");
				$r->uri('/zoo.pl');
				$r->filename($constants->{basedir} . '/zoo.pl');
			} elsif ($op eq 'comments') {
				$r->args("op=editcomm");
				$r->uri('/users.pl');
				$r->filename($constants->{basedir} . '/users.pl');
			} elsif ($op eq 'homepage') {
				$r->args("op=edithome");
				$r->uri('/users.pl');
				$r->filename($constants->{basedir} . '/users.pl');
			} elsif ($op eq 'password') {
				$r->args("op=changeprefs");
				$r->uri('/login.pl');
				$r->filename($constants->{basedir} . '/login.pl');
			} elsif ($op eq 'logout') {
				$r->args("op=userclose");
				$r->uri('/login.pl');
				$r->filename($constants->{basedir} . '/login.pl');
			} elsif ($op eq 'misc') {
				$r->args("op=editmiscopts");
				$r->uri('/users.pl');
				$r->filename($constants->{basedir} . '/users.pl');
			} elsif ($op eq 'amigos') {
				$r->args("op=friendview");
				$r->uri('/journal.pl');
				$r->filename($constants->{basedir} . '/journal.pl');
			} else {
				$r->args("op=edituser");
				$r->uri('/users.pl');
				$r->filename($constants->{basedir} . '/users.pl');
			}
			return OK;
		} else {
			$r->uri('/login.pl');
			$r->filename($constants->{basedir} . '/login.pl');
			return OK;
		}
	}

	# assuming Apache/mod_perl is decoding the URL in ->uri before
	# returning it, we have to re-encode it with fixparam().  that
	# will change if somehow Apache/mod_perl no longer decodes before
	# returning the data. -- pudge
	if ($saveuri =~ m[^/(?:%7[eE]|~)(.+)]) {
		my($nick, $op, $extra) = split /\//, $1, 4;
		for ($nick, $op, $extra) {
			s/%([a-fA-F0-9]{2})/pack('C', hex($1))/ge;
		}

		my $slashdb = getCurrentDB();
		my $uid = $slashdb->getUserUID($nick);
		$nick = fixparam($nick);	# make safe to pass back to script

		# maybe we should refactor this code a bit ...
		# have a hash that points op to args and script name -- pudge
		# e.g.:
		# my %ops = ( journal => ['/journal.pl', 'op=display'], ... );
		# $r->args($ops{$op}[1] . "&nick=$nick");
		# $r->uri($ops{$op}[0]);
		# $r->filename($constants->{basedir} . $ops{$op}[0]);

		if (!$uid) {
			$r->args("op=no_user");
			$r->uri('/users.pl');
			$r->filename($constants->{basedir} . '/users.pl');

		} elsif ($op eq 'journal') {
			my $args = "op=display&nick=$nick&uid=$uid";
			if ($extra && $extra =~ /^\d+$/) {
				$args .= "&id=$extra";
			} elsif ($extra && $extra =~ /^rss$/) {
				$args .= "&content_type=rss";
			} elsif ($extra && $extra =~ /^friends$/) {
				$args =~ s/display/friendview/;
			}
			$r->args($args);
			$r->uri('/journal.pl');
			$r->filename($constants->{basedir} . '/journal.pl');

		} elsif ($op eq 'discussions') {
			$r->args("op=creator_index&nick=$nick&uid=$uid");
			$r->uri('/comments.pl');
			$r->filename($constants->{basedir} . '/comments.pl');

		} elsif ($op eq 'pubkey') {
			$r->args("nick=$nick&uid=$uid");
			$r->uri('/pubkey.pl');
			$r->filename($constants->{basedir} . '/pubkey.pl');

		} elsif ($op eq 'submissions') {
			$r->args("nick=$nick&op=usersubmissions&uid=$uid");
			$r->uri('/users.pl');
			$r->filename($constants->{basedir} . '/users.pl');

		} elsif ($op eq 'comments') {
			$r->args("nick=$nick&op=usercomments&uid=$uid");
			$r->uri('/users.pl');
			$r->filename($constants->{basedir} . '/users.pl');

		} elsif ($op eq 'friends') {
			if ($extra eq 'friends') {
				$r->args("op=fof&nick=$nick&uid=$uid");
				$r->uri('/zoo.pl');
				$r->filename($constants->{basedir} . '/zoo.pl');
			} elsif ($extra eq 'foes') {
				$r->args("op=eof&nick=$nick&uid=$uid");
				$r->uri('/zoo.pl');
				$r->filename($constants->{basedir} . '/zoo.pl');
			} else {
				$r->args("op=friends&nick=$nick&uid=$uid");
				$r->uri('/zoo.pl');
				$r->filename($constants->{basedir} . '/zoo.pl');
			}
		} elsif ($op eq 'fans') {
			$r->args("op=fans&nick=$nick&uid=$uid");
			$r->uri('/zoo.pl');
			$r->filename($constants->{basedir} . '/zoo.pl');

		} elsif ($op eq 'freaks') {
			$r->args("op=freaks&nick=$nick&uid=$uid");
			$r->uri('/zoo.pl');
			$r->filename($constants->{basedir} . '/zoo.pl');

		} elsif ($op eq 'foes') {
			$r->args("op=foes&nick=$nick&uid=$uid");
			$r->uri('/zoo.pl');
			$r->filename($constants->{basedir} . '/zoo.pl');

		} elsif ($op eq 'amigos') {
			$r->args("op=friendview&nick=$nick&uid=$uid");
			$r->uri('/journal.pl');
			$r->filename($constants->{basedir} . '/journal.pl');

		} else {
			$r->args("nick=$nick&uid=$uid");
			$r->uri('/users.pl');
			$r->filename($constants->{basedir} . '/users.pl');
		}

		return OK;
	}

	return DECLINED;
}



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
Bender:This guy's not making any sense.  Can I kill him?  Please?
Bender:Hooray, we don't have to do anything!
Bender:I only speak enough binary to ask where the bathroom is.
Fry:There's a lot about my face you don't know.
Fry:These new hands are great. I'm gonna break them in tonight.
Fry:I refuse to testify on the grounds that my organs will be chopped up into a patty.
Fry:Leela, there's nothing wrong with anything.
Fry:Leela, Bender, we're going grave-robbing.
Fry:Where's Captain Bender? Off catastrophizing some other planet?
Fry:People said I was dumb but I proved them!
Fry:It's like a party in my mouth and everyone's throwing up.
Fry:I don't regret this, but I both rue and lament it.
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
Fry:I can burp the alphabet.  A, B, D ... no, wait ...
Fry:Why use my own legs like an idiot when I can use a Chickenwalker?
Fry:Hooray, we don't have to do anything!
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

# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Apache::User;

use strict;
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

	$request_start_time = Time::HiRes::time;

	# Ok, this will make it so that we can reliably use Apache->request
	Apache->request($r);

	my $cfg = Apache::ModuleConfig->get($r);
	my $dbcfg = Apache::ModuleConfig->get($r, 'Slash::Apache');
	my $constants = getCurrentStatic();
	my $slashdb = $dbcfg->{slashdb};
	my $apr = Apache::Request->new($r);
	
	my $hostname = $r->header_in('host');

	$r->err_header_out('X-Powered-By' => "Slash $Slash::VERSION");
	random($r);

	# let pass unless / or .pl
	my $uri = $r->uri;
	if ($constants->{rootdir}) {
		my $path = URI->new($constants->{rootdir})->path;
		$uri =~ s/^\Q$path//;
	}

	if (!$cfg->{auth} && $uri !~ /\.pl$/ && $uri !~ /\.tmpl$/) {
		$r->subprocess_env(SLASH_USER => $constants->{anonymous_coward_uid});
		createCurrentUser();
		createCurrentForm();
		createCurrentCookie();
		if (!$constants->{allow_nonadmin_ssl}
			&& Slash::Apache::ConnectionIsSSL() ) {
			# Accessing non-dynamic URL on SSL webserver; redirect
			# to the non-SSL URL.
			my $newloc = $uri;
			$newloc .= "?" . $r->args if $r->args;
			$r->err_header_out(Location =>
				URI->new_abs($newloc,
					$constants->{absolutedir}) );
			return REDIRECT;
		}
		return OK;
	}

	$slashdb->sqlConnect;

	my $method = $r->method;
	# Don't remove this. This solves a known bug in Apache -- brian
	$r->method('GET');

	my $form = filter_params($apr);
	$form->{query_apache} = $apr;
	@{$form}{keys  %{$constants->{form_override}}} =
		values %{$constants->{form_override}};
	my $cookies = Apache::Cookie->fetch;

	# So we are either going to pick the user up from
	# the form, a cookie, or they will be anonymous
	my $uid;
	my $op = $form->{op} || '';

	if (($op eq 'userlogin' || $form->{rlogin}) && length($form->{upasswd}) > 1) {
		my $tmpuid = $slashdb->getUserUID($form->{unickname});
		($uid, my($newpass)) = userLogin($tmpuid, $form->{upasswd});

		# here we want to redirect only if the user has posted via
		# GET, and the user has logged in successfully

		if ($method eq 'GET' && $uid && ! isAnon($uid)) {
			$form->{returnto} =~ s/%3D/=/;
			$form->{returnto} =~ s/%3F/?/;
			$form->{returnto} = url2abs($newpass
				? "$constants->{rootdir}/users.pl?op=changepasswd" .
					# XXX This "note" field is ignored now...
					# right?  - Jamie 2002/09/17
				  "&note=Please+change+your+password+now!"
				: $form->{returnto}
					? $form->{returnto}
					: $uri
			);
			# not working ... move out into users.pl and index.pl
			# I may know why this is the case, we may need
			# to send a custom errormessage. -Brian
#			$r->err_header_out(Location => $newurl);
#			return REDIRECT;
		}

	} elsif ($op eq 'userclose') {
		# It may be faster to just let the delete fail then test -Brian
		# well, uid is undef here ... can't use it to test
		# until it is defined :-) -- pudge
		# Went boom without if. --Brian
		# When did we comment out this? This means that even
		# if an author logs out, the other authors will
		# not know about it. Bad....
		#$slashdb->deleteSession(); #  if $slashdb->getUser($uid, 'seclev') >= 99;
		delete $cookies->{user};
		setCookie('user', '');

	} elsif ($cookies->{user} and $cookies->{user}->value) {
		my($tmpuid, $password) = eatUserCookie($cookies->{user}->value);
		($uid, my($cookpasswd)) =
			$slashdb->getUserAuthenticate($tmpuid, $password);

		if ($uid) {
			# set cookie every time, in case session_login
			# value changes, or time is almost expired on
			# saved cookie, or password changes, or ...

			# can't set it every time, it upsets people.
			# we need to set it only if password or
			# session_login changes. -- pudge

# 			setCookie('user', bakeUserCookie($uid, $cookpasswd),
# 				$slashdb->getUser($uid, 'session_login')
# 			);
		} else {
			$uid = $constants->{anonymous_coward_uid};
			delete $cookies->{user};
			setCookie('user', '');
		}
	}

	# This has happened to me a couple of times.
	delete $cookies->{user} if ($cookies->{user} and !($cookies->{user}->value));

	$uid = $constants->{anonymous_coward_uid} unless defined $uid;

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
	srand(time ^ ($$ + ($$ << 15))) unless $srand_called;
	$srand_called ||= 1;

	my $user = prepareUser($uid, $form, $uri, $cookies, $method);
	$user->{state}{_dynamic_page} = 1;
	createCurrentUser($user);
	createCurrentForm($form);
	if ( ($user->{seclev} <= 1 && !$user->{state}{lostprivs})
		&& !$constants->{allow_nonadmin_ssl}
		&& Slash::Apache::ConnectionIsSSL()
		&& !(
			# If the user is trying to log in, they are allowed
			# to do so on the SSL server.  Logging in means the
			# users.pl script and either an empty op or the
			# 'userlogin' op.
			$uri =~ m{^/users\.pl}
			&& (!$form->{op} || $form->{op} eq 'userlogin')
		) ) {                             
		# User is not an admin but is trying to connect to an admin-only
		# webserver.  Redirect them to the non-SSL URL.
		my $newloc = $uri;
		$newloc .= "?" . $r->args if $r->args;
		$r->err_header_out(Location =>
			URI->new_abs($newloc, $constants->{absolutedir}));
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
}

########################################################
sub userLogin {
	my($name, $passwd) = @_;
	my $r = Apache->request;
	my $slashdb = getCurrentDB();

	# Do we want to allow logins with encrypted passwords? -- pudge
#	$passwd = substr $passwd, 0, 20;
	my($uid, $cookpasswd, $newpass) =
		$slashdb->getUserAuthenticate($name, $passwd); #, 1

	if (!isAnon($uid)) {
		setCookie('user', bakeUserCookie($uid, $cookpasswd),
			$slashdb->getUser($uid, 'session_login'));
		return($uid, $newpass);
	} else {
		return getCurrentStatic('anonymous_coward_uid');
	}
}

########################################################
sub userdir_handler {
	my($r) = @_;

	my $constants = getCurrentStatic();

	# note that, contrary to the RFC, a + in this handler
	# will be treated as a space; the only way to get a +
	# is to encode it, such as %2B
	my $uri = $r->the_request;
	$uri =~ s/^\S+\s+//;
	$uri =~ s/\s+\S+$//;
	$uri =~ s/\+/ /g;
	my $saveuri = $uri;
	$uri =~ s/%([a-fA-F0-9]{2})/pack('C', hex($1))/ge;

	if ($constants->{rootdir}) {
		my $path = URI->new($constants->{rootdir})->path;
		$uri =~ s/^\Q$path//;
	}

	# /my/ or /my can match, but not /mything
	if (($uri =~ m[^/~/(.+)]) or ($uri =~ m[^/my (?: /(.*) | /? ) $]x)) {
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
				$r->args("op=changepasswd");
				$r->uri('/users.pl');
				$r->filename($constants->{basedir} . '/users.pl');
			} elsif ($op eq 'logout') {
				$r->args("op=userclose");
				$r->uri('/users.pl');
				$r->filename($constants->{basedir} . '/users.pl');
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
			$r->uri('/users.pl');
			$r->filename($constants->{basedir} . '/users.pl');
			return OK;
		}
	}

	# assuming Apache/mod_perl is decoding the URL in ->uri before
	# returning it, we have to re-encode it with fixparam().  that
	# will change if somehow Apache/mod_perl no longer decodes before
	# returning the data. -- pudge
	if ($saveuri =~ m[^/(?:%7[eE]|~)(.+)]) {
		# this won't work if the nick has a "/" in it ...
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
		# Not against it, or something like it. This is getting a bit long. 
		# I would rather prefer it did not turn out like ops have though. -Brian
		# what do you mean? -- pudge

		unless ($uid) {
			$r->args("op=no_user");
			$r->uri('/users.pl');
			$r->filename($constants->{basedir} . '/users.pl');

		} elsif ($op eq 'journal') {
			my $args = "op=display&nick=$nick&uid=$uid";
			if ($extra && $extra =~ /^\d+$/) {
				$args .= "&id=$extra";
			} elsif ($extra && $extra =~ /^friends$/) {
				$args = "op=friendview";
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
Bender:I hate people who love me.  And they hate me.
Bender:Oh no! Not the magnet!
Bender:Bender's a genius!
Bender:Well I don't have anything else planned for today, let's get drunk!
Bender:Forget your stupid theme park!  I'm gonna make my own!  With hookers!  And blackjack!  In fact, forget the theme park!
Bender:Oh, no room for Bender, huh?  Fine.  I'll go build my own lunar lander.  With blackjack.  And hookers.  In fact, forget the lunar lander and the blackjack!  Ah, screw the whole thing.
Bender:Oh, so, just 'cause a robot wants to kill humans that makes him a radical?
Bender:There's nothing wrong with murder, just as long as you let Bender whet his beak.
Bender:Bite my shiny, metal ass!
Bender:The laws of science be a harsh mistress.
Bender:In the event of an emergency, my ass can be used as a flotation device.
Bender:Like most of life's problems, this one can be solved with bending.
Bender:Honey, I wouldn't talk about taste if I was wearing a lime green tank top.
Bender:A woman like that you gotta romance first!
Bender:OK, but I don't want anyone thinking we're robosexuals.
Bender:Hey Fry, I'm steering with my ass!
Bender:Care to contribute to the Anti-Mugging-You Fund?
Bender:Want me to smack the corpse around a little?
Bender:My full name is Bender Bending Rodriguez.
Bender:My life, and by extension everyone else's, is meaningless.
Fry:Why couldn't she be the other kind of mermaid, with the fish part on the top and the human part on the bottom?
Fry:There's a lot about my face you don't know.
Fry:Drugs are for losers.  And hypnosis is for losers with big weird eyebrows.
Fry:These new hands are great.  I'm gonna break them in tonight.
Fry:I refuse to testify on the grounds that my organs will be chopped up into a patty.
Fry:Leela, there's nothing wrong with anything.
Fry:Augh, I am so unlucky. I've run over black cats that were luckier than me.
Fry:That's it! You can only take my money for so long before you take it all and I say enough! 
Fry:Leela, Bender, we're going grave-robbing.
Fry:Where's Captain Bender? Off catastrophizing some other planet?
Fry:Would you cram a sock in it, Bender? Those aren't even medals! They're bottle caps and pepperoni slices.
Fry:To Captain Bender! He's the best! ...at being a big jerk who's stupid and his big ugly face is as dumb as a butt!
Fry:People said I was dumb but I proved them!
Fry:It's like a party in my mouth and everyone's throwing up.
Fry:Nowadays people aren't interested in art that's not tattooed on fat guys.
Fry:I don't regret this, but I both rue and lament it.
Fry:I'm gonna be a famous hero just like Neil Armstrong and those other brave guys no one ever heard of.
Fry:Well, thanks to the Internet I'm now bored with sex.  Is there a place on the web that panders to my lust for violence?
Fry:Maybe you can't understand this, but I finally found what I need to be happy, and it's not friends, it's things.
Fry:I heard one time you single-handedly defeated a hoard of rampaging somethings in the something something system.
Fry:I'm never gonna get used to the thirty-first century. Caffeinated bacon?
Fry:Professor, please, the fate of the world depends on you getting to second base with Mom.
Fry:They're great! They're like sex except I'm having them.
Fry:No, no, I was just picking my nose.
Fry:How can I live my life if I can't tell good from evil?
Fry:That's a chick show. I prefer programs of the genre: World's Blankiest Blank.
Fry:But this is HDTV. It's got better resolution than the real world.
Fry:I'm gonna be a science fiction hero, just like Uhura, or Captain Janeway, or Xena!
Fry:He's an animal. He belongs in the wild. Or in the circus on one of those tiny tricycles. Now that's entertainment.
Fry:I learned how to handle delicate social situations from a little show called "Three's Company."
Fry:Make up some feelings and tell her you have them.
Fry:I'm flattered, really. If I was gonna do it with a big freaky mud bug, you'd be way up the list.
Fry:I'm not a robot like you. I don't like having disks crammed into me... unless they're Oreos, and then only in the mouth.
Fry:I must be a robot. Why else would human women refuse to date me?
Fry:If this is some kind of scam, I don't get it.  You already have my power of attorney.
Fry:Hey look, it's that guy you are!
Fry:That doesn't look like an "L", unless you count lower case.
Fry:Hardy Boys: too easy.  Nancy Drew: too hard!
Fry:And then when I feel so stuffed I can't eat any more, I just use the restroom, and then I *can* eat more!
Fry:I'm going to continue never washing this cheek again.
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
method of authenication. The rest of Slash depends
on finding the UID of the user in the SLASH_USER
environmental variable.

=head1 SEE ALSO

Slash(3), Slash::Apache(3).

=cut

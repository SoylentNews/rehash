# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Apache::User;

use strict;
use Apache; 
use Apache::Constants qw(:common REDIRECT);
use Apache::Cookie; 
use Apache::File; 
use Apache::ModuleConfig;
use AutoLoader ();
use DynaLoader ();
use Slash::DB;
use Slash::Utility;
use URI ();
use vars qw($REVISION $VERSION @ISA @QUOTES);

@ISA		= qw(DynaLoader);
$VERSION	= '2.000000';	# v2.0.0
($REVISION)	= ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

bootstrap Slash::Apache::User $VERSION;

# BENDER: Oh, so, just 'cause a robot wants to kill humans
# that makes him a radical?

sub SlashEnableENV ($$$) {
	my($cfg, $params, $flag) = @_;
	$cfg->{env} = $flag;
}

sub SlashAuthAll ($$$) {
	my($cfg, $params, $flag) = @_;
	$cfg->{auth} = $flag;
}

# handler method
sub handler {
	my($r) = @_;

	return DECLINED unless $r->is_main;

	# Ok, this will make it so that we can reliably use Apache->request
	Apache->request($r);

	my $cfg = Apache::ModuleConfig->get($r);
	my $dbcfg = Apache::ModuleConfig->get($r, 'Slash::Apache');
	my $constants = $dbcfg->{constants};
	my $slashdb = $dbcfg->{slashdb};

	$r->err_header_out('X-Powered-By' => "Slash $Slash::VERSION");
	random($r);

	# let pass unless / or .pl
	my $uri = $r->uri;
	if ($constants->{rootdir}) {
		my $path = URI->new($constants->{rootdir})->path;
		$uri =~ s/^\Q$path//;
	}

	unless ($cfg->{auth}) {
		#unless ($uri =~ m[(?:^/$)|(?:\.pl$)]) 
		unless ($uri =~ m[(?:\.pl$)]) {
			$r->subprocess_env(SLASH_USER => $constants->{anonymous_coward_uid});
			createCurrentUser();
			createCurrentForm();
			createCurrentCookie();
			return OK;
		}
	}

	$slashdb->sqlConnect;
	#Ok, this solves the annoying issue of not having true OOP in perl
	# You can comment this out if you want if you only use one database type
	# long term, it might be nice to create new classes for each slashdb
	# object, and set @ISA for each class, or make each other class inherit
	# from Slash::DB instead of vice versa ...
	$slashdb->fixup;

	my $method = $r->method;
	# Don't remove this. This solves a known bug in Apache -- brian
	$r->method('GET');

	my $form = filter_params($r->args, $r->content);
	my $cookies = Apache::Cookie->fetch;

	# So we are either going to pick the user up from 
	# the form, a cookie, or they will be anonymous
	my $uid;
	my $op = $form->{op} || '';

	if (($op eq 'userlogin' || $form->{rlogin} ) && length($form->{upasswd}) > 1) {
		my $tmpuid = $slashdb->getUserUID($form->{unickname});
		($uid, my($newpass)) = userLogin($tmpuid, $form->{upasswd});

		# here we want to redirect only if the user has posted via
		# GET, and the user has logged in successfully

		if ($method eq 'GET' && $uid && ! isAnon($uid)) {
			$form->{returnto} = url2abs($newpass
				? "$constants->{rootdir}/users.pl?op=edit" .
				  "user&note=Please+change+your+password+now!"
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

	} elsif ($op eq 'userclose' ) {
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
			setCookie('user', bakeUserCookie($uid, $cookpasswd),
				$slashdb->getUser($uid, 'session_login')
			);
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
	return DECLINED if $cfg->{auth} && isAnon($uid);

	createCurrentUser(prepareUser($uid, $form, $uri, $cookies));
	createCurrentForm($form);
	createCurrentCookie($cookies);
	createEnv($r) if $cfg->{env};
	authors($r) if $form->{'slashcode_authors'};

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
	$r->header_out('X-Bender' => $QUOTES[int(rand(@QUOTES))]);
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
	my $cfg = Apache::ModuleConfig->get($r, 'Slash::Apache');
	my $slashdb = getCurrentDB();

	# Do we want to allow logins with encrypted passwords? -- pudge
#	$passwd = substr $passwd, 0, 20;
	my($uid, $cookpasswd, $newpass) =
		$slashdb->getUserAuthenticate($name, $passwd); #, 1

	if (!isAnon($uid)) {
		setCookie('user', bakeUserCookie($uid, $cookpasswd));
		return($uid, $newpass);
	} else {
		return getCurrentStatic('anonymous_coward_uid');
	}
}

########################################################
sub userdir_handler {
	my($r) = @_;

	my $constants = getCurrentStatic();
	my $uri = $r->uri;
	if ($constants->{rootdir}) {
		my $path = URI->new($constants->{rootdir})->path;
		$uri =~ s/^\Q$path//;
	}

	if ($uri =~ m[^/~(.*)]) {
		my $clean = $1;
		$clean =~ s|\/.*$||;
		$r->args("nick=$clean");
		$r->uri('/users.pl');
		$r->filename($constants->{basedir} . '/users.pl');
		return OK;
	}

	return DECLINED;
}


########################################################
#
sub DESTROY { }

@QUOTES = (
	'Fry, of all the friends I\'ve had ... you\'re the first.',
	'I hate people who love me.  And they hate me.',
	'Oh no! Not the magnet!',
	'Bender\'s a genius!',
	'Well I don\'t have anything else planned for today, let\'s get drunk!',
	'Forget your stupid theme park!  I\'m gonna make my own!  With hookers!  And blackjack!  In fact, forget the theme park!',
	'Oh, no room for Bender, huh?  Fine.  I\'ll go build my own lunar lander.  With blackjack.  And hookers.  In fact, forget the lunar lander and the blackjack!  Ah, screw the whole thing.',
	'Oh, so, just \'cause a robot wants to kill humans that makes him a radical?',
	'There\'s nothing wrong with murder, just as long as you let Bender whet his beak.',
	'Bite my shiny, metal ass!',
	'The laws of science be a harsh mistress.',
	'In the event of an emergency, my ass can be used as a flotation device.',
	'Like most of life\'s problems, this one can be solved with bending.',
	'Honey, I wouldn\'t talk about taste if I was wearing a lime green tank top.',
	'A woman like that you gotta romance first!',
	'OK, but I don\'t want anyone thinking we\'re robosexuals.',
	'Hey Fry, I\'m steering with my ass!',
	'Care to contribute to the Anti-Mugging-You Fund?',
	'Want me to smack the corpse around a little?',
	'My full name is Bender Bending Rodriguez.',
);


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

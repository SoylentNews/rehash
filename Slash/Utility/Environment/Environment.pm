# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Utility::Environment;

=head1 NAME

Slash::Utility::Environment - SHORT DESCRIPTION for Slash


=head1 SYNOPSIS

	use Slash::Utility;
	# do not use this module directly

=head1 DESCRIPTION

LONG DESCRIPTION.


=head1 EXPORTED FUNCTIONS

=cut

use strict;
use Apache::ModuleConfig;
use Digest::MD5 'md5_hex';

use base 'Exporter';
use vars qw($VERSION @EXPORT);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;
@EXPORT	   = qw(
	createCurrentAnonymousCoward
	createCurrentCookie
	createCurrentDB
	createCurrentForm
	createCurrentHostname
	createCurrentStatic
	createCurrentUser
	createCurrentVirtualUser

	setCurrentForm
	setCurrentUser

	getCurrentAnonymousCoward
	getCurrentCookie
	getCurrentDB
	getCurrentForm
	getCurrentMenu
	getCurrentStatic
	getCurrentUser
	getCurrentVirtualUser
	getCurrentCache

	createEnvironment
	getObject
	getAnonId
	isAnon
	prepareUser
	filter_params

	bakeUserCookie
	eatUserCookie
	setCookie

	createLog
	errorLog
	writeLog
);

# These are file-scoped variables that are used when you need to use the
# set methods when not running under mod_perl
my($static_user, $static_form, $static_constants, $static_site_constants, 
	$static_db, $static_anonymous_coward, $static_cookie,
	$static_virtual_user, $static_objects, $static_cache, $static_hostname);

# FRY: I don't regret this.  But I both rue and lament it.

#========================================================================

=head2 getCurrentMenu([NAME])

Returns the menu for the resource requested.

=over 4

=item Parameters

=over 4

=item NAME

Name of the menu that you want to fetch.  If not supplied,
menu named after active script will be used (i.e., the "users"
menu for "users.pl").

=back

=item Return value

A reference to an array with the menu in it is returned.

=back

=cut

sub getCurrentMenu {
	my($menu) = @_;
	my($user, @menus, $user_menu);

	# do we want to bother with menus at all for static pages?
	# i can see why we might ... i dunno -- pudge
	#
	# Well, yes. Since createMenu() may be used in a header
	# and a footer, if we don't generate menus on static pages,
	# the page itself will be busted. We've already run into this
	# for one site, so took a stab at fixing it. -- Cliff
	if ($ENV{GATEWAY_INTERFACE}) {;
		$user = getCurrentUser();

		unless ($menu) {
			($menu = $ENV{SCRIPT_NAME}) =~ s/\.pl$//;
		}

		my $r = Apache->request;
		my $cfg = Apache::ModuleConfig->get($r, 'Slash::Apache');

		return unless $cfg->{menus}{$menu};
		@menus = @{$cfg->{menus}{$menu}};
	} else {
		# Load menus direct from the database.
		my $slashdb = getCurrentDB();
		my $menus = $slashdb->getMenus();

		@menus = @{$menus->{$menu}} if exists $menus->{$menu};
	}
	
	if ($user && ($user_menu = $user->{menus}{$menu})) {
		push @menus, values %$user_menu;
	}

	return \@menus;
}

#========================================================================

=head2 getCurrentUser([MEMBER])

Returns the current authenicated user.

=over 4

=item Parameters

=over 4

=item MEMBER

A member from the users record to be returned.

=back

=item Return value

A hash reference with the user information is returned unless VALUE is passed. If
MEMBER is passed in then only its value will be returned.

=back

=cut

sub getCurrentUser {
	my($value) = @_;
	my $user;

	if ($ENV{GATEWAY_INTERFACE} && (my $r = Apache->request)) {
		my $cfg = Apache::ModuleConfig->get($r, 'Slash::Apache');
		$user = $cfg->{'user'} ||= {};
	} else {
		$user = $static_user   ||= {};
	}

	# i think we want to test defined($foo), not just $foo, right?
	if ($value) {
		return defined($user->{$value})
			? $user->{$value}
			: undef;
	} else {
		return $user;
	}
}

#========================================================================

=head2 setCurrentUser(MEMBER, VALUE)

Sets a value for the current user.  It will not be permanently stored.

=over 4

=item Parameters

=over 4

=item MEMBER

The member to store VALUE in.

=item VALUE

VALUE to be stored in the current user hash.

=back

=item Return value

The passed value.

=back

=cut

sub setCurrentUser {
	my($key, $value) = @_;
	my $user;

	if ($ENV{GATEWAY_INTERFACE}) {
		my $r = Apache->request;
		my $cfg = Apache::ModuleConfig->get($r, 'Slash::Apache');
		$user = $cfg->{'user'};
	} else {
		$user = $static_user;
	}

	$user->{$key} = $value;
}

#========================================================================

=head2 setCurrentForm(MEMBER, VALUE)

Sets a value for the current user.  It will not be permanently stored.

=over 4

=item Parameters

=over 4

=item MEMBER

The member to store VALUE in.

=item VALUE

VALUE to be stored in the current user hash.

=back

=item Return value

The passed value.

=back

=cut

sub setCurrentForm {
	my($key, $value) = @_;
	my $form;

	if ($ENV{GATEWAY_INTERFACE}) {
		my $r = Apache->request;
		my $cfg = Apache::ModuleConfig->get($r, 'Slash::Apache');
		$form = $cfg->{'form'};
	} else {
		$form = $static_form;
	}

	$form->{$key} = $value;
}

#========================================================================

=head2 createCurrentUser(USER)

Creates the current user.

=over 4

=item Parameters

=over 4

=item USER

USER to be inserted into current user.

=back

=item Return value

Returns no value.

=back

=cut

sub createCurrentUser {
	my($user) = @_;

	$user ||= {};

	if ($ENV{GATEWAY_INTERFACE} && (my $r = Apache->request)) {
		my $cfg = Apache::ModuleConfig->get($r, 'Slash::Apache');
		$cfg->{'user'} = $user;
	} else {
		$static_user = $user;
	}
}

#========================================================================

=head2 getCurrentForm([MEMBER])

Returns the current form.

=over 4

=item Parameters

=over 4

=item MEMBER

A member from the forms record to be returned.

=back

=item Return value

A hash reference with the form information is returned unless VALUE is passed.  If
MEMBER is passed in then only its value will be returned.

=back

=cut

sub getCurrentForm {
	my($value) = @_;
	my $form;

	if ($ENV{GATEWAY_INTERFACE} && (my $r = Apache->request)) {
		my $cfg = Apache::ModuleConfig->get($r, 'Slash::Apache');
		$form = $cfg->{'form'};
	} else {
		$form = $static_form;
	}

	if ($value) {
		return defined($form->{$value})
			? $form->{$value}
			: undef;
	} else {
		return $form;
	}
}

#========================================================================

=head2 createCurrentForm(FORM)

Creates the current form.

=over 4

=item Parameters

=over 4

=item FORM

FORM to be inserted into current form.

=back

=item Return value

Returns no value.

=back

=cut

sub createCurrentForm {
	my($form) = @_;

	$form ||= {};

	if ($ENV{GATEWAY_INTERFACE}) {
		my $r = Apache->request;
		my $cfg = Apache::ModuleConfig->get($r, 'Slash::Apache');
		$cfg->{'form'} = $form;
	} else {
		$static_form = $form;
	}
}

#========================================================================

=head2 getCurrentCookie([MEMBER])

Returns the current cookie.

=over 4

=item Parameters

=over 4

=item MEMBER

A member from the cookies record to be returned.

=back

=item Return value

A hash reference with the cookie incookieation is returned
unless VALUE is passed.  If MEMBER is passed in then
only its value will be returned.

=back

=cut

sub getCurrentCookie {
	my($value) = @_;
	my $cookie;

	if ($ENV{GATEWAY_INTERFACE}) {
		my $r = Apache->request;
		my $cfg = Apache::ModuleConfig->get($r, 'Slash::Apache');
		$cookie = $cfg->{'cookie'};
	} else {
		$cookie = $static_cookie;
	}

	if ($value) {
		return defined($cookie->{$value})
			? $cookie->{$value}
			: undef;
	} else {
		return $cookie;
	}
}

#========================================================================

=head2 createCurrentCookie(COOKIE)

Creates the current cookie.

=over 4

=item Parameters

=over 4

=item COOKIE

COOKIE to be inserted into current cookie.

=back

=item Return value

Returns no value.

=back

=cut

sub createCurrentCookie {
	my($cookie) = @_;

	$cookie ||= {};

	if ($ENV{GATEWAY_INTERFACE}) {
		my $r = Apache->request;
		my $cfg = Apache::ModuleConfig->get($r, 'Slash::Apache');
		$cfg->{'cookie'} = $cookie;
	} else {
		$static_cookie = $cookie;
	}
}

#========================================================================

=head2 getCurrentStatic([MEMBER])

Returns the current static variables (or variable).

=over 4

=item Parameters

=over 4

=item MEMBER

A member from the static record to be returned.

=back

=item Return value

A hash reference with the static information is returned unless MEMBER is passed. If
MEMBER is passed in then only its value will be returned.

=back

=cut

sub getCurrentStatic {
	my($value) = @_;
	my $constants;

	if ($ENV{GATEWAY_INTERFACE} && (my $r = Apache->request)) {
		my $const_cfg = Apache::ModuleConfig->get($r, 'Slash::Apache');
		my $hostname = $r->header_in('host');
		if ($const_cfg->{'site_constants'}{$hostname}) { 
			$constants = $const_cfg->{site_constants}{$hostname};
		} else {
			$constants = $const_cfg->{'constants'};
		}
	} else {
		if ($static_site_constants->{$static_hostname}) {
			$constants = $static_site_constants->{$static_hostname};
		} else {
			$constants = $static_constants;
		}
	}

	if ($value) {
		return defined($constants->{$value})
			? $constants->{$value}
			: undef;
	} else {
		return $constants;
	}
}

#========================================================================

=head2 createCurrentStatic(HASH)

Creates the current static information for non Apache scripts.

=over 4

=item Parameters

=over 4

=item HASH

A hash that is to be used in scripts not running in Apache to simulate a
script running under Apache.

=back

=item Return value

Returns no value.

=back

=cut

sub createCurrentStatic {
	($static_constants, $static_site_constants) = @_;
}

#========================================================================

=head2 createCurrentHostname(HOSTNAME)

Allows you to set a host so that constants will behave properly.

=over 4

=item Parameters

=over 4

=item HOSTNAME

A name of a host to use to force constants to think it is being used by a host.

=back

=item Return value

Returns no value.

=back

=cut

sub createCurrentHostname {
	($static_hostname) = @_;
}

#========================================================================

=head2 getCurrentAnonymousCoward([MEMBER])

Returns the current anonymous corward (or value from that object).

=over 4

=item Parameters

=over 4

=item MEMBER

A member from the AC record to be returned.

=back

=item Return value

If MEMBER, then that value is returned; else, the hash containing all
the AC info will be returned.

=back

=cut

sub getCurrentAnonymousCoward {
	my($value) = @_;

	if ($ENV{GATEWAY_INTERFACE}) {
		my $r = Apache->request;
		my $const_cfg = Apache::ModuleConfig->get($r, 'Slash::Apache');
		if ($value) {
			return $const_cfg->{'anonymous_coward'}{$value};
		} else {
			my %coward = %{$const_cfg->{'anonymous_coward'}};
			return \%coward;
		}
	} else {
		if ($value) {
			return $static_anonymous_coward->{$value};
		} else {
			my %coward = %{$static_anonymous_coward};
			return \%coward;
		}
	}
}

#========================================================================

=head2 createCurrentAnonymousCoward(HASH)

Creates the current anonymous coward for non Apache scripts.

=over 4

=item Parameters

=over 4

=item HASH

A hash that is to be used in scripts not running in Apache to simulate a
script running under Apache.

=back

=item Return value

Returns no value.

=back

=cut

sub createCurrentAnonymousCoward {
	($static_anonymous_coward) = @_;
}

#========================================================================

=head2 getCurrentVirtualUser()

Returns the current virtual user that the site is running under.

=over 4

=item Return value

The current virtual user that the site is running under.

=back

=cut

sub getCurrentVirtualUser {
	if ($ENV{GATEWAY_INTERFACE} && (my $r = Apache->request)) {
		my $cfg = Apache::ModuleConfig->get($r, 'Slash::Apache');
		return $cfg->{'VirtualUser'};
	} else {
		return $static_virtual_user;
	}
}

#========================================================================

=head2 createCurrentVirtualUser(VIRTUAL_USER)

Creates the current virtual user for non Apache scripts.

=over 4

=item Parameters

=over 4

=item VIRTUAL_USER

The current virtual user that is to be used in scripts not running in Apache
to simulate a script running under Apache.

=back

=item Return value

Returns no value.

=back

=cut

sub createCurrentVirtualUser {
	($static_virtual_user) = @_;
}

#========================================================================

=head2 getCurrentDB()

Returns the current Slash::DB object.

=over 4

=item Return value

Returns the current Slash::DB object.

=back

=cut

sub getCurrentDB {
	my $slashdb;

	if ($ENV{GATEWAY_INTERFACE} && (my $r = Apache->request)) {
		my $const_cfg = Apache::ModuleConfig->get($r, 'Slash::Apache');
		$slashdb = $const_cfg->{slashdb};
	} else {
		$slashdb = $static_db;
	}

	return $slashdb;
}

#========================================================================

=head2 createCurrentDB(SLASHDB)

Creates the current DB object for scripts not running under Apache.

=over 4

=item Parameters

=over 4

=item SLASHDB

Pass in a Slash::DB object to be used for scripts not running
in Apache.

=back

=item Return value

Returns no value.

=back

=cut

sub createCurrentDB {
	($static_db) = @_;
}

#========================================================================

=head2 isAnon(UID)

Tests to see if the uid passed in is an anonymous coward.

=over 4

=item Parameters

=over 4

=item UID

Value UID.

=back

=item Return value

Returns true if the UID is an anonymous coward, otherwise false.

=back

=cut

sub isAnon {
	my($uid) = @_;
	# this might be undefined in the event of a comment preview
	# when a data structure is not fully filled out, etc.
	return 1 if	!defined($uid)		# no undef
		||	$uid eq ''		# no empty string
		||	$uid =~ /[^0-9]/	# only integers
		||	$uid < 1		# only positive
	;
	return $uid == getCurrentStatic('anonymous_coward_uid');
}

#========================================================================

=head2 getAnonId([FORMKEY])

Creates an anonymous ID that is used to set an AC cookie,
with some random data (well, as random as random gets)

=over 4

=item Parameters

=over 4

=item FORMKEY

Return the same value as normal, but without prepending with a '-1-'.
The normal case, with '-1-', is for easy identification of cookies.
This case is for use with formkeys.

=back

=item Return value

A random value based on alphanumeric characters

=back

=cut

{
	my @chars = (0..9, 'A'..'Z', 'a'..'z');
	sub getAnonId {
		my $str;
		$str = '-1-' unless $_[0];
		$str .= join('', map { $chars[rand @chars] }  0 .. 9);
		return $str;
	}
}

#========================================================================

=head2 bakeUserCookie(UID, PASSWD)

Bakes (creates) a user cookie from its ingredients (UID, PASSWD).

Currently cookie is hexified: this should be changed, no need anymore,
perhaps?  -- pudge

=over 4

=item Parameters

=over 4

=item UID

User ID.

=item PASSWD

Password.

=back

=item Return value

Created cookie.

=back

=cut

# create a user cookie from ingredients
sub bakeUserCookie {
	my($uid, $passwd) = @_;
	my $cookie = $uid . '::' . $passwd;
	$cookie =~ s/(.)/sprintf("%%%02x", ord($1))/ge;
	return $cookie;
}

#========================================================================

=head2 eatUserCookie(COOKIE)

Digests (parses) a user cookie, returning it to its original ingredients
(UID, password).

Currently cookie is hexified: this should be changed, no need anymore,
perhaps?  -- pudge

=over 4

=item Parameters

=over 4

=item COOKIE

Cookie to be parsed.

=back

=item Return value

The UID and password encoded in the cookie.

=back

=cut

sub eatUserCookie {
	my($cookie) = @_;
	$cookie =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack('C', hex($1))/ge;
	my($uid, $passwd) = split(/::/, $cookie, 2);
	return($uid, $passwd);
}

#========================================================================

=head2 setCookie(NAME, VALUE, SESSION)

Creates a cookie and places it into the outbound headers.  Can be
called multiple times to set multiple cookies.

=over 4

=item Parameters

=over 4

=item NAME

NAme of the cookie.

=item VALUE

Value to be placed in the cookie.

=item SESSION

Flag to determine if the cookie should be a session cookie.

=back

=item Return value

No value is returned.

=back

=cut

sub setCookie {
	return unless $ENV{GATEWAY_INTERFACE};

	my($name, $val, $session) = @_;
	return unless $name;

	my $r = Apache->request;
	my $constants = getCurrentStatic();

	# We need to actually determine domain from preferences,
	# not from the server, so the site admin can specify
	# special preferences if they want to. -- pudge
	my $cookiedomain = $constants->{cookiedomain};
	my $cookiepath   = $constants->{cookiepath};

	# note that domain is not a *host*, it is a *domain*,
	# so "slashdot.org" is an invalid domain, but
	# ".slashdot.org" is OK.  the only way to set a cookie
	# to a *host* is to leave the domain blank, which is
	# why we set the first cookie with no domain. -- pudge

	# domain must start with a '.' and have one more '.'
	# embedded in it, else we ignore it
	my $domain = ($cookiedomain && $cookiedomain =~ /^\..+\./)
		? $cookiedomain
		: '';

	my %cookiehash = (
		-name    =>  $name,
		-value   =>  $val || 'nobody',
		-path    =>  $cookiepath
	);

	if ($constants->{cookiesecure}) {
		my $subr = $r->lookup_uri($r->uri);
		if ($subr && $subr->subprocess_env('HTTPS') eq 'on') {
			$cookiehash{-secure} = 1;
		}
	}

	my $cookie = Apache::Cookie->new($r, %cookiehash);

	$cookie->expires('+1y') unless $session;
	$cookie->bake;

	if ($domain) {
		$cookie->domain($domain);
		$cookie->bake;
	}
}

#========================================================================

=head2 prepareUser(UID, FORM, URI [, COOKIES])

This is called to initialize the user.  It is called from
Slash::Apache::User::handler, and from createEnvironment (so it
can set up a user in "command line" mode).  See those two functions
to see how to call this function in each kind of environment.

=over 4

=item Parameters

=over 4

=item UID

The UID of the user.  Can be anonymous coward.  Will be anonymous
coward if uid is not defined.

=item FORM

The form data (which may be the same data returned by getCurrentForm).

=item URI

The URI of the page the user is on.

=item COOKIES

An Apache::Cookie object (not used in "command line" mode).

=back

=item Return value

The prepared user data.

=item Side effects

Sets some cookies in Apache mode, sets currentPage (for templates) and
bunches of other user datum.

=back

=cut

sub prepareUser {
	# we must get form data and cookies, because we are preparing it here
	my($uid, $form, $uri, $cookies, $method) = @_;
	my($slashdb, $constants, $user, $hostip);

	$cookies ||= {};
	$slashdb = getCurrentDB();
	$constants = getCurrentStatic();

	if ($ENV{GATEWAY_INTERFACE}) {
		my $r = Apache->request;
		$hostip = $r->connection->remote_ip;
	} else {
		$hostip = '';
	}

	$uid = $constants->{anonymous_coward_uid} unless defined($uid) && $uid ne '';

	if (isAnon($uid)) {
		if ($ENV{GATEWAY_INTERFACE}) {
			$user = getCurrentAnonymousCoward();
		} else {
			$user = $slashdb->getUser($constants->{anonymous_coward_uid});
		}
		$user->{is_anon} = 1;

	} else {
		$user  = $slashdb->getUser($uid); # getUserInstance($uid, $uri) {}
		$user->{is_anon} = 0;
	}

	unless ($user->{is_anon} && $ENV{GATEWAY_INTERFACE}) {
		my $timezones = $slashdb->getDescriptions('tzcodes');
		$user->{off_set} = $timezones->{ $user->{tzcode} };

		my $dateformats = $slashdb->getDescriptions('datecodes');
		$user->{'format'} = $dateformats->{ $user->{dfid} };
	}

	$user->{state}{post}	= $method eq 'POST' ? 1 : 0;
	$user->{ipid}		= md5_hex($hostip);
	$user->{subnetid}	= $hostip;
	$user->{subnetid}	=~ s/(\d+\.\d+\.\d+)\.\d+/$1\.0/;
	$user->{subnetid}	= md5_hex($user->{subnetid});

	my @defaults = (
		['mode', 'thread'], qw[
		savechanges commentsort threshold
		posttype noboxes light
	]);

	for my $param (@defaults) {
		my $default;
		if (ref($param) eq 'ARRAY') {
			($param, $default) = @$param;
		}

		if (defined $form->{$param} && $form->{$param} ne '') {
			$user->{$param} = $form->{$param};
		} else {
			$user->{$param} ||= $default || 0;
		}
	}

	if ($user->{commentlimit} > $constants->{breaking}
		&& $user->{mode} ne 'archive'
		&& $user->{mode} ne 'metamod') {
		$user->{commentlimit} = int($constants->{breaking} / 2);
		$user->{breaking} = 1;
	} else {
		$user->{breaking} = 0;
	}

	# All sorts of checks on user data
	$user->{exaid}		= _testExStr($user->{exaid}) if $user->{exaid};
	$user->{exboxes}	= _testExStr($user->{exboxes}) if $user->{exboxes};
	$user->{extid}		= _testExStr($user->{extid}) if $user->{extid};
	$user->{points}		= 0 unless $user->{willing}; # No points if you dont want 'em

	# This is here so when user selects "6 ish" it
	# "posted by xxx around 6 ish" instead of "on 6 ish"
	if ($user->{'format'} eq '%l ish') {	# %i
		$user->{aton} = 'around'; # getData('atonish');
	} else {
		$user->{aton} = 'on'; # getData('aton');
	}

	if ($uri =~ m[^/$]) {
		$user->{currentPage} = 'index';
	} elsif ($uri =~ m{(?:/|\b)([^/]+)\.pl$}) {
		$user->{currentPage} = $1;
	} else {
		$user->{currentPage} = 'misc';
	}

	if ($user->{seclev} >= 100) {
		$user->{is_admin} = 1;
		my $sid;
		#This cookie could go, and we could have session instance
		#do its own thing without the cookie. -Brian
		if ($cookies->{session}) {
			$sid = $slashdb->getSessionInstance($uid, $cookies->{session}->value);
		} else {
			$sid = $slashdb->getSessionInstance($uid);
		}
		setCookie('session', $sid) if $sid;
		if ($constants->{admin_check_clearpass}
			&& !Slash::Apache::ConnectionIsSecure()) {
			$user->{state}{admin_clearpass_thisclick} = 1;
		}
	}
	if ($user->{seclev} > 1
		&& $constants->{admin_clearpass_disable}
		&& ($user->{state}{admin_clearpass_thisclick} || $user->{admin_clearpass})) {
		# User temporarily loses their admin privileges until they
		# change their password.
		$user->{seclev} = 1;
		$user->{state}{lostprivs} = 1;
	}

	return $user;
}


#========================================================================

=head2 filter_params(PARAMS)

This cleans up form data before it is used by the program.

=over 4

=item Parameters

=over 4

=item PARAMS

A hash of the parameters to clean up.

=back

=item Return value

Hashref of cleaned-up data.

=back

=cut

{
	my %multivalue = map {($_ => 1)} qw(
		section_multiple
	);

	# fields that are numeric only
	my %nums = map {($_ => 1)} qw(
		approved artcount bseclev
		buymore cid clbig clsmall
		commentlimit commentsort commentspill
		commentstatus del displaystatus
		filter_id hbtm height highlightthresh
		isolate issue last maillist max
		maxcommentsize maximum_length maxstories
		min minimum_length minimum_match next
		ordernum pid posttype ratio retrieve
		seclev start startat threshold uid
		uthreshold voters width
		textarea_rows textarea_cols
		subid tpid tid qid aid
		url_id spider_id miner_id keyword_id
	);

	# fields that have ONLY a-zA-Z0-9_
	my %alphas = map {($_ => 1)} qw(
		formkey hcanswer mode op section type
	);

	# regexes to match dynamically generated numeric fields
	my @regints = (qr/^reason_.+$/, qr/^votes.+$/, qr/^people_bonus_.+$/);

	# special few
	my %special = (
		sid	=> sub { $_[0] =~ s|[^A-Za-z0-9/._]||g	},
		flags	=> sub { $_[0] =~ s|[^a-z0-9_,]||g	},
		query	=> sub { $_[0] =~ s|[\000-\040<>\177-\377]+| |g;
			         $_[0] =~ s|\s+| |g;		},
	);


sub filter_params {
	my($apr) = @_;
	my %form;

	if (ref($apr) eq "HASH") {
		# for now, we cannot have more than simple key->value
		# (see createEnvironment())
		%form = %$apr;
	} else {
		for ($apr->param) {
			my @values = $apr->param($_);
			if (scalar(@values) > 1) { 
				$form{$_} = $values[0];
				$form{_multi}{$_} = \@values;
			} else {
				$form{$_} = $values[0];
			}
			# allow any param ending in _multiple to be multiple -- pudge
			if (exists $multivalue{$_} || /_multiple$/) {
				my @multi = $apr->param($_);
				$form{$_} = \@multi;
				$form{_multi}{$_} = \@multi;
				next;
			}
		}
	}

	for my $key (keys %form) {
		if ($key eq '_multi') {
			for my $key (keys %{$form{_multi}}) {
				my @data;
				for my $data (@{$form{_multi}{$key}}) {
					push @data, filter_param($key, $data);
				}
				$form{_multi}{$key} = \@data;
			}			
		} elsif (ref($form{$key}) eq 'ARRAY') {
			my @data;
			for my $data (@{$form{$key}}) {
				push @data, filter_param($key, $data);
			}
			$form{$key} = \@data;
		} else {
			$form{$key} = filter_param($key, $form{$key});
		}
	}

	return \%form;
}


sub filter_param {
	my($key, $data) = @_;

	# Paranoia - Clean out any embedded NULs. -- cbwood
	# hm.  NULs in a param() value means multiple values
	# for that item.  do we use that anywhere? -- pudge
	$data =~ s/\0//g;

	# clean up numbers
	if (exists $nums{$key}) {
		$data = fixint($data);
	} elsif (exists $alphas{$key}) {
		$data =~ s|[^a-zA-Z0-9_]+||g;
	} elsif (exists $special{$key}) {
		$special{$key}->($data);
	} else {
		for my $ri (@regints) {
			$data = fixint($data) if /$ri/;
		}
	}

	return $data;
}
} # see lexical variables above

########################################################
sub _testExStr {
	local($_) = @_;
	$_ .= "'" unless m/'$/;
	return $_;
}

########################################################
# fix parameter input that should be integers
sub fixint {
	my($int) = @_;
# allow + ... should be OK ... ?  -- pudge
# 	$int =~ s/^\+//;
# 	$int =~ s/^(-?[\d.]+).*$/$1/s or return;
	$int =~ s/^([+-]?[\d.]+).*$/$1/s or return;
	return $int;
}

#========================================================================

=head2 getObject(CLASS_NAME [, VIRTUAL_USER, ARGS])

Returns a object in CLASS_NAME, using the new() constructor.  It passes
VIRTUAL_USER and ARGS to it, and then caches it by CLASS_NAME and VIRTUAL_USER.
If the object for that CLASS_NAME/VIRTUAL_USER exists the second time through,
it will just return, without reinitializing (even if different ARGS are passed,
so don't do that).

=over 4

=item Parameters

=over 4

=item CLASS_NAME

A class name to use in creating a object.  Only [\w:] characters are allowed.

=item VIRTUAL_USER

Optional; will default to main Virtual User for site if not supplied.
Passed as second argument to the new() constructor (after class name).

=item ARGS

Any other arguments to be passed to the object's constructor.

=back

=item Return value

An object, unless object cannot be gotten; then undef.

=back

=cut

sub getObject {
	my($class, $user, @args) = @_;
	my($cfg, $objects);

	if ($ENV{GATEWAY_INTERFACE} && (my $r = Apache->request)) {
		$cfg     = Apache::ModuleConfig->get($r, 'Slash::Apache');
		$objects = $cfg->{'objects'} ||= {};
	} else {
		$objects = $static_objects   ||= {};
	}

	# clean up dangerous characters
	$class =~ s/[^\w:]+//g;
	$user ||= getCurrentVirtualUser();
	return undef unless $user && $class;

	if ($objects->{$class, $user}) {
		# we've been here before, and it didn't work last time ...
		# what, you think you can try it again and it will work
		# magically this time?  you think you're better than me?
		if ($objects->{$class, $user} eq 'NA') {
			return undef;
		} else {
			return $objects->{$class, $user};
		}

	} else {
		# see if module has been loaded in already ...
		(my $file = $class) =~ s|::|/|g;
		# ... because i really hate eval
		eval "require $class" unless exists $INC{"$file.pm"};

		if ($@) {
			errorLog($@);
		} elsif (!$class->can("new")) {
			errorLog("Class $class is not returning an object.  Try " .
				"`perl -M$class -le '$class->new'` to see why.\n");
		} else {
			my $object = $class->new($user, @args);
			return $objects->{$class, $user} = $object if $object;
		}

		$objects->{$class, $user} = 'NA';
		return undef;
	}
}

#========================================================================

=head2 errorLog()

Generates an error that either goes to Apache's error log
or to STDERR. The error consists of the package and
and filename the error was generated and the same information
on the previous caller.

=over 4

=item Return value

Returns 0;

=back

=cut

sub errorLog {
	my($package, $filename, $line) = caller(1);
	return if $Slash::Utility::NO_ERROR_LOG;
	if ($ENV{GATEWAY_INTERFACE}) {
		my $r = Apache->request;
		if ($r) {
			$r->log_error("$ENV{SCRIPT_NAME}:$package:$filename:$line:@_");
			($package, $filename, $line) = caller(2);
			$r->log_error ("Which was called by:$package:$filename:$line:@_\n");

			return 0;
		}
	}
	print STDERR ("Error in library:$package:$filename:$line:@_\n");
	($package, $filename, $line) = caller(2);
	print STDERR ("Which was called by:$package:$filename:$line:@_\n") if $package;

	return 0;
}

#========================================================================

=head2 writeLog(DATA)

Places optional data in the accesslog.

=over 4

=item Parameters

=over 4

=item DATA

Strings that are concatenated together to be used in the SLASH_LOG_DATA field.

=back

=item Return value

No value is returned.

=back

=cut

sub writeLog {
	return unless $ENV{GATEWAY_INTERFACE};
	my $dat = join("\t", @_);

	my $r = Apache->request;

	# Notes has a bug (still in apache 1.3.17 at
	# last look). Apache's directory sub handler
	# is not copying notes. Bad Apache!
	# -Brian
	$r->err_header_out(SLASH_LOG_DATA => $dat);
}

sub createLog {
	my($uri, $dat) = @_;
	my $slashdb = getCurrentDB();

	my $page = qr|\d{2}/\d{2}/\d{2}/\d{4,7}|;

	if ($uri eq 'palm') {
		($dat = $ENV{REQUEST_URI}) =~ s|\.shtml$||;
		$slashdb->createAccessLog('palm', $dat);
	} elsif ($uri eq '/') {
		$slashdb->createAccessLog('index', $dat);
	} elsif ($uri =~ /\.pl$/) {
		$uri =~ s|^/(.*)\.pl$|$1|;
		$slashdb->createAccessLog($uri, $dat);
	# This is for me, I am getting tired of patching my local copy -Brian
	} elsif ($uri =~ /\.tar\.gz$/) {
		$uri =~ s|^/(.*)\.tar\.gz$|$1|;
		$slashdb->createAccessLog($uri, $dat);
	} elsif ($uri =~ /\.rss$/ || $uri =~ /\.xml$/ || $uri =~ /\.rdf$/) {
		$slashdb->createAccessLog('rss', $dat);
	} elsif ($uri =~ /\.shtml$/) {
		$uri =~ s|^/(.*)\.shtml$|$1|;
		$dat = $uri if $uri =~ $page;	
		$uri =~ s|^/?(\w+)/?.*|$1|;
		$slashdb->createAccessLog($uri, $dat);
	} elsif ($uri =~ /\.html$/) {
		$uri =~ s|^/(.*)\.html$|$1|;
		$dat = $uri if $uri =~ $page;	
		$uri =~ s|^/?(\w+)/?.*|$1|;
		$slashdb->createAccessLog($uri, $dat);
	}

}

#========================================================================

=head2 createEnvironment([VIRTUAL_USER])

Places data into the request records notes table. The two keys
it uses are SLASH_LOG_OPERATION and SLASH_LOG_DATA.

=over 4

=item Parameters

=over 4

=item VIRTUAL_USER

Optional.  You can pass in a virtual user that will be used instead of
parsing C<@ARGV>.

=back

=item Return value

No value is returned.

=back

=cut

sub createEnvironment {
	return if $ENV{GATEWAY_INTERFACE};
	my($virtual_user) = @_;
	my %form;
	unless ($virtual_user) {
		while (my $pair = shift @ARGV) {
			my($key, $val) = split /=/, $pair;
			# stop processing if key=val stops, and put last arg back on
			unshift(@ARGV, $pair), last if ! defined $val;
			$form{$key} = $val;
		}
		$virtual_user = $form{'virtual_user'};
	}

	createCurrentVirtualUser($virtual_user);
	createCurrentForm(filter_params(\%form));

	my $slashdb = Slash::DB->new($virtual_user);
	my $constants = $slashdb->getSlashConf();
	my $site_constants;
	my $sections = $slashdb->getSections();
	for (values %$sections) {
		if ($_->{hostname} && $_->{url}) {
			my $new_cfg;
			for (keys %{$constants}) {
				$new_cfg->{$_} = $constants->{$_}
					unless $_ eq 'form_override';
			}
			# Must not just copy the form_override info
			$new_cfg->{form_override} = {}; 
			$new_cfg->{absolutedir} = $_->{url};
			$new_cfg->{rootdir} = $_->{url};
			$new_cfg->{cookiedomain} = $_->{cookiedomain} if $_->{cookiedomain};
			$new_cfg->{defaultsection} = $_->{section};
			$new_cfg->{section} = $_->{section};
			$new_cfg->{basedomain} = $_->{hostname};
			$new_cfg->{static_section} = $_->{section};
			$new_cfg->{index_handler} = $_->{index_handler};
			$site_constants->{$_->{hostname}} = $new_cfg;
		}
	}
	my $form = getCurrentForm();

	# If this is a sectional site, we need to set our hostname if one exists.
	my $hostname = $slashdb->getSection($form->{section}, 'hostname') || "";
	createCurrentHostname($hostname);

	# We assume that the user for scripts is the anonymous user
	createCurrentDB($slashdb);
	createCurrentStatic($constants, $site_constants);

	$ENV{SLASH_USER} = $constants->{anonymous_coward_uid};
	my $user = prepareUser($constants->{anonymous_coward_uid}, $form, $0);
	createCurrentUser($user);
	createCurrentAnonymousCoward($user);
}

######################################################################
# Quick intro -Brian
sub getCurrentCache {
	my($value) = @_;
	my $cache;

	if ($ENV{GATEWAY_INTERFACE} && (my $r = Apache->request)) {
		my $cfg = Apache::ModuleConfig->get($r, 'Slash::Apache');
		$cache = $cfg->{'cache'} ||= {};
	} else {
		$cache = $static_cache   ||= {};
	}

	# i think we want to test defined($foo), not just $foo, right?
	if ($value) {
		return defined($cache->{$value})
			? $cache->{$value}
			: undef;
	} else {
		return $cache;
	}
}

1;

__END__


=head1 SEE ALSO

Slash(3), Slash::Utility(3).

=head1 VERSION

$Id$

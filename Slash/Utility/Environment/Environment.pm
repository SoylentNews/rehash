# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
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
use Time::HiRes;
use Socket qw( inet_aton inet_ntoa );

use base 'Exporter';
use vars qw($VERSION @EXPORT);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;
@EXPORT	   = qw(

	dbAvailable

	createCurrentAnonymousCoward
	createCurrentCookie
	createCurrentDB
	createCurrentForm
	createCurrentHostname
	createCurrentStatic
	createCurrentUser
	createCurrentVirtualUser

	setCurrentForm
	setCurrentSkin
	setCurrentUser

	getCurrentAnonymousCoward
	getCurrentCookie
	getCurrentDB
	getCurrentForm
	getCurrentMenu
	getCurrentSkin
	getCurrentStatic
	getCurrentUser
	getCurrentVirtualUser
	getCurrentCache

	setUserDBs
	saveUserDBs

	createEnvironment
	getObject
	getAnonId
	isAnon
	isAdmin
	isSubscriber
	prepareUser
	filter_params
	loadClass
	loadCoderef

	setUserDate
	isDST

	bakeUserCookie
	eatUserCookie
	setCookie
	getPublicLogToken

	getPollVoterHash

	debugHash
	slashProf
	slashProfBail
	slashProfInit
	slashProfEnd

	getOpAndDatFromStatusAndURI
	createLog
	errorLog
	writeLog

	determineCurrentSkin

	get_ipids
	get_srcids
	convert_srcid
	get_srcid_prependbyte
	get_srcid_sql_in
	get_srcid_sql_out
	get_srcid_type
	get_srcid_vis
	decode_srcid_prependbyte

);

use constant DST_HR  => 0;
use constant DST_NUM => 1;
use constant DST_DAY => 2;
use constant DST_MON => 3;

# These are file-scoped variables that are used when you need to use the
# set methods when not running under mod_perl
my($static_user, $static_form, $static_constants, $static_site_constants, 
	$static_db, $static_anonymous_coward, $static_cookie,
	$static_virtual_user, $static_objects, $static_cache, $static_hostname,
	$static_skin);

# FRY: I don't regret this.  But I both rue and lament it.

#========================================================================

=head2 dbAvailable([TOKEN])

Returns TRUE if (as usual) the DB(s) are available for reading and
writing.  Returns FALSE if the DB(s) are not available and should not
be accessed.  If a TOKEN is named, return FALSE if either the DB(s)
required for that purpose are down or all DBs are down.  If no TOKEN is
named, return FALSE only if all DBs are down.

Whether or not the DBs are down is determined only by whether files exist
at /usr/local/slash/dboff or /usr/local/slash/dboff_TOKEN.  For best
results, admins will want to write their own db-angel scripts that detect
DBs having gone down and create one or more of those files.

=over 4

=item Parameters

=over 4

=item TOKEN

Name of the resource specifically being asked about, or the
empty string.

=back

=item Return value

0 or 1.

=back

=cut

{ # closure
my $dbAvailable_lastcheck = {};
my $dbAvailable_lastval = {};
sub dbAvailable {
	# I'm not going to explain exactly how I came up with this
	# logic... the if's are ordered to reduce computation as
	# much as possible.
	my($token) = @_;

	# if we're doing a general check for dbAvailability we set
	# the token to empty-string and store the lastchecked status
	# and lastval check in the hashrefs with that as the key
	$token ||= '';

	if (defined $dbAvailable_lastcheck->{$token} && time < ($dbAvailable_lastcheck->{$token} + 5)) {
		return $dbAvailable_lastval->{$token};
	}


	my $newval;
	   if (-e "/usr/local/slash/dboff")		{ $newval = 0 }
	elsif (!$token || $token !~ /^(\w+)/)		{ $newval = 1 }
	elsif (-e "/usr/local/slash/dboff_$token")	{ $newval = 0 }
	else						{ $newval = 1 }
	$dbAvailable_lastval->{$token} = $newval;
	$dbAvailable_lastcheck->{$token} = time;
	return $newval;
}
} # end closure

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
		my $reader = getObject('Slash::DB', { db_type => 'reader' });
		my $menus = $reader->getMenus();

		@menus = @{$menus->{$menu}} if exists $menus->{$menu};
	}
	
	if ($user && ($user_menu = $user->{menus}{$menu})) {
		push @menus, values %$user_menu;
	}

	return \@menus;
}

#========================================================================

=head2 getCurrentUser([MEMBER])

Returns the current authenticated user.

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
		$user = $cfg->{user} ||= {};
	} else {
		$user = $static_user ||= {};
	}

	return $user->{$value} if defined $value;
	return $user;
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

	return defined $value ? $form->{$value} : $form;
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

	return defined $value ? $cookie->{$value} : $cookie;
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

=head2 getCurrentSkin([MEMBER])

Returns the current skin.

=over 4

=item Parameters

=over 4

=item MEMBER

A member (field) from the skin record.

=back

=item Return value

A hash reference with the skin information is returned unless MEMBER is
passed. If MEMBER is passed in then only its value will be returned.

=back

=cut

sub getCurrentSkin {
	my($value) = @_;

	my $current_skin;
	if ($ENV{GATEWAY_INTERFACE}) {
		my $r = Apache->request;
		my $cfg = Apache::ModuleConfig->get($r, 'Slash::Apache');
		$current_skin = $cfg->{skin}  ||= {};
	} else {
		$current_skin = $static_skin  ||= {};
	}

	return defined $value ? $current_skin->{$value} : $current_skin;
}

#========================================================================

=head2 setCurrentSkin(HASH)

Set up the current skin global, which will be returned by
getCurrentSkin(), for both static scripts and under Apache.

=over 4

=item Parameters

=over 4

=item ID

Numeric ID (skins.skid) or name (skins.name).

=back

=item Return value

Returns no value.

=back

=cut

sub setCurrentSkin {
	my($id) = @_;
	my $slashdb = getCurrentDB();

	my $current_skin;
	if ($ENV{GATEWAY_INTERFACE}) {
		my $r = Apache->request;
		my $cfg = Apache::ModuleConfig->get($r, 'Slash::Apache');
		$current_skin = $cfg->{skin} ||= {};
	} else {
		$current_skin = $static_skin ||= {};
	}

#print STDERR scalar(localtime) . " $$ setCurrentSkin id=$id c_s->{skid}=$current_skin->{skid}\n";
	return 1 if $current_skin->{skid} && $current_skin->{skid} == $id;

	my $gSkin = $slashdb->getSkin($id);

	# we want to retain any references to $gSkin that are already
	# in existence
	@{$current_skin}{keys %$gSkin} = values %$gSkin;

	# Now, if prepareUser() has already been called, we have to update
	# the anonymous coward.	Otherwise, we leave it alone and trust
	# that prepareUser() will set it properly itself.
	my $user = getCurrentUser();
#print STDERR scalar(localtime) . " $$ setCurrentSkin user->uid=$user->{uid} current_skin->skid=$current_skin->{skid}\n";
	if ($user->{uid}) {
		# prepareUser() has been called already, so it's OK to
		# call it again.
		my $new_ac_uid = $current_skin->{ac_uid} || getCurrentStatic('anonymous_coward_uid');
		my $ac_user = getCurrentAnonymousCoward();
#print STDERR scalar(localtime) . " $$ setCurrentSkin new_ac_uid='$new_ac_uid' ac_user->uid='$ac_user->{uid}'\n";
		if ($ac_user->{uid} != $new_ac_uid) {
			$ENV{SLASH_USER} = $new_ac_uid;
			my $form = getCurrentForm();
			my $new_ac_user = prepareUser($new_ac_uid, $form, $0);
#print STDERR scalar(localtime) . " $$ new_ac_user: " . Dumper($new_ac_user);
			createCurrentAnonymousCoward($new_ac_user);
			# If the user is not currently logged in, switch them
			# from the old AC user to the new AC user.
			if ($user->{is_anon}) {
				createCurrentUser($new_ac_user);
			}
		}
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
## XXXSKIN - this should probably go away, along with SlashSectionHost,
## SlashSetFormHost, and SlashSetVarHost in Slash::Apache, except ...
#		my $hostname = $r->header_in('host');
#		$hostname =~ s/:\d+$//;
#		if ($const_cfg->{'site_constants'}{$hostname}) { 
#			$constants = $const_cfg->{site_constants}{$hostname};
#		} else {
## XXXSKIN - ... this would be the one line to keep
			$constants = $const_cfg->{'constants'};
#		}
	} else {
		$constants = $static_constants;
	}

	return defined $value ? $constants->{$value} : $constants;
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
	($static_constants) = @_;
	$static_site_constants = $_[1] if defined $_[1];
}

#========================================================================

=head2 createCurrentHostname(HOSTNAME)

Allows you to set a host so that constants will behave properly.
This is used as a key into %$static_site_constants so that a single
Apache process can serve multiple Slash sites.

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

	my $ref;
	if ($ENV{GATEWAY_INTERFACE}) {
		my $r = Apache->request;
		my $const_cfg = Apache::ModuleConfig->get($r, 'Slash::Apache') or return;
		$ref = $const_cfg->{anonymous_coward};
	} else {
		$ref = $static_anonymous_coward;
	}

	return undef unless $ref && ref $ref;
	return $ref->{$value} if defined $value;
	my %coward = %$ref;
	return \%coward;
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

	# This might be undefined in the event of a comment preview
	# when a data structure is not fully filled out.  So let's
	# handle improper input by saying yes, that bogus value is
	# anonymous (the least dangerous response).
	return 1 if	!defined($uid)		# no undef
		||	$uid eq ''		# no empty string
		||	$uid =~ /[^0-9]/	# only integers
		||	$uid < 1		# only positive
	;

	# Quick check for very common case.
	my $constants = getCurrentStatic();
	return 1 if $uid == $constants->{anonymous_coward_uid};

	# Might be one of the alternate ACs specified in a skin.
	# Check them all.
	my $slashdb = getCurrentDB();
	my $skins = $slashdb->getSkins();
	for my $skid (keys %$skins) {
		return 1 if $skins->{$skid}{ac_uid} && $uid == $skins->{$skid}{ac_uid};
	}

	# Nope, this UID is not anonymous.
	return 0;
}

#========================================================================

=head2 isAdmin(UID)

Tests to see if the uid passed in is an admin.

=over 4

=item Parameters

=over 4

=item UID

Value UID.  Can also be standard C<$user> hashref.

=back

=item Return value

Returns true if the UID is an admin, otherwise false.

=back

=cut

sub isAdmin {
	my($user) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	# $user can be real $user, or $uid
	my $usercheck = ref $user
		? $user
		: $slashdb->getUser($user, [qw(seclev)]);

	return $usercheck->{seclev} >= 100
		? 1
		: 0;
}

#========================================================================

=head2 isSubscriber(USER)

Tests to see if the user passed in is a subscriber.

=over 4

=item Parameters

=over 4

=item USER

User data hashref from getUser() call.

If you pass a UID instead of a USER, then the function will call getUser() for you.

=back

=item Return value

Returns true if the USER is a subscriber, otherwise false.  Also returns
true if the C<subscribe> var is false (everyone is a subscriber if there
are no subscriptions), so check in your caller if you need subscriptions
turned on.

=back

=cut

sub isSubscriber {
	my($suser) = @_;
	my $constants = getCurrentStatic();

	# assume is not subscriber by default
	my $subscriber = 0;

	if ($constants->{subscribe}) {
		if (! ref $suser) {
			my $slashdb = getCurrentDB();
			$suser = $slashdb->getUser($suser, [qw(hits_paidfor hits_bought)]);
		}

		$subscriber = 1 if $suser->{hits_paidfor} &&
			$suser->{hits_bought} < $suser->{hits_paidfor};
	} else {
		$subscriber = 1;  # everyone is a subscriber if subscriptions are turned off
	}

	return $subscriber;
}

#========================================================================

=head2 getAnonId([FORMKEY])

Returns a string of random alphanumeric characters.

=over 4

=item Parameters

=over 4

=item NOPREFIX

Don't prepend a "-1-" string. That prefix is no longer used anywhere in
the code, so basically everyplace this function is used passes in true
for noprefix.  All part of the slow evolution of the codebase!

=item COUNT

Number of characters (default 10).

=back

=item Return value

A random value based on alphanumeric characters

=back

=cut

{
	my @chars = (0..9, 'A'..'Z', 'a'..'z');
	sub getAnonId {
		my($noprefix, $count) = @_;
		$count ||= 10;
		my $str = "";
		$str = '-1-' unless $noprefix;
		$str .= join('', map { $chars[rand @chars] } 1 .. $count);
		return $str;
	}
}

#========================================================================

=head2 bakeUserCookie(UID, VALUE)

Bakes (creates) a user cookie from its ingredients (UID, VALUE).

The cookie used to be hexified; it is no longer.  We can still read such
cookies, though, but we don't create them.

=over 4

=item Parameters

=over 4

=item UID

User ID.

=item VALUE

Cookie's value.  This used to be called 'passwd' but the value that gets
put into user cookies now isn't a password anymore.

=back

=item Return value

Created cookie.

=back

=cut

# create a user cookie from ingredients
sub bakeUserCookie {
	my($uid, $value) = @_;
	my $cookie = $uid . '::' . $value;
	return $cookie;
}

#========================================================================

=head2 eatUserCookie(COOKIE)

Digests (parses) a user cookie, returning it to its original ingredients
(UID, value).

The cookie used to be hexified; it is no longer.  We can still read such
cookies, though.

=over 4

=item Parameters

=over 4

=item COOKIE

Cookie to be parsed.

=back

=item Return value

The UID and value encoded in the cookie.

=back

=cut

sub eatUserCookie {
	my($cookie) = @_;
	$cookie =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack('C', hex($1))/ge
		unless $cookie =~ /^\d+::/;
	my($uid, $value) = split(/::/, $cookie, 2);
	return($uid, $value);
}

#========================================================================

=head2 setCookie(NAME, VALUE, SESSION)

Creates a cookie and places it into the outbound headers.  Can be
called multiple times to set multiple cookies.

=over 4

=item Parameters

=over 4

=item NAME

Name of the cookie.

=item VALUE

Value to be placed in the cookie.

=item SESSION

Flag to determine if the cookie should be a session cookie.  "1" means
yes, expire it after the current session.  "2" means to expire it
according to the login_temp_minutes var.  And a value that looks like
a session time, like "+24h", is passed along directly (in that case,
expires 24 hours from now).

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
	my $gSkin = getCurrentSkin();

	my $cookiedomain = $gSkin->{cookiedomain} || $constants->{cookiedomain};
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

	$cookiehash{-secure} = 1
		if $constants->{cookiesecure} && Slash::Apache::ConnectionIsSSL();

	my $cookie = Apache::Cookie->new($r, %cookiehash);

	# this should be fine, but if there is a problem, comment the following
	# lines, and uncomment the one right above "bake"
	if (!$val) {
		$cookie->expires('-1y');  # delete
	} elsif ($session && $session =~ /^\+\d+[mhdy]$/) {
		$cookie->expires($session);
	} elsif ($session && $session > 1) {
		my $minutes = $constants->{login_temp_minutes};
		$cookie->expires("+${minutes}m");
	} elsif (!$session) {
		$cookie->expires('+1y');
	}

	$cookie->bake;

	if ($domain) {
		$cookie->domain($domain);
		$cookie->bake;
	}
}

#========================================================================

=head2 getPollVoterHash([UID])

=cut

sub getPollVoterHash {
	my $constants = getCurrentStatic();
	my $remote_addr = $ENV{REMOTE_ADDR} || '';
        if ($constants->{poll_fwdfor} && $ENV{HTTP_X_FORWARDED_FOR}) {
                return md5_hex($remote_addr . $ENV{HTTP_X_FORWARDED_FOR});
        } else {
                return md5_hex($remote_addr);
        }
}

#========================================================================

=head2 getPublicLogToken([UID])

Just a wrapper around:

	bakeUserCookie($uid, $slashdb->getLogToken($uid, 1, 2));

to get a public logtoken.  Uses current user's UID if none supplied.

=cut

sub getPublicLogToken {
	my($uid) = @_;
	$uid ||= getCurrentUser('uid');
	if ($uid) {
		my $slashdb = getCurrentDB();
		# Don't bump a public logtoken's expiration time if we're
		# just getting its value to emit.
		my $logtoken = $slashdb->getLogToken($uid, 1, 2, 0);
		if ($logtoken) {
			return bakeUserCookie($uid, $logtoken);
		}
	}
	return '';
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
bunches of other user datum.  If the default values or the schema for
fields like karma_bonus or domaintags ever changes, such that writing
'undef' to delete a users_param row is no longer an acceptable
alternative to writing out the default value, then the code both here
and in users.pl save*() should be re-examined.

=back

=cut

sub prepareUser {
	# we must get form data and cookies, because we are preparing it here
	my($uid, $form, $uri, $cookies, $method) = @_;
#print STDERR scalar(localtime) . " $$ prepareUser($uid)\n";
	my($slashdb, $constants, $user, $hostip);

	$cookies ||= {};
	$method ||= "";
	$slashdb = getCurrentDB();
	$constants = getCurrentStatic();

	my $r;
	if ($ENV{GATEWAY_INTERFACE}) {
		$r = Apache->request;
		$hostip = $r->connection->remote_ip;
	} else {
		$hostip = '';
	}

	# First we find a good reader DB so that we can use that for the user
	my $user_types = setUserDBs();
	my $reader = getObject('Slash::DB', { virtual_user => $user_types->{reader} });
	if (!$reader) {
		die "no reader found in prepareUser($uid), user_types: " . join(',', sort keys %$user_types);
	}

	if (!$uid) {
		# No user defined;  set the anonymous coward user.
		my $gSkin = getCurrentSkin();
		if ($gSkin && $gSkin->{ac_uid}) {
			$uid = $gSkin->{ac_uid};
		} else {
			$uid = $constants->{anonymous_coward_uid};
		}
	}

	if (isAnon($uid)) {
		if ($ENV{GATEWAY_INTERFACE}) {
			$user = getCurrentAnonymousCoward();
#print STDERR scalar(localtime) . " $$ prepareUser going to getCurrentAnonymousCoward for uid $uid, got uid $user->{uid}\n";
		}
		if (!$user || $user->{uid} != $uid) {
			# If we didn't just call getCurrentAnonymousCoward, or if
			# the AC user we got is not the AC user we were expecting,
			# we need to load that user from the DB.
			$user = $reader->getUser($uid);
		}
		$user->{is_anon} = 1;
		$user->{state} = {};
	} else {
		$user = $reader->getUser($uid);
		$user->{is_anon} = 0;
		# If this was a public logtoken, we do want to bump its
		# expiration time out, because it was used to authenticate.
		$user->{logtoken} = bakeUserCookie($uid,
			$slashdb->getLogToken($uid, 0, 0, 1));
	}
#print STDERR scalar(localtime) . " $$ prepareUser user->uid=$user->{uid} is_anon=$user->{is_anon}\n";

	# Now store the DB information from above in the user
	saveUserDBs($user, $user_types);

	unless ($user->{is_anon} && $ENV{GATEWAY_INTERFACE}) { # already done in Apache.pm
		setUserDate($user);
	}

	$user->{state}{post}	= $method eq 'POST' ? 1 : 0;
	$user->{srcids}		= get_srcids({ ip => $hostip, uid => $uid });
	@{$user}{qw[ipid subnetid classbid hostip]} = get_ipids();
#	@{$user}{qw[ipid subnetid classbid hostip]} = get_srcids({ ip => $hostip },
#		{ return_only => [qw( ipid subnetid classbid ip )] });

	my @defaults = (
		['mode', 'thread'], qw[
		savechanges commentsort threshold
		posttype noboxes lowbandwidth simpledesign pda
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
	$user->{karma_bonus}  = '+1' unless defined($user->{karma_bonus});

	# see Slash::discussion2()
	# if D2 is not set, it is because user is anon, or user has not
	# selected D2 one way or another.  such users get D2 by default unless
	# no_d2 is set, or they are IE users
	$user->{state}{no_d2} = $form->{no_d2} ? 1 : 0;
	if (!$user->{discussion2}) {
		my $d2 = 'slashdot';  # default for all users
		if ($user->{state}{no_d2}) {
			$d2 = 'none';
		} elsif ($ENV{GATEWAY_INTERFACE}) {
			# get user-agent (ENV not populated yet)
			my %headers = $r->headers_in;
			# just in case:
			@headers{map lc, keys %headers} = values %headers;
			my $ua = $r->headers_in->{'user-agent'};
			if ($ua =~ /MSIE (\d+)/) {
				$d2 = 'none';# if $1 < 7;
			}
		}
		$user->{discussion2} = $d2;
	}

	# All sorts of checks on user data.  The story_{never,always} checks
	# are important because that data is fed directly into SQL queries
	# without being quoted.
	for my $field (qw(
		story_never_topic	story_never_author	story_never_nexus
		story_always_topic	story_always_author	story_always_nexus
	)) {
		if ($user->{$field}) {
			$user->{$field} = _testExStrNumeric($user->{$field}, 1);
		}
	}
	if ($user->{slashboxes}) {
		$user->{slashboxes} = _testExStr($user->{slashboxes});
	}
	$user->{points}		= 0 unless $user->{willing}; # No points if you dont want 'em
	$user->{domaintags}	= 2 if !defined($user->{domaintags}) || $user->{domaintags} !~ /^\d+$/;

	# This is here so when user selects "6 ish" it
	# "posted by xxx around 6 ish" instead of "on 6 ish"
	## this does not call Slash::getData right now because
	## it is just so early in the code that the AC user does
	## not even exist yet in static mode, and it causes problems
	## with slashDisplay.  -- pudge
	if ($user->{'format'} eq '%l ish') {	# %i
		$user->{aton} = 'around'; # Slash::getData('atonish');
	} else {
		$user->{aton} = 'on'; # Slash::getData('aton');
	}

	if ($uri =~ m[^/$]) {
		$user->{currentPage} = 'index';
	} elsif ($uri =~ m{\b([^/]+)\.pl\b}) {
		$user->{currentPage} = $1;
	} else {
		$user->{currentPage} = 'misc';
	}

	if (	   ( $user->{currentPage} eq 'article'
			|| $user->{currentPage} eq 'comments' )
		&& ( $user->{commentlimit} > $constants->{breaking}
			&& $user->{mode} ne 'archive'
			&& $user->{mode} ne 'metamod' )
	) {
		$user->{commentlimit} = int($constants->{breaking} / 2);
		$user->{breaking} = 1;
	} else {
		$user->{breaking} = 0;
	}

	if ($constants->{subscribe}) {
		# Decide whether the user is a subscriber.
		$user->{is_subscriber} = isSubscriber($user);
		# Make other decisions about subscriber-related attributes
		# of this page.  Note that we still have $r lying around,
		# so we can save Subscribe.pm a bit of work.
		# we don't need or want to do this if not in Apache ...
		if ($ENV{GATEWAY_INTERFACE} && (my $subscribe = getObject('Slash::Subscribe', { db_type => 'reader' }))) {
			$user->{state}{page_plummy} = $subscribe->plummyPage($r, $user);
			$user->{state}{page_buying} = $subscribe->buyingThisPage($r, $user);
			$user->{state}{page_adless} = $subscribe->adlessPage($r, $user);
		}
	}
	if (!$user->{is_subscriber} && $constants->{daypass}) {
		# If the user is not a subscriber, they may still be
		# _effectively_ a subscriber if they have a daypass.
		my $daypass_db = getObject('Slash::Daypass', { db_type => 'reader' });
		if ($daypass_db && $daypass_db->userHasDaypass($user)) {
#			$user->{is_subscriber} = 1;
			$user->{has_daypass} = 1;
			$user->{state}{page_plummy} = 1;
			$user->{state}{page_buying} = 0;
			$user->{state}{page_adless} = 0;
print STDERR scalar(localtime) . " Env.pm $$ userHasDaypass uid=$user->{uid} cs=$constants->{subscribe} is=$user->{is_subscriber} cd=$constants->{daypass}\n";
		}
	}

	if ($user->{seclev} >= 100) {
		$user->{is_admin} = 1;
		# can edit users and do all sorts of cool stuff
		$user->{is_super_admin} = 1 if $user->{seclev} >= 10_000 || $user->{acl}{super_admin};

		# cookie no longer used, remove it if it is there -- pudge
		setCookie('session', '') if $cookies->{session};
		# this no longer "gets" anything, it only sets -- pudge
		$slashdb->getSessionInstance($uid);

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

	$user->{test_code} ||= $constants->{test_code};

	if ($constants->{plugin}{Tags}) {
		my $max_uid;
		my $write = $constants->{tags_stories_allowwrite} || 0;
		$user->{tags_canwrite_stories} = 0;
		$user->{tags_canwrite_stories} = 1 if
			!$user->{is_anon} && (
				   $write >= 2.5 && $user->{acl}{tags_stories_allowwrite}
				|| $write >= 2 && $user->{is_subscriber}
				|| $write >= 1 && $user->{is_admin}
			);
		if (!$user->{is_anon} && !$user->{tags_canwrite_stories}) {
			$user->{tags_canwrite_stories} = 1 if
				   $write >= 4
				|| $write >= 3 && $user->{karma} >= 0;
			if ($user->{tags_canwrite_stories} && $constants->{tags_userfrac_write} < 1) {
				$max_uid = $slashdb->countUsers({ max => 1 });
				if ($user->{uid} > $max_uid*$constants->{tags_userfrac_write}) {
					$user->{tags_canwrite_stories} = 0;
				}
			}
		}
		my $read;
		if ($user->{tags_canwrite_stories} || $constants->{tags_stories_allowread} >= 5) {
			$user->{tags_canread_stories} = 1;
		} else {
			$read = $constants->{tags_stories_allowread} || 0;
			$user->{tags_canread_stories} = 0;
			$user->{tags_canread_stories} = 1 if
				!$user->{is_anon} && (
					   $read >= 2.5 && $user->{acl}{tags_stories_allowread}
					|| $read >= 2 && $user->{is_subscriber}
					|| $read >= 1 && $user->{is_admin}
				);
		}
		if (!$user->{is_anon} && !$user->{tags_canread_stories}) {
			$user->{tags_canread_stories} = 1 if
					   $read >= 4
					|| $read >= 3 && $user->{karma} >= 0;
			if ($user->{tags_canread_stories} && $constants->{tags_userfrac_read} < 1) {
				$max_uid ||= $slashdb->countUsers({ max => 1 });
				if ($user->{uid} > $max_uid*$constants->{tags_userfrac_read}) {
					$user->{tags_canread_stories} = 0;
				}
			}
		}
	}

	return $user;
}

#========================================================================

# For DB types that can have multiple replicated slaves, it is important
# that, on any given request, the user always work with one DB of that
# type.  This is because one slave may be further along in replication
# than another, and switching between two slaves that are literally at
# different points in time could cause chaos.  So, for each type of DB
# that is available, we pick exactly one virtual user and assign it.
# Those settings will not change throughout the script -- the Apache
# page delivery, or the running of the slashd task, or whatever.

sub setUserDBs {
	my($user) = @_;
	my $slashdb = getCurrentDB();

	my $dbs = $slashdb->getDBs();

	# Run through the hashref of all DBs returned and mark how many
	# types we're going to need to set.
	my %user_types = ( );
	for my $dbid (keys %$dbs) {
		$user_types{ $dbs->{$dbid}{type} } = 1;
	}

	# Now for each type needed, pick a DB (at random) and assign it.
	for my $type (sort keys %user_types) {
		$user_types{$type} = $slashdb->getDB($type);
	}

	saveUserDBs($user, \%user_types) if $user;
	return \%user_types;
}

#========================================================================

sub saveUserDBs {
	my($user, $user_types) = @_;
	for my $type (keys %$user_types) {
		$user->{state}{dbs}{$type} = $user_types->{$type};
	}
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
		st_main_select
		stc_main_select
	);

	# fields that are numeric only
	my %nums = map {($_ => 1)} qw(
		approved artcount art_offset bseclev
		buymore cid clbig clsmall cm_offset
		commentlimit commentsort commentspill
		del displaystatus limit
		filter_id hbtm height highlightthresh
		issue last maillist max
		maxcommentsize maximum_length maxstories
		min min_comment minimum_length minimum_match next
		nobonus_present
		nosubscriberbonus_present nv_offset 
		ordernum pid submittable
		postanon_present posttype ratio retrieve
		show_m1s show_m2s
		seclev start startat threshold
		thresh_count thresh_secs thresh_hps
		uid uthreshold voters width
		textarea_rows textarea_cols tokens
		s subid stid stoid tpid tid qid aid pagenum
		url_id spider_id miner_id keyword_id
		st_main_select stc_main_select
		parent_topic child_topic
		skid primaryskid d2_comment_q d2_comment_order
	),
	# Survey
	qw(
		svid sqid ordnum next_sqid condnext_sqid sqcid
		owneruid discussionid uid_min uid_max
		expyear expmonth expday exphour expmin
		openyear openmonth openday openhour openmin
	);

	# fields that have ONLY a-zA-Z0-9_
	my %alphas = map {($_ => 1)} qw(
		commentstatus comments_control content_type
		fieldname filter formkey hcanswer id
		mode op reskey section thisname type
	),
	# Survey
	qw(
		svsid
	);

	# regexes to match dynamically generated numeric fields
	my @regints = (qr/^reason_.+$/, qr/^votes.+$/, qr/^people_bonus_.+$/);

	# special few
	my %special = (
		logtoken	=> sub { $_[0] = '' unless
					 $_[0] =~ m|^\d+::[A-Za-z0-9]{22}$|		},
		sid		=> sub { $_[0] = '' unless
					 $_[0] =~ Slash::Utility::Data::regexSid()	},
		flags		=> sub { $_[0] =~ s|[^a-z0-9_,]||g			},
		query		=> sub { $_[0] =~ s|[\000-\040<>\177-\377]+| |g;
			        	 $_[0] =~ s|\s+| |g;				},
		colorblock	=> sub { $_[0] =~ s|[^\w#,]+||g				},
# What I actually want to do for userfield is allow it to match
# [\w.]+, or pass emailValid(), or be changed to the return value
# from nickFix().  For technical reasons I'm putting that off
# until probably next week.  Until then this breaks some very
# minor functionality. - Jamie 2008-01-09
		userfield	=> sub { $_[0] =~ s|[^\w.@ -]||g			},
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

	for my $formkey (keys %form) {
		if ($formkey eq '_multi') {
			# This is the placeholder we just created
			# a moment ago.
			for my $multikey (keys %{$form{_multi}}) {
				my @data;
				for my $data (@{$form{_multi}{$multikey}}) {
					push @data, filter_param($multikey, $data);
				}
				$form{_multi}{$multikey} = \@data;
			}			
		} elsif (ref($form{$formkey}) eq 'ARRAY') {
			my @data;
			for my $data (@{$form{$formkey}}) {
				push @data, filter_param($formkey, $data);
			}
			$form{$formkey} = \@data;
		} else {
			$form{$formkey} = filter_param($formkey, $form{$formkey});
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
sub _testExStrNumeric {
	my($str, $do_sort) = @_;
	return "" if !$str;
	my @n = split ',', $str;

	# Strip off quotes, which were saved earlier and may be present
	# in old data, leaving only numeric data.
	for (@n) { tr/0-9//cd }

	# Verify the data is numeric (no empty strings).
	@n = grep /^\d+$/, @n;

	# Sort if necessary.
	@n = sort { $a <=> $b } @n if $do_sort;

	return join ",", @n;
}

########################################################
sub _testExStr {
	my($str, $do_sort) = @_;
	return "" if !$str;
	my @n = split ',', $str;
	# Sort if necessary.
	@n = sort @n if $do_sort;
	return join ",", @n;
}

########################################################
# fix parameter input that should be integers
sub fixint {
	my($int) = @_;
	$int =~ s/^([+-]?[\d.]+).*$/$1/s or return;
	return $int;
}


#========================================================================

=head2 setUserDate(USER)

Sets some date information for the user, including date format, time zone,
and time zone offset from GMT.  This is a separate function because the
logic is a bit complex, and it needs to happen in two different places:
anonymous coward creation in the httpd creation, and each time a user is
prepared.

=over 4

=item Parameters

=over 4

=item USER

The user hash reference.

=back

=item Return value

None.

=back

=cut

sub setUserDate {
	my($user) = @_;
	my $slashdb = getCurrentDB();

	my $dateformats   = $slashdb->getDescriptions('datecodes');
	$user->{'format'} = $dateformats->{ $user->{dfid} };

	my $timezones     = $slashdb->getTZCodes;
	my $tz            = $timezones->{ $user->{tzcode} };
	$user->{off_set}  = $tz->{off_set};  # we need for calculation

	my $is_dst = 0;
	if ($user->{dst} && $user->{dst} eq "on") {  # manual on ("on")
		$is_dst = 1;

	} elsif (!$user->{dst}) { # automatic (calculate on/off) ("")
		$is_dst = isDST($tz->{dst_region}, $user);

	} # manual off ("off")

	if ($is_dst) {
		# if tz has no dst_off_set, default to base off_set + 3600 (one hour)
		$user->{off_set}     = defined $tz->{dst_off_set}
			? $tz->{dst_off_set}
			: ($tz->{off_set} + 3600);

		# if tz no dst_tz, fake a new tzcode by appending ' (D)'
		# (tzcode is rarely used, this shouldn't matter much)
		$user->{tzcode_orig} = $user->{tzcode};
		$user->{tzcode}      = defined $tz->{dst_tz}
			? $tz->{dst_tz}
			: ($user->{tzcode} . ' (D)');
	} else {
		$user->{off_set}     = $tz->{off_set};
	}
}

#========================================================================

=head2 isDST(REGION [, USER, TIME, OFFSET])

Returns boolean for whether given time, for given user, is in Daylight
Savings Time.

=over 4

=item Parameters

=over 4

=item REGION

The name of the current DST region (e.g., America, Europe, Australia).
It must match the C<region> column of the C<dst> table.

=item USER

You will get better results if you pass in the USER, but it is optional.

=item TIME

Time in seconds since beginning of epoch, in GMT (which is the default
for Unix).  Optional; default is current time if undefined.

=item OFFSET

Offset of current timezone in seconds from GMT.  Optional; default is
current user's C<off_set> if undefined.

=back

=item Return value

Boolean for whether we are currently in DST.

=back

=cut

{
my %last = (
	1	=> 28, # yes, i know, February may have 29 days; but barely worth fixing
	2	=> 31, # barely worth fixing, since we don't even currently have
	3	=> 30, # a DST region that uses the end of February, though some
	8	=> 30, # do exist -- pudge
	9	=> 31,
	10	=> 30,
);

# we don't bother trying to figure out exact offset for calculations,
# since that is what we are changing!  if we are off by an hour per year,
# oh well, unless someone has a solution.

sub isDST {
	my($region, $user, $unixtime, $off_set) = @_;

	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	$user     ||= getCurrentUser();
	my $regions = $reader->getDSTRegions;

	return 0 unless $region;
	my $start = $regions->{$region}{start} or return 0;
	my $end   = $regions->{$region}{end}   or return 0;

	$unixtime = time unless defined $unixtime;
	$off_set  = $user->{off_set} unless defined $off_set;

	my($hour, $mday, $month, $wday) = (gmtime($unixtime + $off_set))[2,3,4,6];


	# if we are outside the monthly boundaries, the calculations is easy
	# assume start and end months are different
	if ($start->[DST_MON] < $end->[DST_MON]) { # up over
		return 1 if $month > $start->[DST_MON]  &&  $month < $end->[DST_MON];
		return 0 if $month < $start->[DST_MON]  ||  $month > $end->[DST_MON];

	} else { # down under
		return 1 if $month > $start->[DST_MON]  ||  $month < $end->[DST_MON];
		return 0 if $month < $start->[DST_MON]  &&  $month > $end->[DST_MON];
	}

	# assume, by now, that current month contains either start or end date
	for my $mon ($start, $end) {
		if ($month == $mon->[DST_MON]) {
			my($max_day, $switch_day);

			# 1st, 2d, 3d ${foo}day of month
			if ($mon->[DST_NUM] > 0) {
				$max_day = ($mon->[DST_NUM] * 7) - 1;
			# last, second-to-last $fooday of month
			} else { # assume != 0
				$max_day = $last{$month} - ((abs($mon->[DST_NUM]) - 1) * 7);
			}

			# figure out the day we switch
			$switch_day = $mday - ($wday - $start->[DST_DAY]);

			$switch_day += 7 while $switch_day < $max_day;
			$switch_day -= 7 while $switch_day > $max_day;

			my($v1, $v2) = (1, 0);
			# start/end are the same, except for the reversed values here
			($v1, $v2) = ($v2, $v1) if $month == $end->[DST_MON];

			return $v1 if	$mday >  $switch_day;
			return $v1 if	$mday == $switch_day
					&& $hour >= $start->[DST_HR];
			return $v2;
		}
	}
	return 0; # we shouldn't ever get here, but if we do, assume not in DST
}
}

#========================================================================

=head2 getObject(CLASS_NAME [, VIRTUAL_USER, ARGS])
=head2 getObject(CLASS_NAME [, OPTIONS, ARGS])

Returns a object in CLASS_NAME, using the new() constructor.  It passes
VIRTUAL_USER and ARGS to it, and then caches it by CLASS_NAME and VIRTUAL_USER.
If the object for that CLASS_NAME/VIRTUAL_USER exists the second time through,
it will just return, without reinitializing (even if different ARGS are passed,
so don't do that; see "nocache" option).

In the second form, OPTIONS is a hashref.

=over 4

=item Parameters

=over 4

=item CLASS_NAME

A class name to use in creating a object.  Only [\w:] characters are allowed.

=item VIRTUAL_USER

Optional; will default to main Virtual User for site if not supplied.
Passed as second argument to the new() constructor (after class name).

=item OPTIONS

Optional; several options are currently recognized.

=over 4

=item virtual_user

String.  This is handled the same was as the first form, as though using
VIRTUAL_USER, but allows for passing other options too.  Overrides "db_type"
option.

=item db_type

String.  There are types of DBs (reader, writer, search, log), and there may be more
than one DB of each type.  By passing a db_type instead of a virtual_user, you
request any DB of that type, instead of a specific DB.

If neither "virtual_user" or "db_type" is passed, then the function will do a
lookup of the class for what type of DB handle it wants, and then pick one
DB at random that is of that type.

=item nocache

Boolean.  Get a new object, not a cached one.  Also won't cache the resulting object
for future calls.

=back


=item ARGS

Any other arguments to be passed to the object's constructor.

=back

=item Return value

An object, unless object cannot be gotten; then undef.

=back

=cut

sub getObject {
	my($class, $data, @args) = @_;
	my($vuser, $cfg, $objects);
	my $user = getCurrentUser();

	# clean up dangerous characters
	$class =~ s/[^\w:]+//g;

	# Determine the db_type and the virtual user, based on the data
	# passed in (if any), the 'classes' var (see getClasses()),
	# and $user->{state}{dbs}.
	if (!$data || ref $data eq 'HASH') {
		# If we were passed a hash, or no data at all...
		$data ||= {};
		if ($data->{virtual_user}) {
			$vuser = $data->{virtual_user};

		} else {
			# For now, the $class specified is really only used to
			# bless the returned object.  In theory setting rows in
			# the classes table properly (which ends up in the var
			# named 'classes') should also provide correct db_type
			# and fallback data for that class.  But the classes
			# table hasn't been tested in production.
			my $classes = getCurrentStatic('classes');

			# try passed db first, then db for given class
			my $db_type  = $data->{db_type}  || $classes->{$class}{db_type};
			my $fallback = $data->{fallback} || $classes->{$class}{fallback};

			$vuser = ($db_type  && $user->{state}{dbs}{$db_type})
			      || ($fallback && $user->{state}{dbs}{$fallback});

			return undef if $db_type && $fallback && !$vuser;
		}
	} elsif (!ref $data) {
		# If we were passed a plain string, use that as
		# the virtual user...
		$data = { virtual_user => $data };
		$vuser = $data->{virtual_user};
	}

	# The writer is the logical DB to default to if nothing is specified.
	$vuser ||= $user->{state}{dbs}{writer} || getCurrentVirtualUser();
	return undef unless $vuser && $class;

	if ($ENV{GATEWAY_INTERFACE} && (my $r = Apache->request)) {
		$cfg     = Apache::ModuleConfig->get($r, 'Slash::Apache');
		$objects = $cfg->{'objects'} ||= {};
	} else {
		$objects = $static_objects   ||= {};
	}

	if (!$data->{nocache} && $objects->{$class, $vuser}) {
		# We tried this before (and we're allowed to use the cache
		# to return the last result).
		if ($objects->{$class, $vuser} eq 'NA') {
			# It failed.  Don't waste time retrying.
			return undef;
		}
		# We tried this before and it succeeded.
		return $objects->{$class, $vuser};
	}

	# We either haven't tried loading this class before, or were
	# asked not to use the cache.
	if (loadClass($class)) { # 'require' the class
		if ($class->isInstalled($vuser) && $class->can('new')) {
			my $object = $class->new($vuser, @args);
			if ($object) {
				$objects->{$class, $vuser} = $object if !$data->{nocache};
				return $object;
			}
			errorLog("Class $class is installed for '$vuser' but returned false for new()");
		}
	} else {
		if ($@) {
			errorLog("Class $class could not be loaded: '$@'");
		} elsif (!$class->can('new')) {
			errorLog("Class $class is not returning an object, or"
				. " at least not one that has a new() method.  Try"
				. "`perl -M$class -le '$class->new'` to see why");
		} else {
			errorLog("Class $class could not be loaded");
		}
	}

	# We got here because the 'return' in the successful case above
	# was not reached.  So we know either the attempt to 'require'
	# the class or call new() for the class failed.  Unless the
	# caller requested that we not cache this information, mark the
	# cache so we don't waste time with those shenanigans again.
	$objects->{$class, $vuser} = 'NA' if !$data->{nocache};
	return undef;
}

{
my %classes;
sub loadClass {
	my($class) = @_;

	# If we use a cache, we won't actually call eval.  If that's the
	# case, make sure we don't mislead the caller as to whether
	# there's an error.
	undef $@;

	if ($classes{$class}) {
		# The eval to load this class was called earlier.  If it
		# succeeded, this cached value will be 1;  otherwise it
		# will be 'NA'.  Note that in this case, we return false
		# indicating error without setting $@ to what the error
		# was.
		return($classes{$class} ne 'NA');
	}

	# To avoid calling eval unless necessary (eval'ing a string is slow),
	# we also check %INC.  If this class was perhaps require'd by some
	# other part of the code, we can avoid an eval here.
	(my $file = $class) =~ s|::|/|g;
	eval "require $class" unless exists $INC{"$file.pm"};
	
	if ($@) {
		# Our attempt to load the class failed.  Return false,
		# and in this case, $@ tells what the error was.
		$classes{$class} = 'NA';
		return 0;
	}
	# We loaded the class successfully.  Set the cache to 1 to
	# short-circuit the next time loadClass is called, and
	# return true.
	return $classes{$class} = 1;
}
}

{
my %coderefs;
sub loadCoderef {
	my($class, $function) = @_;
	my $full = $class . '::' . $function;


	if ($coderefs{$full}) {
		if ($coderefs{$full} eq 'NA') {
			return 0;  # previous failure
		}
		return $coderefs{$full};  # previous success
	}

	return 0 unless loadClass($class);

	my $code;
	{
		no strict 'refs';
		$code = \&{ $full };
	}

	if (defined &$code) {
		return $coderefs{$full} = $code;
	} else {
		$coderefs{$full} = 'NA';
		return 0;
	}
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
	return if $Slash::Utility::NO_ERROR_LOG;

	# if set to 0, goes until no more callers found
	my $max_level = defined $Slash::Utility::MAX_ERROR_LOG_LEVEL
		? $Slash::Utility::MAX_ERROR_LOG_LEVEL
		: 2;

	my $level = 1;
	$level++ while (caller($level))[3] =~ /log/i;  # ignore other logging subs

	my(@errors, $package, $filename, $line);

	($package, $filename, $line) = caller($level++);
	push @errors, ":$package:$filename:$line:@_";
	$max_level--;

	while ($max_level--) {
		($package, $filename, $line) = caller($level++);
		last unless $package;
		push @errors, "Which was called by:$package:$filename:$line";
	}

	if ($ENV{GATEWAY_INTERFACE} && (my $r = Apache->request)) {
		$errors[0] = $ENV{SCRIPT_NAME} . $errors[0];
		$errors[-1] .= "\n";
		$r->log_error($_) for @errors;
	} else {
		$errors[0] = 'Error' . $errors[0];
		print STDERR $_, "\n" for @errors;
	}

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
	my @args = grep { defined $_ } @_;
	my $dat = @args ? join("\t", @args) : '';

	my $r = Apache->request;

	# Notes has a bug (still in apache 1.3.17 at
	# last look). Apache's directory sub handler
	# is not copying notes. Bad Apache!
	# -Brian
	$r->err_header_out(SLASH_LOG_DATA => $dat);
}

sub getOpAndDatFromStatusAndURI {
	my($status, $uri, $dat) = @_;
	$dat ||= "";

	# XXX check regexSid()
	my $page = qr|\d{2}/\d{2}/\d{2}/\d{4,7}|;

	if ($status == 302) {
		# See mod_relocate -Brian
		if ($uri =~ /\.relo$/) {
			my $apr = Apache::Request->new(Apache->request);
			$dat = $apr->param('_URL');
			$uri = 'relocate';
		} else  {
			$dat = $uri;
			$uri = 'relocate-undef';
		}
	} elsif ($status == 404) {
		$dat = $uri;
		$uri = 'not found';
	} elsif ($uri =~ /^\/palm/) {
		($dat = $ENV{REQUEST_URI}) =~ s|\.shtml$||;
		$uri = 'palm';
	} elsif ($uri eq '/') {
		$uri = 'index';
	} elsif ($uri =~ /\.ico$/) {
		$uri = 'image';
	} elsif ($uri =~ /\.jpg$/) {
		$uri = 'image';
	} elsif ($uri =~ /\.jpeg$/) {
		$uri = 'image';
	} elsif ($uri =~ /\.gif$/) {
		$uri = 'image';
	} elsif ($uri =~ /\.tiff$/) {
		$uri = 'image';
	} elsif ($uri =~ /\.png$/) {
		$uri = 'image';
	} elsif ($uri =~ /\.(?:rss|xml|rdf|atom)$/ || $ENV{QUERY_STRING} =~ /\bcontent_type=(?:rss|xml|rdf|atom)\b/) {
		$dat = $uri;
		$uri = 'rss';
	} elsif ($uri =~ /\.pl$/) {
		$uri =~ s|^/(.*)\.pl$|$1|;
		if ($uri eq "ajax") {
			my $form = getCurrentForm();
			if ($form && $form->{op}) {
				my $user = getCurrentUser;
				if ($user->{state}{ajax_accesslog_op}) {
					$uri = $user->{state}{ajax_accesslog_op};
				} else {
					my $reader = getObject('Slash::DB', { db_type => 'reader' });
					my $class = $reader->getClassForAjaxOp($form->{op});
					$class =~s/^Slash:://g;
					$class =~s/::/_/g;
					$class =~ tr/A-Z/a-z/;
					$uri = "ajax_$class" if $class;
				}
			}
		}
	# This is for me, I am getting tired of patching my local copy -Brian
	} elsif ($uri =~ /\.tar\.gz$/) {
		$uri =~ s|^/(.*)\.tar\.gz$|$1|;
	} elsif ($uri =~ /\.rpm$/) {
		$uri =~ s|^/(.*)\.rpm$|$1|;
	} elsif ($uri =~ /\.dmg$/) {
		$uri =~ s|^/(.*)\.dmg$|$1|;
	} elsif ($uri =~ /\.css$/) {
		$uri = 'css';
	} elsif ($uri =~ /\.js$/) {
		$uri = 'js';
	} elsif ($uri =~ /\.shtml$/) {
		$uri =~ s|^/(.*)\.shtml$|$1|;
		$dat = $uri if $uri =~ $page;	
		$uri =~ s|^/?(\w+)/?(.*)|$1|;
		my $suspected_handler = $2;
		my $handler;
		my $reader = getObject('Slash::DB', { db_type => 'reader' });
		if ($handler = $reader->getSection($uri, 'index_handler')) {
			$handler =~ s|^(.*)\.pl$|$1|;
			$uri = $handler if $handler eq $suspected_handler;
		}
	} elsif ($uri =~ /\.html$/) {
		$uri =~ s|^/(.*)\.html$|$1|;
		$dat = $uri if $uri =~ $page;	
		$uri =~ s|^/?(\w+)/?.*|$1|;
	
	# for linux.com -- maps things like /howtos/HOWTO-INDEX/ to howtos which is what we want
	# if this isn't desirable for other sites we can add a var to control this on a per-site
	# basis.  --vroom 2004/01/27
	} elsif ($uri =~ m|^/([^/]*)/([^/]*/)+$|) {
		$uri = $1;
	}
	$uri = 'image' if $uri eq 'images';
	($uri, $dat);
}

sub createLog {
	my($uri, $dat, $status) = @_;
	my $constants = getCurrentStatic();

	# At this point, if we have short-circuited the
	# "PerlAccessHandler  Slash::Apache::User"
	# by returning an apache code like DONE before that processing
	# could take place (which currently happens in Banlist.pm), then
	# prepareUser() has not been called, thus the $user->{state}{dbs}
	# table is not set up.  So to make sure we write to the proper
	# logging DB (assuming there is one), we have to use the old-style
	# arguments to getObject(), instead of passing in {db_type=>'log'}.
	# - Jamie 2003/05/25
	my $logdb = getObject('Slash::DB', { virtual_user => $constants->{log_db_user} });

	my($op, $new_dat) = getOpAndDatFromStatusAndURI($status, $uri, $dat);
	my $user = getCurrentUser();

	# Always log this hit to accesslog, unless this is an admin hitting
	# admin.pl and the log_admin var has been set to false (this will
	# help small sites keep admin traffic out of that log, which really
	# is of questionable value since crawlers will be just as bad, but
	# hey, we offer site admins the option anyway).
	unless (!$constants->{log_admin} && $user->{is_admin} && $uri =~ /admin\.pl/) {
		$logdb->createAccessLog($op, $new_dat, $status);
	}

	# If this is an admin user, all hits go into accesslog_admin.
	if ($user->{is_admin}) {
		$logdb->createAccessLogAdmin($op, $new_dat, $status);
	}
}

#========================================================================

=head2 createEnvironment([VIRTUAL_USER])

Places data into the request records notes table. The two keys
it uses are SLASH_LOG_OPERATION and SLASH_LOG_DATA.

This does NOT create the current skin, which all scripts are
expected to set themselves with setCurrentSkin().  For doing
so, the function determineCurrentSkin() may be helpful.

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

	########################################
	# Skip the nonsense that used to be here.  Previously we
	# were copying the whole set of constants, and then putting
	# sectional data into it as well, for each section that had
	# a hostname defined.  First of all, of course, sections
	# have become skins so the data can be found in getSkin().
	# But also, we're not doing this stuff with separate sets of
	# constants for each hostname.  Because the skin-specific
	# data is split off into getSkin()'s hashref, we only need
	# one set of data for $constants.  These fields were moved
	# from constants to skins:
	# absolutedir, rootdir, cookiedomain, defaulttopic,
	# defaultdisplaystatus, defaultcommentstatus,
	# basedomain, index_handler, and though I'm not sure
	# it was ever used, absolutedir_secure.
	# These fields are gone because they are now obviated:
	# defaultsubsection, defaultsection, static_section.
	########################################

	my $form = getCurrentForm();

	# We assume that the user for scripts is the anonymous user
	createCurrentDB($slashdb);
	createCurrentStatic($constants);

	# The current anonymous coward may end up changing later,
	# if a new skin is assigned, and the current user may end up
	# changing later if a user is successfully authorized.
	# Either is OK.
	my $gSkin = getCurrentSkin();
#print STDERR scalar(localtime) . " $$ createEnvironment gSkin->skid=$gSkin->{skid} ac_uid=$gSkin->{ac_uid}\n";
	my $ac_uid = $gSkin->{ac_uid} || $constants->{anonymous_coward_uid};
	$ENV{SLASH_USER} = $ac_uid;
	my $user = prepareUser($ac_uid, $form, $0);
	createCurrentUser($user);
	createCurrentAnonymousCoward($user);
}

#========================================================================

=head2 determineCurrentSkin

Returns what the skid of the current skin "should" be.  If we are in
an Apache request, this is done by examining the URL, principally the
hostname but perhaps also the path and the form.  If not, this is done
by examining the form (which was passed on the command line).

Just a placeholder for now, this will be written later.

=over 4

=item Parameters

=over 4

=item Return value

Numeric skid of the current skin.

=back

=cut

sub determineCurrentSkin {
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $skin;

	if ($ENV{GATEWAY_INTERFACE} && (my $r = Apache->request)) {
		my $hostname = $r->header_in('host') || '';
		$hostname =~ s/:\d+$//;
 
		my $skins = $reader->getSkins;
		($skin) = grep {
				(my $tmp = lc $skins->{$_}{hostname} || '') =~ s/:\d+$//;
				$tmp eq lc $hostname
			} sort { $a <=> $b } keys %$skins;

		# don't bother warning if $hostname is numeric IP
		if (!$skin && $hostname !~ /^\d+\.\d+\.\d+\.\d+$/) {
			$skin = getCurrentStatic('mainpage_skid');
			if (!$skin) {
				errorLog("determineCurrentSkin called but no skin found (even default) for '$hostname'\n");
			} else {
				errorLog("determineCurrentSkin called but no skin found (so using default) for '$hostname'\n");
			}
		}
	} else {
		my $form = getCurrentForm();
		$skin   = $reader->getSkidFromName($form->{section}) if $form->{section};
		$skin ||= getCurrentStatic('mainpage_skid');
		if (!$skin) {
			# this should never happen
			errorLog("determineCurrentSkin called but no skin found (even default)");
		}
	}
 
	return $skin;
}

#========================================================================
# XXXSRCID eliminate this or bring it back or something
sub get_ipids {
	my($hostip, $no_md5, $locationid) = @_;
 
	$locationid = getCurrentStatic('cookie_location') if @_ > 2 && !$locationid;
 
	if (!$hostip && $ENV{GATEWAY_INTERFACE}) {
		my $r = Apache->request;
		$hostip = $r->connection->remote_ip;
	} elsif (!$hostip) {
		$hostip = '';
	}
 
	my $ipid = $no_md5 ? $hostip : md5_hex($hostip);
	(my $subnetid = $hostip) =~ s/(\d+\.\d+\.\d+)\.\d+/$1\.0/;
	$subnetid = $no_md5 ? $subnetid : md5_hex($subnetid);
	(my $classbid = $hostip) =~ s/(\d+\.\d+)\.\d+\.\d+/$1\.0\.0/;
	$classbid = $no_md5 ? $classbid : md5_hex($classbid);
 
	if ($locationid) {
		return $locationid eq 'classbid' ? $classbid
		     : $locationid eq 'subnetid' ? $subnetid
		     : $locationid eq 'ipid'     ? $ipid
		     : $locationid eq 'ip'       ? $hostip
		     : '';
	}
 
	return($ipid, $subnetid, $classbid, $hostip);
}

#========================================================================

=head2 get_srcids

Converts an IP address and/or user id to a hashref containing one or
more srcids.

=over 4

=item Parameters

=over 4

=item DATA

A hashref containing one or more of two possible fields:  (1) "uid",
whose value is a user id;  and/or (2) "ip", whose value is a text string
representing an IPv4 address in the form of "1.2.3.4" (IPv6 is not
yet supported), or a false value which means to use the current Apache
connection's remote_ip if invoked within Apache, or the dummy value
"0.0.0.0" otherwise.

=item OPTIONS

An optional hashref containing zero or more options.  The option
'no_md5', if its field is any true value, ensures that IPs encoded into
the returned hashref, while still masked, are not MD5'd but kept in string
"1.2.3.4" form.

The option 'masks' can be a scalar containing a single value or an
arrayref containing multiple values.  By default, only two masked-off
values of an IP are encoded:  a 32-bit and a 24-bit mask (the IP itself
and its Class C subnet).  Any additional values between 1 and 32 may be
passed in in 'masks' and those additional mask sizes will also be
calculated and encoded in the returned hashref.

The option 'return_only' will change the returned value from a hashref
with multiple fields into an array which contains the values of one or
more of what those fields would have been.  The value(s) of 'return_only'
can be: (1) the string "uid" to return just the uid, (2) an integer
between 1 and 32 (which will be implied into the 'masks' option as well),
(3) one of the three strings "ipid", "subnetid", or "classbid" which
are the equivalent of the integers 32, 24, and 16 respectively, or (4)
the string "cookie_location", which will be replaced by the value of
the var 'cookie_location'.

=back

=item Return value

The uid and/or ip converted to an encoded hashref.  If a uid was passed
in, the field "uid" stores the converted uid (which happens to be the
uid itself).  If an ip was passed in, there will be one or more fields
whose names are integer values between 1 and 32 and whose values are
64-bit (16-char) lowercase hex strings with the encoded values of the ip.
There will also be the convenience field "ip" set which contains the
original ip value passed in.  (But see OPTIONS:  if return_only is set,
only one of the fields of the hashref will be returned.)

=back

=cut

sub get_srcids {
	my($hr, $options) = @_;
	$hr ||= { };
	my $retval = { };
	my($no_md5, $return_only, $masks) = _get_srcids_options($options);

	# UIDs are the easy part.  The encoded value of a uid is the uid
	# itself, in decimal form, so we just pass this input along to
	# the output.
	if (my $uid = $hr->{uid}) {
		$retval->{uid} = $uid;
	}

	# IPs are the tricky part.
	if (defined(my $ip = $hr->{ip})) {
		if (!defined($no_md5)) {
			# Error in options passed.
			warn "Error in options passed to get_srcids";
#use Data::Dumper; $Data::Dumper::Sortkeys=1; print STDERR "options: " . Dumper($options);
			return undef;
		}
		if (!$ip) {
			if ($ENV{GATEWAY_INTERFACE}) {
				my $r = Apache->request;
				$ip = $r->connection->remote_ip;
			} elsif (!$ip) {
				$ip = '0.0.0.0';
			}
		}

		$retval->{ip} = $ip; # return the IP passed in, for convenience

		# For each entry in @$masks, we truncate the IPv4 address
		# to that many bits (so 32 is the whole IP address, this
		# works the same way as a /32 mask).  Then convert to
		# a text string of the dotted-quad, truncate to the
		# proper width, and prepend the code indicating what kind
		# of mask has been applied.

		# XXX For IPv6, here's where we need to decide how to
		# extend the value of 'masks' to a 128-bit IP address.
		# For IPv4, we convert the string "1.2.3.4" to the
		# number 0x01020304, mask it, then convert back to
		# dotted-quad string.
		my $n = unpack("N", inet_aton($ip));

		for my $mask (@$masks) {
			my $prepend_code = get_srcid_prependbyte({
				type =>         'ipid',
				mask =>         $mask,
			});
			my $bitmask = ~( 2**(32-$mask) - 1 );
			my $nm = $n & $bitmask;
			my $str = inet_ntoa(pack("N", $nm));
			my $val;
			if ($no_md5) {
				$val = $str;
			} else {
				my $md5 = md5_hex($str);
				my $md5_trunc = substr($md5, 0, 14);
				$val = lc("$prepend_code$md5_trunc");
			}
			$retval->{$mask} = $val;
		}

	}

	if ($return_only) {
		# Return just the value(s) requested, no hashref
		# wrapper around them.
		my @retvals = ( );
		for my $field (@$return_only) {
			push @retvals, $retval->{$field};
		}
		return @retvals;
	}

	return $retval;
}

{ # closure
my %mask_size_name = (
	ipid =>         32,
	subnetid =>     24,
	classbid =>     16,
);

sub convert_srcid {
	my($type, $old_id_str) = @_;
	# UIDs are easy, they haven't changed.
	return $old_id_str if $type eq 'uid';
	# IPs, Subnets, and Class B's get converted to MD5s and then
	# treated like IPIDs, SubnetIDs, and ClassBIDs..
	if ($mask_size_name{"${type}id"}) {
		$old_id_str = md5_hex($old_id_str);
		$type = "${type}id";
	}
	# IPIDs, SubnetIDs, and ClassBIDs get a prepended byte and a
	# truncate to convert them..
	if ($mask_size_name{$type}) {
		my $str_trunc = lc(substr($old_id_str, 0, 14));
		my $prependbyte = get_srcid_prependbyte({
			type => 'ipid',
			mask => $mask_size_name{$type}
		});
		return "$prependbyte$str_trunc";
	}
	# XXXSRCID this is a logic error but handle it better
	die "logic error convert_srcid: type='$type' ois='$old_id_str'";
}

sub _get_srcids_options {
	my($options) = @_;
	my $no_md5 = $options->{no_md5} || 0;

	my $return_only = '';
	if (defined $options->{return_only}) {
		# Pass in no defined value for the return_only field,
		# and get_srcids returns the whole hashref.
		# Pass in a defined value which is either a common
		# name of a mask size, or an integer indicating a
		# mask size, and this function returns only that one
		# value out of the hashref.
		# Pass in the word 'cookie_location', and this function
		# returns only the one value named in the var 'cookie_location'.
		if ($options->{return_only} eq 'cookie_location') {
			$return_only = getCurrentStatic('cookie_location');
		} else {
			$return_only = $options->{return_only};
		}
		my %ro = ( );
		my @k = ref($return_only) ? @$return_only : ( $return_only );
		my @ret = ( );
		for my $k (@k) {
			if ($k =~ /^\d+$/ && $k >= 1 && $k <= 32) {
				# It's already a valid number indicating mask size.
				push @ret, $k;
			} else {
				if ($mask_size_name{$k}) {
					# It's the name of a valid mask.
					push @ret, $mask_size_name{$k};
				} elsif ( $mask_size_name{"${k}id"} ) {
					# It's the name of a valid mask
					# minus the "id", which is close
					# enough.
					push @ret, $mask_size_name{"${k}id"};
				} else {
					# Invalid value, abort.
#use Data::Dumper; $Data::Dumper::Sortkeys=1; print STDERR "k='$k' options: " . Dumper($options);
					return undef;
				}
			}
		}
		$return_only = \@ret;
	}

	my $masks = [ ];
	if ($return_only) {
		# If we've been asked to return specific values,
		# calculate just those values.
		$masks = [ @$return_only ];
	} else {
		if (defined $options->{masks}) {
			$masks = $options->{masks};
			if (!ref $masks) {
				$masks = [ $masks ];
			}
		}
		@$masks = sort grep { /^\d+$/ } @$masks;
		if (!@$masks) {
			# Bad or no option passed in;  use default.
			# XXXSRCID This should be a var.
			$masks = [qw( 16 24 32 )];
		}
	}

	# Return the options the caller's caller asked for.
	return ($no_md5, $return_only, $masks);
}
} # closure

#========================================================================

=head2 get_srcid_prependbyte

This returns the two-character hex code that should be prepended
to a 14-character hex value to create the 16-character hex value
representing either a user ID or an encoded IP address MD5.

=over 4

=item Parameters

=over 4

=item PARAMS

A hash of the parameters.  'type' is a required parameter; its only
defined values so far are 'ipid', indicating an encoded IP address of
some type, or 'uid', indicating a user ID.  Other values may be
possible in future.

=over 4

If 'type' eq 'ipid', the parameter 'mask' must be present, a number
from 1 to 32 indicating how many bits will be present.  For example,
a 24 here would have the same meaning as in '192.168.0.0/24',
signifying the address is a Class C.

=back

=over 4

If 'type' eq 'uid', no other parameters are necessary.

=back

=back

=item Return value

Two-character hex code to prepend.  The bit values of this code are
currently defined as follows:

=over 4

bits 0-2 (MSBs): 0b000=uid; 0b001=IPv4 ipid; other values reserved
for future use.

bits 3-7 (LSBs): if uid, all 0; if IPv4 ipid, 32 minus the mask
size (so 0b00000 indicates a mask size of 32, 0b01000 24, etc.)

=back

Thus the most commonly returned values will be: "00" = uid,
"20" = ipid, "28" = subnetid, "30" = classbid.

=cut

sub get_srcid_prependbyte {
	my($hr) = @_;
	my $val = 0;
	my $type = $hr->{type};
	if ($type eq 'ipid') {
		my $mask32 = 32 - $hr->{mask};
		$val = 0x20 + $mask32;
	} else {
		$val = 0x00;
	}
	return sprintf("%02x", $val);
}

#========================================================================

=head2 decode_srcid_prependbyte(BYTE)

Decodes the byte encoded by encode_prepend_byte.  Returns a
hashref with fields 'type' and, if type is 'ipid', 'mask'.

=cut

sub decode_srcid_prependbyte {
	my($byte) = @_;
	my $val = hex($byte);
	my $type = ($val & 0b11100000) >> 5;
	if ($type == 0) {
		return { type => 'uid' };
	}
	my $mask = 32 - ($val & 0b00011111);
	return {
		type => 'ipid',
		mask => $mask,
	};
}

#========================================================================

=head2 get_srcid_sql_in

Pass this a srcid, either in decimal form (which is what uids will
typically be in) or as a 64-bit (16-char) hex string, and it will return
an SQL function or value which can be used as part of a test against
or an assignment into an SQL integer value.  This value should _not_ be
quoted but rather inserted directly into an SQL request.  For example,
if passed "123" (a user id), will return "CAST('123' AS UNSIGNED)"
(same value, quoted);  if passed "200123456789abcd" (an encoded IP),
will return "CAST(CONV('200123456789abcd', 16, 10) AS UNSIGNED)" which
can be used as an assignment into or test against a BIGINT column.

For speed, does not do error-checking against the value passed in.

There are tricky technical reasons why all values that are used in
comparisons to srcid columns must be wrapped in a CAST(x AS UNSIGNED).
Tricky enough that I submitted a MySQL bug report which turned out to
be not a bug:  <http://bugs.mysql.com/bug.php?id=24759>.  The short
explanation is that any comparison of a number (the srcid column in
the table) to a string results in both being internally converted to
a float before the comparison, and floats with more bits of data than
will fit in their mantissa do not always compare "equal to themselves."
We must ensure that the values compared against the BIGINT column are not
strings, and that means wrapping both a quoted uid ('123' is a string)
and a CONV (which returns a string) in a CAST.  Note that even integers
known to have fewer bits than a float's mantissa, such as uid's, cannot
be quoted strings, as that can break equality testing even for other
properly-CAST values in an IN list.

Usage:

$slashdb->sqlInsert("al2", { srcid => get_srcid_sql_in($srcid) });

=cut

sub get_srcid_sql_in {
	my($srcid) = @_;
	if ($srcid !~ /^[0-9a-f]+$/) {
		my @caller_info = ( );
		for (my $lvl = 1; $lvl < 99; ++$lvl) {
			my @c = caller($lvl);
			last unless @c;
			next if $c[0] =~ /^Template/;
			push @caller_info, "$c[0] line $c[2]";
			last if scalar(@caller_info) >= 3;
		}
		warn "Invalid param to get_srcid_sql_in, callers: @caller_info";
	}
	my $slashdb = getCurrentDB();
	my $srcid_q = $slashdb->sqlQuote($srcid);
	my $type = get_srcid_type($srcid);
	return $type eq 'uid'
		? "CAST($srcid_q AS UNSIGNED)"
		: "CAST(CONV($srcid_q, 16, 10) AS UNSIGNED)";
}

#========================================================================

=head2 get_srcid_sql_out

Pass this the name of a column with srcid data, and it returns the SQL
necessary to retrieve data from that column in srcid format.  The
column data is returned in decimal format if it can be represented in
decimal in an ordinarily-compiled perl, as a hex string otherwise.
"Non-decimal characters in the result will be uppercase," say the docs,
so we lowercase them.

Usage:

$slashdb->sqlSelectColArrayref(get_srcid_sql_out('srcid') . ' AS srcid',
'al2', 'value=1');

=cut

sub get_srcid_sql_out {
	my($colname) = @_;
	return "IF($colname < (1 << 31), $colname, LOWER(CONV($colname, 10, 16)))";
}

#========================================================================

=head2 get_srcid_type

Pass this a srcid, either in decimal form (which is what uids will
typically be in) or as a 64-bit (16-char) hex string, and it will return
the name of the field in a srcid hashref that the data belongs in: either
"uid" for a uid, or an integer between 1 and 32 for an encoded IP.

For speed, does not do error-checking against the value passed in.

=cut

sub get_srcid_type {
	my($srcid) = @_;
	my $is_hex = ( length($srcid) == 16 || $srcid !~ /^\d+$/ );
	if (!$is_hex) {
		# Only uids are allowed to be passed around in decimal
		# form, so this must be a uid.
		return 'uid';
	}
	# Read the code on the front of the string.
	my $code = substr($srcid, 0, 2);
	if ($code eq '00') {
		# Hex-encoded UID.
		return 'uid';
	}
	# That code indicates an IP, and its least significant 5 bits
	# encode the size of the mask used on that IP, which we return.
	my $decval = hex($code);
	return $decval & 0b00011111;
}

#========================================================================

=head2 get_srcid_vis

Pass this a srcid, either in decimal form (which is what uids will
typically be in) or as a 64-bit (16-char) hex string, and it will return
a short text string suitable for display, typically as the text that
is linked in HTML.

For speed, does not do error-checking against the value passed in.

=cut

sub get_srcid_vis {
	my($srcid) = @_;
	my $type = get_srcid_type($srcid);
	return $srcid if $type eq 'uid';
	my $vislen = getCurrentStatic('id_md5_vislength') || 5;
	return substr($srcid, 2, $vislen);
}

#========================================================================
{my($prof_ok, @prof) = (0);
sub slashProf {
	return unless getCurrentStatic('use_profiling') && $prof_ok;
	my($begin, $end) = @_;
	$begin ||= '';
	$end   ||= '';
	push @prof, [ Time::HiRes::time(), (caller(0))[0, 1, 2, 3], $begin, $end ];
}

sub slashProfBail {
	return unless getCurrentStatic('use_profiling') && $prof_ok;
	$prof_ok = 0;
}

sub slashProfInit {
	return unless getCurrentStatic('use_profiling');
	$prof_ok = 1;
	@prof = ();
}

sub slashProfEnd {
	my($prefixstr, $silent) = @_;
	my $use_profiling = getCurrentStatic('use_profiling');
	return unless $use_profiling && $prof_ok && @prof;

	if ($silent) {
		# Output is disabled for this profile.  And after we
		# did all that work!  What a shame :)
		$prof_ok = 0;
		@prof = ();
		return;
	}

	my $first = $prof[0][0];
	my $last  = $first;  # Matthew 20:16
	my $end   = $prof[-1][0];
	my $total = $end - $first;

	$total ||= $first || $end || 1;  # just in case

	my $unit  = ' s';
	my $multi = 1;

	if ($total < 100) {
		$unit    = 'ms';
		$multi  *= 1_000;
		$total  *= 1_000;
	}

	local $\;

	my $user = getCurrentUser();
	my $vislen = getCurrentStatic('id_md5_vislength') || 5;
	my $prefix = sprintf("PROF %d:%d:%s:%s:",
		$$, $user->{uid}, substr($user->{ipid}, 0, $vislen), ($prefixstr || ''));

	print STDERR "\n$prefix *** Begin profiling\n";
	print STDERR "$prefix *** Begin ordered\n" if $use_profiling > 1;
	printf STDERR <<"EOT", "what", "this #", "pct", "tot. #", "pct" if $use_profiling > 1;
$prefix %-64.64s % 6.6s $unit (%6.6s%%) / % 6.6s $unit (%6.6s%%)
EOT

	my(%totals, %begin);
	for my $prof (@prof) {
		my $t1 = ($prof->[0] - $first) * $multi;
		my $t2 = ($prof->[0] - $last) * $multi;
		my $p1 = $t1 / $total * 100;
		my $p2 = $t2 / $total * 100;
		my $s1 = sprintf('%.2f', $p1);
		my $s2 = sprintf('%.2f', $p2);
		$last = $prof->[0];

		# either use passed tag(s), or package/line number
		my $where;
		if ($prof->[6]) {
			$where = "$prof->[6] end";
		}

		if ($prof->[5]) {
			$where .= '; ' if $where;
			$where .= "$prof->[5] begin";
		}
		
		$where ||= sprintf('%56s:%d:', @{$prof}[1, 3]);
		$where =~ s/[\t\r\n]/ /g;
		$where =~ s/^ +//;
		$where =~ s/ +$//;

		# if we know what this is the end of, we want that;
		# if no begin or end, use that; else, punt
		if ($prof->[6] && defined $begin{$prof->[6]}) {
			$totals{$prof->[6]} += $t1 - $begin{$prof->[6]};
			delete $begin{$prof->[6]};
		} elsif (!$prof->[5] && !$prof->[6]) {
			$totals{$where} += $t2;
		}

		# only take away if an end of something
		# (note: assume nested)
		if ($prof->[6]) {
			for (keys %begin) {
				$begin{$_} += $t2 unless $_ eq $prof->[5];
			}
		}

		# mark new beginning
		$begin{$prof->[5]} = $t1 if $prof->[5];

		printf STDERR <<"EOT", $where, $t2, $s2, $t1, $s1 if $use_profiling > 1;
$prefix %-64.64s % 6d $unit (%6.6s%%) / % 6d $unit (%6.6s%%)
EOT
	}

	print STDERR "\n*** Begin summary\n";
	printf STDERR <<"EOT", "what", "time", "pct";
$prefix %-64.64s % 6.6s $unit (%6.6s%%)
EOT
	printf STDERR <<"EOT", 'total', $total, '100.00';
$prefix %-64.64s % 6d $unit (%6.6s%%)
EOT
	for (sort { $totals{$b} <=> $totals{$a} } keys %totals) {
		my $p = $totals{$_} / $total * 100;
		my $s = sprintf('%.2f', $p);
		printf STDERR <<"EOT", $_, $totals{$_}, $s;
$prefix %-64.64s % 6d $unit (%6.6s%%)
EOT
	}

	print STDERR "$prefix *** End profiling\n\n";

	$prof_ok = 0;
	@prof = ();
}
}

######################################################################
# This needs to move into a Slash::Cache along with the code from
# Slash::DB::MySQL
sub getCurrentCache {
	my($value) = @_;
	my $cache;

	if ($ENV{GATEWAY_INTERFACE} && (my $r = Apache->request)) {
		my $cfg = Apache::ModuleConfig->get($r, 'Slash::Apache');
		$cache = $cfg->{'cache'} ||= {};
	} else {
		$cache = $static_cache   ||= {};
	}

	return defined $value ? $cache->{$value} : $cache;
}


######################################################################
# for debugging cached hashes, finding out where they are changing
# inappropriately
# 
# to use this, just do something like this to create the hash:
#
#   my $skins_ref = $self->sqlSelectAllHashref("skid", "*", "skins");
#   if (my $regex = $constants->{debughash_getSkins}) {
#     $skins_ref = debugHash($regex, $skins_ref);
#   }
#
# pass in the regex that contains what a key SHOULD look like (e.g., '^\d+$'),
# and optionally the original data as a hashref; assign result to variable
#
# I am not aware that this has ever been a problem, and I don't
# know of any sites that use the debughash* vars.  Can we delete
# this code? - Jamie 2006-08-27
# 
# It's been a problem before.  We don't use this regularly; you usually
# set it only when you are having the problem.  I say we leave it in,
# in case we need it again.  We have so many hashes like this, and so much
# potential for misuse of them, I think we really should leave it in. -- pudge

sub debugHash {
	my($regex, $hash) = @_;
	$hash = {} unless ref $hash eq 'HASH';
	tie my(%tied), 'Slash::Utility::Environment::Tie', $regex, $hash;
	return \%tied;
}

package Slash::Utility::Environment::Tie;
require Tie::Hash;
our @ISA = 'Tie::ExtraHash';

sub TIEHASH  {
	my($class, $regex, $hash) = @_;
	$hash = {} unless ref $hash eq 'HASH';

	my $ref = ref $regex;
	unless ($ref && $ref eq 'Regex') {
		# if no regex, assume any characters are good
		$regex = '.' unless length $regex;
		$regex = qr{$regex};
	}

	return bless [$hash, $regex], $class;
}

sub STORE {
	my($ref, $key, $value) = @_;
	my($hash, $regex) = @$ref;

	$hash->{$key} = $value;
	if ($key !~ $regex) {
		warn "$$: bad hash: [$key] => [$value]: ", join "|", caller(0);
	}
}

0 if $Slash::Utility::NO_ERROR_LOG; # prevent a "Used only once" warning

1;

__END__


=head1 SEE ALSO

Slash(3), Slash::Utility(3).

=head1 VERSION

$Id$

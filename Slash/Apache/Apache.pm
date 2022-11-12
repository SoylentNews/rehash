# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Apache;

use strict;
use utf8;
use Time::HiRes;
use Apache2::Connection;
use Apache2::Const;
use Apache2::Module;
use Apache2::RequestUtil ();
use Apache2::RequestIO ();
use Slash::DB;
use Slash::Display;
use Slash::Utility;
use URI;

use Data::Dumper;

use vars qw($VERSION $USER_MATCH $DAYPASS_MATCH);

$VERSION   	= '2.003000';  # v2.3.0

$USER_MATCH = qr{ \buser=(?!	# must have user, but NOT ...
	(?: nobody | %[20]0 )?	# nobody or space or null or nothing ...
	(?: \s | ; | $ )	# followed by whitespace, ;, or EOS
)}x;
$DAYPASS_MATCH = qr{\bdaypassconfcode=};

# BENDER: There's nothing wrong with murder, just as long
# as you let Bender whet his beak.

# Apache configuration Directives
my @directives = (
	{ name			=> 'SlashVirtualUser',
	function		=> __PACKAGE__ . '::SlashVirtualUser',
	errmsg			=> 'Takes a DBIx::Password virtual name',
	args_how		=> 'TAKE1',
	req_override		=> 'RSRC_CONF'
	},
	{ name			=> 'SlashSetVar',
	errmsg			=> 'Takes a key and a value that will override the var values in the DB',
	args_how		=> 'TAKE2',
	req_override		=> 'RSRC_CONF'
	},
	{ name			=> 'SlashSetForm',
	errmsg			=> 'Takes a key and a value that will be applied to each form object',
	args_how		=> 'TAKE2',
	req_override		=> 'RSRC_CONF'
	},
	{ name			=> 'SlashSetVarHost',
	errmsg			=> 'Takes a key, a value, and a hostname that will override the var values in the DB for a specific hostname',
	args_how		=> 'TAKE3',
	req_override		=> 'RSRC_CONF'
	},
	{ name			=> 'SlashSetFormHost',
	errmsg			=> 'Takes a key, a value, and a hostname that will be applied to each form object for a specific hostname',
	args_how		=> 'TAKE3',
	req_override		=> 'RSRC_CONF'
	},
	{ name			=> 'SlashCompileTemplates',
	errmsg			=> 'Turn precompiling templates on or off',
	args_how		=> 'FLAG',
	req_override		=> 'RSRC_CONF'
	},
	{ name			=> 'SlashSectionHost',
	errmsg			=> 'Associate a host with a given section name',
	args_how		=> 'TAKE2',
	req_override		=> 'RSRC_CONF'
	}
);

Apache2::Module::add(__PACKAGE__, \@directives);

sub SlashVirtualUser ($$$) {
	my($cfg, $params, $user) = @_;

	###################################
	# MC: this is horridly hacky, but basically, we use %ENV{MOD_PERL}
	# to see if we're in mod_perl, to see if we can use Request APIs
	# However, in early init, we can't do that without Apache crashing
	# so we need to clean up the ENV, then restore it before we exit. What a hack
	$ENV{FORCE_SLASH_STATIC} = 1;

	# In case someone calls SlashSetVar before we have done the big mojo -Brian
	my $overrides = $cfg->{constants};

	createCurrentVirtualUser($cfg->{VirtualUser} = $user);
	createCurrentDB		($cfg->{slashdb} = Slash::DB->new($user));
	createCurrentStatic(     $cfg->{constants} = $cfg->{slashdb}->getSlashConf(0),
	                  $cfg->{constants_secure} = $cfg->{slashdb}->getSlashConf(1) );

	# placeholders ... store extra placeholders in DB?  :)
	for (qw[user form themes template cookie objects cache site_constants]) {
		$cfg->{$_} = '';
	}

	$cfg->{constants}{form_override} ||= {};
	# This has to be a hash
	$cfg->{site_constants} = {};

	if ($overrides) {
		@{$cfg->{constants}}{keys %$overrides} = values %$overrides;
	}

	my $anonymous_coward = $cfg->{slashdb}->getUser(
		$cfg->{constants}{anonymous_coward_uid}
	);

	# Let's just do this once
	setUserDate($anonymous_coward);

	createCurrentAnonymousCoward($cfg->{anonymous_coward} = $anonymous_coward);
	createCurrentUser($anonymous_coward);

	$cfg->{menus} = $cfg->{slashdb}->getMenus();

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

	$cfg->{slashdb}->{_dbh}->disconnect if $cfg->{slashdb}->{_dbh};

	# delete FORCE var
	delete $ENV{FORCE_SLASH_STATIC};
}

sub SlashSetVar ($$$$) {
	my($cfg, $params, $key, $value) = @_;
	unless ($cfg->{constants}) {
		print STDERR "SlashSetVar must be called after call SlashVirtualUser \n";
		exit(1);
	}
	$cfg->{constants}{$key} = $value;
}

sub SlashSetForm ($$$$) {
	my($cfg, $params, $key, $value) = @_;
	unless ($cfg->{constants}) {
		print STDERR "SlashSetForm must be called after call SlashVirtualUser \n";
		exit(1);
	}
	$cfg->{constants}{form_override}{$key} = $value;
}

#sub SlashSetVarHost ($$$$$) {
#	my($cfg, $params, $key, $value, $hostname) = @_;
#	unless ($cfg->{constants}) {
#		print STDERR "SlashSetVarHost must be called after call SlashVirtualUser \n";
#		exit(1);
#	}
#	my $new_cfg;
#	for (keys %{$cfg->{constants}}) {
#		$new_cfg->{$_} = $cfg->{constants}{$_}
#			unless $_ eq 'form_override';
#	}
#	$new_cfg->{$key} = $value;
#	$cfg->{site_constants}{$hostname} = $new_cfg;
#}
#
#sub SlashSetFormHost ($$$$$) {
#	my($cfg, $params, $key, $value, $hostname) = @_;
#	unless ($cfg->{constants}) {
#		print STDERR "SlashSetFormHost must be called after call SlashVirtualUser \n";
#		exit(1);
#	}
#	my $new_cfg;
#	for (keys %{$cfg->{constants}}) {
#		$new_cfg->{$_} = $cfg->{constants}{$_}
#			unless $_ eq 'form_override';
#	}
#	$new_cfg->{form_override}{$key} = $value;
#	$cfg->{site_constants}{$hostname} = $new_cfg;
#}
#
#sub SlashSectionHost ($$$$) {
#	my($cfg, $params, $section, $url)  = @_;
#	my $hostname = $url;
#	$hostname =~ s/.*\/\///;
#	unless ($cfg->{constants}) {
#		print STDERR "SlashSectionHost must be called after call SlashVirtualUser \n";
#		exit(1);
#	}
#	# Yes, this looks slower then the other method but I was getting different results.
#	# Bad results, and it's Friday. Bad results on Friday is a bad thing.
#	# -Brian
#	my $new_cfg;
#	for (keys %{$cfg->{constants}}) {
#		$new_cfg->{$_} = $cfg->{constants}{$_}
#			unless $_ eq 'form_override';
#	}
#	# Must not just copy the form_override info
#	$new_cfg->{form_override} = {};
#	$new_cfg->{absolutedir} = $url;
#	$new_cfg->{absolutedir_secure} = set_rootdir($url, $cfg->{constants}{absolutedir_secure});
#	$new_cfg->{rootdir} = set_rootdir($url, $cfg->{constants}{rootdir});
#	$new_cfg->{basedomain} = $hostname;
#	$new_cfg->{defaultsection} = $section;
#	$new_cfg->{static_section} = $section;
#	# Should no longer be needed -Brian
#	#$new_cfg->{form_override}{section} = $section;
#	$cfg->{site_constants}{$hostname} = $new_cfg;
#}

sub SlashCompileTemplates ($$$) {
	my($cfg, $params, $flag) = @_;
	return unless $flag;

	# set up defaults
	my $slashdb	= $cfg->{slashdb};
	my $constants	= $cfg->{constants};

	# caching must be on, along with unlimited cache size
	return unless $constants->{cache_enabled}
		  && !$constants->{template_cache_size};

	my $start_time = Time::HiRes::time;
	my $begin_printed = 0;
	my $elapsed_time = 0;

	my $templates = $slashdb->getTemplateNameCache();

	# temporarily turn off warnings and errors, see errorLog()
	# This is normally considered a big no no inside of Apache
	# since how will its own signal handlers be put back in place?
	# -Brian
	# what do you mean, put back in place?  when the function
	# finishes, they are all automatically reverted, because
	# of local() -- pudge
	local $Slash::Utility::NO_ERROR_LOG = 1;
	local $SIG{__WARN__} = 'IGNORE';
	local $slashdb->{_dbh}{PrintError};

	# this will call every template in turn, and it will
	# then be compiled; now, we will get errors in
	# the error log for templates that don't check
	# the input values; that can't easily be helped
	my @templates = ( );
	for my $name (sort keys %$templates) {
		for my $page (sort keys %{$templates->{$name}}) {
			for my $skin (sort keys %{$templates->{$name}{$page}}) {
				push @templates, [$name, $page, $skin];
			}
		}
	}
	for my $i (0..$#templates) {
		my($name, $page, $skin) = @{$templates[$i]};
		slashDisplay($name, 0, {
			Page	=> $page,
			Skin	=> $skin,
			Return	=> 1,
			Nocomm	=> 1
		});
		$elapsed_time = Time::HiRes::time - $start_time;
		if (!$begin_printed
			&& ( $i < $#templates * 0.5 && $elapsed_time > 6 * 0.5
			  || $i > 2 && $elapsed_time * $#templates / $i > 6	)
		) {
			# Only bother to print the begin (and done) message
			# if this is taking a while and we're not almost done
			# anyway.
			printf STDERR "%s (%d): Compiling All Templates Begin\n",
				$cfg->{VirtualUser}, $$;
			$begin_printed = 1;
		}
	}

	printf STDERR "%s (%d): Compiling All Templates Done in %0.3f secs\n",
		$cfg->{VirtualUser}, $$, Time::HiRes::time - $start_time
		if $begin_printed;

	$cfg->{template} = Slash::Display::get_template(0, 0, 1);
	# let's make sure
	$slashdb->{_dbh}->disconnect;
}

# This handler is called in the first Apache phase, post-read-request.
#
# This can be used in conjunction with mod_proxy_add_forward or somesuch,
# if you use a frontend/backend Apache setup, where all requests come
# from 127.0.0.1 or some other predictable IP number(s).  For speed, we
# use a closure to store the regex that matches incoming IP number.
{
my $trusted_ip_regex = undef;
my $trusted_header = undef;
sub ProxyRemoteAddr ($) {
	my($class, $r) = @_;

	# Set up the variables that are loaded only once.
	#if (!defined($trusted_ip_regex) || !defined($trusted_header)) {
	#	my $constants = getCurrentStatic();
	#	$trusted_ip_regex = $constants->{clientip_xff_trust_regex};
	#	if ($trusted_ip_regex) {
	#		# Avoid a little processing each time by doing
	#		# the regex parsing just once.
	#		$trusted_ip_regex = qr{$trusted_ip_regex};
	#	} elsif (!defined($trusted_ip_regex)) {
	#		# If not defined, use localhost.
	#		$trusted_ip_regex = qr{^127\.0\.0\.1$};
	#	} else {
	#		# If defined but false, disable.
	#		$trusted_ip_regex = '0';
	#	}
	#	$trusted_header = $constants->{clientip_trust_header} || '';
	#}

	# If the actual IP the connection came from is not trusted, we
	# skip the following processing.  An untrusted client could send
	# any header with any value.
	#if ($trusted_ip_regex eq '0'
	#	|| $r->connection->remote_ip !~ $trusted_ip_regex) {
	#	return OK;
	#}

	# The connection comes from a trusted IP.  Use either the
	# specified header (which presumably the trusted IP overwrites
	# or modifies) and pull from it the last IP on its list (so
	# presumably if the trusted IP does merely modify the header,
	# it appends the actual original IP to its value).
	my $xf = undef;
	$xf = $r->headers_in->{$trusted_header} if $trusted_header;
	$xf ||= $r->headers_in->{'X-Real-IP'} | '';
	if ($xf) {
		# This doesn't strictly speaking handle the case of multiple IPs in
		# XFF, so this probably should be fixed.
		$r->connection->remote_ip($xf);
	}

	return OK;
}
}

sub ConnectionIsSSL {
	# If the connection is made over an SSL connection, it's secure.
	# %ENV won't contain all its fields this early in mod_perl but
	# it's quick to check just in case.

	# if we don't have headers (i.e. config directives, return 0 here
	return 0 if (!exists $ENV{HTTP_HOST});

	return 1 if $ENV{SSL_SESSION_ID};

	# That probably didn't work so let's get that data the hard way.
	my $r = Apache2::RequestUtil->request;
	return 0 if !$r;

	my $x = $r->headers_in->{'X-SFINC-SSL'} || '';
	return 1 if $x && $x eq 'true';

	# This is a very expensive test and not one useful to us.
	# It is doubtful Slashdot will ever turn this back on.
#	my $subr = $r->lookup_uri($r->uri);
#	if ($subr) {
#		my $se = $subr->subprocess_env('HTTPS');
#		return 1 if $se && $se eq 'on'; # https is on
#	}

	$x = $r->headers_in->{'X-SSL-On'} || '';
	return 1 if $x && $x eq 'yes'; 

	# We're out of ideas.  If the above didn't work we must not be
	# on SSL.
	return 0;
}

sub ConnectionIsSecure {
	return 1 if ConnectionIsSSL();

	# If the connection comes from a local IP or a network deemed
	# secure by the admin, it's secure.  (The too-clever-by-half
	# way of doing this would be to check this machine's routing
	# tables.  Instead we have the admins set a regex in a var.)
	my $r = Apache2::RequestUtil->request;
	my $ip = $r->connection->remote_ip;
	my $constants = getCurrentStatic();
	my $secure_ip_regex = $constants->{admin_secure_ip_regex};
	# Check the IP against the regex.  Assume we don't need to wrap
	# this in an "eval" -- it might break, but whoever set it should
	# know what they're doing.  Since this isn't s/// there's no 
	# chance of evaluating it, so this is not exploitable to gain
	# security or damage the site (beyond causing errors for every
	# click) even if it were compromised.
	return 1 if $secure_ip_regex && $ip =~ /$secure_ip_regex/;
 
	# Non-SSL connection, from a network not known to be secure.
	# Call it insecure.
	return 0;
}

sub IndexHandler  {
	my ($class, $r) = @_;

	return DECLINED unless (!$r->main);
	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();
	my $dbon = $slashdb->sqlConnect(); 

	my $uri = $r->uri;
	my $cookie = $r->headers_in->{'Cookie'} || '';
	my $is_user = $cookie =~ $USER_MATCH;
	my $has_daypass = 0;
	my $basedir = $constants->{basedir};
	
	# Bypass skin set if not a regular file
	if ($uri =~ /\.(?:jpg|gif|png|js|css|txt)$/) {
		return DECLINED;
	}

	setCurrentSkin(determineCurrentSkin());
	my $gSkin     = getCurrentSkin();

	if (!$is_user) {
		if ($constants->{daypass} && $cookie =~ $DAYPASS_MATCH) {
			$has_daypass = 1;
		}
	}

	# Remove base rootdir path from uri so that all nexuses behave as mainpage.
	if ($gSkin->{rootdir}) {
		my $path = URI->new($gSkin->{rootdir})->path;
		$uri =~ s/^\Q$path//;
	}
	
	# set index handler
	if ($uri eq '/' && $gSkin->{index_handler} ne 'IGNORE') {
		$r->uri("/$gSkin->{index_handler}");
		$r->filename("$basedir/$gSkin->{index_handler}");
		return OK;
	}

	# check for Edit Plugin
	if ($uri =~ m|^/(\w+)/?$|) {
		my $key = $1;

		if ($constants->{plugin}{Edit}) {
			if ($key =~ /^(submit|submission|story|journal)$/) {
				$r->uri('/edit.pl');
				my $type;
				if ($key ne 'submit') {
					$type = $key;
				}
				$r->uri('/edit.pl');
				my %args = $r->args();
				$args{type} = $type if $type;
				my @add_args;

				foreach (qw(url title type bare new introtext)) {
					push @add_args, "$_=". strip_paramattr($args{$_}) if defined $args{$_};
				}
				$r->args(join('&',@add_args)) if @add_args;
				return OK;
			}
		}
	}

	# MC: Deleted a huge chunk of code here that handled shit of the DB was MIA, which we don't support

	# Handle redirecting nexus links
	# Nexuses can either be in the form of nexus.domain or domain/nexus, in the later case, we can have things like
	# http://domain/nexus/article.pl. We should handle this case properly
	
	if ($uri =~ /\.(?:pl)$/) {
		$r->filename("$basedir$uri");
		return OK;
	}

	return DECLINED;
}

sub DESTROY { }


1;

__END__

=head1 NAME

Slash::Apache - Apache Specific handler for Slash

=head1 SYNOPSIS

	use Slash::Apache;

=head1 DESCRIPTION

This is what creates the SlashVirtualUser command for us
in the httpd.conf file.

=head1 SEE ALSO

Slash(3).

=cut

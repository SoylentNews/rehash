# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Apache;

use strict;
use Apache;
use Apache::SIG ();
use Apache::ModuleConfig;
use Apache::Constants qw(:common);
use Slash::DB;
use Slash::Display;
use Slash::Utility;
use URI;

require DynaLoader;
require AutoLoader;
use vars qw($REVISION $VERSION @ISA $USER_MATCH);

@ISA		= qw(DynaLoader);
$VERSION   	= '2.003000';  # v2.3.0
($REVISION)	= ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

$USER_MATCH = qr{ \buser=(?!	# must have user, but NOT ...
	(?: nobody | %[20]0 )?	# nobody or space or null or nothing ...
	(?: \s | ; | $ )	# followed by whitespace, ;, or EOS
)}x;

bootstrap Slash::Apache $VERSION;

# BENDER: There's nothing wrong with murder, just as long
# as you let Bender whet his beak.

sub SlashVirtualUser ($$$) {
	my($cfg, $params, $user) = @_;

	# In case someone calls SlashSetVar before we have done the big mojo -Brian
	my $overrides = $cfg->{constants};

	createCurrentVirtualUser($cfg->{VirtualUser} = $user);
	createCurrentDB		($cfg->{slashdb} = Slash::DB->new($user));
	createCurrentStatic	($cfg->{constants} = $cfg->{slashdb}->getSlashConf());
	$cfg->{constants}{section} = 'index'; # This is in here till I finish up some work -Brian

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
	my $sections = $cfg->{slashdb}->getSections();
	for (values %$sections) {
		if ($_->{hostname} && $_->{url}) {
			my $new_cfg;
			for (keys %{$cfg->{constants}}) {
				$new_cfg->{$_} = $cfg->{constants}{$_}
					unless $_ eq 'form_override';
			}
			# Must not just copy the form_override info
			$new_cfg->{form_override} = {}; 
			$new_cfg->{absolutedir} = $_->{url};
			$new_cfg->{absolutedir_secure} = set_rootdir($_->{url}, $cfg->{constants}{absolutedir_secure});
			$new_cfg->{rootdir} = set_rootdir($_->{url}, $cfg->{constants}{rootdir});
			$new_cfg->{cookiedomain} = $_->{cookiedomain} if $_->{cookiedomain};
			$new_cfg->{defaultsubsection} = $_->{defaultsubsection} if $_->{defaultsubsection};
			$new_cfg->{defaulttopic} = $_->{defaulttopic} if $_->{defaulttopic};
			$new_cfg->{defaultdisplaystatus} = $_->{defaultdisplaystatus} if $_->{defaultdisplaystatus};
			$new_cfg->{defaultcommentstatus} = $_->{defaultcommentstatus} if $_->{defaultcommentstatus};
			$new_cfg->{defaultsection} = $_->{defaultsection} || $_->{section};
			$new_cfg->{section} = $_->{section};
			$new_cfg->{basedomain} = $_->{hostname};
			$new_cfg->{static_section} = $_->{section};
			$new_cfg->{index_handler} = $_->{index_handler};

# Should no longer be needed -Brian
			#$new_cfg->{form_override}{section} = $_->{section};
			$cfg->{site_constants}{$_->{hostname}} = $new_cfg;
		}
	}
	$cfg->{slashdb}->{_dbh}->disconnect if $cfg->{slashdb}->{_dbh};
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

sub SlashSetVarHost ($$$$$) {
	my($cfg, $params, $key, $value, $hostname) = @_;
	unless ($cfg->{constants}) {
		print STDERR "SlashSetVarHost must be called after call SlashVirtualUser \n";
		exit(1);
	}
	my $new_cfg;
	for (keys %{$cfg->{constants}}) {
		$new_cfg->{$_} = $cfg->{constants}{$_}
			unless $_ eq 'form_override';
	}
	$new_cfg->{$key} = $value;
	$cfg->{site_constants}{$hostname} = $new_cfg;
}

sub SlashSetFormHost ($$$$$) {
	my($cfg, $params, $key, $value, $hostname) = @_;
	unless ($cfg->{constants}) {
		print STDERR "SlashSetFormHost must be called after call SlashVirtualUser \n";
		exit(1);
	}
	my $new_cfg;
	for (keys %{$cfg->{constants}}) {
		$new_cfg->{$_} = $cfg->{constants}{$_}
			unless $_ eq 'form_override';
	}
	$new_cfg->{form_override}{$key} = $value;
	$cfg->{site_constants}{$hostname} = $new_cfg;
}

sub SlashSectionHost ($$$$) {
	my($cfg, $params, $section, $url)  = @_;
	my $hostname = $url;
	$hostname =~ s/.*\/\///;
	unless ($cfg->{constants}) {
		print STDERR "SlashSectionHost must be called after call SlashVirtualUser \n";
		exit(1);
	}
	# Yes, this looks slower then the other method but I was getting different results.
	# Bad results, and it's Friday. Bad results on Friday is a bad thing.
	# -Brian
	my $new_cfg;
	for (keys %{$cfg->{constants}}) {
		$new_cfg->{$_} = $cfg->{constants}{$_}
			unless $_ eq 'form_override';
	}
	# Must not just copy the form_override info
	$new_cfg->{form_override} = {};
	$new_cfg->{absolutedir} = $url;
	$new_cfg->{absolutedir_secure} = set_rootdir($url, $cfg->{constants}{absolutedir_secure});
	$new_cfg->{rootdir} = set_rootdir($url, $cfg->{constants}{rootdir});
	$new_cfg->{basedomain} = $hostname;
	$new_cfg->{defaultsection} = $section;
	$new_cfg->{static_section} = $section;
	# Should no longer be needed -Brian
	#$new_cfg->{form_override}{section} = $section;
	$cfg->{site_constants}{$hostname} = $new_cfg;
}

sub SlashCompileTemplates ($$$) {
	my($cfg, $params, $flag) = @_;
	return unless $flag;

	# set up defaults
	my $slashdb	= $cfg->{slashdb};
	my $constants	= $cfg->{constants};

	# caching must be on, along with unlimited cache size
	return unless $constants->{cache_enabled}
		  && !$constants->{template_cache_size};

	print STDERR "$cfg->{VirtualUser} ($$): Compiling All Templates Begin\n";

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
	for my $t (keys %$templates) {
		my($name, $page, $section) = split /$;/, $t;
		slashDisplay($name, 0, {
			Page	=> $page,
			Section	=> $section,
			Return	=> 1,
			Nocomm	=> 1
		});
	}

	# Pudge, any reason we still need this Begin/Done debug log? - Jamie
	print STDERR "$cfg->{VirtualUser} ($$): Compiling All Templates Done\n";

	$cfg->{template} = Slash::Display::get_template(0, 0, 1);
	# let's make sure
	$slashdb->{_dbh}->disconnect;
}

# This can be used in conjunction with mod_proxy_add_forward or somesuch,
# if you use a frontend/backend Apache setup, where all requests come
# from 127.0.0.1 or some other predictable IP number(s).  For speed, we
# use a closure to store the regex that matches incoming IP number.
{
my $trusted_ip_regex = undef;
sub ProxyRemoteAddr ($) {
	my($r) = @_;

	if (!defined($trusted_ip_regex)) {
		$trusted_ip_regex = getCurrentStatic("x_forwarded_for_trust_regex");
		if ($trusted_ip_regex) {
			# Avoid a little processing each time by doing
			# the regex parsing just once.
			$trusted_ip_regex = qr{$trusted_ip_regex};
		} elsif (!defined($trusted_ip_regex)) {
			# If not defined, use localhost.
			$trusted_ip_regex = qr{^127\.0\.0\.1$};
		} else {
			# If defined but false, disable.
			$trusted_ip_regex = '0';
		}
	}
	return OK if $trusted_ip_regex eq '0';

	# Since any client can forge X-Forwarded-For, we ignore it...
	return OK unless $r->connection->remote_ip =~ $trusted_ip_regex;

	# ...unless the connection comes from a trusted source.
	my $xf = $r->header_in('X-Forward-Pound') || $r->header_in('X-Forwarded-For');
	if (my($ip) = $xf =~ /([^,\s]+)$/) {
		$r->connection->remote_ip($ip);
	}

	return OK;
}
}

sub ConnectionIsSSL {
	# If the connection is made over an SSL connection, it's secure.
	# %ENV won't contain all its fields this early in mod_perl but
	# it's quick to check just in case.
	return 1 if $ENV{SSL_SESSION_ID};

	# That probably didn't work so let's get that data the hard way.
	my $r = Apache->request;
	my $subr = $r->lookup_uri($r->uri);
	my $https_on = ($subr && $subr->subprocess_env('HTTPS') eq 'on')
		? 1 : 0;
	return 1 if $https_on;

	return 1 
		if $r->header_in('X-SSL-On') eq 'yes'; 

	# Nope, it's not SSL.  We're out of ideas, if the above didn't
	# work we must not be on SSL.
	return 0;
}

sub ConnectionIsSecure {
	return 1 if ConnectionIsSSL();

	# If the connection comes from a local IP or a network deemed
	# secure by the admin, it's secure.  (The too-clever-by-half
	# way of doing this would be to check this machine's routing
	# tables.  Instead we have the admins set a regex in a var.)
	my $r = Apache->request;
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

sub IndexHandler {
	my($r) = @_;

	return DECLINED unless $r->is_main;
	my $constants = getCurrentStatic();
	my $uri = $r->uri;
	my $is_user = $r->header_in('Cookie') =~ $USER_MATCH;

	if ($constants->{rootdir}) {
		my $path = URI->new($constants->{rootdir})->path;
		$uri =~ s/^\Q$path//;
	}

	# Comment this in if you want to try having this do the right
	# thing dynamically
	# my $slashdb = getCurrentDB();
	# my $dbon = $slashdb->sqlConnect(); 
	my $dbon = dbAvailable();

	if ($uri eq '/' && $constants->{index_handler} ne 'IGNORE') {
		my $basedir = $constants->{basedir};

		# $USER_MATCH defined above
		if ($dbon && $is_user) {
			$r->uri("/$constants->{index_handler}");
			$r->filename("$basedir/$constants->{index_handler}");
			return OK;
		} elsif(!$dbon) {
			# no db
			$r->uri("/index.shtml");
			return DECLINED;
		} else {
			# user not logged in
	
			# consider using File::Basename::basename() here
			# for more robustness, if it ever matters -- pudge
			my($base) = split(/\./, $constants->{index_handler});
			$base = $constants->{index_handler_noanon}
				if $constants->{index_noanon};

			if ($constants->{static_section}) {
				$r->filename("$basedir/$constants->{static_section}/$base.shtml");
				$r->uri("/$constants->{static_section}/$base.shtml");
			} else {
				$r->filename("$basedir/$base.shtml");
				$r->uri("/$base.shtml");
			}
			writeLog('shtml');
			return OK;
		}
	}

	# match /section/ or /section
	if ($uri =~ m|^/(\w+)/?$|) {
		my $key = $1;
		
		if (!$dbon) {
			$r->uri("/index.shtml");
			return DECLINED;
		}

		my $slashdb = getCurrentDB();
		my $section = $slashdb->getSection($key);
		my $index_handler = $section->{index_handler}
			|| $constants->{index_handler};
		if ($section && $section->{id} && $index_handler ne 'IGNORE') {
			my $basedir = $constants->{basedir};

			# $USER_MATCH defined above
			if ($dbon && $is_user) {
				$r->args("section=$key");
				$r->uri("/$index_handler");
				$r->filename("$basedir/$index_handler");
				return OK;
			} else {
				# user not logged in

				# consider using File::Basename::basename() here
				# for more robustness, if it ever matters -- pudge
				my($base) = split(/\./, $index_handler);
				$r->uri("/$key/$base.shtml");
				$r->filename("$basedir/$key/$base.shtml");
				writeLog('shtml');
				return OK;
			}
		}
	}

	if ($uri eq '/authors.pl') {
		my $filename = $r->filename;
		my $basedir  = $constants->{basedir};

		if (!$dbon || !$is_user) {
			$r->uri('/authors.shtml');
			$r->filename("$basedir/authors.shtml");
			writeLog('shtml');
			return OK;
		}
	}

	if ($uri eq '/hof.pl') {
		my $basedir  = $constants->{basedir};

		$r->uri('/hof.shtml');
		$r->filename("$basedir/hof.shtml");
		writeLog('shtml');
		return OK;
	}

	# redirect to static if not a user, and
	# * var is on
	# * is article.pl
	# * no page number > 1 specified
	# * sid specified
	# * referrer exists AND is external to our site
	if ($constants->{referrer_external_static_redirect} && !$is_user && $uri eq '/article.pl') {
		my $referrer = $r->header_in("Referer");
		my $referrer_domain = $constants->{referrer_domain} || $constants->{basedomain};
		my $the_request = $r->the_request;
		if ($referrer
			&& $referrer !~ m{^(?:https?:)?(?://)?(?:[\w-.]+\.)?$referrer_domain(?:/|$)}
			&& $the_request !~ m{\bpagenum=(?:[2-9]|\d\d+)\b}
			&& $the_request =~ m{\bsid=([\d/]+)}
		) {
			my $sid = $1;
			my $slashdb = getCurrentDB();
			my $section = $slashdb->getStory($sid, 'section') || $constants->{defaultsection};

			my $newurl = "/$section/$sid.shtml";
			if (-e "$constants->{basedir}$newurl") {
				redirect($newurl);
				return DONE;
			}
		}
	}

	if (!$dbon && $uri !~ /\.(?:shtml|jpg|gif|png)$/) {
		# if db is off we don't necessarily have access to constants
		# this means we change the URI and return DECLINED which lets
		# Apache do the URI to filename translation
		$r->uri('/index.shtml');
		writeLog('shtml');
		$r->notes('SLASH_FAILURE' => "db"); # You should be able to find this in other processes
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

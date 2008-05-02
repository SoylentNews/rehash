# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Client;

use strict;
use warnings;

use Digest::MD5 'md5_hex';
use File::Spec::Functions;

our $VERSION = 0.01;

sub new {
	my($class, $opts) = @_;

	my $self = {};
	$self->{host} = $opts->{host} or return;
	$self->{http} = $opts->{ssl} ? 'https' : 'http';

	$self->{uid}  = $opts->{uid};
	$self->{pass} = $opts->{pass};
	$self->{logtoken}    = $opts->{logtoken};
	$self->{cookie_file} = $opts->{cookie_file};

	bless $self, $class;
	return $self;
}

sub soap {
	my($self) = @_;
	my $uri   = $self->{soap}{uri}   or return;
	my $proxy = $self->{soap}{proxy} or return;

	return $self->{soap}{cache} if $self->{soap}{cache};

	require HTTP::Cookies;
	require SOAP::Lite;

	my $cookies = HTTP::Cookies->new;

	if ($self->{logtoken}) {
		$cookies->set_cookie(0, user => $self->{logtoken}, '/', $self->{host});

	} elsif ($self->{uid} && $self->{pass}) {
		my $cookie = bakeUserCookie($self->{uid}, $self->{pass});
		$cookies->set_cookie(0, user => $cookie, '/', $self->{host});

	} else {
		my $cookie_file = $self->{cookie_file} || find_cookie_file();
		if ($cookie_file) {
			$cookies = HTTP::Cookies::Netscape->new;
			$cookies->load($cookie_file);
		}
	}

	my $soap = SOAP::Lite->uri($uri)->proxy($proxy, cookie_jar => $cookies);
	$self->{soap}{cache} = $soap;
	return $soap;
}


sub find_cookie_file {
	my $app = shift || 'Firefox';
	my $file;
	if ($^O eq 'MacOS' || $^O eq 'darwin') {
		require Mac::Files;
		Mac::Files->import(':DEFAULT');

		my($dir, $vref, $type);
		if ($^O eq 'darwin') {
			$vref = &kUserDomain;
			if ($app eq 'Chimera' || $app eq 'Firefox') {
				$type = &kApplicationSupportFolderType;
			} elsif ($app eq 'Mozilla') {
				$type = &kDomainLibraryFolderType;
			}
		} elsif ($^O eq 'MacOS') {
			$vref = &kOnSystemDisk;
			$type = &kDocumentsFolderType;
		}

		$dir = FindFolder($vref, $type, &kDontCreateFolder);
		$dir = catdir($dir, $app, 'Profiles');
		for (0, 1) {
			last if -e catfile($dir, 'cookies.txt');
			opendir(my $dh, $dir) or die "Can't open $dir: $!";
			$dir = catdir($dir, (grep !/^\./, readdir($dh))[0]);
			closedir($dh);
		}
		$file = catfile($dir, 'cookies.txt');
	}
	return $file;
}

sub bakeUserCookie {
	my($uid, $pass) = @_;
	my $cookie = $uid . '::' . md5_hex($pass);
	$cookie =~ s/(.)/sprintf("%%%02x", ord($1))/ge;
	$cookie =~ s/%/%25/g;
	return $cookie;
}

sub literal {
	my($str) = @_;
	$str =~ s/&/&amp;/g;
	$str =~ s/</&lt;/og;
	$str =~ s/>/&gt;/og;
	return $str;
}

sub fixparam {
	my($str) = @_;
	$str =~ s/([^$URI::unreserved ])/$URI::Escape::escapes{$1}/og;
	$str =~ s/ /+/g;
	return $str;
}

1;

__END__

=head1 NAME

Slash::Client - Write clients for Slash

=head1 SYNOPSIS

	my $client = Slash::Client::Journal->new({
		host => 'use.perl.org',
	});
	my $entry = $client->get_entry(10_000);

=head1 DESCRIPTION

Slash::Client allows writing clients to access Slash.  So far, only one
client is implemented: accessing journals, which is done via SOAP.  See
L<Slash::Client::Journal> for more information.

=head2 Constructor

You create an object with the C<new> constructor, which takes a hashref
of options.

=over 4

=item host

The Slash site's host name.

=item ssl

Boolean, true if the Slash site can be accessed via SSL.

=item uid

=item pass

If uid and pass have true values, they are used to construct the cookie
for authentication purposes.  See L<Authentication>.

=item logtoken

Logtoken is used for the cookie if it is passed.

=item cookie_file

Path to the file in Netscape format containing a cookie.

=back

=head2 Authentication

Some methods require authentication; others may require authentication,
depending on the site.

There are three ways to authenticate.  The first that's tried is uid/pass.
If those are not supplied, logtoken is used: this is the value actually
stored in the browser cookie (and used in the query string for some
user-authenticated feed URLS).  The third is to just try to load the cookie
from a cookie file, either passing in a path in cookie_file, or trying to
find the file automatically.

I've only tested the cookie authentication recently with Firefox on Mac OS X.
Feel free to submit patches for other browsers and platforms.

If the given authentication method fails, others are not attempted, and the
method will attempt to execute anyway.


=head1 TODO

Work on error handling.

Other platforms for finding/reading cookies.


=head1 SEE ALSO

Slash::Client::Journal(3).

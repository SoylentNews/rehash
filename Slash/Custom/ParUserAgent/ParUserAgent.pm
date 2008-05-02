# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

# This overrides LWP::Parallel::UserAgent to allow multiple
# proxies to be used with a single scheme, indeed with a
# single URL.  This is done by overriding proxy() to also
# push arguments onto an arrayref instance variable, and
# overriding _need_proxy() to, instead of using the scalar
# single proxy, pop the top proxy off the arrayref (and
# then push it back onto the end of the list, just in case).

package Slash::Custom::ParUserAgent;

use strict;
use base 'LWP::Parallel::UserAgent';
use vars qw($VERSION);

use LWP::Parallel::UserAgent;

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub _need_proxy {
	my($self, $url) = @_;
	$url = $HTTP::URI_CLASS->new($url) unless ref $url;
 
	my $scheme = $url->scheme || return;
	my $proxy;
	if ($self->{slash_proxies}{$scheme}
		&& @{$self->{slash_proxies}{$scheme}}) {
		$proxy = shift @{$self->{slash_proxies}{$scheme}};
		push @{$self->{slash_proxies}{$scheme}}, $proxy;
	} else {
		$proxy = $self->{'proxy'}{$scheme};
	}
	if ($proxy) {
		if (@{ $self->{'no_proxy'} }) {
		    if (my $host = eval { $url->host }) {
			for my $domain (@{ $self->{'no_proxy'} }) {
			    if ($host =~ /\Q$domain\E$/) {
				LWP::Debug::trace("no_proxy configured");
				return;
			    }
			}
		    }
		}
		LWP::Debug::debug("SCP Proxied to $proxy");
		return $HTTP::URI_CLASS->new($proxy);
	}
	LWP::Debug::debug('SCP Not proxied');
	undef;
}

sub proxy {
	my($self, $schemes, $proxyurl) = @_;
	my @schemes = ref $schemes ? @$schemes : ( $schemes );
	LWP::Debug::trace("SCP '@schemes' $proxyurl");
	my $old;
	for my $scheme (@schemes) {
		$old = $self->{proxy}{$scheme};
		$self->{proxy}{$scheme} = $proxyurl;
		$self->{slash_proxies}{$scheme} ||= [ ];
		push @{$self->{slash_proxies}{$scheme}}, $proxyurl;
	}
	return $old;
}

1;

__END__

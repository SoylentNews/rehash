# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::ResKey::Session;

=head1 NAME

Slash::ResKey::Session - Resource management for Slash


=head1 SYNOPSIS

	my $session = getObject('Slash::ResKey::Session');
	my $skey = $session->new; # creates/uses existing session
	$skey->session;       # returns session key
	$skey->expire;        # expire the session
	$skey->params;        # returns hashref of params for this session key
	$skey->param($p);     # set or get a param
	$skey->set_cookie;    # sets cookie (must be called before header())
	$skey->remove_cookie; # removes cookie (must be called before header())

=cut

use warnings;
use strict;

#========================================================================
sub new {
	my($class, $opts) = @_;

	my $skey = bless { _opts => $opts }, $class;
	my $sessionkey = $skey->session;

	my $reskey = getObject('Slash::ResKey') or return 0;
	my $rkey = $reskey->key('session', { nostate => 1, reskey => $sessionkey }) or return 0;
	($rkey->create && $rkey->touch) or return 0;

	$skey->session($rkey->reskey);

	$skey->{_rkey} = $rkey;
	return $skey;
}

#========================================================================
sub session {
	my($self, $newkey) = @_;
	my $cookie = getCurrentCookie();
	if (defined $newkey) {
		$cookie->{sessionkey} = $self->{_sessionkey} = $newkey;
	}
	return $self->{_sessionkey} ||= ($cookie->{sessionkey} || '');
}

#========================================================================
sub expire {
	my($self) = @_;
	$self->{_rkey}->use;
	$self->session('');
}

#========================================================================
sub set_cookie {
	my($self) = @_;
	setCookie('sessionkey', $self->session, "+24h"); # XXX might change time later ...
}

#========================================================================
sub remove_cookie {
	my($self) = @_;
	setCookie('sessionkey', '');
}

#========================================================================
sub param {
	my($self, $name, $value) = @_;
	return unless defined $name && $name;

	if (defined $value) {
		my $slashdb = getCurrentDB();
		if (length $value) {
			$slashdb->sqlReplace('reskey_sessions', {
				name   => $name,
				value  => $value,
				reskey => $self->session
			});
		} else {
			$slashdb->sqlDelete('reskey_sessions',
				'reskey=' . $reader->sqlQuote($self->session)
			);
		}
	} else {
		my $reader = getObject('Slash::DB', { db_type => 'reader' });
		$reader->sqlSelect('value', 'reskey_sessions',
			'name='   . $reader->sqlQuote($name) . ' AND ' .
			'reskey=' . $reader->sqlQuote($self->session)
		);
	}
}

#========================================================================
sub params {
	my($self) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	return $reader->sqlSelectHashref('name,value', 'reskey_sessions',
		'reskey=' . $reader->sqlQuote($self->session)
	) || {};
}



1;

__END__


=head1 SEE ALSO

Slash(3).


=head1 NOTES

need task to purge table

need to define session reskey

need param API

# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Display::Plugin;

=head1 NAME

Slash::Display::Plugin - Template Toolkit plugin for Slash


=head1 SYNOPSIS

	[% USE Slash %]
	[% Slash.someFunction('some data') %]
	[% Slash.db.someMethod(var1, var2) %]


=head1 DESCRIPTION

Call available exported functions from Slash and Slash::Utility
from within your template.  Also call methods from Slash::DB
with the C<db> method.  Constants from Slash::Constants are
available.  Invoke with C<[% USE Slash %]>.

C<[% Slash.version %]> gives the version of Slash.
C<[% Slash.VERSION %]> (note case) gives the version
of this Slash Template plugin.

=cut

use strict;
use vars qw($VERSION $AUTOLOAD);
use Slash ();
use Slash::Constants ();
use Slash::Utility ();
use base qw(Template::Plugin);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# BENDER: Forget your stupid theme park!  I'm gonna make my own!
# With hookers!  And blackjack!  In fact, forget the theme park!

my %subs;
sub _populate {
	return if %subs;
	# mmmmmm, agic
	no strict 'refs';
	for my $pkg (qw(Slash Slash::Utility)) {
		@subs{@{"${pkg}::EXPORT"}} =
			map { *{"${pkg}::$_"}{CODE} } @{"${pkg}::EXPORT"};
	}

	# all constants in EXPORT_OK
	for my $pkg (qw(Slash::Constants)) {
		@subs{@{"${pkg}::EXPORT_OK"}} =
			map { *{"${pkg}::$_"}{CODE} } @{"${pkg}::EXPORT_OK"};
	}

	$subs{version} = sub { Slash->VERSION };
}

sub new {
	_populate();
	my($class, $context, $name) = @_;
	return bless {
		_CONTEXT => $context,
	}, $class;
}

sub db { Slash::Utility::getCurrentDB() }

sub AUTOLOAD {
	# pull off first param before sending to function;
	# that's the whole reason we have AUTOLOAD here,
	# to de-OOP the call
	my $obj = shift;
	(my $name = $AUTOLOAD) =~ s/^.*://;
	return if $name eq 'DESTROY';

	if (exists $subs{$name}) {
		local $Slash::Display::CONTEXT = $obj->{_CONTEXT};
		return $subs{$name}->(@_);
	} else {
		warn "Can't find $name";
		return;
	}
}

1;

__END__

=head1 SEE ALSO

Template(3), Slash(3), Slash::Utility(3), Slash::Display(3).

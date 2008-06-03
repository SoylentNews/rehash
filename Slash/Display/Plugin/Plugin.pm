# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Display::Plugin;

=head1 NAME

Slash::Display::Plugin - Template Toolkit plugin for Slash


=head1 SYNOPSIS

	[% Slash.someFunction('some data') %]
	[% Slash.db.someMethod(var1, var2) %]


=head1 DESCRIPTION

Call available exported functions from Slash and Slash::Utility
from within your template.  Also call methods from Slash::DB
with the C<db> method.  Constants from Slash::Constants are
available.

C<[% Slash.version %]> gives the version of Slash.
C<[% Slash.VERSION %]> (note case) gives the version
of this Slash Template plugin.

C<[% Slash.Display %]> provides access to C<slashDisplay()>.  Use
this B<sparingly>, only when you need to pass in certain options
(such as setting Skin or Page).  In the general case, use
C<PROCESS> in the template, or C<INCLUDE> if necessary.
This method will always set C<Return>, so you may assign its
result to a variable, or call it by itself to have its result
outputted normally.

=head2 Implementation Notes

The C<db> method merely returns the object returned by C<getCurrentDB>,
and then any Slash::DB method may be called on that object.

The API for Slash and Slash::Utility is provided by populating
a hash of C<functionname =E<gt> coderef> for each function in
the C<@EXPORT> array, and then doing a lookup in C<AUTOLOAD>.
Slash::Constants is similar, except it uses the C<@EXPORT_OK>
array.  C<AUTOLOAD> will therefore catch all method calls (except
for a few predefined ones) and will warn if it can't be found.

For all of these, and for the C<Display> plugin method,
the current Template context is stored in a global variable,
which C<slashDisplay> uses, if invoked.  The problem is
that Template will sort of clear itself out if we let it
create a new template object in this case, so we pass along
the current one to be used.

=cut

use strict;
use vars qw($AUTOLOAD);
use Slash ();
use Slash::Utility ();
use base qw(Template::Plugin);

our $VERSION = $Slash::Constants::VERSION;

# BENDER: Forget your stupid theme park!  I'm gonna make my own!
# With hookers!  And blackjack!  In fact, forget the theme park!

my %subs;
sub _populate {
	return if %subs;
	# mmmmmm, agic
	# we are taking all the symbols to exported from certain packages,
	# and adding them as coderefs to @subs.  then in AUTOLOAD below,
	# when that symbol is called, we put it in its proper TT context,
	# and execute it.  simple!
	no strict 'refs';
	for my $pkg (qw(Slash Slash::Utility)) {       # for these packages ...
	                                               # (read rest bottom-to-top):
		@subs{@{"${pkg}::EXPORT"}} =           # save the coderefs for later!
			map  { *{"${pkg}::$_"}{CODE} } # ... get the coderef
			grep { *{"${pkg}::$_"}{CODE} } # if they have a coderef ...
			@{"${pkg}::EXPORT"};           # get the syms from @EXPORT
	}

	# Slash::Constants uses @EXPORT_OK, not @EXPORT
	for my $pkg (qw(Slash::Constants)) {
		@subs{@{"${pkg}::EXPORT_OK"}} =
			map  { *{"${pkg}::$_"}{CODE} }
			grep { *{"${pkg}::$_"}{CODE} }
			@{"${pkg}::EXPORT_OK"};
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

sub db  { Slash::Utility::getObject('Slash::DB', { db_type => 'reader' }) }

# not to be confused with Slash::Test::Display(); that may only be
# called from Slash::Test, this may only be called from plugins
# (see note above)
sub Display {
	my($self, @args) = @_;
	$args[2] ||= {};
	$args[2]{Return} = 1;
	local $Slash::Display::CONTEXT = $self->{_CONTEXT};
	return Slash::Display::slashDisplay(@args);
}

sub AUTOLOAD {
	# pull off first param before sending to function;
	# that's the whole reason we have AUTOLOAD here,
	# to de-OOP the call, since TT wants it to all be
	# OOP-ified and we don't.
	my $self = shift;
	(my $name = $AUTOLOAD) =~ s/^.*://;
	return if $name eq 'DESTROY';

	if (exists $subs{$name}) {
		local $Slash::Display::CONTEXT = $self->{_CONTEXT};
		return $subs{$name}->(@_);
	} else {
		warn "Can't find method '$name'";
		return;
	}
}

1;

__END__

=head1 SEE ALSO

Template(3), Slash(3), Slash::Utility(3), Slash::Display(3).

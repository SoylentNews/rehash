# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Hook;
use strict;
use DBIx::Password;
use Slash;
use Slash::DB;
use Slash::Utility::Environment; # avoid cross-caller issues
use vars qw($VERSION);

# Arrrr Matey...

use base 'Exporter';
use vars qw($VERSION @EXPORT);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;
@EXPORT	   = qw(slashHook);

my %classes;

sub slashHook {
	my($param, $options) = @_;
	my $slashdb = getCurrentDB();

	my $retval = undef;
	my $hooks = $slashdb->getHooksByParam($param);
	for my $hook (@$hooks) {
		my $function = $hook->{class} . '::' . $hook->{subroutine};

		my $code = loadCoderef($hook->{class}, $hook->{subroutine});
		if ($code) {
			$retval = $code->($options);
			if (! defined $retval) {
				errorLog("Failed executing hook ($param) - $function: no return value");
			}
		} else {
			errorLog("Failed trying to do hook ($param) - $function");
		}
	}

	$retval;
}

1;

__END__

=head1 NAME

Slash::Hook - Hook libraries for slash

=head1 SYNOPSIS

	use Slash::Hook;

=head1 DESCRIPTION

This was deciphered from crop circles.

=head1 SEE ALSO

Slash(3).

=cut

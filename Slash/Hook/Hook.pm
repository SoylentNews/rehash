# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Hook;
use strict;
use DBIx::Password;
use Slash;
use Slash::DB;
use Slash::Utility;
use vars qw($VERSION);

# Arrrr Matey...

use base 'Exporter';
use vars qw($VERSION @EXPORT);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;
@EXPORT	   = qw(slashHook);


sub slashHook {
	my($param, $options) = @_;
	my $slashdb = getCurrentDB();

	my $hooks = $slashdb->getHooksByParam($param);
	for my $hook (@$hooks) {
		eval "require $hook->{class}";
		my $code;
		{
			no strict 'refs';
			$code = \&{ $hook->{class} . '::' . $hook->{subroutine} };
		}
		if (defined (&$code)) {
			unless ($code->($options)) {
					errorLog("Failed executing hook ($param) - $hook->{class}::$hook->{subroutine}");
			}
		} else {
			errorLog("Failed trying to do hook ($param) - $hook->{class}::$hook->{subroutine}");
		}
	}
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

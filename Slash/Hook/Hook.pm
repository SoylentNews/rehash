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
	my($param, $luggage, $options) = @_;
	# Why call these instead of taking them out of luggage?
	# This allows the calling code to modify those values.
	# -Brian
	my $section = getCurrentForm('section');
	my $slashdb = getCurrentDB();

	my $hooks = $slashdb->getHooksByParam($param);
	for my $hook (@$hooks) {
		eval "require $hook->{class}";
		if(eval "$hook->{class}->can('$hook->{subroutine}')") {
			unless (eval "$hook->{class}::$hook->{subroutine}(\$luggage, \$options)") {
				errorLog("Failed executing hook ($param) - $hook->{class}::$hook->{subroutine}");
				print STDERR  ("$hook->{class}::$hook->{subroutine}(\$luggage, \$options)\n");
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

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

my %classes;

sub slashHook {
	my($param, $options) = @_;
	my $slashdb = getCurrentDB();

	my $hooks = $slashdb->getHooksByParam($param);
	for my $hook (@$hooks) {
		my $class = $hook->{class};
		my $function = $class . '::' . $hook->{subroutine};

		if ($classes{$class}) {			# already require'd
			if ($classes{$class} eq 'NA') {	# already failed
				next;
			}
		} else {
			eval "require $class";		# we cache because this is expensive,
							# even if it has already succeeded or
							# failed, just by doing the eval -- pudge
			if ($@) {			# failed
				$classes{$class} = 'NA';
				next;
			} else {			# success!
				$classes{$class} = 1;
			}
		}

		my $code;
		{
			no strict 'refs';
			$code = \&{ $function };
		}
		if (defined (&$code)) {
			unless ($code->($options)) {
				errorLog("Failed executing hook ($param) - $function");
			}
		} else {
			errorLog("Failed trying to do hook ($param) - $function");
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

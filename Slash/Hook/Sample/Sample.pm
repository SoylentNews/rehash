# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Hook::Sample;
use strict;
use DBIx::Password;
use Slash;
use Slash::DB;
use Slash::Utility;
use vars qw($VERSION);

# Shake well, serve warm.

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;


sub sample {
	my($luggage, $options) = @_;
	my ($constants, $slashdb, $user, $form) = @$luggage;
	errorLog("Sample Hook called");
	return 1;
}

sub ingar {
	my($luggage, $options) = @_;
	my ($constants, $slashdb, $user, $form) = @$luggage;
	errorLog("My name is Ingar, I am from Ikea, you killed my brother, prepare to die");
	return 1;
}

1;

__END__

=head1 NAME

Slash::Hook::Sample - Hook library samples for slash

=head1 SYNOPSIS

	use Slash::Hook::Sample;

=head1 DESCRIPTION

This was deciphered from crop circles.

=head1 SEE ALSO

Slash(3), Slash::Hook(3).

=cut

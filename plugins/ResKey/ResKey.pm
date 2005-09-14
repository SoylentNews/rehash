# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::ResKey;

=head1 NAME

Slash::ResKey - Resource management for Slash


=head1 SYNOPSIS

	my $reskey = getObject('Slash::ResKey');
	my $key = $reskey->key('zoo');
	if ($key->create) { ... }
	if ($key->touch)  { ... }
	if ($key->use) { ... }
	else { print $key->errstr }

=cut

use warnings;
use strict;

use Slash;
use Slash::Constants ':reskey';
use Slash::ResKey::Key;
use Slash::Utility;

use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

our($AUTOLOAD);
our($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

#========================================================================
sub new {
	my($class, $user) = @_;
	my $self = {};

	my $plugin = getCurrentStatic('plugin');
	return unless $plugin->{'ResKey'};

	bless($self, $class);
	$self->{virtual_user} = $user;

	return $self;
}

#========================================================================
sub key {
	my($self, $resource, $reskey) = @_;
	return Slash::ResKey::Key->new($self->{virtual_user}, $resource, $reskey);
}

#========================================================================
# For tasks/reskey_purge.pl
sub purge_old {
	my($self) = @_;
	my $timeframe = getCurrentStatic('reskey_timeframe');
	my $delete_before_time = time - ($timeframe || 14400);
	$self->sqlDelete('reskeys', 'ts < $delete_before_time');
}

1;

__END__


=head1 SEE ALSO

Slash(3).

=head1 VERSION

$Id$


=head1 TODO

=head2 Check Classes

The default failure value is DEATH, rather than FATAL, which is non-fatal:
callers can choose to re-display the form on FAILURE, whereas with DEATH
there's no reason to continue, but one must start over with a new form (if
indeed even that).

=over 4

=item User (DONE)

Admins can be skipped on these checks with a var.  Simple checks for:

=over 4

=item karma

=item seclev

=item is_subscriber

=item is_admin

=back


=item Duration

We need to implement limit modulation.

=over 4

=item min duration between uses (DONE)

FAILURE

=item min duration betwen creation and use (DONE)

FAILURE

=item max num of uses per time period (DONE)

FAILURE

=item max touches per reskey (NA)

DEATH

Not doing now, if ever.  But will add if we feel a need.

=item max simultaneous reskeys (NA)

FAILURE

I don't think this is necessary, since we've worked out some atomicity problems.

If we do: report error, or invalidate old reskeys?  Which ones?

=back


=item HumanConf

Still needs implementation.


=item AL2 (DONE)

=over 4

=item NoPost

This user cannot post.

=item NoPostAnon

This user cannot post anonymoously.

=item AnonNoPost

This user is anonymous -- or is posting anonymously -- and the anonymous user
cannot post.

=back



=item Proxy Scan (DONE)

Simple wrapper around the proxy scan code.


=item ACL (DONE)

If an ACL required, make sure user has it (is_admin bypasses this check (by default)).

If an ACL prohibits access, make sure user does NOT have it (no bypass).


=item POST (NA)

Probably best handled in .pl as we always have, though we could move it if we
felt a need.


=back


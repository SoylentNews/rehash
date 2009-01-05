# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

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


=head1 DESCRIPTION

Slash::ResKey is for managing resources.  You get a key object by requesting
a specific sort of resource with the C<key> method, which takes the name
of the resource (an arbitrary string, defined in the database table
C<reskey_resources>).

Optionally, C<key> takes a hashref of keys "reskey" and "debug".  Debug levels
are 0, 1, and 2, with default 0.  If you don't include a reskey, it will
be determined automatically from C<getCurrentForm('reskey')>.

See L<Slash::ResKey::Key> for more info on what to do with an object returned
by <key>.

=cut

use warnings;
use strict;

use Slash;
use Slash::Utility;
use Slash::Constants ':reskey';
use Slash::ResKey::Key;

use base 'Slash::Plugin';

our($AUTOLOAD);
our $VERSION = $Slash::Constants::VERSION;

our $DEBUG = 0;

#========================================================================
sub key {
	my($self, $resource, $opts) = @_;

	$opts ||= {};
	$opts->{debug} = $DEBUG unless defined $opts->{debug};

	return Slash::ResKey::Key->new(
		$self->{virtual_user},
		$resource,
		$opts->{reskey},
		$opts->{debug},
		$opts
	);
}

#========================================================================
# For tasks/reskey_salt.pl
sub update_salts {
	my($self) = @_;
	my $constants = getCurrentStatic();

	# fill if empty!
	if (!$constants->{reskey_static_salt}) {
		$self->createVar(
			'reskey_static_salt',
			getAnonId(1, 20),
			'sitewide salt for reskeys'
		);
	}

	# delete old salts
	my $timeframe = $constants->{reskey_timeframe} || 14400;
	$self->sqlDelete('reskey_hourlysalt', "ts < DATE_SUB(NOW(), INTERVAL $timeframe SECOND)");

	# create new ones, if they don't exist
	for my $i (0 .. 48) {
		$self->sqlInsert('reskey_hourlysalt', {
			-ts	=> "DATE_ADD(DATE_FORMAT(NOW(), '%Y-%m-%d %H:00:00'), INTERVAL $i HOUR)",
			salt	=> getAnonId(1, 20),
		}, { ignore => 1 });
	}
}

#========================================================================
# For tasks/reskey_purge.pl
sub purge_old {
	my($self) = @_;

	my $count = 0;

	# first, purge all old reskeys
	my $timeframe = getCurrentStatic('reskey_timeframe') || 14400;
	$count += $self->sqlDelete('reskeys', "create_ts < DATE_SUB(NOW(), INTERVAL $timeframe SECOND)");


	my $uses     = $self->sqlSelectAll('rkrid, value', 'reskey_vars', 'name="duration_uses"');
	my $max_uses = $self->sqlSelectAll('rkrid', 'reskey_vars', 'name="duration_max-uses"');
	my %max_uses = map { $_->[0] => 1 } @$max_uses;
	my %rkids    = map { $_->[0] => 1 } (@$uses, @$max_uses);
	my $rkid_str = join ', ', keys %rkids;

	# then, delete all used reskeys where duration_uses and
	# duration_max-uses are not in use
	$count += $self->sqlDelete('reskeys', "rkrid NOT IN ($rkid_str) AND is_alive = 'no'");

	# next, purge all reskeys that are used and older than duration_uses
	# (minimum time between uses) where duration_max-uses (max uses per
	# timeframe) not defined
	for (@$uses) {
		my($rkrid, $seconds) = @$_;
		next if $max_uses{$rkrid};
		$count += $self->sqlDelete('reskeys',
			"rkrid = $rkrid AND is_alive = 'no' AND " .
			"submit_ts IS NOT NULL AND " .
			"submit_ts < DATE_SUB(NOW(), INTERVAL $seconds SECOND)"
		);
	}

	# finally, delete orphaned reskey_failures entries
	my $rkids = $self->sqlSelectAll('rkf.rkid',
		'reskey_failures AS rkf LEFT JOIN reskeys AS rk ON rk.rkid=rkf.rkid',
		'rk.rkid IS NULL'
	);

	if (@$rkids) {
		my $rkid_string = join ',', map { $_->[0] } @$rkids;
		$count += $self->sqlDelete('reskey_failures', "rkid IN ($rkid_string)");
	}

	return $count;
}

1;

__END__


=head1 SEE ALSO

Slash(3).


=head1 TODO

=head2 Check Classes

The default failure value is DEATH, rather than FAILURE, which is non-fatal:
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


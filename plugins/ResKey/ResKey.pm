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


Check Classes:

(default: DEATH, rather than FAILURE [which is non-fatal])

User - DONE
	* simple checks for:
		* karma
		* seclev
		* is_subscriber
		* is_admin

Limit
	* min duration between uses (FAILURE) - DONE
	* min duration betwen creation and use (FAILURE) - DONE
	* max # of creations/uses per time period (DEATH?) - DONE
	* max touches per reskey? - NOT DOING FOR NOW, IF EVER
	* max simultaneous reskeys - NOT DOING FOR NOW, IF EVER
		* report error, or invalidate old ones?
	*** all above subject to increasing limits per user specifics

HumanConf
AL2 - DONE
Proxy Scan - DONE
ACL - DONE
	* if an ACL required, make sure user has it
		* is_admin bypasses this check (by default)
	* if an ACL prohibits access, make sure user does NOT have it
		* no bypass
POST?  - probably best handled in .pl as we always have, though we could move it


test AnonNoPost

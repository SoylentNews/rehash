# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Remarks;

=head1 NAME

Slash::Remarks - Perl extension for Remarks


=head1 SYNOPSIS

	use Slash::Remarks;


=head1 DESCRIPTION

LONG DESCRIPTION.


=head1 EXPORTED FUNCTIONS

=cut

use strict;
use DBIx::Password;
use Slash;
use Slash::Utility;

use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub new {
	my($class, $user) = @_;
	my $self = {};

	my $plugin = getCurrentStatic('plugin');
	return unless $plugin->{'Remarks'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;

	return $self;
}

sub getRemarks {
	my($self, $options) = @_;

	my $max = $options->{max} || 100;

	my $remarks = $self->sqlSelectAllHashrefArray(
		'rid, uid, stoid, time, remark, type',
		'remarks',
		'',
		"ORDER BY rid DESC LIMIT $max"
	);

	return $remarks || [];
}


1;

__END__


=head1 SEE ALSO

Slash(3).

=head1 VERSION

$Id$

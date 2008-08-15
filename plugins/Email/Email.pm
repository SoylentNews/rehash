# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Email;

use strict;

use Slash 2.003;	# require Slash 2.3

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

########################################################

sub checkOptoutList {
	my($self, $email) = @_;

	my $returnable = $self->sqlSelect(
		'email',
		'email_optout',
		'email=' . $self->sqlQuote($email)
	);

	return $returnable;
}

########################################################

sub addToOptoutList {
	my($self, $email) = @_;
	return if $self->checkOptoutList($email);
	my $user = getCurrentUser();

	$self->sqlInsert('email_optout', {
		email		=> $email,
		-added		=> 'now()',
		ipid		=> $user->{ipid},
		subnetid	=> $user->{subnetid},
	});
}

########################################################

sub removeFromOptoutList {
	my($self, $email) = @_;

	return unless $self->checkOptoutList($email);

	$self->sqlDelete(
		'email_optout',
		'email=' . $self->sqlQuote($email)
	);
}

1;


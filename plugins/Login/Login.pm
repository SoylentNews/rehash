# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2009 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Login;

=head1 NAME

Slash::Login - Perl extension for Login


=head1 SYNOPSIS

	use Slash::Login;


=head1 DESCRIPTION

LONG DESCRIPTION.


=head1 EXPORTED FUNCTIONS

=cut

use strict;

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

sub deleteOpenID {
	my($self, $claimed_identity) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	return unless allowOpenID();

	my $claimed_uid = $self->getUIDByOpenID($claimed_identity);
	if (!$claimed_uid || $claimed_uid != $user->{uid}) {
		return getLoginData("openid_not_yours", { claimed_identity => $claimed_identity });
	}

	if ($self->deleteOpenID($user->{uid}, $claimed_identity)) {
		# XXX redirect automatically to /my/password
		return getLoginData("openid_verify_delete", { claimed_identity => $claimed_identity });
	} else {
		return getLoginData("openid_error");
	}
}

sub allowOpenID {
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	if (!$constants->{openid_consumer_allow}) {
		return getLoginData("openid_not_enabled");
	}

	# no more checks needed if we're logging in
	return 1 if $form->{openid_login};

	if ($user->{is_anon}) {
		return getLoginData("openid_not_logged_in");
	}

	return 1;
}

sub getLoginData {
	my($str) = @_;
	return getData($str, { Page => 'login' });
}

sub displaySendPassword {
	my ($self) = @_;

	my $user = getCurrentUser();

	my $hc = slashDisplay('hc_modal', {}, { Return => 1, Page => 'login' });
	return slashDisplay('sendPasswdModal', { hc => $hc }, { Return => 1, Page => 'login' });
}

sub sendPassword {
	my ($self) = @_;

	my $user = getCurrentUser();

	# XXX This is not done, so return errors for testing
	my $hc = slashDisplay('hc_modal', {}, { Return => 1, Page => 'login' });
	my $updates = {};
	$updates->{hc} = $hc;
	return $updates;
}

1;

__END__


=head1 SEE ALSO

Slash(3).

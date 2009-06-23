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
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	return unless allowOpenID();

	my $claimed_uid = $slashdb->getUIDByOpenID($claimed_identity);
	if (!$claimed_uid || $claimed_uid != $user->{uid}) {
		return getLoginData("openid_not_yours", { claimed_identity => $claimed_identity });
	}

	if ($slashdb->deleteOpenID($user->{uid}, $claimed_identity)) {
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
	my($str, $data) = @_;
	return getData($str, $data, 'login');
}

sub displaySendPassword {
	my ($self) = @_;

	my $user = getCurrentUser();

	my $hc = slashDisplay('hc_modal', {}, { Return => 1, Page => 'login' });
	return slashDisplay('sendPasswdModal', { hc => $hc }, { Return => 1, Page => 'login' });
}

sub sendPassword {
	my ($self, $params, $validated_uid, $validated_nick) = @_;

	my $slashdb = getCurrentDB();
        my $constants = getCurrentStatic();
        my $user = getCurrentUser();
        my $form = (keys %$params) ? $params : getCurrentForm();

        my $uid = $user->{uid};
        my $unickname = $form->{unickname};
        my $updates = {};
        my $error_message = '';
        my $error = 0;

        if ($unickname) {
                if ($unickname =~ /\@/) {
                        $uid = $slashdb->getUserEmail($unickname);
                } elsif ($unickname =~ /^\d+$/) {
                        my $tmpuser = $slashdb->getUser($unickname, ['nickname', 'uid']);
                        $uid = $tmpuser->{uid};
                } else {
                        $uid = $slashdb->getUserUID($unickname);
                }
        }

	if (!$unickname || !$uid || isAnon($uid)) {
                $updates->{unickname_error} = getData('modal_mail_nonickname', {}, 'login');
                $updates->{error} = 1;
        } elsif ($user->{acl}{nopasswd}) {
                $updates->{unickname_error} = getData('modal_mail_acl_nopasswd', {}, 'login');
                $updates->{error} = 1;
        }

        return $updates if $updates->{error};

        my %srcids;
        my $user_send = $slashdb->getUser($uid);

        @srcids{keys %{$user->{srcids}}} = values %{$user->{srcids}};
        delete $srcids{uid};

        if ($slashdb->checkAL2(\%srcids, [qw( nopost nopostanon spammer openproxy )])) {
                $updates->{unickname_error} = getData('modal_mail_readonly', {}, 'login');
                $updates->{error} = 1;
        } elsif ($slashdb->checkMaxMailPasswords($user_send)) {
                $updates->{unickname_error} = getData('modal_mail_toooften', {}, 'login');
                $updates->{error} = 1;
        }

        if (!$updates->{error}) {
                $$validated_uid = $uid;
                $$validated_nick = $user_send->{nickname};
        }

        return $updates;
}

sub sendMailPasswd {
	my ($self, $uid) = @_;

	return if isAnon($uid);

	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = $slashdb->getUser($uid);

	my $newpasswd = $slashdb->getNewPasswd($uid);

	my $r = Apache->request;
	my $remote_ip = $r->connection->remote_ip;

	my $xff = $r->header_in('X-Forwarded-For') || '';
	$xff =~ s/\s+/ /g;
	$xff = substr(strip_notags($xff), 0, 20);

	my $ua = $r->header_in('User-Agent') || '';
	$ua =~ s/\s+/ /g;
	$ua = substr(strip_attribute($ua), 0, 60);

	my $subject = getData('mail_subject', { nickname => $user->{nickname} }, 'login');

	my $msg = getData('mail_msg', {
		newpasswd       => $newpasswd,
		tempnick        => $user->{nickname},
		remote_ip       => $remote_ip,
		x_forwarded_for => $xff,
		user_agent      => $ua,
	}, 'login');

	doEmail($uid, $subject, $msg);
}

sub displayNewUser {
	my ($self) = @_;

	return slashDisplay('newUserModal', {}, { Return => 1, Page => 'login' });
}



1;

__END__


=head1 SEE ALSO

Slash(3).

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

use Slash;
use Slash::Display;
use Slash::Utility;
use Slash::Constants qw(:web :messages);

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

# extra security similar to reskey, makes sure timestamp in return_to URL isn't faked
# we probably don't need it since we have reskeys, but best to use it anyway
sub getOpenIDSecret {
	my($time) = @_;
	return getCurrentStatic('openid_consumer_secret') . $time;
}

sub getOpenID {
	my($self, $form) = @_;
	require Net::OpenID::Consumer;
	require LWPx::ParanoidAgent;

	$self->{_ua}    ||= LWPx::ParanoidAgent->new;
	$self->{_cache} ||= Slash::Login::Cache->new;

	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $abs = $user->{state}{ssl}
		? $constants->{absolutedir_secure}
		: $constants->{absolutedir};

	my $csr = Net::OpenID::Consumer->new(
		ua              => $self->{_ua},
		consumer_secret => \&getOpenIDSecret,
		args            => $form,
		required_root   => $abs . '/',
		cache		=> $self->{_cache},
		debug           => 1 # XXX
	);

	return $csr;
}


sub deleteOpenID {
	my($self, $claimed_identity) = @_;
	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	return unless allowOpenID();

	my $claimed_uid = $slashdb->getUIDByOpenID($claimed_identity);
	if (!$claimed_uid || $claimed_uid != $user->{uid}) {
		return getLoginData("openid_not_yours", { claimed_identity => normalizeOpenID($claimed_identity) });
	}

	if ($slashdb->deleteOpenID($user->{uid}, $claimed_identity)) {
		return getLoginData("openid_verify_delete", { claimed_identity => normalizeOpenID($claimed_identity) });
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
	my($self, $form) = @_;

	my $user = getCurrentUser();

	my $hc = slashDisplay('hc_modal', {}, { Return => 1, Page => 'login' });
	return slashDisplay('sendPasswdModal', { tabbed => $form->{tabbed}, hc => $hc }, { Return => 1, Page => 'login' });
}

sub sendPassword {
	my($self, $params, $validated_uid, $validated_nick) = @_;

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
                $updates->{unickname_error} = getData('modal_mail_nonickname', { note_type => 'modal_error' }, 'login');
                $updates->{error} = 1;
        } elsif ($user->{acl}{nopasswd}) {
                $updates->{unickname_error} = getData('modal_mail_acl_nopasswd', { note_type => 'modal_error' }, 'login');
                $updates->{error} = 1;
        }

        return $updates if $updates->{error};

        my %srcids;
        my $user_send = $slashdb->getUser($uid);

        @srcids{keys %{$user->{srcids}}} = values %{$user->{srcids}};
        delete $srcids{uid};

        if ($slashdb->checkAL2(\%srcids, [qw( nopost nopostanon spammer openproxy )])) {
                $updates->{unickname_error} = getData('modal_mail_readonly', { note_type => 'modal_error' }, 'login');
                $updates->{error} = 1;
        } elsif ($slashdb->checkMaxMailPasswords($user_send)) {
                $updates->{unickname_error} = getData('modal_mail_toooften', { note_type => 'modal_error' }, 'login');
                $updates->{error} = 1;
        }

        if (!$updates->{error}) {
                $$validated_uid = $uid;
                $$validated_nick = $user_send->{nickname};
        }

        return $updates;
}

sub sendMailPasswd {
	my($self, $uid) = @_;

	return if isAnon($uid);

	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = $slashdb->getUser($uid);

	my $newpasswd = $slashdb->getNewPasswd($uid);

	my $r = Apache2::RequestUtil->request;
	my $remote_ip = $r->connection->remote_ip;

	my $xff = $r->headers_in->{'X-Real-IP'} || '';
	$xff =~ s/\s+/ /g;
	$xff = substr(strip_notags($xff), 0, 20);

	my $ua = $r->headers_in->{'User-Agent'} || '';
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
	$slashdb->setUserMailPasswd($user);
}

sub displayNewUser {
        my($self, $form) = @_;

        my $user = getCurrentUser();

        my $reskey = getObject('Slash::ResKey');
        my $reskey_resource = 'ajax_base_modal_misc';
        my $rkey = $reskey->key($reskey_resource, { nostate => 1 });
        $rkey->create;

	my $hc = slashDisplay('hc_modal', {}, { Return => 1, Page => 'login' });

	return slashDisplay('newUserModal', { tabbed => $form->{tabbed}, nick_rkey => $rkey, hc => $hc }, { Return => 1, Page => 'login' });
}

sub validateNewUserInfo {
        my($self, $form) = @_;

        my $slashdb = getCurrentDB();
        my $constants = getCurrentStatic();
        my $user = $slashdb->getUser($form->{uid});

        my $updates = {};
        my $error = 0;

	# Check if the nick is invalid or taken.
	my $newnick = nickFix($form->{newusernick});
        my $matchname;
        if (!$newnick) {
		$updates->{submit_error} = getData('modal_createacct_nick_invalid', { note_type => 'modal_error' }, 'login');
                $error = 1;
        } else {
                $matchname = nick2matchname($newnick);
                if ($slashdb->getUserUIDWithMatchname($form->{newusernick})) {
                        $updates->{submit_error} = getData('modal_createacct_duplicate_user', { note_type => 'modal_error', nick => $newnick }, 'login');
			$error = 1;
                }
        }

        return $updates if $error;

	# Check if email address is invalid or taken.
	if (!$form->{email} || !emailValid($form->{email})) {
                $updates->{submit_error} = getData('modal_createacct_email_invalid', { note_type => 'modal_error', email => $form->{email} }, 'login');
		$error = 1;
        } elsif ($form->{email} ne $form->{email2}) {
                $updates->{submit_error} = getData('modal_createacct_email_do_not_match', { note_type => 'modal_error' }, 'login');
		$error = 1;
        } elsif ($slashdb->existsEmail($form->{email})) {
                $updates->{submit_error} = getData('modal_createacct_email_exists', { note_type => 'modal_error', email => $form->{email} }, 'login');
		$error = 1;
        }

        return $updates if $error;

	# Check for an open proxy.
	if ($constants->{newuser_portscan}) {
                my $is_trusted = $slashdb->checkAL2($user->{srcids}, 'trusted');
                if (!$is_trusted) {
                        my $is_proxy = $slashdb->checkForOpenProxy($user->{hostip});
                        if ($is_proxy) {
				$updates->{submit_error} =
                                	getData('modal_createacct_new_user_open_proxy',
						{
							unencoded_ip => $ENV{REMOTE_ADDR},
							port => $is_proxy,
							note_type => 'modal_error',
						},
						'login'
					);
				$error = 1;
                        }
                }

                return $updates if $error;
        }

        $form->{matchname} = $matchname;
        $form->{newnick} = $newnick;

	# No errors. This should be clean.
	return $updates;
}

sub createNewUser {
        my($self, $user, $form) = @_;

	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $updates = {};

	my $uid = $slashdb->createUser($form->{matchname}, $form->{email}, $form->{newnick});

        if (!$uid) {
                $updates->{submit_error} = getData('modal_createacct_duplicate_user', { note_type => 'modal_error', nick => $form->{newnick} }, 'login');
                return $updates;
        }

        my $data = {};
        $slashdb->getOtherUserParams($data);

	$data->{tzcode} = $form->{tzcode} if defined $form->{tzcode};
        $data->{creation_ipid} = $user->{ipid};

        $slashdb->setUser($uid, $data) if keys %$data;

        my $messages = getObject('Slash::Messages');
        my %params;
        my @default_types = (
                'Comment Moderation',
                'Comment Reply',
                'Journal Entry by Friend',
                'Subscription Running Low',
                'Subscription Expired',
                'Relationship Change'
        );

        foreach my $type (@default_types) {
                my $code = $messages->getDescription('messagecodes', $type);
                $params{$code} = MSG_MODE_WEB() if $code;
        }

	$params{MSG_CODE_NEWSLETTER()} = MSG_MODE_EMAIL() if $constants->{newsletter_by_default};

        $messages->setPrefs($uid, \%params);

        $self->sendMailPasswd($uid);

	if ($form->{openid_reskey}) {
		my $openid_url = $slashdb->checkOpenIDResKey($form->{openid_reskey});
		if ($openid_url) {
			$slashdb->setOpenID($uid, $openid_url);
		}

		my $reskey = getObject('Slash::ResKey');
		my $rkey = $reskey->key('openid', { nostate => 1, reskey => $form->{openid_reskey} });
		$rkey->use; # we're done with it, clean up
	}

        $updates->{modal_prefs} = slashDisplay('newUserModalSuccess', {
                nick      => $form->{newnick},
                email     => $form->{email},
                uid       => $uid,
        }, { Page => 'login', Return => 1 });

        return $updates;
}

sub ajaxCheckNickAvailability {
        my($slashdb, $constants, $user, $form, $options) = @_;

        my $updates = {};

        if ($slashdb->getUserUIDWithMatchname($form->{nickname})) {
                $updates->{'nickname_error'} =
			getData('modal_createacct_nickname_message',
				{
					nickname => $form->{nickname},
					nickname_available => 'is not available',
					note_type => 'modal_error',
				},
				'login'
			);
        } else {
                $updates->{'nickname_error'} =
			getData('modal_createacct_nickname_message',
				{
					nickname => $form->{nickname},
					nickname_available => 'is available',
					note_type => 'modal_ok',
				},
				'login'
			);
        }

        my $reskey = getObject('Slash::ResKey');
        my $reskey_resource = 'ajax_base_modal_misc';
        my $rkey = $reskey->key($reskey_resource, { nostate => 1 });
        $rkey->create;

        $updates->{nick_rkey} =
		getData('replace_rkey',
			{
				rkey_id => 'nick_rkey',
				rkey_name => 'nick_rkey',
				rkey => $rkey->reskey
			},
			'login'
		);

        return Data::JavaScript::Anon->anon_dump({ html_replace => $updates });
}


package Slash::Login::Cache;
use strict;
use Slash;
use Slash::Utility;

sub new {
	my $slashdb = getCurrentDB();
	my $mcd = $slashdb->getMCD or return undef;
	my $mcdkey = "$slashdb->{_mcd_keyprefix}:openid:";

	return bless { _mcd => $mcd, _mcdkey => $mcdkey }, __PACKAGE__;
}

sub set {
	my($self, $key, $value, $expires) = @_;
	$self->{_mcd}->set($self->{_mcdkey} . $key, $value, $expires);
}

sub get {
	my($self, $key) = @_;
	$self->{_mcd}->get($self->{_mcdkey} . $key);
}

1;

__END__


=head1 SEE ALSO

Slash(3).


--- /Users/pudge/Desktop/untitled text 6	2009-06-25 12:37:14.000000000 -0700
+++ /usr/local/lib/perl5/site_perl/5.10.0/Net/OpenID/URIFetch.pm	2009-06-25 12:33:38.000000000 -0700
@@ -84,7 +84,7 @@
             $req->header('If-None-Match', $etag);
         }
         if (my $ts = ($ref->{Headers}->{'last-modified'})) {
-            $req->if_modified_since($ts);
+            $req->if_modified_since(HTTP::Date::str2time($ts));
         }
     }
 

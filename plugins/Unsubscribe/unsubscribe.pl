#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use utf8;
use File::Path;
use Slash 2.003;        # require Slash 2.3.x
use Slash::Constants qw(:messages :web);
use Slash::Display;
use Slash::Utility;
use Time::HiRes qw( usleep );

sub main {
        my $slashdb   = getCurrentDB();
        my $constants = getCurrentStatic();
        my $user      = getCurrentUser();
        my $form      = getCurrentForm();
        my $gSkin     = getCurrentSkin();

	my $allowed      = ($user->{acl}{unsubscribe} || ($user->{seclev} >= ($constants->{stats_admin_seclev} || 100)));

        # possible value of "op" parameter in form
        my %ops = (
		unsubscribe => [ $allowed, \&unsubscribe ],
		default => [ $allowed, \&showForm ]
	);

	# prepare op to proper value if bad value given
        my $op = $form->{op};
        if (!$op || !exists $ops{$op} || !$ops{$op}[ALLOWED]) {
                $op = 'default';
        }

	if (!$ops{$op}[ALLOWED]) {
                redirect("$gSkin->{rootdir}/");
                return;
        }

	header('', '', { admin => 1, adminmenu => 'config', tab_selected => 'unsubscribe' })  or return;
	print createMenu('unsubscribe');

	$ops{$op}[FUNCTION]->($slashdb, $constants, $user, $form);

	footer();
}

sub unsubscribe {
	my($slashdb, $constants, $user, $form) = @_;

	my $goodcount = my $badcount = 0;
	my @emails = split /\n/, $form->{emails};

	foreach my $email (@emails) {
		chomp $email;
	
		my $uid = $slashdb->sqlSelect('uid','users',
                	'realemail=' . $slashdb->sqlQuote($email));

		unless ($uid) {
			$badcount++;
			usleep 100;
			next;
		}

		$slashdb->sqlUpdate('users_info', { maillist => 0 }, "uid=$uid");
        	$slashdb->sqlUpdate('users_messages', { mode => MSG_MODE_NONE },
                	"uid=$uid AND mode=" . MSG_MODE_EMAIL);

		$goodcount++;
		usleep 100;
	}

	print getData('users-unsubscribed', { goodcount => $goodcount, badcount => $badcount });
}

sub showForm {
	my($slashdb, $constants, $user, $form) = @_;

	slashDisplay ('form');
}

createEnvironment();
main();

1;

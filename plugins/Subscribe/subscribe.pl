#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;

use Slash;
use Slash::Display;
use Slash::Utility;

sub main {
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	# lc just in case
	my $op = lc($form->{op});

	my($tbtitle);

	my $ops = {
		default		=> {
			function	=> \&edit,
			seclev		=> 1,
		},
		save		=> {
			function	=> \&save,
			seclev		=> 1,
		},
	};

	# subscribe.pl is not yet for regular users
	if ($user->{seclev} < 100) {
		my $rootdir = getCurrentStatic('rootdir');
		redirect("$rootdir/users.pl");
		return;
	}
	unless ($ops->{$op}) {
		$op = 'default';
	}

	header("subscribe");

	my $retval = $ops->{$op}{function}->($form, $slashdb, $user, $constants);

	footer();
	writeLog($user->{uid}, $op);
}

##################################################################
# Edit options
sub edit {
	my($form, $slashdb, $user, $constants) = @_;
	titlebar("95%", "Editing Subscription...");
	slashDisplay("edit");
	1;
}

##################################################################
# Edit options
sub save {
	my($form, $slashdb, $user, $constants) = @_;
	my $user_update = { };
	if ($user->{seclev} >= 100) {
		my($buymore) = $form->{buymore} =~ /(\d+)/;
		$user_update->{hits_paidfor} = $user->{hits_paidfor} || 0;
		$user_update->{hits_paidfor} += $buymore;
	}
	for my $key (grep /^boughtpage_\w+$/, keys %$form) {
		# Empty string means delete the row from users_param.
		$user_update->{$key} = $form->{$key} ? 1 : "";
	}
	$slashdb->setUser($user->{uid}, $user_update);
	print "<p>Subscription options saved.\n";
	titlebar("95%", "Editing Subscription...");
	slashDisplay("edit", { user_update => $user_update });
	1;
}

createEnvironment();
main();
1;


#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
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
		paypal		=> {
			function	=> \&paypal,
			seclev		=> 1,
		},
		pause		=> {
			function	=> \&pause,
			seclev		=> 1,
		},
	};

	# subscribe.pl is not yet for regular users
	if ($user->{seclev} < 100) {
		my $rootdir = getCurrentStatic('rootdir');
		redirect("$rootdir/users.pl");
		return;
	}
	$op = 'default' unless $ops->{$op};

	header("subscribe") unless $op eq 'pause';

	my $retval = $ops->{$op}{function}->($form, $slashdb, $user, $constants);

	footer();
	writeLog($user->{uid}, $op);
}

##################################################################
# Edit options
sub edit {
	my($form, $slashdb, $user, $constants) = @_;
	my $user_edit;
	if ($form->{uid}
		&& $user->{seclev} >= 100
		&& $form->{uid} =~ /^\d+$/
		&& !isAnon($form->{uid})) {
		$user_edit = $slashdb->getUser($form->{uid});
	}
	$user_edit ||= $user;

	my $user_newvalues = { };
	my $bought_nothing_yet = ($user_edit->{hits_paidfor} ? 0 : 1);
	if ($bought_nothing_yet) {
		if ($constants->{subscribe_defpages}) {
			my @defpages = split / /, $constants->{subscribe_defpages};
			for my $page (@defpages) {
				$user_newvalues->{"buypage_$page"} = 1;
			}
		}
	}

	titlebar("95%", "Editing Subscription...");
	slashDisplay("edit", {
		user_edit => $user_edit,
		user_newvalues => $user_newvalues,
	});
	1;
}

##################################################################
# Edit options
sub save {
	my($form, $slashdb, $user, $constants) = @_;
	my $user_edit;
	if ($form->{uid}
		&& $user->{seclev} >= 100
		&& $form->{uid} =~ /^\d+$/
		&& !isAnon($form->{uid})) {
		$user_edit = $slashdb->getUser($form->{uid});
	}
	$user_edit ||= $user;

	my $has_buying_permission = 0;
	$has_buying_permission = 1
		if $form->{secretword} eq $constants->{subscribe_secretword}
			or $user->{seclev} >= 100;

	my $user_update = { };
	my $user_newvalues = { };
	my $bought_nothing_yet = ($user_edit->{hits_paidfor} ? 0 : 1);
	if ($has_buying_permission) {
		my($buymore) = $form->{buymore} =~ /(\d+)/;
		if ($buymore) {
			$user_update->{"-hits_paidfor"} =
				"hits_paidfor + $buymore";
			$user_newvalues->{hits_paidfor} =
				$user_edit->{hits_paidfor} + $buymore;
		}
	}
	for my $key (grep /^buypage_\w+$/, keys %$form) {
		# Empty string means delete the row from users_param.
		$user_newvalues->{$key} =
			$user_update->{$key} = $form->{$key} ? 1 : "";
	}
	if ($bought_nothing_yet) {
		my @buypage_updates = grep /^buypage_/, keys %$user_update;
		if (!@buypage_updates && $constants->{subscribe_defpages}) {
			my @defpages = split / /, $constants->{subscribe_defpages};
			for my $page (@defpages) {
				$user_newvalues->{"buypage_$page"} =
					$user_update->{"buypage_$page"} = 1 if $page;
			}
		}
	}
	$slashdb->setUser($user_edit->{uid}, $user_update);

	print "<p>Subscription options saved.\n<p>";
	titlebar("95%", "Editing Subscription...");
	slashDisplay("edit", {
		user_edit => $user_edit,
		user_newvalues => $user_newvalues,
	});
	1;
}

sub paypal {
	my($form, $slashdb, $user, $constants) = @_;

	if (!$form->{secretword}
		|| $form->{secretword} ne $constants->{subscribe_secretword}) {
		sleep 5; # easy way to help defeat brute-force attacks
		print "<p>Paypal rejected, wrong secretword\n";
	}

	my @keys = qw( uid email payment_gross payment_net transaction_id data );
	my $payment = { };
	for my $key (@keys) {
		$payment->{$key} = $form->{$key};
	}
	if (!defined($payment->{payment_net})) {
		$payment->{payment_net} = $payment->{payment_gross};
	}

	my $subscribe = getObject('Slash::Subscribe');
	my $num_pages = $subscribe->convertDollarsToPages($payment->{payment_gross});
	$payment->{pages} = $num_pages;
	my $rows = $subscribe->insertPayment($payment);
	if ($rows == 1) {
		$slashdb->setUser($payment->{uid}, {
			"-hits_paidfor" => "hits_paidfor + $num_pages"
		});
		print "<p>Paypal confirmed\n";
	} else {
		use Data::Dumper;
		my $warning = "WARNING: Paypal payment accepted but record "
			. "not added to database! rows='$rows'\n"
			. Dumper($payment);
		print STDERR $warning;
		print "<p>Paypal transaction ID already recorded or other error, "
			. "not added to database! rows='$rows'\n";
	}
}

# Wait a moment for Paypal's instant payment notification to take place
# "behind the scenes," then redirect the user to the main subscribe.pl
# page where they will see their new subscription options.
sub pause {
	my($form, $slashdb, $user, $constants) = @_;
	sleep 5;
	redirect("/subscribe.pl");
}

createEnvironment();
main();
1;


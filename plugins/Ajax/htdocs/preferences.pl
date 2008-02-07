#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
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

        my $ops = {
                displayprefs   => {
                        function        => \&display_prefs,
                        seclev          => 1,
                },
                default         => {
                        function        => \&display_prefs,
                        seclev          => 1,
                },
        };
 
	if ($user->{is_anon}) {
		my $rootdir = getCurrentSkin('rootdir');
		redirect("$rootdir/users.pl");
		return;
	}

	if ($op ne 'pause') {
		# "pause" is special, it does a 302 redirect so we need
		# to not output any HTML.  Everything else gets this,
		# header and menu.
		header("Preferences") or return;
		print createMenu('users', {
			style =>	'tabbed',
			justify =>	'right',
			color =>	'colored',
			tab_selected =>	'preferences',
		});
	}

        $op = 'default' unless $ops->{$op};
        
	my $retval = $ops->{$op}{function}->($form, $slashdb, $user, $constants);

	footer();
	writeLog($user->{uid}, $op);
}

sub display_prefs {
	my($form, $slashdb, $user, $constants) = @_;

	slashDisplay('prefs_main', { discussion2 => $user->{discussion2}}, { Page => "ajax" });
        
}

createEnvironment();
main();
1;


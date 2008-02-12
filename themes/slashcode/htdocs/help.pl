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
                displayhelp   => {
                        function        => \&display_help,
                        seclev          => 1,
                },
                default         => {
                        function        => \&display_help,
                        seclev          => 1,
                },
        };
 
	if ($op ne 'pause') {
		# "pause" is special, it does a 302 redirect so we need
		# to not output any HTML.  Everything else gets this,
		# header and menu.
		header("Help") or return;
		print createMenu('users', {
			style =>	'tabbed',
			justify =>	'right',
			color =>	'colored',
			tab_selected =>	'help',
		});
	}

        $op = 'default' unless $ops->{$op};
        
	my $retval = $ops->{$op}{function}->($form, $slashdb, $user, $constants);

	footer();
	writeLog($user->{uid}, $op);
}

sub display_help {
        my($form, $slashdb, $user, $constants) = @_;
        
        my $other;
        if (!$user->{is_anon}) {
                $other = slashDisplay('prefs_main', { discussion2 => $user->{discussion2}, main_help => 1}, { Return => 1, Page => "ajax" });
        } else {
                $other = slashDisplay('help_anon', { }, { Return => 1 });
        }

        slashDisplay('help_main', { other => $other });
        
}

createEnvironment();
main();
1;


#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants qw(:web);
use Slash::Display;
use Slash::Utility;
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;


sub main {
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();

	# This will need to be changed to "log_db_user"
	my $logdb     = $constants->{backup_db_user}
		? getObject('Slash::DB', $constants->{backup_db_user})
		: $slashdb;
	my $stats     = getObject('Slash::Stats', $logdb->{virtual_user});

	my $admin_post = $user->{is_admin} && $user->{state}{post};

	# possible value of "op" parameter in form
	my %ops = (
		list	=> [ $admin_post,	\&list		],

		default	=> [ $user->{is_admin},	\&list		]
	);

	# prepare op to proper value if bad value given
	my $op = $form->{op};
	if (!$op || !exists $ops{$op} || !$ops{$op}[ALLOWED]) {
		$op = 'default';
	}

	# from data;SCRIPTNAME;default
	#getData('head')
	header('', '', { admin => 1 } );

	# dispatch of op
	$ops{$op}[FUNCTION]->($slashdb, $constants, $user, $form, $stats)
		if $ops{$op}[ALLOWED];

	footer();
}


sub list {
	my($slashdb, $constants, $user, $form, $stats) = @_;

	my $stats_data = $stats->getAllStats({
		section	=> $form->{stats_section},
		days	=> $form->{stats_days} || 1,
	});

	# don't modify the data, copy it
	my %sections = %{$slashdb->getDescriptions('sections')};
	$sections{all} = 'All';

	slashDisplay('list', {
		stats_data	=> $stats_data,
		sections	=> \%sections,
	});
}


createEnvironment();
main();

1;

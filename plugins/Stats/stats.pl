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
		report	=> [ $user->{is_admin},	\&report	],
		graph	=> [ $user->{is_admin},	\&graph		],
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
	header('', '', { admin => 1 } ) unless $op eq 'graph';

	# dispatch of op
	$ops{$op}[FUNCTION]->($slashdb, $constants, $user, $form, $stats)
		if $ops{$op}[ALLOWED];

	footer() unless $op eq 'graph';
}

sub graph {
	my($slashdb, $constants, $user, $form, $stats) = @_;

	my $sections = _get_sections();
	my @data;
	for my $namesec (@{$form->{stats_graph_multiple}}) {
		my($name, $section) = split /,/, $namesec;
		my $stats_data = $stats->getAllStats({
			section	=> $section,
			name	=> $name,
			days	=> $form->{stats_days}  # 0 || 14 || 31*3
		});
		my $data;
		for my $day (keys %{$stats_data->{$section}}) {
			next if $day eq 'names';
			$data->{$day} = $stats_data->{$section}{$day}{$name};
		}
		push @data, { data => $data, type => "$name ($sections->{$section})" };
	}

	my $type = 'image/png';
	my $date;  # for when we save to disk

	my $r = Apache->request;
	$r->content_type($type);
	$r->header_out('Cache-control', 'private');
	$r->header_out('Pragma', 'no-cache');
	$r->set_last_modified($date) if $date;
	$r->status(200);
	$r->send_http_header;
	$r->rflush;

	slashDisplay('graph', {
		set_legend	=> \&_set_legend,
		data		=> \@data,
	}, { Return => 1, Nocomm => 1 });

	$r->status(200);
	return 1;
}

sub report {
	my($slashdb, $constants, $user, $form, $stats) = @_;

	slashDisplay('report', {
	});
}

sub list {
	my($slashdb, $constants, $user, $form, $stats) = @_;

	my $stats_data = $stats->getAllStats({
		section	=> $form->{stats_section},
		days	=> $form->{stats_days} || 1,
	});

	slashDisplay('list', {
		stats_data	=> $stats_data,
		sections	=> _get_sections(),
	});
}

# helper method for graph(), because GD->set_legend doesn't
# take a reference, and TT can only pass a reference -- pudge
sub _set_legend {
	my($gd, $legend) = @_;
	$gd->set_legend(@$legend);
}

sub _get_sections {
	my $slashdb = getCurrentDB();
	# don't modify the data, copy it
	my %sections = %{$slashdb->getDescriptions('sections')};
	$sections{all} = 'All';
	return \%sections;
}

createEnvironment();
main();

1;

#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use File::Path;
use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants qw(:web);
use Slash::Display;
use Slash::Utility;
use URI::Escape;
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub main {
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();

	# we can make a separate reader and writer, but we need to write, so
	# for now ... writer
	my $stats     = getObject('Slash::Stats', { db_type => 'writer' } );

	# maybe eventually make this acl-only
	my $admin      = ($user->{acl}{stats} || ($user->{seclev} >= ($constants->{stats_admin_seclev} || 100)));
	my $admin_post = $admin && $user->{state}{post};

	# possible value of "op" parameter in form
	my %ops = (
		report	=> [ $admin,		\&report	],
		graph	=> [ $admin,		\&graph		],
		table	=> [ $admin,		\&table		],
		csv	=> [ $admin,		\&csv		],
		list	=> [ $admin_post,	\&list		],

		default	=> [ $admin,		\&list		]
	);

	# prepare op to proper value if bad value given
	my $op = $form->{op};
	if (!$op || !exists $ops{$op} || !$ops{$op}[ALLOWED]) {
		$op = 'default';
	}

	if (!$ops{$op}[ALLOWED]) {
		redirect("$constants->{rootdir}/users.pl");
		return;
	}

	# from data;SCRIPTNAME;default
	#getData('head')
	unless ($op eq 'graph' || $op eq 'csv') {
		header('', '', { admin => 1, adminmenu => 'info', tab_selected => 'stats' } ) or return;
		print createMenu('stats');
	}

	# dispatch of op
	$ops{$op}[FUNCTION]->($slashdb, $constants, $user, $form, $stats);

	footer() unless $op eq 'graph' || $op eq 'csv';
}

sub _get_graph_data {
	my($slashdb, $constants, $user, $form, $stats) = @_;

	my $sections = _get_sections();
	my(%days, @data);
	for my $namesec (@{$form->{stats_graph_multiple}}) {
		my($name, $section, $label) = split /,/, $namesec;

		my $stats_data = $stats->getAllStats({
			section	=> $section,
			name	=> $name,
			days	=> $form->{stats_days}  # 0 || 14 || 31*3
		});

		my $data;
		for my $day (keys %{$stats_data->{$section}}) {
			next if $day eq 'names';
			$data->{$day} = $stats_data->{$section}{$day}{$name};
			$days{$day} ||= $data->{$day};
		}

		$label ||= '';
		push @data, {
			data  => $data,
			type  => "$name / $sections->{$section}",
			label => $label,
		};
	}

	for my $data (@data) {
		for my $day (keys %days) {
			$data->{data}{$day} ||= 0;
		}
	}

	return \@data;
}

sub _get_graph_id {
	my($slashdb, $constants, $user, $form, $stats) = @_;

	my @id;
	for my $namesec (@{$form->{stats_graph_multiple}}) {
		my($name, $section, $label) = split /,/, $namesec;
		push @id, join '-', map { uri_escape($_, '\W') } ($name, $section, $label);
	}

	for ($form->{stats_days}, $form->{title}, $form->{type}, $form->{byweekavg}) {
		my $val = uri_escape($_, '\W');
		$val = '0' unless length $val;
		unshift @id, $val;
	}

	my $id   = join ',', @id;
	my $day  = $slashdb->getVar('adminmail_last_run', 'value', 1);

	return($id, $day);
}

sub table {
	my($slashdb, $constants, $user, $form, $stats) = @_;

	my($data) = _get_graph_data($slashdb, $constants, $user, $form, $stats);

	slashDisplay('table', {
		data		=> $data,
	});
}

sub csv {
	my($slashdb, $constants, $user, $form, $stats) = @_;

	my($data) = _get_graph_data($slashdb, $constants, $user, $form, $stats);

	my $content = slashDisplay('csv', {
		data		=> $data,
	}, {
		Nocomm		=> 1,
		Return		=> 1,
	});

	my $filename = join '-',
		$constants->{sitename},
		$form->{stats_days},
		$form->{title};
	$filename =~ s/[^\w_.-]+//g;

	my $r = Apache->request;
	$r->content_type('text/csv');
	$r->header_out('Cache-control', 'private');
	$r->header_out('Pragma', 'no-cache');
	$r->header_out('Content-Disposition', "attachment; filename=$filename.csv");
	$r->status(200);
	$r->send_http_header;
	return 1 if $r->header_only;
	$r->rflush;
	$r->print($content);
	$r->status(200);
	return 1;
}

sub graph {
	my($slashdb, $constants, $user, $form, $stats) = @_;

	my($id, $day) = _get_graph_id($slashdb, $constants, $user, $form, $stats);

	my $image   = $constants->{cache_enabled} 
		? $stats->getGraph({ day => $day, id => $id })
		: {};
	my $content = $image->{data};
	my $type    = $image->{content_type} || 'image/png';

	# make image if we don't have it ...
	if (! $content) {
		my($data) = _get_graph_data($slashdb, $constants, $user, $form, $stats);

		$content = slashDisplay('graph', {
			set_legend	=> \&_set_legend,
			data		=> $data,
		}, { Return => 1, Nocomm => 1 });

		$stats->setGraph({
			day		=> $day,
			id		=> $id,
			image		=> $content,
			content_type	=> $type
		});
	}

	my $r = Apache->request;
	$r->content_type($type);
	$r->header_out('Cache-control', 'private');
	$r->header_out('Pragma', 'no-cache');
	$r->status(200);
	$r->send_http_header;
	return 1 if $r->header_only;
	$r->rflush;
	$r->print($content);
	$r->status(200);
	return 1;
}

sub report {
	my($slashdb, $constants, $user, $form, $stats) = @_;

	slashDisplay('report', {
		sections	=> _get_sections(),
	});
}

sub list {
	my($slashdb, $constants, $user, $form, $stats) = @_;

	my $stats_data = {};
	$stats_data = $stats->getAllStats({
		section	=> $form->{stats_section},
		days	=> $form->{stats_days} || 1,
	}) unless $form->{type} eq 'graphs';

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
	my %sections = %{$slashdb->getDescriptions('sections-all')};
	$sections{all} = 'All';
	return \%sections;
}

createEnvironment();
main();

1;

#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

# shifts.pl -- Part of the ScheduleShifts plugin.

use strict;

use Date::Calc qw(Add_Delta_Days);

use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants qw(:web);
use Slash::Display;
use Slash::Utility;
use Slash::XML;
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub main {
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();
	my $gSkin     = getCurrentSkin();
	my $schedule  = getObject('Slash::ScheduleShifts');

	my $admin  = $user->{seclev} >= 500;
	my $shifts = $user->{seclev} >= 100 || $user->{acl}{shifts};

	my %ops = (
		show	=> [ $admin,  \&showShifts	],
		save	=> [ $admin,  \&saveShifts	],
		default	=> [ $admin,  \&showShifts	],
		daddy	=> [ $shifts, \&getDaddyList	],
		lcr	=> [ $shifts, \&setLCR		],
		remark	=> [ $shifts, \&createRemark	],
	);

	my $op = $form->{op};

	if (!$op || !exists $ops{$op} || !$ops{$op}[ALLOWED]) {
		$op = 'default';
		if (!exists $ops{$op} || !$ops{$op}[ALLOWED]) {
			redirect($gSkin->{rootdir});
			return;
		}
	}

	if ($op ne 'daddy' && $op ne 'remark') {
		header(getData('page_title')) or return;
	}

	# dispatch of op
	$ops{$op}[FUNCTION]->($slashdb, $constants, $user, $form, $gSkin, $schedule);

	if ($op ne 'daddy' && $op ne 'remark') {
		# writeLog('SOME DATA');	# if appropriate
		footer();
	}
}


sub setLCR {
	my($slashdb, $constants, $user, $form, $gSkin, $schedule) = @_;

	my $lcr_tag  = $form->{tag};
	my $lcr_site = $form->{site};

	$slashdb->setVar("ircslash_lcr_$lcr_site", $slashdb->getTime . "|$lcr_tag");
}


sub createRemark {
	my($slashdb, $constants, $user, $form, $gSkin, $schedule) = @_;

	my($remark) = $form->{remark};
	my $remarks = getObject('Slash::Remarks');
	$remarks->createRemark($remark, { type => 'system' });
	1;
}


sub getDaddyList {
	my($slashdb, $constants, $user, $form, $gSkin, $schedule) = @_;

	my $daddies = $schedule->getDaddy($form->{when});
	my $when = $form->{when} || 'now';
	my @items;

	my $link = "$gSkin->{absolutedir}/admin.pl";

	my $shift_types = @$daddies > 1
		? $schedule->{shift_types}
		: [ $when ];

	my $editors = $schedule->getEditors;
	my $all = join ', ', map { "<$_->{realemail}>" } grep { $_->{realemail} } @$editors;
	my $extra = ', <pudge@slashdot.org>, <jamie@slashdot.org>';

	for (0 .. $#{$shift_types}) {
		my $shift = $shift_types->[$_];
		my $daddy = $daddies->[$_];

		my $item = {
			title	=> $shift,
			'link'	=> $link
		};

		my($nickname, $email);
		if ($daddy->{uid} > 0) {
			($nickname, $email) = ($daddy->{nickname}, "<$daddy->{realemail}>");
		} else {
			($nickname, $email) = ('unassigned', $all);
		}

		if ($form->{text} && $item->{title} eq 'now') {
			http_send({ content_type => 'text/plain' });
			my $send = $email . $extra;
			$send =~ s/, /\n/g;
			print $send;
			return;
		}

		$item->{description} = "$nickname $email";

		push @items, $item;
	}

	$form->{content_type} ||= 'rss';
	xmlDisplay($form->{content_type} => {
		channel			=> {
			title	=> "$constants->{sitename} shifts for $when",
			'link'	=> $link,
		},
		items			=> \@items,
		rdfitemdesc		=> 1,
		rdfitemdesc_html	=> 1,
	});
}


sub saveShifts {
	my($slashdb, $constants, $user, $form, $gSkin, $schedule) = @_;
	my $defaults = $schedule->getCurrentDefaultShifts;

	$schedule->saveDefaultShifts($defaults);
	$schedule->saveCurrentShifts($defaults);

	showShifts(@_);
}


sub showShifts {
	my($slashdb, $constants, $user, $form, $gSkin, $schedule) = @_;

	my $authors = $slashdb->getDescriptions('authors', '', 1);
	my $defaults = $schedule->getCurrentDefaultShifts || {};
	my $num_weeks = $constants->{shift_schedule_weeks};
	my $shifts = $schedule->getCurrentShifts($num_weeks);

	my $schedule_weeks;
	my $cur_week = $schedule->getCurrentGregorianWeek;
	for (0 .. $num_weeks) {
		push @{$schedule_weeks}, sprintf('%4d-%02d-%02d', 
			# Adjust $cur_week to 1 AD base.
			Add_Delta_Days(1, 1, 1, ($cur_week - 366) + $_ * 7)
		);
	}

	my @dow = map { $schedule->getDayOfWeekOffset($_) } 0..6;

	my($time, $day, $slots) = $schedule->getShift;

	slashDisplay('scheduleForm', {
		# we will be modifying it
		author_list	=> { %$authors },
		days_of_week	=> \@dow,
		default_shifts	=> $defaults,
		shifts 		=> $shifts,
		shift_types 	=> $schedule->{shift_types},
		weeks		=> $schedule_weeks,
		curr_day	=> $day,
	});
}


createEnvironment();
main();

1;

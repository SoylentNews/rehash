#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

# shifts.pl -- Part of the ScheduleShifts plugin.

use strict;

use Date::Calc qw(Add_Delta_Days);
use HTML::FormatText;
use HTML::TreeBuilder;
use MIME::Parser;
use URI::Escape;
use URI::Find;

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
	my($slashdb, $constants, $user, $form, $gSkin, $schedule, $remark) = @_;

	$remark ||= $form->{remark};
	my $remarks = getObject('Slash::Remarks');
	$remarks->createRemark($remark, { type => 'system' });
	1;
}

sub formatRemarkFromEmail {
	my($text) = @_;
	return if !$text || $text eq '1';

	# parse out the mail pieces
	my $parser = new MIME::Parser;
	$parser->output_to_core(1);
	my $entity = $parser->parse_data($text);
	if (!$parser) {
		errorLog("Daddy Mail: parse failed");
		return;
	}

	my $subject = $entity->head->get('Subject');
	$subject =~ s/^\s*\[DP\]\s*//;
	$subject = '(no subject)' unless length $subject;

	my @types = map { qr{^$_$} } qw(text/plain text/.?html text/.+);

	my $body;
	my @parts = $entity->parts;
	if (@parts == 0) {
		$body = $entity;
	} elsif (@parts == 1) {
		$body = $parts[0];
	} else {
		OUTER: for my $type (@types) {
			for my $part (@parts) {
				if ($part->effective_type =~ $type) {
					$body = $part;
					last OUTER;
				}
			}
		}
	}

	my $remark   = join '', @{$body->body};
	my $type     = $body->effective_type;
	my $encoding = $body->head->get('Content-Transfer-Encoding') || '';

	# this really should have been taken care of in the module ...
	$encoding =~ s/\s+$//s;

	# decode
	if ($encoding eq 'base64') {
		require MIME::Base64;
		$remark = MIME::Base64::decode_base64($remark);
	} elsif ($encoding eq 'quoted-printable') {
		require MIME::QuotedPrint;
		$remark = MIME::QuotedPrint::decode_qp($remark);
	}

	# smart check, and dumb check, to see if this is HTML
	if ($type =~ m|/.?html$| || $remark =~ /<html.*>/si) {
		my $tree = HTML::TreeBuilder->new->parse($remark);
		my $formatter = HTML::FormatText->new;
		$remark = $formatter->format($tree);

		$remark =~ s/\[(?:IMAGE)\]//g;

	} else {
		# has to be a recognized type
		$remark = '' unless grep { $type =~ $_ } @types;
	}

	# now pull out the URLs, if they are Slashdot URLs
	my @uris;
	my $find = URI::Find->new(sub {
		my($uri, $uri_text) = @_;
		if ($uri->can('scheme') && $uri->scheme =~ /^https?$/ &&
			$uri->host =~ /(^|\W)slashdot\.org$/) {
			push @uris, $uri;
			return 'U' . ($#uris + 1);
		}
		return $uri_text;
	});

	$find->find(\$remark);

	# reformat the URLs
	my @uri_str;
	for my $uri (@uris) {
		$uri->host('slashdot.org');
		my $sid;
		if ($uri->path =~ m|^/(?:\w+)/(\d+/\d+/\d+/\d+)\.shtml|) {
			$sid = $1;
		} elsif ($uri->path eq '/article.pl' && $uri->query =~ m|sid=(\d+/\d+/\d+/\d+)|) {
			$sid = $1;
		}
		if ($sid) {
			$uri->scheme('https');
#			$uri->path('/admin.pl');
#			$uri->query("op=edit&sid=$sid");
			$uri->path('/article.pl');
			$uri->query("sid=$sid");

			push @uri_str, $uri->as_string;
		}
	}

	# finish up
	$remark =~ s/\n--\s*\n.*$//s;

	for ($subject, $remark) {
		s/\s+/ /sg;
		s/\s$//s;
	}

	my $final = sprintf "DP/%s: %s", substr($subject, 0, 35),
		join('; ', @uri_str, $remark);

	return $final;
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
	# yeah it's lame we're hardcoding this, oh well -- pudge
	my $extra = ', <pudge@slashdot.org>, <jamie@slashdot.org>';

	# we're kinda hijacking things here, using this for something it's not normally
	# used for.  sue me! -- pudge
	if ($form->{text}) {
		my $remark = formatRemarkFromEmail($form->{text});
		createRemark(@_, $remark) if $remark;

		http_send({ content_type => 'text/plain' });
		my $send = $all . $extra;
		#$send =~ s/, /\n/g;
		print $send;
		return;
	}


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

#!/usr/bin/perl
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use warnings;

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
	my $firehose  = getObject("Slash::FireHose");

	my $anonval = $constants->{firehose_anonval_param} || "";

	my %ops = (
		list		=> [1,  \&list, 1, $anonval, { index => 1, issue => 1, page => 1, query_apache => -1, virtual_user => -1, startdate => 1, duration => 1, tab => 1, tabtype => 1, change => 1, section => 1  }],
		default		=> [1,	\&list, 1,  $anonval, { index => 1, issue => 1, page => 1, query_apache => -1, virtual_user => -1, startdate => 1, duration => 1, tab => 1, tabtype => 1, change => 1, section => 1 }],
	);

	my $op = $form->{op} || "";

	if (!$op || !exists $ops{$op} || !$ops{$op}[ALLOWED] || $user->{seclev} < $ops{$op}[MINSECLEV] ) {
		$op = 'default';
	}

	# If default or list op and not logged in force them to be using allowed params or math anonval param
	if (($op eq 'default' || $op eq 'list') && $user->{seclev} <1) {

		my $redirect = 0;
		if ($ops{$op}[4] && ref($ops{$op}[4]) eq "HASH") {
			$redirect = 0;
			my $count;
			foreach (keys %$form) {
				$redirect = 1 if !$ops{$op}[4]{$_}; 
				$count++ if $ops{$op}[4]{$_} && $ops{$op}[4]{$_} > 0;
			}
			# Redirect if there are no operative non/system ops  
			$redirect = 1 if $count == 0;
		}
		if ($redirect && ($ops{$op}[3] && $ops{$op}[3] eq $form->{anonval})) {
			$redirect = 0;
		}
		if ($redirect) {
			my $prefix = $form->{embed} ? "embed_" : "";
			redirect("$gSkin->{rootdir}/${prefix}firehose.shtml");
			return;
		}
	}

	my $title;
	$title = "$constants->{sitename} - $constants->{slogan}";
	header($title, '') or return;


	$ops{$op}[FUNCTION]->($slashdb, $constants, $user, $form, $gSkin);

	footer();
}


sub list {
	my($slashdb, $constants, $user, $form, $gSkin) = @_;
	slashProfInit();
	$form->{'index'} = 1;
	my $firehose = getObject("Slash::FireHose");
	print $firehose->listView();
	slashProfEnd();
}

createEnvironment();
main();

1;

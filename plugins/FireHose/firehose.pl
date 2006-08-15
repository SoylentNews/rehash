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

	if (! $user->{is_admin}) {
		redirect("$gSkin->{rootdir}/");
		return;
	}

	my %ops = (
		list		=> [1,  \&list ],
		view		=> [1, 	\&view ],
		default		=> [1,	\&list]
	);

	my $op = $form->{op};
	if (!$op || !exists $ops{$op} || !$ops{$op}[ALLOWED]) {
		$op = 'default';
	}

	header('FireHose', '' ) or return;

	$ops{$op}[FUNCTION]->($slashdb, $constants, $user, $form, $gSkin);

	footer();
}


sub list {
	my($slashdb, $constants, $user, $form, $gSkin) = @_;
	my $firehose = getObject("Slash::FireHose");
	my $options = {};

	my $view = defined $form->{view} && $form->{view} eq "full" ? "full" : "headline";
	if ($view eq "full") {
		$options->{limit} = 25;
	} else {
		$options->{limit} = 50;
	}

	if ($form->{page}) {
		$options->{offset} = $form->{page} * $options->{limit};
	}

	my $types = { feed => 1, bookmark => 1, submission => 1, journal => 1 };
	my $modes = { full => 1, fulltitle => 1};
	my $orders = { createtime => 1, popularity => 1};

	my $mode = $modes->{$form->{mode}} ? $form->{mode} : "";
	$options->{orderby} = $orders->{$form->{order}} ? $form->{order} : "";

	$options->{primaryskid} = $form->{primaryskid} if $form->{primaryskid};

	$options->{type} = $form->{type} if $form->{type} && $types->{$form->{type}};

	$options->{orderby} = "popularity" if $form->{popularity};
	$options->{orderdir} = $form->{orderdir} eq "ASC" ? "ASC" : "DESC";

	if ($user->{is_admin}) {
		# $options->{attention_needed} = "yes";
		 $options->{accepted} = "no";
		 $options->{rejected} = "no";
	} else  {
		$options->{public} = "yes";
	}
	my $items = $firehose->getFireHoseEssentials($options);
	my $itemstext;
	foreach (@$items) {
		my $item =  $firehose->getFireHose($_->{id});
		$itemstext .= $firehose->dispFireHose($item, { mode => $mode });
	}
	my $page = $form->{page} * 1;
	slashDisplay("list", { itemstext => $itemstext, page => $page } );

}


sub view {
	my($slashdb, $constants, $user, $form, $gSkin) = @_;
	my $firehose = getObject("Slash::FireHose");
	my $item = $firehose->getFireHose($form->{id});
	slashDisplay("view", { item => $item } );
}


createEnvironment();
main();

1;

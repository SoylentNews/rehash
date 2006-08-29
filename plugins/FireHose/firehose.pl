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
	my $options = getAndSetOptions(); 
	my $page = $form->{page} || 0;
	if ($page) {
		$options->{offset} = $page * $options->{limit};
	}

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
		$itemstext .= $firehose->dispFireHose($item, { mode => $options->{mode} });
	}
	
	slashDisplay("list", { itemstext => $itemstext, page => $page, options => $options } );

}

sub getAndSetOptions {
	my $user 	= getCurrentUser();
	my $slashdb	= getCurrentDB();
	my $constants 	= getCurrentStatic();
	my $form 	= getCurrentForm();
	my $options 	= {};

	my $types = { feed => 1, bookmark => 1, submission => 1, journal => 1 };
	my $modes = { full => 1, fulltitle => 1};
	my $orders = { createtime => 1, popularity => 1};

	my $mode = $form->{mode} || $user->{firehose_mode};
	$mode = $modes->{$mode} ? $mode : "fulltitle";
	$options->{mode} = $mode;

	if ($mode eq "full") {
		$options->{limit} = 25;
	} else {
		$options->{limit} = 50;
	}

	$options->{orderby} = defined $form->{order} ? $form->{order} : $user->{firehose_orderdby};

	$options->{primaryskid} = defined $form->{primaryskid} ? $form->{primaryskid} : $user->{firehose_primaryskid};

	$options->{type} = defined $form->{type} ? $form->{type} : $user->{firehose_type};

	$options->{category} = defined $form->{category} ? $form->{category} : $user->{firehose_category};

	$options->{filter} = defined $form->{filter} ? $form->{filter} : $user->{firehose_filter};

	if (!$user->{is_anon}) {
		my $data_change = {};
		foreach (keys %$options) {
			$data_change->{"firehose_$_"} = $options->{$_} if !defined $user->{"firehose_$_"} || $user->{"firehose_$_"} ne $options->{$_};
		}
		$slashdb->setUser($user->{uid}, $data_change ) if keys %$data_change > 0;
		
	}


	return $options;
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

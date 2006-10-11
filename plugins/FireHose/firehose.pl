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

	unless ($user->{is_admin} || $user->{is_subscriber} || $user->{acl}{firehose}) {
		redirect("$gSkin->{rootdir}/");
		return;
	}

	my %ops = (
		list		=> [1,  \&list ],
		view		=> [1, 	\&view ],
		default		=> [1,	\&list],
		setusermode	=> [1,	\&setUserMode ],
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
	my $firehose_reader = getObject('Slash::FireHose', {db_type => 'reader'});
	my $options = $firehose->getAndSetOptions();
	my $page = $form->{page} || 0;
	if ($page) {
		$options->{offset} = $page * $options->{limit};
	}

	my $items = $firehose_reader->getFireHoseEssentials($options);
	my $itemstext;
	my $maxtime = $firehose->getTime();
	
	foreach (@$items) {
		$maxtime = $_->{createtime} if $_->{createtime} gt $maxtime;
		my $item =  $firehose_reader->getFireHose($_->{id});
		my $tags_top = $firehose_reader->getFireHoseTagsTop($item);
		$itemstext .= $firehose->dispFireHose($item, { mode => $options->{mode} , tags_top => $tags_top, options => $options });
	}
	my $refresh_options;
	if ($options->{orderby} eq "createtime" || $options->{orderby} eq "popularity") {
		$refresh_options->{maxtime} = $maxtime;
		if (uc($options->{orderdir}) eq "ASC") {
			$refresh_options->{insert_new_at} = "bottom";
		} else {
			$refresh_options->{insert_new_at} = "top";
		}
	} 

	slashDisplay("list", {
		itemstext => $itemstext, 
		page => $page, 
		options => $options,
		refresh_options => $refresh_options
	});

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

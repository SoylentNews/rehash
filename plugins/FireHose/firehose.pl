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
	print $firehose->listView();
}

sub view {
	my($slashdb, $constants, $user, $form, $gSkin) = @_;
	my $firehose = getObject("Slash::FireHose");
	my $firehose_reader = getObject("Slash::FireHose", { db_type => 'reader' });
	my $options = $firehose->getAndSetOptions();
	my $item = $firehose_reader->getFireHose($form->{id});
	if ($item && $item->{id} && ($item->{public} eq "yes" || $user->{is_admin}) ) {
		my $tags_top = $firehose_reader->getFireHoseTagsTop($item);
		my $firehosetext = $firehose_reader->dispFireHose($item, { mode => "full", tags_top => $tags_top, options => $options });
		slashDisplay("view", {
			firehosetext => $firehosetext
		});
	} else {
		print getData('notavailable');
	}
}



createEnvironment();
main();

1;

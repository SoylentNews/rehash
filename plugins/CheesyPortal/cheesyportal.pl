#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

##################################################################
sub main {
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	header(getData('head')) or return;

	my @portals;
	my $portals = $slashdb->getPortals();

	for (@$portals) {
		my $portal = {};
		@{$portal}{qw(block title bid url)} = @$_;

		if ($portal->{bid} eq 'mysite') {
			$portal->{box} = portalbox($constants->{fancyboxwidth},
				getData('mysite'),
				$user->{mylinks} ||  $portal->{block}
			);
		} elsif ($portal->{bid} =~ /_more$/) {    # do nothing
			next;
		} elsif ($portal->{bid} eq 'userlogin') { # do nothing
			next;
		} else {
			$portal->{box} = portalbox($constants->{fancyboxwidth},
				$portal->{title},
				$portal->{block}, '', $portal->{url}
			);
		}

		push @portals, $portal;
	}

	slashDisplay('main', {
		title	=> "Cheesy $constants->{sitename} Portal Page",
		width	=> '100%',
		portals	=> \@portals,
	});

	footer();
}

#################################################################
createEnvironment();
main();

1;

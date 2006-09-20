#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
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
	setCurrentSkin(determineCurrentSkin());
	my $gSkin = getCurrentSkin();

	my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });
	my $title;
	my $tagname = $form->{tagname} || '';
	my $index_hr = { tagname => $tagname };

	if ($tagname eq '') {

		# If tagname is the empty string, set:
		# displaytype = one of 'active', 'recent', 'all'
		# tagnames = arrayref of tagnames for that display type
		my $type = $index_hr->{displaytype} =
			$form->{type} && $form->{type} =~ /^(active|recent|all)$/
				? $form->{type}
				: 'active';

		if ($type eq 'all') {
			$index_hr->{tagnames} = $tags_reader->listTagnamesAll();
		} elsif ($type eq 'active') {
			$index_hr->{tagnames} = $tags_reader->listTagnamesActive();
		} else { # recent
			$index_hr->{tagnames} = $tags_reader->listTagnamesRecent();
		}

		$title = getData('head1');

	} else {

		my $objects = $tags_reader->getAllObjectsTagname($tagname);
		my %globjids = ( map { ( $_->{globjid}, 1 ) } @$objects );
		my @objects = ( );
		for my $globjid (keys %globjids) {
			my @objs = (grep { $_->{globjid} == $globjid } @$objects);
			push @objects, {
				url	=> $objs[0]{url},
				title	=> $objs[0]{title},
				count	=> scalar(@objs),
			};
		}
		@objects = sort { $b->{count} <=> $a->{count} || $a->{title} cmp $b->{title} } @objects;
		$index_hr->{objects} = \@objects;

		$title = getData('head2', { tagname => $tagname });

	}

#use Data::Dumper; print STDERR scalar(localtime) . " index_hr: " . Dumper($index_hr);

	header({ title => $title });
	slashDisplay('index', $index_hr);
	footer();
}

#################################################################
createEnvironment();
main();

1;


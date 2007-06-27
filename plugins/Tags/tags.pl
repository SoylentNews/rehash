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
	$tagname = '' if !$tags_reader->tagnameSyntaxOK($tagname);
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

		my @objects = ( );

		my $mcd = undef;
		my $mcdkey = undef;
		my $value = undef;
		$mcd = $tags_reader->getMCD();
		if ($mcd) {
			$mcdkey = "$tags_reader->{_mcd_keyprefix}:taotnl:";
			$value = $mcd->get("$mcdkey$tagname");
		}

		if ($value) {
			@objects = @$value;
#print STDERR "tags.pl got '$mcdkey$tagname' as " . scalar(@objects) . " objects\n";
		} else {
			my $objects = $tags_reader->getAllObjectsTagname($tagname, { cloutfield => 'tagpeerval' });
			my %globjids = ( map { ( $_->{globjid}, 1 ) } @$objects );
			my $mintc = defined($constants->{tags_list_mintc}) ? $constants->{tags_list_mintc} : 4;
			for my $globjid (keys %globjids) {
				my @objs = grep { $_->{globjid} == $globjid } @$objects;
				my $sum_tc = 0;
				for my $obj (@objs) {
					$sum_tc += $obj->{total_clout};
				}
				push @objects, {
					url	=> $objs[0]{url},
					title	=> $objs[0]{title},
					count	=> $sum_tc,
				} if $sum_tc >= $mintc;
			}
			@objects = sort { $b->{count} <=> $a->{count} || ($a->{title}||'') cmp ($b->{title}||'') } @objects;
			if ($mcd) {
				my $constants = getCurrentStatic();
				my $secs = $constants->{memcached_exptime_tags_brief} || 300;
				$mcd->set("$mcdkey$tagname", \@objects, $secs);
#print STDERR "tags.pl set '$mcdkey$tagname' to " . scalar(@objects) . " objects\n";
			}
		}
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


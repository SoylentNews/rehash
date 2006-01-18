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
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();
	my $gSkin     = getCurrentSkin();
	
	my $postflag = $user->{state}{post};
	my $op = $form->{op};	
	my $ops = {
		getSectionPrefsHTML => {
			function	=> \&getSectionPrefsHTML,
			seclev		=> 1
		},
		default => {
			function	=> \&default
		}
	};
	
	if ($ops->{$op}{post} && !$postflag) {
		$op = "default";
	}
	
	if ($user->{seclev} < $ops->{$op}{seclev}) {
		$op = 'userinfo';
	}
	
	$ops->{$op}{function}->($slashdb, $constants, $user, $form);
} 

sub getSectionPrefsHTML {
	my ($slashdb, $constants, $user, $form) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	
	my %story023_default = (
		author	=> { },
		nexus	=> { },
		topic	=> { },
	);

	my %prefs = ( );
	
	for my $field (qw(
		story_never_nexus 	story_always_nexus	story_brief_always_nexus
		story_full_brief_nexus	story_full_best_nexus	story_brief_best_nexus
	)) {
		for my $id (
			grep /^\d+$/,
			split /,/,
			($user->{$field} || "")
		) {
			$prefs{$field}{$id} = 1;
		}
	}
	
	my $r = Apache->request;
	$r->content_type('text/plain');
	$r->header_out('Cache-Control', 'no-cache');
	$r->send_http_header;
	
	my $topic_tree = $reader->getTopicTree();
	my $nexus_tids_ar = $reader->getStorypickableNexusChildren($constants->{mainpage_nexus_tid}, 1);
	my $nexus_hr = { };
	my $skins = $reader->getSkins();

	my $hide_nexus;
	foreach(keys %$skins) {
		$hide_nexus->{$skins->{$_}->{nexus}} = 1 if $skins->{$_}{skinindex} eq "no";
	}
	
	for my $tid (@$nexus_tids_ar) {
		$nexus_hr->{$tid} = $topic_tree->{$tid}{textname} if !$hide_nexus->{$tid};
	}
	my @nexustid_order = sort {($b == $constants->{mainpage_nexus_tid}) <=> ($a == $constants->{mainpage_nexus_tid}) || 

lc $nexus_hr->{$a} cmp lc $nexus_hr->{$b} } keys %$nexus_hr;

	for my $tid (@nexustid_order) {
		if ($prefs{story_never_nexus}{$tid}) {
			$story023_default{nexus}{$tid} = 0;
		} elsif ($prefs{story_always_nexus}{$tid}) {
			$story023_default{nexus}{$tid} = 5;
		} elsif ($prefs{story_full_brief_nexus}{$tid}) {
			$story023_default{nexus}{$tid} = 4;
		} elsif ($prefs{story_brief_always_nexus}{$tid}) {
			$story023_default{nexus}{$tid} = 3;
		} elsif ($prefs{story_full_best_nexus}{$tid}) {
			$story023_default{nexus}{$tid} = 2;
		} elsif ($prefs{story_brief_best_nexus}) {
			$story023_default{nexus}{$tid} = 1;
		} else {
			if ($constants->{brief_sectional_mainpage}) {
				$story023_default{nexus}{$tid} = 4;
			} else {
				$story023_default{nexus}{$tid} = 2;
			}		}
	}

	print slashDisplay("sectionpref", {
		nexusref		=> $nexus_hr,
		nexustid_order		=> \@nexustid_order,
		story023_default	=> \%story023_default,
		}, 
		{ Return => 1 }
	);
	
}

sub default {
	my ($slashdb, $constants, $user, $form) = @_;

}

createEnvironment();
main();
1;

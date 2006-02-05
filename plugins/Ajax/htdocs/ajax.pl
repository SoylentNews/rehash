#!/usr/bin/perl
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use warnings;

use Slash 2.003;	# require Slash 2.3.x
use Slash::Display;
use Slash::Utility;
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

##################################################################
sub main {
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();
	my $gSkin     = getCurrentSkin();

=pod

	my $postflag = $user->{state}{post};
	my $op = $form->{op};
	my $ops = {
		getSectionPrefsHTML => {
			function	=> \&getSectionPrefsHTML,
			seclev		=> 1,
		},
		setSectionNexusPrefs => {
			function	=> \&setSectionNexusPrefs,
			seclev		=> 1
		},
		storySignOff => {
			function	=> \&storySignOff,
			seclev		=> 100
		},
		tagsGetUserStory => {
			function	=> \&tagsGetUserStory,
			seclev		=> 1,
		},
		tagsCreateForStory => {
			function	=> \&tagsCreateForStory,
			seclev		=> 1,
		},
		adminTagsCommands => {
			function	=> \&adminTagsCommands,
			seclev		=> 100,
		},
		default => {
			function	=> \&default
		}
	};

=cut

	my $ops = getOps($slashdb);
	my $op = $form->{op};
	$op = 'default' unless $ops->{$op};

	$op = 'default' unless $ops->{$op}{function} || (
		$ops->{$op}{class} && $ops->{$op}{subroutine}
	);

	$ops->{$op}{function} ||= loadCoderef($ops->{$op}{class}, $ops->{$op}{subroutine});
	$op = 'default' unless $ops->{$op}{function};

	$form->{op} = $op;  # save for others to use

	my $reskey_name = $ops->{$op}{reskey_name} || 'ajax_base';

	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key($reskey_name);

	if ($rkey->use) {
		my $options = {};
		my $retval = $ops->{$op}{function}->(
			$slashdb, $constants, $user, $form, $options
		);

		if ($retval) {
			header_ajax($options);
			print $retval;
		}
	}
	# XXX: do anything on error?  a standard error dialog?  or fail silently?
}

##################################################################
sub getSectionPrefsHTML {
	my($slashdb, $constants, $user, $form) = @_;
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

	my $topic_tree = $reader->getTopicTree();
	my $nexus_tids_ar = $reader->getStorypickableNexusChildren($constants->{mainpage_nexus_tid});
	my $nexus_hr = { };
	my $skins = $reader->getSkins();

	my $hide_nexus;
	foreach(keys %$skins) {
		$hide_nexus->{$skins->{$_}->{nexus}} = 1 if $skins->{$_}{skinindex} eq "no";
	}

	for my $tid (@$nexus_tids_ar) {
		$nexus_hr->{$tid} = $topic_tree->{$tid}{textname} if !$hide_nexus->{$tid};
	}
	my @nexustid_order = sort {
		($b == $constants->{mainpage_nexus_tid}) <=> ($a == $constants->{mainpage_nexus_tid})
		||
		lc $nexus_hr->{$a} cmp lc $nexus_hr->{$b}
	} keys %$nexus_hr;

	my $first_val = "";
	my $multiple_values = 0;
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
			}
		}
		$first_val = $story023_default{nexus}{$tid} if $first_val eq "";
		$multiple_values = 1 if $story023_default{nexus}{$tid} != $first_val;
	}

	my $master_value = !$multiple_values ? $first_val : "";

	return slashDisplay("sectionpref",
		{
			nexusref		=> $nexus_hr,
			nexustid_order		=> \@nexustid_order,
			story023_default	=> \%story023_default,
			multiple_values		=> $multiple_values,
			master_value		=> $master_value,
		},
		{ Return => 1 }
	);
}

sub setSectionNexusPrefs() {
	my ($slashdb, $constants, $user, $form) = @_;
	
	my $nexus_tids_ar = $slashdb->getStorypickableNexusChildren($constants->{mainpage_nexus_tid}, 1);

	my @story_always_nexus 		= split ",", $user->{story_always_nexus} || "";
	my @story_full_brief_nexus 	= split ",", $user->{story_full_brief_nexus} || "";
	my @story_brief_always_nexus 	= split ",", $user->{story_brief_always_nexus} || "";
	my @story_full_best_nexus 	= split ",", $user->{story_full_best_nexus} || "";
	my @story_brief_best_nexus 	= split ",", $user->{story_brief_best_nexus} || "";
	my @story_never_nexus 		= split ",", $user->{story_never_nexus} || "";

	my $update = {};

	foreach my $key (keys %$form) {
		my $value = $form->{$key};
		if ($key =~ /^nexustid(\d+)$/) {
			my $tid = $1;
			if ($value >= 0 && $value <= 5 && $value =~ /^\d+$/) {
				$update->{$tid} = $value;
			}
		} elsif ($key eq "nexus_master") {
			if ($value >= 1 && $value <= 5 && $value =~ /^\d+$/) {
				foreach my $tid (@$nexus_tids_ar) {
					$update->{$tid} = $value;
				}
			}
		}
			
	}


	foreach my $tid (keys %$update) {
		my $value = $update->{$tid};

		# First remove tid in question from all arrays
		@story_always_nexus 		= grep { $_ != $tid } @story_always_nexus; 
		@story_full_brief_nexus 	= grep { $_ != $tid } @story_full_brief_nexus;
		@story_brief_always_nexus 	= grep { $_ != $tid } @story_brief_always_nexus;
		@story_full_best_nexus 		= grep { $_ != $tid } @story_full_best_nexus;
		@story_brief_best_nexus 	= grep { $_ != $tid } @story_brief_best_nexus;
		@story_never_nexus 		= grep { $_ != $tid } @story_never_nexus;
			
		# Then add it to the correct array
		if ($value == 5) {
			push @story_always_nexus, $tid;
		} elsif ($value == 4) {
			push @story_full_brief_nexus, $tid;
		} elsif ($value == 3) {
			push @story_brief_always_nexus, $tid;
		} elsif ($value == 2) {
			push @story_full_best_nexus, $tid;
		} elsif ($value == 1) {
			push @story_brief_best_nexus, $tid;
		} elsif ($value == 0) {
			push @story_never_nexus, $tid;
		}
	}

	my $story_always_nexus       	= join ",", @story_always_nexus;
	my $story_full_brief_nexus   	= join ",", @story_full_brief_nexus;
	my $story_brief_always_nexus 	= join ",", @story_brief_always_nexus;
	my $story_full_best_nexus	= join ",", @story_full_best_nexus;
	my $story_brief_best_nexus	= join ",", @story_brief_best_nexus;
	my $story_never_nexus       	= join ",", @story_never_nexus;
				
	$slashdb->setUser($user->{uid}, {
			story_always_nexus => $story_always_nexus,
			story_full_brief_nexus => $story_full_brief_nexus,
			story_brief_always_nexus => $story_brief_always_nexus,
			story_full_best_nexus	=> $story_full_best_nexus,
			story_brief_best_nexus	=> $story_brief_best_nexus,
			story_never_nexus	=> $story_never_nexus
		}
	);

	return getData('set_section_prefs_success_msg');
}

sub storySignOff {
	my($slashdb, $constants, $user, $form) = @_;
	return unless $user->{is_admin};

	my $stoid = $form->{stoid};
	my $uid   = $user->{uid};

	return unless $stoid =~/^\d+$/;

	if ($slashdb->sqlCount("signoff", "stoid = $stoid AND uid = $uid")) {
		return "Already Signed";
	}

	$slashdb->createSignoff($stoid, $uid, "signed");
	return "Signed";
}

sub tagsGetUserStory {
	my($slashdb, $constants, $user, $form) = @_;
	my $stoid = $form->{stoid};
	my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });
print STDERR scalar(localtime) . " tagsGetUserStory stoid='$stoid' user-is='$user->{is_anon}' uid='$user->{uid}' tags_reader='$tags_reader'\n";
	if (!$stoid || $stoid !~ /^\d+$/ || $user->{is_anon} || !$tags_reader) {
		print getData('error', {}, 'tags');
		return;
	}
	my $uid = $user->{uid};

	my $tags_ar = $tags_reader->getTagsByNameAndIdArrayref('stories', $stoid, { uid => $uid });
	my @tags = sort map { $_->{tagname} } @$tags_ar;
use Data::Dumper; print STDERR scalar(localtime) . " tagsGetUserStory for stoid=$stoid uid=$uid tags: '@tags' tags_ar: " . Dumper($tags_ar);

	print getData('tags_user', { tags => \@tags }, 'tags');
}

sub tagsCreateForStory {
	my($slashdb, $constants, $user, $form) = @_;
	my $stoid = $form->{stoid};
	my $tags = getObject('Slash::Tags');
print STDERR scalar(localtime) . " tagsCreateForStory stoid='$stoid' user-is='$user->{is_anon}' uid='$user->{uid}' tags='$tags'\n";
	if (!$stoid || $stoid !~ /^\d+$/ || $user->{is_anon} || !$tags) {
		print getData('error', {}, 'tags');
		return;
	}

	my @tagnames =
		grep { $tags->tagnameSyntaxOK($_) }
		split /[\s,]+/,
		($form->{tags} || '');
	if (!@tagnames) {
		print getData('tags_none_given', {}, 'tags');
		return;
	}

	my @saved_tagnames = ( );
	for my $tagname (@tagnames) {
		push @saved_tagnames, $tagname
			if $tags->createTag({
				uid =>		$user->{uid},
				name =>		$tagname,
				table =>	'stories',
				id =>		$stoid
			});
	}
	print getData('tags_saved', {}, 'tags');
}

sub adminTagsCommands {
	my($slashdb, $constants, $user, $form) = @_;
	my $stoid = $form->{stoid};
	my $tags = getObject('Slash::Tags');
print STDERR scalar(localtime) . " adminTagsCommands stoid='$stoid' seclev='$user->{seclev}' uid='$user->{uid}' tags='$tags'\n";
	if (!$stoid || $stoid !~ /^\d+$/ || $user->{seclev} < 100 || !$tags) {
		print getData('error', {}, 'tags');
		return;
	}

	my @tagnames =
		grep { $tags->adminTagnameSyntaxOK($_) }
		split /[\s,]+/,
		($form->{tags} || '');
	if (!@tagnames) {
		print getData('tags_none_given', {}, 'tags');
		return;
	}

	my @results = ( );
	for my $pseudotag (@tagnames) {
		# do it
	}

	print getData('tags_admin_result', { results => \@results }, 'tags');
}

##################################################################
sub default { }

##################################################################
sub header_ajax {
	my($options) = @_;
	my $ct = $options->{content_type} || 'text/plain';

	my $r = Apache->request;
	$r->content_type($ct);
	$r->header_out('Cache-Control', 'no-cache');
	$r->send_http_header;
}

##################################################################
sub getOps {
	my($slashdb) = @_;
	my $ops;

	# XXX: cache this
	$ops = $slashdb->sqlSelectAllHashref(
		'op', 'op, class, subroutine, reskey_name', 'ajax_ops'
	);

	$ops->{default} = {
		function => \&default,		
	};

	return $ops;
}

##################################################################
createEnvironment();
main();
1;

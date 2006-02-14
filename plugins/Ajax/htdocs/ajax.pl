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

	my $ops = getOps();
	my $op = $form->{op};

	if (!$ops->{$op}) {
		errorLog("No Ajax op '$op' found");
		$op = 'default';
	}

	$op = 'default' unless $ops->{$op}{function} || (
		$ops->{$op}{class} && $ops->{$op}{subroutine}
	);

#$Slash::ResKey::DEBUG = 2;

	$ops->{$op}{function} ||= loadCoderef($ops->{$op}{class}, $ops->{$op}{subroutine});
	$op = 'default' unless $ops->{$op}{function};

	$form->{op} = $op;  # save for others to use

	my $reskey_name = $ops->{$op}{reskey_name} || 'ajax_base';
	$ops->{$op}{reskey_type} ||= 'use';

	if ($reskey_name ne 'NA') {
		my $reskey = getObject('Slash::ResKey');
		my $rkey = $reskey->key($reskey_name);
print STDERR scalar(localtime) . " ajax.pl main no rkey for '$reskey_name'\n" if !$rkey;
		if ($ops->{$op}{reskey_type} eq 'createuse') {
			return unless $rkey && $rkey->createuse;
		} else {
			return unless $rkey && $rkey->use;
		}
	}

	my $options = {};
	my $retval = $ops->{$op}{function}->(
		$slashdb, $constants, $user, $form, $options
	);

	if ($retval) {
		header_ajax($options);
		print $retval;
	}

	# XXX: do anything on error?  a standard error dialog?  or fail silently?
}

##################################################################
sub getSectionPrefsHTML {
	my($slashdb, $constants, $user, $form) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	sleep 3;
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
		grep { $tags->adminPseudotagnameSyntaxOK($_) }
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

	return getData('tags_admin_result', { results => \@results }, 'tags');
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
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();

	my $table_cache         = "_ajaxops_cache";
	my $table_cache_time    = "_ajaxops_cache_time";
	$slashdb->_genericCacheRefresh('ajaxops', $constants->{block_expire});
	if ($slashdb->{$table_cache_time} && $slashdb->{$table_cache}) {
		return $slashdb->{$table_cache};
	}

	my $ops = $slashdb->sqlSelectAllHashref(
		'op', 'op, class, subroutine, reskey_name, reskey_type', 'ajax_ops'
	);

	my %mainops = (
		getSectionPrefsHTML => {
			function	=> \&getSectionPrefsHTML,
			reskey_name	=> 'ajax_user',
			reskey_type	=> 'createuse',
		},
		setSectionNexusPrefs => {
			function	=> \&setSectionNexusPrefs,
			reskey_name	=> 'ajax_user',
			reskey_type	=> 'createuse',
		},
#		tagsGetUserStory => {
#			function	=> \&tagsGetUserStory,
#			reskey_type	=> 'createuse',
#		},
#		tagsCreateForStory => {
#			function	=> \&tagsCreateForStory,
#			reskey_type	=> 'createuse',
#		},
#		adminTagsCommands => {
#			function	=> \&adminTagsCommands,
#			reskey_name	=> 'ajax_admin',
#			reskey_type	=> 'createuse',
#		},
		default	=> {
			function	=> \&default,		
		},
	);

	for (keys %mainops) {
		$ops->{$_} ||= $mainops{$_};
	}

	if ($slashdb->{$table_cache_time}) {
		$slashdb->{$table_cache} = $ops;
	}

	return $ops;
}

##################################################################
createEnvironment();
main();
1;

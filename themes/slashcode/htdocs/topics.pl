#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

#################################################################
sub main {
	my $form    = getCurrentForm();
	my $user    = getCurrentUser();

	my $data = ($form->{op} eq 'hierarchy') ? { admin => 1, adminmenu => 'info', tab_selected => 'hierarchy' } : {};
	header(getData('head'), $form->{section}, $data) or return;

	print createMenu('topics');

	if ($form->{op} eq 'hierarchy') {
		hierarchy();
	} else {
		listTopics();
	}

	footer();
}

#################################################################
sub hierarchy {
	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();
	my $topic_tree = $slashdb->getTopicTree();
	
	my @nexuses;

	foreach my $tid (sort {$topic_tree->{$a}{textname} cmp $topic_tree->{$b}{textname}} keys %$topic_tree) {
		push @nexuses, $tid if $topic_tree->{$tid}{nexus};
	}

	slashDisplay('hierarchy', {
		topic_tree	=> $topic_tree,
		nexuses		=> \@nexuses
	});
}

#################################################################
sub listTopics {
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();

	my $topics = $reader->getTopics;
	
	if ($form->{section}) {
		my %new_topics;
		my $ids = $reader->getDescriptions('topics_section', $form->{section});
		for (keys %$topics) {
			$new_topics{$_} = $topics->{$_} if $ids->{$_};
		}
		$topics = \%new_topics;
	}

	slashDisplay('listTopics', {
		title		=> 'Current Topic Categories',
		width		=> '90%',
		topic_admin	=> getCurrentUser('seclev') >= 500,
		topics		=> [ values %$topics ],
	});

}

#################################################################
createEnvironment();
main();

1;

#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

#################################################################
sub main {
	my $form = getCurrentForm();
	my $section = getSection();

	header(getData('head'), $section->{section});
	print createMenu('topics');

	if ($form->{op} eq 'toptopics') {
		topTopics($section);
	} else {
		listTopics();
	}

	footer($form->{ssi});
}

#################################################################
sub topTopics {
	my($section) = @_;
	my $slashdb = getCurrentDB();
	my $form = getCurrentForm(); 

	$section->{issue} = 0;  # should this be local() ?  -- pudge

	my(@topics, $topics);
	$topics = $slashdb->getTopNewsstoryTopics($form->{all});

	for (@$topics) {
		my $top = $topics[@topics] = {};
		@{$top}{qw(tid alttext image width height cnt)} = @$_;
		$top->{count} = $slashdb->countStory($top->{tid});

		my $limit = $top->{cnt} > 10
			? 10 : $top->{cnt} < 3 || $form->{all}
			? 3 : $top->{cnt};

		$top->{stories} = getOlderStories(
			$slashdb->getNewStories($section, $limit, $top->{tid}),
			$section
		);
	}

	slashDisplay('topTopics', {
		title		=> 'Recent Topics',
		width		=> '90%',
		topics		=> \@topics,
		currtime	=> scalar localtime,
	});
}

#################################################################
sub listTopics {
	my $slashdb = getCurrentDB();

	slashDisplay('listTopics', {
		title		=> 'Current Topic Categories',
		width		=> '90%',
		topic_admin	=> getCurrentUser('seclev') > 500,
		topics		=> $slashdb->getTopics()
	});

}

#################################################################
createEnvironment();
main();

1;

#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

#################################################################
sub main {
	my $slashdb = getCurrentDB();
	my $form    = getCurrentForm();
	my $section = $slashdb->getSection($form->{section});

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
	my $constants = getCurrentStatic();

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
			$slashdb->getStoriesEssentials($limit, $section->{section}, $top->{tid}),
			$section
		);
		if ($top->{image} =~ /^\w+\.\w+$/) {
			$top->{imageclean} = "$constants->{imagedir}/topics/$top->{image}";
		} else {
			$top->{imageclean} = $top->{image};
		}
	}

	slashDisplay('topTopics', {
		title		=> 'Recent Topics',
		width		=> '90%',
		topics		=> \@topics,
		currtime	=> timeCalc(scalar localtime),
	});
}

#################################################################
sub listTopics {
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	my $topics = $slashdb->getTopics();

	for (values %$topics) {
		if ($_->{image} =~ /^\w+\.\w+$/) {
			$_->{imageclean} = "$constants->{imagedir}/topics/$_->{image}";
		} else {
			$_->{imageclean} = $_->{image};
		}
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

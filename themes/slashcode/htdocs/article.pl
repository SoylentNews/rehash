#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

##################################################################
sub main {
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $dbslash = getCurrentDB();
	my $constants = getCurrentStatic();

	# Let's make ONE call to getStory() and fetch all we need.
	# - Cliff
	my $story = $dbslash->getStory($form->{sid});

	my $SECT = $dbslash->getSection($story->{section});
	my $title = $SECT->{isolate} ?
		"$SECT->{title} | $story->{title}" :
		"$constants->{sitename} | $story->{title}";

	header($title, $story->{section});
	slashDisplay('display', {
		poll			=> pollbooth($story->{sid}, 1),
		section			=> $SECT,
		section_block		=> $dbslash->getBlock($SECT->{section}),
		show_poll		=> $dbslash->getPollQuestion($story->{sid}),
		story			=> $story,
		'next'			=> $dbslash->getStoryByTime('>', $story, $SECT),
		prev			=> $dbslash->getStoryByTime('<', $story, $SECT),
	});

	printComments($form->{sid});

	footer();
	writeLog($story->{sid} || $form->{sid});
}

createEnvironment();
main();
1;

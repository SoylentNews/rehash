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
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();

	# Let's make ONE call to getStory() and fetch all we need.
	# - Cliff
	my $story = $slashdb->getStory($form->{sid});

	my $SECT = $slashdb->getSection($story->{section});
	my $title = $SECT->{isolate} ?
		"$SECT->{title} | $story->{title}" :
		"$constants->{sitename} | $story->{title}";

	header($title, $story->{section});
	slashDisplay('display', {
		poll			=> pollbooth($story->{sid}, 1),
		section			=> $SECT,
		section_block		=> $slashdb->getBlock($SECT->{section}),
		show_poll		=> $slashdb->getPollQuestion($story->{sid}),
		story			=> $story,
		'next'			=> $slashdb->getStoryByTime('>', $story, $SECT),
		prev			=> $slashdb->getStoryByTime('<', $story, $SECT),
	});

	printComments($form->{sid});

	footer();
	writeLog($story->{sid} || $form->{sid});
}

createEnvironment();
main();
1;

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

	my $story;

	#Yeah, I am being lazy and paranoid  -Brian
	if (!($user->{author} or $user->{is_admin}) and !$slashdb->checkStoryViewable($form->{sid})) {
		$story = '';
	} else {
		$story = $slashdb->getStory($form->{sid});
	}

	if ($story) {
		my $SECT = $slashdb->getSection($story->{section});
		my $title = $SECT->{isolate} ?
			"$SECT->{title} | $story->{title}" :
			"$constants->{sitename} | $story->{title}";

		# set things up to use the <LINK> tag in the header
		my $next = $slashdb->getStoryByTime('>', $story, $SECT);
		my $prev = $slashdb->getStoryByTime('<', $story, $SECT);

		my $links = {
			title	=> $title,
			'link'	=> {
				section	=> $SECT->{title},
				prev	=> $prev,
				'next'	=> $next,
				author	=> $story->{uid},
			},
		};
		header($links, $story->{section});

		my $pollbooth = pollbooth($story->{sid}, 1);
		slashDisplay('display', {
			poll			=> $pollbooth,
			section			=> $SECT,
			section_block		=> $slashdb->getBlock($SECT->{section}),
			show_poll		=> $pollbooth ? 1 : 0,
			story			=> $story,
			'next'			=> $next,
			prev			=> $prev,
		});

		my $discussion = $slashdb->getDiscussionBySid($story->{sid});
		printComments($discussion);
	} else {
		my $message = getData('no_such_sid');
		header($message);
		print $message;
	}

	footer();
	if ($story) {
		writeLog($story->{sid} || $form->{sid});
	} else {
		writeLog($form->{sid});
	}
}

createEnvironment();
main();
1;

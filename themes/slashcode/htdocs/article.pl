#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
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
		my $authortext;
		if ($user->{is_admin} ) {
			my $future = $slashdb->getStoryByTimeAdmin('>', $story, "3");
			$future = [ reverse(@$future) ];
			my $past = $slashdb->getStoryByTimeAdmin('<', $story, "3");

			$authortext = slashDisplay('futurestorybox', {
							past => $past,
							future => $future,
						}, { Return => 1 });
		}

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

		my $pollbooth = pollbooth($story->{qid}, 1);
		slashDisplay('display', {
			poll			=> $pollbooth,
			section			=> $SECT,
			section_block		=> $slashdb->getBlock($SECT->{section}),
			show_poll		=> $pollbooth ? 1 : 0,
			story			=> $story,
			authortext		=> $authortext,
			'next'			=> $next,
			prev			=> $prev,
		});

		my $discussion = $slashdb->getDiscussionBySid($story->{sid});
		# This is to get tid in comments. It would be a mess to pass it directly to every comment -Brian
		$user->{state}{tid} = $discussion->{topic};
		# this should really be done per-story, perhaps with article_nocomment
		# being a default for the story editor instead of being system-wide; that feature
		# has been begun, but doesn't work -- pudge
		if ($constants->{article_nocomment}) {
			# to do the error channel
			Slash::selectComments($discussion, 0) if $form->{ssi};
		} else {
			printComments($discussion);
		}
	} else {
		my $message = getData('no_such_sid');
		header($message, $form->{section});
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

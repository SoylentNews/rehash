#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
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
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	$story = $reader->getStory($form->{sid});

	my $future_err = 0;
	if ($story && $story->{is_future} && !($user->{is_admin} || $user->{author})) {
		$future_err = 1 if !$constants->{subscribe}
			|| !$user->{is_subscriber}
			|| !$user->{state}{page_plummy};
		if ($future_err) {
			$story = '';
		}
	}

	# Yeah, I am being lazy and paranoid  -Brian
	# Always check the main DB for story status since it will always be accurate -Brian
	if ($story
		&& !($user->{author} || $user->{is_admin})
		&& !$slashdb->checkStoryViewable($form->{sid})) {
		$story = '';
	}

	if ($story) {
		my $SECT = $reader->getSection($story->{section});
		# This should be a getData call for title
		my $title = "$constants->{sitename} | $story->{title}";

		my $authortext;
		if ($user->{is_admin} ) {
			my $future = $reader->getStoryByTimeAdmin('>', $story, "3");
			$future = [ reverse(@$future) ];
			my $past = $reader->getStoryByTimeAdmin('<', $story, "3");

			$authortext = slashDisplay('futurestorybox', {
							past => $past,
							future => $future,
						}, { Return => 1 });
		}

		# set things up to use the <LINK> tag in the header
		my($next, $prev) = ('', '');
		if ($constants->{use_prev_next_link}) {
			$next = $reader->getStoryByTime('>', $story, $SECT) unless $story->{is_future};
			$prev = $reader->getStoryByTime('<', $story, $SECT);
		}

		my $links = {
			title	=> $title,
			story	=> $story,
			'link'	=> {
				section	=> $SECT,
				prev	=> $prev,
				'next'	=> $next,
				author	=> $story->{uid},
			},
		};
		header($links, $story->{section}) or return;

		# Can't do this before getStoryByTime because
		# $story->{time} is passed to an SQL request.
		$story->{time} = $constants->{subscribe_future_name}
			if $story->{is_future} && !($user->{is_admin} || $user->{author});

		my $pollbooth = pollbooth($story->{qid}, 1)
			if $story->{qid} and ($slashdb->hasPollActivated($story->{qid}) or $user->{is_admin}) ;
		slashDisplay('display', {
			poll			=> $pollbooth,
			section			=> $SECT,
			section_block		=> $reader->getBlock($SECT->{section}),
			show_poll		=> $pollbooth ? 1 : 0,
			story			=> $story,
			authortext		=> $authortext,
			'next'			=> $next,
			prev			=> $prev,
		});

		# Still not happy with this logic -Brian
		if ($story->{discussion}) {
			my $discussion = $reader->getDiscussion($story->{discussion});
			$discussion->{is_future} = $story->{is_future};
			# This is to get tid in comments. It would be a mess to pass it
			# directly to every comment -Brian
			my $tids = $reader->getStoryTopicsJustTids($story->{sid}); 
			my $tid_string = join('&amp;tid=', @$tids);
			$user->{state}{tid} = $tid_string;
			# If no comments ever have existed and commentstatus is disabled,
			# just skip the display of the comment header bar -Brian
			printComments($discussion)
				if $discussion && !(
					!$discussion->{commentcount} && $discussion->{commentstatus} eq 'disabled'
				);
		}
	} else {
		header('Error', $form->{section}) or return;
		my $message;
		if ($future_err) {
			$message = getData('article_nosubscription');
		} else {
			$message = getData('no_such_sid');
		}
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

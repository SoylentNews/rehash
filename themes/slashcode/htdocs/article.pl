#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
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
			my $future = $reader->getStoryByTimeAdmin('>', $story, 3);
			$future = [ reverse @$future ];
			my $past = $reader->getStoryByTimeAdmin('<', $story, 3);
			my $current = $reader->getStoryByTimeAdmin('=', $story, 20);
			unshift @$past, @$current;

			$authortext = slashDisplay('futurestorybox', {
				past	=> $past,
				future	=> $future,
			}, { Return => 1 });
		}

		# set things up to use the <LINK> tag in the header
		my %stories;
		my $prev_next_linkrel = '';
		if ($constants->{use_prev_next_link}) {
			# section and series links must be defined as separate
			# constants in vars
			my($use_section, $use_series);
			$use_section = $story->{section} if
				$constants->{use_prev_next_link_section} &&
				$SECT->{type} eq 'contained';
			$use_series  = $story->{tid}     if 
				$constants->{use_prev_next_link_series} &&
				$reader->getTopic($story->{tid})->{series};

			$stories{'prev'}   = $reader->getStoryByTime('<', $story);
			$stories{'next'}   = $reader->getStoryByTime('>', $story)
				unless $story->{is_future};

			if ($use_section) {
				my @a = ($story, { section => $use_section });
				$stories{'s_prev'} = $reader->getStoryByTime('<', @a);
				$stories{'s_next'} = $reader->getStoryByTime('>', @a)
					unless $story->{is_future};
			}

			if ($use_series) {
				my @a = ($story, { topic => $use_series });
				$stories{'t_prev'} = $reader->getStoryByTime('<', @a);
				$stories{'t_next'} = $reader->getStoryByTime('>', @a)
					unless $story->{is_future};
			}

			# you should only have one next/prev link, so do series first, then sectional,
			# then main, each if applicable -- pudge
			$prev_next_linkrel = $use_series ? 't_' : $use_section ? 's_' : '';
		}

		my $links = {
			title	=> $title,
			story	=> $story,
			'link'	=> {
				section	=> $SECT,
				prev	=> $stories{$prev_next_linkrel . 'prev'},
				'next'	=> $stories{$prev_next_linkrel . 'next'},
				author	=> $story->{uid},
			},
		};

		my $topics = $reader->getStoryTopics($form->{sid}, 1);
		my @topic_desc = values %$topics;
		my $a;
		if (@topic_desc == 1) {
			$a = $topic_desc[0];
		} elsif (@topic_desc == 2){
			$a = join(' and ', @topic_desc);
		} elsif (@topic_desc > 2) {
			my $last = pop @topic_desc;
			$a = join(', ', @topic_desc) . ", and $last";
		}
		my $meta_desc = "$story->{title} -- article related to $a.";

		header($links, $story->{section}, { meta_desc => $meta_desc }) or return;

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
			stories			=> \%stories,
		});

		my $called_pc = 0;
		if ($story->{discussion}) {
			# Still not happy with this logic -Brian
			my $discussion = $reader->getDiscussion($story->{discussion});
			$discussion->{is_future} = $story->{is_future};
			if ($constants->{tids_in_urls}) {
				# This is to get tid in comments. It would be a mess to
				# pass it directly to every comment -Brian
				my $tids = $reader->getStoryTopicsJustTids($story->{sid}); 
				my $tid_string = join('&amp;tid=', @$tids);
				$user->{state}{tid} = $tid_string;
			}
			# If no comments ever have existed and commentstatus is disabled,
			# just skip the display of the comment header bar -Brian
			if ($discussion && ! (
				   !$discussion->{commentcount}
				&&  $discussion->{commentstatus} eq 'disabled'
			)) {
				printComments($discussion);
				$called_pc = 1;
			}
		}
		if (!$called_pc && $form->{ssi} eq 'yes' && $form->{cchp}) {
			# This is a real hack, we're kind of skipping down
			# two levels of code.  But the cchp printing is an
			# important optimization;  we avoid having to do
			# multiple expensive comment selects.  One problem
			# is that if there's no discussion with a story,
			# printComments() doesn't get called, which means
			# selectComments() doesn't get called, which means
			# the cchp file won't be written.  If article.pl
			# is being called by slashd, and we need to write
			# that file, then here's where we print an empty
			# file that will satisfy slashd. - Jamie
			Slash::_print_cchp({ sid => "dummy" });
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

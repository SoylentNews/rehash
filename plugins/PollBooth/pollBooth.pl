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
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();

	my %ops = (
		edit		=> \&editpoll,
		save		=> \&savepoll,
		'delete'	=> \&deletepolls,
		list		=> \&listpolls,
		default		=> \&default,
		vote		=> \&vote,
		vote_return		=> \&vote_return,
		get		=> \&poll_booth,
	);

	my $op = $form->{op};
	$op = 'default' unless $ops{$form->{op}};
	if (defined $form->{'aid'} && $form->{'aid'} !~ /^\-?\d$/) {
		undef $form->{'aid'};
	}

	if ($op eq "vote_return") {
		$ops{$op}->($slashdb,$form);
		# Why not do this in a more generic manner you say? 
		# Because I am paranoid about this being abused. -Brian
		if ($form->{sid}) {
			my $section = $slashdb->getStory($form->{sid}, 'section');
			my $url = $slashdb->getSection($section, 'url');
			$url ||= $constants->{real_rootdir};
			
			redirect($url, "/article.pl?sid=$form->{sid}");
		}
	}

	if ($form->{qid}) {
		my $section = $slashdb->getPollQuestion($form->{qid}, 'section');
		header(getData('title'), $section);
	} else {
		header(getData('title'), $form->{section});
	}

	$ops{$op}->($form);

	writeLog($form->{'qid'});
	footer();
}

#################################################################
sub poll_booth {
	my($form) = @_;

	print pollbooth($form->{'qid'}, 0, 1);
}

#################################################################
sub default {
	my($form) = @_;

	if (!$form->{'qid'}) {
		listpolls(@_);
	} elsif (! defined $form->{'aid'}) {
		poll_booth(@_);
	} else {
		my $vote = vote(@_);
		if (getCurrentStatic('poll_discussions')) {
			my $slashdb = getCurrentDB();
			my $discussion_id = $slashdb->getPollQuestion(
				$form->{'qid'}, 'discussion'
			);
			my $discussion = $slashdb->getDiscussion($discussion_id)
				if $discussion_id;
			if ($discussion) {
				printComments($discussion);
			}
		}
	}
}

#################################################################
sub editpoll {
	my($form) = @_;

	my($qid) = $form->{'qid'};
	unless (getCurrentUser('is_admin')) {
		default(@_);
		return;
	}
	my $slashdb = getCurrentDB();

	my $currentqid = $slashdb->getVar('currentqid', 'value')
		if $qid;
	my($question, $answers, $pollbooth);
	if ($qid) {
		$question = $slashdb->getPollQuestion($qid, [qw( question voters )]);
		$question->{sid} = $slashdb->sqlSelect("sid", "stories",
			"qid=".$slashdb->sqlQuote($qid),
			"ORDER BY time DESC");
		$answers = $slashdb->getPollAnswers($qid, [qw( answer votes aid )]);
		my $polls;
		for (@$answers) {
			push @$polls, [$question, $_->[0], $_->[2], $_->[1]];
		}
		my $raw_pollbooth = slashDisplay('pollbooth', {
			polls		=> $polls,
			question	=> $question->{question},
			qid		=> $qid,
			voters		=> $question->{voters},
		}, 1);
		my $constants = getCurrentStatic();
		$pollbooth = fancybox($constants->{fancyboxwidth}, 'Poll', $raw_pollbooth, 0, 1);
	}

	if ($question) {
		$question->{voters} ||= 0;
	} else {
		$question->{voters} ||= 0;
		$question->{question} = $form->{question}; 
		$question->{sid} = $form->{sid}; 
	}

	slashDisplay('editpoll', {
		title		=> getData('edit_poll_title', { qid=>$qid }),
		checked		=> $currentqid eq $qid ? ' CHECKED' : '',
		qid		=> $qid,
		question	=> $question,
		answers		=> $answers,
		pollbooth	=> $pollbooth,
	});
}

#################################################################
sub savepoll {
	my($form) = @_;

	unless (getCurrentUser('is_admin')) {
		default(@_);
		return;
	}
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	slashDisplay('savepoll');
	#We are lazy, we just pass along $form as a $poll
	my $qid = $slashdb->savePollQuestion($form);

	# we have a problem here.  if you attach the poll to an SID,
	# and then unattach it, it will still be attached to that SID
	# until you either change it manually in the DB, or attach it
	# to a new SID.  Deal with it, or send in a patch.  The logic
	# to deal with it otherwise is too complex to be warranted
	# given the infrequency of the circumstance. -- pudge
	# Right - I still need to put a qid editing field into
	# editStory and it'd be nice to see an overall list of which
	# stories are associated with which polls for the last, say,
	# year.  But one thing at a time. -- jamie 2002/04/15

	if ($constants->{poll_discussions}) {
		my $poll = $slashdb->getPollQuestion($qid);
		my $discussion;
		if ($poll->{sid}) {
			# if sid lookup fails, then $discussion is empty,
			# and the poll's discussion is not set
			$discussion = $slashdb->getStory($form->{sid}, 'discussion');
		} elsif (!$poll->{discussion}) {
			$discussion = $slashdb->createDiscussion({
				title	=> $form->{question},
				topic	=> $form->{topic},
				approved  => 1, # Story discussions are always approved -Brian
				url	=> "$constants->{rootdir}/pollBooth.pl?qid=$qid&aid=-1",
			});
		} elsif ($poll->{discussion}) {
			# Yep, this is lazy -Brian
			$slashdb->setDiscussion($poll->{discussion}, {
				title => $form->{question},
				topic => $form->{topic}
			});
		}
		# if it already has a discussion (so $discussion is not set),
		# or discussion ID is unchanged, don't bother setting
		$slashdb->setPollQuestion($qid, { discussion => $discussion })
			if $discussion && $discussion != $poll->{discussion};
	}
	$slashdb->setStory($form->{sid}, { qid => $qid }) if $form->{sid};
}

#################################################################
sub vote_return {
	my($slashdb, $form) = @_;

	my $qid = $form->{'qid'};
	my $aid = $form->{'aid'};
	return unless $qid && $aid;

	my(%all_aid) = map { ($_->[0], 1) }
		@{$slashdb->getPollAnswers($qid, ['aid'])};
	my $poll_open = $slashdb->isPollOpen($qid);
	my $has_voted = $slashdb->hasVotedIn($qid);

	if ($has_voted) {
		# Specific reason why can't vote.
	} elsif (!$poll_open) {
		# Voting is closed on this poll.
	} elsif (exists $all_aid{$aid}) {
		$slashdb->createPollVoter($qid, $aid);
	}
}

#################################################################
sub vote {
	my($form) = @_;

	my $qid = $form->{'qid'};
	my $aid = $form->{'aid'};

	return unless $qid;

	my $slashdb = getCurrentDB();

	my(%all_aid) = map { ($_->[0], 1) }
		@{$slashdb->getPollAnswers($qid, ['aid'])};

	if (! keys %all_aid) {
		print getData('invalid');
		# Non-zero denotes error condition and that comments
		# should not be printed.
		return;
	}

	my $question = $slashdb->getPollQuestion($qid, ['voters', 'question']);
	my $notes = getData('display');
	if (getCurrentUser('is_anon') and ! getCurrentStatic('allow_anonymous')) {
		$notes = getData('anon');
	} elsif ($aid > 0) {
		my $poll_open = $slashdb->isPollOpen($qid);
		my $has_voted = $slashdb->hasVotedIn($qid);

		if ($has_voted) {
			# Specific reason why can't vote.
			$notes = getData('uid_voted');
		} elsif (!$poll_open) {
			# Voting is closed on this poll.
			$notes = getData('poll_closed');
		} elsif (exists $all_aid{$aid}) {
			$notes = getData('success', { aid => $aid });
			$slashdb->createPollVoter($qid, $aid);
			$question->{voters}++;
		} else {
			$notes = getData('reject', { aid => $aid });
		}
	}

	my $answers  = $slashdb->getPollAnswers($qid, ['answer', 'votes']);
	my $maxvotes = $slashdb->getPollVotesMax($qid);
	my @pollitems;
	for (@$answers) {
		my($answer, $votes) = @$_;
		my $imagewidth	= $maxvotes
			? int(350 * $votes / $maxvotes) + 1
			: 0;
		my $percent	= $question->{voters}
			? int(100 * $votes / $question->{voters})
			: 0;
		push @pollitems, [$answer, $imagewidth, $votes, $percent];
	}

	slashDisplay('vote', {
		qid		=> $qid,
		width		=> '99%',
		title		=> $question->{question},
		voters		=> $question->{voters},
		pollitems	=> \@pollitems,
		notes		=> $notes
	});
}

#################################################################
sub deletepolls {
	my($form) = @_;
	if (getCurrentUser('is_admin')) {
		my $slashdb = getCurrentDB();
		$slashdb->deletePoll($form->{'qid'});
	}
	listpolls(@_);
}

#################################################################
sub listpolls {
	my($form) = @_;
	my $slashdb = getCurrentDB();
	my $min = $form->{min} || 0;
	my $questions = $slashdb->getPollQuestionList($min, { section => $form->{section} } );
	my $sitename = getCurrentStatic('sitename');

	# Just me, but shouldn't title be in the template?
	# yes
	slashDisplay('listpolls', {
		questions	=> $questions,
		startat		=> $min + @$questions,
		admin		=> getCurrentUser('seclev') >= 100,
		title		=> "$sitename Polls",
		width		=> '99%'
	});
}

#################################################################
createEnvironment();
main();

1;

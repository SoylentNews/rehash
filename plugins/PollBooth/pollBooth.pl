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

	my %ops = (
		edit		=> \&editpoll,
		save		=> \&savepoll,
		'delete'	=> \&deletepolls,
		list		=> \&listpolls,
		default		=> \&default,
		vote		=> \&vote,
		get		=> \&poll_booth,
	);

	my $op = $form->{op};
	if (defined $form->{'aid'} && $form->{'aid'} !~ /^\-?\d$/) {
		undef $form->{'aid'};
	}

	header(getData('title'), $form->{section});

	$op = 'default' unless $ops{$form->{op}};
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
			my $discussion = 
				$slashdb->getDiscussion($discussion_id);
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
		$question = $slashdb->getPollQuestion($qid, ['question', 'voters', 'sid']);
		$answers = $slashdb->getPollAnswers($qid, ['answer', 'votes', 'aid']);
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
				url	=> "$constants->{rootdir}/pollBooth.pl?qid=$qid&aid=-1",
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
		my $id = $slashdb->getPollVoter($qid);

		if ($id) {
			$notes = getData('uid_voted');
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
	my $questions = $slashdb->getPollQuestionList($min);
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

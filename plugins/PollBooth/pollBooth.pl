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
	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $user = getCurrentUser();

	my $op = $form->{op};
	if (defined $form->{aid} && $form->{aid} !~ /^\-?\d$/) {
		undef $form->{aid};
	}

	header(getData('title'), $form->{section});

	if ($user->{seclev} > 99 && $op eq 'edit') {
		editpoll($form->{qid});

	} elsif ($user->{seclev} > 99 && $op eq 'save') {
		savepoll();

	} elsif (! defined $form->{qid}) {
		listpolls();

	} elsif (! defined $form->{aid}) {
		print pollbooth($form->{qid}, 0, 1);

	} else {
		my $vote = vote($form->{qid}, $form->{aid});
		printComments($form->{qid})
			if $vote && ! $slashdb->getVar('nocomment', 'value');
	}

	writeLog($form->{qid});
	footer();
}

#################################################################
sub editpoll {
	my($qid) = @_;
	my $slashdb = getCurrentDB();

	my($currentqid) = $slashdb->getVar('currentqid', 'value');
	my $question = $slashdb->getPollQuestion($qid, ['question', 'voters']);
	$question->{voters} ||= 0;

	my $answers = $slashdb->getPollAnswers($qid, ['answer', 'votes']);

	slashDisplay('editpoll', {
		checked		=> $currentqid eq $qid ? ' CHECKED' : '',
		qid		=> $qid,
		question	=> $question,
		answers		=> $answers,
	});
}

#################################################################
sub savepoll {
	return unless getCurrentForm('qid');
	my $slashdb = getCurrentDB();
	slashDisplay('savepoll');
	$slashdb->savePollQuestion();
}

#################################################################
sub vote {
	my($qid, $aid) = @_;
	return unless $qid;

	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
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
	if ($user->{is_anon} && ! $constants->{allow_anonymous}) {
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
sub listpolls {
	my $slashdb = getCurrentDB();
	my $min = getCurrentForm('min') || 0;
	my $questions = $slashdb->getPollQuestionList($min);
	my $sitename = getCurrentStatic('sitename');

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

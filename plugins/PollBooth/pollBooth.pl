#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
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
		vote_return	=> \&vote_return,
		get		=> \&poll_booth,
	);

	my $op = $form->{op};
	$op = 'default' unless $ops{$form->{op}};
	if (defined $form->{'aid'} && $form->{'aid'} !~ /^\-?\d$/) {
		undef $form->{'aid'};
	}
# This is unfinished and has been hacked. I don't trust it anymore and
# the site that it was written for does not use it currently -Brian
#
#	# Paranoia is fine, but why can't this be done from the handler 
#	# rather than hacking in special case code? - Cliff
#	if ($op eq "vote_return") {
#		$ops{$op}->($form, $slashdb);
#		# Why not do this in a more generic manner you say? 
#		# Because I am paranoid about this being abused. -Brian
#		#
#		# This doesn't answer my question. How is doing this here
#		# any better or worse than doing it at the end of vote_return()
#		# -Cliff
#		my $SECT = $slashdb->getSection();
#		if ($SECT) {
#			my $url = $SECT->{rootdir} || $constants->{real_rootdir};
#
#			# Remove the scheme and authority portions, if present.
#			$form->{returnto} =~ s{^(?:.+?)?//.+?/}{/};
#			
#			# Form new absolute URL based on section URL and then
#			# redirect the user.
#			my $refer = URI->new_abs($form->{returnto}, $url);
#			redirect($refer->as_string);
#		}
#	}
#
	header(getData('title'), $form->{section}, { tab_selected => 'poll'});

	$ops{$op}->($form, $slashdb, $constants);

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
	my($form, $slashdb, $constants) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	if (!$form->{'qid'}) {
		listpolls(@_);
	} elsif (! defined $form->{'aid'}) {
		poll_booth(@_);
	} else {
		my $vote = vote(@_);
		if ($constants->{poll_discussions}) {
			my $discussion_id = $reader->getPollQuestion(
				$form->{'qid'}, 'discussion'
			);
			my $discussion = $reader->getDiscussion($discussion_id)
				if $discussion_id;
			if ($discussion) {
				printComments($discussion);
			}
		}
	}
}

#################################################################
sub editpoll {
	my($form, $slashdb, $constants) = @_;

	my $qid  = $form->{'qid'};

	my $user = getCurrentUser();

	unless ($user->{'is_admin'}) {
		default(@_);
		return;
	}

	my($question, $answers, $pollbooth, $checked);
	if ($qid) {
		$question = $slashdb->getPollQuestion($qid);
		$question->{sid} = $slashdb->getSidForQID($qid)
			unless $question->{autopoll};
		$answers = $slashdb->getPollAnswers(
			$qid, [qw( answer votes aid )]
		);
		$checked = ($slashdb->getSection($question->{section}, 'qid', 1) == $qid) ? 1 : 0;
		my $poll_open = $slashdb->isPollOpen($qid);

		# Just use the DB method, it's too messed up to rebuild the logic
		# here -Brian
		my $poll = $slashdb->getPoll($qid);
		my $raw_pollbooth = slashDisplay('pollbooth', {
			qid		=> $qid,
			voters		=> $question->{voters},
			poll_open 	=> $poll_open,
			question	=> $poll->{pollq}{question},
			answers		=> $poll->{answers},
			voters		=> $poll->{pollq}{voters},
			sect		=> $user->{section} || $question->{section},
		}, 1);
		$pollbooth = fancybox(
			$constants->{fancyboxwidth}, 
			'Poll', 
			$raw_pollbooth, 
			0, 1
		);
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
		qid		=> $qid,
		question	=> $question,
		answers		=> $answers,
		pollbooth	=> $pollbooth,
		checked		=> $checked,
	});
}

#################################################################
sub savepoll {
	my($form, $slashdb, $constants) = @_;

	my $user = getCurrentUser();

	unless ($user->{'is_admin'}) {
		default(@_);
		return;
	}
	slashDisplay('savepoll');
	#We are lazy, we just pass along $form as a $poll
	# Correct section for sectional editor first -Brian
	$form->{section} = $user->{section} if $user->{section};
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
			$discussion = $slashdb->getStory(
				$form->{sid}, 'discussion'
			);
		} elsif (!$poll->{discussion}) {
			$discussion = $slashdb->createDiscussion({
				title		=> $form->{question},
				topic		=> $form->{topic},
				approved	=> 1, # Story discussions are always approved -Brian
				url		=> "$constants->{rootdir}/pollBooth.pl?qid=$qid&aid=-1",
			});
		} elsif ($poll->{discussion}) {
			# Yep, this is lazy -Brian
			$slashdb->setDiscussion($poll->{discussion}, {
				title	=> $form->{question},
				topic	=> $form->{topic}
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
	my($form, $slashdb) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	my $qid = $form->{'qid'};
	my $aid = $form->{'aid'};
	return unless $qid && $aid;

	my(%all_aid) = map { ($_->[0], 1) }
		@{$reader->getPollAnswers($qid, ['aid'])};
	my $poll_open = $reader->isPollOpen($qid);
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
	my($form, $slashdb) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	my $qid = $form->{'qid'};
	my $aid = $form->{'aid'};
	return unless $qid;

	my(%all_aid) = map { ($_->[0], 1) }
		@{$reader->getPollAnswers($qid, ['aid'])};

	if (! keys %all_aid) {
		print getData('invalid');
		# Non-zero denotes error condition and that comments
		# should not be printed.
		return;
	}

	my $question = $reader->getPollQuestion($qid, ['voters', 'question']);
	my $notes = getData('display');
	if (getCurrentUser('is_anon') && !getCurrentStatic('allow_anonymous')) {
		$notes = getData('anon');
	} elsif ($aid > 0) {
		my $poll_open = $reader->isPollOpen($qid);
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

	my $answers  = $reader->getPollAnswers($qid, ['answer', 'votes']);
	my $maxvotes = $reader->getPollVotesMax($qid);
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
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $min = $form->{min} || 0;
	my $questions = $reader->getPollQuestionList($min);
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

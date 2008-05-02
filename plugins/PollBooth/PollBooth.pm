# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::PollBooth;

use strict;
use DBIx::Password;
use Slash;
use Slash::Constants qw(:people :messages);
use Slash::Utility;
use Slash::DB::Utility;

use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

our $VERSION = $Slash::Constants::VERSION;

sub new {
	my($class, $user) = @_;
	my $self = {};

	my $plugin = getCurrentStatic('plugin');
	return unless $plugin->{'PollBooth'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;

	return $self;
}

sub setPollQuestion {
	Slash::DB::MySQL::_genericSet('pollquestions', 'qid', '', @_);
}

sub getPollQuestion {
	my $answer = Slash::DB::MySQL::_genericGet({
		table           => 'pollquestions',
		table_prime     => 'qid',
		arguments       => \@_,
	});
	return $answer;
}

sub createAutoPollFromStory {
	my($options) = @_;
	my $pollbooth_db = getObject('Slash::PollBooth');
	my $story = $options->{story};
	my $qid = $pollbooth_db->sqlSelect('qid', 'auto_poll', "primaryskid = '$story->{primaryskid}'");
	if ($qid) {
		my $question = $pollbooth_db->getPollQuestion($qid, 'question');
		my $answers = $pollbooth_db->getPollAnswers($qid, [ qw| answer | ]);
		my $newpoll = {
			primaryskid => $story->{primaryskid},
			topic => $story->{tid},
			question  => $question,
			autopoll => 'yes',
		};
		
		my $x =1;
		for (@$answers) {
			$newpoll->{'aid' . $x} = $_->[0];
			$x++;
		}
		my $qid = $pollbooth_db->savePollQuestion($newpoll);
		$pollbooth_db->setStory($story->{sid}, { qid => $qid, writestatus => 'dirty' });
	}

	return 1;
}

sub getCurrentQidForSkid {
	my($self, $skid) = @_;
	my $tree = $self->getTopicTree();
	my $nexus_id = $self->getNexusFromSkid($skid);
	my $nexus = $tree->{$nexus_id};
	return $nexus ? $nexus->{current_qid} : 0;
}

sub createPollVoter {
	my($self, $qid, $aid) = @_;
	my $constants = getCurrentStatic();

	my $qid_quoted = $self->sqlQuote($qid);
	my $aid_quoted = $self->sqlQuote($aid);
	my $pollvoter_md5 = getPollVoterHash();
	$self->sqlInsert("pollvoters", {
		qid     => $qid,
		id      => $pollvoter_md5,
		-'time' => 'NOW()',
		uid     => getCurrentUser('uid')
	});

	$self->sqlUpdate("pollquestions", {
			-voters =>      'voters+1',
		}, "qid=$qid_quoted");
	$self->sqlUpdate("pollanswers", {
			-votes =>       'votes+1',
		}, "qid=$qid_quoted AND aid=$aid_quoted");
}

sub checkPollVoter {
	my($self, $qid, $uid) = @_;
	my $qid_q = $self->sqlQuote($qid);
	my $pollvoter_md5 = getPollVoterHash();
	return $self->sqlSelect(
		'id',
		'pollvoters',
		"qid=$qid_q AND id='$pollvoter_md5' AND uid=$uid"
	) || 0;
}

# Someday we'll support closing polls, in which case this method
# may return 0 sometimes.
sub isPollOpen {
	my($self, $qid) = @_;
	return 0 unless $self->hasPollActivated($qid);
	return 1;
}

sub hasPollActivated{
	my($self, $qid) = @_;
	return $self->sqlCount("pollquestions", "qid='$qid' and date <= now() and polltype!='nodisplay'");
}

# Yes, I hate the name of this. -Brian
# Presumably because it also saves poll answers, and number of
# votes cast for those answers, and optionally attaches the
# poll to a story.  Can we think of a better name than
# "savePollQuestion"? - Jamie
# sub saveMuTantSpawnSatanPollCrap {
#    -Brian
sub savePollQuestion {
	my($self, $poll) = @_;

	# XXXSKIN should get mainpage_skid, not defaultsection
	$poll->{section}  ||= getCurrentStatic('defaultsection');
	$poll->{voters}   ||= "0";
	$poll->{autopoll} ||= "no";
	$poll->{polltype} ||= "section";

	my $qid_quoted = "";
	$qid_quoted = $self->sqlQuote($poll->{qid}) if $poll->{qid};

	my $stoid;
	$stoid = $self->getStoidFromSidOrStoid($poll->{sid}) if $poll->{sid};
	my $sid_quoted = "";
	$sid_quoted = $self->sqlQuote($poll->{sid}) if $poll->{sid};
	$self->setStory_delete_memcached_by_stoid([ $stoid ]) if $stoid;

	# get hash of fields to update based on the linked story
	my $data = $self->getPollUpdateHashFromStory($poll->{sid}, {
		topic           => 1,
		primaryskid     => 1,
		date            => 1,
		polltype        => 1
	}) if $poll->{sid};
	# replace form values with those from story
	foreach (keys %$data){
		$poll->{$_} = $data->{$_};
	}

	if ($poll->{qid}) {
		$self->sqlUpdate("pollquestions", {
			question        => $poll->{question},
			voters          => $poll->{voters},
			topic           => $poll->{topic},
			autopoll        => $poll->{autopoll},
			primaryskid     => $poll->{primaryskid},
			date            => $poll->{date},
			polltype        => $poll->{polltype}
		}, "qid = $qid_quoted");
		$self->sqlUpdate("stories", {
			qid             => $poll->{qid}
		}, "sid = $sid_quoted") if $sid_quoted;
	} else {
		$self->sqlInsert("pollquestions", {
			question        => $poll->{question},
			voters          => $poll->{voters},
			topic           => $poll->{topic},
			primaryskid     => $poll->{primaryskid},
			autopoll        => $poll->{autopoll},
			uid             => getCurrentUser('uid'),
			date            => $poll->{date},
			polltype        => $poll->{polltype}
		});
		$poll->{qid} = $self->getLastInsertId();
		$qid_quoted = $self->sqlQuote($poll->{qid});
		$self->sqlUpdate("stories", {
			qid             => $poll->{qid}
		}, "sid = $sid_quoted") if $sid_quoted;
	}
	$self->setStory_delete_memcached_by_stoid([ $stoid ]) if $stoid;

	# Loop through 1..8 and insert/update if defined
	for (my $x = 1; $x < 9; $x++) {
		if ($poll->{"aid$x"}) {
			my $votes = $poll->{"votes$x"};
			$votes = 0 if $votes !~ /^-?\d+$/;
			$self->sqlReplace("pollanswers", {
				aid     => $x,
				qid     => $poll->{qid},
				answer  => $poll->{"aid$x"},
				votes   => $votes,
			});

		} else {
			$self->sqlDo("DELETE from pollanswers
				WHERE qid=$qid_quoted AND aid=$x");
		}
	}

	# Go on and unset any reference to the qid in sections, if it
	# needs to exist the next statement will correct this. -Brian
	$self->sqlUpdate('sections', { qid => '0' }, " qid = $poll->{qid} ")
		if $poll->{qid};

	if ($poll->{qid} && $poll->{polltype} eq "section" && $poll->{date} le $self->getTime()) {
		$self->setSection($poll->{section}, { qid => $poll->{qid} });
	}

	return $poll->{qid};
}

sub updatePollFromStory {
	my($self, $sid, $opts) = @_;
	my($data, $qid) = $self->getPollUpdateHashFromStory($sid, $opts);
	if ($qid){
		$self->sqlUpdate("pollquestions", $data, "qid=" . $self->sqlQuote($qid));
	}
}

#XXXSECTIONTOPICS section and tid still need to be handled
sub getPollUpdateHashFromStory {
	my($self, $id, $opts) = @_;
	my $stoid = $self->getStoidFromSidOrStoid($id);
	return undef unless $stoid;
	my $story_ref = $self->sqlSelectHashref(
		"sid,qid,time,primaryskid,tid",
		"stories",
		"stoid=$stoid");
	my $data;
	my $viewable = $self->checkStoryViewable($stoid, 0, { no_time_restrict => 1});
	if ($story_ref->{qid}) {
		$data->{date}           = $story_ref->{time} if $opts->{date};
		$data->{polltype}       = $viewable ? "story" : "nodisplay" if $opts->{polltype};
		$data->{topic}          = $story_ref->{tid} if $opts->{topic};
		$data->{primaryskid}    = $story_ref->{primaryskid} if $opts->{primaryskid};
	}
	# return the hash of fields and values to update for the poll
	# if asked for the array return the qid of the poll too
	return wantarray ? ($data, $story_ref->{qid}) : $data;
}

# A note, this does not remove the issue of a story
# still having a poll attached to it (orphan issue)
sub deletePoll {
	my($self, $qid) = @_;
	return if !$qid;

	my $qid_quoted = $self->sqlQuote($qid);
	my $did = $self->sqlSelect(
		'discussion',
		'pollquestions',
		"qid=$qid_quoted"
	);

	$self->deleteDiscussion($did) if $did;

	$self->sqlDo("DELETE FROM pollanswers   WHERE qid=$qid_quoted");
	$self->sqlDo("DELETE FROM pollquestions WHERE qid=$qid_quoted");
	$self->sqlDo("DELETE FROM pollvoters    WHERE qid=$qid_quoted");
}

sub getPollQuestionList {
	my($self, $offset, $other) = @_;
	my($where);

	my $justStories = ($other->{type} && $other->{type} eq 'story') ? 1 : 0;

	$offset = 0 if $offset !~ /^\d+$/;
	my $admin = getCurrentUser('is_admin');

	# $others->{section} takes precidence over $others->{exclude_section}. Both
	# keys are mutually exclusive and should not be used in the same call.
	delete $other->{exclude_section} if exists $other->{section};
	for (qw(section exclude_section)) {
		# Usage issue. Some folks may add an "s" to the key name.
		$other->{$_} ||= $other->{"${_}s"} if exists $other->{"${_}s"};
		if (exists $other->{$_} && $other->{$_}) {
			if (!ref $other->{$_}) {
				$other->{$_} = [$other->{$_}];
			} elsif (ref $other->{$_} eq 'HASH') {
				my @list = sort keys %{$other->{$_}};
				$other->{$_} = \@list;
			}
			# Quote the data.
			$_ = $self->sqlQuote($_) for @{$other->{$_}};
		}
	}

	$where .= "autopoll = 'no'";
	$where .= " AND pollquestions.discussion  = discussions.id ";
	$where .= sprintf ' AND pollquestions.primaryskid IN (%s)', join(',', @{$other->{section}})
		if $other->{section};
	$where .= sprintf ' AND pollquestions.primaryskid NOT IN (%s)', join(',', @{$other->{exclude_section}})
		if $other->{exclude_section} && @{$other->{section}};
	$where .= " AND pollquestions.topic = $other->{topic} " if $other->{topic};

	$where .= " AND date <= NOW() " unless $admin;
	my $limit = $other->{limit} || 20;

	my $cols = 'pollquestions.qid as qid, question, date, voters, discussions.commentcount as commentcount,
			polltype, date>now() as future,pollquestions.topic, pollquestions.primaryskid';
	$cols .= ", stories.title as title, stories.sid as sid" if $justStories;

	my $tables = 'pollquestions,discussions';
	$tables .= ',stories' if $justStories;

	$where .= ' AND pollquestions.qid = stories.qid' if $justStories;

	my $questions = $self->sqlSelectAll(
		$cols,
		$tables,
		$where,
		"ORDER BY date DESC LIMIT $offset, $limit"
	);

	return $questions;
}

sub getPollAnswers {
	my($self, $qid, $val) = @_;
	my $qid_quoted = $self->sqlQuote($qid);
	my $values = join ',', @$val;
	my $answers = $self->sqlSelectAll($values, 'pollanswers',
		"qid=$qid_quoted", 'ORDER BY aid');

	return $answers;
}

sub getPoll {
	my($self, $qid) = @_;
	my $qid_quoted = $self->sqlQuote($qid);
	# First select info about the question...
	my $pollq = $self->sqlSelectHashref(
		"*", "pollquestions",
		"qid=$qid_quoted");
	# Then select all the answers.
	my $answers_hr = $self->sqlSelectAllHashref(
		"aid",
		"aid, answer, votes",
		"pollanswers",
		"qid=$qid_quoted"
	);
	# Do the sort in perl, it's faster than asking the DB to do
	# an ORDER BY.
	# (I wrote that comment in 2002.  It's a little silly... hardly
	# matters for sorting < 10 items!  If I wrote this today I'd use
	# sqlSelectAllHashrefArray and ORDER BY aid. - Jamie)
	my @answers = ( );
	for my $aid (sort
		{ $answers_hr->{$a}{aid} <=> $answers_hr->{$b}{aid} }
		keys %$answers_hr) {
		push @answers, {
			answer =>       $answers_hr->{$aid}{answer},
			aid =>          $answers_hr->{$aid}{aid},
			votes =>        $answers_hr->{$aid}{votes},
		};
	}
	return {
		pollq =>        $pollq,
		answers =>      \@answers
	};
}

# This will screw with an autopoll -Brian
sub getSidForQid {
	my($self, $qid) = @_;
	return $self->sqlSelect("sid", "stories",
				"qid=" . $self->sqlQuote($qid),
				"ORDER BY time DESC");
}

sub getPollVotesMax {
	my($self, $qid) = @_;
	my $qid_quoted = $self->sqlQuote($qid);
	my($answer) = $self->sqlSelect("MAX(votes)", "pollanswers",
		"qid=$qid_quoted");
	return $answer;
}

sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if !$ENV{GATEWAY_INTERFACE} && $self->{_dbh};
}


1;

# This is not (yet?) used anywhere in the code. - Jamie 2006-08-27
#sub getTopPollTopics {
#	my($self, $limit) = @_;
#	my $all = 1 if !$limit;
#
#	$limit =~ s/\D+//g;
#	$limit = 10 if !$limit || $limit == 1;
#	my $sect_clause;
#	my $other  = $all ? '' : "LIMIT $limit";
#	my $topics = $self->sqlSelectAllHashrefArray(
#		"topics.tid AS tid, alttext, COUNT(*) AS cnt, default_image, MAX(date) AS tme",
#		'topics,pollquestions',
#		"polltype != 'nodisplay'
#		AND autopoll = 'no'
#		AND date <= NOW()
#		AND topics.tid=pollquestions.topic
#		GROUP BY topics.tid
#		ORDER BY tme DESC
#		$other"
#	);
#
#	# fix names
#	for (@$topics) {
#		$_->{count}  = delete $_->{cnt};
#		$_->{'time'} = delete $_->{tme};
#	}
#	return $topics;
#}

# Has this "user" already voted in a particular poll?  "User" here is
# specially taken to mean a conflation of IP address (possibly thru proxy)
# and uid, such that only one anonymous reader can post from any given
# IP address.
# XXX NO LONGER USED, REPLACED BY reskeys -- pudge 2005-10-20
#sub hasVotedIn {
#	my($self, $qid) = @_;
#	my $constants = getCurrentStatic();
#
#	my $pollvoter_md5 = getPollVoterHash();
#	my $qid_quoted = $self->sqlQuote($qid);
#	# Yes, qid/id/uid is a key in pollvoters.
#	my $uid = getCurrentUser('uid');
#	my($voters) = $self->sqlSelect('id', 'pollvoters',
#		"qid=$qid_quoted AND id='$pollvoter_md5' AND uid=$uid"
#	);
#
#	# Should be a max of one row returned.  In any case, if any
#	# data is returned, this "user" has already voted.
#	return $voters ? 1 : 0;
#}

__END__

# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Slash::PollBooth - PollBooth system splace

=head1 SYNOPSIS

	use Slash::PollBooth;

=head1 DESCRIPTION

This is a port of Tangent's journal system.

Blah blah blah.

=head1 AUTHOR

Brian Aker, brian@tangent.org

=head1 SEE ALSO

perl(1).

=cut

# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Hof;

use strict;
use Slash::Utility;
use Slash::DB::Utility;
use vars qw($VERSION);
use base 'Slash::DB::Utility';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# FRY: And where would a giant nerd be? THE LIBRARY!

#################################################################
sub new {
	my($class, $user) = @_;
	my $self = {};

	my $slashdb = getCurrentDB();
	my $plugins = $slashdb->getDescriptions('plugins');
	return unless $plugins->{'Hof'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect();

	return $self;
}

########################################################
sub countStories {
	my($self) = @_;
	my $stories = $self->sqlSelectAll(
		'stories.sid, stories.title, stories.section as section, stories.commentcount, nickname',
		'stories, users, discussions',
		'stories.uid=users.uid AND stories.discussion=discussions.id',
		'ORDER BY commentcount DESC LIMIT 10'
	);
	return $stories;
}

########################################################
sub countPollquestions {
	my($self) = @_;
	my $pollquestions = $self->sqlSelectAll("voters,question,qid", "pollquestions",
		"1=1", "ORDER by voters DESC LIMIT 10"
	);
	return $pollquestions;
}

########################################################
# Not used currently
sub countUsersIndexExboxesByBid {
	my($self, $bid) = @_;
	my($count) = $self->sqlSelect("count(*)", "users_index",
		qq!exboxes like "%'$bid'%" !
	);

	return $count;
}

########################################################
sub countStorySubmitters {
	my($self) = @_;

	# Sometimes getCurrentAnonymousCoward() is missing data when it is
	# called, so we drop in an appropriate default.
	my $ac_uid = getCurrentAnonymousCoward('uid') ||
		     getCurrentStatic('anonymous_coward_uid');
	my $uid = $self->sqlSelectColArrayref('uid', 'authors_cache');
	my $in_list = join(',', @{$uid}, $ac_uid);

	my $submitters = $self->sqlSelectAll(
		'count(*) as c, users.nickname',
		'stories, users', 
		"users.uid=stories.submitter AND submitter NOT IN ($in_list)",
		'GROUP BY users.uid ORDER BY c DESC LIMIT 10'
	);

	return $submitters;
}


########################################################
# Just used for Hof
sub countStoriesAuthors {
	my($self) = @_;
	my $authors = $self->sqlSelectAll('storycount, nickname, homepage',
		'authors_cache', '',
		'GROUP BY uid ORDER BY storycount DESC LIMIT 10'
	);
	return $authors;
}

########################################################
sub countStoriesTopHits {
	my($self) = @_;
	my $stories = $self->sqlSelectAll('sid,title,section,hits,users.nickname',
		'stories,users', 'stories.uid=users.uid',
		'ORDER BY hits DESC LIMIT 10'
	);
	return $stories;
}

##################################################################
# counts the number of stories
sub countStory {
	my($self, $tid) = @_;
	my($value) = $self->sqlSelect("count(*)",
		'stories',
		"tid=" . $self->sqlQuote($tid));

	return $value;
}

########################################################
# This is going to blow chunks -Brian
# To be precise it locks the DB every two hours when hof.pl is run
# by slashd.  I've commented out the 3-way join and STARTED coding
# up a replacement (it should select the comments first, then pull
# from story_heap and users without doing a join).  I don't have
# time to finish this right now so I've also commented out the code
# that calls this method, see themes/slashcode/htdocs/hof.pl.
# - Jamie 2001/07/12
sub getCommentsTop {
	my($self, $sid) = @_;
	my $user = getCurrentUser();

	my $where = 'stories.sid=comments.sid AND stories.uid=users.uid';
	$where .= ' AND stories.sid=' . $self->sqlQuote($sid) if $sid;
	my $stories = $self->sqlSelectAll(
		'section, stories.sid, users.nickname, title,
		pid, subject, date, time, comments.uid, cid, points',
		'stories, comments, users',
		$where,
		' ORDER BY points DESC, date DESC LIMIT 10 '
	);

	# First select the top scoring comments (which on Slashdot or
	# any big site will just be the latest score:5 comments).
	my $columns = "sid, pid, cid, uid, points, date, subject";
	my $tables = 'comments';
	$where = "1=1";
	my $other = "ORDER BY points DESC, date DESC LIMIT 10";
	my $top_comments = $self->sqlSelectAll($columns,$tables,$where,$other);
	formatDate($top_comments, 5);

	# Then we want to match the sids against story_heap.discussion
	# and then the uids against users.nickname.  But I have not
	# written that code yet because there are bigger bugs to kill.
	# Meanwhile...
	return $top_comments;

#	my $where = "comments.points >= 2 AND stories.discussion=comments.sid AND comments.uid=users.uid";
#	$where .= " AND stories.sid=" . $self->sqlQuote($sid) if $sid;
#	my $stories = $self->sqlSelectAll(
#		"section, stories.sid, users.nickname, title, pid,
#		subject, date, time, comments.uid, cid, points",
#		"stories, comments, users",
#		$where,
#		" ORDER BY points DESC, date DESC LIMIT 10"
#	);
#
#	formatDate($stories, 6);
#	formatDate($stories, 7);
#	return $stories;
}

#################################################################
sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if $self->{_dbh} && !$ENV{GATEWAY_INTERFACE};
}

1;

=head1 NAME

Slash::Hof - Slash Hof module

=head1 SYNOPSIS

	use Slash::Hof;

=head1 DESCRIPTION

This contains all of the routines currently used by Hof to generate it's stats. 

=head1 SEE ALSO

Slash(3).

=cut

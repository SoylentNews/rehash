# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Search;

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
	return unless $plugins->{'Search'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect();

	return $self;
}

#################################################################
# Private method used by the search methods
sub _keysearch {
	my($self, $keywords, $columns) = @_;

	my @words = split m/ /, $keywords;
	my $sql;
	my $x = 0;
	my $latch = 0;

	for my $word (@words) {
		next if length $word < 3;
		last if $x++ > 3;
		$sql .= " AND " if $sql;
		$sql .= " ( ";
		$latch = 0;
		for (@$columns) {
			$sql .= " OR " if $latch;
			$sql .= "$_ LIKE " . $self->sqlQuote("%$word%"). " ";
			$latch++;
		}
		$sql .= " ) ";
	}
	# void context, does nothing?
	$sql = "0" unless $sql;

	return qq|($sql)|;
};

####################################################################################
# This has been changed. Since we no longer delete comments
# it is safe to have this run against stories.
sub findComments {
	my($self, $form, $start, $limit, $sort) = @_;
	# select comment ID, comment Title, Author, Email, link to comment
	# and SID, article title, type and a link to the article
	my $query = $self->sqlQuote($form->{query});
	my $columns = "section, discussions.url, discussions.uid, discussions.title, pid, subject, ts, date, comments.uid as uid, comments.cid as cid ";
	$columns .= ", TRUNCATE((MATCH (comments.subject) AGAINST($query)), 1) as score "
		if ($form->{query} && $sort == 1);

	my $tables = "comments, discussions";

	my $key = " MATCH (comments.subject) AGAINST ($query) ";

	# Welcome to the join from hell -Brian
	my $where;
	$where .= " comments.sid = discussions.id ";
	$where .= "	  AND $key "
			if $form->{query};

	$where .= "     AND discussions.sid=" . $self->sqlQuote($form->{sid})
			if $form->{sid};
	$where .= "     AND points >= " .  $self->sqlQuote($form->{threshold})
			if $form->{threshold};
	$where .= "     AND section=" . $self->sqlQuote($form->{section})
			if $form->{section};

	my $other;
	if ($form->{query} && $sort == 1) {
		$other = " ORDER BY score DESC ";
	} else {
		$other = " ORDER BY cid DESC ";
	}


	my $sql = "SELECT $columns FROM $tables WHERE $where $other";
	$sql .= " LIMIT $start, $limit" if $limit;

	$self->sqlConnect();
	my $cursor = $self->{_dbh}->prepare($sql);
	$cursor->execute;

	my $search = $cursor->fetchall_arrayref;
	return $search;
}


####################################################################################
# This has been changed. Since we no longer delete comments
# it is safe to have this run against stories.
# Original with comment body
#sub findComments {
#	my($self, $form, $start, $limit) = @_;
#	# select comment ID, comment Title, Author, Email, link to comment
#	# and SID, article title, type and a link to the article
#	my $query = $self->sqlQuote($form->{query});
#	my $columns = "section, stories.sid, stories.uid as author, discussions.title as title, pid, subject, stories.writestatus as writestatus, time, date, comments.uid as uid, comments.cid as cid ";
#	$columns .= ", TRUNCATE((((MATCH (comments.subject) AGAINST($query) + (MATCH (comment_text.comment) AGAINST($query)))) / 2), 1) as score "
#		if $form->{query};
#
#	my $tables = "stories, comments, comment_text, discussions";
#
#	my $key = " (MATCH (comments.subject) AGAINST ($query) or MATCH (comment_text.comment) AGAINST ($query)) ";
#
#
#	$limit = " LIMIT $start, $limit" if $limit;
#
#	# Welcome to the join from hell -Brian
#	my $where;
#	$where .= " comments.cid = comment_text.cid ";
#	$where .= " AND comments.sid = discussions.id ";
#	$where .= " AND discussions.sid = stories.sid ";
#	$where .= "	  AND $key "
#			if $form->{query};
#
#	$where .= "     AND stories.sid=" . $self->sqlQuote($form->{sid})
#			if $form->{sid};
#	$where .= "     AND points >= $form->{threshold} "
#			if $form->{threshold};
#	$where .= "     AND section=" . $self->sqlQuote($form->{section})
#			if $form->{section};
#
#	my $other;
#	if ($form->{query}) {
#		$other = " ORDER BY score DESC, time DESC ";
#	} else {
#		$other = " ORDER BY date DESC, time DESC ";
#	}
#
#
#	my $sql = "SELECT $columns FROM $tables WHERE $where $other $limit";
#
#	my $cursor = $self->{_dbh}->prepare($sql);
#	$cursor->execute;
#
#	my $search = $cursor->fetchall_arrayref;
#	return $search;
#}

####################################################################################
sub findUsers {
	my($self, $form, $start, $limit, $sort, $users_to_ignore) = @_;
	# userSearch REALLY doesn't need to be ordered by keyword since you
	# only care if the substring is found.
	my $query = $self->sqlQuote($form->{query});
	$limit = " LIMIT $start, $limit" if $limit;

	my $columns = 'fakeemail,nickname,users.uid,journal_last_entry_date ';
	$columns .= ", TRUNCATE((MATCH (nickname) AGAINST($query)), 1) as score "
		if ($form->{query} && $sort == 1);

	my $key = " MATCH (nickname) AGAINST ($query) ";
	my $tables = 'users';
	my $where .= ' seclev > 0 ';
	$where .= " AND $key" if $form->{query};


	my $other;
	if ($form->{query} && $sort == 1) {
		$other = " ORDER BY score "
	} else {
		$other = " ORDER BY users.uid "
	}

	my $sql = "SELECT $columns FROM $tables WHERE $where $other $limit";

	$self->sqlConnect();
	my $sth = $self->{_dbh}->prepare($sql);
	$sth->execute;

	my $users = $sth->fetchall_arrayref;

	return $users;
}

####################################################################################
sub findStory {
	my($self, $form, $start, $limit, $sort) = @_;
	$start ||= 0;

	my $query = $self->sqlQuote($form->{query});
	my $columns = "users.nickname, stories.title, stories.sid as sid, time, commentcount, section";
	$columns .= ", TRUNCATE((((MATCH (stories.title) AGAINST($query) + (MATCH (introtext,bodytext) AGAINST($query)))) / 2), 1) as score "
		if ($form->{query} && $sort == 1);

	my $tables = "stories,users";
	$tables .= ",story_text" if $form->{query};

	my $other;
	if ($form->{query} && $sort == 1) {
		$other = " ORDER BY score DESC";
	} else {
		$other = " ORDER BY time DESC";
	}
	$other .= " LIMIT $start, $limit" if $limit;

	# The big old searching WHERE clause, fear it
	my $key = " (MATCH (stories.title) AGAINST ($query) or MATCH (introtext,bodytext) AGAINST ($query)) ";
	my $where = "stories.uid = users.uid ";
	$where .= " AND stories.sid = story_text.sid AND $key" 
		if $form->{query};

	if ($form->{section}) { 
		my $section = $self->sqlQuote($form->{section});
		$where .= " AND ((displaystatus = 0 and $section = '')";
		$where .= " OR (section = $section AND displaystatus != -1))";
	} else {
		$where .= " AND displaystatus != -1";
	}
	$where .= " AND time < now() AND stories.writestatus != 'delete' ";
	$where .= " AND stories.uid=" . $self->sqlQuote($form->{author})
		if $form->{author};
	$where .= " AND section=" . $self->sqlQuote($form->{section})
		if $form->{section};
	$where .= " AND tid=" . $self->sqlQuote($form->{topic})
		if $form->{topic};
	
	my $sql = "SELECT $columns FROM $tables WHERE $where $other";

	$self->sqlConnect();
	my $cursor = $self->{_dbh}->prepare($sql);
	$cursor->execute;
	my $stories = $cursor->fetchall_arrayref;

	return $stories;
}

################################################################################
sub findRetrieveSite {
	my($self, $query, $start, $limit, $sort) = @_;
	$query = $self->sqlQuote($query);
	$limit = " LIMIT $start, $limit" if $limit;

	# Welcome to the join from hell -Brian
	my $sql = " SELECT bid,title, MATCH (description,title,block) AGAINST($query) as score  FROM blocks WHERE rdf IS NOT NULL AND url IS NOT NULL and retrieve=1 AND MATCH (description,title,block) AGAINST ($query) $limit";


	$self->sqlConnect();
	my $cursor = $self->{_dbh}->prepare($sql);
	$cursor->execute;

	my $search = $cursor->fetchall_arrayref;
	return $search;
}

####################################################################################
sub findJournalEntry {
	my($self, $form, $start, $limit, $sort) = @_;
	$start ||= 0;

	my $query = $self->sqlQuote($form->{query});
	my $columns = "users.nickname, journals.description, journals.id as id, date";
	$columns .= ", TRUNCATE((((MATCH (description) AGAINST($query) + (MATCH (article) AGAINST($query)))) / 2), 1) as score "
		if ($form->{query} && $sort == 1);
	my $tables = "journals, journals_text, users";
	my $other;
	if ($form->{query} && $sort == 1) {
		$other = " ORDER BY score DESC";
	} else {
		$other = " ORDER BY date DESC";
	}
	$other .= " LIMIT $start, $limit" if $limit;

	# The big old searching WHERE clause, fear it
	my $key = " (MATCH (description) AGAINST ($query) or MATCH (article) AGAINST ($query)) ";
	my $where = "journals.id = journals_text.id AND journals.uid = users.uid ";
	$where .= " AND $key" if $form->{query};
	$where .= " AND time < now() AND writestatus != 'delete' ";
	$where .= " AND users.nickname=" . $self->sqlQuote($form->{nickname})
		if $form->{nickname};
	$where .= " AND users.uid=" . $self->sqlQuote($form->{uid})
		if $form->{uid};
	$where .= " AND tid=" . $self->sqlQuote($form->{topic})
		if $form->{topic};
	
	my $sql = "SELECT $columns FROM $tables WHERE $where $other";

	$self->sqlConnect();
	my $cursor = $self->{_dbh}->prepare($sql);
	$cursor->execute;
	my $stories = $cursor->fetchall_arrayref;

	return $stories;
}

####################################################################################
sub findPollQuestion {
	my($self, $form, $start, $limit, $sort) = @_;
	$start ||= 0;

	my $query = $self->sqlQuote($form->{query});
	my $columns = "qid, question, voters, date";
	$columns .= ", TRUNCATE((MATCH (question) AGAINST($query)), 1) as score "
		if ($form->{query} && $sort == 1);
	my $tables = "pollquestions";
	my $other;
	if ($form->{query} && $sort == 1) {
		$other = " ORDER BY score DESC";
	} else {
		$other = " ORDER BY date DESC";
	}
	$other .= " LIMIT $start, $limit" if $limit;

	# The big old searching WHERE clause, fear it
	my $key = " MATCH (question) AGAINST ($query) ";
	my $where = " 1 = 1 ";
	$where .= " AND $key" if $form->{query};
	$where .= " AND date < now() ";
	$where .= " AND uid=" . $self->sqlQuote($form->{uid})
		if $form->{uid};
	$where .= " AND topic=" . $self->sqlQuote($form->{topic})
		if $form->{topic};
	
	my $sql = "SELECT $columns FROM $tables WHERE $where $other";

	$self->sqlConnect();
	my $cursor = $self->{_dbh}->prepare($sql);
	$cursor->execute;
	my $stories = $cursor->fetchall_arrayref;

	return $stories;
}

#################################################################
sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect unless $ENV{GATEWAY_INTERFACE};
}

1;
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Slash::Search - Slash Search module

=head1 SYNOPSIS

	use Slash::Search;

=head1 DESCRIPTION

Slash search module.

Blah blah blah.

=head1 SEE ALSO

Slash(3).

=cut

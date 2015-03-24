# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Search;

use strict;
use Sphinx::Search;
use Slash::Utility;

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

sub initializeSphinxSearch {
	my $constants = getCurrentStatic();
	my $sph = Sphinx::Search->new();
	$sph->SetServer($constants->{search_sphinx_host}, $constants->{search_sphinx_port});

	return $sph;
}

sub findComments {
	my($self, $form, $start, $limit, $sort) = @_;

	# First, let's talk to Sphinx and get our search results
	my $query = $form->{query};
	my $sph = initializeSphinxSearch();
	$sph->SetLimits($start, $limit);
	my $results = $sph->Query($query, "rehash_comment_index");

	if ($form->{sid}) { 
		my @sid = split (',', $form->{sid});
		$sph->SetFilter("sid", \@sid);
	}

	if ($form->{threshold}) {
		my @thresholds = split (',', $form->{threshold});
		$sph->SetFilter("score", \@thresholds);
	}

	# Sphinx will return an array of matches with the cid; 
	# we need to retrieve the comments for those matches

	# Based off of: http://blogs.perl.org/users/michal_wojciechowski/2012/12/building-a-search-web-app-with-dancer-and-sphinx.html
	if ($results->{'total_found'}) {
		my @document_ids = map { $_->{'doc'} } @{$results->{'matches'}};
		my $ids_joined = join ',', @document_ids;

		# Now query the database
		my $constants = getCurrentStatic();
		my $columns = "primaryskid, url, discussions.uid AS author_uid, discussions.title AS title, ";
		$columns .= "pid, subject, ts, date, comments.uid AS uid, cid, ";
		$columns .= "discussions.id AS did";

		my $tables = "comments, discussions";
		my $where = " cid IN ($ids_joined) AND comments.sid = discussions.id ";

		my $search = $self->sqlSelectAllHashrefArray($columns, $tables, $where);
		return $search;
	} else {
		return 0;
	}	
}

sub findUsers {
	my($self, $form, $start, $limit, $sort, $with_journal) = @_;
	# First, let's talk to Sphinx and get our search results
	my $query = $form->{query};
	my $sph = initializeSphinxSearch();
	$sph->SetLimits($start, $limit);
	my $results = $sph->Query($query, "rehash_users_index");

	if ($results->{'total_found'}) {
		my @document_ids = map { $_->{'doc'} } @{$results->{'matches'}};
		my $ids_joined = join ',', @document_ids;

		# Now query the database
		my $constants = getCurrentStatic();

		my $columns = 'fakeemail,nickname,users.uid as uid,journal_last_entry_date ';

		my $tables = 'users';
		my $where = " uid IN ($ids_joined) AND seclev > 0 ";
		$where .= " AND journal_last_entry_date IS NOT NULL" 
				if $with_journal;

		my $other;
		if ($form->{query} && $sort == 2) {
			$other .= " ORDER BY FIELD(uid, $ids_joined)";
		} else {
			$other .= " ORDER BY users.uid ";
		}

		my $users = $self->sqlSelectAllHashrefArray($columns, $tables, $where, $other );

		return $users;
	} else {
		return 0;
	}
}

####################################################################################
sub findStory {
	my($self, $form, $start, $limit, $sort) = @_;
	$start ||= 0;

	# First, let's talk to Sphinx and get our search results
	my $query = $form->{query};
	my $sph = initializeSphinxSearch();
	$sph->SetLimits($start, $limit);

	# filter our results if need be
	if ($form->{author}) { 
		my @authors = split (',', $form->{author});
		$sph->SetFilter("uid", \@authors);
	}

	if ($form->{submitter}) { 
		my @submitter = split (',', $form->{submitter});
		$sph->SetFilter("submitter", \@submitter);
	}

	if ($form->{section}) {
		my @sections = split (',', $form->{section});
		$sph->SetFilter("primaryskid", \@sections);
	}

	if ($form->{tid}) {
		my @tids;
		if (ref($form->{_multi}{tid}) eq 'ARRAY') {
			push @tids, @{$form->{_multi}{tid}};
		} else {
			@tids = split(',', $form->{tid});
		}

		$sph->SetFilter("tid", \@tids);
	}
	

	# Low priority FIXME: search_ignore_skids not implemented


	#if  ($sort == 2) {
	#	$sph->SetSortMode(SPH_SORT_TIME_SEGMENTS, "time");
	#} else {
	#	$sph->SetSortMode(SPH_SORT_RELEVANCE);
	#}

	my $results = $sph->Query($query, "rehash_stories_index");

	if ($results->{'total_found'}) {
		my @document_ids = map { $_->{'doc'} } @{$results->{'matches'}};
		my $ids_joined = join ',', @document_ids;

		my $constants = getCurrentStatic();

		my $columns;
		$columns .= "title, stories.stoid AS stoid, sid, "; 
		$columns .= "time, commentcount, stories.primaryskid AS skid, ";
		$columns .= "introtext ";

		my $tables = "story_text, stories LEFT JOIN story_param ON stories.stoid=story_param.stoid AND story_param.name='neverdisplay'";

		# The big old searching WHERE clause, fear it
		my $where = "stories.stoid = story_text.stoid";
		$where .= " AND stories.stoid IN ($ids_joined) ";
		my $other;
		my $gSkin = getCurrentSkin();
		my $reader = getObject('Slash::DB', { db_type => 'reader' });
	
		my $stories = $self->sqlSelectAllHashrefArray($columns, $tables, $where);

		# Don't return just one topic id in tid, also return an arrayref
		# in tids, with all topic ids in the preferred order.
		for my $story (@$stories) {
			$story->{tids} = $reader->getTopiclistForStory($story->{stoid});
		}

		return $stories;
	} else {
		return 0;
	}
}

####################################################################################
sub findJournalEntry {
	my($self, $form, $start, $limit, $sort) = @_;

	# First, let's talk to Sphinx and get our search results
	my $query = $form->{query};
	my $sph = initializeSphinxSearch();
	$sph->SetLimits($start, $limit);

	# FIXME: figure out how to do Sphinx string matching
	if ($form->{nickname}) {
		$form->{uid} = $self->getUserUID($self->sqlQuote($form->{nickname}));
	}

	if ($form->{uid}) { 
		my @uids = split (',', $form->{uid});
		$sph->SetFilter("uid", \@uids);
	}

	if ($form->{tid}) { 
		my @tids = split (',', $form->{tid});
		$sph->SetFilter("tid", \@tids);
	}

	my $results = $sph->Query($query, "rehash_journal_index");

	if ($results->{'total_found'}) {
		my @document_ids = map { $_->{'doc'} } @{$results->{'matches'}};
		my $ids_joined = join ',', @document_ids;

		my $constants = getCurrentStatic();

		my $columns;
		$columns .= "users.nickname as nickname, journals.description as description, ";
		$columns .= "journals.id as id, date, users.uid as uid, article, posttype, tid";
		my $tables = "journals, journals_text, users";

		# The big old searching WHERE clause, fear it
		my $where = "journals.id IN ($ids_joined)";
		$where .= " AND journals.id = journals_text.id AND journals.uid = users.uid ";
	
		my $stories = $self->sqlSelectAllHashrefArray($columns, $tables, $where);

		return $stories;
	} else {
		return 0;
	}
}

####################################################################################
sub findPollQuestion {
	my($self, $form, $start, $limit, $sort) = @_;
	$start ||= 0;
	my $constants = getCurrentStatic();

	my $query = $form->{query};
	my $sph = initializeSphinxSearch();
	$sph->SetLimits($start, $limit);
	my $results = $sph->Query($query, "rehash_poll_questions_index");

	if ($results->{'total_found'}) {
		my @document_ids = map { $_->{'doc'} } @{$results->{'matches'}};
		my $ids_joined = join ',', @document_ids;

		my $query = $self->sqlQuote($form->{query});
		my $columns = "*";
		my $tables = "pollquestions";
		my $other;
		if ($sort == 2) {
			$other .= " ORDER BY date DESC";
		}

		# The big old searching WHERE clause, fear it
		my $where = "qid IN ($ids_joined) AND autopoll = 'no' ";
		$where .= " AND date < now() ";
		$where .= " AND uid=" . $self->sqlQuote($form->{uid})
			if $form->{uid};
		$where .= " AND topic=" . $self->sqlQuote($form->{tid})
			if $form->{tid};

		my $reader = getObject('Slash::DB', { db_type => 'reader' });
		my $skid   = $reader->getSkidFromName($form->{section});
		$where .= " AND pollquestions.primaryskid = " . $skid if $skid;
	
		my $sql = "SELECT $columns FROM $tables WHERE $where $other";

		$other .= " LIMIT $start, $limit" if $limit;
		my $stories = $self->sqlSelectAllHashrefArray($columns, $tables, $where, $other);

		return $stories;
	} else {
		return 0;
	}
}

####################################################################################
sub findSubmission {
	my($self, $form, $start, $limit, $sort) = @_;
	my($self, $form, $start, $limit, $sort) = @_;
	$start ||= 0;
	my $constants = getCurrentStatic();

	my $query = $form->{query};
	my $sph = initializeSphinxSearch();
	$sph->SetLimits($start, $limit);
	my $results = $sph->Query($query, "rehash_submissions_index");

	if ($results->{'total_found'}) {
		my @document_ids = map { $_->{'doc'} } @{$results->{'matches'}};
		my $ids_joined = join ',', @document_ids;


		$form->{query} = $form->{query};
		my $query = $self->sqlQuote($form->{query});
		my $columns = "*";
		my $tables = "submissions";
		my $other;
		if ($sort == 2) {
			$other .= " ORDER BY subid DESC";
		}

		# The big old searching WHERE clause, fear it
		my $where = " subid IN ($ids_joined) ";
		$where .= " AND uid=" . $self->sqlQuote($form->{uid})
			if $form->{uid};
# XXXSKIN - needs to be replaced with select on submission_topics_rendered
# not sure why need to have multiple topics for submissions though ...
# regardless, tid must end up as an arrayref now, in $stories
#	$where .= " AND tid=" . $self->sqlQuote($form->{tid})
#		if $form->{tid};
		$where .= " AND note=" . $self->sqlQuote($form->{note})
			if $form->{note};

		my $reader = getObject('Slash::DB', { db_type => 'reader' });
		my $skid = $reader->getSkidFromName($form->{section});
		$where .= " AND primaryskid=$skid" if $skid;

		my $stories = $self->sqlSelectAllHashrefArray($columns, $tables, $where, $other );

		return $stories;
	} else {
		return 0;
	}
}

# MC: Removed findRSS/findDiscussion functions, they were only exported via
# SOAP, and I'm not sure they are useful. While rewriting them would
# be easy, I don't feel like spending the time fixing code we're not using.
# This comment exists so a grep for them can find them at a later date should
# we need to restore them from git history

#################################################################
sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if $self->{_dbh} && !$ENV{MOD_PERL};
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

# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
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
sub SelectDataBases {
	my $search_db_user = getCurrentStatic('search_db_user');
	my($slashdb, $searchDB);
	if ($search_db_user) {
		$slashdb  = getObject('Slash::DB', $search_db_user);
		$searchDB = getObject('Slash::Search', $search_db_user);
	} else {
		$slashdb  = getCurrentDB();
		$searchDB = Slash::Search->new(getCurrentVirtualUser());
	}

	return($slashdb, $searchDB);
}

#################################################################
sub new {
	my($class, $user) = @_;
	my $self = {};

	my $plugin = getCurrentStatic('plugin');
	return unless $plugin->{'Search'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect();

	return $self;
}

####################################################################################
# This has been changed. Since we no longer delete comments
# it is safe to have this run against stories.
sub findComments {
	my($self, $form, $start, $limit, $sort) = @_;
	# select comment ID, comment Title, Author, Email, link to comment
	# and SID, article title, type and a link to the article
	$form->{query} = $self->_cleanQuery($form->{query});
	my $query = $self->sqlQuote($form->{query});
	my $constants = getCurrentStatic();
	my $columns;
	# XXXSKIN - discussions.section needs to be fixed somehow to new system
	$columns .= "discussions.section as section, discussions.url as url, discussions.uid as author_uid,";
	$columns .= "discussions.title as title, pid, subject, ts, date, comments.uid as uid, ";
	$columns .= "comments.cid as cid, discussions.id as did ";
	$columns .= ", TRUNCATE( " . $self->_score('comments.subject', $form->{query}, $constants->{search_method}) . ", 1) as score "
		if $form->{query};

	my $tables = "comments, discussions";

	my $key = " MATCH (comments.subject) AGAINST ($query) ";

	# Welcome to the join from hell -Brian
	my $where;
	$where .= " comments.sid = discussions.id ";
	$where .= "	  AND $key "
			if $form->{query};

	if ($form->{sid}) {
		if ($form->{sid} !~ /^\d+$/) {
			$where .= "     AND discussions.sid=" . $self->sqlQuote($form->{sid})
		} else {
			$where .= "     AND discussions.id=" . $self->sqlQuote($form->{sid})
		}
	}
	if (defined $form->{threshold}){
		my $threshold   = $form->{threshold};
		my $threshold_q = $self->sqlQuote($threshold);
		$where .= " AND GREATEST((points + tweak), $constants->{comment_minscore}) >= $threshold_q ";
		
	}

	my $gSkin = getCurrentSkin();
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $skin = $reader->getSkin($form->{section} || $gSkin->{skid});
	if ($skin->{skid} != $constants->{mainpage_skid}) {
		$where .= " AND discussions.primaryskid = $skin->{skid}";
	}

	my $other;
	$other .= " HAVING score > 0 "
		if $form->{query};
	if ($form->{query} && $sort == 2) {
		$other .= " ORDER BY score DESC ";
	} else {
		$other .= " ORDER BY cid DESC ";
	}


	$other .= " LIMIT $start, $limit" if $limit;
	my $search = $self->sqlSelectAllHashrefArray($columns, $tables, $where, $other );

	return $search;
}

####################################################################################
# I am beginning to hate all the options.
sub findUsers {
	my($self, $form, $start, $limit, $sort, $with_journal) = @_;
	# userSearch REALLY doesn't need to be ordered by keyword since you
	# only care if the substring is found.
	$form->{query} = $self->_cleanQuery($form->{query});
	my $query = $self->sqlQuote($form->{query});
	my $constants = getCurrentStatic();

	my $columns = 'fakeemail,nickname,users.uid as uid,journal_last_entry_date ';
	$columns .= ", TRUNCATE( " . $self->_score('nickname', $form->{query}, $constants->{search_method}) . ", 1) as score "
		if $form->{query};

	my $key = " MATCH (nickname) AGAINST ($query) ";
	my $tables = 'users';
	my $where .= ' seclev > 0 ';
	$where .= " AND $key" 
			if $form->{query};
	$where .= " AND journal_last_entry_date IS NOT NULL" 
			if $with_journal;


	my $other;
	$other .= " HAVING score > 0 "
		if $form->{query};
	if ($form->{query} && $sort == 2) {
		$other .= " ORDER BY score "
	} else {
		$other .= " ORDER BY users.uid "
	}

	$other .= " LIMIT $start, $limit" if $limit;
	my $users = $self->sqlSelectAllHashrefArray($columns, $tables, $where, $other );

	return $users;
}

####################################################################################
sub findStory {
	my($self, $form, $start, $limit, $sort) = @_;
	$start ||= 0;

	my $constants = getCurrentStatic();

	$form->{query} = $self->_cleanQuery($form->{query});
	my $query = $self->sqlQuote($form->{query});
	my $columns;
	$columns .= "title, stories.stoid as stoid, "; 
	$columns .= "time, commentcount, stories.primaryskid as skid,";
	$columns .= "introtext ";
	$columns .= ", TRUNCATE((( " . $self->_score('title', $form->{query}, $constants->{search_method}) . "  + " .  $self->_score('introtext,bodytext', $form->{query}, $constants->{search_method}) .") / 2), 1) as score "
		if $form->{query};

	my $tables = "stories,story_text";

	my $other;
	$other .= " HAVING score > 0 "
		if $form->{query};
	if ($form->{query} && $sort == 2) {
		$other .= " ORDER BY score DESC";
	} else {
		$other .= " ORDER BY time DESC";
	}

	# The big old searching WHERE clause, fear it
	# XXX This can be a single MATCH now if we do a FULLTEXT
	# index on all three columns. - Jamie 2004/04/06
	my $where = "stories.stoid = story_text.stoid ";
	$where .= " AND ( MATCH (title) AGAINST ($query)
		OR MATCH (introtext,bodytext) AGAINST ($query) ) "
		if $form->{query};

	$where .= " AND time < NOW() AND stories.in_trash = 'no' ";
	$where .= " AND stories.uid=" . $self->sqlQuote($form->{author})
		if $form->{author};
	$where .= " AND stories.submitter=" . $self->sqlQuote($form->{submitter})
		if $form->{submitter};
	$where .= " AND displaystatus != -1";

	my $gSkin = getCurrentSkin();
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $skin = $reader->getSkin($form->{section} || $gSkin->{skid});
	if ($skin->{skid} != $constants->{mainpage_skid}) {
		# XXXSKIN this is wrong, we want to join on story_topics_rendered
		$where .= " AND stories.primaryskid = $skin->{skid}";
	}

	# Here we find the possible sids that could have this tid and
	# then search only those.
	# ...but there are two ways to do this.  The proper way is to
	# do a "LEFT JOIN story_topics ON stories.sid=story_topics.sid" and
	# put a "story_topics.id IS NOT NULL" into the WHERE clause.  But
	# my guess is that on the searches by the larger topics, this will
	# be too slow.  The other way (which we have done so far) is to do
	# one select to pull out *all* sids with the topic(s) in question,
	# and then not join on story_topics, just use a "sid IN" clause.
	# The problem is that, for large topics, this may be very many sids;
	# on OSDN sites, we're seeing some topics with 4,000 to 13,000
	# stories in them.  That makes the SELECT too large to be efficient.
	# So I'm fixing this in a not very good way:  limiting the number
	# of stories we search, on any search that includes a topic
	# limitation.  This sucks and should be replaced with a real
	# solution ASAP -- this is only a stopgap! - Jamie 2003/11/10
	#
	# Changed sorting of story sids by time instead of sid.  This prevents
	# only dated stories from showing up when there were > 1000 
	# sids that were created prior to 2000 
	#
	# Added support for more correct left join method.  Also added vars
	# so you can choose to lose left join method or change the limit on
	# sids returned in the two select method
	#
	# Tweak to your site size and performance needs
	#
	#-- Vroom 2003/12/08

	if ($form->{tid}) {
		my @tids;
		if (ref($form->{_multi}{tid}) eq 'ARRAY') {
			push @tids, @{$form->{_multi}{tid}};
		} else {
			push @tids, $form->{tid};
		}
		my $string = join(',', @{$self->sqlQuote(\@tids)});
		if ($constants->{topic_search_use_join}) {
			$tables.= " LEFT JOIN story_topics_rendered ON stories.stoid = story_topics_rendered.stoid ";
# XXXSKIN - no more id in schema, just yank?
#			$where .= " AND story_topics_rendered.id IS NOT NULL";
			$where .= " AND story_topics_rendered.tid IN ($string)";
			$other = "GROUP by stoid $other";
		} else {
			my $topic_search_sid_limit = $constants->{topic_search_sid_limit} || 1000;
			my $sids = $self->sqlSelectColArrayref(
				'story_topics_rendered.stoid',
				'story_topics_rendered, stories', 
				"story_topics_rendered.stoid = stories.stoid AND story_topics_rendered.tid IN ($string)",
				"ORDER BY time DESC LIMIT $topic_search_sid_limit");
			if ($sids && @$sids) {
				$string = join(',', @{$self->sqlQuote($sids)});
				$where .= " AND stories.stoid IN ($string) ";
			} else {
				return; # No results could possibly match
			}
		}
	}
	
	$other .= " LIMIT $start, $limit" if $limit;
	my $stories = $self->sqlSelectAllHashrefArray($columns, $tables, $where, $other);
	# fetch all the topics
	for my $story (@$stories) {
		$story->{tid} = $self->sqlSelectColArrayref(
			'tid', 'story_topics_rendered',
			'sid=' . $self->sqlQuote($story->{stoid})
		);
	}

	return $stories;
}

################################################################################
# Dead code at the moment -Brian
sub findRetrieveSite {
#	my($self, $query, $start, $limit, $sort) = @_;
#	$query = $self->sqlQuote($query);
#	$limit = " LIMIT $start, $limit" if $limit;
#
#	# Welcome to the join from hell -Brian
#	my $sql = " SELECT bid,title, MATCH (description,title,block) AGAINST($query) as score  FROM blocks WHERE rdf IS NOT NULL AND url IS NOT NULL and retrieve=1 AND MATCH (description,title,block) AGAINST ($query) $limit";
#
#
#	$self->sqlConnect();
#	my $cursor = $self->{_dbh}->prepare($sql);
#	$cursor->execute;
#
#	my $search = $cursor->fetchall_arrayref;
#	return $search;
}

####################################################################################
sub findJournalEntry {
	my($self, $form, $start, $limit, $sort) = @_;
	$start ||= 0;
	my $constants = getCurrentStatic();

	$form->{query} = $self->_cleanQuery($form->{query});
	my $query = $self->sqlQuote($form->{query});
	my $columns;
	$columns .= "users.nickname as nickname, journals.description as description, ";
	$columns .= "journals.id as id, date, users.uid as uid, article";
	$columns .= ", TRUNCATE((( " . $self->_score('description', $form->{query}, $constants->{search_method}) . " + " .  $self->_score('article', $form->{query}, $constants->{search_method}) .") / 2), 1) as score "
		if $form->{query};
	my $tables = "journals, journals_text, users";
	my $other;
	$other .= " HAVING score > 0 "
		if ($form->{query});
	if ($form->{query} && $sort == 2) {
		$other .= " ORDER BY score DESC";
	} else {
		$other .= " ORDER BY date DESC";
	}

	# The big old searching WHERE clause, fear it
	my $key = " (MATCH (description) AGAINST ($query) or MATCH (article) AGAINST ($query)) ";
	my $where = "journals.id = journals_text.id AND journals.uid = users.uid ";
	$where .= " AND $key" if $form->{query};
	$where .= " AND users.nickname=" . $self->sqlQuote($form->{nickname})
		if $form->{nickname};
	$where .= " AND users.uid=" . $self->sqlQuote($form->{uid})
		if $form->{uid};
	$where .= " AND tid=" . $self->sqlQuote($form->{tid})
		if $form->{tid};
	
	$other .= " LIMIT $start, $limit" if $limit;
	my $stories = $self->sqlSelectAllHashrefArray($columns, $tables, $where, $other );

	return $stories;
}

####################################################################################
sub findPollQuestion {
	my($self, $form, $start, $limit, $sort) = @_;
	$start ||= 0;
	my $constants = getCurrentStatic();

	$form->{query} = $self->_cleanQuery($form->{query});
	my $query = $self->sqlQuote($form->{query});
	my $columns = "*";
	$columns .= ", TRUNCATE( " . $self->_score('question', $form->{query}, $constants->{search_method}) . ", 1) as score "
		if $form->{query};
	my $tables = "pollquestions";
	my $other;
	$other .= " HAVING score > 0 "
		if ($form->{query});
	if ($form->{query} && $sort == 2) {
		$other .= " ORDER BY score DESC";
	} else {
		$other .= " ORDER BY date DESC";
	}

	# The big old searching WHERE clause, fear it
	my $key = " MATCH (question) AGAINST ($query) ";
	my $where = " 1 = 1 AND autopoll = 'no' ";
	$where .= " AND $key" if $form->{query};
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
}

####################################################################################
sub findSubmission {
	my($self, $form, $start, $limit, $sort) = @_;
	$start ||= 0;
	my $constants = getCurrentStatic();
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	$form->{query} = $self->_cleanQuery($form->{query});
	my $query = $self->sqlQuote($form->{query});
	my $columns = "*";
	$columns .= ", TRUNCATE( " . $self->_score('subj,story', $form->{query}, $constants->{search_method}) . ", 1) as score "
		if $form->{query};
	my $tables = "submissions";
	my $other;
	$other .= " HAVING score > 0 "
		if ($form->{query});
	if ($form->{query} && $sort == 2) {
		$other .= " ORDER BY score DESC";
	} else {
		$other .= " ORDER BY subid DESC";
	}
	# The big old searching WHERE clause, fear it
	my $key = " MATCH (subj,story) AGAINST ($query) ";
	my $where = " 1 = 1 ";
	$where .= " AND $key" if $form->{query};
	$where .= " AND uid=" . $self->sqlQuote($form->{uid})
		if $form->{uid};
# XXXSKIN - needs to be replaced with select on submission_topics_rendered
# not sure why need to have multiple topics for submissions though ...
# regardless, tid must end up as an arrayref now, in $stories
#	$where .= " AND tid=" . $self->sqlQuote($form->{tid})
#		if $form->{tid};
	$where .= " AND note=" . $self->sqlQuote($form->{note})
		if $form->{note};

	my $skid = $reader->getSkidFromName($form->{section});
	$where .= " AND primaryskid=$skid" if $skid;

	$other .= " LIMIT $start, $limit" if $limit;
	my $stories = $self->sqlSelectAllHashrefArray($columns, $tables, $where, $other );

	return $stories;
}

####################################################################################
sub findRSS {
	my($self, $form, $start, $limit, $sort) = @_;
	$start ||= 0;
	my $constants = getCurrentStatic();

	$form->{query} = $self->_cleanQuery($form->{query});
	my $query = $self->sqlQuote($form->{query});
	my $columns = "title, link, description, created";
	$columns .= ", TRUNCATE( " . $self->_score('title,description', $form->{query}, $constants->{search_method}) . ", 1) as score "
		if $form->{query};
	my $tables = "rss_raw";
	my $other;
	$other .= " HAVING score > 0 "
		if ($form->{query});
	if ($form->{query} && $sort == 2) {
		$other .= " ORDER BY score DESC";
	} else {
		$other .= " ORDER BY created DESC";
	}

	# The big old searching WHERE clause, fear it
	my $key = " MATCH (title,description) AGAINST ($query) ";
	my $where = " 1 = 1 ";
	$where .= " AND $key" if $form->{query};
	$where .= " AND bid=" . $self->sqlQuote($form->{bid})
		if $form->{bid};
	
	$other .= " LIMIT $start, $limit" if $limit;
	my $stories = $self->sqlSelectAllHashrefArray($columns, $tables, $where, $other );

	return $stories;
}

####################################################################################
sub findDiscussion {
	my($self, $form, $start, $limit, $sort) = @_;
	$form->{query} = $self->_cleanQuery($form->{query});
	my $query = $self->sqlQuote($form->{query});
	my $constants = getCurrentStatic();
	$start ||= 0;

	my $columns = "*";
	$columns .= ", TRUNCATE( " . $self->_score('title', $form->{query}, $constants->{search_method}) . ", 1) as score "
		if $form->{query};
	my $tables = "discussions";
	my $other;
	$other .= " HAVING score > 0 "
		if ($form->{query});

	if ($form->{query} && $sort == 2) {
		$other .= " ORDER BY score DESC";
	} elsif ($sort == 3) {
		$other .= " ORDER BY last_update DESC";
	} else {
		$other .= " ORDER BY ts DESC";
	}

	# The big old searching WHERE clause, fear it
	my $key = " MATCH (title) AGAINST ($query) ";
	my $where = " ts <= now() ";
	$where .= " AND $key" 
		if $form->{query};
	$where .= " AND type=" . $self->sqlQuote($form->{type})
		if $form->{type};
	$where .= " AND topic=" . $self->sqlQuote($form->{tid})
		if $form->{tid};

	my $gSkin = getCurrentSkin();
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $skin = $reader->getSkin($form->{section} || $gSkin->{skid});
	if ($skin->{skid} != $constants->{mainpage_skid}) {
		$where .= " AND discussions.primaryskid = $skin->{skid}";
	}

	$where .= " AND uid=" . $self->sqlQuote($form->{uid})
		if $form->{uid};
	$where .= " AND approved = " . $self->sqlQuote($form->{approved})
		if defined($form->{approved})
			&& $constants->{discussion_approval};
	
	$other .= " LIMIT $start, $limit" if $limit;
#	print STDERR "select $columns from $tables where $where $other\n";
	my $stories = $self->sqlSelectAllHashrefArray($columns, $tables, $where, $other );

	return $stories;
}

sub _score {
	my ($self, $col, $query, $method) = @_;
	my $constants = getCurrentStatic();
	
	if ($method) {
		# We were getting malformed SQL queries with the previous
		# way this was done, so I made it a bit more robust.  If
		# no search terms are passed in with $query, instead of
		# crashing it returns "0" which of course will assign a
		# score of 0 to all hits.  I'd prefer to see the callers
		# massage $form->{query} themselves, stripping leading
		# and trailing spaces before passing it in here, but this
		# will do for now. - Jamie 2002/10/20
		# Nope, the caller should be unaware of all of this. We can extend 
		# and use different methods for searching and never have to modify
		# all of the above code. -Brian
		my @terms = ( );
		for my $term (split / /, $query) {
			$term =~ /^\s*(.*?)\s*$/;
			$term = $1;
			next unless $term;
			push @terms, $self->sqlQuote($term);
		}
		my @cols = ();
		for my $c (split /,/, $col) {
			$c =~ /^\s*(.*?)\s*$/;
			$c = $1;
			next unless $c;
			push @cols, $c;
		}
		return "0" if !@terms || !@cols;
		my $terms = join(",", @terms);
		if ($method eq "scour") {
			# This is a fix to do separate SCOUR()s on each
			# column;  it only applies if your mysqld is set
			# up to use Brian's special function.
			my @scour = map { $_ = "($method($_, $terms))" } @cols;
			my $scour = join " + ", @scour;
			my $n_scour = scalar(@scour);
			$scour = "( ( $scour ) / $n_scour )" if $n_scour > 1;
			return $scour;
		}
		return "($method($col, $terms))";
	} else {
		$query = $self->sqlQuote($query);
		return "\n(MATCH ($col) AGAINST ($query))\n";
	}
}

#################################################################
sub _cleanQuery {
	my ($self, $query) = @_;
	# This next line could be removed -Brian
	# get rid of bad characters
	$query =~ s/[^A-Z0-9'. :\/_]/ /gi;

	# This should be configurable -Brian
	# truncate query length
	if (length($query) > 40) {
		$query = substr($query, 0, 40);
	}

	return $query;
}


#################################################################
sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if $self->{_dbh} && !$ENV{GATEWAY_INTERFACE};
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

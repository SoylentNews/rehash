# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::DB::MySQL;
use strict;
use Digest::MD5 'md5_hex';
use HTML::Entities;
use Time::HiRes;
use Date::Format qw(time2str);
use Slash::Utility;
use Storable qw(thaw freeze);
use URI ();
use vars qw($VERSION);
use base 'Slash::DB';
use base 'Slash::DB::Utility';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# Fry: How can I live my life if I can't tell good from evil?

# For the getDecriptions() method
my %descriptions = (
	'sortcodes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='sortcodes'") },

	'generic'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='$_[2]'") },

	'genericstring'
		=> sub { $_[0]->sqlSelectMany('code,name', 'string_param', "type='$_[2]'") },

	'statuscodes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='statuscodes'") },

	'yes_no'
		=> sub { $_[0]->sqlSelectMany('code,name', 'string_param', "type='yes_no'") },

	'submission-notes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'string_param', "type='submission-notes'") },

	'months'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='months'") },

	'years'
		=> sub { $_[0]->sqlSelectMany('name,name', 'code_param', "type='years'") },

	'blocktype'
		=> sub { $_[0]->sqlSelectMany('name,name', 'code_param', "type='blocktype'") },

	'tzcodes'
		=> sub { $_[0]->sqlSelectMany('tz,off_set', 'tzcodes') },

	'tzdescription'
		=> sub { $_[0]->sqlSelectMany('tz,description', 'tzcodes') },

	'dateformats'
		=> sub { $_[0]->sqlSelectMany('id,description', 'dateformats') },

	'datecodes'
		=> sub { $_[0]->sqlSelectMany('id,format', 'dateformats') },

	'discussiontypes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='discussiontypes'") },

	'commentmodes'
		=> sub { $_[0]->sqlSelectMany('mode,name', 'commentmodes') },

	'threshcodes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='threshcodes'") },

	'threshcode_values'
		=> sub { $_[0]->sqlSelectMany('code,code', 'code_param', "type='threshcodes'") },

	'postmodes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='postmodes'") },

	'isolatemodes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='isolatemodes'") },

	'issuemodes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='issuemodes'") },

	'vars'
		=> sub { $_[0]->sqlSelectMany('name,name', 'vars') },

	'topics'
		=> sub { $_[0]->sqlSelectMany('tid,alttext', 'topics') },

	'topics_all'
		=> sub { $_[0]->sqlSelectMany('tid,alttext', 'topics') },

	'topics_section'
		=> sub { $_[0]->sqlSelectMany('topics.tid,topics.alttext', 'topics, section_topics', "section='$_[2]' AND section_topics.tid=topics.tid") },

	'topics_section_type'
		=> sub { $_[0]->sqlSelectMany('topics.tid as tid,topics.alttext as alttext', 'topics, section_topics', "section='$_[2]' AND section_topics.tid=topics.tid AND type= '$_[3]'") },

	'section_subsection'
		=> sub { $_[0]->sqlSelectMany('id,title', 'subsections', "section='$_[2]'") },

	'maillist'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='maillist'") },

	'session_login'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='session_login'") },

	'sortorder'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='sortorder'") },

	'displaycodes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='displaycodes'") },

	'commentcodes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='commentcodes'") },

	'sections'
		=> sub { $_[0]->sqlSelectMany('section,title', 'sections', 'isolate=0', 'order by title') },

	'sections-all'
		=> sub { $_[0]->sqlSelectMany('section,title', 'sections', '', 'ORDER BY title') },

	'static_block'
		=> sub { $_[0]->sqlSelectMany('bid,bid', 'blocks', "$_[2] >= seclev AND type != 'portald'") },

	'portald_block'
		=> sub { $_[0]->sqlSelectMany('bid,bid', 'blocks', "$_[2] >= seclev AND type = 'portald'") },

	'static_block_section'
		=> sub { $_[0]->sqlSelectMany('bid,bid', 'blocks', "$_[2]->{seclev} >= seclev AND section='$_[2]->{section}' AND type != 'portald'") },

	'portald_block_section'
		=> sub { $_[0]->sqlSelectMany('bid,bid', 'blocks', "$_[2]->{seclev} >= seclev AND section='$_[2]->{section}' AND type = 'portald'") },

	'color_block'
		=> sub { $_[0]->sqlSelectMany('bid,bid', 'blocks', "type = 'color'") },

	'authors'
		=> sub { $_[0]->sqlSelectMany('uid,nickname', 'authors_cache', "author = 1") },

	'all-authors'
		=> sub { $_[0]->sqlSelectMany('uid,nickname', 'authors_cache') },

	'admins'
		=> sub { $_[0]->sqlSelectMany('uid,nickname', 'users', 'seclev >= 100') },

	'users'
		=> sub { $_[0]->sqlSelectMany('uid,nickname', 'users') },

	'templates'
		=> sub { $_[0]->sqlSelectMany('tpid,name', 'templates') },

	'templatesbypage'
		=> sub { $_[0]->sqlSelectMany('tpid,name', 'templates', "page = '$_[2]'") },

	'templatesbysection'
		=> sub { $_[0]->sqlSelectMany('tpid,name', 'templates', "section = '$_[2]'") },

	'keywords'
		=> sub { $_[0]->sqlSelectMany('id,CONCAT(keyword, " - ", name)', 'related_links') },

	'pages'
		=> sub { $_[0]->sqlSelectMany('distinct page,page', 'templates') },

	'templatesections'
		=> sub { $_[0]->sqlSelectMany('distinct section, section', 'templates') },

	'sectionblocks'
		=> sub { $_[0]->sqlSelectMany('bid,title', 'blocks', 'portal=1') },

	'plugins'
		=> sub { $_[0]->sqlSelectMany('value,description', 'site_info', "name='plugin'") },

	'site_info'
		=> sub { $_[0]->sqlSelectMany('name,value', 'site_info', "name != 'plugin'") },

	'topic-sections'
		=> sub { $_[0]->sqlSelectMany('section,type', 'section_topics', "tid = '$_[2]'") },

	'forms'
		=> sub { $_[0]->sqlSelectMany('value,value', 'site_info', "name = 'form'") },

	'journal_discuss'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='journal_discuss'") },

	'section_extra_types'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='extra_types'") },

	'otherusersparam',
		=> sub { $_[0]->sqlSelectMany('code,name', 'string_param', "type='otherusersparam'") },

	countries => sub {
		$_[0]->sqlSelectMany(
			'code,CONCAT(code," (",name,")") as name',
			'string_param',
			'type="iso_countries"',
			'ORDER BY name'
		);
	},
);

########################################################
sub _whereFormkey {
	my($self) = @_;

	my $ipid = getCurrentUser('ipid');
	my $uid = getCurrentUser('uid');
	my $where;

	# anonymous user without cookie, check host, not ipid
	if (isAnon($uid)) {
		$where = "ipid = '$ipid'";
	} else {
		$where = "uid = '$uid'";
	}

	return $where;
};

########################################################
# Notes:
#  formAbuse, use defaults as ENV, be able to override
#  	(pudge idea).
#  description method cleanup. (done)
#  fetchall_rowref vs fetch the hashses and push'ing
#  	them into an array (good arguments for both)
#	 break up these methods into multiple classes and
#   use the dB classes to override methods (this
#   could end up being very slow though since the march
#   is kinda slow...).
#	 the getAuthorEdit() methods need to be refined
########################################################

########################################################
sub init {
	my($self) = @_;
	# These are here to remind us of what exists
	$self->{_storyBank} = {};
	$self->{_codeBank} = {};
	$self->{_sectionBank} = {};

	$self->{_boxes} = {};
	$self->{_sectionBoxes} = {};

	$self->{_comment_text} = {};
	$self->{_comment_text_full} = {};

	$self->{_story_comm} = {};

	# Do all cache elements contain '_cache_' in it, if so, we should 
	# probably perform a delete on anything matching, here.
}

#######################################################
# Wrapper to get the latest ID from the database
sub getLastInsertId {
	my($self, $table, $col) = @_;
	my($answer) = $self->sqlSelect('LAST_INSERT_ID()');
	return $answer;
}

########################################################
# Yes, this is ugly, and we can ditch it in about 6 months
# Turn off autocommit here
sub sqlTransactionStart {
	my($self, $arg) = @_;
	$self->sqlDo($arg);
}

########################################################
# Put commit here
sub sqlTransactionFinish {
	my($self) = @_;
	$self->sqlDo("UNLOCK TABLES");
}

########################################################
# In another DB put rollback here
sub sqlTransactionCancel {
	my($self) = @_;
	$self->sqlDo("UNLOCK TABLES");
}

########################################################
# Bad need of rewriting....
sub createComment {
	my($self, $comment) = @_;

	my $comment_text = $comment->{comment};
	delete $comment->{comment};
	$comment->{signature} = md5_hex($comment_text);
	$comment->{-date} = 'now()';

	my $cid;
	if ($self->sqlInsert('comments', $comment)) {
		$cid = $self->getLastInsertId();
	} else {
		errorLog("$DBI::errstr");
		return -1;
	}

	$self->sqlInsert('comment_text', {
			cid	=> $cid,
			comment	=>  $comment_text,
	});


	# should this be conditional on the others happening?
	# is there some sort of way to doublecheck that this value
	# is correct?  -- pudge
	# This is fine as is; if the insert failed, we've already
	# returned out of this method. - Jamie
	$self->sqlUpdate(
		"discussions",
		{ -commentcount	=> 'commentcount+1' },
		"id=$comment->{sid}",
	);

	return $cid;
}

########################################################
sub setModeratorLog {
	my($self, $comment, $uid, $val, $reason, $active) = @_;

	$active = 1 unless defined $active;
	$self->sqlInsert("moderatorlog", {
		uid	=> $uid,
		val	=> $val,
		sid	=> $comment->{sid},
		cid	=> $comment->{cid},
		cuid	=> $comment->{uid},
		reason  => $reason,
		-ts	=> 'now()',
		active 	=> $active,
	});
}

########################################################
#this is broke right now -Brian
#
# Work, dammit! - Cliff
sub getMetamodComments {
	my($self, $user, $num_comments) = @_;

	#require Benchmark;
	#my $t0 = new Benchmark;

	# We first check to see if we have any moderator records that need
	# processing at the current count level If not, we then increment the
	# count level and use that.
	#
	# If the vars are cached, might we have a race condition here?
	my $thresh = $self->getVar('m2_consensus', 'value');
	my $previousM2s = [
		map { $_ = $_->[0] }
		@{$self->sqlSelectAll('mmid', 'metamodlog', "uid=$user->{uid}")}
	];
	my $M2mods = [];
	$self->sqlTransactionStart('LOCK TABLES moderatorlog READ, vars WRITE');
	my $modpos = $user->{lastmmid} ||
		     $self->getVar('m2_modlog_pos', 'value');
	my $timesthru = $self->getVar('m2_modlog_cycles', 'value');
	my($minMod, $maxMod) =
		$self->sqlSelect('min(id), max(id)', 'moderatorlog');
	$minMod--;
	my($count, $num) = (0, $num_comments);
	while ($num && $count < 2) {
		my @excluded;

		@excluded = map { $_ = $_->{id} } (@excluded = @{$M2mods})
			if @{$M2mods};
		push @excluded, @{$previousM2s} if scalar @{$previousM2s};
		$modpos = $minMod if $modpos < $minMod ||
			             $maxMod - $modpos < $num_comments;
		my $cond = "moderatorlog.uid != $user->{uid}
			AND moderatorlog.cuid != $user->{uid}
			AND moderatorlog.reason < 8
			AND moderatorlog.id > $modpos
			AND moderatorlog.m2count < $thresh";
		{
			local $" = ',';
			$cond .= " AND id NOT IN (@excluded)"
				if scalar @excluded;
		}

		my $result = $self->sqlSelectAllHashrefArray(
			'id, cid as mcid, reason as modreason',
			'moderatorlog',
			$cond,
			"ORDER BY id LIMIT $num"
		);

		if ($result) {
			push @{$M2mods}, @{$result};
			$num -= scalar @{$result};
		}

		# We only do this the first time thru.
		if ($num && ! $count) {
			$self->setVar('m2_modlog_cycles', $timesthru + 1);
			$modpos = $minMod;
		}
		$count++;
	}
	# Only write position change if it changes for the user.
	$self->setVar('m2_modlog_pos', $M2mods->[-1]{id})
		if @{$M2mods} && !$user->{lastmmid};
	$self->sqlTransactionFinish();

	# Note in error log if we've picked up less than the requested number
	# of comments.
	if ($num) {
		my @list = @{$M2mods};
		$_ = $_->{id} for @list;
		local $" = ', ';
		errorLog(<<EOT);
M2 - Gave U#$user->{uid} less than $num_comments comments: [@list]
EOT

	}

	# Update user if necessary. Users are STUCK at the same moderations
	# for M2 until they submit the form (or those comments fall out of 
	# the moderatorlog.
	$self->setUser($user->{uid}, { lastmmid => $modpos })
		if !$user->{lastmmid};

	my(@comments);
	push @comments, $_->{mcid} for @{$M2mods};

	# Retrieve the remaining data.
	my $comments;
	{
		local $" = ',';
		$comments = $self->sqlSelectAllHashref(
			'cid',
			'comments.cid, comments.sid as sid, date,
			subject, discussions.sid as discussions_sid,
			comment,comments.uid,pid, reason, sig, title, nickname',
	
			'comments, comment_text, discussions, users',

			"comments.cid in (@comments)
			AND comments.cid=comment_text.cid
			AND comments.uid=users.uid
			AND discussions.id=comments.sid"
		) if @comments;
	}

	my @finalM2mods;
	for my $m2Mod (@{$M2mods}) {
		while (my($key, $val) = each %{$comments->{$m2Mod->{mcid}}}) {

			$m2Mod->{$key} = $val;

			# Anonymize comment identity a bit for fairness.
			$m2Mod->{$key} = '-' if $key eq 'nickname';
			$m2Mod->{$key} = getCurrentStatic(
				'anonymous_coward_uid'
			) if $key eq 'uid';
			$m2Mod->{$key} = '0' if $key eq 'points';
			# No longer anonymizing sig.
			#$m2Mod->{$key} = '' if $key eq 'sig';
		}
		# We also need to provide the url, but the question is,
		# where to link to?
		if ($m2Mod->{discussions_sid}) {
			# This is a comment posted to a story discussion, so
			# we can link straight to the story, providing even
			# more context for this comment.
			$m2Mod->{url} = getCurrentStatic('rootdir')
				. "/article.pl?sid=$m2Mod->{discussions_sid}";
		} else {
			# This is a comment posted to a discussion that isn't
			# a story.  It could be attached to a poll, a journal
			# entry, or nothing at all (user-created discussion).
			# Whatever the case, we can't trust the url field, so
			# we should just link to the discussion itself.
			$m2Mod->{url} = getCurrentStatic('rootdir')
				. "/comments.pl?sid=$m2Mod->{sid}";
		}
		$m2Mod->{no_moderation} = 1;

		delete $m2Mod->{mcid};
		# make sure we have a good moderation for an existing comment
		push @finalM2mods, $m2Mod if $m2Mod->{cid} && $m2Mod->{sid};
	}
	#my $t1 = new Benchmark;
	#printf STDERR "M2 Time: %s\n", 
	#	Benchmark::timestr(Benchmark::timediff($t1, $t0), 'noc');

# format in the template instead
#	formatDate($M2mods);
	return \@finalM2mods;
}

########################################################
# ok, I was tired of trying to mould getDescriptions into 
# taking more args.
sub getTemplateList {
	my($self, $section, $page) = @_;

	my $templatelist = {};
	my $where = "seclev <= " . getCurrentUser('seclev');
	$where .= " AND section = '$section'" if $section;
	$where .= " AND page = '$page'" if $page;
	my $templates =	$self->sqlSelectMany('tpid,name', 'templates', $where); 
	while (my($tpid, $name) = $templates->fetchrow) {
		$templatelist->{$tpid} = $name;
	}

	return $templatelist;
}

########################################################
sub getModeratorCommentLog {
	my($self, $asc_desc, $limit, $type, $value) = @_;

	$asc_desc ||= 'ASC';
	$asc_desc = uc $asc_desc;
	$asc_desc = 'ASC' if $asc_desc ne 'DESC';

	if ($limit and $limit =~ /^(\d+)$/) {
		$limit = "LIMIT $1";
	} else {
		$limit = "";
	}

	my $vq = $self->sqlQuote($value);
	my $where_clause = "";
	   if ($type eq 'uid') {	$where_clause = "moderatorlog.uid=$vq  AND comments.uid=users.uid"	}
	elsif ($type eq 'cid') {	$where_clause = "moderatorlog.cid=$vq  AND moderatorlog.uid=users.uid"	}
	elsif ($type eq 'cuid') {	$where_clause = "moderatorlog.cuid=$vq AND moderatorlog.uid=users.uid"	}
	elsif ($type eq 'subnetid') {	$where_clause = "comments.subnetid=$vq AND moderatorlog.uid=users.uid"	}
	elsif ($type eq 'ipid') {	$where_clause = "comments.ipid=$vq     AND moderatorlog.uid=users.uid"	}
	return [ ] unless $where_clause;

	my $comments = $self->sqlSelectMany("comments.sid AS sid,
				 comments.cid AS cid,
				 comments.points AS score,
				 users.uid AS uid,
				 users.nickname AS nickname,
				 moderatorlog.val AS val,
				 moderatorlog.reason AS reason,
				 moderatorlog.ts AS ts,
				 moderatorlog.active AS active",
				"moderatorlog, users, comments",
				"$where_clause
				 AND moderatorlog.cid=comments.cid",
				"ORDER BY ts $asc_desc $limit"
	);
	my(@comments, $comment);
	push @comments, $comment while ($comment = $comments->fetchrow_hashref);
	return \@comments;
}

########################################################
sub getModeratorLogID {
	my($self, $cid, $uid) = @_;
	# We no longer need the SID as CID is now unique.
	my($mid) = $self->sqlSelect(
		"id", "moderatorlog", "uid=$uid and cid=$cid"
	);
	return $mid;
}

########################################################
sub undoModeration {
	my($self, $uid, $sid) = @_;
	my $constants = getCurrentStatic();

	# SID here really refers to discussions.id, NOT stories.sid
	my $cursor = $self->sqlSelectMany("cid,val,active,cuid",
			"moderatorlog",
			"moderatorlog.uid=$uid and moderatorlog.sid=$sid"
	);

	my $min_score = $constants->{comment_minscore};
	my $max_score = $constants->{comment_maxscore};
	my $min_karma = $constants->{minkarma};
	my $max_karma = $constants->{maxkarma};

	my @removed;
	while (my($cid, $val, $active, $cuid) = $cursor->fetchrow){

		# If moderation wasn't actually performed, we skip ahead one.
		next if ! $active;

		# We undo moderation even for inactive records (but silently for
		# inactive ones...).  Leave them in the table but inactive, so
		# they are still eligible to be metamodded.
		$self->sqlUpdate("moderatorlog",
			{ active => 0 },
			"cid=$cid and uid=$uid"
		);

		my $comm_update = { };

		# Adjust the comment score up or down, but don't push it beyond the
		# maximum or minimum.
		my $adjust = -$val;
		$adjust =~ s/^([^+-])/+$1/;
		$comm_update->{-points} =
			$adjust > 0
			? "LEAST($max_score, points $adjust)"
			: "GREATEST($min_score, points $adjust)";

		# Recalculate the comment's reason.
		$comm_update->{reason} = $self->getCommentMostCommonReason($cid)
			|| 0; # no active moderations? reset reason to empty

		$self->sqlUpdate("comments", $comm_update, "cid=$cid");

		# Restore modded user's karma, again within the proper boundaries.
		# XXX If we don't care about tracking the Anonymous Coward's karma,
		# here's a place to take it out.
		$self->sqlUpdate(
			"users_info",
			{ -karma =>	$adjust > 0
					? "LEAST($max_karma, karma $adjust)"
					: "GREATEST($min_karma, karma $adjust)" },
			"uid=$cuid"
		);

		push(@removed, $cid);
	}

	return \@removed;
}

########################################################
sub deleteSectionTopicsByTopic {
	my($self, $tid, $type) = @_;
	# $type ||= 1; # ! is the default type
	# arghghg no, it's not, and this caused
	# saving a topic to not work. 
	# not fun  at 12:19 AM
	$type ||= 0;

	$self->sqlDo("DELETE FROM section_topics WHERE tid=$tid");
}

########################################################
sub deleteRelatedLink {
	my($self, $id) = @_;

	$self->sqlDo("DELETE FROM related_links WHERE id=$id");
}

########################################################
sub createSectionTopic {
	my($self, $section, $tid, $type) = @_;
	$type ||= 'topic_1'; # ! is the default type

	$self->sqlDo("INSERT INTO section_topics (section, tid, type) VALUES ('$section',$tid, '$type')");
}

########################################################
sub getSectionExtras {
	my($self, $section) = @_;
	return unless $section;

	my $answer = $self->sqlSelectAll(
		'name,value,type,section', 
		'section_extras', 
		'section = '. $self->sqlQuote($section)
	);

	return $answer;
}


########################################################
sub setSectionExtras {
	my($self, $section, $extras) = @_;
	return unless $section;

	$self->sqlDo('DELETE FROM section_extras
			WHERE section=' . $self->sqlQuote($section)
	);
	
	for (@{$extras}) {
		$self->sqlInsert('section_extras', {
			section	=> $section,
			name 	=> $_->[0],
			value	=> $_->[1],
		});
	}
}

########################################################
sub getContentFilters {
	my($self, $formname, $field) = @_;

	my $field_string = $field ne '' ? " AND field = '$field'" : " AND field != ''";

	my $filters = $self->sqlSelectAll("*", "content_filters",
		"regex != '' $field_string and form = '$formname'");
	return $filters;
}

########################################################
sub createPollVoter {
	my($self, $qid, $aid) = @_;

	my $qid_quoted = $self->sqlQuote($qid);
	my $aid_quoted = $self->sqlQuote($aid);
	$self->sqlInsert("pollvoters", {
		qid	=> $qid,
		id	=> md5_hex($ENV{REMOTE_ADDR} . $ENV{HTTP_X_FORWARDED_FOR}),
		-'time'	=> 'now()',
		uid	=> $ENV{SLASH_USER}
	});

	$self->sqlDo("UPDATE pollquestions SET voters=voters+1
		WHERE qid=$qid_quoted");
	$self->sqlDo("UPDATE pollanswers SET votes=votes+1
		WHERE qid=$qid_quoted AND aid=$aid_quoted");
}

########################################################
sub createSubmission {
	my($self, $submission) = @_;

	return unless	$submission && 
			($submission->{story} || $submission->{story});

	my $data;
	$data->{story} = $submission->{story};
	$data->{subj} = $submission->{subj};
	$data->{ipid} = getCurrentUser('ipid');
	$data->{subnetid} = getCurrentUser('subnetid');
	$data->{email} ||= $submission->{email} ? $submission->{email} : ''; 
	$data->{uid} ||= $submission->{uid} ? $submission->{uid} 
		: getCurrentStatic('anonymous_coward_uid'); 
	$data->{section} ||= getCurrentStatic('defaultsection'); 
	$data->{'-time'} = 'now()' unless $submission->{'time'};

	# To help cut down on duplicates generated by automated routines. For
	# crap- flooders, we will need to look into an alternate methods. 
	# Filters of some sort, maybe?
	$data->{'signature'} = md5_hex($submission->{story});

	$self->sqlInsert('submissions', $data);
	my $subid = $self->getLastInsertId();
	#The next line makes sure that we get any section_extras in the DB - Brian
	$self->setSubmission($subid, $submission);

	return $subid;
}

#################################################################
sub getStoryDiscussions {
	my($self, $section, $limit, $start) = @_;
	$limit ||= 50; # Sanity check in case var is gone
	$start ||= 0; # Sanity check in case var is gone
	my $tables = "discussions, stories",
	my $where = "displaystatus != -1
		AND discussions.sid=stories.sid
		AND time <= NOW()
		AND stories.writestatus != 'delete'
		AND stories.writestatus != 'archived'";

	if ($section) {
		$where .= " AND discussions.section = '$section'"
	} else {
		$tables .= ", sections";
		$where .= " AND sections.section = discussions.section
			AND sections.isolate != 1 ";
	}

	my $discussion = $self->sqlSelectAll(
		"discussions.sid, discussions.title, discussions.url",
		$tables,
		$where,
		"ORDER BY time DESC LIMIT $start, $limit"
	);

	return $discussion;
}

#################################################################
# Less then 2, ince 2 would be a read only discussion
sub getDiscussions {
	my($self, $section, $limit, $start) = @_;
	$limit ||= 50; # Sanity check in case var is gone
	$start ||= 0; # Sanity check in case var is gone
	my $tables = "discussions";

	my $where = "type != 'archived' AND ts <= now()";

	if ($section) {
		$where .= " AND discussions.section = '$section'"
	} else {
		$tables .= ", sections";
		$where .= " AND sections.section = discussions.section AND sections.isolate != 1 ";
	}

	my $discussion = $self->sqlSelectAll("discussions.id, discussions.title, discussions.url",
		$tables,
		$where,
		"ORDER BY ts DESC LIMIT $start, $limit"
	);

	return $discussion;
}

#################################################################
# Less then 2, ince 2 would be a read only discussion
sub getDiscussionsByCreator {
	my($self, $section, $uid, $limit, $start) = @_;
	return unless $uid;
	$limit ||= 50; # Sanity check in case var is gone
	$start ||= 0; # Sanity check in case var is gone
	my $tables = "discussions";

	my $where = "type != 'archived' AND ts <= now() AND uid = $uid";

	if ($section) {
		$where .= " AND discussions.section = '$section'"
	} else {
		$tables .= ", sections";
		$where .= " AND sections.section = discussions.section AND sections.isolate != 1 ";
	}

	my $discussion = $self->sqlSelectAll("id, title, url",
		$tables,
		$where,
		"ORDER BY ts DESC LIMIT $start, $limit"
	);

	return $discussion;
}

#################################################################
sub getDiscussionsUserCreated {
	my($self, $section, $limit, $start, $all) = @_;

	$limit ||= 50; # Sanity check in case var is gone
	$start ||= 0; # Sanity check in case var is gone
	my $tables = "discussions, users";

	my $where = "type = 'recycle' AND ts <= now() AND users.uid = discussions.uid";
	$where .= " AND section = '$section'"
		if $section;
	$where .= " AND commentcount > 0"
		unless $all;

	if ($section) {
		$where .= " AND discussions.section = '$section'";
	} else {
		$tables .= ", sections";
		$where .= " AND sections.section = discussions.section AND sections.isolate != 1 ";
	}

	my $discussion = $self->sqlSelectAll("discussions.id, discussions.title, discussions.ts, users.nickname",
		$tables,
		$where,
		"ORDER BY ts DESC LIMIT $start, $limit"
	);

	return $discussion;
}

########################################################
# Handles admin logins (checks the sessions table for a cookie that
# matches).  Called during authentication
sub getSessionInstance {
	my($self, $uid, $session_in) = @_;
	my $admin_timeout = getCurrentStatic('admin_timeout');
	my $session_out = '';

	if ($session_in) {
		# CHANGE DATE_ FUNCTION
		$self->sqlDo("DELETE from sessions WHERE now() > DATE_ADD(lasttime, INTERVAL $admin_timeout MINUTE)");

		my $session_in_q = $self->sqlQuote($session_in);

		my($uid) = $self->sqlSelect(
			'uid',
			'sessions',
			"session=$session_in_q"
		);

		if ($uid) {
			$self->sqlDo("DELETE from sessions WHERE uid = '$uid' AND " .
				"session != $session_in_q"
			);
			$self->sqlUpdate('sessions', {-lasttime => 'now()'},
				"session = $session_in_q"
			);
			$session_out = $session_in;
		}
	}
	if (!$session_out) {
		my($title, $last_sid, $last_subid) = $self->sqlSelect(
			'lasttitle, last_sid, last_subid', 
			'sessions',
			"uid=$uid"
		);
		$_ ||= '' for ($title, $last_sid, $last_subid);

		# Why not have sessions have UID be unique and use 
		# sqlReplace() here? Minor quibble, just curious.
		# - Cliff
		$self->sqlDo("DELETE FROM sessions WHERE uid=$uid");

		$self->sqlInsert('sessions', { -uid => $uid,
			-logintime	=> 'now()',
			-lasttime	=> 'now()',
			lasttitle	=> $title,
			last_sid	=> $last_sid,
			last_subid	=> $last_subid
		});
		$session_out = $self->getLastInsertId('sessions', 'session');
	}
	return $session_out;

}

########################################################
sub setContentFilter {
	my($self, $formname) = @_;

	my $form = getCurrentForm();
	$formname ||= $form->{formname};

	$self->sqlUpdate("content_filters", {
			regex		=> $form->{regex},
			form		=> $formname,
			modifier	=> $form->{modifier},
			field		=> $form->{field},
			ratio		=> $form->{ratio},
			minimum_match	=> $form->{minimum_match},
			minimum_length	=> $form->{minimum_length},
			err_message	=> $form->{err_message},
		}, "filter_id=$form->{filter_id}"
	);
}

########################################################
# Only Slashdot uses this method
# not for long... - Cliff
sub setSectionExtra {
	my($self, $full, $story) = @_;

	if ($full && $self->sqlTableExists($story->{section}) && $story->{section}) {
		my $extra = $self->sqlSelectHashref('*', $story->{section}, "sid='$story->{sid}'");
		for (keys %$extra) {
			$story->{$_} = $extra->{$_};
		}
	}

}

########################################################
# This creates an entry in the accesslog
sub createAccessLog {
	my($self, $op, $dat) = @_;
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $r = Apache->request;
	my $hostip = $r->connection->remote_ip; 
	my $bytes = $r->bytes_sent; 

	my $uid;
	if ($ENV{SLASH_USER}) {
		$uid = $ENV{SLASH_USER};
	} else {
		$uid = $constants->{anonymous_coward_uid};
	}
	my $section = $constants->{section};
	# The following two are special cases
	if ($op eq 'index' || $op eq 'article') {
		$section = $form->{section} ? $form->{section} : $constants->{section};
	}

	my $ipid = getCurrentUser('ipid') || md5_hex($hostip);
	$hostip =~ s/^(\d+\.\d+\.\d+)\.\d+$/$1.0/;
	$hostip = md5_hex($hostip);
	my $subnetid = getCurrentUser('subnetid') || $hostip;

	if ($dat =~ /.*(\d{2}\/\d{2}\/\d{2}\/\d{4,7}).*/) {
		$dat = $1;
#		$self->sqlUpdate('stories', { -hits => 'hits+1' },
#			'sid=' . $self->sqlQuote($dat)
#		);
	}

	$self->sqlInsert('accesslog', {
		host_addr	=> $ipid,
		subnetid	=> $subnetid,
		dat		=> $dat,
		uid		=> $uid,
		section		=> $section,
		bytes		=> $bytes,
		op		=> $op,
		-ts		=> 'NOW()',
		query_string	=> $ENV{QUERY_STRING} || '0',
		user_agent	=> $ENV{HTTP_USER_AGENT} || '0',
	}, { delayed => 1 });
}


########################################################
# pass in additional optional descriptions
sub getDescriptions {
	my($self, $codetype, $optional, $flag, $altdescs) =  @_;
	return unless $codetype;
	my $codeBank_hash_ref = {};
	$optional ||= '';
	$altdescs ||= '';

	# I am extending this, without the extension the cache was
	# not always returning the right data -Brian
	my $cache = '_getDescriptions_' . $codetype . $optional . $altdescs;

	if ($flag) {
		undef $self->{$cache};
	} else {
		return $self->{$cache} if $self->{$cache};
	}

	$altdescs ||= {};
	my $descref = $altdescs->{$codetype} || $descriptions{$codetype};
	return $codeBank_hash_ref unless $descref;

	my $sth = $descref->(@_);
	while (my($id, $desc) = $sth->fetchrow) {
		$codeBank_hash_ref->{$id} = $desc;
	}
	$sth->finish;

	$self->{$cache} = $codeBank_hash_ref if getCurrentStatic('cache_enabled');
	return $codeBank_hash_ref;
}

########################################################
# Get user info from the users table.
# If you don't pass in a $script, you get everything
# which is handy for you if you need the entire user

# why not just axe this entirely and always get all the data? -- pudge
# Worry about access times. Realize that when MySQL has row level
# locking that we can combine all of the user table (except param)
# into one table again. -Brian

sub getUserInstance {
	my($self, $uid, $script) = @_;

	my $user;
	unless ($script) {
		$user = $self->getUser($uid);
		return $user || undef;
	}

	$user = $self->sqlSelectHashref('*', 'users',
		' uid = ' . $self->sqlQuote($uid)
	);
	return undef unless $user;
	my $user_extra = $self->sqlSelectHashref('*', "users_prefs", "uid=$uid");
	while (my($key, $val) = each %$user_extra) {
		$user->{$key} = $val;
	}

	# what is this for?  it appears to want to do the same as the
	# code above ... but this assigns a scalar to a scalar ...
	# perhaps `@{$user}{ keys %foo } = values %foo` is wanted?  -- pudge
#	$user->{ keys %$user_extra } = values %$user_extra;

#	if (!$script || $script =~ /index|article|comments|metamod|search|pollBooth/)
	{
		my $user_extra = $self->sqlSelectHashref('*', "users_comments", "uid=$uid");
		while (my($key, $val) = each %$user_extra) {
			$user->{$key} = $val;
		}
	}

	# Do we want the index stuff?
#	if (!$script || $script =~ /index/)
	{
		my $user_extra = $self->sqlSelectHashref('*', "users_index", "uid=$uid");
		while (my($key, $val) = each %$user_extra) {
			$user->{$key} = $val;
		}
	}

	return $user;
}

########################################################
sub deleteUser {
	my($self, $uid) = @_;
	return unless $uid;
	$self->setUser($uid, {
		bio		=> '',
		nickname	=> 'deleted user',
		matchname	=> 'deleted user',
		realname	=> 'deleted user',
		realemail	=> '',
		fakeemail	=> '',
		newpasswd	=> '',
		homepage	=> '',
		passwd		=> '',
		people		=> '',
		sig		=> '',
		seclev		=> 0
	});
	$self->sqlDo("DELETE FROM users_param WHERE uid=$uid");
}

########################################################
# Get user info from the users table.
sub getUserAuthenticate {
	my($self, $user, $passwd, $kind) = @_;
	my($uid, $cookpasswd, $newpass, $dbh, $user_db,
		$cryptpasswd, @pass);

	return unless $user && $passwd;

	# if $kind is 1, then only try to auth password as plaintext
	# if $kind is 2, then only try to auth password as encrypted
	# if $kind is undef or 0, try as encrypted
	#	(the most common case), then as plaintext
	my($EITHER, $PLAIN, $ENCRYPTED) = (0, 1, 2);
	my($UID, $PASSWD, $NEWPASSWD) = (0, 1, 2);
	$kind ||= $EITHER;

	# RECHECK LOGIC!!  -- pudge

	$dbh = $self->{_dbh};
	$user_db = $dbh->quote($user);
	$cryptpasswd = encryptPassword($passwd);
	@pass = $self->sqlSelect(
		'uid,passwd,newpasswd',
		'users',
		"uid=$user_db"
	);

	# try ENCRYPTED -> ENCRYPTED
	if ($kind == $EITHER || $kind == $ENCRYPTED) {
		if ($passwd eq $pass[$PASSWD]) {
			$uid = $pass[$UID];
			$cookpasswd = $passwd;
		}
	}

	# try PLAINTEXT -> ENCRYPTED
	if (($kind == $EITHER || $kind == $PLAIN) && !defined $uid) {
		if ($cryptpasswd eq $pass[$PASSWD]) {
			$uid = $pass[$UID];
			$cookpasswd = $cryptpasswd;
		}
	}

	# try PLAINTEXT -> NEWPASS
	if (($kind == $EITHER || $kind == $PLAIN) && !defined $uid) {
		if ($passwd eq $pass[$NEWPASSWD]) {
			$self->sqlUpdate('users', {
				newpasswd	=> '',
				passwd		=> $cryptpasswd
			}, "uid=$user_db");
			$newpass = 1;

			$uid = $pass[$UID];
			$cookpasswd = $cryptpasswd;
		}
	}

	# return UID alone in scalar context
	return wantarray ? ($uid, $cookpasswd, $newpass) : $uid;
}

########################################################
# Make a new password, save it in the DB, and return it.
sub getNewPasswd {
	my($self, $uid) = @_;
	my $newpasswd = changePassword();
	$self->sqlUpdate('users', {
		newpasswd => $newpasswd
	}, 'uid=' . $self->sqlQuote($uid));
	return $newpasswd;
}


########################################################
# Get user info from the users table.
# May be worth it to cache this at some point
sub getUserUID {
	my($self, $name) = @_;

# We may want to add BINARY to this. -Brian
#
# The concern is that MySQL's "=" matches text chars that are not
# bit-for-bit equal, e.g. a-umlaut may "=" a, but that BINARY
# matching is apparently significantly slower than non-BINARY.
# Adding the ORDER at least makes the results predictable so this
# is not exploitable -- no one can add a later account that will
# make an earlier one inaccessible.  A better method would be to
# grab all uid/nicknames that MySQL thinks match, and then to
# compare them (in order) in perl until a real bit-for-bit match
# is found. -jamie
# Actually there is a way to optimize a table for binary searches
# I believe -Brian

	my($uid) = $self->sqlSelect(
		'uid',
		'users',
		'nickname=' . $self->sqlQuote($name),
		'ORDER BY uid ASC'
	);

	return $uid;
}

########################################################
# Get user info from the users table with email address.
# May be worth it to cache this at some point
sub getUserEmail {
	my($self, $email) = @_;

	my($uid) = $self->sqlSelect('uid', 'users',
		'realemail=' . $self->sqlQuote($email)
	);

	return $uid;
}

#################################################################
# Turns out it is faster to hit the disk, so forget about
# comment_heap
sub getCommentsByGeneric {
	my($self, $where_clause, $num, $min) = @_;
	$min ||= 0;

	my $sqlquery = "SELECT pid,sid,cid,subject,date,points "
			. " FROM comments WHERE $where_clause "
			. " ORDER BY date DESC LIMIT $min, $num ";

	my $sth = $self->{_dbh}->prepare($sqlquery);
	$sth->execute;
	my($comments) = $sth->fetchall_arrayref;
	formatDate($comments, 4);
	return $comments;
}

#################################################################
sub getCommentsByUID {
	my($self, $uid, $num, $min) = @_;
	return $self->getCommentsByGeneric("uid=$uid", $num, $min);
}

#################################################################
sub getCommentsByIPID {
	my($self, $id, $num, $min) = @_;
	return $self->getCommentsByGeneric("ipid='$id'", $num, $min);
}

#################################################################
sub getCommentsBySubnetID {
	my($self, $id, $num, $min) = @_;
	return $self->getCommentsByGeneric("subnetid='$id'", $num, $min);
}

#################################################################
# Avoid using this one unless absolutely necessary;  if you know
# whether you have an IPID or a SubnetID, those queries take a
# fraction of a second, but this "OR" is a table scan.
sub getCommentsByIPIDOrSubnetID {
	my($self, $id, $min) = @_;
	return $self->getCommentsByGeneric(
		"ipid='$id' OR subnetid='$id'", $min);
}

#################################################################
# Just create an empty content_filter
sub createContentFilter {
	my($self, $formname) = @_;

	$self->sqlInsert("content_filters", {
		regex		=> '',
		form		=> $formname,
		modifier	=> '',
		field		=> '',
		ratio		=> 0,
		minimum_match	=> 0,
		minimum_length	=> 0,
		err_message	=> ''
	});

	my $filter_id = $self->getLastInsertId('content_filters', 'filter_id');

	return $filter_id;
}

sub existsEmail {
	my($self, $email) = @_;

	# Returns count of users matching $email.
	return ($self->sqlSelect('uid', 'users',
		'realemail=' . $self->sqlQuote($email)))[0];
}

#################################################################
# Replication issue. This needs to be a two-phase commit.
sub createUser {
	my($self, $matchname, $email, $newuser) = @_;
	return unless $matchname && $email && $newuser;

	return if ($self->sqlSelect(
		"uid", "users",
		"matchname=" . $self->sqlQuote($matchname)
	))[0] || $self->existsEmail($email);

	$self->sqlInsert("users", {
		uid		=> '',
		realemail	=> $email,
		nickname	=> $newuser,
		matchname	=> $matchname,
		seclev		=> 1,
		passwd		=> encryptPassword(changePassword())
	});

# This is most likely a transaction problem waiting to
# bite us at some point. -Brian
	my $uid = $self->getLastInsertId('users', 'uid');
	return unless $uid;
	$self->sqlInsert("users_info", {
		uid 			=> $uid,
		-lastaccess		=> 'now()',
		-created_at		=> 'now()',
	});
	$self->sqlInsert("users_prefs", { uid => $uid });
	$self->sqlInsert("users_comments", { uid => $uid });
	$self->sqlInsert("users_index", { uid => $uid });
	$self->sqlInsert("users_hits", { uid => $uid });
	$self->sqlInsert("users_count", { uid => $uid });

	# All param fields should be set here, as some code may not behave
	# properly if the values don't exist.
	#
	# You know, I know this might be slow, but maybe this thing could be
	# initialized by a template? Wild thought, but that would prevent
	# site admins from having to edit CODE to set this stuff up.
	#
	#	- Cliff
	# Initialize the expiry variables...
	# ...users start out as registered...
	# ...the default email view is to SHOW email address...
	#	(not anymore - Jamie)
	my $constants = getCurrentStatic();

	# editComm;users;default knows that the default emaildisplay is 0...
	# ...as it should be
	$self->setUser($uid, {
		'registered'		=> 1,
		'expiry_comm'		=> $constants->{min_expiry_comm},
		'expiry_days'		=> $constants->{min_expiry_days},
		'user_expiry_comm'	=> $constants->{min_expiry_comm},
		'user_expiry_days'	=> $constants->{min_expiry_days},
#		'emaildisplay'		=> 2,
	});

	return $uid;
}


########################################################
# Do not like this method -Brian
sub setVar {
	my($self, $name, $value) = @_;
	if (ref $value) {
		$self->sqlUpdate('vars', {
			value		=> $value->{'value'},
			description	=> $value->{'description'}
		}, 'name=' . $self->sqlQuote($name));
	} else {
		$self->sqlUpdate('vars', {
			value		=> $value
		}, 'name=' . $self->sqlQuote($name));
	}
}

########################################################
sub setSession {
	my($self, $name, $value) = @_;
	$self->sqlUpdate('sessions', $value, 'uid=' . $self->sqlQuote($name));
}

########################################################
sub setBlock {
	_genericSet('blocks', 'bid', '', @_);
}

########################################################
sub setRelatedLink {
	_genericSet('related_links', 'id', '', @_);
}

########################################################
sub setDiscussion {
	_genericSet('discussions', 'id', '', @_);
}

########################################################
sub setDiscussionBySid {
	_genericSet('discussions', 'sid', '', @_);
}

########################################################
sub setPollQuestion {
	_genericSet('pollquestions', 'qid', '', @_);
}

########################################################
sub setTemplate {
	# Instructions don't get passed to the DB.
	delete $_[2]->{instructions};

	for (qw| page name section |) {
		next unless $_[2]->{$_};
		if ($_[2]->{$_} =~ /;/) {
			errorLog("A semicolon was found in the $_ while trying to update a template");
			return;
		}
	}
	_genericSet('templates', 'tpid', '', @_);
}

########################################################
sub getCommentChildren {
	my($self, $cid) = @_;
	my($scid) = $self->sqlSelectAll('cid', 'comments', "pid=$cid");

	return $scid;
}

########################################################
# Does what it says, deletes one comment.
# For optimization's sake (not that Slashdot really deletes a lot of
# comments, currently one every four years!) commentcount and hitparade
# are updated from comments.pl's delete() function.
sub deleteComment {
	my($self, $cid, $discussion_id) = @_;
	my @comment_tables = qw( comment_text comments );
	# We have to update the discussion, so make sure we have its id.
	if (!$discussion_id) {
		($discussion_id) = $self->sqlSelect("sid", 'comments', "cid=$cid");
	}
	my $total_rows = 0;
	for my $table (@comment_tables) {
		$total_rows += $self->sqlDo("DELETE FROM $table WHERE cid=$cid");
	}
	$self->deleteModeratorlog({ cid => $cid });
	if ($total_rows != scalar(@comment_tables)) {
		# Here is the thing, an orphaned comment with no text blob
		# would fuck up the comment count.
		# Bad juju, no cookie -Brian
		errorLog("deleteComment cid $cid from $discussion_id,"
			. " only $total_rows deletions");
		return 0;
	}
	return 1;
}

########################################################
sub deleteModeratorlog {
	my($self, $opts) = @_;
	my $where;

	if ($opts->{cid}) {
		$where = 'cid=' . $self->sqlQuote($opts->{cid});
	} elsif ($opts->{sid}) {
		$where = 'sid=' . $self->sqlQuote($opts->{sid});
	} else {
		return;
	}

	my $mmids = $self->sqlSelectColArrayref(
		'id', 'moderatorlog', $where
	);
	return unless @$mmids;

	my $mmid_in = join ',', @$mmids;
	$self->sqlDelete('moderatorlog', $where);
	$self->sqlDelete('metamodlog', "mmid IN ($mmid_in)");
}

########################################################
sub getCommentPid {
	my($self, $sid, $cid) = @_;

	$self->sqlSelect('pid', 'comments', "sid='$sid' and cid=$cid");
}

########################################################
# Ugly yes, needed at the moment, yes
sub checkStoryViewable {
	my($self, $sid) = @_;
	return unless $sid;

	my $count = $self->sqlCount('stories', "sid='$sid' AND  displaystatus != -1 AND time < now()");
	return $count;
}

########################################################
# Ugly yes, needed at the moment, yes
# $id is a discussion id. -Brian
sub checkDiscussionPostable {
	my($self, $id) = @_;
	return unless $id;

	# This should do it. 
	my $count = $self->sqlSelect('id', 'discussions', "id='$id' AND  type != 'archived' AND ts < now()");
	return unless $count;

	# Now, we are going to get paranoid and run the story checker against it
	my $sid;
	if ($sid = $self->getDiscussion($id, 'sid')) {
		return $self->checkStoryViewable($sid);
	}
	
	return 1;
}

########################################################
sub setSection {
	_genericSet('sections', 'section', '', @_);
}

########################################################
sub setSubSection {
	_genericSet('subsections', 'id', '', @_);
}

########################################################
sub createSection {
	my($self, $hash) = @_;

	$self->sqlInsert('sections', $hash);
}

########################################################
sub createSubSection {
	my($self, $section, $subsection, $artcount) = @_;

	$self->sqlInsert('subsections', {
		title		=> $subsection,
		section		=> $section,
		artcount	=> $artcount || 0,
	});
}

########################################################
sub removeSubSection {
	my($self, $section, $subsection) = @_;

	my $where;
	if ($subsection =~ /^\d+$/) {
		$where = 'id=' . $self->sqlQuote($subsection);
	} else {
		$where = sprintf 'name=%s AND title=%s',
			$self->sqlQuote($section),
			$self->sqlQuote($subsection);
	}

	$self->sqlDelete('subsections', $where);
}

########################################################
sub setDiscussionDelCount {
	my($self, $sid, $count) = @_;
	return unless $sid;

	my $where = '';
	if ($sid =~ /^\d+$/) {
		$where = "id=$sid";
	} else {
		$where = "sid=" . $self->sqlQuote($sid);
	}
	$self->sqlUpdate(
		'discussions',
		{
			-commentcount	=> "commentcount-$count",
			flags		=> "dirty",
		},
		$where
	);
}

########################################################
# Long term, this needs to be modified to take in account
# of someone wanting to delete a submission that is
# not part in the form
sub deleteSubmission {
	my($self, $subid) = @_;
	my $uid = getCurrentUser('uid');
	my $form = getCurrentForm();
	my %subid;

	if ($form->{subid}) {
		$self->sqlUpdate("submissions", { del => 1 },
			"subid=" . $self->sqlQuote($form->{subid})
		);

		# Brian mentions that this isn't atomic and that two updates
		# executing this code with the same UID will cause problems.
		# I say, that if you have 2 processes executing this code 
		# at the same time, with the same uid, that you have a SECURITY
		# BREACH. Caveat User.			- Cliff

		# I don't understand what would be a security
		# breach.  If someone has two windows open and
		# deletes from one, and while that request is
		# pending does it from the other, that's no
		# security breach. -- pudge

		$self->setUser($uid,
			{ deletedsubmissions => 
				getCurrentUser('deletedsubmissions') + 1,
		});
		$subid{$form->{subid}}++;
	}

	for (keys %{$form}) {
		# $form has several new internal variables that match this regexp, so 
		# the logic below should always check $t.
		next unless /(.*)_(.*)/;
		my($t, $n) = ($1, $2);
		if ($t eq "note" || $t eq "comment" || $t eq "section") {
			$form->{"note_$n"} = "" if $form->{"note_$n"} eq " ";
			if ($form->{$_}) {
				my %sub = (
					note	=> $form->{"note_$n"},
					comment	=> $form->{"comment_$n"},
					section	=> $form->{"section_$n"}
				);

				if (!$sub{note}) {
					delete $sub{note};
					$sub{-note} = 'NULL';
				}

				$self->sqlUpdate("submissions", \%sub,
					"subid=" . $self->sqlQuote($n));
			}
		} elsif ($t eq 'del') {
			$self->sqlUpdate("submissions", { del => 1 },
				'subid=' . $self->sqlQuote($n));
			$self->setUser($uid,
				{ -deletedsubmissions => 'deletedsubmissions+1' }
			);
			$subid{$n}++;
		}
	}

	return keys %subid;
}

########################################################
sub deleteSession {
	my($self, $uid) = @_;
	return unless $uid;
	$uid = defined($uid) || getCurrentUser('uid');
	if (defined $uid) {
		$self->sqlDo("DELETE FROM sessions WHERE uid=$uid");
	}
}

########################################################
sub deleteDiscussion {
	my($self, $did) = @_;

	$self->sqlDo("DELETE FROM discussions WHERE id=$did");
	my $comment_ids = $self->sqlSelectAll('cid', 'comments', "sid=$did");
	$self->sqlDo("DELETE FROM comments WHERE sid=$did");
	$self->sqlDo("DELETE FROM comment_text WHERE cid IN ("
		. join(",", map { $_->[0] } @$comment_ids)
		. ")") if @$comment_ids;
	$self->deleteModeratorlog({ sid => $did });
}

########################################################
sub deleteAuthor {
	my($self, $uid) = @_;
	$self->sqlDo("DELETE FROM sessions WHERE uid=$uid");
}

########################################################
sub deleteTopic {
	my($self, $tid) = @_;
	$self->sqlDo('DELETE from topics WHERE tid=' . $self->sqlQuote($tid));
}

########################################################
sub revertBlock {
	my($self, $bid) = @_;
	my $db_bid = $self->sqlQuote($bid);
	my $block = $self->{_dbh}->selectrow_array("SELECT block from backup_blocks WHERE bid=$db_bid");
	$self->sqlDo("update blocks set block = $block where bid = $db_bid");
}

########################################################
sub deleteBlock {
	my($self, $bid) = @_;
	$self->sqlDo('DELETE FROM blocks WHERE bid =' . $self->sqlQuote($bid));
}

########################################################
sub deleteTemplate {
	my($self, $tpid) = @_;
	$self->sqlDo('DELETE FROM templates WHERE tpid=' . $self->sqlQuote($tpid));
}

########################################################
sub deleteSection {
	my($self, $section) = @_;
	$self->sqlDo("DELETE from sections WHERE section='$section'");
}

########################################################
sub deleteContentFilter {
	my($self, $id) = @_;
	$self->sqlDo("DELETE from content_filters WHERE filter_id = $id");
}

########################################################
sub saveTopic {
	my($self, $topic) = @_;
	my($tid) = $topic->{tid} || 0;
	my($rows) = $self->sqlSelect('count(*)', 'topics', "tid=$tid");
	my $image = $topic->{image2} ? $topic->{image2} : $topic->{image};

	if ($rows == 0) {
		$self->sqlInsert('topics', {
			name	=> $topic->{name},
			image	=> $image,
			alttext	=> $topic->{alttext},
			width	=> $topic->{width},
			height	=> $topic->{height}
		});
		$tid = $self->getLastInsertId();
	} else {
		$self->sqlUpdate('topics', {
			image	=> $image,
			alttext	=> $topic->{alttext},
			width	=> $topic->{width},
			height	=> $topic->{height},
			name	=> $topic->{name},
		}, "tid=$tid");
	}

	return $tid;
}

##################################################################
# Another hated method -Brian
sub saveBlock {
	my($self, $bid) = @_;
	my($rows) = $self->sqlSelect('count(*)', 'blocks',
		'bid=' . $self->sqlQuote($bid)
	);

	my $form = getCurrentForm();
	if ($form->{save_new} && $rows > 0) {
		return $rows;
	}

	if ($rows == 0) {
		$self->sqlInsert('blocks', { bid => $bid, seclev => 500 });
	}

	my($portal, $retrieve) = (0, 0);

	# If someone marks a block as a portald block then potald is a portald
	# something tell me I may regret this...  -Brian
	$form->{type} = 'portald' if $form->{portal} == 1;

	# this is to make sure that a  static block doesn't get
	# saved with retrieve set to true
	$form->{retrieve} = 0 if $form->{type} ne 'portald';

	# If a block is a portald block then portal=1. type
	# is done so poorly -Brian
	$form->{portal} = 1 if $form->{type} eq 'portald';

	$form->{block} = $self->autoUrl($form->{section}, $form->{block})
		unless $form->{type} eq 'template';

	if ($rows == 0 || $form->{blocksavedef}) {
		$self->sqlUpdate('blocks', {
			seclev		=> $form->{bseclev},
			block		=> $form->{block},
			description	=> $form->{description},
			type		=> $form->{type},
			ordernum	=> $form->{ordernum},
			title		=> $form->{title},
			url		=> $form->{url},
			rdf		=> $form->{rdf},
			rss_template	=> $form->{rss_template},
			items		=> $form->{items},
			section		=> $form->{section},
			retrieve	=> $form->{retrieve},
			autosubmit	=> $form->{autosubmit},
			portal		=> $form->{portal},
		}, 'bid=' . $self->sqlQuote($bid));
		$self->sqlUpdate('backup_blocks', {
			block		=> $form->{block},
		}, 'bid=' . $self->sqlQuote($bid));
	} else {
		$self->sqlUpdate('blocks', {
			seclev		=> $form->{bseclev},
			block		=> $form->{block},
			description	=> $form->{description},
			type		=> $form->{type},
			ordernum	=> $form->{ordernum},
			title		=> $form->{title},
			url		=> $form->{url},
			rdf		=> $form->{rdf},
			rss_template	=> $form->{rss_template},
			items		=> $form->{items},
			section		=> $form->{section},
			retrieve	=> $form->{retrieve},
			portal		=> $form->{portal},
			autosubmit	=> $form->{autosubmit},
		}, 'bid=' . $self->sqlQuote($bid));
	}


	return $rows;
}

########################################################
sub saveColorBlock {
	my($self, $colorblock) = @_;
	my $form = getCurrentForm();

	my $db_bid = $self->sqlQuote($form->{color_block} || 'colors');

	if ($form->{colorsave}) {
		# save into colors and colorsback
		$self->sqlUpdate('blocks', {
				block => $colorblock,
			}, "bid = $db_bid"
		);

	} elsif ($form->{colorsavedef}) {
		# save into colors and colorsback
		$self->sqlUpdate('blocks', {
				block => $colorblock,
			}, "bid = $db_bid"
		);
		$self->sqlUpdate('backup_blocks', {
				block => $colorblock,
			}, "bid = $db_bid"
		);

	} elsif ($form->{colororig}) {
		# reload original version of colors
		my $block = $self->{_dbh}->selectrow_array("SELECT block FROM backup_blocks WHERE bid = $db_bid");
		$self->sqlDo("UPDATE blocks SET block = $block WHERE bid = $db_bid");
	}
}

########################################################
sub getSectionBlock {
	my($self, $section) = @_;
	my $block = $self->sqlSelectAll("section,bid,ordernum,title,portal,url,rdf,retrieve",
		"blocks", "section=" . $self->sqlQuote($section),
		"ORDER by ordernum"
	);

	return $block;
}

########################################################
sub getSectionBlocks {
	my($self) = @_;

	my $blocks = $self->sqlSelectAll("bid,title,ordernum", "blocks", "portal=1", "order by title");

	return $blocks;
}

########################################################
sub getAuthorDescription {
	my($self) = @_;
	my $authors = $self->sqlSelectAll('storycount, uid, nickname, homepage, bio',
		'authors_cache',
		'author = 1',
		'GROUP BY uid ORDER BY storycount DESC'
	);

	return $authors;
}

########################################################
# Someday we'll support closing polls, in which case this method
# may return 0 sometimes.
sub isPollOpen {
	my($self, $qid) = @_;
	return 1;
}

########################################################
# Has this "user" already voted in a particular poll?  "User" here is
# specially taken to mean a conflation of IP address (possibly thru proxy)
# and uid, such that only one anonymous reader can post from any given
# IP address.
sub hasVotedIn {
	my($self, $qid) = @_;

	my $md5 = md5_hex($ENV{REMOTE_ADDR} . $ENV{HTTP_X_FORWARDED_FOR});
	my $qid_quoted = $self->sqlQuote($qid);
	# Yes, qid/id/uid is a key in pollvoters.
	my($voters) = $self->sqlSelect('id', 'pollvoters',
		"qid=$qid_quoted AND id='$md5' AND uid=$ENV{SLASH_USER}"
	);

	# Should be a max of one row returned.  In any case, if any
	# data is returned, this "user" has already voted.
	return $voters ? 1 : 0;
}

########################################################
# Yes, I hate the name of this. -Brian
# Presumably because it also saves poll answers, and number of
# votes cast for those answers, and optionally attaches the
# poll to a story.  Can we think of a better name than
# "savePollQuestion"? - Jamie
sub savePollQuestion {
	my($self, $poll) = @_;
	$poll->{section} ||= getCurrentStatic('defaultsection');
	$poll->{voters} ||= "0";
	$poll->{autopoll} ||= "no";
	my $qid_quoted = "";
	$qid_quoted = $self->sqlQuote($poll->{qid}) if $poll->{qid};
	my $sid_quoted = "";
	$sid_quoted = $self->sqlQuote($poll->{sid}) if $poll->{sid};
	if ($poll->{qid}) {
		$self->sqlUpdate("pollquestions", {
			question	=> $poll->{question},
			voters		=> $poll->{voters},
			topic		=> $poll->{topic},
			autopoll	=> $poll->{autopoll},
			section		=> $poll->{section},
			-date		=>'now()'
		}, "qid	= $qid_quoted");
		$self->sqlUpdate("stories", {
			qid		=> $poll->{qid}
		}, "sid = $sid_quoted") if $sid_quoted;
	} else {
		$self->sqlInsert("pollquestions", {
			question	=> $poll->{question},
			voters		=> $poll->{voters},
			topic		=> $poll->{topic},
			section		=> $poll->{section},
			autopoll	=> $poll->{autopoll},
			uid		=> getCurrentUser('uid'),
			-date		=>'now()'
		});
		$poll->{qid} = $self->getLastInsertId();
		$qid_quoted = $self->sqlQuote($poll->{qid});
		$self->sqlUpdate("stories", {
			qid		=> $poll->{qid}
		}, "sid = $sid_quoted") if $sid_quoted;
	}

	$self->setVar("currentqid", $poll->{qid}) if $poll->{currentqid};

	# Loop through 1..8 and insert/update if defined
	for (my $x = 1; $x < 9; $x++) {
		if ($poll->{"aid$x"}) {
			my $votes = $poll->{"votes$x"};
			$votes = 0 if $votes !~ /^-?\d+$/;
			$self->sqlReplace("pollanswers", {
				aid	=> $x,
				qid	=> $poll->{qid},
				answer	=> $poll->{"aid$x"},
				votes	=> $votes,
			});

		} else {
			$self->sqlDo("DELETE from pollanswers
				WHERE qid=$qid_quoted AND aid=$x");
		}
	}
	return $poll->{qid};
}

########################################################
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

########################################################
sub getPollQuestionList {
	my($self, $offset, $other) = @_;
	my($where);
	$offset = 0 if $offset !~ /^\d+$/;

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
	$where .= sprintf ' AND section IN (%s)', join(',', @{$other->{section}})
		if $other->{section};
	$where .= sprintf ' AND section NOT IN (%s)', join(',', @{$other->{exclude_section}})
		if $other->{exclude_section} && @{$other->{section}};

	my $questions = $self->sqlSelectAll(
		'qid, question, date',
		'pollquestions',
		$where,
		"ORDER BY date DESC LIMIT $offset,20"
	);

	formatDate($questions, 2, 2, '%A, %B %e, %Y'); # '%F'

	return $questions;
}

########################################################
sub getPollAnswers {
	my($self, $qid, $val) = @_;
	my $qid_quoted = $self->sqlQuote($qid);
	my $values = join ',', @$val;
	my $answers = $self->sqlSelectAll($values, 'pollanswers',
		"qid=$qid_quoted", 'ORDER BY aid');

	return $answers;
}

########################################################
sub getPollQuestions {
# This may go away. Haven't finished poll stuff yet
#
	my($self, $limit) = @_;

	$limit = 25 if (!defined($limit));

	my $poll_hash_ref = {};
	my $sql = "SELECT qid,question FROM pollquestions ORDER BY date DESC ";
	$sql .= " LIMIT $limit " if $limit;
	my $sth = $self->{_dbh}->prepare_cached($sql);
	$sth->execute;
	while (my($id, $desc) = $sth->fetchrow) {
		$poll_hash_ref->{$id} = $desc;
	}
	$sth->finish;

	return $poll_hash_ref;
}

########################################################
sub deleteStory {
	my($self, $sid) = @_;
	$self->setStory($sid,
		{ writestatus => 'delete' }
	);
}

########################################################
sub setStory {
	my($self, $sid, $hashref) = @_;
	my(@param, %update_tables, $cache);
	# ??? should we do this?  -- pudge
	my $table_prime = 'sid';
	my $param_table = 'story_param';
	my $tables = [qw(
		stories story_text
	)];

	$cache = _genericGetCacheName($self, $tables);
	if ($hashref->{displaystatus} == 0) {
		my $section = $hashref->{section} ? $hashref->{section} : $self->getStory($sid, 'section');
		my $isolate = $self->getSection($section, 'isolate');
		$hashref->{displaystatus} = 1
			if ($isolate);
	}

	$hashref->{day_published} = $hashref->{'time'}
		if ($hashref->{'time'});

	for (keys %$hashref) {
		(my $clean_val = $_) =~ s/^-//;
		my $key = $self->{$cache}{$clean_val};
		if ($key) {
			push @{$update_tables{$key}}, $_;
		} else {
			push @param, [$_, $hashref->{$_}];
		}
	}

	for my $table (keys %update_tables) {
		my %minihash;
		for my $key (@{$update_tables{$table}}){
			$minihash{$key} = $hashref->{$key}
				if defined $hashref->{$key};
		}
		# Why the trailing "1" parameter, here? 
		$self->sqlUpdate($table, \%minihash, 'sid=' . $self->sqlQuote($sid), 1);
	}

	for (@param)  {
		$self->sqlReplace($param_table, {
			sid	=> $sid,
			name	=> $_->[0],
			value	=> $_->[1]
		}) if defined $_->[1];
	}
}

########################################################
# the the last time a user submitted a form successfuly
sub getSubmissionLast {
	my($self, $formname) = @_;

	my $where = $self->_whereFormkey();
	my($last_submitted) = $self->sqlSelect(
		"max(submit_ts)",
		"formkeys",
		"$where AND formname = '$formname'");
	$last_submitted ||= 0;

	return $last_submitted;
}

########################################################
# get the last timestamp user created  or
# submitted a formkey
sub getLastTs {
	my($self, $formname, $submitted) = @_;

	my $tscol = $submitted ? 'submit_ts' : 'ts';
	my $where = $self->_whereFormkey();
	$where .= " AND formname =  '$formname'";
	$where .= ' AND value = 1' if $submitted;

	my($last_created) = $self->sqlSelect(
		"max($tscol)",
		"formkeys",
		$where);
	$last_created ||= 0;
}

########################################################
sub _getLastFkCount {
	my($self, $formname) = @_;

	my $where = $self->_whereFormkey();
	my($idcount) = $self->sqlSelect(
		"max(idcount)",
		"formkeys",
		"$where AND formname = '$formname'");
	$idcount ||= 0;

}

########################################################
# gives a true or false of whether the system has given
# out more than the allowed unused formkeys per form
# over the formkey timeframe
sub getUnsetFkCount {
	my($self, $formname) = @_;
	my $constants = getCurrentStatic();

	my $formkey_earliest = time() - $constants->{formkey_timeframe};
	my $where = $self->_whereFormkey();
	$where .=  " AND formname = '$formname'";
	$where .= " AND ts >= $formkey_earliest";
	$where .= " AND value = 0";

	my $unused = 0;

	my $max_unused = $constants->{"max_${formname}_unusedfk"};

	if ($max_unused) {
		($unused) = $self->sqlSelect(
			"count(*) >= $max_unused",
			"formkeys",
			$where);

		return $unused;

	} else {
		return(0);
	}
}

########################################################
sub updateFormkeyId {
	my($self, $formname, $formkey, $uid, $rlogin, $upasswd) = @_;

	if (! isAnon($uid) && $rlogin && length($upasswd) > 1) {
		my $constants = getCurrentStatic();
		my $last_count = $self->_getLastFkCount($formname);
		$self->sqlUpdate("formkeys", {
				uid	=> $uid,
				idcount	=> $last_count,
			},
			"formname='$formname' AND uid = $constants->{anonymous_coward_uid} AND formkey=" .
			$self->sqlQuote($formkey)
		);
	}
}

########################################################
sub createFormkey {
	my($self, $formname) = @_;

	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $ipid = getCurrentUser('ipid');
	my $subnetid = getCurrentUser('subnetid');

	my $last_count = $self->_getLastFkCount($formname);
	my $last_submitted = $self->getLastTs($formname, 1);

	my $formkey = "";
	my $num_tries = 50;
	while (1) {
		$formkey = getFormkey();
		my $rows = $self->sqlInsert('formkeys', {
			formkey         => $formkey,
			formname        => $formname,
			uid             => $ENV{SLASH_USER},
			ipid            => $ipid,
			subnetid        => $subnetid,
			value           => 0,
			ts              => time(),
			last_ts         => $last_submitted,
			idcount         => $last_count,
		});
		last if $rows;
		# The INSERT failed because $formkey is already being
		# used.  Keep retrying as long as is reasonably possible.
		if (--$num_tries <= 0) {
			# Give up!
			print STDERR scalar(localtime)
				. "createFormkey failed: $formkey\n";
			$formkey = "";
			last;
		}
	}
	# save in form object for printing to user
	$form->{formkey} = $formkey;
	return $formkey ? 1 : 0;
}

########################################################
sub checkResponseTime {
	my($self, $formname) = @_;

	my $constants = getCurrentStatic();
	my $form = getCurrentForm();

	my $now =  time();

	my $response_limit = $constants->{"${formname}_response_limit"} || 0;

	# 1 or 0
	my($response_time) = $self->sqlSelect("$now - ts", 'formkeys',
		'formkey = ' . $self->sqlQuote($form->{formkey}));

	if ($constants->{DEBUG}) {
		print STDERR "SQL select $now - ts from formkeys where formkey = '$form->{formkey}'\n";
		print STDERR "LIMIT REACHED $response_time\n";
	}

	return ($response_time < $response_limit && $response_time > 0) ? $response_time : 0;
}

########################################################
# This used to return boolean, 1=valid, 0=invalid.  Now it returns
# "ok", "invalid", or "invalidhc".  The two "invalid*" responses
# function somewhat the same (but print different error messages,
# and "invalidhc" can be retried several times before the formkey
# is invalidated).
sub validFormkey {
	my($self, $formname, $options) = @_;

	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $uid = getCurrentUser('uid');
	my $subnetid = getCurrentUser('subnetid');

	undef $form->{formkey} unless $form->{formkey} =~ /^\w{10}$/;
	return 'invalid' if !$form->{formkey};
	my $formkey_quoted = $self->sqlQuote($form->{formkey});

	my $formkey_earliest = time() - $constants->{formkey_timeframe};

	my $where = $self->_whereFormkey();
	$where = "($where OR subnetid = '$subnetid')"
		if $constants->{lenient_formkeys} && isAnon($uid);
	my($is_valid) = $self->sqlSelect(
		'COUNT(*)',
		'formkeys',
		"formkey = $formkey_quoted
		 AND $where
		 AND ts >= $formkey_earliest AND formname = '$formname'"
	);
	print STDERR "ISVALID $is_valid\n" if $constants->{DEBUG};
	return 'invalid' if !$is_valid;
 
	# If we're using the HumanConf plugin, check for its validity
	# as well.
	return 'ok' if $options->{no_hc};
	my $hc = getObject("Slash::HumanConf");
	return 'ok' if !$hc;
	return $hc->validFormkeyHC($formname);
}

##################################################################
sub getFormkeyTs {
	my($self, $formkey, $ts_flag) = @_;

	my $constants = getCurrentStatic();

	my $tscol = $ts_flag == 1 ? 'submit_ts' : 'ts';

	my($ts) = $self->sqlSelect(
		$tscol,
		"formkeys",
		"formkey=" . $self->sqlQuote($formkey));

	print STDERR "FORMKEY TS $ts\n" if $constants->{DEBUG};
	return($ts);
}

##################################################################
# two things at once. Validate and increment
sub updateFormkeyVal {
	my($self, $formname, $formkey) = @_;

	my $constants = getCurrentStatic();

	my $formkey_quoted = $self->sqlQuote($formkey);

	my $where = "value = 0";

	# Before the transaction-based version was written, we
	# did something like this, which Patrick noted seemed
	# to cause difficult-to-track errors.
	# my $speed_limit = $constants->{"${formname}_speed_limit"};
	# my $maxposts = $constants->{"max_${formname}_allowed"} || 0;
	# my $min = time() - $speed_limit;
	# $where .= " AND idcount < $maxposts";
	# $where .= " AND last_ts <= $min";

	# print STDERR "MIN $min MAXPOSTS $maxposts WHERE $where\n" if $constants->{DEBUG};

	# increment the value from 0 to 1 (shouldn't ever get past 1)
	# this does two things: increment the value (meaning the formkey
	# can't be used again) and also gives a true/false value
	my $updated = $self->sqlUpdate("formkeys", {
		-value		=> 'value+1',
		-idcount	=> 'idcount+1',
	}, "formkey=$formkey_quoted AND $where");

	$updated = int($updated);

	print STDERR "UPDATED formkey var $updated\n" if $constants->{DEBUG};
	return($updated);
}

##################################################################
# use this in case the function you call fails prior to updateFormkey
# but after updateFormkeyVal
sub resetFormkey {
	my($self, $formkey) = @_;

	my $constants = getCurrentStatic();

	# reset the formkey to 0, and reset the ts
	my $updated = $self->sqlUpdate("formkeys", {
		-value		=> 0,
		-idcount	=> '(idcount -1)',
		ts		=> time(),
		submit_ts	=> '0',
	}, "formkey=" . $self->sqlQuote($formkey));

	print STDERR "RESET formkey $updated\n" if $constants->{DEBUG};
	return($updated);
}

##################################################################
sub updateFormkey {
	my($self, $formkey, $length) = @_;
	$formkey  ||= getCurrentForm('formkey');

	my $constants = getCurrentStatic();

	# update formkeys to show that there has been a successful post,
	# and increment the value from 0 to 1 (shouldn't ever get past 1)
	# meaning that yes, this form has been submitted, so don't try i t again.
	my $updated = $self->sqlUpdate("formkeys", {
		submit_ts	=> time(),
		content_length	=> $length,
	}, "formkey=" . $self->sqlQuote($formkey));

	print STDERR "UPDATED formkey $updated\n" if $constants->{DEBUG};
	return($updated);
}

##################################################################
sub checkPostInterval {
	my($self, $formname) = @_;
	$formname ||= getCurrentUser('currentPage');

	my $constants = getCurrentStatic();
	my $speedlimit = $constants->{"${formname}_speed_limit"} || 0;
	my $formkey_earliest = time() - $constants->{formkey_timeframe};

	my $where = $self->_whereFormkey();
	$where .= " AND formname = '$formname' ";
	$where .= "AND ts >= $formkey_earliest";

	my $now = time();
	my($interval) = $self->sqlSelect(
		"$now - max(submit_ts)",
		"formkeys",
		$where);

	$interval ||= 0;
	print STDERR "CHECK INTERVAL $interval speedlimit $speedlimit\n" if $constants->{DEBUG};

	return ($interval < $speedlimit && $speedlimit > 0) ? $interval : 0;
}

##################################################################
sub checkMaxReads {
	my($self, $formname) = @_;
	my $constants = getCurrentStatic();

	my $maxreads = $constants->{"max_${formname}_viewings"} || 0;
	my $formkey_earliest = time() - $constants->{formkey_timeframe};

	my $where = $self->_whereFormkey();
	$where .= " AND formname = '$formname'";
	$where .= " AND ts >= $formkey_earliest";
	$where .= " HAVING count >= $maxreads";

	my($limit_reached) = $self->sqlSelect(
		"COUNT(*) AS count",
		"formkeys",
		$where);

	return $limit_reached ? $limit_reached : 0;
}

##################################################################
sub checkMaxPosts {
	my($self, $formname) = @_;
	my $constants = getCurrentStatic();
	$formname ||= getCurrentUser('currentPage');

	my $formkey_earliest = time() - $constants->{formkey_timeframe};
	my $maxposts = 0;
	if ($constants->{"max_${formname}_allowed"}) {
		$maxposts = $constants->{"max_${formname}_allowed"};
	} elsif ($formname =~ m{/}) {
		# If the formname is in the format "users/nu", that means
		# it also counts as a formname of "users" for this purpose.
		(my $formname_main = $formname) =~ s{/.*}{};
		if ($constants->{"max_${formname_main}_allowed"}) {
			$maxposts = $constants->{"max_${formname_main}_allowed"};
		}
	}

	my $where = $self->_whereFormkey();
	$where .= " AND submit_ts >= $formkey_earliest";
	$where .= " AND formname = '$formname'",
	$where .= " HAVING count >= $maxposts";

	my($limit_reached) = $self->sqlSelect(
		"COUNT(*) AS count",
		"formkeys",
		$where);

	if ($constants->{DEBUG}) {
		print STDERR "LIMIT REACHED (times posted) $limit_reached\n";
		print STDERR "LIMIT REACHED limit_reached maxposts $maxposts\n";
	}

	return $limit_reached ? $limit_reached : 0;
}

##################################################################
sub checkTimesPosted {
	my($self, $formname, $max, $formkey_earliest) = @_;

	my $where = $self->_whereFormkey();
	my($times_posted) = $self->sqlSelect(
		"count(*) as times_posted",
		'formkeys',
		"$where AND submit_ts >= $formkey_earliest AND formname = '$formname'");

	return $times_posted >= $max ? 0 : 1;
}

##################################################################
# the form has been submitted, so update the formkey table
# to indicate so
sub formSuccess {
	my($self, $formkey, $cid, $length) = @_;

	# update formkeys to show that there has been a successful post,
	# and increment the value from 0 to 1 (shouldn't ever get past 1)
	# meaning that yes, this form has been submitted, so don't try i t again.
	$self->sqlUpdate("formkeys", {
			-value          => 'value+1',
			cid             => $cid,
			submit_ts       => time(),
			content_length  => $length,
		}, "formkey=" . $self->sqlQuote($formkey)
	);
}

##################################################################
sub formFailure {
	my($self, $formkey) = @_;
	$self->sqlUpdate("formkeys", {
			value   => -1,
		}, "formkey=" . $self->sqlQuote($formkey)
	);
}

##################################################################
# logs attempts to break, fool, flood a particular form
sub createAbuse {
	my($self, $reason, $script_name, $query_string, $uid, $ipid, $subnetid) = @_;

	my $user = getCurrentUser();
	$uid      ||= $user->{uid};
	$ipid     ||= $user->{ipid};
	$subnetid ||= $user->{subnetid};

	# logem' so we can banem'
	$self->sqlInsert("abusers", {
		uid		=> $uid,
		ipid		=> $ipid,
		subnetid	=> $subnetid,
		pagename	=> $script_name,
		querystring	=> $query_string || '',
		reason		=> $reason,
		-ts		=> 'now()',
	});
}

##################################################################
sub setExpired {
	my($self, $uid) = @_;

	if  (! $self->checkExpired($uid)) {
		$self->setUser($uid, { expired => 1});
		$self->sqlInsert('accesslist', {
			-uid		=> $uid,
			formname 	=> 'comments',
			-readonly	=> 1,
			-ts		=> 'now()',
			reason		=> 'expired'
		}) if $uid ;
	}
}

##################################################################
sub setUnexpired {
	my($self, $uid) = @_;

	if ($self->checkExpired($uid)) {
		$self->setUser($uid, { expired => 0});
		my $sql = "WHERE uid = $uid AND reason = 'expired' AND formname = 'comments'";
		$self->sqlDo("DELETE from accesslist $sql") if $uid;
	}
}

##################################################################
sub checkExpired {
	my($self, $uid) = @_;
	return 0 if !$uid;

	my $where = "uid = $uid AND readonly = 1 AND reason = 'expired'";

	$self->sqlSelect(
		"readonly",
		"accesslist", $where
	);
}

##################################################################
sub checkReadOnly {
	my($self, $formname, $user_check) = @_;

	$user_check ||= getCurrentUser();  # might not be actual current user!
	my $constants = getCurrentStatic();

	my $where = '';

	# please check to make sure this is what you want;
	# isAnon already checks for numeric uids -- pudge
	if ($user_check->{uid} && $user_check->{uid} =~ /^\d+$/) {
		if (!isAnon($user_check->{uid})) {
			$where = "uid = $user_check->{uid}";
		} else {
			$where = "ipid = '$user_check->{ipid}'";
		}
	} elsif ($user_check->{md5id}) {
		# Note, this is a slow query -- either column by itself is
		# fast since they're both indexed, but if you OR them, it's
		# about 10-12 seconds, MySQL is weird sometimes.  Good thing
		# we rarely (ever?) do this.
		$where = "(ipid = '$user_check->{md5id}' OR subnetid = '$user_check->{md5id}')";

	} elsif ($user_check->{ipid}) {
		my $tmpid = $user_check->{ipid} =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}/ ? 
				md5_hex($user_check->{ipid}) : $user_check->{ipid}; 
		$where = "ipid = '$tmpid'";

	} elsif ($user_check->{subnetid}) {
		my $tmpid = $user_check->{subnetid} =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}/ ? 
				md5_hex($user_check->{subnetid}) : $user_check->{subnetid}; 
		$where = "subnetid = '$tmpid'";
	} else {
		my $tmpid = $user_check->{ipid} =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}/ ? 
				md5_hex($user_check->{ipid}) : $user_check->{ipid}; 
		$where = "ipid = '$tmpid'";
	}

	$where .= " AND readonly = 1 AND formname = '$formname' AND reason != 'expired'";

	$self->sqlSelect("readonly", "accesslist", $where);
}

##################################################################
sub getUIDList {
	my($self, $column, $id) = @_;

	my $where = '';
	$id = md5_hex($id) if length($id) != 32;
	if ($column eq 'md5id') {
		# Avoid this when possible, the OR makes the query slow.
		$where = "ipid = '$id' OR subnetid = '$id'";
	} elsif ($column =~ /^(ipid|subnetid)$/) {
		$where = "$column = '$id'";
	} else {
		return [ ];
	}
	return $self->sqlSelectAll("DISTINCT uid ", "comments", $where);
}

##################################################################
sub getNetIDList {
	my($self, $id) = @_;
	my $vislength = getCurrentStatic('id_md5_vislength');
	my $column4 = "ipid";
	$column4 = "SUBSTRING(ipid, 1, $vislength)" if $vislength;
	$self->sqlSelectAll(
		"ipid,
		MIN(SUBSTRING(date, 1, 10)) AS dmin, MAX(SUBSTRING(date, 1, 10)) AS dmax,
		COUNT(*) AS c, $column4",
		"comments",
		"uid = '$id' AND ipid != ''",
		"GROUP BY ipid ORDER BY dmax DESC, dmin DESC, c DESC, ipid ASC LIMIT 100"
	);
}

########################################################
sub getBanList {
	my($self, $refresh) = @_;
	my $constants = getCurrentStatic();
	
	_genericCacheRefresh($self, 'banlist', $constants->{'banlist_expire'});
	my $banlist_ref = $self->{'_banlist_cache'} ||= {};

	%$banlist_ref = () if $refresh;

	if (! keys %$banlist_ref) {
		my $sth = $self->{_dbh}->prepare("SELECT ipid,subnetid,uid from accesslist WHERE isbanned = 1");
		$sth->execute;
		my $list = $sth->fetchall_arrayref;
		for (@$list) {
			$banlist_ref->{$_->[0]} = 1 if $_->[0] ne '';
			$banlist_ref->{$_->[1]} = 1 if $_->[1] ne '';
			$banlist_ref->{$_->[2]} = 1 if ($_->[2] ne '' and $_->[2] ne $constants->{'anon_coward_uid'});
		}
		# why this? in case there are no banned users.
		$banlist_ref->{'junk'} = 1;
	}

	return $banlist_ref;
}

##################################################################
sub getAccessList {
	my($self, $min, $flag) = @_;
	$min ||= 0;
	my $max = $min + 100;

	my $where = "WHERE $flag = 1";
	$self->sqlSelectAll("ts, uid, ipid, subnetid, formname, reason", "accesslist $where order by ts DESC limit $min, $max");
}

##################################################################
sub getTopAbusers {
	my($self, $min) = @_;
	$min ||= 0;
	my $max = $min + 100;
	my $where = "GROUP BY ipid ORDER BY abusecount DESC LIMIT $min,$max";
	$self->sqlSelectAll("count(*) AS abusecount,uid,ipid,subnetid", "abusers $where");
}

##################################################################
sub getAbuses {
	my($self, $key, $id) = @_;
	my $where = {
		uid => "uid = $id",
		ipid => "ipid = '$id'",
		subnetid => "subnetid = '$id'",
	};

	$self->sqlSelectAll("ts,uid,ipid,subnetid,pagename,reason", "abusers WHERE $where->{$key} ORDER by ts DESC");

}

##################################################################
sub getAccessListReason {
	my($self, $formname, $column, $user_check) = @_;

	my $constants = getCurrentStatic();
	my $ref = {};
	my($reason,$where) = ('','');

	if ($user_check) {
		if ($user_check->{uid} =~ /^\d+$/ && !isAnon($user_check->{uid})) {
			$where = "WHERE uid = $user_check->{uid}";
		} elsif ($user_check->{md5id}) {
			$where = "WHERE ipid = '$user_check->{md5id}'";
		} elsif ($user_check->{ipid}) {
			$where = "WHERE ipid = '$user_check->{ipid}'";
		} elsif ($user_check->{subnetid}) {
			$where = "WHERE subnetid = '$user_check->{subnetid}'";
		} else {
			return "";
		}
	} else {
		$user_check = $self->getCurrentUser();
		$where = "WHERE (ipid = '$user_check->{ipid}' OR subnetid = '$user_check->{subnetid}')";
	}

	if ($column eq 'isbanned') {
		$where .= " AND isbanned = 1";
	} else {
		$where .= " AND readonly = 1 AND formname = '$formname' AND reason != 'expired'";
	}
	

	$ref = $self->sqlSelectAll("reason", "accesslist $where");

	for (@$ref) {
		if ($reason eq '') {
			$reason = $_->[0];
		} elsif ($reason ne $_->[0]) {
			$reason = 'multiple';
			return($reason);
		}
	}

	return($reason);
}

##################################################################
sub setAccessList {
	# do not use this method to set/unset expired
	my($self, $formname, $user_check, $setflag, $column, $reason) = @_;

	return if $reason eq 'expired';

	my $insert_hashref = {};
#	print STDERR "banned $column\n";
	$insert_hashref->{"-$column"} = 1;
	my $constants = getCurrentStatic();
	my $rows;

	my $where = "/* setAccessList $column WHERE clause */";

	if ($user_check) {
		if ($user_check->{uid} =~ /^\d+$/ && !isAnon($user_check->{uid})) {
			$where .= "uid = $user_check->{uid}";
			$insert_hashref->{-uid} = $user_check->{uid};

		} elsif ($user_check->{ipid}) {
			$where .= "ipid = '$user_check->{ipid}'";
			$insert_hashref->{ipid} = $user_check->{ipid};

		} elsif ($user_check->{subnetid}) {
			$where .= "subnetid = '$user_check->{subnetid}'";
			$insert_hashref->{subnetid} = $user_check->{subnetid};
		}

	} else {
		$user_check = getCurrentUser();
		$where = "(ipid = '$user_check->{ipid}' OR subnetid = '$user_check->{subnetid}')";
	}

	$where .= " AND formname = '$formname' AND reason != 'expired'" if $column eq 'readonly';
	$insert_hashref->{formname} = $formname if $formname ne '';
	$insert_hashref->{reason} = $reason if $reason ne '';
	$insert_hashref->{-ts} = 'now()';

	$rows = $self->sqlSelect("count(*) FROM accesslist WHERE $where AND $column = 1");
	$rows ||= 0;

	if ($setflag == 0) {
		if ($rows > 0) {
			$self->sqlDo("DELETE from accesslist WHERE $where");
		}
	} else {
		if ($rows > 0) {
			my $return = $self->sqlUpdate("accesslist", {
				"-$column" => $setflag,
				reason		=> $reason,
			}, $where);

			return $return ? 1 : 0;
		} else {
			my $return = $self->sqlInsert("accesslist", $insert_hashref);
			return $return ? 1 : 0;
		}
	}
}

##################################################################
# Check to see if the formkey already exists
# i know this slightly overlaps what checkForm does, but checkForm
# returns data i don't want, and checks for formname which isn't
# necessary, since formkey is a unique key
sub existsFormkey {
	my($self, $formkey) = @_;
	my $keycheck = $self->sqlSelect("formkey", "formkeys", "formkey='$formkey'");
	return $keycheck eq $formkey ? 1 : 0;
}


##################################################################
# Check to see if the form already exists
sub checkForm {
	my($self, $formkey, $formname) = @_;
	$self->sqlSelect(
		"value,submit_ts",
		"formkeys",
		"formkey=" . $self->sqlQuote($formkey)
			. " AND formname = '$formname'"
	);
}

##################################################################
# Current admin users
sub currentAdmin {
	my($self) = @_;
	my $aids = $self->sqlSelectAll(
		'nickname,lasttime,lasttitle,last_subid,last_sid,sessions.uid',
		'sessions,users',
		'sessions.uid=users.uid GROUP BY sessions.uid'
	);

	return $aids;
}

########################################################
#
sub getTopNewsstoryTopics {
	my($self, $all) = @_;
	my $when = "AND to_days(now()) - to_days(time) < 14" unless $all;
	my $order = $all ? "ORDER BY alttext" : "ORDER BY cnt DESC";
	my $topics = $self->sqlSelectAll("topics.tid, alttext, image, width, height, count(*) as cnt",
		'topics,stories',
		"topics.tid=stories.tid
		$when
		GROUP BY topics.tid
		$order"
	);

	return $topics;
}

##################################################################
# Get poll
# Until today, this has returned an arrayref of arrays, each
# subarray having 5 values (question, answer, aid, votes, qid).
# Since sid can no longer point to more than one poll, there
# can now be only one question, so there's no point in repeating
# it;  the return format is now a hashref.  Only one place in the
# core code calls this (Slash::Utility::Display::pollbooth) and
# only one template (pollbooth;misc;default) uses its values;
# both have been updated of course.  - Jamie 2002/04/03
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
	my @answers = ( );
	for my $aid (sort
		{ $answers_hr->{$a}{aid} <=> $answers_hr->{$b}{aid} }
		keys %$answers_hr) {
		push @answers, {
			answer =>	$answers_hr->{$aid}{answer},
			aid =>		$answers_hr->{$aid}{aid},
			votes =>	$answers_hr->{$aid}{votes},
		};
	}
	return {
		pollq =>	$pollq,
		answers =>	\@answers
	};
}

##################################################################
sub getSubmissionsSections {
	my($self) = @_;
	my $del = getCurrentForm('del');

	my $hash = $self->sqlSelectAll("section,note,count(*)", "submissions WHERE del=$del GROUP BY section,note");

	return $hash;
}

##################################################################
# Get submission count
sub getSubmissionsPending {
	my($self, $uid) = @_;
	my $submissions;

	if ($uid) {
		$submissions = $self->sqlSelectAll("time, subj, section, tid, del", "submissions", "uid=$uid");
	} else {
		$uid = getCurrentUser('uid');
		$submissions = $self->sqlSelectAll("time, subj, section, tid, del", "submissions", "uid=$uid");
	}
	return $submissions;
}

##################################################################
# Get submission count
sub getSubmissionCount {
	my($self, $articles_only) = @_;
	my($count);
	my $section = getCurrentUser('section');
	if ($articles_only) {
		$count = $self->sqlSelect('count(*)', 'submissions',
			"del=0 and section='articles' and note != ''"
		);
	} elsif ($section) {
		$section = $self->sqlQuote($section);
		$count = $self->sqlSelect("count(*)", "submissions",
			"(length(note)<1 or isnull(note)) and del=0 AND section = $section"
		);
	} else {
		$count = $self->sqlSelect("count(*)", "submissions",
			"(length(note)<1 or isnull(note)) and del=0"
		);
	}
	return $count;
}

##################################################################
# Get all portals
sub getPortals {
	my($self) = @_;
	my $strsql = "SELECT block,title,blocks.bid,url
		   FROM blocks
		  WHERE section='index'
		    AND type='portald'
		  GROUP BY bid
		  ORDER BY ordernum";

	my $sth = $self->{_dbh}->prepare($strsql);
	$sth->execute;
	my $portals = $sth->fetchall_arrayref;

	return $portals;
}

##################################################################
# Get standard portals
sub getPortalsCommon {
	my($self) = @_;
	return($self->{_boxes}, $self->{_sectionBoxes}) if keys %{$self->{_boxes}};
	$self->{_boxes} = {};
	$self->{_sectionBoxes} = {};
	my $sth = $self->sqlSelectMany(
			'bid,title,url,section,portal,ordernum',
			'blocks',
			'',
			'ORDER BY ordernum ASC'
	);
	# We could get rid of tmp at some point
	my %tmp;
	while (my $SB = $sth->fetchrow_hashref) {
		$self->{_boxes}{$SB->{bid}} = $SB;  # Set the Slashbox
		next unless $SB->{ordernum} > 0;  # Set the index if applicable
		push @{$tmp{$SB->{section}}}, $SB->{bid};
	}
	$self->{_sectionBoxes} = \%tmp;
	$sth->finish;

	return($self->{_boxes}, $self->{_sectionBoxes});
}

##################################################################
# Heaps are not optimized for count; use main comments table
sub countCommentsByGeneric {
	my($self, $where_clause) = @_;
	return $self->sqlCount('comments', $where_clause);
}

##################################################################
sub countCommentsBySid {
	my($self, $sid) = @_;
	return 0 if !$sid;
	return $self->countCommentsByGeneric("sid=$sid");
}

##################################################################
sub countCommentsByUID {
	my($self, $uid) = @_;
	return 0 if !$uid;
	return $self->countCommentsByGeneric("uid=$uid");
}

##################################################################
sub countCommentsBySubnetID {
	my($self, $subnetid) = @_;
	return 0 if !$subnetid;
	return $self->countCommentsByGeneric("subnetid='$subnetid'");
}

##################################################################
sub countCommentsByIPID {
	my($self, $ipid) = @_;
	return 0 if !$ipid;
	return $self->countCommentsByGeneric("ipid='$ipid'");
}

##################################################################
sub countCommentsByIPIDOrSubnetID {
	my($self, $id) = @_;
	return 0 if !$id;
	return $self->countCommentsByGeneric("ipid='$id' OR subnetid='$id'");
}

##################################################################
sub countCommentsBySidUID {
	my($self, $sid, $uid) = @_;
	return 0 if !$sid or !$uid;
	return $self->countCommentsByGeneric("sid=$sid AND uid=$uid");
}

##################################################################
sub countCommentsBySidPid {
	my($self, $sid, $pid) = @_;
	return 0 if !$sid or !$pid;
	return $self->countCommentsByGeneric("sid=$sid AND pid=$pid");
}

##################################################################
# Search on block comparison! No way, easier on everything
# if we just do a match on the signature (AKA MD5 of the comment)
# -Brian
sub findCommentsDuplicate {
	my($self, $sid, $comment) = @_;
	my $sid_quoted = $self->sqlQuote($sid);
	my $signature_quoted = $self->sqlQuote(md5_hex($comment));
	return $self->sqlCount('comments', "sid=$sid_quoted AND signature=$signature_quoted");
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

##################################################################
sub checkForMetaModerator {
	my($self, $user) = @_;

	# Easy tests the user can fail to be ineligible to metamod.
	return 0 if $user->{is_anon}
		|| !$user->{willing}
		||  $user->{karma} < 0
		||  $user->{rtbl};

	# Not eligible if has already metamodded today.
	my $current_date = time2str("%Y-%m-%d", time, 'GMT');
	return 0 if $user->{lastmm} eq $current_date;

	# Last test, have to hit the DB for this one.
	my($tuid) = $self->sqlSelect('max(uid)', 'users_count');
	return 0 if $user->{uid} >
		  $tuid * $self->getVar('m2_userpercentage', 'value');

	# User is OK to metamod.
	return 1;
}

##################################################################
sub getAuthorNames {
	my($self) = @_;
	my $authors = $self->getDescriptions('authors');
	my @authors;
	for (values %$authors){
		push @authors, $_;
	}

	return [sort(@authors)];
}

##################################################################
# Oranges to Apples. Would it be faster to grab some of this
# data from the cache? Or is it just as fast to grab it from
# the database?
sub getStoryByTime {
	my($self, $sign, $story, $section, $limit) = @_;
	my $where;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	$limit ||= '1';

	# We only do getStoryByTime() for stories that are more recent
	# than twice the story archiving delay.  If the DB has to scan
	# back thousands of stories, this can really bog.  We solve
	# this by having the first clause in the WHERE be an impossible
	# condition for any stories that are too old (this is more
	# straightforward than parsing the timestamp in perl).
	my $time = $story->{time};
	my $twice_arch_delay = $constants->{archive_delay}*2;
	$twice_arch_delay = 7 if $twice_arch_delay < 7;

	my $order = $sign eq '<' ? 'DESC' : 'ASC';
	if ($section->{isolate}) {
		$where  = ' AND displaystatus>=0 AND section=' .
			  $self->sqlQuote($story->{'section'})
	} elsif ($user->{sectioncollapse}) {
		$where .= ' AND displaystatus>=0';
	} else {
		$where .= ' AND displaystatus=0';
	}

	$where .= "   AND tid not in ($user->{'extid'})" if $user->{'extid'};
	$where .= "   AND uid not in ($user->{'exaid'})" if $user->{'exaid'};
	$where .= "   AND section not in ($user->{'exsect'})" if $user->{'exsect'};
	$where .= "   AND sid != '$story->{'sid'}'";

	my $returnable = $self->sqlSelectHashref(
			'title, sid, section, tid',
			'stories',
			
			"'$time' > DATE_SUB(NOW(), INTERVAL $twice_arch_delay DAY)
			 AND time $sign '$time'
			 AND time < NOW()
			 AND writestatus != 'delete'
			 $where",

			"ORDER BY time $order LIMIT $limit"
	);

	return $returnable;
}

##################################################################
# admin.pl only
sub getStoryByTimeAdmin {
	my($self, $sign, $story, $limit) = @_;
	my($where);
	my $user = getCurrentUser();
	$limit ||= '1';

	my $order = $sign eq '<' ? 'DESC' : 'ASC';

	$where .= "   AND sid != '$story->{'sid'}'";

	my $time = $story->{'time'};
	my $returnable = $self->sqlSelectAllHashrefArray(
			'title, sid, time',
			'stories',
			"time $sign '$time' AND writestatus != 'delete' $where",
			"ORDER BY time $order LIMIT $limit"
	);

	return $returnable;
}

########################################################
sub setModeratorVotes {
	my($self, $uid, $metamod) = @_;
	$self->sqlUpdate("users_info", {
		-m2unfairvotes	=> "m2unfairvotes+$metamod->{unfair}",
		-m2fairvotes	=> "m2fairvotes+$metamod->{fair}",
		-lastmm		=> 'now()',
		lastmmid	=> 0
	}, "uid=$uid");
}

########################################################
sub setMetaMod {
	my($self, $m2victims, $flag, $ts) = @_;

	my $constants = getCurrentStatic();
	my $returns = [];

	# Update $muid's Karma
	$self->sqlTransactionStart(qq(
LOCK TABLES users_info WRITE, metamodlog WRITE, moderatorlog WRITE
	));
	for (keys %{$m2victims}) {
		my $muid = $m2victims->{$_}[0];
		my $val = $m2victims->{$_}[1];
		next unless $val;
		push(@$returns , [$muid, $val]);

		my $mmid = $_;
		if ($muid && $val) {
			if ($val eq '+') {
				$self->sqlUpdate("users_info", {
					-m2fair => "m2fair+1"
				}, "uid=$muid");

				# Karma changes are now deferred until reconcile time.
				#
				#$self->sqlUpdate(
				#	"users_info", { -karma => "karma+1" },
				#	"$muid=uid AND
				#	karma<$constants->{m2_maxbonus}"
				#);
			} elsif ($val eq '-') {
				$self->sqlUpdate("users_info", {
					-m2unfair => "m2unfair+1",
				}, "uid=$muid");

				# Karma changes are now deferred until reconcile time.
				#
				#$self->sqlUpdate(
				#	"users_info", { -karma => "karma-1" },
				#	"$muid=uid AND
				#	karma>$constants->{badkarma}"
				#);
			}
		}
		# Time is now fixed at form submission time to ease 'debugging'
		# of the moderation system, ie 'GROUP BY uid, ts' will give
		# you the M2 votes for a specific user ordered by M2 'session'
		$self->sqlInsert("metamodlog", {
			-mmid => $mmid,
			-uid  => $ENV{SLASH_USER},
			-val  => ($val eq '+') ? '+1' : '-1',
			-ts   => "from_unixtime($ts)",
			-flag => $flag
		});
		$self->sqlUpdate('moderatorlog', {
			-m2count => 'm2count+1',
		}, "id=$mmid");
	}
	$self->sqlTransactionFinish();

	return $returns;
}

########################################################
sub getModeratorLast {
	my($self, $uid) = @_;
	my $last = $self->sqlSelectHashref(
		"(to_days(now()) - to_days(lastmm)) as lastmm, lastmmid",
		"users_info",
		"uid=$uid"
	);

	return $last;
}

########################################################
# No, this is not API, this is pretty specialized
sub getModeratorLogRandom {
	my($self, $uid) = @_;
	my($m2max) = $self->sqlSelect("max(mmid)", "metamodlog", "uid=$uid");
	my($modmax) = $self->sqlSelect("max(id)", "moderatorlog");

	# KLUDGE: This assumes that $m2max will always be below
	# $max - vars(m2_comment).
	return $m2max + int rand($modmax - $m2max);
}

########################################################
sub countUsers {
	my($self) = @_;
	my($users) = $self->sqlCount('users_count');
	return $users;
}

########################################################
sub createVar {
	my($self, $name, $value, $desc) = @_;
	$self->sqlInsert('vars', {name => $name, value => $value, description => $desc});
}

########################################################
sub deleteVar {
	my($self, $name) = @_;

	$self->sqlDo("DELETE from vars WHERE name=" .
		$self->sqlQuote($name));
}

########################################################
# This is a little better. Most of the business logic
# has been removed and now resides at the theme level.
#	- Cliff 7/3/01
# It now returns a boolean: whether or not the comment was changed. - Jamie
sub setCommentCleanup {
	my($self, $cid, $val, $newreason, $oldreason) = @_;

	return 0 if $val eq '+0';

	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	my $update = {
		-points => "points$val",
		reason => $self->getCommentMostCommonReason($cid,
			$newreason, $oldreason),
		lastmod => $user->{uid},
	};
	my $where = "cid=$cid AND points ";
	$where .= " > $constants->{comment_minscore}" if $val < 0;
	$where .= " < $constants->{comment_maxscore}" if $val > 0;
	$where .= " AND lastmod<>$user->{uid}"
		unless $constants->{authors_unlimited}
			&& $user->{seclev} >= $constants->{authors_unlimited};

	return $self->sqlUpdate("comments", $update, $where);
}

########################################################
# This gets the mathematical mode, in other words the most common, of the
# moderations done to a comment.  If no mods, return undef.  Tiebreakers
# break ties, first tiebreaker found wins.  "cid" is a key in moderatorlog
# so this is not a table scan.
sub getCommentMostCommonReason {
	my($self, $cid, @tiebreaker_reasons) = @_;
	my $hr = $self->sqlSelectAllHashref(
		"reason",
		"reason, COUNT(*) as c",
		"moderatorlog",
		"cid=$cid AND active=1",
		"GROUP BY reason"
	);
	# Overrated and Underrated can't show up as a comment's reason.
	delete $hr->{9}; delete $hr->{10};
	# If no mods, return undef.
	return undef if !keys %$hr;
	# Sort first by popularity and secondarily by reason.
	# "reason" is a numeric field, so we sort $a<=>$b numerically.
	my @sorted_keys = sort {
		$hr->{$a}{c} <=> $hr->{$b}{c}
		||
		$a <=> $b
	} keys %$hr;
	my $top_count = $hr->{$sorted_keys[-1]}{c};
	@sorted_keys = grep { $hr->{$_}{c} == $top_count } @sorted_keys;
	# Now sorted_keys are only the top values, one or more of them,
	# any of which could be the winning reason.
	if (scalar(@sorted_keys) == 1) {
		# A clear winner.  Return it.
		return $sorted_keys[0];
	}
	# No clear winner. Are any of our tiebreakers contenders?
	my %sorted_hash = ( map { $_ => 1 } @sorted_keys );
	for my $reason (@tiebreaker_reasons) {
		# Yes, return the first tiebreaker we find.
		return $reason if $sorted_hash{$reason};
	}
	# Nope, we don't have a good way to resolve the tie. Pick whatever
	# comes first in the reason list (reasons are all numeric and
	# sorted_keys is already sorted, making this easy).
	return $sorted_keys[0];
}


########################################################
sub getCommentReply {
	my($self, $sid, $pid) = @_;
	my $sid_quoted = $self->sqlQuote($sid);
	my $reply = $self->sqlSelectHashref(
		"date,date as time,subject,comments.points as points,
		comment_text.comment as comment,realname,nickname,
		fakeemail,homepage,comments.cid as cid,sid,
		users.uid as uid",
		"comments,comment_text,users,users_info,users_comments",
		"sid=$sid_quoted
		AND comments.cid=$pid
		AND users.uid=users_info.uid
		AND users.uid=users_comments.uid
		AND comment_text.cid=$pid
		AND users.uid=comments.uid"
	) || {};

	# For a comment we're replying to, there's no need to mod.
	$reply->{no_moderation} = 1;

	return $reply;
}

########################################################
sub getCommentsForUser {
	my($self, $sid, $cid, $cache_read_only) = @_;

	my $sid_quoted = $self->sqlQuote($sid);
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	# this was a here-doc.  why was it changed back to slower,
	# harder to read/edit variable assignments?  -- pudge
	my $sql;
	$sql .= " SELECT	cid, date, date as time, subject, nickname, homepage, fakeemail, ";
	$sql .= "	users.uid as uid, sig, comments.points as points, pid, sid, ";
	$sql .= " lastmod, reason, journal_last_entry_date, ipid, subnetid ";
	$sql .= "	FROM comments, users  ";
	$sql .= "	WHERE sid=$sid_quoted AND comments.uid=users.uid ";

	if ($user->{hardthresh}) {
		$sql .= "    AND (";
		$sql .= "	comments.points >= " .
			$self->sqlQuote($user->{threshold});
		$sql .= "     OR comments.uid=$user->{uid}"
			unless $user->{is_anon};
		$sql .= "     OR cid=$cid" if $cid;
		$sql .= "	)";
	}

# We are now doing this in the webserver not in the DB
#	$sql .= "         ORDER BY ";
#	$sql .= "comments.points DESC, " if $user->{commentsort} == 3;
#	$sql .= " cid ";
#	$sql .= ($user->{commentsort} == 1 || $user->{commentsort} == 5) ?
#			'DESC' : 'ASC';


	my $thisComment = $self->{_dbh}->prepare_cached($sql) or errorLog($sql);
	$thisComment->execute or errorLog($sql);

	if ($constants->{comment_cache_newstyle}) {

		my $comments = [];
		while (my $comment = $thisComment->fetchrow_hashref) {
			push @$comments, $comment;
		}
		$thisComment->finish;

		# XXX We could significantly speed things up by flagging the
		# comments whose text we don't need with a special field that is
		# only read by _getCommentText, and then simply not fetching the
		# text of those comments.  But, we need to use identical code
		# both here and in xxx() to decide which comments will be
		# displayed and which won't.
		$self->_getCommentTextNew($comments, $sid, $cache_read_only);

		return $comments;

	}

	my $archive = $cache_read_only;
	my $comments = [];
	my $cids = [];
	while (my $comment = $thisComment->fetchrow_hashref) {
		$comment->{time_unixepoch} = timeCalc($comment->{date}, "%s", 0);
		push @$comments, $comment;
		push @$cids, $comment->{cid};# if $comment->{points} >= $user->{threshold};
	}
	$thisComment->finish;

	# We have a list of all the cids in @$comments.  Get the texts of
	# all these comments, all at once.
	# XXX This algorithm could be (significantly?) sped up for users
	# with hardthresh=0 (most of them) by only getting the text of
	# comments we're going to be displaying.  As it is now, if you
	# display a thread with threshold=5, it (above) SELECTs all the
	# comments you _won't_ see just so it can count them -- and (here)
	# grabs their full text as well.  Wasteful.  We could probably
	# just refuse to push $comment (above) when
	# ($comment->{points} < $user->{threshold}). - Jamie
	# That has side effects and doesn't do that much good anyway,
	# see SF bug 452558. - Jamie
	my $start_time = Time::HiRes::time;
	my $comment_texts = $self->_getCommentTextOld($cids, $archive);
	# Now distribute those texts into the $comments hashref.

	for my $comment (@$comments) {
		# we need to check for *existence* of the hash key,
		# not merely definedness; exists is faster, too -- pudge
		if (!exists($comment_texts->{$comment->{cid}})) {
			errorLog("no text for cid " . $comment->{cid});
		} else {
			$comment->{comment} = $comment_texts->{$comment->{cid}};
		}
	}

	if ($constants->{comment_cache_debug}) {
		my $duration = Time::HiRes::time - $start_time;
		$self->{_comment_text}{totalcomments} += scalar @$cids;
		$self->{_comment_text}{secs} += $duration;
		my $secs = $self->{_comment_text}{secs};
		my $totalcomments = $self->{_comment_text}{totalcomments};
		if ($totalcomments and $secs) {
			my $cache = getCurrentCache();
			$cache->{status}{comment_text} = 
				sprintf "%.1f comments/sec",
					$totalcomments/$secs;
		}
	}

	return $comments;
}

########################################################
# This is here to save us a database lookup when drawing comment pages.
#
# I tweaked this to go a little faster by allowing $cid to be either
# an integer (old mode, retained for backwards compatibility, returns
# the text) or a reference to an array of integers (new mode, returns
# a hashref of cid=>text).  Either way it stores all the answers it
# gets into cache.  But passing it an arrayref of 100 cids is faster
# than calling it 100 times with one cid.  Works fine with an arrayref
# of 0 or 1 entries, of course.  - Jamie
sub _getCommentTextOld {
	my($self, $cid, $archive) = @_;
	# If this is the first time this is called, create an empty comment text
	# cache (a hashref).
	$self->{_comment_text} ||= { };
	if (scalar(keys %{$self->{_comment_text}}) > 5_000) {
		# Cache too big. Big cache bad. Kill cache. Kludge.
		undef $self->{_comment_text};
		$self->{_comment_text} = { };
	}
	if (ref $cid) {
		if (ref $cid ne "ARRAY") {
			errorLog("_getCommentText called with ref to non-array: $cid");
			return { };
		}
		#Archive, means it is doubtful this is useful in the cache. -Brian
		if ($archive) {
			my %return;
			my $in_list = join(",", @$cid);
			my $comment_array;
			$comment_array = $self->sqlSelectAll(
				"cid, comment",
				"comment_text",
				"cid IN ($in_list)"
			) if @$cid;
			# Now we cache them so we never fetch them again
			for my $comment_hr (@$comment_array) {
				$return{$comment_hr->[0]} = $comment_hr->[1];
			}

			return \%return;
		}
		# We need a list of comments' text.  First, eliminate the ones we
		# already have in cache.
		my @needed = grep { !exists($self->{_comment_text}{$_}) } @$cid;
		my $num_cache_misses = scalar(@needed);
		my $num_cache_hits = scalar(@$cid) - $num_cache_misses;
		if (@needed) {
			my $in_list = join(",", @needed);
			my $comment_array = $self->sqlSelectAll(
				"cid, comment",
				"comment_text",
				"cid IN ($in_list)"
			);
			# Now we cache them so we never fetch them again
			for my $comment_hr (@$comment_array) {
				$self->{_comment_text}{$comment_hr->[0]} = $comment_hr->[1];
			}
		}
		# Now, all the comment texts we need are in cache, return them.
		return $self->{_comment_text};

	} else {
		my $num_cache_misses = 0;
		my $num_cache_hits = 0;
		# We just need a single comment's text.
		if (!$self->{_comment_text}{$cid}) {
			# If it's not already in cache, load it in.
			$num_cache_misses = 1;
			$self->{_comment_text}{$cid} =
				$self->sqlSelect("comment", "comment_text", "cid=$cid");
		} else {
			$num_cache_hits = 1;
		}
		# Now it's in cache.  Return it.
		return $self->{_comment_text}{$cid};
	}
}

########################################################
# This is here to hopefully save us a database lookup when drawing
# comment pages, or to reduce the amount of data we have to fetch.
#
# This function has been changed to accept a reference to an array
# of hashrefs, each of which describes one comment.  All the hashrefs
# have several fields, including {cid} which is its index, but lack
# the {comment} field which we're going to write in directly.
# Because only references are being passed back and forth, we limit
# how much text gets copied around in RAM.  The disadvantage is that
# the data structures get more complex.
sub _getCommentTextNew {
	my($self, $comment_ar, $sid, $cache_read_only) = @_;
	my $constants = getCurrentStatic();

	my $start_time = Time::HiRes::time;
	my $entry_n_keys = scalar keys %{$self->{_comment_text}};

	# If we have debugging turned on, %log will store a bunch of data
	# that we'll print to STDERR when this method returns.
	my %log;
	$log{entry_n_keys} = $entry_n_keys if $constants->{comment_cache_debug};
	$log{ro1} = $cache_read_only if $constants->{comment_cache_debug} >= 2;

	# If this is the first time this is called, create an empty hashref
	# for the story LRU comment cache.
	$self->{_story_comm} ||= { };

	# Update info for this story's LRU cache.  Even if we don't put
	# anything for this story into the comment cache, we make note of
	# this request.
	$self->{_story_comm}{$sid}{last_time} = time;
	$self->{_story_comm}{$sid}{num_requests}++;

	# If this is the first time this is called, create an empty comment text
	# cache (a hashref).
	$self->{_comment_text} ||= { };

	# The caller passes in "1" for $cache_read_only if we are not to
	# write to the cache.  But we can set it as well, and we will when
	# the cache is full.
	my $max_keys = $constants->{comment_cache_max_keys} || 3000;
	my $keys_left = $max_keys - $entry_n_keys;
	if ($self->{_comment_text_full}) {
		$cache_read_only = 1;
	} elsif ($keys_left <= 0) {
		$self->{_comment_text_full} = 1;
		$cache_read_only = 1;
	}
	$log{ro2} = $cache_read_only if $constants->{comment_cache_debug} >= 2;

	# We need a list of comments' text.  First, copy over (if necessary)
	# the ones we already have in the cache, and make a list of those we
	# don't have.  The %needed hash has keys that are comment cids, and
	# values that are numeric indexes into @$comment_ar.  Keep track of
	# how many we need, since the purge subroutine needs that number.
	my %needed = ( );
	for my $comment_num (0..$#$comment_ar) {
		my $comment = $comment_ar->[$comment_num];
		if (exists $self->{_comment_text}{$comment->{cid}}) {
			$comment->{comment} = $self->{_comment_text}{$comment->{cid}};
			++$log{num_exist};
			++$self->{_comment_text}{hits};
		} else {
			# We don't have it, add it to our request list.
			$needed{$comment->{cid}} = $comment_num;
			++$self->{_comment_text}{misses};
		}
	}
	my $num_needed = scalar keys %needed;
	$log{num_needed} = $num_needed if $constants->{comment_cache_debug};

	my $purge_msg = "";
	my $purge_msg_ref = undef;
	$purge_msg_ref = \$purge_msg if $constants->{comment_cache_debug} >= 2;
	if ($self->_purgeCommentTextIfNecessary($sid,
		$num_needed,
		$purge_msg_ref)
	) {
		$cache_read_only = 0;
	}
	if ($constants->{comment_cache_debug} >= 2) {
		$log{ro3} = $cache_read_only;
		$log{purge_msg} = $purge_msg if $purge_msg;
	}

	# Whatever we don't have, get, and copy into the $comment_ar array
	# that we were passed in.  And if the cache is not read-only, also
	# copy it into the cache.
	if ($num_needed) {
		my %cid_list = ( );
		%cid_list = map { $_ => 1 } @{$self->{_story_comm}{$sid}{cid_list}}
			if $self->{_story_comm}{$sid}{cid_list};
		my $in_list = join(",", keys %needed);
		my $comment_array = $self->sqlSelectAll(
			"cid, comment",
			"comment_text",
			"cid IN ($in_list)"
		);
		# Copy the new text data to the $comment_ar array which
		# our caller will use, and (if appropriate) also cache it.
		for my $i (@$comment_array) {
			my($cid, $text) = @$i;
			$comment_ar->[$needed{$cid}]{comment} = $text;
			if (!$cache_read_only) {
				$self->{_comment_text}{$cid} = $text;
				$cid_list{$cid} = 1;
				++$log{num_added} if $constants->{comment_cache_debug};
				--$keys_left;
				$cache_read_only = 1 if $keys_left <= 0;
			}
		}
		$self->{_story_comm}{$sid}{cid_list} = [ keys %cid_list ];
	}
	$log{ro4} = $cache_read_only if $constants->{comment_cache_debug} >= 2;

	# We're done, $comment_ar contains all the data we need.  Write log,
	# and store some status info which /86.pl can read.
	my $duration = Time::HiRes::time - $start_time;
	$self->{_comment_text}{secs} += $duration;
	if ($constants->{comment_cache_debug}) {
		printf STDERR "_getCommentText $$ time %0.3f %s\n",
			$duration,
			join(" ", map { "$_:$log{$_}" } sort keys %log );
	}
	my $cache = getCurrentCache();
	my $hits = $self->{_comment_text}{hits};
	my $misses = $self->{_comment_text}{misses};
	my $secs = $self->{_comment_text}{secs};
	# Just to make extra sure we don't divide by zero...
	if ($hits+$misses and $secs) {
		$cache->{status}{comment_text} = 
			sprintf "%d hits on %d comments, %.1f%%, %.1f comments/sec",
				$hits, $hits+$misses,
				$hits*100/($hits+$misses),
				($hits+$misses)/$secs;
	}
}

########################################################
# Called by _getCommentTextNew, this purges the comment cache if and
# only if it is necessary to do so.
#
# It does a number of tests to see if we can get away with doing nothing;
# if so, we do nothing.  If we have to purge the cache, use the last_time
# data in the _story_comm instance hashref to figure out which story was
# requested _longest_ ago.  Purge from the comment cache all the cids
# from that story, then purge the info about the story itself.
sub _purgeCommentTextIfNecessary {
	my($self, $sid, $num_needed, $msg_ref) = @_;
	$num_needed ||= 0;
	my $constants = getCurrentStatic();
	my $start_time = Time::HiRes::time;

	my $min_comm = $constants->{comment_cache_purge_min_comm} || 50;
	if ($num_needed < $min_comm) {
		# This sid doesn't need very many (more) comments, not
		# important enough to purge for.
		$$msg_ref = "only $num_needed comments needed on $sid, "
			. "no purge"
			if $msg_ref;
		return 0;
	}

	if (!$self->{_comment_text_full}) {
		# Cache can still grow, no need to purge.
		$$msg_ref = "cache not full, no purge" if $msg_ref;
		return 0;
	}

	my $num_requests = $self->{_story_comm}{$sid}{num_requests} || 0;
	my $min_req = $constants->{comment_cache_purge_min_req} || 10;
	if ($num_requests < $min_req) {
		# Not many requests for this story, not important enough
		# to purge for.
		$$msg_ref = "only " . $self->{_story_comm}{$sid}{num_requests}
			. " requests for $sid, no purge"
			if $msg_ref;
		return 0;
	}

	# Now the complex part.  Construct @last_time as an ordered list of the
	# sids, from least-recently-used to most-recently-used.  Do this by
	# building a %last_time hash, keys are sids, values are timestamps.
	my %last_time = ( );
	for my $lru_sid (keys %{$self->{_story_comm}}) {
		$last_time{$lru_sid} = $self->{_story_comm}{$lru_sid}{last_time}
			if $self->{_story_comm}{$lru_sid}{last_time};
	}
	if (scalar keys %last_time <= 1) {
		$$msg_ref = "only one sid in cache, no purge" if $msg_ref;
		return 0;
	}
	my @last_time = sort {
		($last_time{$a} <=> $last_time{$b}) || ($a <=> $b)
	} keys %last_time;
	$$msg_ref = "_purgeCommentText $$ last_time '"
		. join(",", map { "$_:$last_time{$_}" } @last_time ) . "'"
		if $msg_ref;

	my $empty_enough = 0;
	my $max_keys = $constants->{comment_cache_max_keys} || 3000;
	my $max_frac = $constants->{comment_cache_purge_max_frac} || 0.75;
	my $max_keys_desired = int($max_keys * $max_frac);
	$$msg_ref .= " desired $max_keys_desired" if $msg_ref;
	while (!$empty_enough) {
		# Keep trying to purge old story comments until we have to
		# give up or until the cache becomes sufficiently non-full.
		if (scalar @last_time < 2) {
			$$msg_ref .= "; giving up on purge attempt, only "
				. "sid '@last_time' left" if $msg_ref;
			last;
		}
		my $sid_to_purge = shift @last_time;
		if ($sid_to_purge eq $sid) {
			$$msg_ref .= "; LOGIC ERROR sid_to_purge=sid='$sid' "
				. "last_time='@last_time'" if $msg_ref;
			last;
		}

		# Purge the data.
		my $cids_to_purge = $self->{_story_comm}{$sid_to_purge}{cid_list};
		$$msg_ref .= "; sid_to_purge '$sid_to_purge' "
			. "cids_to_purge (" . scalar(@$cids_to_purge) . ") "
			. "'@$cids_to_purge'" if $msg_ref;
		delete @{$self->{_comment_text}}{@$cids_to_purge};
		delete $self->{_story_comm}{$sid_to_purge};

		# If the cache is below its max size, it's no longer full.  If it's
		# below the max size desired, we're done looping.
		my $keys_left = scalar(keys %{$self->{_comment_text}});
		$self->{_comment_text_full} = 0
			if $self->{_comment_text_full}
				and $keys_left < $max_keys;
		$empty_enough = ($keys_left < $max_keys_desired) ? 1 : 0;
		$$msg_ref .= "; after purge '$sid_to_purge', "
			. scalar(keys %{$self->{_comment_text}})
			. " keys, $max_keys_desired desired"
			if $msg_ref;
	}

	my $duration = sprintf("%.3f", Time::HiRes::time - $start_time);
	$$msg_ref .= "; duration ${duration}s" if $msg_ref;

	if ($self->{_comment_text_full}) {
		# Purge attempt failed.
		return 0;
	}

	# Purge attempt succeeded, maybe not purged down as far as
	# we'd like, but success nonetheless.
	return 1;
}

########################################################
sub getComments {
	my($self, $sid, $cid) = @_;
	my $sid_quoted = $self->sqlQuote($sid);
	$self->sqlSelect("uid, pid, subject, points, reason, ipid, subnetid",
		'comments',
		"cid=$cid AND sid=$sid_quoted"
	);
}

########################################################
# Needs to be more generic in the long run. 
# Be nice if we could just pull certain elements -Brian
sub getStoriesBySubmitter {
	my($self, $id, $limit) = @_;

	$limit = 'LIMIT ' . $limit if $limit;
	my $answer = $self->sqlSelectAllHashrefArray(
		'sid,title,time',
		'stories', "submitter='$id' AND time < NOW() AND (writestatus = 'ok' OR writestatus = 'dirty') and displaystatus >= 0 ",
		"ORDER by time DESC $limit");
	return $answer;
}

########################################################
sub countStoriesBySubmitter {
	my($self, $id) = @_;

	my $count = $self->sqlCount('stories', "submitter='$id'  AND time < NOW() AND (writestatus = 'ok' OR writestatus = 'dirty') and displaystatus >= 0");

	return $count;
}

########################################################
# Be nice if we could control more of what this 
# returns -Brian
# ok, I extended it to take an sid so I could get 
# just one particlar story (getStory doesn't cut it)
# since I don't want the story text but what 
# this method gives for the feature story) -Patrick
# ..and an exclude sid for excluding and sid should feature
# stories be enabled
sub getStoriesEssentials {
	my($self, $limit, $section, $tid, $misc) = @_;
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();

	$limit ||= 15;
	my $columns;
	$columns = 'sid, section, title, time, commentcount, hitparade, tid';

	my $where = "time < NOW() ";
	# Added this to narrow the query a bit more, I need
	# see about the impact on this -Brian
	$where .= "AND writestatus != 'delete' ";

	if ($section) {
		my $section_dbi = $self->sqlQuote($section || '');
		$where .= "AND (displaystatus>=0 AND section=$section_dbi) ";
	} elsif ($user->{sectioncollapse}) {
		$where .= "AND displaystatus>=0 ";
	} else {
		$where .= "AND displaystatus=0 ";
	}

	$where .= "AND tid='$tid' " if $tid;
	$where .= "AND sid = '$misc->{sid}' " if $misc->{sid};
	$where .= "AND sid != '$misc->{exclude_sid}' " if $misc->{exclude_sid};
	$where .= "AND subsection=$misc->{subsection}" if $misc->{subsection};

	# User Config Vars
	$where .= "AND tid not in ($user->{extid}) "
		if $user->{extid};
	$where .= "AND stories.uid not in ($user->{exaid}) "
		if $user->{exaid};
	$where .= "AND section not in ($user->{exsect}) "
		if $user->{exsect} && !$section;

	# Order
	my $other = "ORDER BY time DESC ";

	# Since stories may potentially have thousands of rows, we
	# cannot simply select the whole table and cursor through it, it might
	# seriously suck resources.  Normally we can just add a LIMIT $limit,
	# but if we're in "issue" form we have to be careful where we're
	# starting/ending so we only limit by time in the DB and do the rest
	# in perl.
	if ($form->{issue}) {
		# It would be slightly faster to calculate the
		# yesterday/tomorrow for $form->{issue} in perl so that the
		# DB only has to manipulate each row's "time" once instead
		# of twice.  But this works now;  we'll optimize later. - Jamie
		my $tomorrow_str =
			'DATE_FORMAT(DATE_ADD(time, INTERVAL 1 DAY),"%Y%m%d")';
		my $yesterday_str =
			'DATE_FORMAT(DATE_SUB(time, INTERVAL 1 DAY),"%Y%m%d")';
#		$where .=
#			"AND day_published = '$form->{issue}' ";
		$where .=" AND '$form->{issue}' BETWEEN $yesterday_str AND
			$tomorrow_str ";
	} else {
		$other .= "LIMIT $limit ";
	}

	my(@stories, @story_ids, @discussion_ids, $count);
	my $cursor = $self->sqlSelectMany($columns, 'stories', $where, $other)
		or
	errorLog(<<EOT);
error in getStoriesEssentials
	columns: $columns
	story_table: stories
	where: $where
	other: $other
EOT

	while (my $data = $cursor->fetchrow_arrayref) {
		# Rather than have MySQL/DBI return us "time" three times
		# because we'd want three different representations, we
		# just get it once in position 3 and then drop it into
		# its traditional other locations in the array.
		$data = [
			@$data[0..4], 
			$data->[3], 
			$data->[5], 
			$data->[3], 
			$data->[6] 
		];
		formatDate([$data], 3, 3, '%A %B %d %I %M %p');
		formatDate([$data], 5, 5, '%Y%m%d'); # %Q
		formatDate([$data], 7, 7, '%s');
		next if $form->{issue} && $data->[5] > $form->{issue};
		push @stories, [@$data];
		last if ++$count >= $limit;
	}
	$cursor->finish;

	return \@stories;
}


########################################################
# This makes me nervous... we grab, and they get
# deleted? I may move the delete to the setQuickies();
# 
# (That would make sense to me too. - Jamie)
sub getQuickies {
	my($self) = @_;
# This is doing nothing (unless I am just missing the point). We grab
# them and then null them? -Brian
#  my($stuff) = $self->sqlSelect("story", "submissions", "subid='quickies'");
#	$stuff = "";
	my $submission = $self->sqlSelectAll("subid,subj,email,name,story",
		"submissions", "note='Quik' and del=0"
	);

	return $submission;
}

########################################################
sub setQuickies {
	my($self, $content) = @_;
	$self->sqlInsert("submissions", {
		#subid	=> 'quickies',
		subj	=> 'Generated Quickies',
		email	=> '',
		name	=> '',
		-'time'	=> 'now()',
		section	=> 'articles',
		tid	=> 'quickies',
		story	=> $content,
		uid	=> getCurrentUser('uid'),
	});
}

########################################################
# What an ugly method
sub getSubmissionForUser {
	my($self) = @_;

	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $del  = $form->{del} || 0;

	# Master WHERE array, each element in the list must be true for a valid
	# result.
	my @where = (
		'submissions.uid=users_info.uid',
		"$del=del"
	);

	# Build note logic and add it to master WHERE array.
	my $logic = $form->{note} ? 
		'note=' . $self->sqlQuote($form->{note}) : 'isnull(note)';
	$logic .= " or note=' ' " unless $form->{note};
	$logic = "($logic)";
	push @where, $logic;

	push @where, 'tid=' . $self->sqlQuote($form->{tid}) if $form->{tid};

	# Why do both here? If both are set and non-equal, we've got problems.
	push @where, 'section=' . $self->sqlQuote($user->{section})
		if $user->{section};
	push @where, 'section=' . $self->sqlQuote($form->{section})
		if $form->{section};
	
	my $submissions = $self->sqlSelectAllHashrefArray(
		'submissions.*',
		'submissions,users_info',
		join(' AND ', @where),
		'ORDER BY time'
	);

	formatDate($submissions, 'time', 'time', '%m/%d  %H:%M');

	# Drawback - This method won't return param data for these submissions
	# without a little more work.
	return $submissions;
}

########################################################
sub calcModval {
	my($self, $where_clause, $halflife, $minicache) = @_;

	# There's just no good way to do this with a join; it takes
	# over 1 second and if either comment posting or moderation
	# is reasonably heavy, the DB can get bogged very fast.  So
	# let's split it up into two queries.  Dagnabbit.
	my $cid_ar = $self->sqlSelectColArrayref(
		"cid",
		"comments",
		$where_clause,
	);
	return 0 if !$cid_ar or !@$cid_ar;

	# If a minicache was passed in, see if we match it;  if so,
	# we can save a query.  In reality, this means that if an IP
	# is the only IP posting from its subnet, we don't need to
	# get the moderatorlog valsum twice.
	my $cid_text = join(",", @$cid_ar);
	if ($minicache and defined($minicache->{$cid_text})) {
		return $minicache->{$cid_text};
	}

	# We've got the cids that fit the where clause;  find all
	# moderations of those cids.
	my $hr = $self->sqlSelectAllHashref(
		"hoursback",
		"CEILING((UNIX_TIMESTAMP(NOW())-
			UNIX_TIMESTAMP(ts))/3600) AS hoursback,
			SUM(val) AS valsum",
		"moderatorlog",
		"moderatorlog.cid IN ($cid_text)
			AND moderatorlog.active=1",
		"GROUP BY hoursback",
	);

	my $modval = 0;
	for my $hoursback (keys %$hr) {
		my $val = $hr->{$hoursback}{valsum};
		next unless $val;
		if ($hoursback <= $halflife) {
			$modval += $val;
		} elsif ($hoursback > $halflife*10) {
			# So old it's not worth looking at.
		} else {
			# Logarithmically weighted.
			$modval += $val / (2 ** ($hoursback/$halflife));
		}
	}

	$minicache->{$cid_text} = $modval if $minicache;
	$modval;
}

########################################################
########################################################
# (And now a word from CmdrTaco)
#
# I'm putting this note here because I hate posting stories about
# Slashcode on Slashdot.  It's just distracting from the news, and the
# vast majority of Slashdot readers simply don't care about it. I know
# that this is interpreted as me being all men-in-black, but thats
# bull pucky.  I don't want Slashdot to be about Slashdot or
# Slashcode.  A few people have recently taken to reading CVS and then
# trolling Slashdot with the deep dark secrets that they think they
# have found within.  They don't bother going so far as to bother
# *asking* before freaking.  We have a mailing list if people want to
# ask questions.  We love getting patches when people have better ways
# to do things.  But answers are much more likely if you ask us to our
# faces instead of just sitting in the back of class and bitching to
# everyone sitting around you.  I'm not going to try to have an
# offtopic discussion in an unrelated story.  And I'm not going to
# bother posting a story to appease the 1% of readers for whom this
# story matters one iota.  So this seems to be a reasonable way for me
# to reach you.
#
# What I'm talking about this time is all this IPID crap.  It's a
# temporary kludge that people simply don't understand. It isn't
# intended to be permanent, or secure.  These 2 misconceptions are the
# source of the problem.
#
# The IPID stuff was designed when we only kept 2 weeks of comments in
# the DB at a time.  We need to track IPs and Subnets to prevent DoS
# script attacks.  Again, I know conspiracy theorists freak out, but
# the reality is that without this,  we get constant scripted
# trolling.  This simply isn't up for debate.  We've been doing this
# for years.  It's not new.  We *used* to just store the plain old IP.
#
# The problem is that I don't want IPs staring me in the face. So we
# MD5d em. This wasn't for "security" in the strict sense of the word.
# It just was meant to make it inconvenient for now.  Not impossible. 
# Now I don't have any IPs.  Instead we have reasonably abstracted
# functions that should let us create a more secure system when we
# have the time.
#
# What really needs to happen is that these IDs need to be generated
# with some sort of random rolling key. Of course lookups need to be
# computationally fast within the limitations of our existing
# database.  Ideas?  Or better yet, Diffs?
#
# Lastly I have to say, I find it ironic that we've tracked IPs for
# years.  But nobody complained until we *stopped* tracking IPs and
# put the hooks in place to provide a *secure* system.  You'd think
# people were just looking for an excuse to bitch...
########################################################
########################################################

########################################################
sub getIsTroll {
	my($self, $good_behavior) = @_;
	$good_behavior ||= 0;
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	my $ipid_hoursback = $constants->{istroll_ipid_hours} || 72;
	my $uid_hoursback = $constants->{istroll_uid_hours} || 72;
	my($modval, $trollpoint);
	my $minicache = { };

	# Check for modval by IPID.
	$trollpoint = -abs($constants->{istroll_downmods_ip}) - $good_behavior;
	$modval = $self->calcModval("ipid = '$user->{ipid}'",
		$ipid_hoursback, $minicache);
	return 1 if $modval <= $trollpoint;

	# Check for modval by subnet.
	$trollpoint = -abs($constants->{istroll_downmods_subnet}) - $good_behavior;
	$modval = $self->calcModval("subnetid = '$user->{subnetid}'",
		$ipid_hoursback, $minicache);
	return 1 if $modval <= $trollpoint;

	# At this point, if the user is not logged in, then we don't need
	# to check the AC's downmods by user ID;  they pass the tests.
	return 0 if $user->{is_anon};

	# Check for modval by user ID.
	$trollpoint = -abs($constants->{istroll_downmods_user}) - $good_behavior;
	$modval = $self->calcModval("comments.uid = $user->{uid}", $uid_hoursback);
	return 1 if $modval <= $trollpoint;

	# All tests passed, user is not a troll.
	return 0;
}

########################################################
sub createDiscussion {
	my($self, $discussion) = @_;
	return unless $discussion->{title} && $discussion->{url} && $discussion->{topic};

	#If no type is specified we assume the value is zero
	$discussion->{section} ||= getCurrentStatic('defaultsection');
	$discussion->{type} ||= 'open';
	$discussion->{sid} ||= '';
	$discussion->{ts} ||= $self->getTime();
	$discussion->{uid} ||= getCurrentUser('uid');
	# commentcount and flags set to defaults

	$self->sqlInsert('discussions', $discussion);

	my $discussion_id = $self->getLastInsertId();

	return $discussion_id;
}

########################################################
sub createStory {
	my($self, $story) = @_;

	my $constants = getCurrentStatic();

	$story ||= getCurrentForm();

	# yes, this format is correct, don't change it :-)
	my $sidformat = '%02d/%02d/%02d/%02d%0d2%02d';
	# Create a sid based on the current time.
	my $start_time = time;
	my @lt = localtime($start_time);
	$lt[5] %= 100; $lt[4]++; # year and month
	$story->{sid} = sprintf($sidformat, @lt[reverse 0..5]);

	# If this came from a submission, update submission and grant
	# Karma to the user
	my $suid;
	if ($story->{subid}) {
		my $constants = getCurrentStatic();
		my($suid) = $self->sqlSelect(
			'uid', 'submissions',
			'subid=' . $self->sqlQuote($story->{subid})
		);

		# i think i got this right -- pudge
		my($userkarma) =
			$self->sqlSelect('karma', 'users_info', "uid=$suid");
		my $newkarma = (($userkarma + $constants->{submission_bonus})
			> $constants->{maxkarma})
				? $constants->{maxkarma}
				: "karma+$constants->{submission_bonus}";
		$self->sqlUpdate('users_info', {
			-karma => $newkarma },
		"uid=$suid") if !isAnon($suid);

		$self->sqlUpdate('submissions',
			{ del=>2 },
			'subid=' . $self->sqlQuote($story->{subid})
		);
	}
	if ($story->{displaystatus} == 0) {
		my $isolate = $self->getSection($story->{section}, 'isolate');
		$story->{displaystatus} = 1
			if ($isolate);
	}

	$story->{submitter}	= $story->{submitter} ?
		$story->{submitter} : $story->{uid};
	$story->{writestatus}	= 'dirty',

	my $sid_ok = 0;
	while ($sid_ok == 0) {
		$sid_ok = $self->sqlInsert('stories',
			{ sid => $story->{sid} },
			{ ignore => 1 } ); # don't print error messages
		if ($sid_ok == 0) { # returns 0E0 on collision, which == 0
			# Look back in time until we find a free second.
			# This is faster than waiting forward in time :)
			--$start_time;
			@lt = localtime($start_time);
			$lt[5] %= 100; $lt[4]++; # year and month
			$story->{sid} = sprintf($sidformat, @lt[reverse 0..5]);
		}
	}
	$self->sqlInsert('story_text', { sid => $story->{sid}});
	$self->setStory($story->{sid}, $story);

	return $story->{sid};
}

##################################################################
sub updateStory {
	my($self, $story) = @_;
	my $constants = getCurrentStatic();

	my $time = ($story->{fastforward})
		? $self->getTime()
		: $story->{'time'};

	if ($story->{displaystatus} == 0) {
		my $section = $story->{section} ? $story->{section}  : $self->getStory($story->{sid}, 'section');
		my $isolate = $self->getSection($section, 'isolate');
		$story->{displaystatus} = 1
			if ($isolate);
	}

	my $data = {
		sid	=> $story->{sid},
		title	=> $story->{title},
		section	=> $story->{section},
		url	=> "$constants->{rootdir}/article.pl?sid=$story->{sid}",
		ts	=> $time,
		topic	=> $story->{tid},
	};


	$self->sqlUpdate('discussions', $data, 
	'sid = ' . $self->sqlQuote($story->{sid}));

	$data = {};

	$data = {
		uid		=> $story->{uid},
		tid		=> $story->{tid},
		dept		=> $story->{dept},
		'time'		=> $time,
		day_published	=> $time,
		title		=> $story->{title},
		section		=> $story->{section},
		displaystatus	=> $story->{displaystatus},
		commentstatus	=> $story->{commentstatus},
		writestatus	=> $story->{writestatus},
	};

	$self->sqlUpdate('stories', $data, 
	'sid=' . $self->sqlQuote($story->{sid}));

	$self->sqlUpdate('story_text', {
		bodytext	=> $story->{bodytext},
		introtext	=> $story->{introtext},
		relatedtext	=> $story->{relatedtext},
	}, 'sid=' . $self->sqlQuote($story->{sid}));

	$self->_saveExtras($story);
}

########################################################
# Now, the idea is to not cache here, since we actually
# cache elsewhere (namely in %Slash::Apache::constants)
sub getSlashConf {
	my($self) = @_;

	# get all the data, yo! However make sure we can return if any DB
	# errors occur.
	my $confdata = $self->sqlSelectAll('name, value', 'vars');
	return if !defined $confdata;
	my %conf = map { $_->[0], $_->[1] } @{$confdata};
	# This allows you to do stuff like constant.plugin.Zoo in a template
	# and know that the plugin is installed -Brian
	my $plugindata = $self->sqlSelectColArrayref('value', 'site_info',
		"name='plugin'");
	for (@$plugindata) {
		$conf{plugin}{$_} = 1;
	}

	# the rest of this function is where is where we fix up
	# any bad or missing data in the vars table
	$conf{rootdir}		||= "//$conf{basedomain}";
	$conf{real_rootdir}	||= $conf{rootdir};  # for when rootdir changes
	$conf{absolutedir}	||= "http://$conf{basedomain}";
	$conf{absolutedir_secure} ||= "https://$conf{basedomain}";
	$conf{basedir}		||= "$conf{datadir}/public_html";
	$conf{imagedir}		||= "$conf{rootdir}/images";
	$conf{rdfimg}		||= "$conf{imagedir}/topics/topicslash.gif";
	$conf{index_handler}	||= 'index.pl';
	$conf{cookiepath}	||= URI->new($conf{rootdir})->path . '/';
	$conf{maxkarma}		= 999  unless defined $conf{maxkarma};
	$conf{minkarma}		= -999 unless defined $conf{minkarma};
	$conf{expiry_exponent}	= 1 unless defined $conf{expiry_exponent};
	$conf{panic}		||= 0;
	$conf{textarea_rows}	||= 10;
	$conf{textarea_cols}	||= 50;
	$conf{allow_deletions}  ||= 1;
	$conf{authors_unlimited} = 100 if ( (! defined $conf{authors_unlimited})
		|| ($conf{authors_unlimited} == 1) );
	# For all fields that it is safe to default to -1 if their
	# values are not present...
	for (qw[min_expiry_days max_expiry_days min_expiry_comm max_expiry_comm]) {
		$conf{$_}	= -1 unless exists $conf{$_};
	}

	# no trailing newlines on directory variables
	# possibly should rethink this for basedir,
	# since some OSes don't use /, and if we use File::Spec
	# everywhere this won't matter, but still should be do
	# it for the others, since they are URL paths
	# -- pudge
	for (qw[rootdir absolutedir imagedir basedir]) {
		$conf{$_} =~ s|/+$||;
	}

	if (!$conf{m2_maxbonus} || $conf{m2_maxbonus} > $conf{maxkarma}) {
		# this was changed on slashdot in 6/2001
		# $conf{m2_maxbonus} = int $conf{goodkarma} / 2;
		$conf{m2_maxbonus} = 1;
	}

	my $fixup = sub {
		return [
			map {(
				s/^\s+//,
				s/\s+$//,
				$_
			)[-1]}
			split /\|/, $_[0]
		] if $_[0];
	};

	my %conf_fixup_arrays = (
		# var name			# default array value
		# --------			# -------------------
						# See <http://www.iana.org/assignments/uri-schemes>
		approved_url_schemes =>		[qw( ftp http gopher mailto news nntp telnet wais https )],
		approvedtags =>			[qw( B I P A LI OL UL EM BR TT STRONG BLOCKQUOTE DIV ECODE )],
		approvedtags_break =>		[qw( P LI OL UL BR BLOCKQUOTE DIV HR )],
		fixhrefs =>			[ ],
		lonetags =>			[ ],
		reasons =>			[qw( Normal Offtopic Flamebait Troll Redundant
						     Insightful Interesting Informative Funny
						     Overrated Underrated )],
		stats_reports =>		[ $conf{adminmail} ],
		submit_categories =>		[ ],
	);
	my %conf_fixup_hashes = (
		# var name			# default list of keys
		# --------			# --------------------
		ad_messaging_sections =>	[ ],
	);
	for my $key (keys %conf_fixup_arrays) {
		$conf{$key} = $fixup->($conf{$key}) || $conf_fixup_arrays{$key};
	}
	for my $key (keys %conf_fixup_hashes) {
		$conf{$key} = { map { $_, 1 }
			@{$fixup->($conf{$key}) || $conf_fixup_hashes{$key}}
		};
	}

	if ($conf{comment_nonstartwordchars}) {
		# Expand this into a complete regex.  We catch not only
		# these chars in their raw form, but also all HTML entities
		# (because Windows/MSIE refuses to break before any word
		# that starts with either the chars, or their entities).
		# Build the regex with qr// and match entities for
		# optimal speed.
		my $src = $conf{comment_nonstartwordchars};
		my @chars = ( );
		my @entities = ( );
		for my $i (0..length($src)-1) {
			my $c = substr($src, $i, 1);
			push @chars, "\Q$c";
			push @entities, ord($c);
			push @entities, sprintf("x%x", ord($c));
		}
		my $dotchar =
			'(?:'
			       . '[' . join("", @chars) . ']'
			       . '|&#(?:' . join("|", @entities) . ');'
		       . ')';
		my $regex = '^(\s+' . "$dotchar+" . ')\S';
		$conf{comment_nonstartwordchars_regex} = qr{$regex}i;
	}

	$conf{badreasons} = 4 unless defined $conf{badreasons};

	# for fun ... or something
	$conf{colors} = $self->sqlSelect("block", "blocks", "bid='colors'");

	return \%conf;
}

##################################################################
sub autoUrl {
	my $self = shift;
	my $section = shift;
	local $_ = join ' ', @_;
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	s/([0-9a-z])\?([0-9a-z])/$1'$2/gi if $form->{fixquotes};
	s/\[([^\]]+)\]/linkNode($1)/ge if $form->{autonode};

	my $initials = substr $user->{nickname}, 0, 1;
	my $more = substr $user->{nickname}, 1;
	$more =~ s/[a-z]//g;
	$initials = uc($initials . $more);
	my($now) = timeCalc(scalar localtime, '%m/%d %H:%M %Z', 0);

	# Assorted Automatic Autoreplacements for Convenience
	s|<disclaimer:(.*)>|<B><A HREF="/about.shtml#disclaimer">disclaimer</A>:<A HREF="$user->{homepage}">$user->{nickname}</A> owns shares in $1</B>|ig;
	s|<update>|<B>Update: <date></B> by <author>|ig;
	s|<date>|$now|g;
	s|<author>|<B><A HREF="$user->{homepage}">$initials</A></B>:|ig;

	# The delimiters below were once "[%...%]" but that's legacy code from
	# before Template, and we've since changed it to what you see below.
	s/\{%\s*(.*?)\s*%\}/$self->getUrlFromTitle($1)/eg if $form->{shortcuts};

	# Assorted ways to add files:
	s|<import>|importText()|ex;
	s/<image(.*?)>/importImage($section)/ex;
	s/<attach(.*?)>/importFile($section)/ex;
	return $_;
}

#################################################################
# link to Everything2 nodes --- should be elsewhere (as should autoUrl)
sub linkNode {
	my($title) = @_;
	my $link = URI->new("http://www.everything2.com/");
	$link->query("node=$title");

	return qq|$title<sup><a href="$link">?</a></sup>|;
}

##################################################################
# autoUrl & Helper Functions
# Image Importing, Size checking, File Importing etc
sub getUrlFromTitle {
	my($self, $title) = @_;
	my($sid) = $self->sqlSelect('sid',
		'stories',
		"title like '\%$title\%'",
		'ORDER BY time DESC LIMIT 1'
	);
	my $rootdir = getCurrentStatic('rootdir');
	return "$rootdir/article.pl?sid=$sid";
}

##################################################################
# Should this really be in here?
# this should probably return time() or something ... -- pudge
# Well, the only problem with that is that we would then
# be trusting all machines to be timed to the database box.
# How safe is that? And I like our sysadmins :) -Brian
sub getTime {
	my($self) = @_;
	my($now) = $self->sqlSelect('now()');

	return $now;
}

##################################################################
# Should this really be in here? -- krow
# dunno ... sigh, i am still not sure this is best
# (see getStories()) -- pudge
# As of now, getDay is only used in Slash.pm getOlderStories() - Jamie
# And if a webserver had a date that is off... -Brian
# ...it wouldn't matter; "today's date" is a timezone dependent concept.
# If you live halfway around the world from whatever timezone we pick,
# this will be consistently off by hours, so we shouldn't spend an SQL
# query to worry about minutes or seconds - Jamie
sub getDay {
#	my($now) = $self->sqlSelect('to_days(now())');
	my($self, $days_back) = @_;
	$days_back ||= 0;
	my $day = timeCalc(scalar(localtime(time-86400*$days_back)), '%Y%m%d'); # epoch time, %Q
	return $day;
}

##################################################################
sub getStoryList {
	my ($self, $first_story, $num_stories) = @_;
	$first_story ||= 0;
	$num_stories ||= 40;

	my $user = getCurrentUser();
	my $form = getCurrentForm();

	# CHANGE DATE_ FUNCTIONS
	my $columns = 'hits, stories.commentcount as commentcount, stories.sid, stories.title, stories.uid, '
		. 'time, name, stories.section, displaystatus, stories.writestatus';
	my $tables = "stories, discussions, topics";
	my $where = "stories.tid=topics.tid AND stories.discussion=discussions.id";
	$where .= " AND stories.section='$user->{section}'" if $user->{section};
	$where .= " AND stories.section='$form->{section}'"
		if $form->{section} && !$user->{section};
	$where .= " AND time < DATE_ADD(NOW(), INTERVAL 72 HOUR) "
		if $form->{section} eq "";
	my $other = "ORDER BY time DESC LIMIT $first_story, $num_stories";

	my $count = $self->sqlSelect("COUNT(*)", $tables, $where);

	my $cursor = $self->{_dbh}->prepare("SELECT $columns FROM $tables WHERE $where $other");
	$cursor->execute;
	my $list = $cursor->fetchall_arrayref;

	return($count, $list);
}

##################################################################
sub getPollVotesMax {
	my($self, $qid) = @_;
	my $qid_quoted = $self->sqlQuote($qid);
	my($answer) = $self->sqlSelect("MAX(votes)", "pollanswers",
		"qid=$qid_quoted");
	return $answer;
}

##################################################################
sub getSlashdStatus {
        my($self) = @_;
	my $answer = _genericGet('slashd_status', 'task', '', @_);
	$answer->{last_completed_hhmm} =
		substr($answer->{last_completed}, 11, 5)
		if defined($answer->{last_completed});
	$answer->{next_begin_hhmm} =
		substr($answer->{next_begin}, 11, 5)
		if defined($answer->{next_begin});
	$answer->{summary_trunc} =
		substr($answer->{summary}, 0, 30)
		if $answer->{summary};
	return $answer;
}

##################################################################
sub getSlashdStatuses {
	my($self) = @_;
	my $answer = $self->sqlSelectAllHashref(
		"task",
		"*",
		"slashd_status"
	);
	for my $task (keys %$answer) {
		$answer->{$task}{last_completed_hhmm} =
			substr($answer->{$task}{last_completed}, 11, 5)
			if defined($answer->{$task}{last_completed});
		$answer->{$task}{next_begin_hhmm} =
			substr($answer->{$task}{next_begin}, 11, 5)
			if defined($answer->{$task}{next_begin});
		$answer->{$task}{summary_trunc} =
			substr($answer->{$task}{summary}, 0, 30)
			if $answer->{$task}{summary};
	}
	return $answer;
}

##################################################################
# Probably should make this private at some point
sub _saveExtras {
	my($self, $story) = @_;

	# Update main-page write status if saved story is marked 
	# "Always Display" or "Never Display".
	$self->setVar('writestatus', 'dirty') if $story->{displaystatus} < 1;

	my $extras = $self->getSectionExtras($story->{section});
	return unless $extras;
	for (@$extras) {
		my $key = $_->[1];
		$self->sqlReplace('story_param', { 
			sid	=> $story->{sid}, 
			name	=> $key,
			value	=> $story->{$key},
		}) if $story->{$key};
	}
}

########################################################
sub getStory {
	my($self, $id, $val, $force_cache_freshen) = @_;
	my $constants = getCurrentStatic();

	# If our story cache is too old, expire it.
	_genericCacheRefresh($self, 'stories', $constants->{story_expire});
	my $table_cache = '_stories_cache';
	my $table_cache_time= '_stories_cache_time';

	my $val_scalar = 1;
	$val_scalar = 0 if !$val or ref($val);

	# Go grab the data if we don't have it, or if the caller
	# demands that we grab it anyway.
	my $is_in_cache = exists $self->{$table_cache}{$id};
	if (!$is_in_cache or $force_cache_freshen) {
		# We avoid the join here. Sure, it's two calls to the db,
		# but why do a join if it's not needed?
		my($append, $answer, $db_id);
		$db_id = $self->sqlQuote($id);
		$answer = $self->sqlSelectHashref('*', 'stories', "sid=$db_id");
		$append = $self->sqlSelectHashref('*', 'story_text', "sid=$db_id");
		for my $key (keys %$append) {
			$answer->{$key} = $append->{$key};
		}
		$append = $self->sqlSelectAll('name,value', 'story_param', "sid=$db_id");
		for my $ary_ref (@$append) {
			$answer->{$ary_ref->[0]} = $ary_ref->[1];
		}
		if (!$answer or ref($answer) ne 'HASH') {
			# If there's no data for this sid, then there's no data
			# for us to return, and we shouldn't touch the cache.
			return undef;
		}
		# If this is the first data we're writing into the cache,
		# mark the time -- this data, and any other stories we
		# write into the cache for the next n seconds, will be
		# expired at that time.
		$self->{$table_cache_time} = time() if !$self->{$table_cache_time};
		# Cache the data.
		$self->{$table_cache}{$id} = $answer;
	}

	# The data is in the table cache now.
	if ($val_scalar) {
		# Caller only asked for one return value.
		if (exists $self->{$table_cache}{$id}{$val}) {
			return $self->{$table_cache}{$id}{$val};
		} else {
			return undef;
		}
	} else {
		# Caller asked for multiple return values.  It really doesn't
		# matter what specifically they asked for, we always return
		# the same thing:  a hashref with all the values.
		my %return = %{$self->{$table_cache}{$id}};
		return \%return;
	}
}

########################################################
sub getSimilarStories {
	my($self, $story, $max_wanted) = @_;
	$max_wanted ||= 100;
	my $constants = getCurrentStatic();
	my($title, $introtext, $bodytext) =
		($story->{title} || "",
		 $story->{introtext} || "",
		 $story->{bodytext} || "");
	my $not_original_sid = $story->{sid} || "";
	$not_original_sid = " AND stories.sid != "
		. $self->sqlQuote($not_original_sid)
		if $not_original_sid;
	my $backupdb;
	if ($constants->{backup_db_user}) {
		$backupdb = getObject('Slash::DB', $constants->{backup_db_user})
	} else {
		$backupdb = getCurrentDB();
	}

	my $text = "$title $introtext $bodytext";
	# Find a list of all the words in the current story.
	my $text_words = findWords($text);
	# Load up the list of words in recent stories (the only ones we
	# need to concern ourselves with looking for).
	my @recent_uncommon_words = split " ",
		($self->getVar("uncommonstorywords", "value") || "");
	# If we don't (yet) know the list of uncommon words, return now.
	return [ ] unless @recent_uncommon_words;
	# Find the intersection of this story and recent stories.
	my @text_uncommon_words =
		sort {
			$text_words->{$b}{weight} <=> $text_words->{$a}{weight}
			||
			$a cmp $b
		}
		grep { $text_words->{$_}{count} }
		grep { length($_) > 3 }
		@recent_uncommon_words;
#use Data::Dumper;
#print STDERR "text_words: " . Dumper($text_words);
#print STDERR "uncommon intersection: '@text_uncommon_words'\n";
	# If there is no intersection, return now.
	return [ ] unless @text_uncommon_words;
	# If that list is too long, don't use all of them.
	my $maxwords = $constants->{similarstorymaxwords} || 30;
	$#text_uncommon_words = $maxwords-1
		if $#text_uncommon_words > $maxwords-1;
	# Find previous stories which have used these words.
	my $where = "";
	my @where_clauses = ( );
	for my $word (@text_uncommon_words) {
		my $word_q = $self->sqlQuote('%' . $word . '%');
		push @where_clauses, "stories.title LIKE $word_q";
		push @where_clauses, "story_text.introtext LIKE $word_q";
		push @where_clauses, "story_text.bodytext LIKE $word_q";
	}
	$where = join(" OR ", @where_clauses);
	my $n_days = $constants->{similarstorydays} || 30;
	my $stories = $backupdb->sqlSelectAllHashref(
		"sid",
		"stories.sid AS sid, title, introtext, bodytext,
			time, displaystatus",
		"stories, story_text",
		"stories.sid = story_text.sid $not_original_sid
		 AND stories.time >= DATE_SUB(NOW(), INTERVAL $n_days DAY)
		 AND ($where)"
	);
#print STDERR "similar stories: " . Dumper($stories);

	for my $sid (keys %$stories) {
		# Add up the weights of each story in turn, for how closely
		# they match with the current story.  Include a multiplier
		# based on the length of the match.
		my $s = $stories->{$sid};
		$s->{weight} = 0;
		for my $word (@text_uncommon_words) {
			my $word_weight = 0;
			my $wr = qr{(?i:\b\Q$word\E)};
			my $m = log(length $word);
			$word_weight += 2.0*$m * (() = $s->{title} =~     m{$wr}g);
			$word_weight += 1.0*$m * (() = $s->{introtext} =~ m{$wr}g);
			$word_weight += 0.5*$m * (() = $s->{bodytext} =~  m{$wr}g);
			$s->{word_hr}{$word} = $word_weight if $word_weight > 0;
			$s->{weight} += $word_weight;
		}
		# Round off weight to 0 decimal places (to an integer).
		$s->{weight} = sprintf("%.0f", $s->{weight});
		# Store (the top-scoring-ten of) the words that connected
		# the original story to this story.
		$s->{words} = [
			sort { $s->{word_hr}{$b} <=> $s->{word_hr}{$a} }
			keys %{$s->{word_hr}}
		];
		$#{$s->{words}} = 9 if $#{$s->{words}} > 9;
	}
	# If any stories match and are above the threshold, return them.
	# Pull out the top $max_wanted scorers.  Then sort them by time.
	my $minweight = $constants->{similarstoryminweight} || 4;
	my @sids = sort {
		$stories->{$b}{weight} <=> $stories->{$a}{weight}
		||
		$stories->{$b}{'time'} cmp $stories->{$a}{'time'}
		||
		$a cmp $b
	} grep { $stories->{$_}{weight} >= $minweight } keys %$stories;
#print STDERR "all sids @sids stories " . Dumper($stories);
	return [ ] if !@sids;
	$#sids = $max_wanted-1 if $#sids > $max_wanted-1;
	# Now that we have only the ones we want, push them onto the
	# return list sorted by time.
	my $ret_ar = [ ];
	for my $sid (sort {
		$stories->{$b}{'time'} cmp $stories->{$a}{'time'}
		||
		$stories->{$b}{weight} <=> $stories->{$a}{weight}
		||
		$a cmp $b
	} @sids) {
		push @$ret_ar, {
			sid =>		$sid,
			weight =>	sprintf("%.0f", $stories->{$sid}{weight}),
			title =>	$stories->{$sid}{title},
			'time' =>	$stories->{$sid}{'time'},
			words =>	$stories->{$sid}{words},
			displaystatus => $stories->{$sid}{displaystatus},
		};
	}
#print STDERR "ret_ar " . Dumper($ret_ar);
	return $ret_ar;
}

########################################################
sub getAuthor {
	my($self) = @_;
	_genericCacheRefresh($self, 'authors_cache', getCurrentStatic('block_expire'));
	my $answer = _genericGetCache('authors_cache', 'uid', '', @_);
	return $answer;
}

########################################################
# This of course is modified from the norm
sub getAuthors {
	my $answer = _genericGetsCache('authors_cache', 'uid', '', @_);
	return $answer;
}

########################################################
# copy of getAuthors, for admins ... needed for anything?
sub getAdmins {
	my($self, $cache_flag) = @_;

	my $table = 'admins';
	my $table_cache= '_' . $table . '_cache';
	my $table_cache_time= '_' . $table . '_cache_time';
	my $table_cache_full= '_' . $table . '_cache_full';

	if (keys %{$self->{$table_cache}} && $self->{$table_cache_full} && !$cache_flag) {
		my %return = %{$self->{$table_cache}};
		return \%return;
	}

	$self->{$table_cache} = {};
	my $sth = $self->sqlSelectMany(
		'users.uid,nickname,fakeemail,homepage,bio',
		'users,users_info',
		'seclev >= 100 and users.uid = users_info.uid'
	);
	while (my $row = $sth->fetchrow_hashref) {
		$self->{$table_cache}{ $row->{'uid'} } = $row;
	}

	$self->{$table_cache_full} = 1;
	$sth->finish;
	$self->{$table_cache_time} = time();

	my %return = %{$self->{$table_cache}};
	return \%return;
}

########################################################
sub getComment {
	my $answer = _genericGet('comments', 'cid', '', @_);
	return $answer;
}

########################################################
sub getPollQuestion {
	my $answer = _genericGet('pollquestions', 'qid', '', @_);
	return $answer;
}

########################################################
sub getRelatedLink {
	my $answer = _genericGet('related_links', 'id', '', @_);
	return $answer;
}

########################################################
sub getDiscussion {
	my $answer = _genericGet('discussions', 'id', '', @_);
	return $answer;
}

########################################################
sub getDiscussionBySid {
	my $answer = _genericGet('discussions', 'sid', '', @_);
	return $answer;
}

########################################################
sub getRSS {
	my $answer = _genericGet('rss_raw', 'id', '', @_);
	return $answer;
}

########################################################
sub setRSS {
	_genericSet('rss_raw', 'id', '', @_);
}

########################################################
sub getBlock {
	my($self) = @_;
	_genericCacheRefresh($self, 'blocks', getCurrentStatic('block_expire'));
	my $answer = _genericGetCache('blocks', 'bid', '', @_);
	return $answer;
}

########################################################
sub getTemplateNameCache {
	my($self) = @_;
	my %cache;
	my $templates = $self->sqlSelectAll('tpid,name,page,section', 'templates');
	for (@$templates) {
		$cache{$_->[1], $_->[2], $_->[3]} = $_->[0];
	}
	return \%cache;
}

########################################################
sub existsTemplate {
	# if this is going to get called a lot, we already
	# have the template names cached -- pudge
	my($self, $template) = @_;
	my $answer = $self->sqlSelect('tpid', 'templates', "name = '$template->{name}' AND section = '$template->{section}' AND page = '$template->{page}'");
	return $answer;
}

########################################################
sub getTemplate {
	my($self) = @_;
	_genericCacheRefresh($self, 'templates', getCurrentStatic('block_expire'));
	my $answer = _genericGetCache('templates', 'tpid', '', @_);
	return $answer;
}

########################################################
# This is a bit different
sub getTemplateByName {
	my($self, $name, $values, $cache_flag, $page, $section, $ignore_errors) = @_;
	return if ref $name;	# no scalar refs, only text names
	my $constants = getCurrentStatic();
	_genericCacheRefresh($self, 'templates', $constants->{'block_expire'});

	my $table_cache = '_templates_cache';
	my $table_cache_time= '_templates_cache_time';
	my $table_cache_id= '_templates_cache_id';

	#First, we get the cache
	$self->{$table_cache_id} =
		$constants->{'cache_enabled'} && $self->{$table_cache_id}
		? $self->{$table_cache_id} : getTemplateNameCache($self);

	#Now, lets determine what we are after
	unless ($page) {
		$page = getCurrentUser('currentPage');
		$page ||= 'misc';
	}
	unless ($section) {
		$section = getCurrentUser('currentSection');
		$section ||= 'default';
	}

	#Now, lets figure out the id
	#name|page|section => name|page|default => name|misc|section => name|misc|default
	# That frat boy march with a paddle
	my $id = $self->{$table_cache_id}{$name, $page,  $section };
	$id  ||= $self->{$table_cache_id}{$name, $page,  'default'};
	$id  ||= $self->{$table_cache_id}{$name, 'misc', $section };
	$id  ||= $self->{$table_cache_id}{$name, 'misc', 'default'};
	if (!$id) {
		if (!$ignore_errors) {
			# Not finding a template is reasonably serious.  Let's make the
			# error log entry pretty descriptive.
			my @caller_info = ( );
			for (my $lvl = 1; $lvl < 99; ++$lvl) {
				my @c = caller($lvl);
				last unless @c;
				next if $c[0] =~ /^Template/;
				push @caller_info, "$c[0] line $c[2]";
				last if scalar(@caller_info) >= 3;
			}
			errorLog("Failed template lookup on '$name;$page\[misc\];$section\[default\]'"
				. ", callers: " . join(", ", @caller_info));
		}
		return ;
	}

	my $type;
	if (ref($values) eq 'ARRAY') {
		$type = 0;
	} else {
		$type  = $values ? 1 : 0;
	}

	if (!$cache_flag && exists $self->{$table_cache}{$id} && keys %{$self->{$table_cache}{$id}}) {
		if ($type) {
			return $self->{$table_cache}{$id}{$values};
		} else {
			my %return = %{$self->{$table_cache}{$id}};
			return \%return;
		}
	}

	$self->{$table_cache}{$id} = {};
	my $answer = $self->sqlSelectHashref('*', "templates", "tpid=$id");
	$answer->{'_modtime'} = time();
	$self->{$table_cache}{$id} = $answer;

	$self->{$table_cache_time} = time();

	if ($type) {
		return $self->{$table_cache}{$id}{$values};
	} else {
		if ($self->{$table_cache}{$id}) {
			my %return = %{$self->{$table_cache}{$id}};
			return \%return;
		}
	}

	return $answer;
}

########################################################
sub getTopic {
	my $answer = _genericGetCache('topics', 'tid', '', @_);
	return $answer;
}

########################################################
sub getSectionTopicType {
	my($self, $tid) = @_;

	return [] unless $tid;
	my $type = $self->sqlSelectAll('section,type', 'section_topics', "tid = $tid");

	return $type || [];
}

########################################################
sub getTopics {
	my $answer = _genericGetsCache('topics', 'tid', '', @_);
	return $answer;
}

########################################################
# add_names = 1, or any other non-zero/non-two value  -> Topic Alt text.
# add_names = 2 -> Topic Name.
sub getStoryTopics {
	my($self, $sid, $add_names) = @_;
	my($topicdesc);

	my $topics = $self->sqlSelectAll(
		'tid',
		'story_topics',
		'sid=' . $self->sqlQuote($sid)
	);

	# All this to avoid a join. :/
	#
	# Poor man's hash assignment from an array for the short names.
	$topicdesc =  {
		map { @{$_} }
		@{$self->sqlSelectAll(
			'tid, name',
			'topics'
		)}
	} if $add_names == 2;

	# We use a Description for the long names. 
	$topicdesc = $self->getDescriptions('topics') 
		if !$topicdesc && $add_names;

	my $answer;
	$answer->{$_->[0]} = $add_names && $topicdesc ? $topicdesc->{$_->[0]}:1
		for @{$topics};

	return $answer;
}

########################################################
sub setStoryTopics {
	my($self, $sid, $topic_ref) = @_;

	$self->sqlDo("DELETE from story_topics where sid = '$sid'");

	for (@{$topic_ref}) {
	    $self->sqlInsert("story_topics", { sid => $sid, tid => $_ });
	}
}

########################################################
sub getTemplates {
	my $answer = _genericGetsCache('templates', 'tpid', '', @_);
	return $answer;
}

########################################################
sub getContentFilter {
	my $answer = _genericGet('content_filters', 'filter_id', '', @_);
	return $answer;
}

########################################################
sub getSubmission {
	my $answer = _genericGet('submissions', 'subid', 'submission_param', @_);
	return $answer;
}

########################################################
sub setSubmission {
	_genericSet('submissions', 'subid', 'submission_param', @_);
}

########################################################
sub getSection {
	my($self, $section) = @_;
	if (!$section) {
		my $constants = getCurrentStatic();
		return {
			title    => "$constants->{sitename}: $constants->{slogan}",
			artcount => getCurrentUser('maxstories') || 30,
			issue    => 3
		};
	}

	my $answer = _genericGetCache('sections', 'section', '', @_);
	return $answer;
}

########################################################
sub getSubSection {
	my $answer = _genericGetCache('subsections', 'id', '', @_);
	return $answer;
}

########################################################
sub getSections {
	my $answer = _genericGetsCache('sections', 'section', '', @_);
	return $answer;
}

########################################################
sub getSubSections {
	my $answer = _genericGetsCache('subsections', 'id', '', @_);
	return $answer;
}

########################################################
sub getSubSectionsBySection {
	my($self, $section) = @_;

	my $answer = $self->sqlSelectAllHashrefArray(
		'*',
		'subsections',
		'section=' . $self->sqlQuote($section)
	);

	return $answer;
}

########################################################
sub getModeratorLog {
	my $answer = _genericGet('moderatorlog', 'id', '', @_);
	return $answer;
}

########################################################
sub getVar {
	my $answer = _genericGet('vars', 'name', '', @_);
	return $answer;
}

########################################################
sub setUser {
	my($self, $uid, $hashref) = @_;
	my(@param, %update_tables, $cache);
	my $tables = [qw(
		users users_comments users_index
		users_info users_prefs
		users_hits
	)];

	# special cases for password, exboxes, people
	if (exists $hashref->{passwd}) {
		# get rid of newpasswd if defined in DB
		$hashref->{newpasswd} = '';
		$hashref->{passwd} = encryptPassword($hashref->{passwd});
	}

	# Power to the People
	if ($hashref->{people}) {
		my $people = $hashref->{people};
		$hashref->{people} = freeze($people);
	}

	# hm, come back to exboxes later; it works for now
	# as is, since external scripts handle it -- pudge
	# a VARARRAY would make a lot more sense for this, no need to
	# pack either -Brian
	if (0 && exists $hashref->{exboxes}) {
		if (ref $hashref->{exboxes} eq 'ARRAY') {
			$hashref->{exboxes} = sprintf("'%s'", join "','", @{$hashref->{exboxes}});
		} elsif (ref $hashref->{exboxes}) {
			$hashref->{exboxes} = '';
		} # if nonref scalar, just let it pass
	}

	$cache = _genericGetCacheName($self, $tables);

	for (keys %$hashref) {
		(my $clean_val = $_) =~ s/^-//;
		my $key = $self->{$cache}{$clean_val};
		if ($key) {
			push @{$update_tables{$key}}, $_;
		} else {
			push @param, [$_, $hashref->{$_}];
		}
	}

	for my $table (keys %update_tables) {
		my %minihash;
		for my $key (@{$update_tables{$table}}){
			$minihash{$key} = $hashref->{$key}
				if defined $hashref->{$key};
		}
		$self->sqlUpdate($table, \%minihash, 'uid=' . $uid, 1);
	}
	# What is worse, a select+update or a replace?
	# I should look into that. (REPLACE is faster) -Brian
	for (@param)  {
		if ($_->[1] eq "") {
			$self->sqlDelete('users_param', 
				"uid = $uid AND name = " . $self->sqlQuote($_->[0]));
		} elsif ($_->[0] eq "acl") {
			$self->sqlReplace('users_acl', {
				uid	=> $uid,
				name	=> $_->[1]{name},
				value	=> $_->[1]{value},
			});
		} else {
			$self->sqlReplace('users_param', {
				uid	=> $uid,
				name	=> $_->[0],
				value	=> $_->[1],
			}) if defined $_->[1];
		}
	}
}

########################################################
# Now here is the thing. We want getUser to look like
# a generic, despite the fact that it is not :)
sub getUser {
	my($self, $id, $val) = @_;
	my $answer;
	my $tables = [qw(
		users users_comments users_index
		users_info users_prefs users_hits
	)];
	# The sort makes sure that someone will always get the cache if
	# they have the same tables
	my $cache = _genericGetCacheName($self, $tables);

	if (ref($val) eq 'ARRAY') {
		my($values, %tables, @param, $where, $table);
		for (@$val) {
			(my $clean_val = $_) =~ s/^-//;
			if ($self->{$cache}{$clean_val}) {
				$tables{$self->{$cache}{$_}} = 1;
				$values .= "$_,";
			} else {
				push @param, $_;
			}
		}
		chop($values);

		for (keys %tables) {
			$where .= "$_.uid=$id AND ";
		}
		$where =~ s/ AND $//;

		$table = join ',', keys %tables;
		$answer = $self->sqlSelectHashref($values, $table, $where)
			if $values;
		for (@param) {
			# First we try it as an acl param -acs
			my $val = $self->sqlSelect('value', 'users_acl', "uid=$id AND name='$_'");
			$val = $self->sqlSelect('value', 'users_param', "uid=$id AND name='$_'") if !$val;
			$answer->{$_} = $val;
		}

	} elsif ($val) {
		(my $clean_val = $val) =~ s/^-//;
		my $table = $self->{$cache}{$clean_val};
		if ($table) {
			$answer = $self->sqlSelect($val, $table, "uid=$id");
		} else {
			# First we try it as an acl param -acs
			$answer = $self->sqlSelect('value', 'users_acl', "uid=$id AND name='$val'");
			$answer = $self->sqlSelect('value', 'users_param', "uid=$id AND name='$val'") if !$answer;
		}

	} else {

		# The five-way join is causing us some pain.  For testing, let's
		# use a var to decide whether to do it that way, or a new way
		# where we do multiple SELECTs.  Let the var decide how many
		# SELECTs we do, and if more than 1, the first tables we'll pull
		# off separately are Rob's suspicions:  users_prefs and
		# users_comments.

		my $n = getCurrentStatic('num_users_selects') || 1;
		my @tables_ordered = qw( users users_index
			users_info users_hits
			users_comments users_prefs );
		while ($n > 0) {
			my @tables_thispass = ( );
			if ($n > 1) {
				# Grab the columns from the last table still
				# on the list.
				@tables_thispass = pop @tables_ordered;
			} else {
				# This is the last SELECT we'll be doing, so
				# join all remaining tables.
				@tables_thispass = @tables_ordered;
			}
			my $table = join(",", @tables_thispass);
			my $where = join(" AND ", map { "$_.uid=$id" } @tables_thispass);
			if (!$answer) {
				$answer = $self->sqlSelectHashref('*', $table, $where);
			} else {
				my $moreanswer = $self->sqlSelectHashref('*', $table, $where);
				for (keys %$moreanswer) {
					$answer->{$_} = $moreanswer->{$_}
						unless exists $answer->{$_};
				}
			}
			$n--;
		}

		my($append_acl, $append);
		$append_acl = $self->sqlSelectAll('name,value', 'users_acl', "uid=$id");
		for (@$append_acl) {
			$answer->{$_->[0]} = $_->[1];
		}
		$append = $self->sqlSelectAll('name,value', 'users_param', "uid=$id");
		for (@$append) {
			$answer->{$_->[0]} = $_->[1];
		}
	}

	# we have a bit of cleanup to do before returning;
	# thaw the people element, and clean up possibly broken
	# exsect/exaid/extid.  gotta do it separately for hashrefs ...
	if (ref($answer) eq 'HASH') {
		for (qw(exaid extid exsect)) {
			next unless $answer->{$_};
			$answer->{$_} =~ s/,'[^']+$//;
			$answer->{$_} =~ s/,'?$//;
		}
		$answer->{'people'} = thaw($answer->{'people'}) if $answer->{'people'};

	# ... and for scalars
	} else {
		if ($val eq 'people') {
			$answer = thaw($answer);
		} elsif ($val =~ m/^ex(?:aid|tid|sect)$/) {
			$answer =~ s/,'[^']+$//;
			$answer =~ s/,'?$//;
		}
	}

	return $answer;
}

########################################################
# This could be optimized by not making multiple calls
# to getKeys or by fixing getKeys() to return multiple
# values
sub _genericGetCacheName {
	my($self, $tables) = @_;
	my $cache;

	if (ref($tables) eq 'ARRAY') {
		$cache = '_' . join ('_', sort(@$tables), 'cache_tables_keys');
		unless (keys %{$self->{$cache}}) {
			for my $table (@$tables) {
				my $keys = $self->getKeys($table);
				for (@$keys) {
					$self->{$cache}{$_} = $table;
				}
			}
		}
	} else {
		$cache = '_' . $tables . 'cache_tables_keys';
		unless (keys %{$self->{$cache}}) {
			my $keys = $self->getKeys($tables);
			for (@$keys) {
				$self->{$cache}{$_} = $tables;
			}
		}
	}
	return $cache;
}

########################################################
# Now here is the thing. We want setUser to look like
# a generic, despite the fact that it is not :)
# We assum most people called set to hit the database
# and just not the cache (if one even exists)
sub _genericSet {
	my($table, $table_prime, $param_table, $self, $id, $value) = @_;

	if ($param_table) {
		my $cache = _genericGetCacheName($self, $table);

		my(@param, %updates);
		for (keys %$value) {
			(my $clean_val = $_) =~ s/^-//;
			my $key = $self->{$cache}{$clean_val};
			if ($key) {
				$updates{$_} = $value->{$_};
			} else {
				push @param, [$_, $value->{$_}];
			}
		}
		$self->sqlUpdate($table, \%updates, $table_prime . '=' . $self->sqlQuote($id))
			if keys %updates;
		# What is worse, a select+update or a replace?
		# I should look into that. if EXISTS() the
		# need for a fully sql92 database.
		# transactions baby, transactions... -Brian
		for (@param)  {
			$self->sqlReplace($param_table, { $table_prime => $id, name => $_->[0], value => $_->[1]});
		}
	} else {
		$self->sqlUpdate($table, $value, $table_prime . '=' . $self->sqlQuote($id));
	}

	my $table_cache= '_' . $table . '_cache';
	return unless keys %{$self->{$table_cache}};

	my $table_cache_time= '_' . $table . '_cache_time';
	$self->{$table_cache_time} = time();
	for (keys %$value) {
		$self->{$table_cache}{$id}{$_} = $value->{$_};
	}
	$self->{$table_cache}{$id}{'_modtime'} = time();
}

########################################################
# You can use this to reset cache's in a timely
# manner :)
sub _genericCacheRefresh {
	my($self, $table,  $expiration) = @_;
	return unless $expiration;
	my $table_cache = '_' . $table . '_cache';
	my $table_cache_time = '_' . $table . '_cache_time';
	my $table_cache_full = '_' . $table . '_cache_full';
	return unless $self->{$table_cache_time};
	my $time = time();
	my $diff = $time - $self->{$table_cache_time};

	if ($diff > $expiration) {
		# print STDERR "TIME:$diff:$expiration:$time:$self->{$table_cache_time}:\n";
		$self->{$table_cache} = {};
		$self->{$table_cache_time} = 0;
		$self->{$table_cache_full} = 0;
	}
}

########################################################
# This is protected and don't call it from your
# scripts directly.
sub _genericGetCache {
	return _genericGet(@_) unless getCurrentStatic('cache_enabled');

	my($table, $table_prime, $param_table,  $self, $id, $values, $cache_flag) = @_;
	my $table_cache = '_' . $table . '_cache';
	my $table_cache_time= '_' . $table . '_cache_time';

	my $type;
	if (ref($values) eq 'ARRAY') {
		$type = 0;
	} else {
		$type  = $values ? 1 : 0;
	}

	if ($type) {
		return $self->{$table_cache}{$id}{$values}
			if (keys %{$self->{$table_cache}{$id}} and !$cache_flag);
	} else {
		if (keys %{$self->{$table_cache}{$id}} && !$cache_flag) {
			my %return = %{$self->{$table_cache}{$id}};
			return \%return;
		}
	}

	$self->{$table_cache}{$id} = {};
	my $answer = $self->sqlSelectHashref('*', $table, "$table_prime=" . $self->sqlQuote($id));
	$answer->{'_modtime'} = time();
	if ($param_table) {
		my $append = $self->sqlSelectAll('name,value', $param_table, "$table_prime=" . $self->sqlQuote($id));
		for (@$append) {
			$answer->{$_->[0]} = $_->[1];
		}
	}
	$self->{$table_cache}{$id} = $answer;

	$self->{$table_cache_time} = time();

	if ($type) {
		return $self->{$table_cache}{$id}{$values};
	} else {
		if ($self->{$table_cache}{$id}) {
			my %return = %{$self->{$table_cache}{$id}};
			return \%return;
		} else {
			return;
		}
	}
}

########################################################
# This is protected and don't call it from your
# scripts directly.
sub _genericClearCache {
	my($table, $self) = @_;
	my $table_cache= '_' . $table . '_cache';

	$self->{$table_cache} = {};
}

########################################################
# This is protected and don't call it from your
# scripts directly.
sub _genericGet {
	my($table, $table_prime, $param_table, $self, $id, $val) = @_;
	my($answer, $type);
	my $id_db = $self->sqlQuote($id);

	if ($param_table) {
	# With Param table
		if (ref($val) eq 'ARRAY') {
			my $cache = _genericGetCacheName($self, $table);

			my($values, @param);
			for (@$val) {
				(my $clean_val = $_) =~ s/^-//;
				if ($self->{$cache}{$clean_val}) {
					$values .= "$_,";
				} else {
					push @param, $_;
				}
			}
			chop($values);

			$answer = $self->sqlSelectHashref($values, $table, "$table_prime=$id_db");
			for (@param) {
				my $val = $self->sqlSelect('value', $param_table, "$table_prime=$id_db AND name='$_'");
				$answer->{$_} = $val;
			}

		} elsif ($val) {
			my $cache = _genericGetCacheName($self, $table);
			(my $clean_val = $val) =~ s/^-//;
			my $table = $self->{$cache}{$clean_val};
			if ($table) {
				($answer) = $self->sqlSelect($val, $table, "uid=$id");
			} else {
				($answer) = $self->sqlSelect('value', $param_table, "$table_prime=$id_db AND name='$val'");
			}

		} else {
			$answer = $self->sqlSelectHashref('*', $table, "$table_prime=$id_db");
			my $append = $self->sqlSelectAll('name,value', $param_table, "$table_prime=$id_db");
			for (@$append) {
				$answer->{$_->[0]} = $_->[1];
			}
		}
	} else {
	# Without Param table
		if (ref($val) eq 'ARRAY') {
			my $values = join ',', @$val;
			$answer = $self->sqlSelectHashref($values, $table, "$table_prime=$id_db");
		} elsif ($val) {
			($answer) = $self->sqlSelect($val, $table, "$table_prime=$id_db");
		} else {
			$answer = $self->sqlSelectHashref('*', $table, "$table_prime=$id_db");
		}
	}


	return $answer;
}

########################################################
# This is protected and don't call it from your
# scripts directly.
sub _genericGetsCache {
	return _genericGets(@_) unless getCurrentStatic('cache_enabled');

	my($table, $table_prime, $param_Table, $self, $cache_flag) = @_;
	my $table_cache= '_' . $table . '_cache';
	my $table_cache_time= '_' . $table . '_cache_time';
	my $table_cache_full= '_' . $table . '_cache_full';

	if (keys %{$self->{$table_cache}} && $self->{$table_cache_full} && !$cache_flag) {
		my %return = %{$self->{$table_cache}};
		return \%return;
	}

	# Lets go knock on the door of the database
	# and grab the data since it is not cached
	# On a side note, I hate grabbing "*" from a database
	# -Brian
	$self->{$table_cache} = {};
#	my $sth = $self->sqlSelectMany('*', $table);
#	while (my $row = $sth->fetchrow_hashref) {
#		$row->{'_modtime'} = time();
#		$self->{$table_cache}{ $row->{$table_prime} } = $row;
#	}
#	$sth->finish;
	$self->{$table_cache} = _genericGets(@_);
	$self->{$table_cache_full} = 1;
	$self->{$table_cache_time} = time();

	my %return = %{$self->{$table_cache}};
	return \%return;
}

########################################################
# This is protected and don't call it from your
# scripts directly.
sub _genericGets {
	my($table, $table_prime, $param_table, $self, $values) = @_;
	my(%return, $sth, $params);

	if (ref($values) eq 'ARRAY') {
		my $get_values;

		if ($param_table) {
			my $cache = _genericGetCacheName($self, $table);
			for (@$values) {
				(my $clean_val = $_) =~ s/^-//;
				if ($self->{$cache}{$clean_val}) {
					push @$get_values, $_;
				} else {
					my $val = $self->sqlSelectAll("$table_prime, name, value", $param_table, "name='$_'");
					for my $row (@$val) {
						push @$params, $row;
					}
				}
			}
		} else {
			$get_values = $values;
		}
		if ($get_values) {
			my $val = join ',', @$get_values;
			$val .= ",$table_prime" unless grep $table_prime, @$get_values;
			$sth = $self->sqlSelectMany($val, $table);
		}
	} elsif ($values) {
		if ($param_table) {
			my $cache = _genericGetCacheName($self, $table);
			(my $clean_val = $values) =~ s/^-//;
			my $use_table = $self->{$cache}{$clean_val};

			if ($use_table) {
				$values .= ",$table_prime" unless $values eq $table_prime;
				$sth = $self->sqlSelectMany($values, $table);
			} else {
				my $val = $self->sqlSelectAll("$table_prime, name, value", $param_table, "name=$values");
				for my $row (@$val) {
					push @$params, $row;
				}
			}
		} else {
			$values .= ",$table_prime" unless $values eq $table_prime;
			$sth = $self->sqlSelectMany($values, $table);
		}
	} else {
		$sth = $self->sqlSelectMany('*', $table);
		if ($param_table) {
			$params = $self->sqlSelectAll("$table_prime, name, value", $param_table);
		}
	}

	if ($sth) {
		while (my $row = $sth->fetchrow_hashref) {
			$return{ $row->{$table_prime} } = $row;
		}
		$sth->finish;
	}

	if ($params) {
		for (@$params) {
			# this is not right ... perhaps the other is? -- pudge
#			${return->{$_->[0]}->{$_->[1]}} = $_->[2]
			$return{$_->[0]}{$_->[1]} = $_->[2]
		}
	}

	return \%return;
}

########################################################
# This is only called by Slash/DB/t/story.t and it doesn't even serve much purpose
# there...I assume we can kill it?  - Jamie
# Actually, we should keep it around since it is a generic method -Brian
# I am using it for something on OSDN.com -- pudge
sub getStories {
	my $answer = _genericGets('stories', 'sid', 'story_param', @_);
	return $answer;
}

########################################################
sub getRelatedLinks {
	my $answer = _genericGets('related_links', 'id', '', @_);
	return $answer;
}

########################################################
sub getHooksByParam {
	my ($self, $param) = @_;
	my $answer = $self->sqlSelectAllHashrefArray('*', 'hooks', 'param =' . $self->sqlQuote($param) );
	return $answer;
}

########################################################
sub getHook {
	my $answer = _genericGet('hooks', 'id', '', @_);
	return $answer;
}

########################################################
sub createHook {
	my($self, $hash) = @_;

	$self->sqlInsert('hooks', $hash);
}

########################################################
sub deleteHook {
	my($self, $id) = @_;

	$self->sqlDelete('hooks', 'id =' . $self->sqlQuote($id));  
}

########################################################
sub setHook {
	my($self, $id, $value) = @_;
	$self->sqlUpdate('hooks', $value, 'id=' . $self->sqlQuote($id));
}

########################################################
# single big select for ForumZilla ... if someone wants to
# improve on this, please go ahead
sub fzGetStories {
	my($self, $section) = @_;
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();

	my $section_where;
	if ($section) {
		my $section_dbi = $self->sqlQuote($section || '');
		$section_where = "(S.displaystatus>=0 AND S.section=$section_dbi) ";
	} elsif ($user->{sectioncollapse}) {
		$section_where = "S.displaystatus>=0 ";
	} else {
		$section_where = "S.displaystatus=0 ";
	}

# right now, we do not get lastcommentdate ... this is too big a drain
# on the server. -- pudge
#,MAX(comments.date) AS lastcommentdate
#LEFT OUTER JOIN comments ON discussions.id = comments.sid

# stories as S for when we did a join, keep in case we do another
# at some point -- pudge
	my $data = $slashdb->sqlSelectAllHashrefArray(<<S, <<F, <<W, <<E);
S.sid, S.title, S.time, S.commentcount
S
stories AS S
F
    time < NOW()
AND S.writestatus != 'delete' 
AND $section_where
W
GROUP BY S.sid
ORDER BY S.time DESC
LIMIT 10
E

	# note that LIMIT could be a var -- pudge
	return $data;
}


########################################################
sub getSessions {
	my $answer = _genericGets('sessions', 'session', '', @_);
	return $answer;
}

########################################################
sub createBlock {
	my($self, $hash) = @_;
	$self->sqlInsert('blocks', $hash);

	return $hash->{bid};
}

########################################################
sub createRelatedLink {
	my($self, $hash) = @_;
	$self->sqlInsert('related_links', $hash);
}

########################################################
sub createTemplate {
	my($self, $hash) = @_;
	for (qw| page name section |) {
		next unless $hash->{$_};
		if ($hash->{$_} =~ /;/) {
			errorLog("A semicolon was found in the $_ while trying to create a template");
			return;
		}
	}
	# Instructions field does not get passed to the DB.
	delete $hash->{instructions};

	$self->sqlInsert('templates', $hash);
	my $tpid  = $self->getLastInsertId('templates', 'tpid');
	return $tpid;
}

########################################################
sub createMenuItem {
	my($self, $hash) = @_;
	$self->sqlInsert('menus', $hash);
}

########################################################
# It'd be faster for getMenus() to just "SELECT *" and parse
# the results into a perl hash, than to "SELECT DISTINCT" and
# then make separate calls to getMenuItems. XXX - Jamie
sub getMenuItems {
	my($self, $script) = @_;
	my $sql = "SELECT * FROM menus WHERE page=" . $self->sqlQuote($script) . " ORDER by menuorder";
	my $sth = $self->{_dbh}->prepare($sql);
	$sth->execute();
	my(@menu, $row);
	push(@menu, $row) while ($row = $sth->fetchrow_hashref);
	$sth->finish;

	return \@menu;
}

########################################################
sub getMiscUserOpts {
	my($self) = @_;

	my $user_seclev = getCurrentUser('seclev') || 0;
	my $hr = $self->sqlSelectAllHashref("name", "*", "misc_user_opts",
		"seclev <= $user_seclev");
	my $ar = [ ];
	for my $row (
		sort { $hr->{$a}{optorder} <=> $hr->{$b}{optorder} } keys %$hr
	) {
		push @$ar, $hr->{$row};
	}
	return $ar;
}

########################################################
sub getMenus {
	my($self) = @_;

	my $sql = "SELECT DISTINCT menu FROM menus ORDER BY menu";
	my $sth = $self->{_dbh}->prepare($sql);
	$sth->execute;
	my $menu_names = $sth->fetchall_arrayref;
	$sth->finish;

	my $menus;
	for (@$menu_names) {
		my $script = $_->[0];
		$sql = "SELECT * FROM menus WHERE menu=" . $self->sqlQuote($script) . " ORDER by menuorder";
		$sth =	$self->{_dbh}->prepare($sql);
		$sth->execute();
		my(@menu, $row);
		push(@menu, $row) while ($row = $sth->fetchrow_hashref);
		$sth->finish;
		$menus->{$script} = \@menu;
	}

	return $menus;
}

########################################################
sub sqlReplace {
	my($self, $table, $data) = @_;
	my($names, $values);

	foreach (keys %$data) {
		if (/^-/) {
			$values .= "\n  $data->{$_},";
			s/^-//;
		} else {
			$values .= "\n  " . $self->sqlQuote($data->{$_}) . ',';
		}
		$names .= "$_,";
	}

	chop($names);
	chop($values);

	my $sql = "REPLACE INTO $table ($names) VALUES($values)\n";
	$self->sqlConnect();
	return $self->sqlDo($sql) or errorLog($sql);
}

##################################################################
# This should be rewritten so that at no point do we
# pass along an array -Brian
sub getKeys {
	my($self, $table) = @_;
	my $keys = $self->sqlSelectColumns($table)
		if $self->sqlTableExists($table);

	return $keys;
}

########################################################
sub sqlTableExists {
	my($self, $table) = @_;
	return unless $table;

	$self->sqlConnect();
	my $tab = $self->{_dbh}->selectrow_array(qq!SHOW TABLES LIKE "$table"!);
	return $tab;

#	if (wantarray) {
#		my(@tabs) = map { $_->[0] }
#			@{$self->{_dbh}->selectall_arrayref(
#				qq!SHOW TABLES LIKE "$table"!
#			)};
#		return @tabs;
#	} else {
#		my $tab = $self->{_dbh}->selectrow_array(
#			qq!SHOW TABLES LIKE "$table"!
#		);
#		return $tab;
#	}
}

########################################################
sub sqlSelectColumns {
	my($self, $table) = @_;
	return unless $table;

	$self->sqlConnect();
	my $rows = $self->{_dbh}->selectcol_arrayref("SHOW COLUMNS FROM $table");
	return $rows;
}

########################################################
sub getRandomSpamArmor {
	my($self) = @_;

	my $ret = $self->sqlSelectAllHashref(
		'armor_id', '*', 'spamarmors', 'active=1'
	);
	my @armor_keys = keys %{$ret};

	# array index automatically int'd
	return $ret->{$armor_keys[rand($#armor_keys + 1)]};
}

########################################################
sub sqlShowProcessList {
	my($self) = @_;

	$self->sqlConnect();
	my $proclist = $self->{_dbh}->prepare("SHOW PROCESSLIST");

	return $proclist;
}

########################################################
sub sqlShowStatus {
	my($self) = @_;

	$self->sqlConnect();
	my $status = $self->{_dbh}->prepare("SHOW STATUS");

	return $status;
}

########################################################
# Get a unique string for an admin session
#sub generatesession {
#	# crypt() may be implemented differently so as to
#	# make the field in the db too short ... use the same
#	# MD5 encrypt function?  is this session thing used
#	# at all anymore?
#	my $newsid = crypt(rand(99999), $_[0]);
#	$newsid =~ s/[^A-Za-z0-9]//i;
#
#	return $newsid;
#}

1;

__END__

=head1 NAME

Slash::DB::MySQL - MySQL Interface for Slash

=head1 SYNOPSIS

	use Slash::DB::MySQL;

=head1 DESCRIPTION

This is the MySQL specific stuff. To get the real
docs look at Slash::DB.

=head1 SEE ALSO

Slash(3), Slash::DB(3).

=cut

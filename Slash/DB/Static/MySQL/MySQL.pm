# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::DB::Static::MySQL;

# This package contains "static" methods for MySQL, which in this
# context means methods which are not needed by Apache.  If Apache
# doesn't need their code, keeping it out saves a bit of RAM.
# So what should go in here are the methods which are only needed
# by the backend.

use strict;
use Slash::Utility;
use Digest::MD5 'md5_hex';
use Time::HiRes;
use URI ();
use vars qw($VERSION);
use base 'Slash::DB::MySQL';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# FRY: Hey, thinking hurts 'em! Maybe I can think of a way to use that.


# SQL STATUS FUNCTIONS.

########################################################
sub sqlShowMasterStatus {
	my($self) = @_;

	$self->sqlConnect();
	my $stat = $self->{_dbh}->prepare("SHOW MASTER STATUS");
	$stat->execute;
	my $statlist = [];
	push @{$statlist}, $_ while $_ = $stat->fetchrow_hashref;

	return $statlist;
}


########################################################
sub sqlShowSlaveStatus {
	my($self) = @_;

	$self->sqlConnect();
	my $stat = $self->{_dbh}->prepare("SHOW SLAVE STATUS");
	$stat->execute;
	my $statlist = [];
	push @{$statlist}, $_ while $_ = $stat->fetchrow_hashref;

	return $statlist;
}

########################################################
# For rss, rdf etc feeds, basically used by tasks.
# Ultimately this should be subsumed into
# getStoriesEssentials since they serve the same purpose.
# XXXSECTIONTOPICS let's get the NOW() out of here
sub getBackendStories {
	my($self, $options) = @_;

	my $topic = $options->{topic} || getCurrentStatic('mainpage_nexus_tid');

	my $select = "stories.stoid, sid, title, stories.tid, primaryskid, time, dept, stories.uid,
		commentcount, hitparade, introtext, bodytext";

	my $from = "stories, story_text";

	my $where = "stories.stoid = story_text.stoid
		AND time < NOW() AND in_trash = 'no'";

	my %image = ( );
	my $topic_hr = $self->getTopicTree($topic);
	$from .= ", story_topics_rendered";
	$where .= " AND stories.stoid = story_topics_rendered.stoid
		AND story_topics_rendered.tid=$topic";
	for my $key (qw( image width height )) {
		$image{$key} = $topic_hr->{$key};
	}

	my $other = "ORDER BY time DESC LIMIT 10";

	my $returnable = $self->sqlSelectAllHashrefArray($select, $from, $where, $other);

	# Load up the image field for each story with a hashref
	# containing this one topic's image data;  this is not
	# that useful and it's a bit silly to repeat the data
	# 10 times, but this makes this method's return value
	# compatible with what it was before 2004/05. - Jamie
	for my $story (@$returnable) {
		# XXXSECTIONTOPICS need to set $story->{alttext}
		# to something, here - the main topic, I guess
		$story->{image} = { %image };
	}

	return $returnable;
}

########################################################
# For slashd
sub insertErrnoteLog {
	my($self, $taskname, $errnote, $moreinfo) = @_;
	my @c = caller(1);
	my $line = $c[2] || 0;
	$moreinfo = undef unless $moreinfo;
	$self->sqlInsert("slashd_errnotes", {
		-ts =>		'NOW()',
		taskname =>	$taskname,
		line =>		$line,
		errnote =>	$errnote,
		moreinfo =>	$moreinfo,
	});
}

########################################################
# For slashd
# This is for set_recent_topics.pl which updates the template
# for the "five recent topics" icons across the top of skin
# index pages.
sub getNewStoryTopics {
	my($self, $skin_name) = @_;

	my $constants = getCurrentStatic();
	my $needed = $constants->{recent_topic_img_count} || 5;
	$needed = $constants->{recent_topic_txt_count}
		if ($constants->{recent_topic_txt_count} || 0) > $needed;
	# There may be duplicate topics, which we'll handle in perl;
	# here in SQL we just need to be sure we get enough (but not so
	# many we snarf down the whole table).  This guesstimate should
	# work for all sites except those that post tons of duplicate
	# topic stories.
	$needed = $needed * 3 + 5;
	my $skin = $self->getSkin($skin_name);
	my $nexus_tid = $skin->{nexus};
	my $ar = $self->sqlSelectAllHashrefArray(
		"stories.tid",
		"stories, story_topics_rendered",
		"stories.stoid=story_topics_rendered.stoid
		 AND story_topics_rendered.tid=$nexus_tid
		 AND in_trash = 'no' AND time < NOW()",
		"ORDER BY time DESC LIMIT $needed"
	);

	my $topics = $self->getTopics;
	for my $topic (@$ar) {
		@{ $topic                   }{qw(alttext image width height)} =
		@{ $topics->{$topic->{tid}} }{qw(alttext image width height)};
	}

	return $ar;
}

########################################################
# For dailystuff
sub updateArchivedDiscussions {
	my($self) = @_;

	my $days_to_archive = getCurrentStatic('archive_delay');
	return 0 if !$days_to_archive;

	# Close discussions.
	return $self->sqlUpdate(
		"discussions",
		{ type => 'archived' },
		"TO_DAYS(NOW()) - TO_DAYS(ts) > $days_to_archive
		 AND type = 'open'
		 AND flags != 'delete'"
	);
}


########################################################
# For daily_archive.pl
sub getArchiveList {
	my($self, $limit, $dir) = @_;
	$limit ||= 1;
	$dir = 'ASC' if $dir !~ /^(?:ASC|DESC)$/;

	my $days_to_archive = getCurrentStatic('archive_delay');
	return 0 unless $days_to_archive;

	my $mp_tid = getCurrentStatic('mainpage_nexus_tid');
	my $nexuses = $self->getNexusChildrenTids($mp_tid);
	my $nexus_clause = join ',', @$nexuses, $mp_tid;
	
	# Close associated story so that final archival .shtml is written
	# to disk. This is accomplished by the archive.pl task.
	# XXXSECTIONTOPICS - We need to get the list of all nexuses,
	# and not archive any stories that don't belong to them
	# (which is the new equivalent of the old "never display").
	# That replaces "displaystatus > -1" - Jamie 2005/04
	my $returnable = $self->sqlSelectAll(
		'stories.stoid, sid, title',
		'stories, story_text, story_topics_rendered',
		"stories.stoid=story_text.stoid
		 AND stories.stoid = story_topics_rendered.stoid
		 AND TO_DAYS(NOW()) - TO_DAYS(time) > $days_to_archive
		 AND is_archived = 'no'
		 AND story_topics_rendered.tid IN ($nexus_clause)",
		"GROUP BY stoid ORDER BY time $dir LIMIT $limit"
	);

	return $returnable;
}


########################################################
# For dailystuff
sub deleteRecycledComments {
	my($self) = @_;

	my $days_to_archive = getCurrentStatic('archive_delay');
	return unless $days_to_archive;

	my $comments = $self->sqlSelectAll(
		'cid, discussions.id',
		'comments,discussions',
		"to_days(now()) - to_days(date) > $days_to_archive AND 
		discussions.id = comments.sid AND
		discussions.type = 'recycle' AND 
		comments.pid = 0"
	);

	my $rtotal = 0;
	# This *must* be made faster, it seems to do about 4 per minute
	# unless the comments being deleted are mostly-threaded.  Maybe
	# it's time to make _deleteThread not be recursive.
	for my $comment (@$comments) {
		next if !$comment or ref($comment) ne 'ARRAY' or !@$comment;
		my $local_count = $self->_deleteThread($comment->[0]);
		$self->setDiscussionDelCount($comment->[1], $local_count);
		$rtotal += $local_count;
	}

	return $rtotal;
}
	

sub _deleteThread {
	my($self, $cid, $level, $comments_deleted) = @_;
	$level ||= 0;

	if (!$cid) {
		errorLog("_deleteThread called with no cid");
		return 0;
	}

	my $count = 0;
	my @delList;
	$comments_deleted = \@delList if !$level;

	my $delkids = $self->getCommentChildren($cid);

	# Delete children of $cid.
	push @{$comments_deleted}, $cid;
	for (@{$delkids}) {
		my($cid) = @{$_};
		push @{$comments_deleted}, $cid;
		$self->_deleteThread($cid, $level+1, $comments_deleted);
	}
	my %comment_hash;
	for (@{$comments_deleted}) {
		$comment_hash{$_} = 1;
	}
	@{$comments_deleted} = keys %comment_hash;

	if (!$level) {
		for (@{$comments_deleted}) {
			$count += $self->deleteComment($_);
		}
	}

	return $count;
}

########################################################
# For dailystuff
# This just updates the counts for the day before
# -Brian
# This is now done more efficiently throughout the day,
# by the counthits.pl task - Jamie
#sub updateStoriesCounts {
#	my($self) = @_;
#	my $constants = getCurrentStatic();
#	my $counts = $self->sqlSelectAll(
#		'dat,count(*)',
#		'accesslog',
#		"op='article' AND dat !='' AND to_days(now()) - to_days(ts) = 1",
#		'GROUP BY(dat)'
#	);
#
#	for my $count (@$counts) {
#		$self->sqlUpdate('stories', { -hits => "hits+$count->[1]" },
#			'sid=' . $self->sqlQuote($count->[0])
#		);
#	}
#}

########################################################
# For daily_forget.pl
sub forgetUsersLogtokens {
	my($self) = @_;

	return $self->sqlDelete("users_logtokens",
		"DATE_ADD(expires, INTERVAL 1 MONTH) < NOW()");
}

########################################################
# For daily_forget.pl
sub forgetCommentIPs {
	my($self) = @_;
	my $constants = getCurrentStatic();

	# Forget the source IP information for comments older than a given
	# time.
	my $hours = $constants->{comments_forgetip_hours} || 720;
	my $hours1 = $hours-1; $hours1 = 0 if $hours1 < 0;
	# At what cid do we start scanning?
	my $mincid = $constants->{comments_forgetip_mincid};
	if (!defined($mincid)) {
		$self->sqlInsert('vars', {
			name	=> 'comments_forgetip_mincid',
			value	=> '0',
		});
		$mincid = 0;
	}
	# How many rows to do at once?  We don't want to tie up the DB
	# for too long at one sitting.  Find the first discussion posted
	# just after the time limit, and then the first comment in that
	# discussion.  A discussion predates its comments, so this comment
	# is guaranteed to postdate the time limit, and finding it doesn't
	# require a table scan of comments, only of discussions.
	my $maxrows = $constants->{comments_forgetip_maxrows} || 10000;
	my $maxcid = 0;
	my $min_remember_sid = $self->sqlSelect("MIN(id)",
		"discussions",
		"ts > DATE_SUB(NOW(), INTERVAL $hours1 HOUR)
		 AND commentcount > 0");
	if ($min_remember_sid) {
		$maxcid = $self->sqlSelect("MIN(cid)",
			"comments",
			"sid=$min_remember_sid") || 0;
	}
	if ($maxcid < $mincid) {
		# Shouldn't happen, but just in case
		$maxcid = $mincid;
	} elsif ($mincid+$maxrows < $maxcid) {
		$maxcid = $mincid+$maxrows;
	}
	my $nextcid = $mincid;
	if ($maxcid > $mincid) {
		# Do the update.
		$self->sqlUpdate("comments",
			{ ipid => '', subnetid => '' },
			"cid BETWEEN $mincid AND $maxcid
			AND date < DATE_SUB(NOW(), INTERVAL $hours HOUR)"
		);
		# How far did we go?
		$nextcid = $self->sqlSelect("MAX(cid)",
			"comments USE INDEX (primary)", # XXX ugly
			"cid BETWEEN $mincid AND $maxcid
			AND ipid = ''",
		);
		$nextcid ||= $mincid;
		# The next forgetting can start here.
		$self->setVar('comments_forgetip_mincid', $nextcid);
	}
	return $nextcid - $mincid;
}

########################################################
# For daily_forget.pl
sub forgetSubmissionIPs {
	my($self) = @_;
	my $constants = getCurrentStatic();

	# Forget the source IP information for submissions older than a
	# given time.
	my $hours = $constants->{submit_forgetip_hours} ||
		$constants->{comments_forgetip_hours} || 720;
	my $hours1 = $hours-1; $hours1 = 0 if $hours1 < 0;

	# At what subid do we start scanning?
	my $minsubid = $constants->{submit_forgetip_minsubid};
	if (!defined($minsubid)) {
		$self->sqlInsert('vars', {
			name	=> 'submit_forgetip_minsubid',
			value	=> '0',
		});
		$minsubid = 0;
	}
	# How many rows to do at once?  We don't want to tie up the DB
	# for too long at one sitting.
	my $maxrows = $constants->{submit_forgetip_maxrows} ||
		$constants->{comments_forgetip_maxrows} || 10000;
	my $maxsubid = $minsubid + $maxrows;
	my $nextsubid = $minsubid;
	{
		# Do the update.
		$self->sqlUpdate("submissions",
			{ ipid => '', subnetid => '' },
			"subid BETWEEN $minsubid AND $maxsubid
			AND time < DATE_SUB(NOW(), INTERVAL $hours HOUR)"
		);
		# How far did we go?
		$nextsubid = $self->sqlSelect("MAX(subid)",
			"submissions",
			"subid BETWEEN $minsubid AND $maxsubid
			AND ipid = ''",
		);
		$nextsubid ||= $minsubid;
		# The next forgetting can start here.
		$self->setVar('submit_forgetip_minsubid', $nextsubid);
	}
	return $nextsubid - $minsubid;
}

########################################################
# For daily_forget.pl
sub forgetOpenProxyIPs {
	my($self) = @_;
	my $constants = getCurrentStatic();

	my $hours = $constants->{comments_portscan_cachehours} || 48;
	$hours++;
	return $self->sqlDelete("open_proxies",
		"ts < DATE_SUB(NOW(), INTERVAL $hours HOUR)");
}

########################################################
# For dailystuff
sub deleteDaily {
	my($self) = @_;
	my $constants = getCurrentStatic();

# This is now done more efficiently, throughout the day, by the
# counthits.pl task.
#	$self->updateStoriesCounts();

	$self->sqlDelete('badpasswords', "TO_DAYS(NOW()) - TO_DAYS(ts) > 2");

	$self->sqlDelete('pollvoters');

	my $archive_delay_mod =
		   $constants->{archive_delay_mod}
		|| $constants->{archive_delay}
		|| 14;
	$self->sqlDelete('moderatorlog',
		"TO_DAYS(NOW()) - TO_DAYS(ts) > $archive_delay_mod");
	$self->sqlDelete('metamodlog',
		"TO_DAYS(NOW()) - TO_DAYS(ts) > $archive_delay_mod");

# This is now done by the flush_formkeys task.
#	my $delete_time = time() - $constants->{formkey_timeframe};
#	$self->sqlDelete('formkeys', "ts < $delete_time");

	$self->sqlDelete('discussions', "type='recycle' AND commentcount=0")
		unless $constants->{noflush_empty_discussions};
}

########################################################
# For daily_archive.pl
# If the Subscribe plugin is enabled and a certain var is set,
# we're already writing "lastclick" to users_hits so this gets a
# lot easier.  If not, we use the old method of a table scan on
# accesslog.
# Note that "lastaccess" is never guaranteed to be accurate if
# the user has clicked today;  it will still probably show
# yesterday.  It's only intended for longer-term tracking of who
# has visited the site when.
# Updating all UIDs at once locks the users_info table on
# Slashdot's master DB for about a minute, which is too long.
# Let's do them in batches - Jamie 2004/04/28
sub updateLastaccess {
	my($self) = @_;
	my $constants = getCurrentStatic();

	my $splice_count = 2000;
	if ($constants->{subscribe} && !$constants->{subscribe_hits_only}) {
		my @gmt = gmtime();
		my $today = sprintf "%4d%02d%02d", $gmt[5] + 1900, $gmt[4] + 1, $gmt[3];
		my $ar = $self->sqlSelectAll(
			"uid, lastclick",
			"users_hits",
			"TO_DAYS(NOW()) - TO_DAYS(lastclick) <= 1"
		);
		my %uids_day = ( );
		for my $uid_ar (@$ar) {
			my($uid, $lastclick) = @$uid_ar;
			my $lastclick_day = substr($lastclick, 0, 8);
			$uids_day{$lastclick_day}{$uid} = 1;
		}
		for my $day (keys %uids_day) {
			my @uids = sort { $a <=> $b } keys %{$uids_day{$day}};
			while (@uids) {
				my @uid_chunk = splice @uids, 0, $splice_count;
				my $uids_in = join(",", @uid_chunk);
				$self->sqlUpdate(
					"users_info",
					{ lastaccess => $day },
					"uid IN ($uids_in)"
				);
				# If there is more to do, sleep for a moment so we don't
				# hit the DB too hard.
				Time::HiRes::sleep(0.2) if @uids;
			}
		}
	} else {
		my @gmt = gmtime(time-86400);
		my $yesterday = sprintf "%4d%02d%02d", $gmt[5] + 1900, $gmt[4] + 1, $gmt[3];
		my $uids_ar = $self->sqlSelectColArrayref(
			"uid",
			"accesslog",
			"TO_DAYS(NOW()) - TO_DAYS(ts) <= 1",
			"GROUP BY uid"
		);
		return unless $uids_ar && @$uids_ar;
		my @uids = sort { $a <=> $b } @$uids_ar;
		while (@uids) {
			my @uid_chunk = splice @uids, 0, $splice_count;
			my $uids_in = join(",", @uid_chunk);
			$self->sqlUpdate(
				"users_info",
				{ lastaccess => $yesterday },
				"uid IN ($uids_in) AND lastaccess < '$yesterday'"
			);
			# If there is more to do, sleep for a moment so we don't
			# hit the DB too hard.
			Time::HiRes::sleep(0.2) if @uids;
		}
	}
}

########################################################
# For daily_archive.pl
sub decayTokens {
	my($self) = @_;
	my $constants = getCurrentStatic();
	my $days = $constants->{mod_token_decay_days} || 14;
	my $min_k = ($constants->{mod_elig_minkarma} || 0) - 3;
	my $perday = int($constants->{mod_token_decay_perday} || 0);

	# If no decay wanted, nothing need be done.
	return if !$perday;

	# We know that the lastaccess field will be accurate, because
	# this method is called right after updateLastaccess().
	my $uids_ar = $self->sqlSelectColArrayref(
		"uid",
		"users_info",
		"(lastaccess < DATE_SUB(NOW(), INTERVAL $days DAY) OR karma < $min_k)
		 AND tokens > 0"
	);
	my $uids_in = join(",", sort @$uids_ar);
	my $rows = 0;
	if ($uids_in) {
		$rows = $self->sqlUpdate(
			"users_info",
			{ -tokens => "GREATEST(0, tokens - $perday)" },
			"uid IN ($uids_in) AND tokens > 0"
		);
	}
	my $decayed = $rows * $perday;
	return $decayed;
}

########################################################
# For dailystuff
sub getDailyMail {
	my($self, $user) = @_;

	my $columns = "DISTINCT stories.sid, title, stories.primaryskid,
		users.nickname, stories.tid, stories.time, stories.dept,
		story_text.introtext, story_text.bodytext ";
	my $tables = "stories, story_text, users, story_topics_rendered";
	my $where = "time < NOW() AND TO_DAYS(NOW())-TO_DAYS(time)=1 ";
	$where .= "AND users.uid=stories.uid AND stories.stoid=story_text.stoid AND story_topics_rendered.stoid = stories.stoid ";

	# XXXSECTIONTOPICS - The 'sectioncollapse' bit now means:
	# 0 - only want stories in the mainpage nexus mailed
	# 1 - want all stories in the mainpage nexus, or any
	# other nexuses linked to it, mailed
	my $mp_tid = getCurrentStatic('mainpage_nexus_tid');
	if ($user->{sectioncollapse}) {
		my $nexuses = $self->getNexusChildrenTids($mp_tid);
		my $nexus_clause = join ',', @$nexuses, $mp_tid;
		$where .= "AND story_topics_rendered.tid IN ($nexus_clause) ";
	} else {
		$where .= "AND story_topics_rendered.tid = $mp_tid ";
	}

	$where .= "AND story_topics_rendered.tid NOT IN ($user->{extid}) "
		if $user->{extid};
	$where .= "AND stories.uid NOT IN ($user->{exaid}) "
		if $user->{exaid};
# XXXSKIN !!!!
#	$where .= "AND section not in ($user->{exsect}) "
#		if $user->{exsect};

	my $other = " ORDER BY stories.time DESC";

	my $email = $self->sqlSelectAll($columns, $tables, $where, $other);

	return $email;
}

########################################################
# For dailystuff
sub getMailingList {
	my($self) = @_;

	my $columns = "realemail,nickname,users.uid";
	my $tables  = "users,users_comments,users_info";
	my $where   = "users.uid=users_comments.uid AND users.uid=users_info.uid AND maillist=1";
	my $other   = "order by realemail";

	my $users = $self->sqlSelectAll($columns, $tables, $where, $other);

	return $users;
}

########################################################
# For dailystuff
# XXX Outdated, delete before tarball release - Jamie 2001/07/08
# If we go back to using this is may have issues -Brian
#sub getOldStories {
#	my($self, $delay) = @_;
#
#	my $columns = "sid,time,section,title";
#	my $tables = "stories";
#	my $where = "writestatus<5 AND writestatus >= 0 AND to_days(now()) - to_days(time) > $delay";
#
#	my $stories = $self->sqlSelectAll($columns, $tables, $where);
#
#	return $stories;
#}

########################################################
# For portald
sub getTop10Comments {
	my($self) = @_;
	my $constants = getCurrentStatic();

	my($min_score, $max_score) =
		($constants->{comment_minscore}, $constants->{comment_maxscore});

	my $num_wanted = $constants->{top10comm_num} || 10;

	my $cids = [];
	my $comments = [];
	my $num_top10_comments = 0;
	my $max_cid = $self->getMaxCid();

	# To make this select a LOT faster, we limit not only by date
	# but by the primary key.  If any site gets more than 20,000
	# comments in a day, my hat's off to ya.
	my $min_cid = ($max_cid || 0) - 20_000;
	$min_cid = 0 if $min_cid < 1;

	while (1) {
		# Select the latest comments with high scores.  If we
		# can't get 10 of them, our standards are too high;
		# lower our minimum score requirement and re-SELECT.
		$cids = $self->sqlSelectAll(
			'cid',
			'comments',
			"cid >= $min_cid
				AND date >= DATE_SUB(NOW(), INTERVAL 1 DAY)
				AND points >= $max_score",
			'ORDER BY date DESC');

		$num_top10_comments = scalar(@$cids);
		last if $num_top10_comments >= $num_wanted;
                # Didn't get $num_wanted... try again with lower standards.
                --$max_score;
                # If this is as low as we can get... take what we have.
                last if $max_score <= $min_score;
	}

	# if for any reason we don't get any comments, return now
	return [] unless scalar(@$cids);

	foreach (@$cids) {
		# Of our prospective hot comments, find the overall time
		# it took to moderate em up. Faster == hotter
		$_->[1] = $self->sqlSelect(
			'UNIX_TIMESTAMP(MAX(ts)) - UNIX_TIMESTAMP(MIN(ts))',
			'moderatorlog',
			"cid=$_->[0]");
	}

	@$cids = sort { $a->[1] <=> $b->[1] } @$cids;
	$num_top10_comments = 0;

	while (@$cids
		&& $cids->[$num_top10_comments]
		&& @{$cids->[$num_top10_comments]}
		&& $num_top10_comments < $num_wanted
	) {
		my $comment = $self->sqlSelectArrayRef(
			"stories.sid, title, cid, subject, date, nickname, comments.points, comments.reason",
			"comments, stories, story_text, users",
			"cid=$cids->[$num_top10_comments]->[0]
				AND stories.stoid = story_text.stoid
				AND users.uid=comments.uid
                                AND comments.sid=stories.discussion");
		push @$comments, $comment if $comment;
		++$num_top10_comments;
	}

	formatDate($comments, 4, 4);
	return $comments
}

########################################################
# For portald
sub getWhatsPlaying {
	my($self) = @_;

	my $list = $self->sqlSelectAll(
		'nickname, value',
		'users, users_param',
		"users.uid = users_param.uid
			AND seclev > 99
			AND name='playing'",
		'ORDER BY users.uid ASC');
	return $list;
}

sub getTopRecentSkinsForDays {
	my ($self, $days, $options) = @_;
	my $skins = $self->getSkins();
	my $limit = "";
	$limit = " LIMIT $options->{limit}" if $options->{limit};	
	my $orderby = $options->{orderby} || "score";
	my $skin_to_nexus;
	my $nexus_to_skins;
	my @nexus_tids;
	my $exclude_clause = "";
	if ($options->{exclude_skins}) {
		$exclude_clause = " AND skins.name NOT IN(".( join(',', map { $_ = $self->sqlQuote($_) } @{$options->{exclude_skins}})).") ";
	}
	foreach	(values %$skins) {
		$skin_to_nexus->{$_->{skid}}=$_->{nexus};
		push @{$nexus_to_skins->{$_->{nexus}}}, $_->{skid} if $_->{skid};
		push @nexus_tids, $_->{nexus} if $_->{nexus};	
	}
	return [] unless @nexus_tids;
	my $tid_string = join ',', @nexus_tids;

	return $self->sqlSelectAllHashrefArray(
		"skins.skid, skins.name, skins.title, COUNT(*) as cnt, 
		 SUM(LOG(($days + 1)- ((UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(time))/86400))) as score, 
		 MAX(time) as recent",
		"stories, story_topics_rendered,skins",
		"time <= NOW() AND stories.stoid = story_topics_rendered.stoid AND story_topics_rendered.tid IN($tid_string) AND skins.nexus = story_topics_rendered.tid $exclude_clause",
		"GROUP BY skins.skid ORDER BY $orderby desc $limit"
	);
}

sub getTopRecentSkinTopicsForDays {
	my ($self, $skid, $days, $options) = @_;
	$days ||= 14;

	my $orderby = $options->{orderby} || "score";
	my $limit = "";
	$limit = " LIMIT $options->{limit}" if $options->{limit};
	
	my $exclude_clause = "";
	if ($options->{exclude_topics}) {
		$exclude_clause = " AND topics.keyword NOT IN(".( join(',', map { $_ = $self->sqlQuote($_) } @{$options->{exclude_skins}})).") ";
	}
	
	my $nexus = $self->getNexusFromSkid($skid);
	my @nexus_tids = $self->getNexusTids();
	my $nexus_exclude_clause = " AND story_topics_rendered.tid NOT IN(".(join ',', @nexus_tids).")" if $options->{exclude_nexus_topics};
	my $stoids = $self->sqlSelectColArrayref(
		"stories.stoid",
		"story_topics_rendered,stories",
		"story_topics_rendered.stoid = stories.stoid AND stories.time <= NOW() AND stories.time > DATE_SUB(NOW(), INTERVAL $days DAY)
		 AND story_topics_rendered.tid=$nexus"
	);
	my $stoid_str = join ',', @$stoids;
	return [] unless $stoid_str;
	my $topic_res = $self->sqlSelectAllHashrefArray(
		"topics.tid,topics.keyword,topics.textname, COUNT(*) as cnt, COUNT(*) as cnt, 
		 SUM(LOG(($days + 1)- ((UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(time))/86400))) as score,
		 MAX(time) as recent",
		"stories,story_topics_rendered,topics",
		"time < NOW() AND stories.stoid=story_topics_rendered.stoid AND stories.stoid IN($stoid_str) AND story_topics_rendered.tid = topics.tid
		 AND story_topics_rendered.tid != $nexus $nexus_exclude_clause",
		"GROUP BY story_topics_rendered.tid ORDER BY $orderby desc $limit"
	);
	return $topic_res;
}
	
########################################################
# For portald
sub randomBlock {
	my($self) = @_;
	my $c = $self->sqlSelectMany("bid,title,url,block",
		"blocks",
		"skin='mainpage' AND portal=1 AND ordernum < 0");

	my $A = $c->fetchall_arrayref;
	$c->finish;

	my $R = $A->[rand @$A];
	my($bid, $title, $url, $block) = @$R;

	$self->sqlUpdate("blocks", {
		title	=> "rand($title);",
		url	=> $url
	}, "bid='rand'");

	return $block;

}


########################################################
# For portald
sub getSitesRDF {
	my($self) = @_;
	my $columns = "bid,url,rdf,retrieve";
	my $tables = "blocks";
	my $where = "rdf != '' and retrieve=1";
	my $other = "";
	my $rdf = $self->sqlSelectAll($columns, $tables, $where, $other);

	return $rdf;
}

########################################################
# XXXSECTIONTOPICS - This is broken, I'm working on it - Jamie
sub getSkinInfo {
	my($self) = @_;
	$self->sqlConnect;

	my $tree  = $self->getTopicTree;
	my $skins = $self->getSkins;
	my $constants = getCurrentStatic();

	# in case one child nexus has more than one parent nexus,
	# cache the data in %children so we don't need to fetch it all
	# more than once
	my(%children, %index);
	for my $tid (keys %$tree) {
		next unless $tree->{$tid}{nexus} && $tree->{$tid}{skid} && $tree->{$tid}{child};

		my $skinname = $skins->{ $tree->{$tid}{skid} }{name};
		my $mp_tid = $constants->{mainpage_nexus_tid};
		for my $child_tid (sort { lc $tree->{$a}{textname} cmp lc $tree->{$b}{textname} } keys %{$tree->{$tid}{child}}) {
			next unless $tree->{$child_tid}{nexus} && $tree->{$child_tid}{skid};
			if ($children{$child_tid}) {
				push @{$index{$skinname}{$child_tid}}, $children{$child_tid};
				next;
			}

			my %child_data;
			# copy, don't mess up cache
			@child_data{keys %{$tree->{$child_tid}}} = values %{$tree->{$child_tid}};

			$child_data{skin}    = $skins->{ $tree->{$child_tid}{skid} };
			my $rootdir = $child_data{skin}{rootdir};
			$child_data{rootdir} = set_rootdir($child_data{url}, $rootdir);
#use Data::Dumper; $Data::Dumper::Sortkeys = 1; print STDERR "getSkinInfo tid '$tid' skinname '$skinname' child_data: " . Dumper(\%child_data);

			@child_data{qw(month monthname day)} = $self->sqlSelect(
				'MONTH(time), MONTHNAME(time), DAYOFMONTH(time)',
				'stories, story_topics_rendered',
				"stories.stoid=story_topics_rendered.stoid AND
				 story_topics_rendered.tid='$child_tid' AND in_trash = 'no' AND time < NOW()
				 ORDER BY time DESC LIMIT 1"
			);

			$child_data{count} = $self->sqlCount(
				'stories, story_topics_chosen',
				"stories.stoid=story_topics_rendered.stoid AND
				 story_topics_rendered.tid='$child_tid' AND in_trash = 'no' AND time < NOW()
				 AND TO_DAYS(NOW()) - TO_DAYS(time) <= 2"
			) || 0;

			my $stoids = $self->sqlSelectColArrayref(
				"stories.stoid",
				"stories, story_topics_rendered AS str_sect",
				"stories.stoid=str_sect.stoid AND str_sect.tid='$child_tid'
				 AND in_trash = 'no' AND time < NOW()
				 AND TO_DAYS(NOW()) - TO_DAYS(time) <= 2");
			my $ds_hr = $self->displaystatusForStories($stoids);
			$child_data{count_sectional} = scalar(grep { $ds_hr->{$_} == 1 } @$stoids);

			$children{$child_tid} = \%child_data;
			push @{$index{$skinname}}, $children{$child_tid};
		}
	}

	return \%index;
}

########################################################
# For run_moderatord.pl
# Slightly new logic.  Now users can accumulate tokens beyond the
# "trade-in" limit and the token_retention var is obviated.
# Any user with more than $tokentrade tokens is forced to cash
# them in for points, but they get to keep any excess tokens.
# And on 2002/10/23, even newer logic:  the number of desired
# conversions is passed in and the top that-many token holders
# get points.
sub convert_tokens_to_points {
	my($self, $n_wanted) = @_;

	my $constants = getCurrentStatic();
	my %granted = ( );

	return unless $n_wanted;

	# Sanity check.
	my $n_users = $self->countUsers();
	$n_wanted = int($n_users/10) if $n_wanted > int($n_users)/10;

	my $maxtokens = $constants->{maxtokens} || 60;
	my $tokperpt = $constants->{tokensperpoint} || 8;
	my $maxpoints = $constants->{maxpoints} || 5;
	my $pointtrade = $maxpoints;
	my $tokentrade = $pointtrade * $tokperpt;
	$tokentrade = $maxtokens if $tokentrade > $maxtokens; # sanity check
	my $half_tokentrade = int($tokentrade/2); # another sanity check

	my $uids = $self->sqlSelectColArrayref(
		"uid",
		"users_info",
		"tokens >= $half_tokentrade",
		"ORDER BY tokens DESC, RAND() LIMIT $n_wanted",
	);

	# Locking tables is no longer required since we're doing the
	# update all at once on just one table and since we're using
	# + and - instead of using absolute values. - Jamie 2002/08/08

	for my $uid (@$uids) {
		next unless $uid;
		my $rows = $self->setUser($uid, {
			-lastgranted	=> 'NOW()',
			-tokens		=> "GREATEST(0, tokens - $tokentrade)",
			-points		=> "LEAST(points + $pointtrade, $maxpoints)",
		});
		$granted{$uid} = 1 if $rows;
	}

	# We used to do some fancy footwork with a cursor and locking
	# tables.  The only difference between that code and this is that
	# it only limited points to maxpoints for users with karma >= 0
	# and seclev < 100.  These aren't meaningful limitations, so these
	# updates should work as well.  - Jamie 2002/08/08
	# Actually I don't think these are needed at all. - Jamie 2003/09/09
	$self->sqlUpdate(
		"users_comments",
		{ points => $maxpoints },
		"points > $maxpoints"
	);
	$self->sqlUpdate(
		"users_info",
		{ tokens => $maxtokens },
		"tokens > $maxtokens"
	);

	return \%granted;
}

########################################################
# For run_moderatord
sub stirPool {
	my($self) = @_;

	# Old var "stir" still works, its value is in days.
	# But "mod_stir_hours" is preferred.
	my $constants = getCurrentStatic();
	my $stir_hours = $constants->{mod_stir_hours}
		|| $constants->{stir} * 24
		|| 96;
	my $tokens_per_pt = $constants->{mod_stir_token_cost} || 0;

	# This isn't atomic.  But it doesn't need to be.  We could lock the
	# tables during this operation, but all that happens if we don't
	# is that a user might use up a mod point that we were about to stir,
	# and it gets counted twice, later, in stats.  No big whup.

	my $stir_ar = $self->sqlSelectAllHashrefArray(
		"users_info.uid AS uid, points",
		"users_info, users_comments",
		"users_info.uid = users_comments.uid
		 AND points > 0
		 AND DATE_SUB(NOW(), INTERVAL $stir_hours HOUR) > lastgranted"
	);

	my $n_stirred = 0;
	for my $user_hr (@$stir_ar) {
		my $uid = $user_hr->{uid};
		my $pts = $user_hr->{points};
		my $tokens_pt_chg = $tokens_per_pt * $pts;

		my $change = { };
		$change->{points} = 0;
		$change->{-lastgranted} = "NOW()";
		$change->{-stirred} = "stirred + $pts";
		# In taking tokens away, this subtraction itself will not
		# cause the value to go negative.
		$change->{-tokens} = "LEAST(tokens, GREATEST(tokens - $tokens_pt_chg, 0))"
			if $tokens_pt_chg;
		$self->setUser($uid, $change);

		$n_stirred += $pts;
	}

	return $n_stirred;
}

########################################################
# For run_moderatord.pl
#
# New as of 2002/09/05:  returns ordered first by hitcount, and
# second randomly, so when give_out_tokens() chops off the list
# halfway through the minimum number of clicks, the survivors
# are determined at random and not by (probably) uid order.
#
# New as of 2002/09/11:  limit look-back distance to 48 hours,
# to make the effects of click-grouping more predictable, and
# not being erased all at once with accesslog expiration.
#
# New as of 2003/01/30:  fetchEligibleModerators() has been
# split into fetchEligibleModerators_accesslog and
# fetchEligibleModerators_users.  The first pulls down the data
# we need from accesslog, which may be a different DBIx virtual
# user (different database).  The second uses that data to pull
# down the rest of the data we need from the users tables.
# Also, the var mod_elig_hoursback is no longer needed.
# Note that fetchEligibleModerators_accesslog can return a
# *very* large hashref.
#
# New as of 2004/02/04:  fetchEligibleModerators_accesslog has
# been split into ~_insertnew, ~_deleteold, and ~_read.  They
# all are methods for the logslavedb, which may or may not be
# the same as the main slashdb.

sub fetchEligibleModerators_accesslog_insertnew {
	my($self, $lastmaxid, $newmaxid, $youngest_uid) = @_;
	return if $lastmaxid > $newmaxid;
	my $ac_uid = getCurrentStatic('anonymous_coward_uid');
	$self->sqlDo("INSERT INTO accesslog_artcom (uid, ts, c)"
		. " SELECT uid, AVG(ts) AS ts, COUNT(*) AS c"
		. " FROM accesslog"
		. " WHERE id BETWEEN $lastmaxid AND $newmaxid"
			. " AND (op='article' OR op='comments')"
		. " AND uid != $ac_uid AND uid <= $youngest_uid"
		. " GROUP BY uid");
}

sub fetchEligibleModerators_accesslog_deleteold {
	my($self) = @_;
	my $constants = getCurrentStatic();
	my $hoursback = $constants->{accesslog_hoursback} || 60;
	$self->sqlDelete("accesslog_artcom",
		"ts < DATE_SUB(NOW(), INTERVAL $hoursback HOUR)");
}

sub fetchEligibleModerators_accesslog_read {
	my($self) = @_;
	my $constants = getCurrentStatic();
	my $hitcount = defined($constants->{m1_eligible_hitcount})
		? $constants->{m1_eligible_hitcount} : 3;
	return $self->sqlSelectAllHashref(
		"uid",
		"uid, SUM(c) AS c",
		"accesslog_artcom",
		"",
		"GROUP BY uid HAVING c >= $hitcount");
}

# This is a method for the main slashdb, which may or may not be
# the same as the logslavedb.

sub fetchEligibleModerators_users {
	my($self, $count_hr) = @_;
	my $constants = getCurrentStatic();
	my $youngest_uid = $self->getYoungestEligibleModerator();
	my $minkarma = $constants->{mod_elig_minkarma} || 0;

	my @uids =
		sort { $a <=> $b } # don't know if this helps MySQL but it can't hurt... much
		grep { $_ <= $youngest_uid }
		keys %$count_hr;
	my @uids_start = @uids;

	# What is a good splice_count?  Well I was seeing entries show
	# up in the *.slow log for a size of 5000, so smaller is good.
	my $splice_count = 2000;
	while (@uids) {
		my @uid_chunk = splice @uids, 0, $splice_count;
		my $uid_list = join(",", @uid_chunk);
		my $uids_disallowed = $self->sqlSelectColArrayref(
			"users_info.uid AS uid",
			"users_info, users_prefs",
			"(karma < $minkarma OR willing != 1)
			 AND users_info.uid = users_prefs.uid
			 AND users_info.uid IN ($uid_list)"
		);
		for my $uid (@$uids_disallowed) {
			delete $count_hr->{$uid};
		}
		# If there is more to do, sleep for a moment so we don't
		# hit the DB too hard.
		sleep 1 if @uids;
	}

	my $return_ar = [
		map { [ $count_hr->{$_}{uid}, $count_hr->{$_}{c} ] }
		sort { $count_hr->{$a}{c} <=> $count_hr->{$b}{c}
			|| int(rand(3))-1 }
		grep { defined $count_hr->{$_} }
		@uids_start
	];
	return $return_ar;
}

########################################################
# For run_moderatord.pl
# Quick overview:  This method takes a list of uids who are eligible
# to be moderators and returns that same list, with the "worst"
# users made statistically less likely to be on it, and the "best"
# users more likely to remain on the list and appear more than once.
# Longer explanation:
# This method takes a list of uids who are eligible to be moderators
# (i.e., eligible to receive tokens which may end up giving them mod
# points).  It also takes several numeric values, positive numbers
# that are almost certainly slightly greater than 1 (e.g. 1.3 or so).
# For each uid, several values are calculated:  the total number of
# times the user has been M2'd "fair," the ratio of fair-to-unfair M2s,
# and the ratio of spent-to-stirred modpoints.  Multiple lists of
# the uids are made, from "worst" to "best," the "worst" user in each
# case having the probability of being eligible for tokens (remaining
# on the list) reduced and the "best" with that probability increased
# (appearing two or more times on the list).
# The list of which factors to use and the numeric values of those
# factors is in $wtf_hr ("what to factor");  its currently-defined
# keys are factor_ratio, factor_total and factor_stirred.
sub factorEligibleModerators {
	my($self, $orig_uids, $wtf, $info_hr) = @_;
	return $orig_uids if !$orig_uids || !@$orig_uids || scalar(@$orig_uids) < 10;

	$wtf->{fairratio} ||= 0;	$wtf->{fairratio} = 0	if $wtf->{fairratio} == 1;
	$wtf->{fairtotal} ||= 0;	$wtf->{fairtotal} = 0	if $wtf->{fairtotal} == 1;
	$wtf->{stirratio} ||= 0;	$wtf->{stirratio} = 0	if $wtf->{stirratio} == 1;

	return $orig_uids if !$wtf->{fairratio} || !$wtf->{fairtotal} || !$wtf->{stirratio};

	my $start_time = Time::HiRes::time;

	my @return_uids = ( );

	my $uids_in = join(",", @$orig_uids);
	my $u_hr = $self->sqlSelectAllHashref(
		"uid",
		"uid, m2fair, m2unfair, totalmods, stirred",
		"users_info",
		"uid IN ($uids_in)",
	);

	# Assign ratio values that will be used in the sorts in a moment.
	# We precalculate these because they're used in several places.
	# Note that we only calculate the *ratio* if there are a decent
	# number of votes, otherwise we leave it undef.
	for my $uid (keys %$u_hr) {
		# Fairness ratio.
		my $ratio = undef;
		if ($u_hr->{$uid}{m2fair}+$u_hr->{$uid}{m2unfair} >= 5) {
			$ratio = $u_hr->{$uid}{m2fair}
				/ ($u_hr->{$uid}{m2fair}+$u_hr->{$uid}{m2unfair});
		}
		$u_hr->{$uid}{m2fairratio} = $ratio;
		# Spent-to-stirred ratio.
		$ratio = undef;
		if ($u_hr->{$uid}{totalmods}+$u_hr->{$uid}{stirred} >= 10) {
			$ratio = $u_hr->{$uid}{totalmods}
				/ ($u_hr->{$uid}{totalmods}+$u_hr->{$uid}{stirred});
		}               
		$u_hr->{$uid}{stirredratio} = $ratio;
	}

	if ($wtf->{fairtotal}) {
		# Assign a token likeliness factor based on the absolute
		# number of "fair" M2s assigned to each user's moderations.
		# Sort by total m2fair first (that's the point of this
		# code).  If there's a tie in that, the secondary sort is
		# by ratio, and tertiary is random.
		my @new_uids = sort {
				$u_hr->{$a}{m2fair} <=> $u_hr->{$b}{m2fair}
				||
				( defined($u_hr->{$a}{m2fairratio})
					&& defined($u_hr->{$b}{m2fairratio})
				  ? $u_hr->{$a}{m2fairratio} <=> $u_hr->{$b}{m2fairratio}
				  : 0 )
				||
				int(rand(1)*2)*2-1
			} @$orig_uids;
		# Assign the factors in the hashref according to this
		# sort order.  Those that sort first get the lowest value,
		# the approximate middle gets 1, the last get highest.
		_set_factor($u_hr, $wtf->{fairtotal}, 'factor_m2total',
			\@new_uids);
	}

	if ($wtf->{fairratio}) {
		# Assign a token likeliness factor based on the ratio of
		# "fair" to "unfair" M2s assigned to each user's
		# moderations.  In order not to be "prejudiced" against
		# users with no M2 history, those users get no change in
		# their factor (i.e. 1) by simply being left out of the
		# list.  Sort by ratio first (that's the point of this
		# code);  if there's a tie in ratio, the secondary sort
		# order is total m2fair, and tertiary is random.
		my @new_uids = sort {
			  	$u_hr->{$a}{m2fairratio} <=> $u_hr->{$b}{m2fairratio}
				||
				$u_hr->{$a}{m2fair} <=> $u_hr->{$b}{m2fair}
				||
				int(rand(1)*2)*2-1
			} grep { defined($u_hr->{$_}{m2fairratio}) }
			@$orig_uids;
		# Assign the factors in the hashref according to this
		# sort order.  Those that sort first get the lowest value,
		# the approximate middle gets 1, the last get highest.
		_set_factor($u_hr, $wtf->{fairratio}, 'factor_m2ratio',
			\@new_uids);
	}

	if ($wtf->{stirratio}) {
		# Assign a token likeliness factor based on the ratio of
		# stirred to spent mod points.  In order not to be
		# "prejudiced" against users with little or no mod history,
		# those users get no change in their factor (i.e. 1) by
		# simply being left out of the list.  Sort by ratio first
		# (that's the point of this code); if there's a tie in
		# ratio, the secondary sort order is total spent, and
		# tertiary is random.
		my @new_uids = sort {
			  	$u_hr->{$a}{stirredratio} <=> $u_hr->{$b}{stirredratio}
				||
				$u_hr->{$a}{totalmods} <=> $u_hr->{$b}{totalmods}
				||
				int(rand(1)*2)*2-1
			} grep { defined($u_hr->{$_}{stirredratio}) }
			@$orig_uids;
		# Assign the factors in the hashref according to this
		# sort order.  Those that sort first get the lowest value,
		# the approximate middle gets 1, the last get highest.
		_set_factor($u_hr, $wtf->{stirratio}, 'factor_stirredratio',
			\@new_uids);
	}

	# If the caller wanted to keep stats, prep some stats.
	if ($info_hr) {
		$info_hr->{factor_lowest} = 1;
		$info_hr->{factor_highest} = 1;
	}

	# Now modify the list of uids.  Each uid in the list has the product
	# of its factors calculated.  If the product is exactly 1, that uid
	# is left alone.  If less than 1, there is a chance the uid will be
	# deleted from the list.  If more than 1, there is a chance it will
	# be doubled up in the list (or more than doubled for large factors).
	for my $uid (@$orig_uids) {
		my $factor = 1;
		for my $field (qw(
			factor_m2total factor_m2ratio factor_stirredratio
		)) {
			$factor *= $u_hr->{$uid}{$field}
				if defined($u_hr->{$uid}{$field});
		}
		# If the caller wanted to keep stats, send some stats.
		$info_hr->{factor_lowest} = $factor
			if $info_hr && $info_hr->{factor_lowest}
				&& $factor < $info_hr->{factor_lowest};
		$info_hr->{factor_highest} = $factor
			if $info_hr && $info_hr->{factor_highest}
				&& $factor > $info_hr->{factor_highest};
		# If the factor is, say, 1.3, then the count of this uid is
		# at least 1, and there is a 0.3 chance that it goes to 2.
		my $count = roundrand($factor);
		push @return_uids, ($uid) x $count;
	}

	return \@return_uids;
}

# This specialized utility function takes a list of uids and assigns
# values into the hashrefs that are their values in %$u_hr.  The
# @$uidlist determines the order that the values will be assigned.
# The first uid gets the value 1/$factor (and since $factor should
# be >1, this value will be <1).  The middle uid in @$uidlist will
# get the value approximately 1, and the last uid will get the value
# $factor.  After these assignments are made, any uid keys in %$u_hr
# *not* in @$uidlist will be given the value 1.  The 2nd-level hash
# key that these values are assigned to is $u_hr->{$uid}{$field}.
sub _set_factor {
	my($u_hr, $factor, $field, $uidlist) = @_;
	my $halfway = int($#$uidlist/2);
	return if $halfway <= 1;

	if ($factor != 1) {
		for my $i (0 .. $halfway) {

			# We'll use this first as a numerator, then as
			# a denominator.
			my $between_1_and_factor = 1 + ($factor-1)*($i/$halfway);

			# Set the lower uid, which ranges from 1/$factor to
			# $factor/$factor.
			my $uid = $uidlist->[$i];
			$u_hr->{$uid}{$field} = $between_1_and_factor/$factor;

			# Set its counterpart the higher uid, which ranges from
			# $factor/$factor to $factor/1 (but we build this list
			# backwards, from $#uidlist down to $halfway-ish, so we
			# start at $factor/1 and come down to $factor/$factor).
			my $j = $#$uidlist-$i;
			$uid = $uidlist->[$j];
			$u_hr->{$uid}{$field} = $factor/$between_1_and_factor;

		}
	}

	# uids which didn't get a value assigned just get "1".
	for my $uid (keys %$u_hr) {
		$u_hr->{$uid}{$field} = 1 if !defined($u_hr->{$uid}{$field});
	}
}

########################################################
# For run_moderatord.pl
sub updateTokens {
	my($self, $uid_hr) = @_;
	my $constants = getCurrentStatic();
	my $maxtokens = $constants->{maxtokens} || 60;
	for my $uid (sort keys %$uid_hr) {
		next unless $uid
			&& $uid		   =~ /^\d+$/
			&& $uid_hr->{$uid} =~ /^\d+$/;
		my $add = $uid_hr->{$uid};
		$self->setUser($uid, {
			-tokens	=> "LEAST(tokens+$add, $maxtokens)",
		});
	}
}

########################################################
# For run_moderatord.pl
# Given a fractional value representing the fraction of fair M2
# votes, returns the token/karma consequences of that fraction
# in a hashref.  Makes the very complex var m2_consequences a
# little easier to use.  Note that the value returned has three
# fields:  a float, its sign, and an SQL expression which may be
# either an integer or an IF().
# The mod_hr passed in here is the same format as the items
# returned by getModsNeedingReconcile().
sub getM2Consequences {
	my($self, $frac, $mod_hr) = @_;
	my $constants = getCurrentStatic();

	my $c = $constants->{m2_consequences};
	my $retval = { };
	for my $ckey (sort { $a <=> $b } keys %$c) {
		if ($frac <= $ckey) {
			my @vals = @{$c->{$ckey}};
			for my $key (qw(        m2_fair_tokens
						m2_unfair_tokens
						m1_tokens
						m1_karma )) {
				$retval->{$key}{num} = shift @vals; 
			}
			$self->_csq_bonuses($frac, $retval, $mod_hr);
			for my $key (keys %$retval) {
				$self->_set_csq($key, $retval->{$key});
			}
			last;
		}
	}

	my $cr = $constants->{m2_consequences_repeats};
	if ($cr && %$cr) {
		my $repeats = $self->_csq_repeats($mod_hr);
		for my $min (sort { $b <=> $a } keys %$cr) {
			if ($min <= $repeats) {
				$retval->{m1_tokens}{num} += $cr->{$min};
				$self->_set_csq('m1_tokens', $retval->{m1_tokens});
				last;
			}
		}
	}

	return $retval;
}

sub getModResolutionSummaryForUser {
	my($self, $uid, $limit) = @_;
	my $uid_q = $self->sqlQuote($uid);
	my $limit_str = "";
	$limit_str = "LIMIT $limit" if $limit;
	my($fair, $unfair, $fairvotes, $unfairvotes) = (0,0,0,0);
	
	my $reasons = $self->getReasons();
	my @reasons_m2able = grep { $reasons->{$_}{m2able} } keys %$reasons;
	my $reasons_m2able = join(",", @reasons_m2able);
	
	return {} unless @reasons_m2able;
	my $reason_str = " AND reason IN ($reasons_m2able)";
	
	my $mod_ids = $self->sqlSelectColArrayref("id", "moderatorlog",
			"uid=$uid_q AND active=1 AND m2status=2 $reason_str",
			"ORDER BY id desc $limit_str");

	foreach my $mod (@$mod_ids){
		my $m2_ar = $self->getMetaModerations($mod);
		
		my $nunfair = scalar(grep { $_->{active} && $_->{val} == -1 } @$m2_ar);
		my $nfair   = scalar(grep { $_->{active} && $_->{val} ==  1 } @$m2_ar);

		$unfair++ if $nunfair > $nfair;
		$fair++ if $nfair > $nunfair;
		$fairvotes += $nfair;
		$unfairvotes += $nunfair;
	}
	return { fair => $fair, unfair => $unfair, fairvotes => $fairvotes, unfairvotes => $unfairvotes };
}

sub _csq_repeats {
	my($self, $mod_hr) = @_;
	# Count the number of moderations performed by this user
	# on the same target user, in the same direction (up or
	# down), before the current mod we're reconciling, but of
	# course after the archive_delay_mod (or a max of 60 days).
	my $ac_uid = getCurrentStatic("anonymous_coward_uid");
	return $self->sqlCount(
		"moderatorlog",
		"active=1
		 AND uid=$mod_hr->{uid} AND cuid=$mod_hr->{cuid}
		 AND cuid != $ac_uid
		 AND val=$mod_hr->{val}
		 AND id < $mod_hr->{id}
		 AND ts >= DATE_SUB(NOW(), INTERVAL 60 DAY)");
}

sub _csq_bonuses {
	my($self, $frac, $retval, $mod_hr) = @_;
	my $constants = getCurrentStatic();

	my $num = $retval->{m1_tokens}{num};
	# Only moderations that are going to give a token bonus
	# already qualify to have that bonus hiked.
	return if $num <= 0;

	my $num_orig = $num;
	my @applied = qw( );

	# "Slashdot provides an existence proof that the basic idea
	# of distributed moderation is sound. ... There is still
	# room, however, for design advances that require only
	# modestly more moderator effort to produce far more timely
	# and accurate moderation overall."
	#
	# That and following quotes are taken from:
	# Lampe, C. and Resnick, P. "Slash(dot) and Burn: Moderation in a
	# Large Scale Conversation Space."  Proceedings of the Conference on
	# Computer Human Interaction (SIGCHI).  April 2004. Vienna, Austria.
	# ACM Press.  (Forthcoming.)
	#
	# The goal of _csq_bonuses is to reward moderators who take
	# a little extra effort, by giving them their next set of
	# mod points sooner.  It may work better if moderators are
	# told about these bonuses and are encouraged to take actions
	# to earn them.  Even if not, at least the moderators who
	# take it upon themselves to _do_ these actions will be able
	# to moderate more frequently.

	# If a comment was Fairly moderated *soon* after being posted,
	# give the moderator a bonus for being quick on the draw.
	#
	# "Among comments that received some moderation, the median time
	# until receiving the first moderation was 83 minutes... More
	# than 40% of comments that reached a +4 score took longer to do
	# so than 174 minutes, the time at which a typical conversation
	# was already half over."
	if ($mod_hr->{secs_before_mod} < $constants->{m2_consequences_bonus_earlymod_secs}) {
		$num *= $constants->{m2_consequences_bonus_earlymod_tokenmult} || 1;
		push @applied, 'earlymod';
	}

	# If a Fair moderation was applied to a comment not posted
	# too early in a discussion, give the moderator a bonus for
	# not just hanging out for the first few minutes of a story.
	#
	# "Of early comments [in the first quintile of their
	# discussion], 59% were moderated, compared to 25% for
	# comments in the middle [third quintile] of their
	# conversation and 7% for late comments [fifth quintile]."
	# Here, quintile 5 is the latest 20% of the discussion, and
	# quintile 1 is the earliest 20%.
	if ($mod_hr->{cid_percentile} > 80) {
		$num *= $constants->{m2_consequences_bonus_quintile_5} || 1;
		push @applied, 'quintile_5';
	} elsif ($mod_hr->{cid_percentile} > 60) {
		$num *= $constants->{m2_consequences_bonus_quintile_4} || 1;
		push @applied, 'quintile_4';
	} elsif ($mod_hr->{cid_percentile} > 40) {
		$num *= $constants->{m2_consequences_bonus_quintile_3} || 1;
		push @applied, 'quintile_3';
	} elsif ($mod_hr->{cid_percentile} > 20) {
		$num *= $constants->{m2_consequences_bonus_quintile_2} || 1;
		push @applied, 'quintile_2';
	} else {
		$num *= $constants->{m2_consequences_bonus_quintile_1} || 1;
		push @applied, 'quintile_1';
	}

	# If a Fair moderation was applied to a comment that was
	# a reply, rather than top-level, give the moderator a bonus
	# for not just scanning the most visible comments.
	#
	# "Of top-level comments, 48% received some moderation,
	# compared to 22% for response comments.  The mean final
	# score for top-level comments was 1.73, as compared to
	# 1.40 for responses."
	if ($mod_hr->{comment_pid}) {
		$num *= $constants->{m2_consequences_bonus_replypost_tokenmult} || 1;
		push @applied, 'reply';
	}

	# If a Fair moderation was applied to a comment while it
	# was at a low score, give the moderator a bonus.  Or
	# perhaps don't give the moderator quite so many tokens
	# for moderating a comment while it was at a high score.
	#
	# "Moderators may give insufficient attention to comments
	# with low scores... comments with lower starting scores
	# were less likely to be moderated.  For example, 30% of
	# comments starting at 2 received a moderation, compared
	# to only 29% of those starting at 1, 25% of those
	# starting at 0, and 9% of those starting at -1."
	#
	# I don't think that's much of a spread (from 0 to 2
	# anyway), and note this applies to the comment's score
	# at the time of moderation, not its original score
	# (since if a comment went from 0 to 4 and then got
	# moderated, the moderator only saw it at 4 anyway).
	my $constname = "m2_consequences_bonus_pointsorig_$mod_hr->{points_orig}";
	if (defined($constants->{$constname})) {
		$num *= $constants->{$constname};
		push @applied, "pointsorig_$mod_hr->{points_orig}";
	}

	return if $num == $num_orig;

	if ($frac < $constants->{m2_consequences_bonus_minfairfrac}) {
		# Only moderations that meet a certain minimum
		# level of Fairness qualify for the bonuses.
		# This mod did not meet that level.  So now, the
		# consequences change does not happen if it would
		# be advantageous to the moderator.
		return if $num_orig > $num;
	}

printf STDERR "%s m2_consequences change from '%d' to '%.2f' because '%s' id %d cid %d uid %d\n",
scalar(localtime), $num_orig, $num, join(" ", @applied), $mod_hr->{id}, $mod_hr->{cid}, $mod_hr->{uid};

	$retval->{csq_token_change}{num} ||= 0;
	$retval->{csq_token_change}{num} += $num - $num_orig;
	$retval->{m1_tokens}{num} = sprintf("%+.2f", $num);
}

sub _set_csq {
        my($self, $key, $hr) = @_;
        my $n = $hr->{num};
        if (!$n) {
                $hr->{chance} = $hr->{sign} = 0;
                $hr->{sql_base} = $hr->{sql_possible} = "";
                $hr->{sql_and_where} = undef;
                return ;
        }

        my $constants = getCurrentStatic();
        my $column = 'tokens';
        $column = 'karma' if $key =~ /karma$/;
        my $max = ($column eq 'tokens')
                ? $constants->{m2_consequences_token_max}
                : $constants->{m2_maxbonus_karma};
        my $min = ($column eq 'tokens')
                ? $constants->{m2_consequences_token_min}
                : $constants->{minkarma};

        my $sign = 1; $sign = -1 if $n < 0;
        $hr->{sign} = $sign;

        my $a = abs($n);
        my $i = int($a);

        $hr->{chance} = $a - $i;
        $hr->{num_base} = $i * $sign;
        $hr->{num_possible} = ($i+1) * $sign;
        if ($sign > 0) {
                $hr->{sql_and_where}{$column} = "$column < $max";
                $hr->{sql_base} = $i ? "LEAST($column+$i, $max)" : "";
                $hr->{sql_possible} = "LEAST($column+" . ($i+1) . ", $max)"
                        if $hr->{chance};
        } else {
                $hr->{sql_and_where}{$column} = "$column > $min";
                $hr->{sql_base} = $i ? "GREATEST($column-$i, $min)" : "";
                $hr->{sql_possible} = "GREATEST($column-" . ($i+1) . ", $min)"
                        if $hr->{chance};
        }
}

########################################################
# For dailyStuff
# 	This should only be run once per day, if this isn't
#	true, the simple logic below, breaks. This can be
#	fixed by moving the by_days trigger to a date
#	based system as opposed to a counter-based one,
#	or even adding a date component to expiry checks,
#	which might be a better solution.
sub checkUserExpiry {
	my($self) = @_;
	my($ret);

	# Subtract one from number of 'registered days left' for all users.
	$self->sqlUpdate(
		'users_info',
		{ -'expiry_days' => 'expiry_days-1' },
		'1=1'
	);

	# Now grab all UIDs that look to be expired, we explicitly exclude
	# authors from this search.
	$ret = $self->sqlSelectAll(
		'distinct uid',
		'users_info',
		'expiry_days < 0 or expiry_comm < 0'
	);

	# We only want the list of UIDs that aren't authors and have not already
	# expired. The extra perl code would be completely unavoidable if we had
	# subselects... *sigh*
	my(@returnable) = grep {
		my $user = $self->getUser($_->[0]);
		$_ = $_->[0];
		!($user->{author} || ! $user->{registered});
	} @{$ret};

	return \@returnable;
}

########################################################
# Get an arrayref of moderatorlog rows that are ready to have
# their M2's reconciled.  This used to be complex to figure out but
# now it's easy;  moderatorlog rows start with m2status=0, graduate
# to m2status=1 when they are ready to be reconciled by the task,
# and move to m2status=2 when they are reconciled.
sub getModsNeedingReconcile {
	my($self) = @_;

	my $batchsize = getCurrentStatic("m2_batchsize");
	my $limit = "";
	$limit = "LIMIT $batchsize" if $batchsize;

	my $mods_ar = $self->sqlSelectAllHashrefArray(
		'moderatorlog.id AS id, moderatorlog.ipid AS ipid,
			moderatorlog.subnetid AS subnetid,
			moderatorlog.uid AS uid, val,
			moderatorlog.sid AS sid,
			moderatorlog.ts AS ts,
			moderatorlog.cid AS cid, cuid,
			moderatorlog.reason AS reason,
			active, spent, m2count, m2status,
			points_orig,
		 comments.pid AS comment_pid,
		 comments.pointsorig AS comment_pointsorig,
		 UNIX_TIMESTAMP(moderatorlog.ts) AS mod_unixts,
		 UNIX_TIMESTAMP(comments.date) AS comment_unixts,
		 UNIX_TIMESTAMP(discussions.ts) AS discussion_unixts,
		 discussions.commentcount AS discussion_commentcount',
		'moderatorlog,comments,discussions',
		'm2status=1
			AND moderatorlog.cid = comments.cid
			AND moderatorlog.sid = discussions.id',
		"ORDER BY id $limit",
	);

	# Now get some extra data about each discussion and the
	# moderated comments in question.  We want the percentile
	# of each comment in its discussion, and also the time
	# in seconds between discussion opening and the comment
	# being posted.
	if ($mods_ar && @$mods_ar) {
		my %disc_ids = map { ($_->{sid}, 1) } @$mods_ar;
		my %sid_cids = ( );
		my $sid_in_clause = "sid IN (" . join(", ", keys %disc_ids) . ")";
		my $cid_ar = $self->sqlSelectAll(
			"sid, cid",
			"comments",
			$sid_in_clause,
			"ORDER BY sid, cid");
		for my $ar (@$cid_ar) {
			my($sid, $cid) = @$ar;
			push @{$sid_cids{$sid}}, $cid;
		}
		for my $mod (@$mods_ar) {
			# Generate the cid_percentile, where 0 is the
			# first comment in the discussion, and 100 is
			# the last comment (posted so far).
			my($sid, $cid) = ($mod->{sid}, $mod->{cid});
			my $cidlist_ar = $sid_cids{$sid};
			if (scalar(@$cidlist_ar < 10)) {
				$mod->{cid_percentile} = undef;
			} else {
				$mod->{cid_percentile} = _find_percentile(
					$cid, $cidlist_ar);
			}
			# Generate the number of seconds between
			# discussion opening and the comment being
			# posted.
			$mod->{secs_before_post} = $mod->{comment_unixts}
				- $mod->{discussion_unixts};
			# Generate the number of seconds between
			# the comment being posted and its being
			# moderated.
			$mod->{secs_before_mod} = $mod->{mod_unixts}
				- $mod->{comment_unixts};
		}
	}

	return $mods_ar;
}

sub _find_percentile {
	my($item, $list) = @_;
	my $n = $#$list;
	return undef if $n < 1;
	my $i = $n;
	for (0..$n-1) {
		$i = $_, last if $item <= $list->[$_];
	}
	return sprintf("%.1f", 100*($i/$n));
}

########################################################
# For moderation scripts.
#	This sub returns the meta-moderation information
#	given the appropriate M2ID (primary
#	key into the metamodlog table).
#
sub getMetaModerations {
	my($self, $mmid) = @_;

	my $ret = $self->sqlSelectAllHashrefArray(
		'*', 'metamodlog', "mmid=$mmid"
	);

	return $ret;
}

########################################################
# For freshenup.pl
sub getMinCommentcount {
	my($self, $stoids) = @_;
	return 0 if !$stoids || !@$stoids;
	my $stoid_clause = join(",", map { $self->sqlQuote($_) } @$stoids );
	return $self->sqlSelect(
		"MIN(commentcount)",
		"stories",
		"stoid IN ($stoid_clause)");
}

########################################################
# For freshenup.pl
#
# We have an index on just 1 char of story_text.rendered, and
# its only purpose is to make this select into a lookup instead
# of a table scan.
# XXXSECTIONTOPICS - This is broken, I'm fixing - Jamie
sub getStoriesNeedingRender {
	my($self, $limit) = @_;
	$limit ||= 10;
	
	my $mp_tid = getCurrentStatic('mainpage_nexus_tid');
	
	my $returnable = $self->sqlSelectColArrayref(
		"stories.stoid",
		"stories, story_text, story_topics_rendered", 
		"stories.stoid = story_text.stoid
		 AND stories.stoid = story_topics_rendered.stoid 
		 AND story_topics_rendered.tid = $mp_tid
		 AND rendered IS NULL",
		"ORDER BY time DESC LIMIT $limit"
	);
	return $returnable;
}

########################################################
# For freshenup.pl,archive.pl
#
#XXXSECTIONTOPICS - This is broken, I'm fixing - Jamie
# displaystatus stuff still needs reworking here
sub getStoriesWithFlag {
	my($self, $purpose, $order, $limit) = @_;

	my $order_clause = " ORDER BY time $order";
	my $limit_clause = "";
	$limit_clause = " LIMIT $limit" if $limit;

	# Currently only used by two tasks and we do NOT want stories
	# that are marked as "Never Display". If this changes, 
	# another method will be required. If such is created, I would
	# suggest getAllStoriesWithFlag() as the method name. We ALSO
	# don't want to mess with stories that haven't been displayed
	# yet!  - Cliff 14-Oct-2001
	# But if writestatus is delete, we want ALL the candidates,
	# not just the ones that are displaying -- pudge
	my $returnable = [ ];
	my $mp_tid = getCurrentStatic('mainpage_nexus_tid');
	if ($purpose eq 'delete') {
		# Find all stories that are in the trash.
		$returnable = $self->sqlSelectAllHashrefArray(
			"stories.stoid AS stoid, sid, primaryskid, title, time",
			"stories, story_text",
			"stories.stoid = story_text.stoid
			 AND in_trash = 'yes'",
			"$order_clause$limit_clause");
	} elsif ($purpose eq 'mainpage_dirty') {
		# Find all stories in the past that are dirty and have
		# been rendered into the mainpage nexus tid.
		$returnable = $self->sqlSelectAllHashrefArray(
			"stories.stoid AS stoid, sid, primaryskid, title, time",
			"stories, story_text, story_topics_rendered
			 LEFT JOIN story_dirty ON stories.stoid=story_dirty.stoid",
			"time < NOW()
			 AND stories.stoid = story_text.stoid
			 AND story_dirty.stoid IS NOT NULL
			 AND stories.stoid = story_topics_rendered.stoid
			 AND story_topics_rendered.tid = '$mp_tid'",
			"$order_clause$limit_clause");
	} elsif ($purpose eq 'all_dirty') {
		# Find all stories in the past that are dirty and have
		# been rendered into ANY tid (thus excluding "ND"
		# stories which don't have any nexus tids)..
		$returnable = $self->sqlSelectAllHashrefArray(
			"stories.stoid AS stoid, sid, primaryskid, title, time",
			"stories, story_text, story_topics_rendered
			 LEFT JOIN story_dirty ON stories.stoid=story_dirty.stoid",
			"time < NOW()
			 AND stories.stoid = story_text.stoid
			 AND story_dirty.stoid IS NOT NULL
			 AND stories.stoid = story_topics_rendered.stoid",
			"GROUP BY stories.stoid $order_clause$limit_clause");
		# Now we walk the list and eliminate any stories that
		# aren't viewable.  Viewable may not be exactly the
		# same as simply having one or more nexus tids, so the
		# select may not have excluded all the right ones.
		for my $story (@$returnable) {
			$story->{killme} = 1 if !$self->checkStoryViewable($story->{stoid});
		}
		$returnable = [ grep { !$_->{killme} } @$returnable ];
	}

	return $returnable;
}

########################################################
# For tasks/spamarmor.pl
#
# This returns a hashref of uid and realemail for 1/nth of the users
# whose emaildisplay param is set to 1 (armored email addresses).
# By default 1/7th, and which 1/7th determined by date.
#
# If emaildisplay is moved from users_param into the schema proper,
# this code will have to be changed.
#
sub getTodayArmorList {
	my($self, $buckets, $which_bucket) = @_;

	# Defaults to 7 for weekly rotation.
	$buckets = 7 if !defined($buckets);
	$buckets =~ /(\d+)/; $buckets = $1;

	# Default to day of year.
	$which_bucket = (localtime)[7] if !defined($which_bucket); 
	$which_bucket =~ /(\d+)/; $which_bucket = $1;
	$which_bucket %= $buckets;
	my $uid_aryref = $self->sqlSelectColArrayref(
		"uid",
		"users_param",
		"MOD(uid, $buckets) = $which_bucket AND name='emaildisplay' AND value=1",
		"ORDER BY uid"
	);
	return { } if !@$uid_aryref; # nobody wants armor? skip next select
	my $uid_list = join(",", @$uid_aryref);
	return $self->sqlSelectAllHashref(
		"uid",
		"uid, realemail",
		"users",
		"uid IN ($uid_list)"
	);
}

########################################################
# freshen.pl
sub deleteStoryAll {
	my($self, $sid) = @_;
	my $sid_q = $self->sqlQuote($sid);

#	$self->{_dbh}{AutoCommit} = 0;
	$self->sqlDo("SET AUTOCOMMIT=0");
	my $discussion_id = $self->sqlSelect('id', 'discussions', "sid = $sid_q");
	$self->sqlDelete("stories", "sid=$sid_q");
	$self->sqlDelete("story_text", "sid=$sid_q");
	$self->deleteDiscussion($discussion_id) if $discussion_id;
#	$self->{_dbh}->commit;
#	$self->{_dbh}{AutoCommit} = 1;
	$self->sqlDo("COMMIT");
	$self->sqlDo("SET AUTOCOMMIT=1");
}

########################################################
# For tasks/author_cache.pl
# GREATEST() is because of inconsistent schema where some values can
# be NULL, which breaks MySQL -- pudge
sub createAuthorCache {
	my($self) = @_;
	my $sql;
	$sql  = "REPLACE INTO authors_cache ";
	$sql .= "SELECT users.uid, nickname, GREATEST(fakeemail, ''),
		GREATEST(homepage, ''), 0, GREATEST(bio, ''), author ";
	$sql .= "FROM users, users_info ";
	$sql .= "WHERE users.author=1 ";
	$sql .= "AND users.uid=users_info.uid";

	$self->sqlDo($sql);

	$sql  = "REPLACE INTO authors_cache ";
	$sql .= "SELECT users.uid, nickname, GREATEST(fakeemail, ''),
		GREATEST(homepage, ''), count(stories.uid),
		GREATEST(bio, ''), author ";
	$sql .= "FROM users, stories, users_info ";
	$sql .= "WHERE stories.uid=users.uid ";
	$sql .= "AND users.uid=users_info.uid GROUP BY stories.uid";

	$self->sqlDo($sql);

	# The above can leave old entries in authors_cache where author
	# used to be 1 but is now 0, but the user in question has never
	# posted a story.  Delete them.  This can't be done in the
	# REPLACE INTOs above because the SELECT clause can't join on
	# the same table we REPLACE INTO.
	my $uid_ar = $self->sqlSelectColArrayref(
		"authors_cache.uid AS uid",
		"authors_cache, users",
		"authors_cache.uid = users.uid
		 AND authors_cache.author != users.author"
	);
	return if !$uid_ar || !@$uid_ar;
	my $uid_list = "(" . join(",", @$uid_ar) . ")";
	$self->sqlDelete("authors_cache", "uid IN $uid_list");
}

########################################################
# For plugins/Admin/refresh_uncommon.pl
sub refreshUncommonStoryWords {
	my($self) = @_;
	my $constants = getCurrentStatic();
	my $ignore_threshold = $constants->{uncommonstoryword_thresh} || 2;
	my $n_days = $constants->{similarstorydays} || 30;
	$ignore_threshold = int($n_days/$ignore_threshold+0.5);

	# First, get a collection of all words posted in stories for the last
	# however-many days.
	my $arr = $self->sqlSelectAll(
		"title, introtext, bodytext",
		"story_text, stories",
		"stories.stoid = story_text.stoid
		 AND stories.time >= DATE_SUB(NOW(), INTERVAL $n_days DAY)"
	);
	my %common_words = map { ($_, 1) } split " ",
		($self->getVar('common_story_words', 'value', 1) || "");
	my @weights = (
		$constants->{uncommon_weight_title} || 8,
		$constants->{uncommon_weight_introtext} || 1,
		$constants->{uncommon_weight_bodytext} || 0.5,
	);
	my $word_hr = { };
	for my $ar (@$arr) {
		my $data = {
			output_hr	=> $word_hr,
			title		=> { text => $ar->[0],
					     weight => $constants->{uncommon_weight_title}	|| 8.0 },
			introtext	=> { text => $ar->[1],
					     weight => $constants->{uncommon_weight_introtext}	|| 2.0 },
			bodytext	=> { text => $ar->[2],
					     weight => $constants->{uncommon_weight_bodytext}	|| 1.0 },
		};
		findWords($data);
	}

	# The only words that count as uncommon are the ones that appear in
	# stories less frequently than once every uncommonstoryword_thresh
	# days.  Everything else is, well, too common to bother with.
	my @uncommon_words = ( );
	my $maxlen = $constants->{uncommonstorywords_maxlen} || 65000;
	my $minlen = $constants->{uncommonstoryword_minlen} || 3;
	my $length = $maxlen+1;
	@uncommon_words =
		sort {
			$word_hr->{$b}{weight} <=> $word_hr->{$a}{weight}
			||
			length($b) <=> length($a)
			||
			$a cmp $b
		}
		grep { $word_hr->{$_}{count} <= $ignore_threshold }
		grep { length($_) > $minlen }
		grep { !$common_words{$_} }
		keys %$word_hr;
	my $uncommon_words = substr(join(" ", @uncommon_words), 0, $maxlen);
	if (length($uncommon_words) == $maxlen) {
		$uncommon_words =~ s/\s+\S+\Z//;
	}

	$self->setVar("uncommonstorywords", $uncommon_words);
}

########################################################
# For tasks/freshenup.pl
#
# get previous sections stored so we can clear out old .shtml
# files and redirect to new

sub getPrevSectionsForSid {
	my($self, $stoid) = @_;
	my $old_sect = $self->sqlSelect(
		"value",
		"story_param",
		"name='old_shtml_sections' AND stoid=$stoid");
	my @old_sect = grep { $_ } split(/,/, $old_sect);
	return @old_sect;
}

########################################################
# For tasks/freshenup.pl
#
# clear old sections stored after their .shtml files 
# have been cleaned up
 
sub clearPrevSectionsForSid {
	my($self, $stoid) = @_;
	$self->sqlDelete(
		"story_param",
		"name='old_shtml_sections' AND stoid=$stoid");
}

########################################################
# For tasks/flush_formkeys.pl
sub deleteOldFormkeys {
	my($self, $timeframe) = @_;
	my $delete_before_time = time - ($timeframe || 14400);
	$self->sqlDelete("formkeys", "ts < $delete_before_time");
}

########################################################
sub countAccesslogDaily {
	my($self) = @_;
	return $self->sqlCount("accesslog", "TO_DAYS(NOW()) - TO_DAYS(ts)=1");
}

########################################################
# For tasks/run_moderatord.pl
sub countM2M1Ratios {
	my($self, $longterm) = @_;

	my $reasons = $self->getReasons();
	my @reasons_m2able = grep { $reasons->{$_}{m2able} } keys %$reasons;
	my $reasons_m2able = join(",", @reasons_m2able);

	my @ratios = ( );
	for my $daysback (7, 28) {
		my $m1 = $self->sqlCount("moderatorlog");
	}
	my $daysback = $longterm ? 28 : 7;

	return $self->sqlCount("moderatorlog");
}

sub countM2 {
	my($self) = @_;
	return 0;
}

########################################################
# For portald
sub createRSS {
	my($self, $bid, $item) = @_;
	# this will go away once we require Digest::MD5 2.17 or greater
	# Hey pudge, CPAN is up to Digest::MD5 2.25 or so, think we can
	# make this go away now? - Jamie 2003/07/24
	# Oh probably, if someone wants to test it and all, i can
	# add it to Slash::Bundle etc.  i'll put it on my TODO
	# and DO it when i can. -- pudge
	$item->{title} =~ /^(.*)$/;
	my $title = $1;
	$item->{description} =~ /^(.*)$/;
	my $description = $1;
	$item->{'link'} =~ /^(.*)$/;
	my $link = $1;

	$self->sqlInsert('rss_raw', {
# 		link_signature		=> md5_hex($item->{'link'}),
# 		title_signature		=> md5_hex($item->{'title'}),
# 		description_signature	=> md5_hex($item->{'description'}),
		link_signature		=> md5_hex($link),
		title_signature		=> md5_hex($title),
		description_signature	=> md5_hex($description),
		'link'			=> $item->{'link'},
		title			=> $item->{'title'},
		description		=> $item->{'description'},
		-created		=> 'now()',
		bid => $bid,
	}, { ignore => 1});
}

sub getRSSNotProcessed {
	my($self, $bid, $item) = @_;
	$self->sqlSelectAllHashrefArray('*', 'rss_raw', ' processed = "no"');
}

sub expireRSS {
	my($self, $day) = @_;
	return unless $day;
	$self->sqlUpdate('rss_raw', {
		processed	=> 'yes',
		'link'		=> '',
		title		=> '',
		description	=> '',
	}, "created < '$day 00:00'");
}

########################################################
# For slashd

########################################################
# see Slash::DB::MySQL instead
#sub getSlashdStatus {
#	my($self) = @_;
#	my $answer = _genericGet('slashd_status', 'task', '', @_);
#	$answer->{last_completed_hhmm} =
#		substr($answer->{last_completed}, 11, 5)
#		if defined($answer->{last_completed});
#	$answer->{next_begin_hhmm} =
#		substr($answer->{next_begin}, 11, 5)
#		if defined($answer->{next_begin});
#	return $answer;
#}

########################################################
sub setSlashdStatus {
	my($self, $taskname, $options) = @_;
	return $self->sqlUpdate(
		"slashd_status",
		$options,
		"task=" . $self->sqlQuote($taskname)
	);
}

########################################################
sub countPollQuestion {
	my($self, $qid) = @_;
	my $answer = $self->sqlSelect(
		"SUM(votes)",
		"pollanswers",
		"qid = $qid",
		"GROUP BY qid");

	return $answer;
}

########################################################

sub setCurrentSectionPolls {
        my($self) = @_;
        my $section_polls = $self->sqlSelectAllHashrefArray("primaryskid,max(date) as date", "pollquestions", "date<=NOW() and polltype='section'", "group by primaryskid"); 
	foreach my $p (@$section_polls) {
                my $poll = $self->sqlSelectHashref("qid,primaryskid", "pollquestions", "primaryskid='$p->{primaryskid}' and date='$p->{date}'");
		my $nexus_id = $self->getNexusFromSkid($p->{primaryskid});
		$self->setNexusCurrentQid($nexus_id, $poll->{qid});
        }
}

########################################################
sub createSlashdStatus {
	my($self, $taskname) = @_;
	$self->sqlInsert(
		"slashd_status",
		{ task => $taskname },
		{ ignore => 1 } );
	$self->sqlUpdate(
		"slashd_status",
		{ in_progress => 0 },
		"task=" . $self->sqlQuote($taskname));
}

########################################################
# Basically, a special-purpose alias to setSlashdStatus()
sub updateTaskSummary {
	my($self, $taskname, $summary) = @_;

	$self->setSlashdStatus($taskname, {
		summary => $summary,
	});
}

########################################################
# Returns the number of new users created since n days in the past
# (chunks to a GMT day boundary).  E.g., if n=0, number created
# since the last GMT midnight;  subtract n=1 from n=0 to figure
# out how many users were created yesterday (GMT).
sub getNumNewUsersSinceDaysback {
	my($self, $daysback) = @_;
	$daysback ||= 0;

	my $max_uid = $self->countUsers({ max => 1 });
	my $min = $self->sqlSelect(
		"MIN(uid)",
		"users_info",
		"SUBSTRING(created_at, 1, 10) >= SUBSTRING(DATE_SUB(
			NOW(), INTERVAL $daysback DAY
		 ), 1, 10)");
	if (!defined($min)) {
		return 0;
	} else {
		return $max_uid - $min + 1;
	}
}

########################################################
# Returns the first UID created within the last n days.
# Rounds off to GMT midnight.
sub getFirstUIDCreatedDaysBack {
	my($self, $num_days, $yesterday) = @_;
	$yesterday = substr($yesterday, 0, 10);

	my $between_str = '';
	if ($num_days) {
		$between_str = "BETWEEN DATE_SUB('$yesterday 00:00',    INTERVAL $num_days DAY)
				    AND DATE_SUB('$yesterday 23:59:59', INTERVAL $num_days DAY)";
	} else {
		$between_str = "BETWEEN '$yesterday 00:00' AND '$yesterday 23:59:59'";
	}
	return $self->sqlSelect(
		"MIN(uid)",
		"users_info",
		"created_at $between_str");
}

########################################################
sub getLastUIDCreatedBeforeDaysBack {
	my($self, $num_days, $yesterday) = @_;
	$yesterday = substr($yesterday, 0, 10);
	my $where = '';
	if ($where) {
		$where = "created_at < DATE_SUB('$yesterday 00:00',INTERVAL $num_days DAY)";
	} else {
		$where = "created_at < '$yesterday 00:00'";
	}
	return $self->sqlSelect(
		"MAX(uid)",
		"users_info",
		$where);
}

########################################################
# Returns the uid/nicks of a random sample of users created
# since yesterday.
sub getRandUsersCreatedYest {
	my($self, $num, $yesterday) = @_;
	$num ||= 10;

	my $min_uid = $self->getLastUIDCreatedBeforeDaysBack(0, $yesterday);
	return [ ] unless $min_uid;
	my $max_uid = $self->getFirstUIDCreatedDaysBack(-1, $yesterday);
	if ($max_uid) {
		$max_uid--;
	} else {
		$max_uid = $self->countUsers({ max => 1 });
	}
	return [ ] unless $max_uid && $max_uid >= $min_uid;
	my $users_ar = $self->sqlSelectAllHashrefArray(
		"uid, nickname, realemail",
		"users",
		"uid BETWEEN $min_uid + 1 AND $max_uid",
		"ORDER BY RAND() LIMIT $num");
	return [ ] unless $users_ar && @$users_ar;
	@$users_ar = sort { $a->{uid} <=> $b->{uid} } @$users_ar;
	return $users_ar;
}

########################################################
# Returns the most popular email hosts of recently created
# user accounts.
sub getTopRecentRealemailDomains {
	my($self, $yesterday, $options) = @_;
	my $daysback = $options->{daysback} || 7;
	my $num = $options->{num_wanted} || 10;

	my $min_uid = $self->getLastUIDCreatedBeforeDaysBack($daysback, $yesterday);
	my $newaccounts = $self->sqlSelect('max(uid)','users') - $min_uid;
	my $newnicks = {};
	return [ ] unless $min_uid;
	my $domains = $self->sqlSelectAllHashrefArray(
		"initdomain, COUNT(*) AS c",
		"users_info",
		"uid > $min_uid",
		"GROUP BY initdomain ORDER BY c DESC, initdomain LIMIT $num");

	foreach my $domain (@$domains) {
		my $nicks = $self->sqlSelectAll('nickname','users, users_info',"users.uid=users_info.uid AND users_info.uid >= $min_uid AND initdomain=".$self->sqlQuote($domain->{initdomain}),'ORDER BY users.uid DESC');
		my $length = 5 + length($domain->{initdomain});
		my $i = 0;
		$newnicks->{$domain->{initdomain}} = "";

		while ($length + length($nicks->[$i][0]) + 2 < 78) {
			$newnicks->{$domain->{initdomain}} .= ', ' unless !$i;
			$newnicks->{$domain->{initdomain}} .= $nicks->[$i][0];
			$length += length($nicks->[$i][0]) + 2;
			$i++;
		}
	}

	return $domains, $daysback, $newaccounts, $newnicks;
}



########################################################
# freshenup
sub getSkinsDirty {
	my($self) = @_;
	my $skin_ids = $self->sqlSelectColArrayref(
		'DISTINCT skid',
		'skins LEFT JOIN topic_nexus_dirty ON skins.nexus = topic_nexus_dirty.tid',
		'topic_nexus_dirty.tid IS NOT NULL
		 OR skins.last_rewrite < DATE_SUB(NOW(), INTERVAL max_rewrite_secs SECOND)');
	return $skin_ids || [ ];
}

########################################################
# for new_headfoot.pl
sub getHeadFootPages {
	my($self, $skin, $headfoot) = @_;

	return [] unless $headfoot eq 'header' || $headfoot eq 'footer';

	$skin ||= 'default'; # default to default

	my $list = $self->sqlSelectAll(
		'page',
		'templates',
		"skin = '$skin' AND name='$headfoot' AND page != 'misc'");
	push @$list, [qw( misc )];

	return $list;
}

########################################################
sub getCidForDaysBack {
	my($self, $days, $startat_cid) = @_;
	$days ||= 0;
	$startat_cid ||= 0;
	return $self->sqlSelect(
		"MIN(cid)",
		"comments",
		"cid > $startat_cid AND date > DATE_SUB(NOW(), INTERVAL $days DAY)");
}

########################################################
sub getModderModdeeSummary {
	my ($self, $options) = @_;
	my $ac_uid = getCurrentStatic('anonymous_coward_uid');
	$options ||= {};
	my @where;
	push @where, "ts > date_sub(NOW(),INTERVAL $options->{days_back} DAY)" if $options->{days_back};
	push @where, "cuid != $ac_uid" if $options->{no_anon_comments};
	push @where, "id >= $options->{start_at_id}" if $options->{start_at_id};
	push @where, "id <= $options->{end_at_id}" if $options->{end_at_id};
	push @where, "ipid is not null and ipid!=''" if $options->{need_defined_ipid};

	my $where = join(" AND ", @where);

	my $mods = $self->sqlSelectAllHashref(
			[qw(uid cuid)],
			"uid,cuid,count(*) as count",
			"moderatorlog",
			$where,
			"group by uid, cuid");

	return $mods;
}

########################################################
sub getModderCommenterIPIDSummary {
	my ($self, $options) = @_;
	my $ac_uid = getCurrentStatic('anonymous_coward_uid');
	$options ||= {};
	my @where = ("moderatorlog.cid=comments.cid");
	push @where, "ts > date_sub(NOW(),INTERVAL $options->{days_back} DAY)" if $options->{days_back};
	push @where, "cuid != $ac_uid" if $options->{no_anon_comments};
	push @where, "cuid = $ac_uid" if $options->{only_anon_comments};
	push @where, "id >= $options->{start_at_id}" if $options->{start_at_id};
	push @where, "id <= $options->{end_at_id}" if $options->{end_at_id};
	push @where, "ipid is not null and ipid!=''" if $options->{need_defined_ipid};
	my $where = join(" AND ", @where);
	my $mods = $self->sqlSelectAllHashref(
			[qw(uid ipid)],
			"moderatorlog.uid as uid, comments.ipid as ipid, count(*) as count",
			"moderatorlog,comments",
			$where,
			"group by uid, comments.ipid");
			
	return $mods;
}

########################################################
# Returns a string representing pages per second that the site
# has done recently, based on recent accesslog entries, and the
# MAX(id) that was retrieved.  Optionally pass in the MAX(id)
# from the previous call to try to optimize how much of the
# table to bite off.  This is designed to be called once a
# minute, and to occupy the accesslog table as little as
# possible.
sub getAccesslogPPS {
	my($self, $last_max_id) = @_;
	my $max_id = $self->sqlSelect("MAX(id)", "accesslog") || 0;
	my $span = $last_max_id ? $max_id - $last_max_id : 0;

	my $pps = "-";
	my $rowsback = 1000;
	# If the site is accumulating accesslog rows at fewer
	# than 500 per minute, then don't look back as far as
	# we otherwise might.
	$rowsback = $span*2 if $span && $rowsback > $span*2;
	$rowsback = $max_id-1 if $rowsback > $max_id-1;

	my $retries = 3;
	while ($retries-- > 0) {
		my $lookback_id = $max_id - $rowsback;
		$lookback_id = 1 if $lookback_id < 1;
		my($count, $time) = $self->sqlSelect(
			"COUNT(*), UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(MIN(ts))",
			"accesslog",
			"id >= $lookback_id AND op != 'image'");
		if (!$count || $count < 10) {
			# Very small count;  site is almost unused.
			$pps = "slow";
			$retries = 0;
		} elsif ($time > $count) {
			# Under 1 page/sec;  count less, to make sure
			# this is a _recent_ stat.
			if ($rowsback <= 250) {
				# Close enough.
				# Guaranteed not div-by-zero because
				# $time > 10.
				$pps = sprintf("%.1f", $count / $time);
				$retries = 0;
			} else {
				$rowsback /= 2;
			}
		} elsif ($time < 3) {
			# Page count would be _very_ high;  count more,
			# to make sure we're not just measuring a
			# random spike in DB write timing.
			if ($rowsback >= 4000) {
				$pps = "fast";
				$retries = 0;
			} elsif ($rowsback * 2 >= $max_id - 1) {
				# No sense looking farther back.
				# This site must be pretty new.
				if ($time > 0) {
					$pps = sprintf("%.1f", $count / $time);
				} else {
					$pps = "n/a";
				}
				$retries = 0;
			} else {
				$rowsback *= 2;
			}
		} else {
			# Guaranteed not div-by-zero because $time >= 3.
			$pps = sprintf("%.1f", $count / $time);
			$retries = 0;
		}
	}
	return ($pps, $max_id);
}

########################################################

sub avgDynamicDurationForHour {
	my($self, $ops, $days, $hour) = @_;
	my $page_types = [@$ops];
	my $name_clause = join ',', map { $_ = $self->sqlQuote("duration_dy_$_\_$hour\_mean") } @$page_types;
	my $day_clause = join ',', map { $_ = $self->sqlQuote($_) } @$days;

	return $self->sqlSelectAllHashref(
		"name",
		"AVG(value) AS avg, name",
		"stats_daily",
		"name IN ($name_clause) AND day IN ($day_clause)",
		"GROUP BY name"
	);
}

sub avgDynamicDurationForMinutesBack {
	my($self, $ops, $minutes, $start_id) = @_;
	$start_id ||= 0;
	my $page_types = [@$ops];
	my $op_clause = join ',', map { $_ = $self->sqlQuote("$_") } @$page_types;
	return $self->sqlSelectAllHashref(
		"op",
		"op, AVG(duration) AS avg",
		"accesslog",
		"id >= $start_id
		 AND ts >= DATE_SUB(NOW(), INTERVAL $minutes MINUTE)
		 AND static='no'
		 AND op IN ($op_clause)",
		"GROUP BY op"
	);
}

1;

__END__

=head1 NAME

Slash::DB::Static::MySQL - MySQL Interface for Slash

=head1 SYNOPSIS

	use Slash::DB::Static::MySQL;

=head1 DESCRIPTION

No documentation yet. Sue me.

=head1 SEE ALSO

Slash(3), Slash::DB(3).

=cut

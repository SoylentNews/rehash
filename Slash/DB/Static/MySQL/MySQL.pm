# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::DB::Static::MySQL;
#####################################################################
#
# Note, this is where all of the ugly red headed step children go.
# This does not exist, these are not the methods you are looking for.
#
#####################################################################
use strict;
use Slash::Utility;
use Digest::MD5 'md5_hex';
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
# for slashd
# This method is used in a pretty wasteful way
sub getBackendStories {
	my($self, $section, $topic) = @_;
	# right now it is only topic OR section, because i am lazy;
	# section overrides topic -- pudge

	my $select;
	$select .= "stories.sid, stories.title, time, dept, stories.uid,";
	$select .= "alttext, image, commentcount, hitparade,";
	$select .= "stories.section as section, introtext,";
	$select .= "bodytext, topics.tid as tid";
	my $from = "stories, story_text, topics";

	my $where;
	$where .= "stories.sid = story_text.sid";
	$where .= " AND stories.tid=topics.tid";
	$where .= " AND time < NOW()";
	$where .= " AND stories.writestatus != 'delete'";

	if ($section) {
		$where .= " AND stories.section=\"$section\" AND displaystatus > -1";
	} elsif ($topic) {
		$where .= " AND stories.tid=$topic AND displaystatus = 0";
	} else {
		$where .= " AND displaystatus = 0";
	}
	my $other = "ORDER BY time DESC LIMIT 10";

	my $returnable = $self->sqlSelectAllHashrefArray($select, $from, $where, $other);

	return $returnable;
}

########################################################
# This is only called if ssi is set
# 
# Deprecated code as this is now handled in the tasks!
# - Cliff 10/11/01
sub updateCommentTotals {
	my($self, $sid, $comments) = @_;
	my $hp = join ',', @{$comments->{0}{totals}};
	$self->sqlUpdate("stories", {
			hitparade	=> $hp,
			writestatus	=> 'ok',
			commentcount	=> $comments->{0}{totals}[0]
		}, 'sid=' . $self->{_dbh}->quote($sid)
	);
}

########################################################
# For slashd
sub getNewStoryTopic {
	my($self) = @_;

	my $constants = getCurrentStatic();
	my $needed = $constants->{recent_topic_img_count} || 5;
	$needed = $constants->{recent_topic_txt_count}
		if ($constants->{recent_topic_txt_count} || 0) > $needed;
	# There may be duplicate topics, which we'll handle in perl;
	# here in SQL we just need to be sure we get enough (but not so
	# many we snarf down the whole table).  This guesstimate should
	# work for all sites except those that post tons of duplicate
	# topic stories.
	$needed = $needed*3 + 5;
	my $ar = $self->sqlSelectAllHashrefArray(
		"alttext, image, width, height, stories.tid AS tid",
		"stories, topics",
		"stories.tid=topics.tid AND displaystatus = 0
		 AND writestatus != 'delete' AND time < NOW()",
		"ORDER BY time DESC LIMIT $needed"
	);

	return $ar;
}

########################################################
# For dailystuff
sub updateArchivedDiscussions {
	my($self) = @_;

	my $days_to_archive = getCurrentStatic('archive_delay');
	return unless $days_to_archive;
	# Close discussions.
	$self->sqlDo(
		"UPDATE discussions SET type='archived'
		 WHERE to_days(now()) - to_days(ts) > $days_to_archive AND 
		       (type='open' OR type='dirty')"
	);
}


########################################################
# For dailystuff
sub getArchiveList {
	my($self, $limit, $dir) = @_;
	$limit ||= 1;
	$dir = 'ASC' if $dir ne 'ASC' || $dir ne 'DESC';

	my $days_to_archive = getCurrentStatic('archive_delay');
	return unless $days_to_archive;

	# Close associated story so that final archival .shtml is written
	# to disk. This is accomplished by the archive.pl task.
	my $returnable = $self->sqlSelectAll(
		'sid, title, section', 'stories',
		"to_days(now()) - to_days(time) > $days_to_archive
		AND (writestatus='ok' OR writestatus='dirty')
		AND displaystatus > -1",
		"ORDER BY time $dir LIMIT $limit"
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
sub updateStoriesCounts {
	my($self) = @_;
	my $constants = getCurrentStatic();
	my $counts = $self->sqlSelectAll(
		'dat,count(*)',
		'accesslog',
		"op='article' AND dat !='' AND to_days(now()) - to_days(ts) = 1",
		'GROUP BY(dat)'
	);

	for my $count (@$counts) {
		$self->sqlUpdate('stories', { -hits => "hits+$count->[1]" },
			'sid=' . $self->sqlQuote($count->[0])
		);
	}
}

########################################################
# For dailystuff
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
# For dailystuff
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
# For dailystuff
sub deleteDaily {
	my($self) = @_;
	my $constants = getCurrentStatic();

	$self->updateStoriesCounts();
	my $archive_delay = $constants->{archive_delay} || 14;

	# Now for some random stuff
	$self->sqlDo("DELETE from pollvoters");
	$self->sqlDo("DELETE from moderatorlog WHERE
		to_days(now()) - to_days(ts) > $archive_delay");
	$self->sqlDo("DELETE from metamodlog WHERE
		to_days(now()) - to_days(ts) > $archive_delay");

	# Formkeys
	my $delete_time = time() - $constants->{'formkey_timeframe'};
	$self->sqlDo("DELETE FROM formkeys WHERE ts < $delete_time");

	# Note, on Slashdot, the next line locks the accesslog for several
	# minutes, up to 10 minutes if traffic has been heavy.
	unless ($constants->{noflush_accesslog}) {
		$self->sqlDo("DELETE FROM accesslog WHERE date_add(ts,interval 48 hour) < now()");
	}

	unless ($constants->{noflush_empty_discussions}) {
		$self->sqlDo("DELETE FROM discussions WHERE type='recycle' AND commentcount = 0");
	}
}

########################################################
# For dailystuff
# If the Subscribe plugin is enabled and a certain var is set,
# we're already writing "lastclick" to users_hits so this gets a
# lot easier.  If not, we use the old method of a table scan on
# accesslog.
# Note that "lastaccess" is never guaranteed to be accurate if
# the user has clicked today;  it will still probably show
# yesterday.  It's only intended for longer-term tracking of who
# has visited the site when.
sub updateLastaccess {
	my($self) = @_;
	my $constants = getCurrentStatic();

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
			my @uids = sort keys %{$uids_day{$day}};
			next unless @uids;
			my $uids_in = join(",", @uids);
			$self->sqlUpdate(
				"users_info",
				{ lastaccess => $day },
				"uid IN ($uids_in)"
			);
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
		my $uids_in = join(",", sort @$uids_ar);
		$self->sqlUpdate(
			"users_info",
			{ lastaccess => $yesterday },
			"uid IN ($uids_in) AND lastaccess < '$yesterday'"
		);
	}
}

########################################################
# For dailystuff
sub getDailyMail {
	my($self, $user) = @_;

	my $columns = "stories.sid, stories.title, stories.section,
		users.nickname,
		stories.tid, stories.time, stories.dept,
		story_text.introtext, story_text.bodytext";
	my $tables = "stories, story_text, users";
	my $where = "time < NOW() AND TO_DAYS(NOW())-TO_DAYS(time)=1 ";
	$where .= "AND users.uid=stories.uid AND stories.sid=story_text.sid ";

	if ($user->{sectioncollapse}) {
		$where .= "AND stories.displaystatus>=0 ";
	} else {
		$where .= "AND stories.displaystatus=0 ";
	}

	$where .= "AND tid not in ($user->{extid}) "
		if $user->{extid};
	$where .= "AND stories.uid not in ($user->{exaid}) "
		if $user->{exaid};
	$where .= "AND section not in ($user->{exsect}) "
		if $user->{exsect};

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
	my $archive_delay = $constants->{archive_delay} || 14;
	$archive_delay = 365 if $archive_delay > 365;
	my($min_points, $max_points) =
		($constants->{minpoints}, $constants->{maxpoints});

	my $num_wanted = $constants->{top10comm_num} || 10;

	my $comments;
	my $num_top10_comments = 0;
	while (1) {
		# Select the latest comments with high scores.  If we
		# can't get 10 of them, our standards are too high;
		# lower our minimum score requirement and re-SELECT.
		my $c = $self->sqlSelectMany(
			"stories.sid, title, cid, subject, date, nickname, comments.points, comments.reason",
			"comments, stories, users",
			"stories.time >= DATE_SUB(NOW(), INTERVAL $archive_delay DAY)
				AND comments.points >= $max_points
				AND users.uid=comments.uid
				AND comments.sid=stories.discussion",
			"ORDER BY date DESC LIMIT $num_wanted");
		$comments = $c->fetchall_arrayref;
		$c->finish;
		$num_top10_comments = scalar(@$comments);
		last if $num_top10_comments >= $num_wanted;
		# Didn't get $num_wanted... try again with lower standards.
		--$max_points;
		# If this is as low as we can get... take what we have.
		last if $max_points <= $min_points;
	}

	formatDate($comments, 4, 4);

	return $comments;
}

########################################################
# For portald
sub randomBlock {
	my($self) = @_;
	my $c = $self->sqlSelectMany("bid,title,url,block",
		"blocks",
		"section='index' AND portal=1 AND ordernum < 0");

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
# ugly method name
sub getAccesslogCountTodayAndYesterday {
	my($self) = @_;
	my $c = $self->sqlSelectMany("count(*), to_days(now()) - to_days(ts) as d",
		"accesslog",
		"",
		"GROUP by d order by d asc");

	my($today) = $c->fetchrow;
	my($yesterday) = $c->fetchrow;
	$c->finish;

	return ($today, $yesterday);

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
sub getSectionInfo {
	my($self) = @_;
	$self->sqlConnect();
	# Make more sense to make this a getDescriptions call -Brian
	my $sections = $self->sqlSelectAllHashrefArray(
		"section, url",
		"sections",
		"type='contained' ",
		"ORDER BY section"
	);

	for (@{$sections}) {
		@{%{$_}}{qw(month monthname day)} =
			$self->{_dbh}->selectrow_array(<<EOT);
SELECT MONTH(time), MONTHNAME(time), DAYOFMONTH(time)
FROM stories
WHERE section='$_->{section}' AND time < NOW() AND displaystatus > -1
ORDER BY time DESC LIMIT 1
EOT

		$_->{count} =
			$self->{_dbh}->selectrow_array(<<EOT);
SELECT COUNT(*) FROM stories
WHERE section='$_->{section}'
	AND TO_DAYS(NOW()) - TO_DAYS(time) <= 2 AND time < NOW()
	AND displaystatus > -1
EOT

		$_->{count_sectional} =
			$self->{_dbh}->selectrow_array(<<EOT);
SELECT COUNT(*) FROM stories
WHERE section='$_->{section}'
	AND TO_DAYS(NOW()) - TO_DAYS(time) <= 2 AND time < NOW()
	AND displaystatus > 0
EOT

	}

	my $rootdir = getCurrentStatic('rootdir');
	for my $section (@$sections) {
		# add rootdir, form figured dynamically -- pudge
		$section->{rootdir} = set_rootdir(
			$section->{url}, $rootdir
		);
	}

	return $sections;
}

########################################################
# For run_moderatord.pl
# Slightly new logic.  Now users can accumulate tokens beyond the
# "trade-in" limit and the token_retention var is obviated.
# Any user with more than $tokentrade tokens is forced to cash
# them in for points, but they get to keep any excess tokens.
sub convert_tokens_to_points {
	my($self) = @_;

	my $constants = getCurrentStatic();
	my %granted = ( );

	my $maxtokens = $constants->{maxtokens} || 60;
	my $tokperpt = $constants->{tokensperpoint} || 8;
	my $maxpoints = $constants->{maxpoints} || 5;
	my $pointtrade = $maxpoints;
	my $tokentrade = $pointtrade * $tokperpt;
	$tokentrade = $maxtokens if $tokentrade > $maxtokens; # sanity check

	my $uids = $self->sqlSelectColArrayref(
		"uid",
		"users_info",
		"tokens >= $tokentrade",
		"ORDER BY uid",
	);

	# Locking tables is no longer required since we're doing the
	# update all at once on just one table and since we're using
	# + and - instead of using absolute values. - Jamie 2002/08/08

	for my $uid (@$uids) {
		next unless $uid;
		my $rows = $self->setUser($uid, {
			-lastgranted	=> 'NOW()',
			-tokens		=> "tokens - $tokentrade",
			-points		=> "LEAST(points + $pointtrade, $maxpoints)",
		});
		$granted{$uid} = 1 if $rows;
	}

	# We used to do some fancy footwork with a cursor and locking
	# tables.  The only difference between that code and this is that
	# it only limited points to maxpoints for users with karma >= 0
	# and seclev < 100.  These aren't meaningful limitations, so these
	# updates should work as well.  - Jamie 2002/08/08
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
# For moderatord
sub stirPool {
	my($self) = @_;
	my $stir = getCurrentStatic('stir');
	# Note that this query should not affect editors, although it used
	# to, hence we've removed seclev, and the users table from this 
	# query, entirely.
	my $cursor = $self->sqlSelectMany("points,users_comments.uid AS uid",
			"users_comments,users_info",
			"users_info.uid=users_comments.uid AND
			 points > 0 AND
			 TO_DAYS(now())-TO_DAYS(lastgranted) > $stir");

	my $revoked = 0;

	$self->sqlTransactionStart("LOCK TABLES users_info WRITE,users_comments WRITE");

	while (my($p, $u) = $cursor->fetchrow) {
		$revoked += $p;
		$self->setUser($u, {
			points 		=> '0',
			-lastgranted 	=> 'now()',
		});
	}

	$self->sqlTransactionFinish();
	$cursor->finish;

	return $revoked;
}

########################################################
# For moderatord and some utils
sub getLastUser {
	my($self) = @_;
	# Why users_info instead of users?	- Cliff
	# No reason, and I think the other was slower -Brian
	my $totalusers  = $self->sqlSelect("max(uid)", "users");

	return $totalusers;
}

########################################################
# For tailslash
sub pagesServed {
	my($self) = @_;
	my $returnable = $self->sqlSelectAll("count(*),ts",
			"accesslog", "1=1",
			"GROUP BY ts ORDER BY ts ASC");

	return $returnable;

}

########################################################
# For tailslash
sub maxAccessLog {
	my($self) = @_;
	my($returnable) = $self->sqlSelect("max(id)", "accesslog");;

	return $returnable;
}

########################################################
# For tailslash
sub getAccessLogInfo {
	my($self, $id) = @_;
	my $returnable = $self->sqlSelectAll("host_addr,uid,op,dat,ts,id",
				"accesslog", "id > $id",
				"ORDER BY ts DESC");
	formatDate($returnable, 4, 4, '%H:%M');
	return $returnable;
}

########################################################
# For run_moderatord.pl
# New as of 2002/09/05:  returns ordered first by hitcount, and
# second randomly, so when give_out_tokens() chops off the list
# halfway through the minimum number of clicks, the survivors
# are determined at random and not by (probably) uid order.
sub fetchEligibleModerators {
	my($self) = @_;
	my $constants = getCurrentStatic();
	my $hitcount = defined($constants->{m1_eligible_hitcount})
		? $constants->{m1_eligible_hitcount} : 3;
	my $eligible_users = $self->getLastUser()
		* ($constants->{m1_eligible_percentage} || 0.8);

	# Whether the var "authors_unlimited" is set or not, it doesn't
	# much matter whether we return admins in this list.

	my $returnable =
		$self->sqlSelectAll(
			"users_info.uid, COUNT(*) AS c",
			"users_info, users_prefs, accesslog",
			"users_info.uid < $eligible_users
			 AND users_info.uid=accesslog.uid
			 AND users_info.uid=users_prefs.uid
			 AND (op='article' OR op='comments')
			 AND willing=1
			 AND karma >= 0",
			"GROUP BY users_info.uid
			 HAVING c >= $hitcount
			 ORDER BY c, RAND()");

	return $returnable;
}

########################################################
# For run_moderatord.pl
sub updateTokens {
	my($self, $uidlist) = @_;
	my $constants = getCurrentStatic();
	my $maxtokens = $constants->{maxtokens} || 60;
	for my $uid (@$uidlist) {
		next unless $uid;
		$self->setUser($uid, {
			-tokens	=> "LEAST(tokens+1, $maxtokens)",
		});
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
		'*',
		'moderatorlog',
		'm2status=1',
		"ORDER BY id $limit",
	);

	return $mods_ar;
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
# For freshenup.pl,archive.pl
#
#
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
	my $writestatus_clause;
	my $displaystatus_clause;
	if ($purpose eq 'delete') {
		# We want everything that needs to be deleted.
		$writestatus_clause = " AND writestatus = 'delete'";
		$displaystatus_clause = "";
	} elsif ($purpose eq 'mainpage_dirty') {
		# We only want mainpage stories that are dirty.
		$writestatus_clause = " AND writestatus = 'dirty'";
		$displaystatus_clause = " AND displaystatus = 0";
	} elsif ($purpose eq 'all_dirty') {
		# We are updating stories that are dirty, don't
		# want ND'd stories, do want sectional as well as
		# mainpage stories.
		$writestatus_clause = " AND writestatus = 'dirty'";
		$displaystatus_clause = " AND displaystatus > -1";
	} else {
		# Invalid purpose.
		return [ ];
	}

	my $returnable = $self->sqlSelectAllHashrefArray(
		"sid, title, section, time, displaystatus",
		"stories", 
		"time < NOW()
		$writestatus_clause	$displaystatus_clause
		$order_clause		$limit_clause"
	);

	return $returnable;
}

########################################################
# For tasks/spamarmor.pl
#
# Please note use of closure. This is not an error.
#
#{
#my($usr_block_size, $usr_start_point);
#
#sub iterateUsers {
#	my($self, $blocksize, $start) = @_;
#
#	$start ||= 0;
#
#	($usr_block_size, $usr_start_point) = ($blocksize, $start)
#		if $blocksize && $blocksize != $usr_block_size;
#	$usr_start_point += $usr_block_size  + 1 if !$blocksize;
#
#	return $self->sqlSelectAllHashrefArray(
#		'*',
#		'users', '',
#		"ORDER BY uid LIMIT $usr_start_point,$usr_block_size"
#	);
#}
#}

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
	my $db_sid = $self->sqlQuote($sid);

	$self->sqlDo("DELETE FROM stories WHERE sid=$db_sid");
	$self->sqlDo("DELETE FROM story_text WHERE sid=$db_sid");
	my $discussion_id = $self->sqlSelect('id', 'discussions', "sid = $db_sid");
	$self->deleteDiscussion($discussion_id) if $discussion_id;
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
		"stories.sid = story_text.sid
		 AND stories.time >= DATE_SUB(NOW(), INTERVAL $n_days DAY)"
	);
	my $word_hr = { };
	for my $ar (@$arr) {
		findWords($ar->[0], 8  , $word_hr) if $ar->[0];	# title
		findWords($ar->[1], 1  , $word_hr) if $ar->[1];	# introtext
		findWords($ar->[2], 0.5, $word_hr) if $ar->[2];	# bodytext
	}
#use Data::Dumper; print STDERR Dumper($word_hr);

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
		keys %$word_hr;
#print STDERR "@uncommon_words\n";
	my $uncommon_words = substr(join(" ", @uncommon_words), 0, $maxlen);
	if (length($uncommon_words) == $maxlen) {
		$uncommon_words =~ s/\s+\S+\Z//;
	}

	$self->setVar("uncommonstorywords", $uncommon_words);
}

########################################################
# For tasks/flush_formkeys.pl
sub deleteOldFormkeys {
	my($self, $timeframe) = @_;
	$timeframe ||= 14400;
	my $nowtime = time();
	$self->sqlDo("DELETE FROM formkeys WHERE ts < ($nowtime - (2*".$timeframe."))");
}

########################################################
sub countAccesslogDaily {
	my($self) = @_;

	return $self->sqlSelect("count(*)", "accesslog",
		"to_days(now()) - to_days(ts)=1");
}

########################################################
# For portald

sub createRSS {
	my($self, $bid, $item) = @_;
	# this will go away once we require Digest::MD5 2.17 or greater
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
sub getSlashdStatus {
	my($self) = @_;
	my $answer = _genericGet('slashd_status', 'task', '', @_);
	$answer->{last_completed_hhmm} =
		substr($answer->{last_completed}, 11, 5)
		if defined($answer->{last_completed});
	$answer->{next_begin_hhmm} =
		substr($answer->{next_begin}, 11, 5)
		if defined($answer->{next_begin});
	return $answer;
}

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
#freshenup
sub getSectionsDirty {
	my($self) = @_;

	$self->sqlSelectColArrayref('section', 'sections', '(writestatus = "dirty") OR ((UNIX_TIMESTAMP(last_update) + rewrite) <  UNIX_TIMESTAMP(now()) )');
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

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
	$needed = $needed * 3 + 5;
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
	my $archive_delay_mod =
		   $constants->{archive_delay_mod}
		|| $constants->{archive_delay}
		|| 14;

	# Now for some random stuff
	$self->sqlDo("DELETE FROM pollvoters");
	$self->sqlDo("DELETE FROM moderatorlog
		WHERE TO_DAYS(NOW()) - TO_DAYS(ts) > $archive_delay_mod");
	$self->sqlDo("DELETE FROM metamodlog
		WHERE TO_DAYS(NOW()) - TO_DAYS(ts) > $archive_delay_mod");

	# Formkeys
	my $delete_time = time() - $constants->{'formkey_timeframe'};
	$self->sqlDo("DELETE FROM formkeys WHERE ts < $delete_time");

	unless ($constants->{noflush_empty_discussions}) {
		$self->sqlDo("DELETE FROM discussions
			WHERE type='recycle' AND commentcount=0");
	}
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
		return unless $uids_ar && @$uids_ar;
		my $uids_in = join(",", sort @$uids_ar);
		$self->sqlUpdate(
			"users_info",
			{ lastaccess => $yesterday },
			"uid IN ($uids_in) AND lastaccess < '$yesterday'"
		);
	}
}

########################################################
# For daily_archive.pl
sub decayTokens {
	my($self) = @_;
	my $constants = getCurrentStatic();
	my $days = $constants->{mod_token_decay_days} || 14;
	my $perday = int($constants->{mod_token_decay_perday} || 0);

	# If no decay wanted, nothing need be done.
	return if !$perday;

	# We know that the lastaccess field will be accurate, because
	# this method is called right after updateLastaccess().
	my $uids_ar = $self->sqlSelectColArrayref(
		"uid",
		"users_info",
		"lastaccess < DATE_SUB(NOW(), INTERVAL $days DAY)
		 AND tokens > 0"
	);
	my $uids_in = join(",", sort @$uids_ar);
	my $rows = $self->sqlUpdate(
		"users_info",
		{ -tokens => "GREATEST(0, tokens - $perday)" },
		"uid IN ($uids_in) AND tokens > 0"
	);
	my $decayed = $rows * $perday;
	return $decayed;
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
	my $defaultsection = getCurrentStatic('defaultsection');
	# Make more sense to make this a getDescriptions call -Brian
	my $sections = $self->sqlSelectAllHashrefArray(
		"section, url",
		"sections",
		"type='contained' AND section != '$defaultsection' ",
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
	$n_wanted = int($n_users/100) if $n_wanted > int($n_users)/100;

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
# For tailslash
sub pagesServed {
	my($self) = @_;
	my $returnable = $self->sqlSelectAll("count(*),ts",
			"accesslog", "to_days(now()) - to_days(ts) <= 1",
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

sub fetchEligibleModerators_accesslog {
	my($self) = @_;
	my $constants = getCurrentStatic();
	my $hitcount = defined($constants->{m1_eligible_hitcount})
		? $constants->{m1_eligible_hitcount} : 3;

	# Whether the var "authors_unlimited" is set or not, it doesn't
	# much matter whether we return admins in this list.

	return $self->sqlSelectAllHashref(
		"uid",
		"uid, COUNT(*) AS c",
		"accesslog USE INDEX (op_part)",
		"op='article' OR op='comments'",
		"GROUP BY uid
		 HAVING c >= $hitcount");
}

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
		# "prejudiced" against users with little or not mod history,
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
		my $count = int($factor);
		$count++ if rand() < $factor-$count;
		push @return_uids, ($uid) x $count;
	}

# Because this is a complicated method, here is some lengthy debugging
# output that doesn't appear to be necessary... this will be removed
# soon. - Jamie
#	print STDERR "factorEligibleModerators ran on " . scalar(@$orig_uids)
#		. " uids, producing a list of " . scalar(@return_uids)
#		. " uids, in "
#		. sprintf("%0.3f", Time::HiRes::time - $start_time)
#		. " seconds\n";
#	print STDERR "factorEligibleModerators orig start: '@$orig_uids[0..9]' now start: '@return_uids[0..9]'\n";
#	print STDERR "factorEligibleModerators orig   end: '@$orig_uids[-10..-1]' now   end: '@return_uids[-10..-1]'\n";
#	for my $uid (sort { $u_hr->{$a}{factor_m2total} <=> $u_hr->{$b}{factor_m2total} }
#		keys %$u_hr) {
#		print STDERR
#			sprintf("m2total %0.4f m2ratio %0.4f stirredratio %0.4f uid %6d m2fair %6d stirred %6d",
#				$u_hr->{$uid}{factor_m2total} || 1,
#				$u_hr->{$uid}{factor_m2ratio} || 1,
#				$u_hr->{$uid}{factor_stirredratio} || 1,
#				$uid,
#				$u_hr->{$uid}{m2fair},
#				$u_hr->{$uid}{stirred}
#			) . "\n";
#	}
#use Data::Dumper;
#	print STDERR "factorEligibleModerators u_hr: " . Dumper($u_hr);

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
		keys %$word_hr;
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
#freshenup
sub getSectionsDirty {
	my($self) = @_;

	$self->sqlSelectColArrayref('section', 'sections', '(writestatus = "dirty") OR ((UNIX_TIMESTAMP(last_update) + rewrite) <  UNIX_TIMESTAMP(now()) )');
}

########################################################
# Was once used in template-tool's check_site_templates()
# but is now deprecated. Left here in case another 
# application has need of it, but can be removed if
# necessary.   	- Cliff 2002-09-10
sub getAllTemplateIds {
	my($self, $min, $max) = @_;
	my $where;

	return if $min =~ /\D/ or $max =~ /\D/;

	$where = "tpid BETWEEN $min AND $max" if $min || $max;
	$self->sqlSelectColArrayref(
		'tpid', 'templates', $where, 'ORDER BY tpid'
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

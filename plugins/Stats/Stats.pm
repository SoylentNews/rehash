# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Stats;

=head1 NAME

Slash::Stats - Stats plugin for Slash

=cut

use strict;
use DBIx::Password;
use Slash;
use Slash::Utility;
use Slash::DB::Utility;
use LWP::UserAgent;

use vars qw($VERSION);
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# On a side note, I am not sure if I liked the way I named the methods either.
# -Brian
sub new {
	my($class, $user, $options) = @_;
	my $self = {};

	my $plugin = getCurrentStatic('plugin');
	return unless $plugin->{'Stats'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;

	# The default _day is yesterday.  (86400 seconds = 1 day)
	my @yest_lt = localtime(time - 86400);
	$self->{_day} = $options->{day}
		? $options->{day}
		: sprintf("%4d-%02d-%02d", $yest_lt[5] + 1900, $yest_lt[4] + 1, $yest_lt[3]);
	$self->{_day_between_clause} = " BETWEEN '$self->{_day} 00:00' AND '$self->{_day} 23:59:59' ";

	my $count = 0;
	if ($options->{create}) {

		# Why not just truncate? If we did we would never pick up schema changes -Brian
		# Create "accesslog_temp" and "accesslog_temp_errors" from the
		# schema of "accesslog".

		# First, drop them (if they exist).
		$self->sqlDo("DROP TABLE IF EXISTS accesslog_temp");
		$self->sqlDo("DROP TABLE IF EXISTS accesslog_temp_errors");

		# Then, get the schema in its CREATE TABLE statement format.
		my $sth = $self->{_dbh}->prepare("SHOW CREATE TABLE accesslog");
		$sth->execute();
		my $rows = $sth->fetchrow_arrayref;
		$self->{_table} = "accesslog_temp";
		my $create_sql = $rows->[1];

		# Now, munge the schema to do the two new tables, and execute it.
		$create_sql =~ s/accesslog/accesslog_temp/;
		$self->sqlDo($create_sql);
		$create_sql =~ s/accesslog_temp/accesslog_temp_errors/;
		$self->sqlDo($create_sql);

		# Add in the indexes we need.
		$self->sqlDo("ALTER TABLE accesslog_temp ADD INDEX uid(uid)");
		$self->sqlDo("ALTER TABLE accesslog_temp ADD INDEX section(section)");
		$self->sqlDo("ALTER TABLE accesslog_temp_errors ADD INDEX status(status)");

		# The status line =200 is temp till I can go through and fix more of this
		# to make use of if -Brian
		# Having put errors into the _errors table, this is fine the way it is,
		# now, right? -Jamie 2003/05/20
		my $sql = "INSERT INTO accesslog_temp SELECT * FROM accesslog WHERE ts $self->{_day_between_clause} AND status=200 FOR UPDATE";
		$self->sqlDo($sql);
		if(!($count = $self->sqlSelect("count(id)", "accesslog_temp"))) {
			for (1..4) {
				sleep 5;
				$self->sqlDo($sql);
				last if $self->sqlSelect("count(id)", "accesslog_temp");
			}
		}

		$sql = "INSERT INTO accesslog_temp_errors SELECT * FROM accesslog WHERE ts $self->{_day_between_clause} AND status != 200 FOR UPDATE";
		$self->sqlDo($sql);
		if(!($count = $self->sqlSelect("count(id)", "accesslog_temp_errors"))) {
			for (1..4) {
				sleep 5;
				$self->sqlDo($sql);
				last if $self->sqlSelect("count(id)", "accesslog_temp_errors");
			}
		}
	}

	return $self;
}


########################################################
sub getAccesslistCounts {
	my($self) = @_;
	my $hr = { };
	for my $key (qw( ban nopost nosubmit norss nopalm proxy trusted )) {
		$hr->{$key} = $self->sqlCount('accesslist',
			"now_$key = 'yes'") || 0;
	}
	$hr->{all} = $self->sqlCount('accesslist') || 0;
	return $hr;
}

########################################################
sub getPointsInPool {
	my($self) = @_;
	return $self->sqlSelect('SUM(points)', 'users_comments');
}

########################################################
sub getTokenConversionPoint {
	my($self) = @_;
	# We can't actually predict what the exact token value will be
	# where they get converted to mod points;  we'd have to predict
	# number of comments posted and run the same logic as
	# run_moderatord.pl to find that.  But we can make a good
	# educated guess that's probably off by a maximum of 1 token.
	my $limit = 100; # XXX need to determine this based off a stat, probably mod_tokens_lost_converted/(24*40)
	return +(@{$self->sqlSelectColArrayref(
		"tokens",
		"users_info",
		"tokens > 20", # sanity check, also appears in run_moderatord algorithm
		"ORDER BY tokens DESC LIMIT $limit"
	)})[-1];
}

########################################################
sub getTokensInPoolPos {
	my($self) = @_;
	return $self->sqlSelect('SUM(tokens)', 'users_info',
		'tokens > 0');
}

########################################################
sub getTokensInPoolNeg {
	my($self) = @_;
	return $self->sqlSelect('SUM(tokens)', 'users_info',
		'tokens < 0');
}

########################################################
sub getAdminsClearpass {
	my($self) = @_;
	return $self->sqlSelectAllHashref(
		"nickname",
		"nickname, value",
		"users, users_param",
		"users.uid = users_param.uid
			AND users.seclev > 1
			AND users_param.name='admin_clearpass'
			AND users_param.value",
		"LIMIT 999"
	);
}

########################################################
sub countModeratorLog {
	my($self, $options) = @_;

	my @clauses = ( );

	my $day = $self->{_day};
	$day = $options->{day} if $options->{day};
	push @clauses, "ts $self->{_day_between_clause}"
		if $options->{oneday_only};

	push @clauses, "active=1" if $options->{active_only};

	if ($options->{m2able_only}) {
		my $reasons = $self->getReasons();
		my @reasons_m2able = grep { $reasons->{$_}{m2able} } keys %$reasons;
		my $reasons_m2able = join(",", @reasons_m2able);
		push @clauses, "reason IN ($reasons_m2able)"
	}

	my $where = join(" AND ", @clauses) || "";
	my $count = $self->sqlCount("moderatorlog", $where);
	return $count;
}

########################################################
sub countMetamodLog {
	my($self, $options) = @_;

	my @clauses = ( );

	my $day = $self->{_day};
	$day = $options->{day} if $options->{day};
	push @clauses, "ts $self->{_day_between_clause}"
		if $options->{oneday_only};

	push @clauses, "active=1" if $options->{active_only};

	if ($options->{val}) {
		push @clauses, "val=" . $self->sqlQuote($options->{val});
	}

	my $where = join(" AND ", @clauses) || "";
	my $count = $self->sqlCount("metamodlog", $where);
	return $count;
}

########################################################
sub getOldestUnm2dMod {
	my($self) = @_;
	my $reasons = $self->getReasons();
	my @reasons_m2able = grep { $reasons->{$_}{m2able} } keys %$reasons;
	my $reasons_m2able = join(",", @reasons_m2able);
	my($oldest) = $self->sqlSelect(
		"UNIX_TIMESTAMP(MIN(ts))",
		"moderatorlog",
		"active=1 AND reason IN ($reasons_m2able) AND m2status=0"
	);
	return $oldest || 0;
}

########################################################
# Note, we have to use $slashdb here instead of $self.
sub getSlaveDBLagCount {
	my($self) = @_;
	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();
	my $bdu = $constants->{backup_db_user};
	# If there *is* no backup DB, it's not lagged.
	return 0 if !$bdu || $bdu eq getCurrentVirtualUser();

	my $backupdb = getObject('Slash::DB', $bdu);
	# If there is supposed to be a backup DB but we can't contact it,
	# return a large number that is sufficiently noticeable that it
	# should alert people that something is wrong.
	return 2**30 if !$backupdb;

	# Get the actual lag count.  Assume that each file is 2**30
	# (a billion) bytes (should this be a var?).  Yes, the same
	# data is called "File" vs. "Log_File", "Position" vs. "Pos",
	# depending on whether it's on the master or slave side.
	# And on the slave side, for MySQL 4.x, I *think* I want
	# Master_Log_File and Read_Master_Log_Pos but other possible
	# candidates are Relay_Master_Log_File and Exec_master_log_pos
	# respectively.
	my $master = ($slashdb->sqlShowMasterStatus())->[0];
	my $slave  = ($backupdb->sqlShowSlaveStatus())->[0];
	my $master_filename = $master->{File};
	my $slave_filename  = $slave ->{Log_File} || $slave->{Master_Log_File};
	my($master_file_num) = $master_filename =~ /\.(\d+)$/;
	my($slave_file_num)  = $slave_filename  =~ /\.(\d+)$/;
	my $master_pos = $master->{Position};
	my $slave_pos  = $slave->{Pos} || $slave->{Read_Master_Log_Pos};

	my $count = 2**30 * ($master_file_num - $slave_file_num)
		+ $master_pos - $slave_pos;
	$count = 0 if $count < 0;
	$count = 2**30 if $count > 2**30;
	return $count;
}

########################################################
sub getRepeatMods {
	my($self, $options) = @_;
	my $constants = getCurrentStatic();
	my $ac_uid = $constants->{anonymous_coward_uid};

	my $within = $options->{within_hours} || 96;
	my $limit = $options->{limit} || 50;
	my $min_count = $options->{min_count}
		|| $constants->{mod_stats_min_repeat}
		|| 2;

	my $hr = $self->sqlSelectAllHashref(
		[qw( val orguid destuid )],
		"usersorg.uid AS orguid,
		 usersorg.nickname AS orgnick,
		 COUNT(*) AS c, val,
		 MAX(ts) AS latest,
		 IF(MAX(ts) > DATE_SUB(NOW(), INTERVAL 24 HOUR),
			1, 0) AS isrecent,
		 usersdest.uid AS destuid,
		 usersdest.nickname AS destnick,
		 usersdesti.karma AS destkarma",
		"users AS usersorg,
		 moderatorlog,
		 users AS usersdest,
		 users_info AS usersdesti",
		"usersorg.uid=moderatorlog.uid
		 AND usersorg.seclev < 100
		 AND moderatorlog.cuid=usersdest.uid
		 AND usersdest.uid=usersdesti.uid
		 AND usersdest.uid != $ac_uid",
		"GROUP BY usersorg.uid, usersdest.uid, val
		 HAVING c >= $min_count
			AND latest >= DATE_SUB(NOW(), INTERVAL $within HOUR)
		 ORDER BY c DESC, orguid
		 LIMIT $limit"
	);
	return $hr;
}

########################################################
sub getModM2Ratios {
	my($self, $options) = @_;

	my $reasons = $self->getReasons();
	my @reasons_m2able = grep { $reasons->{$_}{m2able} } keys %$reasons;
	my $reasons_m2able = join(",", @reasons_m2able);
	my $hr = $self->sqlSelectAllHashref(
		[qw( day val )],
		"SUBSTRING(ts, 1, 10) AS day,
		 IF(m2status=0,
			IF(reason IN ($reasons_m2able), m2count, '_'),
			'X'
		 ) AS val,
		 COUNT(*) AS c",
		"moderatorlog",
		"active=1",
		"GROUP BY day, val"
	);

	return $hr;
}

########################################################
sub getReverseMods {
	my($self, $options) = @_;

	# Double-check that options are numeric because we're going to
	# drop them directly into the SQL.
	for my $key (keys %$options) {
		$options->{$key} =~ s/[^\d.-]+//g;
	}

	my $down5 =     0.5;	$down5 = $options->{down5} if defined $options->{down5};
	my $upmax =     0  ;	$upmax = $options->{upmax} if defined $options->{upmax};
	my $upsub =     3  ;	$upsub = $options->{upsub} if defined $options->{upsub};
	my $upmul =     2  ;	$upmul = $options->{upmul} if defined $options->{upmul};
	my $unm2able =  0.5;	$unm2able = $options->{unm2able} if defined $options->{unm2able};
	my $denomadd =  4  ;	$denomadd = $options->{denomadd} if defined $options->{denomadd};
	my $limit =    12  ;	$limit = $options->{limit} if defined $options->{limit};
	my $min_tokens = -100; # fudge factor: only users who are likely to mod soon

	my $reasons = $self->getReasons();
	my @reasons_m2able = grep { $reasons->{$_}{m2able} } keys %$reasons;
	my $reasons_m2able = join(",", @reasons_m2able);
	my $ar = $self->sqlSelectAllHashrefArray(
		"moderatorlog.uid AS muid,
		 nickname, tokens, karma,
		 ( SUM( IF( moderatorlog.val=-1,
				IF(points=5, $down5, 0),
				IF(points<=$upmax, $upsub-points*$upmul, 0) ) )
		  +SUM( IF( moderatorlog.reason IN ($reasons_m2able), 0, $unm2able ) )
		 )/(COUNT(*)+$denomadd) AS score,
		 IF(MAX(moderatorlog.ts) > DATE_SUB(NOW(), INTERVAL 24 HOUR),
			1, 0) AS isrecent",
		"moderatorlog, comments, users, users_info",
		"comments.cid=moderatorlog.cid
		 AND users.uid=moderatorlog.uid
		 AND users_info.uid=moderatorlog.uid
		 AND moderatorlog.active
		 AND tokens >= $min_tokens",
		"GROUP BY muid ORDER BY score DESC, karma, tokens, muid LIMIT $limit",
	);
	for my $rm (@$ar) {
		$rm->{score} = sprintf("%0.3f", $rm->{score});
	}

	return $ar;
}
########################################################
sub countErrorStatuses {
	my($self, $options) = @_;

	my $where = " status BETWEEN 500 AND 600 ";

	$self->sqlSelect("count(id)", "accesslog_temp_errors", $where);
}

########################################################
sub countByStatus {
	my($self, $status, $options) = @_;

	my $where = " status = $status  ";

	$self->sqlSelect("count(id)", "accesslog_temp_errors", $where);
}

########################################################
sub getErrorStatuses {
	my($self, $op, $options) = @_;

	my $where = "1=1 ";
	$where .= " AND op='$op' "
		if $op;
	$where .= " AND section='$options->{section}' "
		if $options->{section};
	$where .= " AND status BETWEEN 500 AND 600 ";

	$self->sqlSelectAllHashrefArray("status, count(op) as count, op", "accesslog_temp_errors", $where, " GROUP BY status ORDER BY status ");
}

########################################################
sub getCommentsByDistinctIPID {
	my($self, $options) = @_;

	my $where = "date $self->{_day_between_clause}";
	$where .= " AND discussions.id = comments.sid
		    AND discussions.section = '$options->{section}'"
		if $options->{section};

	my $tables = 'comments';
	$tables .= ", discussions" if $options->{section};

	my $used = $self->sqlSelectColArrayref(
		'ipid',
		$tables, 
		$where,
		'',
		{ distinct => 1 }
	);
}

########################################################
sub countCommentsByDistinctIPIDPerAnon {
	my($self, $options) = @_;
	my $constants = getCurrentStatic();

	my $where = "date $self->{_day_between_clause}";
	$where .= " AND discussions.id = comments.sid
		    AND discussions.section = '$options->{section}'"
		if $options->{section};

	my $tables = 'comments';
	$tables .= ", discussions" if $options->{section};

	my $ipid_uid_hr = $self->sqlSelectAllHashref(
		[qw( ipid uid )],
		"ipid, comments.uid AS uid",
		$tables, 
		$where,
		"GROUP BY ipid, uid"
	);
	return (0, 0, 0) unless $ipid_uid_hr && scalar keys %$ipid_uid_hr;

	my($anon_only, $loggedin_only, $both) = (0, 0, 0);
	my $ac_uid = $constants->{anonymous_coward_uid};
	for my $ipid (keys %$ipid_uid_hr) {
		my @uids = keys %{$ipid_uid_hr->{$ipid}};
		if ($ipid_uid_hr->{$ipid}{$ac_uid}) {
			# At least one post by AC.
			if (scalar(@uids) > 1) {
				++$both;
			} else {
				++$anon_only;
			}
		} else {
			++$loggedin_only;
		}
	}
	return ($anon_only, $loggedin_only, $both);
}

########################################################
sub countCommentsByDiscussionType {
	my($self) = @_;
	my $constants = getCurrentStatic();

	my $return_hr = { };

	# First count comments posted to polls.
	if ($constants->{plugin}{PollBooth}) {
		$return_hr->{polls} = $self->sqlSelect(
			"COUNT(*), IF(pollquestions.discussion IS NULL, 'no', 'yes') AS ispoll",
			"comments, discussions
				LEFT JOIN pollquestions ON discussions.id=pollquestions.discussion",
			"comments.date $self->{_day_between_clause}
				AND comments.sid=discussions.id",
			"GROUP BY ispoll HAVING ispoll='yes'"
		) || 0;
	} else {
		$return_hr->{polls} = 0;
	}

	# Now comments posted to journals.
	if ($constants->{plugin}{Journal}) {
		$return_hr->{journals} = $self->sqlSelect(
			"COUNT(*), IF(journals.discussion IS NULL, 'no', 'yes') AS isjournal",
			"comments, discussions
				LEFT JOIN journals ON discussions.id=journals.discussion",
			"comments.date $self->{_day_between_clause}
				AND comments.sid=discussions.id",
			"GROUP BY isjournal HAVING isjournal='yes'"
		) || 0;
	} else {
		$return_hr->{journals} = 0;
	}

	# Don't forget comments posted to stories.
	$return_hr->{stories} = $self->sqlSelect(
		"COUNT(*), IF(stories.discussion IS NULL, 'no', 'yes') AS isstory",
		"comments, discussions
			LEFT JOIN stories ON discussions.id=stories.discussion",
		"comments.date $self->{_day_between_clause}
			AND comments.sid=discussions.id",
		"GROUP BY isstory HAVING isstory='yes'"
	) || 0;

	# Whatever's left must be user-created discussions.
	my $total = $self->sqlCount("comments", "date $self->{_day_between_clause}");
	$return_hr->{user} = $total -
		( $return_hr->{polls} + $return_hr->{journals} + $return_hr->{stories} );

	return $return_hr;
}

########################################################
sub getCommentsByDistinctUIDPosters {
	my($self, $options) = @_;

	my $section_where = "";
	$section_where = " AND discussions.id = comments.sid
			   AND discussions.section = '$options->{section}'"
		if $options->{section};

	my $tables = 'comments';
	$tables .= ", discussions" if $options->{section};

	my $used = $self->sqlSelect(
		"COUNT(DISTINCT uid)", $tables, 
		"date $self->{_day_between_clause}
		$section_where",
		'',
		{ }
	);
}

########################################################
sub getAdminModsInfo {
	my($self) = @_;

	# First get the count of upmods and downmods performed by each admin.
	my $m1_uid_val_hr = $self->sqlSelectAllHashref(
		[qw( uid val )],
		"moderatorlog.uid AS uid, val, nickname, COUNT(*) AS count",
		"moderatorlog, users",
		"users.seclev > 1 AND moderatorlog.uid=users.uid 
		 AND ts $self->{_day_between_clause}",
		"GROUP BY moderatorlog.uid, val"
	);

	# Now get a count of fair/unfair counts for each admin.
	my $m2_uid_val_hr = $self->sqlSelectAllHashref(
		[qw( uid val )],
		"users.uid AS uid, metamodlog.val AS val, users.nickname AS nickname, COUNT(*) AS count",
		"metamodlog, moderatorlog, users",
		"users.seclev > 1 AND moderatorlog.uid=users.uid
		 AND metamodlog.mmid=moderatorlog.id 
		 AND metamodlog.ts $self->{_day_between_clause} ",
		"GROUP BY users.uid, metamodlog.val"
	);

	# If nothing for either, no data to return.
	return { } if !%$m1_uid_val_hr && !%$m2_uid_val_hr;

	# Get the history of moderation fairness for all admins from the
	# last month.  This reads the last 30 days worth of stats_daily
	# data (not counting today, which will be added to that table
	# shortly).  Set up both the {count} and {nickname} fields for
	# each combination of uid and 1/-1 fairness.
	my $m2_history_mo_hr = $self->sqlSelectAllHashref(
		"name",
		"name, SUM(value) AS count",
		"stats_daily",
		"name LIKE 'm%fair_%' AND day > DATE_SUB(NOW(), INTERVAL 732 HOUR)",
		"GROUP BY name"
	);
	my $m2_uid_val_mo_hr = { };
	for my $name (keys %$m2_history_mo_hr) {
		my($fairness, $uid) = $name =~ /^m2_((?:un)?fair)_admin_(\d+)$/;
		next unless defined($fairness);
		$fairness = ($fairness eq 'unfair') ? -1 : 1;
		$m2_uid_val_mo_hr->{$uid}{$fairness}{count} =
			$m2_history_mo_hr->{$name}{count};
	}
	if (%$m2_uid_val_mo_hr) {
		my $m2_uid_nickname = $self->sqlSelectAllHashref(
			"uid",
			"uid, nickname",
			"users",
			"uid IN (" . join(",", keys %$m2_uid_val_mo_hr) . ")"
		);
		for my $uid (keys %$m2_uid_nickname) {
			for my $fairness (qw( -1 1 )) {
				$m2_uid_val_mo_hr->{$uid}{$fairness}{nickname} =
					$m2_uid_nickname->{$uid}{nickname};
				$m2_uid_val_mo_hr->{$uid}{$fairness}{count} +=
					$m2_uid_val_hr->{$uid}{$fairness}{count};
			}
		}
	}

	# For comparison, get the same stats for all users on the site and
	# add them in as a phony admin user that sorts itself alphabetically
	# last.  Hack, hack.
	my($total_nick, $total_uid) = ("~Day Total", 0);
	my $m1_val_hr = $self->sqlSelectAllHashref(
		"val",
		"val, COUNT(*) AS count",
		"moderatorlog",
		"ts $self->{_day_between_clause}",
		"GROUP BY val"
	);
	$m1_uid_val_hr->{$total_uid} = {
		uid =>	$total_uid,
		  1 =>	{ nickname => $total_nick, count => $m1_val_hr-> {1}{count} },
		 -1 =>	{ nickname => $total_nick, count => $m1_val_hr->{-1}{count} },
	};
	my $m2_val_hr = $self->sqlSelectAllHashref(
		"val",
		"val, COUNT(*) AS count",
		"metamodlog",
		"ts $self->{_day_between_clause}",
		"GROUP BY val"
	);
	$m2_uid_val_hr->{$total_uid} = {
		uid =>	$total_uid,
		  1 =>	{ nickname => $total_nick, count => $m2_val_hr-> {1}{count} },
		 -1 =>	{ nickname => $total_nick, count => $m2_val_hr->{-1}{count} },
	};

	# Build a hashref with one key for each admin user, and subkeys
	# that give data we will want for stats.
	my($nup, $ndown, $nfair, $nunfair, $percent);
	my @m1_keys = sort keys %$m1_uid_val_hr;
	my @m2_keys = sort keys %$m2_uid_val_hr;
	my %all_keys = map { $_ => 1 } @m1_keys, @m2_keys;
	my @all_keys = sort keys %all_keys;
	my $hr = { };
	for my $uid (@m1_keys) {
		my $nickname = $m1_uid_val_hr->{$uid} {1}{nickname}
			|| $m1_uid_val_hr->{$uid}{-1}{nickname}
			|| "";
		next unless $nickname;
		$nup   = $m1_uid_val_hr->{$uid} {1}{count} || 0;
		$ndown = $m1_uid_val_hr->{$uid}{-1}{count} || 0;
		$percent = ($nup+$ndown > 0)
			? $nup*100/($nup+$ndown)
			: 0;
		# Add the m1 data for this admin.
		$hr->{$nickname}{uid} = $uid;
		$hr->{$nickname}{m1_up} = $nup;
		$hr->{$nickname}{m1_down} = $ndown;
		# If this admin had m1 activity today but no m2 activity,
		# blank out that field.
		if (!exists($m2_uid_val_hr->{$uid})) {
			# $hr->{$nickname}{m2_fair} = 0;
			# $hr->{$nickname}{m2_unfair} = 0;
		}
	}
	for my $uid (@all_keys) {
		my $nickname =
			   $m2_uid_val_hr->{$uid} {1}{nickname}
			|| $m2_uid_val_hr->{$uid}{-1}{nickname}
			|| $m2_uid_val_mo_hr->{$uid} {1}{nickname}
			|| $m2_uid_val_mo_hr->{$uid}{-1}{nickname}
			|| "";
		next unless $nickname;
		$nfair   = $m2_uid_val_hr->{$uid} {1}{count} || 0;
		$nunfair = $m2_uid_val_hr->{$uid}{-1}{count} || 0;
		$percent = ($nfair+$nunfair > 0)
			? $nunfair*100/($nfair+$nunfair)
			: 0;
		# Add the m2 data for this admin.
		$hr->{$nickname}{uid} = $uid;
		# Also calculate overall-month percentage.
		my $nfair_mo   = $m2_uid_val_mo_hr->{$uid} {1}{count} || 0;
		my $nunfair_mo = $m2_uid_val_mo_hr->{$uid}{-1}{count} || 0;
		$percent = ($nfair_mo+$nunfair_mo > 0)
			? $nunfair_mo*100/($nfair_mo+$nunfair_mo)
			: 0;
		# Set another few data points.
		$hr->{$nickname}{m2_fair} = $nfair;
		$hr->{$nickname}{m2_unfair} = $nunfair;
		$hr->{$nickname}{m2_fair_mo} = $nfair_mo;
		$hr->{$nickname}{m2_unfair_mo} = $nunfair_mo;
		# If this admin had m2 activity today but no m1 activity,
		# blank out that field.
		if (!exists($m1_uid_val_hr->{$uid})) {
			# Not really necessary
			# $hr->{$nickname}{m1_up} = 0;
			# $hr->{$nickname}{m1_down} = 0;
		}
	}

	return $hr;
}

########################################################
sub countSubmissionsByDay {
	my($self, $options) = @_;

	my $where = "time $self->{_day_between_clause}";
	$where .= " AND section = '$options->{section}'" if $options->{section};

	my $used = $self->sqlCount(
		'submissions', 
		$where
	);
	return $used;
}

########################################################
sub countSubmissionsByCommentIPID {
	my($self, $ipids, $options) = @_;
	return unless @$ipids;
	my $slashdb = getCurrentDB();
	my $in_list = join(",", map { $slashdb->sqlQuote($_) } @$ipids);

	my $where = "time $self->{_day_between_clause}
		AND ipid IN ($in_list)";
	$where .= " AND section = '$options->{section}'" if $options->{section};

	my $used = $self->sqlCount(
		'submissions', 
		$where
	);
	return $used;
}

########################################################
sub countModeratorLogByVal {
	my($self) = @_;

	my $modlog_hr = $self->sqlSelectAllHashref(
		"val",
		"val, SUM(spent) AS spent, COUNT(*) AS count",
		"moderatorlog",
		"ts $self->{_day_between_clause}",
		"GROUP BY val"
	);
	
	return $modlog_hr;
}

########################################################
sub countCommentsDaily {
	my($self, $options) = @_;

	my $tables = 'comments';
	$tables .= ", submissions" if $options->{section};

	my $section_where = "";
	$section_where = " AND discussions.id = comments.sid
			   AND discussions.section = '$options->{section}'"
		if $options->{section};
	
	# Count comments posted yesterday... using a primary key,
	# if it'll save us a table scan.  On Slashdot this cuts the
	# query time from about 12 seconds to about 0.8 seconds.
	my $cid_limit_clause = "";
	my $max_cid = $self->sqlSelect("MAX(comments.cid)", $tables);
	if ($max_cid > 300_000) {
		# No site can get more than 100K comments a day in
		# all its sections combined.  It is decided.  :)
		$cid_limit_clause = " AND cid > " . ($max_cid-100_000);
	}

	my $comments = $self->sqlSelect(
		"COUNT(*)",
		"comments",
		"date $self->{_day_between_clause}
		 $cid_limit_clause $section_where"
	);

	return $comments; 
}

########################################################
sub countBytesByPage {
	my($self, $op, $options) = @_;

	my $where = "1=1 ";
	$where .= " AND op='$op'"
		if $op;
	$where .= " AND section='$options->{section}'"
		if $options->{section};

	# The "no_op" option can take either a scalar for one op to exclude,
	# or an arrayref of multiple ops to exclude.
	my $no_op = $options->{no_op} || [ ];
	$no_op = [ $no_op ] if $options->{no_op} && !ref($no_op);
	if (@$no_op) {
		my $op_not_in = join(",", map { $self->sqlQuote($_) } @$no_op);
		$where .= " AND op NOT IN ($op_not_in)";
	}

	$self->sqlSelect("SUM(bytes)", "accesslog_temp", $where);
}

########################################################
sub countUsersByPage {
	my($self, $op, $options) = @_;
	my $where = "1=1 ";
	$where .= "AND op='$op' "
		if $op;
	$where .= " AND section='$options->{section}' "
		if $options->{section};
	$where = "($where) AND $options->{extra_where_clause}"
		if $options->{extra_where_clause};
	$self->sqlSelect("COUNT(DISTINCT uid)", "accesslog_temp", $where);
}

########################################################
sub countDailyByPage {
	my($self, $op, $options) = @_;
	$options ||= {};

	my $where = "1=1 ";
	$where .= " AND op='$op'"
		if $op;
	$where .= " AND section='$options->{section}'"
		if $options->{section};
	$where .= " AND static='$options->{static}'"
		if $options->{static};

	# The "no_op" option can take either a scalar for one op to exclude,
	# or an arrayref of multiple ops to exclude.
	my $no_op = $options->{no_op} || [ ];
	$no_op = [ $no_op ] if $options->{no_op} && !ref($no_op);
	if (@$no_op) {
		my $op_not_in = join(",", map { $self->sqlQuote($_) } @$no_op);
		$where .= " AND op NOT IN ($op_not_in)";
	}

	$self->sqlSelect("count(*)", "accesslog_temp", $where);
}

########################################################
sub countDailyByPageDistinctIPID {
	# This is so lame, and so not ANSI SQL -Brian
	my($self, $op, $options) = @_;
	my $where = "1=1 ";
	$where .= "AND op='$op' "
		if $op;
	$where .= " AND section='$options->{section}' "
		if $options->{section};
	$self->sqlSelect("COUNT(DISTINCT host_addr)", "accesslog_temp", $where);
}

########################################################
sub countDailyStoriesAccess {
	my($self) = @_;
	my $c = $self->sqlSelectMany("dat, COUNT(*), op", "accesslog_temp",
		"op='article'",
		"GROUP BY dat");

	my %articles; 
	while (my($sid, $cnt) = $c->fetchrow) {
		$articles{$sid} = $cnt;
	}
	$c->finish;
	return \%articles;
}

########################################################
sub countDailySecure {
	my($self) = @_;
	return $self->sqlCount("accesslog_temp", "secure=1");
}

########################################################
sub getRecentSubscribers {
	my($self) = @_;
	my $constants = getCurrentStatic();
	return 0 unless $constants->{subscribe};
	my $subscribers_all = $self->sqlSelectColArrayref(
		"uid",
		"users_hits",
		"hits_paidfor > hits_bought
		 AND lastclick >= DATE_SUB(NOW(), INTERVAL 48 HOUR)",
	);
	return [ ] unless $subscribers_all && @$subscribers_all;
	my $uid_list = join(", ", @$subscribers_all);
	my $subscribers = $self->sqlSelectColArrayref(
		"uid",
		"users",
		"uid in ($uid_list) AND seclev < 100");

	return $subscribers;
}

########################################################
sub countDailySubscribers {
	my($self, $subscribers) = @_;
	return 0 unless $subscribers && @$subscribers;
	my $uid_list = join(", ", @$subscribers);
	my $count = $self->sqlCount("accesslog_temp", "uid IN ($uid_list)");
	return $count;
}

########################################################
sub getStatToday {
	my($self, $name) = @_;
	my $name_q = $self->sqlQuote($name);
	return $self->sqlSelect("value + 0", "stats_daily",
		"name = $name_q AND day = '$self->{_day}'");
}

########################################################
sub getStatLastNDays {
	my($self, $name, $days) = @_;
	my $name_q = $self->sqlQuote($name);
	return $self->sqlSelect("AVG(value) + 0", "stats_daily",
		"name = $name_q
		 AND day BETWEEN DATE_SUB('$self->{_day}', INTERVAL $days DAY) AND '$self->{_day}'");
}

########################################################
sub getDurationByStaticOpHour {
	my($self, $options) = @_;

	my @ops = qw( index article comments metamod users rss );
	@ops = @{$options->{ops}} if $options->{ops} && @{$options->{ops}};
	my $ops = join(", ", map { $self->sqlQuote($_) } @ops);

	# First get the stats that are easy, the AVG() and STDDEV()
	# which the DB feeds to us.
	my $hr = $self->sqlSelectAllHashref(
		[qw( static op hour )],
		"static, op, HOUR(ts) AS hour,
		 COUNT(*) AS c,
		 AVG(duration) AS dur_mean, STDDEV(duration) AS dur_stddev",
		"accesslog_temp",
		"op IN ($ops)",
		"GROUP BY static, op, hour"
	);

	# Now we need the stats that are hard, the various percentiles
	# in the duration list for each static/localaddr key
	# (including the median, which is just the 50th %ile).

	# Pick a duration precision.  The more precise, the more data
	# to chew through.  I think 10 ms should be good enough and yet
	# not run us out of memory processing even Slashdot's log.
	my $precision = 0.010;

	my $ile_hr = $self->sqlSelectAllHashref(
		[qw( static op hour dur_round )],
		"static, op, HOUR(ts) AS hour,
		 ROUND(duration/$precision)*$precision AS dur_round,
		 COUNT(*) AS c",
		"accesslog_temp",
		"op IN ($ops)",
		"GROUP BY static, op, hour, dur_round"
	);

	_calc_percentiles($hr, $ile_hr);

	return $hr;
}

########################################################
sub getDurationByStaticLocaladdr {
	my($self) = @_;

	# First get the stats that are easy, the AVG() and STDDEV()
	# which the DB feeds to us.
	my $hr = $self->sqlSelectAllHashref(
		[qw( static local_addr )],
		"static, local_addr,
		 COUNT(*) AS c,
		 AVG(duration) AS dur_mean, STDDEV(duration) AS dur_stddev",
		"accesslog_temp",
		"",
		"GROUP BY static, local_addr"
	);

	# Now we need the stats that are hard, the various percentiles
	# in the duration list for each static/localaddr key
	# (including the median, which is just the 50th %ile).

	# Pick a duration precision.  The more precise, the more data
	# to chew through.  I think 10 ms should be good enough and yet
	# not run us out of memory processing even Slashdot's log.
	my $precision = 0.010;

	my $ile_hr = $self->sqlSelectAllHashref(
		[qw( static local_addr dur_round )],
		"static, local_addr,
		 ROUND(duration/$precision)*$precision AS dur_round,
		 COUNT(*) AS c",
		"accesslog_temp",
		"",
		"GROUP BY static, local_addr, dur_round"
	);

#use Data::Dumper; print Dumper $ile_hr;

	_calc_percentiles($hr, $ile_hr);

	return $hr;
}

sub _walk_keys {
	my($hr) = @_;
	my @hr_keys = keys %$hr;
	if (!exists $hr->{$hr_keys[0]}{dur_round}) {
		# We need to recurse down at least one more
		# level.  Keep track of where we are.
		my @results = ( );
		for my $key (sort @hr_keys) {
			my @sub_results = _walk_keys($hr->{$key});
			for my $sub_r (@sub_results) {
				unshift @$sub_r, $key;
			}
			push @results, @sub_results;
		}
		return @results;
	} else {
		# This hashref's keys hold the data we want.
		# We don't want to return that data.
		return [ ];
	}
}

sub _calc_percentiles {
	my($main_hr, $ile_hr, $percentiles) = @_;

	# List of percentiles we want.  The expensive part is doing this
	# at all, so we might as well grab more than just the median!
	$percentiles = [qw( 10 50 90 95 99 )]
		if !$percentiles || !@$percentiles;

	# Go through a somewhat convoluted process to walk the keys of the
	# hashrefs, given that we have a scalar numeric that tells us how
	# deep those keys go.  Essentially we're doing an any-depth version
	# of "for $i {for $j {for $k ... } }".
	my @keysets = _walk_keys($ile_hr);
	while (my $keyset = shift @keysets) {

		# Each keyset is an arrayref that lists the keys needed
		# to walk down into $main_hr and $ile_hr to get to a
		# set of data that we want.  Use it to walk the hashrefs
		# $main_hr_entry and $ile_hr_entry down to that data.

		my $main_hr_entry = $main_hr;
		my $ile_hr_entry = $ile_hr;
		for my $key (@$keyset) {
			$main_hr_entry = $main_hr_entry->{$key};
			$ile_hr_entry = $ile_hr_entry->{$key};
		}

#print "main_hr_entry for keyset '@$keyset': " . Dumper($main_hr_entry);
#print "ile_hr_entry for keyset '@$keyset': " . Dumper($ile_hr_entry);

		my $cur_count = 0;
		my $total_count = $main_hr_entry->{c};
		next unless $total_count; # sanity check
		my $cur_duration = 0;
		# Get the list of all the rounded durations that we
		# had returned (for this value of static/localaddr).
		my @rounds = sort { $a <=> $b } keys %$ile_hr_entry;
		# Start counting with the current percentile at 0.
		# For each one that we need, walk up through the
		# list of rounded durations totalling up how many
		# hits took that long (or faster).  If the percentage
		# of hits out of total hits (for this value of
		# static/localaddr) equals or exceeds the percentile
		# that is needed, this duration corresponds to that
		# percentile.  Store it in the main hashref (not
		# ile_hr, it will be thrown away) with a key of
		# "ile_50" for the median, "ile_95" for the
		# 95th percentile, etc.
		my $cur_ile = 0;
		for my $ile_needed (@$percentiles) {
			my $ile_frac = $ile_needed/100;
			# Note, if we wanted to get really fancy in
			# this next while loop, we could also do
			# interpolation between this $cur_ile and
			# the next $cur_ile, effectively almost
			# doubling $precision.  I don't think it's
			# necessary;  our sample sets should be
			# plenty large enough and RAM is cheap.
			while ($cur_ile <= $ile_frac && @rounds) {
				$cur_duration = shift @rounds;
				$cur_count += $ile_hr_entry->{$cur_duration}{c};
				$cur_ile = $cur_count / $total_count;
			}
			my $ile_key = sprintf("dur_ile_%02d", $ile_needed);
			$main_hr_entry->{$ile_key} = $cur_duration;
		}
	}
}

########################################################
sub getDailyScoreTotal {
	my($self, $score) = @_;

	return $self->sqlCount('comments',
		"points=$score AND date $self->{_day_between_clause}");
}

########################################################
# Note, we are carrying the misspelling of "referrer" over from
# the HTTP spec.
sub getTopReferers {
	my($self, $options) = @_;

	my $count = $options->{count} || 10;
	my $where;
	if ($options->{include_local}) {
		$where = "";
	} else {
		my $constants = getCurrentStatic();
		$where = " AND referer NOT REGEXP '$constants->{basedomain}'";
	}

	return $self->sqlSelectAll(
		"distinct SUBSTRING_INDEX(referer,'/',3) as referer, COUNT(id) AS c",
		"accesslog_temp",
		"referer IS NOT NULL AND LENGTH(referer) > 0 AND referer REGEXP '^http' $where ",
		"GROUP BY referer ORDER BY c DESC, referer LIMIT $count"
	);
}

########################################################
sub countSfNetIssues {
	my($self, $group_id) = @_;
	my $constants = getCurrentStatic();
	my $url = "http://sf.net/export/projhtml.php?group_id=$group_id&mode=full&no_table=1";
	my $ua = new LWP::UserAgent;
	my $request = new HTTP::Request('GET', $url);
        $ua->proxy(http => $constants->{http_proxy}) if $constants->{http_proxy};
        $ua->timeout(30);
        my $result = $ua->request($request);
	my $content = $result->is_success ? $result->content : "";
	if (!$content) {
		return { };
	}
	my $hr = { };
	while ($content =~ m{
		>
		([\w\s]+)
		</A>
		\s*
		\( \s* <B>
		(\d+) \s+ open \s* / \s* (\d+) \s* total
		</B> \s* \)
	}gx) {
		my($tracker, $open, $total) = ($1, $2, $3);
		$hr->{$tracker}{open} = $open;
		$hr->{$tracker}{total} = $total;
	}
	return $hr;
}

########################################################
sub setGraph {
	my($self, $data) = @_;

	return unless $data->{id} && $data->{day} && $data->{image};
	$data->{content_type} ||= 'image/png';

	# check to see if we have a duplicate, just in case
	$data->{want_md5} = 1;
	my $md5 = $self->getGraph($data);
	return $md5 if $md5;

	my $blob = getObject('Slash::Blob');
	$md5 = $blob->create({
		data		=> $data->{image},
		content_type	=> $data->{content_type},
		# see stats.pl:main()
		seclev		=> getCurrentStatic('stats_admin_seclev') || 100
	});

	$self->sqlInsert('stats_graphs_index', {
		day	=> $data->{day},
		id	=> $data->{id},
		md5	=> $md5
	});

	return $md5;
}

########################################################
sub getGraph {
	my($self, $data) = @_;

	return unless $data->{id} && $data->{day};

	my $id  = $self->sqlQuote($data->{id});
	my $day = $self->sqlQuote($data->{day});

	my $md5 = $self->sqlSelect('md5', 'stats_graphs_index',
		"id=$id AND day=$day");

	return $md5 if $data->{want_md5};

	my $blob = getObject('Slash::Blob');
	my $image = $blob->get($md5);

	return $image || {};
}

########################################################
sub deleteGraph {
	my($self, $data) = @_;

	return unless $data->{id} && $data->{day};

	my $id  = $self->sqlQuote($data->{id});
	my $day = $self->sqlQuote($data->{day});

	my $md5 = $self->sqlSelect('md5', 'stats_graphs_index',
		"id=$id AND day=$day");

	$self->sqlDelete('stats_graphs_index', "id=$id AND day=$day");

	if ($md5) {
		my $blob = getObject('Slash::Blob');
		$blob->delete($md5);
	}
}

########################################################
sub cleanGraphs {
	my($self, $data) = @_;

	# default 7 days, should be var?  don't care, myself -- pudge
	$data->{days} ||= 7;

	my @time = localtime(time() - (86400 * $data->{days}));
	my $oldday = $self->sqlQuote(sprintf "%4d-%02d-%02d", 
		$time[5] + 1900, $time[4] + 1, $time[3]
	);

	my $images = $self->sqlSelectAll(
		"day, id",
		"stats_graphs_index",
		"day < $oldday"
	);

	my $count = 0;
	for my $image (@$images) {
		$count += 1 if $self->deleteGraph({
			day	=> $image->[0],
			id	=> $image->[1],
		});
	}
	return $count;
}


########################################################
sub getAllStats {
	my($self, $options) = @_;
	my $table = 'stats_daily';
	my $sel   = 'name, value+0 as value, section, day';
	my $extra = 'ORDER BY section, day, name';
	my @where;

	if ($options->{section}) {
		push @where, 'section = ' . $self->sqlQuote($options->{section});
	}

	if ($options->{name}) {
		push @where, 'name = ' . $self->sqlQuote($options->{name});
	}

	# today is no good
	my $offset = 1;
	# yesterday no good either, early in the GMT day
	# (based on standard task timespec's)
	$offset++ if (gmtime)[2] < 8;

	push @where, sprintf(
		'(day <= DATE_SUB(NOW(), INTERVAL %d DAY))',
		$offset
	);

	if ($options->{days} && $options->{days} > 0) {
		push @where, sprintf(
			'(day > DATE_SUB(NOW(), INTERVAL %d DAY))',
			$options->{days} + $offset
		) if $options->{days};
	}

	my $data = $self->sqlSelectAll($sel, $table, join(' AND ', @where), $extra) or return;
	my %returnable;

	for my $d (@$data) {
		# $returnable{SECTION}{DAY}{NAME} = VALUE
		$returnable{$d->[2]}{$d->[3]}{$d->[0]} = $d->[1];

		$returnable{$d->[2]}{names} ||= [];
		push @{$returnable{$d->[2]}{names}}, $d->[0]
			unless grep { $_ eq $d->[0] } @{$returnable{$d->[2]}{names}};
	}

	return \%returnable;
}


sub DESTROY {
	my($self) = @_;
	#$self->sqlDo("DROP TABLE $self->{_table}");
	$self->{_dbh}->disconnect if !$ENV{GATEWAY_INTERFACE} && $self->{_dbh};
}


1;

__END__

=head1 SEE ALSO

Slash(3).

=head1 VERSION

$Id$

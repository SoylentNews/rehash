# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::DB::Oracle;

use strict;
use vars qw($VERSION);
# Hey, there's still *some* stuff we share...
use Slash::Utility;
use DBD::Oracle qw(:ora_types);

use base 'Slash::DB';
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# BENDER: Oh, no room for Bender, huh?  Fine.  I'll go build my own lunar
# lander.  With blackjack.  And hookers.  In fact, forget the lunar lander
# and the blackjack!  Ah, screw the whole thing.

sub DBPreConnectSetup {
	# Is there a configuration I can read from somewhere? -- thebrain
	$ENV{ORACLE_HOME} = '/opt/oracle/app/oracle/product/8.1.6';
}

sub DBPostConnectSetup {
	my($self) = @_;
	$self->setPrepareMethod('prepare');
	# Default date values to the MySQL format, since a lot of stuff seems to expect that -- thebrain
	$self->sqlDo("ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS'");
}

# Oracle dain bramage workaround -- See Slash::DB -- thebrain
sub TopicAllKey { return 'all' };
sub SectionAllKey { return 'all' };

# For the getDecriptions() method
my %descriptions = (
	'sortcodes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='$_[1]'") },

	'statuscodes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='statuscodes'") },

	'tzcodes'
		=> sub { $_[0]->sqlSelectMany('tz,off_set', 'tzcodes') },

	'tzdescription'
		=> sub { $_[0]->sqlSelectMany('tz,description', 'tzcodes') },

	'dateformats'
		=> sub { $_[0]->sqlSelectMany('id,description', 'dateformats') },

	'datecodes'
		=> sub { $_[0]->sqlSelectMany('id,format', 'dateformats') },

	'commentmodes'
		=> sub { $_[0]->sqlSelectMany('comment_mode,name', 'commentmodes') },

	'threshcodes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='threshcodes'") },

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

	'maillist'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='maillist'") },

	'session_login'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='session_login'") },

	'displaycodes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='displaycodes'") },

	'commentcodes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='commentcodes'") },

	'sections'
		=> sub { $_[0]->sqlSelectMany('section,title', 'sections', 'isolate=0', 'order by title') },

	'static_block'
		=> sub { $_[0]->sqlSelectMany('bid,bid', 'blocks', "$_[2] >= seclev AND type != 'portald'") },

	'portald_block'
		=> sub { $_[0]->sqlSelectMany('bid,bid', 'blocks', "$_[2] >= seclev AND type = 'portald'") },

	'color_block'
		=> sub { $_[0]->sqlSelectMany('bid,bid', 'blocks', "type = 'color'") },

	'authors'
		=> sub { $_[0]->sqlSelectMany('U.user_id, U.nickname', 'users U, users_param P', "P.name = 'author' AND U.user_id = P.user_id and P.value = 1") },

	'admins'
		=> sub { $_[0]->sqlSelectMany('user_id,nickname', 'users', 'seclev >= 100') },

	'users'
		=> sub { $_[0]->sqlSelectMany('user_id,nickname', 'users') },

	'templates'
		=> sub { $_[0]->sqlSelectMany('tpid,name', 'templates') },

	'templatesbypage'
		=> sub { $_[0]->sqlSelectMany('tpid,name', 'templates', "page = '$_[2]'") },

	'templatesbysection'
		=> sub { $_[0]->sqlSelectMany('tpid,name', 'templates', "section = '$_[2]'") },

	'pages'
		=> sub { $_[0]->sqlSelectMany('distinct page,page', 'templates') },

	'templatesections'
		=> sub { $_[0]->sqlSelectMany('distinct section,section', 'templates') },

	'sectionblocks'
		=> sub { $_[0]->sqlSelectMany('bid,title', 'blocks', 'portal=1') },

	'plugins'
		=> sub { $_[0]->sqlSelectMany('value,description', 'site_info', "name='plugin'") },

	'site_info'
		=> sub { $_[0]->sqlSelectMany('name,value', 'site_info', "name != 'plugin'") },

);

#sub _whereFormkey {
#sub init {

########################################################
# Bad need of rewriting....
sub createComment {
	my($self, $form, $user, $pts, $default_user) = @_;

	$self->{_dbh}->{AutoCommit} = 0;
	$self->sqlDo('LOCK TABLE comments IN EXCLUSIVE MODE');
	my($maxCid) = $self->sqlSelect('MAX(cid)','comments','sid = ?',[$form->{sid}]);

	$maxCid++; # This is gonna cause troubles, fixed in altcomments

	my $rv = $self->sqlInsert('comments',
		{	sid		=> $form->{sid},
			cid		=> $maxCid,
			pid		=> $form->{pid},
			-comment_date	=> 'SYSDATE',
			host_name	=> $ENV{REMOTE_ADDR},
			subject		=> $form->{postersubj},
			comment_text	=> $form->{postercomment},
			user_id		=> ($form->{postanon} ? $default_user : $user->{uid}),
			points		=> $pts,
			lastmod		=> -1,
			reason		=> 0
		},
		{ comment_text => { ora_type => ORA_CLOB, ora_field => 'comment_text' } }
	);
	# Unlock table
	$self->{_dbh}->commit;
	$self->{_dbh}->{AutoCommit} = 1;

	# don't allow pid to be passed in the form.
	# This will keep a pid from being replace by
	# with other comment's pid
	if ($form->{pid} >= $maxCid || $form->{pid} < 0) {
		return;
	}

	if ($rv) {
		return $maxCid;
	} else {
		return -1;
	}
}

########################################################
sub setModeratorLog {
	my($self, $cid, $sid, $uid, $val, $reason) = @_;
	$self->sqlInsert("moderatorlog", {
		user_id => $uid,
		val => $val,
		sid => $sid,
		cid => $cid,
		reason  => $reason,
		-ts => 'SYSDATE'
	});
}

########################################################
sub getMetamodComments {
	my($self, $id, $uid, $num_comments) = @_;

	my $sth = $self->sqlSelectMany(
		'comments.cid,comment_date,' .
		'subject,comment_text,users.user_id as user_id,
		sig,pid,comments.sid as sid,
		moderatorlog.id as id,title,moderatorlog.reason as modreason,
		comments.reason',
		'comments,users,users_info,moderatorlog,stories',
		"stories.sid=comments.sid AND moderatorlog.sid=comments.sid AND
		moderatorlog.cid=comments.cid AND moderatorlog.id>$id AND
		comments.user_id!=$uid AND users.user_id=comments.user_id AND
		users.user_id=users_info.user_id AND users.user_id!=$uid AND
		moderatorlog.user_id!=$uid AND moderatorlog.reason<8 LIMIT $num_comments"
	);

	my $comments = [];
	while (my $comment = $sth->fetchrow_hashref('NAME_lc')) {
		# Give the caller the column names he's expecting -- thebrain
		@$comment{'date','comment','uid'} = @$comment{'comment_date','comment_text','user_id'};
		delete @$comment{'comment_date','comment_text','user_id'};
		# Anonymize comment that is to be metamoderated.
		@{$comment}{qw(nickname uid points)} = ('-', -1, 0);
		push @$comments, $comment;
	}
	$sth->finish;

	formatDate($comments);
	return $comments;
}

########################################################
sub getModeratorCommentLog {

# why was this removed?  -- pudge
#				"moderatorlog.active=1
# Probably by accident. -Brian

	my($self, $sid, $cid) = @_;
	my $comments = $self->sqlSelectMany(  "comments.sid as sid,
				 comments.cid as cid,
				 comments.points as score,
				 subject, moderatorlog.user_id as user_id,
				 users.nickname as nickname,
				 moderatorlog.val as val,
				 moderatorlog.reason as reason",
				"moderatorlog, users, comments",
				"moderatorlog.sid='$sid'
			     AND moderatorlog.cid=$cid
			     AND moderatorlog.user_id=users.user_id
			     AND comments.sid=moderatorlog.sid
			     AND comments.cid=moderatorlog.cid"
	);
	my(@comments, $comment);
	while ($comment = $comments->fetchrow_hashref('NAME_lc')) {
		# Give the caller the column names he's expecting -- thebrain
		@$comment{'date','comment','uid'} = @$comment{'comment_date','comment_text','user_id'};
		delete @$comment{'comment_date','comment_text','user_id'};
		push @comments, $comment;
	}
	return \@comments;
}

########################################################
sub getModeratorLogID {
	my($self, $cid, $sid, $uid) = @_;
	my($mid) = $self->sqlSelect(
		"id", "moderatorlog",
		"user_id=$uid and cid=$cid and sid='$sid'"
	);
	return $mid;
}

########################################################
sub unsetModeratorlog {
	my($self, $uid, $sid, $max, $min) = @_;
	my $cursor = $self->sqlSelectMany("cid,val", "moderatorlog",
			"user_id=$uid and sid=" . $self->{_dbh}->quote($sid)
	);
	my @removed;

	while (my($cid, $val, $active, $max, $min) = $cursor->fetchrow){
		# We undo moderation even for inactive records (but silently for
		# inactive ones...)
		$self->sqlDo("delete from moderatorlog where
			cid=$cid and user_id=$uid and sid=" .
			$self->{_dbh}->quote($sid)
		);

		# If moderation wasn't actually performed, we should not change
		# the score.
		next if ! $active;

		# Insure scores still fall within the proper boundaries
		my $scorelogic = $val < 0
			? "points < $max"
			: "points > $min";
		$self->sqlUpdate(
			"comments",
			{ -points => "points+" . (-1 * $val) },
			"cid=$cid and sid=" . $self->{_dbh}->quote($sid) . " AND $scorelogic"
		);
		push(@removed, $cid);
	}

	return \@removed;
}

########################################################
sub getContentFilters {
	my($self) = @_;
	my $filters = $self->sqlSelectAll("*","content_filters","regex IS NOT NULL and field IS NOT NULL");
	return $filters;
}

########################################################
sub createPollVoter {
	my($self, $qid, $aid) = @_;

	$self->sqlInsert("pollvoters", {
		qid	=> $qid,
		id	=> $ENV{REMOTE_ADDR} . $ENV{HTTP_X_FORWARDED_FOR},
		-'time'	=> 'SYSDATE',
		user_id	=> $ENV{SLASH_USER}
	});

	my $qid_db = $self->{_dbh}->quote($qid);
	$self->sqlDo("update pollquestions set
		voters=voters+1 where qid=$qid_db");
	$self->sqlDo("update pollanswers set votes=votes+1 where
		qid=$qid_db and aid=" . $self->{_dbh}->quote($aid));
}

########################################################
sub createSubmission {
	my($self, $submission) = @_;
	return unless $submission;

	my($sec, $min, $hour, $mday, $mon, $year) = localtime;
	my $subid = "$hour$min$sec.$mon$mday$year";

	$submission->{user_id} = $submission->{uid}; delete $submission->{uid};
	$submission->{'-time'} = 'SYSDATE';
	$submission->{'subid'} = $subid;
	$self->sqlInsert('submissions', $submission);
	$submission->{uid} = $submission->{user_id}; delete $submission->{user_id};
}

#################################################################
sub getDiscussions {
	my($self) = @_;
	my $discussion = $self->{_dbh}->prepare('
		SELECT sid, title, url
		FROM (
			SELECT ROWNUM as rn, sid, title, url
			FROM (
				SELECT d.sid sid, d.title title, d.url url
				FROM discussions d, stories s
				WHERE displaystatus > -1 AND d.sid = s.sid AND time <= SYSDATE
				ORDER BY time DESC
			)
		) WHERE rn <= 50
	');

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
		$self->sqlDo("DELETE from sessions WHERE SYSDATE > lasttime + ($admin_timeout / 1440)");
  
		my $session_in_q = $self->{_dbh}->quote($session_in);
  
		my($uid) = $self->sqlSelect(
			'user_id',
			'sessions',
			"session_id=$session_in_q"
		);
  
		if ($uid) {
			$self->sqlDo("DELETE from sessions WHERE user_id = '$uid' AND " .
				"session_id != $session_in_q"
			);
			$self->sqlUpdate('sessions', {-lasttime => 'SYSDATE'},
				"session_id = $session_in_q"
			);
			$session_out = $session_in;
		}
	}
	if (!$session_out) {
		my($title) = $self->sqlSelect('lasttitle', 'sessions',
			"user_id=$uid"
		);
		$title ||= "";

		$self->sqlDo("DELETE FROM sessions WHERE user_id=$uid");

		$self->sqlInsert('sessions', { -user_id => $uid,
			-logintime => 'SYSDATE', -lasttime => 'SYSDATE',
			lasttitle => $title }
		);
		($session_out) = $self->sqlSelect('seq_sessions.currval','dual');
	}
	return $session_out;

}

#sub setContentFilter {
#sub setSectionExtra {

########################################################
# This creates an entry in the accesslog
sub createAccessLog {
	my($self, $op, $dat) = @_;

	my $uid;
	if ($ENV{SLASH_USER}) {
		$uid = $ENV{SLASH_USER};
	} else {
		$uid = getCurrentStatic('anonymous_coward_uid');
	}

	$self->sqlInsert('accesslog', {
		host_addr	=> $ENV{REMOTE_ADDR} || '0',
		dat		=> $dat,
		user_id		=> $uid,
		op		=> $op,
		-ts		=> 'SYSDATE',
		query_string	=> $ENV{QUERY_STRING} || '0',
		user_agent	=> $ENV{HTTP_USER_AGENT} || '0',
	});

	if ($dat =~ /\//) {
		$self->sqlUpdate('storiestuff', { -hits => 'hits+1' },
			'sid=' . $self->{_dbh}->quote($dat)
		);
	}
}

########################################################
sub getDescriptions {
	my($self, $codetype, $optional, $flag) =  @_;
	return unless $codetype;
	my $codeBank_hash_ref = {};
	my $cache = '_getDescriptions_' . $codetype;

	if ($flag) {
		undef $self->{$cache};
	} else {
		return $self->{$cache} if $self->{$cache}; 
	}

	my $sth = $descriptions{$codetype}->(@_);
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
		' user_id = ' . $self->{_dbh}->quote($uid)
	);
	return undef unless $user;
	my $user_extra = $self->sqlSelectHashref('*', "users_prefs", "user_id=$uid");
	while (my($key, $val) = each %$user_extra) {
		$user->{$key} = $val;
	}

	# what is this for?  it appears to want to do the same as the
	# code above ... but this assigns a scalar to a scalar ...
	# perhaps `@{$user}{ keys %foo } = values %foo` is wanted?  -- pudge
#	$user->{ keys %$user_extra } = values %$user_extra;

#	if (!$script || $script =~ /index|article|comments|metamod|search|pollBooth/)
	{
		my $user_extra = $self->sqlSelectHashref('*', "users_comments", "user_id=$uid");
		while (my($key, $val) = each %$user_extra) {
			$user->{$key} = $val;
		}
	}

	# Do we want the index stuff?
#	if (!$script || $script =~ /index/)
	{
		my $user_extra = $self->sqlSelectHashref('*', "users_index", "user_id=$uid");
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
		sig		=> '',
		seclev		=> 0
	});
	$self->sqlDo("DELETE FROM users_param WHERE user_id=$uid");
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
		'user_id,passwd,newpasswd',
		'users',
		"user_id=$user_db"
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
			}, "user_id=$user_db");
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
	}, 'user_id=' . $self->{_dbh}->quote($uid));
	return $newpasswd;
}

########################################################
# Get user info from the users table.
# May be worth it to cache this at some point
sub getUserUID {
	my($self, $name) = @_;

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# We need to add BINARY to this
# as is, it may be a security flaw
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	my($uid) = $self->sqlSelect('user_id', 'users',
		'nickname=' . $self->{_dbh}->quote($name)
	);

	return $uid;
}

#################################################################
sub getCommentsByUID {
	my($self, $uid, $min) = @_;

	my $sqlquery = "SELECT pid,sid,cid,subject,comment_date,points "
			. " FROM comments WHERE user_id=$uid "
			. " ORDER BY comment_date DESC";

	my $sth = $self->{_dbh}->prepare($sqlquery);
	$sth->execute;
	my $comments = [];
	# Oracle has no convenient LIMIT clause, so we simulate -- thebrain
	if ($min) { 1 while $min-- and $sth->fetchrow }
	$min = 50;
	while ($min-- and my $row = $sth->fetchrow) {
		push @$comments, [@$row];
	}
	formatDate($comments, 4);
	return $comments;
}

#################################################################
# Just create an empty content_filter
sub createContentFilter {
	my($self) = @_;

	$self->sqlInsert("content_filters", {
		regex		=> '',
		modifier	=> '',
		field		=> '',
		ratio		=> 0,
		minimum_match	=> 0,
		minimum_length	=> 0,
		maximum_length	=> 0,
		err_message	=> ''
	});

	my($filter_id) = $self->sqlSelect('seq_content_filters.currval','dual');

	return $filter_id;
}

#################################################################
# Replication issue. This needs to be a two-phase commit.
sub createUser {
	my($self, $matchname, $email, $newuser) = @_;
	return unless $matchname && $email && $newuser;

	return if ($self->sqlSelect(
		"count(user_id)","users",
		"matchname=?",[$matchname]
	))[0] || ($self->sqlSelect(
		"count(user_id)","users",
		"realemail=?",[$email]
	))[0];

	$self->sqlInsert("users", {
		user_id		=> '',
		realemail	=> $email,
		nickname	=> $newuser,
		matchname	=> $matchname,
		seclev		=> 1,
		passwd		=> encryptPassword(changePassword())
	});

# This is most likely a transaction problem waiting to
# bite us at some point. -Brian
	my($uid) = $self->sqlSelect('seq_users.currval','dual');
	return unless $uid;
	$self->sqlInsert("users_info", { user_id => $uid, -lastaccess => 'SYSDATE' } );
	$self->sqlInsert("users_prefs", { user_id => $uid } );
	$self->sqlInsert("users_comments", { user_id => $uid } );
	$self->sqlInsert("users_index", { user_id => $uid } );

	return $uid;
}

#sub setVar {

########################################################
sub setSession {
	my($self, $name, $value) = @_;
	$self->sqlUpdate('sessions', $value, 'user_id=' . $self->{_dbh}->quote($name));
}

#sub setBlock {
#sub setDiscussion {
#sub setTemplate {
#sub getCommentCid {
#sub deleteComment {
#sub getCommentPid {
#sub setSection {
#sub setStoryCount {

########################################################
sub getSectionTitle {
	my($self) = @_;
	return $self->sqlSelectAll('CASE WHEN section = ? THEN NULL ELSE SECTION END, title',
				   'sections','',
				   'ORDER BY CASE WHEN section = ? THEN 0 ELSE 1 END, section',[$self->SectionAllKey,$self->SectionAllKey]);
}

#sub getSectionTitle {

########################################################
# Long term, this needs to be modified to take in account
# of someone wanting to delete a submission that is
# not part in the form
sub deleteSubmission {
return 0; # oh not yet
	my($self, $subid) = @_;
	my $uid = getCurrentUser('uid');
	my $form = getCurrentForm();
	my %subid;

	if ($form->{subid}) {
		$self->sqlUpdate("submissions", { del => 1 },
			"subid=" . $self->{_dbh}->quote($form->{subid})
		);
		$self->setUser($uid,
			{ -deletedsubmissions => 'deletedsubmissions+1' }
		);
		$subid{$form->{subid}}++;
	}

	foreach (keys %{$form}) {
		next unless /(.*)_(.*)/;
		my($t, $n) = ($1, $2);
		if ($t eq "note" || $t eq "comment" || $t eq "section") {
			$form->{"note_$n"} = "" if $form->{"note_$n"} eq " ";
			if ($form->{$_}) {
				my %sub = (
					note	=> $form->{"note_$n"},
					comment_text	=> $form->{"comment_$n"},
					section	=> $form->{"section_$n"}
				);

				if (!$sub{note}) {
					delete $sub{note};
					$sub{-note} = 'NULL';
				}

				$self->sqlUpdate("submissions", \%sub,
					"subid=" . $self->{_dbh}->quote($n));
			}
		} else {
			my $key = $n;
			$self->sqlUpdate("submissions", { del => 1 },
				"subid='$key'");
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
		$self->sqlDo("DELETE FROM sessions WHERE user_id=$uid");
	}
}

########################################################
sub deleteAuthor {
	my($self, $uid) = @_;
	$self->sqlDo("DELETE FROM sessions WHERE user_id=$uid");
}

#sub deleteTopic {
#sub revertBlock {
#sub deleteBlock {
#sub deleteTemplate {
#sub deleteSection {
#sub deleteContentFilter {
#sub saveTopic {
#sub saveBlock {
#sub saveColorBlock {
#sub getSectionBlock {
#sub getSectionBlocks {

########################################################
sub getAuthorDescription {
	my($self) = @_;
	my $authors = $self->sqlSelectAll("count(*) as c, user_id",
		"stories", '', "GROUP BY user_id ORDER BY c DESC"
	);

	return $authors;
}

########################################################
# This method does not follow basic guidlines
sub getPollVoter {
	my($self, $id) = @_;
	my($voters) = $self->sqlSelect('id', 'pollvoters',
		"qid=" . $self->{_dbh}->quote($id) .
		"AND id=" . $self->{_dbh}->quote($ENV{REMOTE_ADDR} . $ENV{HTTP_X_FORWARDED_FOR}) .
		"AND user_id=" . $ENV{SLASH_USER}
	);

	return $voters;
}

########################################################
sub savePollQuestion {
	my($self) = @_;
	my $form = getCurrentForm();
	$form->{voters} ||= "0";
	$self->sqlReplace("pollquestions", {
		qid		=> $form->{qid},
		question	=> $form->{question},
		voters		=> $form->{voters},
		-poll_date	=>'SYSDATE'
	});

	$self->setVar("currentqid", $form->{qid}) if $form->{currentqid};

	# Loop through 1..8 and insert/update if defined
	for (my $x = 1; $x < 9; $x++) {
		if ($form->{"aid$x"}) {
			$self->sqlReplace("pollanswers", {
				aid	=> $x,
				qid	=> $form->{qid},
				answer	=> $form->{"aid$x"},
				votes	=> $form->{"votes$x"}
			});

		} else {
			$self->sqlDo("DELETE from pollanswers WHERE qid="
				. $self->{_dbh}->quote($form->{qid}) . " and aid=$x");
		}
	}
}

########################################################
sub getPollQuestionList {
	my($self, $min) = @_;
	my $sth = $self->sqlSelectMany('qid, question, poll_date','pollquestions','','ORDER BY poll_date DESC');
	$sth->execute;
	my $questions = [];
	# Oracle has no convenient LIMIT clause, so we simulate -- thebrain
	if ($min) { 1 while $min-- and $sth->fetch }
	$min = 20;
	while ($min-- and my $row = $sth->fetch) {
		push @$questions, [@$row];
	}

	formatDate($questions, 2, 2, '%F'); # '%A %B %E' || '%F'

	return $questions;
}

#sub getPollAnswers {

########################################################
sub getPollQuestions {
# This may go away. Haven't finished poll stuff yet
#
	my($self) = @_;

	my $poll_hash_ref = {};
	my $sth = $self->sqlSelectMany('qid, question','pollquestions','','ORDER BY poll_date');

	# Oracle has no convenient LIMIT clause, so we simulate -- thebrain
	my $max = 25;
	while ($max-- and my $row = $sth->fetch) {
		$poll_hash_ref->{$row->[0]} = $row->[1];
	}
	$sth->finish;

	return $poll_hash_ref;
}

#sub deleteStory {
#sub deleteStoryAll {
#sub setStory {
#sub getSubmissionLast {

########################################################
sub updateFormkeyId {
	my($self, $formname, $formkey, $anon, $uid, $rlogin, $upasswd) = @_;

	if ($uid != $anon && $rlogin && length($upasswd) > 1) {
		$self->sqlUpdate("formkeys", {
			id	=> $uid,
			uid	=> $uid,
		}, "formname='$formname' AND user_id = $anon AND formkey=" .
			$self->{_dbh}->quote($formkey));
	}
}

########################################################
sub createFormkey {
	my($self, $formname, $id, $sid) = @_;
	my $form = getCurrentForm();

	# save in form object for printing to user
	$form->{formkey} = getFormkey();

	# insert the fact that the form has been displayed, but not submitted at this point
	$self->sqlInsert('formkeys', {
		formkey		=> $form->{formkey},
		formname 	=> $formname,
		id 		=> $id,
		sid		=> $sid,
		user_id		=> $ENV{SLASH_USER},
		host_name	=> $ENV{REMOTE_ADDR},
		value		=> 0,
		ts		=> time()
	});
}

#sub checkFormkey {
#sub checkTimesPosted {
#sub formSuccess {
#sub formFailure {
#sub createAbuse {
#sub checkForm {

##################################################################
# Current admin users
sub currentAdmin {
	my($self) = @_;
	# The original query had a GROUP BY clause but there are no group expressions
	# anywhere in the statement -- I'm curious if MySQL returns something other than
	# a plain old join in that instance, or if the GROUP BY was just a leftover or
	# a thinko -- thebrain
	my $aids = $self->sqlSelectAll('nickname,lasttime,lasttitle', 'sessions,users',
		'sessions.user_id=users.user_id'
	);

	return $aids;
}

#sub getTopNewsstoryTopics {
#sub getPoll {
#sub getSubmissionsSections {

##################################################################
# Get submission count
sub getSubmissionsPending {
	my($self, $uid) = @_;
	my $submissions;

	if ($uid) {
		$submissions = $self->sqlSelectAll("time, subj, section, tid, del", "submissions", "user_id=$uid");
	} else {
		$uid = getCurrentUser('uid');
		$submissions = $self->sqlSelectAll("time, subj, section, tid, del", "submissions", "user_id=$uid");
	}
	return $submissions;
}

##################################################################
# Get submission count
sub getSubmissionCount {
	my($self, $articles_only) = @_;
	my($count);
	if ($articles_only) {
		($count) = $self->sqlSelect('count(*)', 'submissions',
			"(LENGTH(note) < 1 or note IS NULL) and del=0" .
			" and section='articles'"
		);
	} else {
		($count) = $self->sqlSelect("count(*)", "submissions",
			"(LENGTH(note) < 1 or note IS NULL) and del=0"
		);
	}
	return $count;
}

#sub getPortals {

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
	while (my $SB = $sth->fetchrow_hashref('NAME_lc')) {
		$self->{_boxes}{$SB->{bid}} = $SB;  # Set the Slashbox
		next unless $SB->{ordernum} > 0;  # Set the index if applicable
		push @{$tmp{$SB->{section}}}, $SB->{bid};
	}
	$self->{_sectionBoxes} = \%tmp;
	$sth->finish;

	return($self->{_boxes}, $self->{_sectionBoxes});
}

#sub countCommentsBySid {
#sub countCommentsBySidUID {
#sub countCommentsBySidPid {

##################################################################
sub findCommentsDuplicate {
	my($self, $sid, $comment) = @_;
	$self->sqlInsert('clob_compare',
		{ id => 1, data => $comment },
		{ data => { ora_type => ORA_CLOB, ora_field => 'data' } }
	);
	my $c = $self->sqlCount('comments',
		'sid = ? AND DBMS_LOB.COMPARE(comment_text,(SELECT data FROM clob_compare WHERE id = 1)) = 0',
		[$sid]
	);
	$self->sqlDo('DELETE FROM clob_compare');
	return $c;
}

#sub countStory {

##################################################################
sub checkForMetaModerator {
	my($self, $user) = @_;
	return unless $user->{willing};
	return if $user->{is_anon};
	return if $user->{karma} < 0;
	# This should be equivalent to the to_days thing in MySQL
	my($d) = $self->sqlSelect("ROUND(SYSDATE,'DD') - ROUND(lastmm,'DD')",
		'users_info', "user_id = '$user->{uid}'");
	return unless $d;
	my($tuid) = $self->sqlSelect('count(*)', 'users');
	return if $user->{uid} >
		  $tuid * $self->getVar('m2_userpercentage', 'value');
	# what to do with I hash here?
	return 1;  # OK to M2
}

#sub getAuthorNames {

##################################################################
# Oranges to Apples. Would it be faster to grab some of this
# data from the cache? Or is it just as fast to grab it from
# the database?
sub getStoryByTime {
	my($self, $sign, $story, $isolate, $section) = @_;
	my($where);
	my $user = getCurrentUser();

	my $order = $sign eq '<' ? 'DESC' : 'ASC';
	if ($isolate) {
		$where = 'AND section=' . $self->{_dbh}->quote($story->{'section'})
			if $isolate == 1;
	} else {
		$where = 'AND displaystatus=0';
	}

	$where .= "   AND tid not in ($user->{'extid'})" if $user->{'extid'};
	$where .= "   AND uid not in ($user->{'exaid'})" if $user->{'exaid'};
	$where .= "   AND section not in ($user->{'exsect'})" if $user->{'exsect'};
	$where .= "   AND sid != '$story->{'sid'}'";

	my $time = $story->{'time'};
	my $returnable = $self->sqlSelectHashref(
			'title, sid, section', 'newstories',
			"time $sign '$time' AND writestatus >= 0 AND time < SYSDATE $where",
			"ORDER BY time $order"
	);

	return $returnable;
}

########################################################
sub countStories {
	my($self) = @_;
	my $sth = $self->sqlSelectMany("sid,title,section,commentcount,users.nickname",
		"stories,users","stories.user_id=users.user_id", "ORDER BY commentcount DESC"
	);
	my $stories = [];
	my $limit = 10;
	while ($limit-- and my $row = $sth->fetchrow) {
		push @$stories, [@$row];
	}
	return $stories;
}

########################################################
sub setModeratorVotes {
	my($self, $uid, $metamod) = @_;
	$self->sqlUpdate("users_info",{
		-m2unfairvotes	=> "m2unfairvotes+$metamod->{unfair}",
		-m2fairvotes	=> "m2fairvotes+$metamod->{fair}",
		-lastmm		=> 'SYSDATE',
		lastmmid	=> 0
	}, "user_id=$uid");
}

########################################################
sub setMetaMod {
	my($self, $m2victims, $flag, $ts) = @_;

	my $constants = getCurrentStatic();
	my $returns = [];

	# Update $muid's Karma
	$self->{_dbh}->{AutoCommit} = 0;
	$self->sqlDo('LOCK TABLE users_info IN EXCLUSIVE MODE');
	$self->sqlDo('LOCK TABLE metamodlog IN EXCLUSIVE MODE');
	for (keys %{$m2victims}) {
		my $muid = $m2victims->{$_}[0];
		my $val = $m2victims->{$_}[1];
		next unless $val;
		push(@$returns , [$muid, $val]);

		my $mmid = $_;
		if ($muid && $val && !$flag) {
			if ($val eq '+') {
				$self->sqlUpdate("users_info", { -m2fair => "m2fair+1" }, "user_id=$muid");
				# There is a limit on how much karma you can get from M2.
				$self->sqlUpdate("users_info", { -karma => "karma+1" },
					"$muid=user_id and karma<$constants->{m2_maxbonus}");
			} elsif ($val eq '-') {
				$self->sqlUpdate("users_info", { -m2unfair => "m2unfair+1" },
					"user_id=$muid");
				$self->sqlUpdate("users_info", { -karma => "karma-1" },
					"$muid=user_id and karma>$constants->{badkarma}");
			}
		}
		# Time is now fixed at form submission time to ease 'debugging'
		# of the moderation system, ie 'GROUP BY uid, ts' will give
		# you the M2 votes for a specific user ordered by M2 'session'
		$self->sqlInsert("metamodlog", {
			-mmid => $mmid,
			-uid  => $ENV{SLASH_USER},
			-val  => ($val eq '+') ? 1 : -1,
			# You know, occasionally Oracle's internal treatment of dates
			# can be convenient :) -- thebrain
			-ts   => "TO_DATE('01-JAN-1970','DD-MON-YYYY') + $ts / 86400",
			-flag => $flag
		});
	}
	# Unlock table
	$self->{_dbh}->commit;
	$self->{_dbh}->{AutoCommit} = 1;

	return $returns;
}

########################################################
sub getModeratorLast {
	my($self, $uid) = @_;
	my $last = $self->sqlSelectHashref(
		"ROUND(SYSDATE,'DD') - ROUND(lastmm,'DD') as lastmm, lastmmid",
		"users_info",
		"user_id=$uid"
	);
	return $last;
}

#sub getModeratorLogRandom {
#sub countUsers {

########################################################
sub countStoriesStuff {
	my($self) = @_;
	my $sth = $self->sqlSelectMany("stories.sid,title,section,storiestuff.hits as hits,users.nickname",
		"stories,storiestuff,users","stories.sid=storiestuff.sid AND stories.user_id=users.user_id",
		"ORDER BY hits DESC"
	);
	my $stories = [];
	my $limit = 10;
	while ($limit-- and my $row = $sth->fetchrow) {
		push @$stories, [@$row];
	}
	return $stories;
}

########################################################
sub countStoriesAuthors {
	my($self) = @_;
	my $sth = $self->sqlSelectMany("count(*) as c, nickname, homepage",
		"stories, users","users.user_id=stories.user_id",
		"GROUP BY stories.user_id ORDER BY c DESC"
	);
	my $authors = [];
	my $limit = 10;
	while ($limit-- and my $row = $sth->fetchrow) {
		push @$authors, [@$row];
	}
	return $authors;
}

########################################################
sub countPollquestions {
	my($self) = @_;
	my $sth = $self->sqlSelectMany("voters,question,qid", "pollquestions",
		"", "ORDER by voters DESC"
	);
	my $pollquestions = [];
	my $limit = 10;
	while ($limit-- and my $row = $sth->fetchrow) {
		push @$pollquestions, [@$row];
	}
	return $pollquestions;
}

#sub createVar {
#sub deleteVar {

########################################################
# I'm not happy with this method at all
sub setCommentCleanup {
	my($self, $val, $sid, $reason, $modreason, $cid) = @_;
	# Grab the user object.
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my($cuid, $ppid, $subj, $points, $oldreason) = $self->getComments($sid, $cid);

	my $strsql = "UPDATE comments SET
		points=points$val,
		reason=$reason,
		lastmod=$user->{uid}
		WHERE sid=" . $self->{_dbh}->quote($sid)."
		AND cid=$cid
		AND points " .
			($val < 0 ? " > $constants->{comment_minscore}" : "") .
			($val > 0 ? " < $constants->{comment_maxscore}" : "");

	$strsql .= " AND lastmod<>$user->{uid}"
		unless $user->{seclev} >= 100 && $constants->{authors_unlimited};

	if ($val ne "+0" && $self->sqlDo($strsql)) {
		$self->setModeratorLog($cid, $sid, $user->{uid}, $modreason, $val);

		# Adjust comment posters karma
		if ($cuid != $constants->{anonymous_coward}) {
			if ($val > 0) {
				$self->sqlUpdate("users_info", {
						-karma	=> "karma$val",
						-upmods	=> 'upmods+1',
					}, "user_id=$cuid AND karma < $constants->{maxkarma}"
				);
			} elsif ($val < 0) {
				$self->sqlUpdate("users_info", {
						-karma		=> "karma$val",
						-downmods	=> 'downmods+1',
					}, "user_id=$cuid AND karma > $constants->{minkarma}"
				);
			}
		}

		# Adjust moderators total mods
		$self->sqlUpdate(
			"users_info",
			{ -totalmods => 'totalmods+1' },
			"user_id=$user->{uid}"
		);

		# And deduct a point.
		$user->{points} = $user->{points} > 0 ? $user->{points} - 1 : 0;
		$self->sqlUpdate(
			"users_comments",
			{ -points=>$user->{points} },
			"user_id=$user->{uid}"
		); 
		return 1;
	}
	return;
}

#sub countUsersIndexExboxesByBid {

########################################################
sub getCommentReply {
	my($self, $sid, $pid) = @_;
	my $reply = $self->sqlSelectHashref('comment_date, subject, comments.points as points,
		comment_text, realname, nickname,
		fakeemail, homepage, cid, sid, users.user_id as user_id',
		'comments, users, users_info, users_comments',
		'sid = ? AND cid = ? AND users.user_id = users_info.user_id
		AND users.user_id = users_comments.user_id AND users.user_id = comments.user_id',
		[$sid,$pid]
	);
	$reply->{uid} = $reply->{user_id}; delete $reply->{user_id};

	formatDate([$reply]);
	return $reply;
}

########################################################
sub getCommentsForUser {
	my($self, $sid, $cid) = @_;
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $sql = "SELECT cid,comment_date,
				subject,comment_text,
				nickname,homepage,fakeemail,
				users.user_id as user_id,sig,
				comments.points as points,pid,sid,
				lastmod, reason
			   FROM comments,users
			  WHERE sid=" . $self->{_dbh}->quote($sid) . "
			    AND comments.user_id=users.user_id";
	$sql .= "	    AND (";
	$sql .= "		comments.user_id=$user->{uid} OR " unless $user->{is_anon};
	$sql .= "		cid=$cid OR " if $cid;
	$sql .= "		comments.points >= " . $self->{_dbh}->quote($user->{threshold}) . " OR " if $user->{hardthresh};
	$sql .= "		  1=1 )   ";
	$sql .= "	  ORDER BY ";
	$sql .= "comments.points DESC, " if $user->{commentsort} eq '3';
	$sql .= " cid ";
	$sql .= ($user->{commentsort} == 1 || $user->{commentsort} == 5) ? 'DESC' : 'ASC';


	my $thisComment = $self->{_dbh}->prepare_cached($sql) or errorLog($sql);
	$thisComment->execute or errorLog($sql);
	my $comments = [];
	while (my $comment = $thisComment->fetchrow_hashref('NAME_lc')){
		# Give the caller the column names he's expecting -- thebrain
		@$comment{'date','comment','uid'} = @$comment{'comment_date','comment_text','user_id'};
		delete @$comment{'comment_date','comment_text','user_id'};
		push @$comments, $comment;
	}
	formatDate($comments);
	return $comments;
}

########################################################
sub getComments {
	my($self, $sid, $cid) = @_;
	$self->sqlSelect("user_id,pid,subject,points,reason",
		"comments", "cid=$cid and sid='$sid'"
	);
}

########################################################
sub getNewStories {
	my($self, $section, $limit, $tid, $section_display) = @_;
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	$section ||= $user->{currentSection} || $self->SectionAllKey;
	$section_display ||= $form->{section};

	$limit ||= $section eq 'index'
		? $user->{maxstories}
		: $self->getSection($section, 'artcount');

	my $tables = 'newstories';
	my $columns = 'sid, section, title, time, commentcount, time as time2, hitparade';

	my $where = "time < SYSDATE ";
	$where .= "AND displaystatus=0 " unless $form->{section};
	$where .= "AND (displaystatus>=0 AND section='$section') " if $section_display;
	$where .= "AND tid='$tid' " if $tid;

	# User Config Vars
	$where .= "AND tid not in ($user->{extid}) "		if $user->{extid};
	$where .= "AND uid not in ($user->{exaid}) "		if $user->{exaid};
	$where .= "AND section not in ($user->{exsect}) "	if $user->{exsect};

	# Order
	my $other = "ORDER BY time DESC ";

	# We need to check up on this later for performance -Brian
	my(@stories, $count);
	my $cursor = $self->sqlSelectMany($columns, $tables, $where, $other)
		or errorLog("error in getStories columns $columns table $tables where $where other $other");

	while (my(@data) = $cursor->fetchrow) {
		formatDate([\@data], 3, 3, '%A %B %d %I %M %p');
		formatDate([\@data], 5, 5, '%Q');
		next if $form->{issue} && $data[5] > $form->{issue};
		push @stories, [@data];
		last if ++$count >= $limit;
	}
	$cursor->finish;

	return \@stories;
}

########################################################
sub getCommentsTop {
	my($self, $sid) = @_;
	my $user = getCurrentUser();
	my $where = "stories.sid=comments.sid and stories.user_id=users.user_id";
	$where .= " AND stories.sid=" . $self->{_dbh}->quote($sid) if $sid;
	my $sth = $self->sqlSelectMany("section, stories.sid, users.nickname, title, pid, subject,"
		. "date, time, comments.user_id, cid, points"
		, "stories, comments, users"
		, $where
		, " ORDER BY points DESC, date DESC");

	my $stories = [];
	my $limit = 10;
	while ($limit-- and my $row = $sth->fetchrow) {
		push @$stories, [@$row];
	}
	formatDate($stories, 6);
	formatDate($stories, 7);
	return $stories;
}

#sub getQuickies {

########################################################
sub setQuickies {
	my($self, $content) = @_;
	$self->sqlInsert("submissions", {
		subid	=> 'quickies',
		subj	=> 'Generated Quickies',
		email	=> '',
		name	=> '',
		-'time'	=> 'SYSDATE',
		section	=> 'articles',
		tid	=> 'quickies',
		story	=> $content,
		uid	=> getCurrentStatic('anonymous_coward_uid'),
	});
}

########################################################
# What an ugly method
sub getSubmissionForUser {
	my($self) = @_;
	my $form = getCurrentForm();
	my $user = getCurrentUser();

	my $sql = "SELECT subid,subj,time,tid,note,email,name,section,comment_text,submissions.user_id,karma FROM submissions,users_info";
	$sql .= "  WHERE submissions.user_id=users_info.user_id AND $form->{del}=del AND (";
	$sql .= $form->{note} ? "note=" . $self->{_dbh}->quote($form->{note}) : "note IS NULL";
	$sql .= "		or note=' ' " unless $form->{note};
	$sql .= ")";
	$sql .= "		and tid='$form->{tid}' " if $form->{tid};
	$sql .= "         and section=" . $self->{_dbh}->quote($user->{section}) if $user->{section};
	$sql .= "         and section=" . $self->{_dbh}->quote($form->{section}) if $form->{section};
	$sql .= "	  ORDER BY time";

	my $cursor = $self->{_dbh}->prepare($sql);
	$cursor->execute;

	my $submission = $cursor->fetchall_arrayref;

	formatDate($submission, 2, 2, '%m/%d  %H:%M');

	return $submission;
}

########################################################
sub getTrollAddress {
	my($self) = @_;
	my($badIP) = $self->sqlSelect("sum(val)","comments,moderatorlog",
			"comments.sid=moderatorlog.sid AND comments.cid=moderatorlog.cid
			AND host_name='$ENV{REMOTE_ADDR}' AND moderatorlog.active=1
			AND ROUND(SYSDATE,'DD') - ROUND(ts,'DD') < 3 GROUP BY host_name"
	);

	return $badIP;
}

########################################################
sub getTrollUID {
	my($self) = @_;
	my $user = getCurrentUser();
	my($badUID) = $self->sqlSelect("sum(val)","comments,moderatorlog",
		"comments.sid=moderatorlog.sid AND comments.cid=moderatorlog.cid
		AND comments.user_id=$user->{uid} AND moderatorlog.active=1
		AND ROUND(SYSDATE,'DD') - ROUND(ts,'DD') < 3 GROUP BY comments.user_id"
	);

	return $badUID;
}

#sub createDiscussion {

########################################################
sub createStory {
	my($self, $story) = @_;
	unless ($story) {
		$story ||= getCurrentForm();
	}
	#Create a sid 
	my($sec, $min, $hour, $mday, $mon, $year) = localtime;
	$year = $year % 100;
	my $sid = sprintf('%02d/%02d/%02d/%02d%0d2%02d',
		$year, $mon+1, $mday, $hour, $min, $sec);

	$self->sqlInsert('storiestuff', { sid => $sid });

	# If this came from a submission, update submission and grant
	# Karma to the user
	my $suid;
	if ($story->{subid}) {
		my $constants = getCurrentStatic();
		my($suid) = $self->sqlSelect(
			'user_id','submissions',
			'subid=' . $self->{_dbh}->quote($story->{subid})
		);

		# i think i got this right -- pudge
 		my($userkarma) = $self->sqlSelect('karma', 'users_info', "user_id=$suid");
 		my $newkarma = (($userkarma + $constants->{submission_bonus})
 			> $constants->{maxkarma})
 				? $constants->{maxkarma}
 				: "karma+$constants->{submission_bonus}";
 		$self->sqlUpdate('users_info', { -karma => $newkarma }, "user_id=$suid")
 			if $suid != $constants->{anonymous_coward_uid};

		$self->sqlUpdate('users_info',
			{ -karma => 'karma + 3' },
			"user_id=$suid"
		) if $suid != $constants->{anonymous_coward_uid};

		$self->sqlUpdate('submissions',
			{ del=>2 },
			'subid=' . $self->{_dbh}->quote($story->{subid})
		);
	}

	my $data = {
		sid		=> $sid,
		user_id		=> $story->{uid},
		tid		=> $story->{tid},
		dept		=> $story->{dept},
		'time'		=> $story->{'time'},
		title		=> $story->{title},
		section		=> $story->{section},
		bodytext	=> $story->{bodytext},
		introtext	=> $story->{introtext},
		writestatus	=> $story->{writestatus},
		relatedtext	=> $story->{relatedtext},
		displaystatus	=> $story->{displaystatus},
		commentstatus	=> $story->{commentstatus}
	};

	$self->sqlInsert('stories', $data);
	$self->sqlInsert('newstories', $data);
	$self->_saveExtras($story);

	return $sid;
}

##################################################################
sub updateStory {
	my($self) = @_;
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();
	$self->sqlUpdate('discussions',{
		sid	=> $form->{sid},
		title	=> $form->{title},
		url	=> "$constants->{rootdir}/article.pl?sid=$form->{sid}",
		ts	=> $form->{'time'},
	}, 'sid = ' . $self->{_dbh}->quote($form->{sid}));

	$self->sqlUpdate('stories', {
		user_id		=> $form->{uid},
		tid		=> $form->{tid},
		dept		=> $form->{dept},
		'time'		=> $form->{'time'},
		title		=> $form->{title},
		section		=> $form->{section},
		bodytext	=> $form->{bodytext},
		introtext	=> $form->{introtext},
		writestatus	=> $form->{writestatus},
		relatedtext	=> $form->{relatedtext},
		displaystatus	=> $form->{displaystatus},
		commentstatus	=> $form->{commentstatus}
	}, 
	{
		bodytext => { ora_type => ORA_CLOB, ora_field => 'bodytext' },
		introtext => { ora_type => ORA_CLOB, ora_field => 'introtext' },
		relatedtext => { ora_type => ORA_CLOB, ora_field => 'relatedtext' }
	},
	'sid=?',
	[$form->{sid}]
	);

	$self->sqlDo('UPDATE stories SET time=now() WHERE sid='
		. $self->{_dbh}->quote($form->{sid})
	) if $form->{fastforward} eq 'on';
	$self->_saveExtras($form);
}

#sub getSlashConf {
#sub autoUrl {

##################################################################
# autoUrl & Helper Functions
# Image Importing, Size checking, File Importing etc
sub getUrlFromTitle {
	my($self, $title) = @_;
	my($sid) = $self->sqlSelect('sid', 'stories',
		qq[title like "\%$title%"],
		'order by time desc'
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
	# This should be the exact same format MySQL returns -- thebrain
	my($now) = $self->sqlSelect('SYSDATE','dual');

	return $now;
}

#sub getDay {

##################################################################
sub getStoryList {
	my($self) = @_;

	my $user = getCurrentUser();
	my $form = getCurrentForm();

	# CHANGE DATE_ FUNCTIONS
	my $sql = q[SELECT storiestuff.hits, commentcount, stories.sid, title, user_id,
			TO_CHAR(time,'HH24:MI') as t,tid,section,
			displaystatus,writestatus,
			TO_CHAR(time,'Day Month DD'),
			TO_CHAR(time,'MM/DD')
			FROM stories,storiestuff
			WHERE storiestuff.sid=stories.sid];
	$sql .= "	AND section='$user->{section}'" if $user->{section};
	$sql .= "	AND section='$form->{section}'" if $form->{section} && !$user->{section};
	$sql .= "	AND time < SYSDATE + 3 " if $form->{section} eq "";
	$sql .= "	ORDER BY time DESC";

	my $cursor = $self->{_dbh}->prepare($sql);
	$cursor->execute;
	my $list = $cursor->fetchall_arrayref;

	return $list;
}

#sub getPollVotesMax {
#sub _saveExtras {
#sub getStory {

########################################################
sub getAuthor {
	my($self, $id, $values, $cache_flag) = @_;
	my $table = 'authors';
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

	# Lets go knock on the door of the database
	# and grab the data's since it is not cached
	# On a side note, I hate grabbing "*" from a database
	# -Brian
	$self->{$table_cache}{$id} = {};
	my $answer = $self->sqlSelectHashref('users.user_id as user_id,nickname,fakeemail,homepage,bio', 
		'users,users_info', 'users.user_id=' . $self->{_dbh}->quote($id) . ' AND users.user_id = users_info.user_id');
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
# This of course is modified from the norm
sub getAuthors {
	my($self, $cache_flag) = @_;

	my $table = 'authors';
	my $table_cache= '_' . $table . '_cache';
	my $table_cache_time= '_' . $table . '_cache_time';
	my $table_cache_full= '_' . $table . '_cache_full';

	if (keys %{$self->{$table_cache}} && $self->{$table_cache_full} && !$cache_flag) {
		my %return = %{$self->{$table_cache}};
		return \%return;
	}

	$self->{$table_cache} = {};
	my $sth = $self->sqlSelectMany('users.user_id,nickname,fakeemail,homepage,bio',
		'users,users_info,users_param',
		'users_param.name="author" and users_param.value = 1 and ' .
		'users.user_id = users_param.user_id and users.user_id = users_info.uid');
	while (my $row = $sth->fetchrow_hashref('NAME_lc')) {
		# Fix column names -- thebrain
		@$row{'uid'} = @$row{'user_id'}; delete @$row{'user_id'};
		$self->{$table_cache}{ $row->{'uid'} } = $row;
	}

	$self->{$table_cache_full} = 1;
	$sth->finish;
	$self->{$table_cache_time} = time();

	my %return = %{$self->{$table_cache}};
	return \%return;
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
	my $sth = $self->sqlSelectMany('users.user_id,nickname,fakeemail,homepage,bio',
		'users,users_info', 'seclev >= 100 and users.user_id = users_info.user_id');
	while (my $row = $sth->fetchrow_hashref('NAME_lc')) {
		# Fix column names -- thebrain
		@$row{'uid'} = @$row{'user_id'}; delete @$row{'user_id'};
		$self->{$table_cache}{ $row->{'uid'} } = $row;
	}

	$self->{$table_cache_full} = 1;
	$sth->finish;
	$self->{$table_cache_time} = time();

	my %return = %{$self->{$table_cache}};
	return \%return;
}

#sub getPollQuestion {
#sub getDiscussion {
#sub getBlock {
#sub _getTemplateNameCache {
#sub getTemplate {
#sub getTemplateByName {
#sub getTopic {
#sub getTopics {
#sub getTemplates {
#sub getContentFilter {

########################################################
sub getSubmission {
	my $self = shift;
	# Nasty hack for column name change (i'm getting sick of these) -- thebrain
	if (ref($_[1]) eq 'ARRAY') {
		for (@{$_[1]}) {
			$_ = 'comment_text' if $_ eq 'comment';
		}
	}
	my $answer = $self->_genericGet('submissions', 'subid', '', @_);
	if (exists $answer->{comment_text}) {
		$answer->{comment} = $answer->{comment_text}; delete $answer->{comment_text};
	}
	return $answer;
}

#sub getSection {
#sub getSections {
#sub getModeratorLog {
#sub getNewStory {
#sub getVar {

########################################################
# The only change is s/uid/user_id/ -- grrrrr -- thebrain
sub setUser {
	my($self, $uid, $hashref) = @_;
	my(@param, %update_tables, $cache);
	my $tables = [qw(
		users users_comments users_index
		users_info users_prefs
	)];

	# special cases for password, exboxes
	if (exists $hashref->{passwd}) {
		# get rid of newpasswd if defined in DB
		$hashref->{newpasswd} = '';
		$hashref->{passwd} = encryptPassword($hashref->{passwd});
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

	$cache = $self->_genericGetCacheName($tables);

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
		$self->sqlUpdate($table, \%minihash, 'user_id=' . $uid, 1);
	}
	# What is worse, a select+update or a replace?
	# I should look into that.
	for (@param)  {
		$self->sqlReplace('users_param', { user_id => $uid, name => $_->[0], value => $_->[1]})
			if defined $_->[1];
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
		users_info users_prefs
	)];
	# The sort makes sure that someone will always get the cache if
	# they have the same tables
	my $cache = $self->_genericGetCacheName($tables);

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
			$where .= "$_.user_id=$id AND ";
		}
		$where =~ s/ AND $//;

		$table = join ',', keys %tables;
		$answer = $self->sqlSelectHashref($values, $table, $where);

		# The system expects uid, not user_id, so munge it back
		# wonder if this will screw something -- thebrain
		if (exists $answer->{user_id}) {
			$answer->{uid} = $answer->{user_id};
			delete $answer->{user_id};
		}

		for (@param) {
			my $val = $self->sqlSelect('value', 'users_param', "user_id=$id AND name='$_'");
			$answer->{$_} = $val;
		}

	} elsif ($val) {
		(my $clean_val = $val) =~ s/^-//;
		my $table = $self->{$cache}{$clean_val};
		if ($table) {
			($answer) = $self->sqlSelect($val, $table, "user_id=$id");
		} else {
			($answer) = $self->sqlSelect('value', 'users_param', "user_id=$id AND name='$val'");
		}

	} else {
		my($where, $table, $append);
		for (@$tables) {
			$where .= "$_.user_id=$id AND ";
		}
		$where =~ s/ AND $//;

		$table = join ',', @$tables;
		$answer = $self->sqlSelectHashref('*', $table, $where);

		# See above -- thebrain
		if (exists $answer->{user_id}) {
			$answer->{uid} = $answer->{user_id};
			delete $answer->{user_id};
		}

		$append = $self->sqlSelectAll('name,value', 'users_param', "user_id=$id");
		for (@$append) {
			$answer->{$_->[0]} = $_->[1];
		}
	}

	return $answer;
}

#sub _genericGetCacheName {
#sub _genericSet {
#sub _genericCacheRefresh {
#sub _genericGetCache {
#sub _genericClearCache {
#sub _genericGet {
#sub _genericGetsCache {

########################################################
# This is protected and don't call it from your
# scripts directly.
sub _genericGets {
	my($self, $table, $table_prime, $param_table, $values) = @_;
	my(%return, $sth, $params);

	if (ref($values) eq 'ARRAY') {
		my $get_values;

		if ($param_table) {
			my $cache = $self->_genericGetCacheName($table);
			for (@$values) {
				(my $clean_val = $values) =~ s/^-//;
				if ($self->{$cache}{$clean_val}) {
					push @$get_values, $_;
				} else {
					my $val = $self->sqlSelectAll('$table_prime, name, value', $param_table, "name='$_'");
					for my $row (@$val) {
						push @$params, $row;
					}
				}
			}
		} else {
			$get_values = $values;
		}
		my $val = join ',', @$get_values;
		$val .= ",$table_prime" unless grep $table_prime, @$get_values;
		$sth = $self->sqlSelectMany($val, $table);
	} elsif ($values) {
		if ($param_table) {
			my $cache = $self->_genericGetCacheName($table);
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
		while (my $row = $sth->fetchrow_hashref('NAME_lc')) {
			if ($row->{'user_id'}) { $row->{'uid'} = $row->{'user_id'}; delete $row->{'user_id'} };
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

#sub getStories {
#sub getSessions {
#sub createBlock {

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
	$self->sqlInsert('templates', $hash, {
		template => { ora_type => ORA_CLOB, ora_field => 'template' }
	} );
	my($tpid) = $self->sqlSelect('seq_templates.currval','dual');
	return $tpid;
}

#sub createMenuItem {

########################################################
sub getMenuItems {
	my($self, $script) = @_;
	my $sql = "SELECT * FROM menus WHERE page=" . $self->{_dbh}->quote($script) . "ORDER by menuorder";
	my $sth = $self->{_dbh}->prepare($sql);
	$sth->execute();
	my(@menu, $row);
	push(@menu, $row) while ($row = $sth->fetchrow_hashref('NAME_lc'));
	$sth->finish;

	return \@menu;
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
		$sql = "SELECT * FROM menus WHERE menu=" . $self->{_dbh}->quote($script) . "ORDER by menuorder";
		$sth =	$self->{_dbh}->prepare($sql);
		$sth->execute();
		my(@menu, $row);
		push(@menu, $row) while ($row = $sth->fetchrow_hashref('NAME_lc'));
		$sth->finish;
		$menus->{$script} = \@menu;
	}

	return $menus;
}

########################################################
# leet haxoring to emulate MySQL's REPLACE function -- thebrain
# Try an insert; if it throws ORA-00001, see what constraint
# got violated and update using its columns as the match keys
sub sqlReplace {
	my($self, $table, $data) = @_;

	my($sth,$sql,$binds) = $self->_sqlPrepareInsert($table,$data);
	$sth->{PrintError} = 0;
	if (!$sth->execute(@$binds)) {
		if ($sth->err == 1) {
			my($cname) = ($sth->errstr =~ /unique constraint \([^\.]+\.([^\)]+)\) violated/)[0];
			die "wtf: error string match failed, can't derive constraint name to analyze" unless $cname;
			my $keycols = $self->{_dbh}->selectcol_arrayref('SELECT LOWER(column_name) FROM user_cons_columns WHERE constraint_name = ?',undef,$cname);
			die "wtf: query on constraint $cname returned no columns (did we get the name wrong?)" unless @$keycols;
			my $datacopy = { %$data };
			my @where = ();
			my @wherebinds = ();
			foreach my $col (@$keycols) {
				next KEY if !exists $datacopy->{$col};
				push @where, "$col = ?";
				push @wherebinds, $datacopy->{$col};
				delete $datacopy->{$col};
			}
			my $where = join(' AND ',@where);
			my $rv = $self->sqlUpdate($table, $datacopy, $where, \@wherebinds);
			die "wtf: sqlReplace didn't insert or update anything" if $rv == 0;
		} else {
			errorLog($self->sqlFillInPlaceholders($sql,$binds));
			$self->sqlConnect;
		}
	}
}

#sub getKeys {

########################################################
sub sqlTableExists {
	my($self, $table) = @_;
	return unless $table;

	$self->sqlConnect();
	my $tab = $self->{_dbh}->selectrow_array('SELECT LOWER(table_name) FROM user_tables WHERE table_name LIKE ?',undef,uc($table));
	return $tab;
}

########################################################
sub sqlSelectColumns {
	my($self, $table) = @_;
	return unless $table;

	$self->sqlConnect();
	my $rows = $self->{_dbh}->selectcol_arrayref('SELECT LOWER(column_name) FROM user_tab_columns WHERE table_name = ? ORDER BY column_id',undef,uc($table));
	return $rows;
}

1;

__END__

=head1 NAME

Slash::DB::Oracle - Oracle Interface for Slash

=head1 SYNOPSIS

  use Slash::DB::Oracle;

=head1 DESCRIPTION

No documentation yet.

=head1 SEE ALSO

Slash(3), Slash::DB(3).

=cut

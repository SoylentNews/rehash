# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::DB::Static::Oracle;
use strict;
use DBIx::Password;
use Slash::DB::Utility;
use Slash::Utility;
use URI ();
use vars qw($VERSION);

use base 'Slash::DB::Oracle';
use base 'Slash::DB::Static::MySQL';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

########################################################
# for slashd
# This method is used in a pretty wasteful way
sub getBackendStories {
	my($self, $section) = @_;

	my $cursor = $self->{_dbh}->prepare("SELECT stories.sid,title,time,dept,user_id,alttext,
		image,commentcount,section,introtext,bodytext,hitparade,
		topics.tid as tid
		    FROM stories,topics
		   WHERE ((displaystatus = 0 and \"$section\"=\"\")
		      OR (section=\"$section\" and displaystatus > -1))
		     AND time < SYSDATE
		     AND writestatus > -1
		     AND stories.tid=topics.tid
		ORDER BY time DESC");

		  # AND time < date_add(now(), INTERVAL 4 HOUR)

	$cursor->execute;
	my $returnable = [];
	my $row;
	my $limit = 10;
	push(@$returnable, $row) while ($limit-- and $row = $cursor->fetchrow_hashref('NAME_lc'));

	return $returnable;
}

#sub updateCommentTotals {

########################################################
# For slashd
sub setStoryIndex {
	my($self, @sids) = @_;

	my %stories;

	for my $sid (@sids) {
		$stories{$sid} = $self->sqlSelectHashref("*","stories","sid='$sid'");
	}
	$self->{_dbh}->{AutoCommit} = 0;
	$self->{_dbh}->do("LOCK TABLE newstories IN EXCLUSIVE MODE");

	foreach my $sid (keys %stories) {
		$self->sqlReplace("newstories", $stories{$sid}, "sid='$sid'");
	}
	# Unlock table
	$self->{_dbh}->commit;
	$self->{_dbh}->{AutoCommit} = 1;
}

########################################################
# For slashd
sub getNewStoryTopic {
	my($self) = @_;

	my $returnable = $self->sqlSelectAll(
				"alttext,image,width,height,newstories.tid",
				"newstories,topics",
				"newstories.tid=topics.tid
				AND displaystatus = 0
				AND writestatus >= 0
				AND time < SYSDATE
				ORDER BY time DESC");

	return $returnable;
}

#sub getStoriesForSlashdb {

########################################################
# For dailystuff
sub deleteDaily {
	my ($self) = @_;
	my $constants = getCurrentStatic();

	my $delay1 = $constants->{archive_delay} * 2;
	my $delay2 = $constants->{archive_delay} * 9;
	$constants->{defaultsection} ||= 'articles';

	my($d) = $self->sqlSelect("ROUND(SYSDATE,'DD') - ROUND(lastmm,'DD')",

	$self->sqlDo("DELETE FROM newstories WHERE
			(section='$constants->{defaultsection}' and ROUND(SYSDATE,'DD') - ROUND(time,'DD') > $delay1)
			or (ROUND(SYSDATE,'DD') - ROUND(time,'DD') > $delay2)");

#	$self->sqlDo("DELETE FROM comments where to_days(now()) - to_days(date) > $constants->{archive_delay}");

	# Now for some random stuff
	$self->sqlDo("DELETE from pollvoters");
# why are these commented out?
#	$self->sqlDo("DELETE from moderatorlog WHERE
#	  to_days(now()) - to_days(ts) > $constants->{archive_delay} ");
#	$self->sqlDo("DELETE from metamodlog WHERE
#		to_days(now()) - to_days(ts) > $constants->{archive_delay} ");
	# Formkeys
	my $delete_time = time() - $constants->{'formkey_timeframe'};
	$self->sqlDo("DELETE FROM formkeys WHERE ts < $delete_time");
	$self->sqlDo("DELETE FROM accesslog WHERE date_add(ts,interval 48 hour) < now()");
}

########################################################
# For dailystuff
sub countDaily {
	my ($self) = @_;
	my %returnable;

	my $constants = getCurrentStatic();

	($returnable{'total'}) = $self->sqlSelect("count(*)", "accesslog",
		"ROUND(SYSDATE,'DD') - ROUND(ts,'DD')=1");

	my $c = $self->sqlSelectMany("count(*)","accesslog",
		"ROUND(SYSDATE,'DD') - ROUND(ts,'DD')=1 GROUP BY host_addr");
	$returnable{'unique'} = $c->rows;
	$c->finish;

#	my ($comments) = $self->sqlSelect("count(*)","accesslog",
#		"to_days(now()) - to_days(ts)=1 AND op='comments'");

	$c = $self->sqlSelectMany("dat,count(*)","accesslog",
		"ROUND(SYSDATE,'DD') - ROUND(ts,'DD')=1 AND 
		(op='index' OR dat='index')
		GROUP BY dat");

	my(%indexes, %articles, %commentviews);

	while(my($sect, $cnt) = $c->fetchrow) {
		$indexes{$sect} = $cnt;
	}
	$c->finish;

	$c = $self->sqlSelectMany("dat,count(*),op","accesslog",
		"ROUND(SYSDATE,'DD') - ROUND(ts,'DD')=1 AND op='article'",
		"GROUP BY dat");

	while(my($sid, $cnt) = $c->fetchrow) {
		$articles{$sid} = $cnt;
	}
	$c->finish;

	# clean the key table


	$c = $self->sqlSelectMany("dat,count(*)","accesslog",
		"ROUND(SYSDATE,'DD') - ROUND(ts,'DD')=1 AND op='comments'",
		"GROUP BY dat");
	while(my($sid, $cnt) = $c->fetchrow) {
		$commentviews{$sid} = $cnt;
	}
	$c->finish;

	$returnable{'index'} = \%indexes;
	$returnable{'articles'} = \%articles;


	return \%returnable;
}

########################################################
# For dailystuff
sub updateStamps {
	my ($self) = @_;
	my $columns = "user_id";
	my $tables = "accesslog";
	my $where = "ROUND(SYSDATE,'DD') - ROUND(ts,'DD')=1 AND user_id > 0";
	my $other = "GROUP BY user_id";

	my $E = $self->sqlSelectAll($columns, $tables, $where, $other);

	$self->{_dbh}->{AutoCommit} = 0;
	$self->{_dbh}->do("LOCK TABLE users_info IN EXCLUSIVE MODE");

	for (@{$E}) {
		my $uid=$_->[0];
		$self->setUser($uid, {-lastaccess=>'SYSDATE'});
	}
	# Unlock table
	$self->{_dbh}->commit;
	$self->{_dbh}->{AutoCommit} = 1;
}

########################################################
# For dailystuff
sub getDailyMail {	
	my ($self) = @_;
	my $columns = "sid,title,section,users.nickname,tid,time,dept";
	my $tables = "stories,users";
	my $where = "users.user_id = stories.user_id AND ROUND(SYSDATE,'DD') - ROUND(time,'DD') = 1 AND displaystatus=0 AND time < SYSDATE";
	my $other = " ORDER BY time DESC";

	my $email = $self->sqlSelectAll($columns,$tables,$where,$other);

	return $email;
}

########################################################
# For dailystuff
sub getMailingList {
	my($self) = @_;

	my $columns ="realemail,mode,nickname";
	my $tables = "users,users_comments,users_info";
	my $where = "users.user_id=users_comments.user_id AND users.user_id=users_info.user_id AND maillist=1";
	my $other = "order by realemail";

	my $users = $self->sqlSelectAll($columns,$tables,$where,$other);

	return $users;
}

#sub getOldStories {

########################################################
# For portald
sub getTop10Comments {
	my($self) = @_;
	my $c = $self->sqlSelectMany("stories.sid, title,
		cid, subject,date,nickname,comments.points",
		"comments,stories,users",
		"comments.points >= 4
		AND users.user_id=comments.user_id
		AND comments.sid=stories.sid
		ORDER BY date DESC");

	my $comments = [];
	my $limit = 10;
	while ($limit-- and my $row = $c->fetchrow) {
		push @$comments, [@$row];
	}
	$c->finish;

	formatDate($comments, 4, 4);

	return $comments;
}

#sub randomBlock {

########################################################
# For portald
# ugly method name
sub getAccesLogCountTodayAndYestarday {
	my($self) = @_;
	my $c = $self->sqlSelectMany("count(*), ROUND(SYSDATE,'DD') - ROUND(ts,'DD') as d",    "accesslog","","GROUP by d order by d asc");

	my($today) = $c->fetchrow;
	my($yesterday) = $c->fetchrow;
	$c->finish;
	
	return ($today, $yesterday);

}

#sub getSitesRDF {
#sub getSectionMenu2{

########################################################
# For portald
sub getSectionMenu2Info{
	my($self, $section) = @_;
	my $sth = $self->{_dbh}->prepare(
			"select to_date('MM',time), to_date('DD',time) from stories where " .
			"section='$section' and time < SYSDATE and displaystatus > -1 order by ".
			"time desc");
	$sth->execute;
	my($month, $day) = $sth->fetchrow_array;
	my($count) = $self->{_dbh}->selectrow_array(
			"select count(*) from stories where section='$section' and " .
			"ROUND(SYSDATE,'DD') - ROUND(time,'DD') <= 2 and time < SYSDATE and " .
			"displaystatus > -1");

	return($month, $day, $count);
}

########################################################
# For moderatord
sub tokens2points {
	my($self) = @_;
	my $constants = getCurrentStatic();
	my @log;
	my $c = $self->sqlSelectMany("user_id,tokens", "users_info", "tokens >= $constants->{maxtokens}");

	$self->{_dbh}->{AutoCommit} = 0;
	$self->{_dbh}->do("LOCK TABLE users IN EXCLUSIVE MODE");
	$self->{_dbh}->do("LOCK TABLE users_info IN EXCLUSIVE MODE");
	$self->{_dbh}->do("LOCK TABLE users_comments IN EXCLUSIVE MODE");

	while (my($uid, $tokens) = $c->fetchrow) {
		push @log, ("Giving $constants->{maxtokens}/$constants->{tokensperpoint} " .
			($constants->{maxtokens}/$constants->{tokensperpoint}) . " to $uid");
		$self->setUser($uid, {
			-lastgranted	=> 'now()',
			-tokens		=> "tokens - $constants->{maxtokens}",
			-points		=> "points +" . ($constants->{maxtokens} / $constants->{tokensperpoint})
		});
	}

	$c->finish;

	$c = $self->sqlSelectMany("users.user_id as user_id", "users,users_comments,users_info",
		"karma > -1 AND
		 points > 5 AND 
		 seclev < 100 AND
		 users.user_id=users_comments.user_id AND
		 users.user_id=users_info.user_id");

	while (my($uid) = $c->fetchrow) {
		$self->sqlUpdate("users_comments", { points => 5 } ,"user_id=$uid");
	}
	# Unlock table
	$self->{_dbh}->commit;
	$self->{_dbh}->{AutoCommit} = 1;

	return \@log;
}

########################################################
# For moderatord
sub stirPool {
	my($self) = @_;
	my $stir = getCurrentStatic('stir');
	my $c = $self->sqlSelectMany("points,users.user_id as user_id",
			"users,users_comments,users_info",
			"users.user_id=users_comments.user_id AND
			 users.user_id=users_info.user_id AND
			 seclev = 0 AND
			 points > 0 AND
			 ROUND(SYSDATE,'DD') - ROUND(lastgranted,'DD') > $stir");

	my $revoked = 0;

	$self->{_dbh}->{AutoCommit} = 0;
	$self->{_dbh}->do("LOCK TABLE users_comments IN EXCLUSIVE MODE");

	while (my($p, $u) = $c->fetchrow) {
		$revoked += $p;
		$self->sqlUpdate("users_comments", { points => '0' }, "user_id=$u");
	}

	# Unlock table
	$self->{_dbh}->commit;
	$self->{_dbh}->{AutoCommit} = 1;
	$c->finish;
	return 0;
}

########################################################
# For moderatord
sub getUserLast {
	my($self) = @_;
	my($totalusers) = $self->sqlSelect("max(user_id)", "users_info");

	return $totalusers;
}

#sub pagesServed {
#sub maxAccessLog {

########################################################
# For tailslash
sub getAccessLogInfo {
	my ($self, $id) = @_;
	my $returnable = $self->sqlSelectAll("host_addr,user_id,op,dat,
				TO_CHAR(ts,'HH24:MI') as ts,id",
				"accesslog","id > $id",
				"ORDER BY ts DESC");

	return $returnable;
}

########################################################
# For moderatord
sub giveKarma {
	my($self, $eligibleusers, $tokenpool) = @_;
	my $c = $self->sqlSelectMany("users_info.user_id,count(*) as c",
			"users_info,users_prefs, accesslog",
			"users_info.user_id < $eligibleusers
			 AND users_info.user_id=accesslog.user_id 
			 AND users_info.user_id=users_prefs.user_id
			 AND (op='article' or op='comments')
			 AND willing=1
			 AND karma >= 0
			 GROUP BY users_info.user_id
			 ORDER BY c");

	my $eligible = $c->rows;
	my($uid, $cnt);
	while ((($uid,$cnt) = $c->fetchrow) && ($cnt < 4)) {
		$eligible--;
	}

	my($st, $fi) = (int($eligible / 6), int($eligible / 8) * 7);
	my $x;

	moderatordLog("Start at $st end at $fi.  $eligible left. First score is $cnt");

	my @eligibles;
	while (($x++ < $fi) && (($uid, $cnt) = $c->fetchrow)) {
		next if $x < $st;
		push @eligibles, $uid;
	}
	$c->finish;

	my @scores;
	for (my $x = 0; $x < $tokenpool; $x++) {
		$scores[$eligibles[rand @eligibles]]++;
	}

	$self->{_dbh}->{AutoCommit} = 0;
	$self->{_dbh}->do("LOCK TABLE users_info IN EXCLUSIVE MODE");
	for (@eligibles) {
		next unless $scores[$uid];
		$self->setUser($uid, { 
			-tokens	=> "tokens+" . $scores[$uid]
		});
	}
	# Unlock table
	$self->{_dbh}->commit;
	$self->{_dbh}->{AutoCommit} = 1;

	return("Start at $st end at $fi.  $eligible left. First score is $cnt");
}

1;

__END__

=head1 NAME

Slash::DB::Static::Oracle - Oracle Interface for Slash

=head1 SYNOPSIS

  use Slash::DB::Static::Oracle;

=head1 DESCRIPTION

No documentation yet. Sue me.

=head1 SEE ALSO

Slash(3), Slash::DB(3).

=cut

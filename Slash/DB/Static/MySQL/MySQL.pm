# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
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
use DBIx::Password;
use Slash::DB::Utility;
use Slash::Utility;
use URI ();
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# BENDER: Bite my shiny, metal ass! 

########################################################
# for slashd
# This method is used in a pretty wasteful way
sub getBackendStories {
	my($self, $section) = @_;

	my $cursor = $self->{_dbh}->prepare("SELECT stories.sid,title,time,dept,uid,alttext,
		image,commentcount,section,introtext,bodytext,hitparade,
		topics.tid as tid
		    FROM stories,topics
		   WHERE ((displaystatus = 0 and \"$section\"=\"\")
		      OR (section=\"$section\" and displaystatus > -1))
		     AND time < now()
		     AND writestatus > -1
		     AND stories.tid=topics.tid
		ORDER BY time DESC
		   LIMIT 10");

		  # AND time < date_add(now(), INTERVAL 4 HOUR)

	$cursor->execute;
	my $returnable = [];
	my $row;
	push(@$returnable, $row) while ($row = $cursor->fetchrow_hashref);

	return $returnable;
}

########################################################
# This is only call if ssi is set
sub updateCommentTotals {
	my($self, $sid, $comments) = @_;
	my $hp = join ',', @{$comments->[0]{totals}};
	$self->sqlUpdate("stories", {
			hitparade	=> $hp,
			writestatus	=> 0,
			commentcount	=> $comments->[0]{totals}[0]
		}, 'sid=' . $self->{_dbh}->quote($sid)
	);
	$self->sqlUpdate("newstories", {
			hitparade	=> $hp,
			writestatus	=> 0,
			commentcount	=> $comments->[0]{totals}[0]
		}, 'sid=' . $self->{_dbh}->quote($sid)
	);
}

########################################################
# For slashd
sub setStoryIndex {
	my($self, @sids) = @_;

	my %stories;

	for my $sid (@sids) {
		$stories{$sid} = $self->sqlSelectHashref("*","stories","sid='$sid'");
	}
	$self->sqlTransactionStart("LOCK TABLES newstories WRITE");

	foreach my $sid (keys %stories) {
		$self->sqlReplace("newstories", $stories{$sid}, "sid='$sid'");
	}

	$self->sqlTransactionFinish();
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
				AND time < now()
				ORDER BY time DESC");

	return $returnable;
}

########################################################
# For slashd
sub getStoriesForSlashdb {
	my($self, $writestatus) = @_;

	my $returnable = $self->sqlSelectAll("sid,title,section", 
			"stories", "writestatus=$writestatus");

	return $returnable;
}

########################################################
# For dailystuff
sub deleteDaily {
	my ($self) = @_;
	my $constants = getCurrentStatic();

	my $delay1 = $constants->{archive_delay} * 2;
	my $delay2 = $constants->{archive_delay} * 9;
	$constants->{defaultsection} ||= 'articles';

	$self->sqlDo("DELETE FROM newstories WHERE
			(section='$constants->{defaultsection}' and to_days(now()) - to_days(time) > $delay1)
			or (to_days(now()) - to_days(time) > $delay2)");

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
		"to_days(now()) - to_days(ts)=1");

	my $c = $self->sqlSelectMany("count(*)","accesslog",
		"to_days(now()) - to_days(ts)=1 GROUP BY host_addr");
	$returnable{'unique'} = $c->rows;
	$c->finish;

#	my ($comments) = $self->sqlSelect("count(*)","accesslog",
#		"to_days(now()) - to_days(ts)=1 AND op='comments'");

	$c = $self->sqlSelectMany("dat,count(*)","accesslog",
		"to_days(now()) - to_days(ts)=1 AND 
		(op='index' OR dat='index')
		GROUP BY dat");

	my(%indexes, %articles, %commentviews);

	while(my($sect, $cnt) = $c->fetchrow) {
		$indexes{$sect} = $cnt;
	}
	$c->finish;

	$c = $self->sqlSelectMany("dat,count(*),op","accesslog",
		"to_days(now()) - to_days(ts)=1 AND op='article'",
		"GROUP BY dat");

	while(my($sid, $cnt) = $c->fetchrow) {
		$articles{$sid} = $cnt;
	}
	$c->finish;

	# clean the key table


	$c = $self->sqlSelectMany("dat,count(*)","accesslog",
		"to_days(now()) - to_days(ts)=1 AND op='comments'",
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
	my $columns = "uid";
	my $tables = "accesslog";
	my $where = "to_days(now())-to_days(ts)=1 AND uid > 0";
	my $other = "GROUP BY uid";

	my $E = $self->sqlSelectAll($columns, $tables, $where, $other);

	$self->sqlTransactionStart("LOCK TABLES users_info WRITE");

	for (@{$E}) {
		my $uid=$_->[0];
		$self->setUser($uid, {-lastaccess=>'now()'});
	}
	$self->sqlTransactionFinish();
}

########################################################
# For dailystuff
sub getDailyMail {	
	my ($self) = @_;
	my $columns = "sid,title,section,users.nickname,tid,time,dept";
	my $tables = "stories,users";
	my $where = "users.uid = stories.uid AND to_days(now()) - to_days(time) = 1 AND displaystatus=0 AND time < now()";
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
	my $where = "users.uid=users_comments.uid AND users.uid=users_info.uid AND maillist=1";
	my $other = "order by realemail";

	my $users = $self->sqlSelectAll($columns,$tables,$where,$other);

	return $users;
}

########################################################
# For dailystuff
#sub getOldStories {
#	my($self, $delay) = @_;
#
#	my $columns = "sid,time,section,title";
#	my $tables = "stories";
#	my $where = "writestatus<5 AND writestatus >= 0 AND to_days(now()) - to_days(time) > $delay";
#
#	my $stories = $self->sqlSelectAll($columns,$tables,$where);
#
#	return $stories;
#}

########################################################
# For portald
sub getTop10Comments {
	my($self) = @_;
	my $c = $self->sqlSelectMany("stories.sid, title,
		cid, subject,date,nickname,comments.points",
		"comments,stories,users",
		"comments.points >= 4
		AND users.uid=comments.uid
		AND comments.sid=stories.sid
		ORDER BY date DESC limit 10");

	my $comments = $c->fetchall_arrayref;
	$c->finish;

	formatDate($comments, 4, 4);

	return $comments;
}

########################################################
# For portald
sub randomBlock {
	my($self) = @_;
	my $c = $self->sqlSelectMany("bid,title,url,block",
		"blocks",
		"section='index'
		AND portal=1
		AND ordernum < 0");

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
sub getAccesLogCountTodayAndYestarday {
	my($self) = @_;
	my $c = $self->sqlSelectMany("count(*), to_days(now()) - to_days(ts) as d",    "accesslog","","GROUP by d order by d asc");

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
# For portald
sub getSectionMenu2{
	my($self) = @_;
	my $menu = $self->sqlSelectAll("section","sections",
	    "isolate=0 and (section != '' and section != 'articles')
			    ORDER BY section");

	return $menu;
}
########################################################
# For portald
sub getSectionMenu2Info{
	my($self, $section) = @_;
	my($month, $day) = $self->{_dbh}->selectrow_array(
			"select month(time), dayofmonth(time) from stories where " .
			"section='$section' and time < now() and displaystatus > -1 order by ".
			"time desc limit 1");
	my($count) = $self->{_dbh}->selectrow_array(
			"select count(*) from stories where section='$section' and " .
			"to_days(now()) - to_days(time) <= 2 and time < now() and " .
			"displaystatus > -1");

	return($month, $day, $count);
}

########################################################
# For moderatord
sub tokens2points {
	my($self) = @_;
	my $constants = getCurrentStatic();
	my @log;
	my $c = $self->sqlSelectMany("uid,tokens", "users_info", "tokens >= $constants->{maxtokens}");
	$self->sqlTransactionStart("LOCK TABLES users READ, users_info WRITE, users_comments WRITE");

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

	$c = $self->sqlSelectMany("users.uid as uid", "users,users_comments,users_info",
		"karma > -1 AND
		 points > 5 AND 
		 seclev < 100 AND
		 users.uid=users_comments.uid AND
		 users.uid=users_info.uid");
	$self->sqlTransactionFinish();

	$self->sqlTransactionStart("LOCK TABLES users_comments WRITE");
	while (my($uid) = $c->fetchrow) {
		$self->sqlUpdate("users_comments", { points => 5 } ,"uid=$uid");
	}
	$self->sqlTransactionFinish();

	return \@log;
}

########################################################
# For moderatord
sub stirPool {
	my($self) = @_;
	my $stir = getCurrentStatic('stir');
	my $c = $self->sqlSelectMany("points,users.uid as uid",
			"users,users_comments,users_info",
			"users.uid=users_comments.uid AND
			 users.uid=users_info.uid AND
			 seclev = 0 AND
			 points > 0 AND
			 to_days(now())-to_days(lastgranted) > $stir");

	my $revoked = 0;

	$self->sqlTransactionStart("LOCK TABLES users_comments WRITE");

	while (my($p, $u) = $c->fetchrow) {
		$revoked += $p;
		$self->sqlUpdate("users_comments", { points => '0' }, "uid=$u");
	}

	$self->sqlTransactionFinish();
	$c->finish;
	return 0;
}

########################################################
# For moderatord
sub getUserLast {
	my($self) = @_;
	my($totalusers) = $self->sqlSelect("max(uid)", "users_info");

	return $totalusers;
}

########################################################
# For tailslash
sub pagesServed {
	my ($self) = @_;
	my $returnable = $self->sqlSelectAll("count(*),ts",
			"accesslog", "1=1",
			"GROUP BY ts ORDER BY ts ASC");

	return $returnable;

}

########################################################
# For tailslash
sub maxAccessLog {
	my ($self) = @_;
	my ($returnable) = $self->sqlSelect("max(id)", "accesslog");;

	return $returnable;
}

########################################################
# For tailslash
sub getAccessLogInfo {
	my ($self, $id) = @_;
	my $returnable = $self->sqlSelectAll("host_addr,uid,op,dat,
				date_format(ts,\"\%H:\%i\") as ts,id",
				"accesslog","id > $id",
				"ORDER BY ts DESC");

	return $returnable;
}

########################################################
# For moderatord
sub giveKarma {
	my($self, $eligibleusers, $tokenpool) = @_;
	my $c = $self->sqlSelectMany("users_info.uid,count(*) as c",
			"users_info,users_prefs, accesslog",
			"users_info.uid < $eligibleusers
			 AND users_info.uid=accesslog.uid 
			 AND users_info.uid=users_prefs.uid
			 AND (op='article' or op='comments')
			 AND willing=1
			 AND karma >= 0
			 GROUP BY users_info.uid
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


	$self->sqlTransactionStart("LOCK TABLES users_info WRITE");
	for (@eligibles) {
		next unless $scores[$uid];
		$self->setUser($uid, { 
			-tokens	=> "tokens+" . $scores[$uid]
		});
	}
	$self->sqlTransactionFinish();

	return("Start at $st end at $fi.  $eligible left. First score is $cnt");
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

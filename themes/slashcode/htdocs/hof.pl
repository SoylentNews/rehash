#!/usr/bin/perl -w

###############################################################################
# hof.pl - this page displays statistics about stories posted to the site 
# 
# Copyright (C) 1997 Rob "CmdrTaco" Malda
# malda@slashdot.org
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#
#  $Id$
###############################################################################
use strict;
use lib '../';
use vars '%I';
use Slash;

##################################################################
sub main {
	*I = getSlashConf();
	getSlash();
	my $SECT=getSection($I{F}{section});

	header("$I{sitename}: Hall of Fame", $SECT->{section});

	my $storyDisp = sub { <<EOT };
<B><FONT SIZE=4>$_[3]</FONT></B>
<A HREF="$I{rootdir}/$_[2]/$_[0].shtml">$_[1]</A> by $_[4]<BR>
EOT

	# Top 10 Hit Generating Articles
	titlebar("98%", "Most Active Stories");
	displayCursor($storyDisp, sqlSelectMany(
		"sid,title,section,commentcount,aid",
		"stories","", "ORDER BY commentcount DESC LIMIT 10"
	));

	print "<P>";
	titlebar("98%", "Most Visited Stories");
	displayCursor($storyDisp,sqlSelectMany(
		"stories.sid,title,section,storiestuff.hits as hits,aid",
		"stories,storiestuff", "stories.sid=storiestuff.sid",
		"ORDER BY hits DESC LIMIT 10"
	));
	
	print "<P>";
	titlebar("98%", "Most Active Authors");
	displayCursor(sub { qq!<B>$_[0]</B> <A HREF="$_[2]">$_[1]</A><BR>! },
		sqlSelectMany("count(*) as c, stories.aid, url", "stories, authors",
			"authors.aid=stories.aid",
			"GROUP BY aid ORDER BY c DESC LIMIT 10"
		)
	);

	print "<P>";
	titlebar("98%", "Most Active Poll Topics");
	displayCursor(sub { qq!<B>$_[0]</B> <A HREF="$I{rootdir}/pollBooth.pl?qid=$_[2]">$_[1]</A><BR>! },
		sqlSelectMany("voters,question,qid",
			"pollquestions","1=1", "ORDER by voters DESC LIMIT 10"
		)
	);

	if (0) {  #  only do this in static mode
		print "<P>";
		titlebar("100%", "Most Popular Slashboxes");
		my $boxes = sqlSelectMany("bid,title", "sectionblocks", "portal=1");
		my(%b, %titles);

		while (my($bid, $title) = $boxes->fetchrow) {
			$b{$bid} = 1;
			$titles{$bid} = $title;
		}

		$boxes->finish;

		foreach my $bid (keys %b) {
			($b{$bid}) = sqlSelect("count(*)","users_index",
				qq!exboxes like "%'$bid'%" !
			);
		}

		my $x;
		foreach my $bid (sort { $b{$b} <=> $b{$a} } keys %b) {
			$x++;
			$titles{$bid} =~ s/<(.*?)>//g;
			print <<EOT;

<B>$b{$bid}</B> <A HREF="$I{rootdir}/users.pl?op=preview&bid=$bid">$titles{$bid}</A><BR>
EOT
			last if $x > 10;
		}
	}

	topComments();

	printf <<EOT, scalar localtime;
<BR><FONT SIZE="2"><CENTER>generated on %s</CENTER></FONT><BR>
EOT

	writelog("hof");
	footer($I{F}{ssi});
}

##################################################################
sub displayCursor {
	my($d, $c) = @_;
	return unless $c;
	while (@_ = $c->fetchrow) {
		print $d->(@_);
	}
	$c->finish;
}

##################################################################
sub topComments {
	# and SID, article title, type and a link to the article
	print "<P>";
	titlebar("100%","Top 10 Comments");
	my $sqlquery = "SELECT section, stories.sid, aid, title, pid, subject," .
		getDateFormat("date","d") . "," . getDateFormat("time","t") . 
		",uid, cid, points";
	$sqlquery .= "	  FROM stories, comments
			 WHERE stories.sid=comments.sid";
	$sqlquery .= "	   AND stories.sid=" . $I{dbh}->quote($I{F}{sid}) if $I{F}{sid};

	$sqlquery .= " ORDER BY points DESC, d DESC LIMIT 10 ";

	my $cursor = $I{dbh}->prepare($sqlquery);
	$cursor->execute;

	my $x = $I{F}{min};
	while (my($section, $sid, $aid, $title, $pid, $subj, $cdate, $sdate,
		$uid, $cid, $score) = $cursor->fetchrow) {
		my($cname, $cemail) = sqlSelect("nickname,fakeemail",
			"users","uid=$uid");

		print <<EOT;
<BR><B>$score</B>
	<A HREF="$I{rootdir}/comments.pl?sid=$sid&pid=$pid#$cid">$subj</A>
	by <A HREF="mailto:$cemail">$cname</A> on $cdate<BR>

	<FONT SIZE="2">attached to <A HREF="$I{rootdir}/$section/$sid.shtml">$title</A>
	posted on $sdate by $aid</FONT><BR>
EOT

	}

	$cursor->finish;
}

main();
$I{dbh}->disconnect if $I{dbh};

#!/usr/bin/perl -w

###############################################################################
# search.pl - this code is the search page 
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

#################################################################
sub main {
	*I = getSlashConf();
	getSlash();

	# Set some defaults
	$I{F}{query}	||= "";
	$I{F}{section}	||= "";
	$I{F}{op}	||= "";
	$I{F}{min}	||= "0";
	$I{F}{max}	||= "30";
	$I{F}{'last'}	||= $I{F}{min} + $I{F}{max};

	# don't echo bad characters back to browser
	$I{F}{html_query} = stripByMode($I{F}{query}, 'exttrans');

	header("$I{sitename}: Search $I{F}{html_query}", $I{F}{section});
	titlebar("99%", "Searching $I{F}{html_query}");

	searchForm();

	if	($I{F}{op} eq "comments")	{ commentSearch()	}
	elsif	($I{F}{op} eq "users")		{ userSearch()		}
	else					{ storySearch()		}
	writelog("search", $I{F}{query});
	footer();	
}

#################################################################
sub linkSearch {
	my $C = shift;
	my $r;

	foreach (qw[threshold html_query min author op sid topic section total]) {
		my $x = "";
		$x =  $C->{$_} if defined $C->{$_};
		$x =  $I{F}{$_} if defined $I{F}{$_} && !$x;
		$x =~ s/ /+/g;
		next if $x eq "";
		if ($_ eq 'html_query') {
			$r .= "query=$x&";
		} else {
			$r .= "$_=$x&";
		}
	}
	$r =~ s/&$//;

	$r = qq!<A HREF="$ENV{SCRIPT_NAME}?$r">$C->{'link'}</A>!;
}

#################################################################
sub keysearch {
	my $keywords = shift;
	my @columns = @_;

	$keywords =~ s/[^A-Z0-9'\. ]//gi;
	my @words = split m/ /, $keywords;
	my $sql;
	my $x = 0;

	foreach my $w (@words) {
		next if length $w < 3;
		last if $x++ > 3;
		foreach my $c (@columns) { 
			$sql .= "+" if $sql;
			$sql .= "($c LIKE " . $I{dbh}->quote("%$w%") . ")";
		}
	}
#	void context, does nothing?
#	substr $sql, 1, length($sql)-1;
	$sql = "0" unless $sql;
	$sql .= " as kw";
	return $sql;
}

#################################################################
sub searchForm {
	my $SECT = getSection($I{F}{section});

	my $t = lc $I{sitename};
	$t = $I{F}{topic} if $I{F}{topic};
	my $tref = getTopic($t);
	print <<EOT if $tref;

<IMG SRC="$I{imagedir}/topics/$tref->{image}"
	ALIGN="RIGHT" BORDER="0" ALT="$tref->{alttext}"
	HSPACE="30" VSPACE="10" WIDTH="$tref->{width}"
	HEIGHT="$tref->{height}">

EOT

	print <<EOT;
<FORM ACTION="$ENV{SCRIPT_NAME}" METHOD="POST">
	<INPUT TYPE="TEXT" NAME="query" VALUE="$I{F}{html_query}">
	<INPUT TYPE="SUBMIT" VALUE="Search">
EOT

	$I{F}{op} ||= "stories";
	my %ch;
	$ch{$I{F}{op}} = $I{F}{op} ? ' CHECKED' : '';

	print <<EOT;
	<INPUT TYPE="RADIO" NAME="op" VALUE="stories"$ch{stories}> Stories
	<INPUT TYPE="RADIO" NAME="op" VALUE="comments"$ch{comments}> Comments
	<INPUT TYPE="RADIO" NAME="op" VALUE="users"$ch{users}> Users<BR>

EOT

	if ($I{F}{op} eq "stories") {
		selectTopic("topic", $I{F}{topic});
		selectGeneric("authors", "author", "aid", "name", $I{F}{author});

	} elsif ($I{F}{op} eq "comments") {
		print <<EOT;
	Threshold <INPUT TYPE="TEXT" SIZE="3" NAME="threshold" VALUE="$I{U}{threshold}">
	<INPUT TYPE="HIDDEN" NAME="sid" VALUE="$I{F}{sid}">
EOT
	}

	selectSection("section", $I{F}{section}, $SECT)
		unless $I{F}{op} eq "users";
	print "\n<P></FORM>\n\n";
}

#################################################################
sub commentSearch {
	print <<EOT;
<P>This search covers the name, email, subject and contents of
each of the last 30,000 or so comments posted.  Older comments
are removed and currently only visible as static HTML.<P>
EOT
	
	$I{F}{min} = int $I{F}{min};
	my $prev = $I{F}{min} - 20;
	print linkSearch({
		'link'	=> "<B>$I{F}{min} previous matches...</B>",
		min	=> $prev
	}), "<P>" if $prev >= 0;
	
	# select comment ID, comment Title, Author, Email, link to comment
	# and SID, article title, type and a link to the article
	my $sqlquery = "SELECT section, newstories.sid, aid, title, pid, subject, writestatus," .
		getDateFormat("time","d") . ",".
		getDateFormat("date","t") . ", 
		uid, cid, ";

	$sqlquery .= "	  " . keysearch($I{F}{query}, "subject", "comment") if $I{F}{query};
	$sqlquery .= "	  1 as kw " unless $I{F}{query};
	$sqlquery .= "	  FROM newstories, comments
			 WHERE newstories.sid=comments.sid ";
	$sqlquery .= "     AND newstories.sid=" . $I{dbh}->quote($I{F}{sid}) if $I{F}{sid};
	$sqlquery .= "     AND points >= $I{U}{threshold} ";
	$sqlquery .= "     AND section=" . $I{dbh}->quote($I{F}{section}) if $I{F}{section};
	$sqlquery .= " ORDER BY kw DESC, date DESC, time DESC LIMIT $I{F}{min},20 ";

	if ($I{F}{sid}) {
		my($t) = sqlSelect("title", "newstories",
			"sid=" . $I{dbh}->quote($I{F}{sid})
		) || "discussion";

		printf "<B>Return to %s</B><P>", linkComment({
			sid	=> $I{F}{sid},
			pid	=> 0,
			subject	=> $t
		});
		print "</B><P>";
		return unless $I{F}{query};
	}

	my $cursor = $I{dbh}->prepare($sqlquery);
	$cursor->execute;

	my $x = $I{F}{min};
	while (my($section, $sid, $aid, $title, $pid, $subj, $ws, $sdate,
		$cdate, $uid, $cid, $match) = $cursor->fetchrow) {
		last if $I{F}{query} && !$match;
		$x++;

		my $href = $ws == 10
			? "$I{rootdir}/$section/$sid.shtml#$cid"
			: "$I{rootdir}/comments.pl?sid=$sid&pid=$pid#$cid";

		my($cname, $cemail) = sqlSelect("nickname,fakeemail", "users", "uid=$uid");
		printf <<EOT, $match ? $match : $x;
<BR><B>%s</B>
	<A HREF="$href">$subj</A>
	by <A HREF="mailto:$cemail">$cname</A> on $cdate<BR>
	<FONT SIZE="2">attached to <A HREF="$I{rootdir}/$section/$sid.shtml">$title</A> 
	posted on $sdate by $aid</FONT><BR>
EOT
	}

	$cursor->finish;

	print "No Matches Found for your query" unless $x > 0 || $I{F}{query};

	my $remaining = "";
	print "<P>", linkSearch({
		'link'	=> "<B>$remaining Matches Left</B>",
		min	=> $x
	}) unless $x - $I{F}{min} < 20;
}

#################################################################
sub userSearch {
	my $prev = int($I{F}{min}) - $I{F}{max};
	print linkSearch({
		'link'	=> "<B>$I{F}{min} previous matches...</B>",
		min	=> $prev
	}), "<P>" if $prev >=0;
	
	my $c = sqlSelectMany("fakeemail,nickname,uid," .
		keysearch($I{F}{query},"nickname"),
		"users", "", "ORDER BY kw DESC LIMIT 10"
	) if $I{F}{query};
	return unless $c;

	my $total = $c->{rows};
	my($x, $cnt) = 0;

	while(my $N = $c->fetchrow_hashref) {
		last unless $N->{kw};
		my $ln = $N->{nickname};
		$ln =~ s/ /+/g;

		my $fake = $N->{fakeemail} ? <<EOT : '';
	<A HREF="mailto:$N->{fakeemail}">$N->{fakeemail}</A>
EOT
		print <<EOT;
<LI><A HREF="$I{rootdir}/users.pl?nick=$ln">$N->{nickname}</A> &nbsp;
$fake	($N->{uid})</LI>
EOT

		$x++;
	}

	$c->finish;

	print "No Matches Found for your query" if $x < 1;

	my $remaining = $total - $I{F}{'last'};
	print linkSearch({
		'link'	=> "<B>$remaining matches left</B>",
		min	=> $I{F}{'last'}
	}) unless $x < $I{F}{max};
}

#################################################################
sub storySearch {
	my $prev = $I{F}{min} - $I{F}{max};
	print linkSearch({
		'link'	=> "<B>$I{F}{min} previous matches...</B>",
		min	=> $prev
	}), "<P>" if $prev >= 0;

	my $sqlquery = "SELECT aid,title,sid," .
			getDateFormat("time","t") .
			", commentcount,section ";
	$sqlquery .= "," . keysearch($I{F}{query}, "title", "introtext") . " "
		if $I{F}{query};
	$sqlquery .="	,0 " unless $I{F}{query};

	if ($I{F}{query}) {
		$sqlquery .= "  FROM stories ";
	} else {
		$sqlquery .= "  FROM newstories ";
	}

	$sqlquery .= $I{F}{section} ? <<EOT : 'WHERE displaystatus >= 0';
WHERE ((displaystatus = 0 and "$I{F}{section}"="")
        OR (section="$I{F}{section}" and displaystatus>=0))
EOT

	$sqlquery .= "   AND time < now() AND writestatus >= 0  ";
	$sqlquery .= "   AND aid="	. $I{dbh}->quote($I{F}{author})  if $I{F}{author};
	$sqlquery .= "   AND section="	. $I{dbh}->quote($I{F}{section}) if $I{F}{section};
	$sqlquery .= "   AND tid="	. $I{dbh}->quote($I{F}{topic})   if $I{F}{topic};

	$sqlquery .= " ORDER BY ";
	$sqlquery .= " kw DESC, " if $I{F}{query};
	$sqlquery .= " time DESC LIMIT $I{F}{min},$I{F}{max} ";

#	print "<P><TT>$sqlquery</TT></P>";

	my $cursor = $I{dbh}->prepare($sqlquery);
	$cursor->execute;

	my($x, $cnt) = 0;
	# print $sqlquery if $I{U}{uid}==1;
	print " ";

	while (my($aid, $title, $sid, $time, $commentcount, $section, $cnt) = 
		$cursor->fetchrow) {
		last if $cnt == 0 && $I{F}{query};
		print $cnt ? $cnt :  $x + $I{F}{min};
		print " ";
		print linkStory({
			section	=> $section,
			sid	=> $sid,
			'link'	=> "<B>$title</B>"
		}), qq! by $aid <FONT SIZE="2">on $time <b>$commentcount</b></FONT><BR>!;
		$x++;
	}

	$cursor->finish;

	print "No Matches Found for your query" if $x < 1;

	my $remaining = "";
	print "<P>", linkSearch({
		'link'	=> "<B>$remaining matches left</B>",
		min	=> $I{F}{'last'}
	}) unless $x < $I{F}{max};
}

main;
$I{dbh}->disconnect if $I{dbh};
1;

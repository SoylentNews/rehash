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
	$I{F}{threshold} ||= $I{U}{threshold};
	$I{F}{'last'}	||= $I{F}{min} + $I{F}{max};

	# get rid of bad characters
	$I{F}{query} =~ s/[^A-Z0-9\'. ]//gi;

	# Precounting the results, even on fast servers seems to cause severe 
	# performance problems, especially comment searching, where certain
	# table locks CAN'T be perform, hence making the httpds very unstable.
	# Counting is therefore removed until a solution can be determined. 
	#
	#countSearchHits($I{F}{op} || 'stories') if ! $I{F}{hitcount};
	#my $hitcount = "($I{F}{hitcount} total matches)" if $I{F}{hitcount};

	header("$I{sitename}: Search $I{F}{query}", $I{F}{section});
	titlebar("99%", "Searching $I{F}{query}");

	searchForm();

	if		($I{F}{op} eq "comments")	{ commentSearch()	}
	elsif	($I{F}{op} eq "users")		{ userSearch()		}
	elsif	($I{F}{op} eq "stories")	{ storySearch()		}
	else	{
		print "Invalid operation!<BR>";
	}
	writelog("search", $I{F}{query})
		if $I{F}{op} =~ /^(comments|stories|users)$/;
	footer();	
}

#################################################################
sub linkSearch {
	my $C = shift;
	my $r;

	foreach (qw[threshold query min author op sid topic section total hitcount]) {
		my $x = "";
		$x =  $C->{$_} if defined $C->{$_};
		$x =  $I{F}{$_} if defined $I{F}{$_} && $x eq "";
		$x =~ s/ /+/g;
		$r .= "$_=$x&" unless $x eq "";
	}
	$r =~ s/&$//;

	$r = qq!<A HREF="$ENV{SCRIPT_NAME}?$r">$C->{'link'}</A>!;
}

#################################################################
sub keysearch {
	my $keywords = shift;
	my @columns = @_;

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


sub countSearchHits {
	my $searchtype = shift;
	my($sqlquery, $kw) = ('SELECT count(*) ', '');

	if ($searchtype eq 'comments') {
		$kw = keysearch($I{F}{query}, 'subject', 'comment');
		$sqlquery .= "FROM newstories, comments WHERE ";
		$sqlquery .= "newstories.sid=" . $I{dbh}->quote($I{F}{sid}) . " AND "
			if $I{F}{sid};
		$sqlquery .= "points >= $I{F}{threshold} ";
		$sqlquery .= "AND section=" . $I{dbh}->quote($I{F}{section})
			if $I{F}{section};
		$sqlquery .= " AND" if $I{F}{query};
	} elsif ($searchtype eq 'users') {
		$kw = keysearch($I{F}{query}, 'nickname', 'fakeemail');
		$sqlquery .= "FROM users ";
		$sqlquery .= "WHERE " if $I{F}{query};
	} elsif ($searchtype eq 'stories') {
		$kw = keysearch($I{F}{query}, 'title', 'introtext');
		$sqlquery .= '  FROM stories ';
		$sqlquery .= $I{F}{section} ? <<EOT : 'WHERE displaystatus >= 0';
WHERE ((displaystatus = 0 and "$I{F}{section}"="")
        OR (section="$I{F}{section}" and displaystatus>=0))
EOT

		$sqlquery .= "   AND time < now() AND writestatus >= 0  ";
		$sqlquery .= "   AND aid=" . $I{dbh}->quote($I{F}{author})
			if $I{F}{author};
		$sqlquery .= "   AND section="	. $I{dbh}->quote($I{F}{section})
			if $I{F}{section};
		$sqlquery .= "   AND tid="	. $I{dbh}->quote($I{F}{topic})
			if $I{F}{topic};
		$sqlquery .= " AND " if $I{F}{query};
	}
	if ($I{F}{query}) {
		$kw =~ s/as kw$//;
		$kw =~ s/\+/ OR /g;
		$sqlquery .= " ($kw)";
	}

	my $cursor = $I{dbh}->prepare($sqlquery);
	$cursor->execute;
	($I{F}{hitcount}) = $cursor->fetchrow;

#	$I{F}{mycountingquery} = "($I{F}{hitcount}) <= $sqlquery<BR>";
}

#################################################################
sub searchForm {
	my $SECT = getSection($I{F}{section});

	# Count the number of hits for the entire search if we haven't
	# done so and we have keywords to search with.
#	print "<TT>$I{F}{mycountingquery}</TT><BR>" if $I{F}{mycountingquery};

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
	<INPUT TYPE="TEXT" NAME="query" VALUE="$I{F}{query}">
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
	Threshold <INPUT TYPE="TEXT" SIZE="3" NAME="threshold" VALUE="$I{F}{threshold}">
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
	
	my $prev = $I{F}{min} - $I{F}{max};
	print linkSearch({
		'link'	=> "<B>$I{F}{min} previous matches...</B>",
		min	=> $prev
	}), "<P>" if $prev >= 0;
	
	# select comment ID, comment Title, Author, Email, link to comment
	# and SID, article title, type and a link to the article
	my $sqlquery = "SELECT section, newstories.sid, aid, title, pid, subject, writestatus," .
		getDateFormat("time","d") . "," .
		getDateFormat("date","t") . ", uid, cid, ";

	$sqlquery .= keysearch($I{F}{query}, 'subject', 'comment') if $I{F}{query};
	$sqlquery .= " 1 as kw " unless $I{F}{query};
	$sqlquery .= " FROM newstories, comments WHERE newstories.sid=comments.sid ";
	$sqlquery .= " AND newstories.sid=" . $I{dbh}->quote($I{F}{sid}) if $I{F}{sid};
	$sqlquery .= " AND points >= $I{F}{threshold} ";
	$sqlquery .= " AND section=" . $I{dbh}->quote($I{F}{section}) if $I{F}{section};
	$sqlquery .= " ORDER BY kw DESC, date DESC, time DESC LIMIT $I{F}{min},$I{F}{max} ";

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

	print "No Matches Found for your query" if $x < 1;

#	Counting has been removed (see comment at top).
#	my $remaining = $I{F}{hitcount} - $I{F}{'last'};
	print "<P>", linkSearch({
#		'link'	=> "<B>$remaining Matches Left</B>",
		'link'	=> "<B>More matches...</B>",
		min	=> $x
	}) unless !$x || $x < $I{F}{max};
}

#################################################################
sub userSearch {
	my $prev = int($I{F}{min}) - $I{F}{max};
	print linkSearch({
		'link'	=> "<B>$I{F}{min} previous matches...</B>",
		min	=> $prev
	}), "<P>" if $prev >=0;

	# userSearch REALLY doesn't need to be ordered by keyword since you 
	# only care if the substring is found.
	my $sqlquery = "SELECT fakeemail,nickname,uid ";
	$sqlquery .= " FROM users WHERE uid > 0 ";
	if ($I{F}{query}) {
		my $kw = keysearch($I{F}{query}, 'nickname', 'ifnull(fakeemail,"")');
		$kw =~ s/as kw$//;
		$kw =~ s/\+/ OR /g;
		$sqlquery .= "AND ($kw) ";
	}
	$sqlquery .= "ORDER BY uid LIMIT $I{F}{min}, $I{F}{max}";
	my $c = $I{dbh}->prepare($sqlquery);
	undef $c unless $c->execute;

#	print "<P><TT>$sqlquery</TT><BR>";
	return unless $c;

	my $total = $c->{rows};
	my($x, $cnt) = 0;

	while(my $N = $c->fetchrow_hashref) {
		my $ln = $N->{nickname};
		$ln =~ s/ /+/g;

		my $fake = $N->{fakeemail} ? <<EOT : '';
	email: <A HREF="mailto:$N->{fakeemail}">$N->{fakeemail}</A>
EOT
		print <<EOT;
<A HREF="$I{rootdir}/users.pl?nick=$ln">$N->{nickname}</A> &nbsp;
($N->{uid}) $fake<BR>
EOT

		$x++;
	}

	$c->finish;

	print "No Matches Found for your query" if $x < 1;

#	Counting has been removed (see comment at top).
#	my $remaining = $I{F}{hitcount} - $I{F}{'last'};
	print "<P>";
	print linkSearch({
#		'link'	=> "<B>$remaining matches left</B>",
		'link'	=> "<B>More matches...</B>",
		min	=> $I{F}{'last'},
#		hitcount => $I{F}{hitcount}
	}) unless !$x || $x < $I{F}{max};
}

#################################################################
sub storySearch {
	my $prev = $I{F}{min} - $I{F}{max};
	print linkSearch({
		'link'	=> "<B>$I{F}{min} previous matches...</B>",
		min	=> $prev
	}), "<P>" if $prev >= 0;

	my $sqlquery = "SELECT aid,title,sid," . getDateFormat("time","t") .
		", commentcount,section ";
	$sqlquery .= "," . keysearch($I{F}{query}, "title", "introtext") . " "
		if $I{F}{query};
	$sqlquery .="	,0 " unless $I{F}{query};

	if ($I{F}{query} || $I{F}{topic}) {
		$sqlquery .= "  FROM stories ";
	} else {
		$sqlquery .= "  FROM newstories ";
	}

	$sqlquery .= $I{F}{section} ? <<EOT : 'WHERE displaystatus >= 0';
WHERE ((displaystatus = 0 and "$I{F}{section}"="")
        OR (section="$I{F}{section}" and displaystatus>=0))
EOT

	$sqlquery .= "   AND time<now() AND writestatus>=0 AND displaystatus>=0";
	$sqlquery .= "   AND aid=" . $I{dbh}->quote($I{F}{author})
		if $I{F}{author};
	$sqlquery .= "   AND section=" . $I{dbh}->quote($I{F}{section})
		if $I{F}{section};
	$sqlquery .= "   AND tid=" . $I{dbh}->quote($I{F}{topic})
		if $I{F}{topic};

	$sqlquery .= " ORDER BY ";
	$sqlquery .= " kw DESC, " if $I{F}{query};
	$sqlquery .= " time DESC LIMIT $I{F}{min},$I{F}{max}";

#	print "<P><TT>$sqlquery</TT></P>";

	my $cursor = $I{dbh}->prepare($sqlquery);
	$cursor->execute;

	my($x, $cnt) = 0;
	print " ";

	while (my($aid, $title, $sid, $time, $commentcount, $section, $cnt) = 
		$cursor->fetchrow) {
		last unless $cnt || ! $I{F}{query};
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

	print "No Matches Found for your query." if $x < 1;

#	Counting has been removed (see comment at top).
#	my $remaining = $I{F}{hitcount} - $I{F}{'last'};
	print "<P>", linkSearch({
		'link'	=> "<B>More Articles</B>",
		min	=> $I{F}{'last'}
	}) unless !$x || $x < $I{F}{max};
}

main;
$I{dbh}->disconnect if $I{dbh};
1;

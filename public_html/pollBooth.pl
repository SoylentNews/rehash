#!/usr/bin/perl -w

###############################################################################
# pollBooth.pl - this page displays the page where users can vote in a poll, 
# or displays poll results 
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

	if (defined $I{F}{aid} && $I{F}{aid} !~ /^\-?\d$/) {
		undef $I{F}{aid};
	}

	header("$I{sitename} Poll", $I{F}{section});

	if ($I{F}{qid} eq "gradschool") {
		footer();
		return;
	}

	if ($I{U}{aseclev} > 99) { 
		print qq!<FONT SIZE="2">[ <A HREF="$ENV{SCRIPT_NAME}?op=edit">New Poll</A> ]!;
	}
	my $op = $I{F}{op};
	if ($I{U}{aseclev} > 99 && $op eq "edit") {
		editpoll($I{F}{qid});

	} elsif ($I{U}{aseclev} > 99 && $op eq "save") {
		savepoll();

	} elsif (! defined $I{F}{qid}) {
		listPolls();

	} elsif (! defined $I{F}{aid}) {
		print "<CENTER><P>";
		pollbooth($I{F}{qid});
		print "</CENTER>";

	} else {
		vote($I{F}{qid}, $I{F}{aid});
		printComments($I{F}{qid}) unless getvar("nocomment");
	}

	writelog("pollbooth", $I{F}{qid});
	footer();
}

#################################################################
sub editpoll {
	my($qid) = @_;
	my $qid_dbi = $I{dbh}->quote($qid);
	my $qid_htm = stripByMode($qid, 'attribute');

	# Display a form for the Question
	my($question, $voters) = sqlSelect(
		"question, voters", "pollquestions", "qid=$qid_dbi");

	$voters = 0 if ! defined $voters;

	my($currentqid) = getvar("currentqid");
	printf <<EOT, $currentqid eq $qid ? " CHECKED" : "";

<FORM ACTION="$ENV{SCRIPT_NAME}" METHOD="POST">
	<B>id</B> (if this matches a story's ID, it will appear with the story,
		else just pick a unique string)<BR>
	<INPUT TYPE="TEXT" NAME="qid" VALUE="$qid_htm" SIZE="20">
	<INPUT TYPE="CHECKBOX" NAME="currentqid"%s> (appears on homepage)

	<BR><B>The Question</B> (followed by the total number of voters so far)<BR>
	<INPUT TYPE="TEXT" NAME="question" VALUE="$question" SIZE="40">
	<INPUT TYPE="TEXT" NAME="voters" VALUE="$voters" SIZE="5">
	<BR><B>The Answers</B> (voters)<BR>
EOT


	my $c = sqlSelectMany("answer,votes", "pollanswers", "qid=$qid_dbi ORDER by aid");
	my $x = 0;
	while (my($answers, $votes) = $c->fetchrow) {
		$x++;
		print <<EOT;
	<INPUT TYPE="text" NAME="aid$x" VALUE="$answers" SIZE="40">
	<INPUT TYPE="text" NAME="votes$x" VALUE="$votes" SIZE="5"><BR>
EOT
	}

	$c->finish;

	while ($x < 8) {
		$x++;
		print <<EOT;
	<INPUT TYPE="text" NAME="aid$x" VALUE="" SIZE="40">
	<INPUT TYPE="text" NAME="votes$x" VALUE="0" SIZE="5"><BR>
EOT
	}

	print <<EOT;
	<INPUT TYPE="SUBMIT" VALUE="Save">
	<INPUT TYPE="HIDDEN" NAME="op" VALUE="save">
</FORM>

EOT

}

#################################################################
sub savepoll {
	return unless $I{F}{qid};
	# Check if QID exists, and either update/insert

	$I{F}{voters} ||= "0";
	sqlReplace("pollquestions", {
		qid		=> $I{F}{qid},
		question	=> $I{F}{question},
		voters		=> $I{F}{voters},
		-date		=>'now()'
	});

	setvar("currentqid", $I{F}{qid}) if $I{F}{currentqid};

	# Loop through 1..8 and insert/update if defined
	for (my $x = 1; $x < 9; $x++) {
		if ($I{F}{"aid$x"}) {
			print qq!<BR>Answer $x '$I{F}{"aid$x"}' $I{F}{"votes$x"}!;
			sqlReplace("pollanswers", {
				aid	=> $x,
				qid	=> $I{F}{qid},
				answer	=> $I{F}{"aid$x"},
				votes	=> $I{F}{"votes$x"}
			});

		} else {
			$I{dbh}->do("DELETE from pollanswers WHERE 
				qid=" . $I{dbh}->quote($qid) . " and aid=$x"); 
		}
	}
}

#################################################################
sub vote {
	my($qid, $aid) = @_;

	my $qid_dbi = $I{dbh}->quote($qid);
	my $qid_htm = stripByMode($qid, 'attribute');

	my $notes = "Displaying poll results $aid";
	if ($I{U}{uid} == -1 && ! $I{allow_anonymous}) {
		$notes = "You may not vote anonymously.  " .
		    qq[Please <A HREF="$I{rootdir}/users.pl">log in</A>.];
	} elsif ($aid > 0) {
		my($id) = sqlSelect("id","pollvoters",
			"qid=$qid_dbi AND 
			 id="  . $I{dbh}->quote($ENV{REMOTE_ADDR} . $ENV{HTTP_X_FORWARDED_FOR}) . " AND
			 uid=" . $I{dbh}->quote($I{U}{uid})
		);

		if ($id) {
			$notes = "$I{U}{nickname} at $ENV{REMOTE_ADDR} has already voted.";
			if ($ENV{HTTP_X_FORWARDED_FOR}) { 
				$notes .= " (proxy for $ENV{HTTP_X_FORWARDED_FOR})";
			}

		} else {
			$notes = "Your vote ($aid) has been registered.";
			sqlInsert("pollvoters", {
				qid	=> $qid, 
				id	=> $ENV{REMOTE_ADDR} . $ENV{HTTP_X_FORWARDED_FOR},
				-'time'	=> "now()" ,
				uid	=> $I{U}{uid}
			});

			$I{dbh}->do("update pollquestions set 
				voters=voters+1 where qid=$qid_dbi");
			$I{dbh}->do("update pollanswers set votes=votes+1 where 
				qid=$qid_dbi and aid=" . $I{dbh}->quote($aid));
		}
	} 

	my($totalvotes, $question) = sqlSelect(
		"voters,question", "pollquestions", "qid=$qid_dbi");

	my($maxvotes) = sqlSelect("max(votes)", "pollanswers", "qid=$qid_dbi");

	print <<EOT;
<CENTER><TABLE BORDER="0" CELLPADDING="2" CELLSPACING="0" WIDTH="500">
	<TR><TD> </TD><TD COLSPAN="1">
EOT

	titlebar("99%", $question);
	print qq!\t<FONT SIZE="2">$notes</FONT></TD></TR>!;

	my $a = sqlSelectMany("answer,votes", "pollanswers", "qid=$qid_dbi ORDER by aid");

	while (my($answer, $votes) = $a->fetchrow) {
		my $imagewidth	= $maxvotes ? int (350 * $votes / $maxvotes) + 1 : 0;
		my $percent	= $totalvotes ? int (100 * $votes / $totalvotes) : 0;
		pollItem($answer, $imagewidth, $votes, $percent);
	}

	$a->finish;

	my $postvote = blockCache("$I{currentSection}_postvote")
		|| blockCache("postvote");

	print <<EOT;
	<TR><TD COLSPAN="2" ALIGN="RIGHT">
		<FONT SIZE="4"><B>$totalvotes total votes.</B></FONT>
	</TD></TR><TR><TD COLSPAN="2"><P ALIGN="CENTER">
		[
			<A HREF="$ENV{SCRIPT_NAME}?qid=$qid_htm">Voting Booth</A> |
			<A HREF="$ENV{SCRIPT_NAME}">Other Polls</A> |
			<A HREF="$I{rootdir}/">Back Home</A>
		]
	</TD></TR><TR><TD COLSPAN="2">$postvote</TD></TR>
</TABLE></CENTER>

EOT
}

#################################################################
sub listPolls {
	$I{F}{min} ||= "0";

	my $cursor = sqlSelectMany("qid, question, date_format(date,\"W M D\")",
		"pollquestions order by date DESC LIMIT $I{F}{min},20");

	titlebar("99%", "$I{sitename} Polls");
	while (my($qid, $question, $date) = $cursor->fetchrow) {
		my $href = $I{U}{aseclev} >= 100
			? qq! (<A HREF="$ENV{SCRIPT_NAME}?op=edit&qid=$qid">Edit</A>)!
			: '';

		print <<EOT;
<BR><LI><A HREF="$ENV{SCRIPT_NAME}?qid=$qid">$question</A> $date$href</LI>
EOT

	}

	my $startat = $I{F}{min} + $cursor->rows;
	print <<EOT;
<P><FONT SIZE="4"><B><A HREF="$ENV{SCRIPT_NAME}?min=$startat">More Polls</A></B></FONT>
EOT

	$cursor->finish;
}

main();
$I{dbh}->disconnect if $I{dbh};
1;

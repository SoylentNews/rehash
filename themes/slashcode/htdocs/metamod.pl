#!/usr/bin/perl -w

###############################################################################
# metamod.pl - this code displays the page where users meta-moderate 
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

	$I{U}{karma}=sqlSelect("karma","users_info","uid=$I{U}{uid}") if $I{U}{uid} > 0;
	header("Meta Moderation");
	$I{F}{cid}=~s/[^0-9]//g;  # Some browser wants to send invalid chars

	my $id = isEligible();
	if (!$id) {
		print <<EOT;
<BR>You are currently not eligible to Meta Moderate.<BR>
Return to <A HREF="$I{rootdir}/">the $I{sitename} homepage</A>.<BR>
EOT

	} elsif ($I{F}{op} eq "MetaModerate") {
		metaModerate($id);
	} else {
		displayTheComments($id);
	}

	writelog("metamod", $I{F}{op});
	footer();
}

#################################################################
sub karmaBonus {
	my $x = 10 - $I{U}{karma};
	return 0 unless $x > 0;
	return 1 if rand(10) < $x;
	return 0;
}

#################################################################
sub metaModerate {
	my $id = shift;
	# Sum Elements from Form and Update User Record
	my $y = 0;

	foreach (keys %{$I{F}}) {
		$I{F}{$_} =~ s/[^\+\-]//g; # Some protection
		if (/mm(.*)/) {
			$I{metamod_sum}-- if $I{F}{$_} eq "-";
			$I{metamod_sum}++ if $I{F}{$_} eq "+";
		}
	}


	my %m2victims;
	foreach (keys %{$I{F}}) {
		if ($y < 10 && /^mm(\d+)$/) { 
			my $id = $1;
			$y++;
			my($muid) = sqlSelect("uid","moderatorlog",
				"id=" . $I{dbh}->quote($id)
			);

			$m2victims{$id} = [$muid, $I{F}{$_}] if $I{metamod_sum} > 0;
			# metaMod($1, $I{F}{$_}) if $I{metamod_sum} > 0;
		}
	}

	$I{dbh}->do("LOCK TABLES users_info WRITE, metamodlog WRITE");
	foreach (keys %m2victims) {
		metaMod($m2victims{$_}[0], $m2victims{$_}[1], $_);
	}
	$I{dbh}->do("UNLOCK TABLES");

	print <<EOT;
$y comments have been meta moderated.  Thanks for participating.
You may wanna go back <A HREF="$I{rootdir}/">home</A> or perhaps to
<A HREF="$I{rootdir}/users.pl">your user page</A>.
EOT

	print "<BR>Total unfairs is $I{metamod_sum}" if $I{U}{aseclev} > 10;

	sqlUpdate("users_info",{
		-lastmm		=> 'now()',
		lastmmid	=> 0
	}, "uid=$I{U}{uid}") unless $I{U}{uid} == 1;

	if ($y > 5 && $I{metamod_sum} > 0 && karmaBonus()) {
		# Bonus Karma For Helping Out
		sqlUpdate("users_info", { -karma => 'karma+1' },
			"uid=$I{U}{uid} and karma<10");
	}
}

#################################################################
sub getRandomActions {
	my($min, $max) = sqlSelect("min(id),max(id)", "moderatorlog");
	return $min + int rand($max - $min - 10);
}

#################################################################
sub metaMod {
	my($muid, $val, $mmid) = @_;

	return unless $val; # Gotta have something to do with it...

	# Update $muid's Karma
	if ($muid && $val) {
		sqlUpdate("users_info", { -karma => "karma+1" },
			"$muid=uid and karma<10") if $val eq "+";
		sqlUpdate("users_info", { -karma => "karma-1" },
			"$muid=uid and karma>-10") if $val eq "-";
		sqlInsert("metamodlog", {
			-mmid => $mmid,
			-uid  => $muid,
			-val  => ($val eq '+' ? 1 : -1),
			-ts   => 'now()',
		});
	}
	print "<BR>Updating $muid with $val" if $I{U}{aseclev} > 10;
}

#################################################################
sub displayTheComments {
	my $id = shift;

	titlebar("99%","Meta Moderation");
	print <<EOT;
<B>PLEASE READ THE DIRECTIONS CAREFULLY BEFORE EMAILING
\U$I{siteadmin_name}\E!</B> <P>What follows is 10 random moderations
performed on comments in the last few weeks on $I{sitename}.  You are
asked to <B>honestly</B> evaluate the actions of the moderator of each
comment. Moderators who are ranked poorly will cease to be eligible for
moderator access in the future.

<UL>

<LI>If you are confused about the context of a particular comment, just
link back to the comment page through the parent link, or the #XXX cid
link. (use the back arrow to come back or you'll get 10 new comments!)</LI>

<LI><B><FONT SIZE="5">Duplicates are fine</FONT></B> (Big because over
<B>100</B> people have emailed me to tell me about this even though it is
explained <B>right here</B>.)  You are not moderating a "Comment" you
are moderating a "Moderation".  Therefore, if a comment is moderated
more than once, it can appear multiple times below.  Don't worry about it.</LI>

<LI>If you are unsure, feel free to leave it unchanged.</LI>

<LI>Please read the <A HREF="$I{rootdir}/moderation.shtml">Moderator Guidelines</A>
and try to be impartial and fair.  You are not moderating to make your
opinions heard, you are trying to help promote a rational discussion. 
Play fairly and help make $I{sitename} a little better for everyone.</LI>

<LI>Scores are removed.  You can click thru and get them if you want them,
but they shouldn't be a factor in your M2 decision.</LI>

</UL>

<FORM ACTION="$ENV{SCRIPT_NAME}" METHOD="POST">
<TABLE>

EOT
	
	$I{U}{noscores} = 1; # Keep Things Impartial

	my $c = sqlSelectMany("comments.cid," . getDateFormat("date","time") . ",
		subject,comment,nickname,homepage,fakeemail,realname,
		users.uid as uid,sig,comments.points as points,pid,comments.sid as sid,
		moderatorlog.id as id,title,moderatorlog.reason as modreason,
		comments.reason",
		"comments,users,users_info,moderatorlog,stories",
		"stories.sid=comments.sid AND 
		moderatorlog.sid = comments.sid AND
		moderatorlog.cid = comments.cid AND
		moderatorlog.id > $id AND
		comments.uid != $I{U}{uid} AND
		users.uid = comments.uid AND
		users.uid = users_info.uid AND
		users.uid != $I{U}{uid} AND
		moderatorlog.uid != $I{U}{uid} AND
		moderatorlog.reason < 8 LIMIT 10");

	$I{U}{points} = 0;
	while(my $C = $c->fetchrow_hashref) {
		dispComment($C);
		printf <<EOT, linkStory({ 'link' => $C->{title}, sid => $C->{sid} });
	<TR><TD>
		Story:<B>%s</B><BR> Rating:
		'<B>$I{reasons}[$C->{modreason}]</B>'.<BR>This rating is <B>Unfair
			<INPUT TYPE="RADIO" NAME="mm$C->{id}" VALUE="-">
			<INPUT TYPE="RADIO" NAME="mm$C->{id}" VALUE="0" CHECKED>
			<INPUT TYPE="RADIO" NAME="mm$C->{id}" VALUE="+">
		Fair</B><HR>
	</TD></TR>
	
EOT
	}

	print <<EOT;

</TABLE>

<INPUT TYPE="SUBMIT" NAME="op" VALUE="MetaModerate">

</FORM>

EOT


}

#################################################################
sub isEligible {

	if ($I{U}{uid} < 0) {
		print "You are not logged in";
		return 0;
	}

	my($tuid) = sqlSelect("count(*)", "users");
	
	if ($I{U}{uid} > int($tuid / 0.75) ) {
		print "You haven't been a $I{sitename} user long enough.";
		return 0;
	}

	if ($I{U}{karma} < 0) {
		print "You have bad Karma.";
		return 0;	
	}

	my($lastmm, $lastmmid) = sqlSelect(
		"(to_days(now()) - to_days(lastmm)), lastmmid",
		"users_info",
		"uid=$I{U}{uid}"
	);

	if ($lastmm eq "0") {
		print "You have recently meta moderated.";
		return 0;
	}

	unless ($lastmmid) {
		$lastmmid = getRandomActions();
		sqlUpdate("users_info", { lastmmid => $lastmmid }, 
			"uid=$I{U}{uid}");
	}

	return $lastmmid; # Hooray!
}

main();


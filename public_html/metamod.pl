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

	$I{U}{karma}=sqlSelect("karma","users_info","uid=$I{U}{uid}")
		if $I{U}{uid} > 0;
	header("Meta Moderation");

	# This validation now performed in Slash.pm This section will be removed
	# in the near future.
	# $I{F}{cid}=~s/[^0-9]//g;  # Some browser wants to send invalid chars

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
	# Sliding scale: having karma closer to $I{m2_maxkarma}, 
	# lowers a users chance for M2 bonus.
	my $x = $I{m2_maxkarma} - $I{U}{karma};
	return 0 unless $x > 0;
	return 1 if rand($I{m2_maxkarma}) < $x;
	return 0;
}

#################################################################
sub metaModerate {
	my $id = shift;
	# Sum Elements from Form and Update User Record
	my $y = 0;
	my %metamod;

	# Meta-mod changes need to be re-applied from code backups! 

	foreach (keys %{$I{F}}) {
		# Meta mod form data can only be a '+' or '-' so we apply some
		# protection from taint.
		$I{F}{$_} =~ s/[^\+\-]//g;

		# Strict check on form data since experience shows that people will
		# exploit any hole for any given purpose. Even just to be annoying.
		if (/^mm(\d+)$/) {
			$metamod{unfair}++ if $I{F}{$_} eq "-";
			$metamod{fair}++   if $I{F}{$_} eq "+";
		}
	}


	my %m2victims;
	foreach (keys %{$I{F}}) {
		if ($y < $I{m2_comments} && /^mm(\d+)$/ && $I{F}{$_}) { 
			my $id = $1;
			$y++;
			my($muid) = sqlSelect("uid","moderatorlog",
				"id=" . $I{dbh}->quote($id)
			);

			$m2victims{$id} = [$muid, $I{F}{$_}];
			# metaMod($1, $I{F}{$_}) if $I{metamod_sum} > 0;
		}
	}

	# Perform M2 validity checks and set $flag accordingly. M2 is only recorded
	# if $flag is 0. Immediate and long term checks for M2 validity go here
	# (or in moderatord?).
	#
	# Also, it was probably unnecessary, but I want it to be understood that
	# an M2 session can be retrieved by:
	#		SELECT * from metamodlog WHERE uid=x and ts=y 
	# for a given x and y.
	my($flag, $ts) = (0, time);
	if ($y >= $I{m2_mincheck}) {
		# Test for excessive number of unfair votes (by percentage)
		# (Ignore M2 & penalize user)
		$flag = 2 if ($metamod{unfair}/$y >= $I{m2_maxunfair});
		# Test for questionable number of unfair votes (by percentage)
		# (Ignore M2).
		$flag = 1 if (!$flag && ($metamod{unfair}/$y >= $I{m2_toomanyunfair}));
	}
	
	$I{dbh}->do("LOCK TABLES users_info WRITE, metamodlog WRITE");
	foreach (keys %m2victims) {
		metaMod($m2victims{$_}[0], $m2victims{$_}[1], $_, $flag, $ts);
	}
	$I{dbh}->do("UNLOCK TABLES");

	print <<EOT;
$y comments have been meta moderated.  Thanks for participating.
You may wanna go back <A HREF="$I{rootdir}/">home</A> or perhaps to
<A HREF="$I{rootdir}/users.pl">your user page</A>.
EOT

	print "<BR>Total unfairs is $metamod{unfair}" if $I{U}{aseclev} > 10;

	$metamod{unfair} ||= 0;
	$metamod{fair} ||= 0;
	sqlUpdate("users_info",{
		-m2unfairvotes	=> "m2unfairvotes+$metamod{unfair}",
		-m2fairvotes	=> "m2fairvotes+$metamod{fair}",
		-lastmm			=> 'now()',
		lastmmid		=> '0'
	}, "uid=$I{U}{uid}") unless $I{U}{uid} == 1;

	# Of course, I'm waiting for someone to make the eventual joke...
	my($change, $excon);
	if ($y > $I{m2_mincheck}) {
		if (!$flag && karmaBonus()) {
			# Bonus Karma For Helping Out
			($change, $excon) = ($I{m2_bonus}, "and karma<$I{m2_maxbonus}");
		} elsif ($flag == 2) {
			# Penalty for Abuse
			($change, $excon) = ($I{m2_penalty}, '');
		}
		# Update karma.
		sqlUpdate("users_info", { -karma => "karma$change" },
			"uid=$I{U}{uid} $excon") if $change;
	}
}

#################################################################
sub getRandomActions {
	my ($min, $max) = sqlSelect("min(id), max(id)", "moderatorlog");
	return $min + int rand($max - $min - $I{m2_comments});
}

#################################################################
sub metaMod {
	my($muid, $val, $mmid, $flag, $ts) = @_;

	return unless $val; # Gotta have something to do with it...

	# Update $muid's Karma
	if ($muid && $val && !$flag) {
		if ($val eq '+') {
			sqlUpdate("users_info", { -m2fair => "m2fair+1" }, "uid=$muid");
			# The idea here is to not let meta moderators get the comment
			# bonus...
			sqlUpdate("users_info", { -karma => "karma+1" },
				"$muid=uid and karma<$I{m2_maxbonus}");
		} elsif ($val eq '-') {
			sqlUpdate("users_info", { -m2unfair => "m2unfair+1" },
				"uid=$muid");
			# ...while sufficiently bad moderators can still get the 
			# comment penalty.
			sqlUpdate("users_info", { -karma => "karma-1" },
				"$muid=uid and karma>$I{badkarma_limit}");
		}
	}
	# Time is now fixed at form submission time to ease 'debugging'
	# of the moderation system, ie 'GROUP BY uid, ts' will give 
	# you the M2 votes for a specific user ordered by M2 'session'
	sqlInsert("metamodlog", {
		-mmid => $mmid,
		-uid  => $I{U}{uid},
		-val  => ($val eq '+') ? 1 : -1,
		-ts   => "from_unixtime($ts)",
		-flag => $flag
	});
	print "<BR>Updating $muid with $val" if $I{U}{aseclev} > 10;
}

#################################################################
sub displayTheComments {
	my $id = shift;

	titlebar("99%","Meta Moderation");
	print <<EOT;
<B>PLEASE READ THE DIRECTIONS CAREFULLY BEFORE EMAILING
\U$I{siteadmin_name}\E!</B> <P>What follows is $I{m2_comments} random
moderations performed on comments in the last few weeks on $I{sitename}.
You are asked to <B>honestly</B> evaluate the actions of the moderator of each
comment. Moderators who are ranked poorly will cease to be eligible for
moderator access in the future.

<UL>

<LI>If you are confused about the context of a particular comment, just
link back to the comment page through the parent link, or the #XXX cid
link.</LI>

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
		moderatorlog.reason < 8 LIMIT $I{m2_comments}");

	$I{U}{points} = 0;
	while(my $C = $c->fetchrow_hashref) {
		# Anonymize the comment; it should be safe to reset $C->{uid}, and 
		# $C->{points} (as a matter of fact, the latter SHOULD be done due to
		# the nickname).
		#
		# The '-' in place of nickname -may- be a problem, though. And we
		# Probably shouldn't assume a score of 0, here either but we'll leave
		# it for now.
		@{%{$C}}{qw(nickname uid fakeemail homepage points)} =
			('-', -1, '', '', 0);
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
	
	if ($I{U}{uid} > int($tuid * 0.75) ) {
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

	# Eligible for M2. Determine M2 comments by selecting random starting
	# point in moderatorlog.
	unless ($lastmmid) {
		$lastmmid = getRandomActions();
		sqlUpdate("users_info", { lastmmid => $lastmmid }, 
			"uid=$I{U}{uid}");
	}

	return $lastmmid; # Hooray!
}

main();


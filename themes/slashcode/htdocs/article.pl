#!/usr/bin/perl -w

###############################################################################
# article.pl - this code displays a particular story and it's comments 
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

	if ($I{F}{refresh}) {
		sqlUpdate('stories',
			{ writestatus => 1 },
			'sid=' . $I{dbh}->quote($I{F}{sid}) . ' and writestatus=0'
		);
		# won't work now because HTTP headers not printed until header() below
		# print qq[<FONT COLOR="white" SIZE="${\( $I{fontbase} + 5 )}">How Refreshing! ($I{F}{sid}) </FONT>\n];
	}

	my($sect, $title, $ws);

	# only go to the database if we don't have it persistent in memory
	if ($I{storyBank}{$I{F}{sid}}) {	
		$sect  = $I{storyBank}{ $I{F}{sid} }{section};
		$title = $I{storyBank}{ $I{F}{sid} }{title};
		$ws    = $I{storyBank}{ $I{F}{sid} }{writestatus};

	} else {
		($sect, $title, $ws) = sqlSelect(
			'section,title,writestatus', 'stories',
			'sid=' . $I{dbh}->quote($I{F}{sid})
		);
	}

	if ($ws == 10) {
		$ENV{SCRIPT_NAME} = '';
		redirect("$I{rootdir}/$sect/$I{F}{sid}$I{userMode}.shtml");
		return;
	};

	my $SECT = getSection($sect);
	$title = $SECT->{isolate} ? "$SECT->{title} | $title" : "$I{sitename} | $title";
	header($title, $sect);

	my($S, $A, $T) = displayStory($I{F}{sid}, 'Full');

	print "<P>";
	articleMenu($S, $SECT);
#	print qq!</TD><TD VALIGN="TOP">\n!;
	print qq!</TD><TD>&nbsp;</TD><TD VALIGN="TOP">\n!;

	yourArticle($S);

	# Poll Booth
	pollbooth($I{F}{sid}) if sqlSelect('qid', 'pollquestions', "qid='$S->{sid}'");

	# Related Links
	fancybox($I{fancyboxwidth}, 'Related Links', $S->{relatedtext});

	# Display this section's Section Block (if Found)
	fancybox($I{fancyboxwidth}, $SECT->{title}, getblock($SECT->{section}));

	print qq!</TD></TR><TR><TD COLSPAN="3">\n!;

	printComments($I{F}{sid});
	writelog($SECT->{section}, $I{F}{sid}) unless $I{F}{ssi};
	footer();

	# zero the refresh flag 
	# and undef sid sequence array
	if ($I{story_refresh}) {
		$I{story_refresh} = 0;
		# garbage collection 
		undef $I{sid_array};
	}
	# zero the order count
	$I{StoryCount} = 0;
}

##################################################################
sub moderatorLog {
	my $S=shift;
	my $c=sqlSelectMany(   "comments.sid as sid,
				comments.cid as cid,
				comments.points as score,
				subject, moderatorlog.uid as uid,
				users.nickname as nickname,
				moderatorlog.val as val, 
				moderatorlog.reason as reason,
				moderatorlog.active as active",
			       "moderatorlog, users, comments",
			       "moderatorlog.sid='$S->{sid}'
				AND moderatorlog.uid=users.uid
				AND comments.sid=moderatorlog.sid
				AND comments.cid=moderatorlog.cid
			       ");

	if ($c->rows > 0) {
		print <<EOT;
<TABLE BGCOLOR="$I{bg}[2]" WIDTH="95%" ALIGN="CENTER">
	<TR BGCOLOR="$I{bg}[3]">
		<TH><FONT COLOR="$I{fg}[3]"> val / score </FONT></TH>
		<TH><FONT COLOR="$I{fg}[3]"> reason </FONT></TH>
		<TH><FONT COLOR="$I{fg}[3]"> moderator </FONT></TH>
		<TH><FONT COLOR="$I{fg}[3]"> comment </FONT></TH>
		<TH><FONT COLOR="$I{fg}[3]"> active </FONT></TH>
	</TR>

EOT

		while (my $C = $c->fetchrow_hashref) {
			print <<EOT;
	<TR>
		<TD> <B>$C->{val}</B> / $C->{score} </TD>
		<TD> $I{reasons}[$C->{reason}] </TD>
		<TD> $C->{nickname} ($C->{uid}) </TD>
		<TD><A HREF="$I{rootdir}/comments.pl?sid=$S->{sid}&cid=$C->{cid}">$C->{subject}</A></TD>
		<TD> $C->{active} </TD>
	</TR>

EOT
		}
		print "</TABLE>\n\n";
	}
	$c->finish;
}

##################################################################
sub pleaseLogin {
	return if $I{U}{uid} > 0;
	my $block = eval prepBlock getblock('userlogin');
	$block =~ s/index\.pl/article.pl?sid=$I{F}{sid}/;
	$block =~ s/\$I{rootdir}/$I{rootdir}/g;
	fancybox($I{fancyboxwidth}, "$I{sitename} Login", $block);
}

##################################################################
sub yourArticle {
	if ($I{U}{uid} < 1) {
		pleaseLogin();
		return;
	}

	my $S = shift;
	my $m = qq![ <A HREF="$I{rootdir}/users.pl?op=preferences">Preferences</A> !;
	$m .= qq! | <A HREF="$I{rootdir}/admin.pl">Admin</A> |! .
		qq! <A HREF="$I{rootdir}/admin.pl?op=edit&sid=$S->{sid}">Editor</A> !
		if $I{U}{aseclev} > 99 and $I{U}{aid};
	$m .= " ]<P>\n";

	$m .= <<EOT if $I{U}{points} or $I{U}{aseclev} > 99;

<A HREF="$I{rootdir}/users.pl">You</A> have moderator access and 
<B>$I{U}{points}</B> points.  Welcome to the those of you
just joining: <B>please</B> read the
<A HREF="$I{rootdir}/moderation.shtml">moderator guidelines</A>
for instructions. (<B>updated 9.9!</B>)

<P>

<LI>You can't post & moderate the same discussion.
<LI>Concentrate on Promoting more than Demoting.
<LI>Browse at -1 to keep an eye out for abuses.
<LI><A HREF="mailto:$I{adminmail}">Mail admin</A> URLs showing abuse (the cid link please!).

EOT

	$m .= "<P> $I{U}{mylinks} ";

	fancybox($I{fancyboxwidth}, $I{U}{aid} || $I{U}{nickname}, $m);
}

##################################################################
sub articleMenu {
	my($story, $SECT) = @_;

	print ' &lt;&nbsp; ' . nextStory('<', $story, $SECT);

	my $n = nextStory('>', $story, $SECT);
	print " | $n &nbsp;&gt; " if $n;

	print ' <P>&nbsp;';
}

##################################################################
sub nextStory {
	my($sign, $story, $SECT) = @_;
	my($array_place, $where);

	if ($SECT->{isolate}) {
		$where = 'AND section=' . $I{dbh}->quote($story->{section})
			if $SECT->{isolate} == 1;
	} else {
		$where = 'AND displaystatus=0';
	}

	$where .= "   AND tid not in ($I{U}{extid})" if $I{U}{extid};
	$where .= "   AND aid not in ($I{U}{exaid})" if $I{U}{exaid};
	$where .= "   AND section not in ($I{U}{exsect})" if $I{U}{exsect};

	my $order = $sign eq '<' ? 'DESC' : 'ASC';

	# find out what sequence this is in from the storyBank
	$array_place = $I{storyBank}{$I{F}{sid}}{story_order};

	# next article, previous article	
	$array_place += $sign eq '<' ? 1 : -1;

	# if this is AC, and within the range of the number of stories in storyBank
	# then get title,sid, and section from storyBank
	if (	$I{sid_array}[$array_place]
			&&
		$I{storyBank}{$I{sid_array}[$array_place]}
			&& 
		$I{storyBank}{$I{F}{sid}}{story_order} != ($I{StoryCount} - 1)
			&&
		$array_place != -1
			&&
		$I{U}{uid} == -1
	) {
		my $title   = $I{storyBank}{ $I{sid_array}[$array_place] }{title};
		my $psid    = $I{sid_array}[$array_place];
		my $section = $I{storyBank}{ $I{sid_array}[$array_place] }{section};
		return linkStory({ 'link' => $title, sid => $psid, section => $section });

	} elsif (my($title, $psid, $section) = sqlSelect(
		'title, sid, section', 'newstories',
		 "time $sign '$story->{sqltime}' AND writestatus >= 0 AND time < now() $where",
		"ORDER BY time $order LIMIT 1")
	) {
		return linkStory({ 'link' => $title, sid => $psid, section => $section });
	}
	'';
}

main();

$I{dbh}->disconnect if $I{dbh};

1;

#!/usr/bin/perl -w

###############################################################################
# topics.pl - this page is for the display and modification of system topics by
# authors 
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
	my $SECT = getSection();

	header("$I{sitename}: Topics", $SECT->{section});
	print <<EOT;
[	<A HREF="$I{rootdir}/topics.pl?op=toptopics">Recent Topics</A> |
	<A HREF="$I{rootdir}/topics.pl?op=listtopics">List Topics</A> ]
EOT

	if ($I{F}{op} eq "toptopics") {
#		return;
		topTopics($SECT);
	} else {
		listTopics();
	}

	writelog("topics");
	footer($I{F}{ssi});
}

#################################################################
sub topTopics {
	my $SECT=shift;

	titlebar("90%", "Recent Topics");

	my $when = "AND to_days(now()) - to_days(time) < 14" unless $I{F}{all};
	my $order = $I{F}{all} ? "ORDER BY alttext" : "ORDER BY cnt DESC";
	my $c=sqlSelectMany("*, count(*) as cnt","topics,newstories",
				"topics.tid=newstories.tid
				 $when
				 GROUP BY topics.tid
				 $order");

	my $T;
	my $col=0;

	print <<EOT;

<TABLE WIDTH="90%" BORDER="0" CELLPADDING="3">
EOT

	while ($T = $c->fetchrow_hashref) {
		printf <<EOT, sqlSelect("count(*)", "stories", "tid=" . $I{dbh}->quote($T->{tid}));
	<TR><TD ALIGN="RIGHT" VALIGN="TOP>
		<FONT SIZE="6" COLOR="$I{bg}[3]">$T->{alttext}</FONT>
		<BR>( %s )
		<A HREF="$I{rootdir}/search.pl?topic=$T->{tid}"><IMG
			SRC="$I{imagedir}/topics/$T->{image}"
			BORDER="0" ALT="$T->{alttext}" ALIGN="RIGHT"
			HSPACE="0" VSPACE="10" WIDTH="$T->{width}"
			HEIGHT="$T->{height}"></A>
	</TD><TD BGCOLOR="$I{bg}[2]" VALIGN="TOP">
EOT

		my $limit = $T->{cnt};
		$limit = 10 if $limit > 10;
		$limit = 3  if $limit < 3 or $I{F}{all};
		$SECT->{issue} = 0;

		my $stories = selectStories($SECT, $limit, $T->{tid});
		print getOlderStories($stories, $SECT);
		$stories->finish;
		print "\n\t</TD></TR>\n";
	} 
	print "</TABLE>\n\n";
	$c->finish;

	printf <<EOT, scalar localtime;
<BR><FONT SIZE="2"><CENTER>generated on %s</CENTER></FONT><BR>
EOT

	writelog("topics");
}

#################################################################
sub listTopics {
	my $cursor = $I{dbh}->prepare("SELECT tid,image,alttext,width,height
					 FROM topics
				     ORDER BY alttext");

	titlebar("99%", "Current Topic Catagories");
	my $x = 0;
	$cursor->execute;

	print qq!\n<TABLE ALIGN="CENTER">\n\t<TR>\n!;

	while (my($tid, $image, $alttext, $width, $height) = $cursor->fetchrow) {
		unless ($x++ % 6) {
			print "\t</TR><TR>";
		}

		my $href = $I{U}{aseclev} > 500 ? <<EOT : '';
</A><A HREF="$I{rootdir}/admin.pl?op=topiced&nexttid=$tid">
EOT

		print <<EOT;
<TD ALIGN="CENTER">
		<A HREF="$I{rootdir}/search.pl?topic=$tid"><IMG
			SRC="$I{imagedir}/topics/$image" ALT="$alttext"
			WIDTH="$width" HEIGHT="$height"
			BORDER="0">$href<BR>$alttext</A>
		</TD>
EOT
	}

	$cursor->finish;
	print "\t</TR>\n</TABLE>\n\n";
}

main();
$I{dbh}->disconnect if $I{dbh};

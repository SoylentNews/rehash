#!/usr/bin/perl -w

###############################################################################
# sections.pl - this page displays the sections of the site for the admin 
# user, allows editing of the sections 
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

	header("Section Editor", "admin");
	if ($I{U}{aseclev} > 100) {
		# adminMenu();
	} else { 
		print <<EOT;
<PRE>
         I woke up in the Soho bar when a policeman knew my name. He said,
         "You can go sleep at home tonite if you can get up and walk away."
         I staggered back to the underground and a breeze threw back my
         head. I remember throwing punches around and preachin' from my chair.
                         From 'Who Are You' by God (aka Pete Townshend)<BR></PRE>
EOT
		footer();
		return;
	}

	my $op = $I{F}{op};
	my $seclev=$I{U}{aseclev};
	if ($op eq "rmsub" && $seclev > 99) {

	} elsif ($I{F}{addsection}) {
		titlebar("100%", "Add Section");
		editSection($seclev);

	} elsif ($I{F}{deletesection} || $I{F}{deletesection_cancel} || $I{F}{deletesection_confirm}) {
		delSection($I{F}{section});
		listSections();

	} elsif ($op eq "editsection" || $I{F}{editsection}) {
		titlebar("100%", "Editing $I{F}{section} Section");
		editSection($seclev, $I{F}{section});
		# Edit Section

	} elsif ($I{F}{savesection}) {
		titlebar("100%", "Saving $I{F}{section}");
		saveSection($I{F}{section});
		listSections();

	} elsif ((! defined $op || $op eq "list") && $seclev > 499) {
		titlebar("100%", "Sections");
		listSections();
	}
	footer();
}

#################################################################
sub listSections {
	if ($I{U}{asection}) {
		editSection($I{U}{aseclev}, $I{U}{asection});
		return;
	}

	my $c = $I{dbh}->prepare("SELECT section,title FROM sections ORDER BY section");
	$c->execute;

	print "<B>";

	while (my($section, $title)=$c->fetchrow) {
		print <<EOT if $section;
<P><A HREF="$ENV{SCRIPT_NAME}?section=$section&op=editsection">$section</A> $title
EOT
	}

	$c->finish;
	print "</B>";

	# New section Form
	print <<EOT;
	<FORM ACTION="$ENV{SCRIPT_NAME}">
		<INPUT TYPE="SUBMIT" NAME="addsection" VALUE="add section">
	</FORM>
EOT

}

#################################################################
sub delSection {
	my($section) = shift;
	
	if ($I{F}{deletesection}) {
		print <<EOT;
		<FORM ACTION="$ENV{SCRIPT_NAME}" METHOD="POST">
		<P>
		Do you really want to delete the $section section? 
		<INPUT TYPE="HIDDEN" NAME="section" VALUE="$section">
		<INPUT TYPE="SUBMIT" NAME="deletesection_cancel" VALUE="Cancel">
		<INPUT TYPE="SUBMIT" NAME="deletesection_confirm" VALUE="Delete $section">
		</P>
		</FORM>
EOT
	}
	elsif ($I{F}{deletesection_cancel}) {
		print "<B>Canceled deletion of $section</B><BR>\n";
	}
	elsif ($I{F}{deletesection_confirm}) {
		titlebar("100%", "Deleted $section Section") unless DBI::errstr;
		$I{dbh}->do("DELETE from sections WHERE section='$section'");
	}
}

#################################################################
sub editSection {
	my($seclev, $section) = @_;

	my($artcount, $title, $qid, $isolate, $issue) = sqlSelect(
		"artcount,title,qid,isolate,issue",
		"sections","section='$section'") unless $I{F}{addsection};

	print <<EOT;
<FORM ACTION="$ENV{SCRIPT_NAME}" METHOD="POST">
	[	
		<A HREF="$I{rootdir}/admin.pl?section=$section">Stories</A> |
		<A HREF="$I{rootdir}/submit.pl?section=$section&op=list">Submissions</A> |
		<A HREF="$I{rootdir}/index.pl?section=$section">Preview</A> |
	]
	<BR><BR><B>Section name:</B><BR>
	<INPUT TYPE="TEXT" NAME="section" VALUE="$section"><BR><BR> 
	<BR><B>Article Count</B> (how many articles to display on section index)<BR>
	<INPUT TYPE="TEXT" NAME="artcount" SIZE="4" VALUE="$artcount">
		1/3rd of these will display intro text, 2/3rds just headers<BR><BR>

	<B>Title</B>
	<BR><INPUT TYPE="TEXT" NAME="title" SIZE="30" VALUE="$title"><BR>

EOT

	print qq|<BR><BR><B>Polls for this section:</B><br>\n|;
	selectGeneric("pollquestions", "qid", "qid", "question", $qid, "", "date DESC", 25);
	print qq|<BR><BR><B>Isolate mode:</B><br>\n|;
	selectGeneric("isolatemodes", "isolate", "code", "name", $isolate);
	print qq|<BR><BR><B>Issue mode:</B><br>\n|;
	selectGeneric("issuemodes", "issue", "code", "name", $issue);
	

	unless ($I{F}{addsection}) {
		my $c = sqlSelectMany("*", "sectionblocks",
		"section=" . $I{dbh}->quote($section), "ORDER by ordernum"); 
		
		if($c) {
			print <<EOT;
<BR><BR><B>edit section slashboxes (blocks)</B><BR><BR>
<TABLE BORDER="1">
EOT
			while(my $B = $c->fetchrow_hashref) {
				$B->{title} =~ s/<(.*?)>//g;
				printf <<EOT, $$B{ordernum} > 0 ? '(default)' : '';
			<TR>
				<TD>
				<B><A HREF="$I{rootdir}/admin.pl?op=blocked&bid=$B->{bid}">$B->{title}</A></B>
			<A HREF="$B->{url}">$B->{url}</A> %s 
				</TD>
			</TR>
EOT

			}
			print "</TABLE>\n";
		}

		$c->finish;
	}

	print <<EOT;
	<BR><INPUT TYPE="SUBMIT" NAME="savesection" VALUE="save section">
	<BR><INPUT TYPE="SUBMIT" NAME="addsection" VALUE="add section">
	<BR><INPUT TYPE="SUBMIT" NAME="deletesection" VALUE="delete section">
</FORM>
EOT

}

#################################################################
sub saveSection {
	my $section = shift;

	my ($rows) = sqlSelect("count(*)","sections","section = '$I{F}{section}'");

	unless ($rows) {
		$I{dbh}->do("INSERT into sections (section) VALUES('$section')"); 
		print "Inserted $section<br>\n" unless DBI::errstr;
	}

	sqlUpdate("sections", {
		qid		=> $I{F}{qid},
		title		=> $I{F}{title},
		issue		=> $I{F}{issue},
		isolate		=> $I{F}{isolate},
		artcount	=> $I{F}{artcount}
	}, "section=" . $I{dbh}->quote($I{F}{section}));

	print "Updated $section<br>\n" unless DBI::errstr;
}

main();
$I{dbh}->disconnect if $I{dbh};

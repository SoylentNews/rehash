#!/usr/bin/perl -w

###############################################################################
# submit.pl - this code inputs user submission into the system to be 
# approved by authors 
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

	my $id = getFormkeyId($I{F}{uid});
	my $formkey_earliest = time() - $I{formkey_timeframe};

	my($section, $op, $seclev, $aid) = (
		$I{F}{section}, $I{F}{op}, $I{U}{aseclev}, $I{U}{aid}
	);

	$I{F}{del} ||= "0";
	$I{F}{op}  ||= "";

	$I{F}{from}  = stripByMode($I{F}{from})  if $I{F}{from}; 
	$I{F}{subj}  = stripByMode($I{F}{subj})  if $I{F}{subj}; 
	$I{F}{email} = stripByMode($I{F}{email}) if $I{F}{email}; 

	$section = "admin" if $seclev > 100;
	header("$I{sitename} Submissions", $section);
	# print "from $I{F}{from} email $I{F}{email} subject $I{F}{subj}<BR>\n";

	#adminMenu() if $seclev > 100;

	if ($op eq "list" && ($seclev > 99 || $I{submiss_view})) {
		titlebar("100%", 'Submissions ' . ($seclev > 99 ? 'Admin' : 'List'));
		submissionEd();

	} elsif ($op eq "Update" && $seclev > 99) {
		titlebar("100%", "Deleting $I{F}{subid}");
		rmSub();
		submissionEd();

	} elsif ($op eq "GenQuickies" && $seclev > 99) {
		titlebar("100%", "Quickies Generated");
		genQuickies();
		submissionEd();

	} elsif (! $op) {
		yourPendingSubmissions();
		titlebar("100%", "$I{sitename} Submissions", "c");
		displayForm($I{U}{nickname},$I{U}{fakeemail}, $I{F}{section});

	} elsif ($op eq "PreviewStory") {
		titlebar("100%", "$I{sitename} Submission Preview", "c");

		# generate a random key to use for the form
		$I{F}{formkey} = getFormkey();

		# insert the fact that the form has been displayed,
		# but not submitted at this point
		sqlInsert("formkeys", {
			formkey		=> $I{F}{formkey},
			formname	=> 'submissions',
			id		=> $id,
			sid		=> 'submission',
			uid		=> $I{U}{uid},
			host_name	=> $ENV{REMOTE_ADDR},
			value		=> 0,
			ts		=> time()
		});

		displayForm($I{F}{from}, $I{F}{email}, $I{F}{section});

	} elsif ($op eq "viewsub" && ($seclev > 99 || $I{submiss_view})) {
		previewForm($aid, $I{F}{subid});

	} elsif ($op eq "SubmitStory") {
		titlebar("100%", "Saving");
		saveSub($id,$formkey_earliest);
		yourPendingSubmissions();

	} else {
		print "Huh?";
		# foreach (keys %{$I{U}}) { print "$_ = $I{U}{$_}<BR>" }
	}

	footer();
}

#################################################################
sub yourPendingSubmissions {
	return unless $I{U}{uid} > 0;
	my $c = sqlSelectMany("*", "submissions", "uid=$I{U}{uid}");
	if ($c->rows) {
		my($count) = sqlSelect("count(*)", "submissions", "del=0");
		titlebar("100%", "Your Recent Submissions (total:$count)");
		print <<EOT;
<P>Here are your recent submissions to $I{sitename},
and their status within the system:

<UL>
EOT

		while (my $S = $c->fetchrow_hashref) {
			print "<LI>$S->{'time'} $S->{subj} ($S->{section},$S->{tid})";
			print " (rejected) " if $S->{del} == 1;
			print " (accepted) " if $S->{del} == 2;
			print "<BR>\n";
		}

		print "</UL>\n\n";
	}
	$c->finish;
	print "<P>";
}

#################################################################
sub previewForm {
	my($aid, $subid) = @_;

	my $admin = $I{U}{aseclev} > 99;

	my($writestatus) = getvars("defaultwritestatus");
	($subid, my($email, $name, $title, $tid, $introtext,$time)) =
		sqlSelect("subid,email,name,subj,tid,story,time",
		"submissions","subid='$subid'");

	$introtext =~ s/\n\n/\n<P>/gi;
	$introtext .= " ";
	$introtext =~  s{(?!"|=)(.|\n|^)(http|ftp|gopher|telnet)://(.*?)(\W\s)?[\s]}
			{<A HREF="$2://$3"> link <\/A> }gi;
	$introtext = qq!<I>"$introtext"</I>! if $name;

	if ($email) {
		local $_ = $email;
		if (/@/) {
			$email = "mailto:$email"; 
		} elsif (!/http/) {
			$email = "http://$email";
		}

		$introtext = qq!<A HREF="$email">$name</A> writes $introtext! if $name;

	} else {
		$introtext = "$name writes $introtext" if $name;

	}

	my @fs = (
		$I{query}->textfield(-name => 'title', -default => $title, -size => 50),
		lockTest($title)
	);

	push @fs, sprintf("\n\t\tdept %s<BR>",
		$I{query}->textfield(-name => 'dept', -default => '', -size => 50)
	) if $I{use_dept};

	print <<EOT;
	<P>Submitted by <B>$name <A HREF="$email">$email</A></B> at $time

	<P>$introtext<P>
EOT

	printf <<ADMIN, @fs if $admin;
	[ <A HREF="$ENV{SCRIPT_NAME}?op=Update&subid=$subid">Delete Submission</A> ]<BR>

	<FORM ACTION="$I{rootdir}/admin.pl" METHOD="POST">
		<INPUT TYPE="hidden" NAME="subid" VALUE="$subid">
		<BR>title %s<BR>%s%s

ADMIN

	if ($admin) {
		selectTopic("tid", $tid);
		selectSection("section", $I{F}{section} || $I{defaultsection});
	}

	print <<ADMIN if $admin;

		<INPUT TYPE="SUBMIT" NAME="op" VALUE="preview"><BR>
		<BR>Intro Copy<BR>
		<TEXTAREA NAME="introtext" COLS="70" ROWS="10" WRAP="VIRTUAL">$introtext</TEXTAREA><BR>
		<INPUT TYPE="SUBMIT" NAME="op" VALUE="preview"><BR>
	</FORM>

ADMIN

	sqlUpdate("sessions", { lasttitle => $title },
		"aid=" . $I{dbh}->quote($I{U}{aid})
	);
}

#################################################################
sub rmSub {
	if ($I{F}{subid}) {
		sqlUpdate("submissions", { del => 1 }, 
			"subid=" . $I{dbh}->quote($I{F}{subid})
		);

		sqlUpdate("authors",
			{ -deletedsubmissions => 'deletedsubmissions+1' },
			"aid='$I{U}{aid}'"
		);
	}

	foreach (keys %{$I{F}}) {
		next unless /(.*)_(.*)/;
		my($t,$n) = ($1,$2);
		if ($t eq "note" || $t eq "comment" || $t eq "section") {
			$I{F}{"note_$n"} = "" if $I{F}{"note_$n"} eq " ";
			if ($I{F}{$_}) {
				my %sub = (
					note	=> $I{F}{"note_$n"},
					comment	=> $I{F}{"comment_$n"},
					section	=> $I{F}{"section_$n"}
				);

				if (!$sub{note}) {
					delete $sub{note};
					$sub{-note} = 'NULL';
				}

				sqlUpdate("submissions", \%sub,
					"subid=" . $I{dbh}->quote($n));
			}
		} else {
			my $key = $n;
			print "$key " if sqlUpdate(
				"submissions", { del => 1 }, "subid='$key'"
			) && sqlUpdate("authors",
				{ -deletedsubmissions => 'deletedsubmissions+1' },
				"aid='$I{U}{aid}'"
			);
		}
	}
}

#################################################################
sub genQuickies {
	my($stuff) = sqlSelect("story", "submissions", "subid='quickies'");
	$I{dbh}->do("DELETE FROM submissions WHERE subid='quickies'");
	$stuff = "";

	my $c = sqlSelectMany("subid,subj,email,name,story",
		"submissions", "note='Quik' and del=0"
	);

	while(my($subid, $subj, $email, $name, $story) = $c->fetchrow) {
		$stuff .= qq!\n\n<P><A HREF="mailto:$email">$name</A> writes $story\n\n!;
	}

	$c->finish;

	sqlInsert("submissions", {
		subid	=> 'quickies',
		subj	=> 'Generated Quickies',
		email	=> '',
		name	=> '',
		-'time'	=> 'now()',
		section	=> 'articles',
		tid	=> 'quickies',
		story	=> $stuff,
	});
}

#################################################################
sub submissionEd {
	my $admin = $I{U}{aseclev} > 99;
	print <<EOT if $admin;
<META HTTP-EQUIV="Refresh" CONTENT="900; URL=$ENV{SCRIPT_NAME}?op=list">
<FORM ACTION="$ENV{SCRIPT_NAME}" METHOD="POST">
<INPUT TYPE="HIDDEN" NAME="note" VALUE="$I{F}{note}">
<INPUT TYPE="HIDDEN" NAME="section" VALUE="$I{F}{section}">
EOT

	$I{F}{del} = 0 if $admin;

	my $c = sqlSelectMany("section,note,count(*)", "submissions WHERE del=$I{F}{del} GROUP BY section,note");

	print qq!\n<TABLE BORDER="0" CELLPADDING="0" CELLSPACING="3" BGCOLOR="$I{bg}[2]"><TR>\n\t!;

	my $cur_section_str = $I{F}{section} || 'All Sections'; # Unfortunately, "articles" seems to be hardcoded
	my $cur_note_str = $I{F}{note} || 'Unclassified';

	my(%all_sections, %all_notes, %sn);

	while (my($section, $note, $cnt) = $c->fetchrow) {
		my $section_str = $section;
		$all_sections{$section_str} = 1;
		my $note_str = $note || 'Unclassified';
		$all_notes{$note_str} = 1;
		$sn{$section_str}{$note_str} = $cnt;
	}

	$c->finish;

	for my $note_str (keys %all_notes) {
		$sn{'All Sections'}{$note_str} = 0;
		for (grep { $_ ne 'All Sections' } keys %sn) {
			$sn{'All Sections'}{$note_str} += $sn{$_}{$note_str};
		}
	}
	$all_sections{'All Sections'} = 1;

	print qq!<TR ALIGN="RIGHT"><TD></TD>!;

	for my $section_str (	map  { $_->[0] }
				sort { $a->[1] cmp $b->[1] }
				map  { [$_, ($_ eq 'All Sections' ? '' : $_)] }
				keys %all_sections) {

	    	my $section = $section_str eq 'All Sections' ? '' : $section_str;
		print qq!<TD>&nbsp;<B><A HREF="$ENV{SCRIPT_NAME}?section=$section&op=list">$section_str</A></B>&nbsp;</TD>!;
		print "<TD></TD>" if $section_str eq 'All Sections';
	}

	print "</TR>\n";

	for my $note_str (	map  { $_->[0] }
				sort { $a->[1] cmp $b->[1] }
				map  { [$_, ($_ eq 'Unclassified' ? '' : $_)] }
				keys %all_notes) {
		my $note = $note_str eq 'Unclassified' ? '' : $note_str;

		print qq!<TR ALIGN="RIGHT">\n!;
		print qq!<TD>&nbsp;<B><A HREF="$ENV{SCRIPT_NAME}?note=$note&op=list">$note_str</A></B>&nbsp;</TD>!;

		for my $section_str (sort keys %all_sections) {
			my $section = $section_str eq 'All Sections' ? '' : $section_str;
			$sn{$section_str}{$note_str} = 0 if !$sn{$section_str}{$note_str};
			my $bgcolor = qq! BGCOLOR="$I{bg}[1]"!
				if $note_str eq $cur_note_str && $section_str eq $cur_section_str;
			print qq!<TD$bgcolor><A HREF="$ENV{SCRIPT_NAME}?section=$section&op=list&note=$note">$sn{$section_str}{$note_str}</A>&nbsp;</TD>!;
			print "<TD></TD>" if $section_str eq 'All Sections';
		}
		print "</TR>\n";
	}

	print "</TABLE>\n";

	my $sql = "SELECT subid, subj, date_format(" . getDateOffset("time") .
		',"m/d  H:i"), tid,note,email,name,section,comment,submissions.uid,karma FROM submissions,users_info';
	$sql .= "  WHERE submissions.uid=users_info.uid AND $I{F}{del}=del AND (";
	$sql .= $I{F}{note} ? "note=" . $I{dbh}->quote($I{F}{note}) : "isnull(note)";
	$sql .= "		or note=' ' " unless $I{F}{note};
	$sql .= ")";
	$sql .= "		and tid='$I{F}{tid}' " if $I{F}{tid};
	$sql .= "         and section='$I{U}{asection}' " if $I{U}{asection};
	$sql .= "         and section='$I{F}{section}' " if $I{F}{section};
	$sql .= "	  ORDER BY time";

	# print $sql;

	my $cursor = $I{dbh}->prepare($sql);
	$cursor->execute;

	my %select = (DEFAULT => '', Hold => '', Quik => '');

	print qq!\n\n<TABLE WIDTH="95%" CELLPADDING="0" CELLSPACING="0" BORDER="0">\n!;
	while (my($subid, $subj, $time, $tid, $note, $email, $name,
		$section, $comment, $uid, $karma) = $cursor->fetchrow) {

		$select{$note || 'DEFAULT'} = ' SELECTED';
		print $admin ? <<ADMIN : <<USER;
	<TR><TD><NOBR>
		<FONT SIZE="1"><INPUT TYPE="TEXT" NAME="comment_$subid" VALUE="$comment" SIZE="15">
		<SELECT NAME="note_$subid">
			<OPTION$select{DEFAULT}></OPTION>
			<OPTION$select{Hold}>Hold</OPTION>
			<OPTION$select{Quik}>Quik</OPTION>
		</SELECT>
ADMIN
	<TR><TD>$comment</TD> <TD>$note</TD>
USER

		my $ptime = $I{submiss_ts} ? $time : '';
		selectSection("section_$subid", $section) if $admin;
		$name  =~ s/<(.*)>//g;
		$email =~ s/<(.*)>//g;

		$karma = $uid > -1 && defined $karma ? " ($karma)" : "";

		my @strs = (substr($subj, 0, 35), substr($name, 0, 20), substr($email, 0, 20));
		my $s = $section ne $I{defaultsection} ? "&section=$section" : "";
		printf(($admin ? <<ADMIN : <<USER), @strs);

		</FONT><INPUT TYPE="CHECKBOX" NAME="del_$subid">
	</NOBR></TD><TD>$ptime</TD><TD>
		<A HREF="$ENV{SCRIPT_NAME}?op=viewsub&subid=$subid&note=$I{F}{note}$s">%s&nbsp;</A>
	</TD><TD><FONT SIZE="2">%s$karma<BR>%s</FONT></TD></TR>
ADMIN
	<TD>\u$section</TD><TD>$ptime</TD>
	<TD>
		<A HREF="$ENV{SCRIPT_NAME}?op=viewsub&subid=$subid&note=$I{F}{note}">%s&nbsp;</A>
	</TD><TD><FONT SIZE="-1">%s<BR>%s</FONT></TD></TR>
	<TR><TD COLSPAN="7"><IMG SRC="$I{imagedir}/pix.gif" ALT="" HEIGHT="3"></TD></TR>
USER
	}

	my $quik = $I{F}{note} eq "Quik" ? <<EOT : '';
		<INPUT TYPE="SUBMIT" NAME="op" VALUE="GenQuickies">
EOT

	print $admin ? <<ADMIN : <<USER;
</TABLE>

<P>

<INPUT TYPE="SUBMIT" NAME="op" VALUE="Update">
$quik</FORM>

ADMIN
</TABLE>
<P>

USER

	$cursor->finish;
}	

#################################################################
# sub formLabel {
# 	return qq!<P><FONT COLOR="$I{bg}[3]"><B>!, shift, "</B></FONT>\n",
# 		@_ ? ("(", @_, ")") : "", "<BR>\n";
# }

#################################################################
sub displayForm {
	my($user, $fakeemail, $section) = @_;

	print <<EOT if $I{submiss_view};
<P><B>
	<A HREF="$ENV{SCRIPT_NAME}?op=list">View Current Pending Submissions</A>
</B></P>
EOT

	$section = "articles" unless $section;
	print qq!\n<FORM ACTION="$ENV{SCRIPT_NAME}" METHOD="POST">\n!;
	print qq|<INPUT TYPE="hidden" NAME="formkey" VALUE="$I{F}{formkey}">\n|
		if $I{F}{op} eq 'PreviewStory';

	print getblock("submit_before");

	$user = $I{F}{from} || $user;
	$fakeemail = $I{F}{email} || $fakeemail;

	print
		formLabel("Your Name", "Leave Blank to be Anonymous"),
		$I{query}->textfield(-name => 'from', -default => $user, -size=>50),

		formLabel("Your Email or Homepage", "Leave Blank to be Anonymous"),
		$I{query}->textfield(-name => 'email', -default => $fakeemail, -size => 50),

		formLabel("Subject", "Be Descriptive, Clear and Simple!"),
		$I{query}->textfield(-name => 'subj', -default => $I{F}{subj}, -size => 50),

		qq[\n<BR><FONT SIZE="2">(bad subjects='Check This Out!' or 'An Article'.  
		We get many submissions each day, and if yours isn't clear, it will
		be deleted.)</FONT>],
		formLabel("Topic and Section");

	selectTopic("tid", $I{F}{tid} || "news");
	selectSection("section", $I{F}{section} || $section);
	print qq!\n<BR><FONT SIZE="2">(Almost everything should go under Articles)</FONT>!;

	if ($I{F}{story}) {
		print "<P>";
		titlebar("100%", $I{F}{subj});
		my $tref = getTopic($I{F}{tid});
		print <<EOT;

<IMG SRC="$I{imagedir}/topics/$tref->{image}" ALIGN="RIGHT" BORDER="0"
	ALT="$tref->{alttext}" HSPACE="30" VSPACE="10"
	WIDTH="$tref->{width}" HEIGHT="$tref->{height}">

EOT

		print qq!<P>$user writes <I>"$I{F}{story}"</I></P>!;
	}

	print formLabel("The Scoop",
		"HTML is fine, but double check those URLs and HTML tags!");
	print <<EOT;

<TEXTAREA WRAP="VIRTUAL" COLS="70" ROWS="12" NAME="story">$I{F}{story}</TEXTAREA><BR>
<FONT SIZE="2">(Are you sure you included a URL?  Didja test them for typos?)</FONT><P>

<INPUT TYPE="SUBMIT" NAME="op" VALUE="PreviewStory">
EOT
	print "(You must preview once before you can submit)" unless $I{F}{subj};
	print qq!<INPUT TYPE="SUBMIT" NAME="op" VALUE="SubmitStory">\n! if $I{F}{subj};
	print "\n</FORM><P>\n\n";
}

#################################################################
sub saveSub {
	my $id = shift;
	my $formkey_earliest = shift;
	my $is_a_valid_key = 0;
	my($last_submitted,$interval);

	($last_submitted) = sqlSelect(
			"max(submit_ts)",
			"formkeys",
			"id = '$id' AND formname = 'submissions'") or ($last_submitted = 0);

	$interval = time() - $last_submitted;

	# if the interval is less than the post_limit, let them know
	my $submission_interval_string = intervalString($I{submission_speed_limit});
	my $thissub_interval_string = intervalString($interval);
	if ($interval < $I{submission_speed_limit}) {
		print <<EOT;
<B>Slow down cowboy!</B><BR>
<P>$I{sitename} requires you to wait $submission_interval_string between
each submission in order to allow everyone to have a fair chance to post a story.</P>
It's been $thissub_interval_string since your last attempt to post a submission!<BR>
EOT
	} else {
		if (length $I{F}{subj} < 2) {
			print "Please enter a reasonable subject.\n";
			displayForm($I{F}{from}, $I{F}{email}, $I{F}{section});
			return;
		}	

		print "Perhaps you would like to enter an email address or a URL next time.<P>"
			unless length $I{F}{email} > 2;

		print "This story has been submitted anonymously<P>"
			unless length $I{F}{from} > 2;

		my($times_submitted) = sqlSelect( 
			"count(*) as times_submitted", "formkeys","id = '$id' AND submit_ts >= $formkey_earliest AND formname = 'submissions'");

		if ($times_submitted < $I{max_submissions_allowed}) {

				# find out if this form has been submitted already
				my($submitted_already, $submit_ts) = sqlSelect(
					"value,submit_ts",
					"formkeys","formkey='$I{F}{formkey}' and formname = 'submissions'")
					or print <<EOT and return;
<P><B>We can't find your formkey.</B></P>
<P>Please complete the submissions form to submit a story 
EOT
			# make sure that there's a valid form key, and we only care about the last 4 hours!
			$is_a_valid_key = checkFormkey($formkey_earliest,"submissions");

			if (($I{F}{formkey} !~ /\w{10}/ || $I{F}{formkey} =~ /^(.)\1+$/ ) && !$is_a_valid_key) {
				print qq|<B>Invalid form key!</B>\n|;
			} else {

				# unless the form has been submitted, submit it
				unless ($submitted_already) {
					print "<B>There are currently ",
					sqlSelect("count(*)", "submissions", "del=0"),
					" submissions pending.</B><P>";

					print getblock("submit_after");
					my($sec, $min, $hour, $mday, $mon, $year) = localtime;

					my $subid="$hour$min$sec.$mon$mday$year";
					sqlInsert("submissions", {
						email	=> $I{F}{email},
						uid	=> $I{U}{uid},
						name	=> $I{F}{from},
						story	=> $I{F}{story},
						-'time'	=> 'now()',
						subid	=> $subid,
						subj	=> $I{F}{subj},
						tid	=> $I{F}{tid},
						section	=> $I{F}{section}
					});

					# update formkeys to show that there has been a successful pos t,
					# and increment the value from 0 to 1 (shouldn't ever get past 1)
					# meaning that yes, this form has been submitted, so don't try i t again.
					sqlUpdate("formkeys", { 
						-value		=> 'value+1',
						cid		=> 0,
						submit_ts	=> time(),
						comment_length	=> length($I{F}{subj})
					}, "formkey=" . $I{dbh}->quote($I{F}{formkey}));

				} else {
					my $interval_string = intervalString($interval);
					# else print an error
					print <<EOT;
			<B>Easy does it!</B>
			<P>This submission has been submitted already, $interval_string ago.
			No need to try again.</P>
EOT
				}
			}
		} else {
			print qq|You have submitted $times_submitted. The maximum submissions for a day are $I{max_submissions_allowed}.\n|;
		}
	}
}

main();
$I{dbh}->disconnect if $I{dbh};
1;

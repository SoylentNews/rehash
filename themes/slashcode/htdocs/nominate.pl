#!/usr/bin/perl -w

###############################################################################
# nominate.pl - this page displays the nominations page 
#
# Copyright (C) 1997 Rob "CmdrTaco" Malda
# malda@slashdot.org
# coded by Jonathan "CowboyNeal" Pater
# pater@slashdot.org
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

	my $op = $I{F}{op};

	if ($op eq "userlogin" && $I{U}{uid} > 0) {
		my $refer = $I{F}{returnto} || $I{rootdir};
		redirect($refer);
		return;
	}

	header("$I{sitename} Award Nominations", "awards");

	# and now the carnage begins
	if ($I{U}{uid} < 0) {
		crapMesg();
	} elsif ($op eq "Save") {
		saveNoms();
		displayForm();
	} else {
		displayForm();
	}

	writelog("nominate", $I{U}{nickname});
	footer();
}

sub crapMesg {
	print <<EOT;
<H1>Sorry!</H1>
<P>This page is only available to registered $I{sitename} users.
If you don't like this, then go <A HREF="$I{rootdir}/users.pl">create
an account</A>! It's fast, free, and safe. Worried about spam, etc?
Don't be. We won't send you stuff (unless you ask for it) and you
can hide your real email address when posting. Check out our
<A HREF="$I{rootdir}/privacy.html">privacy policy</A> if
you're still not convinced.
EOT
}

#################################################################
sub displayForm {
	print <<EOT;
<H1>Nominations</H1>
<P>Nominate some people for the following awards. <B>Note:</B>
You can update your nominations if you change your mind. So join
in the discussions and see who should be nominated.

<FORM METHOD="POST" ACTION="$ENV{SCRIPT_NAME}">
EOT

	my %supercats = getSuperCats();

	foreach my $supercat (sort keys %supercats) {
		my @cats = getCats($supercat);

		titlebar("95%", $supercats{$supercat});

		foreach my $cat (@cats) {
			my($nominee) = sqlSelect("nominee",
				"users_nominate", "uid=$I{U}{uid} AND category='$cat'"
			);
			print <<EOT;
<P><B><FONT COLOR="#006666">$cat</FONT></B><BR>
<INPUT TYPE="TEXT" SIZE="40" MAXLENGTH="64" NAME="nom_$cat" VALUE="$nominee"><BR>
EOT
		}

		print "<P>";
	}

	print <<EOT;
<INPUT NAME="op" TYPE="SUBMIT" VALUE="Save">
</FORM>
EOT
}

#################################################################
sub saveNoms {
	my %supercats = getSuperCats();

	foreach my $supercat (keys %supercats) {
		my @cats = getCats($supercat);

		foreach my $cat (@cats) {
			my($uid) = sqlSelect("uid","users_nominate",
				"uid=$I{U}{uid} AND category='$cat'"
			);
			if ($uid eq "") {
				my $sql = "INSERT INTO users_nominate (uid, " .
					"category, nominee) VALUES ($I{U}{uid}, ".
					$I{dbh}->quote($cat) . ", " .
					$I{dbh}->quote($I{F}{"nom_$cat"}) . ")";

				# print "<BR>$sql<BR>";
				$I{dbh}->do($sql);

			} else {
				sqlUpdate("users_nominate",
					{ nominee => $I{F}{"nom_$cat"} },
					"uid=$I{U}{uid} AND category=" .
					$I{dbh}->quote($cat)
				);
			}
		}
	}

	# print "<H1>You Lucky Dog!</H1>\n";
	print "<P>Your nominations have been saved.";
}

#################################################################
sub getSuperCats {
	return ("abig"		=> "The Big Award (\$30k)",
		"bserious"	=> "Serious Awards (\$10k)",
		"cfun"		=> "Fun Awards (\$2k)",
		"dinsane"	=> "Insane Awards (a Beanie and a hug from CowboyNeal)"
	);
}

#################################################################
sub getCats {
	my $cat = shift;

	if ($cat eq "abig") {
		return ("Most Improved Open Source Project");

	} elsif ($cat eq "bserious") {
		return ("Most Improved Kernel Module",
			"Unsung Hero",
			"Best Open Source Advocate",
			"Best Newbie Helper",
			"Most Deserving Open Source Charity");

	} elsif ($cat eq "cfun") {
		return ("Best Unix Desktop Eyecandy",
			"Best Unix Desktop Earcandy",
			"Best Desktop Theme",
			"Best Perl Module",
			"Best Apache Module",
			"Best Open Source Text Editor",
			"Best Designed Interface in a Graphical Application",
			"Best Designed Interface in a Non-Graphical Application",
			"Most Deserving of a \$2000 Award",
			"Best Open Source-Related Book");

	} elsif ($cat eq "dinsane") {
		return ("Best Dressed",
			"Favorite $I{sitename} Comment Poster",
			"Favorite $I{sitename} Author",
			"Best $I{sitename} Story of 1999",
			"Big Dumb Patent Bully",
			"Big Dumb Domain Bully",
			"Clue Stick Award for FUD in Journalism",
			"The Hemos Award (only Hemos is eligible)");
	}
}

main();
$I{dbh}->disconnect if $I{dbh};
1;

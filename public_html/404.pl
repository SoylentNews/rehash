#!/usr/bin/perl -w

###############################################################################
# 404.pl - this code displays the error page
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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA	 02111-1307, USA.
#
#
#	 $Id$
###############################################################################
use strict;
use lib '../';
use vars '%I';
use Slash;

sub main {
	*I = getSlashConf();
	getSlash();

	$ENV{REQUEST_URI} ||= "";

	my $url = stripByMode(substr($ENV{REQUEST_URI}, 1), 'exttrans');

	my $admin = $I{adminmail};

	header("404 File Not Found", '', '404 File Not Found');

	print "<H1>404 File Not Found</H1>\nThe requested URL ($url) is not found.\n";

	my($new_url, $errnum) = fixHref($url, 1);

	if ($errnum && $errnum !~ /^\d+$/) {
	    print qq|<P>$errnum, so you probably want to be here: <A HREF="$new_url">$new_url</A>\n|;
	} elsif ($errnum == 1) {
		print "<P>Someone <I>probably</I> just forgot the \"http://\" part of the URL, and you might really want to be here: <A HREF=\"$new_url\">$new_url</A>.\n";
	} elsif ($errnum == 2) {
		print "<P>Someone <I>probably</I> just forgot the \"ftp://\" part of the URL, and you might really want to be here: <A HREF=\"$new_url\">$new_url</A>.\n";
	} elsif ($errnum == 3) {
		print "<P>Someone <I>probably</I> just forgot the \"mailto:\" part of the URL, and you might really want to be here: <A HREF=\"$new_url\">$new_url</A>.\n";
	} elsif ($errnum == 6) {
		print "<P>All of the older articles have been moved to /articles/older, so you probably want to be here: <A HREF=\"$new_url\">$new_url</A>.\n";
	} elsif ($errnum == 7) {
		print "<P>All of the older features have been moved to /features/older, so you probably want to be here: <A HREF=\"$new_url\">$new_url</A>.\n";
	} elsif ($errnum == 8) {
		print "<P>All of the older book reviews have been moved to /books/older, so you probably want to be here: <A HREF=\"$new_url\">$new_url</A>.\n";
	} elsif ($errnum == 9) {
		print "<P>All of the older Ask $I{sitename} articles have been moved to /askslashdot/older, so you probably want to be here: <A HREF=\"$new_url\">$new_url</A>.\n";
	}

	print "<P>If you feel like it, mail the url, and where ya came from to <A HREF=\"mailto:$I{adminmail}\">$admin</A>\n";

	# $r->log_error("Borked Browser $url $ENV{HTTP_REFERER} $ENV{HTTP_USER_AGENT}") if $url=~/gif/;
	writelog("404","404");
	footer();
}

main();

1;

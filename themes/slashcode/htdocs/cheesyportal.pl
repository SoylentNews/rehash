#!/usr/bin/perl -w

###############################################################################
# cheesyportal.pl - this code displays a bunch of portals 
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

	header("Cheesy Portal");
	# Display Blocks
	titlebar("100%", "Cheesy $I{sitename} Portal Page");
	my $strsql="SELECT block,title,blocks.bid,url
		   FROM blocks,sectionblocks
		  WHERE section='index'
		    AND portal > -1
		    AND blocks.bid=sectionblocks.bid 
		  GROUP BY blocks.bid
		  ORDER BY ordernum";

	my $c = $I{dbh}->prepare($strsql);
	$c->execute;

	print qq!<MULTICOL COLS="3">\n!;
	my $b;
	while (my($block, $title, $bid, $url) = $c->fetchrow) {
		if ($bid eq "mysite") {
			$b = portalbox(200, "$I{U}{nickname}'s Slashbox",
				$I{U}{mylinks} ||  $block
			);

		} elsif ($bid =~ /_more$/) {
		} elsif ($bid eq "userlogin") {
		} else {
			$b = portalbox(200, $title, $block, "", $url);
		}

		print $b;
	}

	$c->finish;

	print "\n</MULTICOL>\n";

	footer();

	writelog("cheesyportal") unless $I{F}{ssi};
}

main();

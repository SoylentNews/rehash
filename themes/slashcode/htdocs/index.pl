#!/usr/bin/perl -w
###############################################################################
# index.pl - this code displays the index page 
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
# pre stories cache update
use strict;
use lib '../';
use vars '%I';
use Slash;

#################################################################
sub main {
	*I = getSlashConf();
	getSlash();

	if ($I{F}{op} eq 'userlogin' && $I{F}{upasswd} && $I{F}{unickname}) {
		redirect($ENV{SCRIPT_NAME});
		return;
	}

	# $I{F}{mode} = $I{U}{mode}="dynamic" if $ENV{SCRIPT_NAME};

	for ($I{F}{op}) {
		/^u$/ and upBid($I{F}{bid});
		/^d$/ and dnBid($I{F}{bid});
		/^x$/ and rmBid($I{F}{bid});
	}

	my $SECT = getSection($I{F}{section});
	$SECT->{mainsize} = int($SECT->{artcount} / 3);

	my $title = $SECT->{title};
	$title = "$I{sitename}: $title" unless $SECT->{isolate};
	
	header($title, $SECT->{section});
	checkForM2(); # if $I{U}{uid}==1;
		
	my $block = Slash::getEvalBlock("index");
	my $execme = Slash::prepEvalBlock($block);

	eval $execme;

	print "\n<H1>Error:$@</H1>\n" if $@;

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

	writelog('index', $I{F}{section} || 'index') unless $I{F}{ssi};
}

#################################################################
sub saveUserBoxes {
	my(@a) = @_;

	$I{U}{exboxes} = @a ? sprintf("'%s'", join "','", @a) : '';
	sqlUpdate('users_index', { exboxes => $I{U}{exboxes} },
		"uid=$I{U}{uid}", 1) if $I{U}{uid} > 0;
}

#################################################################
sub getUserBoxes {
	my $boxes = $I{U}{exboxes};
	$boxes =~ s/'//g;
	return split m/,/, $boxes;
}

#################################################################
sub upBid {
	my($bid) = @_;
	my @a = getUserBoxes();

	if ($a[0] eq $bid) {
		($a[0], $a[@a-1]) = ($a[@a-1], $a[0]);
	} else {
		for (my $x = 1; $x < @a; $x++) {
			($a[$x-1], $a[$x]) = ($a[$x], $a[$x-1]) if $a[$x] eq $bid;
		}
	}

	saveUserBoxes(@a);
}

#################################################################
sub dnBid {
	my($bid) = @_;
	my @a = getUserBoxes();
	if ($a[@a-1] eq $bid) {
		($a[0], $a[@a-1]) = ($a[@a-1], $a[0]);
	} else {
		for(my $x = @a-1; $x > -1; $x--) {
			($a[$x], $a[$x+1]) = ($a[$x+1], $a[$x]) if $a[$x] eq $bid;
		}
	}

	saveUserBoxes(@a);
}

#################################################################
sub rmBid {
	my($bid) = @_;
	my @a = getUserBoxes();
	foreach (my $x = @a; $x >= 0; $x--) {
		splice @a, $x, 1 if $a[$x] eq $bid;
	}
	saveUserBoxes(@a);
}

#################################################################
sub getAllSlashBoxes {
	return if defined $I{boxBank};
	undef $I{sectionBoxes};

	my $c = sqlSelectMany(
		'blocks.bid as bid,title,url,section,portal,ordernum',	
		'sectionblocks,blocks',
		'sectionblocks.bid=blocks.bid ORDER BY ordernum ASC'
	);

	my %tmp;
	while (my $SB = $c->fetchrow_hashref) {
		$I{boxBank}{$SB->{bid}} = $SB;	# Set the Slashbox
		next unless $SB->{ordernum} > 0;	# Set the index if applicable
		push @{$tmp{$SB->{section}}}, $SB->{bid};
		# push @{$I{sectionBoxes}{$SB->{section}}}, $SB->{bid};
	}
	$I{sectionBoxes} = {%tmp};
	$c->finish;
}

#################################################################
sub displayStandardBlocks {
	my ($SECT, $olderStuff) = @_;
	return if $I{U}{noboxes};

	my $getblocks = $SECT->{section} || 'index';
	my @boxes;
	getAllSlashBoxes();

	if ($I{U}{exboxes} && $getblocks eq 'index') {
		$I{U}{exboxes} =~ s/'//g;
		@boxes = split m/,/, $I{U}{exboxes};
	} else {
		@boxes = @{$I{sectionBoxes}{$getblocks}} if ref $I{sectionBoxes}{$getblocks};
	}

	foreach my $bid (@boxes) {
		if ($bid eq 'mysite') {
			print portalbox(
				200, "$I{U}{nickname}'s Slashbox",
				$I{U}{mylinks} || 'This is your user space.  Love it.',
				$bid
			);
		} elsif ($bid =~ /_more$/) {
			print portalbox(200,"Older Stuff",
				getOlderStories($olderStuff, $SECT),
				$bid) if $olderStuff;
		} elsif ($bid eq "userlogin" && $I{U}{uid} > 0) {
			# Don't do nuttin'
		} elsif ($bid eq "userlogin") {
			my $SB = $I{boxBank}{$bid};
			my $B = eval prepBlock $I{blockBank}{$bid};
			print portalbox(200, $SB->{title}, $B, $SB->{bid}, $SB->{url});
		} else {
			my $SB = $I{boxBank}{$bid};
			my $B = $I{blockBank}{$bid};
			print portalbox(200, $SB->{title}, $B, $SB->{bid}, $SB->{url});
		}
	}
}

#################################################################
# pass it how many, and what.
sub displayStories {
	my $cursor = shift;
	my($today, $x) = ('', 1);
	my $cnt = int($I{U}{maxstories} / 3);

	while (my($sid, $thissection, $title, $time, $cc, $d, $hp) = $cursor->fetchrow) {
		my @threshComments = split m/,/, $hp;

		# Prefix story with section if section != this section and no
		# colon
		my($S) = displayStory($sid, '', 'index');

		my $execme = getEvalBlock('story_link');

		print eval $execme;

		if ($@) {
			print "<!-- story_link eval failed!\n$@\n-->\n";
		}

		print linkStory({
			'link'	=> "<B>Read More...</B>",
			sid	=> $sid,
			section	=> $thissection
		});

		if ($S->{bodytext} || $cc) {
			print ' | ', linkStory({
				'link'	=> length($S->{bodytext}) . ' bytes in body',
				sid	=> $sid,
				mode	=> 'nocomment'
			}) if $S->{bodytext};

			$cc = $threshComments[0];
			print ' | <B>' if $cc;

			if ($cc && $I{U}{threshold} > -1
				&& $cc ne $threshComments[$I{U}{threshold}]+1) {

				print linkStory({
					sid	  => $sid,
					threshold => $I{U}{threshold},
					'link'	  => $threshComments[$I{U}{threshold} + 1]
				});
				print ' of ';
			}

			print linkStory({
				sid		=> $sid, 
				threshold	=> '-1', 
				'link'		=> $cc
			}) if $cc;

			print ' </B>comment', $cc > 1 ? 's' : '' if $cc;

		}
		print qq' | <A HREF="$I{rootdir}/admin.pl?op=edit&sid=$sid">Edit</A>'
			if $I{U}{aseclev} > 100;

		$execme = getEvalBlock('story_trailer');
		print eval $execme; 

		if ($@) {
			print "<!-- story_trailer eval failed!\n$@\n-->\n";
		}

		my($w) = join ' ', (split m/ /, $time)[0 .. 2];
		$today ||= $w;
#		print "<!-- <$today> <$w> <$x> <$cnt> <$time> -->\n";
		last if ++$x > $cnt && $today ne $w;
	}
}

#################################################################
sub checkForM2 {
	return unless $I{U}{willing};
	return if $I{U}{uid} < 1;
	return if $I{U}{karma} < 0;
	my($d) = sqlSelect('to_days(now()) - to_days(lastmm)',
		'users_info', "uid=$I{U}{uid}");
	return unless $d;
	print qq'Have you <A HREF="$I{rootdir}/metamod.pl">Meta Moderated</A> Today?<BR>';
}


#################################################################
main();
#################################################################

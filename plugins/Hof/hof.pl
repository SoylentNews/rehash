#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

##################################################################
sub main {
	my $form	= getCurrentForm();
	my $constants	= getCurrentStatic();

	header(getData('head'));

	my($hofDB);

	if ($constants->{backup_db_user}) {
		$hofDB = getObject('Slash::Hof', { db_type => 'reader' });
	} else {
		$hofDB = getObject('Slash::Hof');
	}

	my @topcomments = ( );
# getCommentsTop() comes in two versions as of 2001/07/12.  The old
# version takes impossibly long to do a 3-way join on 2.5 million
# rows.  The new version isn't really written yet.  So I'm just
# commenting this out until the new version is done.  See
# Slash/DB/MySQL/MySQL.pm getCommentsTop(). - Jamie 2001/07/12
#	my $topcomments;
#	$topcomments = $hofDB->getCommentsTop($form->{sid});
#	for (@$topcomments) {
#		my $top = $topcomments[@topcomments] = {};
#		# leave as "aid" for now
#		@{$top}{qw(section sid anickname title pid subj cdate sdate uid cid score)} = @$_;
#		my $user_email = $hofDB->getUser($top->{uid}, ['fakeemail', 'nickname']);
#		@{$top}{'fakeemail', 'nickname'} = @{$user_email}{'fakeemail', 'nickname'};
#	}

	slashDisplay('main', {
		width		=> '98%',
		actives		=> $hofDB->countStories(),
		visited		=> $hofDB->countStoriesTopHits(),
		activea		=> $hofDB->countStoriesAuthors(),
		activep		=> $hofDB->countPollquestions(),
		activesub	=> $hofDB->countStorySubmitters(),
		currtime	=> timeCalc(scalar localtime),
		topcomments	=> \@topcomments,
	});

# this is commented out ... ?
# Not I. -Brian
# 	if (0) {  #  only do this in static mode
# 		print "<P>";
# 		titlebar("100%", "Most Popular Slashboxes");
# 		my $boxes = $I{dbobject}->getDescription('sectionblocks');
# 		my(%b, %titles);
# 
# 		while (my($bid, $title) = each %$boxes) {
# 			$b{$bid} = 1;
# 			$titles{$bid} = $title;
# 		}
# 
# 
# 		#Something tells me we could simplify this with some
# 		# thought -Brian
# 		foreach my $bid (keys %b) {
# 			$b{$bid} = $I{dbobject}->countUsersIndexExboxesByBid($bid);
# 		}
# 
# 		my $x;
# 		foreach my $bid (sort { $b{$b} <=> $b{$a} } keys %b) {
# 			$x++;
# 			$titles{$bid} =~ s/<(.*?)>//g;
# 			print <<EOT;
# 
# <B>$b{$bid}</B> <A HREF="$I{rootdir}/users.pl?op=preview&amp;bid=$bid">$titles{$bid}</A><BR>
# EOT
# 			last if $x > 10;
# 		}
# 	}

	footer();
}

#################################################################
createEnvironment();
main();

1;

#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

sub main {
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();


	if ($form->{op} eq 'userlogin' && !$user->{is_anon}) {
		my $refer = $form->{returnto} || $ENV{SCRIPT_NAME};
		redirect($refer);
		return;
	}

	# why is this commented out?  -- pudge
	# $form->{mode} = $user->{mode}="dynamic" if $ENV{SCRIPT_NAME};

	for ($form->{op}) {
		my $c;
		upBid($form->{bid}), $c++ if /^u$/;
		dnBid($form->{bid}), $c++ if /^d$/;
		rmBid($form->{bid}), $c++ if /^x$/;
		redirect($ENV{SCRIPT_NAME}), return if $c;
	}

	my $section = getSection($form->{section});
	$section->{artcount} = $user->{maxstories} unless $user->{is_anon};
	$section->{mainsize} = int($section->{artcount} / 3);

	my $title = getData('head', { section => $section });
	header($title, $section->{section});

	my $stories = $slashdb->getNewStories($section->{section});
	my $Stories = displayStories($stories);
	my $StandardBlocks = displayStandardBlocks($section, $stories);

	slashDisplay('index', {
		is_moderator	=> scalar $slashdb->checkForMetaModerator($user),
		stories		=> $Stories,
		boxes		=> $StandardBlocks,
	});

	footer();

	writeLog($form->{section});
}

#################################################################
# Should this method be in the DB library?
# absolutely.  we should hide the details there.  but this is in a lot of
# places (modules, index, users); let's come back to it later.  -- pudge
sub saveUserBoxes {
	my(@a) = @_;
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	$user->{exboxes} = @a ? sprintf("'%s'", join "','", @a) : '';
	$slashdb->setUser($user->{uid}, { exboxes => $user->{exboxes} })
		unless $user->{is_anon};
}

#################################################################
sub getUserBoxes {
	my $boxes = getCurrentUser('exboxes');
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
		for (my $x = @a-1; $x > -1; $x--) {
			($a[$x], $a[$x+1]) = ($a[$x+1], $a[$x]) if $a[$x] eq $bid;
		}
	}
	saveUserBoxes(@a);
}

#################################################################
sub rmBid {
	my($bid) = @_;
	my @a = getUserBoxes();
	for (my $x = @a; $x >= 0; $x--) {
		splice @a, $x, 1 if $a[$x] eq $bid;
	}
	saveUserBoxes(@a);
}

#################################################################
sub displayStandardBlocks {
	my($section, $olderStuff) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	return if $user->{noboxes};

	my(@boxes, $return);
	my($boxBank, $sectionBoxes) = $slashdb->getPortalsCommon();
	my $getblocks = $section->{section} || 'index';

	if ($user->{exboxes} && $getblocks eq 'index') {
		@boxes = getUserBoxes();
	} else {
		@boxes = @{$sectionBoxes->{$getblocks}}
			if ref $sectionBoxes->{$getblocks};
	}

	for my $bid (@boxes) {
		if ($bid eq 'mysite') {
			$return .= portalbox(
				$constants->{fancyboxwidth},
				getData('userboxhead'),
				$user->{mylinks} || getData('userboxdefault'),
				$bid
			);

		} elsif ($bid =~ /_more$/ && $olderStuff) {
			$return .= portalbox(
				$constants->{fancyboxwidth},
				getData('morehead'),
				getOlderStories($olderStuff, $section),
				$bid
			) if @$olderStuff;

		} elsif ($bid eq 'userlogin' && ! $user->{is_anon}) {
			# do nothing!

		} elsif ($bid eq 'userlogin' && $user->{is_anon}) {
			$return .= portalbox(
				$constants->{fancyboxwidth},
				$boxBank->{$bid}{title},
				slashDisplay('userlogin', 0, { Return => 1, Nocomm => 1 }),
				$boxBank->{$bid}{bid},
				$boxBank->{$bid}{url}
			);

		} elsif ($bid eq 'poll' && !$constants->{poll_cache}) {
			$return .= portalbox(
				$constants->{fancyboxwidth},
				$boxBank->{$bid}{title},
				pollbooth('', 1),
				$boxBank->{$bid}{bid},
				$boxBank->{$bid}{url}
			);

		} else {
			$return .= portalbox(
				$constants->{fancyboxwidth},
				$boxBank->{$bid}{title},
				$slashdb->getBlock($bid, 'block'),
				$boxBank->{$bid}{bid},
				$boxBank->{$bid}{url}
			);
		}
	}

	return $return;
}

#################################################################
# pass it how many, and what.
sub displayStories {
	my($stories) = @_;
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $user = getCurrentUser();

	my($today, $x) = ('', 1);
	my $cnt = int($user->{maxstories} / 3);
	my $return;

	# shift them off, so we do not display them in the Older
	# Stuff block later (simulate the old cursor-based
	# method)
	while ($_ = shift @{$stories}) {
		my($sid, $thissection, $title, $time, $cc, $d, $hp) = @{$_};
		my @links;
		my @threshComments = split m/,/, $hp;  # posts in each threshold
		my($storytext, $story) = displayStory($sid);

		$return .= $storytext;

		push @links, linkStory({
			'link'	=> getData('readmore'),
			sid	=> $sid,
			section	=> $thissection
		});

		if ($story->{bodytext} || $cc) {
			push @links, linkStory({
				'link'	=> length($story->{bodytext}) . ' ' . getData('bytes'),
				sid	=> $sid,
				mode	=> 'nocomment'
			}) if $story->{bodytext};

			my @cclink;
			my $thresh = $threshComments[$user->{threshold} + 1];

			if ($cc = $threshComments[0]) {
				if ($user->{threshold} > -1 && $cc ne $thresh) {
					$cclink[0] = linkStory({
						sid		=> $sid,
						threshold	=> $user->{threshold},
						'link'		=> $thresh
					});
				}

				$cclink[1] = linkStory({
					sid		=> $sid, 
					threshold	=> -1, 
					'link'		=> $cc || 0
				});

				push @cclink, $thresh, ($cc || 0);
				push @links, getData('comments', { cc => \@cclink });
			}

			if ($thissection ne $constants->{defaultsection} && !getCurrentForm('section')) {
				my($section) = getSection($thissection);
				push @links, getData('seclink', {
					name	=> $thissection,
					section	=> $section
				});
			}

			push @links, getData('editstory', { sid => $sid }) if $user->{seclev} > 100;
		}

		$return .= slashDisplay('storylink', {
			links	=> \@links,
		}, { Return => 1});

		my($w) = join ' ', (split m/ /, $time)[0 .. 2];
		$today ||= $w;
		last if ++$x > $cnt && $today ne $w;
	}

	return $return;
}

#################################################################
createEnvironment();
main();

1;

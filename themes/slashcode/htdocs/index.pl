#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;
use Data::Dumper;

sub main {
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();


	my($stories, $Feature, $Stories, $storystruct, $section);
	if ($form->{op} eq 'userlogin' && !$user->{is_anon}) {
		my $refer = $form->{returnto} || $ENV{SCRIPT_NAME};
		redirect($refer);
		return;
	}

	# why is this commented out?  -- pudge
	# $form->{mode} = $user->{mode} = "dynamic" if $ENV{SCRIPT_NAME};

	for ($form->{op}) {
		my $c;
		upBid($form->{bid}), $c++ if /^u$/;
		dnBid($form->{bid}), $c++ if /^d$/;
		rmBid($form->{bid}), $c++ if /^x$/;
		redirect($ENV{SCRIPT_NAME}), return if $c;
	}

	if ($form->{section}) {
		$section = $slashdb->getSection($form->{section});
	} else {
		$section->{section} = 'index';
		$section->{issue} = 1;
	}

	$section->{artcount} = $user->{maxstories} unless $user->{is_anon};
	$section->{mainsize} = int($section->{artcount} / 3);

	my $title = getData('head', { section => $section });
	header($title, $section->{section} ne 'index' ? $section->{section} : '');

	my $limit = $section->{section} eq 'index' ?
	    $user->{maxstories} : $section->{artcount};

	$stories = $slashdb->getStoriesEssentials(
		$limit, 
		($form->{section} ne 'index') ? $form->{section} : '',
		'',
	);

	# this makes sure that existing sites don't
	# have to worry about being affected by this
	# change
	$storystruct = displayStories($stories);
	$Stories = $storystruct->{stories}{full};
	$Feature = $storystruct->{feature}{full};

	my $StandardBlocks = displayStandardBlocks($section, $stories);

	slashDisplay('index', {
		is_moderator	=> scalar $slashdb->checkForMetaModerator($user),
		stories		=> $Stories,
		feature		=> $Feature,
		storystruct	=> $storystruct,
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
	my($section, $older_stories_essentials) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $cache = getCurrentCache();

	return if $user->{noboxes};

	my(@boxes, $return, $boxcache);
	my($boxBank, $sectionBoxes) = $slashdb->getPortalsCommon();
	my $getblocks = $section->{section} || 'index';

	# two variants of box cache: one for index with portalmap,
	# the other for any other section, or without portalmap

	if ($user->{exboxes} && $getblocks eq 'index') {
		@boxes = getUserBoxes();
		$boxcache = $cache->{slashboxes}{index_map}{$user->{light}} ||= {};
	} else {
		@boxes = @{$sectionBoxes->{$getblocks}}
			if ref $sectionBoxes->{$getblocks};
		push(@boxes, @{$sectionBoxes->{'all_sections'}})
			if ref $sectionBoxes->{'all_sections'};
		$boxcache = $cache->{slashboxes}{$getblocks}{$user->{light}} ||= {};
	}

	for my $bid (@boxes) {
		if ($bid eq 'mysite') {
			$return .= portalbox(
				$constants->{fancyboxwidth},
				getData('userboxhead'),
				$user->{mylinks} || getData('userboxdefault'),
				$bid
			);

		} elsif ($bid =~ /_more$/ && $older_stories_essentials) {
			$return .= portalbox(
				$constants->{fancyboxwidth},
				getData('morehead'),
				getOlderStories($older_stories_essentials, $section),
				$bid
			) if @$older_stories_essentials;

		} elsif ($bid eq 'userlogin' && ! $user->{is_anon}) {
			# do nothing!

		} elsif ($bid eq 'userlogin' && $user->{is_anon}) {
			$return .= $boxcache->{$bid} ||= portalbox(
				$constants->{fancyboxwidth},
				$boxBank->{$bid}{title},
				slashDisplay('userlogin', 0, { Return => 1, Nocomm => 1 }),
				$boxBank->{$bid}{bid},
				$boxBank->{$bid}{url}
			);

		} elsif ($bid eq 'poll' && !$constants->{poll_cache}) {
			# this is only executed if poll is to be dynamic
			$return .= portalbox(
				$constants->{fancyboxwidth},
				$boxBank->{$bid}{title},
				pollbooth('_currentqid', 1),
				$boxBank->{$bid}{bid},
				$boxBank->{$bid}{url}
			);

		# this could grab from the cache in the future, perhaps ... ?
		} elsif ($bid eq 'rand' || $bid eq 'srandblock') {
			# don't use cached title/bid/url from getPortalsCommon
			my $data = $slashdb->getBlock($bid, [qw(title block bid url)]);
			$return .= portalbox(
				$constants->{fancyboxwidth},
				@{$data}{qw(title block bid url)}
			);

		} else {
			$return .= $boxcache->{$bid} ||= portalbox(
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
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $form      = getCurrentForm();
	my $user      = getCurrentUser();

	my($today, $x) = ('', 1);
	my $cnt = int($user->{maxstories} / 3);
	my ($return,$counter,$feature_retrieved);

	# shift them off, so we do not display them in the Older
	# Stuff block later (simulate the old cursor-based
	# method)
	while ($_ = shift @{$stories}) {
		my($sid, $thissection, $title, $time, $cc, $d, $hp, $secs, $tid) = @{$_};
		my($tmpreturn, $category, $feature_sid, $other, @links);
		my @threshComments = split m/,/, $hp;  # posts in each threshold

		if ($constants->{organise_stories}) {
		    $category = $slashdb->getStory($sid,$constants->{organise_stories});
		}
		$category ||= 'stories';
		$counter->{$category} ||= $x;
		# feature_retrieved keeps the code from checking again for that section
		# if the feature story has already been retrieved
		if ($constants->{feature_story_enabled} && ! $feature_retrieved->{$thissection}) {
			$feature_sid = $slashdb->getSection($thissection,'feature_story');
			if ($sid eq $feature_sid) {
				$other->{story_template} = 'dispFeature';
				$category = 'feature';
				# ok, we have the feature story for this section
				$feature_retrieved->{$thissection} = 1;
			}	
		}
		
		my($storytext, $story) = displayStory($sid, '', $other);

		if ($constants->{get_titles}) {
			my $titlelink = slashDisplay('storyTitleOnly', { story => $story }, {Return => 1});

			$return->{$category}{titles} .= $titlelink; 
		}

		$tmpreturn .= $storytext;
	
		push @links, linkStory({
			'link'	=> getData('readmore'),
			sid	=> $sid,
			tid	=> $tid,
			section	=> $thissection
		});

		my $link;

		if ($constants->{body_bytes}) {
			$link = length($story->{bodytext}) . ' ' .
				getData('bytes');
		} else {
			my $count = countWords($story->{introtext}) +
				countWords($story->{bodytext});
			$link = sprintf '%d %s', $count, getData('words');
		}

		if ($story->{bodytext} || $cc) {
			push @links, linkStory({
				'link'	=> $link,
				sid	=> $sid,
				tid	=> $tid,
				mode	=> 'nocomment',
				section	=> $thissection
			}) if $story->{bodytext};

			my @cclink;
			my $thresh = $threshComments[$user->{threshold} + 1];

			if ($cc = $threshComments[0]) {
				if ($user->{threshold} > -1 && $cc ne $thresh) {
					$cclink[0] = linkStory({
						sid		=> $sid,
						tid		=> $tid,
						threshold	=> $user->{threshold},
						'link'		=> $thresh,
						section		=> $thissection
					});
				}
			}

			$cclink[1] = linkStory({
				sid		=> $sid,
				tid		=> $tid,
				threshold	=> -1,
				'link'		=> $cc || 0,
				section		=> $thissection
			});

			push @cclink, $thresh, ($cc || 0);
			push @links, getData('comments', { cc => \@cclink })
				if $cc || $thresh;
		}

		if ($thissection ne $constants->{defaultsection} && !$form->{section}) {
			my($section) = $slashdb->getSection($thissection);
			push @links, getData('seclink', {
				name	=> $thissection,
				section	=> $section
			});
		}

		push @links, getData('editstory', { sid => $sid }) if $user->{seclev} > 100;

		my $link_template = $category eq 'feature' ? 'feature_storylink' : 'storylink';

		# I added sid so that you could set up replies from the front page -Brian
		$tmpreturn .= slashDisplay($link_template, {
			links	=> \@links,
			sid	=> $sid,
		}, { Return => 1});

		$return->{$category}{full} .= $tmpreturn;

	    my($w) = join ' ', (split m/ /, $time)[0 .. 2];
	    $today ||= $w;
	    last if ++$counter->{$category} > $cnt && $today ne $w;
	}

	return $return;
}

#################################################################
createEnvironment();
main();

1;

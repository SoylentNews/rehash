#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;
use Slash::XML;
use Time::HiRes;

sub main {
my $start_time = Time::HiRes::time;
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	my($stories, $Stories); # could this be MORE confusing please? kthx
	if ($form->{op} eq 'userlogin' && !$user->{is_anon}
			# Any login attempt, successful or not, gets
			# redirected to the homepage, to avoid keeping
			# the password or nickname in the query_string of
			# the URL (this is a security risk via "Referer")
		|| $form->{upasswd} || $form->{unickname}
	) {
		my $refer = $form->{returnto} || $ENV{SCRIPT_NAME};
		redirect($refer); return;
	}

	# why is this commented out?  -- pudge
	# $form->{mode} = $user->{mode} = "dynamic" if $ENV{SCRIPT_NAME};

	for ($form->{op}) {
		my $c;
		upBid($form->{bid}), $c++ if /^u$/;
		dnBid($form->{bid}), $c++ if /^d$/;
		rmBid($form->{bid}), $c++ if /^x$/;
		redirect($ENV{HTTP_REFERER} || $ENV{SCRIPT_NAME}), return if $c;
	}


	my $rss = $constants->{rss_allow_index} && $form->{content_type} eq 'rss' && (
		$user->{is_admin}
			||
		($constants->{rss_allow_index} > 1 && $user->{is_subscriber})
			||
		($constants->{rss_allow_index} > 2 && !$user->{is_anon})
	);

	# $form->{logtoken} is only allowed if using rss
	if ($form->{logtoken} && !$rss) {
		redirect($ENV{SCRIPT_NAME});
	}

	my $skin_name = $form->{section};
	my $skid = $skin_name
		? $reader->getSkidFromName($skin_name)
		: determineCurrentSkin();
	setCurrentSkin($skid);
	my $gSkin = getCurrentSkin();
	$skin_name = $gSkin->{name};

	# Decide what our limit is going to be.
	my $limit;
	if ($form->{issue}) {
		if ($user->{is_anon}) {
			$limit = $gSkin->{artcount_max} * 3;
		} else {
			$limit = $user->{maxstories} * 7;
		}
	} elsif ($user->{is_anon}) {
		$limit = $gSkin->{artcount_max};
	} else {
		$limit = $user->{maxstories};
	}

	# TIMING START
	# From here to the "TIMING END", the bulk of the work in index.pl is
	# done.  Times listed at "TIMING MARKPOINT" are as measured on
	# Slashdot, normalized such that the median request takes 1 second.
	# Times listed are elapsed time from the previous markpoint.

	my $gse_hr = { tids => $gSkin->{nexus} };
	$gse_hr->{limit} = $user->{maxstories} if !$user->{is_anon} && $user->{maxstories};
	$stories = $reader->getStoriesEssentials($gse_hr);

	# We may, in this listing, have a story from the Mysterious Future.
	# If so, there are three possibilities:
	# 1) This user is a subscriber, in which case they see it (and its
	#    timestamp gets altered to the MystFu text)
	# 2) This user is not a subscriber, but is logged-in, and logged-in
	#    non-subscribers are allowed to *know* that there is such a
	#    story without being able to see it, so we make them aware.
	# 3) This user is not a subscriber, and non-subscribers are not
	#    to be made aware of this story's existence, so ignore it.
	my $future_plug = 0;

	# Do we want to display the plug saying "there's a future story,
	# subscribe and you can see it"?  Yes if the user is logged-in
	# but not a subscriber, but only if the first story is actually
	# in the future.  Just check the first story;  they're in order.
	if ($stories->[0]{is_future}
		&& !$user->{is_subscriber}
		&& !$user->{is_anon}
		&& $constants->{subscribe_future_plug}) {
		$future_plug = 1;
	}

	# TIMING MARKPOINT
	# Median 0.145 seconds, 90th percentile 0.222 seconds

	return do_rss($reader, $constants, $user, $form, $stories, $skin_name) if $rss;

#	# See comment in plugins/Journal/journal.pl for its call of
#	# getSkinColors() as well.
#	$user->{currentSection} = $section->{section};
	Slash::Utility::Anchor::getSkinColors();

	# displayStories() pops stories off the front of the @$stories array.
	# Whatever's left is fed to displayStandardBlocks for use in the
	# index_more block (aka Older Stuff).
	my $linkrel = {};
	$Stories = displayStories($stories, $linkrel);

	# TIMING MARKPOINT
	# Median 0.437 seconds, 90th percentile 1.078 seconds

	# damn you, autovivification!
	my($first_date, $last_date);
	if (@$stories) {
		($first_date, $last_date) = ($stories->[0]{time}, $stories->[-1]{time});
		$first_date =~ s/(\d\d\d\d)-(\d\d)-(\d\d).*$/$1$2$3/;
		$last_date  =~ s/(\d\d\d\d)-(\d\d)-(\d\d).*$/$1$2$3/;
	}

	my $StandardBlocks = displayStandardBlocks($gSkin, $stories,
		{ first_date => $first_date, last_date => $last_date }
	);

	# TIMING MARKPOINT
	# Median 0.235 seconds, 90th percentile 0.513 seconds

	my $title = getData('head', { skin => $skin_name });
	header({ title => $title, link => $linkrel }) or return;

	# TIMING MARKPOINT
	# Median 0.090 seconds, 90th percentile 0.145 seconds

	slashDisplay('index', {
		metamod_elig	=> scalar $reader->metamodEligible($user),
		future_plug	=> $future_plug,
		stories		=> $Stories,
		boxes		=> $StandardBlocks,
	});

	# TIMING MARKPOINT
	# Median 0.052 seconds, 90th percentile 0.084 seconds

	footer();

	writeLog($skin_name);

	# TIMING MARKPOINT
	# Median 0.037 seconds, 90th percentile 0.059 seconds
}


sub do_rss {
	my($reader, $constants, $user, $form, $stories, $skin_name) = @_;
	my $gSkin = getCurrentSkin();
	my @rss_stories;
	for (@$stories) {
		my $story = $reader->getStory($_->{sid});
		$story->{introtext} = parseSlashizedLinks($story->{introtext});
		$story->{introtext} = processSlashTags($story->{introtext});
		$story->{introtext} =~ s{(HREF|SRC)\s*=\s*"(//[^/]+)}
		                        {$1 . '="' . url2abs($2)}sieg;
		push @rss_stories, { story => $story };
	}

	my $title = getData('rsshead', { skin => $skin_name });
	my $name = lc($gSkin->{basedomain}) . '.rss';

	xmlDisplay('rss', {
		channel	=> {
			title	=> $title,
		},
		version 		=> $form->{rss_version},
		image			=> 1,
		items			=> \@rss_stories,
		rdfitemdesc		=> 1,
		rdfitemdesc_html	=> 1,
	}, {
		filename		=> $name,
	});

	writeLog($skin_name);
	return;
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
	my($skin, $older_stories_essentials, $other) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $cache = getCurrentCache();
	my $gSkin = getCurrentSkin();

	return if $user->{noboxes};

	my(@boxes, $return, $boxcache);
	my($boxBank, $skinBoxes) = $reader->getPortalsCommon();
	my $getblocks = $skin->{skid} || $constants->{mainpage_skid};

	# two variants of box cache: one for index with portalmap,
	# the other for any other section, or without portalmap

	if ($user->{exboxes} && ($getblocks == $constants->{mainpage_skid} || $constants->{slashbox_sections})) {
		@boxes = getUserBoxes();
		$boxcache = $cache->{slashboxes}{index_map}{$user->{light}} ||= {};
	} else {
		@boxes = @{$skinBoxes->{$getblocks}}
			if ref $skinBoxes->{$getblocks};
		$boxcache = $cache->{slashboxes}{$getblocks}{$user->{light}} ||= {};
	}

	for my $bid (@boxes) {
		if ($bid eq 'mysite') {
			$return .= portalbox(
				$constants->{fancyboxwidth},
				getData('userboxhead'),
				$user->{mylinks} || getData('userboxdefault'),
				$bid,
				'',
				$getblocks
			);

		} elsif ($bid =~ /_more$/ && $older_stories_essentials) {
			$return .= portalbox(
				$constants->{fancyboxwidth},
				getData('morehead'),
				getOlderStories($older_stories_essentials, $skin,
					{ first_date => $other->{first_date}, last_date => $other->{last_date} }),
				$bid,
				'',
				$getblocks
			) if @$older_stories_essentials;

		} elsif ($bid eq 'userlogin' && ! $user->{is_anon}) {
			# do nothing!

		} elsif ($bid eq 'userlogin' && $user->{is_anon}) {
			$return .= $boxcache->{$bid} ||= portalbox(
				$constants->{fancyboxwidth},
				$boxBank->{$bid}{title},
				slashDisplay('userlogin', 0, { Return => 1, Nocomm => 1 }),
				$boxBank->{$bid}{bid},
				$boxBank->{$bid}{url},
				$getblocks
			);

		} elsif ($bid eq 'poll' && !$constants->{poll_cache}) {
			# this is only executed if poll is to be dynamic
			$return .= portalbox(
				$constants->{fancyboxwidth},
				$boxBank->{$bid}{title},
				pollbooth('_currentqid', 1),
				$boxBank->{$bid}{bid},
				$boxBank->{$bid}{url},
				$getblocks
			);
		} elsif ($bid eq 'friends_journal' && $constants->{plugin}{Journal} && $constants->{plugin}{Zoo}) {
			my $journal = getObject("Slash::Journal");
			my $zoo = getObject("Slash::Zoo");
			my $uids = $zoo->getFriendsUIDs($user->{uid});
			my $articles = $journal->getsByUids($uids, 0,
				$constants->{journal_default_display}, { titles_only => 1})
				if ($uids && @$uids);
			# We only display if the person has friends with data
			if ($articles && @$articles) {
				$return .= portalbox(
					$constants->{fancyboxwidth},
					getData('friends_journal_head'),
					slashDisplay('friendsview', { articles => $articles}, { Return => 1 }),
					$bid,
					"$gSkin->{rootdir}/my/journal/friends",
					$getblocks
				);
			}
		# this could grab from the cache in the future, perhaps ... ?
		} elsif ($bid eq 'rand' || $bid eq 'srandblock') {
			# don't use cached title/bid/url from getPortalsCommon
			my $data = $reader->getBlock($bid, [qw(title block bid url)]);
			$return .= portalbox(
				$constants->{fancyboxwidth},
				@{$data}{qw(title block bid url)},
				$getblocks
			);

		} else {
			$return .= $boxcache->{$bid} ||= portalbox(
				$constants->{fancyboxwidth},
				$boxBank->{$bid}{title},
				$reader->getBlock($bid, 'block'),
				$boxBank->{$bid}{bid},
				$boxBank->{$bid}{url},
				$getblocks
			);
		}
	}

	return $return;
}

#################################################################
# pass it how many, and what.
sub displayStories {
	my($stories, $linkrel) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $form      = getCurrentForm();
	my $user      = getCurrentUser();
	my $gSkin     = getCurrentSkin();
	my $ls_other  = { user => $user, reader => $reader, constants => $constants };
	my($today, $x) = ('', 0);
	my $cnt = int($user->{maxstories} / 3);
	my($return, $counter);

	# shift them off, so we do not display them in the Older
	# Stuff block later (simulate the old cursor-based
	# method)
	my $story;

	# get some of our constant messages but do it just once instead
	# of for every story
	my $msg;
	$msg->{readmore} = getData('readmore');
	if ($constants->{body_bytes}) {
		$msg->{bytes} = getData('bytes');
	} else {
		$msg->{words} = getData('words');
	}
	
	while ($story = shift @$stories) {
		my($tmpreturn, $other, @links);

		# This user may not be authorized to see future stories;  if so,
		# skip them.
		next if $story->{is_future}
			&& (!$user->{is_subscriber} || !$constants->{subscribe_future_secs});

		# Check the day this story was posted (in the user's timezone).
		# Compare it to what we believe "today" is (which will be the
		# first eligible story in this list).  If this story's day is
		# not "today", and if we've already displayed enough stories
		# to sufficiently fill the homepage (typically 10), then we're
		# done -- put the story back on the list (so it'll correctly
		# appear in the Older Stuff box) and exit.
		my $day = timeCalc($story->{time}, '%A %B %d');
		my($w) = join ' ', (split / /, $day)[0 .. 2];
		$today ||= $w;
		if (++$x > $cnt && $today ne $w) {
			unshift @$stories, $story;
			last;
		}

		my @threshComments = split /,/, $story->{hitparade};  # posts in each threshold

		$other->{is_future} = 1 if $story->{is_future};
		my $storytext = displayStory($story->{sid}, '', $other);

		$tmpreturn .= $storytext;

		push @links, linkStory({
			'link'	=> $msg->{readmore},
			sid	=> $story->{sid},
			tid	=> $story->{tid},
			skin	=> $story->{primaryskid}
		}, "", $ls_other);

		my $link;

		if ($constants->{body_bytes}) {
			$link = $story->{body_length} . ' ' .
				$msg->{bytes};
		} else {
			$link = sprintf '%d %s', $story->{word_count}, $msg->{words};
		}

		if ($story->{body_length} || $story->{commentcount}) {
			push @links, linkStory({
				'link'	=> $link,
				sid	=> $story->{sid},
				tid	=> $story->{tid},
				mode	=> 'nocomment',
				skin	=> $story->{primaryskid}
			}, "", $ls_other) if $story->{body_length};

			my @commentcount_link;
			my $thresh = $threshComments[$user->{threshold} + 1];

			if ($story->{commentcount} = $threshComments[0]) {
				if ($user->{threshold} > -1 && $story->{commentcount} ne $thresh) {
					$commentcount_link[0] = linkStory({
						sid		=> $story->{sid},
						tid		=> $story->{tid},
						threshold	=> $user->{threshold},
						'link'		=> $thresh,
						skin		=> $story->{primaryskid}
					}, "", $ls_other);
				}
			}

			$commentcount_link[1] = linkStory({
				sid		=> $story->{sid},
				tid		=> $story->{tid},
				threshold	=> -1,
				'link'		=> $story->{commentcount} || 0,
				skin		=> $story->{primaryskid}
			}, "", $ls_other);

			push @commentcount_link, $thresh, ($story->{commentcount} || 0);
			push @links, getData('comments', { cc => \@commentcount_link })
				if $story->{commentcount} || $thresh;
		}

		if ($story->{primaryskid} != $constants->{mainpage_skid} && $gSkin->{skid} == $constants->{mainpage_skid}) {
			my $skin = $reader->getSkin($story->{primaryskid});
			my $url;

			if ($skin->{rootdir}) {
				$url = $skin->{rootdir} . '/';
			} elsif ($user->{is_anon}) {
				$url = $gSkin->{rootdir} . '/' . $story->{name} . '/';
			} else {
				$url = $gSkin->{rootdir} . '/' . $gSkin->{index_handler} . '?section=' . $skin->{name};
			}

			push @links, [ $url, $skin->{hostname} || $skin->{title} ];
		}

		if ($user->{seclev} >= 100) {
			push @links, [ "$gSkin->{rootdir}/admin.pl?op=edit&sid=$story->{sid}", getData('edit') ];
		}

		# I added sid so that you could set up replies from the front page -Brian
		$tmpreturn .= slashDisplay('storylink', {
			links	=> \@links,
			sid	=> $story->{sid},
		}, { Return => 1 });

		$return .= $tmpreturn;
	}

	unless ($constants->{index_no_prev_next_day}) {
		my($today, $tomorrow, $yesterday, $week_ago) = getOlderDays($form->{issue});
		$return .= slashDisplay('next_prev_issue', {
			today		=> $today,
			tomorrow	=> $tomorrow,
			yesterday	=> $yesterday,
			week_ago	=> $week_ago,
			linkrel		=> $linkrel,
		}, { Return => 1 });
	}

	return $return;
}

#################################################################
createEnvironment();
main();

1;

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
	my $constants	= getCurrentStatic();
	my $user	= getCurrentUser();
	my $form	= getCurrentForm();
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

	my $gSkin = getCurrentSkin();
	my $skin_name = $gSkin->{name};

	my $gse_hr = { };
	$gse_hr->{tid} = [ $gSkin->{nexus} ];
	if ($gSkin->{skid} == $constants->{mainpage_skid}) {
		my $always_tid_str = join ",",
			$user->{story_always_topic},
			$user->{story_always_nexus};
		push @{$gse_hr->{tid}}, split /,/, $always_tid_str
			if $always_tid_str;
	}

	my @never_tids = split /,/, $user->{story_never_nexus};
	if ($constants->{story_never_topic_allow} == 2
		|| ($user->{is_subscriber} && $constants->{story_never_topic_allow} == 1)
	) {
		push @never_tids, split /,/, $user->{story_never_topic};
	}
	@never_tids =
		grep { /^'?\d+'?$/ && $_ != $gSkin->{nexus} }
		@never_tids;
	$gse_hr->{tid_exclude} = [ @never_tids ] if @never_tids;
	$gse_hr->{uid_exclude} = [ split /,/, $user->{story_never_author} ]
		if $user->{story_never_author};

	$stories = $reader->getStoriesEssentials($gse_hr);

	Slash::Utility::Anchor::getSkinColors();

	my $linkrel = {};
	$Stories = displayStories($stories, $linkrel);

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

	my $title = getData('head', { skin => $skin_name });
	header({ title => $title, link => $linkrel }) or return;

	my $dilemma_reader = getObject('Slash::Dilemma', { db_type => 'reader' });
	my $dilemma_db = getObject('Slash::Dilemma');

	my $info = $dilemma_reader->getDilemmaInfo();
	my $species_hr = $dilemma_reader->getDilemmaSpeciesInfo();
	my $species_order = [
		sort { $species_hr->{$b}{alivecount} <=> $species_hr->{$a}{alivecount} }
		keys %$species_hr
	];

	slashDisplay('maininfo', {
		info		=> $info,
		species		=> $species_hr,
		species_order	=> $species_order,
	});

	slashDisplay('index', {
		metamod_elig    => 0,
		future_plug     => 0,
		stories         => $Stories,
		boxes           => $StandardBlocks,
	});

	footer();

	writeLog($skin_name);
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
		
	if ($user->{slashboxes}
		&& ($getblocks == $constants->{mainpage_skid} || $constants->{slashbox_sections})
	) {                     
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
# XXXSKIN I'm turning custom numbers of maxstories off for now, so all
# users get the same number.  This will improve query cache hit rates and
# right now we need all the edge we can get.  Hopefully we can get this
# back on soon. - Jamie 2004/07/17
#       my $user_maxstories = $user->{maxstories};
# Here, maxstories should come from the skin, and $cnt should be
# named minstories and that should come from the skin too.
	my $user_maxstories = getCurrentAnonymousCoward("maxstories");
	my $cnt = int($user_maxstories / 3);
	my($return, $counter);

	# get some of our constant messages but do it just once instead
	# of for every story
	my $msg;
	$msg->{readmore} = getData('readmore');
	if ($constants->{body_bytes}) {
		$msg->{bytes} = getData('bytes');
	} else {
		$msg->{words} = getData('words');
	}

	# Pull the story data we'll be needing into a cache all at once,
	# to avoid making multiple calls to the DB.
#       my $n_future_stories = scalar grep { $_->{is_future} } @$stories;
#       my $n_for_cache = $cnt + $n_future_stories;
#       $n_for_cache = scalar(@$stories) if $n_for_cache > scalar(@$stories);
	my @stoids_for_cache =
		map { $_->{stoid} }
		grep { !$_->{is_future} }
		@$stories;
#       @stoids_for_cache = @stoids_for_cache[0..$n_for_cache-1]
#               if $#stoids_for_cache > $n_for_cache;
	my $stories_data_cache;
	$stories_data_cache = $reader->getStoriesData(\@stoids_for_cache)
		if @stoids_for_cache;

	# Shift them off, so we do not display them in the Older Stuff block
	# later (this simulates the old cursor-based method from circa 1997
	# which was actually not all that smart, but umpteen layers of caching
	# makes it quite tolerable here in 2004 :)
	my $story;

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
		my $storytext = displayStory($story->{sid}, '', $other, $stories_data_cache);

		$tmpreturn .= $storytext;

		push @links, linkStory({
			'link'  => $msg->{readmore},
			sid     => $story->{sid},
			tid     => $story->{tid},
			skin    => $story->{primaryskid}
		}, "", $ls_other);

		my $link;

		if ($constants->{body_bytes}) {
			$link = "$story->{body_length} $msg->{bytes}";
		} else {
			$link = "$story->{word_count} $msg->{words}";
		}

		if ($story->{body_length} || $story->{commentcount}) {
			push @links, linkStory({
				'link'  => $link,
				sid     => $story->{sid},
				tid     => $story->{tid},
				mode    => 'nocomment',
				skin    => $story->{primaryskid}
			}, "", $ls_other) if $story->{body_length};

			my @commentcount_link; 
			my $thresh = $threshComments[$user->{threshold} + 1];
		
			if ($story->{commentcount} = $threshComments[0]) {
				if ($user->{threshold} > -1 && $story->{commentcount} ne $thresh) {
					$commentcount_link[0] = linkStory({
						sid             => $story->{sid},
						tid             => $story->{tid},
						threshold       => $user->{threshold},
						'link'          => $thresh,
						skin            => $story->{primaryskid}
					}, "", $ls_other);
				}
			}

			$commentcount_link[1] = linkStory({
				sid             => $story->{sid},
				tid             => $story->{tid},
				threshold       => -1,
				'link'          => $story->{commentcount} || 0,
				skin            => $story->{primaryskid}
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
			links   => \@links,
			sid     => $story->{sid},
		}, { Return => 1 });

		$return .= $tmpreturn;
	}

	return $return;
}

#################################################################
createEnvironment();
main();

1;

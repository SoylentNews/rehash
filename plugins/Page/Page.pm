# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Page;

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;
use Data::Dumper;

use vars qw($VERSION @EXPORT);
use base 'Exporter';
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

#################################################################
# Ok, so we want a nice module to do the front page and utilise 
# subsections. We also want to scrap the old way of doign things.
# I now present to you ... Page
# Patrick 'CaptTofu' Galbraith
# 6.9.02

#################################################################

sub new {
	my($class, $user) = @_;

	my $self = {};

	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $form      = getCurrentForm();

	my $plugin = getCurrentStatic('plugin');
	return unless $plugin->{'Page'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;

	return $self;
}

#################################################################

sub displayStoriesByTitle {
	my($self, $section, $other) = @_;

	$other->{titles_only} = 1;
	my $storystruct = $self->displayStories($section,$other);

	# persistance can bite one in the ass ;)
	$other->{titles_only} = 0;

	return($storystruct);
}

#################################################################
# Handles display of a pre-fetched essentials list or a 
# list of story data.
#
# Ideally, all display routines would then do the basic fetch 
# (ie thru getStoriesEssentials, or something like it) and
# use this routine for display, but that modification can be left
# until someone has the time to do it. 	- Cliff 2002/08/10

sub displayStoryList {
	my($self, $list, $other) = @_;

	my $returnable = [];
	for (@{$list}) {
		my $data;

		if (ref $_ eq 'HASH') {
			if ($other->{title_only}) {
				$data->{widget} = 
					self->getStoryTitleContent($_);
			} else {
				$data->{widget} = 
					$self->getStoryContent($_) .
					$self->getLinksContent($_, $other);
			}
			$data->{sid} = $_->{sid};
			$data->{fulldata} = $_ if $other->{retrieve_data};
		} elsif (ref $_ eq 'ARRAY') {
			# Handle data from getStoryEssentials()
			my($sid, $time, $title) = @{$_}{qw(sid time title)}; #[0, 9, 2];

			$data->{essentials} = $_ if $other->{retrieve_essentials};
			if ($other->{titles_only}) {
				$data->{widget} = $self->getStoryTitleContent({ 
					sid 	=> $sid,
					'time' 	=> $time,
					title 	=> $title,
				});
				$data->{sid} = $sid;
			} else {
				my $story = $self->prepareStory($sid);
				$data->{fulldata} = $story if $other->{retrieve_data};
	
				$data->{sid} = $sid;
				$data->{widget} = 
					$self->getStoryContent($story) .
					$self->getLinksContent($story, $other);
			} 
		}

		push @{$returnable}, $data;
	}

	return $returnable;
}

#################################################################

sub displayStories {
	my($self, $section, $other) = @_;

	my $form = getCurrentForm();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $gSkin = getCurrentSkin();

	my $misc = {};
	my $tid = $other->{tid};
	if ($section) {
		my $skin = $self->getSkin($section);
		$tid ||= $self->getNexusFromSkid($skin->{skid});
	}

	$tid ||= $gSkin->{nexus} || '';

	my $limit = $other->{count};
	$limit ||= $self->getSection($section, 'artcount');

	my $storystruct = [];

	my $stories = $self->getStoriesEssentials({ limit => $limit, tid => $tid });

	my $i = 0;

	# Now the loop below can be replaced by:
	# 	return $self->displayStoryList($stories, $other)
	# - Cliff
	while (my $story = shift @{$stories}) {
		my($sid, $primaryskid, $time, $title) = @{$story}{qw(sid primaryskid time title)}; #[0, 1, 2, 9];
		my $atstorytime;
		my $storyskin = $self->getSkin($primaryskid);
		my $section = $storyskin->{name};
		if ($other->{titles_only}) {
			my $storycontent = $self->getStoryTitleContent({ 
					sid 	=> $sid, 
					'time' 	=> $time, 
					title 	=> $title,
					section	=> $section
			});
			$storystruct->[$i]{widget} = $storycontent
		} else {
			my $storyref = $self->prepareStory($sid);
			my $storycontent = '';
			$storycontent .= $self->getStoryContent($storyref);
			$storycontent .= $self->getLinksContent(
				$storyref, $other
			);
			$storystruct->[$i]{widget} = $storycontent;
		} 
		$storystruct->[$i]{essentials} = $story 
			if $other->{retrieve_essentials};
		$storystruct->[$i++]{sid} = $sid;

		# getStoriesEssentials may have returned more than we
		# asked for, in case we wanted to display the rest in
		# the Older Stories slashbox.  Abort once we reach the
		# number we asked for.
		last if $i >= $limit;
	}

	return($storystruct);
}

#########################################################

sub prepareStory {
	my($self, $sid) = @_;	

	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	# get the body, introtext... 
	my $storyref = $self->getStory($sid);
	my $storyskin = $self->getSkin($storyref->{primaryskid});
	$storyref->{section} = $storyskin->{name} if $storyskin;

	return if ! $storyref;

	if ($storyref->{is_future}) {
		$storyref->{atstorytime} = $constants->{subscribe_future_name};
	} else {
		$storyref->{atstorytime} = $user->{aton} . " " . timeCalc($storyref->{'time'});
	}

	$storyref->{introtext} = parseSlashizedLinks($storyref->{introtext});
	$storyref->{bodytext} =  parseSlashizedLinks($storyref->{bodytext});

	$storyref->{authorref} = $self->getAuthor($storyref->{uid});

	$storyref->{topicref} = $self->getTopic($storyref->{tid});
	$storyref->{topicref}{image} = "$constants->{imagedir}/topics/$storyref->{topicref}{image}" if $storyref->{topicref}{image} =~ /^\w+\.\w+$/; 

	$storyref->{sectionref} = $self->getSection($storyref->{section});

	return($storyref);
}


#########################################################

sub getLinksContent { 
	my($self, $storyref, $other) = @_;

	if ($other->{custom_links}) {
		# For when the default links just aren't what we want, we
		# just build and display them in a special template.
		return slashDisplay('customLinks', {
			story => $storyref,
			style => $other->{style},
		}, { Return => 1 });
	}

	my(@links, $link, $thresh, @cclink);	

	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();
	my $gSkin     = getCurrentSkin();

	# posts in each threshold
	my @threshComments = split m/,/, $storyref->{hitparade}; 

	push @links, linkStory({
		'link'	=> getData('readmore'),
		sid	=> $storyref->{sid},
		tid	=> $storyref->{tid},
		section	=> $storyref->{section},
	});

	if ($constants->{body_bytes}) {
		$link = length($storyref->{bodytext}) . ' ' .  getData('bytes');
	} else {
		my $count = countWords($storyref->{introtext}) + countWords($storyref->{bodytext});
		$link = sprintf '%d %s', $count, getData('words');
	}

	if ($storyref->{bodytext} || $storyref->{commentcount}) {
		push @links, linkStory({
			'link'	=> $link,
			sid	=> $storyref->{sid},
			tid	=> $storyref->{tid},
			mode => 'nocomment',
			section	=> $storyref->{section},
		}) if $storyref->{bodytext};
	
		my $thresh = $threshComments[$user->{threshold} + 1];
	
		if ($storyref->{commentcount} = $threshComments[0]) {
			if ($user->{threshold} > -1 && $storyref->{commentcount} ne $thresh) {
				$cclink[0] = linkStory({
					sid		=> $storyref->{sid},
					tid		=> $storyref->{tid},
					threshold	=> $user->{threshold},
					'link'		=> $thresh,
					section		=> $storyref->{thissection},
				});
			}
		}
	}
	$cclink[1] = linkStory({
		sid		=> $storyref->{sid},
		tid		=> $storyref->{tid},
		threshold	=> -1,
		'link'		=> $storyref->{commentcount} || 0,
		section		=> $storyref->{section},
	});
	
	push @cclink, $thresh, ($storyref->{commentcount} || 0);
	push @links, getData('comments', { cc => \@cclink }) if $storyref->{commentcount} || $thresh;
	
	if ($storyref->{section} ne $constants->{defaultsection} 
		&& !$form->{section}) {

		my $reader = getObject('Slash::DB', { db_type => 'reader' });
		my $SECT = $reader->getSection($storyref->{section});
		my $url;

		if ($SECT->{rootdir}) {
			$url = "$SECT->{rootdir}/";
		} elsif ($user->{is_anon}) {
			$url = "$gSkin->{rootdir}/$storyref->{section}/";
		} else {
			$url = "$gSkin->{rootdir}/index.pl?section=$storyref->{section}";
		}

		push @links, [ $url, $SECT->{hostname} || $SECT->{title} ];
	}

	if ($user->{seclev} >= 100) {
		push @links, [
			"$gSkin->{rootdir}/admin.pl?op=edit&sid=$storyref->{sid}",
			'Edit'
		];
	}

	my $storycontent = 
		slashDisplay('storylink', {
			links	=> \@links,
			sid	=> $storyref->{sid},
		}, { Skin => 'default', Return => 1});

	return($storycontent);
}

#########################################################

sub getStoryContent {
	my($self, $storyref) = @_;	

	my $storycontent = slashDisplay('dispStory', {
		topic	=> $storyref->{topicref},
		section	=> $storyref->{sectionref},
		author	=> $storyref->{authorref},
		story	=> $storyref,
	},{ Return => 1});	
	
	return($storycontent);
}

#########################################################

sub getStoryTitleContent {
	my($self, $storyref) = @_;	

	my $storycontent = slashDisplay('storyTitleOnly', 
				{ story => $storyref },
				{ Return => 1 },
			);
	return($storycontent);
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
	my($self, $skin_passed, $older_stories_essentials) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $cache = getCurrentCache();
	
	my $skin = $slashdb->getSkin($skin_passed);

	return if $user->{noboxes};

	my(@boxes, $return, $boxcache);
	my($boxBank, $skinBoxes) = $slashdb->getPortalsCommon();
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
				$bid
			);

		} elsif ($bid =~ /_more$/ && $older_stories_essentials) {
			$return .= portalbox(
				$constants->{fancyboxwidth},
				getData('morehead'),
				getOlderStories($older_stories_essentials, $skin),
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

1;

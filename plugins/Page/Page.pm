# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
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
	my ($class, $user) = @_;

	my $self = {};

	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $form      = getCurrentForm();

	my $plugins = $slashdb->getDescriptions('plugins');
	return unless $plugins->{'Page'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;

	return $self;
}

#################################################################

sub displayStoriesByTitle {
	my ($self, $section, $other) = @_;

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
	my ($self, $list, $other) = @_;

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
			my($sid, $time, $title) = @{$_}[0, 9, 2];

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
	my ($self, $section, $other) = @_;

	my $form = getCurrentForm();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	my $misc = {};
	$misc->{subsection} = $other->{subsection};
	my $tid = $other->{tid} || '';

	my $limit = $other->{count};
	if ($misc->{subsection}) {
		my $subsections = $self->getDescriptions(
			'section_subsection_names', $section
		); 
		# from title to id
		$misc->{subsection} = $subsections->{$other->{subsection}};
		$limit ||= $self->getSubSection(
			$misc->{subsection}, 'artcount'
		);
	} else {
		$limit ||= $self->getSection($section, 'artcount');
	}

	my $storystruct = [];

	my $stories = $self->getStoriesEssentials(
		$limit, $section, $tid, $misc
	);
	my $i = 0;

	# Now the loop below can be replaced by:
	# 	return $self->displayStoryList($stories, $other)
	# - Cliff
	while (my $story = shift @{$stories}) {
		my $sid = $story->[0];
		my $title = $story->[2];
		my $time = $story->[9];
		my $storytime = timeCalc($time, '%B %d, %Y');

		if ($other->{titles_only}) {
			my $storycontent = $self->getStoryTitleContent({ 
					sid 	=> $sid, 
					'time' 	=> $time, 
					title 	=> $title
			});
			$storystruct->[$i]{widget} = $storycontent;
		} else {
			my $storyref = $self->prepareStory($sid);
			$storyref->{other_topics} = 
				$self->getStoryTopics($sid, 2);

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
	}

	return($storystruct);
}

#########################################################

sub prepareStory {
	my($self, $sid) = @_;	

	my $constants = getCurrentStatic();

	# get the body, introtext... 
	my $storyref = $self->getStory($sid);

	return if ! $storyref;

	$storyref->{storytime} = timeCalc($storyref->{'time'});

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
	my ($self, $storyref, $other) = @_;

	if ($other->{custom_links}) {
		# For when the default links just aren't what we want, we
		# just build and display them in a special template.
		return slashDisplay('customLinks', {
			story => $storyref,
			style => $other->{style},
		}, { Return => 1 });
	}

	my (@links, $link, $thresh,@cclink);	

	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();

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
		my ($section) = $self->getSection($storyref->{section});

		push @links, getData('seclink', {
			name	=> $storyref->{section},
			section	=> $section
		});
	}
	
	push @links, getData('editstory', 
		{ sid => $storyref->{sid} }) if $user->{seclev} > 100;

	my $storycontent = 
		slashDisplay('storylink', {
			links	=> \@links,
			sid	=> $storyref->{sid},
		}, { Page => 'index', Section => 'default', Return => 1});

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
	},{ Page => 'index', Return => 1});	
	
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

1;

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

	my $slashdb = getCurrentDB();
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
sub displayStories {
	my ($self, $section, $other) = @_;

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();


	my $misc = {};
	$misc->{subsection} = $other->{subsection};
	my $tid = $other->{tid} ? $other->{tid} : '';

	my $limit = '';

	if ($misc->{subsection}) {
		my $subsections = $slashdb->getDescriptions('section_subsection_names', $section); 
		# from title to id
		$misc->{subsection} = $subsections->{$other->{subsection}};
		$limit = $other->{count} || $slashdb->getSubSection($misc->{subsection}, 'artcount');
	} else {
		$limit = $other->{count} || $slashdb->getSection($section, 'artcount');
	}

	my $storystruct = [];

	my $stories = $slashdb->getStoriesEssentials($limit, $section, $tid, $misc);
	my $i = 0;
	while (my $story = shift @{$stories}) {
		my $sid = $story->[0];
		my $title = $story->[2];
		my $time = $story->[9];
		my $storytime = timeCalc($time, '%B %d, %Y');

		my $storyref = {};

		if ($other->{titles_only}) {
			my $storycontent = $self->getStoryTitleContent({ 
					sid 	=> $sid, 
					'time' 	=> $time, 
					title 	=> $title
			});

			$storystruct->[$i]{sid} = $sid;
			$storystruct->[$i]{widget} = $storycontent;
			$i++;

		} else {
			$storyref = $self->prepareStory($sid);

			my $storycontent = '';
			$storycontent .= $self->getStoryContent($storyref);
			$storycontent .= $self->getLinksContent($storyref);
			$storystruct->[$i]{sid} = $sid;
			$storystruct->[$i]{widget} = $storycontent;
			$i++;
		} 

	}
	return($storystruct);
}

#########################################################
sub prepareStory {
	my($self, $sid) = @_;	

	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	# get the body, introtext... 
	my $storyref = $slashdb->getStory($sid);

	return if ! $storyref;

	$storyref->{storytime} = timeCalc($storyref->{'time'});

	$storyref->{introtext} = parseSlashizedLinks($storyref->{introtext});
	$storyref->{bodytext} =  parseSlashizedLinks($storyref->{bodytext});

	$storyref->{authorref} = $slashdb->getAuthor($storyref->{uid});

	$storyref->{topicref} = $slashdb->getTopic($storyref->{tid});
	$storyref->{topicref}{image} = "$constants->{imagedir}/topics/$storyref->{topicref}{image}" if $storyref->{topicref}{image} =~ /^\w+\.\w+$/; 

	$storyref->{sectionref} = $slashdb->getSection($storyref->{section});

	return($storyref);
}


#########################################################
sub getLinksContent { 
	my ($self,$storyref) = @_;

	my (@links, $link, $thresh,@cclink);	

	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	# posts in each threshold
	my @threshComments = split m/,/, $storyref->{hits}; 

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
		my ($section) = $slashdb->getSection($storyref->{section});

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

#!/usr/bin/perl -w
###############################################################################
# print.pl - this code displays the story ready to print
#
# based on code Copyright (C) 2001 Norbert "Momo_102" Kuemin
#	<momo_102@bluemail.ch>
#
# modified and ported to Slash 2.2 Fry beta in October 2001 
#	by chromatic <chromatic@wgz.org>
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
###############################################################################

# This plugin is documented in full in the book 
# 	_Running Weblogs with Slash_, by Chromatic, Brian Aker, David Krieger
# 	ISBN: 0-596-00200-2

# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use HTML::TreeBuilder;
use Slash;
use Slash::Display;
use Slash::Utility;
use vars qw( $VERSION );

($VERSION) = ' $Revision$' =~ /\$Revision:\s+([^\s]+)/;

sub main {
	my $constants = getCurrentStatic();
	my $user = getCurrentUser;
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();

	my $sid = $form->{sid};
	unless ($sid) {
		# Where should we redirect to if not to the rootdir? 
		# Do we care?
		redirect($constants->{rootdir});
		return;
	}

	my $sect_title = $user->{currentSection}{title};
	my $story;
	#Yeah, I am being lazy and paranoid  -Brian
	if (!($user->{author} or $user->{is_admin}) and 
	    !$slashdb->checkStoryViewable($form->{sid})) 
	{
		$story = '';
	} else {
		$story = $slashdb->getStory($form->{sid});
	}	

	unless ($story) {
		# Again, an error condition, but we're routed to the rootdir so
		# how is the user supposed to know something is wrong?
		redirect($constants->{rootdir});
		return;
	}

	my $topic	= $slashdb->getTopic($story->{tid});
	my $author	= $slashdb->getAuthor(
		$story->{uid},
		[qw( nickname fakeemail homepage )]
	);

	$story->{storytime} = timeCalc($story->{time});

	(my $adm, $user->{is_admin}) = ($user->{is_admin}, 0);

	header($sect_title, 'print');
	$user->{is_admin} = $adm;

	# To print the links, we extract all <A..> tags from the introtext and 
	# the bodytext and properly separate out URL and the text of the tag.
	# Before this was a regexp against the related text, but pudge 
	# convinced me that was an insane way to do it so we're doing it this
	# way, instead.

	# we should put this in Slash::Utility::Data and port the getRelated()
	# routine in admin.pl to use it instead -- pudge
	my @story_links;
	my $tree = new HTML::TreeBuilder;
	$tree->parse(parseSlashizedLinks($story->{introtext} . $story->{bodytext}));
	$tree->eof;
	my $links = $tree->extract_links('a');  # get "A" tags only

	for (@{$links}) {
		my $content = get_content($_->[1]);

		# make all relative links absolute to the site's root
		my $uri = URI->new_abs($_->[0], $constants->{absolutedir} . $ENV{REQUEST_URI});

		# http://foo -> http://foo/
		$uri->path('/') if ! length $uri->path;

		# need both to have data, and we don't want them if they
		# are the same as each other
		if (length $content && length $uri && $content ne $uri) {
			# don't duplicate URLs
			my $test = join($;, $uri, lc $content);
			if (!scalar(grep { $test eq join($;, $_->[0], lc $_->[1]) } @story_links)) {
				push @story_links, [$uri, $content];
			}
		}
	}

	# This was the insane part, which won't work for everything.
	#
	#X push @story_links, [$1, $2] while
	#X	$story->{relatedtext} =~
	#X	m!<A HREF="?([^"<]+?)"?>([^<]+?)</A>!ig;
	#X Drop the last two links, "More on <topic>", "Also by <author>", as 
	#X they don't appear in the story. 
	#X
	#X Plugin/Theme writers. If you change how story_text.relatedtext works,
	#X you may have to adust either the regexp, the slice below, or both!
	#X @story_links = @story_links[0 .. $#story_links - 2];

	slashDisplay('dispStory', {
		user		=> $user,
		story		=> $story,
		topic		=> $topic,
		author		=> $author,
		section		=> $sect_title,
		links		=> \@story_links,
	}, { Nocomm => 1 });

	slashDisplay('footer', {
		time		=> $slashdb->getTime(),
		story		=> $story,
	}, { Nocomm => 1 });
}

# Thanks for the assist here, pudge!
sub get_content {
	my($ref) = @_;
	my $content;

	$content .= (ref) ? get_content($_) : $_ for @{$ref->{_content}};
	
	return $content;
}

createEnvironment();
main();

1;

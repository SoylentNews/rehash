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

	slashDisplay('dispStory', {
		user		=> $user,
		story		=> $story,
		topic		=> $topic,
		author		=> $author,
		section		=> $sect_title,
	}, { Nocomm => 1 });

	slashDisplay('footer', {
		time		=> $slashdb->getTime(),
		story		=> $story,
	}, { Nocomm => 1 });
}

createEnvironment();
main();

1;

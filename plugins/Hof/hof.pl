#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
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

	header(getData('head'), '', { Page => 'index2' }) or return;

	my $hofDB = getObject('Slash::Hof', { db_type => 'reader' });

	my @topcomments = ( );

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

	footer({ Page => 'index2' });
}

#################################################################
createEnvironment();
main();

1;

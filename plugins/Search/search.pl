#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::Display;
use Slash::Search;
use Slash::Utility;
use Slash::XML;

#################################################################
sub main {
	my %ops = (
		comments	=> \&commentSearch,
		users		=> \&userSearch,
		stories		=> \&storySearch
	);
	my %ops_rss = (
		comments	=> \&commentSearchRSS,
		users		=> \&userSearchRSS,
		stories		=> \&storySearchRSS
	);

	my $constants = getCurrentStatic();
	my $form = getCurrentForm();

	my($slashdb, $searchDB);

	if ($constants->{search_db_user}) {
		$slashdb  = getObject('Slash::DB', $constants->{search_db_user});
		$searchDB = getObject('Slash::Search', $constants->{search_db_user});
	} else {
		$slashdb  = getCurrentDB();
		$searchDB = Slash::Search->new(getCurrentVirtualUser());
	}

	# Set some defaults
	$form->{query}		||= '';
	$form->{section}	||= '';
	$form->{section}	= '' if $form->{section} eq 'index'; # XXX fix this right, do a {realsection}
	$form->{threshold}	||= getCurrentUser('threshold');

	# get rid of bad characters
	$form->{query} =~ s/[^A-Z0-9'. ]/ /gi;

	# truncate query length
	if (length($form->{query}) > 40) {
		$form->{query} = substr($form->{query}, 0, 40);
	}

	# The default search operation is to search stories.
	$form->{op} ||= 'stories';

	if ($form->{content_type} eq 'rss') {
		# Here, panic mode is handled within the individual funcs.
		# We want to return valid (though empty) RSS data even
		# when search is down.
		$form->{op} = 'stories' if !exists($ops_rss{$form->{op}});
		$ops_rss{$form->{op}}->($form, $constants, $slashdb, $searchDB);
	} else {
		header("$constants->{sitename}: Search $form->{query}", $form->{section});
		titlebar("99%", "Searching $form->{query}");
		$form->{op} = 'stories' if !exists($ops{$form->{op}});

		# Here, panic mode is handled without needing to call the
		# individual search subroutines;  we're going to tell the
		# user the same thing in each case anyway.
		if ($constants->{panic} >= 1 or $constants->{search_google}) {
			slashDisplay('nosearch');
		} else {
			slashDisplay('searchform', {
				sections	=> _sections(),
				topics		=> _topics(),
				tref		=> $slashdb->getTopic($form->{topic}),
				op		=> $form->{op},
				authors		=> _authors(),
				'sort'		=> _sort(),
			});
			if ($ops{$form->{op}}) {
				$ops{$form->{op}}->($form, $constants, $slashdb, $searchDB);
			}
		}

		footer();
	}

	writeLog($form->{query})
		if $form->{op} =~ /^(?:comments|stories|users)$/;
}


#################################################################
# Ugly isn't it?
sub _authors {
	my $slashdb = getCurrentDB();
	my $authors = $slashdb->getDescriptions('all-authors');
	$authors->{''} = 'All Authors';

	return $authors;
}

#################################################################
# Ugly isn't it?
sub _topics {
	my $slashdb = getCurrentDB();
	my $topics = $slashdb->getDescriptions('topics');
	$topics->{''} = 'All Topics';

	return $topics;
}

#################################################################
sub _sort {
	# this needs to be in the database -- pudge
	my $sort;
	$sort->{''} = 'Default Order';
	$sort->{'date'} = 'Order By Date';
	$sort->{'score'} = 'Order By Score';

	return $sort;
}

#################################################################
# Ugly isn't it?
sub _sections {
	my $slashdb = getCurrentDB();
	my $sections = $slashdb->getDescriptions('sections');
	$sections->{''} = 'All Sections';

	return $sections;
}

#################################################################
sub _buildargs {
	my($form) = @_;
	my $uri;

	for (qw[threshold query author op topic section]) {
		my $x = "";
		$x =  $form->{$_} if defined $form->{$_} && $x eq "";
		$x =~ s/ /+/g;
		$uri .= "$_=$x&" unless $x eq "";
	}
	$uri =~ s/&$//;

	return fixurl($uri);
}

#################################################################
sub commentSearch {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $comments = $searchDB->findComments($form, $start, $constants->{search_default_display} + 1, $form->{sort});

	# check for extra articles ... we request one more than we need
	# and if we get the extra one, we know we have extra ones, and
	# we pop it off
	my $forward;
	if (@$comments == $constants->{search_default_display} + 1) {
		pop @$comments;
		$forward = $start + $constants->{search_default_display};
	} else {
		$forward = 0;
	}

	# if there are less than search_default_display remaning,
	# just set it to 0
	my $back;
	if ($start > 0) {
		$back = $start - $constants->{search_default_display};
		$back = $back > 0 ? $back : 0;
	} else {
		$back = -1;
	}

	slashDisplay('commentsearch', {
		comments	=> $comments,
		back		=> $back,
		forward		=> $forward,
		args		=> _buildargs($form),
		start		=> $start,
	});
}

#################################################################
sub userSearch {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $users = $searchDB->findUsers($form, $start, $constants->{search_default_display} + 1, $form->{sort});

	# check for extra articles ... we request one more than we need
	# and if we get the extra one, we know we have extra ones, and
	# we pop it off
	my $forward;
	if (@$users == $constants->{search_default_display} + 1) {
		pop @$users;
		$forward = $start + $constants->{search_default_display};
	} else {
		$forward = 0;
	}

	# if there are less than search_default_display remaning,
	# just set it to 0
	my $back;
	if ($start > 0) {
		$back = $start - $constants->{search_default_display};
		$back = $back > 0 ? $back : 0;
	} else {
		$back = -1;
	}

	slashDisplay('usersearch', {
		users		=> $users,
		back		=> $back,
		forward		=> $forward,
		args		=> _buildargs($form),
	});
}

#################################################################
sub storySearch {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $stories = $searchDB->findStory($form, $start, $constants->{search_default_display} + 1, $form->{sort});

	# check for extra articles ... we request one more than we need
	# and if we get the extra one, we know we have extra ones, and
	# we pop it off
	my $forward;
	if (@$stories == $constants->{search_default_display} + 1) {
		pop @$stories;
		$forward = $start + $constants->{search_default_display};
	} else {
		$forward = 0;
	}

	# if there are less than search_default_display remaning,
	# just set it to 0
	my $back;
	if ($start > 0) {
		$back = $start - $constants->{search_default_display};
		$back = $back > 0 ? $back : 0;
	} else {
		$back = -1;
	}

	slashDisplay('storysearch', {
		stories		=> $stories,
		back		=> $back,
		forward		=> $forward,
		args		=> _buildargs($form),
		start		=> $start,
	});
}

#################################################################
sub commentSearchRSS {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $comments;
	if ($constants->{panic} >= 1 or $constants->{search_google}) {
		$comments = [ ];
	} else {
		$comments = $searchDB->findComments($form, $start, 15, $form->{sort});
	}

	my @items;
	for my $entry (@$comments) {
		my $time = timeCalc($entry->[3]);
		push @items, {
			title	=> "$entry->[5] ($time)",
			'link'	=> ($constants->{absolutedir} . "/comments.pl?sid=entry->[1]&pid=entry->[4]#entry->[10]"),
		};
	}

	xmlDisplay(rss => {
		channel => {
			title		=> "$constants->{sitename} Comment Search",
			'link'		=> "$constants->{absolutedir}/search.pl",
			description	=> "$constants->{sitename} Comment Search",
		},
		image	=> 1,
		items	=> \@items
	});
}

#################################################################
sub userSearchRSS {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $users;
	if ($constants->{panic} >= 1 or $constants->{search_google}) {
		$users = [ ];
	} else {
		$users = $searchDB->findUsers($form, $start, 15, $form->{sort});
	}

	my @items;
	for my $entry (@$users) {
		my $time = timeCalc($entry->[3]);
		push @items, {
			title	=> "$entry->[1]",
			'link'	=> ($constants->{absolutedir} . '/users.pl?nick=' . $entry->[1]),
		};
	}

	xmlDisplay(rss => {
		channel => {
			title		=> "$constants->{sitename} User Search",
			'link'		=> "$constants->{absolutedir}/search.pl",
			description	=> "$constants->{sitename} User Search",
		},
		image	=> 1,
		items	=> \@items
	});
}

#################################################################
sub storySearchRSS {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $stories;
	if ($constants->{panic} >= 1 or $constants->{search_google}) {
		$stories = [ ];
	} else {
		$stories = $searchDB->findStory($form, $start, 15, $form->{sort});
	}

	my @items;
	for my $entry (@$stories) {
		my $time = timeCalc($entry->[3]);
		push @items, {
			title	=> "$entry->[1] ($time)",
			'link'	=> ($constants->{absolutedir} . '/article.pl?sid=' . $entry->[2]),
		};
	}

	xmlDisplay(rss => {
		channel => {
			title		=> "$constants->{sitename} Story Search",
			'link'		=> "$constants->{absolutedir}/search.pl",
			description	=> "$constants->{sitename} Story Search",
		},
		image	=> 1,
		items	=> \@items
	});
}

#################################################################
# Do not enable -Brian
sub findRetrieveSite {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $feeds = $searchDB->findRetrieveSite($form->{query}, $start, $constants->{search_default_display} + 1, $form->{sort});

	# check for extra feeds ... we request one more than we need
	# and if we get the extra one, we know we have extra ones, and
	# we pop it off
	my $forward;
	if (@$feeds == $constants->{search_default_display} + 1) {
		pop @$feeds;
		$forward = $start + $constants->{search_default_display};
	} else {
		$forward = 0;
	}

	# if there are less than search_default_display remaning,
	# just set it to 0
	my $back;
	if ($start > 0) {
		$back = $start - $constants->{search_default_display};
		$back = $back > 0 ? $back : 0;
	} else {
		$back = -1;
	}

	slashDisplay('retrievedsites', {
		feeds		=> $feeds,
		back		=> $back,
		forward		=> $forward,
		start		=> $start,
	});
}


#################################################################
# Do not enable -Brian
sub findRetrieveSiteRSS {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $feeds = $searchDB->findFeeds($form->{query}, $start, 15, $form->{sort});

	# I am aware that the link has to be improved.
	my @items;
	for my $entry (@$feeds) {
		my $time = timeCalc($entry->[8]);
		push @items, {
			title	=> "$entry->[2] ($time)",
			'link'	=> ($constants->{absolutedir} . "/users.pl?op=preview&bid=entry->[0] %]"),
		};
	}

	xmlDisplay(rss => {
		channel => {
			title		=> "$constants->{sitename} Retrieve Site Search",
			'link'		=> "$constants->{absolutedir}/search.pl",
			description	=> "$constants->{sitename} Retrieve Site Search",
		},
		image	=> 1,
		items	=> \@items
	});
}

#################################################################
# Do not enable -Brian
sub findJournalEntry {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $entries = $searchDB->findJournalEntry($form, $start, $constants->{search_default_display} + 1, $form->{sort});

	# check for extra articles ... we request one more than we need
	# and if we get the extra one, we know we have extra ones, and
	# we pop it off
	my $forward;
	if (@$entries == $constants->{search_default_display} + 1) {
		pop @$entries;
		$forward = $start + $constants->{search_default_display};
	} else {
		$forward = 0;
	}

	# if there are less than search_default_display remaning,
	# just set it to 0
	my $back;
	if ($start > 0) {
		$back = $start - $constants->{search_default_display};
		$back = $back > 0 ? $back : 0;
	} else {
		$back = -1;
	}

	slashDisplay('storysearch', {
		entries		=> $entries,
		back		=> $back,
		forward		=> $forward,
		args		=> _buildargs($form),
		start		=> $start,
	});
}

#################################################################
# Do not enable -Brian
# do not WRITE in the first place -- pudge
# Writing is fine if it is not enabled --Brian
sub findJournalEntryRSS {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $entries = $searchDB->findJournalEntry($form, $start, 15, $form->{sort});

	my @items;
	for my $entry (@$entries) {
		my $time = timeCalc($entry->[3]);
		push @items, {
			title	=> "$entry->[1] ($time)",
			'link'	=> ($constants->{absolutedir} . '/article.pl?sid=' . $entry->[2]),
		};
	}

	xmlDisplay(rss => {
		channel => {
			title		=> "$constants->{sitename} Journal Search",
			'link'		=> "$constants->{absolutedir}/search.pl",
			description	=> "$constants->{sitename} Journal Search",
		},
		image	=> 1,
		items	=> \@items
	});
}

#################################################################
createEnvironment();
main();

1;

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
use XML::RSS;

#################################################################
sub main {
	my %ops = (
		comments => \&commentSearch,
		users => \&userSearch,
		stories => \&storySearch
	);
	my %ops_rss = (
		comments => \&commentSearchRSS,
		users => \&userSearchRSS,
		stories => \&storySearchRSS
	);

	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();

	# Set some defaults
	$form->{query}		||= '';
	$form->{section}	||= '';
	$form->{min}		||= 0;
	$form->{max}		||= 30;
	$form->{threshold}	||= getCurrentUser('threshold');
	$form->{'last'}		||= $form->{min} + $form->{max};

	# get rid of bad characters
	$form->{query} =~ s/[^A-Z0-9'. ]//gi;

	if ($form->{content_type} eq 'rss') {
		my $r = Apache->request;
		$r->header_out('Cache-Control', 'private');
		$r->content_type('text/xml');
		$r->status(200);
		$r->send_http_header;
		$r->rflush;
		if($ops_rss{$form->{op}}) {
			$r->print($ops_rss{$form->{op}}->($form, $constants));
		} else {
			$r->print($ops_rss{'stories'}->($form, $constants));
		}
		$r->rflush;
		$r->status(200);
	} else {
		header("$constants->{sitename}: Search $form->{query}", $form->{section});
		titlebar("99%", "Searching $form->{query}");

		$form->{op} ||= 'stories';
		my $authors = _authors();
		slashDisplay('searchform', {
			section => getSection($form->{section}),
			tref =>$slashdb->getTopic($form->{topic}),
			op => $form->{op},
			authors => $authors
		});

		if($ops{$form->{op}}) {
			$ops{$form->{op}}->($form, $constants);
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
	my $authors = $slashdb->getDescriptions('authors');
	$authors->{''} = 'All Authors';

	return $authors;
}

#################################################################
sub _buildargs {
	my ($form) = @_;
	my $uri;

	for (qw[threshold query author op topic section]) {
		my $x = "";
		$x =  $form->{$_} if defined $form->{$_} && $x eq "";
		$x =~ s/ /+/g;
		$uri .= "$_=$x&" unless $x eq "";
	}
	$uri =~ s/&$//;

	return $uri;
}

#################################################################
sub commentSearch {
	my ($form, $constants) = @_;
	my $slashdb = getCurrentDB();
	my $searchDB = Slash::Search->new(getCurrentVirtualUser());

	my $start = fixint($form->{start}) || 0;
	my $comments = $searchDB->findComments($form, $start, $constants->{search_default_display} + 1);

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
		comments => $comments,
		back		=> $back,
		forward		=> $forward,
		args		=> _buildargs($form),
		start => $start,
	});
}

#################################################################
sub userSearch {
	my ($form, $constants) = @_;
	my $searchDB = Slash::Search->new(getCurrentVirtualUser());

	my $start = fixint($form->{start}) || 0;
	my $users = $searchDB->findUsers($form, $start, $constants->{search_default_display} + 1);

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
		users => $users,
		back		=> $back,
		forward		=> $forward,
		args		=> _buildargs($form),
	});
}

#################################################################
sub storySearch {
	my ($form, $constants) = @_;
	my $searchDB = Slash::Search->new(getCurrentVirtualUser());

	my $start = fixint($form->{start}) || 0;
	my $stories = $searchDB->findStory($form, $start, $constants->{search_default_display} + 1);

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
		stories => $stories,
		back		=> $back,
		forward		=> $forward,
		args		=> _buildargs($form),
		start => $start,
	});
}

#################################################################
sub commentSearchRSS {
	my ($form, $constants) = @_;
	my $slashdb = getCurrentDB();
	my $searchDB = Slash::Search->new(getCurrentVirtualUser());

	my $start = fixint($form->{start}) || 0;
	my $comments = $searchDB->findComments($form, $start, 15);

	my $rss = XML::RSS->new(
		version		=> '1.0',
		encoding	=> $constants->{rdfencoding},
	);

	$rss->channel(
		title	=> xmlencode($constants->{sitename} . ' Search'),
		'link'	=> xmlencode_plain($constants->{absolutedir} . '/search.pl'),
		description	=> xmlencode($constants->{sitename} . ' Search'),
	);

	$rss->image(
		title	=> xmlencode($constants->{sitename}),
		url	=> xmlencode($constants->{rdfimg}),
		'link'	=> xmlencode_plain($constants->{absolutedir} . '/'),
	);

	for my $entry (@$comments) {
			my $time = timeCalc($entry->[8]);
			$rss->add_item(
				title	=> xmlencode("$entry->[5] ($time)"),
				'link'	=> xmlencode_plain($constants->{absolutedir} . "/comments.pl?sid=entry->[1]&pid=entry->[4]#entry->[10]"),
			);
	}
	return $rss->as_string;
}

#################################################################
sub userSearchRSS {
	my ($form, $constants) = @_;
	my $searchDB = Slash::Search->new(getCurrentVirtualUser());

	my $start = fixint($form->{start}) || 0;
	my $users = $searchDB->findUsers($form, $start, 15);

	my $rss = XML::RSS->new(
		version		=> '1.0',
		encoding	=> $constants->{rdfencoding},
	);

	$rss->channel(
		title	=> xmlencode($constants->{sitename} . ' Search'),
		'link'	=> xmlencode_plain($constants->{absolutedir} . '/search.pl'),
		description	=> xmlencode($constants->{sitename} . ' Search'),
	);

	$rss->image(
		title	=> xmlencode($constants->{sitename}),
		url	=> xmlencode($constants->{rdfimg}),
		'link'	=> xmlencode_plain($constants->{absolutedir} . '/'),
	);

	for my $entry (@$users) {
			my $time = timeCalc($entry->[3]);
			$rss->add_item(
				title	=> xmlencode("$entry->[0]"),
				'link'	=> xmlencode_plain($constants->{absolutedir} . '/users.pl?nick=' . $entry->[0]),
			);
	}
	return $rss->as_string;

}

#################################################################
sub storySearchRSS {
	my ($form, $constants) = @_;
	my $searchDB = Slash::Search->new(getCurrentVirtualUser());

	my $start = fixint($form->{start}) || 0;
	my $stories = $searchDB->findStory($form, $start, 15);

	my $rss = XML::RSS->new(
		version		=> '1.0',
		encoding	=> $constants->{rdfencoding},
	);

	$rss->channel(
		title	=> xmlencode($constants->{sitename} . ' Search'),
		'link'	=> xmlencode_plain($constants->{absolutedir} . '/search.pl'),
		description	=> xmlencode($constants->{sitename} . ' Search'),
	);

	$rss->image(
		title	=> xmlencode($constants->{sitename}),
		url	=> xmlencode($constants->{rdfimg}),
		'link'	=> xmlencode_plain($constants->{absolutedir} . '/'),
	);

	for my $entry (@$stories) {
			my $time = timeCalc($entry->[3]);
			$rss->add_item(
				title	=> xmlencode("$entry->[1] ($time)"),
				'link'	=> xmlencode_plain($constants->{absolutedir} . '/article.pl?sid=' . $entry->[2]),
			);
	}
	return $rss->as_string;
}

#################################################################
createEnvironment();
main();

1;

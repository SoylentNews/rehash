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

#################################################################
sub main {
	my %ops = (
		comments => \&commentSearch,
		users => \&userSearch,
		stories => \&storySearch
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

	#searchForm($form);

	if($ops{$form->{op}}) {
		$ops{$form->{op}}->($form, $constants);
	} 

	writeLog($form->{query})
		if $form->{op} =~ /^(?:comments|stories|users)$/;
	footer();	
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
	});
}

#################################################################
createEnvironment();
main();

1;

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
		$ops{$form->{op}}->($form);
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
sub linkSearch {
	my ($count) = @_;
	my $form = getCurrentForm();
	my $r;

	foreach (qw[threshold query min author op sid topic section total hitcount]) {
		my $x = "";
		$x =  $count->{$_} if defined $count->{$_};
		$x =  $form->{$_} if defined $form->{$_} && $x eq "";
		$x =~ s/ /+/g;
		$r .= "$_=$x&" unless $x eq "";
	}
	$r =~ s/&$//;

	$r = qq!<A HREF="$ENV{SCRIPT_NAME}?$r">$count->{'link'}</A>!;
}


#################################################################
sub commentSearch {
	my ($form) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $searchDB = Slash::Search->new(getCurrentVirtualUser());

	my $comments = $searchDB->findComments($form);
	slashDisplay('commentsearch', {
		comments => $comments
	});

	my $prev = $form->{min} - $form->{max};
	slashDisplay('linksearch', {
		prev => $prev,
		linksearch => \&linksearch
	}) if $prev >= 0;
}

#################################################################
sub userSearch {
	my ($form) = @_;
	my $constants = getCurrentStatic();
	my $searchDB = Slash::Search->new(getCurrentVirtualUser());

	my $users = $searchDB->findUsers($form);
	slashDisplay('usersearch', {
		users => $users
	});
	
	my $x = @$users;

	my $prev = ($form->{min} - $form->{max});

	slashDisplay('linksearch', {
		prev => $prev,
		linksearch => \&linksearch
	}) if $prev >= 0;
}

#################################################################
sub storySearch {
	my ($form) = @_;
	my $searchDB = Slash::Search->new(getCurrentVirtualUser());


	my($x, $cnt) = 0;

	my $stories = $searchDB->findStory($form);
	slashDisplay('storysearch', {
		stories => $stories
	});

	my $prev = $form->{min} - $form->{max};
	slashDisplay('linksearch', {
		prev => $prev,
		linksearch => \&linksearch
	}) if $prev >= 0;
}

#################################################################
createEnvironment();
main();

1;

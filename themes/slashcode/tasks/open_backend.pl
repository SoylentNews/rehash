#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::XML;
use Slash::Constants ':slashd';

use vars qw( %task $me );

$task{$me}{timespec} = '13,43 * * * *';
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;

	my $backupdb = getObject('Slash::DB', { db_type => 'reader' });

	my $stories = $backupdb->getBackendStories;
	if ($stories && @$stories) {
		newxml(@_, undef, $stories);
		newrdf(@_, undef, $stories);
		newrss(@_, undef, $stories);
	}

	my $skins = $slashdb->getSkins();
	for my $skid (keys %$skins) {
		my $name = $skins->{$skid}{name};
		my $nexus = $skins->{$skid}{nexus};
		$stories = $backupdb->getBackendStories({ topic => $nexus });
		if ($stories && @$stories) {
			newxml(@_, $name, $stories);
			newrdf(@_, $name, $stories);
			newrss(@_, $name, $stories);
		}
	}

	return;
};

sub fudge {
	my($current, $new) = @_;
	s|[dD]ate>[^<]+</|| for $current, $new;
	return($current, $new);
}

sub _do_rss {
	my($virtual_user, $constants, $backupdb, $user, $info, $gSkin,
		$name, $stories, $version) = @_;

	my $file    = sitename2filename($name);
	my $skin    = {};
	$skin       = $backupdb->getSkin($name) if $name;
	my $link    = ($skin->{url}  || $gSkin->{absolutedir}) . '/';
	my $title   = $constants->{sitename};
	$title = "$title: $skin->{title}" if $skin->{skid} != $constants->{mainpage_skid};

	my $rss = xmlDisplay('rss', {
		channel		=> {
			title		=> $title,
			'link'		=> $link,
		},
		version		=> $version,
		textinput	=> 1,
		image		=> 1,
		items		=> [ map { { story => $_ } } @$stories ],
	}, 1);

	my $ext = $version == 0.9 ? 'rdf' : 'rss';
	save2file("$constants->{basedir}/$file.$ext", $rss, \&fudge);
}

sub newrdf { _do_rss(@_, "0.9") } # RSS 0.9
sub newrss { _do_rss(@_, "1.0") } # RSS 1.0

sub newxml {
	my($virtual_user, $constants, $backupdb, $user, $info, $gSkin,
		$name, $stories) = @_;

	my $x = <<EOT;
<?xml version="1.0"?><backslash
xmlns:backslash="$gSkin->{absolutedir}/backslash.dtd">

EOT

	for my $story (@$stories) {
		my @str = (xmlencode($story->{title}), xmlencode($story->{dept}));
		my $author = $backupdb->getAuthor($story->{uid}, 'nickname');
		$x.= <<EOT;
	<story>
		<title>$str[0]</title>
		<url>$gSkin->{absolutedir}/article.pl?sid=$story->{sid}</url>
		<time>$story->{'time'}</time>
		<author>$author</author>
		<department>$str[1]</department>
		<topic>$story->{tid}</topic>
		<comments>$story->{commentcount}</comments>
		<section>$name</section>
		<image>$story->{image}{image}</image>
	</story>

EOT
	}

	$x .= "</backslash>\n";

	my $file = sitename2filename($name);
	save2file("$constants->{basedir}/$file.xml", $x, \&fudge);
}

1;


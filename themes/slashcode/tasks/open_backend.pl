#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::XML;
use Slash::Constants ':slashd';

use vars qw( %task $me );

$task{$me}{timespec} = '0-59/10 * * * *';
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;

	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $max_items = $constants->{rss_max_items_outgoing} || 10;

	my $stories = $reader->getBackendStories({ limit => $max_items });
	if ($stories && @$stories) {
		newxml(@_, undef, $stories);
		newrdf(@_, undef, $stories);
		newrss(@_, undef, $stories);
		newatom(@_, undef, $stories);
	}

	my $skins = $slashdb->getSkins();
	for my $skid (keys %$skins) {
		my $name = $skins->{$skid}{name};
		my $nexus = $skins->{$skid}{nexus};
		$stories = $reader->getBackendStories({ limit => $max_items, topic => $nexus });
		if ($stories && @$stories) {
			newxml(@_, $name, $stories);
			newrdf(@_, $name, $stories);
			newrss(@_, $name, $stories);
			newatom(@_, $name, $stories);
		}
	}

	return;
};

# this normalizes old and new content, stripping data that
# updates every time
sub fudge {
	my($current, $new) = @_;
	s{[dD]ate>[^<]+</}{} for $current, $new;
	s{<(?:slash:)?(?:comments|hitparade)>[^<]+</}{}g for $current, $new;
	return($current, $new);
}

sub _do_rss {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin,
		$name, $stories, $version, $type) = @_;

	$type ||= 'rss';

	my $file    = sitename2filename($name);
	my $skin    = {};
	$skin       = $slashdb->getSkin($name) if $name;
	my $link    = ($skin->{url}  || $gSkin->{absolutedir}) . '/';
	my $title   = $constants->{sitename};
	$title = "$title: $skin->{title}"
		if $skin->{skid} != $constants->{mainpage_skid} && $skin->{title};

	my $ext = $version == 0.9 && $type eq 'rss' ? 'rdf' : $type;
	my $filename = "$file.$ext";

	my $rss = xmlDisplay($type, {
		channel		=> {
			title		=> $title,
			'link'		=> $link,
			selflink	=> "$link$filename",
		},
		version		=> $version,
		textinput	=> 1,
		image		=> 1,
		items		=> [ map { { story => $_ } } @$stories ],
	}, 1);

	save2file("$constants->{basedir}/$filename", $rss, \&fudge);
	save2file("$constants->{basedir}/privaterss/$filename", $rss, \&fudge)
		if -d "$constants->{basedir}/privaterss/";
}

sub newrdf  { _do_rss(@_, '0.9') } # RSS 0.9
sub newrss  { _do_rss(@_, '1.0') } # RSS 1.0
sub newatom { _do_rss(@_, '1.0', 'atom') } # Atom 1.0

sub newxml {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin,
		$name, $stories) = @_;

	my $x = <<EOT;
<?xml version="1.0"?><backslash
xmlns:backslash="$gSkin->{absolutedir}/backslash.dtd">

EOT

	for my $story (@$stories) {
		my @str = (xmlencode($story->{title}), xmlencode($story->{dept}));
		my $author = $slashdb->getAuthor($story->{uid}, 'nickname');
		$x.= <<EOT;
	<story>
		<title>$str[0]</title>
		<url>$gSkin->{absolutedir}/article.pl?sid=$story->{sid}</url>
		<time>$story->{'time'}</time>
		<author>$author</author>
		<department>$str[1]</department>
		<topic>$story->{tid}</topic>
		<comments>$story->{commentcount}</comments>
		<section>$story->{section}</section>
		<image>$story->{image}{image}</image>
	</story>

EOT
	}

	$x .= "</backslash>\n";

	my $file = sitename2filename($name);
	save2file("$constants->{basedir}/$file.xml", $x, \&fudge);
}

1;


#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use utf8;
use Slash;
use Slash::XML;
use Slash::Constants ':slashd';
use Encode qw(encode_utf8 decode_utf8 is_utf8);
use vars qw( %task $me %redirects );

$task{$me}{timespec} = '0-59/10 * * * *';
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;
	return 1 if $constants->{rss_allow_index};

	load_redirects();

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
	my $skin    = { };
	$skin       = $slashdb->getSkin($name) if $name;
	my $link    = ($skin->{url}  || $gSkin->{absolutedir}) . '/';
	my $title   = $constants->{sitename};
	$title = "$title: $skin->{title}"
		if $skin->{skid} && $skin->{skid} != $constants->{mainpage_skid} && $skin->{title};

	my $description = $constants->{slogan};

	# XXX: temporary, until we can add a skin_param table
	if ($constants->{sitename} eq 'Slashdot') {
		if ($skin->{title} && $skin->{title} eq 'AMD') {
			$title .= ' Sponsored Content';
			$description = 'Special Advertising Section';
		}
	}

	my $ext = $version == 0.9 && $type eq 'rss' ? 'rdf' : $type;
	my $filename = "$file.$ext";

	if (-d "$constants->{basedir}/privaterss/") {
		my $rss = xmlDisplay($type, {
			channel		=> {
				title		=> $title,
				'link'		=> $link,
				selflink	=> "$link$filename",
				description	=> $description,
			},
			version		=> $version,
			textinput	=> 1,
			image		=> 1,
			items		=> [ map { { story => $_ } } @$stories ],
		}, 1);
		save2file("$constants->{basedir}/privaterss/$filename", $rss, \&fudge);
	}

	my @items = map { { story => $_ } } @$stories;
	if ($constants->{rss_no_public_static}) {
		my $newurl = $redirects{$filename} || '';#"(none for $filename)";
		unshift @items, {
			introtext	=> sprintf('This URL is no longer valid.  Please update your bookmarks to the new URL: %s', $newurl),
			title		=> 'Please Update Your Bookmarks',
			'link'		=> $newurl,
			'time'		=> '2006-12-13 00:00:00',
		} if $newurl;
	}

	use HTML::Entities ();
	foreach my $item (@items) {
		$item->{story}{title} = HTML::Entities::decode($item->{story}{title});
		$item->{story}{title} =~ s/&#([0-9])+;/chr($1)/eg;
		$item->{story}{title} =~ s/&#x([a-fA-F0-9])+;/chr(hex($1))/eg;
		$item->{story}{title} =~ s/[><]//g;
	}


	my $rss = xmlDisplay($type, {
		channel		=> {
			title		=> $title,
			'link'		=> $link,
			selflink	=> "$link$filename",
			description	=> $description,
		},
		version		=> $version,
		textinput	=> 1,
		image		=> 1,
		items		=> \@items,
	}, 1);

	$rss =~ s/#x26;amp;from/amp;from/g;

	save2file("$constants->{basedir}/$filename", $rss, \&fudge);

	# Now write change the links to https, add an s to the front of the extension, and write it again

	$filename =~ s/\./.s/;
	$rss =~ s/http:/https:/g;
	save2file("$constants->{basedir}/$filename", $rss, \&fudge);
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
		my $link;
		if ($constants->{firehose_link_article2}) {
			my $linktitle = $story->{title};
			$linktitle =~ s/\s+/-/g;
			$linktitle =~ s/[^A-Za-z0-9\-]//g;
			$link = "$gSkin->{absolutedir}/story/$story->{sid}/$linktitle";
		} else {
			$link = "$gSkin->{absolutedir}/article.pl?sid=$story->{sid}";
		}
		$x.= <<EOT;
	<story>
		<title>$str[0]</title>
		<url>$link</url>
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

sub load_redirects {
%redirects = (
	'apache.rss'        => 'http://rss.slashdot.org/Slashdot/slashdotApache',
	'apple.rss'         => 'http://rss.slashdot.org/Slashdot/slashdotApple',
	'askslashdot.rss'   => 'http://rss.slashdot.org/Slashdot/slashdotAskSlashdot',
	'awards.rss'        => 'http://rss.slashdot.org/Slashdot/slashdotThe2000Beanies',
	'bookreview.rss'    => 'http://rss.slashdot.org/Slashdot/slashdotBookReviews',
	'books.rss'         => 'http://rss.slashdot.org/Slashdot/slashdotBookReviews',
	'bsd.rss'           => 'http://rss.slashdot.org/Slashdot/slashdotBsd',
	'developers.rss'    => 'http://rss.slashdot.org/Slashdot/slashdotDevelopers',
	'features.rss'      => 'http://rss.slashdot.org/Slashdot/slashdotFeatures',
	'games.rss'         => 'http://rss.slashdot.org/Slashdot/slashdotGames',
	'hardware.rss'      => 'http://rss.slashdot.org/Slashdot/slashdotHardware',
	'index.rss'         => 'http://rss.slashdot.org/Slashdot/slashdot',
	'interviews.rss'    => 'http://rss.slashdot.org/Slashdot/slashdotInterviews',
	'it.rss'            => 'http://rss.slashdot.org/Slashdot/slashdotIt',
	'linux.rss'         => 'http://rss.slashdot.org/Slashdot/slashdotLinux',
	'politics.rss'      => 'http://rss.slashdot.org/Slashdot/slashdotPolitics',
	'radio.rss'         => 'http://rss.slashdot.org/Slashdot/slashdotGeeksInSpace',
	'science.rss'       => 'http://rss.slashdot.org/Slashdot/slashdotScience',
	'search.rss'        => 'http://rss.slashdot.org/Slashdot/slashdotSearch',
	'slashdot.rss'      => 'http://rss.slashdot.org/Slashdot/slashdot',
	'tacohell.rss'      => 'http://rss.slashdot.org/Slashdot/slashdotTacoHell',
	'yro.rss'           => 'http://rss.slashdot.org/Slashdot/slashdotYourRightsOnline',

	'apache.rdf'        => 'http://rss.slashdot.org/Slashdot/slashdotApache/to',
	'apple.rdf'         => 'http://rss.slashdot.org/Slashdot/slashdotApple/to',
	'askslashdot.rdf'   => 'http://rss.slashdot.org/Slashdot/slashdotAskSlashdot/to',
	'awards.rdf'        => 'http://rss.slashdot.org/Slashdot/slashdotThe2000Beanies/to',
	'bookreview.rdf'    => 'http://rss.slashdot.org/Slashdot/slashdotBookReviews/to',
	'books.rdf'         => 'http://rss.slashdot.org/Slashdot/slashdotBookReviews/to',
	'bsd.rdf'           => 'http://rss.slashdot.org/Slashdot/slashdotBsd/to',
	'developers.rdf'    => 'http://rss.slashdot.org/Slashdot/slashdotDevelopers/to',
	'features.rdf'      => 'http://rss.slashdot.org/Slashdot/slashdotFeatures/to',
	'games.rdf'         => 'http://rss.slashdot.org/Slashdot/slashdotGames/to',
	'hardware.rdf'      => 'http://rss.slashdot.org/Slashdot/slashdotHardware/to',
	'index.rdf'         => 'http://rss.slashdot.org/Slashdot/slashdot/to',
	'interviews.rdf'    => 'http://rss.slashdot.org/Slashdot/slashdotInterviews/to',
	'it.rdf'            => 'http://rss.slashdot.org/Slashdot/slashdotIt/to',
	'linux.rdf'         => 'http://rss.slashdot.org/Slashdot/slashdotLinux/to',
	'politics.rdf'      => 'http://rss.slashdot.org/Slashdot/slashdotPolitics/to',
	'radio.rdf'         => 'http://rss.slashdot.org/Slashdot/slashdotGeeksInSpace/to',
	'science.rdf'       => 'http://rss.slashdot.org/Slashdot/slashdotScience/to',
	'search.rdf'        => 'http://rss.slashdot.org/Slashdot/slashdotSearch/to',
	'slashdot.rdf'      => 'http://rss.slashdot.org/Slashdot/slashdot/to',
	'tacohell.rdf'      => 'http://rss.slashdot.org/Slashdot/slashdotTacoHell/to',
	'yro.rdf'           => 'http://rss.slashdot.org/Slashdot/slashdotYourRightsOnline/to',

	'apache.atom'       => 'http://rss.slashdot.org/Slashdot/slashdotApacheatom',
	'apple.atom'        => 'http://rss.slashdot.org/Slashdot/slashdotAppleatom',
	'askslashdot.atom'  => 'http://rss.slashdot.org/Slashdot/slashdotAskslashdotatom',
	'awards.atom'       => 'http://rss.slashdot.org/Slashdot/slashdotAwardsatom',
	'bookreview.atom'   => 'http://rss.slashdot.org/Slashdot/slashdotBooksatom',
	'books.atom'        => 'http://rss.slashdot.org/Slashdot/slashdotBooksatom',
	'bsd.atom'          => 'http://rss.slashdot.org/Slashdot/slashdotBsdatom',
	'developers.atom'   => 'http://rss.slashdot.org/Slashdot/slashdotDevelopersatom',
	'features.atom'     => 'http://rss.slashdot.org/Slashdot/slashdotFeaturesatom',
	'games.atom'        => 'http://rss.slashdot.org/Slashdot/slashdotGamesatom',
	'hardware.atom'     => 'http://rss.slashdot.org/Slashdot/slashdotHardwareatom',
	'index.atom'        => 'http://rss.slashdot.org/Slashdot/slashdotatom',
	'interviews.atom'   => 'http://rss.slashdot.org/Slashdot/slashdotInterviewsatom',
	'it.atom'           => 'http://rss.slashdot.org/Slashdot/slashdotItatom',
	'linux.atom'        => 'http://rss.slashdot.org/Slashdot/slashdotLinuxatom',
	'politics.atom'     => 'http://rss.slashdot.org/Slashdot/slashdotPoliticsatom',
	'radio.atom'        => 'http://rss.slashdot.org/Slashdot/slashdotRadioatom',
	'science.atom'      => 'http://rss.slashdot.org/Slashdot/slashdotScienceatom',
	'search.atom'       => 'http://rss.slashdot.org/Slashdot/slashdotSearchatom',
	'slashdot.atom'     => 'http://rss.slashdot.org/Slashdot/slashdotatom',
	'tacohell.atom'     => 'http://rss.slashdot.org/Slashdot/slashdotTacohellatom',
	'yro.atom'          => 'http://rss.slashdot.org/Slashdot/slashdotYroatom',
);
}

1;


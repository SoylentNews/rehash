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
	my $bookmark_reader = getObject('Slash::Bookmark', { db_type => 'reader' });

	my $bookmarks_recent = $bookmark_reader->getRecentBookmarks();
	my $bookmarks_popular = $bookmark_reader->getPopularBookmarks();

	if ($bookmarks_recent && @$bookmarks_recent) {
		bookrdf(@_, "bookmarks_recent", "Bookmarks Recent", $bookmarks_recent);
		bookrss(@_, "bookmarks_recent", "Bookmarks Recent", $bookmarks_recent);
		bookatom(@_, "bookmarks_recent", "Bookmarks Recent", $bookmarks_recent);
	}
	if ($bookmarks_popular && @$bookmarks_popular) {
		bookrdf(@_, "bookmarks_popular", "Bookmarks Popular", $bookmarks_popular);
		bookrss(@_, "bookmarks_popular", "Bookmarks Popular", $bookmarks_popular);
		bookatom(@_, "bookmarks_popular", "Bookmarks Popular", $bookmarks_popular);
	}

	return;
};

# this normalizes old and new content, stripping data that
# updates every time
sub fudge {
	my($current, $new) = @_;
	s{[dD]ate>[^<]+</}{} for $current, $new;
	return($current, $new);
}

sub _do_book_rss {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin,
		$name, $subtitle, $bookmarks, $version, $type) = @_;

	$type ||= 'rss';

	my $file    = $name;
	my $skin    = { };
	my $link    = ($gSkin->{absolutedir}) . '/';
	$link .= "bookmarks.pl?op=showbookmarks&recent=1" if $name eq "bookmarks_recent";
	$link .= "bookmarks.pl?op=showbookmarks&popular=1" if $name eq "bookmarks_popular";
	my $title   = "$constants->{sitename}";
	$title .= ": $subtitle" if $subtitle;

	my $description = $constants->{slogan};

	# XXX: temporary, until we can add a skin_param table

	my $ext = $version == 0.9 && $type eq 'rss' ? 'rdf' : $type;
	my $filename = "$file.$ext";

	my @items;
	foreach (@$bookmarks) {
		my $title = $_->{validatedtitle} || $_->{initialtitle};
		push @items, { 
			link => $_->{url}, 
			title => $title, 
			story => {
				'time' => $_->{createtime} 
			}
		}
	}

	my $rss = xmlDisplay($type, {
		channel		=> {
			title		=> $title,
			'link'		=> $link,
			selflink	=> "$link$filename",
			description	=> $description,
		},
		version		=> $version,
		image		=> 1,
		items		=> \@items,
	}, 1);

	save2file("$constants->{basedir}/$filename", $rss, \&fudge);
}

sub bookrdf  { _do_book_rss(@_, '0.9') } # RSS 0.9
sub bookrss  { _do_book_rss(@_, '1.0') } # RSS 1.0
sub bookatom { _do_book_rss(@_, '1.0', 'atom') } # Atom 1.0


# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Bookmark;

=head1 NAME

Slash::Console - Perl extension for Bookmars 


=head1 SYNOPSIS

	use Slash::Bookmark;


=head1 DESCRIPTION

LONG DESCRIPTION.


=head1 EXPORTED FUNCTIONS

=cut

use strict;
use DBIx::Password;
use Slash;
use Slash::Display;
use Slash::Utility;

use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub createBookmark {
	my($self, $data) = @_;
	$self->sqlInsert("bookmarks", $data);
	my $id = $self->getLastInsertId();
	return $id;
}

sub getUserBookmarkByUrlId {
	my($self, $uid, $url_id) = @_;
	my $uid_q = $self->sqlQuote($uid);
	my $url_id_q = $self->sqlQuote($url_id);
	return $self->sqlSelectHashref("*", "bookmarks", "uid=$uid_q AND url_id=$url_id_q");
}

sub updateBookmark {
	my($self, $bookmark) = @_;
	$self->sqlUpdate("bookmarks", $bookmark, "bookmark_id = $bookmark->{bookmark_id}");
}

sub getRecentBookmarks {
	my($self, $limit) = @_;
	$limit ||= 50;

	return $self->sqlSelectAllHashrefArray("*", "bookmarks, urls",
		"bookmarks.url_id = urls.url_id",
		"ORDER BY bookmarks.createdtime DESC LIMIT $limit"
	);
}

sub getPopularBookmarks {
	my($self, $days, $limit) = @_;
	$days  ||= 3;
	$limit ||= 50;

	my $time_clause = " AND bookmarks.createdtime >= DATE_SUB(NOW(), INTERVAL $days DAY)";
	
	return $self->sqlSelectAllHashrefArray("COUNT(*) AS cnt, bookmarks.title, urls.*",
		"bookmarks, urls",
		"bookmarks.url_id = urls.url_id $time_clause",
		"GROUP BY urls.url_id ORDER BY popularity DESC, cnt DESC, bookmarks.createdtime DESC LIMIT $limit"
	);
	
}

sub getBookmarkFeeds {
	my($self, $options) = @_;
	$options ||= {};
	my $other = "";
	$other = "ORDER BY RAND() DESC" if $options->{rand_order};
	$self->sqlSelectAllHashrefArray("*,RAND()", "bookmark_feeds", "", $other);
}

sub getBookmarkFeedByUid {
	my($self, $uid) = @_;
	my $uid_q = $self->sqlQuote($uid);
	$self->sqlSelectHashref("*", "bookmark_feeds", "uid=$uid_q");
}

sub getBookmark {
	my($self, $id) = @_;
	my $id_q = $self->sqlQuote($id);
	$self->sqlSelectHashref("*", "bookmarks", "bookmark_id=$id_q");
}

1;

__END__


=head1 SEE ALSO

Slash(3).

=head1 VERSION

$Id$

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

1;

__END__


=head1 SEE ALSO

Slash(3).

=head1 VERSION

$Id$

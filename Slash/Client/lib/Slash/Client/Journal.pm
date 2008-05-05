# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Client::Journal;

use strict;
use warnings;

use base 'Slash::Client';

our $VERSION = 0.01;

sub new {
	my($class, $opts) = @_;

	my $self = $class->SUPER::new($opts);
	$self->{soap}{uri}   = "$self->{http}://$self->{host}/Slash/Journal/SOAP";
	$self->{soap}{proxy} = "$self->{http}://$self->{host}/journal.pl";

	return $self;
}

sub _return_from_entry {
	my($self, $id, $list) = @_;

	if ($list) {
		my $entry = $self->get_entry($id);
		return($id, $entry->{url}) if $entry && $entry->{url};
	} else {
		return $id;
	}

	return;
}

sub add_entry {
	my($self, $data) = @_;

	$data->{body} =~ s/\n/\012/g;  # Local to Unix newlines, JIC

	my $id = 0;
	if ($data->{subject} && $data->{body}) {
		$id = $self->soap->add_entry($data)->result;
	}

	return $self->_return_from_entry($id, wantarray());
}

sub modify_entry {
	my($self, $id, $data) = @_;

	$data->{body} =~ s/\n/\012/g;  # Local to Unix newlines, JIC

	my $newid = 0;
	if ($data->{subject} && $data->{body} && $id) {
		$newid = $self->soap->modify_entry($id, $data)->result;
	}

	return $self->_return_from_entry($id, wantarray());
}

sub delete_entry {
	my($self, $id) = @_;

	return $self->soap->delete_entry($id)->result;
}

sub get_entry {
	my($self, $id) = @_;

	return $self->soap->get_entry($id)->result;
}

sub get_entries {
	my($self, $uid, $limit) = @_;

	return $self->soap->get_entries($uid, $limit)->result;
}

1;

# http://use.perl.org/~pudge/journal/3294

__END__

=head1 NAME

Slash::Client::Journal - Write journal clients for Slash

=head1 SYNOPSIS

	my $client = Slash::Client::Journal->new({
		host => 'use.perl.org',
	});
	my $entry = $client->get_entry(10_000);

=head1 DESCRIPTION

Slash::Client::Journal provides an API for writing clients for Slash journals.

See L<Slash::Client> for details on authentication and for more information.

=head2 Methods

=over 4

=item add_entry(HASHREF)

Add an entry.  Must be authenticated.

Pass key-value pairs for C<subject> and C<body> (both required).  Other optional
keys are C<discuss>, C<posttype>, and C<tid>.

C<discuss> is a boolean for turning on discussions.  If false, comments
are not turned on.  If true, the user's prefs on the site are used (which
is also the default).

C<posttype> is an integer defining the post types.  This is subject to change,
but is currently: 1 = Plain Old Text, 2 = HTML Formatted,
3 = Extrans (html tags to text), 4 = Code.  Again, default is to simply use
the user's preferences.

C<tid> is a topic ID.  This varies widely between Slash sites.  To get a list,
view the source of the journal editing page and look for the "tid" form values.

In scalar context, returns the unique ID of the new entry, or false if failure.

In list context, on success, returns the URL to the new journal entry as
the second list element.


=item modify_entry(ID, HASHREF)

Modify an existing entry.  Must be authenticated.

Parameters are just like C<add_entry>.  (Note: C<discuss> cannot be modified
if a discussion had already been created for the entry.)

In scalar context, returns the unique ID of the modified entry, or false if
failure.

In list context, on success, returns the URL to the modified journal entry as
the second list element.


=item delete_entry(ID)

Deletes an existing entry.  Must be authenticated.

Returns true on success, false on error.


=item get_entries(UID [, LIMIT])

Gets the entries for a given user.  If LIMIT is not supplied, a site-defined
LIMIT is used.

Returns an arrayref of hashrefs, where each hashref is an entry, with the keys
being the entry's id, URL, and subject.

Returns false on error.


=item get_entry(ID)

Get an entry.  Returns lots of information about the entry, including uid,
nickname, date, subject, discussion ID, tid, body, URL, id, posttype,
and discussion URL.

Returns false on error.

=back


=head1 TODO

Work on error handling.


=head1 SEE ALSO

Slash::Client(3).

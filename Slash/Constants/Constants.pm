# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Constants;

=head1 NAME

Slash::Constants - Constants for Slash

=head1 SYNOPSIS

	use Slash::Constants ':all';

=head1 DESCRIPTION

This module is for a single place to have all of our constants.
Each constant is in one or more export tags.  All of the constants
can be gotten via the "all" tag.  None are exported by default.

=head1 CONSTANTS

The constants below are grouped by tag.

=cut

use strict;
use base 'Exporter';
use vars qw(@ISA $VERSION @EXPORT @EXPORT_OK %EXPORT_TAGS %CONSTANTS);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

constants();
@EXPORT		= qw();
@EXPORT_OK	= map { keys %{$CONSTANTS{$_}} } keys %CONSTANTS;
%EXPORT_TAGS	= (
	all	=> [@EXPORT_OK],
	map { ($_, [keys %{$CONSTANTS{$_}}]) } keys %CONSTANTS
);


sub constants {
	my($group, @syms, @nums);

	while (<DATA>) {
		if (/^=head2 (\w+)$/ || /^__END__$/) {
			if ($group && @syms && @nums) {
				@{$CONSTANTS{$group}}{@syms} = @nums;
			}

			$group = $1;
			@syms = @nums = ();
			last if /^__END__$/;

		} elsif (/^\t(\w+)$/) {
			push @syms, $1;

		} elsif (/^# ([\d -]+)$/) {
			push @nums, split ' ', $1;
		}
	}

	for my $g (keys %CONSTANTS) {
		for my $s (keys %{$CONSTANTS{$g}}) {
			eval "use constant $s => $CONSTANTS{$g}{$s}";
		}
	}
}

1;

# we dynamically assign the constants as formatted below.  the grouping
# tag is after "=head2", the symbols are after "\t", and the numeric
# values are listed after "#".  the format is very strict, including
# leading and trailing whitespace, so add things carefully, and check
# that you've got it right.  see the regexes in constants() if you
# are not sure what's being matched.  -- pudge

__DATA__

=head2 messages

These constants are for message delivery modes and message type codes.

	MSG_MODE_NOCODE
	MSG_MODE_NONE
	MSG_MODE_EMAIL
	MSG_MODE_WEB

=cut

# -2 -1 0 1

=pod

	MSG_CODE_REGISTRATION
	MSG_CODE_UNKNOWN
	MSG_CODE_NEWSLETTER
	MSG_CODE_HEADLINES
	MSG_CODE_M2
	MSG_CODE_COMMENT_MODERATE
	MSG_CODE_COMMENT_REPLY
	MSG_CODE_JOURNAL_FRIEND
	MSG_CODE_NEW_SUBMISSION
	MSG_CODE_JOURNAL_REPLY
	MSG_CODE_NEW_COMMENT
	MSG_CODE_INTERUSER
	MSG_CODE_ADMINMAIL
	MSG_CODE_EMAILSTORY
	MSG_CODE_ZOO_CHANGE

=cut

# -2 -1 0 1 2 3 4 5 6 7 8 9 10 11 12

=pod

	MSG_IUM_ANYONE
	MSG_IUM_FRIENDS
	MSG_IUM_NOFOES

=cut

# 1 2 3
	
=head2 web

These constants are used for web programs, for the op hashes.

	ALLOWED
	FUNCTION

=cut

# 0 1

=head2 strip

These constants are used to define the modes passed to stripByMode().  Only
user-definable constants (for journals, comments) should be E<gt>= 1.  All
else should be E<lt> 1.  If adding new user-definable modes, make sure to
change Slash::Data::strip_mode() to allow the new value.

	ANCHOR
	NOTAGS
	ATTRIBUTE
	LITERAL
	NOHTML
	PLAINTEXT
	HTML
	EXTRANS
	CODE

=cut

# -4 -3 -2 -1 0 1 2 3 4

=head2 people

These constants are used to define different constants in the people system.

	FRIEND
	FREAK
	FAN
	FOE
	FOF
	EOF

=cut

# 1 2 3 4 5 6

=head2 slashd

These constants are used to define different constants in the people system.

	SLASHD_LOG_NEXT_TASK
	SLASHD_WAIT
	SLASHD_NOWAIT

=cut

# -1 2 1

__END__

=head1 TODO

Consider allowing some constants, like MSG_CODE_* constants,
be defined dynamically.  Scary, though, with cross-dependencies
in modules, etc.

=head1 SEE ALSO

Slash(3).

=head1 VERSION

$Id$

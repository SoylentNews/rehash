# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Constants;

=head1 NAME

Slash::Constants - SHORT DESCRIPTION for Slash


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
use vars qw($VERSION @EXPORT @EXPORT_OK %EXPORT_TAGS);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;
@EXPORT	   = qw();

=head2 messages

These constants are for message delivery modes and message type codes.

	MSG_MODE_NOCODE
	MSG_MODE_NONE
	MSG_MODE_EMAIL
	MSG_MODE_WEB

	MSG_CODE_REGISTRATION
	MSG_CODE_UNKNOWN
	MSG_CODE_NEWSLETTER
	MSG_CODE_HEADLINES
	MSG_CODE_M2
	MSG_CODE_COMMENT_MODERATE
	MSG_CODE_COMMENT_REPLY
	MSG_CODE_JOURNAL_FRIEND
	MSG_CODE_NEW_SUBMISSION

=cut

my @messages = qw(
	MSG_MODE_NOCODE
	MSG_MODE_NONE
	MSG_MODE_EMAIL
	MSG_MODE_WEB

	MSG_CODE_REGISTRATION
	MSG_CODE_UNKNOWN
	MSG_CODE_NEWSLETTER
	MSG_CODE_HEADLINES
	MSG_CODE_M2
	MSG_CODE_COMMENT_MODERATE
	MSG_CODE_COMMENT_REPLY
	MSG_CODE_JOURNAL_FRIEND
	MSG_CODE_NEW_SUBMISSION
);

=head2 web

These constants are used for web programs, for the op hashes.

	ALLOWED
	FUNCTION

=cut

my @web = qw(
	ALLOWED
	FUNCTION
);

=head2 strip

These constants are used to define the modes passed to stripByMode().

	NOTAGS
	ATTRIBUTE
	LITERAL
	NOHTML
	PLAINTEXT
	HTML
	EXTRANS
	CODE
	ANCHOR

=cut

my @strip = qw(
	NOTAGS
	ATTRIBUTE
	LITERAL
	NOHTML
	PLAINTEXT
	HTML
	EXTRANS
	CODE
	ANCHOR
);

=head2 people

These constants are used to define different constants in the people system.

	FRIEND
	FOE
	FOF

=cut

my @people = qw(
	FRIEND
	FOE
	FOF
);

@EXPORT_OK = (@messages, @web, @strip, @people);

%EXPORT_TAGS = (
	all		=> [@EXPORT_OK],
	messages	=> [@messages],
	web		=> [@web],
	strip		=> [@strip],
	people		=> [@people],
);

BEGIN {
	# messages
	use constant MSG_MODE_NOCODE 		=> -2;
	use constant MSG_MODE_NONE   		=> -1;
	use constant MSG_MODE_EMAIL  		=>  0;
	use constant MSG_MODE_WEB    		=>  1;

	use constant MSG_CODE_REGISTRATION	=> -2;
	use constant MSG_CODE_UNKNOWN		=> -1;
	use constant MSG_CODE_NEWSLETTER	=>  0;
	use constant MSG_CODE_HEADLINES		=>  1;
	use constant MSG_CODE_M2		=>  2;
	use constant MSG_CODE_COMMENT_MODERATE	=>  3;
	use constant MSG_CODE_COMMENT_REPLY	=>  4;
	use constant MSG_CODE_JOURNAL_FRIEND	=>  5;
	use constant MSG_CODE_NEW_SUBMISSION	=>  6;


	# web
	use constant ALLOWED	=> 0;
	use constant FUNCTION	=> 1;


	# strip
	use constant NOTAGS	=> -3;
	use constant ATTRIBUTE	=> -2;
	use constant LITERAL	=> -1;
	use constant NOHTML	=> 0;
	use constant PLAINTEXT	=> 1;
	use constant HTML	=> 2;
	use constant EXTRANS	=> 3;
	use constant CODE	=> 4;
	use constant ANCHOR	=> 5;

	# people
	use constant FRIEND => 1;
	use constant FOE => 2;
	use constant FOF => 3;
}

1;

__END__


=head1 SEE ALSO

Slash(3).

=head1 VERSION

$Id$

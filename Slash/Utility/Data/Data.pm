# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Utility::Data;

=head1 NAME

Slash::MODULE - SHORT DESCRIPTION for Slash


=head1 SYNOPSIS

	use Slash::Utility;
	# do not use this module directly

=head1 DESCRIPTION

LONG DESCRIPTION.


=head1 EXPORTED FUNCTIONS

=cut

use strict;
use Date::Format qw(time2str);
use Date::Language;
use Date::Parse qw(str2time);
use Digest::MD5 'md5_hex';
use HTML::Entities;
use HTML::FormatText;
use HTML::TreeBuilder;
use Safe;
use Slash::Constants qw(:strip);
use Slash::Utility::Environment;
use URI;
use XML::Parser;

use base 'Exporter';
use vars qw($VERSION @EXPORT);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;
@EXPORT	   = qw(
	addDomainTags
	parseDomainTags
	balanceTags
	changePassword
	chopEntity
	countWords
	encryptPassword
	fixHref
	fixint
	fixparam
	fixurl
	fudgeurl
	formatDate
	getArmoredEmail
	html2text
	root2abs
	strip_anchor
	strip_attribute
	strip_code
	strip_extrans
	strip_html
	strip_literal
	strip_mode
	strip_nohtml
	strip_notags
	strip_plaintext
	timeCalc
	url2abs
	xmldecode
	xmlencode
	xmlencode_plain
);

# really, these should not be used externally, but we leave them
# here for reference as to what is in the package
# @EXPORT_OK = qw(
# 	approveTag
# 	breakHtml
# 	stripBadHtml
# 	processCustomTags
# 	stripByMode
# );

#========================================================================

=head2 root2abs()

Convert C<rootdir> to its absolute equivalent.  By default, C<rootdir> is
protocol-inspecific (such as "//www.example.com") and for redirects needs
to be converted to its absolute form.  There is an C<absolutedir> var, but
it is protocol-specific, and we want to inherit the protocol.  So if
C<$ENV{HTTPS}> is true, we use HTTPS, else we use HTTP.

=over 4

=item Return value

rootdir variable, converted to absolute with proper protocol.

=back

=cut

sub root2abs {
	my $rootdir = getCurrentStatic('rootdir');
	if ($rootdir =~ m|^//|) {
		$rootdir = ($ENV{HTTPS} ? 'https:' : 'http:') . $rootdir;
	}
	return $rootdir;
}

#========================================================================

=head2 url2abs(URL)

Take URL and make it absolute.  It takes a URL,
and adds rootdir to the beginning if necessary, and
adds the protocol to the beginning if necessary, and
then uses URI->new_abs() to get the correct string.

=over 4

=item Parameters

=over 4

=item URL

URL to make absolute.

=back

=item Return value

Fixed URL.

=back

=cut

sub url2abs {
	my($url) = @_;

	if (getCurrentStatic('rootdir')) {	# rootdir strongly recommended
		my $rootdir = root2abs($url);
		$url = URI->new_abs($url, $rootdir)->canonical->as_string;
	} elsif ($url !~ m|^https?://|i) {	# but not required
		$url =~ s|^/*|/|;
	}

	return $url;
}

#========================================================================

=head2 formatDate(DATA [, COLUMN, AS, FORMAT])

Converts dates from the database; takes an arrayref of rows.

This example would take the 1th element of each arrayref in C<$data>, format it,
and put the result in the 2th element.

	formatDate($data, 1, 2);

This example would take the "foo" key of each hashref in C<$data>, format it,
and put the result in the "bar" key.

	formatDate($data, 'foo', 'bar');

The C<timeCalc> function does the formatting.

=over 4

=item Parameters

=over 4

=item DATA

Data is either an arrayref of arrayrefs, or an arrayref of hashrefs.
Which it is will be determined by whether COLUMN is numeric or not.  If
it is numeric, then DATA will be assumed to be an arrayref of arrayrefs.

=item COLUMN

The column to take the data from, to be translated.  If numeric, then
DATA will be taken to be an arrayref of arrayrefs.  Otherwise, the value
will be the hashref key.  Default value is "date".

=item AS

The column where to put the newly formatted data.  If COLUMN is numeric
and AS is not defined, then AS will be the same value as COLUMN.  Otherwise,
the default value of AS is "time".

=item FORMAT

Optional Date::Format format string.

=back

=item Return value

True if successful, false if not.

=item Side effects

Changes values in DATA.

=item Dependencies

The C<timeCalc> function.

=back

=cut

sub formatDate {
	my($data, $col, $as, $format) = @_;
	errorLog('Not arrayref'), return unless ref($data) eq 'ARRAY';

	if ($col && $col =~ /^\d+$/) {   # LoL
		$as = defined($as) ? $as : $col;
		for (@$data) {
			errorLog('Not arrayref'), return unless ref eq 'ARRAY';
			$_->[$as] = timeCalc($_->[$col], $format);
		}
	} else {	# LoH
		$col ||= 'date';
		$as  ||= 'time';
		for (@$data) {
			errorLog('Not hashref'), return unless ref eq 'HASH';
			$_->{$as} = timeCalc($_->{$col}, $format);
		}
	}
}


#========================================================================

=head2 timeCalc(DATE [, FORMAT, OFFSET])

Format time strings using user's format preference.

=over 4

=item Parameters

=over 4

=item DATE

Raw date from database.

=item FORMAT

Optional format to override user's format.

=item OFFSET

Optional positive or negative integer for offset seconds from GMT,
to override user's offset.

=back

=item Return value

Formatted date string.

=item Dependencies

The 'atonish' and 'aton' template blocks.

=back

=cut

sub timeCalc {
	# raw mysql date of story
	my($date, $format, $off_set) = @_;
	my $user = getCurrentUser();
	my(@dateformats, $err);

	$off_set = $user->{off_set} unless defined $off_set;

	# massage data for YYYYMMDDHHmmSS
	$date =~ s/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/$1-$2-$3 $4:$5:$6/;

	# find out the user's time based on personal offset in seconds
	$date = str2time($date) + $off_set;

	# set user's language
	my $lang = getCurrentStatic('datelang');

	# convert the raw date to pretty formatted date
	if ($lang && $lang ne 'English') {
		my $datelang = Date::Language->new($lang);
		$date = $datelang->time2str($format || $user->{'format'}, $date);
	} else {
		$date = time2str($format || $user->{'format'}, $date);
	}

	# return the new pretty date
	return $date;
}

#========================================================================

=head2 changePassword()

Return new random 8-character password composed of 0..9, A..Z, a..z
(but not including possibly hard-to-read characters [0O1Iil]).

=over 4

=item Return value

Random password.

=back

=cut

{
	my @chars = grep !/[0O1Iil]/, 0..9, 'A'..'Z', 'a'..'z';
	sub changePassword {
		return join '', map { $chars[rand @chars] } 0 .. 7;
	}
}

#========================================================================

=head2 encryptPassword(PASSWD)

Encrypts given password.  Currently uses MD5, but could change in the future,
so do not depend on implementation.

=over 4

=item Parameters

=over 4

=item PASSWD

Password to be encrypted.

=back

=item Return value

Encrypted password.

=back

=cut

sub encryptPassword {
	my($passwd) = @_;
	return md5_hex($passwd);
}

#========================================================================

=head2 stripByMode(STRING [, MODE, NO_WHITESPACE_FIX])

Private function.  Fixes up a string based on what the mode is.  This
function is no longer exported, use the C<strip_*> functions instead.

=over 4

[ Should this be somewhat templatized, so they can customize
the little HTML bits? Same goes with related functions. -- pudge ]

=item Parameters

=over 4

=item STRING

The string to be manipulated.

=item MODE

May be one of:

=item nohtml

The default.  Just strips out HTML.

=item literal

Prints the text verbatim into HTML, which
means just converting < and > and & to their
HTML entities.  Also turns on NO_WHITESPACE_FIX.

=item extrans

Similarly to 'literal', converts everything
to its HTML entity, but then formatting is
preserved by converting spaces to HTML
space entities, and multiple newlines into BR
tags.

=item code

Just like 'extrans' but wraps in CODE tags.

=item attribute

Attempts to format string to fit in as an HTML
attribute, which means the same thing as 'literal',
but " marks are also converted to their HTML entity.

=item plaintext

Similar to 'extrans', but does not translate < and >
and & first (so C<stripBadHtml> is called first).

=item anchor

Removes ALL whitespace from inside the filter. It's
is indented for use (but not limited to) the removal
of white space from in side HREF anchor tags to 
prevent nasty browser artifacts from showing up in
the display. (Note: the value of NO_WHITESPACE_FIX 
is ignored)

=item html (or anything else)

Just runs through C<stripBadHtml>.


=item NO_WHITESPACE_FIX

A boolean that, if true, disables fixing of whitespace
problems.  A common exploit in these things is to
run a lot of characters together so the page will
stretch very wide.  If NO_WHITESPACE_FIX is false,
then space is inserted to prevent this (see C<breakHtml>).

=back

=item Return value

The manipulated string.


=back

=cut

sub stripByMode {
	my($str, $fmode, $no_white_fix) = @_;
	$fmode ||= NOHTML;
	$no_white_fix = defined($no_white_fix) ?
		$no_white_fix : $fmode == LITERAL;

	$str =~ s/(?:\015?\012|\015)/\n/g;  # change newline to local newline

	# insert whitespace into long words, convert <>& to HTML entities
	if ($fmode == LITERAL || $fmode == EXTRANS || $fmode == ATTRIBUTE || $fmode == CODE) {
		# Encode all HTML tags
		$str =~ s/&/&amp;/g;
		$str =~ s/</&lt;/g;
		$str =~ s/>/&gt;/g;
		### this is not ideal; we want breakHtml to be
		### entity-aware
		# attributes are inside tags, and don't need to be
		# broken up
		$str = breakHtml($str) unless $no_white_fix || $fmode == ATTRIBUTE;

	} elsif ($fmode == PLAINTEXT) {
		$str = processCustomTags($str);
		$str = stripBadHtml($str);
		$str = breakHtml($str) unless $no_white_fix;
	}

	# convert regular text to HTML-ized text, insert P, etc.
	if ($fmode == PLAINTEXT || $fmode == EXTRANS || $fmode == CODE) {
		$str =~ s/\n/<BR>/gi;  # pp breaks
		$str =~ s/(?:<BR>\s*){2,}<BR>/<BR><BR>/gi;
		# Preserve leading indents / spaces
		$str =~ s/\t/    /g;  # can mess up internal tabs, oh well

		if ($fmode == CODE) {  # CODE and TT are the same ... ?
			$str =~ s{((?:  )+)(?: (\S))?} {
				("&nbsp; " x (length($1)/2)) .
				(defined($2) ? "&nbsp;$2" : "")
			}eg;
			$str = '<TT>' . $str . '</TT>';

		} else {
			$str =~ s{<BR>\n?( +)} {
				"<BR>\n" . ("&nbsp; " x length($1))
			}ieg;
		}

	# strip out all HTML
	} elsif ($fmode == NOHTML || $fmode == NOTAGS) {
		$str =~ s/<.*?>//g;
		$str =~ s/<//g;
		$str =~ s/>//g;
		if ($fmode == NOHTML) {
			$str =~ s/&/&amp;/g;
		} elsif ($fmode == NOTAGS) {
			$str =~ s/&(?!#?[a-zA-Z0-9]+;)/&amp;/g
		}

	# convert HTML attribute to allowed text (just convert ")
	} elsif ($fmode == ATTRIBUTE) {
		$str =~ s/"/&#34;/g;

	# for use in templates to remove whitespace from inside HREF anchors
	} elsif ($fmode == ANCHOR) {
		$str =~ s/\n+//g;

	# probably 'html'
	} else {
		# $fmode == HTML, hopefully
		$str = processCustomTags($str);
		$str = stripBadHtml($str);
		$str = breakHtml($str) unless $no_white_fix;
	}

	return $str;
}


#========================================================================

=head2 strip_anchor(STRING [, NO_WHITESPACE_FIX])

=head2 strip_attribute(STRING [, NO_WHITESPACE_FIX])

=head2 strip_code(STRING [, NO_WHITESPACE_FIX])

=head2 strip_extrans(STRING [, NO_WHITESPACE_FIX])

=head2 strip_html(STRING [, NO_WHITESPACE_FIX])

=head2 strip_literal(STRING [, NO_WHITESPACE_FIX])

=head2 strip_nohtml(STRING [, NO_WHITESPACE_FIX])

=head2 strip_notags(STRING [, NO_WHITESPACE_FIX])

=head2 strip_plaintext(STRING [, NO_WHITESPACE_FIX])

=head2 strip_mode(STRING [, MODE, NO_WHITESPACE_FIX])

Wrapper for C<stripByMode>.  C<strip_mode> simply calls C<stripByMode>
and has the same arguments, but C<strip_mode> will only allow modes
with values greater than 0, that is, the user-supplied modes.  C<strip_mode>
is only meant to be used for processing user-supplied modes, to prevent
the user from accessing other mode types.  For using specific modes instead
of user-supplied modes, use the function with that mode's name.

See C<stripByMode> for details.

=cut

sub strip_mode {
	my($string, $mode, @args) = @_;
	return if !$mode || $mode < 1 || $mode > 4;	# user-supplied modes are 1-4
	return stripByMode($string, $mode, @args);
}

sub strip_anchor	{ stripByMode($_[0], ANCHOR,    @_[1 .. $#_]) }
sub strip_attribute	{ stripByMode($_[0], ATTRIBUTE,	@_[1 .. $#_]) }
sub strip_code		{ stripByMode($_[0], CODE,	@_[1 .. $#_]) }
sub strip_extrans	{ stripByMode($_[0], EXTRANS,	@_[1 .. $#_]) }
sub strip_html		{ stripByMode($_[0], HTML,	@_[1 .. $#_]) }
sub strip_literal	{ stripByMode($_[0], LITERAL,	@_[1 .. $#_]) }
sub strip_nohtml	{ stripByMode($_[0], NOHTML,	@_[1 .. $#_]) }
sub strip_notags	{ stripByMode($_[0], NOTAGS,	@_[1 .. $#_]) }
sub strip_plaintext	{ stripByMode($_[0], PLAINTEXT,	@_[1 .. $#_]) }


#========================================================================

=head2 stripBadHtml(STRING)

Private function.  Strips out "bad" HTML by removing unbalanced HTML
tags and sending balanced tags through C<approveTag>.  The "unbalanced"
checker is primitive; no "E<lt>" or "E<gt>" tags will are allowed inside
tag attributes (such as E<lt>A NAME="E<gt>"E<gt>), that breaks the tag.
Also, whitespace is inserted between adjacent tags, so "E<lt>BRE<gt>E<lt>BRE<gt>"
becomes "E<lt>BRE<gt> E<lt>BRE<gt>".

=over 4

=item Parameters

=over 4

=item STRING

String to be processed.

=back

=item Return value

Processed string.

=item Dependencies

C<approveTag> function.

=back

=cut

sub stripBadHtml {
	my($str) = @_;

	$str =~ s/<(?!.*?>)//gs;
	$str =~ s/<(.*?)>/approveTag($1)/sge;
	$str =~ s/></> </g;

	# Encode stray >
	1 while $str =~ s{
		(
			(?: ^ | > )	# either beginning of string,
					# or another close bracket
			[^<]*		# not matching open bracket
		)
		>			# close bracket
	}{$1&gt;}gx;


	# Encode stray <
	1 while $str =~ s{
		<			# open bracket
		(
			[^>]*		# not match close bracket
			(?: < | $ )	# either open bracket, or
					# end of string
		)
	}{&lt;$1}gx;

	return $str;
}

#========================================================================

=head2 processCustomTags(STRING)

Private function.  It does processing of special custom tags
(so far, just ECODE, and its deprecated synonym, LITERAL).

=over 4

=item Parameters

=over 4

=item STRING

String to be processed.

=back

=item Return value

Processed string.

=item Dependencies

It is meant to be used before C<stripBadHtml> is called, only
from regular posting modes, HTML and PLAINTEXT.

=back

=cut

sub processCustomTags {
	my($str) = @_;
	my $constants = getCurrentStatic();

	## Deal with special ECODE tag (Embedded Code).  This tag allows
	## embedding the Code postmode in plain or HTML modes.  It may be
	## of the form:
	##    <ECODE>literal text</ECODE>
	## or, for the case where "</ECODE>" is needed in the text:
	##    <ECODE END="SOMETAG">literal text</SOMETAG>
	##
	## SOMETAG must match /^\w+$/.
	##
	##
	## Note that we also strip out leading and trailing newlines
	## surrounding the tags, because in plain text mode this can
	## be hard to manage, so we manage it for the user.
	##
	## Also note that this won't work if the site disallows TT
	## or BLOCKQUOTE tags.
	##
	## -- pudge

	# ECODE must be in approvedtags
	if (grep /^ECODE$/, @{$constants->{approvedtags}}) {
		my $ecode   = 'literal|ecode';  # "LITERAL" is old name
		my $open    = qr[\n* <\s* (?:$ecode) (?: \s+ END="(\w+)")? \s*> \n*]xsio;
		my $close_1 = qr[$open (.*?) \n* <\s* /\2    \s*> \n*]xsio;  # if END is used
		my $close_2 = qr[$open (.*?) \n* <\s* /ECODE \s*> \n*]xsio;  # if END is not used

		while ($str =~ m[($open)]g) {
			my $len = length($1);
			my $end = $2;
			my $pos = pos($str) - $len;

			my $newlen = 25;  # length('<BLOCKQUOTE></BLOCKQUOTE>')
			my $close = $end ? $close_1 : $close_2;

			my $ok = $str =~ s[^ (.{$pos}) $close][
				my $code = strip_code($3);
				$newlen += length($code);
				$1 . "<BLOCKQUOTE>$code</BLOCKQUOTE>";
			]xsie;

			pos($str) = $pos + $newlen if $ok;
		}
	}

	return $str;
}

#========================================================================

=head2 breakHtml(TEXT, MAX_WORD_LENGTH)

Private function.  Break up long words in some text.  Will ignore the
contents of HTML tags.  Called from C<stripByMode> functions.

=over 4

=item Parameters

=over 4

=item TEXT

The text to be fixed.

=item MAX_WORD_LENGTH

The maximum length of a word.  Default is 50 (breakhtml_wordlength in vars).

=back

=item Return value

The text.

=back

=cut

sub breakHtml {
	my($text, $mwl) = @_;
	my($new, $l, $c, $in_tag, $this_tag, $cwl);

	my $constants = getCurrentStatic();

	# these are tags that "break" a word;
	# a<P>b</P> breaks words, y<B>z</B> does not
	my $approvedtags_break = $constants->{'approvedtags_break'}
		|| [qw(HR BR LI P OL UL BLOCKQUOTE DIV)];
	my %is_break_tag = map { uc, 1 } @$approvedtags_break;

	$mwl = $mwl || $constants->{'breakhtml_wordlength'} || 50;
	$l = length $text;

	for (my $i = 0; $i < $l; $new .= $c, ++$i) {
		$c = substr($text, $i, 1);
		if ($c eq '<')		{ $in_tag = 1 }
		elsif ($c eq '>')	{
			$in_tag = 0;
			$this_tag =~ s{^/?(\S+).*}{\U$1};
			$cwl = 0 if $is_break_tag{$this_tag};
			$this_tag = '';
		}
		elsif ($in_tag)		{ $this_tag .= $c }
		elsif ($c =~ /\s/)	{ $cwl = 0 }
		elsif (++$cwl > $mwl)	{ $new .= ' '; $cwl = 1 }
	}

	return $new;
}

#========================================================================

=head2 fixHref(URL [, ERROR])

Take a relative URL and fix it to some predefined set.

I don't really like this function much, it should be played with.

=over 4

=item Parameters

=over 4

=item URL

Relative URL to manipulate.

=item ERROR

Boolean whether or not to return error number.

=back

=item Return value

Undef if URL is not handled.  If it is handled and ERROR is false,
new URL is returned.  If it is handled and ERROR is true, URL
and the error number are returned.

=item Dependencies

The fixhrefs section in the vars table, and some sort of table
(like 404-main) for determining what the number means.

=back

=cut

sub fixHref {  # I don't like this.  we need to change it. -- pudge
	my($rel_url, $print_errs) = @_;
	my $abs_url; # the "fixed" URL
	my $errnum; # the errnum for 404.pl

	my $fixhrefs = getCurrentStatic('fixhrefs');
	for my $qr (@{$fixhrefs}) {
		if ($rel_url =~ $qr->[0]) {
			my @ret = $qr->[1]->($rel_url);
			return $print_errs ? @ret : $ret[0];
		}
	}

	my $rootdir = getCurrentStatic('rootdir');
	if ($rel_url =~ /^www\.\w+/) {
		# errnum 1
		$abs_url = "http://$rel_url";
		return($abs_url, 1) if $print_errs;
		return $abs_url;

	} elsif ($rel_url =~ /^ftp\.\w+/) {
		# errnum 2
		$abs_url = "ftp://$rel_url";
		return ($abs_url, 2) if $print_errs;
		return $abs_url;

	} elsif ($rel_url =~ /^[\w\-\$\.]+\@\S+/) {
		# errnum 3
		$abs_url = "mailto:$rel_url";
		return ($abs_url, 3) if $print_errs;
		return $abs_url;

	} elsif ($rel_url =~ /^articles/ && $rel_url =~ /\.shtml$/) {
		# errnum 6
		my @chunks = split m|/|, $rel_url;
		my $file = pop @chunks;

		if ($file =~ /^98/ || $file =~ /^0000/) {
			$rel_url = "$rootdir/articles/older/$file";
			return ($rel_url, 6) if $print_errs;
			return $rel_url;
		} else {
			return;
		}

	} elsif ($rel_url =~ /^features/ && $rel_url =~ /\.shtml$/) {
		# errnum 7
		my @chunks = split m|/|, $rel_url;
		my $file = pop @chunks;

		if ($file =~ /^98/ || $file =~ /~00000/) {
			$rel_url = "$rootdir/features/older/$file";
			return ($rel_url, 7) if $print_errs;
			return $rel_url;
		} else {
			return;
		}

	} elsif ($rel_url =~ /^books/ && $rel_url =~ /\.shtml$/) {
		# errnum 8
		my @chunks = split m|/|, $rel_url;
		my $file = pop @chunks;

		if ($file =~ /^98/ || $file =~ /^00000/) {
			$rel_url = "$rootdir/books/older/$file";
			return ($rel_url, 8) if $print_errs;
			return $rel_url;
		} else {
			return;
		}

	} elsif ($rel_url =~ /^askslashdot/ && $rel_url =~ /\.shtml$/) {
		# errnum 9
		my @chunks = split m|/|, $rel_url;
		my $file = pop @chunks;

		if ($file =~ /^98/ || $file =~ /^00000/) {
			$rel_url = "$rootdir/askslashdot/older/$file";
			return ($rel_url, 9) if $print_errs;
			return $rel_url;
		} else {
			return;
		}

	} else {
		# if we get here, we don't know what to
		# $abs_url = $rel_url;
		return;
	}

	# just in case
	return $abs_url;
}

#========================================================================

=head2 approveTag(TAG)

Private function.  Checks to see if HTML tag is OK, and adjusts it as necessary.

=over 4

=item Parameters

=over 4

=item TAG

Tag to check.

=back

=item Return value

Tag after processing.

=item Dependencies

Uses the "approvetags" variable in the vars table.  Passes URLs
in HREFs through C<fudgeurl>.

=back

=cut

sub approveTag {
	my($tag) = @_;

	$tag =~ s/^\s*?(.*)\s*?$/$1/; # trim leading and trailing spaces
	$tag =~ s/\bstyle\s*=(.*)$//is; # go away please

	# Take care of URL:foo and other HREFs
	# Using /s means that the entire variable is treated as a single line
	# which means \n will not fool it into stopping processing.  fudgeurl()
	# knows how to handle multi-line URLs (it removes whitespace).
	if ($tag =~ /^URL:(.+)$/is) {
		my $url = fudgeurl($1);
		return qq!<A HREF="$url">$url</A>!;
	} elsif ($tag =~ /href\s*=\s*(.+)$/is) {
		my $url_raw = $1;
		# Try to get a little closer to the URL we want, and in
		# particular, don't strip '<a href="foo" target="bar">'
		# to the URL 'footarget=bar'.
		$url_raw = $1 if $url_raw =~ /^"([^"]+)"/;
		$url_raw =~ s/\s+target=.+//;
		my $url = fudgeurl($url_raw);
		return qq!<A HREF="$url">!;
	}

	# Validate all other tags
	my $approvedtags = getCurrentStatic('approvedtags');
	$tag =~ s|^(/?\w+)|\U$1|;
	# ECODE is an exception, to be handled elsewhere
	foreach my $goodtag (grep !/^ECODE$/, @$approvedtags) {
		return "<$tag>" if $tag =~ /^$goodtag$/ || $tag =~ m|^/$goodtag$|;
	}
}

#========================================================================

=head2 fixparam(DATA)

Prepares data to be a parameter in a URL.  Such as:

=over 4

	my $url = 'http://example.com/foo.pl?bar=' . fixparam($data);

=item Parameters

=over 4

=item DATA

The data to be escaped.

=back

=item Return value

The escaped data.

=back

=cut

sub fixparam {
	my($url) = @_;
	$url =~ s/([^$URI::unreserved])/$URI::Escape::escapes{$1}/oge;
	return $url;
}

#========================================================================

=head2 fixurl(DATA)

Prepares data to be a URL or in part of a URL.  Such as:

=over 4

	my $url = 'http://example.com/~' . fixurl($data) . '/';

=item Parameters

=over 4

=item DATA

The data to be escaped.

=back

=item Return value

The escaped data.

=back

=cut

sub fixurl {
	my($url) = @_;
	# add '#' to allowed characters, since it is often included
	$url =~ s/([^$URI::uric#])/$URI::Escape::escapes{$1}/oge;
	return $url;
}

#========================================================================

=head2 fudgeurl(DATA)

Prepares data to be a URL.  Such as:

=over 4

	my $url = fixparam($someurl);

=item Parameters

=over 4

=item DATA

The data to be escaped.

=back

=item Return value

The escaped data.

=back

=cut

{
# Use a closure so we only have to generate the regex once.
my $scheme_regex = "";
sub fudgeurl {
	my($url) = @_;

	my $constants = getCurrentStatic();

	# Remove quotes and whitespace (we will expect some at beginning and end,
	# probably)
	$url =~ s/["\s]//g;
	# any < or > char after the first char truncates the URL right there
	# (we will expect a trailing ">" probably)
	$url =~ s/^[<>]+//;
	$url =~ s/[<>].*//;
	# strip surrounding ' if exists
	$url =~ s/^'(.+?)'$/$1/g;
	# escape anything not allowed
	$url = fixurl($url);
	# run it through the grungy URL miscellaneous-"fixer"
	$url = fixHref($url) || $url;

	my $uri = new URI $url;
	my $scheme = undef;
	$scheme = $uri->scheme if $uri && $uri->can("scheme");
	if (!$scheme_regex) {
		$scheme_regex = join("|", map { lc } @{$constants->{approved_url_schemes}});
		$scheme_regex = qr{^(?:$scheme_regex)$};
	}

	if ($scheme && $scheme !~ $scheme_regex) {

		$url =~ s/^$scheme://i;
		$url =~ tr/A-Za-z0-9-//cd; # allow only a few chars
		$url = "$scheme:$url";

	} elsif (1) {
		# Strip the authority, if any.
		# This prevents annoying browser-display-exploits
		# like "http://cnn.com%20%20%20...%20@baddomain.com".
		# In future we may set up a package global or a field like
		# getCurrentUser()->{state}{fixurlauth} that will allow
		# this behavior to be turned off -- it's wrapped in
		# "if (1)" to remind us of this...

		if ($uri && $uri->can('host') && $uri->can('authority')) {
			# Make sure the host and port are legit, then zap
			# the port if it's the default port.
			my $host = $uri->host;
			$host =~ tr/A-Za-z0-9.-//cd; # per RFC 1035
			$uri->host($host);
			my $authority = $uri->can('host_port') &&
				$uri->port != $uri->default_port
				? $uri->host_port
				: $host;
			$uri->authority($authority);
			$url = $uri->canonical->as_string;
		}
	}

	# we don't like SCRIPT at the beginning of a URL
	my $decoded_url = decode_entities($url);
	return $decoded_url =~ /^[\s\w]*script\b/i ? undef : $url;
}
}

#========================================================================

=head2 chopEntity(STRING)

Chops a string to a specified length, without splitting in the middle
of an HTML entity or HTML tag (so we will err on the short side).

=over 4

=item Parameters

=over 4

=item STRING

String to be chomped.

=back

=item Return value

Chomped string.

=back

=cut

sub chopEntity {
	my($text, $length) = @_;
	$text = substr($text, 0, $length) if $length;
	$text =~ s/&#?[a-zA-Z0-9]*$//;
	$text =~ s/<[^>]*$//;
	return $text;
}


# DOCUMENT after we remove some of this in favor of
# HTML::Element

sub html2text {
	my($html, $col) = @_;
	my($text, $tree, $form, $refs);

	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();

	$col ||= 74;

	$tree = new HTML::TreeBuilder;
	$form = new HTML::FormatText (leftmargin => 0, rightmargin => $col-2);
	$refs = new HTML::FormatText::AddRefs;

	$tree->parse($html);
	$tree->eof;
	$refs->parse_refs($tree);
	$text = $form->format($tree);
	1 while chomp($text);

	return $text, $refs->get_refs($constants->{absolutedir});
}

sub HTML::FormatText::AddRefs::new {
	bless { HH => {}, HA => [], HS => 0 }, $_[0];
};

sub HTML::FormatText::AddRefs::parse_refs {
	my($ref, $self, $format) = @_;
	$format ||= '[%d]%s';

	# find all the HREFs where the tag is "a"
	if (exists $self->{'href'} && $self->{'_tag'} =~ /^[aA]$/) {
		my $href = $self->{'href'};

		# only increment number in hash and add to array if
		# not already in array/hash
		if (!exists $ref->{'HH'}{$href}) {
			$ref->{'HH'}{$href} = $$ref{'HS'}++;
			push(@{$ref->{'HA'}}, $href);
		}

		# get nested elements
		my $con = $self->{'_content'};
		while (ref($con->[0]) eq 'HTML::Element') {
			$con = $con->[0]{'_content'};
		}

		# add "footnote" to text
		$con->[0] = sprintf(
			$format, $ref->{'HH'}{$href}, $con->[0]
		) if defined $con->[0];

	# get nested elements
	} elsif (exists $self->{'_content'}) {
		foreach (@{$self->{'_content'}}) {
			if (ref($_) eq 'HTML::Element') {
				$ref->parse_refs($_);
			}
		}
	}
}

sub HTML::FormatText::AddRefs::add_refs {
	my($ref, $url) = @_;

	my $count = 0;
	my $ascii = "\n\nReferences\n";
	foreach ($ref->get_refs($url, $count)) {
		$ascii .= sprintf("%4d. %s\n", $count++, $_);
	}
	return $ascii;
}


sub HTML::FormatText::AddRefs::get_refs {
	my($ref, $url) = @_;

	my @refs;
	foreach (@{$ref->{'HA'}}) {
		push @refs, URI->new_abs($_, $url);
	}
	return @refs;
}


#========================================================================

=head2 balanceTags(HTML [, DEEP_NESTING])

Balances HTML tags; if tags are not closed, close them; if they are not
open, remove close tags; if they are in the wrong order, reorder them
(order of open tags determines order of close tags).

=over 4

=item Parameters

=over 4

=item HTML

The HTML to balance.

=item DEEP_NESTING

Integer for how deep to allow nesting indenting tags, 0 means
no limit.

=back

=item Return value

The balances HTML.

=item Dependencies

The 'approvedtags' and 'lonetags' entries in the vars table.

=back

=cut

sub balanceTags {
	my($html, $max_nest_depth) = @_;
	my(%tags, @stack, $match, %lone, $tag, $close, $whole);
	my $constants = getCurrentStatic();

	# set up / get preferences
	if (@{$constants->{lonetags}}) {
		# ECODE is an exception, to be handled elsewhere
		$match = join '|', grep !/^ECODE$/,
			@{$constants->{approvedtags}};
	} else {
		$constants->{lonetags} = [qw(P LI BR)];
		$match = join '|', grep !/^(?:P|LI|BR|ECODE)$/,
			@{$constants->{approvedtags}};
	}
	%lone = map { ($_, 1) } @{$constants->{lonetags}};

	# If the quoted slash in the next line bothers you, then feel free to
	# remove it. It's just there to prevent broken syntactical highlighting
	# on certain editors (vim AND xemacs).  -- Cliff
	# maybe you should use a REAL editor, like BBEdit.  :) -- pudge
	while ($html =~ m|(<(\/?)($match)\b[^>]*>)|igo) { # loop over tags
		($tag, $close, $whole) = (uc($3), $2, $1);

		if ($close) {
			if (@stack && $tags{$tag}) {
				# Close the tag on the top of the stack
				if ($stack[-1] eq $tag) {
					$tags{$tag}--;
					pop @stack;

				# Close tag somewhere else in stack
				} else {
					my $p = pos($html) - length($whole);
					if (exists $lone{$stack[-1]}) {
						pop @stack;
					} else {
						substr($html, $p, 0) = "</$stack[-1]>";
					}
					pos($html) = $p;  # don't remove this from stack, go again
				}

			} else {
				# Close tag not on stack; just delete it
				my $p = pos($html) - length($whole);
				$html =~ s|^(.{$p})\Q$whole\E|$1|si;
				pos($html) = $p;
			}

		} else {
			$tags{$tag}++;
			push @stack, $tag;

			if ($max_nest_depth) {
				my $cur_depth = 0;
				for (qw( UL OL DIV BLOCKQUOTE )) { $cur_depth += $tags{$_} }
				return undef if $cur_depth > $max_nest_depth;
			}
		}

	}

	$html =~ s/\s+$//;

	# add on any unclosed tags still on stack
	$html .= join '', map { "</$_>" } grep {! exists $lone{$_}} reverse @stack;

	return $html;
}

#========================================================================

=head2 parseDomainTags(HTML, RECOMMENDED, NOTAGS)

To be called before sending the HTML to the user for display.  Takes
HTML with domain tags (see addDomainTags()) and parses out the tags,
if necessary.

=over 4

=item Parameters

=over 4

=item HTML

The HTML with tagged with domains.

=item RECOMMENDED

Boolean for whether or not domain tags are recommended.  They are not
required, the user can choose to leave it up to us.

=item NOTAGS

Boolean overriding RECOMMENDED; it strips out all domain tags if true.

=back

=item Return value

The parsed HTML.

=back

=cut

sub parseDomainTags {
	my($html, $recommended, $notags) = @_;
	return "" if !defined($html) || $html eq "";

	my $user = getCurrentUser();

	# default is 2 # XXX Jamie I think should be 1
	my $udt = exists($user->{domaintags}) ? $user->{domaintags} : 2;

	$udt =~ /^(\d+)$/;			# make sure it's numeric, sigh
	$udt = 2 if !length($1);

	my $want_tags = 1;			# assume we'll be displaying the [domain.tags]
	$want_tags = 0 if			# but, don't display them if...
		$udt == 0			# the user has said they never want the tags
		|| (				# or
			$udt == 1		# the user leaves it up to us
			and $recommended	# and we think the poster has earned tagless posting
		);

	if ($want_tags && !$notags) {
		$html =~ s{</A ([^>]+)>}{</A> [$1]}gi;
	} else {
		$html =~ s{</A[^>]+>}{</A>}gi;
	}

	return $html;
}


#========================================================================

=head2 addDomainTags(HTML)

To be called only after C<balanceTags>, or results are not guaranteed.
Munges HTML E<lt>/aE<gt> tags into E<lt>/a foo.comE<gt> tags, where
"foo.com" is the domain name of the link found in the opening E<lt>aE<gt>
tag.  Note that this is not proper HTML, and that C<dispComment> knows
how properly to convert it back to proper HTML.

=over 4

=item Parameters

=over 4

=item HTML

The HTML to tag with domains.

=back

=item Return value

The tagged HTML.

=back

=cut

sub addDomainTags {
	my($html) = @_;

	# First step is to eliminate unclosed <A> tags.

	my $in_a = 0;
	$html =~ s
	{
		( < (/?) A \b[^>]* > )
	}{
		my $old_in_a = $in_a;
		my $new_in_a = !$2;
		$in_a = $new_in_a;
		(($old_in_a && $new_in_a) ? "</A>" : "") . $1
	}gixe;
	$html .= "</A>" if $in_a;

	# Now, since we know that every <A> has a </A>, this pattern will
	# match and let the subroutine above do its magic properly.
	# Note that, since a <A> followed immediately by </A> will not
	# only fail to appear in a browser, but would also look goofy if
	# followed by a [domain.tag], in such a case we simply remove the
	# <A></A> pair entirely.

	$html =~ s
	{
		(<A\s+HREF="		# $1 is the whole <A HREF...>
			([^">]*)	# $2 is the URL (quotes guaranteed to
					# be there thanks to approveTag)
		">)
		(.*?)			# $3 is whatever's between <A> and </A>
		</A\b[^>]*>
	}{
		$3	? $1 . $3 . _url_to_domain_tag($2)
			: ""
	}gisex;

	# If there were unmatched <A> tags in the original, balanceTags()
	# would have added the corresponding </A> tags to the end.  These
	# will stick out now because they won't have domain tags.  We
	# know we've added enough </A> to make sure everything balances
	# and doesn't overlap, so now we can just remove the extra ones,
	# which are easy to tell because they DON'T have domain tags.

	$html =~ s{</A>}{}g;

	return $html;
}

sub _url_to_domain_tag {
	my($link) = @_;
	my $absolutedir = getCurrentStatic('absolutedir');
	my $uri = URI->new_abs($link, $absolutedir);
	my($info, $host, $scheme) = ("", "", "");
	if ($uri->can("host") and $host = $uri->host) {
		$info = lc $host;
		if ($info =~ m/^([\d.]+)\.in-addr\.arpa$/) {
			$info = join(".", reverse split /\./, $1);
		}
		if ($info =~ m/^(\d{1,3}\.){3}\d{1,3}$/) {
			# leave a numeric IP address alone
		} elsif ($info =~ m/([\w-]+\.[a-z]{3,4})$/) {
			# a.b.c.d.com -> d.com
			$info = $1;
		} elsif ($info =~ m/([\w-]+\.[a-z]{2,4}\.[a-z]{2})$/) {
			# a.b.c.d.co.uk -> d.co.uk
			$info = $1;
		} elsif ($info =~ m/([\w-]+\.[a-z]{2})$/) {
			# a.b.c.realdomain.gr -> realdomain.gr
			$info = $1;
		} else {
			# any other a.b.c.d.e -> c.d.e
			my @info = split /\./, $info;
			my $num_levels = scalar @info;
			if ($num_levels >= 3) {
				$info = join(".", @info[-3..-1]);
			}
		}
	} elsif ($uri->can("scheme") and $scheme = $uri->scheme) {
		# Most schemes, like ftp or http, have a host.  Some,
		# most notably mailto and news, do not.  For those,
		# at least give the user an idea of why not, by
		# listing the scheme.
		$info = lc $scheme;
	} else {
		$info = "?";
	}
	if ($info ne "?") {
		$info =~ tr/A-Za-z0-9.-//cd;
	}
	if (length($info) == 0) {
		$info = "?";
	} elsif (length($info) >= 25) {
		$info = substr($info, 0, 10) . "..." . substr($info, -10);
	}
	return "</a $info>";
}

#========================================================================

=head2 xmlencode_plain(TEXT)

Same as xmlencode(TEXT), but does not encode for use in HTML.  This is
currently ONLY for use for E<lt>linkE<gt> elements.

=over 4

=item Parameters

=over 4

=item TEXT

Whatever text it is you want to encode.

=back

=item Return value

The encoded string.

=item Dependencies

XML::Parser::Expat(3).

=back

=cut

sub xmlencode_plain {
	xmlencode($_[0], 1);
}

#========================================================================

=head2 xmlencode(TEXT)

Encodes / escapes a string for putting into XML.
The text goes through three phases: we first convert
all "&" that are not part of an entity to "&amp;"; then
we convert all "&", "<", and ">" to their entities.
Then all characters that are not printable ASCII characters
(\040 to \176) are converted to their numeric entities
(such as "&#192;").

Note that this is basically encoding a string into valid
HTML, then escaping it for XML.  When run through regular
XML unescaping, a valid HTML string should remain
(that is, the characters will be valid for HTML, while it
may not be syntactically correct).  You may use something
like C<HTML::Entities::decode_entities> if you wish to get
the regular text.

=over 4

=item Parameters

=over 4

=item TEXT

Whatever text it is you want to encode.

=back

=item Return value

The encoded string.

=item Dependencies

XML::Parser::Expat(3).

=back

=cut

sub xmlencode {
	my($text, $nohtml) = @_;

	# if there is an & that is not part of an entity, convert it
	# to &amp;
	$text =~ s/&(?!#?[a-zA-Z0-9]+;)/&amp;/g
		unless $nohtml;

	# convert & < > to XML entities
	$text = XML::Parser::Expat->xml_escape($text, ">");

	# convert ASCII-non-printable to numeric entities
	$text =~ s/([^\s\040-\176])/ "&#" . ord($1) . ";" /ge;

	return $text;
}


#========================================================================

=head2 xmldecode(TEXT)

Decodes / unescapes an XML string.  It basically just
decodes the five entities used to encode "<", ">", '"',
"'", and "&".  "&" is only decoded if it is not the start
of an entity.

This will decode the named, decimal numeric, or hex numeric
versions of the entities.

Note that while C<xmlencode> will make sure the characters
in the string are proper HTML characters, C<xmldecode> will
not take the extra step to get back the original non-HTML
text; we want to leave the text as OK to put directly into
HTML.  You may use something like
C<HTML::Entities::decode_entities> if you wish to get
the regular text.

=over 4

=item Parameters

=over 4

=item TEXT

Whatever text it is you want to decode.

=back

=item Return value

The decoded string.

=back

=cut

{
	# for all following chars but &, convert entities back to
	# the actual character

	# for &, convert &amp; back to &, but only if it is the
	# beginning of an entity (like "&amp;#32;")

	# precompile these so we only do it once

	my %e = qw(< lt > gt " quot ' apos & amp);
	for my $chr (keys %e) {
		my $word = $e{$chr};
		my $ord = ord $chr;
		my $hex = sprintf "%x", $ord;
		$hex =~ s/([a-f])/[$1\U$1]/g;
		my $regex = qq/&(?:$word|#$ord|#[xX]$hex);/;
		$regex .= qq/(?=#?[a-zA-Z0-9]+;)/ if $chr eq "&";
		$e{$chr} = qr/$regex/;
	}

	sub xmldecode {
		my($text) = @_;

		# do & only _after_ the others
		for my $chr ((grep !/^&$/, keys %e), "&") {
			$text =~ s/$e{$chr}/$chr/g;
		}

		return $text;
	}
}

#========================================================================

=head2 getArmoredEmail (UID)

Returns a Spam Armored email address for the user associated with the
given UID.

This routine DOES NOT save its results back to the user record. This is
the responsibility of the calling routine.

=over 4

=item Parameters

=over 4

=item UID

The user's ID whose email address you wish to randomize.

=back

=item Return value

The email address, if successful.

=back

=cut

sub getArmoredEmail {
	my($uid, $realemail) = @_;
	# If the caller knows realemail, pass it in to maybe save a DB query
	$realemail ||= '';

	my $slashdb = getCurrentDB();
	my $armor = $slashdb->getRandomSpamArmor();

	# Execute the retrieved code in a Safe compartment. We do this
	# in an anonymous block to enable local scoping for some variables.
	{
		local $_ = $realemail;
		$_ ||= $slashdb->getUser($uid, 'realemail');

		# maybe this should be cached, something like the template
		# cache in Slash::Display?  it has some significant
		# overhead -- pudge
		my $cpt = new Safe;

		# We only permit basic arithmetic, loop and looping opcodes.
		# We also explicitly allow join since some code may involve
		# Separating the address so that obfuscation can be performed
		# in parts.
		# NOTE: these opcode classes cannot be in the database etc.,
		# because that would compromise the security model.  -- pudge
		$cpt->permit(qw[:base_core :base_loop :base_math join]);

		# Each compartment should be designed to take input from, and
		# send output to, $_.
		$cpt->reval($armor->{code});
		return $_ unless $@;

		# If we are here, an error occured in the block. This should be
		# logged.
		#
		# Ideally, this text should be in a template, somewhere
		# but I hesitate to use Slash::getData() in a module where I
		# don't see it already in use. - Cliff
		# it can be used anywhere, since Slash.pm is assumed to
		# be loaded -- pudge
		errorLog(<<EOT);
Error randomizing realemail using armor '$armor->{name}':
$@
EOT

	}
}

########################################################
# fix parameter input that should be integers
sub fixint {
	my($int) = @_;
	$int =~ s/^\+//;
	$int =~ s/^(-?[\d.]+).*$/$1/s or return;
	return $int;
}

########################################################
# Count words in a given scalar will strip HTML tags
# before counts are made.
sub countWords {
	my($body) = @_;

	# Sanity check.
	return 0 if ref $body;

	# Get rid of nasty print artifacts that may screw up counts.
	$body = strip_nohtml($body);
	$body =~ s/['`"~@#$%^()|\\\/!?.]//g;
	$body =~ s/&(?:\w+|#(\d+));//g;
	$body =~ s/[;\-,+=*&]/ /g;
	$body =~ s/\s\s+/ /g;

	# count words in $body.
	my(@words) = ($body =~ /\b/g);

	# Since we count boundaries, each word has two boundaries, so
	# we divide by two to get our count. This results in values
	# *close* to the return from a 'wc -w' on $body (within 1)
	# so I think this is close enough. ;)
	# - Cliff
	return scalar @words / 2;
}


1;

__END__


=head1 SEE ALSO

Slash(3), Slash::Utility(3).

=head1 VERSION

$Id$

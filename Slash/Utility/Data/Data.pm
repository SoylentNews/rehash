# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
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
	createStoryTopicData
	slashizeLinks
	approveCharref
	parseDomainTags
	parseSlashizedLinks
	balanceTags
	changePassword
	chopEntity
	commify
	countTotalVisibleKids
	countWords
	decode_entities
	ellipsify
	encryptPassword
	findWords
	fixHref
	fixint
	fixparam
	fixurl
	fudgeurl
	formatDate
	getArmoredEmail
	grepn
	html2text
	nickFix
	nick2matchname
	root2abs
	set_rootdir
	sitename2filename
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
	strip_paramattr
	strip_urlattr
	timeCalc
	url2abs
	xmldecode
	xmlencode
	xmlencode_plain
	vislenify
);

# really, these should not be used externally, but we leave them
# here for reference as to what is in the package
# @EXPORT_OK = qw(
# 	approveTag
# 	breakHtml
# 	processCustomTags
# 	stripByMode
# );

#========================================================================

sub nickFix {
	my($nick) = @_;
	my $constants = getCurrentStatic();
	$nick =~ s/\s+/ /g;
	$nick =~ s/[^$constants->{nick_chars}]+//g;
	$nick = substr($nick, 0, $constants->{nick_maxlen});
	return $nick;
}

#========================================================================

sub nick2matchname {
	my($nick) = @_;
	$nick = lc $nick;
	$nick =~ s/[^a-zA-Z0-9]//g;
	return $nick;
}

#========================================================================

=head2 root2abs()

Convert C<rootdir> to its absolute equivalent.  By default, C<rootdir> is
protocol-inspecific (such as "//www.example.com") and for redirects needs
to be converted to its absolute form.  There is an C<absolutedir> var, but
it is protocol-specific, and we want to inherit the protocol.  So if we're
connected over HTTPS, we use HTTPS, else we use HTTP.

=over 4

=item Return value

rootdir variable, converted to absolute with proper protocol.

=back

=cut

sub root2abs {
	my $user = getCurrentUser();

	if ($user->{state}{ssl}) {
		return getCurrentStatic('absolutedir_secure');
	} else {
		return getCurrentStatic('absolutedir');
	}
}

#========================================================================

=head2 set_rootdir()

Make sure all your rootdirs use the same scheme (even if that scheme is no
scheme), and absolutedir's scheme can still be section-specific, and we don't
need an extra var for rootdir/absolutedir.

In the future, even this behavior should perhaps be overridable (so
sites could have http for the main site, and https for sections, for
example).

=over 4

=item Return value

rootdir variable, converted to proper scheme.

=back

=cut

sub set_rootdir {
	my($sectionurl, $rootdir) = @_;
	my $rooturi    = new URI $rootdir, "http";
	my $sectionuri = new URI $sectionurl, "http";

	$sectionuri->scheme($rooturi->scheme || undef);
	return $sectionuri->as_string;
}


#========================================================================

=head2 url2abs(URL [, BASE])

Take URL and make it absolute.  It takes a URL,
and adds base to the beginning if necessary, and
adds the protocol to the beginning if necessary, and
then uses URI->new_abs() to get the correct string.

=over 4

=item Parameters

=over 4

=item URL

URL to make absolute.

=item BASE

URL base.  If not provided, uses rootdir.

=back

=item Return value

Fixed URL.

=back

=cut

sub url2abs {
	my($url, $base) = @_;
	my $newurl;

	# set base only if not already set, and rootdir exists
	$base ||= root2abs();

	if ($base) {
		$newurl = URI->new_abs($url, $base)->canonical->as_string;
	} elsif ($url !~ m|^https?://|i) {	# no base or rootdir, best we can do
		$newurl =~ s|^/*|/|;
	}

	$newurl =~ s|/$|| if $url !~ m|/$|;

	return $newurl;
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

	if (defined($col) && $col =~ /^\d+$/) {   # LoL
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

	# massage data for YYYYMMDDHHmmSS or YYYYMMDDHHmm
	$date =~ s/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?$/"$1-$2-$3 $4:$5:" . ($6 || '00')/e;

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

{ # closure for stripByMode

my %latin1_to_ascii = (
	133	=> '...',
	135	=> 'f',
	138	=> 'S',
	140	=> 'OE',
	142	=> 'Z',
	145	=> '\'',
	146	=> '\'',
	147	=> '"',
	148	=> '"',
	150	=> '-',
	151	=> '--',
	153	=> '(TM)',
	154	=> 's',
	156	=> 'oe',
	158	=> 'z',
	159	=> 'Y',
	166	=> '|',
	169	=> '(C)',
	174	=> '(R)',
	177	=> '+/-',
	188	=> '1/4',
	189	=> '1/2',
	190	=> '3/4',
	192	=> 'A',
	193	=> 'A',
	194	=> 'A',
	195	=> 'A',
	196	=> 'A',
	197	=> 'A',
	198	=> 'AE',
	199	=> 'C',
	200	=> 'E',
	201	=> 'E',
	202	=> 'E',
	203	=> 'E',
	204	=> 'I',
	205	=> 'I',
	206	=> 'I',
	207	=> 'I',
	208	=> 'D',
	209	=> 'N',
	210	=> 'O',
	211	=> 'O',
	212	=> 'O',
	213	=> 'O',
	214	=> 'O',
	215	=> 'x',
	216	=> 'O',
	217	=> 'U',
	218	=> 'U',
	219	=> 'U',
	220	=> 'U',
	221	=> 'Y',
	223	=> 'B',
	224	=> 'a',
	225	=> 'a',
	226	=> 'a',
	227	=> 'a',
	228	=> 'a',
	229	=> 'a',
	230	=> 'ae',
	231	=> 'c',
	232	=> 'e',
	233	=> 'e',
	234	=> 'e',
	235	=> 'e',
	236	=> 'i',
	237	=> 'i',
	238	=> 'i',
	239	=> 'i',
	240	=> 'd',
	241	=> 'n',
	242	=> 'o',
	243	=> 'o',
	244	=> 'o',
	245	=> 'o',
	246	=> 'o',
	247	=> '/',
	248	=> 'o',
	249	=> 'u',
	250	=> 'u',
	251	=> 'u',
	252	=> 'u',
	253	=> 'y',
	255	=> 'y',
);


my %action_data = ( );

my %actions = (
	newline_to_local => sub {
			${$_[0]} =~ s/(?:\015?\012|\015)/\n/g;		},
	trailing_whitespace => sub {
			${$_[0]} =~ s/[\t ]+\n/\n/g;			},
	encode_html_amp => sub {
			${$_[0]} =~ s/&/&amp;/g;			},
	encode_html_amp_ifnotent => sub {
			${$_[0]} =~ s/&(?!#?[a-zA-Z0-9]+;)/&amp;/g;	},
	encode_html_ltgt => sub {
			${$_[0]} =~ s/</&lt;/g;
			${$_[0]} =~ s/>/&gt;/g;				},
	encode_html_ltgt_stray => sub {
			1 while ${$_[0]} =~ s{
				( (?: ^ | > ) [^<]* )
				>
			}{$1&gt;}gx;
			1 while ${$_[0]} =~ s{
				<
				( [^>]* (?: < | $ ) )
				>
			}{&lt;$1}gx;					},
	encode_html_quote => sub {
			${$_[0]} =~ s/"/&#34;/g;			},
	breakHtml_ifwhitefix => sub {
			${$_[0]} = breakHtml(${$_[0]})
				unless $action_data{no_white_fix};	},
	processCustomTags => sub {
			${$_[0]} = processCustomTags(${$_[0]});		},
	approveTags => sub {
			${$_[0]} =~ s/<(.*?)>/approveTag($1)/sge;	},
	approveCharrefs => sub {
			${$_[0]} =~ s{
				&(\#?[a-zA-Z0-9]+);?
			}{approveCharref($1)}gex;			},
	space_between_tags => sub {
			${$_[0]} =~ s/></> </g;				},
	whitespace_tagify => sub {
			${$_[0]} =~ s/\n/<BR>/gi;  # pp breaks
			${$_[0]} =~ s/(?:<BR>\s*){2,}<BR>/<BR><BR>/gi;
			# Preserve leading indents / spaces
			# can mess up internal tabs, oh well
			${$_[0]} =~ s/\t/    /g;			},
	whitespace_and_tt => sub {
			${$_[0]} =~ s{((?:  )+)(?: (\S))?} {
				("&nbsp; " x (length($1)/2)) .
				(defined($2) ? "&nbsp;$2" : "")
			}eg;
			${$_[0]} = "<TT>${$_[0]}</TT>";			},
	newline_indent => sub {
			${$_[0]} =~ s{<BR>\n?( +)} {
				"<BR>\n" . ("&nbsp; " x length($1))
			}ieg;						},
	remove_tags => sub {
			${$_[0]} =~ s/<.*?>//gs;			},
	remove_ltgt => sub {
			${$_[0]} =~ s/<//g;
			${$_[0]} =~ s/>//g;				},
	remove_trailing_lts => sub {
			${$_[0]} =~ s/<(?!.*?>)//gs;			},
	remove_newlines => sub {
			${$_[0]} =~ s/\n+//g;				},
	debugprint => sub {
			print STDERR "stripByMode debug ($_[1]) '${$_[0]}'\n";	},

	encode_high_bits => sub {
			# !! assume Latin-1 !!
			if (getCurrentStatic('draconian_charset')) {
				my $convert = getCurrentStatic('draconian_charset_convert');
				# anything not CRLF tab space or ! to ~ in Latin-1
				# is converted to entities, where approveCharrefs or
				# encode_html_amp takes care of them later
				${$_[0]} =~ s/([^\n\r\t !-~])/($convert && $latin1_to_ascii{ord($1)}) || sprintf("&#%u;", ord($1))/ge;
			}						},
);

my %mode_actions = (
	ANCHOR, [qw(
			newline_to_local
			remove_newlines			)],
	NOTAGS, [qw(
			newline_to_local
			encode_high_bits
			remove_tags
			remove_ltgt
			encode_html_amp_ifnotent
			approveCharrefs			)],
	ATTRIBUTE, [qw(
			newline_to_local
			encode_high_bits
			encode_html_amp
			encode_html_ltgt
			encode_html_quote		)],
	LITERAL, [qw(
			newline_to_local
			encode_html_amp
			encode_html_ltgt
			breakHtml_ifwhitefix
			processCustomTags
			remove_trailing_lts
			approveTags
			space_between_tags
			encode_html_ltgt_stray		)],
	NOHTML, [qw(
			newline_to_local
			trailing_whitespace
			encode_high_bits
			remove_tags
			remove_ltgt
			encode_html_amp			)],
	PLAINTEXT, [qw(
			newline_to_local
			trailing_whitespace
			encode_high_bits
			processCustomTags
			remove_trailing_lts
			approveTags
			space_between_tags
			encode_html_ltgt_stray
			encode_html_amp_ifnotent
			approveCharrefs
			breakHtml_ifwhitefix
			whitespace_tagify
			newline_indent			)],
	HTML, [qw(
			newline_to_local
			trailing_whitespace
			encode_high_bits
			processCustomTags
			remove_trailing_lts
			approveTags
			space_between_tags
			encode_html_ltgt_stray
			encode_html_amp_ifnotent
			approveCharrefs
			breakHtml_ifwhitefix		)],
	CODE, [qw(
			newline_to_local
			trailing_whitespace
			encode_high_bits
			encode_html_amp
			encode_html_ltgt
			whitespace_tagify
			whitespace_and_tt
			breakHtml_ifwhitefix		)],
	EXTRANS, [qw(
			newline_to_local
			trailing_whitespace
			encode_high_bits
			encode_html_amp
			encode_html_ltgt
			breakHtml_ifwhitefix
			whitespace_tagify
			newline_indent			)],
);

sub stripByMode {
	my($str, $fmode, $no_white_fix) = @_;
	$fmode ||= NOHTML;
	$no_white_fix = 1 if !defined($no_white_fix) && $fmode == LITERAL;
	$action_data{no_white_fix} = $no_white_fix || 0;

	my @actions = @{$mode_actions{$fmode}};
	for my $action (@actions) {
		$actions{$action}->(\$str, $fmode);
	}
	return $str;
}

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
	return "" if !$mode || $mode < 1 || $mode > 4;	# user-supplied modes are 1-4
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

=head2 strip_paramattr(STRING [, NO_WHITESPACE_FIX])

=head2 strip_urlattr(STRING [, NO_WHITESPACE_FIX])

Wrappers for strip_attribute(fixparam($param), $no_whitespace_fix) and
strip_attribute(fudgeurl($url), $no_whitespace_fix).

=cut

sub strip_paramattr	{ strip_attribute(fixparam($_[0]), $_[1]) }
sub strip_urlattr	{ strip_attribute(fudgeurl($_[0]), $_[1]) }


#========================================================================

=head2 stripBadHtml(STRING)

Private function.  Strips out "bad" HTML by removing unbalanced HTML
tags and sending balanced tags through C<approveTag>.  The "unbalanced"
checker is primitive; no "E<lt>" or "E<gt>" tags will are allowed inside
tag attributes (such as E<lt>A NAME="E<gt>"E<gt>), that breaks the tag.
Whitespace is inserted between adjacent tags, so "E<lt>BRE<gt>E<lt>BRE<gt>"
becomes "E<lt>BRE<gt> E<lt>BRE<gt>".  And character references are routed
through C<approveCharref>.

=over 4

=item Parameters

=over 4

=item STRING

String to be processed.

=back

=item Return value

Processed string.

=item Dependencies

C<approveTag> function, C<approveCharref> function.

=back

=cut

sub stripBadHtml {
	my($str) = @_;
#print STDERR "stripBadHtml 1 '$str'\n";

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

#print STDERR "stripBadHtml 2 '$str'\n";
	my $ent = qr/#?[a-zA-Z0-9]+/;
	$str =~ s/&(?!$ent;)/&amp;/g;
	$str =~ s/&($ent);?/approveCharref($1)/ge;
#print STDERR "stripBadHtml 3 '$str'\n";

	return $str;
}

#========================================================================

=head2 processCustomTags(STRING)

Private function.  It does processing of special custom tags
(so far, just ECODE).

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
		my $ecode   = 'ecode';
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
contents of HTML tags.  Called from C<stripByMode> functions -- if
there are any HTML tags in the text, C<stripBadHtml> will have been
called first.  Handles spaces before dot-words so as to best work around a
Microsoft bug.  This code largely contributed by Joe Groff <joe at pknet
dot com>.

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
	my $constants = getCurrentStatic();
	$mwl = $mwl || $constants->{breakhtml_wordlength} || 50;

	# Only do the <NOBR> and <WBR> bug workaround if wanted.
	my $workaround_start = $constants->{comment_startword_workaround}
		? "<nobr>" : "";
	my $workaround_end = $constants->{comment_startword_workaround}
		? "<wbr></nobr> " : " ";

	# These are tags that "break" a word;
	# a<P>b</P> breaks words, y<B>z</B> does not
	my $approvedtags_break = $constants->{'approvedtags_break'}
		|| [qw(HR BR LI P OL UL BLOCKQUOTE DIV)];
	my $break_tag = join '|', @$approvedtags_break;
	$break_tag = qr{(?:$break_tag)}i;

	# This is the regex that finds a char that, at the start of
	# a word, will trigger Microsoft's bug.  It's already been
	# set up for us, it just needs a shorter name.
	my $nswcr = $constants->{comment_nonstartwordchars_regex};

	# And we also need a regex that will find an HTML entity or
	# character references, excluding ones that would break words:
	# a non-breaking entity.  For now, let's assume *all* entities
	# are non-breaking (except an encoded space which would be
	# kinda dumb).
	my $nbe = qr{ (?:
		&
		(?! \# (?:32|x20) )
		(\#?[a-zA-Z0-9]+)
		;
	) }xi;

	# Mark off breaking tags, as we don't want them counted as
	# part of long words
	$text =~ s{
		(</?$break_tag>)
	}{\x00$1\x00}gsx;

	# Temporarily hide whitespace inside tags so that the regex below
	# won't accidentally catch attributes, e.g. the HREF= of an A tag.
	# (Which I don't think it can do anyway, based on the way the
	# following regex gobbles <> and the fact that tags should already
	# be balanced by this point...but this can't hurt - Jamie)
	1 while $text =~ s{
		(<[^>\s]*)	# Seek in a tab up to its
		\s+		# first whitespace
	}{$1\x00}gsx;		# and replace the space with NUL

	# Put the <wbr> in front of attempts to exploit MSIE's
	# half-braindead adherance to Unicode char breaking.
	$text =~ s{$nswcr}{<nobr> <wbr></nobr>$2$3}gs
		if $constants->{comment_startword_workaround};

	# Break up overlong words, treating entities/character references
	# as single characters and ignoring HTML tags.
	$text =~ s{(
		(?:^|\G|\s)		# Must start at a word bound
		(?:
			(?>(?:<[^>]+>)*)	# Eat up HTML tags
			(?:			# followed by either
				$nbe		# an entity (char. ref.)
			|	\S		# or an ordinary char
			)
		){$mwl}			# $mwl non-HTML-tag chars in a row
	)}{
		substr($1, 0, -1)
		. $workaround_start
		. substr($1, -1)
		. $workaround_end
	}gsex;

	# Just to be tidy, if we appended that word break at the very end
	# of the text, eliminate it.
	$text =~ s{<nobr> <wbr></nobr>\s*$}{}
		if $constants->{comment_startword_workaround};

	# Fix breaking tags
	$text =~ s{
		\x00
		(</?$break_tag>)
		\x00
	}{$1}gsx;
	
	# Change other NULs back to whitespace.
	$text =~ s{\x00}{ }g;

	return $text;
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
	my($wholetag) = @_;

	$wholetag =~ s/^\s*(.*?)\s*$/$1/; # trim leading and trailing spaces
	$wholetag =~ s/\bstyle\s*=(.*)$//is; # go away please

	# Take care of URL:foo and other HREFs
	# Using /s means that the entire variable is treated as a single line
	# which means \n will not fool it into stopping processing.  fudgeurl()
	# knows how to handle multi-line URLs (it removes whitespace).
	if ($wholetag =~ /^URL:(.+)$/is) {
		my $url = fudgeurl($1);
		return qq!<A HREF="$url">$url</A>!;
	}

	# Build the hash of approved tags.
	my $approvedtags = getCurrentStatic("approvedtags");
	my %approved =
		map  { (uc($_), 1)   }
		grep { $_ ne 'ECODE' }
		@$approvedtags;

	# We can do some checks at this point.  $t is the tag minus its
	# properties, e.g. for "<A HREF=foo>", $t will be "A".
	my($taglead, $slash, $t) = $wholetag =~ m{^(\s*(/?)\s*(\w+))};
	my $t_uc = uc $t;
	if (!$approved{$t_uc}) {
		return "";
	}

	# Some tags allow attributes, or require attributes to be useful.
	# These tags go through a secondary, fancier approval process.
	# Note that approvedtags overrides what is/isn't allowed here.
	# (At some point we should put this hash into a var, maybe
	# like "a:href_RU img:src_RU,alt,width,height,longdesc_U"?)
	my %attr = (
		A =>	{ HREF =>	{ ord => 1, req => 1, url => 1 } },
		IMG =>	{ SRC =>	{ ord => 1, req => 1, url => 1 },
			  ALT =>	{ ord => 2                     },
			  WIDTH =>	{ ord => 3                     },
			  HEIGHT =>	{ ord => 4                     },
			  LONGDESC =>	{ ord => 5,           url => 1 }, },
	);
	if ($slash) {

		# Close-tags ("</A>") never get attributes.
		$wholetag = "/$t";

	} elsif ($attr{$t_uc}) {

		# This is a tag with attributes, verify them.

		my %allowed = %{$attr{$t_uc}};
		my %required =
			map  { $_, $allowed{$_}  }
			grep { $allowed{$_}{req} }
			keys   %allowed;

		my $tree = HTML::TreeBuilder->new_from_content("<$wholetag>");
		my($elem) = $tree->look_down(_tag => 'body')->content_list;
		# look_down() can return a string for some kinds of bogus data
		return "" unless $elem && ref($elem) eq 'HTML::Element';
		my @attr_order =
			sort { $allowed{uc $a}{ord} <=> $allowed{uc $b}{ord} }
			grep { !/^_/ && exists $allowed{uc $_} }
			$elem->all_attr_names;
		my %attr_data  = map { ($_, $elem->attr($_)) } @attr_order;
		my $num_req_found = 0;
		$wholetag = "$t_uc";
		for my $a (@attr_order) {
			my $a_uc = uc $a;
			next unless $allowed{$a_uc};
			my $data = $attr_data{$a};
			$data = fudgeurl($data) if $allowed{$a_uc}{url};
			next unless $data;
			$wholetag .= qq{ $a_uc="$data"};
			++$num_req_found if $required{$a_uc};
		}
		# If the required attributes were not all present, the whole
		# tag is invalid.
		return "" unless $num_req_found == scalar(keys %required);

	} else {

		# No attributes allowed.
		$wholetag = $t;

	}

	# If we made it here, the tag is valid.
	return "<$wholetag>";
}

#========================================================================

=head2 approveCharref(CHARREF)

Private function.  Checks to see if a character reference (minus the
leading & and trailing ;) is OK.  If so, returns the whole character
reference (including & and ;), and if not, returns the empty string.
See <http://www.w3.org/TR/html4/charset.html#h-5.3> for definitions and
explanations of character references.

=over 4

=item Parameters

=over 4

=item CHARREF

HTML character reference to check.

=back

=item Return value

Character reference after processing.

=item Dependencies

None.

=back

=cut

sub approveCharref {
	my($charref) = @_;
	my $constants = getCurrentStatic();

	my $ok = 1; # Everything not forbidden is permitted.

	if ($constants->{draconian_charrefs}) {
		# Don't mess around trying to guess what to forbid.
		# Everything is forbidden except a very few known to
		# be good.
		$ok = 0 unless $charref =~ /^(amp|lt|gt)$/;
	}

	# At the moment, unless the "draconian" rule is set, only
	# entities that change the direction of text are forbidden.
	# For more information, see
	# <http://www.w3.org/TR/html4/struct/dirlang.html#bidirection>
	# and <http://www.htmlhelp.com/reference/html40/special/bdo.html>.
	my %bad_numeric = map { $_, 1 } @{$constants->{charrefs_bad_numeric}};
	my %bad_entity  = map { $_, 1 } @{$constants->{charrefs_bad_entity}};

	if ($ok == 1 && $charref =~ /^#/) {
		# Probably a numeric character reference.
		my $decimal = 0;
		if ($charref =~ /^#x([0-9a-f]+)$/i) {
			# Hexadecimal encoding.
			$decimal = hex($1); # always returns a positive integer
		} elsif ($charref =~ /^#(\d+)$/) {
			# Decimal encoding.
			$decimal = $1;
		} else {
			# Unknown, assume flawed.
			$ok = 0;
		}
		$ok = 0 if $decimal <= 0 || $decimal > 65534; # sanity check
		$ok = 0 if $bad_numeric{$decimal};
	} elsif ($ok == 1 && $charref =~ /^([a-z0-9]+)$/i) {
		# Character entity.
		my $entity = lc $1;
		$ok = 0 if $bad_entity{$entity};
	} elsif ($ok == 1) {
		# Unknown character reference type, assume flawed.
		$ok = 0;
	}

	if ($ok) {
		return "&$charref;";
	} else {
		return "";
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

	if (!$scheme_regex) {
		$scheme_regex = join("|", map { lc } @{$constants->{approved_url_schemes}});
		$scheme_regex = qr{^(?:$scheme_regex)$};
	}

	my $uri = new URI $url;
	my $scheme = undef;
	$scheme = $uri->scheme if $uri && $uri->can("scheme");

	# modify scheme:/ to scheme:// for $schemes defined below
	# need to recreate $uri after doing so to make userinfo
	# clearing work for something like http:/foo.com...@bar.com
	my $schemes_to_mod = { http => 1, https => 1, ftp => 1 };
	if ($scheme && $schemes_to_mod->{$scheme}) {
		$url = $uri->canonical->as_string;
		$url =~ s|^$scheme:/([^/])|$scheme://$1|;
		$uri = new URI $url;
	}

	if ($uri && !$scheme && $uri->can("authority") && $uri->authority) {
		# The URI has an authority but no scheme, e.g. "//sitename.com/".
		# URI.pm doesn't always handle this well.  E.g. host() returns
		# undef.  So give it a scheme.
		# XXX Rethink this -- it could probably be put lower down, in
		# the "if" that handles stripping the userinfo.  We don't
		# really need to add the scheme for most URLs. - Jamie
		$uri->scheme("http");
	}
	if (!$uri) {

		# Nothing we can do with it; manipulate the probably-bogus
		# $url at the end of this function and return it.

	} elsif ($scheme && $scheme !~ $scheme_regex) {

		$url =~ s/^$scheme://i;
		$url =~ tr/A-Za-z0-9-//cd; # allow only a few chars, for security
		$url = "$scheme:$url";

	} elsif ($uri) {

		# Strip the authority, if any.
		# This prevents annoying browser-display-exploits
		# like "http://cnn.com%20%20%20...%20@baddomain.com".
		# In future we may set up a package global or a field like
		# getCurrentUser()->{state}{fixurlauth} that will allow
		# this behavior to be turned off.

		if ($uri->can('userinfo') && $uri->userinfo) {
			$uri->userinfo(undef);
		}
		if ($uri->can('host') && $uri->host) {
			# If this scheme has an authority (which means a
			# username and/or password and/or host and/or port)
			# then make sure the host and port are legit, and
			# zap the port if it's the default port.
			my $host = $uri->host;
			$host =~ tr/A-Za-z0-9.-//cd; # per RFC 1035
			$uri->host($host);
			if ($uri->can('authority') && $uri->authority) {
				# We don't allow anything in the authority except
				# the host and optionally a port.  This shouldn't
				# matter since the userinfo portion was zapped
				# above.  But this is a bit of double security to
				# ensure nothing nasty in the authority.
				my $authority = $uri->host;
				if ($uri->can('host_port')
					&& $uri->port != $uri->default_port) {
					$authority = $uri->host_port;
				}
				$uri->authority($authority);
			}
		}
		$url = $uri->canonical->as_string;
	}

	# These entities can crash browsers and don't belong in URLs.
	$url =~ s/&#(.+?);//g;
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
		$constants->{lonetags} = [qw(P LI BR IMG)];
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

The HTML tagged with domains.

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

	# The default is 2 ("always show");  note this default is enforced in
	# prepareUser().  Note also that if I were being smart I'd use
	# constants for 0, 1 and 2...
	my $udt = $user->{domaintags};

	my $want_tags = 1;			# assume we'll be displaying the [domain.tags]
	$want_tags = 0 if			# but, don't display them if...
		$udt == 0			# the user has said they never want the tags
		|| (				# or
			$udt == 1		# the user leaves it up to us
			&& $recommended		# and we think the poster has earned tagless posting
		);

	if ($want_tags && !$notags) {
		$html =~ s{</A ([^>]+)>}{</A> [$1]}gi;
	} else {
		$html =~ s{</A[^>]+>}{</A>}gi;
	}

	return $html;
}


#========================================================================

=head2 parseSlashizedLinks(HTML)

To be called before sending the HTML to the user for display.  Takes
HTML with slashized links (see slashizedLinks()) and converts them to
the appropriate HTML.

=over 4

=item Parameters

=over 4

=item HTML

The HTML with slashized links.

=back

=item Return value

The parsed HTML.

=back

=cut

sub parseSlashizedLinks {
	my($html, $options) = @_;
	$html =~ s{
		<A[ ]HREF="__SLASHLINK__"
		([^>]+)
		>
	}{
		_slashlink_to_link($1, $options)
	}gxe;
	return $html;
}

# This function mirrors the behavior of _link_to_slashlink.

sub _slashlink_to_link {
	my($sl, $options) = @_;
	my $ssi = getCurrentForm('ssi') || 0;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $root = $constants->{rootdir};
	my %attr = $sl =~ / (\w+)="([^"]+)"/g;
	# We should probably de-strip-attribute the values of %attr
	# here, but it really doesn't matter.

	# Load up special values and delete them from the attribute list.
	my $sn = delete $attr{sn} || "";
	my $sect = delete $attr{sect} || "";
	my $section = $sect ? $reader->getSection($sect) : {};
	my $sect_root = $section->{rootdir} || $root;
	if ($options && $options->{absolute}) {
		$sect_root = URI->new_abs($sect_root, $options->{absolute})
			->as_string;
	}
	my $frag = delete $attr{frag} || "";
	# Generate the return value.
	my $retval = q{<A HREF="};
	if ($sn eq 'comments') {
		$retval .= qq{$sect_root/comments.pl?};
		$retval .= join("&",
			map { qq{$_=$attr{$_}} }
			sort keys %attr);
		$retval .= qq{#$frag} if $frag;
	} elsif ($sn eq 'article') {
		# Different behavior here, depending on whether we are
		# outputting for a dynamic page, or a static one.
		# This is the main reason for doing slashlinks at all!
		if ($ssi) {
			$retval .= qq{$sect_root/};
			$retval .= qq{$sect/$attr{sid}.shtml};
			$retval .= qq{?tid=$attr{tid}} if $attr{tid};
			$retval .= qq{#$frag} if $frag;
		} else {
			$retval .= qq{$sect_root/article.pl?};
			$retval .= join("&",
				map { qq{$_=$attr{$_}} }
				sort keys %attr);
			$retval .= qq{#$frag} if $frag;
		}
	}
	$retval .= q{">};
	return $retval;
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
		$3	? _url_to_domain_tag($1, $2, $3)
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
	my($href, $link, $body) = @_;
	my $absolutedir = getCurrentStatic('absolutedir');
	my $uri = URI->new_abs($link, $absolutedir);
	my $uri_str = $uri->as_string;
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
		# listing the scheme.  Or, if this URL is malformed
		# in a particular way ("scheme:host/path", missing
		# the "//"), treat it the way that many browsers will
		# (rightly or wrongly) treat it.
		if ($uri_str =~ m{^$scheme:([\w-]+)}) {
			$uri_str =~ s{^$scheme:}{$scheme://};
			return _url_to_domain_tag($href, $uri_str, $body);
		} else {
			$info = lc $scheme;
		}
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
	# Add a title tag to make this all friendly for those with vision
	# and similar issues -Brian
	$href =~ s/>/ TITLE="$info">/ if $info ne '?';
	return "$href$body</a $info>";
}

#========================================================================

=head2 slashizeLinks(HTML)

Munges HTML E<lt>aE<gt> tags that point to specific types of links on
this Slash site (articles.pl, comments.pl, and articles .shtml pages)
into a special type of E<lt>aE<gt> tag.  Note that this is not proper
HTML, and that it will be converted back to proper HTML when the
story is displayed.

=over 4

=item Parameters

=over 4

=item HTML

The HTML to slashize links in.

=back

=item Return value

The converted HTML.

=back

=cut

sub slashizeLinks {
	my($html) = @_;
	$html =~ s{
		(<a[^>]+href\s*=\s*"?)
		([^"<>]+)
		([^>]*>)
	}{
		_link_to_slashlink($1, $2, $3)
	}gxie;
	return $html;
}

# URLs that match a pattern are converted into our special format.
# Those that don't are passed through.  This function mirrors the
# behavior of _slashlink_to_link.
{
# This closure is here because generating the %urla table is
# somewhat resource-intensive.
my %urla;
sub _link_to_slashlink {
	my($pre, $url, $post) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $virtual_user = getCurrentVirtualUser();
	my $retval = "$pre$url$post";
	my $abs = $constants->{absolutedir};
#print STDERR "_link_to_slashlink begin '$url'\n";

	if (!defined($urla{$virtual_user})) {
		# URLs may show up in any section, which means when absolutized
		# their host may be either the main one or a sectional one.
		# We have to allow for any of those possibilities.
		my $sections = $reader->getSections();
		my @sect_urls = grep { $_ }
			map { $sections->{$_}{rootdir} }
			sort keys %$sections;
		my %all_urls = ( );
		for my $url ($abs, @sect_urls) {
			my $new_url = URI->new($url);
			# Remove the scheme to make it relative (schemeless).
			$new_url->scheme(undef);
			my $new_url_q = quotemeta($new_url->as_string);
			$all_urls{"(?:https?:)?$new_url"} = 1;
		}
		my $any_host = "(?:"
			. join("|", sort keys %all_urls)
			. ")";
#print STDERR "link_to_slashlink abs '$abs' any_host '$any_host'\n";
		# All possible URLs' arguments, soon to be attributes
		# in the new tag (thus "urla").	Values are the name
		# of the script ("sn") and expressions that can pull
		# those arguments out of a text URL.  (We could use
		# URI::query_form to pull out the .pl arguments, but that
		# wouldn't help with the .shtml regex so we might as well
		# do it this way.)  If we ever want to extend slash-linking
		# to cover other tags, here's the place to start.
		%{$urla{$virtual_user}} = (
			qr{^$any_host/article\.pl\?} =>
				{ _sn => 'article',
				  sid => qr{\bsid=([\w/]+)} },
			qr{^$any_host/\w+/\d+/\d+/\d+/\d+\.shtml\b} =>
				{ _sn => 'article',
				  sid => qr{^$any_host/\w+/(\d+/\d+/\d+/\d+)\.shtml\b} },
			qr{^$any_host/comments\.pl\?} =>
				{ _sn => 'comments',
				  sid => qr{\bsid=(\d+)},
				  cid => qr{\bcid=(\d+)} },
		);
#use Data::Dumper; print STDERR Dumper(\%urla);
	}
	# Get a reference to the URL argument hash for this
	# virtual user, thus "urlavu".
	my $urlavu = $urla{$virtual_user};

	my $canon_url = URI->new_abs($url, $abs)->canonical;
	my $frag = $canon_url->fragment() || "";

	# %attr is the data structure storing the attributes of the <a>
	# tag that we will use.
	my %attr = ( );
	URLA: for my $regex (sort keys %$urlavu) {
		# This loop only applies to the regex that matches this
		# URL (if any).
		next unless $canon_url =~ $regex;

		# The non-underscore keys are regexes that we need to
		# pull from the URL.
		for my $arg (sort grep !/^_/, keys %{$urlavu->{$regex}}) {
			($attr{$arg}) = $canon_url =~ $urlavu->{$regex}{$arg};
			delete $attr{$arg} if !$attr{$arg};
		} 
		# The _sn key is special, it gets copied into sn.
		$attr{sn} = $urlavu->{$regex}{_sn}; 
		# Section and topic attributes get thrown in too.
		if ($attr{sn} eq 'comments') {
			# sid is actually a discussion id!
			$attr{sect} = $reader->getDiscussion(
				$attr{sid}, 'section');
			$attr{tid} = $reader->getDiscussion(
				$attr{sid}, 'topic');
		} else {
			# sid is a story id
			$attr{sect} = $reader->getStory( 
				$attr{sid}, 'section', 1);
			$attr{tid} = $reader->getStory(
				$attr{sid}, 'tid', 1);
		}
		$attr{frag} = $frag if $frag;
		# We're done once we match any regex to the link's URL.
		last URLA;
	}

	# If we have something good in %attr, we can go ahead and
	# use our custom tag.  Concatenate it together.
	if ($attr{sn}) {
		$retval = q{<A HREF="__SLASHLINK__" }
			. join(" ",
				map { qq{$_="} . strip_attribute($attr{$_}) . qq{"} }
				sort keys %attr)
			. q{>};
	}

#print STDERR "_link_to_slashlink end '$url'\n";
	# Return either the new $retval we just made, or just send the
	# original text back.
	return $retval;
}
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

=head2 vislenify (ID_OR_HASHREF [, LEN])

Given an MD5 string such as an IPID or SubnetID, converts it to
the length as determined by the id_md5_vislength var.  If passed
a hashref, looks for any and all of the keys ipid, subnetid, and
md5id, and if found, adds the same keys with _vis appended and
shortened values.  If passed an arrayref, it must be an arrayref
of hashrefs, and does the above for each hashref.

=over 4

=item Parameters

=over 4

=item ID_OR_HASHREF

Either a 32-char MD5 ID string, or a hashref as described above.

=item LEN

Usually not necessary;  if present, overrides the var id_md5_vislength.

=back

=item Return value

If scalar ID passed in, returns new value.  If hashref passed in,
it is modified in place.

=back

=cut

sub vislenify {
	my($id_or_ref, $len) = @_;
	$len ||= getCurrentStatic('id_md5_vislength') || 32;
	if (ref $id_or_ref) {
		if (ref($id_or_ref) eq 'HASH') {
			my $hr = $id_or_ref;
			for my $key (qw( ipid ipid2 subnetid md5id )) {
				if ($hr->{$key}) {
					$hr->{"${key}_vis"} = substr($hr->{$key}, 0, $len);
				}
			}
		} elsif (ref($id_or_ref) eq 'ARRAY') {
			for my $item_hr (@$id_or_ref) {
				for my $key (qw( ipid ipid2 subnetid md5id )) {
					if ($item_hr->{$key}) {
						$item_hr->{"${key}_vis"} = substr($item_hr->{$key}, 0, $len);
					}
				}
			}
		}
	} else {
		return substr($id_or_ref, 0, $len);
	}
}

#========================================================================

=head2 ellipsify (TEXT [, LEN])

Given any text, makes sure it's not too long by shrinking its
length to at most LEN, putting an ellipse in the middle.  If the
LEN is too short to allow an ellipse in the middle, it just does
an ellipse at the end, or in the worst case, a substr.

=over 4

=item Parameters

=over 4

=item TEXT

Any text.

=item LEN

Usually not necessary;  if present, overrides the var
comments_max_email_len (email is what this function was designed to
work on).

=back

=item Return value

New value.

=back

=cut

sub ellipsify {
	my($text, $len) = @_;
	$len ||= getCurrentStatic('comments_max_email_len') || 40;
	if (length($text) > $len) {
		my $len2 = int(($len-7)/2);
		if ($len2 >= 4) {
			$text = substr($text, 0, $len2)
				. " ... "
				. substr($text, -$len2);
		} elsif ($len >= 8) {
			$text = substr($text, 0, $len-4)
				. " ...";
		} else {
			$text = substr($text, 0, $len);
		}
	}
	return $text;
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

	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $armor = $reader->getRandomSpamArmor();

	# Execute the retrieved code in a Safe compartment. We do this
	# in an anonymous block to enable local scoping for some variables.
	{
		local $_ = $realemail;
		$_ ||= $reader->getUser($uid, 'realemail');

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
	$body = ${$body} if ref $body eq 'SCALAR';
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

########################################################
# A very careful extraction of all the words from HTML text.
# URLs count as words.  (A different algorithm than countWords
# because countWords just has to be fast; this has to be
# precise.  Also, this counts occurrences of each word -- which
# is different than counting the overall number of words.)
sub findWords {
	my($args_hr) = @_;
	my $constants = getCurrentStatic();

	# Return a hashref;  keys are the words, values are hashrefs
	# with the number of times they appear and so on.
	my $wordcount = $args_hr->{output_hr} || { };

	for my $key (keys %$args_hr) {

		# The default weight for each chunk of text is 1.
		my $weight_factor = $args_hr->{$key}{weight} || 1;

		my $text = $args_hr->{$key}{text};

		# Pull out linked URLs from $text and treat them specially.
		# We only recognize the two most common types of link.
		# Actually, we could use HTML::LinkExtor here, which might
		# be more robust...
		my @urls_ahref = $text =~ m{
			<a[^>]+href\s*=\s*"?
			([^"<>]+)
		}gxi;
		my @urls_imgsrc = $text =~ m{
			<img[^>]+src\s*=\s*"?
			([^"<>]+)
		}gxi;
		foreach my $url (@urls_ahref, @urls_imgsrc) {
			my $uri = URI->new_abs($url, $constants->{absolutedir})
				->canonical;
			$url = $uri->as_string;
			# Tiny URLs don't count.
			next unless length($url) > 8;
			# All URLs get a high weight so they are almost
			# guaranteed to get into the list.
			$wordcount->{$url}{weight} += $weight_factor * 10;
			$wordcount->{$url}{count}++;
			$wordcount->{$url}{is_url} = 1;
			$wordcount->{$url}{is_url_with_path} = 1 if length($uri->path) > 2;
		}

		# Now remove the text's HTML tags and find and count the
		# words remaining in the text.  For our purposes, words
		# can include character references (entities) and the '
		# and - characters as well as \w.  This regex is a bit
		# messy.  I've tried to reduce backtracking as much as
		# possible but it's still a concern.
		$text = strip_notags($text);
		my $entity = qr{(?:&(?:(?:#x[0-9a-f]+|\d+)|[a-z0-9]+);)};
		my @words = $text =~ m{
			(
				# Start with a non-apostrophe, non-dash char.
				(?: $entity | \w )
				# Followed by, optionally, any valid char.
				[\w'-]?
				# Followed by zero or more sequence of entities,
				# character references, or normal chars.  The
				# ' and - must alternate with the other types,
				# so '' and -- break words.
				(?:
					(?: $entity | \w ) ['-]?
				)*
				# And end with a non-apostrophe, non-dash char.
				(?: $entity | \w )
			)
		}gxi;
		for my $word (@words) {
			my $cap = $word =~ /^[A-Z]/ ? 1 : 0;
			# Ignore all uncapitalized words less than 4 chars.
			next if length($word) < 4 && !$cap;
			# Ignore *all* words less than 3 chars.
			next if length($word) < 3;
			my $ww = $weight_factor * ($cap ? 1.3 : 1);
			$wordcount->{lc $word}{weight} += $ww;
		}
		my %uniquewords = map { ( lc($_), 1 ) } @words;
		for my $word (keys %uniquewords) {
			$wordcount->{$word}{count}++;
		}
	}

	return $wordcount;
}

#========================================================================

=head2 commify(NUMBER)

Returns the number with commas added, so 1234567890 becomes
1,234,567,890.

=over 4

=item Parameters

=over 4

=item NUMBER

A number.

=back

=item Return value

Commified number.

=back

=cut

sub commify {
	my($num) = @_;
	$num =~ s/(^[-+]?\d+?(?=(?>(?:\d{3})+)(?!\d))|\G\d{3}(?=\d))/$1,/g;
	return $num;
}

#========================================================================

=head2 grepn(list, value)

Returns the 1-based position of the first occurance of $value in @$list.

[ That is not actually the case at all! ]

=over 4

=item Parameters

=over 4

=item @$list

A reference to the list in question.

=item $value

The value you wish to search for.

=back

=item Return value

The position in the list of the first occurance of $value or undef if $value
is not in the list. Please note that the returned list is a 1-based value,
not a 0-based value, like perl arrays.

=back

=cut

sub grepn {
	my($list, $value) = @_;

	my $c = 1;
	for (@{$list}) {
		return $c if $_ eq $value;
		$c++;
	}
	return;
}

#========================================================================
# Removed from openbackend
sub sitename2filename {
	my($section) = @_;
	(my $filename = $section || lc getCurrentStatic('sitename')) =~ s/\W+//g;
	return $filename;
}

##################################################################
# counts total visible kids for each parent comment
sub countTotalVisibleKids {
	my($pid, $comments) = @_;
	my $total = 0;

	$total += $comments->{$pid}{visiblekids};

	for my $cid (@{$comments->{$pid}{kids}}) {
		$total += countTotalVisibleKids($cid, $comments);
	}

	$comments->{$pid}{totalvisiblekids} = $total;

	return $total;
}

##################################################################
# Why is this here and not a method in Slash::DB::MySQL? - Jamie 2003/05/13
sub createStoryTopicData {
	my($slashdb, $form) = @_;	
	$form ||= getCurrentForm();

	# Probably should not be changing stid, so set up @tids.
	my @tids = ( );
	if ($form->{_multi}{stid} && ref($form->{_multi}{stid}) eq 'ARRAY') {
		@tids = grep { $_ } @{$form->{_multi}{stid}};
	} elsif ($form->{stid}) {
		push @tids, $form->{stid};
	}
	push @tids, $form->{tid} if $form->{tid};

	# Store the list of original topic ids, before we generate the
	# list of all topic ids including parents.
	my @original = @tids;
	my %original_seen = map { ($_, 1) } @original;

	my $topics = $slashdb->getTopics();
	my %seen = map { ($_, 1) } @tids;
	for my $tid (@tids) {
		my $new_tid = $topics->{$tid}{parent_topic};
		next if !$new_tid || $seen{$new_tid};
		push @tids, $new_tid;
		$seen{$new_tid} = 1;
	}

	# The hashref that we return has an entry for every topic id
	# associated with this story, including all parent topic ids.
	# The value for each topic id is a boolean *string* intended
	# for the database:  "no" if the id is not a parent and is one
	# of the listed topic ids for the story, or "yes" if the id is
	# only in the list because it is the parent id of a listed
	# topic id.
	my %tid_ref;
	for my $tid (@tids) {
		next unless $tid;
		$tid_ref{$tid} = $original_seen{$tid} ? 'no' : 'yes' ;
	}

	return \%tid_ref;
}


1;

__END__


=head1 SEE ALSO

Slash(3), Slash::Utility(3).

=head1 VERSION

$Id$

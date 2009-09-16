# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

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

BEGIN {
#	$HTML::TreeBuilder::DEBUG = 2;
}

use strict;
use Date::Calc qw(Monday_of_Week);
use Date::Format qw(time2str);
use Date::Language;
use Date::Parse qw(str2time);
use Digest::MD5 qw(md5_hex md5_base64);
use Encode qw(encode_utf8 decode_utf8 is_utf8);
use Email::Valid;
use HTML::Entities qw(:DEFAULT %char2entity %entity2char);
use HTML::FormatText;
use HTML::Tagset ();
use HTML::TokeParser;
use HTML::TreeBuilder;
use Lingua::Stem;
use Mail::Address;
use POSIX qw(UINT_MAX);
use Safe;
use Slash::Constants qw(:strip);
use Slash::Utility::Environment;
use Slash::Apache::User::PasswordSalt;
use URI;
use XML::Parser;

use base 'Exporter';

# whitespace regex
our $WS_RE = qr{(?: \s | </? (?:br|p) (?:\ /)?> )*}x;

# without this, HTML::TreeBuilder will skip slash
BEGIN {
	$HTML::Tagset::isKnown{slash} = 1;
	$HTML::Tagset::optionalEndTag{slash} = 1;
	$HTML::Tagset::isBodyElement{slash} = 1;
	$HTML::Tagset::isPhraseMarkup{slash} = 1;
	$HTML::Tagset::linkElements{slash} = ['src', 'href'];
}

our $VERSION = $Slash::Constants::VERSION;
our @EXPORT  = qw(
	addDomainTags
	createStoryTopicData
	slashizeLinks
	approveCharref
	parseDomainTags
	parseSlashizedLinks
	balanceTags
	changePassword
	chopEntity
	cleanRedirectUrl
	cleanRedirectUrlFromForm
	commify
	comparePassword
	countTotalVisibleKids
	countWords
	createLogToken
	createSid
	decode_entities
	determine_html_format
	ellipsify
	emailValid
	email_to_domain
	encryptPassword
	findWords
	fixStory
	fixHref
	fixint
	fixparam
	fixurl
	fudgeurl
	fullhost_to_domain
	formatDate
	getArmoredEmail
	getDayBreakLevels
	getFormatFromDays
	getRandomWordFromDictFile
	getUrlsFromText
	grepn
	html2text
	issueAge
	nickFix
	nick2matchname
	noFollow
	regexSid
	revertQuote
	parseDayBreakLevel
	prepareQuoteReply
	processSub
	quoteFixIntrotext
	root2abs
	roundrand
	set_rootdir
	sitename2filename
	split_bayes
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
	strip_paramattr_nonhttp
	strip_urlattr
	submitDomainAllowed
	timeCalc
	titleCaseConvert
	url2html
	url2abs
	urlizeTitle
	urlFromSite
	xmldecode
	xmlencode
	xmlencode_plain
	validUrl
	vislenify
);


# really, these should not be used externally, but we leave them
# here for reference as to what is in the package
# @EXPORT_OK = qw(
# 	approveTag
# 	breakHtml
# 	processCustomTagsPre
#	processCustomTagsPost
# 	stripByMode
# );

#========================================================================

sub nickFix {
	my($nick) = @_;
	return '' if !$nick;
	my $constants = getCurrentStatic();
	my $nc = $constants->{nick_chars} || join('', 'a' .. 'z');
	my $nr = $constants->{nick_regex} || '^[a-z]$';
	$nick =~ s/\s+/ /g;
	$nick =~ s/[^$nc]+//g;
	$nick = substr($nick, 0, $constants->{nick_maxlen});
	return '' if $nick !~ $nr;
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
# If you change createSid() for your site, change regexSid() too.
# Check getOpAndDatFromStatusAndURI also.
# If your site will have multiple formats of sids, you'll want this
# to continue matching the old formats too.
# NOTE: sid is also used for discussion ID (and maybe stoid too?),
# such as in comments.pl, so that's what the \d{1,8} is for. -- pudge
sub regexSid {
	my $anchor = shift;
	my $sid = '(\d{2}/\d{2}/\d{2}/\d{3,8}|\d{1,8})';
	return $anchor ? qr{^$sid$} : qr{\b$sid\b};
}

#========================================================================

=head2 emailValid(EMAIL)

Returns true if email is valid, false otherwise.

=over 4

=item Parameters

=over 4

=item EMAIL

Email address to check.

=back

=item Return value

True if email is valid, false otherwise.

=back

=cut

sub emailValid {
	my($email) = @_;
	return 0 if !$email;

	my $constants = getCurrentStatic();
	return 0 if $constants->{email_domains_invalid}
		&& ref($constants->{email_domains_invalid})
		&& $email =~ $constants->{email_domains_invalid};

	my $valid = Email::Valid->new;
	return 0 unless $valid->rfc822($email);

	return 1;
}

#========================================================================

=head2 issueAge(ISSUE)

Returns the "age" in days of an issue, given in issue mode form: yyyymmdd.

=over 4

=item Parameters

=over 4

=item ISSUE

Which issue, in yyyymmdd form (matches /^\d{8}$/)

=back

=item Return value

Age in days of that issue (a decimal number).  Takes current user's
timezone into account.  Return value of 0 indicates error.

=back

=cut

sub issueAge {
	my($issue) = @_;
	return 0 unless $issue =~ /^\d{8}$/;
	my $user = getCurrentUser();
	my $issue_unix_timestamp = timeCalc("${issue}0000", '%s', -$user->{off_set});
	my $age = (time - $issue_unix_timestamp) / 86400;
	$age = 0.00001 if $age == 0; # don't return 0 on success
	return $age;
}

#========================================================================

=head2 submitDomainAllowed(DOMAIN)

Returns true if domain is allowed, false otherwise.

=over 4

=item Parameters

=over 4

=item DOMAIN

host domain to check.

=back

=item Return value

True if domain is valid, false otherwise.

=back

=cut

sub submitDomainAllowed {
        my($domain) = @_;

        my $constants = getCurrentStatic();
        return 0 if $constants->{submit_domains_invalid}
                && ref($constants->{submit_domains_invalid})
                && $domain =~ $constants->{submit_domains_invalid};

        return 1;
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
		return getCurrentSkin('absolutedir_secure');
	} else {
		return getCurrentSkin('absolutedir');
	}
}

#========================================================================

=head2 roundrand()

Rounds a real value to an integer value, randomly, with the
two options weighted in linear proportion to the fractional
component.  E.g. 1.3 is 30% likely to round to 1, 70% to 2.
And -4.9 is 90% likely to round to -5, 10% to -4.

=over 4

=item Return value

Input value converted to integer.

=back

=cut

sub roundrand {
	my($real) = @_;
	return 0 if !$real;
	my $i = int($real);
	$i-- if $real < 0;
	my $frac = $real - $i;
	return( (rand(1) >= $frac) ? $i : $i+1 );
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
	my $rooturi    = new URI $rootdir, 'http';
	my $sectionuri = new URI $sectionurl, 'http';

	$sectionuri->scheme($rooturi->scheme || undef);
	return $sectionuri->as_string;
}


#========================================================================

=head2 cleanRedirectUrl(URL)

Clean an untrusted URL for safe redirection.  We do not redirect URLs received
from outside Slash (such as in $form->{returnto}) to arbitrary sites, only
to ourself.

=over 4

=item Parameters

=over 4

=item URL

URL to clean.

=back

=item Return value

Fixed URL.

=back

=cut

sub cleanRedirectUrl {
	my($redirect) = @_;
	my $gSkin = getCurrentSkin();

	if (urlFromSite($redirect)) {
		my $base = root2abs();
		return URI->new_abs($redirect || $gSkin->{rootdir}, $base);
	} else {
		return url2abs($gSkin->{rootdir});
	}
}


sub urlFromSite {
	my($url) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $gSkin = getCurrentSkin();

	# We absolutize the return-to URL to our domain just to
	# be sure nobody can use the site as a redirection service.
	# We decide whether to use the secure homepage or not
	# based on whether the current page is secure.
	my $base = root2abs();
	my $clean = URI->new_abs($url || $gSkin->{rootdir}, $base);

	# obviously, file: URLs are local
	if ($clean->scheme eq 'file') {
		return 1;
	}

	my @site_domain = split m/\./, $gSkin->{basedomain};
	my $site_domain = @site_domain >= 2 ? join '.', @site_domain[-2, -1] : '';
	$site_domain =~ s/:.+$//;	# strip port, if available

	my @host = split m/\./, ($clean->can('host') ? $clean->host : '');
	return 0 if scalar(@host) < 2;
	my $host = join '.', @host[-2, -1];

	return $site_domain eq $host;
}

#========================================================================

sub cleanRedirectUrlFromForm {
	my($redirect_formname) = @_;
	my $constants = getCurrentStatic();
	my $gSkin = getCurrentSkin();
	my $form = getCurrentForm();

	my $formname = $redirect_formname ? "returnto_$redirect_formname" : 'returnto';
	my $formname_confirm = "${formname}_confirm";
	my $returnto = $form->{$formname} || '';
	return undef if !$returnto;

	my $returnto_confirm = $form->{$formname_confirm} || '';

	my $returnto_passwd = $constants->{returnto_passwd};
	my $confirmed = md5_hex("$returnto$returnto_passwd") eq $returnto_confirm;
	if ($confirmed) {
		# The URL and the password have been concatted together
		# and confirmed with the MD5, so we know it comes from a
		# trusted source.  Approve it.
		return $returnto;
	} else {
		# There is no proper MD5, so don't redirect.
		return undef;
	}
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

Raw date/time to format.
Supply a false value here to get the current date/time.

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
	my($date, $format, $off_set, $options) = @_;
	my $user = getCurrentUser();
	my(@dateformats, $err);

	$off_set = $user->{off_set} || 0 if !defined $off_set;

	if ($date) {
		# massage data for YYYYMMDDHHmmSS or YYYYMMDDHHmm (with optional TZ)
		$date =~ s/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?( [a-zA-Z]+)?$/"$1-$2-$3 $4:$5:" . ($6 || '00') . ($7 || '')/e;

		# find out the user's time based on personal offset in seconds
		$date = str2time($date) + $off_set;
	} else {
		# use current time (plus offset) if no time provided
		$date = time() + $off_set;
	}

	# set user's language; we only use this if it is defined,
	# so it's not a performance hit
	my $lang = getCurrentStatic('datelang');

	# If no format passed in, default to the current user's.
	$format ||= $user->{'format'};

	if ($format =~ /\bIF_OLD\b/) {
		# Split $format into its new half and old half.
		my($format_new, $format_old) = $format =~ /^(.+?)\s*\bIF_OLD\b\s*(.+)$/;
		warn "format cannot be parsed: '$format'" if !defined($format_new);
		# Reassign whichever half we want back to $format.
		$format = $date < time() - 180*86400
			|| ($options && $options->{is_old})
			? $format_old
			: $format_new;
	}

	# convert the raw date to pretty formatted date
	if ($lang && $lang ne 'English') {
		my $datelang = Date::Language->new($lang);
		$date = $datelang->time2str($format, $date);
	} else {
		$date = time2str($format, $date);
	}

	# return the new pretty date
	return $date;
}

sub titleCaseConvert {
	my($title) = @_;
	my @words = split / /, $title;
	my @newwords;

	for (my $i = 0; $i < @words; $i++) {
		my $word = $words[$i];
		if ($i == 0) {
			$word = ucfirst $word;
		} elsif ($word =~ m/^a(n|nd)?$|^the$|^of$/i) {
			$word = lcfirst $word;
		} else {
			$word = ucfirst $word;
		}

		push @newwords, $word;
	}

	$title = join(' ', @newwords);
	return $title;
}

sub quoteFixIntrotext {
	my ($text) = @_;
	if ($text =~ m/^[^"]*"[^"]*"[^"]*$/s) {
		$text =~ s/"/'/g;
	}
	return $text;
}

sub getFormatFromDays {
	my($days, $options) = @_;
	my $ret_array = [];
	return $ret_array unless $days && ref($days) eq 'ARRAY';

	my $label;
	my $which_day;
	my $orig_day = $options->{orig_day} || $days->[0];
	my($db_levels, $db_order) = getDayBreakLevels();

	my $slashdb = getCurrentDB();
	my $today = $slashdb->getDay(0, { orig_day => $orig_day });
	my $yesterday = $slashdb->getDay(1, { orig_day => $orig_day });

	if ($orig_day =~ $db_levels->{hour}{re}) {
		$which_day = 'hour';
		my $yesterday = $slashdb->getDay(1);

		for my $day (@$days) {
			my @arr  = $day   =~ $db_levels->{$which_day}{re};
			my $fmt = '%l:00%P'; # 2:00pm

			if ($today =~ /^$arr[0]$arr[1]$arr[2]$arr[3]/) {
				#$fmt = 'Now';
			} elsif ($yesterday =~ /^$arr[0]$arr[1]$arr[2]/) {
				$fmt = "Yesterday, $fmt";
			} elsif ($today !~ /^$arr[0]/) {
				$fmt = "%b. %e, %Y $fmt";
			} elsif ($today !~ /^$arr[0]$arr[1]$arr[2]/) {
				$fmt = "%B %e, $fmt";
			}

			push @$ret_array, [ $day, timeCalc($day . '00', $fmt, 0) ];
		}

	} elsif ($orig_day =~ $db_levels->{day}{re}) {
		$which_day = 'day';

		my $weekago = $slashdb->getDay(7, { orig_day => $orig_day });
		my($ty, $tm, $td) = $today =~ $db_levels->{$which_day}{re};

		for my $day (@$days) {
			my @arr = $day =~ $db_levels->{$which_day}{re};
			if ($day eq $today) {
				$label = 'Today';
			} elsif ($day eq $yesterday) {
				$label = 'Yesterday';
			} elsif ($day <= $today && $day >= $weekago) {
				$label = timeCalc($day, '%A', 0);
			} elsif ($ty == $arr[0]) {
				$label = timeCalc($day, '%B %e', 0);
			} else {
				$label = timeCalc($day, '%b. %e, %Y', 0);
			}
			push @$ret_array, [ $day, $label ];
		}

	} elsif ($orig_day =~ $db_levels->{week}{re}) {
		$which_day = 'week';

		for my $day (@$days) {
			my @arr = $day =~ $db_levels->{$which_day}{re};

			if ($day eq $today) {
				$label = 'This Week';
			} elsif ($day eq $yesterday) {
				$label = 'Last Week';
			} else {
				my($y, $m, $d) = Monday_of_Week($arr[1]+1, $arr[0]);
				my $tmpday = sprintf($db_levels->{day}{sfmt}, $y, $m, $d);
				my $fmt = 'Week of %B %e';
				if ($today !~ /^$y/) {
					$fmt .= ', %Y';
				}
				$label = timeCalc($tmpday, $fmt, 0);
			}

			push @$ret_array, [ $day, $label ];
		}

	} elsif ($orig_day =~ $db_levels->{month}{re}) {
		$which_day = 'month';
		for my $day (@$days) {
			(my $tmpday = $day) =~ s/m$//;
			my $fmt = '%B';
			(my $y = $tmpday) =~ s/\d\d$//;
			if ($today !~ /^$y/) {
				$fmt .= ' %Y';
			}
			push @$ret_array, [ $day, timeCalc($tmpday . '01', $fmt, 0) ];
		}

	} elsif ($orig_day =~ $db_levels->{year}{re}) {
		$which_day = 'year';
		for my $day (@$days) {
			push @$ret_array, [ $day, timeCalc($day . '0101', '%Y', 0) ];
		}
	}


	errorLog("No format found for $orig_day") unless $which_day;

	$_->[1] =~ s/May\./May/ for @$ret_array;

	# re-format elements if necessary
#	$_->[0] = sprintf($db_levels->{$which_day}{refmt}, $_->[0]) for @$ret_array;

	return $ret_array;
}

{
	my @db_levels = (
		hour    => { fmt => '%Y%m%d%H', sfmt => '%04d%02d%02d%02d', refmt => '%s',  re => qr{^(\d{4})(\d{2})(\d{2})(\d{2})$}, timefmt => sub { "$_[0]-$_[1]-$_[2] $_[3]:00:00" } },
		day     => { fmt => '%Y%m%d',   sfmt => '%04d%02d%02d',     refmt => '%s',  re => qr{^(\d{4})-?(\d{2})-?(\d{2})$},    timefmt => sub { "$_[0]-$_[1]-$_[2] 00:00:00" } },
		week    => { fmt => '%Y%Ww',    sfmt => '%04d%02dw',        refmt => '%sw', re => qr{^(\d{4})(\d{1,2})w$},            timefmt => sub { sprintf "%04d-%02d-%02d 00:00:00", Monday_of_Week($_[1]+1,$_[0]) } },
		month   => { fmt => '%Y%mm',    sfmt => '%04d%02dm',        refmt => '%sm', re => qr{^(\d{4})(\d{2})m$},              timefmt => sub { "$_[0]-$_[1]-01 00:00:00" } },
		year    => { fmt => '%Y',       sfmt => '%04d',             refmt => '%s',  re => qr{^(\d{4})$},                      timefmt => sub { "$_[0]-01-01 00:00:00" } },
	);
	my %db_levels = @db_levels;
	my $i = 0;
	my @db_order = grep { ++$i % 2 } @db_levels;
	sub getDayBreakLevels { return(\%db_levels, \@db_order) }
}

sub parseDayBreakLevel {
	my($day) = @_;
	my($db_levels, $db_order) = getDayBreakLevels();
	for my $level (@$db_order) {
		return $level if $day =~ $db_levels->{$level}{re};
	}
	return;
}

#========================================================================

=head2 createLogToken()

Return new random 22-character logtoken, composed of \w chars.

=over 4

=item Return value

Return a random password that matches /^\w{22}$/.

We're only pulling out 3 chars each time thru this loop, so we only
need (and trust) about 18 bits worth of randomness.  We re-seed srand
periodically to try to get more randomness into the mix ("it uses a
semirandom value supplied by the kernel (if it supports the /dev/urandom
device)", says the Camel book).  I don't think I'm doing anything
mathematically dumb to introduce any predictability into this, so it
should be fine, wasteful of a few microseconds perhaps, ugly perhaps, but
the 22-char value it returns should have very close to 131 bits of
randomness.

=back

=cut

sub createLogToken {
	my $str = '';
	my $need_srand = 0;
	while (length($str) < 22) {
		if ($need_srand) {
			srand();
			$need_srand = 0;
		}
		my $r = rand(UINT_MAX) . ':' . rand(UINT_MAX);
		my $md5 = md5_base64($r);
		$md5 =~ tr/A-Za-z0-9//cd;
		$str .= substr($md5, int(rand 8) + 5, 3);
		$need_srand = 1 if rand() < 0.3;
	}
	return substr($str, 0, 22);
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

Encrypts given password, using the most recent salt (if any) in
Slash::Apache::User::PasswordSalt for the current virtual user.
Currently uses MD5, but could change in the future, so do not
depend on the implementation.

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
	my($passwd, $uid) = @_;
	$uid ||= '';
	my $slashdb = getCurrentDB();
	my $vu = $slashdb->{virtual_user};
	my $salt = Slash::Apache::User::PasswordSalt::getCurrentPwSalt($vu);
	$passwd = Encode::encode_utf8($passwd) if getCurrentStatic('utf8');
	return md5_hex("$salt:$uid:$passwd");
}

#========================================================================

=head2 comparePassword(PASSWD, MD5, ISPLAIN, ISENC)

Given a password and an MD5 hex string, compares the two to see if they
represent the same value.  To be precise:

If the password given is equal to the MD5 string, it must already be
in MD5 format and be correct, so return true

Otherwise, the password is assumed to be plaintext.  Each possible
salt-encryption of it (including the encryption with empty salt) is
compared against the MD5 string.  True is returned if there is any
match.

If ISPLAIN is true, PASSWD is assumed to be plaintext, so the
(trivial equality) test against the encrypted MD5 is not performed.

If ISENC is true, PASSWD is assumed to be already encrypted, so the
tests of salting and encrypting it are not performed.

(If neither is true, all tests are performed.  If both are true, no
tests are performed and 0 is returned.)

=over 4

=item Parameters

=over 4

=item PASSWD

Possibly-correct password, either plaintext or already-MD5's,
to be checked.

=item MD5

Encrypted correct password.

=back

=item Return value

0 or 1.

=back

=cut

sub comparePassword {
	my($passwd, $md5, $uid, $is_plain, $is_enc) = @_;
	if (!$is_plain) {
		return 1 if $passwd eq $md5;
	}
	if (!$is_enc) {
		# An old way of encrypting a user's password, which we have
		# to check for reverse compatibility.
		return 1 if md5_hex($passwd) eq $md5;

		# No?  OK let's see if it matches any of the salts.
		my $slashdb = getCurrentDB();
		my $vu = $slashdb->{virtual_user};
		my $salt_ar = Slash::Apache::User::PasswordSalt::getPwSalts($vu);
		unshift @$salt_ar, ''; # always test the case of no salt
		for my $salt (reverse @$salt_ar) {
			# The current way of encrypting a user's password.
			return 1 if md5_hex("$salt:$uid:$passwd") eq $md5;
			# An older way, which we have to check for reverse
			# compatibility.
			return 1 if length($salt) && md5_hex("$salt$passwd") eq $md5;
		}
	}
	return 0;
}

sub split_bayes {
	my($t) = @_;
	my $constants = getCurrentStatic();
	my $min_len = $constants->{fhbayes_min_token_len} ||  2;
	my $max_len = $constants->{fhbayes_max_token_len} || 20;

	my $urls = getUrlsFromText($t);
	my(@urls, @domains) = ( );
	for my $url (@$urls) {
		push @urls, $url;
		my $uri = URI->new($url);
		next unless $uri->can('host');
		my $domain = fullhost_to_domain($uri->host());
		next unless $domain;
		push @domains, $domain;
	}

	$t = strip_nohtml($t);

	$t =~ s/[^A-Za-z0-9&;.']+/ /g;
	$t =~ s/\s[.']+/ /g;
	$t =~ s/[.']+\s/ /g;

	my @tokens = grep { length($_) >= $min_len && length($_) <= $max_len } split ' ', $t;

	return (@urls, @domains, @tokens);
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

my %ansi_to_ascii = (
	131	=> 'f',
	133	=> '...',
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

my %ansi_to_utf = (
	128	=> 8364,
	129	=> '',
	130	=> 8218,
	131	=> 402,
	132	=> 8222,
	133	=> 8230,
	134	=> 8224,
	135	=> 8225,
	136	=> 710,
	137	=> 8240,
	138	=> 352,
	139	=> 8249,
	140	=> 338,
	141	=> '',
	142	=> 381,
	143	=> '',
	144	=> '',
	145	=> 8216,
	146	=> 8217,
	147	=> 8220,
	148	=> 8221,
	149	=> 8226,
	150	=> 8211,
	151	=> 8212,
	152	=> 732,
	153	=> 8482,
	154	=> 353,
	155	=> 8250,
	156	=> 339,
	157	=> '',
	158	=> 382,
	159	=> 376,
);

# protect the hash by just returning it, for external use only
sub _ansi_to_ascii { %ansi_to_ascii }
sub _ansi_to_utf   { %ansi_to_utf }

sub _charsetConvert {
	my($char, $constants) = @_;
	$constants ||= getCurrentStatic();

	my $str = '';
	if ($constants->{draconian_charset_convert}) {
		if ($constants->{draconian_charrefs}) {
			if ($constants->{good_numeric}{$char}) {
				$str = sprintf('&#%u;', $char);
			} else { # see if char is in %good_entity
				my $ent = $char2entity{chr $char};
				if ($ent) {
					(my $data = $ent) =~ s/^&(\w+);$/$1/;
					$str = $ent if $constants->{good_entity}{$data};
				}
			}
		}
		# fall back
		$str ||= $ansi_to_ascii{$char};
	}

	# fall further back
	# if the char is a special one we don't recognize in Latin-1,
	# convert it here.  this does not prevent someone from manually
	# entering &#147; or some such, if they feel they need to, it is
	# to help catch it when browsers send non-Latin-1 data even though
	# they shouldn't
	$char = $ansi_to_utf{$char} if exists $ansi_to_utf{$char};
	$str ||= sprintf('&#%u;', $char) if length $char;
	return $str;
}

sub _fixupCharrefs {
	my $constants = getCurrentStatic();

	return if $constants->{bad_numeric};

	# At the moment, unless the "draconian" rule is set, only
	# entities that change the direction of text are forbidden.
	# For more information, see
	# <http://www.w3.org/TR/html4/struct/dirlang.html#bidirection>
	# and <http://www.htmlhelp.com/reference/html40/special/bdo.html>.
	$constants->{bad_numeric}  = { map { $_, 1 } @{$constants->{charrefs_bad_numeric}} };
	$constants->{bad_entity}   = { map { $_, 1 } @{$constants->{charrefs_bad_entity}} };

	$constants->{good_numeric} = { map { $_, 1 } @{$constants->{charrefs_good_numeric}},
		grep { $_ < 128 || $_ > 159 } keys %ansi_to_ascii };
	$constants->{good_entity}  = { map { $_, 1 } @{$constants->{charrefs_good_entity}}, qw(apos quot),
		grep { s/^&(\w+);$/$1/ } map { $char2entity{chr $_} }
		grep { $_ < 128 || $_ > 159 } keys %ansi_to_ascii };
}

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
	processCustomTagsPre => sub {
			${$_[0]} = processCustomTagsPre(${$_[0]});	},
	processCustomTagsPost => sub {
			${$_[0]} = processCustomTagsPost(${$_[0]});	},
	approveTags => sub {
			${$_[0]} =~ s/<(.*?)>/approveTag($1)/sge;	},
	url2html => sub {
			${$_[0]} = url2html(${$_[0]});			},
	approveCharrefs => sub {
			${$_[0]} =~ s{
				&(\#?[a-zA-Z0-9]+);?
			}{approveCharref($1)}gex;			},
	space_between_tags => sub {
			${$_[0]} =~ s/></> </g;				},
	whitespace_tagify => sub {
			${$_[0]} =~ s/\n/<br>/gi;  # pp breaks
			${$_[0]} =~ s/(?:<br>\s*){2,}<br>/<br><br>/gi;
			# Preserve leading indents / spaces
			# can mess up internal tabs, oh well
			${$_[0]} =~ s/\t/    /g;			},
	paragraph_wrap => sub {
			# start off the text with a <p>!
			${$_[0]} = '<p>' . ${$_[0]} unless ${$_[0]} =~ /^\s*<p>/s;
			# this doesn't assume there will be only two BRs,
			# but it does come after whitespace_tagify, so
			# chances are, will be only two BRs in a row
			${$_[0]} =~ s/(?:<br>){2}/<p>/g;
			# make sure we don't end with a <br><p> or <br>
			${$_[0]} =~ s/<br>(<p>|$)/$1/g;			},
	whitespace_and_tt => sub {
			${$_[0]} =~ s{((?:  )+)(?: (\S))?} {
				("&nbsp; " x (length($1)/2)) .
				(defined($2) ? "&nbsp;$2" : "")
			}eg;
			${$_[0]} = "<tt>${$_[0]}</tt>";			},
	newline_indent => sub {
			${$_[0]} =~ s{<br>\n?( +)} {
				"<br>\n" . ('&nbsp; ' x length($1))
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
			my $constants = getCurrentStatic();
			if ($constants->{draconian_charset}) {
				# anything not CRLF tab space or ! to ~ in Latin-1
				# is converted to entities, where approveCharrefs or
				# encode_html_amp takes care of them later
				_fixupCharrefs();
				${$_[0]} =~ s[([^\n\r\t !-~])][ _charsetConvert(ord($1), $constants)]ge;
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
			processCustomTagsPre
			remove_trailing_lts
			approveTags
			processCustomTagsPost
			space_between_tags
			encode_html_ltgt_stray
			encode_html_amp_ifnotent
			approveCharrefs
			breakHtml_ifwhitefix
			whitespace_tagify
			newline_indent
			paragraph_wrap			)],
	HTML, [qw(
			newline_to_local
			trailing_whitespace
			encode_high_bits
			processCustomTagsPre
			remove_trailing_lts
			approveTags
			processCustomTagsPost
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
	$str = '' if !defined($str);
	$fmode ||= NOHTML;
	$no_white_fix = 1 if !defined($no_white_fix) && $fmode == LITERAL;
	$action_data{no_white_fix} = $no_white_fix || 0;

	my @actions = @{$mode_actions{$fmode}};
#my $c = 0; print STDERR "stripByMode:start:$c:[{ $str }]\n";
	for my $action (@actions) {
		$actions{$action}->(\$str, $fmode);
#$c++; print STDERR "stripByMode:$action:$c:[{ $str }]\n";
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

sub determine_html_format {
	my($html, $user) = @_;
	my $posttype = PLAINTEXT;

	my $is_admin = 0;
	my($match, $admin_text);
	$user ||= getCurrentUser();
	$is_admin = isAdmin($user) || $user->{acl}{journal_admin_tags};

	if ($is_admin) {
		my $constants = getCurrentStatic();
		my $cache = getCurrentCache();
		$match = $cache->{approvedtags_admin_alone};
		if (!$match) {
			my %tags = map {$_ => 1} @{$constants->{approvedtags_admin}};
			delete $tags{$_} for @{$constants->{approvedtags}};
			$match = join '|', map lc, keys %tags;
			$cache->{approvedtags_admin_alone} = $match = qr/$match/;
		}
	}

	# first check to see if the post starts with <pre>
	if ($html =~ /^\s*<pre>/s) {
		$posttype = CODE;
		$html =~ s/<\/?pre>//g;

	# then see if user is an admin, and there's an admin-only tag used
	} elsif ($is_admin && $html =~ /<(?:$match)\b/) {
		$posttype = FULLHTML;

	# finally see if there's a line-breaking tag
	} elsif ($html =~ /<(?:p|br)\b/) {
		$posttype = HTML;
	}

	# the HTML can be modified, so need to return the HTML too
	return($html, $posttype);
}

#========================================================================

=head2 strip_paramattr(STRING [, NO_WHITESPACE_FIX])

=head2 strip_paramattr_nonhttp(STRING [, NO_WHITESPACE_FIX])

=head2 strip_urlattr(STRING [, NO_WHITESPACE_FIX])

Wrappers for strip_attribute(fixparam($param), $no_whitespace_fix) and
strip_attribute(fudgeurl($url), $no_whitespace_fix).

Note that http is a bit of a special case:  its parameters can be escaped
with "+" for " ", instead of just "%20".  So strip_paramattr should
probably be renamed strip_paramattrhttp to best indicate that it is a
special case.  But because the special case is also the most common case,
with over 100 occurrences in the code, we leave it named strip_paramattr,
and create a new function strip_paramattr_nonhttp which must be used for
URI schemes which do not behave in that way.

=cut

sub strip_paramattr		{ strip_attribute(fixparam($_[0]), $_[1]) }
sub strip_paramattr_nonhttp	{ my $h = strip_attribute(fixparam($_[0]), $_[1]); $h =~ s/\+/%20/g; $h }
sub strip_urlattr		{ strip_attribute(fudgeurl($_[0]), $_[1]) }


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

	my $ent = qr/#?[a-zA-Z0-9]+/;
	$str =~ s/&(?!$ent;)/&amp;/g;
	$str =~ s/&($ent);?/approveCharref($1)/ge;

	return $str;
}

#========================================================================

=head2 processCustomTagsPre(STRING)

=head2 processCustomTagsPost(STRING)

Private function.  It does processing of special custom tags (in Pre, ECODE;
in Post, QUOTE).

=over 4

=item Parameters

=over 4

=item STRING

String to be processed.

=back

=item Return value

Processed string.

=item Dependencies

Pre is meant to be used before C<approveTag> is called; Post after.
Both are called only from regular posting modes, HTML and PLAINTEXT.

=back

=cut

sub processCustomTagsPre {
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
	if (grep /^ecode$/i, @{$constants->{approvedtags}}) {
		$str =~ s|<(/?)literal>|<${1}ecode>|gi;  # we used to accept "literal" too
		my $ecode   = 'ecode';
		my $open    = qr[\n* <\s* (?:$ecode) (?: \s+ END="(\w+)")? \s*> \n*]xsio;
		my $close_1 = qr[($open (.*?) \n* <\s* /\2    \s*> \n*)]xsio;  # if END is used
		my $close_2 = qr[($open (.*?) \n* <\s* /ECODE \s*> \n*)]xsio;  # if END is not used

		while ($str =~ m[($open)]g) {
			my $len = length($1);
			my $end = $2;
			my $pos = pos($str) - $len;

			my $close = $end ? $close_1 : $close_2;
			my $substr = substr($str, $pos);
			if ($substr =~ m/^$close/si) {
				my $len = length($1);
				my $codestr = $3;
				# remove these if they were added by url2html; I know
				# this is a rather cheesy way to do this, but c'est la vie
				# -- pudge
				$codestr =~ s{<a href="[^"]+" rel="url2html-$$">(.+?)</a>}{$1}g;
				my $code = strip_code($codestr);
				my $newstr = "<p><blockquote>$code</blockquote></p>";
				substr($str, $pos, $len) = $newstr;
				pos($str) = $pos + length($newstr);
			}
		}
	}
	return $str;
}

sub processCustomTagsPost {
	my($str) = @_;
	my $constants = getCurrentStatic();

	# QUOTE must be in approvedtags
	if (grep /^quote$/i, @{$constants->{approvedtags}}) {
		my $quote   = 'quote';
		my $open    = qr[\n* <\s*  $quote \s*> \n*]xsio;
		my $close   = qr[\n* <\s* /$quote \s*> \n*]xsio;

		$str =~ s/$open/<p><div class="quote">/g;
		$str =~ s/$close/<\/div><\/p>/g;
	}

	# just fix the whitespace for blockquote to something that looks
	# universally good
	if (grep /^blockquote$/i, @{$constants->{approvedtags}}) {
		my $quote   = 'blockquote';
		my $open    = qr[\s* <\s*  $quote \s*> \n*]xsio;
		my $close   = qr[\s* <\s* /$quote \s*> \n*]xsio;

		$str =~ s/(?<!<p>)$open/<p><$quote>/g;
	}

	return $str;
}

# revert div class="quote" back to <quote>, handles nesting
sub revertQuote {
	my($str) = @_;

	my $bail = 0;
	while ($str =~ m|((<p>)?<div class="quote">)(.+)$|sig) {
		my($found, $p, $rest) = ($1, $2, $3);
		my $pos = pos($str) - (length($found) + length($rest));
		substr($str, $pos, length($found)) = '<quote>';
		pos($str) = $pos + length('<quote>');

		my $c = 0;
		$bail = 1;
		while ($str =~ m|(<(/?)div.*?>(</p>)?)|sig) {
			my($found, $end, $p2) = ($1, $2, $3);
			if ($end && !$c) {
				$bail = 0;  # if we don't get here, something is wrong
				my $len = length($found);
				# + 4 is for the </p>
				my $pl = $p && $p2 ? 4 : 0;
				substr($str, pos($str) - $len, $len + $pl) = '</quote>';
				pos($str) = 0;
				last;
			} elsif ($end) {
				$c--;
			} else {
				$c++;
			}
		}

		if ($bail) {
			use Data::Dumper;
			warn "Stuck in endless loop: " . Dumper({
				found	=> $found,
				p	=> $p,
				rest	=> $rest,
				'pos'	=> $pos,
				str	=> $str,
			});
			last;
		}
	}
	return($str);
}


sub prepareQuoteReply {
	my($reply) = @_;
	my $pid_reply = $reply->{comment} = parseDomainTags($reply->{comment}, 0, 1, 1);
	$pid_reply = revertQuote($pid_reply);

	# prep for JavaScript
	$pid_reply =~ s|\\|\\\\|g;
	$pid_reply =~ s|'|\\'|g;
	$pid_reply =~ s|([\r\n])|\\n|g;

	$pid_reply =~ s{<nobr> <wbr></nobr>(\s*)} {$1 || ' '}gie;
	#my $nick = strip_literal($reply->{nickname});
	#$pid_reply = "<div>$nick ($reply->{uid}) wrote: <quote>$pid_reply</quote></div>";
	$pid_reply = "<quote>$pid_reply</quote>";
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
	return $text if $Slash::Utility::Data::approveTag::admin
		     && $Slash::Utility::Data::approveTag::admin > 1;

	my $constants = getCurrentStatic();
	$mwl = $mwl || $constants->{breakhtml_wordlength} || 50;

	# Only do the <NOBR> and <WBR> bug workaround if wanted.
	my $workaround_start = $constants->{comment_startword_workaround}
		? "<nobr>" : "";
	my $workaround_end = $constants->{comment_startword_workaround}
		? "<wbr></nobr> " : " ";

	# These are tags that "break" a word;
	# a<P>b</P> breaks words, y<B>z</B> does not
	my $approvedtags_break = $constants->{'approvedtags_break'} || [];
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
			(			# followed by either
				$nbe		# an entity (char. ref.)
			|	(?!$nbe)\S	# or an ordinary char
			)
		){$mwl}			# $mwl non-HTML-tag chars in a row
	)}{
		substr($1, 0, -length($2))
		. $workaround_start
		. substr($1, -length($2))
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

	my $gSkin = getCurrentSkin();
	my $rootdir = $gSkin->{rootdir};
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

{
	# here's a simple hardcoded list of replacement tags, ones
	# we don't really care about, or that are no longer valid.
	# we just replace them with sane substitutes, if and only if
	# they are not in approvedtags already
	my %replace = (
		em	=> 'i',
		strong	=> 'b',
		dfn	=> 'i',
		code	=> 'tt',
		samp	=> 'tt',
		kbd	=> 'tt',
		var	=> 'i',
		cite	=> 'i',

		address	=> 'i',
		lh	=> 'li',
		dir	=> 'ul',
	);

sub approveTag {
	my($wholetag) = @_;
	my $constants = getCurrentStatic();

	$wholetag =~ s/^\s*(.*?)\s*$/$1/; # trim leading and trailing spaces

	# Take care of URL:foo and other HREFs
	# Using /s means that the entire variable is treated as a single line
	# which means \n will not fool it into stopping processing.  fudgeurl()
	# knows how to handle multi-line URLs (it removes whitespace).
	if ($wholetag =~ /^URL:(.+)$/is) {
		my $url = fudgeurl($1);
		return qq!<a href="$url">$url</a>!;
	}

	# Build the hash of approved tags
	# XXX someday maybe should be an option, not a global var ...
	my $approvedtags = $Slash::Utility::Data::approveTag::admin && $constants->{approvedtags_admin}
		? $constants->{approvedtags_admin}
		: $constants->{approvedtags};
	my %approved =
		map  { (lc, 1)   }
		grep { !/^ecode$/i }
		@$approvedtags;

	# We can do some checks at this point.  $t is the tag minus its
	# properties, e.g. for "<a href=foo>", $t will be "a".
	my($taglead, $slash, $t) = $wholetag =~ m{^(\s*(/?)\s*(\w+))};
	my $t_lc = lc $t;
	if (!$approved{$t_lc}) {
		if ($replace{$t_lc} && $approved{ $replace{$t_lc} }) {
			$t = $t_lc = $replace{$t_lc};
		} else {
			if ($constants->{approveTag_debug}) {
				$Slash::Utility::Data::approveTag::removed->{$t_lc} ||= 0;
				$Slash::Utility::Data::approveTag::removed->{$t_lc}++;
			}
			return '';
		}
	}

	# These are now stored in a var approvedtags_attr
	#
	# A string in the format below:
	# a:href_RU img:src_RU,alt_N,width,height,longdesc_U
	# 
	# Is decoded into the following data structure for attribute
	# approval
	#
	# {
	#	a =>	{ href =>	{ ord => 1, req => 1, url => 1 } },
	#	img =>	{ src =>	{ ord => 1, req => 1, url => 1 },
	#		  alt =>	{ ord => 2, req => 2           },
	#		  width =>	{ ord => 3                     },
	#		  height =>	{ ord => 4                     },
	#		  longdesc =>	{ ord => 5,           url => 1 }, },
	# }
	# this is decoded in Slash/DB/MySQL.pm getSlashConf

	my $attr = $Slash::Utility::Data::approveTag::admin && $constants->{approvedtags_attr_admin}
		? $constants->{approvedtags_attr_admin}
		: $constants->{approvedtags_attr};
	$attr ||= {};

	if ($slash) {
		# Close-tags ("</A>") never get attributes.
		$wholetag = "/$t_lc";

	} elsif ($attr->{$t_lc}) {
		# This is a tag with attributes, verify them.

		my %allowed = %{$attr->{$t_lc}};
		my %required =
			map  { $_, $allowed{$_}  }
			grep { $allowed{$_}{req} }
			keys   %allowed;

		my $tree = HTML::TreeBuilder->new; #_from_content("<$wholetag>");
		$tree->attr_encoded(1);
		$tree->implicit_tags(0);
		$tree->parse("<$wholetag>");
		$tree->eof;
		my $elem = $tree->look_down(_tag => $t_lc);
		# look_down() can return a string for some kinds of bogus data
		return "" unless $elem && ref($elem) eq 'HTML::Element';
		my @attr_order =
			sort { $allowed{lc $a}{ord} <=> $allowed{lc $b}{ord} }
			grep { !/^_/ && exists $allowed{lc $_} }
			$elem->all_attr_names;
		my %attr_data  = map { ($_, $elem->attr($_)) } @attr_order;
		my %found;
		$wholetag = $t_lc;

		for my $a (@attr_order) {
			my $a_lc = lc $a;
			next unless $allowed{$a_lc};
			my $data = $attr_data{$a_lc} || '';
			$data = fudgeurl($data) if $allowed{$a_lc}{url};
			next unless length $data;
			$wholetag .= qq{ $a_lc="$data"};
			++$found{$a_lc} if $required{$a_lc};
		}

		# If the required attributes were not all present, the whole
		# tag is invalid, unless req == 2, in which case we fudge it
		for my $a (keys %required) {
			my $a_lc = lc $a;
			next if $found{$a_lc};
			if ($required{$a}{req} == 2) {
				# is there some better default than "*"?
				$wholetag .= qq{ $a_lc="*"};
			} else {
				return '';
			}
		}

	} else {
		# No attributes allowed.
		$wholetag = $t_lc;
	}

	# If we made it here, the tag is valid.
	return "<$wholetag>";
}
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

	_fixupCharrefs();
	my %ansi_to_ascii = _ansi_to_ascii();
	my $ansi_to_utf   = _ansi_to_utf();
	my $decimal = 0;

	if ($ok == 1 && $charref =~ /^#/) {
		# Probably a numeric character reference.
		if ($charref =~ /^#x([0-9a-f]+)$/i) {
			# Hexadecimal encoding.
			$charref =~ s/^#X/#x/; # X should work fine, but x is better
			$decimal = hex($1); # always returns a positive integer
		} elsif ($charref =~ /^#(\d+)$/) {
			# Decimal encoding.
			$decimal = $1;
		} else {
			# Unknown, assume flawed.
			$ok = 0;
		}

		# NB: 1114111/10FFFF is highest allowed by Unicode spec,
		# but 917631/E007F is highest with actual glyph
		$ok = 0 if $decimal <= 0 || $decimal > 65534; # sanity check
		if ($constants->{draconian_charrefs}) {
			if (!$constants->{good_numeric}{$decimal}) {
				$ok = $ansi_to_ascii{$decimal} ? 2 : 0;
			}
		} else {
			$ok = 0 if $constants->{bad_numeric}{$decimal};
		}
	} elsif ($ok == 1 && $charref =~ /^([a-z0-9]+)$/i) {
		# Character entity.
#		my $entity = lc $1;
		my $entity = $1;  # case matters
		if ($constants->{draconian_charrefs}) {
			if (!$constants->{good_entity}{$entity}) {
				if (defined $entity2char{$entity}) {
					$decimal = ord $entity2char{$entity};
					$ok = $ansi_to_ascii{$decimal} ? 2 : 0;
				} else {
					$ok = 0;
				}
			}
		} else {
			$ok = 0 if $constants->{bad_entity}{$entity}
				|| ($constants->{draconian_charset} && ! exists $entity2char{$entity});
		}
	} elsif ($ok == 1) {
		# Unknown character reference type, assume flawed.
		$ok = 0;
	}

	# special case for old-style broken entities we want to convert to ASCII
	if ($ok == 2 && $decimal) {
		return $ansi_to_ascii{$decimal};
	} elsif ($ok) {
		return "&$charref;";
	} else {
		return '';
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

The data to be escaped.  B<NOTE>: space characters are encoded as C<+>
instead of C<%20>.  If you must have C<%20>, perform an C<s/\+/%20/g>
on the result.  Note that this is designed for HTTP URIs, the most
common scheme;  for other schemes, refer to the comments documenting
strip_paramattr and strip_paramattr_nonhttp.

=back

=item Return value

The escaped data.

=back

=cut

sub fixparam {
	my($url) = @_;
	$url = encode_utf8($url) if (getCurrentStatic('utf8') && is_utf8($url));
	$url =~ s/([^$URI::unreserved ])/$URI::Escape::escapes{$1}/og;
	$url =~ s/ /+/g;
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

{
# [] is only allowed for IPV6 (see RFC 2732), and we don't use IPV6 ...
# in theory others could still create links to them, but we would need
# better heuristics for it, in another place in the code
(my $allowed = $URI::uric) =~ s/[\[\]]//g;
# add '#' to allowed characters, since it is often included
$allowed .= '#';
sub fixurl {
	my($url) = @_;
	$url = encode_utf8($url) if (getCurrentStatic('utf8') && is_utf8($url));
	$url =~ s/([^$allowed])/$URI::Escape::escapes{$1}/og;
	$url =~ s/%(?![a-fA-F0-9]{2})/%25/g;
	return $url;
}
}

#========================================================================

=head2 fudgeurl(DATA)

Prepares data to be a URL.  Such as:

=over 4

	my $url = fudgeurl($someurl);

=item Parameters

=over 4

=item DATA

The data to be escaped.

=back

=item Return value

The escaped data.

=back

=cut

sub fudgeurl {
	my($url) = @_;

	### should we just escape spaces, quotes, apostrophes, and <> instead
	### of removing them? -- pudge

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

	my $scheme_regex = _get_scheme_regex();

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

		# and we should only add scheme if not a local site URL
		my($from_site) = urlFromSite($uri->as_string);
		$uri->scheme('http') unless $from_site;
	}

	if (!$uri) {

		# Nothing we can do with it; manipulate the probably-bogus
		# $url at the end of this function and return it.

	} elsif ($scheme && $scheme !~ /^$scheme_regex$/) {

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
			# Re the below line, see RFC 1035 and maybe 2396.
			# Underscore is not recommended and Slash has
			# disallowed it for some time, but allowing it
			# is really the right thing to do.
			$host =~ tr/A-Za-z0-9._-//cd;
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

		if ($scheme && $scheme eq 'mailto') {
			if (my $query = $uri->query) {
				$query =~ s/@/%40/g;
				$uri->query($query);
			}
		}

		$url = $uri->canonical->as_string;

		if ($url =~ /#/) {
			my $token = ':::INSERT__23__HERE:::';
			# no # is OK, unless ...
			$url =~ s/#/$token/g;
			if ($url =~ m|^https?://|i || $url =~ m|^/|) {
				# HTTP, in which case the first # is OK
				$url =~ s/$token/#/;
			}
			$url =~ s/$token/%23/g;
		}
	}

	# These entities can crash browsers and don't belong in URLs.
	$url =~ s/&#(.+?);//g;
	# we don't like SCRIPT at the beginning of a URL
	my $decoded_url = decode_entities($url);
	$decoded_url =~ s{ &(\#?[a-zA-Z0-9]+);? } { approveCharref($1) }gex;
	return $decoded_url =~ /^[\s\w]*script\b/i ? undef : $url;
}

sub _get_scheme_regex {
	my $constants = getCurrentStatic();
	if (! $constants->{approved_url_schemes_regex}) {
		$constants->{approved_url_schemes_regex} = join('|', map { lc } @{$constants->{approved_url_schemes}});
		$constants->{approved_url_schemes_regex} = qr{(?:$constants->{approved_url_schemes_regex})};
	}
	return $constants->{approved_url_schemes_regex};
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
	my($text, $length, $end) = @_;
	$text = decode_utf8($text) if (getCurrentStatic('utf8') && !is_utf8($text));
	if ($length && $end) {
		$text = substr($text, -$length);
	} elsif ($length) {
		$text = substr($text, 0, $length);
	}	
	$text =~ s/&#?[a-zA-Z0-9]*$//;
	$text =~ s/<[^>]*$//;
	return $text;
}


sub url2html {
	my($text) = @_;
	return '' if !defined($text) || $text eq '';

	my $scheme_regex = _get_scheme_regex();

	# we know this can break real URLs, but probably will
	# preserve real URLs more often than it will break them
	# was ['":=>]
	# should we parse the HTML instead?  problematic ...
	$text =~  s{(?<!\S)((?:$scheme_regex):/{0,2}[$URI::uric#]+)}{
		my $url   = fudgeurl($1);
		my $extra = '';
		$extra = $1 if $url =~ s/([?!;:.,']+)$//;
		$extra = ')' . $extra if $url !~ /\(/ && $url =~ s/\)$//;
print STDERR "url2html s/// url='$url' extra='$extra'\n" if !defined($url) || !defined($extra);
		qq[<a href="$url" rel="url2html-$$">$url</a>$extra];
	}ogie;
	# url2html-$$ is so we can remove the whole thing later for ecode

	return $text;
}

sub urlizeTitle {
	my($title) = @_;
	$title = strip_notags($title);
	$title =~ s/^\s+|\s+$//g;
	$title =~ s/\s+/-/g;
	$title =~ s/[^A-Za-z0-9\-]//g;
	return $title;
}


sub noFollow {
	my($html) = @_;
	$html =~ s/(<a href=.+?)>/$1 rel="nofollow">/gis;
	return $html;
}



# DOCUMENT after we remove some of this in favor of
# HTML::Element

sub html2text {
	my($html, $col) = @_;
	my($text, $tree, $form, $refs);

	my $user      = getCurrentUser();
	my $gSkin     = getCurrentSkin();

	$col ||= 74;

	$tree = new HTML::TreeBuilder;
	$form = new HTML::FormatText (leftmargin => 0, rightmargin => $col-2);
	$refs = new HTML::FormatText::AddRefs;

	my $was_utf8 = getCurrentStatic('utf8') ? is_utf8($html) : 0;
	$tree->parse($html);
	$tree->eof;
	$refs->parse_refs($tree);
	$text = $form->format($tree);
	1 while chomp($text);

	# restore UTF-8 Flag lost by HTML::TreeBuilder
	$text = decode_utf8($text) if ($was_utf8);

	return $text, $refs->get_refs($gSkin->{absolutedir});
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

=head2 balanceTags(HTML [, OPTIONS])

Balances HTML tags; if tags are not closed, close them; if they are not
open, remove close tags; if they are in the wrong order, reorder them
(order of open tags determines order of close tags).

=over 4

=item Parameters

=over 4

=item HTML

The HTML to balance.

=item OPTIONS

A hashref for various options.

=over 4

=item deep_nesting

Integer for how deep to allow nesting indenting tags, 0 means no limit, 1 means
to use var (nesting_maxdepth).  Default is 0.

=item deep_su

Integer for how deep to allow nesting sup/sub tags, 0 means no limit, 1 means
to use var (nest_su_maxdepth).  Default is 0.

=item length

A maximum length limit for the result.

=back

=back

=item Return value

The balanced HTML.

=item Dependencies

The 'approvedtags' entry in the vars table.

=back

=cut

{
	# these are the tags we know about.
	# they are hardcoded because the code must know about each one at 
	# a fairly low level; if you want to add more, then we need to
	# change the code for them.  in theory we could generalize it more,
	# using vars for all this, but that is a low priority.
	my %known_tags	= map { ( lc, 1 ) } qw(
		b i p br a ol ul li dl dt dd em strong tt blockquote div ecode quote
		img hr big small sub sup span
		q dfn code samp kbd var cite address ins del
		h1 h2 h3 h4 h5 h6
	);
	# NB: ECODE is excluded because it is handled elsewhere.

	# tags that are indented, so we can make sure indentation level is not too great
	my %is_nesting  = map { ( lc, 1 ) } qw(ol ul dl blockquote quote);

	# or sub-super level
	my %is_suscript = map { ( lc, 1 ) } qw(sub sup);

	# block elements cannot be inside certain other elements; this defines which are which
	my %is_block    = map { ( lc, 1 ) } qw(p ol ul li dl dt dd blockquote quote div hr address h1 h2 h3 h4 h5 h6);
	my %no_block    = map { ( lc, 1 ) } qw(b i strong em tt q dfn code samp kbd var cite address ins del big small span p sub sup a h1 h2 h3 h4 h5 h6);

	# needs a <p> inside it
	my %needs_p     = map { ( lc, 1 ) } qw(blockquote quote div);

	# when a style tag is cut off prematurely because of a newly introduced block
	# element, we want to re-start the style inside the block; it is not perfect,
	# but that's why we're here, innit?
	my %is_style    = map { ( lc, 1 ) } qw(b i strong em tt q dfn code samp kbd var cite big small span);

	# tags that CAN be empty
	my %empty	= map { ( lc, 1 ) } qw(p br img hr);
	# tags that HAVE to be empty
	my %really_empty = %empty;
	# for now p is the only one ... var?
	delete $really_empty{'p'};


	# define the lists, and the content elements in the lists, in both directions
	my %lists = (
		dl		=> ['dd', 'dt'],
		ul		=> ['li'],
		ol		=> ['li'],
		# blockquote not a list, but has similar semantics:
		# everything in a blockquote needs to be in a block element,
		# so we choose two that would fit the bill
		blockquote	=> ['div'],
	);
	my %needs_list = (
		dd		=> qr/dl/,
		dt		=> qr/dl/,
		li		=> qr/ul|ol/,
	);

	# regexes to use later
	my $list_re = join '|', keys %lists;
	my %lists_re;
	for my $list (keys %lists) {
		my $re = join '|', @{$lists{$list}};
		$lists_re{$list} = qr/$re/;
	}

	my $is_block_re = join '|', keys %is_block;

sub balanceTags {
	my($html, $options) = @_;
	return '' if !defined($html) || !length($html);
	my $orightml = $html;
	my $constants = getCurrentStatic();
	my $cache = getCurrentCache();

	my($max_nest_depth, $max_su_depth) = (0, 0);
	if (ref $options) {
		$max_nest_depth = ($options->{deep_nesting} && $options->{deep_nesting} == 1)
			? $constants->{nesting_maxdepth}
			: ($options->{deep_nesting} || 0);
		$max_su_depth   = ($options->{deep_su} && $options->{deep_su} == 1)
			? $constants->{nest_su_maxdepth}
			: ($options->{deep_su} || 0);
	} else {
		# deprecated
		$max_nest_depth = ($options && $options == 1)
			? $constants->{nesting_maxdepth}
			: ($options || 0);
	}

	my(%tags, @stack, $tag, $close, $whole, $both, @list, $nesting_level, $su_level);

	# cache this regex
	# if $options->{admin} then allow different regex ... also do in approveTag
	my $matchname = $options->{admin} ? 'match_admin' : 'match';
	my $varname   = $options->{admin} && $constants->{approvedtags_admin}
		? 'approvedtags_admin'
		: 'approvedtags';
	my $match = $cache->{balanceTags}{$matchname};
	if (!$match) {
		$match = join '|', grep $known_tags{$_},
			map lc, @{$constants->{$varname}};
		$cache->{balanceTags}{$matchname} = $match = qr/$match/;
	}

	# easier to do this before we start the loop, and then fix it inside
	# we need to make sure when a block ends, a new <p> begins
	$html =~ s|(</(?:$is_block_re)>)|$1<p>|g;


	## this is the main loop.  it finds a tag, any tag
	while ($html =~ /(<(\/?)($match)\b[^>]*?( \/)?>)/sig) { # loop over tags
		($tag, $close, $whole, $both) = (lc($3), $2, $1, $4);
#		printf "DEBUG:%d:%s:%s: %d:%s\n%s\n\n", pos($html), $tag, $whole, scalar(@stack), "@stack", $html;

		# this is a closing tag (note: not an opening AND closing tag,
		# like <br /> ... that is handled with opening tags)
		if ($close) {
			# we have opened this tag already, handle closing of it
			if (!$really_empty{$tag} && @stack && $tags{$tag}) {
				# the tag is the one on the top of the stack,
				# remove from stack and counter, and move on
				if ($stack[-1] eq $tag) {
					pop @stack;
					$tags{$tag}--;

					# we keep track of lists in an add'l stack,
					# so pop off that one too
					if ($lists{$tag}) {
						my $pop = pop @list;
						# this should always be equal, else why
						# would it be bottom of @stack too?
						# so warn if it isn't ...
						warn "huh?  $tag ne $pop?" if $tag ne $pop;
					}

				# Close tag somewhere else in stack; add it to the
				# text and then loop back to catch it properly
				# XXX we could optimize here so we don't need to loop back
				} else {
					_substitute(\$html, $whole, "</$stack[-1]>", 1, 1);
				}

			# Close tag not on stack; just delete it, since it is
			# obviously not needed
			} else {
				_substitute(\$html, $whole, '');
			}


		# this is an open tag (or combined, like <br />)
		} else {
			# the tag nests, and we don't want to nest too deeply,
			# so just remove it if we are in too deep already
			if ($is_nesting{$tag} && $max_nest_depth) {
				my $cur_depth = 0;
				$cur_depth += $tags{$_} || 0 for keys %is_nesting;
				if ($cur_depth >= $max_nest_depth) {
					_substitute(\$html, $whole, '');
					next;
				}
			}

			# the tag nests, and we don't want to nest too deeply,
			# so just remove it if we are in too deep already
			if ($is_suscript{$tag} && $max_su_depth) {
				my $cur_depth = 0;
				$cur_depth += $tags{$_} for keys %is_suscript;
				if ($cur_depth >= $max_su_depth) {
					_substitute(\$html, $whole, '');
					next;
				}
			}

			# we are directly inside a list (UL), but this tag must be
			# a list element (LI)
			# this comes now because it could include a closing tag
# this isn't necessary anymore, with _validateLists()
#			if (@stack && $lists{$stack[-1]} && !(grep { $tag eq $_ } @{$lists{$stack[-1]}}) ) {
#				my $replace = $lists{$stack[-1]}[0];
#				_substitute(\$html, $whole, "<$replace>$whole");
#				$tags{$replace}++;
#				push @stack, $replace;
#			}

			if ($needs_list{$tag}) {
				# tag needs a list, like an LI needs a UL or OL, but we
				# are not inside one: replace it with a P.  not pretty,
				# but you should be more careful about what you put in there!
				if (!@list || $list[-1] !~ /^(?:$needs_list{$tag})$/) {
					my $replace = @list ? $lists{$list[-1]}[0] : 'p';
					_substitute(\$html, $whole, "<$replace>");
					pos($html) -= length("<$replace>");
					next;  # try again

				# we are inside a list (UL), and opening a new list item (LI),
				# but a previous one is already open
				} else {
					for my $check (reverse @stack) {
						last if $check =~ /^(?:$needs_list{$tag})/;
						if ($needs_list{$check}) {
							my $newtag = '';
							while (my $pop = pop @stack) {
								$tags{$pop}--;
								$newtag .= "</$pop>";
								last if $needs_list{$pop};
							}
							_substitute(\$html, $whole, $newtag, 0, 1);
							_substitute(\$html, '', $whole);
							last;
						}
					}
				}
			}

			# if we are opening a block tag, make sure no open no_block
			# tags are on the stack currently.  if they are, close them
			# first!
			if ($is_block{$tag} || $tag eq 'a' || $tag eq 'br') {
				# a is a special case for a and br: we do not want a or b tags
				# to be included in a tags, even though they are not blocks;
				# another var for this special case?
				my @no_block = ($tag eq 'a' || $tag eq 'br') ? 'a' : keys %no_block; 
				my $newtag  = '';  # close no_block tags
				my $newtag2 = '';  # re-open closed style tags inside block

				while (grep { $tags{$_} } @no_block) {
					my $pop = pop @stack;
					$tags{$pop}--;
					$newtag .= "</$pop>";
					if ($is_style{$pop}) {
						$newtag2 = "<$pop>" . $newtag2;
					}
				}

				if ($newtag) {
					_substitute(\$html, $whole, $newtag . $whole . $newtag2);
					# loop back to catch newly added tags properly
					# XXX we could optimize here so we don't need to loop back
					pos($html) -= length($whole . $newtag2);
					next;
				}
			}

			# the tag must be an empty tag, e.g. <br />; if it has $both, do
			# nothing, else add the " /".  since we are closing the tag
			# here, we don't need to add it to the stack
			if ($really_empty{$tag} || ($empty{$tag} && $both)) {
				# this is the only difference we have between
				# XHTML and HTML, in this part of the code
				if ($constants->{xhtml} && !$both) {
					(my $newtag = $whole) =~ s/^<(.+?)>$/<$1 \/>/;
					_substitute(\$html, $whole, $newtag);
				} elsif (!$constants->{xhtml} && $both) {
					(my $newtag = $whole) =~ s/^<(.+?)>$/<$1>/;
					_substitute(\$html, $whole, $newtag);
				}
				next;
			}

			# opening a new tag to be added to the stack
			$tags{$tag}++;
			push @stack, $tag;
			if ($needs_p{$tag}) {
				_substitute(\$html, '', '<p>', 1);
			}

			# we keep track of lists in an add'l stack, for
			# the immediately above purpose, so push it on here
			push @list, $tag if $lists{$tag};
		}

	}

	$html =~ s/\s+$//s;

	# add on any unclosed tags still on stack
	$html .= join '', map { "</$_>" } grep { !exists $really_empty{$_} } reverse @stack;

	_validateLists(\$html);
	_removeEmpty(\$html);

	# if over limit, do it again
	if ($options->{length} && $options->{length} < length($html)) {
		my $limit = delete $options->{length};
		while ($limit > 0 && length($html) > $limit) {
			$limit -= 1;
			$html = balanceTags(chopEntity($orightml, $limit), $options);

			# until we get wrap fix in CSS
			my $nobr  = () = $html =~ m|<nobr>|g;
			my $wbr   = () = $html =~ m|<wbr>|g;
			my $nobre = () = $html =~ m|</nobr>|g;
			$html .= '<wbr>'   if $nobr > $wbr;
			$html .= '</nobr>' if $nobr > $nobre;
		}
	}

	return $html;
}

sub _removeEmpty {
	my($html) = @_;
	my $p    = getCurrentStatic('xhtml') ? '<p />' : '<p>';

	# remove consecutive <p> or <p>, <br> tags
	1 while $$html =~ s{<p> \s* <(?: /?p | br(?:\ /)? )>} {$p}gx;
	# remove <p> and <br> tags before beginning, or end, of blocks, or end of string
	1 while $$html =~ s{\s* <(?: p | br(?:\ /)?) > \s*  ( $ | </?(?:$is_block_re)> )} {$1}gx;

	# remove still-empty tags
	while ($$html =~ m|<(\w+)>\s*</\1>|) {
		$$html =~ s|<(\w+)>\s*</\1>\s*||g;
	}

	# for now, only remove <br> and <p> as whitespace inside
	# lists, where we are more likely to mistakenly run into it,
	# where it will cause more problems
	for my $re (values %lists_re) {
		while ($$html =~ m|<($re)>$WS_RE</\1>|) {
			$$html =~ s|<($re)>$WS_RE</\1>\s*||g;
		}
	}
}


# validate the structure of lists ... essentially, make sure
# they are properly nested, that everything in a list is inside
# a proper li/dt/dd, etc.

sub _validateLists {
	my($html) = @_;

	# each nested list is cleaned up and then stored in the hash,
	# to be expanded later
	my %full;
	# counter for %full
	my $j = 0;
	
	# the main loop finds paired list tags, and what is between them,
	# like <ul> ... </ul>
	while ($$html =~ m:(<($list_re)>(.*?)</\2>):sig) {
		my($whole, $list, $content) = ($1, $2, $3);
		# if we don't have an innermost list, but there's another
		# list nested inside this one, increment pos and try again
		if ($content =~ /<(?:$list_re)>/) {
			pos($$html) -= length($whole) - length("<$list>");
			next;
		}

		# the default element to use inside the list, for content
		# that is not inside any proper element
		my $inside = $lists{$list}[0] || '';
print STDERR "_validateLists logic error, no entry for list '$list'\n" if !$inside;
		my $re     = $lists_re{$list};

		# since we are looking at innermost lists, we do not
		# need to worry about stacks or nesting, just keep
		# track of the current element that we are in
		my $in    = '';

		# the secondary loop finds either a tag, or text between tags
		while ($content =~ m!\s*([^<]+|<([^\s>]+).*?>)!sig) {
			my($whole, $tag) = ($1, $2);
			next if $whole !~ /\S/;
			# we only care here if this is one that can be inside a list
			if ($tag) {
				# if open tag ...
				if ($tag =~ /^(?:$re)$/) {
					# add new close tag if we are current inside a tag
					if ($in) {
						_substitute(\$content, $whole, "</$in>", 0, 1);
						_substitute(\$content, '', $whole);
					}
					# set new open tag
					$in = $tag;
					next;

				# if close tag ...
				} elsif ($tag =~ /^\/(?:$re)$/) {
					# remove if we are not already inside a tag
					_substitute(\$content, $whole, '') unless $in;
					# this should not usually happen, as
					# we've already balanced the tags
					#warn "huh?  $tag ne /$in?" if $tag ne "/$in";
					# set to no open tag
					$in = '';
					next;
				}
			}

			# we are NOT an appropriate tag, or inside one, so
			# create one to be inside of
			if (!$in) {
				$in = $inside;
				_substitute(\$content, $whole, "<$inside>$whole");
			}
		}

		# now done with loop, so add rest of $in if there is any
		$content =~ s|(\s*)$|</$in>$1| if $in;

		# we have nesting to deal with, so replace this part
		# with a temporary token and cache the result in the hash
		$full{$j} = "<$list>$content</$list>";
		_substitute($html, $whole, "<FULL-$j>");
		$j++;
		pos($$html) = 0;  # start over
	}

	# expand it all back out
	while ($j--) {
		last if $j < 0;
		$$html =~ s/<FULL-$j>/$full{$j}/;
	}

	return 1;
}

# put a string into the current position in that string, and update
# pos() accordingly
sub _substitute {
	my($full, $old, $new, $zeropos, $ws_backup) = @_;
	# zeropos is for when we add a close tag or somesuch, but don't touch
	# the stack, and just let the code handle it by keeping pos right in
	# front of the new tag

	my $len = length $old;
	my $p = pos($$full) - $len;

	# back up insert past whitespace
	if ($ws_backup) {
		my $o = $p;
		while (substr($$full, $p-1, 1) =~ /\s/) {
			# just in case
			last if $p == 0;
			$p--;
			$len++ unless $zeropos;
		}
		if (!$zeropos && $p != $o) {
			$new .= substr($$full, $p, $o-$p);
		}
	}

	substr($$full, $p, ($zeropos ? 0 : $len)) = $new;
	pos($$full) = $p + ($zeropos ? 0 : length($new));
}
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

=item NOTITLE

Boolean which strips out title attributes for links if true

=back

=item Return value

The parsed HTML.

=back

=cut

sub parseDomainTags {
	my($html, $recommended, $notags, $notitle) = @_;
	return '' if !defined($html) || $html eq '';

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
		$html =~ s{</a ([^<>]+)>}{</a> [$1]}gi;
	} else {
		$html =~ s{</a[^<>]+>}   {</a>}gi;
	}

	$html =~ s{<a([^>]*) title="([^"]+")>} {<a$1>}gi if $notitle;
	
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
	$html = '' if !defined($html);
	$options = '' if !defined($options);
	$html =~ s{
		<a[ ]href="__SLASHLINK__"
		([^>]+)
		>
	}{
		_slashlink_to_link($1, $options)
	}igxe;
	return $html;
}

# This function mirrors the behavior of _link_to_slashlink.

sub _slashlink_to_link {
	my($sl, $options) = @_;
	my $constants = getCurrentStatic();
	my $ssi = getCurrentForm('ssi') || 0;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my %attr = $sl =~ / (\w+)="([^"]+)"/g;
	# We should probably de-strip-attribute the values of %attr
	# here, but it really doesn't matter.

	# Load up special values and delete them from the attribute list.
	my $sn = delete $attr{sn} || '';
	my $skin_id = delete $attr{sect} || '';

	# skin_id could be a name, a skid, or blank, or invalid.
	# In any case, get its skin hashref and its name.
	my $skin = undef;
	$skin = $reader->getSkin($skin_id) if $skin_id;
	$skin ||= $reader->getSkin($constants->{mainpage_skid});
	my $skin_name = $skin->{name};
	my $skin_root = $skin->{rootdir};
	if ($options && $options->{absolute}) {
		$skin_root = URI->new_abs($skin_root, $options->{absolute})
			->as_string;
	}
	my $frag = delete $attr{frag} || '';
	# Generate the return value.
	my $url = '';
	if ($sn eq 'comments') {
		$url .= qq{$skin_root/comments.pl?};
		$url .= join('&',
			map { qq{$_=$attr{$_}} }
			sort keys %attr);
		$url .= qq{#$frag} if $frag;
	} elsif ($sn eq 'article') {
		# Different behavior here, depending on whether we are
		# outputting for a dynamic page, or a static one.
		# This is the main reason for doing slashlinks at all!
		# Added 2009-04: and now it's mostly obviated :) since
		# we no longer want to output .shtml but instead will
		# trust Varnish to cache non-user-specific data, and
		# will dynamically generate the rest with .pl.
		# Set article_link_story_dynamic to 2 or greater and
		# even slashized links will be forced dynamic.
		my $force_dyn = $constants->{article_link_story_dynamic} > 1 ? 1 : 0;
		if (!$force_dyn && $ssi) {
			$url .= qq{$skin_root/};
			$url .= qq{$skin_name/$attr{sid}.shtml};
			$url .= qq{?tid=$attr{tid}} if $attr{tid};
			$url .= qq{#$frag} if $frag;
		} else {
			$url .= qq{$skin_root/article.pl?};
			$url .= join('&',
				map { qq{$_=$attr{$_}} }
				sort keys %attr);
			$url .= qq{#$frag} if $frag;
		}
	}
	return q{<a href="} . strip_urlattr($url) . q{">};
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
		( < (/?) a \b[^>]* > )
	}{
		my $old_in_a = $in_a;
		my $new_in_a = !$2;
		$in_a = $new_in_a;
		(($old_in_a && $new_in_a) ? '</a>' : '') . $1
	}gixe;
	$html .= '</a>' if $in_a;

	# Now, since we know that every <A> has a </A>, this pattern will
	# match and let the subroutine above do its magic properly.
	# Note that, since a <A> followed immediately by </A> will not
	# only fail to appear in a browser, but would also look goofy if
	# followed by a [domain.tag], in such a case we simply remove the
	# <A></A> pair entirely.

	$html =~ s
	{
		(<a\s+href="		# $1 is the whole <A HREF...>
			([^">]*)	# $2 is the URL (quotes guaranteed to
					# be there thanks to approveTag)
		">)
		(.*?)			# $3 is whatever's between <A> and </A>
		</a\b[^>]*>
	}{
		$3	? _url_to_domain_tag($1, $2, $3)
			: ''
	}gisex;

	# If there were unmatched <A> tags in the original, balanceTags()
	# would have added the corresponding </A> tags to the end.  These
	# will stick out now because they won't have domain tags.  We
	# know we've added enough </A> to make sure everything balances
	# and doesn't overlap, so now we can just remove the extra ones,
	# which are easy to tell because they DON'T have domain tags.

	$html =~ s{</a>}{}gi;

	return $html;
}

sub email_to_domain {
	my($email) = @_;
	my $addr = Mail::Address->new('', $email);
	return '' if !$addr;
	my $host = $addr->host();
	return '' if !$host;
	return fullhost_to_domain($host);
}

sub fullhost_to_domain {
	my($fullhost) = @_;
	my $info = lc $fullhost;
	if ($info =~ m/^([\d.]+)\.in-addr\.arpa$/) {
		$info = join('.', reverse split /\./, $1);
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
			$info = join('.', @info[-3..-1]);
		}
	}
	return $info;
}

sub _url_to_domain_tag {
	my($href, $link, $body) = @_;
	my $absolutedir = getCurrentSkin('absolutedir');
	my $uri = URI->new_abs($link, $absolutedir);
	my $uri_str = $uri->as_string;

	my($info, $scheme) = ('', '');
	if ($uri->can('host')) {
		my $host;
		unless (($host = $uri->host)
				&&
			$uri->can('scheme')
				&&
			($scheme = $uri->scheme)
		) {
			# If this URL is malformed in a particular
			# way ("scheme:///host"), treat it the way
			# that many browsers will (rightly or
			# wrongly) treat it.
			if ($uri_str =~ s|$scheme:///+|$scheme://|) {
				$uri = URI->new_abs($uri_str, $absolutedir);
				$uri_str = $uri->as_string;
				$host = $uri->host;
			}
		}
		$info = fullhost_to_domain($host) if $host;
	}

	if (!$info && ($scheme || (
		$uri->can('scheme') && ($scheme = $uri->scheme)
	))) {
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
	}

	$info =~ tr/A-Za-z0-9.-//cd if $info;

	if (length($info) == 0) {
		$info = '?';
	} elsif (length($info) >= 25) {
		$info = substr($info, 0, 10) . '...' . substr($info, -10);
	}

	# Add a title tag to make this all friendly for those with vision
	# and similar issues -Brian
	$href =~ s/>/ title="$info">/ if $info ne '?';
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
	my $gSkin = getCurrentSkin();
	my $virtual_user = getCurrentVirtualUser();
	my $retval = "$pre$url$post";
	my $abs = $gSkin->{absolutedir};
	my $skins = $reader->getSkins();
#print STDERR "_link_to_slashlink begin '$url'\n";

	if (!defined($urla{$virtual_user})) {
		# URLs may show up in any skins, which means when absolutized
		# their host may be either the main one or a sectional one.
		# We have to allow for any of those possibilities.
		my @skin_urls = grep { $_ }
			map { $skins->{$_}{rootdir} }
			sort keys %$skins;
		my %all_urls = ( );
		for my $url ($abs, @skin_urls) {
			my $new_url = URI->new($url);
			# Remove the scheme to make it relative (schemeless).
			# XXXSECTIONTOPICS hey, skin urls should already be schemeless, test this
			# XXXSKIN - no, urls are not schemeless, rootdirs are
			# (and they are generated, at this point, from urls)
			$new_url->scheme(undef);
			my $new_url_q = quotemeta($new_url->as_string);
			$all_urls{"(?:https?:)?$new_url"} = 1;
		}
		my $any_host = "(?:"
			. join("|", sort keys %all_urls)
			. ")";
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
			# XXXSECTIONTOPICS
			my $primaryskid = $reader->getDiscussion(
				$attr{sid}, 'primaryskid');
			$attr{sect} = $skins->{$primaryskid}{name};
			$attr{tid} = $reader->getDiscussion(
				$attr{sid}, 'topic');
		} else {
			# sid is a story id
			# XXXSECTIONTOPICS
			my $primaryskid = $reader->getStory( 
				$attr{sid}, 'primaryskid', 1);
			$attr{sect} = $skins->{$primaryskid}{name};
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
		$retval = q{<a href="__SLASHLINK__" }
			. join(" ",
				map { qq{$_="} . strip_attribute($attr{$_}) . qq{"} }
				sort keys %attr)
			. q{>};
	}

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
	return '' if !defined($text) || length($text) == 0;

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
			$text = chopEntity($text, $len2)
				. ' ... '
				. chopEntity($text, $len2, 1);
		} elsif ($len >= 8) {
			$text = chopEntity($text, $len-4)
				. ' ...';
		} else {
			$text = chopEntity($text, $len);
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

#========================================================================

=head2 getRandomWordFromDictFile (FILENAME, OPTIONS)

Pulls a random word from a dictionary file on disk (e.g. /usr/dict/words)
based on certain parameters.

=over 4

=item Parameters

=over 4

=item FILENAME

The name of the disk file to read from.

=back

=item OPTIONS

min_chars is the word length minimum, or 1 by default.

max_chars is the word length maximum, or 99 by default.

word_regex is the regex to match a word; by default this will include
all words of all-lowercase letters (e.g. no "O'Reilly") between the
min_chars and max_chars lengths.

excl_regexes is an arrayref of regular expressions.  If any one of them
matches a word it will not be returned.

=item Return value

The word found.

=back

=cut

sub getRandomWordFromDictFile {
	my($filename, $options) = @_;
	my $min_chars = $options->{min_chars} || 1;
	$min_chars = 1 if $min_chars < 1;
	my $max_chars = $options->{max_chars} || 99;
        my $word_regex = $options->{word_regex} || qr{^([a-z]{$min_chars,$max_chars})$};
	my $excl_regexes = $options->{excl_regexes} || [ ];

	return '' if !$filename || !-r $filename;
        my $filesize = -s $filename;
        return '' if !$filesize;
        my $word = '';

        # Start looking in the dictionary at a random location.
        my $start_seek = int(rand($filesize-$max_chars));
        my $fh;
        if (!open($fh, "<", $filename)) {
                return '';
        }
        if (!seek($fh, $start_seek, 0)) {
                return '';
        }
        my $line = <$fh>;		# throw first (likely partial) line away
        my $reseeks = 0;		# how many times have we moved the seek point?
        my $bytes_read_total = 0;	# how much have we read in total?
        my $bytes_read_thisseek = 0;	# how much read since last reseek?
        LINE: while ($line = <$fh>) {
                if (!$line) {
                        # We just hit the end of the file.  Roll around
                        # to the beginning.
                        if (!seek($fh, 0, 0)) {
                                last LINE;
                        }
                        ++$reseeks;
                        next LINE;
                }
                $bytes_read_total += length($line);
                $bytes_read_thisseek += length($line);
                if ($bytes_read_thisseek >= $filesize * 0.001) {
                        # If we've had to read through more than 0.1% of
                        # the dictionary to find a word of the appropriate
                        # length, we're obviously in a part of the
                        # dictionary that doesn't have any acceptable words
                        # (maybe a section with all-capitalized words).
                        # Try another section.
                        if (!seek($fh, int(rand($filesize-$max_chars)), 0)) {
                                last LINE;
                        }
                        $line = <$fh>; # throw likely partial away
                        ++$reseeks;
                        $bytes_read_thisseek = 0;
                }
                if ($bytes_read_total >= $filesize) {
                        # If we've read a total of more than the complete
                        # file and haven't found a word, give up.
                        last LINE;
                }
                chomp $line;
                if ($line =~ $word_regex) {
                        $word = $1;
                        for my $r (@$excl_regexes) {
                                if ($word =~ /$r/) {
                                        # Skip this word.
#print STDERR "word=$word start_seek=$start_seek SKIPPING regex=$r\n";
                                        $word = '';
                                        next LINE;
                                }
                        }
                        last LINE;
                }
        }
        close $fh;
#print STDERR "word=$word start_seek=$start_seek bytes_read_thisseek=$bytes_read_thisseek bytes_read_total=$bytes_read_total\n";
        return $word;
}

sub getUrlsFromText {
	my(@texts) = @_;
	my %urls = ( );
	for my $text (@texts) {
		next unless $text;
		my $tokens = HTML::TokeParser->new(\$text);
		next unless $tokens;
		while (my $token = $tokens->get_tag('a')) {
			my $linkurl = $token->[1]{href};
			next unless $linkurl;
			my $canon = URI->new($linkurl)->canonical()->as_string();
			$urls{$canon} = 1;
		}
	}
	return [ keys %urls ];
}

########################################################
# fix parameter input that should be integers
sub fixint {
	my($int) = @_;
	return if !defined($int);
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
# If you change createSid() for your site, change regexSid() too.
sub createSid {
	my($bogus_sid) = @_;
	# yes, this format is correct, don't change it :-)
	my $sidformat = '%02d/%02d/%02d/%02d%0d2%02d';
	# Create a sid based on the current time.
	my @lt;
	my $start_time = time;
	if ($bogus_sid) {
		# If we were called being told that there's at
		# least one sid that is invalid (already taken),
		# then look backwards in time until we find it,
		# then go one second further.
		my $loops = 1000;
		while (--$loops) {
			$start_time--;
			@lt = localtime($start_time);
			$lt[5] %= 100; $lt[4]++; # year and month
			last if $bogus_sid eq sprintf($sidformat, @lt[reverse 0..5]);
		}
		if ($loops) {
			# Found the bogus sid by looking
			# backwards.  Go one second further.
			$start_time--;
		} else {
			# Something's wrong.  Skip ahead in
			# time instead of back (not sure what
			# else to do).
			$start_time = time + 1;
		}
	}
	@lt = localtime($start_time);
	$lt[5] %= 100; $lt[4]++; # year and month
	return sprintf($sidformat, @lt[reverse 0..5]);
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
	my $gSkin = getCurrentSkin();
	my $use_stemming = $constants->{stem_uncommon_words};
	my $language = $constants->{rdflanguage} || "EN-US";
	$language = uc($language);
	my $stemmer = Lingua::Stem->new(-locale => $language);
	$stemmer->stem_caching({ -level => 2 });
	my $text_return_hr = {};
	my @word_stems;


	# Return a hashref;  keys are the words, values are hashrefs
	# with the number of times they appear and so on.
	my $wordcount = $args_hr->{output_hr} || { };

	for my $key (keys %$args_hr) {

		# The default weight for each chunk of text is 1.
		my $weight_factor = $args_hr->{$key}{weight} || 1;

		my $text = $args_hr->{$key}{text} || '';

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
			my $uri = URI->new_abs($url, $gSkin->{absolutedir})
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
			my $log_word = $word;
			if ($use_stemming) {
				# For performance reasons we don't want to stem story text for all 
				# stories we are comparing to in getSimilarStories.
				# Instead we make sure the stems we save are substrings of the word
				# anchored at the beginning
				#
				# A breakdown of stem/word comparisons based on /usr/dict/words
				# 70%    $stem eq $word
				# 93%    $stem is a substring of $word anchored at the beginning
				# 100%   $stem w/o its last letter is a substring of $word anchored at the beginning
				#
				# For now use the stem only if it a substring of the word anchored at the beginning
				# otherwise use the complete word.  That way we can do a pattern match to check against
				# older stories rather than stemming them for comparison
				

				my $stems = $stemmer->stem($word);
				$log_word = $stems->[0];
				$log_word = $word if $word!~/^\Q$log_word\E/i;
				push @word_stems, $log_word;
			}

			$wordcount->{lc $log_word}{weight} += $ww;
		}
		my %uniquewords = map { ( lc($_), 1 ) } $use_stemming ? @word_stems: @words;
		for my $word (keys %uniquewords) {
			$wordcount->{$word}{count}++;
		}
	}
	$stemmer->clear_stem_cache();

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

##################################################################
sub sitename2filename {
	my($section) = @_;
	$section ||= '';
	my $filename = '';

	# XXXSKIN - hardcode 'index' for the sake of RSS feeds
	if ($section eq 'mainpage') {
		$filename = 'index';
	} elsif ($section ne 'light') {
		$filename = $section || lc getCurrentStatic('sitename');
	} else {
		$filename = lc getCurrentStatic('sitename');
	}

	$filename =~ s/\W+//g;

	return $filename;
}

##################################################################
# counts total visible kids for each parent comment
sub countTotalVisibleKids {
	my($comments, $pid) = @_;

	my $constants        = getCurrentStatic();
	my $total            = 0;
	my $last_updated     = '';
	my $last_updated_uid = 0;
	$pid               ||= 0;

	$total += $comments->{$pid}{visiblekids} || 0;

	for my $cid (@{$comments->{$pid}{kids}}) {
		my($num_kids, $date_test, $uid) =
			countTotalVisibleKids($comments, $cid);
		$total += $num_kids;
	}

	$comments->{$pid}{totalvisiblekids} = $total;

	return($total, $last_updated, $last_updated_uid);
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

	my $topics = $slashdb->getTopics;
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

# check whether url is correctly formatted and has a scheme that is allowed for bookmarks and submissions
sub validUrl {
	my($url) = @_;
	my $constants = getCurrentStatic();
	my $fudgedurl = fudgeurl($url);
	
	my @allowed_schemes = split(/\|/, $constants->{bookmark_allowed_schemes} || "http|https");
	my %allowed_schemes = map { $_ => 1 } @allowed_schemes;

	my $scheme;
	
	if ($fudgedurl) {
		my $uri = new URI $fudgedurl;
		$scheme = $uri->scheme if $uri && $uri->can("scheme");
	}		
	return ($fudgedurl && $scheme && $allowed_schemes{$scheme});
}


#################################################################
sub fixStory {
	my($str, $opts) = @_; 

	if ($opts->{sub_type} && $opts->{sub_type} eq 'plain') {
		$str = strip_plaintext(url2html($str));
	} else {
		$str = strip_html(url2html($str));
	}

	# remove leading and trailing whitespace
	$str =~ s/^$Slash::Utility::Data::WS_RE+//io;
	$str =~ s/$Slash::Utility::Data::WS_RE+$//io;

	# and let's just get rid of these P tags; we don't need them, and they
	# cause too many problems in submissions
	unless (getCurrentStatic('submit_keep_p')) {
		$str =~ s|</p>||g;
		$str =~ s|<p(?: /)?>|<br><br>|g;
	}

	# smart conversion of em dashes to real ones
	# leave if - has nonwhitespace on either side, otherwise, convert
	unless (getCurrentStatic('submit_keep_dashes')) {
		$str =~ s/(\s+-+\s+)/ &mdash; /g;
	}

	$str = balanceTags($str, { deep_nesting => 1 });

	# do it again, just in case balanceTags added more ...
	$str =~ s/^$Slash::Utility::Data::WS_RE+//io;
	$str =~ s/$Slash::Utility::Data::WS_RE+$//io;

	return $str;
}

#################################################################
sub processSub {
	my($home, $known_to_be) = @_;

	my $proto = qr[^(?:mailto|http|https|ftp|gopher|telnet):];

	if 	($home =~ /\@/	&& ($known_to_be eq 'mailto' || $home !~ $proto)) {
		$home = "mailto:$home";
	} elsif	($home ne ''	&& ($known_to_be eq 'http'   || $home !~ $proto)) {
		$home = "http://$home";
	}

	return $home;
}






1;

__END__


=head1 SEE ALSO

Slash(3), Slash::Utility(3).

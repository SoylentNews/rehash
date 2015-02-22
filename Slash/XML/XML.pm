# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::XML;

=head1 NAME

Slash::XML - Perl extension for Slash

=head1 SYNOPSIS

	use Slash::XML;
	xmlDisplay(%data);

=head1 DESCRIPTION

Slash::XML aids in creating XML.  Right now, only RSS is supported.


=head1 EXPORTED FUNCTIONS

=cut

use strict;
use Digest::MD5 'md5_hex';
use Encode 'encode_utf8';
use Time::Local;
use Slash;
use Slash::Utility;

use base 'Exporter';

our $VERSION = $Slash::Constants::VERSION;
our @EXPORT = qw(xmlDisplay);

# FRY: There must be layers and layers of old stuff down there!

#========================================================================

=head2 xmlDisplay(TYPE, PARAM [, OPTIONS])

Creates XML data.

=over 4

=item Parameters

=over 4

=item TYPE

The XML type, which determines which XML creation routine to call.
Right now, supports only "rss" which calls XML::RSS::create().

=item PARAM

A hashref of parameters to pass to the XML creation routine.

=item OPTIONS

Hashref of options.  Currently supported options are below.
If OPTIONS is the value C<1> instead of a hashref, that will
be the same as if the hashref were C<{ Return =E<gt> 1 }>.

=over 4

=item Return

Boolean for whether to print (false) or return (true) the
processed template data.  Default is to print output via
Apache, with full HTML headers.

=item filename

A name for the generated filename Apache sends out.  "Unsafe"
chars are replaced, and ".xml" is appended if there is no "."
in the name already.  "foo bar" becomes "foo_bar.xml" and
"foo bar.rss" becomes "foo_bar.rss".

=back

=back

=item Return value

If OPTIONS-E<gt>{Return} is true, the XML data.
Otherwise, returns true/false for success/failure.

=back

=cut

sub xmlDisplay {
	my($type, $param, $opt) = @_;

	my($class, $file);
	$type =~ s/[^\w]+//g;
	for my $try (uc($type), $type, ucfirst($type)) {
		$class = "Slash::XML::$try";
		$file  = "Slash/XML/$try.pm";

		if (!exists($INC{$file}) && !eval("require $class")) {
			next;
		} elsif (exists($INC{$file}) && !$class->can('create')) {
			delete $INC{$file};
			next;
		} else {
			last;
		}
	}

	# didn't work
	if (!exists($INC{$file})) {
		errorLog($@);
		return;
	}

	my $content = $class->create($param);
	if (!$content) {
		# I don't think we really care, actually ... do we?
# 		errorLog("$class->create returned no content");
		return;
	}

	if (! ref $opt) {
		$opt = ($opt && $opt == 1) ? { Return => 1 } : {};
	}

	if ($opt->{Return}) {
		return $content;
	} else {
		my $r = Apache2::RequestUtil->request;
		my $content_type = 'text/xml';
		my $suffix = 'xml';

		# normalize for etag
		my $temp = $content;

		if ($type =~ /^rss$/i) {
			$temp =~ s|[dD]ate>[^<]+</||;
			$content_type = 'application/rss+xml';
			$suffix = 'rss';
		} elsif ($type =~ /^atom$/) {
			$temp =~ s|updated>[^<]+</||;
			$content_type = 'application/atom+xml';
			$suffix = 'atom';
		}

		$opt->{filename} .= ".$suffix" if $opt->{filename} && $opt->{filename} !~ /\./;

		http_send({
			content_type	=> $content_type,
			filename	=> $opt->{filename},
			etag		=> md5_hex( encode_utf8($temp) ),
			dis_type	=> 'inline',
			content		=> $content
		});
	}
}

#========================================================================

=head2 date2iso8601([TIME, Z])

Return a standard ISO 8601 time string.

=over 4

=item Parameters

=over 4

=item TIME

Some sort of string in GMT that can be parsed by Date::Parse.
If no TIME given, uses current time.

=item Z

By default, strings of the form "2005-04-18T22:38:55+00:00" are returned,
where the "+00:00" denotes the time zone differential.  If Z is true, the
alternate form "2005-04-18T22:38:55Z" will be used, where the string is
forced into UTC and "Z" is used to denote the fact.

Both forms should be acceptable, but some applications may require one
or the other.

=back

=item Return value

The time string.

=back

=cut

sub date2iso8601 {
	my($self, $time, $z) = @_;
	if ($time) {	# force to GMT
		$time .= ' GMT' unless $time =~ / GMT$/;
	} else {	# get current seconds
		my $t = defined $time ? 0 : time();
		$time = $z ? scalar gmtime($t) : scalar localtime($t);
	}

	# calculate timezone differential from GMT
	my $diff = 'Z';
	unless ($z) {
		$diff = (timelocal(localtime) - timelocal(gmtime)) / 36;
		($diff = sprintf '%+0.4d', $diff) =~ s/(\d{2})$/:$1/;
	}

	return scalar timeCalc($time, "%Y-%m-%dT%H:%M:%S$diff", 0);
}

#========================================================================

=head2 encode(VALUE [, KEY])

Encodes the data to put it into the XML.  Normally will encode
assuming the parsed data will be printed in HTML.  See KEY.

=over 4

=item Parameters

=over 4

=item VALUE

Value to be encoded.

=item KEY

If KEY is "link", then data will be encoded so as NOT to assume
the parsed data will be printed in HTML.

=back

=item Return value

The encoded data.

=item Dependencies

See xmlencode() and xmlencode_plain() in Slash::Utility.

=back

=cut

sub encode {
	my($self, $value, $key) = @_;
	$key ||= '';
	my $return = $key eq 'link'
		? xmlencode_plain($value)
		: xmlencode($value);
	return $return;
}

1;

__END__

=head1 SEE ALSO

Slash(3), Slash::Utility(3), XML::Parser(3), XML::RSS(3).

# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::XML::Atom;

=head1 NAME

Slash::XML::Atom - Perl extension for Slash


=head1 SYNOPSIS

	use Slash::XML;
	xmlDisplay(%data);


=head1 DESCRIPTION

LONG DESCRIPTION.


=head1 EXPORTED FUNCTIONS

=cut

use strict;
use Slash;
use Slash::Utility;
use XML::Parser::Expat;
use base 'Slash::XML';
use base 'Slash::XML::RSS';

our $VERSION = $Slash::Constants::VERSION;

my %syn_ok_fields = (
	'updateBase' => '',
	'updateFrequency' => '',
	'updatePeriod' => '',
);

#========================================================================

=head2 create(PARAM)

Creates Atom feed.

=over 4

=item Parameters

=over 4

=item PARAM

Hashref of parameters.  Currently supported options are below.

=over 4

=item version

Defaults to "1.0".

=item rdfencoding

Defaults to "rdfencoding" in vars.

=item title

Defaults to "sitename" in vars.

=item description

Defaults to "slogan" in vars.

=item link

Defaults to "absolutedir" in vars.

=item date

Defaults to current date.  See date2iso8601().

=item subject

Defaults to "rdfsubject" in vars.

=item language

Defaults to "rdflanguage" in vars.

=item creator

Defaults to "adminmail" in vars.

=item publisher

Defaults to "rdfpublisher" in vars.

=item rights

Defaults to "rdfrights" in vars.

=item updatePeriod

Defaults to "rdfupdateperiod" in vars.

=item updateFrequency

Defaults to "rdfupdatefrequency" in vars.

=item updateBase

Defaults to "rdfupdatebase" in vars.

=item image

If scalar, then just prints the default image data if scalar is true.
If hashref, then may have "title", "url", and "link" passed.

=item textinput

If scalar, then just prints the default textinput data if scalar is true.
If hashref, then may have "title", "description", "name", and "link" passed.

=item items

An arrayref of hashrefs.  If the "story" key of the hashref is true,
then the item is passed to rss_story().  Otherwise, "title" and "link" must
be defined keys, and any other single-level key may be defined
(no multiple level hash keys).

=back

=back

=item Return value

The complete RSS data as a string.

=back

=cut


sub create {
	my($class, $param) = @_;
	return unless exists $param->{items};

	my $rss = Slash::XML::RSS->create({%$param, nocreate => 1});

	my $atom = {%$rss};
	bless $atom, __PACKAGE__;
	my $data = as_atom_1_0($atom);
	return $data;
}

# copied from as_rss_1_0 in XML::RSS ... kinda ugly, but oh well
# http://atompub.org/2005/07/11/draft-ietf-atompub-format-10.html
sub as_atom_1_0 {
	my($self) = @_;
	my($val, $output);

	# XML declaration
	$output = qq[<?xml version="1.0" encoding="$self->{encoding}"?>\n\n];

	# namespaces declaration
	$output .= qq[<feed\n xmlns="http://www.w3.org/2005/Atom"\n];

	# print all imported namespaces
	while (my($k, $v) = each %{$self->{modules}}) {
		next if $v =~ /^(?:dc|rdf|taxo|admin)$/;
		$output .= qq[ xmlns:$v="$k"\n];
	}

	my $lang = '';
	if ($self->{channel}{dc}{language}) {
		$val = $self->{channel}{dc}{language};
		$lang = qq[ xml:lang="$val"\n];
	}

	$output .= qq[$lang>\n\n];

	# title
	$output .= atom_encode($self, 'title', $self->{channel}{title});

	# id/link
	$val = $self->{channel}{'link'};
	$output .= qq[<id>$val</id>\n];
	$output .= qq[<link href="$val"/>\n];

	# self link
	$val = '';
	if ($self->{channel}{selflink}) {
		$val = $self->{channel}{selflink};
	} elsif ($ENV{REQUEST_URI}) {
		(my $host = $ENV{HTTP_HOST}) =~ s/:\d+$//;
		my $scheme = apacheConnectionSSL() ? 'https' : 'http';
		$val = $self->encode("$scheme://$host$ENV{REQUEST_URI}");
	}
	$output .= qq[<link rel="self" href="$val"/>\n] if $val;

	# description
	$output .= atom_encode($self, 'subtitle', $self->{channel}{description});

	# copyright
	$val = $self->{channel}{dc}{rights} || $self->{channel}{copyright};
	$output .= atom_encode($self, 'rights', $val);

	# publication date
	$val = $self->{channel}{dc}{date} || $self->{channel}{pubDate} || $self->{channel}{lastBuildDate};
	$output .= atom_encode($self, 'updated', $val);

	my(%author);
	# this is specific to how Slash uses publisher and creator
	$author{name}  = $self->{channel}{dc}{publisher} || $self->{channel}{managingEditor};
	$author{email} = $self->{channel}{dc}{creator}   || $self->{channel}{webMaster};

	if ($author{name} || $author{email}) {
		$output .= "<author>\n";
		for my $field (qw(name email)) {
			$output .= ' ' . atom_encode($self, $field, $author{$field}) if $author{$field};
		}
		$output .= "</author>\n";
	}

	# subject
	if ($self->{channel}{dc}{subject}) {
		$val = $self->{channel}{dc}{subject};
		$output .= qq[<category term="$val"/>\n];
	}

	# Syndication module
	foreach my $syn ( keys %syn_ok_fields ) {
		$output .= atom_encode($self, "syn:$syn", $self->{channel}{syn}{$syn});
	}



	# Ad-hoc modules
	while (my($url, $prefix) = each %{$self->{modules}}) {
		next if $prefix =~ /^(dc|syn|taxo)$/;
		while ( my($el, $value) = each %{$self->{channel}{$prefix}} ) {
			$output .= atom_encode($self, "$prefix:$el", $value);
		}
  	}

	if ($self->{image}{url}) {
		$output .= atom_encode($self, 'logo', $self->{image}{url});
	}

	$output .= "\n";

	################
	# item element #
	################
	foreach my $item (@{$self->{items}}) {
		if ($item->{title}) {
			$output .= "<entry>\n";

			$val = $item->{'link'};
			$output .= qq[<id>$val</id>\n];

			$output .= atom_encode($self, 'title', $item->{title});

			# $val still same as directly above
			$output .= qq[<link href="$val"/>\n];

			# XXXX if at some point we can know this is the whole text
			# of the article, it should be "content" instead of
			# "summary"
			if ($item->{description}) {
				$output .= atom_encode($self, 'summary', $item->{description});
			}

			# Dublin Core module
			$output .= atom_encode($self, 'updated', $item->{dc}{date});
			if ($item->{dc}{creator}) {
				$output .= "<author>\n";
				$output .= ' ' . atom_encode($self, 'name', $item->{dc}{creator});
				$output .= "</author>\n";
			}

			if ($item->{dc}{subject}) {
				$val = $item->{dc}{subject};
				$output .= qq[<category term="$val"/>\n];
			}

			# Ad-hoc modules
			while (my($url, $prefix) = each %{$self->{modules}}) {
				next if $prefix =~ /^(dc|syn|taxo)$/;
				while ( my($el, $value) = each %{$item->{$prefix}} ) {
					$output .= atom_encode($self, "$prefix:$el", $value);
				}
  			}

			# end item element
			$output .= qq[</entry>\n\n];
		}

	}

    $output .= '</feed>';

    return $output;
}


# some of this from Sam Ruby
sub atom_encode {
	my($self, $element, $value) = @_;
	return '' unless $value;

	# XXX make this more robust?
	my $type = $value =~ /(?:&amp;#?\w+;|&[lg]t;)/ ? 'html' : 'text';

	# try parsing.  If well formed, replace the value and type
	if ($type eq 'html' && $value =~ /&[lg]t;/) {
		eval {
			my $unescaped = $value;
			$unescaped =~ s/&lt;/</g;
			$unescaped =~ s/&gt;/>/g;
			$unescaped =~ s/&amp;/&/g;

			my $parser = new XML::Parser::Expat;
			$parser->parsestring("<xml>$unescaped</xml>");
    
			$value = qq[<div xmlns="http://www.w3.org/1999/xhtml">$unescaped</div>];
			$type  = 'xhtml';
		};
	}

	if ($type eq 'text') {
		return qq[<$element>$value</$element>\n];
	} else {
		return qq[<$element type="$type">$value</$element>\n];
	}
}

1;

__END__


=head1 SEE ALSO

Slash(3), Slash::XML(3).

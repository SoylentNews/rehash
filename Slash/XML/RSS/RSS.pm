# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::XML::RSS;

=head1 NAME

Slash::XML::RSS - Perl extension for Slash


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
use XML::RSS;
use base 'Slash::XML';
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;


#========================================================================

=head2 create(PARAM)

Creates RSS.

=over 4

=item Parameters

=over 4

=item PARAM

Hashref of parameters.  Currently supported options are below.

=over 4

=item version

Defaults to "1.0".  May be >= "1.0", >= "0.91", or "0.9".

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
	my $self = bless {}, $class;

	return unless exists $param->{items};

	my $constants = getCurrentStatic();

	my $version  = $param->{version}     || '1.0';
	my $encoding = $param->{rdfencoding} || $constants->{rdfencoding};

	my $rss = XML::RSS->new(
		version		=> $version,
		encoding	=> $encoding,
	);

	# set defaults
	my %channel = (
		title		=> $constants->{sitename},
		description	=> $constants->{slogan},
		'link'		=> $constants->{absolutedir} . '/',

		# dc
		date		=> $self->date2iso8601(),
		subject		=> $constants->{rdfsubject},
		language	=> $constants->{rdflanguage},
		creator		=> $constants->{adminmail},
		publisher	=> $constants->{rdfpublisher},
		rights		=> $constants->{rdfrights},

		# syn
		updatePeriod	=> $constants->{rdfupdateperiod},
		updateFrequency	=> $constants->{rdfupdatefrequency},
		updateBase	=> $constants->{rdfupdatebase},
	);

	# let $param->{channel} override
	for (keys %channel) {
		my $value = defined $param->{channel}{$_}
			? $param->{channel}{$_}
			: $channel{$_};
		$channel{$_} = $self->encode($value, $_);
	}

	if ($version >= 1.0) {
		# move from root to proper namespace
		for (qw(date subject language creator publisher rights)) {
			$channel{dc}{$_} = delete $channel{$_};
		}

		for (qw(updatePeriod updateFrequency updateBase)) {
			$channel{syn}{$_} = delete $channel{$_};
		}

		my($item) = @{$param->{items}};
		$rss->add_module(
			prefix  => 'slash',
			uri     => 'http://purl.org/rss/1.0/modules/slash/',
		) if $item->{story};

	} elsif ($version >= 0.91) {
		# fix mappings for 0.91
		$channel{language}       = substr($channel{language}, 0, 2);
		$channel{pubDate}        = delete $channel{date};
		$channel{managingEditor} = delete $channel{publisher};
		$channel{webMaster}      = delete $channel{creator};
		$channel{copyright}      = delete $channel{rights};

	} else {  # 0.9
		for (keys %channel) {
			delete $channel{$_} unless /^(?:link|title|description)$/;
		}
	}

	# OK, now set it
	$rss->channel(%channel);

	# may be boolean
	if ($param->{image}) {
		# set defaults
		my %image = (
			title	=> $channel{title},
			url	=> $constants->{rdfimg},
			'link'	=> $channel{'link'},
		);

		# let $param->{image} override
		if (ref($param->{image}) eq 'HASH') {
			for (keys %image) {
				my $value = defined $param->{image}{$_}
					? $param->{image}{$_}
					: $image{$_};
				$image{$_} = $self->encode($value, $_);
			}
		}

		# OK, now set it
		$rss->image(%image);
	}

	# may be boolean
	if ($param->{textinput}) {
		# set defaults
		my %textinput = (
			title		=> 'Search ' . $constants->{sitename},
			description	=> 'Search ' . $constants->{sitename} . ' stories',
			name		=> 'query',
			'link'		=> $channel{'link'} . 'search.pl',
		);

		# let $param->{textinput} override
		if (ref($param->{image}) eq 'HASH') {
			for (keys %textinput) {
				my $value = defined $param->{textinput}{$_}
					? $param->{textinput}{$_}
					: $textinput{$_};
				$textinput{$_} = $self->encode($value, $_);
			}
		}

		# OK, now set it
		$rss->textinput(%textinput);
	}

	my @items;
	for my $item (@{$param->{items}}) {
		if ($item->{story} || (
			defined($item->{title})  && $item->{title} ne ""
				&&
			defined($item->{'link'}) && $item->{'link'} ne ""
		)) {
			my $encoded_item = {};

			# story is hashref to be deleted, containing
			# story data
			if ($item->{story}) {
				# set up story params in $encoded_item ref
				$self->rss_story($item, $encoded_item, $version, \%channel);
			}

			for my $key (keys %$item) {
				if ($key eq 'description') {
					if ($version >= 0.91) {
						my $desc = $self->rss_item_description($item->{$key});
						$encoded_item->{$key} = $desc if $desc;
					}
				} else {
					$encoded_item->{$key} = $self->encode($item->{$key}, $key);
				}
			}

			push @items, $encoded_item if keys %$encoded_item;
		}
	}

	# technically, you *must* have items, but that can be
	# checked by the caller, so we are just gonna return
	# the incomplete RSS -- pudge
# 	return unless @items;
	for (@items) {
		$rss->add_item(%$_);
	}

	return $rss->as_string;
}

#========================================================================

=head2 rss_story(ITEM, ENCODED_ITEM, VERSION)

Set up a story item for RSS.  Called from create().

=over 4

=item Parameters

=over 4

=item ITEM

The item hashref passed in the items param key passed to xmlDisplay().

=item ENCODED_ITEM

The prepared encoded data from ITEM.

=item VERSION

The VERSION as defined in create().  Does the Right Thing for >= "1.0",
>= "0.91", and "0.9".

=back

=item Return value

The encoded item.

=back

=cut

sub rss_story {
	my($self, $item, $encoded_item, $version, $channel) = @_;

	# delete it so it won't be processed later
	my $story = delete $item->{story};
	my $constants = getCurrentStatic();
	my $slashdb   = getCurrentDB();

	my $topics = $slashdb->getTopics();

	$encoded_item->{title}  = $self->encode($story->{title});
	$encoded_item->{'link'} = $self->encode("$channel->{'link'}article.pl?sid=$story->{sid}", 'link');

	if ($version >= 0.91) {
		my $desc = $self->rss_item_description($item->{description} || $story->{introtext});
		$encoded_item->{description} = $desc if $desc;
	}

	if ($version >= 1.0) {
		my $slashdb   = getCurrentDB();

		$encoded_item->{dc}{date}    = $self->encode($self->date2iso8601($story->{'time'}));
		$encoded_item->{dc}{subject} = $self->encode($topics->{$story->{tid}}{name});
		$encoded_item->{dc}{creator} = $self->encode($slashdb->getUser($story->{uid}, 'nickname'));

		$encoded_item->{slash}{section}    = $self->encode($story->{section});
		$encoded_item->{slash}{comments}   = $self->encode($story->{commentcount});
		$encoded_item->{slash}{hitparade}  = $self->encode($story->{hitparade});
		$encoded_item->{slash}{department} = $self->encode($story->{dept})
			if $constants->{use_dept};
	}

	return $encoded_item;
}

#========================================================================

=head2 rss_item_description(DESC)

Set up an item description.  If rdfitemdesc in the vars table is "1",
then prints an item's description.  If it is some other true value,
it will chop the description to that length.  If it is false, then no
description for the item will be printed.

=over 4

=item Parameters

=over 4

=item DESC

The description.

=back

=item Return value

The fixed description.

=back

=cut


sub rss_item_description {
	my($self, $desc) = @_;

	my $constants = getCurrentStatic();

	if ($constants->{rdfitemdesc}) {
		# no HTML
		$desc = strip_notags($desc);
		$desc =~ s/\s+/ /g;
		$desc =~ s/ $//;

		# keep $desc as-is if == 1
		if ($constants->{rdfitemdesc} != 1) {
			if (length($desc) > $constants->{rdfitemdesc}) {
				$desc = substr($desc, 0, $constants->{rdfitemdesc});
				$desc =~ s/\S+$//;
				$desc .= '...';
			}
		}

		$desc = $self->encode($desc);		
	} else {
		undef $desc;
	}

	return $desc;
}

1;

__END__


=head1 SEE ALSO

Slash(3), Slash::XML(3).

=head1 VERSION

$Id$

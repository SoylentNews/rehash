# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

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

our $VERSION = $Slash::Constants::VERSION;


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

=item nocreate

Don't actually create RSS feed, just return data structure.

=back

=back

=item Return value

The complete RSS data as a string.

=back

=cut


sub create {
	my($class, $param) = @_;
	return unless ref($param->{items}) eq 'ARRAY';

	my $self = bless {}, $class;

	my $constants = getCurrentStatic();
	my $gSkin = getCurrentSkin();

	my $version  = $param->{version} && $param->{version} =~ /^\d+\.?\d*$/
		? $param->{version}
		: '1.0';
	my $encoding = $param->{rdfencoding} || $constants->{rdfencoding};
	$self->{rdfitemdesc} = defined $param->{rdfitemdesc}
		? $param->{rdfitemdesc}
		: $constants->{rdfitemdesc};
	$self->{rdfitemdesc_html} = defined $param->{rdfitemdesc_html}
		? $param->{rdfitemdesc_html}
		: $constants->{rdfitemdesc_html};

	my $rss = XML::RSS->new(
		version		=> $version,
		encoding	=> $encoding,
	);

	# A convenient way to tell whether our caller is apache.
	# Seems like there should be a better-supported way, but this
	# way is convenient.
	my $dynamic = defined &Slash::Apache::ConnectionIsSSL;
	my $absolutedir = apacheConnectionSSL() ? $gSkin->{absolutedir_secure} : $gSkin->{absolutedir};

	# set defaults
	my %channel = (
		title		=> $constants->{sitename},
		description	=> $constants->{slogan},
		'link'		=> $absolutedir . '/',
		selflink	=> '',

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

		for (@{$param->{items}}) {
			if ($_->{story}) {
				$rss->add_module(
					prefix  => 'slash',
					uri     => 'http://purl.org/rss/1.0/modules/slash/',
				);
				last;
			}
		}

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

	# help users get notification that this feed is specifically for them
	if ($dynamic && getCurrentForm('logtoken')) {
		my $user = getCurrentUser();
		if (!$user->{is_anon}) {
			$channel{$_} .= ": Generated for $user->{nickname} ($user->{uid})"
				for qw(title description);
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
			} else {
				$encoded_item->{dc}{date} = $self->encode($self->date2iso8601($item->{'time'}))
					if $item->{'time'};
				$encoded_item->{dc}{creator} = $self->encode($item->{creator})
					if $item->{creator};
			}

			for my $key (keys %$item) {
				if ($key eq 'description') {
					if ($version >= 0.91) {
						my $desc = $self->rss_item_description($item->{$key});
						$encoded_item->{$key} = $desc if $desc;
					}
				} else {
					my $data = $item->{$key};
					if ($key eq 'link') {
						$data = _tag_link($data);
					}
					$encoded_item->{$key} = $self->encode($data, $key);
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

	return $param->{nocreate} ? $rss : $rss->as_string;
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
	my $reader    = getObject('Slash::DB', { db_type => 'reader' });

	my $topics = $reader->getTopics;
	my $other_creator;
	my $action;

	$encoded_item->{title}  = $self->encode($story->{title})
		if $story->{title};
	if ($story->{sid}) {
		my $edit = "admin.pl?op=edit&sid=$story->{sid}";
		my $linktitle = $story->{title};
		$linktitle =~ s/\s+/-/g;
		$linktitle =~ s/[^A-Za-z0-9\-]//g;
		
		if ($constants->{firehose_link_article2}) {
			$action = "story/$story->{sid}/$linktitle?from=rss";
		} else {
			$action = "article.pl?sid=$story->{sid}&from=rss";
		}


		if ($story->{primaryskid}) {
			my $dir = url2abs(
				$reader->getSkin($story->{primaryskid})->{rootdir},
				$channel->{'link'}
			);
			if ($constants->{firehose_link_article2}) {
				$encoded_item->{'link'} = _tag_link("$dir/story/$story->{sid}/$linktitle");
			} else {
				$encoded_item->{'link'} = _tag_link("$dir/article.pl?sid=$story->{sid}");
			}
			$edit = "$dir/$edit";
			$action = "$dir/$action";
		} else {
			if ($constants->{firehose_link_article2}) {
				$encoded_item->{'link'} = _tag_link("$channel->{'link'}story/$story->{sid}/$linktitle");
			} else {
				$encoded_item->{'link'} = _tag_link("$channel->{'link'}article.pl?sid=$story->{sid}");
			}
			$edit = "$channel->{'link'}$edit";
			$action = "$channel->{'link'}$action";
		}
		$_ = $self->encode($_, 'link') for ($encoded_item->{'link'}, $edit, $action);

		if (getCurrentUser('is_admin')) {
			$story->{introtext} .= qq[\n\n<p><a href="$edit">[ Edit ]</a></p>];
		}

		if ($story->{journal_id}) {
			my $journal = getObject('Slash::Journal');
			if ($journal) {
				my $journal_uid = $journal->get($story->{journal_id}, "uid");
				$other_creator = $reader->getUser($journal_uid, 'nickname')
					if $journal_uid;
			}
		}
	}

	if ($version >= 0.91) {
		my $desc = $self->rss_item_description($item->{description} || $story->{introtext});
		if ($desc) {
			$encoded_item->{description} = $desc;

			my $extra = '';
			# If the text of the <img src>'s query string changes,
			# Stats.pm getTopBadgeURLs() may also have to change.
			$extra .= qq{<p><a href="$action"><img src="$channel->{'link'}slashdot-it.pl?from=rss&amp;op=image&amp;style=h0&amp;sid=$story->{sid}"></a></p>}
				if $constants->{rdfbadge};
			$extra .= "<p><a href=\"$action\">Read more of this story</a> at $constants->{sitename}.</p>"
				if $action;
			# add poll if any
			$extra .= pollbooth($story->{qid},1, 0, 1) if $story->{qid};
			$encoded_item->{description} .= $self->encode($extra) if $extra;
		}
	}

	if ($version >= 1.0) {
		$encoded_item->{dc}{date}    = $self->encode($self->date2iso8601($story->{'time'}))
			if $story->{'time'};
		$encoded_item->{dc}{subject} = $self->encode($topics->{$story->{tid}}{keyword})
			if $story->{tid};

		my $creator;
		if ($story->{uid}) {
			$creator = $reader->getUser($story->{uid}, 'nickname');
			$creator = "$other_creator (posted by $creator)" if $other_creator;
		} elsif ($other_creator) {
			$creator = $other_creator;
		}
		$encoded_item->{dc}{creator} = $self->encode($creator) if $creator;

		$encoded_item->{slash}{comments}   = $self->encode($story->{commentcount})
			if $story->{commentcount};
		# old bug, was "hit_parade" in mod_slash RSS module, so since that
		# has been around forever, we just change the new created feeds
		# to use that
		$encoded_item->{slash}{hit_parade}  = $self->encode($story->{hitparade})
			if $story->{hitparade};
		$encoded_item->{slash}{department} = $self->encode($story->{dept})
			if $story->{dept} && $constants->{use_dept};

		if ($story->{primaryskid}) {
			$encoded_item->{slash}{section} = $self->encode(
				$reader->getSkin($story->{primaryskid})->{name}
			);
		}
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
	$desc ||= '';

	my $constants = getCurrentStatic();

	if ($self->{rdfitemdesc}) {
		if ($self->{rdfitemdesc_html}) {
			# this should not hurt things that don't have
			# slashized links or slash tags ... but if
			# we do have a problem, we can move this to
			# rss_story() -- pudge
			$desc = parseSlashizedLinks($desc);
			$desc = processSlashTags($desc);

			# here we could reprocess content as XHTML if we
			# choose to, since that is in some ways better
			# for feeds ... just set $constants->{xhtml}
			# and run through balanceTags again?


		} else {
			$desc = strip_notags($desc);
			$desc =~ s/\s+/ /g;
			$desc =~ s/ $//;
		}

		# keep $desc as-is if == 1
		if ($self->{rdfitemdesc} != 1) {
			if (length($desc) > $self->{rdfitemdesc}) {
				$desc = substr($desc, 0, $self->{rdfitemdesc});
				$desc =~ s/[\w'-]+$//;  # don't trim in middle of word
				if ($self->{rdfitemdesc_html}) {
					$desc =~ s/<[^>]*$//;
					$desc = balanceTags($desc, { deep_nesting => 1 });
				}
				$desc =~ s/\s+$//;
				$desc .= '...';
			}
		}

		$desc = $self->encode($desc);		
	} else {
		undef $desc;
	}

	return $desc;
}

sub _tag_link {
	my($link) = @_;
	my $uri = URI->new($link);
	if (my $orig_query = $uri->query) {
		$uri->query("$orig_query&from=rss");
	} else {
		$uri->query("from=rss");
	}
	return $uri->as_string;
}

1;

__END__


=head1 SEE ALSO

Slash(3), Slash::XML(3).

#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;
use Slash::XML;

#################################################################
sub main {
	my $reader    = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();
	my $gSkin     = getCurrentSkin();
	my $searchDB  = getObject('Slash::SearchToo', { db_type => 'search' });

	my $ops = $searchDB->getOps;

	# Backwards compatibility, we now favor tid over topic 
	if ($form->{topic}) {
		if ($form->{topic} =~ s/^([+-]?[\d.]+).*$/$1/s) {
			$form->{tid} ||= $form->{topic};
		}
		delete $form->{topic};
	}

	# for now, so they can coexist, this search is called "searchtoo" ...
	# we will probably keep this as "searchtoo" even when we change the
	# page name back to "search.pl", just so we can keep it separate
	$user->{currentPage} = 'searchtoo';

	# Set some defaults
	$form->{query}		||= '';
	$form->{'sort'}		||= 'date';
	$form->{threshold}	= $user->{threshold} unless defined $form->{threshold};
	$form->{op}		= 'stories' if !$form->{op} || !exists $ops->{$form->{op}};

	# switch search mode to poll if in polls skin and other
	# search type isn't specified
	if ($gSkin->{name} eq 'polls' && !$form->{op}) {
		$form->{op}      = 'polls';
		$form->{section} = '';

	# submissions only available to regular users if proper constant set
	} elsif ($form->{op} eq 'submissions' && !$user->{is_admin}) {
		$form->{op} = 'stories' unless $constants->{submiss_view};
	}
 
	my $rss = $form->{content_type} eq 'rss' && $constants->{search_rss_enabled};

	unless ($rss) {
		my $query = strip_notags($form->{query});
		my $header_title   = getData('search_header_title',   { text => $query });
		my $titlebar_title = getData('search_titlebar_title', { text => $query });
		header($header_title) or return;
		titlebar('100%', $titlebar_title);
	}

	# Here, panic mode is handled without needing to call the
	# individual search subroutines;  we're going to tell the
	# user the same thing in each case anyway.
	if ($constants->{panic} >= 1 || $constants->{search_google} || !$searchDB) {
		slashDisplay('nosearch');

	# this is the bulk of it, where the MAGIC happens!
	} elsif ($ops->{$form->{op}}) {
		my %query;
		for (qw[threshold query author op section journal_only submitter uid]) {
			$query{$_} = $form->{$_} if defined $form->{$_};
		}

		my $topics = $form->{_multi}{tid} || $form->{tid};
		$query{topic} = $topics;

		my %opts = (
			# XXX not sure how to define yet ... should we use nums or strings?
			sort		=> $form->{sort},
			records_start	=> $form->{start},
			# XXX for now, don't let user define
			# records_max	=> $form->{max},
			# XXX not yet used
			date_start	=> '',
			date_end	=> '',
		);

		$ops->{$form->{op}} = \&defaultSearch unless ref $ops->{$form->{op}} eq 'CODE';

		my $return = $ops->{$form->{op}}->(
			$reader, $constants, $user, $form,
			$gSkin, $searchDB, $rss, \%query, \%opts
		);

		my $args = _buildargs({
			(map { $_ => $opts{$_} }
			    qw(sort date_start date_end)),
			%query,
		});

		if ($rss) {
			if ($return->{rss}) {
				xmlDisplay(rss => $return->{rss});
			} else {
				# we do this here, because we might not know
				# if the op can do RSS until we get the result
				redirect("$constants->{rootdir}/searchtoo.pl?start=$opts{records_start}&$args");
				return;
			}
				
		} else {
			slashDisplay('searchform', {});
			if (! @{$return->{results}{records}}) {
				print $return->{noresults};
			} else {
				slashDisplay($return->{template}, {
					shorten	=> \&_shorten,
					results => $return->{results},
					query	=> \%query,
					args	=> $args,
				});
			}
		}
	}

	footer() unless $rss;

	my $keys = join '|', keys %$ops;
	writeLog($form->{query}) if $form->{op} =~ /^(?:$keys)$/;
}

#################################################################
sub defaultSearch {
	my($reader, $constants, $user, $form, $gSkin, $searchDB, $rss, $query, $opts) = @_;

	my %return;
	$return{results}   = $searchDB->findRecords($form->{op} => $query, $opts);

	(my $singular_name = $form->{op}) =~ s/([^s])s$/$1/;
	$singular_name = 'story' if $singular_name eq 'storie';

	$return{template}  = $singular_name . 'search';
	$return{noresults} = 'no' . $form->{op};

	# move some RSS processing to templates at some point ...
	if ($rss) {
		$return{rss}{channel} = {
			title		=> getData($form->{op} . '_rss_title'),
			'link'		=> "$gSkin->{absolutedir}/searchtoo.pl",
		};
		$return{rss}{description} = getData($form->{op} . '_rss_description')
			|| $return{rss}{title};
		$return{rss}{image}       = 1;

		if ($form->{op} eq 'stories') {
			my @items;
			for my $entry (@{$return{results}{records}}) {
				my $time = timeCalc($entry->{time});
				# Link should be made to be sectional -Brian
				# so why didn't make it sectional?
				push @items, {
					title	=> $entry->{title},
					'link'	=> ($gSkin->{absolutedir} . '/article.pl?sid=' . $entry->{sid}),
					description	=> $entry->{introtext}
				};
			}
			$return{rss}{items} = \@items;

			$return{rss}{rdfitemdesc}      = $constants->{search_rdfitemdesc};
			$return{rss}{rdfitemdesc_html} = $constants->{search_rdfitemdesc_html};
		}

		elsif ($form->{op} eq 'comments') {
			my @items;
			for my $entry (@{$return{results}{records}}) {
				my $time = timeCalc($entry->{date});
				push @items, {
					title	=> "$entry->{subject} ($time)",
					'link'	=> ($gSkin->{absolutedir} . "/comments.pl?sid=$entry->{did}&cid=$entry->{cid}"),
				};
			}
			$return{rss}{items} = \@items;
		}
	}

	return \%return;
}

#################################################################
sub _authors {
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $authors = $reader->getDescriptions('all-authors');
	my %newauthors = %$authors;
	$newauthors{''} = getData('all_authors');

	return \%newauthors;
}

#################################################################
sub _topics {
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	my $topics = $reader->getDescriptions('topics-searchable');
	my %newtopics = %$topics;
	$newtopics{''} = getData('all_topics');

	return \%newtopics;
}

#################################################################
sub _sort {
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $sort = $reader->getDescriptions('sortorder');

	return $sort;
}

#################################################################
sub _skins {
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	my $skins = $reader->getDescriptions('skins-searchable');
	my %newskins = %$skins;
	$newskins{''} = getData('all_sections');  # keep Sections name for public

	return \%newskins;
}

#################################################################
sub _buildargs {
	my($query) = @_;
	my $uri;

	# all possible args ...
	# XXX we need a better way to do this, maybe vars?
#	for (qw[threshold query author op tid section sort journal_only submitter uid]) {
	for (keys %$query) {
		my $x = "";
		$x =  $query->{$_} if defined $query->{$_} && $x eq "";
		$x =~ s/ /+/g;
		$uri .= "$_=$x&" unless $x eq "";
	}
	$uri =~ s/&$//;

	return fixurl($uri);
}

#################################################################
sub _shorten {
	my($text, $length) = @_;
	$length ||= getCurrentStatic('search_text_length');
	return $text if length($text) <= $length;
	$text = chopEntity($text, $length);
	$text =~ s/(.*) .*$/$1.../g;
	return $text;
}

#################################################################
createEnvironment();
main();

1;

#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
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
	$form->{'sort'}		||= 1; # 'date';
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
 
	my $rss = $form->{content_type} =~ $constants->{feed_types} && $constants->{search_rss_enabled};

	my $querystring    = strip_notags($form->{query});
	my $header_title   = getData('search_header_title',   { text => $querystring });
	my $titlebar_title = getData('search_titlebar_title', { text => $querystring });

	# Here, panic mode is handled without needing to call the
	# individual search subroutines;  we're going to tell the
	# user the same thing in each case anyway.
	if ($constants->{panic} >= 1 || $constants->{search_google} || !$searchDB) {
		header($header_title) or return;
		titlebar('100%', $titlebar_title);
		slashDisplay('nosearch');
		footer();

	# this is the bulk of it, where the MAGIC happens!
	} elsif ($ops->{$form->{op}}) {
		my %query;
		$query{points_min} = $form->{threshold} if defined $form->{threshold};
		for (qw[query author op section journal_only submitter uid]) {
			$query{$_} = $form->{$_} if defined $form->{$_};
		}

		my $topics = $form->{_multi}{tid} || $form->{tid};
		$query{topic} = $topics;

		my %opts = (
			# we accept any value for sort,
			# and deal with filtering in the API
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
			slashDisplay('searchrss', {
				op	=> $form->{op},
				rss	=> $return->{rss},
				results	=> $return->{results},
			}, { Return => 0, Nocomm => 1 });

			if (@{$return->{rss}{items}}) {
				xmlDisplay($form->{content_type} => $return->{rss});
			} else {
				# we redirect here, because we might not know
				# if the op can do RSS until we get the result
				redirect("$constants->{rootdir}$ENV{SCRIPT_NAME}?start=$opts{records_start}&$args");
				return;
			}
				
		} else {
			# XXX add RSS linkrel here ? ...
			header($header_title) or return;
			titlebar('100%', $titlebar_title);

			slashDisplay('searchform', { op => $form->{op} });

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

			footer();
		}
	}

	my $keys = join '|', keys %$ops;
	writeLog($form->{query}) if $form->{op} =~ /^(?:$keys)$/;

	my $plugins = $reader->getDescriptions('plugins');
	if ($form->{query} && $plugins->{Tags}) {
		my $tagsdb = getObject('Slash::Tags');
		$tagsdb->logSearch($form->{query});
	}
}

#################################################################
sub defaultSearch {
	my($reader, $constants, $user, $form, $gSkin, $searchDB, $rss, $query, $opts) = @_;

	my %return;
	$return{results}   = $searchDB->findRecords($form->{op} => $query, $opts);

	(my $singular_name = $form->{op}) =~ s/([^s])s$/$1/;
	$singular_name     = 'story' if $singular_name eq 'storie';
	$singular_name     = 'sub'   if $singular_name eq 'submission';

	$return{template}  = $singular_name . 'search';
	$return{noresults} = getData('no' . $form->{op});

	$return{rss}       = {} if $rss; # populate via searchrss template

	return \%return;
}

#################################################################
sub _buildargs {
	my($query) = @_;
	my $uri;

	for (keys %$query) {
		my $x = "";
		$x =  $query->{$_} if defined $query->{$_} && $x eq "";
		$x =~ s/ /+/g;
		$uri .= "$_=$x&amp;" unless $x eq "";
	}
	$uri =~ s/&amp;$//;

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

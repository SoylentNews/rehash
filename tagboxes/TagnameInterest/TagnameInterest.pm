#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2009 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Tagbox::TagnameInterest;

=head1 NAME

Slash::Tagbox::TagnameInterest - Put popular tagnames in the hose

=head1 SYNOPSIS

	my $tagbox_tcu = getObject("Slash::Tagbox::TagnameInterest");
	my $feederlog_ar = $tagbox_tcu->feed_newtags($tags_ar);
	$tagbox_tcu->run($affected_globjid);

=cut

use strict;

use Slash;
use Slash::Utility;
use Slash::Display;

our $VERSION = $Slash::Constants::VERSION;

use base 'Slash::Tagbox';

sub init {
        my($self) = @_;
        return 0 if ! $self->SUPER::init();

	my $tagsdb = getObject('Slash::Tags');
	$self->{descriptiveid} = $tagsdb->getTagnameidCreate('descriptive');

	1;
}

sub init_tagfilters {
	my($self) = @_;
	$self->{filter_activeonly} = 1;
	$self->{filter_firehoseonly} = 1;

	# If this tagname has already been judged by admins in some way, skip it.
	# (May revisit this decision later.)
	$self->{tagnameid_unwanted} = { };
	my @unwanted_param_names = qw( descriptive tagname_clout posneg fh_exclude exclude popup admin_ok );
	my $unwanted_param_str = join ',', map { qq{'$_'} } @unwanted_param_names;
	my $tagnameids_ar = $self->sqlSelectColArrayref('tagnameid', 'tagname_params',
		"name IN ($unwanted_param_str) AND value != '0'");
	for my $tagnameid (@$tagnameids_ar) {
		$self->{tagnameid_unwanted}{$tagnameid} = 1;
	}

	# Skip tagnames that fetch_rss_bookmarks.pl uses to tag feeds with.
	my $bookmark = getObject("Slash::Bookmark");
	my $tags = getObject("Slash::Tags");
	if ($bookmark && $tags) {
		my $feeds = $bookmark->getBookmarkFeeds();
		for my $feed_hr (@$feeds) {
			for my $tagname (split / /, ($feed_hr->{tags} || '')) {
				my $tagnameid = $tags->getTagnameidFromNameIfExists($tagname);
				next unless $tagnameid;
				$self->{tagnameid_unwanted}{$tagnameid} = 1;
			}
		}
	}
}

sub get_affected_type	{ 'tagname' }
sub get_clid		{ 'vote' }
sub get_nosy_gtids { [qw( tagnames )] }

sub _do_filter_tagnameid {
	my($self, $tags_ar) = @_;
	$tags_ar = [ grep { !$self->{tagnameid_unwanted}{ $_->{tagnameid} } } @$tags_ar ];
	return $self->SUPER::_do_filter_tagnameid($tags_ar);
}

sub run_process {
	my($self, $affected_id, $tags_ar, $options) = @_;

	my $globjid = $self->getGlobjidFromTargetIfExists('tagnames', $affected_id);
#$self->info_log("affid=$affected_id start globjid='$globjid'");
	# If this tagname already has a globjid, there's nothing for
	# this tagbox to do.
	return if $globjid;

	my $tagsdb = getObject('Slash::Tags');
	my $tagname_data = $tagsdb->getTagnameDataFromId($affected_id);
	my $tagname = $tagname_data->{tagname};
#$self->info_log("affid=$affected_id tagname=$tagname unw='$self->{tagnameid_unwanted}{$affected_id}'");
	return unless $tagname;

	# If this tagname has already been judged by admins in some way, skip it.
	return if $self->{tagnameid_unwanted}{$affected_id};

	my $constants = getCurrentStatic();
	my $hose_reader = getObject('Slash::FireHose', { db_type => 'reader' });
	my $fh = $hose_reader->getFireHoseByGlobjid($affected_id);
#$self->info_log("affid=$affected_id fh='$fh'");
	return if $fh;

	my $get_options = { };
	if (length $constants->{tagbox_tni_min_pop}) {
		$get_options->{min_pop} = $constants->{tagbox_tni_min_pop};
	}
	my $tag_ar = [ grep { $_->{total_clout} > 0 && ! $_->{inactivated} }
		@{$tagsdb->getAllObjectsTagname($tagname, $get_options)} ];
#$self->info_log("affid=$affected_id tag_ar " . scalar(@$tag_ar));
	return unless @$tag_ar;
	my $total_count = scalar @$tag_ar;
#$self->info_log("affid=$affected_id tc=$total_count");
	return unless $total_count >= $constants->{tagbox_tni_min_total_count};
	my %uids = ( map { $_->{uid}, 1 } @$tag_ar );
	my $uid_count = scalar keys %uids;
#$self->info_log("affid=$affected_id uc=$uid_count");
	return unless $uid_count >= $constants->{tagbox_tni_min_uid};
	my %globjids = ( map { $_->{globjid}, 1 } @$tag_ar );
	my $globjid_count = scalar keys %globjids;
#$self->info_log("affid=$affected_id gc=$globjid_count");
	return unless $globjid_count >= $constants->{tagbox_tni_min_globjid};
	my $first_time = $tag_ar->[0]{created_at};
	my($first_ut, $last_ut) = ($tag_ar->[0]{created_at_ut}) x 2;
	for my $tag_hr (@$tag_ar) {
		my $ut = $tag_hr->{created_at_ut};
		if ($ut < $first_ut) {
			$first_ut = $ut;
			$first_time = $tag_hr->{created_at};
		}
		if ($ut > $last_ut) {
			$last_ut = $ut;
		}
	}
#$self->info_log("affid=$affected_id last=$last_ut first=$first_ut");
	return unless $last_ut - $first_ut >= $constants->{tagbox_tni_min_time};

	$globjid = $self->getGlobjidCreate('tagnames', $affected_id);
	if (!$globjid) {
		$self->info_log("could not create globj for tagname $affected_id '$tagname'");
		return;
	}
	my @last_n = ( );
	my $examples_wanted = $constants->{tagbox_tni_num_examples} || 0;
	if ($examples_wanted) {
		my $n_minus_1 = $examples_wanted - 1;
		$n_minus_1 = $#$tag_ar if $#$tag_ar < $n_minus_1;
		@last_n = (sort { $b->{created_at_ut} <=> $a->{created_at_ut} } @$tag_ar)[0..$n_minus_1];
	}
	my $firehosedb = getObject('Slash::FireHose');
	for my $tag_hr (@last_n) {
		$tag_hr->{nickname} = $self->getUser($tag_hr->{uid}, 'nickname');
		my $fh = $firehosedb->getFireHoseByGlobjid($tag_hr->{globjid});
		warn "no fh for $tag_hr->{globjid}", next if !$fh;
		$tag_hr->{fhid} = $fh->{id};
		$tag_hr->{fhtitle} = $fh->{title};
	}
	my $template_data = {
		tagname => $tagname,
		total_count => $total_count,
		uid_count => $uid_count,
		globjid_count => $globjid_count,
		first_time => $first_time,
		last_n_tags => \@last_n,
	};
	my $introtext = slashDisplay('tagnameintro', $template_data,
		{ Page => 'tagbox', Return => 1 });
	my $fh_data = {
		globjid => $globjid,
		title => "Tagname: $tagname",
		introtext => $introtext,
		type => 'tagname',
		uid => $constants->{tagbox_tni_submitter_uid} || getCurrentAnonymousCoward('uid'),
	};
use Data::Dumper; $self->info_log("affid=$affected_id creating: " . Dumper($fh_data) . "from " . Dumper($template_data));
	my $fhid = $firehosedb->createFireHose($fh_data);
	$self->info_log("created $globjid ($fhid) for $tagname");
}

1;


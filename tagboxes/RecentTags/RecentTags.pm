#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

# XXX This tagbox doesn't really have an appropriate "affected_id".
# (Maybe this'd be the first tagbox with _tagname_ as affected_id.
# Or maybe its affected_id is always 0 or something.)
# So its run() may not want to do the usual getTagboxTags.

package Slash::Tagbox::RecentTags;

=head1 NAME

Slash::Tagbox::RecentTags - update the Recent Tags slashbox

=head1 SYNOPSIS

	my $tagbox_tcu = getObject("Slash::Tagbox::RecentTags");
	my $feederlog_ar = $tagbox_tcu->feed_newtags($users_ar);
	$tagbox_tcu->run($affected_globjid);

=cut

use strict;

use Slash;

our $VERSION = $Slash::Constants::VERSION;

use base 'Slash::Tagbox';

sub init {
	my($self) = @_;
	return 0 if ! $self->SUPER::init();

	my $constants = getCurrentStatic();
	my $tagsdb = getObject('Slash::Tags');
	$self->{exclude_tagnameids} = {
		map { ($tagsdb->getTagnameidCreate($_), 1) }
                split / /, $constants->{tagbox_top_excludetagnames} || 'yes no'
	};
}

sub init_tagfilters {
	my($self) = @_;

	$self->{filter_firehoseonly} = 1;

	# would be nice to be able to _ex_clude tagnameids here
}

sub get_affected_type	{ 'globj' }
sub get_clid		{ 'describe' }

sub feed_newtags_process {
	my($self, $tags_ar) = @_;
	my $constants = getCurrentStatic();
	my $seconds_back = $constants->{tagbox_recenttags_secondsback};
	my $firehosedb = getObject('Slash::FireHose', { db_type => 'reader' });

	my $ret_ar = [ ];
	for my $tag_hr (@$tags_ar) {
		# Tags outside the window aren't important (maybe this tagbox
		# is running through a backlog)
		my $seconds_old = time - $tag_hr->{created_at_ut};
		next if $seconds_old > $seconds_back;
		# Tags that the Top tagbox excludes aren't important.
		next if $self->{exclude_tagnameids}{ $tag_hr->{tagnameid} };
		# Tags on a hose item under the minslice aren't important.
		my $minslice = $constants->{tagbox_recenttags_minslice} || 4;
		my $firehose_id = $firehosedb->getFireHoseIdFromGlobjid($tag_hr->{globjid});
		next unless $firehose_id;
		my $firehose = $firehosedb->getFireHose($firehose_id);
		my $pop = $firehose->{popularity} || 0;
		my $minpop = $firehosedb->getMinPopularityForColorLevel($minslice);
		next if $pop < $minpop;
		my $ret_hr = {
			affected_id =>  1,
			# We could here reduce importance if the tag is not Descriptive
			# or has a reduced clout.  XXX
			importance =>   0.1,
		};
		# We identify this little chunk of importance by either
		# tagid or tdid depending on whether the source data had
		# the tdid field (which tells us whether feed_newtags was
		# "really" called via feed_deactivatedtags).
		if ($tag_hr->{tdid})	{ $ret_hr->{tdid}  = $tag_hr->{tdid}  }
		else			{ $ret_hr->{tagid} = $tag_hr->{tagid} }
		push @$ret_ar, $ret_hr;
	}

	return $ret_ar;
}

# tags_ar is kind of irrelevant here

sub run_process {
	my($self, $affected_id, $tags_ar) = @_;
	my $constants = getCurrentStatic();
	my $tagsdb = getObject('Slash::Tags');
	my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });

	my $exclude_tagnames = $constants->{tagbox_top_excludetagnames} || 'yes no';
	my %exclude_tagname = (
		map { ($_, 1) }
		split / /, $exclude_tagnames
	);
	my $num_wanted = $constants->{tagbox_recenttags_num} || 5;
	my $max_num = $num_wanted + scalar(keys %exclude_tagname);
	my $seconds_back = $constants->{tagbox_recenttags_secondsback} || 7200;
	my $min_clout = $constants->{tagbox_recenttags_minclout} || 4.0;
	my $tagnames_ar = $tags_reader->listTagnamesActive({
		max_num => $max_num,
		seconds => $seconds_back,
		min_clout => $min_clout,
	});

	# Strip out tagnames we want to exclude.
	@$tagnames_ar = grep { !$exclude_tagname{$_} } @$tagnames_ar;

	# Max of 5 or whatever.
	$#$tagnames_ar = $num_wanted-1 if scalar(@$tagnames_ar) > $num_wanted;

	if (scalar(@$tagnames_ar) < $num_wanted) {
		# If we don't get as many as we wanted, leave up
		# whatever was there before.
		main::tagboxLog("RecentTags->run only " . scalar(@$tagnames_ar) . " so not changing");
		return;
	}
	# XXX this should be a template
	my $block = '<ul>';
	for my $tagname (@$tagnames_ar) {
		$block .= qq{<li><a href="/tags/$tagname">$tagname</a></li>};
	}
	$block .= '</ul>';
	$self->info_log("setting Recent Tags to '%s' (%d chars)", join(' ', @$tagnames_ar), length($block));
	$self->setBlock('activetags', { block => $block });
}

1;


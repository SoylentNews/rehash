#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

# Once a day, rewrite the tags_tagnamecache table, used for finding
# tagname suggestions based on prefixes.

use strict;
use vars qw( %task $me $task_exit_flag );
use Slash::DB;
use Slash::Display;
use Slash::Utility;
use Slash::Constants ':slashd';

(my $VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

$task{$me}{timespec} = "30 6 * * *";
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{fork} = SLASHD_NOWAIT;

$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;
	my $tagsdb = getObject('Slash::Tags');
	my $tagsdb_reader = getObject('Slash::Tags', { db_type => 'reader' });
	my $daysback = $constants->{tags_tagnamecache_daysback} || 180;
	my $min_tagid = getMinimumTagid($tagsdb, $daysback);
	my $ar = getTagnameList($tagsdb_reader, $min_tagid);
	my $rows_replaced = replaceTagnames($tagsdb, $ar);
	my $rows_deleted = deleteTagnamesNotIn($tagsdb, $ar);
	my $total_rows = $tagsdb->sqlCount('tagname_cache');
	return "replaced $rows_replaced, deleted $rows_deleted, total $total_rows";
};

sub getMinimumTagid {
	my($tagsdb, $daysback) = @_;
	my $min = $tagsdb->sqlSelectNumericKeyAssumingMonotonic(
		'tags', 'min', 'tagid',
		"created_at >= DATE_SUB(NOW(), INTERVAL $daysback DAY)");
	return $min;
}

# For now, let's include private tagnames in this list.  It's not
# revealing private information since it's completely aggregated,
# and while suggesting tagnames like 'nod' and 'nix' may not be
# helpful, suggesting 'troll' and 'interesting' seems OK.

sub getTagnameList {
	my($tagsdb_reader, $min_tagid) = @_;
	$min_tagid ||= 1;

	my $constants = getCurrentStatic();
	my $minc = $tagsdb_reader->sqlQuote($constants->{tags_prefixlist_minc} ||  4);
        my $mins = $tagsdb_reader->sqlQuote($constants->{tags_prefixlist_mins} ||  3);
	# $maxnum is to prevent $tagnameid_str from exceeding MySQL limits.
	# Default max_allowed_packet should be 16 MB, so an ~80K query
	# should be perfectly fine.
	my $maxnum = 10000;

	# Get the list of tagnameids sorted in a very rough order of
	# "importance."
	# Note that the query uses multiple columns to sort the data,
	# but we skim off only the tagnameid on the client side since
	# that's all we care about.

	my $tagnameid_ar = $tagsdb_reader->sqlSelectColArrayref(
		'tags.tagnameid,
		 COUNT(DISTINCT tags.uid) AS c,
		 SUM(tag_clout * IF(value IS NULL, 1, value)) AS s,
		 COUNT(DISTINCT tags.uid)/3 + SUM(tag_clout * IF(value IS NULL, 1, value)) AS sc',
		'tags, users_info, tagnames
		 LEFT JOIN tagname_params USING (tagnameid)',
		"tagnames.tagnameid=tags.tagnameid
		 AND tags.uid=users_info.uid
		 AND tags.inactivated IS NULL
		 AND tagid >= $min_tagid",
		"GROUP BY tags.tagnameid
		 HAVING c >= $minc AND s >= $mins
		 ORDER BY sc DESC, tagname ASC
		 LIMIT $maxnum");
	return [ ] if !$tagnameid_ar || !@$tagnameid_ar;
	my $tagnameid_str = join(',', sort { $a <=> $b } @$tagnameid_ar);

	# Now get the total list of tags (which will be very large,
	# so this is a slow query)

	my $tag_ar = $tagsdb_reader->sqlSelectAllHashrefArray(
		'*, UNIX_TIMESTAMP(created_at) AS created_at_ut',
		'tags',
		"tagnameid IN ($tagnameid_str)
		 AND tagid >= $min_tagid
		 AND tags.inactivated IS NULL");

	# This will call getUser() for every uid in the above list and
	# getTagnameidClid() for every tagnameid (up to 10,000).  So
	# this will be a very slow operation.

	$tagsdb_reader->addCloutsToTagArrayref($tag_ar);

	my $tagnameid_sum = { };
	for my $hr (@$tag_ar) {
		$tagnameid_sum->{ $hr->{tagnameid} } ||= 0;
		$tagnameid_sum->{ $hr->{tagnameid} } += $hr->{total_clout};
	}
	my $ret_ar = [ ];
	for my $tagnameid (@$tagnameid_ar) {
		my $sum = $tagnameid_sum->{$tagnameid};
		next unless $sum > 0;
		my $tagname = $tagsdb_reader->getTagnameDataFromId($tagnameid)->{tagname};
		push @$ret_ar, {
			tagnameid =>	$tagnameid,
			tagname =>	$tagname,
			weight =>	$sum,
		};
	}

	return $ret_ar;
}

sub replaceTagnames {
	my($tagsdb, $ar) = @_;
	my $rows = 0;
	for my $hr (@$ar) {
		$rows += $tagsdb->sqlReplace('tagname_cache', $hr);
		Time::HiRes::sleep(0.01);
	}
	return $rows;
}

sub deleteTagnamesNotIn {
	my($tagsdb, $ar) = @_;
	my $tagnameid_str = join(',',
		sort { $a <=> $b }
		map { $_->{tagnameid} }
		@$ar
	);
	my $rows = $tagsdb->sqlDelete('tagname_cache',
		"tagnameid NOT IN ($tagnameid_str)");
	return $rows;
}

1;


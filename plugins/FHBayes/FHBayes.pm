# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2009 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::FHBayes;

use strict;
use Slash;

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

sub getSourceList {
	my($self, $days_back) = @_;
	my $constants = getCurrentStatic();
	$days_back ||= $constants->{fhbayes_daysback} || 20;

	return $self->sqlSelectColArrayref(
		'firehose.id',
		'firehose, tags, authors_cache, users',
		"created_at >= DATE_SUB(NOW(), INTERVAL $days_back DAY)
		 AND created_at < DATE_SUB(NOW(), INTERVAL 8 HOUR)
		 AND firehose.globjid = tags.globjid
		 AND tags.uid = authors_cache.uid
		 AND authors_cache.uid=users.uid
		 AND users.seclev >= 100
		 AND type NOT IN ('feed, comment','vendor')",
		'GROUP BY firehose.id ORDER BY firehose.id');
}

sub getSourceLabels {
	my($self, $ids) = @_;
	my $tags = getObject('Slash::Tags');
	my $binspam_tnid = $tags->getTagnameidCreate('binspam');
	my $binspam_hr = { };
	my $ret_hr = { };
	my $splice_count = 2000;
	while (@$ids) {
		my @id_chunk = splice @$ids, 0, $splice_count;
		my $ids_in = join(",", @id_chunk);
		my $more_ar = $self->sqlSelectColArrayref(
			'DISTINCT firehose.id',
			'firehose, tags, authors_cache, users',
			"firehose.id IN ($ids_in)
			 AND firehose.globjid = tags.globjid
			 AND tags.uid = authors_cache.uid
			 AND authors_cache.uid=users.uid
			 AND users.seclev >= 100
			 AND tagnameid = $binspam_tnid");
		for my $id (@$more_ar) { $ret_hr->{$id} ||= 1 }
		for my $id (@id_chunk) { $ret_hr->{$id} ||= 0 }
	}
	return $ret_hr;
}

1;


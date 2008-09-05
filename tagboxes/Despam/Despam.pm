#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Tagbox::Despam;

=head1 NAME

Slash::Tagbox::Despam - Reduce (firehose) spam

=head1 SYNOPSIS

	my $tagbox_tcu = getObject("Slash::Tagbox::Despam");
	my $feederlog_ar = $tagbox_tcu->feed_newtags($users_ar);
	$tagbox_tcu->run($affected_globjid);

=cut

use strict;

use Slash::Utility;

our $VERSION = $Slash::Constants::VERSION;

use base 'Slash::Tagbox';

sub init {
	my($self) = @_;
	return 0 if ! $self->SUPER::init();

	my $tagsdb = getObject('Slash::Tags');
	$self->{binspamid}	= $tagsdb->getTagnameidCreate('binspam');
	$self->{upvoteid}	= $self->{nodid};
	$self->{recalc_tbids}	= undef;
	my $admins = $tagsdb->getAdmins();
	$self->{admin_in_str}	= join(',',
					sort { $a <=> $b }
					grep { $admins->{$_}{seclev} >= 100 }
					keys %$admins);
	return 0 if ! $self->{admin_in_str};

	1;
}

sub get_affected_type	{ 'globj' }
sub get_clid		{ 'describe' }

sub init_tagfilters {
	my($self) = @_;

	# Despam only cares about active tags.

	$self->{filter_activeonly} = 1;

	# Despam only cares about tags on globjs in the hose.

	$self->{filter_firehoseonly} = 1;

	# Despam only cares about binspam tags.

	$self->{filter_tagnameid} = $self->{binspamid};

	# And Despam only cares about those tags from admins.

	my $admins = $self->getAdmins();
	$self->{filter_uid} = [ sort { $a <=> $b } keys %$admins ];

}

sub run_process {
	my($self, $affected_id, $tags_ar) = @_;
	my $constants = getCurrentStatic();
	my $tagsdb = getObject('Slash::Tags');
	my $tagboxdb = getObject('Slash::Tagbox');
	my $firehose_db = getObject('Slash::FireHose');
	my $slashdb = getCurrentDB();

	# Get info about the firehose item that may have been tagged.
	my $affected_id_q = $self->sqlQuote($affected_id);
	my $fhid = $self->sqlSelect('DISTINCT id', 'firehose', "globjid = $affected_id_q");
	if (!$fhid || !$firehose_db) {
		$self->info_log("bad data, fhid='%d' db='%s'", $fhid, $firehose_db);
		return ;
	}
	my $fhitem = $firehose_db->getFireHose($fhid);

	# Get info about the uid and ipid that submitted the firehose item.
	# We only track ipid for actual submissions, not journals/bookmarks.
	my $submitter_uid = $fhitem->{uid};
	my $submitter_ipid = '';
	my $types = $slashdb->getGlobjTypes();
	my $submission_gtid = $types->{submissions};
	if ($submission_gtid) {
		$submitter_ipid = $slashdb->sqlSelect(
			'ipid',
			'globjs, submissions',
			"globjid=$affected_id
			 AND gtid=$submission_gtid
			 AND target_id=subid"
			) || '';
	}

	# First figure out how many times the globjid was tagged binspam by
	# an admin.  It may be zero (if forceFeederRecalc was called, or if
	# an old binspam tag was deactivated).  Even one admin binspam tag
	# is enough to mark the individual item as binspam.
	# XXX these tags are going to be in $tags_ar, re-SELECTing is redundant
	my $binspam_count_globjid = $slashdb->sqlCount(
		'tags',
		"globjid=$affected_id
		 AND tagnameid=$self->{binspamid}
		 AND uid IN ($self->{admin_in_str})
		 AND inactivated IS NULL");
	my $is_spam = ($binspam_count_globjid > 0);

	# Now see how many times this globjid's uid (or, if anonymous, ipid)
	# was tagged binspam by an admin.  If greater than a certain
	# threshold, that srcid (uid/ipid) will be given the 'spammer' al2.
	my($check_type, $srcid, $table_clause, $where_clause) = (undef, undef);
	if (!isAnon($submitter_uid)) {
		# Logged-in user, check by uid.
		$check_type = 'uid';
		$srcid = $submitter_uid;
		$table_clause = '';
		$where_clause = "firehose.uid = $submitter_uid";
	} elsif ($submitter_ipid) {
		# Non-logged-in user, check by IP (submissions.ipid)
		$check_type = 'ipid';
		$srcid = convert_srcid('ipid', $submitter_ipid);
		$table_clause = ', globjs, submissions';
		$where_clause = "firehose.type='submission'
			AND firehose.globjid=globjs.globjid
			AND globjs.target_id=submissions.subid
			AND submissions.ipid='$submitter_ipid'";
	}
	# If neither of the above, it's an anonymous non-submission, so
	# (at present) there's nothing we will do to block its "fellow"
	# firehose items.

	# Find out which and how many other 'binspam' tags this contributor
	# has amassed in total (where "contributor" can be an ipid or uid).
	my $binspam_tagid_globj_hr = { };
	if ($check_type) {
		# XXX these tags are going to be in $tags_ar, just SELECT the globjids in firehose, see all_globjid_ar below
		$binspam_tagid_globj_hr = $slashdb->sqlSelectAllKeyValue(
			'tags.tagid, tags.globjid',
			"tags, firehose$table_clause",
			"tags.globjid = firehose.globjid
			 AND tags.tagnameid = $self->{binspamid}
			 AND tags.uid IN ($self->{admin_in_str})
			 AND tags.inactivated IS NULL
			 AND $where_clause");
	}

	# This array contains the list of admin tags applied to
	# firehose items from this srcid.  If there are too many
	# of them, mark the srcid.
	my $binspam_count = scalar(keys %$binspam_tagid_globj_hr);
	my $mark_srcid = 0;
	if ($binspam_count >
		( $check_type eq 'uid'
			? $constants->{tagbox_despam_binspamsallowed}
			: $constants->{tagbox_despam_binspamsallowed_ip} )
	) {
		$is_spam = $mark_srcid = 1;
	}

	$self->info_log("uid=%d ipid=%s check_type=%s affected_id=%d srcid=%s count=%d is_spam=%d mark_srcid=%d tagids: '%s'",
		($submitter_uid || '0'), ($submitter_ipid || 'none'),
		(defined($check_type) ? $check_type : 'undef'),
		$affected_id, $srcid, $binspam_count, $is_spam, $mark_srcid,
		join(' ', sort { $a <=> $b } keys %$binspam_tagid_globj_hr));

	#			is_spam=0	is_spam=1	mark_srcid=1
	#
	# check_type undef	clear 1 globj	set 1 globjid	set 1 globjid
	# check_type=uid	clear 1 globj	set 1 globjid	set all globjids, setAL2
	# check_type=ipid	clear 1 globj	set 1 globjid	set all globjids, setAL2

	# Always set/clear at least the one globjid affected.
	my %globjids_mark_spam = ( $affected_id, 1 );
	if ($is_spam) {
		# Set/clear both the individual globjid and all its
		# fellow admin-tagged globjids, if known.  This is
		# almost certainly redundant since run() was surely
		# called on those ids as well (or will be shortly).
		# So XXX consider removing this code after checking
		# the logs to make sure this works as I expect.
		for my $tagid (keys %$binspam_tagid_globj_hr) {
			$globjids_mark_spam{ $binspam_tagid_globj_hr->{$tagid} } = 1;
		}
	}

	# %$binspam_tagid_globj_hr only contains the tags on the globjs
	# which have already been tagged by admins.  There may be more
	# globjs submitted which have not (yet) been tagged.  If the
	# srcid needs to be marked, and we have a valid check_type to
	# mark, fetch the list of all submissions from that check_type
	# and mark them.  As long as $check_type is set to uid or ipid,
	# the only complicated part of this has already been done by
	# setting $table_clause and $where_clause.
	if ($mark_srcid && $check_type) {
		my $all_globjid_ar = $slashdb->sqlSelectColArrayref(
			'firehose.globjid',
			"firehose$table_clause",
			$where_clause);
		for my $globjid (@$all_globjid_ar) {
			$globjids_mark_spam{$globjid} = 1;
		}
	}

	# Convert that list of globjids to firehose ids.
	my $globjid_in_str = join(',', sort { $a <=> $b } keys %globjids_mark_spam);
	my $fhid_mark_spam_hr = $slashdb->sqlSelectAllKeyValue(
		'id, globjid',
		'firehose',
		"globjid IN ($globjid_in_str)");
	$self->info_log("globjids '%s' -> fhids '%s'",
		join(' ', sort { $a <=> $b } keys %globjids_mark_spam),
		join(' ', sort { $a <=> $b } keys %$fhid_mark_spam_hr));

	# Loop on all the fhids required to be changed, setting or
	# clearing them as appropriate.
	for my $fhid (sort { $a <=> $b } keys %$fhid_mark_spam_hr) {
		my $globjid = $fhid_mark_spam_hr->{$fhid};
		my $rows = $firehose_db->setFireHose($fhid, { is_spam => ($is_spam ? 'yes' : 'no') });
		$self->info_log("marked fhid %d (%d) as is_spam=%d rows=%s",
			$fhid, $globjid, $is_spam, $rows);
		if ($rows > 0) {
			# If this firehose item's spam status changed, either way, its
			# scores now need to be recalculated immediately.
			# Get the list of tbids we need to force a recalc for.
			if (!defined $self->{recalc_tbids}) {
				my $tagboxes = $tagboxdb->getTagboxes();
				for my $tagbox_hr (@$tagboxes) {
					push @{$self->{recalc_tbids}}, $tagbox_hr->{tbid}
						if $tagbox_hr->{name} =~ /^(FHEditorPop|FireHoseScores)$/;
				}
			}
			# Force the recalculations of their scores.
			for my $tbid (@{$self->{recalc_tbids}}) {
				my $tagbox_hr = $tagboxdb->getTagboxes($tbid);
				$tagbox_hr->{object}->forceFeederRecalc($globjid);
				$self->info_log("force recalc tbid=%d globjid=%d", $tbid, $globjid);
			}
			# Add this change to the daily stats.
			my $statsSave = getObject('Slash::Stats::Writer');
			$statsSave->addStatDaily('firehose_binspam_despam',
				$is_spam ? '+1' : '-1');
		}
	}

	# If appropriate, mark the submitter's uid or ipid as a spammer
	# and mark _all_ their submissions as binspam.
	if ($mark_srcid && $check_type) {
		$self->info_log("marking spammer AL2 srcid=%s", $srcid);
		# XXX put 1183959 into a constant for goshsakes
		$slashdb->setAL2($srcid, { spammer => 1 }, { adminuid => 1183959 });
	}
}

#sub despam_srcid {
#	my($self, $srcid, $count) = @_;
#	my $slashdb = getCurrentDB();
#	my $constants = getCurrentStatic();
#
#	my $al2_hr = $slashdb->getAL2($srcid);
#	if ($count > $constants->{tagbox_despam_binspamsallowed_ip}) {
#		main::tagboxLog("marking $srcid as spammer for $count");
#		if (!$al2_hr->{spammer}) {
#			$slashdb->setAL2($srcid, { spammer => 1, comment => "Despam $count" });
#		}
#	}
#}
#
#sub despam_uid {
#	my($self, $uid, $count) = @_;
#	my $constants = getCurrentStatic();
#	my $slashdb = getCurrentDB();
#	my $reader = getObject('Slash::DB', { db_type => 'reader' });
#	my $tagboxdb = getObject('Slash::Tagbox');
#
#	# First, set the user's 'spammer' AL2.
#	my $adminuid = $constants->{tagbox_despam_al2adminuid};
#	my $al2_hr = $slashdb->getAL2($uid);
#	if (!$al2_hr->{spammer}) {
#		$slashdb->setAL2($uid, { spammer => 1, comment => "Despam $count" },
#			{ adminuid => $adminuid });
#	}
#
#	# Next, set the user's clout manually to 0.
#	$slashdb->setUser($uid, { tag_clout => 0 });
#
#        # Next, mark as spam everything the user's submitted.
#	$slashdb->sqlUpdate('firehose', { is_spam => 'yes' },
#		"accepted != 'no' AND uid=$uid");
#
#	# Next, if $count is high enough, set the 'spammer' AL2 for all
#	# the IPID's the user has submitted from.
#	if ($count > $constants->{tagbox_despam_binspamsallowed_ip}) {
#		my $days = defined($constants->{tagbox_despam_ipdayslookback})
#			? $constants->{tagbox_despam_ipdayslookback} : 60;
#		my %srcid_used = ( );
#		if ($days) {
#			my $sub_ipid_ar = $reader->sqlSelectColArrayref(
#				'DISTINCT ipid',
#				'submissions',
#				"uid=$uid AND time >= DATE_SUB(NOW(), INTERVAL $days DAY) AND ipid != ''");
#			my $journal_srcid_ar = $reader->sqlSelectColArrayref(
#				'DISTINCT ' . get_srcid_sql_out('srcid_32'),
#				'journals',
#				"uid=$uid AND date >= DATE_SUB(NOW(), INTERVAL $days DAY) AND srcid_32 != 0");
#			my $book_srcid_ar = $reader->sqlSelectColArrayref(
#				'DISTINCT ' . get_srcid_sql_out('srcid_32'),
#				'bookmarks',
#				"uid=$uid AND createdtime >= DATE_SUB(NOW(), INTERVAL $days DAY) AND srcid_32 != 0");
#			for my $ipid (@$sub_ipid_ar) {
#				my $srcid = convert_srcid(ipid => $ipid);
#				$srcid_used{$srcid} = 1;
#			}
#			for my $srcid (@$journal_srcid_ar) {
#				$srcid_used{$srcid} = 1;
#			}
#			for my $srcid (@$book_srcid_ar) {
#				$srcid_used{$srcid} = 1;
#			}
#			my @srcids = sort grep { $_ } keys %srcid_used;
#			for my $srcid (@srcids) {
#				$al2_hr = $slashdb->getAL2($srcid);
#				if (!$al2_hr->{spammer}) {
#					$slashdb->setAL2($srcid, { spammer => 1, comment => "Despam $count for $uid" });
#				}
#			}
#		}
#	}
#
#	# Next, declout everyone who's upvoted any of the user's
#	# recent submissions (except bookmarks, because those are
#	# generic enough).
#	my $daysback = $constants->{tagbox_despam_decloutdaysback} || 7;
#	my $upvoter_ar = $slashdb->sqlSelectColArrayref(
#		'DISTINCT tags.uid',
#		'tags, firehose',
#		"tags.globjid = firehose.globjid
#		 AND firehose.uid = $uid
#		 AND type IN ('submission', 'journal')
#		 AND createtime >= DATE_SUB(NOW(), INTERVAL $daysback DAY)
#		 AND tagnameid = $self->{upvoteid}
#		 AND inactivated IS NULL");
#	my $max_clout = defined($constants->{tagbox_despam_upvotermaxclout})
#		? $constants->{tagbox_despam_upvotermaxclout} : '0.85';
#	for my $upvoter (@$upvoter_ar) {
#		main::tagboxLog("setting user $upvoter clout to max $max_clout for upvoting user $uid");
#		$slashdb->setUser($upvoter, {
#			-tag_clout => "MAX(tag_clout, $max_clout)"
#		});
#	}
#
#	# Next, insert tagboxlog_feeder entries to tell the relevant
#	# tagboxes to recalculate those scores.
#	my $tagboxes = $tagboxdb->getTagboxes();
#	my @tagboxids = map { $_->{tbid} } grep { $_->{name} =~ /^(FHEditorPop|FireHoseScores)$/ } @$tagboxes;
#	my $globjid_tagid = $slashdb->sqlSelectAllKeyValue(
#		'firehose.globjid, tagid',
#		'firehose, tags',
#		"firehose.uid=$uid
#		 AND firehose.globjid=tags.globjid
#		 AND tags.uid=$uid
#		 AND tagnameid=$self->{upvoteid}",
#		'GROUP BY firehose.globjid');
#	for my $globjid (sort keys %$globjid_tagid) {
#		for my $tbid (@tagboxids) {
#			$tagboxdb->addFeederInfo($tbid, {
#				affected_id => $globjid,
#				importance => 1,
#				tagid => $globjid_tagid->{ $globjid },
#			});
#		}
#	}
#}

1;


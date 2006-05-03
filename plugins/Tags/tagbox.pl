#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;

use Slash;
use Slash::Constants ':slashd';
use Slash::Display;
use Slash::Utility;

use Data::Dumper;

use vars qw(
	%task	$me	$task_exit_flag
	$tags	$tagboxdb	$tagboxes
);

$task{$me}{timespec} = '* * * * *';
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;

	$tags = getObject('Slash::Tags');
	$tagboxdb = getObject('Slash::Tagbox');
	$tagboxes = $tagboxdb->getTagboxes();

	my $start_time = time();

	# This task isn't necessary unless there is one or more tagboxes.
	my $n_tagboxes = scalar(@$tagboxes);
	if ($n_tagboxes < 1) {
		# Don't quit, since the task will just restart.  Sleep
		# until the parent slashd quits.
		slashdLog("No tagboxes, so this task would not be useful -- sleeping permanently");
		sleep 5 while !$task_exit_flag;
		return ;
	}

	while (!$task_exit_flag) {

		# Insert into tagbox_feederlog
		$tagboxes = $tagboxdb->getTagboxes();
		my $activity_feeder = update_feederlog(@_);
		sleep 5;
		last if $task_exit_flag;

		# Run tagboxes (based on tagbox_feederlog)
		$tagboxes = $tagboxdb->getTagboxes();
		my $activity_run = run_tagboxes_until(@_, time() + 30);
		sleep 5;
		last if $task_exit_flag;

		# If nothing's going on, ease up more (not that it probably
		# matters much, since if nothing's going on both of the
		# above should be doing very fast SELECTs).
		sleep 20 if !$activity_feeder && !$activity_run;
		last if $task_exit_flag;

	}

	return sprintf("exiting after %d seconds", time - $start_time);
};

sub update_feederlog {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;

	my $min_max_tagid = $tagboxes->[0]{last_tagid_logged};
	for my $tagbox (@$tagboxes) {
		$min_max_tagid = $tagbox->{last_tagid_logged}
			if $tagbox->{last_tagid_logged} < $min_max_tagid;
	}

	my $tags_ar = $tags->sqlSelectAllHashrefArray(
		'*',
		'tags',
		"tagid > $min_max_tagid");
	return 0 # nothing was changed
		if !$tags_ar || !@$tags_ar;

	my $new_maxtagid = $min_max_tagid;
	for my $tag_hr (@$tags_ar) {
		$new_maxtagid = $tag_hr->{tagid}
			if $tag_hr->{tagid} > $new_maxtagid;
	}
#print STDERR "min_max_tagid=$min_max_tagid new_maxtagid=$new_maxtagid count(tags_ar)=" . scalar(@$tags_ar) . "\n";

	for my $tagbox (@$tagboxes) {
		# First, extract out only the tags that are new since the
		# last time this tagbox ran (which may or may not be the
		# same as the last time other tagboxes ran).
		my $tags_this_tagbox_ar = [
			grep { $_->{tagid} > $tagbox->{last_tagid_logged} }
			@$tags_ar
		];
#print STDERR "tagbox=$tagbox->{name} count(tags_this_ar)=" . scalar(@$tags_this_tagbox_ar) . "\n";

		# Dispatch to run custom code for each tagbox, to split a
		# Dumb hard-coded stand-in for the proper dispatch.
		# XXX This will change!
		my $feeder_ar = [ ];
		if ($tagbox->{name} eq 'tag_count') {
			$feeder_ar = _update_feederlog_tag_count(@_,
				$tagbox, $tags_this_tagbox_ar);
		}

		# XXX optimize by consolidating here: sum importances, max tagids
		# Insert the tagbox's data into the feederlog.
		insert_feederlog(@_, $tagbox, $feeder_ar) if $feeder_ar;

		# Mark the tagbox as having logged up to this point.
		# XXX The previous insert and this update should be wrapped
		# in a transaction.
		$tagboxdb->markTagboxLogged($tagbox->{tbid}, $new_maxtagid);

	}

	return 1; # something may have been changed
}

sub insert_feederlog {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin, $tagbox, $feeder_ar) = @_;
	for my $feeder_hr (@$feeder_ar) {
#print STDERR "addFeederInfo: tbid=$tagbox->{tbid} tagid=$feeder_hr->{tagid} affected_id=$feeder_hr->{affected_id} imp=$feeder_hr->{importance}\n";
		$tagboxdb->addFeederInfo($tagbox->{tbid},
			$feeder_hr->{tagid},
			$feeder_hr->{affected_id},
			$feeder_hr->{importance});
	}
}

sub run_tagboxes_until {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin, $run_until, $new_maxtagid) = @_;
	my $activity = 0;

	while (time() < $run_until) {
		my $affected_ar = $tagboxdb->getMostImportantTagboxAffectedIDs();
		return $activity if !$affected_ar || !@$affected_ar;

		$activity = 1;
		for my $affected_hr (@$affected_ar) {
#my $ad = Dumper($affected_hr); $ad =~ s/\s+/ /g; print STDERR "r_t_u affected_hr: $ad\n";
			# Dumb hard-coded stand-in for the proper dispatch.
			# XXX This will change!
			my $tagbox = $tagboxdb->getTagboxes($affected_hr->{tbid});
			if ($tagbox->{name} eq 'tag_count') {
				_run_tagbox_tag_count($virtual_user, $constants, $slashdb, $user, $info, $gSkin,
					$tagbox,
					$affected_hr->{affected_id});
			}
			$tagboxdb->markTagboxRunComplete(
				$tagbox->{tbid},
				$affected_hr->{affected_id},
				$affected_hr->{max_tagid}
			);
		}

		sleep 1;
	}
	return $activity;
}

sub _update_feederlog_tag_count {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin, $tagbox, $tags_ar) = @_;
	my $ret_ar = [ ];
	for my $tag_hr (@$tags_ar) {
		push @$ret_ar, {
			tagid =>	$tag_hr->{tagid},
			affected_id =>	$tag_hr->{uid},
			importance =>	1,
		};
#print STDERR "tag_count update: tagid=$tag_hr->{tagid} aff_id=$tag_hr->{uid} imp=1\n";
	}
	return $ret_ar;
}

sub _run_tagbox_tag_count {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin, $tagbox, $affected_id) = @_;
#	my $user_tags_ar = $tags->getAllTagsFromUser($affected_id);
	my $user_tags_ar = $tagboxdb->getTagboxTags($tagbox->{tbid}, $affected_id, 0);
	my $count = grep { !defined $_->{inactivated} } @$user_tags_ar;
#print STDERR "tag_count run: setting uid=$affected_id to count=$count (of " . scalar(@$user_tags_ar) . ")\n";
	$slashdb->setUser($affected_id, { tag_count => $count });
}

1;


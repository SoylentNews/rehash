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

		# Insert into tagboxlog_feeder
		$tagboxes = $tagboxdb->getTagboxes();
		my $activity_feeder = update_feederlog();
		sleep 5;
		last if $task_exit_flag;

		# Run tagboxes (based on tagboxlog_feeder)
		$tagboxes = $tagboxdb->getTagboxes();
		my $activity_run = run_tagboxes_until(time() + 30);
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

		my $feeder_ar = [ ];
		$feeder_ar = $tagbox->{object}->feed_newtags($tags_this_tagbox_ar);

		# XXX optimize by consolidating here: sum importances, max tagids
		# Insert the tagbox's data into the feederlog.
		insert_feederlog($tagbox, $feeder_ar) if $feeder_ar;

		# Mark the tagbox as having logged up to this point.
		# XXX The previous insert and this update should be wrapped
		# in a transaction.
		$tagboxdb->markTagboxLogged($tagbox->{tbid}, $new_maxtagid);

	}

	return 1; # something may have been changed
}

sub insert_feederlog {
	my($tagbox, $feeder_ar) = @_;
	for my $feeder_hr (@$feeder_ar) {
#print STDERR "addFeederInfo: tbid=$tagbox->{tbid} tagid=$feeder_hr->{tagid} affected_id=$feeder_hr->{affected_id} imp=$feeder_hr->{importance}\n";
		$tagboxdb->addFeederInfo($tagbox->{tbid},
			$feeder_hr->{tagid},
			$feeder_hr->{affected_id},
			$feeder_hr->{importance});
	}
}

sub run_tagboxes_until {
	my($run_until) = @_;
	my $activity = 0;

	while (time() < $run_until) {
		my $affected_ar = $tagboxdb->getMostImportantTagboxAffectedIDs();
		return $activity if !$affected_ar || !@$affected_ar;

		$activity = 1;
		for my $affected_hr (@$affected_ar) {
			my $tagbox = $tagboxdb->getTagboxes($affected_hr->{tbid}, [qw( object )]);
#my $ad = Dumper($affected_hr); $ad =~ s/\s+/ /g; my $tb = Dumper($tagbox); $tb =~ s/\s+/ /g; print STDERR "r_t_u affected_hr: $ad tagbox: $tb\n";
			$tagbox->{object}->run($affected_hr->{affected_id});
			$tagboxdb->markTagboxRunComplete(
				$affected_hr->{tbid},
				$affected_hr->{affected_id},
				$affected_hr->{max_tagid}
			);
		}

		sleep 1;
	}
	return $activity;
}

1;


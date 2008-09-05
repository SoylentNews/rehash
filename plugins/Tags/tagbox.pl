#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

# Two nontrivial improvements I'd like to make:
#
# (1)  Right now, each tagbox only keeps track of a single number,
# tagid, to indicate how far it has progressed in processing tagging
# activity.  (The other two fields, tdid and tuid, are ephemeral;
# rewinding tagid eliminates the need to check those two.)
#
# It would be nice to be able to rewind a tagbox to have it do
# reprocessing of old tags, and still have it keep reasonably near
# real-time on processing new tags as they arrive.  This would make
# testing changes to a tagbox's algorithm much easier.  The first
# problem is that this would require a mildly tricky tracking of three
# numbers: one tagid indicating how far its "real-time" processing
# has gotten and two tagids bracketing its "old/archive" processing.
#
# The second is that, while I'm reasonably happy with how the
# $feederlog_ok check should strike a balance between keeping up with
# real-time and limiting table size for overall performance, I'm not
# yet convinced it would always perform well under stress, and this
# would need to be tested.  Also, it might be desirable to (by default)
# add each "old/archive" feederlog row with a reduced importance field,
# but that only increases my concern for the need to test.
#
# (2)  Multi-processing.  See comment at the top of sbin/slashd re
# getting tasks to run on different machines;  that would almost
# certainly be a prerequisite to implementing this feature.  After
# that's done, an additional change could allow multiple tagbox.pl
# child processes to run (on the same machine or different machines),
# each taking its own set of one or more tagboxes.  It would probably
# be best to designate one the "primary tagbox.pl" which handles
# tagbox-nonspecific responsibilities like inserting nosy feederlog
# entries (and the primary might as well insert all the feederlog
# rows for that matter).  But each tagbox would only have its run() --
# the most CPU-intensive routine -- called by whichever tagbox.pl it
# was assigned to.

use strict;

use Slash;
use Slash::Constants ':slashd';
use Slash::Display;

use Data::Dumper;

use vars qw(
	%task	$me	$task_exit_flag
	$tagsdb	$tagboxdb	$tagboxes
);

$task{$me}{timespec} = '* * * * *';
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;

	$tagsdb = getObject('Slash::Tags');
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
	tagboxLog('tagbox.pl starting');

	my $exclude_behind = 1;
	my $max_activity_for_run = 10;
	my $feederlog_largerows = $constants->{tags_feederlog_largerows} || 50_000;
	my($feederlog_ok, $next_feederlog_check) = (1, 0);
	while (!$task_exit_flag) {

		$exclude_behind = ! $exclude_behind;

		# If tagboxlog_feeder has grown too large, temporarily exclude
		# adding to it until it has shrunk to a more efficient size.

		my $activity_feeder = undef;
		if (time > $next_feederlog_check) {
			my $was_ok = $feederlog_ok;
			my $feederlog_rows = $tagboxdb->sqlCount('tagboxlog_feeder');
			$feederlog_ok = $feederlog_rows < $feederlog_largerows ? 1 : 0;
			if ($feederlog_rows < $feederlog_largerows * 0.8) {
				# Table is nice and small.  Check less often.
				$next_feederlog_check = time + 600;
			} elsif ($feederlog_ok) {
				# Table is under the size limit.  Check periodically.
				$next_feederlog_check = time + 180;
			} else {
				# Table is oversize and we will take special measures
				# to shrink it.  Check frequently to see if we can
				# return to normal behavior.
				$next_feederlog_check = time + 20;
			}
			if (!$feederlog_ok || $was_ok != $feederlog_ok) {
				# XXX We might want to keep track of the
				# UNIX_TIMESTAMP(created_at) for the last tag seen by
				# update_feederlog and for the current MAX(tagid),
				# and log the difference here, so we can grep to see
				# how far behind tagbox.pl ever gets.  I believe a
				# 'SELECT MAX(tagid) FROM tags' would have a
				# worst-case that's much faster than
				# 'SELECT COUNT(*) FROM tagboxlog_feeder'.
				tagboxLog("tagbox.pl feederlog at $feederlog_rows rows, was $was_ok, is $feederlog_ok");
			}
		}
		if ($feederlog_ok) {

			# Insert into tagboxlog_feeder
			$activity_feeder = update_feederlog($exclude_behind);
			sleep 1;
			last if $task_exit_flag;

			# If there was a great deal of feeder activity, there is
			# likely to be more yet to do, and those additions might
			# obsolete the results we'd get by calling run() right now.
			if ($activity_feeder > 10) {
				tagboxLog("tagbox.pl re-updating feederlog, activity $activity_feeder");
				next;
			}

		}

		# Run tagboxes (based on tagboxlog_feeder).
		# If the feederlog is oversize, we pretend it is "overnight" to
		# force more run()s than usual, to shrink it down.
		my $force_overnight = ! $feederlog_ok;
		my $activity_run = run_tagboxes_until(time() + 30, $force_overnight);
		last if $task_exit_flag;

		# If nothing's going on, ease up some (not that it probably
		# matters much, since if nothing's going on both of the
		# above should be doing reasonably fast SELECTs).
		if (!$activity_feeder && !$activity_run) {
			tagboxLog('tagbox.pl sleeping 3');
			sleep 3;
		}
		last if $task_exit_flag;

	}

	my $msg = sprintf("exiting after %d seconds", time - $start_time);
	tagboxLog("tagbox.pl $msg");
	return $msg;
};

sub update_feederlog {
	my($exclude_behind) = @_;

	$tagboxes = $tagboxdb->getTagboxes();

	# These are kind of arbitrary constants.
	my $max_rows_per_tagbox = 1000;
	my $max_rows_total = $max_rows_per_tagbox * 5;

	# Pre-tagbox check:

	# Get list of all new globjs since last update_feederlog, and
	# insert NULL,NULL,NULL rows for each one wanted.
	my $last_globjid_logged = $tagboxdb->getVar('tags_tagbox_lastglobjid', 'value', 1) || 0;
	my $new_globjs_ar = $tagsdb->sqlSelectAllHashrefArray(
		'globjid, gtid, target_id', 'globjs',
		"globjid > $last_globjid_logged",
		"ORDER BY globjid ASC LIMIT $max_rows_per_tagbox");
	if ($new_globjs_ar && @$new_globjs_ar) {
		my %tagbox_wants = ( );
		for my $globj_hr (@$new_globjs_ar) {
			my @tbids = $tagboxdb->getTagboxesNosyForGlobj($globj_hr);
			for my $tbid (@tbids) {
				$tagbox_wants{$tbid} ||= [ ];
				push @{ $tagbox_wants{$tbid} }, $globj_hr->{globjid};
			}
		}
		for my $tbid (keys %tagbox_wants) {
			my $feeder_ar = [ ];
			for my $globjid (@{ $tagbox_wants{$tbid} }) {
				push @$feeder_ar, {
					affected_id =>	$globjid,
					importance =>	1,
					tagid =>	undef,
					tdid =>		undef,
					tuid =>		undef,
				};
			}
			insert_feederlog($tagboxdb->getTagboxes($tbid), $feeder_ar);
		}
		$tagboxdb->setVar('tags_tagbox_lastglobjid', $new_globjs_ar->[-1]{globjid});
	}

	# Now check tagboxes:

	# If this is called with $exclude_behind set, ignore tagboxes
	# which are too far behind other tagboxes.  For this purpose,
	# only last_tagid_logged is examined, since the other two are
	# expired regularly and thus don't generally hold much data.
	my $max_max_tagid = 0;
	if ($exclude_behind) {
		for my $tagbox (@$tagboxes) {
			$max_max_tagid = $tagbox->{last_tagid_logged} if $tagbox->{last_tagid_logged} > $max_max_tagid;
		}
	}
	if ($exclude_behind && $max_max_tagid > $max_rows_total*2) {
		my %exclude = ( );
		for my $tagbox (@$tagboxes) {
			if ($tagbox->{last_tagid_logged} < $max_max_tagid - $max_rows_total*2) {
				$exclude{ $tagbox->{tbid} } = 1;
			}
		}
		if (%exclude) {
			$tagboxes = [ grep { !$exclude{ $_->{tbid} } } @$tagboxes ];
		}
	}

	return 0 unless @$tagboxes;

	# In preparation for doing each tagbox's processing, figure out
	# which data we need to select from the three source tables
	# (tags, tags_deactivated, and tags_userchange) and select the
	# rows needed from each table.

	my $min_max_tagid = $tagboxes->[0]{last_tagid_logged};
	my $min_max_tdid = $tagboxes->[0]{last_tdid_logged};
	my $min_max_tuid = $tagboxes->[0]{last_tuid_logged};
	for my $tagbox (@$tagboxes) {
		$min_max_tagid = $tagbox->{last_tagid_logged} if $tagbox->{last_tagid_logged} < $min_max_tagid;
		$min_max_tuid  = $tagbox->{last_tuid_logged}  if $tagbox->{last_tuid_logged}  < $min_max_tuid;
		$min_max_tdid  = $tagbox->{last_tdid_logged}  if $tagbox->{last_tdid_logged}  < $min_max_tdid;
	}
	# Get the user change data.
	my $userchange_ar = $tagsdb->sqlSelectAllHashrefArray(
		'*', 'tags_userchange',
		"tuid > $min_max_tuid",
		"ORDER BY tuid ASC LIMIT $max_rows_total");
	my $max_tuid = @$userchange_ar ? $userchange_ar->[-1]{tuid} : undef;
	# Get the deactivated tags data.
	my $deactivated_ar = $tagsdb->sqlSelectAllHashrefArray(
		'*', 'tags_deactivated',
		"tdid > $min_max_tdid",
		"ORDER BY tdid ASC LIMIT $max_rows_total");
	my $max_tdid = @$deactivated_ar ? $deactivated_ar->[-1]{tdid} : undef;
	# If there were any deactivated tags, add those to the list of
	# tags to get.
	my $deactivated_tagids_clause = '';
	if ($deactivated_ar && @$deactivated_ar) {
		$deactivated_tagids_clause = ' OR tagid IN ('
			. join(',', map { $_->{tagid} } @$deactivated_ar)
			. ')';
	}
	# Get the tags data.
	my $tags_ar = $tagsdb->sqlSelectAllHashrefArray(
		'*, UNIX_TIMESTAMP(created_at) AS created_at_ut',
		'tags',
		"tagid > $min_max_tagid $deactivated_tagids_clause",
		"ORDER BY tagid ASC LIMIT $max_rows_total");
	my $max_tagid = @$tags_ar ? $tags_ar->[-1]{tagid} : undef;

	# If nothing changed, we're done.
	return 0 if
		   (!$userchange_ar  || !@$userchange_ar)
		&& (!$deactivated_ar || !@$deactivated_ar)
		&& (!$tags_ar        || !@$tags_ar);

	# For each tagbox, we're going to do some processing for each
	# of these three data types.  We'll first call that tagbox's
	# feed_newtags() method for the tags it hasn't seen yet.
	# Then we'll call feed_deactivatedtags() for the deactivated
	# tags it hasn't seen yet.  Then feed_userchanges() for the user
	# changes it hasn't seen yet.  After each call, insert whatever
	# data the tagbox returns into the tagboxlog_feeder table and
	# then mark that tagbox as being logged up to that point.

	my $clout_types = $tagsdb->getCloutTypes();
	for my $tagbox (@$tagboxes) {

		$tagbox->{object}->info_log("last=$tagbox->{last_tagid_logged}");

		my @tags_copy = @$tags_ar;
		my $clout_type = $clout_types->{ $tagbox->{clid} };
		$tagsdb->addCloutsToTagArrayref(\@tags_copy, $clout_type);

		my $feeder_ar;

		#### Newly created tags
		if (@tags_copy) {
			my $tags_this_tagbox_ar = [
				grep { $_->{tagid} > $tagbox->{last_tagid_logged} }
				@tags_copy
			];
			# Mostly for responsiveness reasons, don't process
			# more than 1000 feeder rows at a time.
			$#$tags_this_tagbox_ar = $max_rows_per_tagbox-1
					if $#$tags_this_tagbox_ar > $max_rows_per_tagbox-1;
			if (@$tags_this_tagbox_ar) {
				my $max_tagid_this = $tags_this_tagbox_ar->[-1]{tagid};
				# Call the class's feed_newtags to determine importance etc.
				$feeder_ar = undef;
				$feeder_ar = $tagbox->{object}->feed_newtags($tags_this_tagbox_ar);
				# XXX optimize by consolidating here: sum importances, max tagids
				insert_feederlog($tagbox, $feeder_ar) if $feeder_ar;
				# XXX The previous insert and this update should be wrapped
				# in a transaction.
				$tagbox->{object}->markTagboxLogged(
					{ last_tagid_logged => $max_tagid_this });
			}
		}

		### Newly deactivated tags
		# (this one's a little fancy because feed_deactivatedtags
		# wants the rows from the tags table)
		if (@$deactivated_ar) {
			# Make a list of all the tagid's deactivated since the
			# last time this tagbox logged.
			my $deactivated_tagids_this_tagbox_hr = {
				map { ( $_->{tagid}, $_->{tdid} ) }
				grep { $_->{tdid} > $tagbox->{last_tdid_logged} }
				@$deactivated_ar
			};
			# From the main tag list, grep out only the tags that
			# were deactivated since the last time this tagbox logged.
			my $deactivated_tags_this_tagbox_ar = [
				grep { exists $deactivated_tagids_this_tagbox_hr->{ $_->{tagid} } }
				@tags_copy
			];
			# Add the tdid field to each tag in that list (the tagbox's
			# feed_deactivatedtags() method will want to pass it along
			# to the $feeder_ar data it returns).
			for my $tag_hr (@$deactivated_tags_this_tagbox_ar) {
				$tag_hr->{tdid} = $deactivated_tagids_this_tagbox_hr->{ $tag_hr->{tagid} };
			}
			if (@$deactivated_tags_this_tagbox_ar) {
				# Mostly for responsiveness reasons, don't process
				# more than 1000 feeder rows at a time.
				$#$deactivated_tags_this_tagbox_ar = $max_rows_per_tagbox-1
					if $#$deactivated_tags_this_tagbox_ar > $max_rows_per_tagbox-1;
				my $max_tdid_this = $deactivated_tags_this_tagbox_ar->[-1]{tdid};
				# Call the class's feed_deactivatedtags to determine importance etc.
				$feeder_ar = undef;
				$feeder_ar = $tagbox->{object}->feed_deactivatedtags($deactivated_tags_this_tagbox_ar);
				# XXX optimize
				insert_feederlog($tagbox, $feeder_ar) if $feeder_ar;
				# XXX The previous insert and this update should be wrapped
				# in a transaction.
				$tagbox->{object}->markTagboxLogged(
					{ last_tdid_logged => $max_tdid_this });
			}
		}

		### New changes to users
		if (@$userchange_ar) {
			my $userchanges_this_tagbox_ar = [
				# XXX grep out changes this tagbox's regex doesn't match
				grep { $_->{tuid} > $tagbox->{last_tuid_logged} }
				@$userchange_ar
			];
			if (@$userchanges_this_tagbox_ar) {
				# Mostly for responsiveness reasons, don't process
				# more than 1000 feeder rows at a time.
				$#$userchanges_this_tagbox_ar = $max_rows_per_tagbox-1
					if $#$userchanges_this_tagbox_ar > $max_rows_per_tagbox-1;
				my $max_tuid_this = $userchanges_this_tagbox_ar->[-1]{tuid};
				# Call the class's feed_userchanges to determine importance etc.
				$feeder_ar = undef;
				$feeder_ar = $tagbox->{object}->feed_userchanges($userchanges_this_tagbox_ar);
				# XXX optimize
				insert_feederlog($tagbox, $feeder_ar) if $feeder_ar;
				# XXX The previous insert and this update should be wrapped
				# in a transaction.
				$tagbox->{object}->markTagboxLogged(
					{ last_tuid_logged => $max_tuid_this });
			}
		}

	}

	# Eliminate rows no longer needed.
	$tagboxdb->sqlDelete('tags_userchange',  "tuid <= $max_tuid") if $max_tuid;
	$tagboxdb->sqlDelete('tags_deactivated', "tdid <= $max_tdid") if $max_tdid;

	return 1; # something may have been changed
}

sub insert_feederlog {
	my($tagbox_hr, $feeder_ar) = @_;
	for my $feeder_hr (@$feeder_ar) {
		$tagbox_hr->{object}->addFeederInfo($feeder_hr);
	}
}

sub run_tagboxes_until {
	my($run_until, $force_overnight) = @_;
	my $constants = getCurrentStatic();
	my $activity = 0;
	$tagboxes = $tagboxdb->getTagboxes();
	my $overnight_sum = defined($constants->{tags_overnight_minweightsum})
		? $constants->{tags_overnight_minweightsum}
		: 1;
	my $overnight_starthour = $constants->{tags_overnight_starthour} ||  7;
	my $overnight_stophour  = $constants->{tags_overnight_stophour}  || 10;

	while (time() < $run_until && !$task_exit_flag) {
		my $cur_count = 10;
		my $cur_minweightsum = 1;
		my $try_to_reduce_rowcount = 0;

		# If it's "overnight" (as defined in vars, or determined by
		# tags_feederlog_largerows), purge some feeder log rows.
		my $is_overnight = $force_overnight;
		if (!$is_overnight) {
			my $gmhour = (gmtime)[2];
			if ($gmhour >= $overnight_starthour && $gmhour <= $overnight_stophour) {
				$is_overnight = 1;
			}
		}
		if ($is_overnight) {
			$cur_count = 50;
			$cur_minweightsum = $overnight_sum;
			$try_to_reduce_rowcount = 1;
		}

		my $affected_ar = $tagboxdb->getMostImportantTagboxAffectedIDs({
			num			=> $cur_count,
			min_weightsum		=> $cur_minweightsum,
			try_to_reduce_rowcount	=> $try_to_reduce_rowcount,
		});
		return $activity if !$affected_ar || !@$affected_ar;

		# XXX We should really define a Slash::Tagbox::run_multi, and group the
		# returned $affected_hr's by tbid and pass each group in at once.

		$activity = 1;
		for my $affected_hr (@$affected_ar) {
			my $tagbox_obj = $tagboxdb->getTagboxObject($affected_hr->{tbid});

			$tagbox_obj->run($affected_hr->{affected_id});

			$tagboxdb->markTagboxRunComplete($affected_hr);
			last if time() >= $run_until || $task_exit_flag;
		}

		Time::HiRes::sleep(0.1);
	}
	return $activity;
}

1;


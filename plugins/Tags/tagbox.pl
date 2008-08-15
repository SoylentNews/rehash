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
	while (!$task_exit_flag) {

		$exclude_behind = ! $exclude_behind;

		# If tagboxlog_feeder has grown too large, temporarily exclude
		# adding to it until it has shrunk to a more efficient size.

		my $feederlog_rows = $tagboxdb->sqlCount('tagboxlog_feeder');
		my $activity_feeder = undef;
		if ($feederlog_rows < $feederlog_largerows) {

			# Insert into tagboxlog_feeder
			$activity_feeder = update_feederlog($exclude_behind);
			sleep 2;
			last if $task_exit_flag;

			# If there was a great deal of feeder activity, there is
			# likely to be more yet to do, and it may obsolete the
			# results we'd get by calling run() right now.
			if ($activity_feeder > 10) {
				tagboxLog("tagbox.pl re-updating feederlog, activity $activity_feeder");
				next;
			}

		}

		# Run tagboxes (based on tagboxlog_feeder)
		my $force_overnight = $feederlog_rows < $feederlog_largerows ? 0 : 1;
		my $activity_run = run_tagboxes_until(time() + 30, $force_overnight);
		sleep 2;
		last if $task_exit_flag;

		# If nothing's going on, ease up more (not that it probably
		# matters much, since if nothing's going on both of the
		# above should be doing reasonably fast SELECTs).
		if (!$activity_feeder && !$activity_run) {
			tagboxLog('tagbox.pl sleeping 10');
			sleep 10;
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
			insert_feederlog($tbid, $feeder_ar);
		}
		$tagboxdb->setVar('tags_tagbox_lastglobjid', $new_globjs_ar->[-1]{globjid});
	}

	# Now check tagboxes:

	# If this is called with $exclude_behind set, ignore tagboxes
	# which are too far behind other tagboxes.  For this purpose,
	# only last_tagid_logged is examined, since the other two are
	# expired and don't generally hold much data.
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

main::tagboxLog("update_feederlog name=$tagbox->{name} tbid=$tagbox->{tbid} objtbid=$tagbox->{object}{tbid} last=$tagbox->{last_tagid_logged}");

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
main::tagboxLog("update_feederlog name=$tagbox->{name} inserting " . ($feeder_ar ? scalar(@$feeder_ar) : 'none') . ' based on ' . scalar(@$tags_this_tagbox_ar) . ' tags');
				insert_feederlog($tagbox, $feeder_ar) if $feeder_ar;
				# XXX The previous insert and this update should be wrapped
				# in a transaction.
				$tagboxdb->markTagboxLogged($tagbox->{tbid},
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
				$tagboxdb->markTagboxLogged($tagbox->{tbid},
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
				$tagboxdb->markTagboxLogged($tagbox->{tbid},
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
	my($tagbox, $feeder_ar) = @_;
	for my $feeder_hr (@$feeder_ar) {
{ my $fstr = Dumper($feeder_hr); $fstr =~ s/\s+/ /g; main::tagboxLog("addFeederInfo: tbid=$tagbox->{tbid} f: $fstr"); }
		$tagboxdb->addFeederInfo($tagbox->{tbid}, $feeder_hr);
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

		# If it's "overnight" (as defined in vars), purge the feeder log
		# further down.
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
		}

		my $affected_ar = $tagboxdb->getMostImportantTagboxAffectedIDs($cur_count, $cur_minweightsum);
		return $activity if !$affected_ar || !@$affected_ar;

		$activity = 1;
		for my $affected_hr (@$affected_ar) {
			my $tagbox = $tagboxdb->getTagboxes($affected_hr->{tbid}, [qw( object )]);
#my $ad = Dumper($affected_hr); $ad =~ s/\s+/ /g; my $tb = Dumper($tagbox); $tb =~ s/\s+/ /g; print STDERR "r_t_u affected_hr: $ad tagbox: $tb\n";
if ($affected_hr->{tbid} == 17) {
my $feeder_ar = $tagboxdb->sqlSelectAllHashrefArray('*', 'tagboxlog_feeder', "tbid=17 AND affected_id=$affected_hr->{affected_id}", 'ORDER BY tfid');
print STDERR "r_t_u rows for tbid=17 id=$affected_hr->{affected_id}: " . Dumper($feeder_ar)
}
if (! $tagbox->{object}) { die "no object for tbid=$affected_hr->{tbid}: " . Dumper($tagbox) }
			$tagbox->{object}->run($affected_hr->{affected_id});
			$tagboxdb->markTagboxRunComplete($affected_hr);
			last if time() >= $run_until || $task_exit_flag;
		}

		Time::HiRes::sleep(0.2);
	}
	return $activity;
}

1;


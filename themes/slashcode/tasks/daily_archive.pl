#!/usr/bin/perl -w

use strict;

use Slash::Constants ':slashd';

use vars qw( %task $me );

# Remember that timespec goes by the database's time, which should be
# GMT if you installed everything correctly.  So 6:07 AM GMT is a good
# sort of midnightish time for the Western Hemisphere.  Adjust for
# your audience and admins.
#
#
# This task takes the following options
# 	archive_limit	=> max. number of archived stories to process
# 	archive_dir	=> direction of progression, one of: ASC, or DESC

$task{$me}{timespec} = '7 7 * * *';
$task{$me}{timespec_panic_2} = ''; # if major panic, dailyStuff can wait
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($vuser, $consts, $slashdb, $user) = @_;
	my(@rc);

	slashdLog('Updating User Logins Begin');
	$slashdb->updateStamps();
	slashdLog('Updating User Logins End');

	slashdLog('Update Total Counts Begin');
	my $totalHits = $slashdb->getVar("totalhits");
	my $count = $slashdb->countAccesslogDaily();
	$slashdb->setVar("totalhits", $totalHits);
	slashdLog('Update Total Counts End');

	slashdLog('Daily Deleting Begin');
	$slashdb->deleteDaily();
	slashdLog('Daily Deleting End');

	# Mark discussions as archived.
	$slashdb->updateArchivedDiscussions();
	# Archive stories.
	my $limit = $consts->{task_options}{archive_limit} || 500;
	my $dir   = $consts->{task_options}{archive_dir}   || 'ASC';
	my $astories = $slashdb->getArchiveList($limit, $dir);
	if ($astories && @{$astories}) {
		slashdLog('Daily Archival Begin');
		@rc = archiveStories($vuser,$consts,$slashdb,$user,$astories);
		slashdLog("Daily Archival End ($rc[0] articles in $rc[1]s)");
	}

	slashdLog('Begin Daily Comment Recycle');
	my $msg = $slashdb->deleteRecycledComments();
	slashdLog("End Daily Comment Recycle ($msg recycled)");
};


sub archiveStories {
	my($virtual_user, $constants, $slashdb, $user, $to_archive) = @_;
	# Story archival.
	my $starttime = Time::HiRes::time();

	my $totalChangedStories = 0;
	for (@{$to_archive}) {
		my($sid, $title, $section) = @{$_};

		slashdLog("Archiving $sid") if verbosity() >= 2;
		$totalChangedStories++;
		my $args = "ssi=yes sid='$sid' mode=archive"; 

		# Use backup database handle only if told to and if it is 
		# different than the current virtual user.
		my $vu;
		$vu .= "virtual_user=$constants->{backup_db_user}"
			if $constants->{backup_db_user} &&
			   ($virtual_user ne $constants->{backup_db_user}) &&
			   $constants->{archive_use_backup_db};
		$vu ||= "virtual_user=$virtual_user";
		$args .= " $vu"; 

		my @rc;
		if ($section) {
			$args .= " section=$section";
			makeDir($constants->{basedir}, $section, $sid);
			# Note the change in prog2file() invocation.
			@rc = prog2file(
				"$constants->{basedir}/article.pl",
				"$constants->{basedir}/$section/$sid.shtml", {
					args =>		$args,
					verbosity =>	verbosity(),
					handle_err =>	1
			});
			if (verbosity() >= 2) {
				my $log="$me archived $section:$sid ($title)";
				slashdLog($log);
				slashdLog("Error channel:\n$rc[1]")
					if verbosity() >= 3;
			}
		} else {
			# Note the change in prog2file() invocation.
			@rc = prog2file(
				"$constants->{basedir}/article.pl",
				"$constants->{basedir}/$sid.shtml", {
					args =>		$args,
					verbosity =>	verbosity(),
					handle_err =>	1
			});
			if (verbosity() >= 2) {
				slashdLog("$me archived $sid ($title)");
				slashdLog("Error channel:\n$rc[1]")
					if verbosity() >= 3;
			}
		}

		# Now we extract what we need from the error channel.
		slashdLog("$me *** Update data not in error channel: '@rc'")
			unless $rc[1] =~ /count (\d+), hitparade (.+)$/m;

		my $cc = $1 || 0;
		my $hp = $2 || 0;
		$slashdb->setStory($sid, { 
			writestatus  => 'archived',
			commentcount => $cc,
			hitparade    => $hp,
		});
	}
	my $duration = sprintf("%.2f", Time::HiRes::time() - $starttime);
	
	return ($totalChangedStories, $duration);
};

1;


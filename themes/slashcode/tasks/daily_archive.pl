#!/usr/bin/perl -w

use strict;

use Fcntl;
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
	my($virtual_user, $constants, $slashdb, $user) = @_;
	my $basedir = $constants->{basedir};

	slashdLog('Updating User Logins Begin');
	$slashdb->updateStamps();
	slashdLog('Updating User Logins End');

	slashdLog('Update Total Counts Begin');
	my $totalHits = $slashdb->getVar("totalhits", '', 1);
	my $count = $slashdb->countAccesslogDaily();
	$slashdb->setVar("totalhits", $totalHits);
	slashdLog('Update Total Counts End');

	slashdLog('Daily Deleting Begin');
	$slashdb->deleteDaily();
	slashdLog('Daily Deleting End');

	# Mark discussions as archived.
	$slashdb->updateArchivedDiscussions();
	# Archive stories.
	my $limit = $constants->{task_options}{archive_limit} || 500;
	my $dir   = $constants->{task_options}{archive_dir}   || 'ASC';
	my $astories = $slashdb->getArchiveList($limit, $dir);
	if ($astories && @{$astories}) {
		slashdLog('Daily Archival Begin');
		my @count = archiveStories($virtual_user, $constants,
			$slashdb, $user, $astories);
		slashdLog("Daily Archival End ($count[0] articles in $count[1]s)");
	}

	slashdLog('Begin Daily Comment Recycle');
	my $msg = $slashdb->deleteRecycledComments();
	slashdLog("End Daily Comment Recycle ($msg recycled)");
};

sub archiveStories {
	my($virtual_user, $constants, $slashdb, $user, $to_archive) = @_;
	# Story archival.
	my $starttime = Time::HiRes::time();

	my $vu = "virtual_user=$virtual_user";
	if ($constants->{backup_db_user}
		&& ($virtual_user ne $constants->{backup_db_user})
		&& $constants->{archive_use_backup_db}) {
		$vu = "virtual_user=$constants->{backup_db_user}";
	}
	
	my $totalChangedStories = 0;
	for (@{$to_archive}) {
		my($sid, $title, $section) = @{$_};

		slashdLog("Archiving $sid") if verbosity() >= 2;
		$totalChangedStories++;

                # We need to pull some data from a file that article.pl will
		# write to.  But first it needs us to create the file and
		# tell it where it will be.
		my($cchp_file, $cchp_param) = _make_cchp_file();

		my $args = "$vu ssi=yes sid='$sid' mode=archive$cchp_param"; 
		my($filename, $logmsg);
		if ($section) {
			$filename = "$constants->{basedir}/$section/$sid.shtml";
			$logmsg = "$me archived $section:$sid ($title)";
			$args .= " section='$section'";
			makeDir($constants->{basedir}, $section, $sid);
		} else {
			$filename = "$constants->{basedir}/$sid.shtml";
			$logmsg = "$me archived $sid ($title)";
		}
		prog2file(
			"$constants->{basedir}/article.pl",
			$filename, {
				args =>		$args,
				verbosity =>	verbosity(),
				handle_err =>	1
		});
		slashdLog($logmsg);

		# Now we extract what we need from the file we created
		my($cc, $hp) = _read_and_unlink_cchp_file($cchp_file);
		if (defined($cc)) {
			# all is well, data was found
			$slashdb->setStory($sid, {
				writestatus  => 'archived',
				commentcount => $cc,
				hitparade    => $hp,
			});
		}
	}
	my $duration = sprintf("%.2f", Time::HiRes::time() - $starttime);
	
	return ($totalChangedStories, $duration);
};

sub _make_cchp_file {
	my $constants = getCurrentStatic();
	my $logdir = $constants->{logdir};
	my $cchp_prefix = catfile($logdir, "cchp.");
	my $cchp_fh = undef;
	my $cchp_suffix;
	my($cchp_file, $cchp_param) = ("", "");
	while (!$cchp_fh) {
		$cchp_file = File::Temp::mktemp("${cchp_prefix}XXXXXXXXXX");
		($cchp_suffix) = $cchp_file =~ /^\Q$cchp_prefix\E(.+)$/;
		$cchp_param = " cchp='$cchp_suffix'";
		if (!sysopen($cchp_fh, $cchp_file,
			O_WRONLY | O_EXCL | O_CREAT, # we must create it
			0600 # this must be 0600 for mild security reasons
		)) {
			$cchp_fh = undef; # just to be sure we repeat
			warn "could not create '$cchp_file', $!, retrying";
			Time::HiRes::sleep(0.2);
		}
	}
	close $cchp_fh;
	return ($cchp_file, $cchp_param);
}

sub _read_and_unlink_cchp_file {
	my($cchp_file) = @_;
	my $constants = getCurrentStatic();
	my($cc, $hp) = (undef, undef);
	my $default_hp = join(",", ("0") x
		($constants->{maxscore}-$constants->{minscore}+1));

	# Now we extract what we need from the file we created
	if (!open(my $cchp_fh, "<", $cchp_file)) {
		warn "cannot open $cchp_file for reading, $!";
	} else {
		my $cchp = <$cchp_fh>;
		close $cchp_fh;
		if ($cchp && (($cc, $hp) = $cchp =~
			/count (\d+), hitparade (.+)$/m)) {
		} else {
			slashdLog("Commentcount/hitparade data was not"
				. " retrieved, reason unknown"
				. " (cchp: '$cchp')");
			($cc, $hp) = (undef, undef);
		}
	}
	unlink $cchp_file;
	return($cc, $hp);
}

1;


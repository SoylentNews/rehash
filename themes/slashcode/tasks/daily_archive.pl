#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

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

$task{$me}{timespec} = '7 8 * * *';
$task{$me}{timespec_panic_2} = ''; # if major panic, dailyStuff can wait
$task{$me}{resource_locks} = { log_slave => 1 };
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;
	my $basedir = $constants->{basedir};

	# Takes approx. 10 seconds on Slashdot
	# (approx. 6 minutes if subscribe_hits_only is set)
	slashdLog('Updating User Logins Begin');
	$slashdb->updateLastaccess();
	slashdLog('Updating User Logins End');

	# Takes approx. 2 seconds on Slashdot
	slashdLog('Decaying User Tokens Begin');
	my $decayed = $slashdb->decayTokens();
	slashdLog("Decaying User Tokens End ($decayed decayed)");
	if ($decayed and my $statsSave = getObject('Slash::Stats::Writer')) {
		$statsSave->addStatDaily("mod_tokens_lost_decayed", $decayed);
	}

	# Takes approx. 60 seconds on Slashdot
	my $logdb = getObject('Slash::DB', { db_type => 'log_slave' });
	slashdLog('Update Total Counts Begin');
	# I'm pulling the value out with "+0" because that returns us an
	# exact integer instead of scientific notation which rounds off.
	# Another one of those SQL oddities! - Jamie 2003/08/12
	my $totalHits = $slashdb->sqlSelect("value+0", "vars", "name='totalhits'");
	$totalHits += $logdb->countAccesslogDaily();
	$slashdb->setVar("totalhits", $totalHits);
	slashdLog('Update Total Counts End');

	# Takes approx. 70 minutes on Slashdot
	slashdLog('Daily Deleting Begin');
	$slashdb->deleteDaily();
	slashdLog('Daily Deleting End');

	# Mark discussions as archived.  Less than 1 second.
	$slashdb->updateArchivedDiscussions();

	# Archive stories.
	my $limit = $constants->{task_options}{archive_limit} || $constants->{archive_limit} || 500;
	my $dir   = $constants->{task_options}{archive_dir}   || $constants->{archive_dir} || 'ASC';
	my $astories = $slashdb->getArchiveList($limit, $dir);
	if ($astories && @{$astories}) {
		# Takes approx. 2 minutes on Slashdot
		slashdLog('Daily Archival Begin');
		my @count = archiveStories($virtual_user, $constants,
			$slashdb, $user, $astories);
		slashdLog("Daily Archival End ($count[0] of $count[1] articles in $count[2]s)");
	}

	# Takes approx. 15 seconds on Slashdot
	slashdLog('Begin Daily Comment Recycle');
	my $msg = $slashdb->deleteRecycledComments();
	slashdLog("End Daily Comment Recycle ($msg recycled)");
};

sub archiveStories {
	my($virtual_user, $constants, $slashdb, $user, $to_archive) = @_;
	# Story archival.
	my $starttime = Time::HiRes::time();
	my $db = getObject('Slash::DB', { db_type => 'reader' });
	my $vu = "virtual_user=$db->{virtual_user}";
	
	my $totalTriedStories = 0;
	my $totalChangedStories = 0;
	for my $story (@$to_archive) {
		# XXXSECTIONTOPICS - now $section is NOT set here - Jamie
		my($stoid, $sid, $title, $section) = @$story;

		slashdLog("Archiving $sid") if verbosity() >= 2;
		$totalTriedStories++;

		# We need to pull some data from a file that article.pl will
		# write to.  But first it needs us to create the file and
		# tell it where it will be.
		my($cchp_file, $cchp_param) = _make_cchp_file();

		my $args = "$vu ssi=yes sid='$sid' mode=archive$cchp_param"; 
		my($filename, $logmsg);
		if ($section) {
			$filename = "$constants->{basedir}/$section/$sid.shtml";
			$logmsg = "archived $section:$sid ($title)";
			$args .= " section='$section'";
			makeDir($constants->{basedir}, $section, $sid);
		} else {
			$filename = "$constants->{basedir}/$sid.shtml";
			$logmsg = "archived $sid ($title)";
		}
		slashdLog("prog2file: $constants->{basedir}/article.pl $args") if verbosity() >= 3;
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
			$slashdb->setStory($stoid, {
				writestatus  => 'archived',
				commentcount => $cc,
				hitparade    => $hp,
			});
			$totalChangedStories++;
		}
	}
	my $duration = sprintf("%.2f", Time::HiRes::time() - $starttime);
	
	return ($totalTriedStories, $totalChangedStories, $duration);
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
				. " (cchp: '$cchp' for file '$cchp_file' exists '"
				. (-e $cchp_file) . "' len '"
				. (-s $cchp_file) . "')");
			($cc, $hp) = (undef, undef);
		}
	}
	unlink $cchp_file;
	return($cc, $hp);
}

1;


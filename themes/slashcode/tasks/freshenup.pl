#!/usr/bin/perl -w

use File::Path;
use File::Temp;
use Fcntl;
use Slash::Constants ':slashd';

use strict;

use vars qw( %task $me );

my $total_freshens = 0;

$task{$me}{timespec} = '0-59 * * * *';
$task{$me}{timespec_panic_1} = '1-59/10 * * * *';
$task{$me}{timespec_panic_2} = '';
$task{$me}{on_startup} = 1;
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info) = @_;
	my $start_time = time;
	my $basedir = $constants->{basedir};
	my $vu = "virtual_user=$virtual_user";
	my $args = "$vu ssi=yes";
	my %updates;

	# Every third invocation, we do a big chunk of work.  But the
	# other two times, we just update the top three stories and
	# the front page, skipping sectional stuff and other stories.
	my $do_all = ($info->{invocation_num} % 3 == 1) || 0;
	$do_all = 1 
		if $constants->{task_options}{run_all};

	my $max_stories = defined($constants->{freshenup_max_stories})
		? $constants->{freshenup_max_stories}
		: 100;
	$max_stories = 3 unless $do_all;

	if ($do_all) {
		my $x = 0;
		# this deletes stories that have a writestatus of 5 (now delete), 
		# which is the delete writestatus
		my $deletable = $slashdb->getStoriesWithFlag(
			'delete',
			'ASC',
			$max_stories
		);
		for my $story (@$deletable) {
			$x++;
			$updates{$story->{section}} = 1;
			$slashdb->deleteStoryAll($story->{sid});
			slashdLog("Deleting $story->{sid} ($story->{title})")
				if verbosity() >= 1;
		}
	}

	my $stories;
	
	# Render any stories that need rendering.  This used to be done
	# by admin.pl;  now admin.pl just sets story_text.rendered=NULL
	# and lets this task do it.

	$stories = $slashdb->getStoriesNeedingRender(
		$do_all ? 10 : 3
	);
	STORIES_RENDER: for my $sid (@$stories) {

		# Don't run forever...
		if (time > $start_time + 30) {
			slashdLog("Aborting stories at render, too much elapsed time");
			last STORIES_RENDER;
		}

		my $rendered;
		{
			local $user->{currentSection} = "index";
			local $user->{noicons} = "";
			local $user->{light} = "";

			# ugly hack, but for now, needed: without it, when an
			# editor edits in foo.sitename.com, saved stories get
			# rendered with that section
			Slash::Utility::Anchor::getSectionColors();

			$rendered = displayStory($sid, '', { get_cacheable => 1 });
		}
		$slashdb->setStory($sid, {
			rendered =>	$rendered,
			writestatus =>	'dirty',
		});

	}

	# Freshen the static versions of any stories that have changed.
	# This means writing the .shtml files.

	$stories = $slashdb->getStoriesWithFlag(
		$do_all ? 'all_dirty' : 'mainpage_dirty',
		'DESC',
		$max_stories
	);

	my $bailed = 0;
	my $totalChangedStories = 0;
	STORIES_FRESHEN: for my $story (@$stories) {

		# Don't run forever freshening stories.  Before we
		# stomp on too many other invocations of freshenup.pl,
		# quit and let the next invocation get some work done.
		# Since this task is run every minute, quitting after
		# 90 seconds of work should mean we only stomp on the
		# one invocation following.
		if (time > $start_time + 90) {
			slashdLog("Aborting stories at freshen, too much elapsed time");
			last STORIES_FRESHEN;
		}

		my($sid, $title, $section, $displaystatus) =
			@{$story}{qw( sid title section displaystatus )};
		slashdLog("Updating $sid") if verbosity() >= 3;
		$updates{$section} = 1;
		if ($displaystatus == 0) {
			# If this story goes on the mainpage, its being
			# dirty means the main page is dirty too,
			# regardless of which section the story is in.
			$updates{$constants->{defaultsection}} = 1;
		}
		$totalChangedStories++;

		# We need to pull some data from a file that article.pl will
		# write to.  But first it needs us to create the file and
		# tell it where it will be.
		my($cchp_file, $cchp_param) = _make_cchp_file();

		# Now call prog2file().
		$args = "$vu ssi=yes sid='$sid'$cchp_param";
		my($filename, $logmsg);
		if ($section) {
			$filename = "$basedir/$section/$sid.shtml";
			$args .= " section='$section'";
			$logmsg = "$me updated $section:$sid ($title)";
			makeDir($basedir, $section, $sid);
		} else {
			$filename = "$basedir/$sid.shtml";
			$logmsg = "$me updated $sid ($title)";
		}
		prog2file(
			"$basedir/article.pl",
			$filename, {
				args =>		$args,
				verbosity =>	verbosity(),
				handle_err =>	1,
		});
		slashdLog($logmsg) if verbosity() >= 2;

		# Now we extract what we need from the file we created
		my($cc, $hp) = _read_and_unlink_cchp_file($cchp_file, $cchp_param);
		if (defined($cc)) {
			# all is well, data was found
			$slashdb->setStory($sid, { 
				writestatus  => 'ok',
				commentcount => $cc,
				hitparade    => $hp,
			});
		}
	}

	my $w = $slashdb->getVar('writestatus', 'value', 1);

	my($base) = split(/\./, $constants->{index_handler});

	# Does the homepage need to be freshened whether we think it's
	# necessary or not?
	my $min_days = $constants->{freshen_homepage_min_minutes} || 0;
	if ($min_days) {
		# It's actually in minutes right now;  convert to days for -M.
		$min_days /= 60*24;
		my $basefile = "$basedir/$base.shtml";
		# (Re)write index.shtml if it's missing, empty, or old.
		$w = 'notok' if !-s $basefile || -M _ > $min_days;
	}

	my $dirty_sections;
	if ($constants->{task_options}{run_all}) {
		my $sections = $slashdb->getDescriptions('sections-all');
		for (keys %$sections) {
			push @$dirty_sections, $_;
		}
	} else {
		$dirty_sections = $slashdb->getSectionsDirty();
	}
	for my $cleanme (@$dirty_sections) { $updates{$cleanme} = 1 }

	$args = "$vu ssi=yes";
	if ($updates{$constants->{defaultsection}} ne "" || $w ne "ok") {
		my($base) = split(/\./, $constants->{index_handler});
		$slashdb->setVar("writestatus", "ok");
		prog2file(
			"$basedir/$constants->{index_handler}", 
			"$basedir/$base.shtml", {
				args =>		"$args section='$constants->{section}'",
				verbosity =>	verbosity(),
				handle_err =>	0
		});
	}

	if ($do_all) {
		for my $key (keys %updates) {
			my $section = $slashdb->getSection($key);
			createCurrentHostname($section->{hostname});
			next unless $key;
			my $index_handler = $section->{index_handler}
				|| $constants->{index_handler};
			my($base) = split(/\./, $index_handler);
			prog2file(
				"$basedir/$index_handler", 
				"$basedir/$key/$base.shtml", {
					args =>		"$args section='$key'",
					verbosity =>	verbosity(),
					handle_err =>	0
			});
			$slashdb->setSection($key, { writestatus => 'ok' });
		}
	}

	return $totalChangedStories ?
		"totalChangedStories $totalChangedStories" : '';
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
	my($cchp_file, $cchp_param) = @_;
	my $constants = getCurrentStatic();
	my($cc, $hp) = (undef, undef);
	my $default_hp = join(",", ("0") x
		($constants->{maxscore}-$constants->{minscore}+1));

	# Now we extract what we need from the file we created
	sleep 3;
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
				. " (cchp: '$cchp' for param '$cchp_param' file '$cchp_file' exists '"
				. (-e $cchp_file) . "' len '"
				. (-s $cchp_file) . "')");
			($cc, $hp) = (undef, undef);
		}
	}
	unlink $cchp_file;
	return($cc, $hp);
}

1;

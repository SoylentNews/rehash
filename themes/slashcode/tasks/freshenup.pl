#!/usr/bin/perl -w

use File::Path;
use File::Temp;
use Fcntl;
use Slash::Constants ':slashd';

use strict;

use vars qw( %task $me );

my $total_freshens = 0;

$task{$me}{timespec} = '1-59/3 * * * *';
$task{$me}{timespec_panic_1} = '1-59/10 * * * *';
$task{$me}{timespec_panic_2} = '';
$task{$me}{on_startup} = 1;
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;
	my %updates;

	my $x = 0;
	# this deletes stories that have a writestatus of 5 (now delete), 
	# which is the delete writestatus
	my $deletable = $slashdb->getStoriesWithFlag('delete');
	for (@$deletable) {
		my($sid, $title, $section) = @$_;
		$x++;
		$updates{$section} = 1;
		$slashdb->deleteStoryAll($sid);
		slashdLog("Deleting $sid ($title)") if verbosity() >= 1;
	}
	my $stories = $slashdb->getStoriesWithFlag('dirty');
	my $max_stories = defined($constants->{freshenup_max_stories})
		? $constants->{freshenup_max_stories}
		: 100;
	if ($max_stories && scalar(@$stories) > $max_stories) {
		# There are too many stories marked as dirty.  Just update
		# some of the most recent ones (sorted by sid, which is
		# vaguely the same as chronological order), then skip ahead
		# to the index.shtml's, and pick up the rest of the stories
		# next time around.
		@$stories = (sort {
			$a->[0] cmp $b->[0]		# sort by sid
		} @$stories)[-$max_stories..-1];
	}
	my $totalChangedStories = 0;
	my $vu = "virtual_user=$virtual_user";
	my $default_hp = join(",", ("0") x
		($constants->{maxscore}-$constants->{minscore}+1));

	for (@$stories) {

		my($sid, $title, $section) = @$_;
		slashdLog("Updating $sid") if verbosity() >= 2;
		$updates{$section} = 1;
		$totalChangedStories++;

		# We need to pull some data from a file that article.pl will
		# write to.  But first it needs us to create the file and
		# tell it where it will be.
		my $logdir = $constants->{logdir};
		my $basedir = $constants->{basedir};
		my $cchp_prefix = catfile($logdir, "cchp.");
		my $cchp_fh = undef;
		my($cchp_file, $cchp_suffix, $cchp_param);
		while (!$cchp_fh) {
			$cchp_file = File::Temp::mktemp("${cchp_prefix}XXXXXXXX");
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
		if ($section) {
			makeDir($constants->{basedir}, $section, $sid);
			prog2file(
				"$constants->{basedir}/article.pl",
				"$vu ssi=yes sid='$sid' section='$section'$cchp_param",
				"$constants->{basedir}/$section/$sid.shtml",
				verbosity(), 1
			);
			slashdLog("$me updated $section:$sid ($title)")
				if verbosity() >= 2;
		} else {
			prog2file(
				"$constants->{basedir}/article.pl",
				"$vu ssi=yes sid='$sid'$cchp_param",
				"$constants->{basedir}/$sid.shtml",
				verbosity(), 1
			);
			slashdLog("$me updated $sid ($title)")
				if verbosity() >= 2;
		}

		# Now we extract what we need from the file we created
		if (!open($cchp_fh, "<", $cchp_file)) {
			warn "cannot open $cchp_file for reading, $!";
			$cchp_param = "";
		} else {
			my $cchp = <$cchp_fh>;
			close $cchp_fh;
			my($cc, $hp) = (0, $default_hp);
			if ($cchp && (($cc, $hp) = $cchp =~
				/count (\d+), hitparade (.+)$/m)) {
				# all is well, data was found
				$slashdb->setStory($sid, { 
					writestatus  => 'ok',
					commentcount => $cc,
					hitparade    => $hp,
				});
			} else {
				slashdLog("Commentcount/hitparade data was not"
					. " retrieved, reason unknown"
					. " (cchp: '$cchp')");
			}
		}
		unlink $cchp_file;

	}

	my $w  = $slashdb->getVar('writestatus', 'value');
	my $dirty_sections = $slashdb->getSectionsDirty();
	for my $cleanme (@$dirty_sections) { $updates{$cleanme} = 1 }

	if ($updates{$constants->{defaultsection}} ne "" || $w ne "ok") {
		my($base) = split(/\./, $constants->{index_handler});
		$slashdb->setVar("writestatus", "ok");
		prog2file(
			"$constants->{basedir}/$constants->{index_handler}", 
			"$vu ssi=yes", 
			"$constants->{basedir}/$base.shtml",
			verbosity()
		);
	}

	for my $key (keys %updates) {
		my $section = $slashdb->getSection($key);
		createCurrentHostname($section->{hostname});
		next unless $key;
		my $index_handler = $section->{index_handler}
			|| $constants->{index_handler};
		my($base) = split(/\./, $index_handler);
		prog2file(
			"$constants->{basedir}/$index_handler", 
			"$vu ssi=yes section=$key",
			"$constants->{basedir}/$key/$base.shtml",
			verbosity()
		);
		$slashdb->setSection($key, { writestatus => 'ok' });
	}

	return $totalChangedStories ?
		"totalChangedStories $totalChangedStories" : '';
};

1;

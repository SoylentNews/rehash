#!/usr/bin/perl -w

use File::Path;

use strict;

use vars qw( %task $me );

my $total_freshens = 0;

$task{$me}{timespec} = '1-59/3 * * * *';
$task{$me}{timespec_panic_1} = '1-59/10 * * * *';
$task{$me}{timespec_panic_2} = '';
$task{$me}{on_startup} = 1;
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
	#my @updatedsids;
	my $totalChangedStories = 0;
	my $vu = "virtual_user=$virtual_user";
	my $default_hp = join(",", ("0") x
		($constants->{maxscore}-$constants->{minscore}+1));

	for (@$stories) {
		my($sid, $title, $section) = @$_;
		slashdLog("Updating $sid") if verbosity() >= 2;
		$updates{$section} = 1;
		$totalChangedStories++;
		# What was this for?
		#push @updatedsids, $sid;

		my @rc;
		if ($section) {
			makeDir($constants->{basedir}, $section, $sid);
			@rc = prog2file(
				"$constants->{basedir}/article.pl",
				"$vu ssi=yes sid='$sid' section='$section'",
				"$constants->{basedir}/$section/$sid.shtml",
				verbosity(), 1
			);
			slashdLog("$me updated $section:$sid ($title)")
				if verbosity() >= 2;
		} else {
			@rc = prog2file(
				"$constants->{basedir}/article.pl",
				"$vu ssi=yes sid='$sid'",
				"$constants->{basedir}/$sid.shtml",
				verbosity(), 1
			);
			slashdLog("$me updated $sid ($title)")
				if verbosity() >= 2;
		}

		# Now we extract what we need from the error channel.
		my($cc, $hp) = (0, $default_hp);
		if (@rc && $rc[1]
			&& ($cc, $hp) = $rc[1] =~ /count (\d+), hitparade (.+)$/) {
			# all is well, data was found
			$slashdb->setStory($sid, { 
				writestatus  => 'ok',
				commentcount => $cc,
				hitparade    => $hp,
			});
		} else {
			slashdLog("*** Update data not in error channel!");
		}

	}

	my $w  = $slashdb->getVar('writestatus', 'value');

	if ($updates{$constants->{defaultsection}} ne "" || $w ne "ok") {
		$slashdb->setVar("writestatus", "ok");
		prog2file(
			"$constants->{basedir}/index.pl", 
			"$vu ssi=yes", 
			"$constants->{basedir}/index.shtml",
			verbosity()
		);
	}

	foreach my $key (keys %updates) {
		next unless $key;
		prog2file(
			"$constants->{basedir}/index.pl", 
			"$vu ssi=yes section=$key",
			"$constants->{basedir}/$key/index.shtml",
			verbosity()
		);
	}

	return $totalChangedStories ?
		"totalChangedStories $totalChangedStories" : '';
};

1;

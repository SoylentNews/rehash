#!/usr/bin/perl

use strict;
use warnings;
use Slash;
use Slash::Constants ':slashd';
use Slash::Twitter;
use vars qw( %task $me %redirects );

$task{$me}{timespec} = '0-59/10 * * * *';
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;
	my $tw = getObject('Slash::Twitter');
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $max_items = $constants->{twit_max_items_outgoing} || 10;
	my $stories = $reader->getBackendStories({ limit => $max_items });

	return;

	if ($stories && @$stories) {
		my $totalcount = $reader->sqlSelect(
			"count(*)",
			"twitter_log",
			"1 = 1"
		);
		foreach my $story (@$stories) {
			# Stories are counted based on a combination of sid and title.
			# If the title is updated by an Ed, it will get pushed again.
			my $qtitle = $reader->sqlQuote($story->{title});
			$story->{link} = $reader->getSkin($story->{primaryskid})->{rootdir} . "/article.pl?sid=$story->{sid}";
			$story->{link} = $constants->{absolutedir_secure} ? "https:$story->{link}" : "http:$story->{link}";
			my $stale = $reader->sqlSelect(
				"count(*)",
				"twitter_log",
				"sid = \"$story->{sid}\" AND title = $qtitle"
			);
			print "stale: $stale\n";
			# Only want stories we haven't pushed before.
			# And don't push anything the first time we run.
			if($totalcount == 0) {
				$tw->log_story_pushed($slashdb, $story, 0);
			}
			elsif($stale) { next; }
			else {
				$tw->log_story_pushed($slashdb, $story, 1) if $tw->push_story_to_twitter($constants, $story);
			}
		}
	}
	else { return; }

	$tw->trim_stories_table($slashdb, $constants);

	return;
};

1;

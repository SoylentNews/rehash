#!/usr/bin/perl
# $Id$

use strict;
use warnings;
use utf8;
use Slash;
use Slash::Constants ':slashd';
use vars qw( %task $me %redirects );
use Net::Twitter;

$task{$me}{timespec} = '0-59/10 * * * *';
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $max_items = $constants->{rss_max_items_outgoing} || 10;
	my $stories = $reader->getBackendStories({ limit => $max_items });

	if ($stories && @$stories) {
		my $totalcount = $reader->sqlSelect(
			"count(*)",
			"twitter_log",
			"1 = 1"
		);
		foreach my $story (@$stories) {
			# Stories are counted based on a combination of sid and title.
			# If the title is updated by an Ed, it will get pushed again.
			my $qtitle = $reader->sqlQuote($story->{title};
			$story->{link} = $reader->getSkin($story->{primaryskid})->{rootdir} . "/article.pl?sid=$story->{sid}";
			my $count = $reader->sqlSelect(
				"count(*)",
				"twitter_log",
				"sid = $story->{sid} AND title = $qtitle"
			);
			# Only want stories we haven't pushed before.
			# And don't push anything the first time we run.
			if($totalcount == 0) {
				log_story_pushed($slashdb, $story, 0);
			elsif($count > 0) { next; }
			else {
				log_story_pushed($slashdb, $story, 1) if push_story_to_twitter($constants, $story);
			}
		}
	}
	else { return; }

	trim_stories_table($slashdb, $constants);

	return;
};

sub push_story_to_twitter() {
	my ($constants, $story) = @_;
	my $nt = Net::Twitter->new(
		traits => ['API::RESTv1_1', 'OAuth'],
		consumer_key => $constants->{twit_consumer_key},
		consumer_secret => $constants->{twit_consumer_secret},
		access_token => $constants->{twit_access_token},
		access_token_secret => $constants->{twit_access_token_secret},
	);
	if(! $nt->authorized ) {
		print STDERR "push_story_to_twitter(): Not authorized\n";
		return 0;
	}
	$nt->update("$story->{title} - $$story->{link}");
	return 1;
}

sub log_story_pushed() {
	my ($slashdb, $story, $shown) = @_;
	my $data = {
		sid		=> $story->{sid},
		title	=> $story->{title},
		time		=> "NOW()",
		shown	=> $shown == 0 ? "FALSE" : "TRUE"
	};
	my $rows = $slashdb->sqlInsert(
		"twitter_log",
		$data
	);
	if($rows == 0) {
		print "Failed to log sid $story->{sid} as pushed to Twitter.\n";
	}
	return;
}

sub trim_stories_table() {
	my ($slashdb, $constants) = @_;
	$slashdb->sqlDo("DELETE FROM twitter_log WHERE time < DATE_SUB(NOW(), INTERVAL $constants->{discussion_archive_delay} DAY)");
	return;
}

1;

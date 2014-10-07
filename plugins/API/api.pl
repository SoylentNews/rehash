#!/usr/bin/perl -w

use strict;
use warnings;
use utf8;
use JSON;
use Slash;
use Slash::Utility;
use Slash::Constants qw(:web :messages);
use Data::Dumper;
use Slash::API;

sub main {
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $api = Slash::API->new;
	# lc just in case

	my $endpoint = lc($form->{m});

	my $endpoints = {
		user		=> {
			function	=> \&user,
			seclev		=> 1,
		},
		comment		=> {
			function	=> \&comment,
			seclev		=> 1,
		},
		story		=> {
			function	=> \&story,
			seclev		=> 1,
		},
		auth		=> {
			function	=> \&auth,
			seclev		=> 1,
		},
		default		=> {
			function	=> \&nullop,
			seclev		=> 1,
		},

	};

	$endpoint = 'default' unless $endpoints->{$endpoint};

	my $retval = $endpoints->{$endpoint}{function}->($form, $slashdb, $user, $constants);

	binmode(STDOUT, ':encoding(utf8)');
	$api->header;
	print $retval;
}

sub user {
	my ($form, $slashdb, $user, $constants) = @_;
	my $api = Slash::API->new;
	my $op = lc($form->{op});

	my $ops = {
		default		=> {
			function	=> \&nullop,
			seclev		=> 1,
		},
		max_uid		=> {
			function	=> \&maxUid,
			seclev		=> 1,
		},
		get_uid		=> {
			function	=> \&nameToUid,
			seclev		=> 1,
		},
		get_nick	=> {
			function	=> \&uidToName,
			seclev		=> 1,
		},
		get_user	=> {
			function	=> \&getPubUserInfo,
			seclev		=> 1,
		},
	};
	return $ops->{$op}{function}->($form, $slashdb, $user, $constants);
}

sub story {
	my ($form, $slashdb, $user, $constants) = @_;
	my $op = lc($form->{op});

	my $ops = {
		default		=> {
			function	=> \&nullop,
			seclev		=> 1,
		},
		latest		=> {
			function	=> \&getLatestStories,
			seclev		=> 1,
		},
		single	=> {
			function	=> \&getSingleStory,
			seclev		=> 1,
		},
	};
	return $ops->{$op}{function}->($form, $slashdb, $user, $constants);
}

sub comment {
	my ($form, $slashdb, $user, $constants) = @_;
	my $op = lc($form->{op});

	my $ops = {
		default		=> {
			function	=> \&nullop,
			seclev		=> 1,
		},
		latest		=> {
			function	=> \&getLatestComments,
			seclev		=> 1,
		},
		single		=> {
			function	=> \&getSingleComment,
			seclev		=> 1,
		},
		discussion	=> {
			function	=> \&getDiscussion,
			seclev		=> 1,
		},
	};
	return $ops->{$op}{function}->($form, $slashdb, $user, $constants);
}

sub getDiscussion {
	my ($form, $slashdb, $user, $constants) = @_;
	my $discussion = $slashdb->getDiscussion($form->{id});
	if (!$discussion || !$discussion->{commentcount} ||  $discussion->{commentstatus} eq 'disabled' ) { return; }

	my($comments, $count) = selectComments($discussion);
	# Add comment text
	foreach my $cid (keys %$comments) {
		next if $cid eq "0";
		$comments->{$cid}{comment} = $slashdb->sqlSelect("comment", "comment_text", "cid = $cid");
	}

	my $json = JSON->new->utf8->allow_nonref;
	return $json->pretty->encode($comments);
}

sub getSingleStory {
	my ($form, $slashdb, $user, $constants) = @_;
	my $story = $slashdb->getStory($form->{sid});
	if( ($story->{is_future}) || ($story->{in_trash} ne "no") ){return;};
	return unless $slashdb->checkStoryViewable($story->{stoid});
	delete $story->{story_topics_rendered};
	delete $story->{primaryskid};
	delete $story->{is_future};
	delete $story->{in_trash};
	delete $story->{thumb_signoff_needed};
	delete $story->{rendered};
	delete $story->{qid};
	$story->{bodytext} = $story->{introtext} unless $story->{bodytext};
	$story->{body_length} = length($story->{bodytext});
	my $json = JSON->new->utf8->allow_nonref;
	return $json->encode($story);
}

sub getLatestStories {
	my ($form, $slashdb, $user, $constants) = @_;
	my $options;
	($options->{limit}, $options->{limit_extra}) = (($form->{limit} || 10), 0);
	my $stories = $slashdb->getStoriesEssentials($options);
	foreach my $story (@$stories) {
		($story->{introtext}, $story->{bodytext}, $story->{title}, $story->{relatedtext}) = $slashdb->sqlSelect("introtext, bodytext, title, relatedtext", "story_text", "stoid = $story->{stoid}");
		$story->{bodytext} = $story->{introtext} unless $story->{bodytext};
		$story->{body_length} = length($story->{bodytext});
		delete $story->{is_future};
		delete $story->{hitparade};
		delete $story->{primaryskid};
	}
	my $json = JSON->new->utf8->allow_nonref;	
	return $json->encode($stories);
}

sub nullop {
	return "";
}

sub maxUid {
	my ($form, $slashdb, $user, $constants) = @_;
	my $json = JSON->new->utf8->allow_nonref;
	my $max = {};
	$max->{max_uid} = $slashdb->sqlSelect(
					'max(uid)',
					'users');
	return $json->encode($max);
}

sub nameToUid {
	my ($form, $slashdb, $user, $constants) = @_;
	my $json = JSON->new->utf8->allow_nonref;
	my $nick = $slashdb->sqlQuote($form->{nick});
	my $uid = {};
	$uid->{uid} = $slashdb->sqlSelect(
					'uid',
					'users',
					" nickname = $nick ");
	return $json->encode($uid);
}

sub uidToName {
	my ($form, $slashdb, $user, $constants) = @_;
	my $json = JSON->new->utf8->allow_nonref;
	my $uid = $form->{uid};
	my $nick = {};
	$nick->{nick} = $slashdb->sqlSelect(
					'nickname',
					'users',
					" uid = $uid ");
	return $json->encode($nick);
}

sub getPubUserInfo {
}

#createEnvironment();
main();
1;

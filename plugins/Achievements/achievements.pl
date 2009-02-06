#!/usr/local/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2009 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

use strict;

use Slash;
use Slash::Constants ':slashd';
use Slash::Utility;

use vars qw(%task $me $task_exit_flag);

$task{$me}{timespec} = '0 3 * * *';
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $achievements = getObject('Slash::Achievements');

	getScore5Comments($constants, $slashdb, $achievements);

	return;
};

sub getScore5Comments {
	my ($constants, $slashdb, $achievements) = @_;

	my $comments = $slashdb->sqlSelectAllHashref(
		'cid',
		'cid, sid, ui',
		'comments',
		'points = 5 and uid != ' . $constants->{anonymous_coward_uid}
	);

	my $score5comments_archived;
	foreach my $cid (keys %$comments) {
		my $type = $slashdb->sqlSelect('type', 'discussions', "id = " . $comments->{$cid}{sid});
		if ($type eq 'archived') {
			push(@{$score5comments_archived->{$comments->{$cid}{uid}}}, $cid);
		}
	}

	my $score5_achievement = $achievements->getAchievement('score5_comment');
	my $aid = $score5_achievement->{score5_comment}{aid};

	foreach my $uid (keys %$score5comments_archived) {
		my $comment_count = scalar(@{$score5comments_archived->{$uid}});
		$achievements->setUserAchievement('score5_comment', $uid, { ignore_lookup => 1, exponent => $comment_count });
	}
}

1;

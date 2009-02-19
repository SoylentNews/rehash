# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2009 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Achievements;

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;
use Time::Local;

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

# Set an achievement for a user. Does nothing if the achievement is not
# repeatable or if the new data doesn't warrant an achievement upgrade.
#
# $ach_name: Name of the achievement we're setting.
# $uid: UID of the user.
# $options->{ignore_lookup}: Don't call getAchievementItemCount(). Assumes exponent is set.
# $options->{exponent}: The number of items we're setting for this achievement. Assumes ignore_lookup is set.
# $options->{force_convert}: Take the log() of $options->{exponent}.
sub setUserAchievement {
        my($self, $ach_name, $uid, $options) = @_;

	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();

	return if ($uid == $constants->{anonymous_coward_uid});

        #my $uid_q = $self->sqlQuote($uid);

	# Count the current numnber of items eligible for this achievement
	my $count = 0;
	my $new_exponent = 0;
	$count = $self->getAchievementItemCount($ach_name, $uid, $slashdb) unless $options->{ignore_lookup};
	$count = $options->{exponent} if ($options->{ignore_lookup} && $options->{force_convert});
	$new_exponent = $options->{exponent} if ($options->{exponent} && !$options->{force_convert});

	# Convert to our desred format. Truncate as int so we don't get
	# exponents like 2.xxx.
	my $achievement = $self->getAchievement($ach_name);
        my $increment = $achievement->{$ach_name}{increment};
        if ($increment > 1 && $count != 0) {
                $new_exponent = int(log($count) / log($increment));
        }

	# Check if the user already has this achievement
	my $aid = $achievement->{$ach_name}{aid};
        my $user_achievement = $self->getUserAchievements($uid, { aid => $aid });
        my $old_exponent = $user_achievement->{$aid}{exponent};

	my $data;
        if (!$user_achievement->{$aid}{id}) {
		# The user has never had this type of achievement.
		$data = {
                        "uid" => $uid,
                        "aid" => $achievement->{$ach_name}{aid},
                        "exponent" => $new_exponent,
                        "-createtime" => 'NOW()',
                };
		$slashdb->sqlInsert('user_achievements', $data);
		$self->setUserAchievementObtained($uid, { exponent => $new_exponent });
	} elsif ($achievement->{$ach_name}{repeatable} eq 'yes' && ($new_exponent > $old_exponent)) {
		# The user has the inferior version of the achievement. Upgrade them.
		$data = {
                        "exponent" => $new_exponent,
                        "-createtime" => 'NOW()',
                };
		$slashdb->sqlUpdate('user_achievements', $data, "id = " . $user_achievement->{$aid}{id});
		$self->setUserAchievementObtained($uid);
	} else {
		# The user already has an achievement that is non-repeatable. Do nothing.
	}
}

sub setUserAchievementObtained {
        my($self, $uid) = @_;

        my $slashdb = getCurrentDB();

        my $achievement = $self->getAchievement('achievement_obtained');
        my $aid = $achievement->{'achievement_obtained'}{aid};
        my $user_achievement = $self->getUserAchievements($uid, { aid => $aid });

	my $total_achievements = 0;
        $total_achievements = $user_achievement->{$aid}{exponent};
        $total_achievements += $options->{exponent};
        ++$total_achievements;

        my $data;
        if (!$user_achievement->{$aid}{id}) {
                $data = {
                        "uid" => $uid,
                        "aid" => $aid,
                        "exponent" => $total_achievements,
                        "-createtime" => 'NOW()',
                };
                $slashdb->sqlInsert('user_achievements', $data);
        } else {
                $data = {
                        "exponent" => $total_achievements,
                        "-createtime" => 'NOW()',
                };
                $slashdb->sqlUpdate('user_achievements', $data, "id = " . $user_achievement->{$aid}{id});
        }
}

sub getUserAchievements {
        my($self, $uid, $options) = @_;

        my $slashdb = getCurrentDB();
        #my $uid_q = $self->sqlQuote($uid);

        my $where_string = "uid = $uid";
        if ($options) {
                foreach my $option (keys %$options) {
                        $where_string .= " && " . $option . " = " . $options->{$option};
                }
        }

        my $achievements = $slashdb->sqlSelectAllHashref(
                'aid',
                'id, aid, uid, exponent, createtime',
                'user_achievements',
                $where_string);

        foreach my $achievement (keys %$achievements) {
		($achievements->{$achievement}{name},
		 $achievements->{$achievement}{description},
		 $achievements->{$achievement}{increment},
		 $achievements->{$achievement}{repeatable}) =
			$slashdb->sqlSelect("name, description, increment, repeatable",
					    "achievements",
					    "aid = " . $achievements->{$achievement}{aid}
			);

		$achievements->{$achievement}{createtime} = (split(/\s/, $achievements->{$achievement}{createtime}))[0];
	}

        return $achievements;
}

sub getAchievement {
        my($self, $ach_name) = @_;

        my $slashdb = getCurrentDB();
        return $slashdb->sqlSelectAllHashref(
                'name',
                "aid, name, description, repeatable, increment",
                'achievements',
                "name = '$ach_name'");
}

sub getAchievementItemCount {
        my($self, $ach_name, $uid, $slashdb) = @_;

        my $ach_item_count = {
                'story_posted' => {
                        "table" => "stories",
                        "where" => "uid = $uid",
                },
                'comment_posted' => {
                        "table" => "comments",
                        "where" => "uid = $uid",
                },
                'journal_posted' => {
                        "table" => "journals",
                        "where" => "uid = $uid",
                },
        };

        my $count;
        if ($ach_name eq 'story_accepted') {
                my $submissions = $slashdb->getSubmissionsByUID($uid, '', { accepted_only => 1 });
                $count = scalar @$submissions;
        } else {
                $count = $slashdb->sqlCount($ach_item_count->{$ach_name}{table}, $ach_item_count->{$ach_name}{where});
        }

        return $count;
}

sub getScore5Comments {
	my($self) = @_;

	my $constants = getCurrentStatic();

	my $comments = $self->sqlSelectAllHashref(
		'cid',
		"comments.cid, comments.uid",
		'comments, discussions',
		'comments.points = 5' .
		' and comments.uid != ' . $constants->{anonymous_coward_uid} .
		' and comments.sid = discussions.id' .
		" and discussions.type = 'archived'"
	);

	my $score5comments_archived;
	foreach my $cid (keys %$comments) {
		push(@{$score5comments_archived->{$comments->{$cid}{uid}}}, $cid);
	}

	foreach my $uid (keys %$score5comments_archived) {
		$self->setUserAchievement('score5_comment', $uid, { ignore_lookup => 1, force_convert => 1, exponent => scalar(@{$score5comments_archived->{$uid}}) });

		# If they've posted a Score:5 comment, they've clearly obtained this.
		# Deprecate this when retroactive achievements are added?
		$self->setUserAchievement('comment_posted', $uid, { ignore_lookup => 1, exponent => 0 });
	}
}

sub getConsecutiveDaysRead {
        my ($self) = @_;

        my $constants = getCurrentStatic();
        my $logdb = getObject('Slash::DB', { db_type => "log_slave" });

        my $users = $logdb->sqlSelectColArrayref('uid', 'accesslog', 'uid != ' . $constants->{anonymous_coward_uid}, '', { distinct => 1});
        my $min_ts = $logdb->sqlSelect("MIN(ts)", "accesslog");
        my $max_ts = $logdb->sqlSelect("NOW()", "accesslog");

        foreach my $uid (@$users) {
                my $days_read = $logdb->sqlSelectAllHashref(
                        'id',
                        'id, ts',
                        'accesslog',
                        "uid = $uid and ts >= '$min_ts' and ts <= '$max_ts'"
                );

                my $unique_days_read;
                foreach my $id (keys %$days_read) {
                        my $ts = (split(/\s/, $days_read->{$id}{ts}))[0];
                        my ($year, $month, $day) = split(/-/, $ts);
                        $unique_days_read->{$ts} = timelocal(0, 0, 0, $day, $month - 1, $year);
                }

                my $streak = 0;
                my $total_days = 0;
                foreach my $day_read (sort keys %$unique_days_read) {
                        $streak = 1;
                        $streak = $self->countDailyAchievementStreak($streak, $day_read, $unique_days_read);
                        $total_days = $streak if ($streak > $total_days);
                }

                $self->setUserAchievement('consecutive_days_read', $uid, { ignore_lookup => 1, force_convert => 1, exponent => $total_days });
	}
}

sub countDailyAchievementStreak {
        my ($self, $streak, $curr_day, $unique_days) = @_;

        my ($sec, $min, $hour, $mday, $mon, $year) = localtime($unique_days->{$curr_day} + 86400);
        my $next_day = sprintf("%4d-%02d-%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);

        if (exists $unique_days->{$next_day}) {
                ++$streak;
                $streak = $self->countDailyAchievementStreak($streak, $next_day, $unique_days);
        }

        return $streak;
}

sub DESTROY {
        my($self) = @_;
        $self->{_dbh}->disconnect if $self->{_dbh} && !$ENV{GATEWAY_INTERFACE};
}

1;

=head1 NAME

Slash::Achievements - Slash Achievements module

=head1 SYNOPSIS

        use Slash::Achievements;

=head1 DESCRIPTION

This contains all of the routines currently used by Achievements.

=head1 SEE ALSO

Slash(3).

=cut		

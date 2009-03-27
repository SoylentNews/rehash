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

	return if (!$uid or ($uid == $constants->{anonymous_coward_uid}));

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

	# If we're creating or updating an achievement, set it,
	# increment their Achievements achievement, and send a message.
	my $dynamic_blocks = getObject("Slash::DynamicBlocks");
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
		$self->setUserAchievementObtained($uid, { exponent => $new_exponent, ach_increment => $increment });
		$self->setAchievementMessage($uid, { description => $achievement->{$ach_name}{description} }) unless $options->{no_message};
		$self->setMakerMode($uid, $achievement->{$ach_name}{aid}) if $options->{maker_mode};
		$dynamic_blocks->setUserBlock('achievements', $uid) if ($uid and $dynamic_blocks);
	} elsif ($achievement->{$ach_name}{repeatable} eq 'yes' && ($new_exponent > $old_exponent)) {
		# The user has the inferior version of the achievement. Upgrade them.
		$data = {
                        "exponent" => $new_exponent,
                        "-createtime" => 'NOW()',
                };
		$slashdb->sqlUpdate('user_achievements', $data, "id = " . $user_achievement->{$aid}{id});
		$self->setUserAchievementObtained($uid);
		$self->setAchievementMessage($uid, { description => $achievement->{$ach_name}{description} }) unless $options->{no_message};
		$self->setMakerMode($uid, $achievement->{$ach_name}{aid}) if $options->{maker_mode};
		$dynamic_blocks->setUserBlock('achievements', $uid) if ($uid and $dynamic_blocks);
	} else {
		# The user already has an achievement that is non-repeatable. Do nothing.
	}
}

sub setUserAchievementObtained {
        my($self, $uid, $options) = @_;

        my $slashdb = getCurrentDB();

        my $achievement = $self->getAchievement('achievement_obtained');
        my $aid = $achievement->{'achievement_obtained'}{aid};
        my $user_achievement = $self->getUserAchievements($uid, { aid => $aid });

	my $total_achievements = 0;
        $total_achievements = $user_achievement->{$aid}{exponent};

        $total_achievements += $options->{exponent};
        ++$total_achievements unless $options->{ach_increment} == 1;

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

sub getUserAchievementStreak {
        my($self, $uid, $aid) = @_;

        return if(!$uid || !$aid);

        my $slashdb = getCurrentDB();
        my $streak;
        ($streak->{id},
         $streak->{uid},
         $streak->{streak},
         $streak->{last_hit},
         $streak->{last_hit_ds}) =
                $slashdb->sqlSelect('id, uid, streak, UNIX_TIMESTAMP(last_hit), last_hit as last_hit_ds',
                                    'user_achievement_streaks',
                                    "aid = $aid and uid = $uid");

        return $streak;
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

	my $mod_reader = getObject("Slash::$constants->{m1_pluginname}", { db_type => 'reader' });
	my $reasons = $mod_reader->getReasons() if $mod_reader;
	foreach my $uid (keys %$score5comments_archived) {
		$self->setUserAchievement('score5_comment', $uid, { ignore_lookup => 1, force_convert => 1, exponent => scalar(@{$score5comments_archived->{$uid}}) });

		# If they've posted a Score:5 comment, they've clearly obtained this.
		# Deprecate this when retroactive achievements are added?
		$self->setUserAchievement('comment_posted', $uid, { ignore_lookup => 1, exponent => 0 });

		# Score 5 Funny
		foreach my $cid (@{$score5comments_archived->{$uid}}) {
			my $reason = $self->sqlSelect('reason', 'comments', "cid = $cid");
			if ($reasons->{$reason}{name} eq 'Funny') {
				$self->setUserAchievement('comedian', $uid, { ignore_lookup => 1, exponent => 0 });
				last;
			}
		}
	}
}

sub getConsecutiveDaysRead {
        my ($self) = @_;

        my $constants = getCurrentStatic();
        my $slashdb = getCurrentDB();

        my $achievement = $self->getAchievement('consecutive_days_read');
        my $cdr_aid = $achievement->{'consecutive_days_read'}{aid};
	# Add another hour to account for possible latency in running the task.
	my $yesterday = (time() - 90000);

	my $users = $slashdb->sqlSelectColArrayref(
                'uid',
                'users_hits',
                'uid != ' . $constants->{anonymous_coward_uid} .
                ' and lastclick >= DATE_SUB(NOW(), INTERVAL 24 HOUR)'
        );

        foreach my $userhit_uid (@$users) {
                my $data;
                my ($id, $uid, $streak, $last_hit) =
                        $slashdb->sqlSelect('id, uid, streak, UNIX_TIMESTAMP(last_hit)', 'user_achievement_streaks', "aid = $cdr_aid and uid = $userhit_uid");
                if (!$id) {
			$streak = 1;
                        $data = {
                                "uid"       => $userhit_uid,
                                "aid"       => $cdr_aid,
                                "streak"    => $streak,
                                "-last_hit" => 'NOW()',
                        };
                        $slashdb->sqlInsert('user_achievement_streaks', $data);
                } else {
			# Reset streak to 1 if the user missed a day.
			$streak = ($last_hit <= $yesterday) ? 1 : $streak + 1;
                        $data = {
                                "streak"    => $streak,
                                "-last_hit" => 'NOW()',
                        };
                        $slashdb->sqlUpdate('user_achievement_streaks', $data, "id = $id");
                }

                $self->setUserAchievement('consecutive_days_read', $userhit_uid, { ignore_lookup => 1, force_convert => 1, exponent => $streak });
        }
}

sub getConsecutiveDaysMetaModded {
        my ($self) = @_;

        my $constants = getCurrentStatic();
        my $slashdb = getCurrentDB();

        my $achievement = $self->getAchievement('consecutive_days_metamod');
        my $aid = $achievement->{'consecutive_days_metamod'}{aid};
        my $yesterday_secs = (time() - 90000);

        my $users = $slashdb->sqlSelectColArrayref(
                'distinct uid',
                'tags, globjs',
                'tags.globjid = globjs.globjid' .
                ' and gtid = 5' .
                ' and tagnameid in (378141, 378199)' .
                ' and inactivated IS NULL ' .
                " and created_at between DATE_SUB(NOW(), INTERVAL 24 HOUR) and NOW()"
        );

        foreach my $userhit_uid (@$users) {
                my $data;
                my ($id, $uid, $streak, $last_hit) =
                        $slashdb->sqlSelect('id, uid, streak, UNIX_TIMESTAMP(last_hit)', 'user_achievement_streaks', "aid = $aid and uid = $userhit_uid");
                if (!$id) {
                        $streak = 1;
                        $data = {
                                "uid"       => $userhit_uid,
                                "aid"       => $aid,
                                "streak"    => $streak,
                                "-last_hit" => 'NOW()',
                        };
                        $slashdb->sqlInsert('user_achievement_streaks', $data);
                } else {
                        $streak = ($last_hit <= $yesterday_secs) ? 1 : $streak + 1;
                        $data = {
                                "streak"    => $streak,
                                "-last_hit" => 'NOW()',
                        };
                        $slashdb->sqlUpdate('user_achievement_streaks', $data, "id = $id");
                }

                $self->setUserAchievement('consecutive_days_metamod', $userhit_uid, { ignore_lookup => 1, force_convert => 1, exponent => $streak });
        }
}

sub getConsecutiveDailyAchievement {
        my ($self, $ach_name) = @_;

        return if !$ach_name;

        my $constants = getCurrentStatic(); 
        my $slashdb = getCurrentDB();

        my $achievement = $self->getAchievement($ach_name);
        my $aid = $achievement->{$ach_name}{aid};
        my $yesterday_secs = (time() - 90000);

        my $queries = {
                'consecutive_days_read' => {
                        'field' => 'uid',
                        'from'  => 'users_hits',
                        'where' => 'uid != ' . $constants->{anonymous_coward_uid} .
                                   ' and lastclick >= DATE_SUB(NOW(), INTERVAL 24 HOUR)',
                },

                'consecutive_days_metamod' => {
                        'field' => 'distinct uid',
                        'from'  => 'tags, globjs',
                        'where' => 'tags.globjid = globjs.globjid' .
                                   ' and gtid = 5' .
                                   ' and tagnameid in (378141, 378199)' .
                                   ' and inactivated IS NULL' .
                                   ' and created_at between DATE_SUB(NOW(), INTERVAL 24 HOUR) and NOW()',
                },
        };

        my $users = $slashdb->sqlSelectColArrayref($queries->{$ach_name}{field}, $queries->{$ach_name}{from}, $queries->{$ach_name}{where});

	foreach my $userhit_uid (@$users) {
                my $data;
                my $achievement_streak = $self->getUserAchievementStreak($userhit_uid, $aid);

                if (!$achievement_streak->{id}) {
                        $achievement_streak->{streak} = 1;
                        $data = {
                                "uid"       => $userhit_uid,
                                "aid"       => $aid,
                                "streak"    => $achievement_streak->{streak},
                                "-last_hit" => 'NOW()',
                        };
                        $slashdb->sqlInsert('user_achievement_streaks', $data);
                } else {
                        $achievement_streak->{streak} = ($achievement_streak->{last_hit} <= $yesterday_secs) ? 1 : $achievement_streak->{streak} + 1;
                        $data = {
                                "streak"    => $achievement_streak->{streak},
                                "-last_hit" => 'NOW()',
                        };
                        $slashdb->sqlUpdate('user_achievement_streaks', $data, 'id = ' . $achievement_streak->{id});
                }

                $self->setUserAchievement($ach_name, $userhit_uid, { ignore_lookup => 1, force_convert => 1, exponent => $achievement_streak->{streak} });
        }
}

sub setAchievementMessage {
        my($self, $uid, $achievement) = @_;

        my $slashdb = getCurrentDB();
        my $user = $slashdb->getUser($uid);

	# Temp. check for admin
	return if ($user->{seclev} < 1000);

	my $ach_message_code = $slashdb->sqlSelect('code', 'message_codes', "type = 'Achievement'");
        my $messages = getObject('Slash::Messages');
        if ($messages && $ach_message_code) {
                my $users = $messages->checkMessageCodes($ach_message_code, [$uid]);
                if (scalar @$users) {
                        my $data  = {
                                template_name   => 'achievement_msg',
                                template_page   => 'achievements',
                                subject         => {
                                        template_name => 'achievement_msg_subj',
                                        template_page => 'achievements',
                                },
                                achievement     => $achievement,
                                useredit        => $user,
                        };
                        $messages->create($uid, $ach_message_code, $data);
                }
        }
}

# setMeta($uid, $meta_name, [$prereq1, $prereq2 ... ]);
sub checkMeta {
        my ($self, $uid, $meta, $prereqs) = @_;

        return 0 if (!$meta);

        my $slashdb = getCurrentDB();
        my $constants = getCurrentStatic();

        my $user_achievements = $self->getUserAchievements($uid);
        my $meta_achievement = $self->getAchievement($meta);
        my $meta_aid = $meta_achievement->{$meta}{aid};

        return 0 if ($user_achievements->{$meta_aid});

        my $has_prereqs = 0;
        foreach my $prereq (@$prereqs) {
                my $prereq_achievement = $self->getAchievement($prereq);
                my $prereq_achievement_aid = $prereq_achievement->{$prereq}{aid};
                $has_prereqs = ($user_achievements->{$prereq_achievement_aid}) ? 1 : 0;
                last if ($has_prereqs == 0);
        }

        return $has_prereqs;
}

sub setMakerMode {
        my ($self, $uid, $aid) = @_;

        my $slashdb = getCurrentDB();
        my $constants = getCurrentStatic();

        return if (!$uid || $uid == $constants->{anonymous_coward_uid});

        my $uid_q = $slashdb->sqlQuote($uid);
        my $user = $slashdb->getUser($uid);

        my $create_time = $slashdb->sqlSelect('createtime', 'user_achievements', "aid = $aid and uid = $uid_q");

	# createtime should always be set, actually...
	if ($create_time and !$user->{'maker_mode'}) {
                $slashdb->setUser($uid, { 'maker_mode' => $create_time });
        }
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

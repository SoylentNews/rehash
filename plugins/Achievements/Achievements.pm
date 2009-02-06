# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2009 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Achievements;

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

sub setUserAchievement {
        my($self, $ach_name, $uid, $options) = @_;

	my $constants = getCurrentStatic();
	return if ($uid == $constants->{anonymous_coward_uid});

        my $slashdb = getCurrentDB();
        #my $uid_q = $self->sqlQuote($uid);

	# Count the current numnber of items eligible for this achievement
	my $count = 0;
	$count = $self->getAchievementItemCount($ach_name, $uid, $slashdb) unless $options->{ignore_lookup};

	# Convert to our desred format. Truncate as int so we don't get
	# exponents like 2.xxx.
	my $achievement = $self->getAchievement($ach_name);
        my $increment = $achievement->{$ach_name}{increment};
	my $new_exponent = $options->{exponent} || 0;
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
		$self->setUserAchievementObtained($uid);
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
        my $total_achievements = $slashdb->sqlCount('user_achievements', "uid = $uid && aid != $aid");

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
                my ($name, $description, $increment, $repeatable) =
                        $slashdb->sqlSelect("name, description, increment, repeatable", "achievements", "aid = " . $achievements->{$achievement}{aid});
 
		$achievements->{$achievement}{name} = $name;
		$achievements->{$achievement}{description} = $description;

		if ($achievements->{$achievement}{repeatable} eq 'yes' && $achievements->{$achievement}{increment} == 1) {
			$achievements->{$achievement}{increment} = $achievements->{$achievement}{exponent};
			$achievements->{$achievement}{exponent} = $increment;
		} else {
			$achievements->{$achievement}{increment} = $increment;
		}

		$achievements->{$achievement}{repeatable} = $repeatable;
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
                my $submissions = $slashdb->getSubmissionsByUID($uid, '', { accepted_only => 1});
                $count = scalar @$submissions;
        } else {
                $count = $slashdb->sqlCount($ach_item_count->{$ach_name}{table}, $ach_item_count->{$ach_name}{where});
        }

        return $count;
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

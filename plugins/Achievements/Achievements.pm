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
        my($self, $ach_name, $uid) = @_;

        my $slashdb = getCurrentDB();
        my $uid_q = $self->sqlQuote($uid);

        my $ach_item_count = {
                'story_posted' => {
                        "table" => "stories",
                        "where" => "uid = $uid_q",
                },
                'comment_posted' => {
                        "table" => "comments",
                        "where" => "uid = $uid_q",
                },
                'journal_posted' => {
                        "table" => "journals",
                        "where" => "uid = $uid_q",
                },
        };

	# Count the current numnber of items eligible for this achievement
	my $count = $slashdb->sqlCount($ach_item_count->{$ach_name}{table}, $ach_item_count->{$ach_name}{where});

	# Convert to our desred format. Truncate as int so we don't get
	# exponents like 2.xxx.
	my $achievement = $self->getAchievement($ach_name);
        my $increment = $achievement->{$ach_name}{increment};
        my $new_exponent = 0;
        if ($increment > 1) {
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
                        "uid" => $uid_q,
                        "aid" => $achievement->{$ach_name}{aid},
                        "exponent" => $new_exponent,
                        "-createtime" => 'NOW()',
                };
		$slashdb->sqlInsert('user_achievements', $data);
	} elsif ($achievement->{$ach_name}{repeatable} eq 'yes' && ($new_exponent > $old_exponent)) {
		# The user has the inferior version of the achievement. Upgrade them.
		$data = {
                        "exponent" => $new_exponent,
                        "-createtime" => 'NOW()',
                };
		$slashdb->sqlUpdate('user_achievements', $data, "id = " . $user_achievement->{$aid}{id});
	} else {
		# The user already has an achievement that is non-repeatable. Do nothing.
	}
}

sub getUserAchievements {
        my($self, $uid, $options) = @_;

        my $slashdb = getCurrentDB();
        my $uid_q = $self->sqlQuote($uid);

        my $where_string = "uid = $uid_q";
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
                $achievements->{$achievement}{increment} = $increment;
                $achievements->{$achievement}{repeatable} = $repeatable;
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

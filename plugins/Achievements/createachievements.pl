#!/usr/local/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

use strict;
use File::Basename;
use Getopt::Std;
use Slash;
use Slash::Utility;

my $PROGNAME = basename($0);

my %opts;
getopts('hu:acjpsdtm', \%opts);
usage() if (!keys %opts || $opts{h});

createEnvironment($opts{u});
my $slashdb = getCurrentDB();
my $constants = getCurrentStatic();

        my $achievements = getObject('Slash::Achievements');
        die 'Achievements not installed, aborting' unless $achievements;

        createAll($slashdb, $achievements)             if $opts{a};
        createComments($slashdb, $achievements)        if $opts{c};
        createJournals($slashdb, $achievements)        if $opts{j};
        createStoriesPosted($slashdb, $achievements)   if $opts{p};
        createStoriesAccepted($slashdb, $achievements) if $opts{s};
        createUIDClub($slashdb, $achievements)         if $opts{d};
        createTagger($slashdb, $achievements)          if $opts{t};
	createMaker($slashdb, $achievements)           if $opts{m};

sub createAll {
        my ($slashdb, $achievements) = @_;

        createComments(@_);
        createJournals(@_);
        createStoriesPosted(@_);
        createStoriesAccepted(@_);
        createUIDClub(@_);
        createTagger(@_);
	createMaker(@_);
}

sub createComments {
        my ($slashdb, $achievements) = @_;

        my $users = $slashdb->sqlSelectColArrayref('uid', 'comments', 'uid != ' . $constants->{anonymous_coward_uid}, '', { distinct => 1});
        foreach my $uid (@$users) {
                print "Creating 'comment_posted' achievement for: $uid\n";
                $achievements->setUserAchievement('comment_posted', $uid, { ignore_lookup => 1, exponent => 0, no_message => 1});
        }
}

sub createJournals {
        my ($slashdb, $achievements) = @_;

        my $users = $slashdb->sqlSelectColArrayref('uid', 'journals', 'uid != ' . $constants->{anonymous_coward_uid}, '', { distinct => 1});
        foreach my $uid (@$users) {
                print "Creating 'journal_posted' achievement for: $uid\n";
                $achievements->setUserAchievement('journal_posted', $uid, { ignore_lookup => 1, exponent => 0, no_message => 1 });
        }
}

sub createStoriesPosted {
        my ($slashdb, $achievements) = @_;

        my $users = $slashdb->sqlSelectColArrayref('uid', 'stories', 'uid != ' . $constants->{anonymous_coward_uid}, '', { distinct => 1});
        foreach my $uid (@$users) {
                print "Creating 'story_posted' achievement for: $uid\n";
                $achievements->setUserAchievement('story_posted', $uid);
        }
}

sub createStoriesAccepted {
        my ($slashdb, $achievements) = @_;

        my $users = $slashdb->sqlSelectColArrayref('uid', 'users', 'uid != ' . $constants->{anonymous_coward_uid});
        foreach my $uid (@$users) {
                my $submissions = $slashdb->getSubmissionsByUID($uid, '', { accepted_only => 1});
                my $count = scalar @$submissions;
                if ($count) {
                        print "Creating 'story_accepted' achievement for: $uid: $count\n";
                        $achievements->setUserAchievement('story_accepted', $uid, { ignore_lookup => 1, exponent => $count, force_convert => 1, no_message => 1, maker_mode => 1}) if $count;
                }
        }
}

sub createUIDClub {
        my ($slashdb, $achievements) = @_;

        my $users = $slashdb->sqlSelectColArrayref('uid', 'comments', 'uid <100000 and uid != ' . $constants->{anonymous_coward_uid}, '', { distinct => 1});
        foreach my $uid (@$users) {
                my @digits = split(//, $uid);
                my $num_digits = scalar @digits;
                $achievements->setUserAchievement("1_uid_club", $uid, { ignore_lookup => 1, exponent => 5, no_message => 1 }) if ($num_digits == 1);
                $achievements->setUserAchievement("2_uid_club", $uid, { ignore_lookup => 1, exponent => 4, no_message => 1 }) if ($num_digits == 2);
                $achievements->setUserAchievement("3_uid_club", $uid, { ignore_lookup => 1, exponent => 3, no_message => 1 }) if ($num_digits == 3);
                $achievements->setUserAchievement("4_uid_club", $uid, { ignore_lookup => 1, exponent => 2, no_message => 1 }) if ($num_digits == 4);
                $achievements->setUserAchievement("5_uid_club", $uid, { ignore_lookup => 1, exponent => 1, no_message => 1 }) if ($num_digits == 5);
        }
}

sub createTagger {
        my ($slashdb, $achievements) = @_;

        my $users = $slashdb->sqlSelectColArrayref('uid', 'tags', 'uid != ' . $constants->{anonymous_coward_uid}, '', { distinct => 1});
        my $tags_reader = getObject("Slash::Tags");
        if ($tags_reader) {
                foreach my $uid (@$users) {
                        my $has_tagged = 0;
                        my $has_not_tagged = 0;
                        my $user_tags = $tags_reader->getAllTagsFromUser($uid, { type => "stories" });
                        foreach my $tag (@$user_tags) {
                                $has_tagged = 1;
                                if ($tag->{tagname} =~ /^!\w+/) {
                                        $has_not_tagged = 1;
                                        last;
                                }
                        }

                        $achievements->setUserAchievement('the_tagger', $uid, { ignore_lookup => 1, exponent => 0, no_message => 1 }) if $has_tagged;
                        $achievements->setUserAchievement('the_contradictor', $uid, { ignore_lookup => 1, exponent => 0, no_message => 1 }) if $has_not_tagged;
                }
        }
}

sub createMaker {
        my ($slashdb, $achievements) = @_;

        my $submissions =
                $slashdb->sqlSelectAllHashrefArray(
                        'discussion, uid',
                        'firehose',
                        'uid != ' . $constants->{anonymous_coward_uid} . " and type = 'submission' and accepted = 'yes'"
                );
        foreach my $submission (@$submissions) {
                next if ($submission->{discussion} == 0);
                my ($cid, $create_time) =
                        $slashdb->sqlSelect(
                                'cid, NOW()',
                                'comments',
                                'sid = ' . $submission->{discussion} . ' and points > 0 limit 1'
                        );
                if ($cid) {
                        $achievements->setUserAchievement('the_maker', $submission->{uid}, { ignore_lookup => 1, exponent => 0, no_message => 1, maker_mode => 1});
                }
        }
}

sub usage {
        print "*** $_[0]\n" if $_[0];
        print <<EOT;

Usage: $PROGNAME [OPTIONS]

This utility inserts achievements, with the exception of score5_comment
and consecutive_days_read. See achievements.pl for those achievements.

Main options:
        -h      Help (this message)
        -u      Virtual user
        -a      Create all
        -c      Create comments
        -j      Create journals
        -p      Create posted stories
        -s      Create accepted stories
        -d      Create UID club
        -t      Create Tagger/Contradictor
	-m	Create The Maker

EOT
        exit;
}

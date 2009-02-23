#!/usr/local/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

use strict;
use File::Basename;
use Getopt::Std;
use Slash;
use Slash::Utility;
use Data::Dumper;

my $PROGNAME = basename($0);

my %opts;
getopts('hu:', \%opts);
usage() if (!keys %opts || $opts{h});

createEnvironment($opts{u});
my $slashdb = getCurrentDB();
my $constants = getCurrentStatic();

	my $achievements = getObject('Slash::Achievements');
        die 'Achievements not installed, aborting' unless $achievements;

        my $users;
	print "\n** comment_posted **\n";
        $users = $slashdb->sqlSelectColArrayref('uid', 'comments', 'uid != ' . $constants->{anonymous_coward_uid}, '', { distinct => 1});
        for (@$users) {
                print "Creating 'comment_posted' achievement for: $_\n";
                $achievements->setUserAchievement('comment_posted', $_, { ignore_lookup => 1, exponent => 0 });
        }

	print "\n** journal_posted **\n";
        $users = $slashdb->sqlSelectColArrayref('uid', 'journals', 'uid != ' . $constants->{anonymous_coward_uid}, '', { distinct => 1});
        for (@$users) {
                print "Creating 'journal_posted' achievement for: $_\n";
                $achievements->setUserAchievement('journal_posted', $_, { ignore_lookup => 1, exponent => 0 });
        }

	print "\n** story_posted **\n";
        $users = $slashdb->sqlSelectColArrayref('uid', 'stories', 'uid != ' . $constants->{anonymous_coward_uid}, '', { distinct => 1});
        for (@$users) {
                print "Creating 'story_posted' achievement for: $_\n";
                $achievements->setUserAchievement('story_posted', $_);
        }

	print "\n** story_accepted **\n";
        $users = $slashdb->sqlSelectColArrayref('uid', 'users', 'uid != ' . $constants->{anonymous_coward_uid});
        for (@$users) {
                my $submissions = $slashdb->getSubmissionsByUID($_, '', { accepted_only => 1});
                my $count = scalar @$submissions;
                if ($count) {
                        print "Creating 'story_accepted' achievement for: $_: $count\n";
                        $achievements->setUserAchievement('story_accepted', $_, { ignore_lookup => 1, exponent => $count, force_convert => 1}) if $count;
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

EOT
        exit;
}

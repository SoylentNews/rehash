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
getopts('hu:acjifbtspm', \%opts);
usage() if (!keys %opts || $opts{h});

createEnvironment($opts{u});
my $slashdb = getCurrentDB();
my $constants = getCurrentStatic();

        my $dynamic_blocks = getObject('Slash::DynamicBlocks');
        die 'DynamicBlocks not installed, aborting' unless $dynamic_blocks;

        createAll($slashdb, $dynamic_blocks)          if $opts{a};
        createComments($slashdb, $dynamic_blocks)     if $opts{c};
        createJournals($slashdb, $dynamic_blocks)     if $opts{j};
        createAchievements($slashdb, $dynamic_blocks) if $opts{i};
        createFriends($slashdb, $dynamic_blocks)      if $opts{f};
        createTags($slashdb, $dynamic_blocks)         if $opts{t};
        createBookmarks($slashdb, $dynamic_blocks)    if $opts{b};
        createSubmissions($slashdb, $dynamic_blocks)  if $opts{s};
        createPortal($slashdb, $dynamic_blocks)       if $opts{p};
        createAdminBlocks($slashdb, $dynamic_blocks)  if $opts{m};

sub createAll {

        createComments(@_);
        createJournals(@_);
        createAchievements(@_);
        createFriends(@_);
        createBookmarks(@_);
        createTags(@_);
        createSubmissions(@_);
        createAdminBlocks(@_);
}

sub createComments {
        my ($slashdb, $dynamic_blocks) = @_;

        my $users;
        $users = $slashdb->sqlSelectColArrayref('uid', 'comments', 'uid != ' . $constants->{anonymous_coward_uid}, '', { distinct => 1});
        foreach my $uid (@$users) {
                print "Creating comment block for $uid\n";
                $dynamic_blocks->setUserBlock('comments', $uid);
        }
}

sub createJournals {
        my ($slashdb, $dynamic_blocks) = @_;

        my $users;
        $users = $slashdb->sqlSelectColArrayref('uid', 'journals', 'uid != ' . $constants->{anonymous_coward_uid} . " and promotetype = 'publish'", '', { distinct => 1});
        foreach my $uid (@$users) {
                print "Creating journal block for $uid\n";
                $dynamic_blocks->setUserBlock('journal', $uid);
        }
}

sub createAchievements {
        my ($slashdb, $dynamic_blocks) = @_;

        my $users;
        $users = $slashdb->sqlSelectColArrayref('uid', 'user_achievements', 'uid != ' . $constants->{anonymous_coward_uid}, '', { distinct => 1});
        foreach my $uid (@$users) {
                print "Creating achievement block for $uid\n";
                $dynamic_blocks->setUserBlock('achievements', $uid);
        }
}

sub createFriends {
        my ($slashdb, $dynamic_blocks) = @_;

        my $users;
        $users = $slashdb->sqlSelectColArrayref('uid', 'people', 'uid != ' . $constants->{anonymous_coward_uid}, '', { distinct => 1});
        foreach my $uid (@$users) {
                print "Creating friends block for $uid\n";
                $dynamic_blocks->setUserBlock('friends', $uid);
        }
}

sub createTags {
        my ($slashdb, $dynamic_blocks) = @_;

        my $users;
        $users = $slashdb->sqlSelectColArrayref('uid', 'tags', 'uid != ' . $constants->{anonymous_coward_uid}, '', { distinct => 1});
        foreach my $uid (@$users) {
                print "Creating tags block for $uid\n";
                $dynamic_blocks->setUserBlock('tags', $uid);
        }
}

sub createBookmarks {
        my ($slashdb, $dynamic_blocks) = @_;

        my $users;
        $users = $slashdb->sqlSelectColArrayref('uid', 'bookmarks', 'uid != ' . $constants->{anonymous_coward_uid}, '', { distinct => 1});
        foreach my $uid (@$users) {
                print "Creating bookmarks block for $uid\n";
                $dynamic_blocks->setUserBlock('bookmarks', $uid);
        }
}

sub createSubmissions {
        my ($slashdb, $dynamic_blocks) = @_;

        my $users;
        $users =
                $slashdb->sqlSelectColArrayref(
                        'uid',
                        'firehose',
                        'uid != ' . $constants->{anonymous_coward_uid} .
                        " and (type = 'submission' or type = 'feed')",
                        '',
                        , { distinct => 1}
                );
        foreach my $uid (@$users) {
                print "Creating submissions block for $uid\n";
                $dynamic_blocks->setUserBlock('submissions', $uid);
        }
}

sub createPortal {
        my ($slashdb, $dynamic_blocks) = @_;

        print "Syncing portals\n";
        $dynamic_blocks->syncPortalBlocks(undef, { all => 1 });
}

sub createAdminBlocks {
        my ($slashdb, $dynamic_blocks) = @_;

        my $cur_admin = $slashdb->currentAdmin();
        my $admin_db = getObject("Slash::Admin");
        return if !$admin_db;

        my $block_definition = $dynamic_blocks->getBlockDefinition('', { type => 'admin', private => 'yes'});
        foreach my $admin (@$cur_admin) {
                my $block = $admin_db->showStoryAdminBox("", { contents_only => 1, uid => $admin->[5]});
                my $name = 'storyadmin-' . $admin->[5];
                my $data = {
                        type_id     => $block_definition->{type_id},
                        uid         => $admin->[5],
                        title       => 'Story Admin',
                        url         => '',
                        name        => $name,
                        description => 'Story Admin',
                        block       => $block,
                        seclev      => 10000,
                };
                $dynamic_blocks->setBlock($data);
        }
}

sub usage {
        print "*** $_[0]\n" if $_[0];
        print <<EOT;

Usage: $PROGNAME [OPTIONS]

This utility inserts retroactive dynamic slashboxes.

Main options:
        -h      Help (this message)
        -u      Virtual user
        -a      Create all
        -c      Create comments
        -j      Create journals
        -i      Create Achievements
        -f      Create friends
        -b      Create bookmarks
        -t      Create tags
        -s      Create submissions
        -p      Create portals
        -m      Create private admin blocks

EOT
        exit;
}

#!/usr/local/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

use strict;
use utf8;
use File::Basename;
use Getopt::Std;
use Slash;
use Slash::Utility;

my $PROGNAME = basename($0);

my %opts;
getopts('hau:c:m:d:', \%opts);
usage() if (
        !keys %opts                            ||
        $opts{h}                               ||
        !$opts{u}                              ||
        !exists $opts{c}                       ||
        !exists $opts{m}                       ||
        (!exists $opts{d} && !exists $opts{a}) ||
        (exists $opts{d} && exists $opts{a}));

createEnvironment($opts{u});
my $slashdb = getCurrentDB();
my $constants = getCurrentStatic();

	my $messages = getObject('Slash::Messages');
        die 'Messages not installed, aborting' unless $messages;

        my ($code, $mode) = ($opts{c}, $opts{m});
        my $users = [];
        if ($opts{d}) {
                $users = [$opts{d}];
        } elsif ($opts{a}) {
                $users = $slashdb->sqlSelectColArrayref('uid', 'users', 'uid != ' . $constants->{anonymous_coward_uid});
        }

        my $table = $messages->{_prefs_table};
        foreach my $uid (@$users) {
		# Skip this user if they already have a preference for $code set.
		my $curr_prefs = $messages->getPrefs($uid);
                next if (exists $curr_prefs->{$code});

                my $rows = $slashdb->sqlInsert($table, {
                        uid  => $uid,
                        code => $code,
                        mode => $mode,
                });

                print "Added $code -> $mode for $uid\n" if $rows;
        }

sub usage {
        print "*** $_[0]\n" if $_[0];
        print <<EOT;

Usage: $PROGNAME [OPTIONS]

This utility sets a specific message preference for a given UID, or all users. This
is not meant to replace a user's existing pref mode.

Main options:
        -h      Help (this message)
        -u      Virtual user
        -c      Message code (required)
        -m      Message mode (required)
        -d      UID for which to set this code/mode (required, or -a)
        -a      Set this code/mode for all users (very time consuming)
EOT
        exit;
}


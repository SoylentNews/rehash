#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

# Calls getStoriesEssentials, on each DB that might perform
# its SQL, a few seconds before the top of each minute, so
# each DB can put that SQL into its query cache.  Thanks to
# jellicle for suggesting this!  :)

use strict;
use vars qw( %task $me );
use Time::HiRes;
use Slash::DB;
use Slash::Display;
use Slash::Utility;
use Slash::Constants ':slashd';

(my $VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

$task{$me}{timespec} = "0-59 * * * *";
$task{$me}{fork} = SLASHD_NOWAIT;

$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;
	my @errs = ( );

	# We should be on the mainpage skin anyway, but just to be sure.
	# Since this is the whole point!
	setCurrentSkin($constants->{mainpage_skid});
	my $gSkin = getCurrentSkin();

	# Get the list of DBs we are going to contact.
	my %virtual_users = ( );
	my $dbs = $slashdb->getDBs();
	if ($constants->{index_gse_backup_prob} < 1 && $dbs->{writer}) {
		my @writer = @{ $dbs->{writer} };
		$virtual_users{$writer[0]{virtual_user}} = 1
			if $writer[0]{isalive} eq 'yes';
	}
	if ($constants->{index_gse_backup_prob} > 0 && $dbs->{reader}) {
		my @readers = @{ $dbs->{reader} };
		for my $reader (@readers) {
			$virtual_users{$reader->{virtual_user}} = 1
				if $reader->{isalive} eq 'yes';
		}
	}
	my @virtual_users = sort keys %virtual_users;
	push @virtual_users, $slashdb->{virtual_user} if !@virtual_users;

	# We'll try precaching two queries for each virtual user,
	# one with Collapse Sections and one without.  Look ahead
	# 45 seconds because that is guaranteed to cross the next
	# minute boundary.  And if there's time, precache the
	# next upcoming minute too -- and if gse_precache_mins_ahead
	# is set to 3 or more, keep going.
	my $mins_ahead = $constants->{gse_precache_mins_ahead} || 2;
	my $mp_tid = $constants->{mainpage_nexus_tid};
	my $default_maxstories = getCurrentAnonymousCoward("maxstories");
	my @gse_1min = (
		{ fake_secs_ahead =>  45,
		  tid => $mp_tid		},
		{ fake_secs_ahead =>  45,
		  tid => $mp_tid,
		  sectioncollapse => 1		},
	);
	my @gse_hrs = ( );
	for my $i (0..$mins_ahead-1) {
		push @gse_hrs, @gse_1min;
		for my $hr (@gse_1min) {
			$hr->{fake_secs_ahead} += 60;
		}
	}

	# Sleep until :10 after the top of the minute.
	my $time = time;
	my $now_secs = $time % 60;
	return "started too late" if $now_secs > 40;
	sleep 10 - $now_secs if $now_secs < 10;
	my $max_time = $time - $now_secs + 55;

	# Make each gSE query to each virtual user.
	OUTER: for my $i (0..$#gse_hrs) {
		my $gse_hr = $gse_hrs[$i];
		INNER: for my $vu (@virtual_users) {
			if (time >= $max_time) {
				push @errs, "ran out of time on i $i vu $vu";
				last OUTER;
			}
			my $vu_db = getObject('Slash::DB', { virtual_user => $vu });
			if (!$vu_db) {
				push @errs, "no db returned for i $i vu $vu";
				next INNER;
			}
			my %copy = %$gse_hr;
			my $dummy = $vu_db->getStoriesEssentials(\%copy);
		}
	}

	if (@errs) {
		return "err: " . join("; ", @errs);
	}
	return "precached for @virtual_users";
};

1;


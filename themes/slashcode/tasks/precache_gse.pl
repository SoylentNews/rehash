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
	# 30 seconds because that is guaranteed to cross the next
	# minute boundary.
	my $mp_tid = $constants->{mainpage_nexus_tid};
	my $default_maxstories = getCurrentAnonymousCoward("maxstories");
	my @gse_hrs = (
		{ fake_secs_ahead => 30,
		  tid => $mp_tid,
		  limit => $default_maxstories	},
		{ fake_secs_ahead => 30,
		  tid => $mp_tid,
		  limit => $default_maxstories,
		  sectioncollapse => 1		},
	);

	# Sleep until :45 after the top of the minute.
	my $now_secs = time % 60;
	return "started too late" if $now_secs > 55;
	sleep 45 - $now_secs if $now_secs < 45;

	# Make each gSE query to each virtual user.
	for my $vu (@virtual_users) {
		$now_secs = time % 60;
		if ($now_secs > 58) {
			push @errs, "ran out of time on vu '$vu': " . scalar(gmtime);
			last;
		}
		my $vu_db = getObject('Slash::DB', { virtual_user => $vu });
		if (!$vu_db) {
			push @errs, "no db returned for vu '$vu'";
			next;
		}
		for my $gse_hr (@gse_hrs) {
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


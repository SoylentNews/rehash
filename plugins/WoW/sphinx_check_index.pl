#!/usr/bin/perl -w

# Nagios plugin to make sure indexer is running occasionally.

use strict;

use Proc::ProcessTable;

use constant OK => 0;
use constant WARNING => 1;
use constant CRITICAL => 2;
use constant UNKNOWN => 3;

# Get the list of files in sphinx's data directory.

my $datadir = '/srv/sphinx/var/data';
my $dh;
if (!opendir($dh, $datadir)) {
	print "cannot read $datadir: $!\n";
	exit CRITICAL;
}
my @fh_files = grep /^firehose_/, readdir($dh);
closedir $dh;

# Check when the last-touched delta2 index file was touched.

my @fh_delta2_files = grep /^firehose_delta2\./, @fh_files;
my $last_touch = 999999;
for my $d2_filename (@fh_delta2_files) {
	my $age_secs = (-M "$datadir/$d2_filename") * 86400;
	if ($age_secs <= 60) {
		# If a firehose_delta2.* file has been touched in
		# the last minute, indexer is clearly being run, so
		# we're done.
		print "OK\n";
		exit OK;
	}
	$last_touch = $age_secs if $age_secs < $last_touch;
}

# Otherwise, an indexer must be in progress (running delta2 or
# main, which might take longer than a minute).

my $t = new Proc::ProcessTable;
for my $p (@{ $t->table }) {
	if ($p->cmndline =~ m{/usr/local/sphinx/bin/indexer}) {
		print "OK\n";
		exit OK;
	}
}

# No indexer and no recently-touched delta means we have a problem.

print "Sphinx: no indexer running and delta2 files last touched $last_touch secs ago\n";
exit($last_touch < 900 ? WARNING : CRITICAL);


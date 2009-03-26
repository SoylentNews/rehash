#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2009 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

# TODO: should be a way in here to adjust memlimit, stopwords, etc.,
# using vars.

use strict;

use File::Spec::Functions;
use Slash;
use Slash::Constants ':slashd';

use vars qw(
	%task	$me	$task_exit_flag
);

$task{$me}{timespec} = '25 7 * * *';
$task{$me}{on_startup} = 1;
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;

	my $sphinxdb = getObject('Slash::Sphinx', { db_type => 'sphinx' });
	return 'sphinx apparently not installed, exiting' unless $sphinxdb;

	my $where_clause = 'completion IS NULL
		AND started < DATE_SUB(NOW(), INTERVAL 1 HOUR)';
	$sphinxdb->sqlDo("INSERT IGNORE INTO sphinx_counter_archived
		SELECT * FROM sphinx_counter
		WHERE $where_clause");
	my $count_after_arch = $sphinxdb->sqlCount('sphinx_counter_archived');
	my $rows = $sphinxdb->sqlDelete('sphinx_counter', $where_clause);

	return "moved $rows rows to sphinx_counter_archived, new total $count_after_arch rows";
};

1;


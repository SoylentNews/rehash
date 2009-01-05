#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2008 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

# Add and delete counts may not precisely match because {uid,globjid}
# pairs are unique to the separate tables, not across both tables.

use strict;

use Slash::Constants ':slashd';

use vars qw( %task $me );

$task{$me}{timespec} = '0-59/5 * * * *';
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $min_gvid = $slashdb->sqlSelect('MIN(gvid)', 'globjs_viewed');
	my $max_gvid = $min_gvid + 50_000;
	my $where_clause = "gvid < $max_gvid AND viewed_at < DATE_SUB(NOW(), INTERVAL 3 MONTH)";

	my $old_arch_size = $slashdb->sqlSelect('COUNT(*)', 'globjs_viewed_archived');
	$slashdb->sqlDo("INSERT IGNORE INTO globjs_viewed_archived
		SELECT * FROM globjs_viewed WHERE $where_clause");
	my $new_arch_size = $slashdb->sqlSelect('COUNT(*)', 'globjs_viewed_archived');
	my $added = $new_arch_size - $old_arch_size;

	my $deleted = $slashdb->sqlDelete('globjs_viewed', $where_clause);

	return "$added added, $deleted deleted";
};

1;


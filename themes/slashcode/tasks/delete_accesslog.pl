#!/usr/bin/perl -w

use strict;

use Fcntl;
use Slash::Constants ':slashd';

use vars qw( %task $me );

# This task slowly delete the accesslog on an hourly basis.
# The concept is to keep the table small and only delete from it a few rows at a time
# to keep locking to a minimum. Load determines how long this runs.
# If you notice any issues, decrease LIMIT.
# -Brian

$task{$me}{timespec} = '22 * * * *'; #Normally run once an hour
$task{$me}{timespec_panic_1} = '20 1,2,3,4,5,6 * * *'; # Just run at night if an issue pops up
$task{$me}{timespec_panic_2} = ''; # In a pinch don't do anything
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;
	my $log_user = getCurrentStatic('log_db_user');
	my $logdb = $log_user ? getObject('Slash::DB', $log_user ) : $slashdb;
	my $counter = 0;
	my $FAILURES = 10; # This is probably related to a lock failure
	my $id = $logdb->sqlSelect('max(id)', 'accesslog', "ts < DATE_ADD(now(), INTERVAL -60 HOUR)");

	my ($rows, $total);

	label:
	while ($rows = $logdb->sqlDo("DELETE FROM accesslog WHERE id < $id LIMIT 100000")) {
		$total += $rows;
		my $div = $total/100000;
		slashdLog("delete_accesslog: Deleted thus far $div x 10^5 rows " . localtime());
		last if $rows eq "0E0";
	}

	if ($logdb->sqlError && $counter < $FAILURES) {
		slashdLog("delete_accesslog: Error occured (" . $logdb->sqlError . ")");
		sleep(5);
					$counter++;
		goto label;
	}
	if ($counter >= $FAILURES) {
		slashdLog("delete_accesslog: More then $FAILURES errors occured, accesslog is probably locked.");
	}
};

1;

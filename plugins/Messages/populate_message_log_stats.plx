#!/usr/bin/perl -w
# run this to generate stats for existing log entries
#
#  perl populate_message_log_stats.plx VIRTUAL_USER
#
# you probably only want to run it once, but running it multiple times
# shouldn't hurt anything

use strict;
use Slash::Test shift;
my $messages = getObject('Slash::Messages');
my $x = shift || 60;

for (my $n = 0; $n < $x; $n++) {
	my @time1 = localtime( time() - (86400 * (1 + $n)) );
	my $date1 = sprintf "%4d%02d%02d000000", $time1[5] + 1900, $time1[4] + 1, $time1[3];

	my @time2 = localtime( time() - (86400 * $n) );
	my $date2 = sprintf "%4d%02d%02d000000", $time2[5] + 1900, $time2[4] + 1, $time2[3];

	my $table = $messages->{_log_table};
	my $msg_log = $messages->sqlSelectAll(
		'code, mode, count(*) as count',
		$table,
		"date >= '$date1' AND date < '$date2'",
		"GROUP BY code, mode"
	);


	my $statsSave = getObject('Slash::Stats::Writer', { nocache => 1 }, {
		day => sprintf("%4d-%02d-%02d", $time1[5] + 1900, $time1[4] + 1, $time1[3])
	});

	my %msg_codes;
	for my $type (@$msg_log) {
		my($code, $mode, $count) = @$type;
		$msg_codes{$code} += $count;
		$statsSave->createStatDaily("msg_${code}_${mode}", $count);
	}

	for my $code (keys %msg_codes) {
		$statsSave->createStatDaily("msg_${code}", $msg_codes{$code});
	}

	printf "%s : %s : %d\n", $date1, $date2, scalar @$msg_log;
}

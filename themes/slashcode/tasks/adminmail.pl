#!/usr/bin/perl -w

use strict;

use vars qw( %task $me );

# Remember that timespec goes by the database's time, which should be
# GMT if you installed everything correctly.  So 6:07 AM GMT is a good
# sort of midnightish time for the Western Hemisphere.  Adjust for
# your audience and admins.
$task{$me}{timespec} = '7 6 * * *';
$task{$me}{timespec_panic_2} = ''; # if major panic, dailyStuff can wait
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;
	my($backupdb);
	if ($constants->{backup_db_user}) {
		$backupdb = getObject('Slash::DB', $constants->{backup_db_user});
	} else {
		$backupdb = $slashdb;
	}

	unless($slashdb) {
		slashdLog('No database to run adminmail against');
		return;
	}

	slashdLog('Send Admin Mail Begin');
	my $count = $backupdb->countDaily();

	# homepage hits are logged as either '' or 'shtml'
	$count->{'index'}{'index'} += delete $count->{'index'}{''};
	$count->{'index'}{'index'} += delete $count->{'index'}{'shtml'};
	# these are 404s
	delete $count->{'index.html'};

	my $sdTotalHits = $backupdb->getVar('totalhits', 'value');

	$sdTotalHits = $sdTotalHits + $count->{'total'};
	$backupdb->setVar("totalhits", $sdTotalHits);

	$backupdb->updateStamps();

	my $accesslog_rows = $slashdb->sqlCount('accesslog');
	my $formkeys_rows = $slashdb->sqlCount('formkeys');
	my $modlog_rows = $slashdb->sqlCount('moderatorlog');
	my $metamodlog_rows = $slashdb->sqlCount('metamodlog');

	my $mod_points = $slashdb->sqlSelect('SUM(points)', 'users_comments');
	my @yesttime = localtime(time-86400);
	my $yesterday = sprintf "%4d-%02d-%02d", 
		$yesttime[5] + 1900, $yesttime[4] + 1, $yesttime[3];
	my $used = $slashdb->sqlCount(
		'moderatorlog', 
		"ts BETWEEN '$yesterday 00:00' AND '$yesterday 23:59:59'"
	);
	my $modlog_hr = $slashdb->sqlSelectAllHashref(
		"val",
		"val, COUNT(*) AS count",
		"moderatorlog",
		"ts BETWEEN '$yesterday 00:00' AND '$yesterday 23:59:59'",
		"GROUP BY val"
	);
	my $modlog_total = $modlog_hr->{1}{count} + $modlog_hr->{-1}{count};
	my $mm_factor = ($modlog_rows ? $metamodlog_rows/$modlog_rows : 0);

	# Count comments posted yesterday... using a primary key,
	# if it'll save us a table scan.  On Slashdot this cuts the
	# query time from about 12 seconds to about 0.8 seconds.
	my $max_cid = $slashdb->sqlSelect("MAX(cid)", "comments");
	my $cid_limit_clause = "";
	if ($max_cid > 300_000) {
		# No site can get more than 100K comments a day.
		# It is decided.  :)
		$cid_limit_clause = "cid > " . ($max_cid-100_000)
			. " AND ";
	}
	my $comments = $slashdb->sqlSelect(
		"COUNT(*)",
		"comments",
		"$cid_limit_clause date BETWEEN '$yesterday 00:00' AND '$yesterday 23:59:59'"
	);

	my $modlog_text = sprintf(<<"EOT", $accesslog_rows, $formkeys_rows, $modlog_rows, $metamodlog_rows, $mm_factor, $mod_points, $modlog_total, ($mod_points ? $modlog_total*100/$mod_points : 0), $modlog_hr->{-1}{count}, $modlog_hr->{1}{count}, $comments);
 accesslog: %7d rows total
  formkeys: %7d rows total
    modlog: %7d rows total
metamodlog: %7d rows total (%.1fx)
mod points: %7d in system
used total: %7d yesterday (%.1f%%)
   used -1: %7d yesterday
   used +1: %7d yesterday
  comments: %7d posted yesterday
EOT

	my $email = <<EOT;
$constants->{sitename} Stats for yesterday

     total: $count->{'total'}
    unique: $count->{'unique'}
     users: $count->{'unique_users'}

$modlog_text
total hits: $sdTotalHits
  homepage: $count->{'index'}{'index'}
  journals: $count->{'journals'}
   indexes
EOT

	for (keys %{$count->{'index'}}) {
		$email .= "\t   $_=$count->{'index'}{$_}\n"
	}

	$email .= "\n-----------------------\n";


	for my $key (sort { $count->{'articles'}{$b} <=> $count->{'articles'}{$a} } keys %{$count->{'articles'}}) {
		my $value = $count->{'articles'}{$key};

 		my $story = $backupdb->getStory($key, ['title', 'uid']);

		$email .= sprintf("%6d %-16s %-30s by %s\n",
			$value, $key, substr($story->{'title'}, 0, 30),
			($slashdb->getUser($story->{uid}, 'nickname') || $story->{uid})
		) if $story->{'title'} && $story->{uid} && $value > 100;
	}

	$email .= "\n-----------------------\n";
	$email .= `$constants->{slashdir}/bin/tailslash -u $virtual_user -y today`;

# NewsForge's code...
# this should be put in an adminmail.pl in the newsforge theme,
# so it is just copied over; you probably know that, though
# -- pudge
#	my($c) = sqlSelectMany("count(*),date_format(date_sub(ts,interval 5 hour),\"%d %H\") as h,
#				date_format(date_sub(ts,interval 5 hour),\"%d\") as d",
#				"accesslog",
#				"to_days(date_sub(now(),interval 5 hour)) - to_days(date_sub(ts,interval 5 hour)) = 1",
#				"GROUP BY h ORDER BY h ASC");
#	my(%total, $max, $today, %data);
#	while (my($cnt, $h, $d) = $c->fetchrow) {
#		$h .= ":00 EST";
#		$total{$d} += $cnt;
#		$data{$h} = $cnt;
#		$max = $cnt if $max < $cnt;
#	}
#	$c->finish();
#	my $old_d;
#	for my $h (sort keys %data) {
#		$h =~ m/^(\d\d)/; my $d = $1 || "";
#		if ($old_d and $d ne $old_d and defined($total{$old_d})) {
#			print "   daily total: " . sprintf("%11u", $total{$old_d}), "\n\n";
#			delete $total{$old_d};
#		}
#		$old_d = $d;
#		print join("  ",
#			$h,
#			sprintf("%6.2f", $data{$h}/3600),
#			sprintf("%7u", $data{$h}),
#			"#" x int($data{$h}*40/$max)
#		), "\n";
#	}
#	if ($old_d and defined($total{$old_d})) {
#		print "   daily total: " . sprintf("%11u", $total{$old_d}), "\n\n";
#	}

	$email .= "\n-----------------------\n";

	# Send a message to the site admin.
	for (@{$constants->{stats_reports}}) {
		sendEmail($_, "$constants->{sitename} Stats Report", $email, 'bulk');
	}
	slashdLog('Send Admin Mail End');

	return ;
};

1;


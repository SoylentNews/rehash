#!/usr/bin/perl -w

use strict;
use Slash::Constants qw( :messages :slashd );
use Slash::Display;

use vars qw( %task $me );

# Remember that timespec goes by the database's time, which should be
# GMT if you installed everything correctly.  So 6:07 AM GMT is a good
# sort of midnightish time for the Western Hemisphere.  Adjust for
# your audience and admins.
$task{$me}{timespec} = '27 6 * * *';
$task{$me}{timespec_panic_2} = ''; # if major panic, dailyStuff can wait
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;
	my($stats, $backupdb, %data, %mod_data);

	my $statsSave = getObject('Slash::Stats');
	if ($constants->{backup_db_user}) {
		$stats = getObject('Slash::Stats', $constants->{backup_db_user});
		$backupdb = getObject('Slash::DB', $constants->{backup_db_user});
	} else {
		$stats = getObject('Slash::Stats');
		$backupdb = $slashdb;
	}

	unless($stats) {
		slashdLog('No database to run adminmail against');
		return;
	}

	slashdLog('Send Admin Mail Begin');
	my $count = $stats->countDaily();

	# homepage hits are logged as either '' or 'shtml'
	$count->{'index'}{'index'} += delete $count->{'index'}{''};
	$count->{'index'}{'index'} += delete $count->{'index'}{'shtml'};
	# these are 404s
	delete $count->{'index.html'};

	my $sdTotalHits = $stats->getVar('totalhits', 'value', 1);
	$sdTotalHits = $sdTotalHits + $count->{'total'};

	my $reasons = $slashdb->getReasons();
	my @reasons_m2able = grep { $reasons->{$_}{m2able} } keys %$reasons;
	my $reasons_m2able = join(",", @reasons_m2able);

	my $admin_clearpass_warning = '';
	if ($constants->{admin_check_clearpass}) {
		my $clear_admins = $stats->getAdminsClearpass();
		if ($clear_admins and keys %$clear_admins) {
			for my $admin (sort keys %$clear_admins) {
				$admin_clearpass_warning .=
					"$admin $clear_admins->{$admin}{value}";
			}
		}
		if ($admin_clearpass_warning) {
			$admin_clearpass_warning = <<EOT;


WARNING: The following admins accessed the site with their passwords,
in cookies, sent in the clear.  They have been told to change their
passwords but have not, as of the generation of this email.  They
need to do so immediately.

$admin_clearpass_warning
EOT
		}
	}

	my @yesttime = localtime(time-86400);
	my @weekagotime = localtime(time-86400*7);
	my $yesterday = sprintf "%4d-%02d-%02d", 
		$yesttime[5] + 1900, $yesttime[4] + 1, $yesttime[3];
	my $weekago = sprintf "%4d-%02d-%02d", 
		$weekagotime[5] + 1900, $weekagotime[4] + 1, $weekagotime[3];

	my $comments = $stats->countCommentsDaily($yesterday);
	my $accesslog_rows = $stats->sqlCount('accesslog');
	my $formkeys_rows = $stats->sqlCount('formkeys');
	my $modlogs = $stats->sqlCount('moderatorlog', 'active=1');
	my $modlogs_yest = $stats->sqlCount('moderatorlog',
		"active=1 AND ts BETWEEN '$yesterday 00:00' AND '$yesterday 23:59:59'");
	my $modlogs_needmeta = $stats->sqlCount('moderatorlog',
		"active=1 AND reason IN ($reasons_m2able)");
	my $modlogs_needmeta_yest = $stats->sqlCount('moderatorlog',
		"active=1 AND ts >= DATE_SUB(NOW(), INTERVAL 2 DAY)
		 AND reason IN ($reasons_m2able)");
	my($oldest_unm2d) = $stats->sqlSelect(
		"UNIX_TIMESTAMP(MIN(ts))",
		"moderatorlog",
		"active=1 AND reason IN ($reasons_m2able) AND m2status=0"
	);
	$oldest_unm2d ||= 0;
	my $youngest_modelig_uid = $stats->getYoungestEligibleModerator();
	my $youngest_modelig_created = $stats->getUser($youngest_modelig_uid,
		'created_at');
	my $metamodlogs = $stats->sqlCount('metamodlog', 'active=1');
	my $metamodlogs_yest = $stats->sqlCount('metamodlog',
		'active=1 AND ts >= DATE_SUB(NOW(), INTERVAL 2 DAY)');

	my $mod_points_pool = $stats->getPointsInPool();
	my $used = $stats->countModeratorLog($yesterday);
	my $modlog_yest_hr = $stats->countModeratorLogHour($yesterday);
	my $distinct_comment_ipids = $stats->getCommentsByDistinctIPID($yesterday);
	my $distinct_comment_posters_uids = $stats->getCommentsByDistinctUIDPosters($yesterday);
	my $submissions = $stats->countSubmissionsByDay($yesterday);
	my $submissions_comments_match = $stats->countSubmissionsByCommentIPID($yesterday, $distinct_comment_ipids);
	my $modlog_yest_total = $modlog_yest_hr->{1}{count} + $modlog_yest_hr->{-1}{count};
	my $consensus = $constants->{m2_consensus};

	my $m2_text = getM2Text($stats->getModM2Ratios());

	my $grand_total = $stats->countDailyByPage('', $yesterday);
	$data{grand_total} = $grand_total;
	for (qw|index article search comments palm journal rss|) {
		my $uniq = $stats->countDailyByPageDistinctIPID($_, $yesterday);
		my $pages = $stats->countDailyByPage($_, $yesterday);
		my $bytes = $stats->countBytesByPage($_, $yesterday);
		my $uids = $stats->countUsersByPage($_, $yesterday);
		$data{"${_}_uids"} = sprintf("%8d", $uniq);
		$data{"${_}_ipids"} = sprintf("%8d", $uniq);
		$data{"${_}_bytes"} = sprintf("%0.1f MB",$bytes/(1024*1024));
		$data{"${_}_page"} = sprintf("%8d", $pages);
		# Section is problematic in this definition, going to store the data in all
	  # "all" till this is resolved. -Brian
		$statsSave->createStatDaily($yesterday, "${_}_ipids", $uniq);
		$statsSave->createStatDaily($yesterday, "${_}_bytes", $bytes);
		$statsSave->createStatDaily($yesterday, "${_}_page", $pages);
	}

	$statsSave->createStatDaily($yesterday, "distinct_comment_posters", $distinct_comment_posters_uids);

# Not yet
#	my $codes = $stats->getMessageCodes($yesterday);
#	for (@$codes) {
#		my $temp->{name} = $_;
#		my $people = $stats->countDailyMessagesByUID($_, $yesterday);
#		my $uses = $stats->countDailyMessagesByCode($_, $yesterday);
#		my $mode = $stats->countDailyMessagesByMode($_, $yesterday);
#		$temp->{people} = sprintf("%8d", $people);
#		$temp->{uses} = sprintf("%8d", $uses);
#		$temp->{mode} = sprintf("%8d", $mode);
#		$statsSave->createStatDaily($yesterday, "message_${_}_people", $people);
#		$statsSave->createStatDaily($yesterday, "message_${_}_uses", $uses);
#		$statsSave->createStatDaily($yesterday, "message_${_}_mode", $mode);
#		push(@{$data{messages}}, $temp);
#	}

	my $sections =  $slashdb->getSections();
	$sections->{index} = 'index';
	for my $section (sort keys %$sections) {
		my $index = $constants->{defaultsection} eq $section ? 1 : 0;
		my $temp = {};
		$temp->{section_name} = $section;
		my $uniq = $stats->countDailyByPageDistinctIPID('', $yesterday, { section => $section });
		my $pages = $stats->countDailyByPage('', $yesterday, {
			section => $section,
			no_op => $constants->{op_exclude_from_countdaily}
		} );
		my $bytes = $stats->countBytesByPage('', $yesterday, { section => $section });
		my $users = $stats->countUsersByPage('', $yesterday, { section => $section });
		$temp->{ipids} = sprintf("%8d", $uniq);
		$temp->{bytes} = sprintf("%8.1f MB",$bytes/(1024*1024));
		$temp->{page} = sprintf("%8d", $pages);
		$temp->{users} = sprintf("%8d", $users);
		$statsSave->createStatDaily($yesterday, "ipids", $uniq, { section => $section });
		$statsSave->createStatDaily($yesterday, "bytes", $bytes, { section => $section } );
		$statsSave->createStatDaily($yesterday, "page", $pages, { section => $section });

		for (qw| index article search comments palm rss|) {
			my $uniq = $stats->countDailyByPageDistinctIPID($_, $yesterday, { section => $section  });
			my $pages = $stats->countDailyByPage($_, $yesterday, {
				section => $section,
				no_op => $constants->{op_exclude_from_countdaily}
			} );
			my $bytes = $stats->countBytesByPage($_, $yesterday, { section => $section  });
			my $users = $stats->countUsersByPage($_, $yesterday, { section => $section  });
			$temp->{$_}{ipids} = sprintf("%8d", $uniq);
			$temp->{$_}{bytes} = sprintf("%8.1f MB",$bytes/(1024*1024));
			$temp->{$_}{page} = sprintf("%8d", $pages);
			$temp->{$_}{users} = sprintf("%8d", $users);
			$statsSave->createStatDaily($yesterday, "${_}_ipids", $uniq, { section => $section});
			$statsSave->createStatDaily($yesterday, "${_}_bytes", $bytes, { section => $section});
			$statsSave->createStatDaily($yesterday, "${_}_page", $pages, { section => $section});
			$statsSave->createStatDaily($yesterday, "${_}_user", $users, { section => $section});
		}
		push(@{$data{sections}}, $temp);
	}


	my $total_bytes = $stats->countBytesByPage('', $yesterday, {
		no_op => $constants->{op_exclude_from_countdaily}
	} );

	my $admin_mods = $stats->getAdminModsInfo($yesterday, $weekago);
	my $admin_mods_text = getAdminModsText($admin_mods);

	$mod_data{repeat_mods} = $stats->getRepeatMods({
		min_count => $constants->{mod_stats_min_repeat}
	});

	$statsSave->createStatDaily($yesterday, "total", $count->{total});
	$statsSave->createStatDaily($yesterday, "grand_total", $grand_total);
	$statsSave->createStatDaily($yesterday, "total_bytes", $total_bytes);
	$statsSave->createStatDaily($yesterday, "unique", $count->{unique});
	$statsSave->createStatDaily($yesterday, "unique_users", $count->{unique_users});
	$statsSave->createStatDaily($yesterday, "comments", $comments);
	$statsSave->createStatDaily($yesterday, "homepage", $count->{index}{index});
	$statsSave->createStatDaily($yesterday, "distinct_comment_ipids", $distinct_comment_ipids);
	$statsSave->createStatDaily($yesterday, "distinct_comment_posters_uids", $distinct_comment_posters_uids);
	$statsSave->createStatDaily($yesterday, "consensus", $consensus);
	$statsSave->createStatDaily($yesterday, "mod_points_pool", $mod_points_pool);
	$statsSave->createStatDaily($yesterday, "mod_points_needmeta", $modlogs_needmeta_yest);
	$statsSave->createStatDaily($yesterday, "mod_points_spent", $modlog_yest_total);
	$statsSave->createStatDaily($yesterday, "mod_points_spent_plus_1", $modlog_yest_hr->{+1}{count});
	$statsSave->createStatDaily($yesterday, "mod_points_spent_minus_1", $modlog_yest_hr->{-1}{count});
	$statsSave->createStatDaily($yesterday, "m2_points_spent", $metamodlogs_yest);
	$statsSave->createStatDaily($yesterday, "oldest_unm2d", $oldest_unm2d);

	for my $nickname (keys %$admin_mods) {
		my $uid = $admin_mods->{$nickname}{uid};
		# Each stat writes one row into stats_daily for each admin who
		# modded anything, which is a lot of rows, but we want all the
		# data.
		for my $stat (qw( m1_up m1_down m2_fair m2_unfair )) {
			my $suffix = $uid
				? "_admin_$uid"
				: "_total";
			my $val = $admin_mods->{$nickname}{$stat};
			$statsSave->createStatDaily($yesterday, "$stat$suffix", $val);
		}
	}

	$data{total} = sprintf("%8d", $count->{total});
	$data{total_bytes} = sprintf("%0.1f MB",$total_bytes/(1024*1024));
	$data{unique} = sprintf("%8d", $count->{unique}), 
	$data{users} = sprintf("%8d", $count->{unique_users});
	$data{accesslog} = sprintf("%8d", $accesslog_rows);
	$data{formkeys} = sprintf("%8d", $formkeys_rows);

	$mod_data{comments} = sprintf("%8d", $comments);
	$mod_data{modlog} = sprintf("%8d", $modlogs);
	$mod_data{modlog_yest} = sprintf("%8d", $modlogs_yest);
	$mod_data{metamodlog} = sprintf("%8d", $metamodlogs);
	$mod_data{metamodlog_yest} = sprintf("%8d", $metamodlogs_yest);
	$mod_data{xmodlog} = sprintf("%.1fx", ($modlogs_needmeta ? $metamodlogs/$modlogs_needmeta : 0));
	$mod_data{xmodlog_yest} = sprintf("%.1fx", ($modlogs_needmeta_yest ? $metamodlogs_yest/$modlogs_needmeta_yest : 0));
	$mod_data{consensus} = sprintf("%8d", $consensus);
	$mod_data{oldest_unm2d_days} = sprintf("%.1f", (time-$oldest_unm2d)/86400);
	$mod_data{youngest_modelig_uid} = sprintf("%d", $youngest_modelig_uid);
	$mod_data{youngest_modelig_created} = sprintf("%11s", $youngest_modelig_created);
	$mod_data{mod_points_pool} = sprintf("%8d", $mod_points_pool);
	$mod_data{used_total} = sprintf("%8d", $modlog_yest_total);
	$mod_data{used_total_pool} = sprintf("%.1f", ($mod_points_pool ? $modlog_yest_total*100/$mod_points_pool : 0));
	$mod_data{used_total_comments} = sprintf("%.1f", ($comments ? $modlog_yest_total*100/$comments : 0));
	$mod_data{used_minus_1} = sprintf("%8d", $modlog_yest_hr->{-1}{count});
	$mod_data{used_minus_1_percent} = sprintf("%.1f", ($modlog_yest_total ? $modlog_yest_hr->{-1}{count}*100/$modlog_yest_total : 0) );
	$mod_data{used_plus_1} = sprintf("%8d", $modlog_yest_hr->{1}{count});
	$mod_data{used_plus_1_percent} = sprintf("%.1f", ($modlog_yest_total ? $modlog_yest_hr->{1}{count}*100/$modlog_yest_total : 0));
	$mod_data{day} = $yesterday;
	$mod_data{m2_text} = $m2_text;

	$data{comments} = $mod_data{comments};
	$data{IPIDS} = sprintf("%8d", scalar(@$distinct_comment_ipids));
	$data{submissions} = sprintf("%8d", $submissions);
	$data{sub_comments} = sprintf("%8.1f", ($submissions ? $submissions_comments_match*100/$submissions : 0));
	$data{total_hits} = sprintf("%8d", $sdTotalHits);
	$data{homepage} = sprintf("%8d", $count->{index}{index});
	$data{day} = $yesterday;
	$data{distinct_comment_posters_uids} = sprintf("%8d", $distinct_comment_posters_uids);

#	my @sections;
#	for (sort {lc($a) cmp lc($b)} keys %{$count->{index}}) {
#		push(@sections, { key => $_, value => $count->{index}{$_} });
#		$statsSave->createStatDaily($yesterday, "$_", $count->{index}{$_});
#	}

	my @lazy;
	for my $key (sort
		{ ($count->{articles}{$b} || 0) <=> ($count->{articles}{$a} || 0) }
		keys %{$count->{articles}}
	) {
		my $value = $count->{'articles'}{$key};

 		my $story = $backupdb->getStory($key, ['title', 'uid']);

		push(@lazy, sprintf("%6d %-16s %-30s by %s",
			$value, $key, substr($story->{'title'}, 0, 30),
			($slashdb->getUser($story->{uid}, 'nickname') || $story->{uid})
		)) if $story->{'title'} && $story->{uid} && $value > 100;
	}

	$mod_data{data} = \%mod_data;
	$mod_data{admin_mods_text} = $admin_mods_text;
	
	$data{data} = \%data;
#	$data{sections} = \@sections; 
	$data{lazy} = \@lazy; 
	$data{admin_clearpass_warning} = $admin_clearpass_warning;
	$data{tailslash} = `$constants->{slashdir}/bin/tailslash -u $virtual_user -y today` if $constants->{tailslash_stats};

	$data{backup_lag} = "";
	for my $slave_name (qw( backup search )) {
		my $virtuser = $constants->{"${slave_name}_db_user"};
		next unless $virtuser;
		my $bytes = $stats->getSlaveDBLagCount($virtuser);
		if ($bytes > ($constants->{db_slave_lag_ignore} || 10000000)) {
			$data{backup_lag} .= "\n" . getData('db lagged', {
				slave_name =>	$slave_name,
				bytes =>	$bytes,
			}, 'adminmail') . "\n";
		}
	}

	my $email = slashDisplay('display', \%data, {
		Return => 1, Page => 'adminmail', Nocomm => 1
	});

	my $mod_email = slashDisplay('display', \%mod_data, {
		Return => 1, Page => 'modmail', Nocomm => 1
	}) if $constants->{mod_stats};

	# Send a message to the site admin.
	my $messages = getObject('Slash::Messages');
	if ($messages) {
		$data{template_name} = 'display';
		$data{subject} = getData('email subject', {
			day =>	$data{day}
		}, 'adminmail');
		$data{template_page} = 'adminmail';
		my $message_users = $messages->getMessageUsers(MSG_CODE_ADMINMAIL);
		for (@$message_users) {
			$messages->create($_, MSG_CODE_ADMINMAIL, \%data);
		}

		if ($constants->{mod_stats}) {
			$mod_data{template_name} = 'display';
			$mod_data{subject} = getData('modmail subject', {
				day => $mod_data{day}
			}, 'adminmail');
			$mod_data{template_page} = 'modmail';
			my $mod_message_users = $messages->getMessageUsers(MSG_CODE_ADMINMAIL);
			for (@$mod_message_users) {
				$messages->create($_, MSG_CODE_ADMINMAIL, \%mod_data);
			}
		}
	}

	if ($constants->{mod_stats} && $mod_email =~ /\S/) {
		for (@{$constants->{mod_stats_reports}}) {
			sendEmail($_, $mod_data{subject}, $mod_email, 'bulk');
		}
	}

	for (@{$constants->{stats_reports}}) {
		sendEmail($_, $data{subject}, $email, 'bulk');
	}
	slashdLog('Send Admin Mail End');

	return ;
};

sub getM2Text {
	my($mmr, $options) = @_;

	# %$mmr is a hashref whose keys are dates, "yyyy-mm-dd".
	# Its values are hashrefs whose keys are M2 counts for
	# those days.  _Those_ values are also hashrefs of which
	# only one key, "c", is important and its value is the
	# count of M2 counts for that day.
	# For example, if $mmr->{'2002-01-01'}{5}{c} == 200,
	# that means that of the moderations performed on
	# 2002-01-01, there are 200 which have been M2'd 5 times.

	# Only one option supported for now (pretty trivial :)
	my $width = 80;
	$width = $options->{width} if $options->{width};
	$width = 10 if $width < 10;

	# Find the max count total for a day.
	my $max_day_count = 0;
	for my $day (keys %$mmr) {
		my $this_day_count = 0;
		for my $m2c (keys %{$mmr->{$day}}) {
			$this_day_count += $mmr->{$day}{$m2c}{c};
		}
		$max_day_count = $this_day_count
			if $this_day_count > $max_day_count;
	}

	# If there are no mods at all, we return nothing.
	return "" if $max_day_count == 0;

	# Prepare to build the $text data.
	my $text = "Moderations and their M2 counts:\n";
	my $prefix_len = 7;
	my $mult = ($width-$prefix_len)/$max_day_count;

	# Build the $text data, one line at a time.
	my @days = sort keys %$mmr;
	if (scalar(@days) > 30) {
		# If we have too much data, throw away the oldest.
		@days = @days[-30..-1];
	}
	for my $day (@days) {
		my $day_display = substr($day, 5); # e.g. '01-01'
		$text .= "$day_display: ";
		for my $m2c (sort { $b <=> $a } keys %{$mmr->{$day}}) {
			my $c = $mmr->{$day}{$m2c}{c};
			my $n = int($c*$mult+0.5);
			next unless $n;
			$text .= $m2c x $n;
		}
		$text .= "\n";
	}

	$text .= "\n";
	return $text;
}

sub getAdminModsText {
	my($am) = @_;
	return "" if !$am or !scalar(keys %$am);

	my $text = sprintf("%-13s   %4s %4s %5s    %5s %5s %6s %14s\n",
		"Nickname",
		"M1up", "M1dn", "M1up%",
		"M2fr", "M2un", " M2un%", " M2un% (month)"
	);
	my($num_admin_mods, $num_mods) = (0, 0);
	for my $nickname (sort { lc($a) cmp lc($b) } keys %$am) {
		my $amn = $am->{$nickname};
		my $m1_up_percent = 0;
		$m1_up_percent = $amn->{m1_up}*100
			/ ($amn->{m1_up} + $amn->{m1_down})
			if $amn->{m1_up} + $amn->{m1_down} > 0;
		my $m2_un_percent = 0;
		$m2_un_percent = $amn->{m2_unfair}*100
			/ ($amn->{m2_unfair} + $amn->{m2_fair})
			if $amn->{m2_unfair} + $amn->{m2_fair} > 20;
		my $m2_un_percent_mo = 0;
		$m2_un_percent_mo = $amn->{m2_unfair_mo}*100
			/ ($amn->{m2_unfair_mo} + $amn->{m2_fair_mo})
			if $amn->{m2_unfair_mo} + $amn->{m2_fair_mo} > 20;
		next unless $amn->{m1_up} || $amn->{m1_down}
			|| $amn->{m2_fair} || $amn->{m2_unfair};
		$text .= sprintf("%13.13s   %4d %4d %4d%%    %5d %5d %5.1f%% %5.1f%%\n",
			$nickname,
			$amn->{m1_up},
			$amn->{m1_down},
			$m1_up_percent,
			$amn->{m2_fair},
			$amn->{m2_unfair},
			$m2_un_percent,
			$m2_un_percent_mo
		);
		if ($nickname eq '~Day Total') {
			$num_mods += $amn->{m1_up};
			$num_mods += $amn->{m1_down};
		} else {
			$num_admin_mods += $amn->{m1_up};
			$num_admin_mods += $amn->{m1_down};
		}
	}
	$text .= sprintf("%d of %d mods (%.2f%%) were performed by admins.\n",
		$num_admin_mods,
		$num_mods,
		($num_mods ? $num_admin_mods*100/$num_mods : 0));
	return $text;
}

1;

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

	my @yesttime = localtime(time-86400);
	my $yesterday = sprintf "%4d-%02d-%02d", 
		$yesttime[5] + 1900, $yesttime[4] + 1, $yesttime[3];

	my $statsSave = getObject('Slash::Stats::Writer', '', { day => $yesterday  });
	# This will need to be changed to "log_db_user"
	if ($constants->{backup_db_user}) {
		$stats = getObject('Slash::Stats', $constants->{backup_db_user}, { day => $yesterday, create => 1  });
		$backupdb = getObject('Slash::DB', $constants->{backup_db_user});
	} else {
		$stats = getObject('Slash::Stats', "", { day => $yesterday, create => 1  });
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
					"$admin $clear_admins->{$admin}{value}\n";
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

	my $comments = $stats->countCommentsDaily();
	my $accesslog_rows = $stats->sqlCount('accesslog');
	my $formkeys_rows = $stats->sqlCount('formkeys');

	my $modlogs = $stats->countModeratorLog({
		active_only	=> 1,
	});
	my $modlogs_yest = $stats->countModeratorLog({
		active_only	=> 1,
		oneday_only	=> 1,
	});
	my $modlogs_needmeta = $stats->countModeratorLog({
		active_only	=> 1,
		m2able_only	=> 1,
	});
	my $modlogs_needmeta_yest = $stats->countModeratorLog({
		active_only	=> 1,
		oneday_only	=> 1,
		m2able_only	=> 1,
	});
	my $modlogs_incl_inactive = $stats->countModeratorLog();
	my $modlogs_incl_inactive_yest = $stats->countModeratorLog({
		oneday_only     => 1,
	});
	my $modlog_inactive_percent =
		($modlogs_incl_inactive - $modlogs)
		? ($modlogs_incl_inactive - $modlogs)*100 / $modlogs_incl_inactive
		: 0;
	my $modlog_inactive_percent_yest =
		($modlogs_incl_inactive_yest - $modlogs_yest)
		? ($modlogs_incl_inactive_yest - $modlogs_yest)*100 / $modlogs_incl_inactive_yest
		: 0;

	my $metamodlogs = $stats->countMetamodLog({
		active_only	=> 1,
	});
	my $metamodlogs_yest_fair = $stats->countMetamodLog({
		active_only	=> 1,
		oneday_only	=> 1,
		val		=> 1,
	});
	my $metamodlogs_yest_unfair = $stats->countMetamodLog({
		active_only	=> 1,
		oneday_only	=> 1,
		val		=> -1,
	});
	my $metamodlogs_yest_total = $metamodlogs_yest_fair + $metamodlogs_yest_unfair;
	my $metamodlogs_incl_inactive = $stats->countMetamodLog();
	my $metamodlogs_incl_inactive_yest = $stats->countMetamodLog({
		oneday_only     => 1,
	});
	my $metamodlog_inactive_percent =
		($metamodlogs_incl_inactive - $metamodlogs)
		? ($metamodlogs_incl_inactive - $metamodlogs)*100 / $metamodlogs_incl_inactive
		: 0;
	my $metamodlog_inactive_percent_yest =
		($metamodlogs_incl_inactive_yest - $metamodlogs_yest_total)
		? ($metamodlogs_incl_inactive_yest - $metamodlogs_yest_total)*100 / $metamodlogs_incl_inactive_yest
		: 0;

	my $oldest_unm2d = $stats->getOldestUnm2dMod();
	my $youngest_modelig_uid = $stats->getYoungestEligibleModerator();
	my $youngest_modelig_created = $stats->getUser($youngest_modelig_uid,
		'created_at');

	my $mod_points_pool = $stats->getPointsInPool();
	my $mod_tokens_pool_pos = $stats->getTokensInPoolPos();
	my $mod_tokens_pool_neg = $stats->getTokensInPoolNeg();
	my $used = $stats->countModeratorLog();
	my $modlog_yest_hr = $stats->countModeratorLogByVal();
	my $distinct_comment_ipids = $stats->getCommentsByDistinctIPID();
	my $distinct_comment_posters_uids = $stats->getCommentsByDistinctUIDPosters();
	my $submissions = $stats->countSubmissionsByDay();
	my $submissions_comments_match = $stats->countSubmissionsByCommentIPID($distinct_comment_ipids);
	my $modlog_count_yest_total = $modlog_yest_hr->{1}{count} + $modlog_yest_hr->{-1}{count};
	my $modlog_spent_yest_total = $modlog_yest_hr->{1}{spent} + $modlog_yest_hr->{-1}{spent};
	my $consensus = $constants->{m2_consensus};
	my $token_conversion_point = $stats->getTokenConversionPoint();

	my $oldest_to_show = int($oldest_unm2d) + 7;
	$oldest_to_show = 21 if $oldest_to_show < 21;
	my $m2_text = getM2Text($stats->getModM2Ratios(), {
		oldest => $oldest_to_show
	});

	my $grand_total = $stats->countDailyByPage('');
	$data{grand_total} = $grand_total;
	my $grand_total_static = $stats->countDailyByPage('',{ static => 'yes' } );
	$data{grand_total_static} = $grand_total_static;
	my $total_static = $stats->countDailyByPage('', {
		static => 'yes',
		no_op => $constants->{op_exclude_from_countdaily}
	} );
	$data{total_static} = $grand_total_static;
	my $total_subscriber = $stats->countDailySubscriber();
	for (qw|index article search comments palm journal rss|) {
		my $uniq = $stats->countDailyByPageDistinctIPID($_);
		my $pages = $stats->countDailyByPage($_);
		my $bytes = $stats->countBytesByPage($_);
		my $uids = $stats->countUsersByPage($_);
		$data{"${_}_uids"} = sprintf("%8d", $uids);
		$data{"${_}_ipids"} = sprintf("%8d", $uniq);
		$data{"${_}_bytes"} = sprintf("%0.1f MB",$bytes/(1024*1024));
		$data{"${_}_page"} = sprintf("%8d", $pages);
		# Section is problematic in this definition, going to store
		# the data in "all" till this is resolved. -Brian
		$statsSave->createStatDaily("${_}_ipids", $uniq);
		$statsSave->createStatDaily("${_}_bytes", $bytes);
		$statsSave->createStatDaily("${_}_page", $pages);
	}

	$statsSave->createStatDaily("distinct_comment_posters", $distinct_comment_posters_uids);

# Not yet
#	my $codes = $stats->getMessageCodes();
#	for (@$codes) {
#		my $temp->{name} = $_;
#		my $people = $stats->countDailyMessagesByUID($_, );
#		my $uses = $stats->countDailyMessagesByCode($_, );
#		my $mode = $stats->countDailyMessagesByMode($_, );
#		$temp->{people} = sprintf("%8d", $people);
#		$temp->{uses} = sprintf("%8d", $uses);
#		$temp->{mode} = sprintf("%8d", $mode);
#		$statsSave->createStatDaily("message_${_}_people", $people);
#		$statsSave->createStatDaily("message_${_}_uses", $uses);
#		$statsSave->createStatDaily("message_${_}_mode", $mode);
#		push(@{$data{messages}}, $temp);
#	}

	my $sections =  $slashdb->getDescriptions('sections-all');
	$sections->{index} = 'index';
	for my $section (sort keys %$sections) {
		my $index = $constants->{defaultsection} eq $section ? 1 : 0;
		my $temp = {};
		$temp->{section_name} = $section;
		my $uniq = $stats->countDailyByPageDistinctIPID('',  { section => $section });
		my $pages = $stats->countDailyByPage('',  {
			section => $section,
			no_op => $constants->{op_exclude_from_countdaily}
		} );
		my $bytes = $stats->countBytesByPage('',  { section => $section });
		my $users = $stats->countUsersByPage('',  { section => $section });
		$temp->{ipids} = sprintf("%8d", $uniq);
		$temp->{bytes} = sprintf("%8.1f MB",$bytes/(1024*1024));
		$temp->{page} = sprintf("%8d", $pages);
		$temp->{users} = sprintf("%8d", $users);
		$statsSave->createStatDaily("ipids", $uniq, { section => $section });
		$statsSave->createStatDaily("bytes", $bytes, { section => $section } );
		$statsSave->createStatDaily("page", $pages, { section => $section });

		for (qw| index article search comments palm rss|) {
			my $uniq = $stats->countDailyByPageDistinctIPID($_,  { section => $section  });
			my $pages = $stats->countDailyByPage($_,  {
				section => $section,
				no_op => $constants->{op_exclude_from_countdaily}
			} );
			my $bytes = $stats->countBytesByPage($_,  { section => $section  });
			my $users = $stats->countUsersByPage($_,  { section => $section  });
			$temp->{$_}{ipids} = sprintf("%8d", $uniq);
			$temp->{$_}{bytes} = sprintf("%8.1f MB",$bytes/(1024*1024));
			$temp->{$_}{page} = sprintf("%8d", $pages);
			$temp->{$_}{users} = sprintf("%8d", $users);
			$statsSave->createStatDaily("${_}_ipids", $uniq, { section => $section});
			$statsSave->createStatDaily("${_}_bytes", $bytes, { section => $section});
			$statsSave->createStatDaily("${_}_page", $pages, { section => $section});
			$statsSave->createStatDaily("${_}_user", $users, { section => $section});
		}
		push(@{$data{sections}}, $temp);
	}


	my $total_bytes = $stats->countBytesByPage('',  {
		no_op => $constants->{op_exclude_from_countdaily}
	} );
	my $grand_total_bytes = $stats->countBytesByPage('');

	my $admin_mods = $stats->getAdminModsInfo();
	my $admin_mods_text = getAdminModsText($admin_mods);

	$mod_data{repeat_mods} = $stats->getRepeatMods({
		min_count => $constants->{mod_stats_min_repeat}
	});
	$mod_data{reverse_mods} = $stats->getReverseMods();

	my $static_op_hour = $stats->getDurationByStaticOpHour({});
	for my $is_static (keys %$static_op_hour) {
		for my $op (keys %{$static_op_hour->{$is_static}}) {
			for my $hour (keys %{$static_op_hour->{$is_static}{$op}}) {
				my $prefix = "duration_";
				$prefix .= $is_static eq 'yes' ? 'st_' : 'dy_';
				$prefix .= "${op}_${hour}_";
				for my $statname (qw( avg stddev )) {
					my $value = $static_op_hour->{$is_static}{$op}{$hour}{"dur_$statname"};
					$statsSave->createStatDaily("$prefix$statname", $value);
				}
			}
		}
	}

	my $static_localaddr = $stats->getDurationByStaticLocaladdr();
	for my $is_static (keys %$static_localaddr) {
		for my $localaddr (keys %{$static_localaddr->{$is_static}}) {
			my $prefix = "duration_";
			$prefix .= $is_static eq 'yes' ? 'st_' : 'dy_';
			$prefix .= "${localaddr}_";
			$prefix =~ s/\W+/_/g; # change "."s in localaddr into "_"s
			for my $statname (qw( avg stddev )) {
				my $value = $static_localaddr->{$is_static}{$localaddr}{"dur_$statname"};
				$statsSave->createStatDaily("$prefix$statname", $value);
			}
		}
	}

	$statsSave->createStatDaily("total", $count->{total});
	$statsSave->createStatDaily("total_static", $total_static);
	$statsSave->createStatDaily("total_subscriber", $total_subscriber);
	$statsSave->createStatDaily("grand_total", $grand_total);
	$statsSave->createStatDaily("grand_total_static", $grand_total_static);
	$statsSave->createStatDaily("total_bytes", $total_bytes);
	$statsSave->createStatDaily("grand_total_bytes", $grand_total_bytes);
	$statsSave->createStatDaily("unique", $count->{unique});
	$statsSave->createStatDaily("unique_users", $count->{unique_users});
	$statsSave->createStatDaily("comments", $comments);
	$statsSave->createStatDaily("homepage", $count->{index}{index});
	$statsSave->createStatDaily("distinct_comment_ipids", $distinct_comment_ipids);
	$statsSave->createStatDaily("distinct_comment_posters_uids", $distinct_comment_posters_uids);
	$statsSave->createStatDaily("consensus", $consensus);
	$statsSave->createStatDaily("mod_points_pool", $mod_points_pool);
	$statsSave->createStatDaily("mod_tokens_pool_pos", $mod_tokens_pool_pos);
	$statsSave->createStatDaily("mod_tokens_pool_neg", $mod_tokens_pool_neg);
	$statsSave->createStatDaily("mod_points_needmeta", $modlogs_needmeta_yest);
	$statsSave->createStatDaily("mod_points_lost_spent", $modlog_spent_yest_total);
	$statsSave->createStatDaily("mod_points_lost_spent_plus_1", $modlog_yest_hr->{+1}{spent});
	$statsSave->createStatDaily("mod_points_lost_spent_minus_1", $modlog_yest_hr->{-1}{spent});
	$statsSave->createStatDaily("m2_freq", $constants->{m2_freq} || 86400);
	$statsSave->createStatDaily("m2_consensus", $constants->{m2_consensus} || 0);
	$statsSave->createStatDaily("m2_mintokens", $slashdb->getVar("m2_mintokens", "value", 1) || 0);
	$statsSave->createStatDaily("m2_points_lost_spent", $metamodlogs_yest_total);
	$statsSave->createStatDaily("m2_points_lost_spent_fair", $metamodlogs_yest_fair);
	$statsSave->createStatDaily("m2_points_lost_spent_unfair", $metamodlogs_yest_unfair);
	$statsSave->createStatDaily("oldest_unm2d", $oldest_unm2d);
	$statsSave->createStatDaily("mod_token_conversion_point", $token_conversion_point);
	$statsSave->createStatDaily("submissions", $submissions);
	$statsSave->createStatDaily("submissions_comments_match", $submissions_comments_match);

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
			$statsSave->createStatDaily("$stat$suffix", $val);
		}
	}

	$data{total} = sprintf("%8d", $count->{total});
	$data{total_bytes} = sprintf("%0.1f MB",$total_bytes/(1024*1024));
	$data{grand_total_bytes} = sprintf("%0.1f MB",$grand_total_bytes/(1024*1024));
	$data{unique} = sprintf("%8d", $count->{unique}), 
	$data{users} = sprintf("%8d", $count->{unique_users});
	$data{accesslog} = sprintf("%8d", $accesslog_rows);
	$data{formkeys} = sprintf("%8d", $formkeys_rows);

	$mod_data{comments} = sprintf("%8d", $comments);
	$mod_data{modlog} = sprintf("%8d", $modlogs);
	$mod_data{modlog_inactive_percent} = sprintf("%.1f", $modlog_inactive_percent);
	$mod_data{modlog_yest} = sprintf("%8d", $modlogs_yest);
	$mod_data{modlog_inactive_percent_yest} = sprintf("%.1f", $modlog_inactive_percent_yest);
	$mod_data{metamodlog} = sprintf("%8d", $metamodlogs);
	$mod_data{metamodlog_inactive_percent} = sprintf("%.1f", $metamodlog_inactive_percent);
	$mod_data{metamodlog_yest} = sprintf("%8d", $metamodlogs_yest_total);
	$mod_data{metamodlog_inactive_percent_yest} = sprintf("%.1f", $metamodlog_inactive_percent_yest);
	$mod_data{xmodlog} = sprintf("%.1fx", ($modlogs_needmeta ? $metamodlogs/$modlogs_needmeta : 0));
	$mod_data{xmodlog_yest} = sprintf("%.1fx", ($modlogs_needmeta_yest ? $metamodlogs_yest_total/$modlogs_needmeta_yest : 0));
	$mod_data{consensus} = sprintf("%8d", $consensus);
	$mod_data{oldest_unm2d_days} = sprintf("%10.1f", $oldest_unm2d ? (time-$oldest_unm2d)/86400 : -1);
	$mod_data{youngest_modelig_uid} = sprintf("%d", $youngest_modelig_uid);
	$mod_data{youngest_modelig_created} = sprintf("%11s", $youngest_modelig_created);
	$mod_data{mod_points_pool} = sprintf("%8d", $mod_points_pool);
	$mod_data{used_total} = sprintf("%8d", $modlog_count_yest_total);
	$mod_data{used_total_pool} = sprintf("%.1f", ($mod_points_pool ? $modlog_spent_yest_total*100/$mod_points_pool : 0));
	$mod_data{used_total_comments} = sprintf("%.1f", ($comments ? $modlog_count_yest_total*100/$comments : 0));
	$mod_data{used_minus_1} = sprintf("%8d", $modlog_yest_hr->{-1}{count});
	$mod_data{used_minus_1_percent} = sprintf("%.1f", ($modlog_count_yest_total ? $modlog_yest_hr->{-1}{count}*100/$modlog_count_yest_total : 0) );
	$mod_data{used_plus_1} = sprintf("%8d", $modlog_yest_hr->{1}{count});
	$mod_data{used_plus_1_percent} = sprintf("%.1f", ($modlog_count_yest_total ? $modlog_yest_hr->{1}{count}*100/$modlog_count_yest_total : 0));
	$mod_data{mod_points_avg_spent} = $modlog_count_yest_total ? sprintf("%12.3f", $modlog_spent_yest_total/$modlog_count_yest_total) : "(n/a)";
	$mod_data{day} = $yesterday;
	$mod_data{token_conversion_point} = sprintf("%8d", $token_conversion_point);
	$mod_data{m2_text} = $m2_text;

	$data{comments} = $mod_data{comments};
	$data{IPIDS} = sprintf("%8d", scalar(@$distinct_comment_ipids));
	$data{submissions} = sprintf("%8d", $submissions);
	$data{sub_comments} = sprintf("%8.1f", ($submissions ? $submissions_comments_match*100/$submissions : 0));
	$data{total_hits} = sprintf("%8d", $sdTotalHits);
	$data{homepage} = sprintf("%8d", $count->{index}{index});
	$data{day} = $yesterday ;
	$data{distinct_comment_posters_uids} = sprintf("%8d", $distinct_comment_posters_uids);

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

	$data{sfnet} = { };
	my $gids = $constants->{stats_sfnet_groupids};
	if ($gids && @$gids) {
		for my $groupid (@$gids) {
			my $hr = $stats->countSfNetIssues($groupid);
			for my $issue (sort keys %$hr) {
				my $lc_issue = lc($issue);
				$lc_issue =~ s/\W+//g;
				$statsSave->createStatDaily("sfnet_${groupid}_${lc_issue}_open", $hr->{$issue}{open});
				$statsSave->createStatDaily("sfnet_${groupid}_${lc_issue}_total", $hr->{$issue}{total});
				$data{sfnet}{$groupid}{$issue} = $hr->{$issue};
			}
		}
	}

	$data{top_referers} = $stats->getTopReferers();

	my $new_users_yest = $slashdb->getNumNewUsersSinceDaysback(1)
		- $slashdb->getNumNewUsersSinceDaysback(0);
	$statsSave->createStatDaily('users_created', $new_users_yest);

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

	my $constants = getCurrentStatic();
	my $consensus = $constants->{m2_consensus};

	# %$mmr is a hashref whose keys are dates, "yyyy-mm-dd".
	# Its values are hashrefs whose keys are M2 counts for
	# those days.  _Those_ values are also hashrefs of which
	# only one key, "c", is important and its value is the
	# count of M2 counts for that day.
	# For example, if $mmr->{'2002-01-01'}{5}{c} == 200,
	# that means that of the moderations performed on
	# 2002-01-01, there are 200 which have been M2'd 5 times.
	# Special keys are "X", which substitutes for all mods
	# which have been completely M2'd, and "_" which is for
	# mods which cannot be M2'd.

	# Only one option supported for now (pretty trivial :)
	my $width = 78;
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
	my $prefix_len = 7;
	my $width_histo = $width-$prefix_len;
	$width_histo = 5 if $width_histo < 5;
	my $mult = $width_histo/$max_day_count;
	$mult = 1 if $mult > 1;
	my $per = sprintf("%.0f", 1/$mult);
	my $text = "Moderations and their M2 counts (each char represents $per mods):\n";

	# Build the $text data, one line at a time.
	my @days = sort keys %$mmr;
	my $oldest = $options->{oldest} || 30;
	if (scalar(@days) > $oldest) {
		# If we have too much data, throw away the oldest.
		@days = @days[-$oldest..-1];
	}
	sub valsort { ($b eq 'X' ? 999 : $b eq '_' ? -999 : $b) <=> ($a eq 'X' ? 999 : $a eq '_' ? -999 : $a) }
	for my $day (@days) {
		my $day_display = substr($day, 5); # e.g. '01-01'
		$text .= "$day_display: ";
		for my $m2c (sort valsort keys %{$mmr->{$day}}) {
			my $c = $mmr->{$day}{$m2c}{c};
			my $n = int($c*$mult+0.5);
			next unless $n;
			my $char = $m2c;
			$char = sprintf("%x", $m2c) if $m2c =~ /^\d+$/;
			$text .= $char x $n;
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

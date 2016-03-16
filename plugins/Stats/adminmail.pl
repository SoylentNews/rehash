#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

use strict;
use utf8;
use Slash::Constants qw( :messages :slashd );
use Slash::Display;

use vars qw( %task $me );

# Remember that timespec goes by the database's time, which should be
# GMT if you installed everything correctly.  So 6:07 AM GMT is a good
# sort of midnightish time for the Western Hemisphere.  Adjust for
# your audience and admins.
$task{$me}{timespec} = '17 5 * * *';
$task{$me}{timespec_panic_2} = ''; # if major panic, dailyStuff can wait
$task{$me}{resource_locks} = { log_slave => 1 };
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;
	my(%data, %mod_data);
	
	# These are the ops (aka pages) that we scan for.
	my @PAGES = qw|index article search comments palm journal rss page users|;
	push @PAGES, @{$constants->{op_extras_countdaily}};
	$data{extra_pagetypes} = [ @{$constants->{op_extras_countdaily}} ];

	my $days_back;
	if (defined $constants->{task_options}{days_back}) {
		$days_back = $constants->{task_options}{days_back};
	} else {
		$days_back = 1;
	}
	my @yesttime = localtime(time-86400*$days_back);
	my $yesterday = sprintf "%4d-%02d-%02d", 
		$yesttime[5] + 1900, $yesttime[4] + 1, $yesttime[3];
	
	my $overwrite = 0;
	$overwrite = 1 if $constants->{task_options}{overwrite};

	my $create = 1;
	$create = 0 if $constants->{task_options}{nocreate};

	# If overwrite is set to 1, we delete any stats which may have
	# been written by an earlier run of this task.
	my $statsSave = getObject('Slash::Stats::Writer',
		{ nocache => 1 }, { day => $yesterday, overwrite => $overwrite });

	my $stats = getObject('Slash::Stats', { db_type => 'reader' });
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	
	
	# 1.5 hours
	my $logdb = getObject('Slash::Stats', {
		db_type	=> 'log_slave',
		nocache		=> 1,
	}, {
		day		=> $yesterday,
		create		=> $create,
		other_no_op	=> [@PAGES]
	});


	unless ($logdb) {
		slashdLog('No database to run adminmail against');
		return;
	}

	slashdLog("Send Admin Mail Begin for $yesterday");

	# figure out all the days we want to set average story commentcounts for
	my $cc_days = $stats->getDaysOfUnarchivedStories();

	# compute dates for the last 3 days so we can get the
	# average hits per story for each in the e-mail	
	
	# we use this array to figure out what comment count
	# days we put in the the stats e-mail too

	my @ah_days = ($yesterday);
	for my $db (1, 2) {
		my @day = localtime(time-86400*($days_back+$db));
		my $day = sprintf "%4d-%02d-%02d",
        	        $day[5] + 1900, $day[4] + 1, $day[3];
		push @ah_days, $day;
	}
	
	
	# let's do the errors
	slashdLog("Counting Error Pages Begin");
	$data{not_found} = $logdb->countByStatus("404");
	$statsSave->createStatDaily("not_found", $data{not_found});
	$data{status_202} = $logdb->countByStatus("202");
	$statsSave->createStatDaily("status_202", $data{status_202});

	my $errors = $logdb->getErrorStatuses();
	my $error_count = $logdb->countErrorStatuses();
	$data{error_count} = $error_count;
	$statsSave->createStatDaily("error_count", $data{error_count});
	$data{errors} = {};
	for my $type (@$errors) {
		$data{errors}{$type->{op}} = $type->{count};
		$statsSave->createStatDaily("error_$type->{op}}", $type->{count});
	}
	slashdLog("Counting Error Pages End");

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

	# depending on the options you pass these you can show the top N offenders in each category, 
	# the top N offenders above the threshold or all offenders above the defined threshold.
	# Right now we show up to 10 but only if they're above the designated thresholds 

	my $bp_ip     = $stats->getTopBadPasswordsByIP(
		{ limit => 10, min => $constants->{bad_password_warn_ip}     || 0 });
	my $bp_subnet = $stats->getTopBadPasswordsBySubnet(
		{ limit => 10, min => $constants->{bad_password_warn_subnet} || 0 });
	my $bp_uid    = $stats->getTopBadPasswordsByUID(
		{ limit => 10, min => $constants->{bad_password_warn_uid}    || 0 });
	my $bp_warning;

	if (@$bp_ip or @$bp_subnet or @$bp_uid) {
		$bp_warning .= "Bad password attempts\n\n";
		if (@$bp_uid) {
			$bp_warning .= "UID      Username                         Attempts\n";
			$bp_warning .= sprintf("%-8s %-32s   %6s\n",
				$_->{uid}, $_->{nickname}, $_->{count}
			) foreach @$bp_uid;
			$bp_warning .= "\n";
		}
		if (@$bp_ip) {
			$bp_warning .= "IP               Attempts\n";
			$bp_warning .= sprintf("%-15s  %8s\n",
				$_->{ip}, $_->{count}
			) foreach @$bp_ip;
			$bp_warning .= "\n";
		}
		if (@$bp_subnet) {
			$bp_warning .= "Subnet           Attempts\n";
			$bp_warning .= sprintf("%-15s  %8s\n",
				$_->{subnet}, $_->{count}
			) foreach @$bp_subnet;
			$bp_warning .= "\n";
		}
	}
	$data{bad_password_warning} = $bp_warning;

	slashdLog("Moderation Stats Begin");

	# 0.25 hours
	slashdLog("row counting Begin");
	my $comments = $stats->countCommentsDaily();
	my $formkeys_rows = $stats->sqlCount('formkeys');
	slashdLog("row counting End");

	slashdLog("countModeratorLog Begin");
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
	slashdLog("countModeratorLog End");

	my($metamodlogs, $unm2dmods,
		$metamodlogs_yest_fair, $metamodlogs_yest_unfair, $metamodlogs_yest_total,
		$metamodlogs_incl_inactive, $metamodlogs_incl_inactive_yest,
		$metamodlog_inactive_percent, $metamodlog_inactive_percent_yest,
		$oldest_unm2d, $oldest_unm2d_days);
	if ($constants->{m2}) {
		slashdLog("countMetamodLog Begin");
		$metamodlogs = $stats->countMetamodLog({
			active_only	=> 1,
		});
		$unm2dmods = $stats->countUnmetamoddedMods({
			active_only	=> 1,
		});
		$metamodlogs_yest_fair = $stats->countMetamodLog({
			active_only	=> 1,
			oneday_only	=> 1,
			val		=> 1,
		});
		$metamodlogs_yest_unfair = $stats->countMetamodLog({
			active_only	=> 1,
			oneday_only	=> 1,
			val		=> -1,
		});
		$metamodlogs_yest_total = $metamodlogs_yest_fair + $metamodlogs_yest_unfair;
		$metamodlogs_incl_inactive = $stats->countMetamodLog();
		$metamodlogs_incl_inactive_yest = $stats->countMetamodLog({
			oneday_only     => 1,
		});
		$metamodlog_inactive_percent =
			($metamodlogs_incl_inactive - $metamodlogs)
			? ($metamodlogs_incl_inactive - $metamodlogs)*100 / $metamodlogs_incl_inactive
			: 0;
		$metamodlog_inactive_percent_yest =
			($metamodlogs_incl_inactive_yest - $metamodlogs_yest_total)
			? ($metamodlogs_incl_inactive_yest - $metamodlogs_yest_total)*100 / $metamodlogs_incl_inactive_yest
			: 0;
		slashdLog("countMetamodLog End");
		$oldest_unm2d = $stats->getOldestUnm2dMod();
		$oldest_unm2d_days = sprintf("%10.1f", $oldest_unm2d ? (time-$oldest_unm2d)/86400 : -1);
	}

	my $youngest_modelig_uid = $stats->getYoungestEligibleModerator();
	my $youngest_modelig_created = $stats->getUser($youngest_modelig_uid,
		'created_at');

	slashdLog("Points and Token Pool Begin");
	my $mod_points_pool = $stats->getPointsInPool();
	my $mod_tokens_pool_pos = $stats->getTokensInPoolPos();
	my $mod_tokens_pool_neg = $stats->getTokensInPoolNeg();
	slashdLog("Points and Token Pool End");

	# 0.25 hours
	slashdLog("Comment Posting Stats Begin");
	my $used = $stats->countModeratorLog();
	my $modlog_yest_hr = $stats->countModeratorLogByVal();
	my $distinct_comment_ipids = $stats->getCommentsByDistinctIPID();
	my($distinct_comment_ipids_anononly,
	   $distinct_comment_ipids_loggedinonly,
	   $distinct_comment_ipids_anonandloggedin,
	   $comments_ipids_anononly,
	   $comments_ipids_loggedinonly,
	   $comments_ipids_anonandloggedin) = $stats->countCommentsByDistinctIPIDPerAnon();
# See comment for countCommentsFromProxyAnon.
#	my $comments_proxyanon = $stats->countCommentsFromProxyAnon();
	my $distinct_comment_posters_uids = $stats->getCommentsByDistinctUIDPosters();
	my $comments_discussiontype_hr = $stats->countCommentsByDiscussionType();
	slashdLog("Comment Posting Stats End");

	slashdLog("Submissions Stats Begin");
	my $submissions = $stats->countSubmissionsByDay();
	my $submissions_comments_match = $stats->countSubmissionsByCommentIPID($distinct_comment_ipids);
	slashdLog("Submissions Stats End");
	my $modlog_count_yest_total = ($modlog_yest_hr->{1}{count} || 0) + ($modlog_yest_hr->{-1}{count} || 0);
	my $modlog_spent_yest_total = ($modlog_yest_hr->{1}{spent} || 0) + ($modlog_yest_hr->{-1}{spent} || 0);
	my $consensus = $constants->{m2_consensus};
	slashdLog("Misc Moderation Stats Begin");
	my $token_conversion_point = $stats->getTokenConversionPoint();

	my $m2_text = '';
	if ($constants->{m2}) {
		my $oldest_to_show = int($oldest_unm2d_days) + 7;
		$oldest_to_show = 21 if $oldest_to_show < 21;
		$m2_text = getM2Text($stats->getModM2Ratios(), {
			oldest => $oldest_to_show
		});
	}
	slashdLog("Misc Moderation Stats End");

	slashdLog("Problem Modders Begin");
	my $late_modders 		= $stats->getTopModdersNearArchive({limit => 5});
	my $early_inactive_modders      = $stats->getTopEarlyInactiveDownmodders({limit => 5 });
	slashdLog("Problem Modders End");

	foreach my $mod (@$late_modders){
		$mod_data{late_modders_report} .= sprintf("%-6d %-20s %5d \n",$mod->{uid}, $mod->{nickname}, $mod->{count});
	}

	foreach my $mod (@$early_inactive_modders){
		$mod_data{early_inactive_modders_report} .= sprintf("%-6d %-20s %5d \n",$mod->{uid}, $mod->{nickname}, $mod->{count});
	}
	
	slashdLog("Moderation Stats End");

	# 2 hours
	slashdLog("Page Counting Begin");
	# I'm pulling the value out with "+0" because that returns us an
	# exact integer instead of scientific notation which rounds off.
	# Another one of those SQL oddities! - Jamie 2003/08/12
	my $sdTotalHits = $reader->sqlSelect("value+0", "vars", "name='totalhits'");
	my $daily_total = $logdb->countDailyByPage('', {
		no_op => $constants->{op_exclude_from_countdaily},
	});

	my $anon_daily_total = $logdb->countDailyByPage('', {
		no_op     => $constants->{op_exclude_from_countdaily},
		user_type => "anonymous"
	});

	my $logged_in_daily_total = $logdb->countDailyByPage('', {
		no_op     => $constants->{op_exclude_from_countdaily},
		user_type => "logged-in"
	});
	
	$sdTotalHits = $sdTotalHits + $daily_total;
	# Need to figure in the main section plus what the handler is.
	# This doesn't work for the other sites... -Brian
	my $homepage = $logdb->countDailyByPage('index', {
		skid    => $constants->{mainpage_skid},
		no_op   => $constants->{op_exclude_from_countdaily},
	});

	my $unique_users = $logdb->countUsersMultiTable({ tables => [qw(accesslog_temp accesslog_temp_rss)]});
	
	my $unique_ips   = $logdb->countUniqueIPs();   
	
	my $anon_ips =  $logdb->countUniqueIPs({ anon => "yes"});
	my $logged_in_ips = $logdb->countUniqueIPs({anon => "no"});

	my $grand_total = $logdb->countDailyByPage('');
	$grand_total   += $logdb->countDailyByPage('', { table_suffix => "_rss"});
	$data{grand_total} =  sprintf("%8u", $grand_total);
	my $grand_total_static = $logdb->countDailyByPage('',{ static => 'yes' } );
	$grand_total_static   += $logdb->countDailyByPage('',{ static => 'yes', table_suffix => "_rss" } );
	$data{grand_total_static} = sprintf("%8u", $grand_total_static);
	my $total_static = $logdb->countDailyByPage('', {
		static => 'yes',
		no_op => $constants->{op_exclude_from_countdaily}
	} );
	$data{total_static} = sprintf("%8u", $total_static);
	my $total_subscriber = $logdb->countDailySubscribers();
	my $unique_users_subscriber = 0;
	$unique_users_subscriber = $logdb->countUsersByPage('', {
		table_suffix => "_subscriber"
	});
	my $total_secure = $logdb->countDailySecure();

	for my $op (@PAGES) {
		my $summary;
		my $options = { op => $op };
		$options->{table_suffix} = "_rss" if $op eq "rss";
		$summary = $logdb->getSummaryStats($options);
		my $uniq  = $summary->{cnt}	|| 0;
		my $pages = $summary->{pages}	|| 0;
		my $bytes = $summary->{bytes}	|| 0;
		my $uids  = $summary->{uids}	|| 0;

		$data{"${op}_label"} = sprintf("%8s", $op);
		$data{"${op}_uids"} = sprintf("%8u", $uids);
		$data{"${op}_ipids"} = sprintf("%8u", $uniq);
		$data{"${op}_bytes"} = sprintf("%0.1f MB", $bytes/(1024*1024));
		$data{"${op}_page"} = sprintf("%8u", $pages);
		# Section is problematic in this definition, going to store
		# the data in "all" till this is resolved. -Brian
		$statsSave->createStatDaily("${op}_uids", $uids);
		$statsSave->createStatDaily("${op}_ipids", $uniq);
		$statsSave->createStatDaily("${op}_bytes", $bytes);
		$statsSave->createStatDaily("${op}_page", $pages);
		if ($op eq "article") {
			my $avg = $stats->getAverageHitsPerStoryOnDay($yesterday, $pages);
			$statsSave->createStatDaily("avg_hits_per_story", $avg);
		}
		if ($op eq 'slashdot-it') {
			# This "badge" page gets its normal stats plus two more sets
			# breaking its total down into badges delivered to RSS readers,
			# and those not.
			my $from_rss = $logdb->getSummaryStats({ op => $op, qs_like => q{from=rss%} });
			$statsSave->createStatDaily("${op}_rss_uids",  $from_rss->{uids});
			$statsSave->createStatDaily("${op}_rss_ipids", $from_rss->{cnt});
			$statsSave->createStatDaily("${op}_rss_bytes", $from_rss->{bytes});
			$statsSave->createStatDaily("${op}_rss_page",  $from_rss->{pages});
			my $no_rss = $logdb->getSummaryStats({ op => $op, qs_not_like => q{from=rss%} });
			$statsSave->createStatDaily("${op}_norss_uids",  $no_rss->{uids});
			$statsSave->createStatDaily("${op}_norss_ipids", $no_rss->{cnt});
			$statsSave->createStatDaily("${op}_norss_bytes", $no_rss->{bytes});
			$statsSave->createStatDaily("${op}_norss_page",  $no_rss->{pages});
		}
	}
	#Other not recorded
	{
		my $options = { table_suffix => "_other"};
		my $uniq = $logdb->countDailyByPageDistinctIPID('', $options);
		my $pages = $logdb->countDailyByPage('', $options);
		my $bytes = $logdb->countBytesByPage('', $options);
		my $uids = $logdb->countUsersByPage('', $options);
		$data{"other_uids"} = sprintf("%8u", $uids || 0);
		$data{"other_ipids"} = sprintf("%8u", $uniq || 0);
		$data{"other_bytes"} = sprintf("%0.1f MB", ($bytes || 0)/(1024*1024));
		$data{"other_page"} = sprintf("%8u", $pages || 0);
		# Section is problematic in this definition, going to store
		# the data in "all" till this is resolved. -Brian
		$statsSave->createStatDaily("other_uids", $uids);
		$statsSave->createStatDaily("other_ipids", $uniq);
		$statsSave->createStatDaily("other_bytes", $bytes);
		$statsSave->createStatDaily("other_page", $pages);
	}
	my %combo = (
		ind		=> [ ['index'],			[]			],
		ind_no_art	=> [ ['index'],			['article']		],
		ind_no_rss	=> [ ['index'],			['rss']			],
		indart		=> [ ['index','article'],	[]			],
		indart_no_rss	=> [ ['index','article'],	['rss']			],
		art		=> [ ['article'],		[]			],
		art_no_ind	=> [ ['article'],		['index']		],
		art_no_rss	=> [ ['article'],		['rss']			],
		rss		=> [ ['rss'],			[]			],
		rss_no_ind	=> [ ['rss'],			['index']		],
		rss_no_art	=> [ ['rss'],			['article']		],
		rss_no_indart	=> [ ['rss'],			['index','article']	],
		rssart		=> [ ['rss','article'],		[]			],
		rssart_no_ind	=> [ ['rss','article'],		['index']		],
	);
	for my $key (sort keys %combo) {
		my @args = @{ $combo{$key} };
		$statsSave->createStatDaily("opcombo_$key",
			$logdb->getOpCombinationStats(@args));
	}
	slashdLog("Page Counting End");

# Not yet
#	my $codes = $stats->getMessageCodes();
#	for (@$codes) {
#		my $temp->{name} = $_;
#		my $people = $stats->countDailyMessagesByUID($_, );
#		my $uses = $stats->countDailyMessagesByCode($_, );
#		my $mode = $stats->countDailyMessagesByMode($_, );
#		$temp->{people} = sprintf("%8u", $people);
#		$temp->{uses} = sprintf("%8u", $uses);
#		$temp->{mode} = sprintf("%8u", $mode);
#		$statsSave->createStatDaily("message_${_}_people", $people);
#		$statsSave->createStatDaily("message_${_}_uses", $uses);
#		$statsSave->createStatDaily("message_${_}_mode", $mode);
#		push(@{$data{messages}}, $temp);
#	}

	# 1 hour
	slashdLog("Sectional Stats Begin");
	my $skins =  $slashdb->getDescriptions('skins');
	my $stats_from_rss = $logdb->countFromRSSStatsBySections({ no_op => $constants->{op_exclude_from_countdaily} });
	#XXXSECTIONTOPICS - don't think we need this anymore but just making sure
	#$sections->{index} = 'index';
	
	slashdLog("Other Section Summary Stats Begin");
	my $other_section_summary_stats = $logdb->getSectionSummaryStats({
		table_suffix => "_other" 
	});
	slashdLog("Other Section Summary Stats End");
	
	
	for my $skid (sort keys %$skins) {
		my $temp = {};
		$temp->{skin_name} = $skins->{$skid};
		my $summary = $logdb->getSummaryStats({ skid => $skid, no_op => $constants->{op_exclude_from_countdaily} });
		my $uniq = $summary->{cnt}	|| 0;
		my $pages = $summary->{pages}	|| 0;
		my $bytes = $summary->{bytes}	|| 0;
		my $users = $summary->{uids}	|| 0;
		my $users_subscriber = 0;
		$users_subscriber = $logdb->countUsersByPage('', {
			skid			=> $skid,
			table_suffix		=> "_subscriber"
		});
		$temp->{ipids} = sprintf("%8u", $uniq);
		$temp->{bytes} = sprintf("%8.1f MB",$bytes/(1024*1024));
		$temp->{pages} = sprintf("%8u", $pages);
		$temp->{site_users} = sprintf("%8u", $users);
		$statsSave->createStatDaily("ipids", $uniq, { skid => $skid });
		$statsSave->createStatDaily("bytes", $bytes, { skid => $skid } );
		$statsSave->createStatDaily("page", $pages, { skid => $skid });
		$statsSave->createStatDaily("users", $users, { skid => $skid });
		$statsSave->createStatDaily("users_subscriber", $users_subscriber, { skid => $skid });
			
		foreach my $d (@$cc_days) {
			my $avg_comments = $stats->getAverageCommentCountPerStoryOnDay($d, { skid => $skid }) || 0;
			$statsSave->createStatDaily("avg_comments_per_story", $avg_comments, 
							{ skid => $skid, overwrite => 1, day => $d });
		}

		for my $op (@PAGES) {
			my $summary;
			my $options = { skid => $skid, op => $op };
			$options->{table_suffix} = "_rss" if $op eq "rss";
			$summary = $logdb->getSummaryStats($options);
			my $uniq  = $summary->{cnt}	|| 0;
			my $pages = $summary->{pages}	|| 0;
			my $bytes = $summary->{bytes}	|| 0;
			my $users = $summary->{uids}	|| 0;
			$temp->{$op}{label} = sprintf("%8s", $op);
			$temp->{$op}{ipids} = sprintf("%8u", $uniq);
			$temp->{$op}{bytes} = sprintf("%8.1f MB",$bytes/(1024*1024));
			$temp->{$op}{pages} = sprintf("%8u", $pages);
			$temp->{$op}{users} = sprintf("%8u", $users);
			$statsSave->createStatDaily("${op}_ipids", $uniq, { skid => $skid});
			$statsSave->createStatDaily("${op}_bytes", $bytes, { skid => $skid});
			$statsSave->createStatDaily("${op}_page", $pages, { skid => $skid});
			$statsSave->createStatDaily("${op}_user", $users, { skid => $skid});

			if ($op eq "article") {
				my $avg = $stats->getAverageHitsPerStoryOnDay($yesterday, $pages, { skid => $skid });
				$statsSave->createStatDaily("avg_hits_per_story", $avg, { skid => $skid });
			}
		}
		#Other not recorded
		{
			
			my $uniq = $other_section_summary_stats->{$skid}{cnt}		|| 0;
			my $pages = $other_section_summary_stats->{$skid}{pages}	|| 0;
			my $bytes = $other_section_summary_stats->{$skid}{bytes}	|| 0;
			my $uids = $other_section_summary_stats->{$skid}{uids}		|| 0;
			my $op = 'other';
			$temp->{$op}{ipids} = sprintf("%8u", $uniq);
			$temp->{$op}{bytes} = sprintf("%8.1f MB",$bytes/(1024*1024));
			$temp->{$op}{pages} = sprintf("%8u", $pages);
			$temp->{$op}{users} = sprintf("%8u", $users);
			$statsSave->createStatDaily("${op}_ipids", $uniq, { skid => $skid});
			$statsSave->createStatDaily("${op}_bytes", $bytes, { skid => $skid});
			$statsSave->createStatDaily("${op}_page", $pages, { skid => $skid});
			$statsSave->createStatDaily("${op}_user", $uids, { skid => $skid});
		}

		$statsSave->createStatDaily( "page_from_rss", $stats_from_rss->{$skid}{cnt}, {skid => $skid});
		$statsSave->createStatDaily( "uid_from_rss", $stats_from_rss->{$skid}{uids}, {skid => $skid});
		$statsSave->createStatDaily( "ipid_from_rss", $stats_from_rss->{$skid}{ipids}, {skid => $skid});
		$temp->{page_from_rss} = sprintf("%8u", $stats_from_rss->{$skid}{cnt} || 0);
		$temp->{uid_from_rss} = sprintf("%8u", $stats_from_rss->{$skid}{uids} || 0);
		$temp->{ipid_from_rss} = sprintf("%8u", $stats_from_rss->{$skid}{ipids} || 0);

		push(@{$data{skins}}, $temp);
	}

	slashdLog("Sectional Stats End");

	slashdLog("Story Comment Counts Begin");
	foreach my $d (@$cc_days) {
		my $avg_comments = $stats->getAverageCommentCountPerStoryOnDay($d) || 0;
		$statsSave->createStatDaily("avg_comments_per_story", $avg_comments, 
						{ overwrite => 1, day => $d });

		my $stories = $stats->getStoryHitsForDay($d);
		my %topic_hits;
		foreach my $st (@$stories) {
			my $topics = $slashdb->getStoryTopics($st->{sid}, 2);
			foreach my $tid (keys %$topics){
				next unless $tid && $topics->{$tid};
				my $key = $tid . '_' . $topics->{$tid};
				$topic_hits{$key} += ($st->{hits} || 0);
			}
		}
		foreach my $key (keys %topic_hits){
			$statsSave->createStatDaily("topichits_$key", $topic_hits{$key}, { overwrite => 1, day => $d });
		}

	}
	
	foreach my $day (@ah_days){
		my $avg = $stats->getStat("avg_comments_per_story", $day, 0) || 0;
		push @{$data{avg_comments_per_story}}, sprintf("%12.1f", $avg);
	}
	slashdLog("Story Comment Counts End");

	slashdLog("Byte Counts Begin");
	my $total_bytes = $logdb->countBytesByPage('', {
		no_op => $constants->{op_exclude_from_countdaily}
	} );
	my $grand_total_bytes = $logdb->countBytesByPage('');
	$grand_total_bytes += $logdb->countBytesByPage('', { table_suffix => "_rss" }) || 0;
	slashdLog("Byte Counts End");

	slashdLog("Mod Info Begin");
	my $admin_mods = $stats->getAdminModsInfo();
	my $admin_mods_text = getAdminModsText($admin_mods);
	$mod_data{repeat_mods} = $stats->getRepeatMods({
		min_count => $constants->{mod_stats_min_repeat},
		lookback_days => $constants->{mod_stats_repeat_lookback},
	});
	$mod_data{reverse_mods} = $stats->getReverseMods();
	slashdLog("Mod Info End");

	slashdLog("Duration Stats Begin");
	my $static_op_hour = $logdb->getDurationByStaticOpHour({});
	for my $is_static (keys %$static_op_hour) {
		for my $op (keys %{$static_op_hour->{$is_static}}) {
			for my $hour (keys %{$static_op_hour->{$is_static}{$op}}) {
				my $prefix = "duration_";
				$prefix .= $is_static eq 'yes' ? 'st_' : 'dy_';
				$prefix .= sprintf("%s_%02d_", $op, $hour);
				my $this_hr = $static_op_hour->{$is_static}{$op}{$hour};
				my @dur_keys =
					grep /^dur_(mean|stddev|ile_\d+)$/,
					keys %$this_hr;
				for my $dur_key (@dur_keys) {
					my($statname) = $dur_key =~ /^dur_(.+)/;
					$statname = "$prefix$statname";
					my $value = $this_hr->{$dur_key};
					$statsSave->createStatDaily($statname, $value);
				}
			}
		}
	}

	my $static_localaddr = $logdb->getDurationByStaticLocaladdr();
	for my $is_static (keys %$static_localaddr) {
		for my $localaddr (keys %{$static_localaddr->{$is_static}}) {
			my $prefix = "duration_";
			$prefix .= $is_static eq 'yes' ? 'st_' : 'dy_';
			$prefix .= "${localaddr}_";
			$prefix =~ s/\W+/_/g; # change "."s in localaddr into "_"s
			my $this_hr = $static_localaddr->{$is_static}{$localaddr};
			my @dur_keys =
				grep /^dur_(mean|stddev|ile_\d+)$/,
				keys %$this_hr;
			for my $dur_key (@dur_keys) {
				my($statname) = $dur_key =~ /^dur_(.+)/;
				$statname = "$prefix$statname";
				my $value = $this_hr->{$dur_key};
				$statsSave->createStatDaily($statname, $value);
			}
		}
	}
	slashdLog("Duration Stats End");

	$statsSave->createStatDaily("total", $daily_total);
	$statsSave->createStatDaily("anon_total", $anon_daily_total);
	$statsSave->createStatDaily("logged_in_total", $logged_in_daily_total);
	$statsSave->createStatDaily("total_static", $total_static);
	$statsSave->createStatDaily("total_subscriber", $total_subscriber);
	$statsSave->createStatDaily("total_secure", $total_secure);
	$statsSave->createStatDaily("grand_total", $grand_total);
	$statsSave->createStatDaily("grand_total_static", $grand_total_static);
	$statsSave->createStatDaily("total_bytes", $total_bytes);
	$statsSave->createStatDaily("grand_total_bytes", $grand_total_bytes);
	$statsSave->createStatDaily("unique", $unique_ips);
	$statsSave->createStatDaily("anon_unique", $anon_ips);
	$statsSave->createStatDaily("logged_in_unique", $logged_in_ips);
	$statsSave->createStatDaily("unique_users", $unique_users);
	$statsSave->createStatDaily("users_subscriber", $unique_users_subscriber);
	$statsSave->createStatDaily("comments", $comments);
	$statsSave->createStatDaily("homepage", $homepage);
	$statsSave->createStatDaily("distinct_comment_ipids", scalar(@$distinct_comment_ipids));
	$statsSave->createStatDaily("distinct_comment_ipids_anononly", $distinct_comment_ipids_anononly);
	$statsSave->createStatDaily("distinct_comment_ipids_loggedinonly", $distinct_comment_ipids_loggedinonly);
	$statsSave->createStatDaily("distinct_comment_ipids_anonandloggedin", $distinct_comment_ipids_anonandloggedin);
	$statsSave->createStatDaily("comments_ipids_anononly", $comments_ipids_anononly);
	$statsSave->createStatDaily("comments_ipids_loggedinonly", $comments_ipids_loggedinonly);
	$statsSave->createStatDaily("comments_ipids_anonandloggedin", $comments_ipids_anonandloggedin);
# See comment for countCommentsFromProxyAnon.
#	$statsSave->createStatDaily("comments_proxyanon", $comments_proxyanon);
	$statsSave->createStatDaily("distinct_comment_posters_uids", $distinct_comment_posters_uids);
	for my $type (sort keys %$comments_discussiontype_hr) {
		$statsSave->createStatDaily("comments_discussiontype_$type", $comments_discussiontype_hr->{$type});
	}
	$statsSave->createStatDaily("consensus", $consensus);
	$statsSave->createStatDaily("modlogs", $modlogs);
	$statsSave->createStatDaily("modlog_inactive_percent", $modlog_inactive_percent);
	$statsSave->createStatDaily("modlog_yest", $modlogs_yest);
	$statsSave->createStatDaily("modlog_inactive_percent_yest", $modlog_inactive_percent_yest);
	$statsSave->createStatDaily("mod_used_total_pool", ($mod_points_pool ? $modlog_spent_yest_total*100/$mod_points_pool : 0));
	$statsSave->createStatDaily("mod_used_total_comments", ($comments ? $modlog_count_yest_total*100/$comments : 0));
	$statsSave->createStatDaily("mod_points_pool", $mod_points_pool);
	$statsSave->createStatDaily("mod_tokens_pool_pos", $mod_tokens_pool_pos);
	$statsSave->createStatDaily("mod_tokens_pool_neg", $mod_tokens_pool_neg);
	$statsSave->createStatDaily("mod_points_lost_spent", $modlog_spent_yest_total);
	$statsSave->createStatDaily("mod_points_lost_spent_plus_1", $modlog_yest_hr->{+1}{spent});
	$statsSave->createStatDaily("mod_points_lost_spent_minus_1", $modlog_yest_hr->{-1}{spent});
	$statsSave->createStatDaily("mod_points_lost_spent_plus_1_percent", ($modlog_count_yest_total ? $modlog_yest_hr->{1}{count}*100/$modlog_count_yest_total : 0));
	$statsSave->createStatDaily("mod_points_lost_spent_minus_1_percent", ($modlog_count_yest_total ? $modlog_yest_hr->{-1}{count}*100/$modlog_count_yest_total : 0));
	$statsSave->createStatDaily("mod_points_avg_spent", $modlog_count_yest_total ? sprintf("%12.3f", $modlog_spent_yest_total/$modlog_count_yest_total) : "(n/a)");
	if ($constants->{m2}) {
		$statsSave->createStatDaily("metamodlogs", $metamodlogs);
		$statsSave->createStatDaily("xmodlog", $modlogs_needmeta ? $metamodlogs/$modlogs_needmeta : 0);
		$statsSave->createStatDaily("metamodlog_inactive_percent", $metamodlog_inactive_percent);
		for my $m2c_hr (@$unm2dmods) {
			$statsSave->createStatDaily("modlog_m2count_$m2c_hr->{m2count}", $m2c_hr->{cnt});
		}
		$statsSave->createStatDaily("metamodlog_yest", $metamodlogs_yest_total);
		$statsSave->createStatDaily("xmodlog_yest", $modlogs_needmeta_yest ? $metamodlogs_yest_total/$modlogs_needmeta_yest : 0);
		$statsSave->createStatDaily("metamodlog_inactive_percent_yest", $metamodlog_inactive_percent_yest);
		$statsSave->createStatDaily("mod_points_needmeta", $modlogs_needmeta_yest);
		$statsSave->createStatDaily("m2_freq", $constants->{m2_freq} || 86400);
		$statsSave->createStatDaily("m2_consensus", $constants->{m2_consensus} || 0);
		$statsSave->createStatDaily("m2_mintokens", $slashdb->getVar("m2_mintokens", "value", 1) || 0);
		$statsSave->createStatDaily("m2_points_lost_spent", $metamodlogs_yest_total);
		$statsSave->createStatDaily("m2_points_lost_spent_fair", $metamodlogs_yest_fair);
		$statsSave->createStatDaily("m2_points_lost_spent_unfair", $metamodlogs_yest_unfair);
		$statsSave->createStatDaily("oldest_unm2d", $oldest_unm2d);
		$statsSave->createStatDaily("oldest_unm2d_days", $oldest_unm2d_days);
	}
	$statsSave->createStatDaily("mod_token_conversion_point", $token_conversion_point);
	$statsSave->createStatDaily("submissions", $submissions);
	$statsSave->createStatDaily("submissions_comments_match", $submissions_comments_match);
	$statsSave->createStatDaily("youngest_modelig_uid", sprintf("%d", $youngest_modelig_uid));
	$statsSave->createStatDaily("youngest_modelig_created", sprintf("%11s", $youngest_modelig_created || 0));

	my $scores = [ $constants->{comment_minscore} .. $constants->{comment_maxscore} ];
	my $scores_hr = $stats->getDailyScoreTotals($scores);
	for my $i (sort { $a <=> $b } keys %$scores_hr) {
		$statsSave->createStatDaily("comments_score_$i", $scores_hr->{$i}{c});
	}

	for my $nickname (keys %$admin_mods) {
		my $uid = $admin_mods->{$nickname}{uid};
		# Each stat writes one row into stats_daily for each admin who
		# modded anything, which is a lot of rows, but we want all the
		# data.
		my @stat_types = qw( m1_up m1_down );
		push @stat_types, qw( m2_fair m2_unfair ) if $constants->{m2};
		for my $stat (@stat_types) {
			my $suffix = $uid
				? "_admin_$uid"
				: "_total";
			my $val = $admin_mods->{$nickname}{$stat};
			$statsSave->createStatDaily("$stat$suffix", $val);
		}
	}

	my $al2_counts = $stats->getAL2Counts();
	for my $key (keys %$al2_counts) {
		$statsSave->createStatDaily("al2count_$key", $al2_counts->{$key});
	}
	
	foreach my $day (@ah_days){
		my $avg = $stats->getStat("avg_hits_per_story", $day, 0) || 0;
		push @{$data{avg_hits_per_story}}, sprintf("%12.1f", $avg);
	}

	$data{total} = sprintf("%8u", $daily_total || 0);
	$data{total_bytes} = sprintf("%0.1f MB", ($total_bytes || 0)/(1024*1024));
	$data{grand_total_bytes} = sprintf("%0.1f MB", ($grand_total_bytes || 0)/(1024*1024));
	$data{total_subscriber} = sprintf("%8u", $total_subscriber);
	$data{total_secure} = sprintf("%8u", $total_secure);
	$data{unique} = sprintf("%8u", $unique_ips), 
	$data{users} = sprintf("%8u", $unique_users);
	$data{formkeys} = sprintf("%8u", $formkeys_rows);
	$data{error_count} = sprintf("%8u", $data{error_count});
	$data{not_found} = sprintf("%8u", $data{not_found});
	$data{status_202} = sprintf("%8u", $data{status_202});

	$mod_data{comments} = sprintf("%8u", $comments);
	$mod_data{modlog} = sprintf("%8u", $modlogs);
	$mod_data{modlog_inactive_percent} = sprintf("%.1f", $modlog_inactive_percent);
	$mod_data{modlog_yest} = sprintf("%8u", $modlogs_yest);
	$mod_data{modlog_inactive_percent_yest} = sprintf("%.1f", $modlog_inactive_percent_yest);
	if ($constants->{m2}) {
		$mod_data{metamodlog} = sprintf("%8u", $metamodlogs);
		$mod_data{metamodlog_inactive_percent} = sprintf("%.1f", $metamodlog_inactive_percent);
		$mod_data{metamodlog_yest} = sprintf("%8u", $metamodlogs_yest_total);
		$mod_data{metamodlog_inactive_percent_yest} = sprintf("%.1f", $metamodlog_inactive_percent_yest);
		$mod_data{xmodlog} = sprintf("%.1fx", ($modlogs_needmeta ? $metamodlogs/$modlogs_needmeta : 0));
		$mod_data{xmodlog_yest} = sprintf("%.1fx", ($modlogs_needmeta_yest ? $metamodlogs_yest_total/$modlogs_needmeta_yest : 0));
		$mod_data{consensus} = sprintf("%8u", $consensus);
		$mod_data{oldest_unm2d_days} = $oldest_unm2d_days;
	}
	$mod_data{youngest_modelig_uid} = sprintf("%d", $youngest_modelig_uid);
	$mod_data{youngest_modelig_created} = sprintf("%11s", $youngest_modelig_created || 0);
	$mod_data{mod_points_pool} = sprintf("%8u", $mod_points_pool);
	$mod_data{used_total} = sprintf("%8u", $modlog_count_yest_total);
	$mod_data{used_total_pool} = sprintf("%.1f", ($mod_points_pool ? $modlog_spent_yest_total*100/$mod_points_pool : 0));
	$mod_data{used_total_comments} = sprintf("%.1f", ($comments ? $modlog_count_yest_total*100/$comments : 0));
	$mod_data{used_minus_1} = sprintf("%8u", $modlog_yest_hr->{-1}{count} || 0);
	$mod_data{used_minus_1_percent} = sprintf("%.1f", ($modlog_count_yest_total ? ($modlog_yest_hr->{-1}{count}*100/$modlog_count_yest_total || 0) : 0) );
	$mod_data{used_plus_1} = sprintf("%8u", $modlog_yest_hr->{1}{count} || 0);
	$mod_data{used_plus_1_percent} = sprintf("%.1f", ($modlog_count_yest_total ? ($modlog_yest_hr->{1}{count}*100/$modlog_count_yest_total || 0) : 0));
	$mod_data{mod_points_avg_spent} = $modlog_count_yest_total ? sprintf("%12.3f", $modlog_spent_yest_total/$modlog_count_yest_total || 0) : "(n/a)";
	$mod_data{day} = $yesterday;
	$mod_data{token_conversion_point} = sprintf("%8d", $token_conversion_point || 0);
	$mod_data{m2_text} = $m2_text;

	$data{comments} = $mod_data{comments};
	$data{IPIDS} = sprintf("%8u", scalar(@$distinct_comment_ipids));
	$data{submissions} = sprintf("%8u", $submissions);
	$data{sub_comments} = sprintf("%8.1f", ($submissions ? $submissions_comments_match*100/$submissions : 0));
	$data{total_hits} = sprintf("%8u", $sdTotalHits);

	$statsSave->createStatDaily("sub_comments", $data{sub_comments});
	$statsSave->createStatDaily("total_hits", $sdTotalHits);
	$slashdb->setVar("totalhits", $sdTotalHits);

	$data{homepage} = sprintf("%8u", $homepage);
	$data{day} = $yesterday ;
	$data{distinct_comment_posters_uids} = sprintf("%8u", $distinct_comment_posters_uids);

	my $stories_article = $logdb->countDailyStoriesAccessArticle();
	my @top_articles =
		grep { $stories_article->{$_} >= 100 }
		sort { ($stories_article->{$b} || 0) <=> ($stories_article->{$a} || 0) }
		keys %$stories_article;
	$#top_articles = 24 if $#top_articles > 24; # only list top 25 stories
	my @lazy_article = ( );
	my %nick = ( );
	for my $sid (@top_articles) {
		my $hitcount = $stories_article->{$sid};
 		my $story = $reader->getStory($sid, [qw( title uid )]);
		next unless $story->{title} && $story->{uid};
		$nick{$story->{uid}} ||= $reader->getUser($story->{uid}, 'nickname')
			|| $story->{uid};

		push @lazy_article, sprintf( "%6d %-16s %-10s %-30s",
			$hitcount, $sid, $nick{$story->{uid}},
			substr($story->{title}, 0, 30),
		);
	}
	$data{lazy_article} = \@lazy_article; 

	my $stories_rss = $logdb->countDailyStoriesAccessRSS;
	my @top_rsses =
		grep { $stories_rss->{$_} >= 100 }
		sort { ($stories_rss->{$b} || 0) <=> ($stories_rss->{$a} || 0) }
		keys %$stories_rss;
	$#top_rsses = 24 if $#top_rsses > 24; # only list top 25 stories
	my @lazy_rss = ( );
	for my $sid (@top_rsses) {
		my $hitcount = $stories_rss->{$sid};
 		my $story = $reader->getStory($sid, [qw( title uid )]);
		next unless $story->{title} && $story->{uid};
		$nick{$story->{uid}} ||= $reader->getUser($story->{uid}, 'nickname')
			|| $story->{uid};

		push @lazy_rss, sprintf( "%6d %-16s %-10s %-30s",
			$hitcount, $sid, $nick{$story->{uid}},
			substr($story->{title}, 0, 30),
		);
	}
	$data{lazy_rss} = \@lazy_rss; 

	$mod_data{data} = \%mod_data;
	$mod_data{admin_mods_text} = $admin_mods_text;
	
	$data{data} = \%data;
	$data{admin_clearpass_warning} = $admin_clearpass_warning;
	$data{tailslash} = $logdb->getTailslash();

	slashdLog("Random Stats Begin");
	$data{backup_lag} = ""; # old, no longer used

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

	$data{top_referers} = $logdb->getTopReferers({count => 20});
	$data{top_badgehosts} = $logdb->getTopBadgeHosts({count => 20});
	$data{top_badgeurls} = $logdb->getTopBadgeURLs({count => 20});
	for my $host_duple (@{ $data{top_badgehosts} }) {
		my($host, $count) = @$host_duple;
		$host =~ s/\W+/_/g;
		$statsSave->createStatDaily("badgehost_$host", $count);
	}

	$data{bookmarks} = $stats->getNumBookmarks();
	$statsSave->createStatDaily("bookmarks", $data{bookmarks});

	my $new_users_yest = $slashdb->getNumNewUsersSinceDaysback(1)
		- $slashdb->getNumNewUsersSinceDaysback(0);
	$statsSave->createStatDaily('users_created', $new_users_yest);
	$data{new_users_yest} = $new_users_yest;
	$data{rand_users_yest} = $slashdb->getRandUsersCreatedYest(10, $yesterday);
	($data{top_recent_domains}, $data{top_recent_domains_daysback}, $data{top_recent_domains_newaccounts}, $data{top_recent_domains_newnicks}) = $slashdb->getTopRecentRealemailDomains($yesterday);

	my $subscribe = getObject('Slash::Subscribe') if $constants->{plugin}{Subscribe};

	if ($subscribe) {
		my $rswh =   $stats->getSubscribersWithRecentHits();
		my $sub_cr = $logdb->getSubscriberCrawlers($rswh);
		my $sub_report;
		foreach my $sub (@$sub_cr){
			$sub_report .= sprintf("%6d %s\n", $sub->{cnt}, ($slashdb->getUser($sub->{uid}, 'nickname') || $sub->{uid})); 
	 	}
		$data{crawling_subscribers} = $sub_report if $sub_report; 
	}

	my $email = slashDisplay('display', \%data, {
		Return => 1, Page => 'adminmail', Nocomm => 1
	});

	my $mod_email = slashDisplay('display', \%mod_data, {
		Return => 1, Page => 'modmail', Nocomm => 1
	}) if $constants->{mod_stats};

	my $messages = getObject('Slash::Messages');

	# do message log stuff
	if ($messages) {
		my $msg_log = $messages->getDailyLog( $statsSave->{_day} );
		my %msg_codes;

		# msg_12_1 -> code 12, mode 1 (relationship change, web)
		for my $type (@$msg_log) {
			my($code, $mode, $count) = @$type;
			$msg_codes{$code} += $count;
			$statsSave->createStatDaily("msg_${code}_${mode}", $count);
		}

		for my $code (keys %msg_codes) {
			$statsSave->createStatDaily("msg_${code}", $msg_codes{$code});
		}
	}
	slashdLog("Random Stats End");

	# Send a message to the site admin.
	if ($messages) {
		$data{template_name} = 'display';
		$data{subject} = getData('email subject', {
			day =>	$data{day}
		}, 'adminmail');
		$data{template_page} = 'adminmail';
		my $message_users = $messages->getMessageUsers(MSG_CODE_ADMINMAIL);
		$messages->create($message_users, MSG_CODE_ADMINMAIL, \%data) if @$message_users;

		if ($constants->{mod_stats}) {
			$mod_data{template_name} = 'display';
			$mod_data{subject} = getData('modmail subject', {
				day => $mod_data{day}
			}, 'adminmail');
			$mod_data{template_page} = 'modmail';
			my $mod_message_users = $messages->getMessageUsers(MSG_CODE_MODSTATS);
			$messages->create($mod_message_users, MSG_CODE_MODSTATS, \%mod_data) if @$mod_message_users;
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
	slashdLog("Send Admin Mail End for $yesterday");

	# for stats.pl to know ...
	$slashdb->setVar('adminmail_last_run', $yesterday);

	return ;
};

sub getM2Text {
	my($mmr, $options) = @_;

	my $constants = getCurrentStatic();
	return '' if $constants->{m1_pluginname} eq 'TagModeration';

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

	my $text = sprintf("%-13s   %4s %4s %5s\n",
		"Nickname",
		"M1up", "M1dn", "M1up%"
	);
	my($num_admin_mods, $num_mods) = (0, 0);
	for my $nickname (sort { lc($a) cmp lc($b) } keys %$am) {
		my $amn = $am->{$nickname};
		my $m1_up_percent = 0;
		$m1_up_percent = $amn->{m1_up}*100
			/ ( ($amn->{m1_up} || 0) + ($amn->{m1_down} || 0) )
			if ($amn->{m1_up} || 0) + ($amn->{m1_down} || 0) > 0;
		next unless $amn->{m1_up} || $amn->{m1_down}
			|| $amn->{m2_fair} || $amn->{m2_unfair};
		$text .= sprintf("%13.13s   %4d %4d %4d%%\n",
			$nickname,
			$amn->{m1_up}		|| 0,
			$amn->{m1_down}		|| 0,
			$m1_up_percent		|| 0,
		);
		if ($nickname eq '~Day Total') {
			$num_mods += $amn->{m1_up} || 0;
			$num_mods += $amn->{m1_down} || 0;
		} else {
			$num_admin_mods += $amn->{m1_up} || 0;
			$num_admin_mods += $amn->{m1_down} || 0;
		}
	}
	$text .= sprintf("%d of %d mods (%.2f%%) were performed by admins.\n",
		$num_admin_mods,
		$num_mods,
		($num_mods ? $num_admin_mods*100/$num_mods : 0));
	return $text;
}

1;

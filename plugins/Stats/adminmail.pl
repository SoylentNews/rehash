#!/usr/bin/perl -w

use strict;
use Slash::Constants ':messages';
use Slash::Display;

use vars qw( %task $me );

# Remember that timespec goes by the database's time, which should be
# GMT if you installed everything correctly.  So 6:07 AM GMT is a good
# sort of midnightish time for the Western Hemisphere.  Adjust for
# your audience and admins.
$task{$me}{timespec} = '7 6 * * *';
$task{$me}{timespec_panic_2} = ''; # if major panic, dailyStuff can wait
$task{$me}{'fork'} = 1;			# If allowed, fork this task from 
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;
	my($stats, $backupdb);

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

	my $sdTotalHits = $stats->getVar('totalhits', 'value');
	$sdTotalHits = $sdTotalHits + $count->{'total'};

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

	my $accesslog_rows = $stats->sqlCount('accesslog');
	my $formkeys_rows = $stats->sqlCount('formkeys');
	my $modlog_rows = $stats->sqlCount('moderatorlog');
	my $metamodlog_rows = $stats->sqlCount('metamodlog');

	my $mod_points = $stats->getPoints;
	my @yesttime = localtime(time-86400);
	my @weekagotime = localtime(time-86400*7);
	my $yesterday = sprintf "%4d-%02d-%02d", 
		$yesttime[5] + 1900, $yesttime[4] + 1, $yesttime[3];
	my $weekago = sprintf "%4d-%02d-%02d", 
		$weekagotime[5] + 1900, $weekagotime[4] + 1, $weekagotime[3];
	my $used = $stats->countModeratorLog($yesterday);
	my $modlog_hr = $stats->countModeratorLogHour($yesterday);
	my $distinct_comment_ipids = $stats->getCommentsByDistinctIPID($yesterday);
	my $submissions = $stats->countSubmissionsByDay($yesterday);
	my $submissions_comments_match = $stats->countSubmissionsByCommentIPID($yesterday, $distinct_comment_ipids);
	my $modlog_total = $modlog_hr->{1}{count} + $modlog_hr->{-1}{count};

	my $comments = $stats->countCommentsDaily($yesterday);

#	for(qw| article search comments palm journal rss|) {
#	}
	my $uniq_comment_users = $stats->countDailyByPageDistinctIPID('comments', $yesterday);
	my $comment_page_views = $stats->countDailyByPage('comments',$yesterday);
	my $comment_bytes = $stats->countBytesByPage('comments',$yesterday);

	my $uniq_article_users = $stats->countDailyByPageDistinctIPID('article', $yesterday);
	my $article_page_views = $stats->countDailyByPage('article',$yesterday);
	my $article_bytes = $stats->countBytesByPage('article',$yesterday);

	my $uniq_search_users = $stats->countDailyByPageDistinctIPID('search', $yesterday);
	my $search_page_views = $stats->countDailyByPage('search',$yesterday);
	my $search_bytes = $stats->countBytesByPage('search',$yesterday);

	my $uniq_palm_users = $stats->countDailyByPageDistinctIPID('palm', $yesterday);
	my $palm_page_views = $stats->countDailyByPage('palm',$yesterday);
	my $palm_bytes = $stats->countBytesByPage('palm',$yesterday);

	my $uniq_journal_users = $stats->countDailyByPageDistinctIPID('journal', $yesterday);
	my $journal_page_views = $stats->countDailyByPage('journal',$yesterday);
	my $journal_bytes = $stats->countBytesByPage('journal',$yesterday);

	my $uniq_rss_users = $stats->countDailyByPageDistinctIPID('rss', $yesterday);
	my $rss_page_views = $stats->countDailyByPage('rss',$yesterday);
	my $rss_bytes = $stats->countBytesByPage('rss',$yesterday);

	my $total_bytes = $stats->countBytesByPage('',$yesterday);

	my $admin_mods = $stats->getAdminModsInfo($yesterday, $weekago);
	my $admin_mods_text = "";
	my($num_admin_mods, $num_mods) = (0, 0);
	if ($admin_mods) {
		for my $nickname (sort { lc($a) cmp lc($b) } keys %$admin_mods) {
			$admin_mods_text .= sprintf("%13.13s: %26s %-46s\n",
				$nickname,
				$admin_mods->{$nickname}{m1_text},
				$admin_mods->{$nickname}{m2_text}
			);
			if ($nickname eq '~Day Total') {
				$num_mods += $admin_mods->{$nickname}{m1_up};
				$num_mods += $admin_mods->{$nickname}{m1_down};
			} else {
				$num_admin_mods += $admin_mods->{$nickname}{m1_up};
				$num_admin_mods += $admin_mods->{$nickname}{m1_down};
			}
		}
		$admin_mods_text =~ s/ +$//gm;
		$admin_mods_text .= sprintf("%13.13s: %4d of %4d (%6.2f%%)\n",
			"Admin Mods", $num_admin_mods, $num_mods,
			($num_mods ? $num_admin_mods*100/$num_mods : 0));
	}

	$statsSave->createStatDaily($yesterday, "total", $count->{total});
	$statsSave->createStatDaily($yesterday, "total_bytes", $total_bytes);
	$statsSave->createStatDaily($yesterday, "unique", $count->{unique});
	$statsSave->createStatDaily($yesterday, "unique_users", $count->{unique_users});
	$statsSave->createStatDaily($yesterday, "comments", $comments);
	$statsSave->createStatDaily($yesterday, "homepage", $count->{index}{index});
	$statsSave->createStatDaily($yesterday, "distinct_comment_ipids", $distinct_comment_ipids);

	$statsSave->createStatDaily($yesterday, "uniq_comment_users", $uniq_comment_users);
	$statsSave->createStatDaily($yesterday, "comment_page_views", $comment_page_views);
	$statsSave->createStatDaily($yesterday, "comment_bytes", $comment_bytes);

	$statsSave->createStatDaily($yesterday, "uniq_article_users", $uniq_article_users);
	$statsSave->createStatDaily($yesterday, "article_page_views", $article_page_views);
	$statsSave->createStatDaily($yesterday, "article_bytes", $article_bytes);

	$statsSave->createStatDaily($yesterday, "uniq_search_users", $uniq_search_users);
	$statsSave->createStatDaily($yesterday, "search_page_views", $search_page_views);
	$statsSave->createStatDaily($yesterday, "search_bytes", $search_bytes);

	$statsSave->createStatDaily($yesterday, "uniq_palm_users", $uniq_palm_users);
	$statsSave->createStatDaily($yesterday, "palm_page_views", $palm_page_views);
	$statsSave->createStatDaily($yesterday, "palm_bytes", $palm_bytes);

	$statsSave->createStatDaily($yesterday, "uniq_journal_users", $uniq_journal_users);
	$statsSave->createStatDaily($yesterday, "journal_page_views", $journal_page_views);
	$statsSave->createStatDaily($yesterday, "journal_bytes", $journal_bytes);

	$statsSave->createStatDaily($yesterday, "uniq_rss_users", $uniq_rss_users);
	$statsSave->createStatDaily($yesterday, "rss_page_views", $rss_page_views);
	$statsSave->createStatDaily($yesterday, "rss_bytes", $rss_bytes);

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
	my %data = (
		total => sprintf("%8d", $count->{total}),
		total_bytes => sprintf("%0.1f MB",$total_bytes/(1024*1024)),
		unique => sprintf("%8d", $count->{unique}), 
		users => sprintf("%8d", $count->{unique_users}),
		accesslog => sprintf("%8d", $accesslog_rows),
		formkeys => sprintf("%8d", $formkeys_rows),
		modlog => sprintf("%8d", $modlog_rows),
		metamodlog => sprintf("%8d", $metamodlog_rows),
		xmodlog	=> sprintf("%.1fx", ($modlog_rows  ? $metamodlog_rows/$modlog_rows  : 0)),
		mod_points => sprintf("%8d", $mod_points),
		used_total => sprintf("%8d", $modlog_total),
		used_total_pool => sprintf("%.1f", ($mod_points ? $modlog_total*100/$mod_points : 0)),
		used_total_comments => sprintf("%.1f", ($comments ? $modlog_total*100/$comments : 0)),
		used_minus_1 => sprintf("%8d", $modlog_hr->{-1}{count}),
		used_minus_1_percent => sprintf("%.1f", ($modlog_total ? $modlog_hr->{-1}{count}*100/$modlog_total : 0) ),
		used_plus_1 => sprintf("%8d", $modlog_hr->{1}{count}),
		used_plus_1_percent => sprintf("%.1f", ($modlog_total ? $modlog_hr->{1}{count}*100/$modlog_total : 0)),
		comments => sprintf("%8d", $comments),
		IPIDS => sprintf("%8d", scalar(@$distinct_comment_ipids)),
		comments_ipids => sprintf("%8d", $uniq_comment_users),
		articles_ipids => sprintf("%8d", $uniq_article_users),
		search_ipids => sprintf("%8d", $uniq_search_users),
		journals_ipids => sprintf("%8d", $uniq_journal_users),
		palm_ipids => sprintf("%8d", $palm_page_views),
		rss_ipids => sprintf("%8d", $rss_page_views),
		comments_page => sprintf("%8d", $comment_page_views ),
		articles_page => sprintf("%8d", $article_page_views ),
		search_page => sprintf("%8d", $search_page_views ),
		journals_page => sprintf("%8d", $journal_page_views),

		palm_bytes => sprintf("%0.1f MB",$palm_bytes/(1024*1024)),
		rss_bytes => sprintf("%0.1f MB",$rss_bytes/(1024*1024)),
		comment_bytes => sprintf("%0.1f MB",$comment_bytes/(1024*1024) ),
		article_bytes => sprintf("%0.1f MB",$article_bytes/(1024*1024) ),
		search_bytes => sprintf("%0.1f MB",$search_bytes/(1024*1024) ),
		journal_bytes => sprintf("%0.1f MB",$journal_bytes/(1024*1024)),
		
		palm_page => sprintf("%8d", $palm_page_views),
		rss_page => sprintf("%8d", $rss_page_views),
		submissions => sprintf("%8d", $submissions),
		sub_comments => sprintf("%8.1f", ($submissions ? $submissions_comments_match*100/$submissions : 0)),
		total_hits => sprintf("%8d", $sdTotalHits),
		homepage => sprintf("%8d", $count->{index}{index}),
		day => $yesterday,
	);

	my @sections;
	for (sort {lc($a) cmp lc($b)} keys %{$count->{index}}) {
		push(@sections, { key => $_, value => $count->{index}{$_} });
		$statsSave->createStatDaily($yesterday, "index_$_", $count->{index}{$_});
	}

	my @lazy;
	for my $key (sort { $count->{'articles'}{$b} <=> $count->{'articles'}{$a} } keys %{$count->{'articles'}}) {
		my $value = $count->{'articles'}{$key};

 		my $story = $backupdb->getStory($key, ['title', 'uid']);

		push(@lazy, sprintf("%6d %-16s %-30s by %s",
			$value, $key, substr($story->{'title'}, 0, 30),
			($slashdb->getUser($story->{uid}, 'nickname') || $story->{uid})
		)) if $story->{'title'} && $story->{uid} && $value > 100;
	}

	$data{data} = \%data;
	$data{sections} = \@sections; 
	$data{lazy} = \@lazy; 
	$data{admin_clearpass_warning} = $admin_clearpass_warning;
	$data{admin_mods_text} = $admin_mods_text;
	$data{tailslash} = `$constants->{slashdir}/bin/tailslash -u $virtual_user -y today`;

	my $email = slashDisplay('display', \%data, { Return => 1, Page => 'adminmail', Nocomm => 1 });

	# Send a message to the site admin.
	my $messages = getObject('Slash::Messages');
	if ($messages) {
		my $message_users = $messages->getMessageUsers(MSG_CODE_ADMINMAIL);
		$data{template_name} = 'display';
		$data{subject} = { template_name => 'subj' };
		$data{template_page} = 'adminmail';
		for (@$message_users) {
			$messages->create($_, MSG_CODE_ADMINMAIL, \%data);
		}
	}
	for (@{$constants->{stats_reports}}) {
		sendEmail($_, "$constants->{sitename} Stats Report", $email, 'bulk');
	}
	slashdLog('Send Admin Mail End');

	return ;
};

1;


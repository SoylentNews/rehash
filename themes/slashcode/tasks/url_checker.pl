#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$
#
# This task checks urls to see if they're still alive, and sets their
# validated titles
#
use Slash::Constants ':slashd';
use LWP::UserAgent;
use Encode 'encode_utf8';
use HTML::HeadParser;

use strict;

use vars qw( %task $me $task_exit_flag );

$task{$me}{timespec} = '0-59/2 * * * *';
$task{$me}{timespec_panic_1} = '1-59/10 * * * *';
$task{$me}{timespec_panic_2} = '';
$task{$me}{on_startup} = 1;
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;

	my $start_time = time();
	my $timeout = 60;

	my $ua = LWP::UserAgent->new;
	$ua->agent($constants->{url_checker_user_agent}) if $constants->{url_checker_user_agent};
	$ua->timeout(30);

	my $urls = $slashdb->getUrlsNeedingFirstCheck();

	my $refresh_urls = $slashdb->getUrlsNeedingRefresh();

	URL_CHECK: for my $url (@$urls, @$refresh_urls) {
		
		# Don't run forever...
		if (time > $start_time + $timeout) {
			slashdLog("Aborting checking urls, too much elapsed time");
			last URL_CHECK;
		}
		if ($task_exit_flag) {
			slashdLog("Aborting url_checker, got SIGUSR1");
			last URL_CHECK;
		}
		

		my $url_update = { url_id => $url->{url_id} };
	
		my $response = $ua->get($url->{url});
		#slashdLog("getting $url->{url}");	
		if ($response->is_success) {
			#slashdLog("success on $url->{url}");	
			my $content =  $response->content;
			my $hp = HTML::HeadParser->new;
			{
				local $SIG{__WARN__} = sub {
					warn @_ unless $_[0] =~
					/Parsing of undecoded UTF-8 will give garbage when decoding entities/
				};
				$hp->parse(encode_utf8($content));
			}
			my $validatedtitle = $hp->header('Title');
			if (defined $validatedtitle) {
				#slashdLog("vt $validatedtitle");	
				$url_update->{validatedtitle} = strip_notags($validatedtitle);
				$url_update->{"-last_success"} = "NOW()";
				$url_update->{is_success} = 1;
				$url_update->{"-believed_fresh_until"} = "DATE_ADD(NOW(), INTERVAL 2 DAY)";
			}
		} else {
			#slashdLog("failure on $url->{url}");	
			$url_update->{is_success} = 0;
			$url_update->{"-believed_fresh_until"} = "DATE_ADD(NOW(), INTERVAL 30 MINUTE)";
		}

		# If this is a second or greater, we adjust the amount of time between refreshes to slowly increase
		# time between refreshes
		if ($url->{last_attempt}) {
			my $secs = $slashdb->sqlSelect("UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP('$url->{last_attempt}')");
			my $decay = 1.2;
			my $secs_until_next = int($secs * $decay);
			$url_update->{"-believed_fresh_until"} = "DATE_ADD(NOW(), INTERVAL $secs_until_next SECOND)";
		}

		my $status_line = $response->status_line;
		my ($code, $reason) = $status_line =~ /^(\d+)\s+(.*)$/;

		$url_update->{status_code} = $code;
		$url_update->{reason_phrase} = $reason;
		$url_update->{"-last_attempt"} = "NOW()";


		$slashdb->setUrl($url->{url_id}, $url_update);
	}
};

1;

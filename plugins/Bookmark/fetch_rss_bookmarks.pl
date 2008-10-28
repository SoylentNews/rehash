#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::XML;
use Slash::Constants qw(:slashd :strip);
use XML::RSS;
use LWP::UserAgent;

use vars qw( %task $me );

$task{$me}{timespec} = '12,32,52 * * * *';
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;
	
	my $rss = new XML::RSS;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $bookmark_reader = getObject('Slash::Bookmark', { db_type => 'reader' });

	my $feeds = $bookmark_reader->getBookmarkFeeds({ rand_order => 1 });
	my $max_adds_per_run = 10;
	my $adds = 0;

	foreach my $feed (@$feeds) {
		slashdLog("Feed: $feed->{feed}");
		last if $adds >= $max_adds_per_run;
		my $content = geturl($feed->{feed});
		eval { $rss->parse($content); };
		if ($@) {
			slashdLog("error parsing feed from $feed->{feed}");
		} else {
			for my $item (@{$rss->{items}}) {
				last if $adds >= $max_adds_per_run;
				for (keys %{$item}) {
					$item->{$_} = xmldecode($item->{$_});
				}
				
				my $title = strip_notags($item->{title});
				my $link = fudgeurl($item->{link});
                                my $text = $item->{description};
                                $text = strip_mode($text, HTML) unless ($feed->{nofilter});
				my $taglist = $feed->{tags};
				
				my $data = {
					url		=> $link,
					initialtitle	=> $title,
				};
				
				my $url_id = $slashdb->getUrlCreate($data);
				my $bookmark_id;
	
				my $bookmark = getObject("Slash::Bookmark");
				my $bookmark_data = {
					url_id 		=> $url_id,
					uid    		=> $feed->{uid},
					title		=> $title,
				};
				
				my $user_bookmark = $bookmark->getUserBookmarkByUrlId($feed->{uid}, $url_id);
				if (!$user_bookmark) {
					$bookmark_data->{"-createdtime"} = 'NOW()';
					slashdLog("creating feed bookmark $url_id");
					slashdLog("$url_id $link $title");
					slashdLog("after creating bookmark");
					$bookmark_id= $bookmark->createBookmark($bookmark_data);
					if ($constants->{plugin}{FireHose}) {
						my $firehose = getObject("Slash::FireHose");
						my $the_bookmark = $bookmark->getBookmark($bookmark_id);
						$firehose->createUpdateItemFromBookmark($bookmark_id, { type => "feed", introtext => $text });
					}
					
					my $tags = getObject('Slash::Tags');
					slashdLog("$taglist $url_id");
					$tags->setTagsForGlobj($url_id, "urls", $taglist, { uid => $feed->{uid}});
					$adds++;
					sleep 10;
				}
			}
		}
	}
};

sub geturl {
	my($url, $options) = @_;
	my $ua = new LWP::UserAgent;
	my $request = new HTTP::Request('GET', $url);
	my $constants = getCurrentStatic();
	$ua->proxy(http => $constants->{http_proxy}) if $constants->{http_proxy};
	my $timeout = 30;
	$timeout = $options->{timeout} if $options->{timeout};
	$ua->timeout($timeout);
	my $result = $ua->request($request);

	if ($result->is_success) {
		return $result->content;
	} else {
		return "";
	}
}

1;

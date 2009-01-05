#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;

use Time::HiRes;

use Slash;
use Slash::Constants ':slashd';
use Slash::Display;
use Slash::Utility;
use LWP::Simple;
use URI::Split qw(uri_split);
use File::Type;
use File::Temp;

use vars qw(
	%task	$me	$task_exit_flag
);

$task{$me}{timespec} = '0-59/2 * * * *';
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;
	my $fh_last = $slashdb->getVar("firehose_last_thumbnail_id", "value", 1);
	if (!defined($fh_last)) {
		$fh_last = 0;
		$slashdb->createVar("firehose_last_thumbnail_id", 0);
	}
	my $firehose = getObject("Slash::FireHose");
	my $items = $firehose->getNextItemsForThumbnails($fh_last, 10);
	
	foreach (@$items) {
		$fh_last = $_->{id} if $_->{id} > $fh_last;
		my $thumb;
		my ($scheme, $domain, $path, $query, $frag) = uri_split($_->{url});
		my $page = get $_->{url};
		slashdLog("$_->{id}: $_->{url}\n");
		my @pairs = split /&/, ($query || '');
		my $params = {};
		foreach my $pair (@pairs) {
			my ($name, $value) = split(/=/, $pair);
			$params->{$name}= $value;
		}
		if ($page) {
			if ($domain =~ /youtube\.com/ && $params->{v}) {
				$thumb = "http://img.youtube.com/vi/$params->{v}/0.jpg";
			} elsif ($domain =~ /video.google.com/ && $params->{docid}) {
				my $feed = get "http://video.google.com/videofeed?docid=$params->{docid}";
				$feed =~/<media:thumbnail url="([^"]+)"/;
				$thumb = $1;
				$thumb =~ s/amp;//g;
				
			} elsif ($page =~ /link\s+rel="videothumbnail"\s+href="([^"]*)"/) {
				$thumb = $1;
			} elsif ($page =~ /link\s+rel="image_src"\s+href="([^"]*)"/) {
				$thumb = $1;
			}
			
			if ($thumb) {
				slashdLog("Thumb url: $thumb");
				my $ft = File::Type->new();
				my $thumb_data = get $thumb;
				my $mimetype = $ft->mime_type($thumb_data);

				if ($mimetype =~ /^image/) {
					if (length($thumb_data) < 600000 ) {
						my $tmpfile = dataToTmpFile($thumb_data, $thumb);
						my $file = {
							fhid   => $_->{id},
							file   => $tmpfile,
							action => "thumbnails"
						};
						$slashdb->addFileToQueue($file);
					}
				}
			}
		}
	}
	slashdLog("Last id: $fh_last");
	$slashdb->setVar('firehose_last_thumbnail_id', $fh_last);
};

sub dataToTmpFile {
	my($data, $url) = @_;
	my ($suffix) = $url =~ /(\.\w+$)/;
	$suffix = lc($suffix);
	my ($ofh, $tmpname) = mkstemps("/tmp/upload/fileXXXXXX", $suffix );
	print $ofh $data;
	close $ofh;
	return $tmpname;
}

1;


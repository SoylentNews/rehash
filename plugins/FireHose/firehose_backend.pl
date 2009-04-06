#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Digest::MD5;
use Slash;
use Slash::XML;
use Slash::Constants ':slashd';

use vars qw( %task $me
	$minutes_run
	$sectional_freq
);

# Change this var to change how often the task runs.  Sandboxes
# run it every half-hour, other sites every 10 minutes.
$minutes_run = ($ENV{SF_SYSTEM_FUNC} =~ /^slashdot-/ ? 10 : 30);

# Process the non-mainpage skins less often.  Sandboxes run them
# every 5 invocations, other sites every other invocation.
$sectional_freq = ($ENV{SF_SYSTEM_FUNC} =~ /^slashdot-/ ? 2 : 5);

$task{$me}{timespec} = fhbackend_get_start_min($minutes_run) . "-59/$minutes_run * * * *";
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;

	my $firehose_reader = getObject('Slash::FireHose', { db_type => 'reader' });
	my $colors = $firehose_reader->getFireHoseColors(1);

	my $rss = {};

	$rss->{"firehose"} = [ "", "green", "" ];
	$rss->{"firehose_nostories"} = ["Non-Stories", "green",  "-story" ];
	$rss->{"firehose_stories"} = ["Stories", "black", "story", { limit => 25}];
	$rss->{"firehose_recent"} = ["Recent", "indigo", "-story", { limit => 25 }];
	$rss->{"firehose_popular"} = ["Popular", "black", "-story", { orderby => "popularity", limit => 25, duration => 7 }];

	foreach (keys %$rss) {
		gen_firehose_rss($virtual_user, $_, "", $rss->{$_}->[0], $rss->{$_}->[1], $rss->{$_}->[2],$rss->{$_}->[3], "rss");
	}

	my $skins = $slashdb->getSkins();
	for my $skid (keys %$skins) {
		next if $skid != $constants->{mainpage_skid}
			&& $info->{invocation_num} % $sectional_freq != $sectional_freq-1;
		my $skinname = $skins->{$skid}{name};
		foreach (keys %$rss) {
			gen_firehose_rss($virtual_user, "${skinname}_$skid", $skinname,
				$rss->{$skid}[0], $rss->{$skid}[1],
				"$skinname $rss->{$skid}[2]", $rss->{$skid}[3],
				"rss");
		}
	}


};

# A bunch of sandboxes all starting this script at the same time spikes
# resource load every n minutes.  Instead, stagger startup times randomly
# based on the hash of each sandbox's hostname.  If the task runs every
# 30 minutes, this will spread the initial hourly runs between :00 and :29
# (with successive runs equally staggered of course).

sub fhbackend_get_start_min {
	my($freq) = @_;
	return 0 if $freq < 2;
	my $hosthash = hex(substr(Digest::MD5::md5_hex($me . $main::hostname), 0, 4));
	my $frac = $hosthash / 65536;
	return int($freq * $frac);
}

sub gen_firehose_rss {
	my($vu, $base, $skin, $label, $color, $filter, $opts, $content_type) = @_;
	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();
	my $gSkin = getCurrentSkin();
	my $form = getCurrentForm();
	$opts ||= {};
	$content_type ||= "rss";

	slashdLog("$base $skin $label $color '$filter'");
	use Data::Dumper;
	slashdLog(Dumper($opts)) if $opts;

	$form->{color} = $color;
	$form->{fhfilter} = $filter;
	$form->{duration} = -1;
	$form->{startdate} = '';


	my $firehose = getObject("Slash::FireHose");
	my $options = $firehose->getAndSetOptions({ no_set => 1 });
	$options->{limit} = 10;

	foreach (keys %$opts) {
		$options->{$_} = $opts->{$_};
	}


	my ($its, $results) = $firehose->getFireHoseEssentials($options);
	my @items;
	foreach (@$its) {
		my $item = $firehose->getFireHose($_->{id});
		my $link = $firehose->linkFireHose($item);
		push @items, {
			title 		=> $item->{title},
			time 		=> $item->{createtime},
			creator 	=> $slashdb->getUser($item->{uid}, 'nickname'),
			'link'		=> $link,
			description	=> $item->{introtext}
		};
	}
	my $rss = xmlDisplay($content_type, {
		channel => {
			title		=> "$constants->{sitename} $skin Firehose $label",
			'link'		=> "$gSkin->{absolutedir}/firehose.pl",
			descriptions 	=> "$constants->{sitename} $skin Firehose $label"
		},
		image	=> 1,
		items	=> \@items,
	}, 1);

	save2file("$constants->{basedir}/$base\.$content_type", $rss, \&fudge);

	# Pause between files to limit the resources required.
	sleep 2;
}


# this normalizes old and new content, stripping data that
# updates every time
sub fudge {
	my($current, $new) = @_;
	s{[dD]ate>[^<]+</}{} for $current, $new;
	return($current, $new);
}

1;


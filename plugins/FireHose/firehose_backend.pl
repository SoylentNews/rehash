#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::XML;
use Slash::Constants ':slashd';

use vars qw( %task $me );

$task{$me}{timespec} = '0-59/10 * * * *';
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
	foreach(keys %$skins) {
		my $skinname = $skins->{$_}{name};
		foreach (keys %$rss) {
			gen_firehose_rss($virtual_user, "$skinname\_$_", $skinname, $rss->{$_}->[0], $rss->{$_}->[1], "$skinname $rss->{$_}->[2]", $rss->{$_}->[3], "rss");
		}
	}


};

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
}


# this normalizes old and new content, stripping data that
# updates every time
sub fudge {
	my($current, $new) = @_;
	s{[dD]ate>[^<]+</}{} for $current, $new;
	return($current, $new);
}




1;

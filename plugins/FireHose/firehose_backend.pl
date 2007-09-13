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

	$rss->{"firehose"} = [ "green", "" ];
	$rss->{"firehose_nostories"} = ["green",  "-story" ];

	foreach (keys %$rss) {
		slashdLog("gen firehose $_\n");
		gen_firehose_rss($virtual_user, $_, $rss->{$_}->[0], $rss->{$_}->[1], "rss");
	}
		
};

# this normalizes old and new content, stripping data that
# updates every time
sub fudge {
	my($current, $new) = @_;
	s{[dD]ate>[^<]+</}{} for $current, $new;
	return($current, $new);
}


sub gen_firehose_rss {
	my($vu, $base, $color, $filter, $content_type) = @_;
	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();
	my $gSkin = getCurrentSkin();
	my $form = getCurrentForm();
	$content_type ||= "rss";

	$form->{color} = $color;
	$form->{fhfilter} = $filter;
	$form->{duration} = -1;
	$form->{startdate} = '';
	$form->{pagesize} = "large";
	
	my $firehose = getObject("Slash::FireHose");
	my $options = $firehose->getAndSetOptions({ no_set => 1 });

	#use Data::Dumper;
	#slashdLog(Dumper($options));

	my ($its, $results) = $firehose->getFireHoseEssentials($options);
	my @items;
	foreach (@$its) {
		my $item = $firehose->getFireHose($_->{id});
		push @items, {
			title 		=> $item->{title},
			time 		=> $item->{createtime},
			creator 	=> $slashdb->getUser($item->{uid}, 'nickname'),
			'link'		=> "$gSkin->{absolutedir}/firehose.pl?op=view&id=$item->{id}",
			description	=> $item->{introtext}
		};
	}
	my $rss = xmlDisplay($content_type, {
		channel => {
			title		=> "$constants->{sitename} Firehose",
			'link'		=> "$gSkin->{absolutedir}/firehose.pl",
			descriptions 	=> "$constants->{sitename} Firehose"
		},
		image	=> 1,
		items	=> \@items,
	}, 1);

	save2file("$constants->{basedir}/$base\.$content_type", $rss, \&fudge);
}



1;

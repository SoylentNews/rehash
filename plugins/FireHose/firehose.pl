#!/usr/bin/perl
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use warnings;

use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants qw(:web);
use Slash::Display;
use Slash::Utility;
use Slash::XML;
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;


sub main {
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();
	my $gSkin     = getCurrentSkin();

	my $anonval = $constants->{firehose_anonval_param} || "";

	my %ops = (
		list		=> [1,  \&list, 0, $anonval],
		view		=> [1, 	\&view, 1,  ""],
		default		=> [1,	\&list, 0,  $anonval],
		edit		=> [1,	\&edit, 100,  ""],
		rss		=> [1,  \&rss, 1, ""]
	);

	my $op = $form->{op} || "";
	
	my $rss = $op eq "rss" && $form->{content_type} && $form->{content_type} =~ $constants->{feed_types};

	
	if ($form->{logtoken} && !$rss) {
		redirect($ENV{SCRIPT_NAME});
	}

	if (!$op || !exists $ops{$op} || !$ops{$op}[ALLOWED] || $user->{seclev} < $ops{$op}[2] ) {
		$op = 'default';
		if ($user->{seclev} < 1 && $ops{$op}[3] && $ops{$op}[3] ne $form->{anonval}) {
			redirect("$gSkin->{rootdir}/login.pl");
			return;
		}
	}

	if ($op ne "rss") {
		header('Firehose', '') or return;
	}

	$ops{$op}[FUNCTION]->($slashdb, $constants, $user, $form, $gSkin);

	if ($op ne "rss") {
		footer();
	}
}


sub list {
	my($slashdb, $constants, $user, $form, $gSkin) = @_;
	my $firehose = getObject("Slash::FireHose");
	print $firehose->listView();
}

sub view {
	my($slashdb, $constants, $user, $form, $gSkin) = @_;
	my $firehose = getObject("Slash::FireHose");
	my $firehose_reader = getObject("Slash::FireHose", { db_type => 'reader' });
	my $options = $firehose->getAndSetOptions();
	my $item = $firehose_reader->getFireHose($form->{id});
	if ($item && $item->{id} && ($item->{public} eq "yes" || $user->{is_admin}) ) {
		if ($user->{is_admin}) {
			$firehose->setFireHoseSession($item->{id});
		}
		my $tags_top = $firehose_reader->getFireHoseTagsTop($item);
		my $firehosetext = $firehose_reader->dispFireHose($item, { mode => "full", tags_top => $tags_top, options => $options });
		slashDisplay("view", {
			firehosetext => $firehosetext
		});
	} else {
		print getData('notavailable');
	}
}

sub edit {
	my($slashdb, $constants, $user, $form, $gSkin) = @_;
	my $firehose = getObject("Slash::FireHose");
	if (!$form->{id}) {
		list(@_);
		return;
	}
	my $item = $firehose->getFireHose($form->{id});
	my $url;
	$url = $slashdb->getUrl($item->{url_id}) if $item->{url_id};
	my $the_user = $slashdb->getUser($item->{uid});
	slashDisplay('fireHoseForm', { item => $item, url => $url, the_user => $the_user, needformwrap => 1, needjssubmit => 1 });

}

sub rss {
	my($slashdb, $constants, $user, $form, $gSkin) = @_;
	my $firehose = getObject("Slash::FireHose");
	my $options = $firehose->getAndSetOptions({ no_set => 1 });
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
	xmlDisplay($form->{content_type} => {
		channel => {
			title		=> "$constants->{sitename} Firehose",
			'link'		=> "$gSkin->{absolutedir}/firehose.pl",
			descriptions 	=> "$constants->{sitename} Firehose"
		},
		image	=> 1,
		items	=> \@items,
	});
}



createEnvironment();
main();

1;

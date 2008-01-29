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
		list		=> [1,  \&list, 1, $anonval, { index => 1, issue => 1, page => 1, query_apache => -1, virtual_user => -1, startdate => 1, duration => 1, tab => 1, tabtype => 1, change => 1, section => 1  }],
		view		=> [1, 	\&view, 0,  ""],
		default		=> [1,	\&list, 1,  $anonval, { index => 1, issue => 1, page => 1, query_apache => -1, virtual_user => -1, startdate => 1, duration => 1, tab => 1, tabtype => 1, change => 1, section => 1 }],
		edit		=> [1,	\&edit, 100,  ""],
		rss		=> [1,  \&rss, 1, ""]
	);

	my $op = $form->{op} || "";
	
	my $rss = $op eq "rss" && $form->{content_type} && $form->{content_type} =~ $constants->{feed_types};

	
	if ($form->{logtoken} && !$rss) {
		redirect($ENV{SCRIPT_NAME});
	}

	if (!$op || !exists $ops{$op} || !$ops{$op}[ALLOWED] || $user->{seclev} < $ops{$op}[MINSECLEV] ) {
		$op = 'default';
	}

	# If default or list op and not logged in force them to be using allowed params or math anonval param
	if (($op eq 'default' || $op eq 'list') && $user->{seclev} <1) {

		my $redirect = 0;
		if ($ops{$op}[4] && ref($ops{$op}[4]) eq "HASH") {
			$redirect = 0;
			my $count;
			foreach (keys %$form) {
				$redirect = 1 if !$ops{$op}[4]{$_}; 
				$count++ if $ops{$op}[4]{$_} && $ops{$op}[4]{$_} > 0;
			}
			# Redirect if there are no operative non/system ops  
			$redirect = 1 if $count == 0;
		} 
		if ($redirect && ($ops{$op}[3] && $ops{$op}[3] eq $form->{anonval})) {
			$redirect = 0;
		} 
		if ($redirect) {
			my $prefix = $form->{embed} ? "embed_" : "";
			redirect("$gSkin->{rootdir}/${prefix}firehose.shtml");
			return;
		}
	}

	if ($op ne "rss") {
		my $title = "$constants->{sitename} - Firehose";
		if ($form->{index}) {
			$title = "$constants->{sitename} - $constants->{slogan}";
		}
		header($title, '') or return;
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
    	my $vote = '';
	if ($item) {
		$vote = $firehose->getUserFireHoseVotesForGlobjs($user->{uid}, [$item->{globjid}])->{$item->{globjid}};
	}
	if ($item && $item->{id} && ($item->{public} eq "yes" || $user->{is_admin}) ) {
		if ($user->{is_admin}) {
			$firehose->setFireHoseSession($item->{id});
		}
		my $tags_top = $firehose_reader->getFireHoseTagsTop($item);
		my $discussion = $item->{discussion};

		my $firehosetext = $firehose_reader->dispFireHose($item, {
			mode			=> 'full',
			view_mode		=> 1,
			tags_top		=> $tags_top,
			options			=> $options,
			nostorylinkwrapper	=> $discussion ? 1 : 0,
			vote			=> $vote
		});

		slashDisplay("view", {
			firehosetext => $firehosetext
		});

		if ($discussion) {
			printComments( $firehose_reader->getDiscussion($discussion) );
		}

		my $plugins = $slashdb->getDescriptions('plugins');
		if (!$user->{is_anon} && $plugins->{Tags}) {
			my $tagsdb = getObject('Slash::Tags');
			$tagsdb->markViewed($user->{uid}, $item->{globjid});
		}
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

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
	my $slashdb   		= getCurrentDB();
	my $constants 		= getCurrentStatic();
	my $user      		= getCurrentUser();
	my $form      		= getCurrentForm();
	my $gSkin     		= getCurrentSkin();
	my $firehose_reader  	= getObject("Slash::FireHose", { db_type => 'reader' });
	my $reader    		= getObject('Slash::DB', { db_type => 'reader' });
	my $noindex = 0;

	my $anonval = $constants->{firehose_anonval_param} || "";

	my %ops = (
		list		=> [1,  \&list, 1, $anonval, { index => 1, issue => 1, page => 1, query_apache => -1, virtual_user => -1, startdate => 1, duration => 1, tab => 1, tabtype => 1, change => 1, section => 1 , view => 1 }],
		view		=> [1, 	\&view, 0,  ""],
		default		=> [1,	\&list, 1,  $anonval, { index => 1, issue => 1, page => 1, query_apache => -1, virtual_user => -1, startdate => 1, duration => 1, tab => 1, tabtype => 1, change => 1, section => 1, view => 1 }],
		edit		=> [1,	\&edit, 100,  ""],
		metamod		=> [1,  \&metamod, 1, ""],
		rss		=> [1,  \&rss, 1, ""]
	);

	my $op = $form->{op} || "";

	if ($form->{sid} || $form->{id}) {
		$op ||= 'view';
	}
	
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
		if ($gSkin->{name} && $gSkin->{name} eq "idle") {
			$title = "$gSkin->{hostname} - Firehose";
		}
		if ($op eq "metamod") {
			$title = "$constants->{sitename} - Metamod";
			$form->{metamod} = 1;
		}
		if ($form->{index}) {
			$title = "$constants->{sitename} - $constants->{slogan}";
		}
		if ($op && $op eq "view") {
			my $item;
			if ($form->{type} && $form->{id}) {
				$item = $firehose_reader->getFireHoseByTypeSrcid($form->{type}, $form->{id});
			} elsif ($form->{id}) {
				$item = $firehose_reader->getFireHose($form->{id});
			}
			
			if (!$item && $form->{sid}) {
				$item = $firehose_reader->getFireHoseBySidOrStoid($form->{sid});
			}
			if ($item && $item->{id}) {
				if ($ENV{HTTP_USER_AGENT} =~ /MSIE [2-6]/) {
					if ($item->{type} eq "story") {
						my $story = $firehose_reader->getStory($item->{srcid});
						redirect("/article.pl?sid=$story->{sid}");
					} elsif ($item->{type} eq "journal") {
						redirect("/journal.pl?op=display&uid=$item->{uid}&id=$item->{srcid}");
					}
				}
				my $type = ucfirst($item->{type});
				my $skintitle = " $gSkin->{title}" if $gSkin->{skid} != $constants->{mainpage_skid};
				$title = "$constants->{sitename}$skintitle $type | $item->{title}" if $item->{title};
				my $author = $reader->getUser($item->{uid});
				if ($author->{shill_id}) {
					my $shill = $reader->getShillInfo($author->{shill_id});
					if ($shill->{skid} && $shill->{skid} != $gSkin->{skid}) {
						my $shill_skin = $reader->getSkin($shill->{skid});
						if ($shill_skin && $shill_skin->{rootdir} ne $gSkin->{rootdir}) {
							redirect("$shill_skin->{rootdir}$ENV{REQUEST_URI}");
							return;
						}
					}
				}
				$noindex = 1 if $item->{type} ne "story"; 
			}
				
		}
		header($title, '', { noindex => $noindex }) or return;
	}

	$ops{$op}[FUNCTION]->($slashdb, $constants, $user, $form, $gSkin);

	if ($op ne "rss") {
		footer();
	}
}


sub list {
	my($slashdb, $constants, $user, $form, $gSkin) = @_;
	slashProfInit();
	$form->{view} ||= "recent" if !$form->{fhfilter} && !$form->{section} && !$form->{color};
	my $firehose = getObject("Slash::FireHose");
	print $firehose->listView();
	slashProfEnd();
}

sub metamod {
	my($slashdb, $constants, $user, $form, $gSkin) = @_;
	my $firehose = getObject("Slash::FireHose");
	$form->{tabtype} 	= "metamod";
	$form->{skipmenu} 	= 1;
	$form->{pause} 		= 1;
	$form->{no_saved} 	= 1;
	print $firehose->listView({ view => 'metamod'});
}



sub view {
	my($slashdb, $constants, $user, $form, $gSkin) = @_;
	my $firehose = getObject("Slash::FireHose");
	my $firehose_reader = getObject("Slash::FireHose", { db_type => 'reader' });
	my $options = $firehose->getAndSetOptions();
	my $item;
	if ($form->{type} && $form->{id}) {
		$item = $firehose_reader->getFireHoseByTypeSrcid($form->{type}, $form->{id});
	} elsif ($form->{id}) {
		$item = $firehose_reader->getFireHose($form->{id});
	}
	if (!$item && $form->{sid}) {
		$item = $firehose_reader->getFireHoseBySidOrStoid($form->{sid});
	}
    	my $vote = '';
	if ($item) {
		$vote = $firehose->getUserFireHoseVotesForGlobjs($user->{uid}, [$item->{globjid}])->{$item->{globjid}};
	}
	if ($item && $item->{id} && ($item->{public} eq "yes" || $user->{is_admin}) ) {
		if ($user->{is_admin}) {
			$firehose->setFireHoseSession($item->{id});
		}
		my $tags_top = $firehose_reader->getFireHoseTagsTop($item);
		my $system_tags = $firehose_reader->getFireHoseSystemTags($item);
		my $discussion = $item->{discussion};

		# Related Stories
		my $related_stories = '';
		$related_stories = displayRelatedStories($item->{srcid}, { fh_view => 1 }) if (($item->{type} eq 'story') && $item->{srcid});

		# Extra book review info
		my $book_info = '';
		if (($item->{type} eq 'story') && $item->{primaryskid}) {
			my $skins = $slashdb->getSkins();
			if ($skins->{$item->{primaryskid}}{name} eq 'bookreview') {
				my $sid = $slashdb->getStorySidFromDiscussion($item->{discussion});
				my $story = $slashdb->getStory($sid) if $sid;
				$book_info = slashDisplay("view_book", { story => $story }, { Return => 1 }) if $story->{book_title};
			}
		}

		my $firehosetext = $firehose_reader->dispFireHose($item, {
			mode			=> 'full',
			view_mode		=> 1,
			tags_top		=> $tags_top,
			top_tags		=> $item->{toptags},
			system_tags		=> $system_tags,
			options			=> $options,
			nostorylinkwrapper	=> $discussion ? 1 : 0,
			vote			=> $vote,
			related_stories		=> $related_stories,
			book_info		=> $book_info,
		});

		my $dynamic_blocks = getObject('Slash::DynamicBlocks');
		my $userbio = '';
		$userbio = $dynamic_blocks->getUserBioBlock($user) if ($dynamic_blocks && !$user->{is_anon});

		my $commenttext="";
		
		if ($discussion) {
			$commenttext = printComments( $firehose_reader->getDiscussion($discussion),0,0, { Return => 1});
		}

		my $sprite_rules = $firehose_reader->js_anon_dump($firehose_reader->getSpriteInfoByFHID($item->{id}));

		slashDisplay("view", {
			firehosetext	=> $firehosetext,
			userbio		=> $userbio,
			commenttext	=> $commenttext,
			item		=> $item,
			sprite_rules	=> $sprite_rules
		});


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

	if ($item->{type} eq 'submission') {
		if ($item->{introtext} =~ m/^[^"]*"[^"]*"[^"]*$/s) {
			$item->{introtext} =~ s/"/'/g;
		}
		$item->{introtext} = quoteFixIntrotext($item->{introtext});
		$item->{title} = titleCaseConvert($item->{tile});
	}

	my $url;
	$url = $slashdb->getUrl($item->{url_id}) if $item->{url_id};
	my $the_user = $slashdb->getUser($item->{uid});
	slashDisplay('fireHoseForm', { item => $item, url => $url, the_user => $the_user, needformwrap => 1, needjssubmit => 1 });

}

sub rss {
	my($slashdb, $constants, $user, $form, $gSkin) = @_;
	my $firehose = getObject("Slash::FireHose");
	my $options = $firehose->getAndSetOptions({ no_set => 1 });
	my ($its, $results, $item, $channeltitle);

	if ($form->{id} && $form->{type}) {
		my $item = $firehose->getFireHoseByTypeSrcid($form->{type}, $form->{id});
		$its = [$item];
		$channeltitle = "$constants->{sitename} $item->{title}";
	} else {
		($its, $results) = $firehose->getFireHoseEssentials($options);
	}
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
	$channeltitle ||= "$constants->{sitename} Firehose - Filtered to  '$options->{fhfilter}'";
	xmlDisplay($form->{content_type} => {
		channel => {
			title		=> $channeltitle,
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

#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::DB;
use Slash::Utility;
use Slash::Journal;
use Slash::Display;
use Date::Manip;
use XML::RSS;
use Apache;


sub main {
	my %ops = (
		list		=> \&listArticle,
		preview		=> \&editArticle,
		edit		=> \&editArticle,
		get		=> \&getArticle,
		display		=> \&displayArticle,
		save		=> \&saveArticle,
		remove		=> \&removeArticle,
		'delete'	=> \&deleteFriend,
		add		=> \&addFriend,
		top		=> \&displayTop,
		friends		=> \&displayFriends,
		default		=> \&displayDefault,
		rss		=> \&displayRSS,
	);

	my %safe = (
		list		=> 1,
		get		=> 1,
		display		=> 1,
		top		=> 1,
		friends		=> 1,
		default		=> 1,
		rss		=> 1,
	);

	my $journal = Slash::Journal->new(getCurrentVirtualUser());
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();

	my $op = $form->{'op'};
	$op = 'default' unless $ops{$op};

	if (getCurrentUser('is_anon')) {
		$op = 'default' unless $safe{$op};
	}

	if ($op eq 'rss') {
		my $r = Apache->request;
		$r->header_out('Cache-Control', 'private');
		$r->content_type('text/xml');
		$r->status(200);
		$r->send_http_header;
		$r->rflush;
		if($form->{content} eq 'top') {
			$r->print(displayTopRSS($form, $journal, $constants));
		} else {
			$r->print(displayRSS($form, $journal, $constants));
		}
		$r->status(200);
	} else {
		my $uid = $form->{'uid'};
		if ($op eq 'display') {
			my $slashdb = getCurrentDB();
			my $nickname = $slashdb->getUser($form->{uid}, 'nickname') if $form->{uid};
			$nickname ||= getCurrentUser('nickname');
			# header text should be in templates
			header("${nickname}'s Journal");
			titlebar("100%","${nickname}'s Journal");
		} else {
			header("$constants->{sitename} Journal System");
			titlebar("100%","Journal System");
		}

		print createMenu('journal');

		$ops{$op}->($form, $journal, $constants);

		footer();
	}
}

sub displayDefault {
	displayFriends(@_);
}

sub displayTop {
	my($form, $journal, $constants) = @_;
	my $journals;

	$journals = $journal->top($constants->{journal_top});
	slashDisplay('journaltop', { journals => $journals, type => 'top' });

	$journals = $journal->topFriends($constants->{journal_top});
	slashDisplay('journaltop', { journals => $journals, type => 'friend' });

	$journals = $journal->topRecent($constants->{journal_top});
	slashDisplay('journaltop', { journals => $journals, type => 'recent' });
}

sub displayFriends {
	my($form, $journal) = @_;
	my $friends = $journal->friends();
	slashDisplay('journalfriends', { friends => $friends });
}

sub displayRSS {
	my($form, $journal, $constants) = @_;
	my $rss = XML::RSS->new(
		version		=> '1.0',
		encoding	=> $constants->{rdfencoding},
	);
	my $slashdb = getCurrentDB();

	my($uid, $nickname);
	if ($form->{uid}) {
		$nickname = $slashdb->getUser($form->{uid}, 'nickname');
		$uid = $form->{uid};
	} else {
		$nickname = getCurrentUser('nickname');
		$uid = getCurrentUser('uid');
	}

	$rss->channel(
		title	=> xmlencode($constants->{sitename} . " Journals"),
		'link'	=> xmlencode($constants->{absolutedir} . "/journal.pl?op=display&uid=$uid"),
		description => xmlencode("${nickname}'s Journal"),
	);

	$rss->image(
		title	=> xmlencode($constants->{sitename}),
		url	=> xmlencode($constants->{rdfimg}),
		'link'	=> $constants->{absolutedir} . '/',
	);


	my $articles = $journal->getsByUid($uid, 0, 15);
	for my $article (@$articles) {
			$rss->add_item(
				title	=> xmlencode($article->[2]),
				'link'	=> xmlencode("$constants->{absolutedir}/journal.pl?op=get&id=$article->[3]"),
				description => xmlencode("$nickname wrote: " . strip_mode($article->[1], $article->[4]))
		);
	}
	return $rss->as_string;
}

sub displayTopRSS {
	my($form, $journal, $constants) = @_;
	my $rss = XML::RSS->new(
		version		=> '1.0',
		encoding	=> $constants->{rdfencoding},
	);

	my $journals;

	if ($form->{type} eq 'count') {
		$journals = $journal->top($constants->{journal_top});
	} elsif ($form->{type} eq 'friends') {
		$journals = $journal->topFriends($constants->{journal_top});
	} else {
		$journals = $journal->topRecent($constants->{journal_top});
	}

	$rss->channel(
		title	=> xmlencode($constants->{sitename} . " Top $constants->{journal_top} Journals"),
		'link'	=> xmlencode($constants->{absolutedir} . "/journal.pl?op=top"),
		description	=> xmlencode($constants->{sitename} . " Top $constants->{journal_top} Journals"),
	);

	$rss->image(
		title	=> xmlencode($constants->{sitename}),
		url	=> xmlencode($constants->{rdfimg}),
		'link'	=> $constants->{absolutedir} . '/',
	);


	for my $entry (@$journals) {
			my $time = timeCalc($entry->[3]);
			$rss->add_item(
				title	=> xmlencode("$entry->[1] ($time)"),
				'link'	=> (xmlencode($constants->{absolutedir} . '/journal.pl?op=display') . '&amp;' . xmlencode('uid=' . $entry->[2])),
			);
	}
	return $rss->as_string;
}

sub displayArticle {
	my($form, $journal, $constants) = @_;
	my $slashdb = getCurrentDB();
	my($uid, $nickname, $date, $forward, $back, @sorted_articles);
	my $collection = {};

	if ($form->{uid}) {
		$nickname = $slashdb->getUser($form->{uid}, 'nickname');
		$uid = $form->{uid};
	} else {
		$nickname = getCurrentUser('nickname');
		$uid = getCurrentUser('uid');
	}

	# clean it up
	my $start = fixint($form->{start}) || 0;
	my $articles = $journal->getsByUid($uid, $start,
		$constants->{journal_default_display} + 1, $form->{id}
	);

	# check for extra articles ... we request one more than we need
	# and if we get the extra one, we know we have extra ones, and
	# we pop it off
	if (@$articles == $constants->{journal_default_display} + 1) {
		pop @$articles;
		$forward = $start + $constants->{journal_default_display};
	} else {
		$forward = 0;
	}

	# if there are less than journal_default_display remaning,
	# just set it to 0
	if ($start > 0) {
		$back = $start - $constants->{journal_default_display};
		$back = $back > 0 ? $back : 0;
	} else {
		$back = -1;
	}

	for my $article (@$articles) {
		my($date_current, $time) =  split / /, $article->[0], 2;	
		if ($date eq $date_current) {
			push @{$collection->{article}}, {
				article		=> strip_mode($article->[1], $article->[4]),
				date		=> $article->[0],
				description	=> $article->[2]
			};
		} else {
			push @sorted_articles, $collection if ($date and (keys %$collection));
			$collection = {};
			$date = $date_current;
			$collection->{day} = $article->[0];
			push @{$collection->{article}}, {
				article		=> strip_mode($article->[1], $article->[4]),
				date		=> $article->[0],
				description	=> $article->[2]
			};
		}
	}
	push @sorted_articles, $collection;
	my $theme = $slashdb->getUser($uid, 'journal-theme');
	$theme ||= $constants->{journal_default_theme};

	slashDisplay($theme, {
		articles	=> \@sorted_articles,
		uid		=> $form->{uid},
		back		=> $back,
		forward		=> $forward,
	});
}

sub listArticle {
	my($form, $journal, $constants) = @_;
	my $user = getCurrentUser();
	my $list = $journal->list($form->{uid} || $ENV{SLASH_USER});
	my $themes = $journal->themes;
	if ($form->{theme}) {
		my $db = getCurrentDB();
		if (grep /^$form->{theme}$/, @$themes) {
			$db->setUser($user->{uid}, { 'journal-theme' => $form->{theme} });
			$user->{'journal-theme'} = $form->{theme};
		}
	}
	my $theme = $user->{'journal-theme'} || $constants->{journal_default_theme};
	slashDisplay('journallist', {
		articles	=> $list,
		default		=> $theme,
		themes		=> $themes,
		uid		=> $form->{uid},
	});
}

sub saveArticle {
	my($form, $journal) = @_;
	my $description = strip_nohtml($form->{description});

	if ($form->{id}) {
		$journal->set($form->{id}, {
			description	=> $description,
			article		=> $form->{article},
			posttype	=> $form->{posttype},
		});
	} else {
		$journal->create($description,
			$form->{article}, $form->{posttype});
	}
	listArticle(@_);
}

sub removeArticle {
	my($form, $journal) = @_;
	$journal->remove($form->{id}) if $form->{id};
	listArticle(@_);
}

sub addFriend {
	my($form, $journal) = @_;

	$journal->add($form->{uid}) if $form->{uid};
	displayDefault(@_);
}

sub deleteFriend {
	my ($form, $journal) = @_;

	$journal->delete($form->{uid}) if $form->{uid} ;
	displayDefault(@_);
}

sub editArticle {
	my($form, $journal, $constants) = @_;
	# This is where we figure out what is happening
	my $article = {};
	my $posttype;

	if ($form->{state}) {
		$article->{date}	= scalar(localtime(time()));
		$article->{article}	= $form->{article};
		$article->{description}	= $form->{description};
		$article->{id}		= $form->{id};
		$posttype		= $form->{posttype};
	} else {
		$article  = $journal->get($form->{id}) if $form->{id};
		$posttype = $article->{posttype};
	}

	$posttype ||= getCurrentUser('posttype');

	if ($article->{article}) {
		my $strip_art = strip_mode($article->{article}, $posttype);
		my $strip_desc = strip_nohtml($article->{description});
		my $disp_article = {
			date		=> $article->{date},
			article		=> $strip_art,
			description	=> $strip_desc,
			id		=> $article->{id},
		};

		my $theme = getCurrentUser('journal-theme');
		$theme ||= $constants->{journal_default_theme};
		slashDisplay($theme, {
			articles	=> [{ day => $article->{date}, article => [ $disp_article ] }],
			uid		=> $article->{uid},
			back		=> -1,
			forward		=> 0,
		});
	}

	my $slashdb = getCurrentDB();
	my $formats = $slashdb->getDescriptions('postmodes');
	my $format_select = createSelect('posttype', $formats, $posttype, 1);

	slashDisplay('journaledit', {
		article		=> $article,
		format_select	=> $format_select,
	});
}

sub getArticle {
	my($form, $journal, $constants) = @_;
	# This is where we figure out what is happening
	my $article = $journal->get($form->{id}, [ qw( article date description ) ]);
	my $theme = getCurrentUser('journal-theme');
	$theme ||= $constants->{journal_default_theme};
	slashDisplay($theme, {
		articles	=> [{ day => $article->{date}, article => [ $article ] }],
		uid		=> $article->{uid},
		back		=> -1,
		forward		=> 0,
	});
}

main();

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
		$r->print(displayRSS($form, $journal));
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
	slashDisplay('journaltop', {
		journals => $journals,
		url => '/journal.pl',
	});
	$journals = $journal->topFriends($constants->{journal_top});
	slashDisplay('journaltop', {
		journals => $journals,
		url => '/journal.pl',
	});
	$journals = $journal->topRecent($constants->{journal_top});
	slashDisplay('journaltop', {
		journals => $journals,
		url => '/journal.pl',
	});
}

sub displayFriends {
	my($form, $journal) = @_;
	my $friends = $journal->friends();
	slashDisplay('journalfriends', {
		friends	=> $friends,
	});
}

sub displayRSS {
	my($form, $journal, $constants) = @_;
	my $rss = XML::RSS->new(
		version		=> '0.91',
		encoding	=>'UTF-8'
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


	my $articles = $journal->getsByUid($uid, $constants->{journal_default_display});
	for my $article (@$articles) {
			$rss->add_item(
				title	=> xmlencode($article->[2]),
				'link'	=> xmlencode("$constants->{absolutedir}/journal.pl?op=get&id=$article->[3]"),
				description => xmlencode("$nickname wrote: " . $article->[1])
		);
	}
	return $rss->as_string;
}

sub displayArticle {
	my($form, $journal, $constants) = @_;
	my $slashdb = getCurrentDB();
	my $uid;
	my $nickname;

	if ($form->{uid}) {
		$nickname = $slashdb->getUser($form->{uid}, 'nickname');
		$uid = $form->{uid};
	} else {
		$nickname = getCurrentUser('nickname');
		$uid = getCurrentUser('uid');
	}
	my $articles = $journal->getsByUid($uid, $constants->{journal_default_display});
	my @sorted_articles;
	my $date;
	my $collection = {};
	for my $article (@$articles) {
		my($date_current, $time) =  split / /, $article->[0], 2;	
		if ($date eq $date_current) {
			push @{$collection->{article}} , { article =>  $article->[1], date =>  $article->[0], description => $article->[2]};
		} else {
			push @sorted_articles, $collection if ($date and (keys %$collection));
			$collection = {};
			$date = $date_current;
			$collection->{day} = $date;
			push @{$collection->{article}} , { article =>  $article->[1], date =>  $article->[0], description => $article->[2]};
		}
	}
	push @sorted_articles, $collection;
	my $theme = $slashdb->getUser($uid, 'journal-theme');
	$theme ||= $constants->{journal_default_theme};
	slashDisplay($theme, {
		articles	=> \@sorted_articles,
		uid		=> $form->{uid},
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
	});
}

sub saveArticle {
	my($form, $journal) = @_;
	my $article = strip_mode($form->{article}, $form->{posttype});
	my $description = strip_nohtml($form->{description});

	if ($form->{id}) {
		$journal->set($form->{id}, {
			description	=> $description,
			article		=> $article,
			original	=> $form->{article},
			posttype	=> $form->{posttype},
		});
	} else {
		$journal->create($description, $article, $form->{article}, $form->{posttype});
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

	if ($form->{state}) {
		$article->{date}	= scalar(localtime(time()));
		$article->{article}	= $form->{article};
		$article->{description}	= $form->{description};
		$article->{id}		= $form->{id};
	} else {
		$article = $journal->get($form->{id}) if $form->{id};
	}
	
	if ($article->{article}) {
		# don't strip if we can get original from DB
		my $strip_art = $article->{original}
			? $article->{article}
			: strip_mode($article->{article}, $form->{posttype});
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
		});
	}

	my $slashdb = getCurrentDB();
	my $formats = $slashdb->getDescriptions('postmodes');
	my $posttype = $form->{posttype} || $article->{posttype} || getCurrentUser('posttype');

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
	});
}

main();

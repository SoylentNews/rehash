#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants qw(:messages :web);
use Slash::Display;
use Slash::Utility;
use Slash::XML;
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub main {
	my $journal   = getObject('Slash::Journal');
	my $constants = getCurrentStatic();
	my $reader    = getObject('Slash::DB', { db_type => 'reader' });
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();

	if ($constants->{journal_soap_enabled}) {
		my $r = Apache->request;
		if ($r->header_in('SOAPAction')) {
			require SOAP::Transport::HTTP;
			# security problem previous to 0.55
			if (SOAP::Lite->VERSION >= 0.55) {
				if ($user->{state}{post}) {
					$r->method('POST');
				}
				$user->{state}{packagename} = __PACKAGE__;
				return SOAP::Transport::HTTP::Apache->dispatch_to
					('Slash::Journal::SOAP')->handle;
			}
		}
	}

	# require POST and logged-in user for these ops
	my $user_ok   = $user->{state}{post} && !$user->{is_anon};

	# if top 10 are allowed
	# My feeling is that an admin should be able to use the
	# feature even if the site does not use it. -Brian
	my $top_ok    = ($constants->{journal_top} && (
		$constants->{journal_top_posters} ||
		$constants->{journal_top_friend}  ||
		$constants->{journal_top_recent}
	)) || $user->{is_admin};

	# possible value of "op" parameter in form
	my %ops = (
		edit		=> [ !$user->{is_anon},	\&editArticle		],
		removemeta	=> [ !$user->{is_anon},	\&articleMeta		],

		preview		=> [ $user_ok,		\&editArticle		],
		save		=> [ $user_ok,		\&saveArticle		], # formkey
		remove		=> [ $user_ok,		\&removeArticle		],

		editprefs	=> [ !$user->{is_anon},	\&editPrefs		],
		setprefs	=> [ $user_ok,		\&setPrefs		],

		list		=> [ 1,			\&listArticle		],
		display		=> [ 1,			\&displayArticle	],
		top		=> [ $top_ok,		\&displayTop		],
		searchusers	=> [ 1,			\&searchUsers		],
		friends		=> [ 1,			\&displayFriends	],
		friendview	=> [ 1,			\&displayArticleFriends	],

		default		=> [ 1,			\&displayFriends	],
	);

	# journal.pl waits until it's inside the op's subroutine to print
	# its header.  Headers are bottlenecked through _printHead.

	# this is a hack, think more on it, OK for now -- pudge
	# I think this needs to be part of cramming all possible
	# user init code into getUser(). Saving a few nanoseconds
	# here and there is not worth my staying up until 11 PM
	# trying to figure out what fields get set where. - Jamie
	# agreed, but the problem is that section is determined by header(),
	# and that determines color.  we could set the color in the
	# user init code, and then change it later in header() only
	# if section is defined, perhaps. -- pudge
	Slash::Utility::Anchor::getSectionColors();

	my $op = $form->{'op'};
	if (!$op || !exists $ops{$op} || !$ops{$op}[ALLOWED]) {
		$op = 'default';
	}

	# hijack RSS feeds
	if ($form->{content_type} eq 'rss') {
		if ($op eq 'top' && $top_ok) {
			displayTopRSS($journal, $constants, $user, $form, $reader);
		} else {
			displayRSS($journal, $constants, $user, $form, $reader);
		}
	} else {
		$ops{$op}[FUNCTION]->($journal, $constants, $user, $form, $reader);
		footer();
	}
}

sub displayTop {
	my($journal, $constants, $user, $form, $reader) = @_;
	my $journals;

	_printHead("mainhead");

	# this should probably be in a separate template, so the site admins
	# can select the order themselves -- pudge
	if ($constants->{journal_top_recent}) {
		$journals = $journal->topRecent();
		slashDisplay('journaltop', { journals => $journals, type => 'recent' });
	}

	if ($constants->{journal_top_posters}) {
		$journals = $journal->top();
		slashDisplay('journaltop', { journals => $journals, type => 'top' });
	}

	if ($constants->{journal_top_friend}) {
		my $zoo   = getObject('Slash::Zoo');
		$journals = $zoo->topFriends();
		slashDisplay('journaltop', { journals => $journals, type => 'friend' });
	}

}

sub displayFriends {
	my($journal, $constants, $user, $form, $reader) = @_;

	redirect("$constants->{rootdir}/search.pl?op=journals") 
		if $user->{is_anon};

	_printHead("mainhead");

	my $zoo = getObject('Slash::Zoo');
	my $friends = $zoo->getFriendsWithJournals();
	if (@$friends) {
		slashDisplay('journalfriends', { friends => $friends });
	} else {
		print getData('nofriends');
		slashDisplay('searchusers');
	}

}

sub searchUsers {
	my($journal, $constants, $user, $form, $reader) = @_;

	if (!$form->{nickname}) {
		_printHead("mainhead");
		slashDisplay('searchusers');
		return;
	}

	my $results = $journal->searchUsers($form->{nickname});

	# if nonref and true, then display user journal
	if ($results && !ref($results)) {
		# clean up a bit, just in case
		for (keys %$form) {
			delete $form->{$_} unless $_ eq 'op';
		}
		$form->{uid} = $results;
		displayArticle(@_);
		return;
	}

	# print the lovely headers
	_printHead("mainhead");

	# if false or empty ref, no users
	if (!$results || (ref($results) eq 'ARRAY' && @$results < 1)) {
		print getData('nousers');
		slashDisplay('searchusers');

	# a hashref, that is exact user with no journal
	} elsif (ref($results) eq 'HASH') {
		print getData('nojournal', { nouser => $results });
		slashDisplay('searchusers');

	# an arrayref, we gots to display a list
	} else {
		slashDisplay('journalfriends', {
			friends => $results,
			search	=> 1,
		});
	}
}

sub displayRSS {
	my($journal, $constants, $user, $form, $reader) = @_;

	$user		= $reader->getUser($form->{uid}, ['nickname', 'fakeemail']) if $form->{uid};
	my $uid		= $form->{uid} || $user->{uid};
	my $nickname	= $user->{nickname};

	my $articles = $journal->getsByUid($uid, 0, 15);
	my @items;
	for my $article (@$articles) {
		push @items, {
			title		=> $article->[2],
# needs a var controlling this ... what to use as desc?
#			description	=> timeCalc($article->[0]),
			description	=> strip_mode($article->[1], $article->[4]),
			'link'		=> "$constants->{absolutedir}/~" . fixparam($nickname) . "/journal/$article->[3]"
		};
	}

	my $usertext = $nickname;
	$usertext .= " <$user->{fakeemail}>" if $user->{fakeemail};
	xmlDisplay(rss => {
		channel => {
			title		=> "$constants->{sitename} Journals",
			description	=> "${nickname}'s Journal",
			'link'		=> "$constants->{absolutedir}/~" . fixparam($nickname) . "/journal/",
			creator		=> $usertext,
		},
		image	=> 1,
		items	=> \@items
	});
}

sub displayTopRSS {
	my($journal, $constants, $user, $form, $reader) = @_;

	my $journals;
	if ($form->{type} eq 'count' && $constants->{journal_top_posters}) {
		$journals = $journal->top();
	} elsif ($form->{type} eq 'friends' && $constants->{journal_top_friend}) {
		$journals = $journal->topFriends();
	} elsif ($constants->{journal_top_recent}) {
		$journals = $journal->topRecent();
	}

	my @items;
	for my $entry (@$journals) {
#		my $time = timeCalc($entry->[3]);
		push @items, {
			title	=> "[$entry->[1]] $entry->[5]",
			'link'	=> "$constants->{absolutedir}/~" . fixparam($entry->[1]) . "/journal/"
		};
	}

	xmlDisplay(rss => {
		channel => {
			title		=> "$constants->{sitename} Journals",
			description	=> "Top $constants->{journal_top} Journals",
			'link'		=> "$constants->{absolutedir}/journal.pl?op=top",
		},
		image	=> 1,
		items	=> \@items
	});
}

sub displayArticleFriends {
	my($journal, $constants, $user, $form, $reader) = @_;
	my($date, $forward, $back, $nickname, $uid);
	my @collection;
	my $zoo   = getObject('Slash::Zoo');

	if ($form->{uid} || $form->{nick}) {
		$uid		= $form->{uid} ? $form->{uid} : $reader->getUserUID($form->{nick});
		$nickname	= $reader->getUser($uid, 'nickname');
	} else {
		$nickname	= $user->{nickname};
		$uid		= $user->{uid};
	}

	_printHead("friendhead", { nickname => $nickname, uid => $uid });

	# clean it up
	my $start = fixint($form->{start}) || 0;
	my $uids = $zoo->getFriendsUIDs($uid);
	my $articles = $journal->getsByUids($uids, $start,
		$constants->{journal_default_display} + 1, $form->{id}
	);

	unless ($articles && @$articles) {
		print getData('noviewfriends');
		return;
	}

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

	my $topics = $reader->getTopics();
	for my $article (@$articles) {
		my $commentcount = $article->[6]
			? $reader->getDiscussion($article->[6], 'commentcount')
			: 0;

		# should get comment count, too -- pudge
		push @collection, {
			article		=> strip_mode($article->[1], $article->[4]),
			date		=> $article->[0],
			description	=> strip_notags($article->[2]),
			topic		=> $topics->{$article->[5]},
			discussion	=> $article->[6],
			id		=> $article->[3],
			commentcount	=> $commentcount,
			uid		=> $article->[7],
			nickname	=> $article->[8],
		};
	}

	slashDisplay('friendsview', {
		articles	=> \@collection,
		uid		=> $uid,
		nickname	=> $nickname,
		back		=> $back,
		forward		=> $forward,
	});
}

sub displayArticle {
	my($journal, $constants, $user, $form, $reader) = @_;
	my($date, $forward, $back, @sorted_articles, $nickname, $uid, $discussion);
	my $collection = {};
	my $user_change = {};
	my $head_data = {};

	if ($form->{uid} || $form->{nick}) {
		$uid		= $form->{uid} ? $form->{uid} : $reader->getUserUID($form->{nick});
		$nickname	= $reader->getUser($uid, 'nickname');
		if ($uid && $uid != $user->{uid}
			&& !isAnon($uid) && !$user->{is_anon}) {
			# Store the fact that this user last looked at that user.
			# For maximal convenience in stalking.
			$user_change->{lastlookuid} = $uid;
			$user_change->{lastlooktime} = time;
			$user->{lastlookuid} = $uid;
			$user->{lastlooktime} = time;
		}
	} else {
		$nickname	= $user->{nickname};
		$uid		= $user->{uid};
	}
	$head_data->{nickname} = $nickname;
	$head_data->{uid} = $uid;

	if (isAnon($uid)) {
		# Don't write user_change.
		return displayFriends(@_);
	}

	_printHead("userhead", $head_data, 1);

	# clean it up
	my $start = fixint($form->{start}) || 0;
	my $articles = $journal->getsByUid($uid, $start,
		$constants->{journal_default_display} + 1, $form->{id}
	);

	unless ($articles && @$articles) {
		print getData('noentries_found');
		if ($user_change && %$user_change) {
			my $slashdb = getCurrentDB();
			$slashdb->setUser($user->{uid}, $user_change);
		}
		return;
	}

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

	my $topics = $reader->getTopics();
	for my $article (@$articles) {
		my($date_current) = timeCalc($article->[0], "%A %B %d, %Y");
		if ($date ne $date_current) {
			push @sorted_articles, $collection if ($date and (keys %$collection));
			$collection = {};
			$date = $date_current;
			$collection->{day} = $article->[0];
		}

		my $commentcount;
		if ($form->{id}) {
			$discussion = $reader->getDiscussion($article->[6]);
			$commentcount = $article->[6]
				? $discussion->{commentcount}
				: 0;
		} else {
			$commentcount = $article->[6]
				? $reader->getDiscussion($article->[6], 'commentcount')
				: 0;
		}

		# should get comment count, too -- pudge
		push @{$collection->{article}}, {
			article		=> strip_mode($article->[1], $article->[4]),
			date		=> $article->[0],
			description	=> strip_notags($article->[2]),
			topic		=> $topics->{$article->[5]},
			discussion	=> $article->[6],
			id		=> $article->[3],
			commentcount	=> $commentcount,
		};
	}

	push @sorted_articles, $collection;
	my $theme = _checkTheme($reader->getUser($uid, 'journal_theme'));

	my $show_discussion = $form->{id} && !$constants->{journal_no_comments_item} && $discussion;
	my $zoo   = getObject('Slash::Zoo');
	slashDisplay($theme, {
		articles	=> \@sorted_articles,
		uid		=> $uid,
		nickname	=> $nickname,
		is_friend	=> $zoo->isFriend($user->{uid}, $uid),
		back		=> $back,
		forward		=> $forward,
		show_discussion	=> $show_discussion,
	});

	if ($show_discussion) {
		printComments($discussion);
	}

	if ($user_change && %$user_change) {
		my $slashdb = getCurrentDB();
		$slashdb->setUser($user->{uid}, $user_change);
	}
}

sub editPrefs {
	my($journal, $constants, $user, $form, $reader) = @_;

	my $nickname	= $user->{nickname};
	my $uid		= $user->{uid};
	_printHead("userhead", { nickname => $nickname, uid => $uid, menutype => 'prefs' });

	my $theme	= _checkTheme($user->{'journal_theme'});
	my $themes	= $journal->themes;
	slashDisplay('journaloptions', {
		default		=> $theme,
		themes		=> $themes,
	});
}

sub setPrefs {
	my($journal, $constants, $user, $form, $reader) = @_;

	my %prefs;
	$prefs{journal_discuss} = $user->{journal_discuss} =
		$form->{journal_discuss}
		if defined $form->{journal_discuss};

	$prefs{journal_theme} = $user->{journal_theme} =
		_checkTheme($form->{journal_theme})
		if defined $form->{journal_theme};

	my $slashdb = getCurrentDB();
	$slashdb->setUser($user->{uid}, \%prefs);

	editPrefs(@_);
}

sub listArticle {
	my($journal, $constants, $user, $form, $reader) = @_;

	my $uid = $form->{uid} || $ENV{SLASH_USER};
	if (isAnon($uid)) {
		return displayFriends(@_);
	}

	my $list 	= $journal->list($uid);
	my $themes	= $journal->themes;
	my $theme	= _checkTheme($user->{'journal_theme'});
	my $nickname	= $form->{uid}
		? $reader->getUser($form->{uid}, 'nickname')
		: $user->{nickname};

	_printHead("userhead",
		{ nickname => $nickname, uid => $form->{uid} || $user->{uid} },
		1);

	if (@$list) {
		slashDisplay('journallist', {
			default		=> $theme,
			themes		=> $themes,
			articles	=> $list,
			uid		=> $form->{uid} || $user->{uid},
			nickname	=> $nickname,
		});
	} elsif (!$user->{is_anon} && (!$form->{uid} || $form->{uid} == $user->{uid})) {
		print getData('noentries');
	} else {
		print getData('noentries', { nickname => $nickname });
	}
}

sub saveArticle {
	my($journal, $constants, $user, $form, $reader, $ws) = @_;
	$form->{description} =~ s/[\r\n].*$//s;  # strip anything after newline
	my $description = strip_notags($form->{description});

	unless ($description ne "" && $form->{article} ne "") {
		unless ($ws) {
			_printHead("mainhead");
			print getData('no_desc_or_article');
			editArticle(@_, 1);
		}
		return 0;
	}

	return 0 unless _validFormkey($ws ? qw(max_post_check interval_check) : ());

	my $slashdb = getCurrentDB();
	if ($form->{id}) {

		my %update;
		my $article = $journal->get($form->{id});

		# note: comments_on is a special case where we are
		# only turning on comments, not saving anything else
		if ($constants->{journal_comments} && $form->{journal_discuss} ne 'disabled' && !$article->{discussion}) {
			my $rootdir = $constants->{'rootdir'};
			if ($form->{comments_on}) {
				$description = $article->{description};
				$form->{tid} = $article->{tid};
			}
			my $did = $slashdb->createDiscussion({
				title	=> $description,
				topic	=> $form->{tid},
				commentstatus	=> $form->{journal_discuss},
				url	=> "$rootdir/~" . fixparam($user->{nickname}) . "/journal/$form->{id}",
			});
			$update{discussion}  = $did;

		# update description if changed
		} elsif (!$form->{comments_on} && $article->{discussion} && $article->{description} ne $description) {
			$slashdb->setDiscussion($article->{discussion}, { title => $description });
		}

		unless ($form->{comments_on}) {
			for (qw(article tid posttype)) {
				$update{$_} = $form->{$_} if defined $form->{$_};
			}
			$update{description} = $description;
		}

		$journal->set($form->{id}, \%update);

		return $form->{id} if $ws;
		$form = { id => $form->{id} };

	} else {
		my $id = $journal->create($description,
			$form->{article}, $form->{posttype}, $form->{tid});

		unless ($id) {
			unless ($ws) {
				_printHead("mainhead");
				print getData('create_failed');
			}
			return 0;
		}

		if ($constants->{journal_comments} && $form->{journal_discuss} ne 'disabled') {
			my $rootdir = $constants->{'rootdir'};
			my $did = $slashdb->createDiscussion({
				title	=> $description,
				topic	=> $form->{tid},
				commentstatus	=> $form->{journal_discuss},
				url	=> "$rootdir/~" . fixparam($user->{nickname}) . "/journal/$id",
			});
			$journal->set($id, { discussion => $did });
		}

		# create messages
		my $messages = getObject('Slash::Messages');
		if ($messages) {
			my $zoo = getObject('Slash::Zoo');
			my $friends = $zoo->getFriendsForMessage;

			my $data = {
				template_name	=> 'messagenew',
				subject		=> { template_name => 'messagenew_subj' },
				journal		=> {
					description	=> $description,
					article		=> $form->{article},
					posttype	=> $form->{posttype},
					id		=> $id,
					uid		=> $user->{uid},
					nickname	=> $user->{nickname},
				}
			};
			for (@$friends) {
				$messages->create($_, MSG_CODE_JOURNAL_FRIEND, $data);
			}
		}

		return $id if $ws;
		$form = { id => $id };
	}

	displayArticle($journal, $constants, $user, $form, $reader);
}

sub articleMeta {
	my($journal, $constants, $user, $form, $reader) = @_;

	if ($form->{id}) {
		my $article = $journal->get($form->{id});
		_printHead("mainhead");
		slashDisplay('meta', { article => $article });
	} else {
		listArticle(@_);
	}
}

sub removeArticle {
	my($journal, $constants, $user, $form, $reader) = @_;

	for my $id (grep { $_ = /^del_(\d+)$/ ? $1 : 0 } keys %$form) {
		$journal->remove($id);
	}

	listArticle(@_);
}

sub editArticle {
	my($journal, $constants, $user, $form, $reader, $nohead) = @_;
	# This is where we figure out what is happening
	my $article = {};
	my $posttype;

	_printHead("mainhead") unless $nohead;

	if ($form->{state}) {
		$article->{date}	= scalar(localtime(time()));
		$article->{article}	= $form->{article};
		$article->{description}	= $form->{description};
		$article->{id}		= $form->{id};
		$article->{tid}		= $form->{tid};
		$posttype		= $form->{posttype};
	} else {
		$article  = $journal->get($form->{id}) if $form->{id};
		$posttype = $article->{posttype};
		my $slashdb = getCurrentDB();
		$slashdb->createFormkey('journal');
	}

	$posttype ||= $user->{'posttype'};

	if ($article->{article}) {
		my $strip_art = strip_mode($article->{article}, $posttype);
		my $strip_desc = strip_notags($article->{description});

		my $commentcount = $article->{discussion}
			? $reader->getDiscussion($article->{discussion}, 'commentcount')
			: 0;

		my $disp_article = {
			article		=> $strip_art,
			date		=> $article->{date},
			description	=> $strip_desc,
			topic		=> $reader->getTopic($article->{tid}),
			id		=> $article->{id},
			discussion	=> $article->{discussion},
			commentcount	=> $commentcount,
		};

		my $theme = _checkTheme($user->{'journal_theme'});
		my $zoo   = getObject('Slash::Zoo');
		slashDisplay($theme, {
			articles	=> [{ day => $article->{date}, article => [ $disp_article ] }],
			uid		=> $article->{uid} || $user->{uid},
			is_friend	=> $zoo->isFriend($user->{uid}, $article->{uid}),
			back		=> -1,
			forward		=> 0,
			nickname	=> $user->{nickname},
		});
	}

	my $formats = $reader->getDescriptions('postmodes');
	my $format_select = createSelect('posttype', $formats, $posttype, 1);

	slashDisplay('journaledit', {
		article		=> $article,
		format_select	=> $format_select,
	});
}

sub _validFormkey {
	my(@checks) = @_ ? @_ : qw(max_post_check interval_check formkey_check);
	my $error;
	for (@checks) {
		last if formkeyHandler($_, 0, 0, \$error);
	}

	if ($error) {
		_printHead("mainhead");
		print $error;
		return 0;
	} else {
		# why does anyone care the length?
		getCurrentDB()->updateFormkey(0, length(getCurrentForm()->{article}));
		return 1;
	}
}

sub _printHead {
	my($head, $data, $edit_the_uid) = @_;
	my $title = getData($head, $data);
	header($title);

	$data->{menutype} ||= 'users';
	$data->{width} = '100%';
	$data->{title} = $title;

	if ($edit_the_uid) {
		my $reader = getObject('Slash::DB', { db_type => 'reader' });
		my $useredit = $data->{uid}
			? $reader->getUser($data->{uid})
			: getCurrentUser();
		$data->{useredit} = $useredit;
	}

	slashDisplay("journalhead", $data);
}

sub _checkTheme {
	my($theme)	= @_;

	my $constants	= getCurrentStatic();
	return $constants->{journal_default_theme} if !$theme;

	my $journal	= getObject('Slash::Journal');
	my $themes	= $journal->themes;

	return $constants->{journal_default_theme}
		unless grep $_ eq $theme, @$themes;
	return $theme;
}

createEnvironment();
main();

#=======================================================================
package Slash::Journal::SOAP;
use Slash::Utility;

sub modify_entry {
	my($class, $id) = (shift, shift);
	my $journal   = getObject('Slash::Journal');
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $slashdb   = getCurrentDB();

	return if $user->{is_anon};

	my $entry = $journal->get($id);
	return unless $entry->{id};
	my $form = _save_params(1, @_) || {};

	for (keys %$form) {
		$entry->{$_} = $form->{$_} if defined $form->{$_};
	}

	no strict 'refs';
	my $saveArticle = *{ $user->{state}{packagename} . '::saveArticle' };
	my $newid = $saveArticle->($journal, $constants, $user, $entry, $slashdb, 1);
	return $newid == $id ? $id : undef;
}

sub add_entry {
	my $class = shift;
	my $journal   = getObject('Slash::Journal');
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $slashdb   = getCurrentDB();

	return if $user->{is_anon};

	my $form = _save_params(0, @_) || {};

	$form->{posttype}		||= $user->{posttype};
	$form->{tid}			||= $constants->{journal_default_topic};
	$form->{journal_discuss}	= $user->{journal_discuss}
		unless defined $form->{journal_discuss};

	no strict 'refs';
	my $saveArticle = *{ $user->{state}{packagename} . '::saveArticle' };
	$slashdb->createFormkey('journal');
	my $reader = getObject('Slash::DB', { db_type => 'reader' }); # We need it for the eventual display
	my $id = $saveArticle->($journal, $constants, $user, $form, $reader, 1);
	return $id;
}


sub delete_entry {
	my($class, $id) = @_;
	my $journal   = getObject('Slash::Journal');
	my $user      = getCurrentUser();

	return if $user->{is_anon};
	return $journal->remove($id);
}

sub get_entry {
	my($class, $id) = @_;
	my $journal   = getObject('Slash::Journal');
	my $constants = getCurrentStatic();
	my $slashdb   = getCurrentDB();

	my $entry = $journal->get($id);
	return unless $entry->{id};

	$entry->{nickname} = $slashdb->getUser($entry->{uid}, 'nickname');
	$entry->{url} = "$constants->{absolutedir}/~" . fixparam($entry->{nickname}) . "/journal/$entry->{id}";
	$entry->{discussion_id} = delete $entry->{'discussion'};
	$entry->{discussion_url} = "$constants->{absolutedir}/comments.pl?sid=$entry->{discussion_id}"
		if $entry->{discussion_id};
	$entry->{body} = delete $entry->{article};
	$entry->{subject} = delete $entry->{description};
	return $entry;
}

sub get_entries {
	my($class, $uid, $num) = @_;
	my $journal   = getObject('Slash::Journal');
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $slashdb   = getCurrentDB();

	$user		= $slashdb->getUser($uid, ['nickname']) if $uid;
	$uid		= $uid || $user->{uid};
	my $nickname	= $user->{nickname};
	return unless $uid;

	my $articles = $journal->getsByUid($uid, 0, $num || 15);
	my @items;
	for my $article (@$articles) {
		push @items, {
			subject	=> $article->[2],
			url	=> "$constants->{absolutedir}/~" . fixparam($nickname) . "/journal/$article->[3]",
			id	=> $article->[3],
		};
	}
	return \@items;
}

# this WILL NOT remain in journal.pl, it is here only temporarily, until
# we get the more generic SOAP interface up and running, and then the Search
# SOAP working (this will be in the Search SOAP API, i think)
sub get_uid_from_nickname {
	my($self, $nick) = @_;
	return getCurrentDB->getUserUID($nick);
}

sub _save_params {
	my %form;
	my $modify = shift;

	# if only two params, they are description and article
	if (!$modify && @_ == 2) {
		@form{qw(description article)} = @_;

	# bad interface, but accept a list of pairs, in order
	# deprecated
	} elsif (!(@_ % 2)) {
		my %data = @_;
		@form{qw(description article journal_discuss posttype tid)} =
			@data{qw(subject body discuss posttype tid)};

	# accept a hashref
	} elsif ((@_ == 1) && (UNIVERSAL::isa($_[0], 'HASH'))) {
		@form{qw(description article journal_discuss posttype tid)} =
			@{$_[0]}{qw(subject body discuss posttype tid)};
	} else {
		return;
	}

	$form{journal_discuss} = 'discuss' if $form{journal_discuss} == 1;

	return \%form;
}

1;

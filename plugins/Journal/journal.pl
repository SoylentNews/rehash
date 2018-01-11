#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use utf8;
use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants qw(:messages :web);
use Slash::Display;
use Slash::Hook;
use Slash::Utility;
use Slash::XML;
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub main {
	my $journal   = getObject('Slash::Journal');
	my $constants = getCurrentStatic();
	my $journal_reader = getObject('Slash::Journal', { db_type => 'reader' });
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();
	my $gSkin     = getCurrentSkin();


	if ($constants->{journal_soap_enabled}) {
		my $r = Apache2::RequestUtil->request;
		if ($r->headers_in->{'SOAPAction'}) {
			require SOAP::Transport::HTTP;
			# security problem previous to 0.55
			if (SOAP::Lite->VERSION gt 0.55) {
				if ($user->{state}{post}) {
					$r->method('POST');
				}
				$user->{state}{packagename} = __PACKAGE__;
				return SOAP::Transport::HTTP::Apache->dispatch_to
					('Slash::Journal::SOAP')->handle(
						Apache2::RequestUtil->request->pnotes('filterobject')
					);
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
		save		=> [ $user_ok,		\&saveArticle		],
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

	# XXXSECTIONTOPICS might want to check if these calls are still necessary after section topics is complete
	# this is a hack, think more on it, OK for now -- pudge
	# I think this needs to be part of cramming all possible
	# user init code into getUser(). Saving a few nanoseconds
	# here and there is not worth my staying up until 11 PM
	# trying to figure out what fields get set where. - Jamie
	# agreed, but the problem is that section is determined by header(),
	# and that determines color.  we could set the color in the
	# user init code, and then change it later in header() only
	# if section is defined, perhaps. -- pudge
	Slash::Utility::Anchor::getSkinColors();

	my $op = $form->{op} || '';
	$op = lc($op);

	if (!$op || !exists $ops{$op} || !$ops{$op}[ALLOWED]) {
		$op = 'default';
	}

	# hijack feeds
	if ($form->{content_type} && $form->{content_type} =~ $constants->{feed_types}) {
		if ($op eq 'top' && $top_ok) {
			displayTopRSS($journal, $constants, $user, $form, $journal_reader, $gSkin);
		} else {
			displayRSS($journal, $constants, $user, $form, $journal_reader, $gSkin);
		}
	} else {
		$ops{$op}[FUNCTION]->($journal, $constants, $user, $form, $journal_reader, $gSkin);
		my $r;
		if ($r = Apache2::RequestUtil->request) {
			return if $r->header_only;
		}
		footer();
	}
}

sub displayTop {
	my($journal, $constants, $user, $form, $journal_reader) = @_;
	my $journals;

	_printHead('mainhead') or return;

	# this should probably be in a separate template, so the site admins
	# can select the order themselves -- pudge
	if ($constants->{journal_top_recent}) {
		$journals = $journal_reader->topRecent;
		slashDisplay('journaltop', { journals => $journals, type => 'recent' });
	}

	if ($constants->{journal_top_posters}) {
		$journals = $journal_reader->top;
		slashDisplay('journaltop', { journals => $journals, type => 'top' });
	}

	if ($constants->{journal_top_friend}) {
		my $zoo   = getObject('Slash::Zoo');
		$journals = $zoo->topFriends;
		slashDisplay('journaltop', { journals => $journals, type => 'friend' });
	}

	print getData('journalfoot');
}

sub displayFriends {
	my($journal, $constants, $user, $form, $journal_reader, $gSkin) = @_;

	redirect("$gSkin->{rootdir}/search.pl?op=journals") 
		if $user->{is_anon};

	_printHead('mainhead') or return;

	my $zoo = getObject('Slash::Zoo');
	my $friends = $zoo->getFriendsWithJournals;
	if (@$friends) {
		slashDisplay('journalfriends', { friends => $friends });
	} else {
		print getData('nofriends');
		slashDisplay('searchusers');
	}

	print getData('journalfoot');
}

sub searchUsers {
	my($journal, $constants, $user, $form, $journal_reader) = @_;

	if (!$form->{nickname}) {
		_printHead('mainhead') or return;
		slashDisplay('searchusers');
		return;
	}

	my $results = $journal_reader->searchUsers($form->{nickname});

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
	_printHead('mainhead') or return;

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

	print getData('journalfoot');
}

sub displayRSS {
	my($journal, $constants, $user, $form, $journal_reader, $gSkin) = @_;

	my($juser, $articles);
	if ($form->{uid} || $form->{nick}) {
		my $uid = $form->{uid} ? $form->{uid} : $journal_reader->getUserUID($form->{nick});
		$juser  = $journal_reader->getUser($uid);
	}
	$juser ||= $user;

	if ($form->{op} && $form->{op} eq 'friendview') {
		my $zoo   = getObject('Slash::Zoo');
		my $uids  = $zoo->getFriendsUIDs($juser->{uid});
		$articles = $journal_reader->getsByUids($uids, 0, $constants->{journal_default_display} * 3);
	} else {
		# give an extra 3 * the normal HTML default display ... we can
		# make a new var if we really need one -- pudge
		$articles = $journal_reader->getsByUid($juser->{uid}, 0, $constants->{journal_default_display} * 3);
	}

	my @items;
	for my $article (@$articles) {
		my($nickname, $juid);
		if ($form->{op} && $form->{op} eq 'friendview') {
			$nickname = $article->[8];
			$juid     = $article->[7];
		} else {
			$nickname = $juser->{nickname};
			$juid     = $juser->{uid};
		}

		push @items, {
			story		=> {
				'time'		=> $article->[0],
				uid		=> $juid,
				tid		=> $article->[5],
			},
			title		=> $article->[2],
			description	=> $journal_reader->fixJournalText($article->[1], $article->[4], $juser),
			'link'		=> root2abs() . '/~' . fixparam($nickname) . "/journal/$article->[3]",
		};
	}

	my $rss_html = $constants->{journal_rdfitemdesc_html} && (
		($user->{is_admin} || isAdmin($juser))
			||
		($constants->{journal_rdfitemdesc_html} == 1)
			||
		($constants->{journal_rdfitemdesc_html} > 1 && ($user->{is_subscriber} || ($constants->{subscribe} && isSubscriber($juser))))
			||
		($constants->{journal_rdfitemdesc_html} > 2 && !$user->{is_anon})
	);

	my($title, $journals, $link);
	if ($form->{op} && $form->{op} eq 'friendview') {
		$title    = "$juser->{nickname}'s Friends'";
		$journals = 'Journals';
		$link     = '/journal/friends/';
	} else {
		$title    = "$juser->{nickname}'s";
		$journals = 'Journal';
		$link     = '/journal/';
	}

	xmlDisplay($form->{content_type} => {
		channel => {
			title		=> "$title $journals",
			description	=> "$title $constants->{sitename} $journals",
			'link'		=> root2abs() . '/~' . fixparam($juser->{nickname}) . $link,
		},
		image	=> 1,
		items	=> \@items,
		rdfitemdesc		=> $constants->{journal_rdfitemdesc},
		rdfitemdesc_html	=> $rss_html,
	});
}

sub displayTopRSS {
	my($journal, $constants, $user, $form, $journal_reader, $gSkin) = @_;

	my $journals;
	my $type = '';
	if ($form->{type} && $form->{type} eq 'count' && $constants->{journal_top_posters}) {
		$type = 'count';
		$journals = $journal_reader->top;
	} elsif ($form->{type} && $form->{type} eq 'friends' && $constants->{journal_top_friend}) {
		$type = 'friends';
		my $zoo   = getObject('Slash::Zoo');
		$journals = $zoo->topFriends;
	} elsif ($constants->{journal_top_recent}) {
		$journals = $journal_reader->topRecent;
	}

	my @items;
	for my $entry (@$journals) {
		my $title = $type eq 'count'
			? "[$entry->[1]] $entry->[0] entries"
			: $type eq 'friends'
				? "[$entry->[1]] $entry->[0] friends"
				: "[$entry->[1]] $entry->[5]";

		$title =~ s/s$// if $entry->[0] == 1 && ($type eq 'count' || $type eq 'friends');

		push @items, {
			title	=> $title,
			'link'	=> "$gSkin->{absolutedir}/~" . fixparam($entry->[1]) . "/journal/"
		};
	}

	xmlDisplay($form->{content_type} => {
		channel => {
			title		=> "$constants->{sitename} Journals",
			description	=> "Top $constants->{journal_top} Journals",
			'link'		=> "$gSkin->{absolutedir}/journal.pl?op=top",
		},
		image	=> 1,
		items	=> \@items
	});
}

sub displayArticleFriends {
	my($journal, $constants, $user, $form, $journal_reader) = @_;
	my($date, $forward, $back, $nickname, $uid);
	my @collection;
	my $zoo = getObject('Slash::Zoo');

	if ($form->{uid} || $form->{nick}) {
		$uid		= $form->{uid} ? $form->{uid} : $journal_reader->getUserUID($form->{nick});
		$nickname	= $journal_reader->getUser($uid, 'nickname');
	} else {
		$nickname	= $user->{nickname};
		$uid		= $user->{uid};
	}

	_printHead('friendhead', { nickname => $nickname, uid => $uid }) or return;

	# clean it up
	my $start = fixint($form->{start}) || 0;
	my $uids = $zoo->getFriendsUIDs($uid);
	my $articles = $journal_reader->getsByUids($uids, $start,
		$constants->{journal_default_display} + 1
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

	my $topics = $journal_reader->getTopics;
	for my $article (@$articles) {
		my $commentcount = $article->[6]
			? $journal_reader->getDiscussion($article->[6], 'commentcount')
			: 0;

		# should get comment count, too -- pudge
		push @collection, {
			article		=> $journal_reader->fixJournalText($article->[1], $article->[4], $article->[7]),
			date		=> $article->[0],
			description	=> strip_subject($article->[2]),
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

	print getData('journalfoot');
}

sub displayArticle {
	my($journal, $constants, $user, $form, $journal_reader) = @_;
	my($date, $forward, $back, @sorted_articles, $nickname, $uid, $karma, $discussion);
	my $collection = {};
	my $user_change = {};
	my $head_data = {};

	if ($form->{uid} || $form->{nick}) {
		$uid		= $form->{uid} ? $form->{uid} : $journal_reader->getUserUID($form->{nick});
		my $tmpuser	= $journal_reader->getUser($uid, ['nickname', 'karma']);
		$nickname	= $tmpuser->{nickname};
		$karma		= $tmpuser->{karma};
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
		$karma		= $user->{karma};
	}

	$head_data->{nickname} = $nickname;
	$head_data->{uid} = $uid;

	if (isAnon($uid)) {
		# Don't write user_change.
		return displayFriends(@_);
	}
	
	if ($uid == $user->{uid}) {
		_printHead('myhead', $head_data, 1) or return;
	} else {
		_printHead('userhead', $head_data, 1) or return;
	}

	# clean it up
	my $start = fixint($form->{start}) || 0;
	my $articles = $journal_reader->getsByUid($uid, $start,
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

	my $topics = $journal_reader->getTopics;
	$date = 'initial_value_which_matches_nothing';
	for my $article (@$articles) {
		my($date_current) = timeCalc($article->[0], "%A %B %d, %Y");
		if ($date ne $date_current) {
			push @sorted_articles, $collection if $date && (keys %$collection);
			$collection = {};
			$date = $date_current;
			$collection->{day} = $article->[0];
		}

		my $commentcount;
		if ($form->{id}) {
			$discussion = $journal_reader->getDiscussion($article->[6]);
			$commentcount = $article->[6]
				? $discussion->{commentcount}
				: 0;
		} else {
			$commentcount = $article->[6]
				? $journal_reader->getDiscussion($article->[6], 'commentcount')
				: 0;
		}

		my $stripped_article = $journal_reader->fixJournalText($article->[1], $article->[4], $uid);
		$stripped_article = noFollow($stripped_article)
			unless $karma > $constants->{goodkarma};

		# should get comment count, too -- pudge
		push @{$collection->{article}}, {
			article		=> $stripped_article,
			date		=> $article->[0],
			description	=> strip_subject($article->[2]),
			topic		=> $topics->{$article->[5]},
			discussion	=> $article->[6],
			id		=> $article->[3],
			commentcount	=> $commentcount,
		};
	}

	push @sorted_articles, $collection;
	my $theme = _checkTheme($journal_reader->getUser($uid, 'journal_theme'));

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

	print getData('journalfoot');

	if ($show_discussion) {
		printComments($discussion);
	}

	if ($user_change && %$user_change) {
		my $slashdb = getCurrentDB();
		$slashdb->setUser($user->{uid}, $user_change);
	}
}

sub doSaveArticle {
	my($journal, $constants, $user, $form, $journal_reader, $gSkin, $rkey) = @_;

	$form->{promotetype} ||= 'publish';

	$form->{description} =~ s/[\r\n].*$//s;  # strip anything after newline
	my $description = $form->{description};

	# from comments.pl
	for ($description, $form->{article}) {
		my $d = decode_entities($_);
		$d =~ s/&#?[a-zA-Z0-9]+;//g;	# remove entities we don't know
		if ($d !~ /[^\h\v\p{Cc}\p{Cf}]/) {		# require SOME non-whitespace
			return(getData('no_desc_or_article'), 1);
		}
	}

	return(getData('submit_must_enable_comments'), 1)
		if !$form->{id} &&
		   ($form->{promotetype} eq "publicize" || $form->{promotetype} eq "publish") &&
		   (!$form->{journal_discuss} || $form->{journal_discuss} eq 'disabled');

	unless ($rkey) {
		my $reskey = getObject('Slash::ResKey');
		$rkey = $reskey->key('journal');
	}

	unless ($rkey->use) {
		return($rkey->errstr, $rkey->failure);
	}

	my $slashdb = getCurrentDB();
	if ($form->{id}) {
		my %update;
		my $article = $journal_reader->get($form->{id});
		return(getData('submit_must_enable_comments'), 1)
			if !$article->{discussion} &&
			   ($form->{promotetype} eq "publicize" || $form->{promotetype} eq "publish") &&
			   (!$form->{journal_discuss} || $form->{journal_discuss} eq 'disabled');

		# note: comments_on is a special case where we are
		# only turning on comments, not saving anything else
		if ($constants->{journal_comments}
			&& $form->{journal_discuss}
			&& $form->{journal_discuss} ne 'disabled'
			&& !$article->{discussion}
		) {
			my $rootdir = $gSkin->{rootdir};
			if ($form->{comments_on}) {
				$description = $article->{description};
				$form->{tid} = $article->{tid};
			}

			my $commentstatus = $form->{journal_discuss};

			my $did = $slashdb->createDiscussion({
				kind	=> 'journal',
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
			for (qw(article tid posttype submit promotetype)) {
				$update{$_} = $form->{$_} if defined $form->{$_};
			}
			$update{description} = $description;
		}

		$journal->set($form->{id}, \%update);
		
		slashHook('journal_save_success', { id => $form->{id} });

	} else {
		my $id = $journal->create($description,
			$form->{article}, $form->{posttype}, $form->{tid}, $form->{promotetype});

		unless ($id) {
			return getData('create_failed');
		}

		if ($form->{url_id}) {
			my $url_id = $form->{url_id};
			my $globjid = $slashdb->getGlobjidCreate('journals', $id);
			$slashdb->addUrlForGlobj($url_id, $globjid);
		}

		if ($constants->{journal_comments} && $form->{journal_discuss} ne 'disabled') {
			my $rootdir = $gSkin->{rootdir};
			my $did = $slashdb->createDiscussion({
				kind	=> 'journal',
				title	=> $description,
				topic	=> $form->{tid},
				commentstatus	=> $form->{journal_discuss},
				url	=> "$rootdir/~" . fixparam($user->{nickname}) . "/journal/$id",
			});
			$journal->set($id, { discussion => $did });
		}

		slashHook('journal_save_success', { id => $id });

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

			$messages->create($friends, MSG_CODE_JOURNAL_FRIEND, $data) if @$friends;
		}

		$form->{id} = $id;
	}

	if ($constants->{validate_html}) {
		my $validator = getObject('Slash::Validator');
		my $article = $journal_reader->get($form->{id});
		my $strip_art = $journal_reader->fixJournalText($article->{article}, $article->{posttype}, $user);
		$validator->isValid($strip_art, {
			data_type	=> 'journal',
			data_id		=> $form->{id},
			message		=> 1
		}) if $validator;
	}

	return 0;
}

sub doEditArticle {
	my($journal, $constants, $user, $form, $journal_reader, $gSkin) = @_;
	# This is where we figure out what is happening
	my $article = {};
	my $posttype;

	$article = $journal_reader->get($form->{id}) if $form->{id};
	# you go now!
	if ($article->{uid} && $article->{uid} != $user->{uid}) {
		return getData('noedit');
	}

	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('journal');

	if ($form->{state}) {
		$rkey->touch;
		return $rkey->errstr if $rkey->death;

		$article->{date}	||= localtime;
		$article->{article}	= $form->{article};
		$article->{description}	= $form->{description};
		$article->{tid}		= $form->{tid};
		$posttype		= $form->{posttype};
	} else {
		$rkey->create or return $rkey->errstr;
		
		unless ($article->{id}) {
			$article->{article}	= $form->{article};
			$article->{description}	= $form->{description};
		}

		$posttype = $article->{posttype};
	}
	$posttype ||= $user->{'posttype'};

	if ($article->{article}) {
		my $strip_art = $journal_reader->fixJournalText($article->{article}, $posttype, $user);

		my $commentcount = $article->{discussion}
			? $journal_reader->getDiscussion($article->{discussion}, 'commentcount')
			: 0;

		# For preview only, strips are okay as long as we don't do them to $article
		my $disp_article = {
			article		=> $strip_art,
			date		=> $article->{date},
			description	=> $article->{description}, # strip_subject in the template is sufficient
			topic		=> $journal_reader->getTopic($article->{tid}),
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

	my $formats = $journal_reader->getDescriptions('postmodes');
	if ($user->{is_admin} || $user->{acl}{journal_admin_tags}) {
		$formats->{77} = 'Full HTML Mode';
	}

	my $format_select = createSelect('posttype', $formats, $posttype, 1);

	slashDisplay('journaledit', {
		article		=> $article,
		format_select	=> $format_select,
		rkey		=> $rkey
	});

	return 0;
}

sub saveArticle {
	my($journal, $constants, $user, $form, $journal_reader, $gSkin) = @_;

	my($err, $retry) = doSaveArticle(@_[0..5]);
	if ($err) {
		_printHead('mainhead') or return;
		print $err;
		if ($retry) {
			my $err = doEditArticle(@_);
			print $err if $err;
		}
		print getData('journalfoot');
		return 1;
	}

	# to make sure we are not faster than replication is, pass
	# the $journal object as the $journal_reader object
	displayArticle($journal, $constants, $user, $form, $journal);
}

sub editArticle {
	my($journal, $constants, $user, $form, $journal_reader, $gSkin) = @_;

	_printHead('mainhead') or return;

	my($err) = doEditArticle(@_);
	print $err if $err;

	print getData('journalfoot');
}

sub editPrefs {
	my($journal, $constants, $user, $form, $journal_reader) = @_;

	my $nickname	= $user->{nickname};
	my $uid		= $user->{uid};
	_printHead('myhead', { nickname => $nickname, uid => $uid, menutype => 'prefs' }) or return;

	my $theme	= _checkTheme($user->{'journal_theme'});
	my $themes	= $journal_reader->themes;
	slashDisplay('journaloptions', {
		default		=> $theme,
		themes		=> $themes,
	});

	print getData('journalfoot');
}

sub setPrefs {
	my($journal, $constants, $user, $form, $journal_reader) = @_;

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
	my($journal, $constants, $user, $form, $journal_reader) = @_;

	my $uid = $form->{uid} || $user->{uid};
	if (isAnon($uid)) {
		return displayFriends(@_);
	}

	my $list 	= $journal_reader->list($uid);
	my $themes	= $journal_reader->themes;
	my $theme	= _checkTheme($user->{'journal_theme'});
	my $nickname	= $form->{uid}
		? $journal_reader->getUser($form->{uid}, 'nickname')
		: $user->{nickname};

	if ($uid == $user->{uid}) {
		_printHead('myhead', { nickname => $nickname, uid => $uid }, 1) or return;
	} else {
		_printHead('userhead', { nickname => $nickname, uid => $uid }, 1) or return;
	}		
		

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

	print getData('journalfoot');
}

sub articleMeta {
	my($journal, $constants, $user, $form, $journal_reader) = @_;

	if ($form->{id}) {
		my $reskey = getObject('Slash::ResKey');
		my $rkey = $reskey->key('journal');
		if ($rkey->create) {
			my $article = $journal_reader->get($form->{id});
			_printHead('mainhead') or return;
			slashDisplay('meta', { article => $article, rkey => $rkey });
			print getData('journalfoot');
			return 1;
		}
	}

	listArticle(@_);
}

sub removeArticle {
	my($journal, $constants, $user, $form, $journal_reader) = @_;

	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('journal');

	# don't bother printing reskey error, since it will confuse
	# most people: we show the list regardless -- pudge
	if ($rkey->use) {
		for my $id (grep { $_ = /^del_(\d+)$/ ? $1 : 0 } keys %$form) {
			$journal->remove($id);
		}
	}

	listArticle(@_);
}

sub _printHead {
	my($head, $data, $edit_the_uid) = @_;
	my $title = getData($head, $data);

	my $links = {
		title		=> $title,
		'link'		=> {
			uid		=> $data->{uid},
			nickname	=> $data->{nickname}
		}
	};
	header($links) or return;

	$data->{menutype} ||= 'users';
	$data->{width} = '100%';
	$data->{title} = $title;

	my $user = getCurrentUser();

	if ($edit_the_uid) {
		my $reader = getObject('Slash::DB', { db_type => 'reader' });
		my $useredit = $data->{uid}
			? $reader->getUser($data->{uid})
			: $user;
		$data->{useredit} = $useredit;
	}
	
	$data->{return_url} = "//".$ENV{HTTP_HOST}.$ENV{REQUEST_URI};

	slashDisplay('journalhead', $data);
}

sub _checkTheme {
	my($theme)	= @_;

	my $constants	= getCurrentStatic();
	return $constants->{journal_default_theme} if !$theme;

	my $journal_reader = getObject('Slash::Journal', { db_type => 'reader' });
	my $themes	= $journal_reader->themes;

	return $constants->{journal_default_theme}
#		unless grep $_ eq $theme, @$themes;
#	return $theme;
# Why do we have journal themes that overide what others see.
# Theme design is now in main themes. Do not need seperate journal theme.
}

createEnvironment();
main();

#=======================================================================
package Slash::Journal::SOAP;
use Slash::Utility;

sub modify_entry {
	my($class, $id) = (shift, shift);

	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('journal-soap');
	$rkey->create or return;

	my $journal   = getObject('Slash::Journal');
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $gSkin     = getCurrentSkin();
	my $journal_reader = getObject('Slash::Journal', { db_type => 'reader' });

	return if $user->{is_anon};

	$id =~ s/\D+//g;
	my $entry = $journal_reader->get($id);
	return unless $entry->{id};

	my $form = _save_params(1, @_) || {};
	for (keys %$form) {
		$entry->{$_} = $form->{$_} if defined $form->{$_};
	}

	no strict 'refs';
	my $saveArticle = *{ $user->{state}{packagename} . '::doSaveArticle' };
	my($err) = $saveArticle->($journal, $constants, $user, $entry, $journal_reader, $gSkin, $rkey);
	return if $err;

	return $id;
}

sub add_entry {
	my($class) = (shift);

	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('journal-soap');
	$rkey->create;
	return if $rkey->failure;

	my $journal   = getObject('Slash::Journal');
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $gSkin     = getCurrentSkin();
	my $journal_reader = getObject('Slash::Journal', { db_type => 'reader' });

	return if $user->{is_anon};

	my $form = _save_params(0, @_) || {};
	$form->{posttype}		||= $user->{posttype};
	$form->{tid}			||= $constants->{journal_default_topic};
	$form->{journal_discuss}	= $user->{journal_discuss}
		unless defined $form->{journal_discuss};

	no strict 'refs';
	my $saveArticle = *{ $user->{state}{packagename} . '::doSaveArticle' };
	my($err) = $saveArticle->($journal, $constants, $user, $form, $journal_reader, $gSkin, $rkey);
	return if $err;

	return $form->{id};
}


sub delete_entry {
	my($class, $id) = @_;

	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('journal-soap');
	$rkey->create or return;

	my $journal   = getObject('Slash::Journal');
	my $user      = getCurrentUser();

	return if $user->{is_anon};

	$id =~ s/\D+//g;

	$rkey->use or return;

	return $journal->remove($id);
}

sub get_entry {
	my($class, $id) = @_;

	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('journal-soap-get');
	$rkey->createuse or return;

	my $journal   = getObject('Slash::Journal');
	my $journal_reader = getObject('Slash::Journal', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $slashdb   = getCurrentDB();
	my $gSkin     = getCurrentSkin();

	$id =~ s/\D+//g;
	return unless $id;

	my $entry = $journal_reader->get($id);
	return unless $entry->{id};

	my $absolutedir = root2abs();

	$entry->{nickname} = $journal_reader->getUser($entry->{uid}, 'nickname');
	$entry->{url} = "$absolutedir/~" . fixparam($entry->{nickname}) . "/journal/$entry->{id}";
	$entry->{discussion_id} = delete $entry->{'discussion'};
	$entry->{discussion_url} = "$absolutedir/comments.pl?sid=$entry->{discussion_id}"
		if $entry->{discussion_id};
	$entry->{body} = delete $entry->{article};
	$entry->{subject} = delete $entry->{description};
	return $entry;
}

sub get_entries {
	my($class, $uid, $num) = @_;

	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('journal-soap-get');
	$rkey->createuse or return;

	my $journal_reader = getObject('Slash::Journal', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $gSkin     = getCurrentSkin();

	$uid =~ s/\D+//g;
	$num =~ s/\D+//g;

	$user		= $journal_reader->getUser($uid, ['nickname']) if $uid;
	$uid		= $uid || $user->{uid};
	my $nickname	= $user->{nickname};

	return unless $uid;

	my $absolutedir = root2abs();

	my $articles = $journal_reader->getsByUid($uid, 0, $num || 15);
	my @items;
	for my $article (@$articles) {
		push @items, {
			subject	=> $article->[2],
			url	=> "$absolutedir/~" . fixparam($nickname) . "/journal/$article->[3]",
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

	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('journal-soap-get');
	$rkey->createuse or return;

	return getCurrentDB()->getUserUID($nick);
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

	if ($form{journal_discuss}) {
		my $user = getCurrentUser();
		$form{journal_discuss} = $user->{journal_discuss} eq 'disabled'
			? 'enabled'
			: $user->{journal_discuss};
	} elsif (defined $form{journal_discuss}) {
		$form{journal_discuss} = 'disabled';
	}

	$form{tid} =~ s/\D+//g;

	return \%form;
}

1;

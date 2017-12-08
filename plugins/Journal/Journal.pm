# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Journal;

use strict;

use Slash;
use Slash::Constants qw(:messages);
use Slash::Utility;

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

sub set {
	my($self, $id, $values) = @_;
	my $uid = getCurrentUser('uid');
	my $constants = getCurrentStatic();

	return unless $self->sqlSelect('id', 'journals', "uid=$uid AND id=$id");

	my(%j1, %j2);
	%j1 = %$values;

	# verify we're allowed to do this at some point, ie can't unset if it's already set
	if (defined $j1{promotetype} && $constants->{journal_allow_journal2submit} ) {
		my $cur_promotetype = $self->get($id, "promotetype");
		if ($cur_promotetype eq "publish" && $j1{promotetype} eq "post") {
			$j1{promotetype} = "publish";
		}
		if ($cur_promotetype eq "publicize") {
			$j1{promotetype} = "publicize";
		}
	}

	$j2{article}   = delete $j1{article};
	$j2{introtext} = $self->getIntrotext($id, $j2{article}, ($j1{posttype}||0), $uid) if $j2{article};
	$j1{"-last_update"} = 'now()';

	$self->sqlUpdate('journals', \%j1, "id=$id") if keys %j1;
	$self->sqlUpdate('journals_text', \%j2, "id=$id") if $j2{article};
}

sub getsByUid {
	my($self, $uid, $start, $limit, $id) = @_;
	my $order = "ORDER BY date DESC";
	$order .= " LIMIT $start, $limit" if $limit;
	my $where = "uid = $uid AND journals.id = journals_text.id";
	$where .= " AND journals.id = $id" if $id;

	my $answer = $self->sqlSelectAll(
		'date, article, description, journals.id, posttype, tid, discussion',
		'journals, journals_text',
		$where,
		$order
	);
	return $answer;
}

sub getsByUids {
	my($self, $uids, $start, $limit, $options) = @_;
	return unless @$uids;
	my $t_o = $options->{titles_only};
	my $uids_list = join(",", @$uids);
	my $order = "ORDER BY journals.date DESC";
	my $order_limit = $order;
	$order_limit .= " LIMIT $start, $limit" if $limit;

	# The list may be quite large, potentially hundreds or even
	# thousands of users, forming a significant portion of all the
	# journal-writing users on a site.  We're splitting this select
	# up into three separate ones.  The uid_date_id index lets this
	# first select succeed without even hitting the data (and yes
	# the ",id" component of that index is required for this to be
	# true, at least on the version of MySQL and the data set I
	# tested it on for Slashdot).

	# First, get the list of journal IDs for the UIDs given.
	my $journals_hr = $self->sqlSelectAllKeyValue(
		'id, uid',
		'journals',
		"uid IN ($uids_list)",
		$order_limit);
	return unless $journals_hr && %$journals_hr;

	# Second, pull nickname from users for the uids identified.
	my @uids_found = sort keys %{ { map { ($_, 1) } values %$journals_hr } };
	my $uids_found_list = join(',', @uids_found);
	my $uid_nick_hr = $self->sqlSelectAllKeyValue(
		'uid, nickname',
		'users',
		"uid IN ($uids_found_list)");

	# Third, pull the required data from journals, and if necessary
	# journals_text.  If in the last few moments any journals from
	# the first select have become unavailable, that's OK, we just
	# won't return any information about them.
	# Oh, and yes, it is _insane_ that this method returns an
	# arrayref of nine-element arrayrefs normally, but an arrayref
	# of hashrefs if called with the "titles_only" option.
	# That should be fixed someday.
	my @journal_ids_found = sort keys %$journals_hr;
	my $journal_ids_found_list = join(',', @journal_ids_found);
	my $columns =	$t_o	? 'id, description'
				: 'date, article, description, journals.id,
				   posttype, tid, discussion, journals.uid';
	my $tables =	$t_o	? 'journals'
				: 'journals, journals_text';
	my $where =	$t_o	? "journals.id IN ($journal_ids_found_list)"
				: "journals.id IN ($journal_ids_found_list)
				   AND journals_text.id = journals.id";
	my $retval;
	if ($t_o) {
		$retval = $self->sqlSelectAllHashrefArray(
			$columns, $tables, $where, $order);
		for my $hr (@$retval) {
			my $id = $hr->{id};
			my $uid = $journals_hr->{$id};
			$hr->{nickname} = $uid_nick_hr->{$uid};
		}
	} else {
		$retval = $self->sqlSelectAll(
			$columns, $tables, $where, $order);
		for my $ar (@$retval) {
			my $uid = $ar->[7];
			push @$ar, $uid_nick_hr->{$uid};
		}
	}
	return $retval;
}

sub list {
	my($self, $uid, $limit) = @_;
	$uid ||= 0;	# no SQL syntax error
	my $order = "ORDER BY date DESC";
	$order .= " LIMIT $limit" if $limit;
	my $answer = $self->sqlSelectAll('id, date, description', 'journals', "uid = $uid", $order);

	return $answer;
}

sub listFriends {
	my($self, $uids, $limit) = @_;
	my $list = join(",", @$uids);
	my $order = "ORDER BY date DESC";
	$order .= " LIMIT $limit" if $limit;
	my $answer = $self->sqlSelectAll('id, journals.date, description, journals.uid, users.nickname',
		'journals,users',
		"journals.uid in ($list) AND users.uid=journals.uid", $order);

	return $answer;
}

sub create {
	my($self, $description, $article, $posttype, $tid, $promotetype) = @_;

	return unless $description;
	return unless $article;
	return unless $tid;

	my $constants = getCurrentStatic();

	# These variable names are not accurate for IPv6.
	my $user = getCurrentUser();
	my $subnetid;
	my $ipid;

	# Handle subnet ID
	if (exists $user->{srcids}{24}) {
		$subnetid = get_srcid_sql_in($user->{srcids}{24});
	} elsif (exists $user->{srcids}{56}) {
		$subnetid = get_srcid_sql_in($user->{srcids}{56});
	}

	# and now the IPID
	if (exists $user->{srcids}{32}) {
		$ipid = get_srcid_sql_in($user->{srcids}{32});
	} elsif (exists $user->{srcids}{64}) {
		$ipid = get_srcid_sql_in($user->{srcids}{64});
	}

	$self->sqlInsert("journals", {
		uid		=> $user->{uid},
		description	=> $description,
		tid		=> $tid,
		-date		=> 'NOW()',
		posttype	=> $posttype,
		promotetype	=> $promotetype,
		-srcid_24	=> $subnetid,
		-srcid_32	=> $ipid,
	});

	my($id) = $self->getLastInsertId({ table => 'journals', prime => 'id' });
	return unless $id;

	my $introtext = $self->getIntrotext(0, $article, $posttype, $user->{uid}) || '';
	$self->sqlInsert("journals_text", {
		id        => $id,
		article   => $article,
		introtext => $introtext
	});

	my($date) = $self->sqlSelect('date', 'journals', "id=$id");
	my $slashdb = getCurrentDB();
	$slashdb->setUser($user->{uid}, { journal_last_entry_date => $date });

	my $dynamic_blocks = getObject('Slash::DynamicBlocks');
	if ($dynamic_blocks) {
		$dynamic_blocks->setUserBlock('journal', $user->{uid});
	}

	return $id;
}

sub remove {
	my($self, $id) = @_;
	my $uid = getCurrentUser('uid');

	my $journal = $self->get($id);
	return unless $journal->{uid} == $uid;

	my $count = $self->sqlDelete("journals", "uid=$uid AND id=$id");
	if ($count == 0) {
		# Return value 0E0 means "no rows deleted" (i.e. this user owns
		# no such journal) and undef means "error."  Either way, abort.
		return;
	}
	$self->sqlDelete("journals_text", "id=$id");

	if ($journal->{discussion}) {
#		my $slashdb = getCurrentDB();
		# if has been submitted as story or submission, don't
		# delete the discussion
#		my $kind = $self->getDiscussion($journal->{discussion}, 'dkid');
#		my $kinds = $self->getDescriptions('discussion_kinds');

		# discussions can be re-used in the hose and stories ...
		# just leave it alone entirely -- pudge 2008-11-17

		# set to disabled only if the journal has not been
		# converted to a journal-story (it will get re-enabled
		# later if it is converted to a journal-story)
#		if ($kinds->{$kind} eq 'journal') {
#			$slashdb->setDiscussion($journal->{discussion}, {
#				commentstatus	=> 'disabled',
#			});
#		} else {
#			$slashdb->deleteDiscussion($journal->{discussion});
#		}
	}

	my $date = $self->sqlSelect('MAX(date)', 'journals', "uid=$uid");
	if ($date) {
		$date = $self->sqlQuote($date);
	} else {
		$date = "NULL";
	}
	my $slashdb = getCurrentDB();
	$slashdb->setUser($uid, { -journal_last_entry_date => $date });

	if (getCurrentStatic()->{plugin}{FireHose}) {
		$slashdb->sqlUpdate('firehose',
			{ public => 'no' },
			"type='journal' AND srcid=$id"
		);
	}

	my $dynamic_blocks = getObject('Slash::DynamicBlocks');
	if ($dynamic_blocks) {
		$dynamic_blocks->setUserBlock('journal', $uid);
	}

	return $count;
}

sub top {
	my($self, $limit) = @_;
	$limit ||= getCurrentStatic('journal_top') || 10;
	$self->sqlConnect;

	my $sql = <<EOT;
SELECT count(j.uid) AS c, u.nickname, j.uid, MAX(date), MAX(id)
FROM journals AS j, users AS u
WHERE j.uid = u.uid
GROUP BY u.nickname ORDER BY c DESC
LIMIT $limit
EOT

	my $losers = $self->{_dbh}->selectall_arrayref($sql);

	my $sql2 = sprintf <<EOT, join (',', map { $_->[4] } @$losers);
SELECT id, description
FROM journals
WHERE id IN (%s)
EOT
	my $losers2 = $self->{_dbh}->selectall_hashref($sql2, 'id');

	for (@$losers) {
		$_->[5] = $losers2->{$_->[4]}{description};
	}

	return $losers;
}

sub topRecent {
	my($self, $limit) = @_;
	$limit ||= getCurrentStatic('journal_top') || 10;
	my $min_karma = getCurrentStatic('journal_sb_min_karma') || 0;
	$self->sqlConnect;

	my $sql = <<EOT;
SELECT count(j.id), u.nickname, u.uid, MAX(j.date) AS date, MAX(id)
FROM journals AS j, users AS u, users_info AS ui
WHERE j.uid = u.uid
AND j.uid = ui.uid
AND ui.karma >= $min_karma
GROUP BY u.nickname
ORDER BY date DESC
LIMIT $limit
EOT

	my $losers = $self->{_dbh}->selectall_arrayref($sql);
	return [ ] if !$losers || !@$losers;

	my $id_list = join(", ", map { $_->[4] } @$losers);
	my $loserid_hr = $self->sqlSelectAllHashref(
		"id",
		"id, description",
		"journals",
		"id IN ($id_list)");

	for my $loser (@$losers) {
		$loser->[5] = $loserid_hr->{$loser->[4]}{description};
	}

	return $losers;
}

sub getRecent {
	my ($self, $limit, $uid) = @_;
	my $where = "1 = 1 ";

	unless(
		(defined $limit) &&
		($limit =~ /^\d+$/) &&
		($limit > 0) &&
		($limit < 51)
	) {
		$limit = 20;
	}

	if( (defined $uid) && ($uid =~ /^\d+$/) ) {
		my $uid_q = $self->sqlQuote($uid);
		$where = " uid = $uid_q ";
	}

	my $journals = $self->sqlSelectAllHashref(
		"id",
		"*",
		"journals",
		"$where",
		"ORDER BY date DESC LIMIT $limit"
	);
	return { } if !$journals || !%$journals;
	return $journals;
}

sub themes {
	my($self) = @_;
	my $uid = getCurrentUser('uid');
	my $sql;
	$sql .= "SELECT name from journal_themes";
	$self->sqlConnect;
	my $themes = $self->{_dbh}->selectcol_arrayref($sql);

	return $themes;
}

sub searchUsers {
	my($self, $nickname) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	if (my $uid = $slashdb->getUserUID($nickname)) {
		if ($self->sqlSelect('uid', 'journals', "uid=$uid")) {
			return $uid;
		} else {
			return $slashdb->getUser($uid);
		}
	}

	my($search, $find, $uids, $jusers, $ids, $journals, @users);
	# This is only important if it exists, aka calling the search db user -Brian
	$search	= getObject("Slash::Search", $constants->{search_db_user}) or return;
	$find	= $search->findUsers(
		{query => $nickname}, 0,
		getCurrentStatic('search_default_display') + 1
	);
	return unless @$find;

	$uids   = join(" OR ", map { "uid=$_->{uid}" } @$find);
	$jusers = $self->sqlSelectAllHashref(
		'uid', 'uid, MAX(id) as id', 'journals', $uids, 'GROUP BY uid'
	);

	$ids      = join(" OR ", map { "id=$_->{id}" } values %$jusers);
	$journals = $self->sqlSelectAllHashref(
		'uid', 'uid, id, date, description', 'journals', $ids
	);

	for my $user (sort { lc $a->{nickname} cmp lc $b->{nickname} } @$find) {
		my $uid  = $user->{uid};
		my $nick = $user->{nickname};
		if (exists $journals->{$uid}) {
			push @users, [
				$nick, $uid, $journals->{$uid}{date},
				$journals->{$uid}{description},
				$journals->{$uid}{id},
			];
		} else {
			push @users, [$nick, $uid];
		}
	}

	return \@users;
}

sub get {
	my($self, $id, $val) = @_;
	my $answer;

	# XXX I have no idea what this does ... what is "comment"?
	if ((ref($val) eq 'ARRAY')) {
		# the grep was failing before, is this right?
		my @articles = grep /^comment$/, @$val;
		my @other = grep !/^comment$/, @$val;
		if (@other) {
			my $values = join ',', @other;
			$answer = $self->sqlSelectHashref($values, 'journals', "id=$id");
		}
		if (@articles) {
			$answer->{comment} = $self->sqlSelect('article', 'journals_text', "id=$id");
		}
	} elsif ($val) {
		if ($val eq 'article' || $val eq 'introtext') {
			($answer) = $self->sqlSelect($val, 'journals_text', "id=$id");
		} else {
			($answer) = $self->sqlSelect($val, 'journals', "id=$id");
		}
	} else {
		$answer = $self->sqlSelectHashref('*', 'journals', "id=$id");
		($answer->{article}) = $self->sqlSelect('article', 'journals_text', "id=$id");
		($answer->{introtext}) = $self->sqlSelect('introtext', 'journals_text', "id=$id");
	}

	return $answer;
}

sub updateStoryFromJournal {
	my($self, $src_journal, $options) = @_;
	my $slashdb = getCurrentDB();

	my $stoid = $slashdb->sqlSelect("stoid", "journal_transfer", "id=$src_journal->{id}");
	return unless $stoid;

	my $data = {};
	$data->{title} = $src_journal->{description};
	my $text = $self->fixJournalText($src_journal->{article}, $src_journal->{posttype}, $src_journal->{uid});
	($data->{introtext}, $data->{bodytext}) = $self->splitJournalTextForStory($text);

	$data->{topics_chosen} = $options->{topics_chosen} if $options->{topics_chosen};
	$slashdb->updateStory($stoid, $data);
}

sub createSubmissionFromJournal {
	my($self, $src_journal, $options) = @_;
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	$options ||= {};

	my $journal_user = $slashdb->getUser($src_journal->{uid});

	my $story = $src_journal->{article};
	
	$story =~ s/^$Slash::Utility::Data::WS_RE2+//io;
	$story =~ s/$Slash::Utility::Data::WS_RE2+$//io;
	
	$story = $self->fixJournalText($story, $src_journal->{posttype}, $src_journal->{uid});
	#perhaps need more string cleanup from submit.pl's findStory here

	my $primaryskid = $constants->{journal2submit_skid} || $constants->{mainpage_skid};
	my $fakeemail = "mailto:$journal_user" if $journal_user->{fakeemail};

	my $submission = {
		email		=> $journal_user->{fakeemail},
		uid		=> $journal_user->{uid},
		name		=> $journal_user->{nickname},
		story		=> $story,
		subj		=> $src_journal->{description},
		tid		=> $src_journal->{tid},
		primaryskid 	=> $primaryskid,
		journal_id 	=> $src_journal->{id},
		discussion 	=> $src_journal->{discussion},
		by		=> $options->{submission_param}{by}     || $journal_user->{nickname},
		# $fakeemail can be undef, but setSubmission can't set a param to NULL
		# (schema forbids, and setSubmission is too dumb not to try). so the
		# empty string is a last resort. the better fix would be to fix
		# setSubmission and/or _genericSet to handle undef values for params
		# the way setStory does, by deleting the param row if any.
		by_url 		=> $options->{submission_param}{by_url} || $journal_user->{homepage} || $fakeemail || '',
	};

	my $sub_param = $options->{submission_param} || {};

	foreach (keys %$sub_param) {
		$submission->{$_} = $sub_param->{$_} if !defined $submission->{$_};
	}

	my $subid = $slashdb->createSubmission($submission);
	if ($subid) {
		$self->logJournalTransfer($src_journal->{id}, $subid);
	} else {
		print STDERR ("Failed attempting to transfer journal id: $src_journal->{id}\n");
	}
	return $subid;
}

sub createStoryFromJournal { 
	my($self, $src_journal, $options) = @_;
	$options ||= {};

	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	my $journal_user = $slashdb->getUser($src_journal->{uid});

	my $text = $self->fixJournalText($src_journal->{article}, $src_journal->{posttype}, $src_journal->{uid});
	my($intro, $body) = $self->splitJournalTextForStory($text);

	my $skid = $options->{skid} || $constants->{journal2submit_skid} || $constants->{mainpage_skid};

	my $fakeemail = "mailto:$journal_user->{fakeemail}" if $journal_user->{fakeemail};

	my $story_param = $options->{story_param} || {};

	my %story = (
		title		=> $src_journal->{description},
		uid		=> $journal_user->{uid},
		introtext	=> $intro,
		bodytext	=> $body,
		'time'		=> $slashdb->getTime(), 
		commentstatus	=> 'enabled',
		journal_id 	=> $src_journal->{id},
		by		=> $options->{story_param}{by}     || $journal_user->{nickname},
		by_url 		=> $options->{story_param}{by_url} || $journal_user->{homepage} || $fakeemail,
		discussion	=> $src_journal->{discussion},
	);

	$story{neverdisplay} = $options->{neverdisplay} if $options->{neverdisplay};

	foreach (keys %$story_param) {
		$story{$_} = $story_param->{$_} if !defined $story{$_};
	}

	# this sets weight (front page, etc.) ... not sure which weight to use;
	# 20/10 is for section-only, 40/30 is for mainpage

	my $skin = $slashdb->getSkin($skid);
	my $skin_nexus = $skin->{nexus};
 	
	# May need to change
	$story{topics_chosen} = $options->{topics_chosen}
		|| { $src_journal->{tid} => 10, $skin_nexus => 20 }; 
 	
	my $topiclist = $slashdb->getTopiclistFromChosen(
 		$story{topics_chosen}
	);

	my $admindb = getObject('Slash::Admin');
 	$story{relatedtext} = $admindb->relatedLinks(
		"$story{title} $story{introtext} $story{bodytext}",
 	       $topiclist,
 	       '', # user's nickname
 	       '', # user's uid
        );

	my $sid = $slashdb->createStory(\%story);
	my $stoid = $slashdb->getStoidFromSidOrStoid($sid);
	$self->logJournalTransfer($src_journal->{id}, 0, $stoid);
}

# this is kindof a "dumb" split for stories, we do a smarter split for
# firehose (see getIntrotext), but it can't be rejoined into intro/body
# like this one can -- pudge

sub splitJournalTextForStory {
	my($self, $text) = @_;
	my($intro, $body) = split(/<br>|<\/p>/i, $text, 2);

	for ($intro, $body) {
		s/^$Slash::Utility::Data::WS_RE2+//io if defined;
		s/$Slash::Utility::Data::WS_RE2+$//io if defined;

		$_ = balanceTags($_);
	}

	return($intro, $body);
}

sub logJournalTransfer {
	my($self, $id, $subid, $stoid) = @_;
	my $slashdb = getCurrentDB();
	$stoid ||=0;
	$subid ||=0;
	return if !$id;

	$slashdb->sqlInsert("journal_transfer", { id => $id, subid => $subid, stoid => $stoid, updated => 0 });
}

sub hasJournalTransferred {
	my($self, $id) = @_;
	return $self->sqlCount("journal_transfer", "id=$id")
}

sub promoteJournal {
	my($data) = @_;
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $journal = getObject('Slash::Journal'); 

	return 0 unless $constants->{journal_allow_journal2submit};
	return 0 unless $data && $data->{id};
	my $src_journal = $journal->get($data->{id});
	if ($src_journal->{promotetype} eq "publicize") {
		my $transferred = $journal->hasJournalTransferred($data->{id});
		if ($user->{acl}{journal_to_story}) {
			unless ($transferred) {
				$journal->createStoryFromJournal($src_journal, { neverdisplay => 1} );
			} else {
				$journal->updateStoryFromJournal($src_journal);	
			}
		} else {
			unless ($transferred) {
				if ($constants->{journal_create_submission}) {
					$journal->createSubmissionFromJournal($src_journal);
				}
			} else {
				# Apply edit?
			}
		}
	}
	return 1;
}


sub updateTransferredJournalDiscussions {
	my($self) = @_;

	my $journal_stories = $self->sqlSelectAllHashrefArray(
		'journal_transfer.id, stories.stoid, discussion, ' .
			'primaryskid, tid, sid, time, title',
		'journal_transfer, stories, story_text',
		'journal_transfer.stoid != 0 AND journal_transfer.updated = 0 AND ' .
			'journal_transfer.stoid = stories.stoid AND ' .
			'stories.time <= NOW() AND '.
			'stories.stoid = story_text.stoid'
	);

	for my $journal_story (@$journal_stories) {
		my $url	= $self->getUrlFromSid(
			$journal_story->{sid},
			$journal_story->{primaryskid},
			$journal_story->{tid}
		);

		my $discussion = {
			title		=> $journal_story->{title},
			url		=> $url,
			ts		=> $journal_story->{'time'}
		};

		if ($self->setDiscussion($journal_story->{discussion}, $discussion)) {
			$self->sqlUpdate('journal_transfer', {
				updated	=> 1,
			}, 'id=' . $self->sqlQuote($journal_story->{id}));
		}
	}

	# if was made a story, then story deleted, we revert discussion data
	# to point to journal (IF stoid = 0 AND updated = 1)
	# ts, title, url from journal
	# revert dkid to 'journal'
	# blank out stoid, sid, primaryskid
	my $revert_journals = $self->sqlSelectAllHashrefArray(
		'journal_transfer.id, journals.discussion, journals.description, journals.date, journals.uid, nickname',
		'journal_transfer, journals, users',
		'journal_transfer.stoid = 0 AND journal_transfer.updated = 1 AND ' .
			'journal_transfer.id = journals.id AND ' .
			'users.uid = journals.uid'
	);

	my $constants = getCurrentStatic();
	for my $revert_journal (@$revert_journals) {
		my $url = "$constants->{rootdir}/~" .
			fixparam($revert_journal->{nickname}) .
			"/journal/$revert_journal->{id}";

		my $discussion = {
			title		=> $revert_journal->{description},
			url		=> $url,
			ts		=> $revert_journal->{date},
			stoid		=> 0,
			sid		=> '',
			primaryskid	=> 0,
			kind		=> 'journal',
		};

		if ($self->setDiscussion($revert_journal->{discussion}, $discussion)) {
			$self->sqlUpdate('journal_transfer', {
				updated	=> 0,
			}, 'id=' . $self->sqlQuote($revert_journal->{id}));
		}
	}
}


{
my $linebreak = qr{(?:
	<br>\s*<br> |
	</?p> |
	</(?:
		div | (?:block)?quote | [oud]l
	)>
)}x;
my $min_chars = 50;
my $max_chars = 500;

sub getIntrotext {
	my($self, $id, $bodytext, $posttype, $uid) = @_;
	return unless $id || $bodytext;

	if ($id && (!$bodytext || !$posttype)) {
		my $article = $self->get($id);
		$bodytext ||= $article->{article};
		$posttype ||= $article->{posttype};
	}
	return unless $bodytext && $posttype;

	my $strip_art = $self->fixJournalText($bodytext, $posttype, $uid);

	my $intro;
	if (length($strip_art) < $min_chars) {
		$intro = $strip_art;
	} else {
		$intro = $1 if $strip_art =~ m/^(.{$min_chars,$max_chars})?$linebreak/s;
	}

	$intro ||= chopEntity($strip_art, $max_chars);
	local $Slash::Utility::Data::approveTag::admin = 1;
	$intro = strip_html($intro);
	$intro = balanceTags($intro, { admin => 1 });
	$intro = addDomainTags($intro);

	return $intro;
} }


sub fixJournalText {
	my($self, $text, $mode, $user) = @_;
	return unless $text && $mode;

	$user ||= getCurrentUser();
	unless (ref $user) {
		if ($user eq '-1') { # force admin
			$user = { seclev => 100 };
		} else {
			$user = $self->getUser($user);
		}
	}

	my $admin = 0;
	# 77 = "full" HTML, 2 = normal HTML
	if ($mode == 77) {
		if (isAdmin($user) || $user->{acl}{journal_admin_tags}) {
			$admin = 1;
		}
		$mode = 2;
	}

	local $Slash::Utility::Data::approveTag::admin = 1
		if $admin;
	my $stripped = strip_mode($text, $mode);

	my $balanced = balanceTags($stripped, {
		deep_nesting => 1,
		deep_su      => 1,
		admin        => ($admin ? 1 : 0)
	});

	return $balanced;
}


sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if !$ENV{MOD_PERL} && $self->{_dbh};
}


1;

__END__

# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Slash::Journal - Journal system splace

=head1 SYNOPSIS

	use Slash::Journal;

=head1 DESCRIPTION

This is a port of Tangent's journal system.

Blah blah blah.

=head1 AUTHOR

Brian Aker, brian@tangent.org

=head1 SEE ALSO

perl(1).

=cut

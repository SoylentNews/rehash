# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Journal;

use strict;
use DBIx::Password;
use Slash;
use Slash::Constants qw(:messages);
use Slash::Utility;

use vars qw($VERSION);
use base 'Exporter';
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# On a side note, I am not sure if I liked the way I named the methods either.
# -Brian
sub new {
	my($class, $user) = @_;
	my $self = {};

	my $slashdb = getCurrentDB();
	my $plugins = $slashdb->getDescriptions('plugins');
	return unless $plugins->{'Journal'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;

	return $self;
}

sub set {
	my($self, $id, $values) = @_;
	my $uid = $ENV{SLASH_USER};

	return unless $self->sqlSelect('id', 'journals', "uid=$uid AND id=$id");

	my(%j1, %j2);
	%j1 = %$values;
	$j2{article}  = delete $j1{article};

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
		'journals, journals_text', $where, $order
	);
	return $answer;
}

sub getsByUids {
	my($self, $uids, $start, $limit, $options) = @_;
	my $list = join(",", @$uids);
	my $answer;
	my $order = "ORDER BY journals.date DESC";
	$order .= " LIMIT $start, $limit" if $limit;

	# Note - if the *.uid table in the where clause is journals, MySQL
	# does a table scan on journals_text.  Make it users and it
	# correctly uses an index on uid.  Logically they are the same and
	# the DB *really* should be smart enough to pick up on that, but no.
	# At least, not in MySQL 3.23.49a.

	if ($options->{titles_only}) {
		my $where = "users.uid IN ($list) AND users.uid=journals.uid";

		$answer = $self->sqlSelectAllHashrefArray(
			'description, id, nickname',
			'journals, users',
			$where,
			$order
		);
	} else {
		my $where = "users.uid IN ($list) AND journals.id=journals_text.id AND users.uid=journals.uid";

		$answer = $self->sqlSelectAll(
			'journals.date, article, description, journals.id,
			 posttype, tid, discussion, users.uid, users.nickname',
			'journals, journals_text, users',
			$where,
			$order
		);
	}
	return $answer;
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
	my $answer = $self->sqlSelectAll('id, journals.date, description, journals.uid, users.nickname', 'journals,users', "journals.uid in ($list) AND users.uid=journals.uid", $order);

	return $answer;
}

sub create {
	my($self, $description, $article, $posttype, $tid) = @_;

	return unless $description;
	return unless $article;
	return unless $tid;

	my $uid = $ENV{SLASH_USER};
	$self->sqlInsert("journals", {
		uid		=> $uid,
		description	=> $description,
		tid		=> $tid,
		-date		=> 'now()',
		posttype	=> $posttype,
	});

	my($id) = $self->getLastInsertId('journals', 'id');
	return unless $id;

	$self->sqlInsert("journals_text", {
		id		=> $id,
		article 	=> $article,
	});

	my($date) = $self->sqlSelect('date', 'journals', "id=$id");
	my $slashdb = getCurrentDB();
	$slashdb->setUser($uid, { journal_last_entry_date => $date });

	return $id;
}

sub remove {
	my($self, $id) = @_;
	my $uid = $ENV{SLASH_USER};

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
		my $slashdb = getCurrentDB();
		$slashdb->deleteDiscussion($journal->{discussion});
	}

	my $date = $self->sqlSelect('MAX(date)', 'journals', "uid=$uid");
	if ($date) {
		$date = $self->sqlQuote($date);
	} else {
		$date = "NULL";
	}
	my $slashdb = getCurrentDB();
	$slashdb->setUser($uid, { -journal_last_entry_date => $date });
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
	$self->sqlConnect;

	my $sql = <<EOT;
SELECT count(j.id), u.nickname, u.uid, MAX(j.date) AS date, MAX(id)
FROM journals AS j, users AS u
WHERE j.uid = u.uid
GROUP BY u.nickname
ORDER BY date DESC
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

sub themes {
	my($self) = @_;
	my $uid = $ENV{SLASH_USER};
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
		my $uid  = $user->[2];
		my $nick = $user->[1];
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

	if ((ref($val) eq 'ARRAY')) {
		# the grep was failing before, is this right?
		my @articles = grep /^comment$/, @$val;
		my @other = grep !/^comment$/, @$val;
		if (@other) {
			my $values = join ',', @other;
			$answer = $self->sqlSelectHashref($values, 'journals', "id=$id");
		}
		if (@articles) {
			$answer->{comment} = $self->sqlSelect('article', 'journals', "id=$id");
		}
	} elsif ($val) {
		if ($val eq 'article') {
			($answer) = $self->sqlSelect('article', 'journals', "id=$id");
		} else {
			($answer) = $self->sqlSelect($val, 'journals', "id=$id");
		}
	} else {
		$answer = $self->sqlSelectHashref('*', 'journals', "id=$id");
		($answer->{article}) = $self->sqlSelect('article', 'journals_text', "id=$id");
	}

	return $answer;
}

sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if !$ENV{GATEWAY_INTERFACE} && $self->{_dbh};
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

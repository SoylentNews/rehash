# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Zoo;

use strict;
use DBIx::Password;
use Slash;
use Slash::Constants qw(:people :messages);
use Slash::Utility;
use Slash::DB::Utility;

use vars qw($VERSION @EXPORT);
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# "There ain't no justice" -Niven
# We can try. 	-Brian

sub new {
	my($class, $user) = @_;
	my $self = {};

	my $slashdb = getCurrentDB();
	my $plugins = $slashdb->getDescriptions('plugins');
	return unless $plugins->{'Zoo'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;

	return $self;
}

sub getFriends {
	_get(@_, "friend");
}

sub getFof {
	_getAssociation(@_, "fof");
}

sub getEof {
	_getAssociation(@_, "eof");
}

sub getFriendsUIDs {
	_getUIDs(@_, "friend");
}

sub getFoes {
	_get(@_, "foe");
}

sub getFoesUIDs {
	_getUIDs(@_, "foe");
}

sub getFreaks {
	my ($self) = @_;
	_getOpposite(@_, "foe");
}

sub getFans {
	_getOpposite(@_, "friend");
}

sub getAll {
	my($self, $uid, $type) = @_;

	my $people = $self->sqlSelectAll(
		'users.uid, nickname',
		'people, users',
		"people.uid = $uid AND person = users.uid",
		" ORDER BY nickname "
	);
	return $people;
}

sub countFriends {
	my($self, $uid) = @_;
	$self->sqlCount('people', "type='friend'  AND uid = $uid");
}

sub countFoes {
	my($self, $uid) = @_;
	$self->sqlCount('people', "type='foe' AND uid = $uid");
}

sub count {
	my($self, $uid) = @_;
	$self->sqlCount('people', "uid = $uid AND type != NULL");
}

sub _get {
	my($self, $uid, $type) = @_;

	my $people = $self->sqlSelectAll(
		'users.uid, nickname, journal_last_entry_date',
		'people, users',
		"people.uid = $uid AND type =\"$type\" AND person = users.uid",
		" ORDER BY nickname "
	);
	return $people;
}

sub _getAssociation {
	my($self, $uid, $type) = @_;

	my $people = $self->sqlSelectAll(
		'users.uid, nickname, journal_last_entry_date',
		'people, users',
		"people.uid = $uid AND $type > 0 AND person = users.uid",
		" ORDER BY nickname "
	);
	return $people;
}

sub _getUIDs {
	my($self, $uid, $type) = @_;

	my $people = $self->sqlSelectColArrayref(
		'person',
		'people',
		"people.uid = $uid AND type ='$type' "
	);
	return $people;
}

# Still in my brain, this is left as a note -Brian
# This has a special reason for existing. Right now we
# can easily fetch info on friends and foes. Future
# features though will not have as easy of a time.
#sub getFriendInfo {
#	my($self, $people) = @_;
#
#	my $info = $self->sqlSelectAll(
#		'uid, nickname, journal_last_entry_date',
#		'users',
#		"uid IN (" . join(",", map { $_->[0] } @$people) . ")"
#		 ) if @$people;
#
#	return $info;
#}

sub _getOpposite {
	my($self, $uid, $type) = @_;

	my $people = $self->sqlSelectAll(
		'people.uid, nickname, journal_last_entry_date',
		'people, users',
		"person = $uid AND type =\"$type\" AND users.uid = people.uid",
		" ORDER BY nickname "
	);
	return $people;
}

sub setFriend {
	_set(@_, 'friend', FRIEND);
}

sub setFoe {
	_set(@_, 'foe', FOE);
}

sub _set {
	my($self, $uid, $person, $type, $const) = @_;
	my $slashdb = getCurrentDB();

	# First we do the main person
	if ($self->sqlSelect('uid', 'people', "uid = $uid AND person = $person")) {
		$self->sqlUpdate('people', { type => $type }, "uid = $uid AND person = $person");
	} else {
		$self->sqlInsert('people', { uid => $uid,  person => $person, type => $type });
	}
	$self->sqlInsert('people_log', { uid => $uid,  person => $person, type => $type, action => 'add' });
	my $people = $slashdb->getUser($uid, 'people');
	# First we clean up, then we reapply
	delete $people->{FRIEND()}{$person};

	delete $people->{FOE()}{$person};
	$people->{$const}{$person} = 1;
	$slashdb->setUser($uid, { people => $people });

	# Now we do the Fan/Foe
	my $s_type = $type eq 'foe' ? 'freak' : 'fan';
	my $s_const = $type eq 'foe' ? FREAK : FAN;
	if ($self->sqlSelect('uid', 'people', "uid = $person AND person = $uid")) {
		$self->sqlUpdate('people', { perceive => $s_type }, "uid = $person AND person = $uid");
	} else {
		$self->sqlInsert('people', { uid => $person,  person => $uid, perceive => $s_type });
	}
	$people = $slashdb->getUser($person, 'people');
	delete $people->{FAN()}{$uid};
	delete $people->{FREAK()}{$uid};
	$people->{$s_const}{$uid} = 1;
	$slashdb->setUser($person, { people => $people })

}

sub addFof {
	my($self, $uid, $person) = @_;
	my $slashdb = getCurrentDB();

	# First we do the main person
	if ($self->sqlSelect('uid', 'people', "uid = $uid AND person = $person")) {
		$self->sqlUpdate('people', { -fof => "fof+1" }, "uid = $uid AND person = $person");
	} else {
		$self->sqlInsert('people', { uid => $uid,  person => $person, fof => 1 });
	}
	my $people = $slashdb->getUser($uid, 'people');
	# First we clean up, then we reapply
	$people->{FOF()}{$person} += 1;
	$slashdb->setUser($uid, { people => $people });
}

sub addEof {
	my($self, $uid, $person) = @_;
	my $slashdb = getCurrentDB();

	# First we do the main person
	if ($self->sqlSelect('uid', 'people', "uid = $uid AND person = $person")) {
		$self->sqlUpdate('people', { '-eof' => "eof+1" }, "uid = $uid AND person = $person");
	} else {
		$self->sqlInsert('people', { uid => $uid,  person => $person, 'eof' => 1 });
	}
	my $people = $slashdb->getUser($uid, 'people');
	# First we clean up, then we reapply
	$people->{EOF()}{$person} += 1;
	$slashdb->setUser($uid, { people => $people });
}

sub deleteFof {
	my($self, $uid, $person) = @_;
	my $slashdb = getCurrentDB();

	# First we do the main person
	my $number = $self->sqlSelect('fof', 'people', "uid = $uid AND person = $person");
	if ($number <= 1) {
		$self->sqlUpdate('people', { fof => "0" }, "uid = $uid AND person = $person");
	} else {
		$self->sqlUpdate('people', { -fof => "fof - 1" }, "uid = $uid AND person = $person");
	}
	my $people = $slashdb->getUser($uid, 'people');
	# First we clean up, then we reapply
	if ($people->{FOF()}{$person} >= 1) {
		$people->{FOF()}{$person} -= 1;
	} else {
		delete $people->{FOF()}{$person};
	}
	$slashdb->setUser($uid, { people => $people });
}

sub deleteEof {
	my($self, $uid, $person) = @_;
	my $slashdb = getCurrentDB();

	# First we do the main person
	my $number = $self->sqlSelect('eof', 'people', "uid = $uid AND person = $person");
	if ($number <= 1) {
		$self->sqlUpdate('people', { 'eof' => "0" }, "uid = $uid AND person = $person");
	} else {
		$self->sqlUpdate('people', { '-eof' => "eof - 1" }, "uid = $uid AND person = $person");
	}
	my $people = $slashdb->getUser($uid, 'people');
	# First we clean up, then we reapply
	if ($people->{EOF()}{$person} >= 1) {
		$people->{EOF()}{$person} -= 1;
	} else {
		delete $people->{EOF()}{$person};
	}
	$slashdb->setUser($uid, { people => $people });
}

sub isFriend {
	my($self, $uid, $friend) = @_;
	return 0 unless $uid && $friend;
	my $cols  = "uid";
	my $table = "people";
	my $where = "uid=$uid AND person=$friend AND type = 'friend'";

	my $is_friend = $self->sqlSelect($cols, $table, $where);
	return $is_friend;
}

sub isFoe {
	my($self, $uid, $foe) = @_;
	return 0 unless $uid && $foe;
	my $cols  = "uid";
	my $table = "people";
	my $where = "uid=$uid AND person=$foe AND type = 'foe'";

	my $is_foe = $self->sqlSelect($cols, $table, $where);
	return $is_foe;
}

# This just really neutrilzes the relationship.
sub delete {
	my($self, $uid, $person) = @_;
	my $type = $self->sqlSelect('type', 'people', "uid=$uid AND person=$person");
	$self->sqlDo("UPDATE people SET type=NULL WHERE uid=$uid AND person=$person");
	$self->sqlInsert('people_log', { uid => $uid,  person => $person, type => $type, action => 'delete' });
	my $slashdb = getCurrentDB();
	my $people = $slashdb->getUser($uid, 'people');
	if ($people) {
		delete $people->{FRIEND()}{$person};
		delete $people->{FOE()}{$person};
		$slashdb->setUser($uid, { people => $people })
	}
	$self->sqlDo("UPDATE people SET perceive=NULL WHERE uid=$person AND person=$uid");
	$people = $slashdb->getUser($person, 'people');
	if ($people) {
		delete $people->{FAN()}{$uid};
		delete $people->{FREAK()}{$uid};
		$slashdb->setUser($person, { people => $people })
	}
}

sub topFriends {
	my($self, $limit) = @_;
	$limit ||= 10; # For sanity
	my $sql;
	$sql .= " SELECT count(person) as c, nickname, person ";
	$sql .= " FROM people, users ";
	$sql .= " WHERE person=users.uid AND type='friend' ";
	$sql .= " AND users.journal_last_entry_date IS NOT NULL ";
	$sql .= " GROUP BY nickname ";
	$sql .= " ORDER BY c DESC ";
	$self->sqlConnect;
	my $losers = $self->{_dbh}->selectall_arrayref($sql);
	$sql = "SELECT max(date) FROM journals WHERE uid=";
	for (@$losers) {
		my $date = $self->{_dbh}->selectrow_array($sql . $_->[2]);
		push @$_, $date;
	}

	return $losers;
}

sub getFriendsWithJournals {
	my($self) = @_;
	my $uid = $ENV{SLASH_USER};

	my($friends, $journals, $ids, %data);
	$friends = $self->sqlSelectAll(
		'u.nickname, j.person, MAX(jo.id) as id',
		'journals as jo, people as j, users as u',
		"j.uid = $uid AND j.person = u.uid AND j.person = jo.uid AND type='friend' AND u.journal_last_entry_date IS NOT NULL ",
		'GROUP BY u.nickname'
	);
	return [] unless @$friends;

	for my $friend (@$friends) {
		$ids .= "id = $friend->[2] OR ";
		$data{$friend->[2]} = [ @$friend[0, 1] ];
	}
	$ids =~ s/ OR $//;

	$journals = $self->sqlSelectAll(
		'date, description, id', 'journals', $ids
	);

	for my $journal (@$journals) {
		# tack on the extra data
		@{$data{$journal->[2]}}[2 .. 4] = @{$journal}[0 .. 2];
	}

	# pull it all back together
	return [ map { $data{$_} } sort { $b <=> $a } keys %data ];
}


sub getFriendsForMessage {
	my($self) = @_;
	my $code  = MSG_CODE_JOURNAL_FRIEND;
	my $uid   = $ENV{SLASH_USER};
	my $cols  = "pp.uid";
	my $table = "people AS pp, users_messages as um";
	my $where = <<SQL;
    pp.person = $uid AND pp.type='friend' AND pp.uid = um.uid 
AND um.code = $code  AND um.mode >= 0
SQL

# 	my $table = "people AS jf, users_param AS up1, users_param AS up2";
# 	my $where = "jf.person=$uid AND type='friend'
# 		AND  jf.uid=up1.uid AND jf.uid=up2.uid
# 		AND  up1.name = 'deliverymodes'      AND up1.value >= 0
# 		AND  up2.name = 'messagecodes_$code' AND up2.value  = 1";

	my $friends  = $self->sqlSelectColArrayref($cols, $table, $where);
	return $friends;
}

sub deleteZooJobs {
	my ($self, $list) = @_;
	$self->sqlDo("DELETE FROM people_log WHERE id IN (" . join(",", @$list) . ")");
}

sub getZooJobs {
	my ($self, $limit) = @_;
	$limit = "LIMIT $limit"
		if $limit;

	return $self->sqlSelectAllHashrefArray('*', 'people_log', '', "ORDER BY id " . $limit);
}


sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if !$ENV{GATEWAY_INTERFACE} && $self->{_dbh};
}


1;

__END__

# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Slash::Zoo - Zoo system splace

=head1 SYNOPSIS

	use Slash::Zoo;

=head1 DESCRIPTION

This is a port of Tangent's journal system.

Blah blah blah.

=head1 AUTHOR

Brian Aker, brian@tangent.org

=head1 SEE ALSO

perl(1).

=cut

# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Zoo;

use strict;
use DBIx::Password;
use Slash;
use Slash::Constants qw(:people :messages);

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

# "There ain't no justice" -Niven
# We can try. 	-Brian

# Get the details for relationships
sub getRelationships {
	my ($self, $uid, $type) = @_;
	return unless $uid;

	my $slashdb = getCurrentDB();
	my $people = $slashdb->getUser($uid, 'people');
	my @people;
	if ($type) {
		@people = keys %{$people->{$type}};
	} else {
		for my $type (keys %$people) {
			for (keys %{$people->{$type}}) {
				push @people, $_;
			}
		}
	}
	return [qw()] unless @people;
	@people = sort { $a <=> $b } @people;
	my $people_str = join(",", @people);

	return $self->sqlSelectAll(
		'uid, nickname, journal_last_entry_date',
		'users',
		"uid IN ($people_str)",
		'ORDER BY nickname');
}

# Get the details for relationships
sub getFriendsUIDs {
	my($self, $uid) = @_;
	return unless $uid;

	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $people = $uid == $user->{uid}
		? $user->{people}
		: $slashdb->getUser($uid, 'people');

	return [] if !$people || !$people->{FRIEND()};
	return [ keys %{$people->{FRIEND()}} ];
}

sub setFriend {
	my($self, $uid, $person) = @_;
	_set(@_, 'friend', FRIEND);
}

sub setFoe {
	my($self, $uid, $person) = @_;
	_set(@_, 'foe', FOE);
}

sub _set {
	my($self, $uid, $person, $type, $const) = @_;
	my $slashdb = getCurrentDB();

#Removed this, since when we make the relationship it will now swap whatever bits we 
#need swapped, this no longer matters. -Brian
#	# Lets see if we need to wipe out a relationship first....
#	my $current_standing = $self->sqlSelectHashref('uid, type', 'people', "uid = $uid AND person = $person");
#	# We need to check to see if type has value to make sure we are not looking at fan or freak
#	$self->delete($uid, $person, $current_standing->{type})
#		if ($current_standing && $current_standing->{type});

	# Make sure $person actually exists.
	return unless $self->sqlSelect('uid', 'users', "uid=$person");

	# First we do the main person
	# We insert to make sure a position exists for this relationship and then we update.
	# If I ever removed freak/fan from the table this could be done as a replace.
	# XXX This should be a transaction.
	$self->sqlInsert('people', { uid => $uid,  person => $person }, { ignore => 1});
	$self->sqlUpdate('people', { type => $type }, "uid = $uid AND person = $person");
	my $people = $self->rebuildUser($uid);
	$slashdb->setUser($uid, { people => $people });

	# Now we do the Fan/Foe
	# We insert to make sure a position exists for this relationship and then we update.
	# If I ever removed freak/fan from the table this could be done as a replace.
	my $s_type = $type eq 'foe' ? 'freak' : 'fan';
	my $s_const = $type eq 'foe' ? FREAK : FAN;
	$self->sqlInsert('people', { uid => $person,  person => $uid }, { ignore => 1});
	$self->sqlUpdate('people', { perceive => $s_type }, "uid = $person AND person = $uid");
	# XXX transaction should end here I think

	# Mark other users as dirty (needing to be changed) as 
	# appropriate, but do it a few at a time with a short
	# sleep between, to avoid bogging the master DB or
	# lagging its slave DBs.  Yes, this method is called
	# by interactive code, not (just) the backend, so I
	# don't really like adding the sleep(), but we still
	# need to do this.
	my $uid_ar = $self->sqlSelectColArrayref('uid', 'people',
		"person=$uid AND type='friend'");
	push @$uid_ar, $person;
	my $splice_count = 100;
	while (@$uid_ar) {
		my @uid_chunk = splice @$uid_ar, 0, $splice_count;
		my $uid_list = join (',', @uid_chunk);
		$self->sqlUpdate("users_info", { people_status => 'dirty' }, "uid IN ($uid_list)");
		$self->setUser_delete_memcached($uid_ar);
		Time::HiRes::sleep(0.2);
	}
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

# This just really neutralizes the relationship.
sub delete {
	my($self, $uid, $person, $type) = @_;

	$self->sqlUpdate("people", { type => undef }, "uid=$uid AND person=$person");
	$self->sqlUpdate("people", { perceive => undef }, "uid=$person AND person=$uid");

	# Cleanup
	my $people = $self->rebuildUser($uid);
	$self->setUser($uid, { people => $people });

	my $uid_ar = $self->sqlSelectColArrayref('uid', 'people',
		"person=$uid AND type='friend'");
	push @$uid_ar, $person;
	my $uid_list = join (',', @$uid_ar);
	$self->sqlUpdate("users_info", { people_status => 'dirty' }, "uid IN ($uid_list)");
	$self->setUser_delete_memcached($uid_ar);
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

sub count {
	my($self, $uid) = @_;
	$self->sqlCount('people', "uid = $uid AND type is not NULL");
} 


sub getFriendsWithJournals {
	my($self) = @_;
	my $uid = getCurrentUser('uid');

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
	my $uid   = getCurrentUser('uid');
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

sub getZooUsersForProcessing {
	my($self) = @_;
	my $people = $self->sqlSelectColArrayref('uid', 'users_info', "people_status='dirty'");

	return $people;
}

sub rebuildUser {
	my($self, $uid) = @_;
	my $data = $self->sqlSelectAllHashrefArray('*', 'people', "uid = $uid");
	my $people;

	my @friends;
	if ($data) {
		for (@$data) {
			if ($_->{type} && $_->{type} eq 'friend') {
				$people->{FRIEND()}{$_->{person}} = 1;
				push @friends, $_->{person};
			} elsif ($_->{type} && $_->{type} eq 'foe') {
				$people->{FOE()}{$_->{person}} = 1;
			}
			if ($_->{perceive} && $_->{perceive} eq 'fan') {
				$people->{FAN()}{$_->{person}} = 1;
			} elsif ($_->{perceive} && $_->{perceive} eq 'freak') {
				$people->{FREAK()}{$_->{person}} = 1;
			}
		}
	}

	my $list = join (',', @friends);
	if (scalar(@friends) && $list) {
		$data = $self->sqlSelectAllHashrefArray('*', 'people', "uid IN ($list) AND type IS NOT NULL");
		for (@$data) {
			if ($_->{type} eq 'friend') {
				$people->{FOF()}{$_->{person}}{$_->{uid}} = 1;
			} elsif ($_->{type} eq 'foe') {
				$people->{EOF()}{$_->{person}}{$_->{uid}} = 1;
			}
		}
	}
	$people ||= {};
	return $people;
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

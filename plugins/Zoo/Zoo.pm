# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Zoo;

use strict;
use DBIx::Password;
use Slash;
use Slash::Constants ':people';
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

sub getFoes {
	_get(@_, "foe");
}

sub getFreaks {
	my ($self) = @_;
	_getOpposite(@_, "foe");
}

sub getFans {
	_getOpposite(@_, "friend");
}

sub _get {
	my($self, $uid, $type) = @_;

	my $people = $self->sqlSelectAll(
		'users.uid, nickname, journal_last_entry_date',
		'people, users',
		"people.uid = $uid AND type =\"$type\" AND person = users.uid"
	);
	return $people;
}

sub _getOpposite {
	my($self, $uid, $type) = @_;

	my $people = $self->sqlSelectAll(
		'people.uid, nickname, journal_last_entry_date',
		'people, users',
		"person = $uid AND type =\"$type\" AND users.uid = people.uid"
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

	$self->sqlDo("REPLACE INTO people (uid,person,type) VALUES ($uid, $person, '$type')");
	my $slashdb = getCurrentDB();
	my $people = $slashdb->getUser($uid, 'people');
	$people->{$person} = {$const};
	$slashdb->setUser($uid, { people => $people })
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

sub delete {
	my($self, $uid, $person) = @_;
	$self->sqlDo("DELETE FROM people WHERE uid=$uid AND person=$person");
	my $slashdb = getCurrentDB();
	my $people = $slashdb->getUser($uid, 'people');
	if ($people) {
		delete $people->{$person};
		$slashdb->setUser($uid, { people => $people })
	}
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

# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Search;

use strict;
use Slash::DB::Utility;

# BENDER: The laws of science be a harsh mistress.

$Slash::Search::VERSION = '0.01';
@Slash::Search::ISA = qw( Slash::DB::Utility );

#################################################################
sub new {
	my($class, $user) = @_;
	my $self = {};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect();

	return $self;
}

#################################################################
# Private method used by the search methods
sub _keysearch {
	my ($self, $keywords, $columns) = @_;

	my @words = split m/ /, $keywords;
	my $sql;
	my $x = 0;
	my $latch = 0;

	for my $word (@words) {
		next if length $word < 3;
		last if $x++ > 3;
		$sql .= " AND " if $sql;
		$sql .= " ( ";
		$latch = 0;
		for (@$columns) {
			$sql .= " OR " if $latch;
			$sql .= "$_ LIKE " . $self->{_dbh}->quote("%$word%"). " ";
			$latch++;
		}
		$sql .= " ) ";
	}
	# void context, does nothing?
	$sql = "0" unless $sql;

	return qq|($sql)|;
};


####################################################################################
# This has been changed. Since we no longer delete comments
# it is safe to have this run against stories.
sub findComments {
	my($self, $form) = @_;
	# select comment ID, comment Title, Author, Email, link to comment
	# and SID, article title, type and a link to the article
	my $sql;

	my $key = $self->_keysearch($form->{query}, ['subject', 'comment']);

	$sql = "SELECT section, stories.sid,";
	$sql .= " stories.uid as author, title, pid, subject, writestatus, time, date, comments.uid as uid, cid ";

	$sql .= "	  FROM stories, comments WHERE stories.sid=comments.sid ";

	$sql .= "	  AND $key " 
			if $form->{query};

	$sql .= "     AND stories.sid=" . $self->{_dbh}->quote($form->{sid}) 
			if $form->{sid};
	$sql .= "     AND points >= $form->{threshold} " 
			if $form->{threshold};
	$sql .= "     AND section=" . $self->{_dbh}->quote($form->{section}) 
			if $form->{section};
	$sql .= " ORDER BY date DESC, time DESC LIMIT $form->{min},20 ";


	my $cursor = $self->{_dbh}->prepare($sql);
	$cursor->execute;

	my $search = $cursor->fetchall_arrayref;
	return $search;
}

####################################################################################
sub findUsers {
	my($self, $form, $users_to_ignore) = @_;
	# userSearch REALLY doesn't need to be ordered by keyword since you
	# only care if the substring is found.
	my $sql;
	$sql .= 'SELECT fakeemail,nickname,uid ';
	$sql .= ' FROM users ';
	$sql .= ' WHERE seclev > 0 ';
	my $x = 0;
	for my $user (@$users_to_ignore) {
		$sql .= ' AND ' if $x != 0;
		$sql .= " nickname != " .  $self->{_dbh}->quote($user);
		$x++;
	}

	if ($form->{query}) {
		$sql .= ' AND ' if @$users_to_ignore;
		my $kw = $self->_keysearch($form->{query}, ['nickname', 'ifnull(fakeemail,"")']);
		$kw =~ s/as kw$//;
		$kw =~ s/\+/ OR /g;
		$sql .= " ($kw) ";
	}
	$sql .= " ORDER BY uid LIMIT $form->{min}, $form->{max}";
	my $sth = $self->{_dbh}->prepare($sql);
	$sth->execute;

	my $users = $sth->fetchall_arrayref;

	return $users;
}

####################################################################################
sub findStory {
	my($self, $form) = @_;
	my $sql;
	my $key = $self->_keysearch($form->{query}, ['title', 'introtext']);

	$sql .= "SELECT nickname,title,sid, time, commentcount,section ";

	$sql .= " FROM stories, users WHERE displaystatus>=0 ";

	$sql .= " AND $key " 
		 if $form->{query};

	if($form->{section}) {
		$sql .= qq| AND ((displaystatus = 0 and "$form->{section}" = "")|;
    $sql .= qq| OR (section = "$form->{section}" AND displaystatus >= 0))|;
	} 

	$sql .= " AND time < now() AND writestatus>=0 ";
	$sql .= " AND stories.uid=" . $self->{_dbh}->quote($form->{author})
		if $form->{author};
	$sql .= " AND section=" . $self->{_dbh}->quote($form->{section})
		if $form->{section};
	$sql .= " AND tid=" . $self->{_dbh}->quote($form->{topic})
		if $form->{topic};

	$sql .= " AND stories.uid=users.uid ";

	$sql .= " ORDER BY ";
	$sql .= " time DESC LIMIT $form->{min},$form->{max}";

	my $cursor = $self->{_dbh}->prepare($sql);
	$cursor->execute;
	my $stories = $cursor->fetchall_arrayref;

	return $stories;
}

#################################################################
sub DESTROY {
	my ($self) = @_;
	$self->{_dbh}->disconnect unless $ENV{GATEWAY_INTERFACE};
}

1;
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Slash::Search - Slash Search module

=head1 SYNOPSIS

  use Slash::Search;

=head1 DESCRIPTION

Slash search module.

Blah blah blah.

=head1 SEE ALSO

Slash(3).

=cut

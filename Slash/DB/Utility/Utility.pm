# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::DB::Utility;

use strict;
use Slash::Utility;
use DBIx::Password;
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# FRY: Bender, if this is some kind of scam, I don't get it.  You already
# have my power of attorney.

my $timeout = 30; # This should eventualy be a parameter that is configurable

########################################################
# Generic methods for libraries.
########################################################
#Class variable that stores the database handle
sub new {
	my($class, $user, @args) = @_;
	my $self = {};
	my $where;

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect();

	if ($self->can('init')) {
		# init should return TRUE for success, else
		# we abort
		return unless $self->init(@args);

		if (exists $self->{'_where'}) {
			for (keys %{ $self->{'_where'} }) {
				$where .= "$_=$self->{'_where'}{$_} AND ";
			}
			$where =~ s/ AND $//g if $where;
			$self->{_wheresql} = $where;
		}
	}

	return $self;
}

##################################################################
sub set {
	my($self, $id, $value) = @_;
	my $table = $self->{'_table'};
	my $prime = $self->{'_prime'};
	my $id_db = $self->sqlQuote($id);
	my $where;
	if ($self->{_wheresql}) {
		$where = "$prime=$id_db  AND " . $self->{_wheresql};
	} else {
		$where = "$prime=$id_db";
	}
	$self->sqlUpdate($table, $value, $where);
}

##################################################################
sub get {
	my($self, $id, $val) = @_;
	my($answer, $type);
	my $table = $self->{'_table'};
	my $prime = $self->{'_prime'};
	my $id_db = $self->sqlQuote($id);
	my $where;

	if ($self->{_wheresql}) {
		$where = "$prime=$id_db  AND " . $self->{_wheresql};
	} else {
		$where = "$prime=$id_db";
	}

	if (ref($val) eq 'ARRAY') {
		my $values = join ',', @$val;
		$answer = $self->sqlSelectHashref($values, $table, $where);
	} elsif ($val) {
		($answer) = $self->sqlSelect($val, $table, $where);
	} else {
		$answer = $self->sqlSelectHashref('*', $table, $where);
	}

	return $answer;
}

##################################################################
sub gets {
	my($self, $val) = @_;
	my $table = $self->{'_table'};
	my $prime = $self->{'_prime'};

	my %return;
	my $sth;

	my $where = $self->{_wheresql};

	if (ref($val) eq 'ARRAY') {
		my $values = join ',', @$val;
		$sth = $self->sqlSelectMany($values, $table, $where);
	} elsif ($val) {
		$sth = $self->sqlSelectMany($val, $table, $where);
	} else {
		$sth = $self->sqlSelectMany('*', $table, $where);
	}

	while (my $row = $sth->fetchrow_hashref) {
		$return{ $row->{$prime} } = $row;
	}
	$sth->finish;

	return \%return;
}


##################################################################
sub list {
	my($self, $val) = @_;
	my $table = $self->{'_table'};
	my $prime = $self->{'_prime'};

	$val ||= $prime;
	$self->sqlConnect();
	my $list = $self->{_dbh}->selectcol_arrayref("SELECT $val FROM $table");

	return $list;
}

##################################################################
sub create {
	my($self, $id, $val) = @_;
	my $table = $self->{'_table'};
	my $prime = $self->{'_prime'};
	my $id_db = $self->sqlQuote($id);
	my $where;

	if ($self->{_wheresql}) {
		$where = "$prime=$id_db AND " . $self->{_wheresql};
	} else {
		$where = "$prime=$id_db";
	}

	my($found) = $self->sqlSelect($prime, $table, $where);
	return if $found;

	for (keys %{ $self->{'_where'} }) {
		$val->{$_} = $self->{'_where'}{$_};
	}
	$val->{$prime} = $id if $id;
	$self->sqlInsert($table, $val);

	# what should $prime really be?  add a new var to $self? -- pudge
	my($rid) = $self->getLastInsertId($table, $prime);

	return $rid;
}

##################################################################
sub delete {
	my($self, $id) = @_;
	my $table = $self->{'_table'};
	my $prime = $self->{'_prime'};
	my $id_db = $self->sqlQuote($id);
	my $where;

	if ($self->{_wheresql}) {
		$where = "$prime=$id_db  AND " . $self->{_wheresql};
	} else {
		$where = "$prime=$id_db";
	}

	$self->sqlDo("DELETE FROM $table WHERE $where");
}

##################################################################
sub exists {
	my($self, $id) = @_;

	my $table = $self->{'_table'};
	my $prime = $self->{'_prime'};
	my $id_db = $self->sqlQuote($id);

	my $where;
	if ($self->{_wheresql}) {
		$where = "$prime=$id_db  AND " . $self->{_wheresql};
	} else {
		$where = "$prime=$id_db";
	}

	my $sql = "SELECT count(*) FROM $table WHERE $where";
	# we just need one stinkin value to see if this exists
	$self->sqlConnect();
	my $count = $self->{_dbh}->selectrow_array($sql);
	return $count;  # count
}

########################################################
# This should be inherited by all 3rd party modules
########################################################
sub sqlConnect {
# What we are going for here, is the ability to reuse
# the database connection.
# Ok, first lets see if we already have a connection
	my($self, $restart) = @_;
	$self->{_dbh}->disconnect if $restart;

	if (defined $self->{_dbh} && $self->{_dbh}->ping) {
		unless ($self->{_dbh}) {
			print STDERR "Undefining and calling to reconnect: $@\n";
			$self->{_dbh}->disconnect;
			undef $self->{_dbh};
			$self->sqlConnect();
		}
	} else {
# Ok, new connection, lets create it
	#	print STDERR "Having to rebuild the database handle\n";
		{
			local @_;
			eval {
				local $SIG{'ALRM'} = sub { die "Connection timed out" };
				alarm $timeout;
				$self->{_dbh} = DBIx::Password->connect_cached($self->{virtual_user});
				alarm 0;
			};

			if ($@ || !defined $self->{_dbh}) {
				#In the future we should have a backupdatabase
				#connection in here. For now, we die
				print STDERR "Major Mojo Bad things\n";
				print STDERR "unable to connect to MySQL: $@ : $DBI::errstr\n";
				#die "Database would not let us connect $DBI::errstr";	 # The Suicide Die
				return 0;
			}# else {
			#	my $time = localtime();
			#	print STDERR "Rebuilt at $time\n";
			#}
		}
	}
	return 1; # We return true that the sqlConnect was ok.
}

########################################################
# Useful SQL Wrapper Functions
########################################################
sub sqlSelectMany {
	my($self, $select, $from, $where, $other) = @_;

	my $sql = "SELECT $select ";
	$sql .= "   FROM $from " if $from;
	$sql .= "  WHERE $where " if $where;
	$sql .= "        $other" if $other;

	my $sth = $self->{_dbh}->prepare_cached($sql);
	$self->sqlConnect();
	if ($sth->execute) {
		return $sth;
	} else {
		$sth->finish;
		errorLog($sql);
		$self->sqlConnect;
		return undef;
	}
}

########################################################
sub sqlSelect {
	my($self, $select, $from, $where, $other) = @_;
	my $sql = "SELECT $select ";
	$sql .= "FROM $from " if $from;
	$sql .= "WHERE $where " if $where;
	$sql .= "$other" if $other;

	my $sth = $self->{_dbh}->prepare_cached($sql);
	$self->sqlConnect();
	if (!$sth->execute) {
		errorLog($sql);
		$self->sqlConnect;
		return undef;
	}
	my @r = $sth->fetchrow;
	$sth->finish;

	if (wantarray()) {
		return @r;
	} else {
		return $r[0];
	}
}

########################################################
sub sqlSelectArrayRef {
	my($self, $select, $from, $where, $other) = @_;
	my $sql = "SELECT $select ";
	$sql .= "FROM $from " if $from;
	$sql .= "WHERE $where " if $where;
	$sql .= "$other" if $other;

	$self->sqlConnect();
	my $sth = $self->{_dbh}->prepare_cached($sql);
	if (!$sth->execute) {
		errorLog($sql);
		$self->sqlConnect;
		return undef;
	}
	my $r = $sth->fetchrow_arrayref;
	return $r;
}

########################################################
sub sqlSelectHash {
	my($self) = @_;
	my $hash = $self->sqlSelectHashref(@_);
	return map { $_ => $hash->{$_} } keys %$hash;
}

##########################################################
# selectCount 051199
# inputs: scalar string table, scaler where clause
# returns: via ref from input
# Simple little function to get the count of a table
##########################################################
sub sqlCount {
	my($self, $table, $where) = @_;

	my $sql = "SELECT count(*) AS count FROM $table";
	$sql .= " WHERE $where" if  $where;
	# we just need one stinkin value - count
	$self->sqlConnect();
	my $count = $self->{_dbh}->selectrow_array($sql);
	return $count;  # count
}


########################################################
sub sqlSelectHashref {
	my($self, $select, $from, $where, $other) = @_;

	my $sql = "SELECT $select ";
	$sql .= "FROM $from " if $from;
	$sql .= "WHERE $where " if $where;
	$sql .= "$other" if $other;

	$self->sqlConnect();
	my $sth = $self->{_dbh}->prepare_cached($sql);

	unless ($sth->execute) {
		errorLog($sql);
		$self->sqlConnect;
		return;
	}
	my $H = $sth->fetchrow_hashref;
	$sth->finish;
	return $H;
}

########################################################
sub sqlSelectColArrayref {
	my($self, $select, $from, $where, $other) = @_;

	my $sql = "SELECT $select ";
	$sql .= "FROM $from " if $from;
	$sql .= "WHERE $where " if $where;
	$sql .= "$other" if $other;

	$self->sqlConnect();
	my $sth = $self->{_dbh}->prepare_cached($sql);

	my $array = $self->{_dbh}->selectcol_arrayref($sth);
	unless (defined($array)) {
		errorLog($sql);
		$self->sqlConnect;
		return;
	}

	return $array;
}

########################################################
# sqlSelectAll - this function returns the entire
# array ref of all records selected. Use this in the case
# where you want all the records and have to do a time consuming
# process that would tie up the db handle for too long.
#
# inputs:
# select - columns selected
# from - tables
# where - where clause
# other - limit, asc ...
#
# returns:
# array ref of all records
sub sqlSelectAll {
	my($self, $select, $from, $where, $other) = @_;

	my $sql = "SELECT $select ";
	$sql .= "FROM $from " if $from;
	$sql .= "WHERE $where " if $where;
	$sql .= "$other" if $other;

	$self->sqlConnect();

	my $H = $self->{_dbh}->selectall_arrayref($sql);
	unless ($H) {
		errorLog($sql);
		$self->sqlConnect;
		return;
	}
	return $H;
}

########################################################
# sqlSelectAllHashref - this function returns the entire
# set of rows in a hash.
#
# inputs:
# id -  column to use as the hash key
# select - columns selected
# from - tables
# where - where clause
# other - limit, asc ...
#
# returns:
# hash ref of all records
sub sqlSelectAllHashref {
	my($self, $id , $select, $from, $where, $other) = @_;

	# Yes, if ID is not in $select things will be bad
	my $sql = "SELECT $select ";
	$sql .= "FROM $from " if $from;
	$sql .= "WHERE $where " if $where;
	$sql .= "$other" if $other;

	my $sth = $self->sqlSelectMany($select, $from, $where, $other);
	my $returnable;
	while (my $row = $sth->fetchrow_hashref) {
		$returnable->{$row->{$id}} = $row;
	}
	$sth->finish;

	return $returnable;
}

########################################################
# sqlSelectAllHashrefArray - this function returns the entire
# set of rows in a array where the elements are the hash.
#
# inputs:
# select - columns selected
# from - tables
# where - where clause
# other - limit, asc ...
#
# returns:
# array ref of all records
sub sqlSelectAllHashrefArray {
	my($self, $select, $from, $where, $other) = @_;

	# Yes, if ID is not in $select things will be bad
	my $sql = "SELECT $select ";
	$sql .= "FROM $from " if $from;
	$sql .= "WHERE $where " if $where;
	$sql .= "$other" if $other;

	my $sth = $self->sqlSelectMany($select, $from, $where, $other);
	my @returnable;
	while (my $row = $sth->fetchrow_hashref) {
		push @returnable, $row;
	}
	$sth->finish;

	return \@returnable;
}

########################################################
sub sqlUpdate {
	my($self, $table, $data, $where) = @_;
	my $sql = "UPDATE $table SET ";
	foreach (keys %$data) {
		if (/^-/) {
			s/^-//;
			$sql .= "\n  $_ = $data->{-$_},";
		} else {
			$sql .= "\n $_ = " . $self->sqlQuote($data->{$_}) . ',';
		}
	}
	chop $sql;
	$sql .= "\nWHERE $where\n";
	$self->sqlConnect();
	my $rows = $self->sqlDo($sql);
	# print STDERR "SQL: $sql\n";
	return $rows;
}

########################################################
sub sqlInsert {
	my($self, $table, $data, $delayed) = @_;
	my($names, $values);
	# oddly enough, this hack seems to work for all DBs -- pudge
	$delayed = $delayed ? " /*! DELAYED */" : "";

	foreach (keys %$data) {
		if (/^-/) {
			$values .= "\n  $data->{$_},";
			s/^-//;
		} else {
			$values .= "\n  " . $self->sqlQuote($data->{$_}) . ',';
		}
		$names .= "$_,";
	}

	chop($names);
	chop($values);

	my $sql = "INSERT$delayed INTO $table ($names) VALUES($values)\n";
	$self->sqlConnect();
	return $self->sqlDo($sql);
}

#################################################################
sub sqlQuote { $_[0]->{_dbh}->quote($_[1]) }

#################################################################
sub sqlDo {
	my($self, $sql) = @_;
	$self->sqlConnect();
	my $rows = $self->{_dbh}->do($sql);
	unless ($rows) {
		errorLog($sql);
		$self->sqlConnect;
		return;
	}

	return $rows;
}

1;

__END__

=head1 NAME

Slash::DB::Utility - Generic SQL code which is common to all DB interfaces for Slash

=head1 SYNOPSIS

	use Slash::DB::Utility;

=head1 DESCRIPTION

No documentation yet.

=head1 SEE ALSO

Slash(3), Slash::DB(3).

=cut

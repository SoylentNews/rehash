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

# BENDER: Oh no! Not the magnet! 

my $timeout = 30; #This should eventualy be a parameter that is configurable
#Class variable that stores the database handle

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
				die "Database would not let us connect $DBI::errstr";	 # The Suicide Die
			}# else {
			#	my $time = localtime();
			#	print STDERR "Rebuilt at $time\n";
			#}
		}
	}
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

	return @r;
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
# array ref of all records
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
	my $sql = "UPDATE $table SET";
	foreach (keys %$data) {
		if (/^-/) {
			s/^-//;
			$sql .= "\n  $_ = $data->{-$_},";
		} else { 
			$sql .= "\n $_ = " . $self->{_dbh}->quote($data->{$_}) . ',';
		}
	}
	chop $sql;
	$sql .= "\nWHERE $where\n";
	$self->sqlConnect();
	my $rows = $self->sqlDo($sql);
	#print STDERR "SQL: $sql\n";
	return $rows;
}

########################################################
sub sqlInsert {
	my($self, $table, $data) = @_;
	my($names, $values);

	foreach (keys %$data) {
		if (/^-/) {
			$values .= "\n  $data->{$_},";
			s/^-//;
		} else {
			$values .= "\n  " . $self->{_dbh}->quote($data->{$_}) . ',';
		}
		$names .= "$_,";	
	}

	chop($names);
	chop($values);

	my $sql = "INSERT INTO $table ($names) VALUES($values)\n";
	$self->sqlConnect();
	return $self->sqlDo($sql);
}

#################################################################
sub sqlQuote {
	my($self, $sql) = @_;
	my $db_sql = $self->{_dbh}->quote($sql);

	return $db_sql;
}

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

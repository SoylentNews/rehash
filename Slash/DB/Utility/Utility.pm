# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::DB::Utility;

use strict;
use Config '%Config';
use Slash::Utility;
use DBIx::Password;
use Time::HiRes;
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
	$self->sqlConnect() or return undef;

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

	$self->{_querylog} = { };

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

	my $qlid = $self->_querylog_start('SELECT', $table);
	if (ref($val) eq 'ARRAY') {
		my $values = join ',', @$val;
		$sth = $self->sqlSelectMany($values, $table, $where);
	} elsif ($val) {
		$sth = $self->sqlSelectMany($val, $table, $where);
	} else {
		$sth = $self->sqlSelectMany('*', $table, $where);
	}
	return undef unless $sth;

	while (my $row = $sth->fetchrow_hashref) {
		$return{ $row->{$prime} } = $row;
	}
	$sth->finish;
	$self->_querylog_finish($qlid);

	return \%return;
}


##################################################################
sub list {
	my($self, $val) = @_;
	my $table = $self->{'_table'};
	my $prime = $self->{'_prime'};

	$val ||= $prime;
	$self->sqlConnect() or return undef;
	my $qlid = $self->_querylog_start('SELECT', $table);
	my $list = $self->{_dbh}->selectcol_arrayref("SELECT $val FROM $table");
	$self->_querylog_finish($qlid);

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

	return $self->getLastInsertId();
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

	my $qlid = $self->_querylog_start('DELETE', $table);
	my $rows = $self->sqlDo("DELETE FROM $table WHERE $where");
	$self->_querylog_finish($qlid);
	return $rows;
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
	$self->sqlConnect() or return undef;
	my $qlid = $self->_querylog_start('DELETE', $table);
	my $count = $self->{_dbh}->selectrow_array($sql);
	$self->_querylog_finish($qlid);
	return $count;
}

########################################################
# This should be inherited by all 3rd party modules
########################################################
sub sqlConnect {
# What we are going for here, is the ability to reuse
# the database connection.
# Ok, first lets see if we already have a connection
	my($self, $restart) = @_;
	if ($restart) {
		$self->{_dbh}->disconnect;
	}

	return 0 unless dbAvailable();

	if (!(defined $self->{_dbh}) || !$self->{_dbh}->ping) {
	#if (!(defined $self->{_dbh}) || !$self->{_dbh}->can("ping") || !$self->{_dbh}->ping) {
# Ok, new connection, lets create it
	#	print STDERR "Having to rebuild the database handle\n";
		{
			local @_;
			eval {
				local $SIG{'ALRM'} = sub { die "Connection timed out" };
				alarm $timeout if $Config{d_alarm};
				$self->{_dbh} = DBIx::Password->connect_cached($self->{virtual_user});
				alarm 0        if $Config{d_alarm};
			};

			if ($@ || !defined $self->{_dbh}) {
				#In the future we should have a backupdatabase
				#connection in here. For now, we die
				print STDERR "Major Mojo Bad things (virtual user: $self->{virtual_user})\n";
				print STDERR "unable to connect to MySQL: $@ : $DBI::errstr\n";
				#die "Database would not let us connect $DBI::errstr";	 # The Suicide Die
				return 0;
			}# else {
			#	my $time = localtime();
			#	print STDERR "Rebuilt at $time\n";
			#}
		}
	}
	$self->{_dbh}{PrintError} = 0; #"off" this kills the issue of bad SQL sending errors to the client

	return 1; # We return true that the sqlConnect was ok.
}

#######################################################
# Wrapper to get the latest ID from the database.
# If query logging may be on, this is only guaranteed to work if you
# use sqlInsert().  E.g., sqlDo("INSERT...") may fail.
sub getLastInsertId {
	my($self, $options) = @_;

	# If we just did an ordinary INSERT and the querylog is in,
	# the DB's LAST_INSERT_ID value will refer to the id column
	# of the querylog table.  But the real LAST_INSERT_ID we're
	# looking for has been stored by _querylog_start and that's
	# what we're going to return.
	if ($self->{_querylog}{enabled} && !$options->{ignore_querylog}) {
		return $self->{_querylog}{lastinsertid};
	}

	# We're not going to go through sqlSelect() because that will
	# involve querylog code;  we'll fetch this value here.
	my $sql = "SELECT LAST_INSERT_ID()";
	$self->sqlConnect() or return undef;
	my $sth = $self->{_dbh}->prepare($sql);
	if (!$sth->execute) {
		$self->sqlErrorLog($sql);
		$self->sqlConnect;
		return undef;
	}
	my($id) = $sth->fetchrow;
	$sth->finish;
	return $id;
}

########################################################
# The SQL query logging methods
#
# SQL query logging is enabled by the presence of a file (and disabled
# by removal of that file).  
########################################################

sub _querylog_enabled {
	my($self) = @_;

	return 0 unless dbAvailable();
	return $self->{_querylog}{enabled}
		if defined $self->{_querylog}{enabled}
			&& $self->{_querylog}{next_check_time} > time;

	# Need to (re)calculate whether it is enabled.  Note that this
	# location is hardcoded!  We can't call getCurrentStatic() at
	# this level, so we can't use $constants->{datadir}.  It would
	# be better to put this into /u/l/s/site/sitename but, same
	# problem.
	my $was_enabled = $self->{_querylog}{enabled} || 0;
	my $is_enabled = -e "/usr/local/slash/querylog";
	my $user;
	if ($is_enabled) {
		$user = getCurrentUser();
		$is_enabled = 0 unless $user && $user->{state};
	}
	if ($is_enabled) {
		my $siteid = getCurrentStatic('siteid');
		$siteid =~ s/\./_2e/g;
		$self->{_querylog}{apache_prefix} = "Apache::ROOT${siteid}::";
	}
	$self->{_querylog}{enabled} = $is_enabled;
	$self->{_querylog}{qlid} = 0;
	$self->{_querylog}{next_check_time} = time
		+ ($is_enabled && $was_enabled ? 60 : 5)
		+ int(rand(5));
	
	# Set up the querylog db object as necessary (the current
	# DB object has-a separate DB object inside it).
	if (!$is_enabled) {
		$self->{_querylog}{db} = undef;
	} else {
		$self->{_querylog}{db} ||=
			$user->{state}{dbs}{querylog}
				? getObject('Slash::DB', { db_type => 'querylog' })
				: $self;
	}
	return $is_enabled;
}

sub _querylog_start {
	my $self = shift;
	return 0 unless $self->_querylog_enabled();
	$self->{_querylog}{type} = shift;
	$self->{_querylog}{tables} = shift || "";
	$self->{_querylog}{options} = shift || { };
	$self->{_querylog}{lastinsertid} = 0;

	$self->{_querylog}{tables} =~ s/\W+/ /g;
	($self->{_querylog}{package} , $self->{_querylog}{line} ) = (caller(1))[0, 2];
	($self->{_querylog}{package1}, $self->{_querylog}{line1}) = (caller(2))[0, 2];
	$self->{_querylog}{package}  =~ s/^\Q$self->{_querylog}{apache_prefix}//;
	$self->{_querylog}{package1} =~ s/^\Q$self->{_querylog}{apache_prefix}//;
	$self->{_querylog}{start_time} = Time::HiRes::time;

	return ++$self->{_querylog}{qlid};
}

sub _querylog_finish {
	my($self, $id) = @_;
	return unless
		   $id
		&& $id == $self->{_querylog}{qlid}
		&& $self->_querylog_enabled();

	# If the code might need the LAST_INSERT_ID() result from an INSERT,
	# preserve it.
	if ($self->{_querylog}{type} eq 'INSERT') {
		$self->{_querylog}{lastinsertid} = $self->getLastInsertId({ ignore_querylog => 1 });
	}

	my $elapsed = sprintf("%.6f",
		Time::HiRes::time - $self->{_querylog}{start_time});

	# Prepare the insert.  If we're in a daemon or command line utility,
	# go ahead and write it now.  If we're in an httpd, push it onto a
	# queue for writing all together.  (We trust that apache processes
	# will run for a relatively long time, so we don't much care when
	# logging occurs, but tasks and other processes should log every
	# query immediately.)
	my $insert = "INSERT /* DELAYED */ INTO querylog VALUES"
		. " (NULL, '$self->{_querylog}{type}', '$self->{_querylog}{tables}', NULL,"
		. " '$self->{_querylog}{package}' , '$self->{_querylog}{line}' ,"
		. " '$self->{_querylog}{package1}', '$self->{_querylog}{line1}',"
		. " $elapsed)";
	if (!$ENV{GATEWAY_INTERFACE}) {
		$self->{_querylog}{db}{_dbh}->do($insert);
		return ;
	}

	push @{$self->{_querylog}{cache}}, $insert;

	# We flush the cache to disk if we have more than 8 items in it.
	# Why 8?  I had to pick some number.  Anyway we can't go looking
	# in $constants because this is a lower level and constants may
	# not exist yet.
	if (scalar(@{$self->{_querylog}{cache}}) >= 8) {
		$self->_querylog_writecache;
	}
}

sub _querylog_writecache {
	my($self) = @_;
	return unless ref($self->{_querylog}{cache})
		&& @{$self->{_querylog}{cache}};
	my $qdb = $self->{_querylog}{db};
	return unless $qdb;
#	$qdbh->{AutoCommit} = 0;
	$qdb->sqlDo("SET AUTOCOMMIT=0");
	while (my $sql = shift @{$self->{_querylog}{cache}}) {
		$qdb->sqlDo($sql);
	}
	$qdb->sqlDo("COMMIT");
	$qdb->sqlDo("SET AUTOCOMMIT=1");
#	$qdbh->commit;
#	$qdbh->{AutoCommit} = 1;
}

########################################################
# Useful SQL Wrapper Functions
########################################################

sub sqlSelectMany {
	my($self, $select, $from, $where, $other, $options) = @_;

	my $distinct = ($options && $options->{distinct}) ? "DISTINCT" : "";
	my $sql = "SELECT $distinct $select ";
	$sql .= "   FROM $from " if $from;
	$sql .= "  WHERE $where " if $where;
	$sql .= "        $other" if $other;

	$self->sqlConnect() or return undef;
	my $sth = $self->{_dbh}->prepare($sql);
	if ($sth->execute) {
		return $sth;
	} else {
		$sth->finish;
		$self->sqlErrorLog($sql);
		$self->sqlConnect;
		return undef;
	}
}

########################################################
# $options is a hash, add optional pieces here.
sub sqlSelect {
	my($self, $select, $from, $where, $other, $options) = @_;
	my $distinct = ($options && $options->{distinct}) ? "DISTINCT" : "";
	my $sql = "SELECT $distinct $select ";
	$sql .= "FROM $from " if $from;
	$sql .= "WHERE $where " if $where;
	$sql .= "$other" if $other;

	$self->sqlConnect() or return undef;
	my $qlid = $self->_querylog_start("SELECT", $from);
	my $sth = $self->{_dbh}->prepare($sql);
	if (!$sth->execute) {
		$self->sqlErrorLog($sql);
		$self->sqlConnect;
		return undef;
	}
	my @r = $sth->fetchrow;
	$sth->finish;

	$self->_querylog_finish($qlid);

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

	$self->sqlConnect() or return undef;
	my $qlid = $self->_querylog_start("SELECT", $from);
	my $sth = $self->{_dbh}->prepare($sql);
	if (!$sth->execute) {
		$self->sqlErrorLog($sql);
		$self->sqlConnect;
		return undef;
	}
	my $r = $sth->fetchrow_arrayref;
	$sth->finish;
	$self->_querylog_finish($qlid);
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

	my $sql = "SELECT COUNT(*) AS count FROM $table";
	$sql .= " WHERE $where" if $where;

	# we just need one stinkin value - count
	$self->sqlConnect() or return undef;
	my $qlid = $self->_querylog_start("SELECT", $table);
	my $count = $self->{_dbh}->selectrow_array($sql);
	$self->_querylog_finish($qlid);

	return $count;  # count
}


########################################################
sub sqlSelectHashref {
	my($self, $select, $from, $where, $other) = @_;

	my $sql = "SELECT $select ";
	$sql .= "FROM $from " if $from;
	$sql .= "WHERE $where " if $where;
	$sql .= "$other" if $other;

	$self->sqlConnect() or return undef;
	my $qlid = $self->_querylog_start("SELECT", $from);
	my $sth = $self->{_dbh}->prepare($sql);

	unless ($sth->execute) {
		$self->sqlErrorLog($sql);
		$self->sqlConnect;
		return;
	}
	my $H = $sth->fetchrow_hashref;
	$sth->finish;
	$self->_querylog_finish($qlid);
	return $H;
}

########################################################
sub sqlSelectColArrayref {
	my($self, $select, $from, $where, $other, $options) = @_;
	my $distinct = ($options && $options->{distinct}) ? "DISTINCT" : "";

	my $sql = "SELECT $distinct $select ";
	$sql .= "FROM $from " if $from;
	$sql .= "WHERE $where " if $where;
	$sql .= "$other" if $other;

	$self->sqlConnect() or return undef;
	my $qlid = $self->_querylog_start("SELECT", $from);
	my $sth = $self->{_dbh}->prepare($sql);

	my $array = $self->{_dbh}->selectcol_arrayref($sth);
	unless (defined($array)) {
		$self->sqlErrorLog($sql);
		$self->sqlConnect;
		return;
	}
	$self->_querylog_finish($qlid);

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

	$self->sqlConnect() or return undef;

	my $qlid = $self->_querylog_start("SELECT", $from);
	my $H = $self->{_dbh}->selectall_arrayref($sql);
	unless ($H) {
		$self->sqlErrorLog($sql);
		$self->sqlConnect;
		return undef;
	}
	$self->_querylog_finish($qlid);
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
	my($self, $id, $select, $from, $where, $other) = @_;
	# Yes, if $id is not in $select things will be bad
	
	# Allow $id to be an arrayref to collect multiple rows of results
	# keyed by more than one column.  E.g. if you "GROUP BY foo, bar"
	# then pass "[qw( foo bar )]" for $id and the column "baz" will
	# be at $returnable->{$foovalue}{$barvalue}{baz}.
	$id = [ $id ] if !ref($id);

	my $sql = "SELECT $select ";
	$sql .= "FROM $from " if $from;
	$sql .= "WHERE $where " if $where;
	$sql .= "$other" if $other;

	my $qlid = $self->_querylog_start("SELECT", $from);
	my $sth = $self->sqlSelectMany($select, $from, $where, $other);
	return undef unless $sth;
	my $returnable = { };
	while (my $row = $sth->fetchrow_hashref) {
		my $reference = $returnable;
		for my $next_id (@$id) {
			$reference = \%{$reference->{$row->{$next_id}}};
		}
		%$reference = %$row;
	}
	$sth->finish;
	$self->_querylog_finish($qlid);

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

	my $sql = "SELECT $select ";
	$sql .= "FROM $from " if $from;
	$sql .= "WHERE $where " if $where;
	$sql .= "$other" if $other;

	my $qlid = $self->_querylog_start("SELECT", $from);
	my $sth = $self->sqlSelectMany($select, $from, $where, $other);
	return undef unless $sth;
	my @returnable;
	while (my $row = $sth->fetchrow_hashref) {
		push @returnable, $row;
	}
	$sth->finish;
	$self->_querylog_finish($qlid);

	return \@returnable;
}

########################################################
# sqlSelectAllKeyValue - this function returns the entire
# set of rows in a hashref, where the keys are the first
# column requested and the values are the second.
# (Name collisions are the caller's problem)
#
# inputs:
# select - exactly 2 columns to select
# from - tables
# where - where clause
# other - limit, asc ...
#
# returns:
# hashref, keys first column, values the second
sub sqlSelectAllKeyValue {
	my($self, $select, $from, $where, $other) = @_;

	my $sql = "SELECT $select ";
	$sql .= "FROM $from " if $from;
	$sql .= "WHERE $where " if $where;
	$sql .= "$other" if $other;

	my $qlid = $self->_querylog_start("SELECT", $from);
	my $H = $self->{_dbh}->selectall_arrayref($sql);
	unless ($H) {
		$self->sqlErrorLog($sql);
		$self->sqlConnect;
		return undef;
	}
	$self->_querylog_finish($qlid);

	my $hashref = { };
	for my $duple (@$H) {
		$hashref->{$duple->[0]} = $duple->[1];
	}
	return $hashref;
}

########################################################
sub sqlUpdate {
	my($self, $table, $data, $where, $options) = @_;

	# If no changes were passed in, there's nothing to do.
	# (And if we tried to proceed we'd generate an SQL error.)
	return 0 if !keys %$data;

	my $sql = "UPDATE $table SET ";

	my @data_fields = ( );
	my $order_hr = { };
	if ($options && $options->{assn_order}) {
		# Reorder the data fields into the order given.  Any
		# fields not specified in the assn_order arrayref
		# go last.  Note that the "-" prefix for each field
		# must be included in assn_order keys.
		# <http://www.mysql.com/documentation/mysql/bychapter/
		# manual_Reference.html#UPDATE>
		# "UPDATE assignments are evaluated from left to right."
		my $order_ar = $options->{assn_order};
		for my $i (0..$#$order_ar) {
			$order_hr->{$order_ar->[$i]} = $i + 1;
		}
	}
	# In any case, the field names are sorted.  This is new
	# behavior as of August 2002.  It should not break anything,
	# because nothing previous should have relied on perl's
	# natural hash key sort order!
	@data_fields = sort {
		($order_hr->{$a} || 9999) <=> ($order_hr->{$b} || 9999)
		||
		$a cmp $b
	} keys %$data;

	for my $field (@data_fields) {
		if ($field =~ /^-/) {
			$field =~ s/^-//;
			$sql .= "\n  $field = $data->{-$field},";
		} else {
			$sql .= "\n $field = " . $self->sqlQuote($data->{$field}) . ',';
		}
	}
	chop $sql; # lose the terminal ","
	$sql .= "\nWHERE $where\n" if $where;
	my $qlid = $self->_querylog_start("UPDATE", $table);
	my $rows = $self->sqlDo($sql);
	$self->_querylog_finish($qlid);
	return $rows;
}

########################################################
sub sqlDelete {
	my($self, $table, $where, $limit) = @_;
	return unless $table;
	my $sql = "DELETE FROM $table";
	$sql .= " WHERE $where" if $where;
	$sql .= " LIMIT $limit" if $limit;
	my $qlid = $self->_querylog_start("DELETE", $table);
	my $rows = $self->sqlDo($sql);
	$self->_querylog_finish($qlid);
	return $rows;
}

########################################################
sub sqlInsert {
	my($self, $table, $data, $options) = @_;
	my($names, $values);
	# oddly enough, this hack seems to work for all DBs -- pudge
	# Its an ANSI sql comment I believe -Brian
	# Hmmmmm... we can trust getCurrentStatic here? - Jamie
	my $delayed = ($options->{delayed} && !getCurrentStatic('delayed_inserts_off'))
		? " /*! DELAYED */" : "";
	my $ignore = $options->{ignore} ? " /*! IGNORE */" : "";

	for (keys %$data) {
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

	my $sql = "INSERT $ignore $delayed INTO $table ($names) VALUES($values)\n";
	my $qlid = $self->_querylog_start("INSERT", $table);
	my $rows = $self->sqlDo($sql);
	$self->_querylog_finish($qlid);
	return $rows;
}

#################################################################
sub sqlQuote {
	my($self, $value) = @_;
	$self->sqlConnect() or return undef;
	if (ref($value) eq 'ARRAY') {
		my(@array);
		for (@$value) {
			push @array, $self->{_dbh}->quote($_);
		}
		return \@array;
	} else {
		return $self->{_dbh}->quote($value);
	}
}

#################################################################
sub sqlDo {
	my($self, $sql) = @_;
	$self->sqlConnect() or return undef;
	my $rows = $self->{_dbh}->do($sql);
	unless ($rows) {
		unless ($sql =~ /^INSERT\s+IGNORE\b/i) {
			$self->sqlErrorLog($sql);
		}
		$self->sqlConnect;
		return;
	}

	return $rows;
}

#################################################################
# Log the error
sub sqlErrorLog {
	my($self, $sql) = @_;
	my $error = $self->sqlError || 'no error string';

	my @return = ("DB='$self->{virtual_user}'", "hostinfo='$self->{_dbh}->{mysql_hostinfo}'", $error);
	push @return, $sql if $sql;
	errorLog(join ' -- ', @return);
}

#################################################################
# Keeps encapsulation
sub sqlError {
	my($self) = @_;
	# can't call any other DBI calls before errstr, or we lose errstr -- pudge
	return $self->{_dbh}->errstr;
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

# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::DB::Utility;

use strict;
use DBIx::Password;
use Slash::Utility;
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
				$self->DBPreConnectSetup();
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

			# See below -- thebrain
			$self->DBPostConnectSetup();
		}
	}
}

# Additional setup instructions for a DB connection before and
# after it has been setup can be inserted by overriding these
# methods; see Slash::DB::Oracle for an example -- thebrain
sub DBPreConnectSetup  { return 0 }
sub DBPostConnectSetup { return 0 }

# This sets the method called to prepare a statement.  The primary use of this
#   is Oracle, where prepare_cached does more harm than good (by perpetually
#   tying up SQL cursors) and is unnecessary anyway (thanks to the server-side
#   SQL cache), so it should just use prepare for everything. -- thebrain
sub setPrepareMethod {
	$_[0]->{_dbh_prepare_method} = $_[1];
}

# These set what value means 'all' in the topics and sections tables, which is
#   important in a few areas.  This is yet another Oracle hack because Oracle
#   stupidly makes '' == NULL and primary keys are NOT NULL fields.  I set the
#   defaults to '' here, but if you happen across another database as damaged
#   as Oracle in this regard, you can override these in the driver. -- thebrain
sub TopicAllKey { return '' };
sub SectionAllKey { return '' };

########################################################
# These _sqlPrepare* methods set up their respective statements but
# don't execute them, instead returning the component parts so we can
# execute and fetch on our own terms.  This decouples the statement
# generation so it doesn't have to be duplicated each time we change
# the execute/fetch technique du jour.
# The most prominent useful place for this is in the REPLACE emulation
# for Oracle, which prepares an insert but defers the execute back to
# the sqlReplace function, where it gets error trapped so appropriate
# action can be taken if the error isn't a truly fatal one. -- thebrain
sub _sqlPrepareSelect {
	my $self	= shift;
	my $sql		= '';

	foreach my $elem ('SELECT ',' FROM ',' WHERE ',' ') {
		last if !@_ or ref($_[0]) eq 'ARRAY';
		my $et = shift;
		$sql .= $elem . $et if $et;
	}

	my $binds	= [];
	$binds		= shift if ref($_[0]) eq 'ARRAY';
	my $attr	= {};
	$attr		= shift if ref($_[0]) eq 'HASH';

	$self->sqlConnect();
	my $pmeth = $self->{_dbh_prepare_method};
	my $sth = $self->{_dbh}->$pmeth($sql);
	foreach my $bp (keys %$attr) {
		$sth->bind_param($bp, undef, $attr->{$bp});
	}
	return($sth, $sql, [@$binds]);
}

########################################################
sub _sqlPrepareInsert {
	my $self	= shift;
	my $table	= shift;
	my $data	= shift;
	my $attr	= {};
	$attr		= shift if ref($_[0]) eq 'HASH';

	my($names, $values, @binds, %bindattr);

	foreach my $key (keys %$data) {
		if ($key =~ s/^-//) {
			$values .= "$data->{-$key},";
		} else {
			$values .= '?,';
			push @binds, $data->{$key};
			$bindattr{scalar(@binds)} = $attr->{$key} if $attr->{$key};
		}
		$names .= "$key,";
	}

	chop($names);
	chop($values);

	$self->sqlConnect();
	my $sql = "INSERT INTO $table ($names) VALUES ($values)\n";
	my $pmeth = $self->{_dbh_prepare_method};
	my $sth = $self->{_dbh}->$pmeth($sql);
	foreach my $bp (keys %bindattr) {
		$sth->bind_param($bp, undef, $bindattr{$bp});
	}
	return ($sth, $sql, \@binds);
}

########################################################
sub sqlSelectMany {
	my $self = shift;
	my($sth, $sql, $binds) = $self->_sqlPrepareSelect(@_);
	if ($sth->execute(@$binds)) {
		return $sth;
	} else {
		$sth->finish;
		errorLog($self->sqlFillInPlaceholders($sql, $binds));
		$self->sqlConnect();
		return undef;
	}
}

########################################################
sub sqlSelect {
	my $self = shift;
	my $sth = $self->sqlSelectMany(@_) || return undef;
	my @r = $sth->fetchrow_array;
	$sth->finish;
	return @r;
}

########################################################
sub sqlSelectArrayRef {
	my $self = shift;
	my $sth = $self->sqlSelectMany(@_) || return undef;
	my $r = $sth->fetchrow_arrayref;
	$sth->finish;
	return $r;
}

########################################################
sub sqlSelectHashref {
	my $self = shift;
	my $sth = $self->sqlSelectMany(@_) || return undef;

	# perldoc DBI:
	# Currently, a new hash reference is returned for each
	# row.  _This_will_change_ in the future to return the
	# same hash ref each time, so don't rely on the current
	# behaviour.
	my $dh = $sth->fetchrow_hashref('NAME_lc') || {};
	$sth->finish;
	return keys %$dh ? { %$dh } : undef;
}

########################################################
# This is kinda pointless -- thebrain
sub sqlSelectHash {
	my $self = shift;
	my $hash = $self->sqlSelectHashref(@_) or return;
	return %$hash;
}

##########################################################
# selectCount 051199
# inputs: scalar string table, scaler where clause 
# returns: via ref from input
# Simple little function to get the count of a table
##########################################################
sub sqlCount {
	my $self = shift;
	return ($self->sqlSelect('COUNT(*)', @_))[0];
}

########################################################
sub sqlSelectColArrayref {
	my $self = shift;
	my $sth = $self->sqlSelectMany(@_) || return undef;
	my $a = $self->{_dbh}->selectcol_arrayref($sth);
	$sth->finish;
	return $a;
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
	my $self = shift;
	my $sth = $self->sqlSelectMany(@_) || return undef;
	my $a = $self->{_dbh}->selectall_arrayref($sth);
	$sth->finish;
	return $a;
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
	my $self = shift;
	my $id = shift;
	my $sth = $self->sqlSelectMany(@_) || return undef;
	my $h = {};
	while (my $row = $sth->fetchrow_hashref('NAME_lc')) {
		# perldoc DBI:
		# Currently, a new hash reference is returned for each
		# row.  _This_will_change_ in the future to return the
		# same hash ref each time, so don't rely on the current
		# behaviour.
		$h->{$row->{$id}} = { %$row };
	}
	$sth->finish;
	return $h;
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
	my $self = shift;
	my $sth = $self->sqlSelectMany(@_) || return undef;
	my $a = [];
	while (my $row = $sth->fetchrow_hashref('NAME_lc')) {
		# perldoc DBI:
		# Currently, a new hash reference is returned for each
		# row.  _This_will_change_ in the future to return the
		# same hash ref each time, so don't rely on the current
		# behaviour.
		push @$a, { %$row };
	}
	$sth->finish;
	return $a;
}

#######################################################
sub sqlUpdate {
	my $self	= shift;
	my $table	= shift;
	my $data	= shift;
	my $dataattr	= {};
	$dataattr	= shift if ref($_[0]) eq 'HASH';
	my $where	= shift;
	my $wherebinds	= [];
	$wherebinds	= shift if ref($_[0]) eq 'ARRAY';
	my $whereattr	= {};
	$whereattr	= shift if ref($_[0]) eq 'HASH';

	my(@binds, %bindattr);
	my $sql = "UPDATE $table SET";
	foreach my $key (keys %$data) {
		if ($key =~ s/^-//) {
			$sql .= " $key = $data->{-$key},";
		} else {
			$sql .= " $key = ?,";
			push @binds, $data->{$key};
			$bindattr{scalar(@binds)} = $dataattr->{$key} if $dataattr->{$key};
		}
	}
	chop $sql;

	$sql .= "\nWHERE $where\n";
	for (my $i = 0; $i < @$wherebinds; $i++) {
		push @binds, $wherebinds->[$i];
		$bindattr{scalar(@binds)} = $whereattr->{$i+1} if $whereattr->{$i+1};
	}

	$self->sqlConnect();
	my $rows = $self->sqlDo($sql, \@binds, \%bindattr);
	#print STDERR "SQL: $sql\n";
	return $rows;
}

########################################################
sub sqlInsert {
	my $self = shift;
	my($sth, $sql, $binds) = $self->_sqlPrepareInsert(@_);
	if (my $rv = $sth->execute(@$binds)) {
		return $rv;
	} else {
		errorLog($self->sqlFillInPlaceholders($sql, $binds));
		$self->sqlConnect;
		return undef;
	}
}

#################################################################
sub sqlQuote {
	return $_[0]->{_dbh}->quote($_[1]);
}

#################################################################
sub sqlDo {
	my($self, $sql, $binds, $bindattrs) = @_;
	$self->sqlConnect();
	my $rows;
	if ($bindattrs && keys %$bindattrs) {
		my $sth = $self->{_dbh}->prepare($sql);
		foreach my $bp (keys %$bindattrs) {
			$sth->bind_param($bp, undef, $bindattrs->{$bp});
		}
		$rows = $sth->execute(@$binds);
	} else {
		$rows = $self->{_dbh}->do($sql, undef, @$binds);
	}
	unless ($rows) {
		errorLog($self->sqlFillInPlaceholders($sql, [@$binds]));
		$self->sqlConnect;
		return;
	}
	return $rows;
}

#################################################################
# For error reporting purposes -- thebrain
sub sqlFillInPlaceholders {
	my($self, $sql, $binds) = @_;
	$sql =~ s/\?/$self->{_dbh}->quote(shift @$binds)/ge;
	return $sql;
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

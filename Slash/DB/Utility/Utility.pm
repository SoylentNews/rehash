# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::DB::Utility;

use strict;
use Config '%Config';
use Slash::Utility;
use DBIx::Password;
use Time::HiRes;
use Encode qw(decode_utf8 is_utf8);

our $VERSION = $Slash::Constants::VERSION;

# FRY: Bender, if this is some kind of scam, I don't get it.  You already
# have my power of attorney.

my $timeout = 30; # This should eventualy be a parameter that is configurable
my $query_ref_regex = qr{(HASH|ARRAY|SCALAR|GLOB|CODE|LVALUE|IO|REF)\(0x[0-9a-f]{3,16}\)}; # this too

########################################################
# Generic methods for libraries.
########################################################
sub new {
	my($class, $user, @extra_args) = @_;
	if ($class->can('isInstalled')) {
		return undef unless $class->isInstalled();
	}

	my $self = {};
	bless($self, $class);
	$self->{virtual_user} = $user;

	if ($self->can('init')) {
		# init should return TRUE for success, else
		# we abort
		return undef unless $self->init(@extra_args);

		if (exists $self->{'_where'}) {
			my $where = '';
			for (keys %{ $self->{'_where'} }) {
				$where .= "$_=$self->{'_where'}{$_} AND ";
			}
			$where =~ s/ AND $//g if $where;
			$self->{_wheresql} = $where;
		}
	}
	$self->sqlConnect() or return undef;

	return $self;
}

# Subclasses may implement their own methods of determining whether
# their class is "installed" or not.  For example, plugins may want
# to check $constants->{plugin}{Foo}.
sub isInstalled {
	return 1;
}

# Many of our database classes use multiple base classes, for example,
# MySQL.pm does:
#       use base 'Slash::DB';
#       use base 'Slash::DB::Utility';
# Many of our optional (plugin) classes do this:
#       use base 'Slash::DB::Utility';
#       use base 'Slash::DB::MySQL';
# along with a code comment suggesting maybe this should be changed.
# (But it hasn't been changed in years, and has been copy-and-pasted
# so many times it would require a great deal of testing to change now.)
#
# The Slash code just uses perl's stock multiple inheritance, which
# means a SUPER::foo() call will only invoke the first base class.
# So most of our database classes, when initialized, will invoke
# Slash::DB::Utility::init(), and MySQL.pm will invoke Slash::DB::init().
# Long story short, any initialization common to all database classes
# should be done both here and in DB.pm.

sub init {
	my($self) = @_;
	# Consider clearing any existing fields matching /_cache_/ too.
	my @fields_to_clear = qw(
		_querylog       _codeBank
		_boxes          _sectionBoxes
		_comment_text   _comment_text_full
		_story_comm
	);
	for my $field (@fields_to_clear) {
		$self->{$field} = { };
	}
	$self->SUPER::init() if $self->can('SUPER::init');
	1;
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

	# ping() isn't currently implemented so it is unnecessary;
	# if it actually did run a query on the DB to determine
	# whether the connection were active, calling it here
	# would be a mistake.  I think we want to check
	# dbh->{Active} instead. XXX -Jamie
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
				print STDERR "unable to connect to MySQL: $@ : " . ($DBI::errstr || '') . "\n";
				#die "Database would not let us connect $DBI::errstr";	 # The Suicide Die
				return 0;
			}# else {
			#	my $time = localtime();
			#	print STDERR "Rebuilt at $time\n";
			#}
		}
	}
	$self->{_dbh}{PrintError} = 0; #"off" this kills the issue of bad SQL sending errors to the client
	if (getCurrentStatic('utf8')) {
		$self->{_dbh}->{mysql_enable_utf8} = 1; # enable utf8 mode (add utf8 flag)
	}

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


#######################################################
# set a system variable if necessary.  this will only be
# good for the current session.  don't forget to set it
# back anyway.
sub sqlSetVar {
	my($self, $var, $value) = @_;
	return if $ENV{GATEWAY_INTERFACE} && !getCurrentUser('is_admin');

	# can't use sqlQuote for this, can't be quoted
	$var =~ s/\W+//;   # just in case
	$value =~ s/\D+//; # ditto (any non-numeric vars we might adjust?)

	$self->sqlDo("SET $var = $value");
}

#######################################################
# get the value of a named system variable
sub sqlGetVar {
	my($self, $var) = @_;

	# to mirror what we do in sqlSetVar
	$var =~ s/\W+//;

	my $sql = "SHOW VARIABLES LIKE '$var'";
	my $sth = $self->{_dbh}->prepare($sql);

	if (!$sth->execute) {
		$self->sqlErrorLog($sql);
		$self->sqlConnect;
		return undef;
	}

	my($name, $value) = $sth->fetchrow;
	$sth->finish;
	return $value;
}


########################################################
# The SQL query logging methods
#
# SQL query logging is enabled by the presence of a file (and disabled
# by removal of that file).  
########################################################

{
my $_querylog_lastchecktime = 0;
my $_querylog_lastval = undef;
sub _querylog_enabled {
	my($self) = @_;

	return 0 unless dbAvailable();
	if (!exists $self->{_querylog}) {
		use Carp;
		Carp::cluck "no ql for $self, perhaps SUPER::init was not called correctly?";
		$self->{_querylog} = { };
	}
	return $_querylog_lastval
		if defined $_querylog_lastval
			&& $_querylog_lastchecktime + 20 > time;

	# Need to (re)calculate whether it is enabled.  Note that this
	# location is hardcoded!  We can't call getCurrentStatic() at
	# this level, so we can't use $constants->{datadir}.  It would
	# be better to put this into /u/l/s/site/sitename but, same
	# problem.
	my $was_enabled = $_querylog_lastval || 0;
	my $is_enabled = -e '/usr/local/slash/querylog';
	my $user;
	$user = getCurrentUser() if $is_enabled;
	$is_enabled = 0 unless $user && $user->{state};
	if ($is_enabled) {
		my $siteid = getCurrentStatic('siteid');
		$siteid =~ s/\./_2e/g;
		$self->{_querylog}{apache_prefix} = "Apache::ROOT${siteid}::";
	}
	$_querylog_lastchecktime = time;
	$_querylog_lastval = $is_enabled;

	if (!$is_enabled) {
		$self->{_querylog}{db} = undef;
	} elsif (!$was_enabled) {
		# State just changed from "not enabled" to "enabled."
		# Initialize some stuff.
		$self->{_querylog}{qlid} = 0;
		$self->{_querylog}{db} ||=
			$user->{state}{dbs}{querylog}
				? getObject('Slash::DB', { db_type => 'querylog' })
				: $self;
	}

	return $is_enabled;
}
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

sub _refCheck {
	my($self, $where) = @_;
	return if !$where || $where !~ $query_ref_regex;
	my @c = caller(1);
	my $w2 = $where; $w2 =~ s/\s+/ /g;
	warn scalar(gmtime) . " query text contains ref string ($c[0] $c[1] $c[2] $c[3]): $w2\n";
}

sub sqlSelectMany {
	my($self, $select, $from, $where, $other, $options) = @_;
	$self->_refCheck($where);

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
		$self->sqlErrorLog($sql);
		$sth->finish;
		$self->sqlConnect;
		return undef;
	}
}

########################################################
# $options is a hash, add optional pieces here.
sub sqlSelect {
	my($self, $select, $from, $where, $other, $options) = @_;
	$self->_refCheck($where);
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
	$self->_refCheck($where);
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
sub sqlCount {
	my($self, $table, $where) = @_;
	$self->_refCheck($where);

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
	$self->_refCheck($where);

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
	$self->_refCheck($where);
	my $distinct = ($options && $options->{distinct}) ? "DISTINCT" : "";
	my $sql_no_cache = ($options && $options->{sql_no_cache}) ? " SQL_NO_CACHE" : "";

	my $sql = "SELECT $distinct$sql_no_cache $select ";
	$sql .= "FROM $from " if $from;
	$sql .= "WHERE $where " if $where;
	$sql .= "$other" if $other;

	$self->sqlConnect() or return undef;
	my $qlid = $self->_querylog_start("SELECT", $from);
	my $sth = $self->{_dbh}->prepare($sql);
	unless ($sth) {
		$self->sqlErrorLog($sql);
		$self->sqlConnect;
		return;
	}

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
	$self->_refCheck($where);

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
	my($self, $id, $select, $from, $where, $other, $options) = @_;
	$self->_refCheck($where);
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
		if ($options->{thin}) {
			for my $next_id (@$id) {
				delete $reference->{$next_id};
			}
		}
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
	$self->_refCheck($where);

	my $sql = "SELECT $select ";
	$sql .= "FROM $from " if $from;
	$sql .= "WHERE $where " if $where;
	$sql .= "$other" if $other;

	my $qlid = $self->_querylog_start("SELECT", $from);
	my $sth = $self->sqlSelectMany($select, $from, $where, $other);
	return undef unless $sth;
	my @returnable = ( );
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
	$self->_refCheck($where);

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

	my $hashref = { };
	for my $duple (@$H) {
		$hashref->{$duple->[0]} = $duple->[1];
	}
	return $hashref;
}

########################################################
# This is a little different from the other sqlSelect* methods.
#
# Its reason for existing is that sometimes, for performance reasons,
# you want to do a select on a large table that is limited by a key
# that differs from the column you actually want to limit by, though
# both of them increase (or decrease) together.  For example, perhaps
# you want to do a SELECT on an accesslog table with millions of rows
# based on a range of accesslog.ts, but to make sure the query optimizer
# restricts by primary key, you'd prefer to determine the range of
# accesslog.id that spans the rows in question, and offer that as
# part of the WHERE clause as well.  The optimizer doesn't know that
# the columns id and ts increase together, but you do.  Telling the
# optimizer that it can restrict by the numeric key may not make your
# query faster, but it might, and in non-pathological situations it
# won't make it slower.
#
# This method will return a boundary value of a numeric key column
# based on an inequality test for a different column that must be
# approximately monotonic with the key.  It will always return quickly,
# since it uses a binary search to narrow down the value sought, and
# all its SELECTs are primary key lookups.
#
# Note that there must not be "holes" in the table where a value of the
# numeric key is missing even though there are values present both above
# and below it, or the answer may impose an incorrectly strict limitation
# (this bug may be fixed in the future).  This includes "holes" in the
# values for that key in the rows returned by the where clause.
#
# For example, if you wanted to count the number of distinct uids in
# a very large accesslog table in several hours, the easy way is:
#
# $c = $slashdb->sqlSelect("COUNT(DISTINCT uid)", "accesslog",
#     "ts BETWEEN '2001-01-01 01:00:00' AND '2001-01-01 03:00:00'");
#
# but it may be faster, and certainly won't be significantly slower,
# to do:
#
# $minid = $slashdb->sqlSelectNumericKeyAssumingMonotonic("accesslog", "min", "id", "ts >= '2001-01-01 01:00:00'");
# $maxid = $slashdb->sqlSelectNumericKeyAssumingMonotonic("accesslog", "max", "id", "ts <= '2001-01-01 03:00:00'");
# $c = $slashdb->sqlSelect("COUNT(DISTINCT uid)", "accesslog",
#     "id BETWEEN $minid AND $maxid AND ts BETWEEN '2001-01-01 01:00:00' AND '2001-01-01 03:00:00'");

sub sqlSelectNumericKeyAssumingMonotonic {
	my($self, $table, $minmax, $keycol, $clause, $max_gap) = @_;
	my $constants = getCurrentStatic();
	$max_gap ||= ($constants->{db_auto_increment_increment} || 1)-1;
	$self->_refCheck($clause);

	# Set up $minmax appropriately.
	$minmax = uc($minmax);
	if ($minmax !~ /^(MIN|MAX)$/) {
		die "sqlSelectNumericKeyAssumingMonotonic called with minmax='$minmax'";
	}
	# In MixedCaps to avoid typo bugs and make the code perhaps
	# a bit clearer.  This is the opposite of $minmax.
	my $MaxMin = $minmax eq 'MIN' ? 'MAX' : 'MIN';

	# We pretend the "left" end of the table is the end pointed to
	# by whichever direction $minmax points, and the "right" end
	# is the end $MaxMin points to.
	# First, seed the leftmost variable with the id at the left end
	# of the table.
	my $leftmost = $self->sqlSelect("$minmax($keycol)", $table);
	# If no such id, the table is empty.
	return undef unless $leftmost;
	# If the test actually passes for that id, then it's not a
	# failure at all, and we know our answer already.
	return $leftmost if $self->sqlSelect($keycol, $table, "$keycol=$leftmost AND ($clause)");

	# Next, seed the rightmost with the id at the right end.
	my $rightmost = $self->sqlSelect("$MaxMin($keycol)", $table);
	# If that test fails, then there are no rows satisfying the
	# desired condition, so we know our answer.
	return undef if !$self->sqlSelect($keycol, $table, "$keycol=$rightmost AND ($clause)");

	# Now iterate a binary search into the table.
	my $answer = undef;
	while (!$answer) {
		# If we're really close, just do the SELECT.
		if (abs($leftmost - $rightmost) < 100) {
			my($min, $max);
			if ($minmax eq 'MIN') { $min = $leftmost; $max = $rightmost }
					 else { $min = $rightmost; $max = $leftmost }
			$answer = $self->sqlSelect("$minmax($keycol)", $table,
				"$keycol BETWEEN $min AND $max
				 AND ($clause)");
			if (!$answer) {
				# Table may have changed, that's one of
				# the risks of using this method.  Return
				# the approximately correct answer that
				# was, at least at one time, valid.
				$answer = $leftmost;
			}
		}
		last if $answer;
		# If we're not that close, narrow it down.  To allow for gaps
		# in the keycol, 
		my $middle = int(($leftmost + $rightmost) / 2);
		my $middle_clause;
		if ($max_gap) {
			my $middle_min = int($middle - $max_gap/2);
			$middle_min = 0 if $middle_min < 0; # very unlikely! but just in case
			my $middle_max = int($middle + $max_gap/2);
			$middle_clause = "$keycol BETWEEN $middle_min AND $middle_max";
		} else {
			$middle_clause = "$keycol=$middle";
		}
		my $hit = $self->sqlSelect($keycol, $table,
			"($middle_clause) AND ($clause)");
		if ($hit) {
			$rightmost = $middle;
		} else {
			$leftmost = $middle;
		}
	}
	return $answer;
}

########################################################
sub sqlUpdate {
	my($self, $tables, $data, $where, $options) = @_;
	$self->_refCheck($where);

	# If no changes were passed in, there's nothing to do.
	# (And if we tried to proceed we'd generate an SQL error.)
	return 0 if !keys %$data;

	my $sql = "UPDATE ";
	# What's inside /*! */ will be treated as a comment by most
	# other SQL servers, but MySQL will parse it.  Kinda pointless
	# since we've basically given up on ever supporting DBs other
	# than MySQL, but what the heck.
	$sql .= "/*! IGNORE */ " if $options->{ignore};

	my $table_str;
	if (ref $tables) {
		$table_str = join(",", @$tables);
	} else {
		$table_str = $tables;
	}
	$sql .= $table_str;

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
	my @data_fields = ( );
	@data_fields = sort {
		($order_hr->{$a} || 9999) <=> ($order_hr->{$b} || 9999)
		||
		$a cmp $b
	} keys %$data;
	my @set_clauses = ( );
	for my $field (@data_fields) {
		if ($field =~ /^-/) {
			$field =~ s/^-//;
			push @set_clauses, "$field = $data->{-$field}";
		} else {
			my $data_q = $self->sqlQuote($data->{$field});
			push @set_clauses, "$field = $data_q";
		}
	}
	$sql .= " SET " . join(", ", @set_clauses) if @set_clauses;

	$sql .= " WHERE $where" if $where;

	my $qlid = $self->_querylog_start("UPDATE", $table_str);
	my $rows = $self->sqlDo($sql);
	$self->_querylog_finish($qlid);
	return $rows;
}

########################################################
sub sqlDelete {
	my($self, $table, $where, $limit) = @_;
	$self->_refCheck($where);
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
	# What's inside /*! */ will be treated as a comment by most
	# other SQL servers, but MySQL will parse it.  Kinda pointless
	# since we've basically given up on ever supporting DBs other
	# than MySQL, but what the heck.
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
	$self->_refCheck($sql);
	$self->sqlConnect() or return undef;
	if (getCurrentStatic('utf8')) {
		is_utf8($sql) or $sql = decode_utf8($sql);
	}
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

	my @return = ("virtuser='$self->{virtual_user}'", "hostinfo='$self->{_dbh}->{mysql_hostinfo}'", $error);
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

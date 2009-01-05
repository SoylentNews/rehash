#!/usr/bin/perl -s
use warnings;
use strict;

# convert freeze to nfreeze

our($debug, $dump);

use Slash::Test shift || 'slash';

my $constants = getCurrentStatic();
my $slashdb = getCurrentDB();

update_nfreeze('users_info', 'uid', 'people');

update_nfreeze('message_drop', 'id', 'message')
	if $constants->{plugin}{Messages};

update_nfreeze('dilemma_agents', 'daid', 'memory')
	if $constants->{plugin}{Dilemma};

# this will take too much time to do; if we ever need to get this data
# out, we'll just need to find a little-endian 32-bit perl to do it with
#$slashdb = getObject('Slash::DB', { virtual_user => $constants->{log_db_user} });
#update_nfreeze('accesslog_admin', 'id', 'form');


sub update_nfreeze {
	my($table, $key, $blob) = @_;

	print "updating $blob in $table\n";
	my $sth = $slashdb->{_dbh}->prepare("SELECT $key, $blob FROM $table");
	$sth->execute or die;
	while (my $row = $sth->fetchrow_arrayref) {
		if ($row->[0] && $row->[1]) {
			print "updating $key $row->[0]\n" if $debug;
			print Dumper thaw($row->[1]) if $dump;
			if ($row->[1]) {
				$slashdb->sqlUpdate($table, {
					$blob => nfreeze(thaw($row->[1])),
				}, "$key=$row->[0]");
			}
		}
	}
	$sth->finish;
	print "\n";
}


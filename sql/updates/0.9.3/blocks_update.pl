#!/usr/bin/perl

################################################## 
# blocks_modify.pl PMG 030300
# use this script to update your blocks table if 
# you are not going to use the full dump file for
# 
# modifies (quick bugfix) to the sectionblocks table
# and then inserts the data for the new columns into
# the blocks table
################################################## 

use DBI;
use strict;

my $dbh ||= DBI->connect('DBI:mysql:database=yourdb;host=localhost', 'slash', 'slashpass') or die $DBI::errstr;
my $sth;
			
$dbh->do("ALTER TABLE sectionblocks modify column retrieve int(1) NOT NULL DEFAULT 0");

open(COL,"<blocks_update.txt") or die "where's the file blocks_update.txt?";

while(<COL>) {
	chomp;
	my ($bid,$type,$description) = split(/\t/,$_);
	$description = $dbh->quote($description);
	$sth = $dbh->prepare("UPDATE blocks SET type = '$type', description = $description WHERE bid = '$bid'");
	$sth->execute();
}

close(COL);

$sth->finish;
$dbh->disconnect;

exit(0);

#!/usr/bin/perl -w
# call from slash root as `sql/fix_matchname.pl`

BEGIN { @ARGV = '' }

use strict;
use lib '../../../';
use vars '%I';
use Slash;

*I = getSlashConf();
getSlash();

$I{dbh}->do(<<EOT) or die $I{dbh}->errstr;
alter table authors add matchname char(30)
EOT

$I{dbh}->do(<<EOT) or die $I{dbh}->errstr;
alter table users add matchname char(20)
EOT

my $sth = sqlSelectMany('aid', 'authors');
while (my($aid) = $sth->fetchrow) {
	(my $matchname = lc $aid) =~ s/[^a-zA-Z0-9]//g;
	sqlUpdate('authors', { matchname => $matchname }, "aid=" . $I{dbh}->quote($aid));
}

$sth = sqlSelectMany('nickname', 'users');
while (my($nick) = $sth->fetchrow) {
	(my $matchname = lc $nick) =~ s/[^a-zA-Z0-9]//g;
	sqlUpdate('users', { matchname => $matchname }, "nickname=" . $I{dbh}->quote($nick));
}


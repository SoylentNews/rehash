#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use vars qw( %task $me );
use Safe;
use Slash;
use Slash::DB;
use Slash::Display;
use Slash::Utility;

(my $VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

my $me = 'counthits.pl';

$task{$me}{timespec} = '30 6 * * *';
$task{$me}{standalone} = 1;

# Counts hits from accesslog and updates story metadata accordingly.
#
# Task Options:
#	since   = <date>; 	Grab counts since <date>; <date> = YYYYMMDD
#	replace = <bool>;	If True then Replace counts, if False then Add.
#	sid	= <char sid>;	If exists, only perform update on the given SID
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	# Process task specific options.
	my $sid = $constants->{task_options}{sid};
	my $replace = $constants->{task_options}{replace};
	#$replace = 1 if exists $constants->{task_options}{replace} && 
	#		!defined $replace;
	# This assures a value in $replace.
	#$replace ||= 0;
	
	my($year, $month, $day) = (localtime)[5,4,3];
	$year += 1900; $month++; $day--;
	my $yesterday = sprintf "%4d-%02d-%02d", $year, $month, $day;
	my $since = $constants->{task_options}{since};
	$since = $yesterday if ! $since;
	$since =~ s/(\d{4})(\d{2})(\d{2})/$1-$2-$3/g;

	# Grab list of stories within our purview.
	my(@stories) = map { $_ = $_->[0] } @{$slashdb->sqlSelectAll(
		'sid',
		'stories',
		"time between '$since 14:00' and now()",
		'order by sid'
	)};

	# This is NOT database independent. This will need to become a method
	# in Slash::DB::Static, when it becomes a problem.
	#my $accesslog = $slashdb->sqlSelectAll(
	#	'op, dat', 
	#	'accesslog',
	#);

	my(%count);
	my $sth = $slashdb->{_dbh}->prepare(<<EOT);
SELECT op, dat FROM accesslog WHERE
ts BETWEEN '$since 00:00' and '$yesterday 23:59'
EOT

	$sth->execute;
	my $accesslog_count = 0;
	while ($_ = $sth->fetchrow_arrayref) {
		$_->[1] =~ s{^(\w+/)+(\d{2}/\d{2}/\d{2}/.+)$}{$2};
		$count{$_->[1]}++ if $_->[0] eq 'article';
		$accesslog_count++;
	}
	$sth->finish;

	my $count = 0;
	for (keys %count) {
		next if $sid && $sid ne $_;

		# The row must exist in the stories database before we even
		# think about updating.
		my $found = $slashdb->sqlSelect(
			'discussion', 'stories', "sid='$_'"
		);
		next if !$found;

		# Optimized for sorted data.
		$replace = inList(\@stories, $_);
		$slashdb->sqlUpdate('stories', {
			-hits => (($replace) ? '':'hits+') . $count{$_},
		}, "sid='$_'");
		#printf STDERR "'$_' = %s$count{$_}\n", ($replace) ? ' ':'+';
		$count++;
	}
	slashdLog("$accesslog_count accesslog entries");
	slashdLog("Updated story counts on $count stories.");
};


# Assumes data in @{$a_ref} is sorted.
sub inList {
	my ($a_ref, $data) = @_;

	for (@{$a_ref}) {
		return 1 if $_ eq $data;
		return 0 if $_ gt $data;
	}
	return 0;
}

1;


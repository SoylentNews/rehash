#!/usr/bin/perl -w
# updates Slash pre-T_2_3_0_53 to the new timezones
# AFTER running the updates in sql/mysql/upgrades run this
#
#  perl dst-update.plx VIRTUAL_USER
#
# do not run more than once (no problems should occur, on multiple uses,
# but there is a slight chance), and if you have any custom TZs, you should
# handle those yourself.

use Slash::Test shift;

our $DEBUG = 1;

my %tzs = (
	'GMT'	=> ['GMT', ''],
	'UTC'	=> ['UTC', ''],

	'WET'	=> ['WEST', ''],
	'BST'	=> ['WEST', ''],
	'WEST'	=> ['WEST', ''],

	'CET'	=> ['CEST', ''],
	'MET'	=> ['CEST', ''],
	'MEW'	=> ['CEST', ''],
	'SWT'	=> ['CEST', ''],
	'FWT'	=> ['CEST', ''],

	'MES'	=> ['CEST', ''],
	'SST'	=> ['CEST', ''],
	'FST'	=> ['CEST', ''],
	'CEST'	=> ['CEST', ''],
# Israel does not have the same timezone change as Eastern Europe
	'ISS'	=> ['EEST', 'off'],
	'EET'	=> ['EEST', ''],

	'IDT'	=> ['EEST', 'on'],
	'EEST'	=> ['EEST', ''],
	'BT'	=> ['BT', ''],
	'IT'	=> ['IT', ''],
	'ZP4'	=> ['ZP4', ''],
	'ZP5'	=> ['ZP5', ''],
	'IST'	=> ['IST', ''],
	'ZP6'	=> ['ZP6', ''],
	'JT'	=> ['JT', ''],

	'CCT'	=> ['CCT', ''],
# Australian Western does not currently recognize DST, but if
# someone was set to D, leave it set to D
	'WAS'	=> ['AWST', 'off'],
	'AWST'	=> ['AWST', 'off'],

	'JST'	=> ['JST', ''],
	'WAD'	=> ['AWST', 'on'],
	'AWDT'	=> ['AWST', 'on'],

	'CAS'	=> ['ACST', ''],
	'ACST'	=> ['ACST', ''],

	'EAS'	=> ['AEST', ''],
	'AEST'	=> ['AEST', ''],

	'CAD'	=> ['ACST', ''],
	'ACDT'	=> ['ACST', ''],

	'EAD'	=> ['AEST', ''],
	'AEDT'	=> ['AEST', ''],

	'NZT'	=> ['NZST', ''],
	'NZS'	=> ['NZST', ''],

	'IDLE'	=> ['IDLE', ''],
	'NZD'	=> ['NZST', ''],

	'WAT'	=> ['WAT', ''],
	'AT'	=> ['AT', ''],
	'NDT'	=> ['NST', ''],
	'ADT'	=> ['AST', ''],
	'GST'	=> ['GST', ''],
	'NFT'	=> ['NST', ''],
	'NST'	=> ['NST', ''],
	'EDT'	=> ['EST', ''],
	'AST'	=> ['AST', ''],
	'CDT'	=> ['CST', ''],
	'EST'	=> ['EST', ''],
	'MDT'	=> ['MST', ''],
	'CST'	=> ['CST', ''],
	'PDT'	=> ['PST', ''],
	'MST'	=> ['MST', ''],
	'YDT'	=> ['AKST', ''],
	'PST'	=> ['PST', ''],
	'HDT'	=> ['HAST', ''],
	'YST'	=> ['AKST', ''],
	'HST'	=> ['HAST', ''],
	'CAT'	=> ['HAST', ''],
	'AHS'	=> ['HAST', ''],
	'NT'	=> ['NT', ''],
	'IDL'	=> ['IDLW', ''],
);

my $dbh = $slashdb->{_dbh};
my $sql1 = 'SELECT uid FROM users_prefs WHERE tzcode = ?';
my $sql2 = 'UPDATE users_prefs SET tzcode = ? WHERE tzcode = ?';

my $sth1 = $dbh->prepare($sql1);
my $sth2 = $dbh->prepare($sql2);

my %users;

for my $tz (sort keys %tzs) {
	my $dat = $tzs{$tz};
	next if $tz eq $dat->[0] && $dat->[1] == 0;

	if ($dat->[1] != 0) {
		print "Converting users for $tz to manual DST ($dat->[1])\n" if $DEBUG;
		$sth1->execute($tz);
		my @uids = map { $_->[0] } @{ $sth1->fetchall_arrayref };
		for my $uid (grep { !exists $users{$_} } @uids) {
			print "  $uid\n" if $DEBUG;
			$slashdb->setUser($uid, { dst => $dat->[1] });
			$users{$uid}++;
		}
	}

	if ($tz ne $dat->[0]) {
		print "Converting users for $tz to $dat->[0]\n" if $DEBUG;
		$sth2->execute($dat->[0], $tz);
	}
}

__END__

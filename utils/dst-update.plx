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

	'WET'	=> ['WET', ''],
	'BST'	=> ['WET', ''],
	'WES'	=> ['WET', ''],
	'WEST'	=> ['WET', ''],

	'CET'	=> ['CET', ''],
	'MET'	=> ['CET', ''],
	'MEW'	=> ['CET', ''],
	'SWT'	=> ['CET', ''],
	'FWT'	=> ['CET', ''],

	'MES'	=> ['CET', ''],
	'SST'	=> ['CET', ''],
	'FST'	=> ['CET', ''],
	'CES'	=> ['CET', ''],
	'CEST'	=> ['CET', ''],
# Israel does not have the same timezone change as Eastern Europe
	'ISS'	=> ['EET', 'off'],
	'EET'	=> ['EET', ''],

	'IDT'	=> ['EET', 'on'],
	'EES'	=> ['EET', ''],
	'EEST'	=> ['EET', ''],
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

	'ID2'	=> ['IDLE', ''],
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
	'AKST'	=> ['AKST', ''],
	'AKDT'	=> ['AKST', ''],
	'HST'	=> ['HAST', ''],
	'CAT'	=> ['HAST', ''],
	'AHS'	=> ['HAST', ''],
	'NT'	=> ['NT', ''],
	'IDL'	=> ['IDLW', ''],

	''	=> ['EST', ''],
);

my $dbh = $slashdb->{_dbh};
my $sql1 = 'SELECT uid FROM users_prefs WHERE tzcode = ?';
my $sql2 = 'UPDATE users_prefs SET tzcode = ? WHERE tzcode = ?';

my $sth1 = $dbh->prepare($sql1);
my $sth2 = $dbh->prepare($sql2);

my %users;

for my $tz (sort keys %tzs) {
	my $dat = $tzs{$tz};
	next if $tz eq $dat->[0] && !$dat->[1];

	if ($dat->[1]) {
#		print "Converting users for $tz to manual DST ($dat->[1])\n" if $DEBUG;
		my @converted = ( );
		$sth1->execute($tz);
		my @uids = map { $_->[0] } @{ $sth1->fetchall_arrayref };
		for my $uid (grep { !exists $users{$_} } @uids) {
#			print "  $uid\n" if $DEBUG;
			push @converted, $uid;
			$slashdb->setUser($uid, { dst => $dat->[1] });
			$users{$uid}++;
		}
		my $num = scalar(@converted);
		my $uidlist = "";
		if ($num) {
			my @converted_short = @converted;
			if ($#converted_short > 5) {
				$#converted_short = 5;
				push @converted_short, "...";
			}
			$uidlist = ": @converted_short" if @converted_short;
		}
		print "Converted $num users from $tz to manual DST ($dat->[1])$uidlist\n";
	}

	if ($tz ne $dat->[0]) {
#		print "Converting users for $tz to $dat->[0]\n" if $DEBUG;
		my $rows = $sth2->execute($dat->[0], $tz);
		$rows += 0; # convert 0E0 to 0
		print "Converted $rows users from $tz to $dat->[0]\n";
	}
}

1 if $DEBUG; # avoid possible "used only once" error

__END__

#!perl -w
use Slash::Test shift;

my $friends = $slashdb->sqlSelectAll("uid,friend", "journal_friends");
for my $id (@$friends) {
	$slashdb->sqlReplace("people", {
		uid	=> $id->[0],
		person	=> $id->[1],
		type	=> "friend",
	});
}

# catch the headlines-only people
my $prefs = $slashdb->sqlSelectAll(<<COLS, <<TABLES, <<WHERE);
up1.uid, up1.value
COLS
users_param AS up1
TABLES
up1.name="messagecodes_1"
WHERE

for my $user (@$prefs) {
	my $uid   = $user->[0];
	my $mode  = $user->[1] ? 0 : -1;

	$slashdb->sqlReplace("users_messages", {
		uid	=> $uid,
		code	=> 1,
		mode	=> $mode,
	});
}


my $prefs = $slashdb->sqlSelectAll(<<COLS, <<TABLES, <<WHERE);
upd.uid, upd.value, up0.value, up1.value, up2.value,
up3.value, up4.value, up5.value, up6.value
COLS
users_param as upd, users_param as up0, users_param as up1, users_param as up2,
users_param as up3, users_param as up4, users_param as up5, users_param as up6
TABLES
upd.uid=up0.uid AND upd.uid=up1.uid AND upd.uid=up2.uid AND upd.uid=up3.uid AND
upd.uid=up4.uid AND upd.uid=up5.uid AND upd.uid=up6.uid AND
upd.name="deliverymodes"  AND up0.name="messagecodes_0" AND
up1.name="messagecodes_1" AND up2.name="messagecodes_2" AND
up3.name="messagecodes_3" AND up4.name="messagecodes_0" AND 
up5.name="messagecodes_5" AND up6.name="messagecodes_0"
WHERE

for my $user (@$prefs) {
	my $uid   = $user->[0];
	my $mode  = $user->[1];

	# set up proper mode for each
	my @codes = map { $_ ? $mode : -1 } @{$user}[2..8];

	# disallow web for new submissions and nightly mails
	for (0, 1, 6) {
		$codes[$_] = 0 if $codes[$_] == 1;
	}

	# set each
	for (my $i = 0; $i < @codes; $i++) {
		$slashdb->sqlReplace("users_messages", {
			uid	=> $uid,
			code	=> $i,
			mode	=> $codes[$i],
		});
	}
}

__END__

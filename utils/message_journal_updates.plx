#!perl -w
use Slash::Test shift;

=pod

# populate new "people" table
my $friends = $slashdb->sqlSelectAll("uid,friend", "journal_friends");
for my $id (@$friends) {
	$slashdb->sqlReplace("people", {
		uid	=> $id->[0],
		person	=> $id->[1],
		type	=> "friend",
	});
}

=cut

for my $code (0..6) {
	my $prefs = $slashdb->sqlSelectAll(<<COLS, <<TABLES, <<WHERE);
upd.uid, upd.value, upc.value
COLS
users_param AS upd, users_param AS upc
TABLES
upd.uid=upc.uid AND
upd.name="deliverymodes" AND upc.name="messagecodes_$code"
WHERE

	for my $user (@$prefs) {
		my $uid   = $user->[0];
		my $mode  = $user->[1];
		my $val   = $user->[2];
		$mode = $val && $mode >= 0
			? ($code =~ /^(?:0|1|6)$/ ? 0 : $mode)
			: -1;

		$slashdb->sqlReplace("users_messages", {
			uid     => $uid,
			code    => $code,
			mode    => $mode,
		});
	}
}

__END__

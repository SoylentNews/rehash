#!perl -w
use Slash::Test shift;

$slashdb->sqlDelete("users_param", "name='sectioncollapse' AND value='0'");

my $mp_tid = $constants->{mainpage_nexus_tid} || 1;
my $nexuses = $slashdb->getNexusChildrenTids($mp_tid);

$slashdb->sqlDo("LOCK TABLES users_index WRITE, users_param WRITE");

my $uid_ar = $slashdb->sqlSelectColArrayref("uid", "users_param",
	"name='sectioncollapse' AND value='1'",
	"ORDER BY uid");

for my $i (0..$#$uid_ar) {
	my $uid = $uid_ar->[$i];
	my($san, $snn) = $slashdb->sqlSelect(
		"story_always_nexus, story_never_nexus",
		"users_index",
		"uid='$uid'");
	# Get the complete list of all nexuses that are always wanted:
	# the children of the mainpage (that's what 'sectioncollapse'
	# means), plus any explicitly named by the user.
	my %san = map { s/'//g; ($_, 1) } (@$nexuses, split /,/, $san);
	# Get the list of all nexuses that are never wanted.
	my %snn = map { s/'//g; ($_, 1) }             split /,/, $snn ;
	# "Never" overrides "always" in case both appear.
	for my $tid (keys %snn) { delete $san{$tid} }
	# Now write out the new "always" list for this user.
	my $san_new = join ",", sort { $a <=> $b } keys %san;
	$slashdb->sqlUpdate(
		"users_index",
		{ story_always_nexus => $san_new },
		"uid='$uid'");
	print "." if $i % 100 == 99;
}
print "\n";

$slashdb->sqlDo("UNLOCK TABLES");

$slashdb->sqlDelete("users_param", "name='sectioncollapse'");


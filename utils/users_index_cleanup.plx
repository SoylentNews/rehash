#!perl -w
use Slash::Test shift;

$| = 1;

my $mp_tid = getCurrentStatic('mainpage_nexus_tid');
my $nexuses = $slashdb->getNexusChildrenTids($mp_tid);
my $authors = $slashdb->sqlSelectColArrayref("uid", "authors_cache");

my $isNexus =  {( map { ($_, 1) } @$nexuses )};
my $isAuthor = {( map { ($_, 1) } @$authors )};

$slashdb->sqlDo("LOCK TABLES users_index WRITE, users_param WRITE");
$slashdb->sqlDo("SET AUTOCOMMIT=0");

my $uid_ar = $slashdb->sqlSelectColArrayref("uid", "users_index",
	"story_always_nexus != '' OR story_never_nexus != '' OR story_never_topic != ''",
	"ORDER BY uid");

for my $i (0..$#$uid_ar) {
	my $uid = $uid_ar->[$i];
	my($san, $snn, $sna) = $slashdb->sqlSelect(
		"story_always_nexus, story_never_nexus, story_never_author",
		"users_index",
		"uid='$uid'");

	my %san = map { s/'//g; ($_, $isNexus->{$_}  ? 1 : 0) } (split /,/, $san);
	my %snn = map { s/'//g; ($_, $isNexus->{$_}  ? 1 : 0) } (split /,/, $snn);
	my %sna = map { s/'//g; ($_, $isAuthor->{$_} ? 1 : 0) } (split /,/, $sna);

	# "Never" overrides "always" in case both appear.
	for my $tid (keys %snn) { delete $san{$tid} }

	# Now write out the new data for this user.
	my $snn_new = join ",", sort { $a <=> $b } keys %snn;
	my $san_new = join ",", sort { $a <=> $b } keys %san;
	my $sna_new = join ",", sort { $a <=> $b } keys %sna;
	$slashdb->sqlUpdate(
		"users_index",
		{ story_never_nexus   => $snn_new,
		  story_always_nexus  => $san_new,
		  story_never_author  => $sna_new,
		  story_always_topic  => '',
		  story_always_author => '',		},
		"uid='$uid'");
	print "." if $i % 100 == 99;
}
print "\n";

$slashdb->sqlDo("COMMIT");
$slashdb->sqlDo("SET AUTOCOMMIT=1");
$slashdb->sqlDo("UNLOCK TABLES");


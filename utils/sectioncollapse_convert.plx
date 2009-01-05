#!perl -w
use Slash::Test shift;

$| = 1;

$slashdb->sqlDelete("users_param", "name='sectioncollapse' AND value='0'");

my $mp_tid = $constants->{mainpage_nexus_tid} || 1;
my $nexuses = $slashdb->getNexusChildrenTids($mp_tid);
my $tree = $slashdb->getTopicTree();

my $skins = $slashdb->getSkins();
my %skin_nex = ( );
for my $skid (keys %$skins) {
	$skin_nex{$skins->{$skid}{name}} = $skins->{$skid}{nexus};
}

my %nonnex_tid = ( );
for my $tid (sort { $b <=> $a } keys %$tree) {
	next if $tree->{$tid}{nexus};
	$nonnex_tid{$tree->{$tid}{keyword}} = $tid;
}

$slashdb->sqlDo("LOCK TABLES users_index WRITE, users_param WRITE");

my $uid_ar = $slashdb->sqlSelectColArrayref("uid", "users_param",
	"name='sectioncollapse' AND value='1'",
	"ORDER BY uid");

for my $i (0..$#$uid_ar) {
	my $uid = $uid_ar->[$i];
	my($san, $snn, $snt) = $slashdb->sqlSelect(
		"story_always_nexus, story_never_nexus, story_never_topic",
		"users_index",
		"uid='$uid'");

	# Get the complete list of all nexuses that are always wanted:
	# the children of the mainpage (that's what 'sectioncollapse'
	# means), plus any explicitly named by the user.
	my %san  = map { s/'//g; ($_, 1) } (@$nexuses, split /,/, $san);

	# Get the list of all nexuses that are never wanted.  This data
	# may be in either of two forms: 1,2,3 or 'foo','bar','baz',
	# where the text is the name of a skin whose nexus we want.
	# Handle either one.  First read it into snn1, then convert as
	# necessary into snn.
	my %snn1 = map { s/'//g; ($_, 1) }		split /,/, $snn;
	my %snn  = map { (($_ =~ /^\d+$/
			   ? (	$tree->{$_}{nexus}
				? 1 : 0 )
			   : ($skin_nex{$_} || 'invalid')
			  ), 1
			 )		 }		keys %snn1;
	delete $snn{invalid}; # just in case there was invalid data

	# Get the list of all topics that are never wanted.  Again,
	# this may appear as numeric or keyword.  This time the
	# keywords are for topics not skins.
	my %snt1 = map { s/'//g; ($_, 1) }		split /,/, $snt;
	my %snt  = map { (($_ =~ /^\d+$/
			   ? (	$tree->{$_}{nexus}
				? 0 : 1 )
                           : ($nonnex_tid{$_} || 'invalid')
                          ), 1
                         )               }              keys %snn1;
	delete $snt{invalid}; # just in case there was invalid data

	# "Never" overrides "always" in case both appear.
	for my $tid (keys %snn) { delete $san{$tid} }

	# Now write out the new data for this user.
	my $snn_new = join ",", sort { $a <=> $b } keys %snn;
	my $san_new = join ",", sort { $a <=> $b } keys %san;
	my $snt_new = join ",", sort { $a <=> $b } keys %snt;
	$slashdb->sqlUpdate(
		"users_index",
		{ story_never_nexus => $snn_new,
		  story_always_nexus => $san_new,
		  story_never_topic => $snt_new },
		"uid='$uid'");
	print "." if $i % 100 == 99;
}
print "\n";

$slashdb->sqlDo("UNLOCK TABLES");

$slashdb->sqlDelete("users_param", "name='sectioncollapse'");


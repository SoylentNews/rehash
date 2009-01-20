use Slash::Test shift;

my $skins = $slashdb->getSkins();

foreach my $skid (keys %$skins) {
	my $skin = $slashdb->getSkin($skid);
	my $data = {
		section_name 	=> $skin->{title},
		section_filter 	=> $skin->{name},
		display		=> $skin->{skinindex},
		skid		=> $skid
	};
	$slashdb->sqlInsert("firehose_section", $data);
}


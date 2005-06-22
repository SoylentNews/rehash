use Slash::Test shift;
use Slash::ResKey;

my $reskey;

for (1..2) {
	$reskey = new Slash::ResKey 'comments';

	handle($reskey->create);
	handle($reskey->touch);
	handle($reskey->touch);
	handle($reskey->use);
	handle($reskey->use);

	print Dumper $reskey;
}


sub handle {
	my($success) = @_;
	if ($success) {
		printf "\u$reskey->{type}'d $reskey->{reskey}\n";
	} else {
		printf "Error on %s: %s\n", $reskey->{type}, $reskey->errstr;
	}
}

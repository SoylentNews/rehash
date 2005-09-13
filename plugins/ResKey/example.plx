use Slash::Test shift;

my($reskey, $key);

for (1..1) {
	$reskey = getObject('Slash::ResKey');
	$rkey = $reskey->key('comments');

	handle($rkey->create);
	handle($rkey->touch);
	handle($rkey->touch);
	handle($rkey->use);
sleep 121;
	handle($rkey->use);

	print Dumper $rkey;
}


sub handle {
	my($success) = @_;
	if ($success) {
		printf "\u$rkey->{type}'d $rkey->{reskey}\n";
	} else {
		printf "Error on %s: %s\n", $rkey->{type}, $rkey->errstr;
	}
}

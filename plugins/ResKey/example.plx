use strict;
use Slash::Test shift;

my($reskey, $rkey, $rkey2, $rkey3);

my $debug = 0;

for (1..1) {
	$reskey = getObject('Slash::ResKey');
	$rkey = $reskey->key('comments', {
		debug	=> $debug
	});

	handle($rkey->create);
	handle($rkey->touch);

	$rkey2 = $reskey->key('comments', {
		debug	=> $debug,
		reskey	=> $rkey->reskey,
	});

	handle($rkey2->touch);

	handle($rkey->use);
	sleep 5;

	$::form->{rkey} = $rkey->reskey;
	$rkey3 = $reskey->key('comments', {
		debug	=> $debug,
	});

	handle($rkey3->use);

	print Dumper $rkey;
}


sub handle {
	my($success) = @_;
	if ($success) {
		printf "%s'd %s\n", ucfirst($rkey->type), $rkey->reskey;
	} else {
		printf "Error on %s: %s\n", $rkey->type, $rkey->errstr;
		print Dumper $rkey;
	}
}

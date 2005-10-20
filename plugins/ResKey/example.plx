use strict;
use Slash::Test shift;

my($reskey, $rkey, $rkey1, $rkey2, $rkey3);

my $debug = 0;

for (1..1) {
	$reskey = getObject('Slash::ResKey');
	$rkey = $reskey->key('pollbooth', {
		debug	=> $debug
	});
	handle($rkey->createuse, $rkey);

	print Dumper $rkey;


	$rkey1 = $reskey->key('comments', {
		debug	=> $debug
	});

	handle($rkey1->create, $rkey1);
	handle($rkey1->touch,  $rkey1);

	$rkey2 = $reskey->key('comments', {
		debug	=> $debug,
		reskey	=> $rkey1->reskey,
	});

	handle($rkey2->touch, $rkey2);

	handle($rkey1->use, $rkey1);
	sleep 5;

	$::form->{reskey} = $rkey1->reskey;
	$rkey3 = $reskey->key('comments', {
		debug	=> $debug,
	});
	handle($rkey3->use, $rkey3) or print Dumper $rkey3;
}


sub handle {
	my($success, $this_rkey) = @_;
	if ($success) {
		printf "%s'd %s\n", ucfirst($this_rkey->type), $this_rkey->reskey;
		return 1;
	} else {
		printf "Error on %s: %s\n", $this_rkey->type, $this_rkey->errstr;
		print Dumper $this_rkey;
	}
}

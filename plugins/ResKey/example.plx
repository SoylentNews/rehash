#!/usr/bin/perl
use warnings;
use strict;

use Slash::Test shift;

my($reskey, $rkey, $rkey1, $rkey2, $rkey3, $lkey);

my $debug = 0;

for (1..1) {
	$reskey = getObject('Slash::ResKey');

# 	$lkey = $reskey->key('comments-moderation-ajax', {
# 		debug	=> $debug
# 	});
# 
# 	handle($lkey, 'create');
# 	handle($lkey, 'use') for 0..19;
# 
# 
# 	$rkey = $reskey->key('pollbooth', {
# 		debug	=> $debug,
# 		qid	=> 1
# 	});
# 	handle($rkey, 'createuse');


	$rkey1 = $reskey->key('comments', {
		debug	=> $debug
	});

	handle($rkey1, 'create');
	handle($rkey1, 'touch');
	chomp(my $answer = <>);
	getCurrentForm()->{hcanswer} = $answer;
	handle($rkey1, 'use');

use Data::Dumper;
print $rkey1;
exit;

	$rkey2 = $reskey->key('comments', {
		debug	=> $debug,
		reskey	=> $rkey1->reskey,
	});

	handle($rkey2, 'touch');
	sleep 5;
	handle($rkey1, 'use');

	$::form->{reskey} = $rkey1->reskey;
	$rkey3 = $reskey->key('comments', {
		debug	=> $debug,
	});
	handle($rkey3, 'use');
}


sub handle {
	my($this_rkey, $method) = @_;

	debug_it($this_rkey);

	my $success = $this_rkey->$method;

	if ($success) {
		printf "%s'd %s\n", ucfirst($this_rkey->type), $this_rkey->reskey;
		debug_it($this_rkey);
		return 1;
	} else {
		printf "Error on %s: %s\n", $this_rkey->type, $this_rkey->errstr;
		debug_it($this_rkey, 1);
	}
}

sub debug_it {
	my($this_rkey, $over) = @_;
	print Dumper $this_rkey if $over || $debug > 1;
}

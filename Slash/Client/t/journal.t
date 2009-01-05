#!/usr/bin/perl -w
use Test::More;
use strict;

BEGIN {
	$|++;
	plan tests => 10;
	use_ok('Slash::Client');
	use_ok('Slash::Client::Journal');
}

my $id   = 10_000;
my $host = 'use.perl.org';

my %checks = (
	id		=> $id,
	discussion_id	=> 10676,
	uid		=> 44,
	nickname	=> 'brian_d_foy',
	subject		=> '10,000th post',
);


my $client = Slash::Client::Journal->new({
	host => $host,
	uid  => '-',  # NOTE: setting uid/pass to bad values ensures
	pass => '-'   # we don't get logged in, which is what we want,
	              # to ensure we don't delete anything by accident
});
ok($client, 'Create object');

my $result = $client->get_entry($id);
ok($result, 'Get entry');

for (sort keys %checks) {
	is($checks{$_}, $result->{$_}, "Check return value for $_");
}

ok(!$client->delete_entry($id), "Can't delete, we aren't logged in");


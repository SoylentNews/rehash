#!/usr/bin/perl -w
use strict;
use LWP::Simple;
use Slash::Test qw(slash);
use vars qw($slashdb);

# set up the $url, $ipid, $subnetid
# i usually just run with the default ipid/subnetid, then fill in the blanks
# when i see the error containing what it should be

my $rootdir	= 'http://slash.site';
my $sid		= 2;
my $ipid	= '2381dd4dbfb2855c1177ce57d4b80f24';
my $subnetid	= '0de1879125ff071fe832255f1f798485';

my $url = $rootdir . '/comments.pl?sid=' . $sid . '&cid=0&pid=0&op=Reply';

while (1) {
	my($formkey) = (get($url) =~ /NAME="formkey" VALUE="(.+?)"/);
	my $data = $slashdb->sqlSelectArrayRef(<<EOT, "formkeys", "formkey='$formkey'");
formkey,formname,id,idcount,uid,ipid,subnetid,value,last_ts,ts,submit_ts,content_length
EOT

	if (
		   $data->[0]  eq $formkey
		&& $data->[1]  eq 'comments'
		&& $data->[2]  eq ''
		&& $data->[3]  == 0
		&& $data->[4]  == 1
		&& $data->[5]  eq $ipid
		&& $data->[6]  eq $subnetid
		&& $data->[7]  == 0
		&& $data->[8]  == 0
		&& $data->[9]  <= time()
		&& $data->[10] == 0
		&& $data->[11] == 0
	) {
		printf "%s : %s\n", $formkey, scalar localtime $data->[9];
	} else {
		printf "%s : %s\n", $formkey, scalar localtime $data->[9];
		print Dumper $data;
	}

	sleep 1;
}


# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

use vars '$loaded';
$ENV{SLASH_USER} = 2;
BEGIN { $| = 1; print "1..42\n"; }
END {print "not ok 1\n" unless $loaded;}
use Slash::Messages;
$loaded = 1;
print "ok 1\n";
print "$_\n" for 2..42;
exit;
# ignore the rest of this for now ...

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

use strict;
use Slash 2.001;
use Slash::Utility;
$ARGV[0] ||= 'virtual_user=slash';
createEnvironment();

ok(my $obj = getObject('Slash::Messages'));
exit unless $obj;

ok(my $id1 = $obj->create(2, 3, "This is a message!", 1));
if ($id1) {
	if (ok(my $msg = $obj->get($id1))) {
		ok2($msg->{id},		$id1);
		ok2($msg->{user}{uid},	2);
		ok2($msg->{code},	3);
		ok2($msg->{message},	"This is a message!", 1);
		ok2($msg->{fuser}{uid},	1);
		ok2($msg->{type},	"Moderation of Comment", 1);
	}
}

ok(my $id1a = $obj->create(2, 3, "This is a message!", 1));
if ($id1a) {
	if (ok(my $msg = $obj->get($id1a))) {
		ok2($msg->{id},		$id1a);
		ok2($msg->{user}{uid},	2);
		ok2($msg->{code},	3);
		ok2($msg->{message},	"This is a message!", 1);
		ok2($msg->{fuser}{uid},	1);
		ok2($msg->{type},	"Moderation of Comment", 1);
	}
}

# from, type, message
ok(my $id2 = $obj->create(2, "Reply to Comment", {
	template_name	=> "commentreply",
	cid1		=> {
		date		=> "20010403162343",
		subj		=> "Whee!",
	},
	cid2		=> {
		date		=> "20010403164633",
		subj		=> "Damn!",
	},	
	sid		=> {
		subj		=> "GPL Violated in Broad Daylight",
	},
	rid		=> {
		nickname	=> "doofus",
	},
	
}));

if ($id2) {
	if (ok(my $msg = $obj->get($id2))) {
		ok2($msg->{id},		$id2);
		ok2($msg->{user}{uid},	2);
		ok2($msg->{code},	4);
		ok(length($msg->{message}) > 256, "Message: '$msg->{message}' too short");
		ok2($msg->{fuser},	0);
		ok2($msg->{type},	"Reply to Comment", 1);
	}
}

# from, type, message
ok(my $id2a = $obj->create(2, "Reply to Comment", {
	template_name	=> "commentreply",
	cid1		=> {
		date		=> "20010403162343",
		subj		=> "Whee!",
	},
	cid2		=> {
		date		=> "20010403164633",
		subj		=> "Damn!",
	},	
	sid		=> {
		subj		=> "GPL Violated in Broad Daylight",
	},
	rid		=> {
		nickname	=> "doofus",
	},
	
}));

if ($id2a) {
	if (ok(my $msg = $obj->get($id2a))) {
		ok2($msg->{id},		$id2a);
		ok2($msg->{user}{uid},	2);
		ok2($msg->{code},	4);
		ok(length($msg->{message}) > 256, "Message: '$msg->{message}' too short");
		ok2($msg->{fuser},	0);
		ok2($msg->{type},	"Reply to Comment", 1);
	}
}

ok(($obj->process($id1a, $id2a)), 2);

ok(my $msgs1 = $obj->gets);
ok((my $count = @$msgs1) > 1);
ok($obj->send($id1), 1);
ok($obj->send($id2), 1);
ok2($obj->delete($id1, $id2), 2);
ok(my $msgs2 = $obj->gets);
ok2($count, (@$msgs2 + 2));

sub ok {
	$loaded++;
	print "not " unless $_[0];
	print "ok $loaded";
	print " ($_[1])" if !$_[0] && $_[1];
	print "\n";
	return $_[0];
}

sub ok2 {
	return ok(($_[2] ? $_[0] eq $_[1] : $_[0] == $_[1]),
		"Expected '$_[1]', got '$_[0]'");
}

__END__

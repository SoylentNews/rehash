# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..9\n"; }
END {print "not ok 1\n" unless $loaded;}
use Slash::DB;
$loaded = 1;

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

my $object = new Slash::DB('slash');
$object->sqlConnect();

########################################################################
my $uid = $object->createUser('dipy', 'dork@example.com', 'dipy');
print "ok 1\n";

my $user = $object->getUserInstance($uid);
print "ok 2\n";

$user = $object->setUser($uid, {passwd => 'friend'});
print "ok 3\n";

$user = $object->getUser($uid);
print "ok 4\n";

$uid = $object->getUserUID($user->{nickname});
print "ok 5\n";

my $auth = $object->getUserAuthenticate($user->{uid},
																				$user->{passwd},
																				2);
print "ok 6\n";

$object->setUser($uid, {icq => 'work'});
print "ok 7\n";

$object->setUser($uid, {icq => '98349343'});
print "ok 8\n";

$object->deleteUser($uid);
print "ok 9\n";

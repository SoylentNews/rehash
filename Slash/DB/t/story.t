# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..4\n"; }
END {print "not ok 1\n" unless $loaded;}
use Slash::DB;
$loaded = 1;

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

my $object = new Slash::DB('slash');
$object->sqlConnect();

my $time = $object->getTime();

my %story =  (
		uid		=> 2,
		tid		=> 'articles',
		dept		=> 'Story testers',
		'time'		=> $time,
		title		=> 'Test Story',
		section		=> 'articles',
		bodytext	=> 'This is body text',
		introtext	=> 'This is intro text',
		relatedtext	=> 'Some related text',
		displaystatus	=> 0,
		commentstatus	=> 0,
		flags		=> "",
);

########################################################################
my $sid = $object->createStory(\%story);

my $story = $object->getStory($sid);
print "ok 1\n";

$object->setStory($sid, , {picture => 'http://madhatter.com/hat.jpg'});
print "ok 2\n";

$object->setStory($sid, , {picture => 'http://madhatter.org/hat.jpg'});
print "ok 3\n";

my $stories = $object->getStories();
print "ok 4\n";

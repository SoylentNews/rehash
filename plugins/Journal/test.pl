# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

$ENV{SLASH_USER} = 2;
BEGIN { $| = 1; print "1..1\n"; }
END {print "not ok 1\n" unless $loaded;}
use Slash::Journal;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

my $object = Slash::Journal->new('slash');
print "ok 2\n";


my $articles = $object->gets(2);
for(@$articles) {
	print "@$_\n";
}
print "ok 3\n";
my $article = $object->get(2);
for(keys %$article) {
	print "$_:$article->{$_}\n";
}
print "ok 4\n";
my $entry = $object->create("This is a description", "This is a journal entry");
print "INSERT $entry\n";
print "ok 5\n";
$object->set($entry, {
	description => 'This is a description, updated',
	article => 'This is a journal entry, updated'
});
print "ok 6\n";
$object->add(1);
$object->add(2);
my $friends = $object->friends;
for(@$friends) {
	print "\t@$_\n";
}
print "ok 7\n";
$object->delete(2);
$friends = $object->friends;
for(@$friends) {
	print "\t@$_\n";
}
$object->delete(1);
print "ok 8\n";
my $top = $object->top;
for(@$top) {
	print "\t@$_\n";
}
print "ok 9\n";
my $themes = $object->themes;
for(@$themes) {
	print "\t$_\n";
}

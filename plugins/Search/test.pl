# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..1\n"; }
END {print "not ok 1\n" unless $loaded;}
use Slash::Search;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

my $object = Slash::Search->new('slash');
print "ok 2\n";
my $form = {};
$form->{query}		||= "";
$form->{section}	||= "";
$form->{min}		||= 0;
$form->{max}		||= 30;
$form->{threshold}	||= 0;
$form->{'last'}		||= $form->{min} + $form->{max};
my $data = $object->findUsers($form, ['Anonymous Coward']);
for(@$data) {
	print "@$_\n";
}
print "ok 3\n";
$form->{query} = "krow";
my $data = $object->findUsers($form);
for(@$data) {
	print "@$_\n";
}
print "ok 4\n";
$form->{query} = "";
my $comments = $object->findComments($form);
for(@$comments) {
	print "@$_\n";
}
print "ok 5\n";
$form->{query} = "";
my $stories = $object->findStory($form);
for(@$stories) {
	print "@$_\n";
}
print "ok 6\n";

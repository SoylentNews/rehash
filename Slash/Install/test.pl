# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..3\n"; }
END {print "not ok 1\n" unless $loaded;}
use Slash::Install;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

my $object = Slash::Install->new('slash');
print "ok 2\n";

$object->create({ name => 'plugin', value => 'eek'});
print "ok 3\n";

my $value = $object->get('plugin');
print "Name:$value->{name}:$value->{value}\n";
print "ok 4\n";

$object->create({ name => 'plugin', value => 'bleek'});
$value = $object->get('plugin');
for my $row (keys %$value) {
	print "Name:$row:$row->{name}:$row->{value}\n";
}

print "ok 4\n" if $value; 

my $value = $object->getValue('plugin');
print "VALUE:$value:\n";

print "ok 5\n"; 

my $plugins = $object->getPluginList("/usr/local/slash");
for(keys %$plugins) {
	print "$_:$_->{name} \n";
}

print "ok 6\n"; 

$object->delete('plugin');

print "ok 7\n"; 

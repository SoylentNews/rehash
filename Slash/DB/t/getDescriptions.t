# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

use Slash::DB;

BEGIN { $| = 1; print "1..1\n"; }
print "ok 1\n";

my $object = new Slash::DB('slash');
$object->sqlConnect();

########################################################################
my @list = qw |
	sortcodes
	statuscodes
	tzcodes
	tzdescription
	dateformats
	datecodes
	commentmodes
	threshcodes
	postmodes
	issuemodes
	vars
	topics
	maillist
	session_login
	displaycodes
	commentcodes
	sections
	static_block
	portald_block
	color_block
	authors
	admins
	users
	templates
	templatesbypage
	templatepages
	sectionblocks
|;

for (@list) {
	my $desc = $object->getDescriptions($_,0);
}

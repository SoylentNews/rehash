#!/usr/bin/perl -w

###############################################################################
#  $Id$
###############################################################################

use strict;
use lib '../';
use vars '%I';
use Slash;

sub main {
	*I = getSlashConf();

	my($adminuser, $passwd);
	print "This script will create a default author for your slashcode site\n";
	print "What is the name of the admin you'd like to use for your site? ";
	chomp($adminuser = <STDIN>);
	print "Enter the password for this user (try to use a good password for\n" .
		"security's sake!) ";
	chomp($passwd = <STDIN>);

	authorCreate($adminuser, $passwd) or die "unable to create adminuser $adminuser\n";
	print <<EOT;

----------------------------------------------------------------------------------
User $adminuser has been created with the password you specified. Now you
can log into the backend of your site via the admin interface 
$I{rootdir}/admin.pl, with this admin user, where you can edit this admin user's 
preferences, as well as other administrative tasks.  As a good security practise,
try to change this admin's password on a regular basis. Good luck with your
slashcode site!
----------------------------------------------------------------------------------

EOT


}

##################################################################
# Author create 
sub authorCreate {
	my($adminuser, $passwd) = @_;

	(my $matchname = lc $adminuser) =~ s/[^a-zA-Z0-9]//g;

	$I{dbh}->do("INSERT INTO authors values ('$adminuser','$adminuser'," .
		"'http://www.example.com','$adminuser\@example.com','test quote'," .
		"'test copy','$passwd',10000,'','',0,'$matchname')")
		or print "DBI::errstr $! couldn't insert admin user\n";
}

main();

$I{dbh}->disconnect if $I{dbh};

1;

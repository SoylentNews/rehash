#!/usr/bin/perl -w

###############################################################################
# admin.pl - this code runs the site's administrative tasks page 
#
# Copyright (C) 1997 Rob "CmdrTaco" Malda
# malda@slashdot.org
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#
#  $Id$
###############################################################################
use strict;
use lib '../';
use vars '%I';
use Slash;

sub main {
	*I = getSlashConf();

	my($adminuser,$passwd);
	print "This script will create a default author for your slashcode site\n";
	print "What is the name of the admin you'd like to use for your site? ";
	$adminuser = <STDIN>;
	chomp($adminuser);
	print "Enter the password for this user (try to use a good password for\nsecurity's sake!) ";
	$passwd = <STDIN>;
	chomp($passwd);


	authorCreate($adminuser,$passwd) or die "unable to create adminuser $adminuser\n";
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
	my ($adminuser,$passwd) = @_;

	(my $matchname = lc $adminuser) =~ s/[^a-zA-Z0-9]//g;

	$I{dbh}->do("INSERT INTO authors values ('$adminuser','$adminuser','http://www.example.com','$adminuser\@example.com','test quote', 'test copy', '$passwd',10000,'','',0,'$matchname')") or print "DBI::errstr $! couldn't insert admin user\n";


}

main;

$I{dbh}->disconnect if $I{dbh};
1;

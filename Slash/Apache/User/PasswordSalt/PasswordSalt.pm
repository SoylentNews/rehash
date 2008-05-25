# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Apache::User::PasswordSalt;

use strict;
use Carp;
use File::Spec::Functions;
use Slash::Utility::Environment;

our $VERSION = $Slash::Constants::VERSION;


#
# To make your Slash installation more secure, create a file at
# /usr/local/slash/slash.salts which contains password salt for
# each of your Slash site virtual users.  A site only needs one
# salt, so your initial setup should contain one scalar value.
# Later, if there is a security issue such as a vulnerability
# that allows user password MD5's to be read from your database,
# or a no-longer-trusted employee being dismissed, you should
# append another scalar onto the list.
#
# For example, if you are running one Slash site with the virtual
# user 'foo', you might create a file with the contents:
#	foo	kL3xeJm6az
# If your site then suffers from a vulnerability, then after the
# vulnerability is fixed, you might add another scalar:
#	foo	kL3xeJm6az	2dJ4oSI4e9
# The format is simply whitespace-separated columns, first the
# virtual user and then the salts.
#
# This salt combines with each user's password before the one-way
# MD5 function stores them in the database.  An attacker who only
# has access to the database, not the salt file, and obtains one
# or more hashed passwords from there will find reversing the
# hashes to determine the original passwords made significantly
# more difficult, depending on how many random bits are in the salt.
#
# If the attacker gains access to both the database and to the file,
# they will easily be able to brute-force decipher users' passwords.
# (They will not be able to use precomputed hash dictionaries, but
# this is only a minor setback.)
#

{ # closure

my $salt_hr = undef;

sub loadSalts {
	return if defined $salt_hr;

	$salt_hr = { };
	my $constants = getCurrentStatic();
	my $slashdir = $constants->{slashdir} || '/usr/local/slash';
	my $saltsfile = 'slash.salts';
	my $fullfile = catfile($slashdir, $saltsfile);
	return if !-e $fullfile || !-r _ || !-s _;
	return if !open(my $fh, $fullfile);
	while (<$fh>) {
		chomp;
		s/\s*$//;
		my($vu, @salts) = split;
		$salt_hr->{$vu} = [ @salts ] if $vu;
	}
	close $fh;
}

sub getPwSalts {
	my($virtual_user) = @_;
	abortIfSuspiciousCaller();
	return [ ] if !$virtual_user;
	loadSalts();
	return $salt_hr->{$virtual_user} || [ ];
}

sub getCurrentPwSalt {
	my($virtual_user) = @_;
	my $salt_ar = getPwSalts($virtual_user);
	return @$salt_ar ? $salt_ar->[-1] : '';
}

} # end closure

#
# This module's purpose is circumvented if there's a way an attacker
# can read any data from getPwSalts().  We consider the case of an
# attacker who may be able to evaluate a template and see the results.
# While this module's methods are not made available to the template
# processing code (see Slash::Display::Plugin, which exports only
# Slash.pm methods in Slash.* and DB methods in Slash.db.*), we add
# this extra check to try to ensure that its data can't be read from a
# template.
#
# As of this writing (2008-02-12) there should be no reason to think
# that a template needs to read password salt.
#

sub abortIfSuspiciousCaller() {
	my $i = 1;
	while (my @c = caller($i)) {
		my($package, $filename, $line, $subroutine) = @c;
		# If we go back up the call chain to a package we know we can
		# trust, then we can stop looking.
		last if $package =~ /^(main|Apache::PerlRun|Apache::ROOT.*)$/;
		if ($package =~ /^Template/ || $subroutine eq '(eval)') {
			# This exits the entire script immediately.
			confess(scalar(gmtime) . " $$ SuspiciousCaller for salt at package '$package'");
		}
		++$i;
	}
}

1;

__END__

=head1 NAME

Slash::Apache::User::PasswordSalt - Salt user passwords for security

=head1 SEE ALSO

Slash::Apache::User(3).

=cut

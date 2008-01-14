# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Apache::User::PasswordSalt;

use strict;
use File::Spec::Functions;
use Slash::Utility::Environment;
use vars qw($REVISION $VERSION);

$VERSION   	= '2.003000';  # v2.3.0
($REVISION)	= ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;


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

sub getSalts {
	my($virtual_user) = @_;
	loadSalts();
	return $salt_hr->{$virtual_user} || [ ];
}

sub getCurrentSalt {
	my($virtual_user) = @_;
	my $salt_ar = getSalts($virtual_user);
	return @$salt_ar ? $salt_ar->[-1] : '';
}

1;

__END__

=head1 NAME

Slash::Apache::User::PasswordSalt - Salt user passwords for security

=head1 SEE ALSO

Slash::Apache::User(3).

=cut

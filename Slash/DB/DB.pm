# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::DB;

use strict;
use DBIx::Password;
use Slash::DB::Utility;
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# FRY: Would you cram a sock in it, Bender?

# Registry of DBI DSNs => Slash::DB driver modules
# If you add another driver, make sure there's an entry here
my $dsnmods = {
	mysql	=> 'MySQL',
};

sub new {
	my($class, $user) = @_;
	my $dsn = DBIx::Password::getDriver($user);
	if (my $modname = $dsnmods->{$dsn}) {
		my $dbclass = ($ENV{GATEWAY_INTERFACE})
			? "Slash::DB::$modname"
			: "Slash::DB::Static::$modname";
		eval "use $dbclass"; die $@ if $@;

		# Bless into the class we're *really* wanting -- thebrain
		my $self = bless {
			virtual_user		=> $user,
			db_driver		=> $dsn,
			# See setPrepareMethod below -- thebrain
			_dbh_prepare_method	=> 'prepare_cached'
		}, $dbclass;
		$self->sqlConnect();
		return $self;
	} elsif ($dsn) {
		die "Database $dsn unsupported! (virtual user '$user')";
	} else {
		die "DBIx::Password has no information about the virtual user '$user'. Most likely either you mistyped it (maybe in slash.sites or your SlashVirtualUser directive?), or DBIx::Password is misconfigured somehow";
	}
}

sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect
		if ! $ENV{GATEWAY_INTERFACE} && defined $self->{_dbh};
}

1;

__END__

=head1 NAME

Slash::DB - Database Class for Slash

=head1 SYNOPSIS

	use Slash::DB;
	my $object = Slash::DB->new("virtual_user");

=head1 DESCRIPTION

This package is the front end interface to slashcode.
By looking at the database parameter during creation
it determines what type of database to inherit from.

=head1 SEE ALSO

Slash(3), Slash::DB::Utility(3).

=cut

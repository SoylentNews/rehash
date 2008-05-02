# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::DB;

use strict;
use DBIx::Password;
use Slash::DB::Utility;

our $VERSION = $Slash::Constants::VERSION;

# FRY: Would you cram a sock in it, Bender?

# Registry of DBI DSNs => Slash::DB driver modules
# If you add another driver, make sure there's an entry here
my $dsnmods = {
	mysql	=> 'MySQL',
};

# It may be of interest to note that while all the other subclasses
# of Slash::DB and Slash::DB::Utility typically have their new()
# method invoked via getObject() and loadClass(), Slash::DB->new()
# is called directly by createEnvironment().  This is because it
# needs to set up the current db before prepareUser() retrieves it
# with getCurrentDB().

sub new {
	my($class, $user) = @_;
	my $dsn = DBIx::Password::getDriver($user);
	if (my $modname = $dsnmods->{$dsn}) {
		my $dbclass = ($ENV{GATEWAY_INTERFACE})
			? "Slash::DB::$modname"
			: "Slash::DB::Static::$modname";
#use Carp; Carp::cluck("$$ Slash::DB->new evaling 'use $dbclass'");
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

# Slash::DB->new returns an object that's a subclass of
# Slash::DB::Utility, where isInstalled is defined.
# But Slash::DB->isInstalled is called before new is called,
# so it can't inherit Slash::DB::Utility::isInstalled.
# So we define our own here.

sub isInstalled {
	1;
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

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
	my($class, $user, @extra_args) = @_;
	if ($class->can('isInstalled')) {
		return undef unless $class->isInstalled();
	}

	my $dsn = DBIx::Password::getDriver($user);
	if (my $modname = $dsnmods->{$dsn}) {
		my $dbclass = ($ENV{GATEWAY_INTERFACE})
			? "Slash::DB::$modname"
			: "Slash::DB::Static::$modname";
		eval "use $dbclass"; die $@ if $@;

		# Slash::DB->new() returns an object of the preferred
		# database class, never of its own class.  (Since
		# Slash hasn't ever really supported Postgres, this
		# will be Slash::DB::MySQL or Slash::DB::Static::MySQL.)
		my $self = bless {
			virtual_user		=> $user,
			db_driver		=> $dsn,
			_dbh_prepare_method	=> 'prepare_cached'
		}, $dbclass;

		# Call (presumably) (one of the) MySQL.pm init()
		# methods.  See init() below for details.
		# this will invoke DB.pm's init() method a few lines
		# down in just a moment.
		if ($self->can('init')) {
			return undef unless $self->init(@extra_args);
		}

		$self->sqlConnect() or return undef;;
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

# Many of our database classes use multiple base classes, for example,
# MySQL.pm does:
#	use base 'Slash::DB';
#	use base 'Slash::DB::Utility';
# Most of our optional (plugin) classes currently do this:
#	use base 'Slash::DB::Utility';
#	use base 'Slash::DB::MySQL';
# along with a code comment suggesting maybe this should be changed.
# (But it hasn't been changed in years, and has been copy-and-pasted
# so many times it would require a great deal of testing to change now.)
#
# The Slash code just uses perl's stock multiple inheritance, which
# means a SUPER::foo() call will only invoke the first base class.
# So most of our database classes, when initialized, will invoke
# Slash::DB::Utility::init(), and MySQL.pm will invoke Slash::DB::init().
# Long story short, any initialization common to all database classes
# should be done both here and in Utility.pm.

sub init {
	my($self) = @_;
	# Consider clearing any existing fields matching /_cache_/ too.
	my @fields_to_clear = qw(
		_querylog	_codeBank
		_boxes		_sectionBoxes
		_comment_text	_comment_text_full
		_story_comm
	);
	for my $field (@fields_to_clear) {
		$self->{$field} = { };
	}
	$self->SUPER::init() if $self->can('SUPER::init');
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

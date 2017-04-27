# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Admin::Upgrade::MySQL;

=head1 NAME

Slash::Admin::Upgrade::MySQL


=head1 SYNOPSIS

	# basic example of usage


=head1 DESCRIPTION

LONG DESCRIPTION.


=head1 EXPORTED FUNCTIONS

=cut

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

sub upgradeDB() {
	my ($self, $upgrade) = @_;
	my $slashdb = getCurrentDB();
	my $schema_versions = $upgrade->getSchemaVersions();
	my $admin_schema_ver = $schema_versions->{db_schema_plugin_Admin};
	my $upgrades_done = 0;

	if ($admin_schema_ver == 0) {
		# Every schema upgrade should have a comment as to why. In this case, initialize the
		# admin version schema (this is done as an example on how this should be done)
		print "upgrading Admin to v1 ...\n";
		if (!$slashdb->sqlDo("INSERT INTO site_info (name, value, description) VALUES ('db_schema_plugin_Admin', 1, 'Version of admin plugin schema')")) {
			return 0;
		};
		$admin_schema_ver = 1;
		$upgrades_done++;
	}

	if (!$upgrades_done) {
		print "No upgrades needed for Admin V$admin_schema_ver \n";
	}

	return 1;
}

1;

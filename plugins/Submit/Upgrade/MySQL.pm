# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Submit::Upgrade::MySQL;

=head1 NAME

Slash::Submit::Upgrade::MySQL


=head1 SYNOPSIS

Database upgrades file for Submit Plugin


=head1 DESCRIPTION

Automagically updates database with schema and data changes
needed for the Submit plugin when associate code changes are
made in rehash.


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
	my $submit_schema_ver = $schema_versions->{db_schema_plugin_Submit};
	my $upgrades_done = 0;

	if ($submit_schema_ver < 1 ) {
		print "upgrading Submit to v1 ...\n";
		if(!$slashdb->sqlDo("ALTER TABLE submissions ADD COLUMN dept varchar (100) null")) {
			return 0;
		};
		if(!$slashdb->sqlDo("INSERT INTO vars (name, value, description) VALUES ('submit_dept', 0, 'Allow users to submit deptatrment with stories')")) {
			return 0;
		};
		if (!$slashdb->sqlDo("INSERT INTO site_info (name, value, description) VALUES ('db_schema_plugin_Submit', 1, 'Version of submit plugin schema')")) {
			return 0;
		};
		$submit_schema_ver = 1;
		$upgrades_done++;
	}
	
	if ($submit_schema_ver < 2 ) {
		print "Upgrading Submit to v2 ...\n";
		print "Running: ALTER TABLE submissions MODIFY COLUMN note varchar(30) DEFAULT '' NOT NULL \n";
		if(!$slashdb->sqlDo("ALTER TABLE submissions MODIFY COLUMN note varchar(30) DEFAULT '' NOT NULL")) {
			return 0
		};
		print "Set to version 2 \n";
		if (!$slashdb->sqlDo("UPDATE site_info SET value = 2 WHERE name = 'db_schema_plugin_Submit'")) {
			return 0;
		};
		print "Upgrade complete \n";
		$submit_schema_ver = 2;
		$upgrades_done++;
	}
	
		if ($submit_schema_ver < 3 ) {
		print "Upgrading Submit to v3 ...\n";
		print "Running: REPLACE INTO vars (name, value, description) VALUES ('submissions_all_page_size', 250, 'Max number of submissions to show for admins and users') \n";
		if (!$slashdb->sqlDo("REPLACE INTO vars (name, value, description) VALUES ('submissions_all_page_size', 250, 'Max number of submissions to show for admins and users')")) {
			return 0;
		};
		print "Running: REPLACE INTO vars (name, value, description) VALUES ('submissions_accepted_only_page_size', 250, 'Max number of submissions to show on other users page') \n";
		if (!$slashdb->sqlDo("REPLACE INTO vars (name, value, description) VALUES ('submissions_accepted_only_page_size', 250, 'Max number of submissions to show on other users page')")) {
			return 0;
		};
		print "Set to version 3 \n";
		if (!$slashdb->sqlDo("UPDATE site_info SET value = 3 WHERE name = 'db_schema_plugin_Submit'")) {
			return 0;
		};
		print "Upgrade complete \n";
		$submit_schema_ver = 3;
		$upgrades_done++;
	}

	if (!$upgrades_done) {
		print "No upgrades needed for Submit V$submit_schema_ver\n";
	}

	return 1;
}

1;

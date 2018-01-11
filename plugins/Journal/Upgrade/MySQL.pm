# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Journal::Upgrade::MySQL;

=head1 NAME

Slash::Journal::Upgrade::MySQL


=head1 SYNOPSIS

Database upgrades file for Journal Plugin


=head1 DESCRIPTION

Automagically updates database with schema and data changes
needed for the Journal plugin when associate code changes are
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
	my $journal_schema_ver = $schema_versions->{db_schema_plugin_Journal};
	my $upgrades_done = 0;

	if ($journal_schema_ver < 1 ) {
		print "upgrading Journal to v1 ...\n";
		if(!$slashdb->sqlDo("REPLACE INTO vars (name, value, description) VALUES ('journal_sb_min_karma', 10, 'Min karma necessary to show up in top recent journals sidebar')")) {
			return 0;
		};
		if (!$slashdb->sqlDo("REPLACE INTO site_info (name, value, description) VALUES ('db_schema_plugin_Journal', 1, 'Version of journal plugin schema')")) {
			return 0;
		};
		$journal_schema_ver = 1;
		$upgrades_done++;
	}

	if (!$upgrades_done) {
		print "No upgrades needed for Journal V$journal_schema_ver\n";
	}

	return 1;
}

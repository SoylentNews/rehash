# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Twitter::Upgrade::MySQL;

=head1 NAME

Slash::Twitter::Upgrade::MySQL


=head1 SYNOPSIS

Database upgrades file for Twitter Plugin


=head1 DESCRIPTION

Automagically updates database with schema and data changes
needed for the Twitter plugin when associate code changes are
made in rehash.


=head1 EXPORTED FUNCTIONS

=cut

use strict;
use warnings;
use Slash;
use Slash::Display;
use Slash::Utility;

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

sub upgradeDB() {
	my ($self, $upgrade) = @_;
	my $slashdb = getCurrentDB();
	my $schema_versions = $upgrade->getSchemaVersions();
	my $twitter_schema_ver = $schema_versions->{db_schema_plugin_Twitter};
	my $upgrades_done = 0;

	if ($twitter_schema_ver < 1 ) {
		print "Doing initial Twitter plugin setup\n";
		print "DROP TABLE IF EXISTS twitter_log\n"
		if(!$slashdb->sqlDo("DROP TABLE IF EXISTS twitter_log")) {
			return 0;
		}
		print "CREATE TABLE twitter_log (sid CHAR(16) NOT NULL, title VARCHAR(100) NOT NULL, time DATETIME DEFAULT NOW(), PRIMARY KEY (sid, title)) ENGINE=ndbcluster DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci\n";
		if(!$slashdb->sqlDo("CREATE TABLE twitter_log (sid CHAR(16) NOT NULL, title VARCHAR(100) NOT NULL, time DATETIME DEFAULT NOW(), PRIMARY KEY (sid, title)) ENGINE=ndbcluster DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci")) {
			return 0;
		}
		print "INSERT INTO vars (name, description, value) VALUES ('twit_consumer_key', 'Twitter consumer_key', 'FILL THIS IN https://apps.twitter.com/')\n";
		if(!$slashdb->sqlDo("INSERT INTO vars (name, description, value) VALUES ('twit_consumer_key', 'Twitter consumer_key', 'FILL THIS IN https://apps.twitter.com/')") {
			return 0;
		}
		print "INSERT INTO vars (name, description, value) VALUES ('twit_consumer_secret', 'Twitter consumer_secret', 'FILL THIS IN https://apps.twitter.com/')\n";
		if(!$slashdb->sqlDo("INSERT INTO vars (name, description, value) VALUES ('twit_consumer_secret', 'Twitter consumer_secret', 'FILL THIS IN https://apps.twitter.com/')")) {
			return 0;
		}
		print "INSERT INTO vars (name, description, value) VALUES ('twit_access_token', 'Twitter access_token', 'FILL THIS IN https://apps.twitter.com/')\n";
		if(!$slashdb->sqlDo("INSERT INTO vars (name, description, value) VALUES ('twit_access_token', 'Twitter access_token', 'FILL THIS IN https://apps.twitter.com/')")) {
			return 0;
		}
		print "INSERT INTO vars (name, description, value) VALUES ('twit_access_token_secret', 'Twitter access_token_secret', 'FILL THIS IN https://apps.twitter.com/')\n";
		if(!$slashdb->sqlDo("INSERT INTO vars (name, description, value) VALUES ('twit_access_token_secret', 'Twitter access_token_secret', 'FILL THIS IN https://apps.twitter.com/')")) {
			return 0;
		}
		print "INSERT INTO vars (name, description, value) VALUES ('twit_max_items_outgoing', 'Max stories to flood Twitter with at once', '10')\n";
		if(!$slashdb->sqlDo("INSERT INTO vars (name, description, value) VALUES ('twit_max_items_outgoing', 'Max stories to flood Twitter with at once', '10')")) {
			return 0;
		}

		print "Set to version 1 \n";
		if (!$slashdb->sqlDo("INSERT INTO site_info (name, value, description) VALUES ('db_schema_plugin_Twitter', 1, 'Version of twitter plugin schema')")) {
			return 0;
		}
		print "Upgrade complete \n";
		$twitter_schema_ver = 1;
		$upgrades_done++;
	}

	if (!$upgrades_done) {
		print "No upgrades needed for Twitter V$twitter_schema_ver\n";
	}

	return 1;
}

1;


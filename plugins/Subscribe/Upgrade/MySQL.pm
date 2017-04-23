# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Subscribe::Upgrade::MySQL;

=head1 NAME

Slash::Subscribe::Upgrade::MySQL


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
	my $subscribe_schema_ver = $schema_versions->{db_schema_plugin_Subscribe};
	my $upgrades_done = 0;

	if ($subscribe_schema_ver < 1) {
		print "upgrading Subscribe to v1 ...\n";
		# clean up here in case we have some of these already existing like could happen on dev or from a partially successful run of this version
		$slashdb->sqlDo("DROP TABLE IF EXISTS stripe_log");
		$slashdb->sqlDo("DELETE FROM vars WHERE name = 'stripe_private_key'");
		$slashdb->sqlDo("DELETE FROM vars WHERE name = 'stripe_public_key'");
		$slashdb->sqlDo("DELETE FROM vars WHERE name = 'stripe_ipn_path'");
		
		# Okay, some method needs to be put in place to select the proper db engine here.
		# For now though, I'm putting ndbcluster in because that's what we use.
		if(!$slashdb->sqlDo("CREATE TABLE stripe_log ( logid bigint(20) unsigned NOT NULL AUTO_INCREMENT, ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, event_id varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL, remote_address varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL, raw_transaction text COLLATE utf8_unicode_ci NOT NULL, PRIMARY KEY (logid) ) ENGINE=ndbcluster DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;")) {
			return 0;
		}
		if(!$slashdb->sqlDo("INSERT INTO vars (name, value, description) VALUES ('stripe_private_key', NULL, 'Private key for initiating Stripe transactions')") ) {
			return 0;
		}
		if(!$slashdb->sqlDo("INSERT INTO vars (name, value, description) VALUES ('stripe_public_key', NULL, 'Public key for generating stripe tokens')") ) {
                        return 0;
                }
		if(!$slashdb->sqlDo("INSERT INTO vars (name, value, description) VALUES ('stripe_ipn_path', '/stripe', 'Stripe ipn daemon listener path')") ) {
                        return 0;
                }
		if(!$slashdb->sqlDo("INSERT INTO vars (name, value, description) VALUES ('crypt_key', 'changeme', 'Key for (de|en)crypting metadata for sending to payment processors')") ) {
                        return 0;
                }
		if (!$slashdb->sqlDo("INSERT INTO site_info (name, value, description) VALUES ('db_schema_plugin_Subscribe', 1, 'Version of subscribe plugin schema')")) {
			return 0;
		};
		$subscribe_schema_ver = 1;
		
		$upgrades_done++;
	}

	if ($subscribe_schema_ver < 2) {
		print "upgrading Subscribe to v2 ...\n";
		print "Running: DELETE FROM vars WHERE name = 'bitpay_amount' OR name = 'bitpay_token' OR name = 'bitpay_host' OR name = 'bitpay_image_src' OR name = 'bitpay_return' OR name = 'bitpay_callback' OR name = 'bp_ipn_path' OR name = 'bitpay_num_days'\n";
		if(!$slashdb->sqlDo("DELETE FROM vars WHERE name = 'bitpay_amount' OR name = 'bitpay_token' OR name = 'bitpay_host' OR name = 'bitpay_image_src' OR name = 'bitpay_return' OR name = 'bitpay_callback' OR name = 'bp_ipn_path' OR name = 'bitpay_num_days'")) {
			return 0;
		}
		print "Running: ALTER TABLE subscribe_payments ADD submethod VARCHAR(3) NULL DEFAULT NULL AFTER method;\n";
		if(!$slashdb->sqlDo("ALTER TABLE subscribe_payments ADD submethod VARCHAR(3) NULL DEFAULT NULL AFTER method") {
			return 0;
		}

		print "Set to version 2.\n";
		if (!$slashdb->sqlDo("UPDATE site_info SET value = 2 WHERE name = 'db_schema_plugin_Subscribe'")) {
			return 0;
		};

		$subscribe_schema_ver = 2;
		$upgrades_done++;
	}

	if (!$upgrades_done) {
		print "No schema upgrades needed for Subscribe\n";
	}

	return 1;
}

1;

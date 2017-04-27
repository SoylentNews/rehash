# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Messages::Upgrade::MySQL;

=head1 NAME

Slash::Message::Upgrade::MySQL


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
	my $messages_schema_ver = $schema_versions->{db_schema_plugin_Messages};
	my $upgrades_done = 0;

	my $max_uid = $slashdb->sqlSelect(
					"max(uid)",
					"users"
	);

	if ($messages_schema_ver == 0) {
		# initialize the messages plugin schema and insert an entry for MSG_CODE_SUBMISSION_REJECT reasons into the message_codes table
		print "upgrading Messages to v1 ...\n";
		if (!$slashdb->sqlDo("REPLACE INTO message_codes (code, type, seclev, send, subscribe, delivery_bvalue) VALUES (19, 'Declined Submission Reason', 1, 'now', 0, 3)")) {
			print "Failed inserting 19 into message_codes.\n";
			return 0;
		}
		if (!$slashdb->sqlDo("REPLACE INTO message_codes (code, type, seclev, send, subscribe, delivery_bvalue) VALUES (20, 'Admin to user message', 1, 'now', 0, 3)")) {
			print "Failed inserting 20 into message_codes.\n";
			return 0;
		}
		if (!$slashdb->sqlDo("REPLACE INTO site_info (name, value, description) VALUES ('db_schema_plugin_Messages', 1, 'Version of messages plugin schema')")) {
			print "Failed updating site_info.db_schema_plugin_Messages to 1.\n";
			return 0;
		}
		my $badupdate = 0;
		foreach my $uid (2 .. $max_uid) {
			if (!$slashdb->sqlDo("REPLACE INTO users_messages (uid, code, mode) VALUES ('$uid', 20, 1)")) {
				$badupdate = 1;
			}
			if (!$slashdb->sqlDo("REPLACE INTO users_messages (uid, code, mode) VALUES ('$uid', 19, 1)")) {
			$badupdate = 1;
			}
		}
		if($badupdate) {
			print "There were problems updating everyone's preferences to web messages for rejected submission messages. This is not fatal though.\n";
		}
		$messages_schema_ver = 1;
		$upgrades_done++;
	}

	if (!$upgrades_done) {
		print "No upgrades needed for Messages V$messages_schema_ver \n";
	}

	return 1;
}

1;


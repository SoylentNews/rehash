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

	if ($messages_schema_ver == 0) {
		# initialize the messages plugin schema and insert an entry for MSG_CODE_SUBMISSION_REJECT reasons into the message_codes table
		print "upgrading messages to v1 ...\n";
		if (!$slashdb->sqlDo("INSERT INTO message_codes (code, type, seclev, send, subscribe, delivery_bvalue) VALUES (19, 'Rejected Submission Reason', 1, 'now', 0, 2)")) {
			return 0;
		}
		if (!$slashdb->sqlDo("INSERT INTO site_info (name, value, description) VALUES ('db_schema_plugin_Messages', 1, 'Version of messages plugin schema')")) {
			return 0;
		}
		$messages_schema_ver = 1;
		$upgrades_done++;
	}

	if (!$upgrades_done) {
		print "No schema upgrades needed for Messages\n";
	}

	return 1;
}

1;


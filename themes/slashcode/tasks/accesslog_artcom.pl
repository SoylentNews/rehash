#!/usr/bin/perl -w
#
# $Id$
# 
# Transfer article and comments hits from accesslog into a new
# table, accesslog_artcom, for fast processing by run_moderatord.

use strict;
use vars qw( %task $me $minutes_run );
use Slash 2.003;	# require Slash 2.3.x
use Slash::DB;
use Slash::Utility;
use Slash::Constants ':slashd';

(my $VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# Change this var to change how often the task runs.
$minutes_run = 6;

$task{$me}{timespec} = "3-59/$minutes_run * * * *";
$task{$me}{timespec_panic_1} = '';			# not that important
$task{$me}{resource_locks} = { log_slave => 1 };
$task{$me}{fork} = SLASHD_NOWAIT;

$task{$me}{code} = sub {

	my($virtual_user, $constants, $slashdb, $user) = @_;

	if (! $constants->{allow_moderation}) {
		slashdLog("$me - moderation inactive") if verbosity() >= 2;
		return ;
	}

	my $log_db = getObject('Slash::DB', { db_type => "log_slave" });

	my $maxrows = $constants->{moderatord_maxrows} || 50000;
	my $lastmaxid = $slashdb->getVar('moderatord_lastmaxid', 'value', 1);
	if (!$lastmaxid) {
		slashdLog("apparently first run of this task");
		# We need to successfully write a value into the var,
		# or the next run of this task will reuse the same
		# log entries.  If we can't, abort.  We could just
		# call createVar() but the admin really should be
		# doing their job :)
		my $success = $slashdb->setVar('moderatord_lastmaxid', 0);
		if (!$success) {
			return "setting var moderatord_lastmaxid failed, create it please";
		}
	}
	my $newmaxid = $log_db->sqlSelect("MAX(id)", "accesslog");
	$lastmaxid = $newmaxid - $maxrows if $lastmaxid < $newmaxid - $maxrows;
	my $youngest_eligible_uid = $slashdb->getYoungestEligibleModerator();
	$log_db->fetchEligibleModerators_accesslog_insertnew($lastmaxid+1, $newmaxid,
		$youngest_eligible_uid);
	$log_db->fetchEligibleModerators_accesslog_deleteold();
	$slashdb->setVar('moderatord_lastmaxid', $newmaxid);

	return ;
};

1;


#!/usr/bin/perl -w
#
# $Id$
#
# SlashD Task (c) OSDN 2001
#
# Description: Performs Spidering runs within Task architechture.
# 	       Converted from original cron jobs from NewsForge
# 	       1.0 production site.
#
# Task Options:
# 
# 	spiders = COMMA separated list of spiders to run. No time checks are
# 		  performed, and no times are written to the database. This 
# 		  behavior may change in the future.
#
#	disable_template_cache = If set and non-zero (boolean), then this 
#	forces the template cache off. This causes a serious hit on
#	performance and should not be used unless you REALLY know what you are
#	doing.
#
#	* Consider adding in a limit here? *

use strict;

use Schedule::Cron;

use vars qw( %task $me );

# We run spiders, periodically depending 
# on this cron timespec.
$task{$me}{timespec} = '*/15 * * * *';	# Every 15 mins.
$task{$me}{timespec_panic_1} = '';	# Don't run at all in a panic.

$task{$me}{'fork'} = 1;			# If allowed, fork this task from 
					# slashd.

$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	# Set the proper section so log messages will print the right messages.
	# Remember to set this back as $user is GLOBAL for slashd's context.
	my $oldPage = $user->{currentPage};
	$user->{currentPage} = 'newsvac';

	# Set default values on task options.
	$constants->{task_options}{spiders} ||= '';

	# Override constants caching and force it ON. For the number of 
	# template calls this thing makes, this is a necessity.
	$constants->{cache_enabled} = 1 
		unless $constants->{task_options}{disable_template_cache};

	# Get our plugin.
	my $newsvac = getObject('Slash::NewsVac');
	slashdLogDie("NewsVac Plugin failed to load, correctly!") 
		unless $newsvac;

	my $cron = init_cron();
	slashdLogDie("Schedule::Cron failed to load, properly!")
		unless $cron;

	# Grab spider list from database. Ideally, the plugin should provide
	# this list instead of us going directly to the dB, but we're being
	# fast 'n dirty, here. Clean up, later.
	my $spiders;
	my $st_list = $slashdb->sqlSelectAllHashrefArray(
		'*', 'spider_timespec'
	);
	# And because there may be more than one timespec per miner, we 
	# arrange it all by hash of array-refs.
	push @{$spiders->{$_->{name}}}, $_ for @{$st_list};

	# If we're using user-specified miner names, then we only store an
	# array of scalars (each scalar being the name of a spider to run).
	my @run_spiders = split(':', $constants->{task_options}{spiders});

	my $now = $slashdb->sqlSelect('UNIX_TIMESTAMP()');
	if (! @run_spiders) {
		for my $s (sort keys %{$spiders}) {
			# Test each timespec in turn.
			for (@{$spiders->{$s}}) {
				my $next_time = $cron->get_next_execution_time(
					$_->{timespec}, $_->{last_run}
				);

				slashdLog("$s Times: $next_time. ($now)");
	
				if ($next_time < $now || !$_->{last_run}) {
					# If no user-specified miners, we push
					# an array ref of:
					# 	(minername, timespec ID)
					push 	@run_spiders, 
						[$s, $_->{timespec_id}];

					slashdLog("Running $s");
					last;
				}
			}
		}
	}

	# We hope this routine is FORKED from slashd, because the only safe
	# thing to do at this point is to execute each spider that hasn't
	# been run since the last time it was checked. If this task isn't
	# being forked, it could be a long time before other site tasks 
	# are executed.
	my(@executed_spiders);
	for (@run_spiders) {
		my $spider_name = ref $_ ? $_->[0] : $_;

		# Lock NewsVac, which forces its error messages into its 
		# own log file and also does poor man's resource locking
		# in the lack anything better.
		$newsvac->lockNewsVac();

		# Execute miner.
		my $rc = $newsvac->spider_by_name($spider_name);
		# Perform ROBOsubmission only if the spider exists.
		$newsvac->robosubmit() unless $rc == 0;

		# Any Clean up?

		# Don't write to the database if miners were user-specified.
		# This can be determined simply by whether or not our loop
		# value is a reference.
		if (ref $_ eq 'ARRAY') {
			$slashdb->sqlUpdate('spiders', {
				-last_run => 'UNIX_TIMESTAMP()'
			}, "timespec_id=$_->[1]");
		}

		push @executed_spiders, $spider_name;
	}

	# Restore $user.
	$user->{currentPage} = $oldPage;

	return "Spiders executed: " .  join(' ', @executed_spiders) 
		if @executed_spiders;
	return "No spiders executed.";
};


#sub init_cron {
#	sub null_dispatcher { die "null_dispatcher called, there's a bug" }
#	my $cron = Schedule::Cron->new(\&null_dispatcher);
#	return $cron;
#}


1;


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
#	iterations = If the spiders option is not given, this value
#	represents the maximum number of spiders that will be run during this
#	execution.

use strict;

use Schedule::Cron;

use vars qw( %task $me );

# We run spiders, periodically depending 
# on this cron timespec.
$task{$me}{timespec} = '0-59/15 * * * *';	# Every 15 mins.
$task{$me}{timespec_panic_1} = '';	# Don't run at all in a panic.

$task{$me}{'fork'} = 1;			# If allowed, fork this task from 
					# slashd and allow slashd to continue
					# processing.

$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	# Set the proper section so log messages will print the right messages.
	# Remember to set this back as $user is GLOBAL for slashd's context.
	# (Setting it back shouldn't matter now that tasks fork. - Jamie)
	local $user->{currentPage} = 'newsvac';

	# Set default values on task options.
	$constants->{task_options}{spiders} ||= '';

	# Override constants caching and force it ON. For the number of 
	# template calls this thing makes, this is a necessity.
	local $constants->{cache_enabled} = 1 
		unless $constants->{task_options}{disable_template_cache};

	# Initialize Cron parser (for the timespecs).
	my $cron = init_cron();
	slashdLogDie('Schedule::Cron failed to load, properly!')
		unless $cron;

	# Initialize our plugin.
	my $newsvac = getObject('Slash::NewsVac');

	# First step: Grab all of the timespecs so we can check them.
	my $spiders = $newsvac->getAllSpiderTimespecs();

	# If we're using user-specified miner names, then we only store an
	# array of scalars (each scalar being the name of a spider to run).
	my @run_spiders = split(':', $constants->{task_options}{spiders});

	my $iterations = 
		$constants->{task_options}{iterations} ||
		$constants->{slashd_max_spiders};
	undef $iterations if $iterations == 0;

	my $now = $slashdb->sqlSelect('UNIX_TIMESTAMP()');
	if (! @run_spiders) {
		for my $s (sort keys %{$spiders}) {
			# Test each timespec in turn.
			for (@{$spiders->{$s}}) {
				my $last_run = $_->{last_run};
				my $next_time = $cron->get_next_execution_time(
					$_->{timespec}, $last_run
				);

				my $exe_lag = $now - $last_run;
				slashdLog(<<EOT) if verbosity() >= 3;

$s Times: $_->{timespec}

     Last run: @{[scalar localtime $last_run]} ($last_run)
Next expected: @{[scalar localtime $next_time]} ($next_time)
          Now: @{[scalar localtime $now]} ($now)
          Lag: $exe_lag
EOT
					
				if ($next_time <= $now || !$last_run) {
					# If no user-specified miners, we push
					# an array ref of:
					#
					# (minername, timespec ID, exe lag)
					#
					# "exe lag" meaning time since the 
					# last run of the current timespec.
					push @run_spiders, [
						$s, 
						$_->{timespec_id}, 
						$exe_lag
					];

					my $data = {
						spider	=> $s,
						count	=> $iterations,
					};
					slashdLog(
						getData(
							'task_spider_stale', 
							$data
						)
					) if verbosity() >=2 ;

					last;
				}
			}
		}
	}

	# Intermediary step. If @run_spiders is a list of array references
	# then we need to re-order @run_spiders based on DECREASING 
	# "exe lag". We don't want spiders that happen to be listed first
	# in the database taking all of the free execution slots that come up.
	if (ref $run_spiders[0] eq 'ARRAY') {
		# If one is a ref, then they all are a ref.
		@run_spiders = sort { $b->[2] <=> $a->[2] } @run_spiders;
	}

	# Good thing this is FORKED from slashd, because the only safe
	# thing to do at this point is to execute each spider that hasn't
	# been run since the last time it was checked. If this task isn't
	# executed with a non-blocking fork, it may be a long time before
	# oher tasks are executed.
	my(@executed_spiders);
	for my $rs (@run_spiders) {
		my($duration, $robo);
		# We gotta use a locally defined loop variable here because
		# $_ is unsafe with all of the calls to $newsvac methods.
		my $spider_name = (ref $rs eq 'ARRAY') ? $rs->[0] : $rs;

		slashdLog("Running spider '$spider_name'") 
			if verbosity() >=2;

		# Lock NewsVac, which forces its error messages into its 
		# own log file and also does poor man's resource locking
		# in the lack of anything better. 
		$newsvac->lockNewsVac;

		# Execute miner.
		$duration = $newsvac->spider_by_name($spider_name);

		# Perform ROBOsubmission only if the spider exists.
		# then why == 0?  it returns 1 if it succeeds.  -- pudge
#		$robo = $newsvac->robosubmit if $duration == 0;
		$robo = $newsvac->robosubmit if $duration == 1;
		# Record the results.
		my $summary = 	($robo &&
				defined $robo->[0] && defined $robo->[1]) ? 
			"worthy $robo->[0], unworthy $robo->[1]" :
			'<NO RESULTS>';

		# Don't write to the database if miners were user-specified.
		# This can be determined simply by whether or not our loop
		# value is an array reference.
		if (ref $rs eq 'ARRAY') {
			slashdLog("Updating timespec_id $rs->[1]");

			# Consider adding a "duration" field to 
			# spider_timespecs and recording that info with this
			# call as well.
			$newsvac->markTimespecAsRun(
				$rs->[1], $duration, $summary
			);
		}

		push @executed_spiders, [$spider_name, $summary];

		# Reset our NewsVac object to as close to pristine as wecan
		# get it.
		$newsvac->Reset;

		# Honor the max iteration count if it has been defined.
		if (defined $iterations) {
			last if ! --$iterations;
		}
	}

	my $summary = 'No spiders executed.';
	if (@executed_spiders) {
		$summary = 'Spiders executed: ' . 
			join '; ', 
			map { join(' - ', @{$_}) } @executed_spiders;

	}

	# If forked, log the summary -- Actually, the idiom used here is 
	# incorrect, since it assumes that slashd will fork if the task
	# preference for forking is honored. What Slashd may need to do for
	# such tasks is to set $task{$me}{forked} so the task knows that the
	# fork did indeed occur, rather than just running based on its 
	# preference.
	#
	# In the meantime, this is left here as a reminder.
	if ($task{$me}{'fork'} && $0 =~ m!slashd!) {
		slashdLog($summary);
		$slashdb->updateTaskSummary($me, $summary);
	}

	return $summary;
};


1;


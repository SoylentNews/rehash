#!/srv/soylentnews.org/local/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use utf8;

use Slash::Utility;
use Slash::Constants qw( :messages :slashd );

use vars qw( %task $me $task_exit_flag );

#$task{$me}{timespec} = '*/5 0-23 * * *';
$task{$me}{timespec} = '10 0 * * *';
$task{$me}{timespec_panic_1} = '';
$task{$me}{resource_locks} = { log_slave => 1, moderatorlog => 1 };
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {

	my($virtual_user, $constants, $slashdb, $user) = @_;

	if (!$constants->{m1} || $constants->{m1_pluginname} ne 'Moderation') {
		slashdLog("$me - Moderation inactive") if verbosity() >= 2;
		return ;
	}

	# So, this basically works in a very simple process
	#
	# 1. Stir the modpoint pool, which also expires old points out
	# 2. Work out if we need to issue more points to get the system
	#    balanaced if we have points
	# 3. Work out who to give points to, and issue
	#my $points_to_handout;
	
	#stir_mod_pool();
	
	# Note, points to hand out CAN be negative, in that case, the system
	# only hands out minimium points (as always more modpoints is better)
	#$points_to_handout = determine_mod_points_to_be_issued($slashdb);
	#distributeModPoints($constants, $slashdb, $points_to_handout);

	# New new method because the old new method was slower than fuck
	my $acUID = $constants->{anonymous_coward_uid};
	my $points = $constants->{m1_pointsgrant_arbitrary};

	my $modshr = $slashdb->sqlSelectAllHashref(
		'uid',
          'uid, 1',
          'users_info',
          " created_at < DATE_SUB(NOW(), INTERVAL 1 MONTH) AND users_info.uid <> $acUID AND mod_banned < NOW() order by uid "
     );
	my @moderators = sort(keys(%$modshr));
     my $unwilling = $slashdb->sqlSelectAllHashref(
          'uid',
          'uid, willing',
          'users_prefs',
          ' willing <> 1 '
     );

	while(1) {
		my @thisbatch = splice(@moderators, 0, 1000);

          # remove unwilling moderators from the array
		my $index = 0;
		foreach my $moderator (@thisbatch) {
			if(exists $unwilling->{$moderator}) {
				splice(@thisbatch, $index, 1);
			}
			$index++;
		}

		# it's technically possible all of one batch don't want to moderate, so...
		if(scalar @thisbatch > 0) {
		
			my $where = join(" or uid = ", @thisbatch);
		
     	     my $rows = $slashdb->sqlUpdate(
          	     'users_info',
               	{ points => $points },
	               "uid = $where"
     	     );
		}

          sleep(10); # sleep for 10 seconds so users can get some pages loaded

		last unless scalar @moderators > 0;
     }
	
	return ;
};

############################################################

sub moderatordLog {
	doLog('slashd', \@_);
}

sub stir_mod_pool {
	my $moddb = getObject('Slash::Moderation');

	my $stirredpoints = $moddb->stirPool();

	if ($stirredpoints and my $statsSave = getObject('Slash::Stats::Writer')) {
		$statsSave->addStatDaily("mod_points_lost_stirred", $stirredpoints);
	}
	
}

############################################################
# Right so, to hand out mod points properly, we need to know
# how many comments are in our 'active' period, which is by
# default one day, then work out the number of points currently
# in the system
############################################################

sub determine_mod_points_to_be_issued {
	my($slashdb) = @_;

	# So, to the database
	my $dailycomments =  $slashdb->countCommentsInActivePeriod();
	my $points_in_circulation = $slashdb->getTotalModPointsInCirculation();

	# This is a bit simple, and I want it smarter, but basically
	# every comment in the last 24 should be theorically moddable at 
	# least once.
	#
	# So one comment == one modpoint in circulation at a given time
	#
	# We double that to insure there are plenty of modpoints in circulation
	# and to handle issues who are elligable for moderation, but just aren't
	# active, willing to mod (despite having it checked!).
	#
	# Note, it IS possible for too many modpoints to be in circulation, so
	# in those cases, the system won't try to hand more out until some expire
	# out of the database
	#
	# This is combined with a shorter mod_stir_period which reduces the time
	# until points go poof to make mod points come and go rapidly in circulation
	 
	my $points_to_issue = $dailycomments*2-$points_in_circulation;
	
	slashdLog("dailycomments: $dailycomments");
	slashdLog("points_currently_in_circulation: $points_in_circulation");
	slashdLog("points_to_issue: $points_to_issue");
	return $points_to_issue;
}

########################################################
# For process_moderatord
#
# MC: Ok, this is a lot simplier than the old moderation
# system, and with luck, considerably more effective.

sub distributeModPoints {
	my ($constants, $slashdb, $points_total) = @_;
	my $moddb = getObject('Slash::Moderation');
	
	# First, we need to know some base information
	#
	# * Total users active
	# * Total number of current moderators
	# * Desired percentage of moderators
	# * Current min and max mod points per user
	# 
	# A user is considered active if they've logged in within mod_stir_hours
	# (with the initial implementation setting this to 24 hours). This keeps 
	# mod points flowing in the system, since at most they can be locked for
	# 24 hours, and someone who signed in yesterday has a far better chance
	# of signing in today.
	#
	# This is admitly a bit of a crapshoot, but we have no way of reclaiming
	# points in users that have gone inactive except for waiting for them to
	# expire. Also, let's call it insentive to be logged in every day :-)
	
	# These are either constants, or easy to calculate
	my $current_mod_count = $slashdb->getModeratorCount();
	
	# These variables directly affect who is eligable via the SELECT query
	my $user_activity_period = $constants->{mod_activity_level}          || 24;
	my $karma_min            = $constants->{mod_elig_minkarma}       || 0;
	my $age_min              = $constants->{m1_pointgrant_end}       || 1;
	
	# Hit the DB
	# We don't want to be selecting a huge data store multiple times, so 
	# we'll get a list off possible mods, then manipulate it here

	slashdLog("Determing current users elligable on following criteria");
	slashdLog("Karma >= $karma_min");
	slashdLog("Active Within: $user_activity_period");
	slashdLog("Account is older than what percentage: " . int($age_min * 100) . "%" );
	my $potential_moderators =
		getPotentialModerators($constants, $slashdb, $user_activity_period, $karma_min, $age_min);

	# Some basic math to work out percentages
	my $current_elligable_count = $potential_moderators->rows;
	my $total_users_elligable = $current_mod_count + $current_elligable_count;
	my $current_mod_percentage = ($total_users_elligable-$current_elligable_count)/$total_users_elligable;

	slashdLog("---------------------------------------------");
	slashdLog("Current elligable moderators: $current_elligable_count");
	slashdLog("Current mod percentage: " . sprintf "%.2f", $current_mod_percentage*100 . "%");
	slashdLog("Total Active Users: $total_users_elligable");

	# Now lets figure out who's getting what
	my $mod_percentage       = $constants->{m1_eligible_percentage}  || 0.30;
	my $mod_points_min       = $constants->{mod_min_points_per_user} || 10;
	my $mod_points_max       = $constants->{mod_max_points_per_user} || 25;
	
	# We need to know the total number of elligable users, then devate from
	# how many active users have mod points vs. all active, which should
	# always be around $mod_percentage
	
	# We will exceed the current percentage of moderators IF we can't hand out
	# all our points to
	# EDIT: Should probably use Math::Round

	my $users_to_hand_points_to = int($current_elligable_count*($mod_percentage-$current_mod_percentage));
	my $points_per_user = int($users_to_hand_points_to/$points_total);
	
	if ($points_per_user < $mod_points_min) {
		# Always want to have SOME modpoints in circulation even if the comment count
		# is low
		$points_per_user = $mod_points_min;
		slashdLog("Bumping modpoints per user up to $mod_points_min");
		
	} elsif ($points_per_user > $mod_points_max) {
		# In the rare cases we want to hand out more points than
		# the percentage if we've got THAT many articles that need
		# it. TBH. I don't expect this logic too often
		
		my $extra_points = $points_total-($mod_points_max*$users_to_hand_points_to);
		$users_to_hand_points_to += ($extra_points/$mod_points_max);
		slashdLog("Overflowed number of points to hand out, increasing")
	}
	
	slashdLog("Handling modpoints to " . + $users_to_hand_points_to . + "users");
	
	# Do magic
	my $mod_rows = $potential_moderators->fetchall_arrayref;
	for my $i ( 0 .. $users_to_hand_points_to ) {
		$moddb->setUser($mod_rows->[$i]['uid'], {
			-lastgranted    => 'NOW()',
			-points         => $points_per_user,
		});
	}
}


########################################################
# So a user is considered a potential moderator if ALL
# the above is true
#
# * User is not CURRENTLY a moderator
# * User has logged within the activity period
# * User is not too young (disabled on v1 in the DB)
# * User has neutral or positive karma (specifics to be decided)
#
# Furthermore, the algo weights the following options
#
# * How recently was a user a moderator which is why the
#    tables is sorted by last time modpoints were issues
########################################################

sub getPotentialModerators {
	my($constants, $slashdb, $user_activity_period, $karma, $age_percentile) = @_;

	# Figure out what the highest UID we can have is
	my $highest_uid = $slashdb->sqlSelect("MAX(uid)", "users", "");
	my $highest_elligable_uid = int($age_percentile * $highest_uid);
	my $anon_uid = $constants->{anonymous_coward_uid};

	# Had to move columns between tables to make this work well.
	# JOINS are scary :-)

	return $slashdb->sqlSelectMany('uid, karma',
		"users_info",
		"karma >= $karma AND lastaccess_ts > DATE_SUB(CURDATE(), INTERVAL $user_activity_period MINUTE) AND (points = 0) AND (uid <= $highest_elligable_uid) AND uid != $anon_uid ORDER BY lastgranted ASC"
	);

} 

1;


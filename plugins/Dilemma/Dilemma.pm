# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Dilemma;

use strict;
use Time::HiRes;
use Safe;
use Storable qw( freeze thaw dclone );
use Slash::Utility;
use Slash::DB::Utility;
use vars qw($VERSION);
use base 'Slash::DB::Utility';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# ZOIDBERG: Friends! Help! A guinea pig tricked me!

#################################################################
sub new {
	my($class, $user) = @_;
	my $self = {};

	my $plugin = getCurrentStatic('plugin');
	return unless $plugin->{Dilemma};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect();

	return $self;
}

#################################################################
# Eventually this will take a param of tournament ID, and return
# the info specific to that tournament
sub getDilemmaInfo {
	my($self) = @_;
	return $self->sqlSelectHashref("*", "dilemma_info", "", "LIMIT 1");
}

#################################################################
sub getDilemmaSpeciesInfo {
	my($self) = @_;
	my $species = $self->getDilemmaSpecies();
	my $count = $self->sqlSelectAllHashref(
		[qw( dsid alive )],
		"dsid, alive, COUNT(*) AS c, SUM(food) AS sumfood",
		"dilemma_agents",
		"",
		"GROUP BY dsid, alive");
	my $species_info = { };
	for my $dsid (keys %$species) {
		$species_info->{$dsid}{name} = $species->{$dsid}{name};
		$species_info->{$dsid}{code} = $species->{$dsid}{code};
		$species_info->{$dsid}{sumfood} = $species-{$dsid}{sumfood};
		$species_info->{$dsid}{alivecount} = $count->{$dsid}{yes}{c} || 0;
		$species_info->{$dsid}{totalcount} = ($count->{$dsid}{yes}{c}
			+ $count->{$dsid}{no}{c}) || 0;
	}
	return $species_info;
}

#################################################################
sub getDilemmaAgentsInfo {
	my($self) = @_;
	return $self->sqlSelectAllHashref(
		"daid",
		"daid, dsid, born",
		"dilemma_agents");
}

#################################################################
sub getDilemmaSpecies {
	my($self) = @_;
	return $self->sqlSelectAllHashref(
		"dsid",
		"*",
		"dilemma_species");
}

#################################################################
sub getDilemmaAgentsForSpecies {
	my($self, $dsid) = @_;
	return undef unless $dsid;
	my $dsid_q = $self->sqlQuote($dsid);
	return $self->sqlSelectAllHashref(
		"daid",
		"*",
		"dilemma_agents",
		"species=$dsid_q");
}

#################################################################
sub getAllAliveDilemmaAgentIDs {
	my($self) = @_;
	return $self->sqlSelectColArrayref(
		"daid",
		"dilemma_agents",
		"alive='yes'");
}

#################################################################
sub getUniqueRandomAgents {
	my($self, $num) = @_;
	my $retval = [ ];
	my $ids = $self->getAllAliveDilemmaAgentIDs();
	if ($num == scalar(@$ids)) {
		push @$retval, @$ids;
	} elsif ($num > scalar(@$ids)) {
		# No way to satisfy this request, there seems to
		# be a genetic monoculture.
		return undef;
	} else {
		while (@$ids && $num-- > 0) {
			# Remove a random agent from @$ids and push
			# it onto our list.
			push @$retval, splice(@$ids, rand(@$ids), 1);
		}
	}
	return $retval;
}

#################################################################
sub reproduceAgents {
	my($self, $daids) = @_;
	return undef unless $daids && @$daids;

	my $info = $self->getDilemmaInfo();
	my $last_tick = $info->{last_tick};

	my $species_births_hr = { };
	for my $daid (@$daids) {
		my $daid_q = $self->sqlQuote($daid);
		
		# Cut the agent's food in half.
		my $updated = $self->sqlUpdate(
			"dilemma_agents",
			{ -food => "food/2" },
			"daid = $daid_q AND alive='yes'");
		# If that update failed, the agent either doesn't exist or
		# is dead.
		next unless $updated;

		# Grab a copy of the agent, with half the food now, and insert
		# it again.
		my $agent_hr = $self->sqlSelectHashref(
			"*",
			"dilemma_agents",
			"daid=$daid_q");
		delete $agent_hr->{daid};
		$agent_hr->{born} = $last_tick;
		my $success = $self->sqlInsert("dilemma_agents", $agent_hr);
		$species_births_hr->{$agent_hr->{dsid}}++ if $success;
	}
	return $species_births_hr;
}

#################################################################

sub countAliveAgents {
	my($self) = @_;
	return $self->sqlCount("dilemma_agents", "alive='yes'");
}

sub doTickHousekeeping {
	my($self) = @_;
	my $info = $self->getDilemmaInfo();

##print STDERR "doTickHousekeeping info: " . Dumper($info);

	# If the info is complete, this is easy.
	return 0 if $info->{alive} ne 'yes';

	##########
	# First, all alive agents burn food.
	my $idle_food_q = $self->sqlQuote($info->{idle_food});
	$self->sqlUpdate("dilemma_agents",
		{ -food => "food - $idle_food_q" },
		"alive = 'yes'");
	# Get the stats per species
	my $species_stats_hr = $self->sqlSelectAllHashref(
		"dsid",
		"dsid, COUNT(*) AS c",
		"dilemma_agents",
		"alive = 'yes' AND food <= 0",
		"GROUP BY dsid");
	# Update the species stats for the deaths.
	for my $dsid (keys %$species_stats_hr) {
		my $dsid_q = $self->sqlQuote($dsid);
		my $inc = $species_stats_hr->{$dsid}{c} || 0;
		next unless $inc;
		my $inc_q = $self->sqlQuote($inc);
		$self->sqlUpdate("dilemma_species",
			{ -deaths => "deaths + $inc_q" },
			"dsid = $dsid_q");
	}
	# Kill off the newly dead agents.
	$self->sqlUpdate("dilemma_agents",
		{ alive => 'no' },
		"food <= 0 AND alive = 'yes'");
	
	##########
	# Any agents with food stores exceeding the birth_food,
	# reproduce.
	my $birth_food_q = $self->sqlQuote($info->{birth_food});
	my $fat_daids = $self->sqlSelectColArrayref(
		"daid",
		"dilemma_agents",
		"food >= $birth_food_q");
	my $species_births_hr = $self->reproduceAgents($fat_daids);
##print STDERR "species_births_hr: " . Dumper($species_births_hr);
	# Update the species stats for the births.
	for my $dsid (keys %$species_births_hr) {
		my $dsid_q = $self->sqlQuote($dsid);
		my $count_q = $self->sqlQuote($species_births_hr->{$dsid});
		$self->sqlUpdate("dilemma_species",
			{ -births => "births + $count_q" },
			"dsid = $dsid_q");
	}

	##########
	# If this was the last tick, or if there is one or fewer
	# agents left alive, we're done.
	my $retval = 1;
	$self->sqlUpdate("dilemma_info",
		{ -last_tick => "last_tick + 1" });
	$info = $self->getDilemmaInfo();
	my $count_alive = $self->countAliveAgents();
	if ($info->{last_tick} >= $info->{max_runtime} || $count_alive <= 1) {
		$self->sqlUpdate("dilemma_info",
			{ alive => 'no' });
		$retval = 0;
	}
	my $last_tick = $self->getDilemmaInfo()->{last_tick};

	# Write count and food info for the species into dilemma_stats.
	my $species = $self->getDilemmaSpeciesInfo();
	for my $dsid (keys %$species) {
		# Should these be sqlReplace instead?
		$self->sqlInsert("dilemma_stats", {
			tick => $last_tick,
			dsid => $dsid,
			name => "num_alive",
			value => $species->{$dsid}{alivecount} || 0,
		}, { ignore => 1 });
		$self->sqlInsert("dilemma_stats", {
			tick => $last_tick,
			dsid => $dsid,
			name => "sumfood",
			value => $species->{$dsid}{sumfood} || 0,
		}, { ignore => 1 });
	}

	return $retval;
}

sub getStatsBySpecies {
	my($self, $dsid) = @_;
	my $dsid_q = $self->sqlQuote($dsid);
	return $self->sqlSelectColArrayref(
		"value",
		"dilemma_stats",
		"dsid=$dsid_q AND name='num_alive'",
		"ORDER BY tick");
}

sub getAveragePlay {
	my($self, $options) = @_;
	my $max = $options->{max} || 1;
	return $self->sqlSelectColArrayref(
		"AVG(playactual) * $max",
		"dilemma_meetlog, dilemma_playlog",
		"dilemma_meetlog.meetid=dilemma_playlog.meetid",
		"GROUP BY tick ORDER BY tick");
}

sub getSpecieses {
	my($self) = @_;
	return $self->sqlSelectAllHashref(
		"dsid",
		"*",
		"dilemma_species");
}

sub getAgents {
	my($self, $daids) = @_;
	my $species = $self->getSpecieses();
	my $daids_list = join(",", map { $self->sqlQuote($_) } @$daids);
	my $agent_data = $self->sqlSelectAllHashref(
		"daid",
		"*",
		"dilemma_agents",
		"daid IN ($daids_list)");
	for my $daid (keys %$agent_data) {
		# Unthaw its memory.
		my $memory = $agent_data->{$daid}{memory};
		my $thawed = undef;
		if ($memory) {
			my $thawed_ref = thaw($memory);
#print STDERR "thawed_ref: " . Dumper($thawed_ref);
			$thawed = $$thawed_ref if defined($thawed_ref);
		}
		$agent_data->{$daid}{memory} = $thawed;
		# Copy over a few fields from its species.
		$agent_data->{$daid}{code} = $species->{$agent_data->{$daid}{dsid}}{code};
		$agent_data->{$daid}{species_name} = $species->{$agent_data->{$daid}{dsid}}{name};
	}
#use Data::Dumper; print STDERR "agent_data for daids '$daids_list': " . Dumper($agent_data);
	return $agent_data;
}

sub setAgents {
	my($self, $agent_data) = @_;
#use Data::Dumper; print STDERR "setAgents: " . Dumper($agent_data);
	my @daids = keys %$agent_data;
	# lock table here
	my $total_rows = 0;
	for my $daid (@daids) {
		my $new_hr = dclone($agent_data->{$daid});
		my $daid_q = $self->sqlQuote($daid);
		delete $new_hr->{daid};
		delete $new_hr->{code};
		delete $new_hr->{species_name};
		if (defined $new_hr->{memory}) {
			my $frozen_memory = freeze(\$new_hr->{memory});
			# Agents can't save memories longer than a certain
			# limit;  those that try get BRAIN-WIPED.  Mwoohaha.
			$frozen_memory = "" if length($frozen_memory) > 10_000;
			$new_hr->{memory} = $frozen_memory;
		} else {
			$new_hr->{memory} = "";
		}
#print STDERR "setAgents daid=$daid updating: " . Dumper($new_hr);
		$total_rows += $self->sqlUpdate(
			"dilemma_agents",
			$new_hr,
			"daid=$daid_q");
	}
	# unlock table
	return $total_rows;
}

sub runSafeWithGlobals {
	my($self, $code, $global_hr, $options) = @_;
	my $debug_str = $options->{debuginfo} || "";
	my $start_time = Time::HiRes::time;
	my $safe = new Safe();
	$safe->permit(qw( :default :base_math ));
	for my $key (sort keys %$global_hr) {
		my($type, $varname) = $key =~ /^([\$\@\%])([A-Za-z]\w*)$/;
		if (!$type) { warn "no type match for key '$key'" }
		next unless $type;
		my $vg = $safe->varglob($varname);
		my $value = $global_hr->{$key};
		   if ($type eq '$') { $$vg =  $value }
		elsif ($type eq '@') { @$vg = @$value }
		elsif ($type eq '%') { %$vg = %$value }
#		   if ($type eq '$') { $$vg =  $value; print STDERR "rswg set scalar '$vg' to '$value'\n" }
#		elsif ($type eq '@') { @$vg = @$value; print STDERR "rswg set array '$vg' to '@$value'\n" }
#		elsif ($type eq '%') { %$vg = %$value; print STDERR "rswg set hash '$vg' to keys '" . join(" ", sort keys %$value) . "'\n" }
	}
	my($err, $retval);
	$code = [ $code ] if ref($code) ne 'ARRAY';
	for my $line (@$code) {
		$retval = $safe->reval($line);
		$err = $@;
		last if $err;
	}
	my $elapsed = Time::HiRes::time - $start_time;
	if ($err) {
		# A code error is interpreted as total defection.
		$retval = 0;
		if ($err && $err =~ /Undefined subroutine .*debrief called/) {
			# Don't log this if the problem is simply that
			# an optional function is not defined.
			$err = "";
		}
	}
	if ($err) {
		$debug_str = " debug_info='$debug_str'" if $debug_str;
		chomp $err;
#		printf STDERR "Safe->reval%s error: '%s'\n",
#			$debug_str,
#			$err;
	}
#use Data::Dumper;
#printf STDERR "runSafeWithGlobals in %.5f secs for '%s', global_hr_memory_hash: %s", $elapsed, $debug_str, Dumper($global_hr->{"\%memory"});
	return($retval, $safe);
}

sub agentPlay {
	my($self, $play_hr) = @_;

	my $agent_data	= $play_hr->{agent_data};
	my $info	= $play_hr->{info};
	my $me_daid	= $play_hr->{me_daid};
	my $it_daid	= $play_hr->{it_daid};

	# For convenience.
	my %me = %{ $agent_data->{$me_daid} };
#use Data::Dumper; print STDERR "agentPlay daid=$me_daid me: " . Dumper(\%me);

	# Call the play() function.
	my @code = ( $me{code}, "play()" );

	# Create the package in which this agent will run.  There may be
	# a way to save some time here by caching it and poking in the
	# values of its globals afterwards, I don't know.
	my($response) = $self->runSafeWithGlobals( \@code, {
		'$memory'	=> $me{memory},
		'$cur_tick'	=> $info->{last_tick},
		'$foodsize'	=> $play_hr->{foodsize},
		'$me_id'	=> $me_daid,
		'$me_food'	=> $me{food},
		'$it_id'	=> $it_daid,
	}, { debuginfo => "agentPlay daid=$me{daid} dsid=$me{dsid}" });

	# Convert undef, "", "0 but true", 0E0, etc. all to 0;
	# canonicalize scientific notation and so on.
	$response += 0;

	# Failure to respond with a number between 0 and 1
	# is interpreted as total defection.
	if (!defined($response)
		|| !length($response)
		|| $response < 0
		|| $response > 1) {
		$response = 0;
	}

##printf STDERR "$agent_data->{$me_daid}{species_name}/$me_daid played %.3f against $agent_data->{$it_daid}{species_name}/$it_daid\n", ($response || 0);

	return $response;
}

sub agentDebrief {
	my($self, $debrief_hr) = @_;

	my $agent_data	= $debrief_hr->{agent_data};
	my $info	= $debrief_hr->{info};
	my $me_daid	= $debrief_hr->{me_daid};
	my $it_daid	= $debrief_hr->{it_daid};

	# For convenience.
	my %me = %{ $agent_data->{$me_daid} };

	# Call the debrief() function.
	my @code = ( $me{code}, "debrief()" );

	# Create the package in which this agent will run.  Note that
	# unlike agentPlay() we don't care about the return value,
	# but we are going to need the Safe object to pull out the
	# (presumably updated) memory value.
#use Data::Dumper;
##print STDERR "agentDebrief me_memory: " . Dumper($me{memory});
	my $memory_clone = undef;
	if (defined($me{memory})) {
		if (ref($me{memory})) {
			$memory_clone = dclone($me{memory});
		} else {
			$memory_clone = $me{memory};
		}
	}
#print STDERR "agentDebrief me_daid=$me_daid memory_clone: " . Dumper($memory_clone);
	my($dummy, $safe) = $self->runSafeWithGlobals( \@code, {
		'$memory'	=> $memory_clone,
		'$cur_tick'	=> $info->{last_tick},
		'$foodsize'	=> $debrief_hr->{foodsize},
		'$me_id'	=> $me_daid,
		'$me_food'	=> $me{food},
		'$me_play'	=> $debrief_hr->{me_play},
		'$me_gain'	=> $debrief_hr->{me_gain},
		'$it_id'	=> $it_daid,
		'$it_play'	=> $debrief_hr->{it_play},
		'$it_gain'	=> $debrief_hr->{it_gain},
	}, { debuginfo => "agentDebrief daid=$me{daid} dsid=$me{dsid}" });
	my $new_memory_varglob = $safe->varglob("memory");
	my $new_memory = undef;
	   if (defined($$new_memory_varglob))	{ $new_memory =  $$new_memory_varglob }
	elsif (@$new_memory_varglob)		{ $new_memory = \@$new_memory_varglob }
	elsif (%$new_memory_varglob)		{ $new_memory = \%$new_memory_varglob }
#use Data::Dumper; print STDERR "agentDebrief me_daid=$me_daid it_daid=$it_daid safe '$safe' nmv '$new_memory_varglob' nm: " . Dumper($new_memory) . "me{memory}: " . Dumper($me{memory}) . "memory_clone: " . Dumper($memory_clone);
	return $new_memory;
}

sub agentsMeet {
	my($self, $meeting_hr, $dilemma_info) = @_;
	$dilemma_info ||= $self->getDilemmaInfo();
	my $daids = $meeting_hr->{daids};
	my $foodsize = $meeting_hr->{foodsize};

	my $info = $self->getDilemmaInfo();
	my $agent_data = $self->getAgents($daids);

	# Tweak which agents are reported to each other -- we may
	# lie to their code, mwoohahaha.
	my $daids_report = $self->agentsMeet_tweakDaids($daids);

	# For each agent, get its play by calling its play() function.
	my @response = ( );
	$response[0] = $self->agentPlay({
		agent_data =>	$agent_data,
		info =>		$info,
		foodsize =>	$foodsize,
		me_daid =>	$daids->[0],
		it_daid =>	$daids_report->[1],
	});
	$response[1] = $self->agentPlay({
		agent_data =>	$agent_data,
		info =>		$info,
		foodsize =>	$foodsize,
		me_daid =>	$daids->[1],
		it_daid =>	$daids_report->[0],
	});

	# Tweak the responses randomly.
	my $response_tweaked = $self->agentsMeet_tweakResponses(\@response);

	# For each agent, calculate the payoffs (aka who "won" if you
	# are in a zero-sum mentality).

	my @payoff = ( );
	$payoff[0] = $self->determinePayoff(
		$response_tweaked->[0], $response_tweaked->[1],
		{ foodsize => $foodsize });
	$payoff[1] = $self->determinePayoff(
		$response_tweaked->[1], $response_tweaked->[0],
		{ foodsize => $foodsize });

	# Then call each species' debrief() function with $me_play and
	# $it_play set (plus some other variables), letting it update its
	# $memory if its wants; then save the payoffs and new memories to
	# the DB.

	my @memory = ( );
	$memory[0] = $self->agentDebrief({
		agent_data =>	$agent_data,
		info =>		$info,
		foodsize =>	$foodsize,
		me_daid =>	$daids->[0],
		me_play =>	$response_tweaked->[0],
		me_gain =>	$payoff[0],
		it_daid =>	$daids_report->[1],
		it_play =>	$response_tweaked->[1],
		it_gain =>	$payoff[1],
	});
	$memory[1] = $self->agentDebrief({
		agent_data =>	$agent_data,
		info =>		$info,
		foodsize =>	$foodsize,
		me_daid =>	$daids->[1],
		me_play =>	$response_tweaked->[1],
		me_gain =>	$payoff[1],
		it_daid =>	$daids_report->[0],
		it_play =>	$response_tweaked->[0],
		it_gain =>	$payoff[0],
	});

	$self->awardPayoffAndMemory($daids->[0], $payoff[0], $memory[0]);
	$self->awardPayoffAndMemory($daids->[1], $payoff[1], $memory[1]);

	$self->logMeeting({
		tick =>		$dilemma_info->{last_tick},
		foodsize =>	$foodsize,
		plays =>	[
			{ daid =>	$daids->[0],
			  playtry =>	$response[0],
			  playactual =>	$response_tweaked->[0],
			  reward =>	$payoff[0],
			  sawdaid =>	$daids_report->[1],	},
			{ daid =>	$daids->[1],
			  playtry =>	$response[1],
			  playactual =>	$response_tweaked->[1],
			  reward =>	$payoff[1],
			  sawdaid =>	$daids_report->[0],	},
		],
	});
}

sub agentsMeet_tweakDaids {
	my($self, $real_daids) = @_;
	my $constants = getCurrentStatic();
	my $daids_report = [ @$real_daids ];
	for my $i (0..$#$daids_report) {
		next unless rand(1) < $constants->{dilemma_errorchange_id};
		my $unique_agents = $self->getUniqueRandomAgents(1);
		next unless $unique_agents; # just make sure request succeeded
		$daids_report->[$i] = $unique_agents->[0];
	}
	return $daids_report;
}

sub agentsMeet_tweakResponses {
	my($self, $response_ar) = @_;
	return [ ] if !$response_ar || !@$response_ar;
	my $constants = getCurrentStatic();
	my @resp = @$response_ar;
	my $ec_play = $constants->{dilemma_errorchange_play} || 0;
	return \@resp if !$ec_play;
	for my $i (0..$#resp) {
		my $val = $resp[$i];
		$val += rand(1) * $ec_play * 2 - $ec_play;
		$val = 0 if $val < 0;
		$val = 1 if $val > 1;
		$resp[$i] = $val;
	}
	return \@resp;
}

# Would probably improve performance to store these up and write
# them all at once

sub logMeeting {
	my($self, $meeting_hr) = @_;

	$self->sqlInsert("dilemma_meetlog", {
		tick =>		$meeting_hr->{tick},
		foodsize =>	$meeting_hr->{foodsize},
	});
	my $meetid = $self->getLastInsertId();
	for my $play (@{$meeting_hr->{plays}}) {
		$self->sqlInsert("dilemma_playlog", {
			meetid =>	$meetid,
			daid =>		$play->{daid},
			playtry =>	$play->{playtry},
			playactual =>	$play->{playactual},
			reward =>	$play->{reward},
			sawdaid =>	$play->{sawdaid},
		});
	}
}

sub getLogDataDump {
	my($self) = @_;

	my $species_info_hr = $self->getDilemmaSpeciesInfo();
	my $agents_info_hr = $self->getDilemmaAgentsInfo();
	my $meetlog_sth = $self->sqlSelectMany(
		"*",
		"dilemma_meetlog",
		"",
		"ORDER BY meetid");
	my $playlog_sth = $self->sqlSelectMany(
		"*",
		"dilemma_playlog",
		"",
		"ORDER BY meetid, daid");
	return {
		species_info =>	$species_info_hr,
		agents_info =>	$agents_info_hr,
		meetlog_sth =>	$meetlog_sth,
		playlog_sth =>	$playlog_sth,
	};
}

sub determinePayoff {
	my($self, $x, $y, $options) = @_;
	$x = 0 if !$x || $x < 0;
	$x = 1 if $x > 1;
	$y = 0 if !$y || $y < 0;
	$y = 1 if $y > 1;
	my $foodsize = $options->{foodsize} || 1;
	return $foodsize * ( 4*$y - $x - $x*$y + 1 );
}

sub awardPayoffAndMemory {
	my($self, $daid, $payoff, $memory) = @_;

	my $payoff_q = $self->sqlQuote($payoff);

	# Increment the species rewardtotal.
	my $agent_data = $self->getAgents([ $daid ]);
	my $dsid_q = $self->sqlQuote($agent_data->{$daid}{dsid});
	$self->sqlUpdate(
		"dilemma_species",
		{ -rewardtotal => "rewardtotal + $payoff_q" },
		"dsid = $dsid_q");

	# Now give the agent its food and memory.
	my $new_daid = {
		$daid => {
			-food => "food + $payoff_q",
			# memory gets frozen by setAgents()
			memory => $memory,
		}
	};
	# Return the number of rows affected.
	return $self->setAgents($new_daid);
}

#################################################################
sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if $self->{_dbh} && !$ENV{GATEWAY_INTERFACE};
}

1;

=head1 NAME

Slash::Dilemma - Slash plugin to run Prisoner's Dilemma tournaments

=head1 SYNOPSIS

	use Slash::Dilemma;

=head1 DESCRIPTION

This contains all of the methods currently used by Dilemma.

=head1 SEE ALSO

Slash(3).

=cut

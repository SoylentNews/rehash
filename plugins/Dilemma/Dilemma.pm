# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Dilemma;

use strict;
use Time::HiRes;
use Safe;
use Storable qw( freeze thaw );
use Slash::Utility;
use Slash::DB::Utility;
use vars qw($VERSION
	%me %it $foodsize $me_play $it_play
);
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
		"dsid, alive, COUNT(*) AS c",
		"dilemma_agents",
		"",
		"GROUP BY dsid, alive");
	my $species_info = { };
	for my $dsid (keys %$species) {
		$species_info->{$dsid}{name} = $species->{$dsid}{name};
		$species_info->{$dsid}{code} = $species->{$dsid}{code};
		$species_info->{$dsid}{alivecount} = $count->{$dsid}{yes}{c} || 0;
		$species_info->{$dsid}{totalcount} = ($count->{$dsid}{yes}{c}
			+ $count->{$dsid}{no}{c}) || 0;
	}
	return $species_info;
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

#print STDERR "doTickHousekeeping info: " . Dumper($info);

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
#print STDERR "species_births_hr: " . Dumper($species_births_hr);
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

	# Write count info for the species into dilemma_stats.
	my $species = $self->getDilemmaSpeciesInfo();
	for my $dsid (keys %$species) {
		$self->sqlInsert("dilemma_stats", {
			tick => $last_tick,
			dsid => $dsid,
			name => "num_alive",
			value => $species->{$dsid}{alivecount} || 0,
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
			$thawed = thaw($memory);
		}
		$agent_data->{$daid}{memory} = $thawed;
		# Copy over a few fields from its species.
		$agent_data->{$daid}{code} = $species->{$agent_data->{$daid}{dsid}}{code};
		$agent_data->{$daid}{species_name} = $species->{$agent_data->{$daid}{dsid}}{name};
	}
#use Data::Dumper; print STDERR "agent_data: " . Dumper($agent_data);
	return $agent_data;
}

sub setAgents {
	my($self, $agent_data) = @_;
#use Data::Dumper; print STDERR "setAgents: " . Dumper($agent_data);
	my @daids = keys %$agent_data;
	# lock table here
	my $total_rows = 0;
	for my $daid (@daids) {
		my %new = %{$agent_data->{$daid}};
		my $daid_q = $self->sqlQuote($daid);
		delete $new{daid};
		delete $new{code};
		delete $new{species_name};
		if (defined $new{memory}) {
			my $frozen_memory = freeze($new{memory});
			# Agents can't save memories longer than a certain
			# limit;  those that try get BRAIN-WIPED.
			$frozen_memory = "" if length($frozen_memory) > 10_000;
			$new{memory} = $frozen_memory;
		} else {
			$new{memory} = "";
		}
#print STDERR "setAgents updating: " . Dumper(\%new);
		$total_rows += $self->sqlUpdate(
			"dilemma_agents",
			\%new,
			"daid=$daid_q");
	}
	# unlock table
	return $total_rows;
}

sub agentsMeet {
	my($self, $meeting_hr) = @_;
	my $daids = $meeting_hr->{daids};
	$foodsize = $meeting_hr->{foodsize};

	my $agent_data = $self->getAgents($daids);
	my %response = ( );

	for my $daid (@$daids) {
		# Spin off a copy of this agent and store it in
		# $me for its code to read as it seems fit.
		%me = %{ $agent_data->{$daid} };

		# Here's the only info an agent gets about its
		# opponent:  its daid.  It might be fun to pass
		# along something about its age, or how much
		# food it has, so agents could use that info
		# if they wants.  But for now, just the daid.
		my($it_daid) = grep { $_ != $daid } @$daids;
		%it = ( daid => $it_daid );

		$me_play = $it_play = undef;

		# Call each species' code for the first time.
		# $me_play and $it_play are undef, indicating
		# we need a response.

		my $safe = new Safe();
		$safe->permit(qw( :default :base_math :base_loop ));
		$safe->share(qw( %me %it $foodsize $me_play $it_play ));
		my $start_time = Time::HiRes::time;
		my $response = $safe->reval($me{code});
		print STDERR "agentsMeet 1 \$\@: '$@'\n" if $@;
#printf STDERR "$agent_data->{$daid}{species_name}/$me{daid} played %.3f against $agent_data->{$it_daid}{species_name}/$it{daid}\n", ($response || 0);
		my $elapsed = Time::HiRes::time - $start_time;

		if (!defined($response)
			|| !length($response)
			|| $response !~ /^\d*(\.\d+)?$/
			|| $response < 0
			|| $response > 1) {
			# Failure to respond with a number between
			# 0 and 1 means total cooperation.
			$response{$daid} = 1;
		} else {
			$response{$daid} = $response;
		}
	}
#print STDERR "response: " . Dumper(\%response);

	# For each agent, calculate the payoffs (aka who "won" if you
	# are in a zero-sum mentality).  Then call each species' code
	# again with $me_play and $it_play set, indicating the code
	# can update its memory if it wants;  then save the payoffs
	# and new memories to the DB.

	for my $daid (@$daids) {
		%me = %{ $agent_data->{$daid} };

		my($it_daid) = grep { $_ != $daid } @$daids;
		%it = ( daid => $it_daid );

		$me_play = $response{$daid};
		$it_play = $response{$it_daid};
		my $payoff = $self->determinePayoff(
			$me_play, $it_play,
			{ foodsize => $foodsize });

		my $safe = new Safe();
		$safe->permit(qw( :default :base_math :base_loop ));
		$safe->share(qw( %me %it $foodsize $me_play $it_play ));
		my $start_time = Time::HiRes::time;
		$safe->reval($me{code});
		print STDERR "agentsMeet 2 \$\@: '$@'\n" if $@;
		my $elapsed = Time::HiRes::time - $start_time;

		# The agent presumably modified its memories based
		# on this new information.  Copy that memory hashref
		# back into its hashref, on top of what was there,
		# so it will be saved in the DB.
		$agent_data->{$daid}{memory} = $me{memory};

		$self->awardPayoffAndMemory($agent_data->{$daid},
			$payoff);
	}
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
	my($self, $agent_data, $payoff) = @_;
	my $daid = $agent_data->{daid};
	my $payoff_q = $self->sqlQuote($payoff);
	my $daid_q = $self->sqlQuote($daid);
	my $dsid_q = $self->sqlQuote($agent_data->{dsid});

	# Increment the species rewardtotal.
	$self->sqlUpdate(
		"dilemma_species",
		{ -rewardtotal => "rewardtotal + $payoff_q" },
		"dsid = $dsid_q");

	# Now give the agent its food and memory.
	my $new_daid = {
		$daid => {
			-food => "food + $payoff_q",
			memory => $agent_data->{memory},
		}
	};
	$self->setAgents($new_daid);
#	my $frozen_memory = "";
#	$frozen_memory = freeze($agent_data->{memory})
#		if defined($agent_data->{memory});
#	$self->sqlUpdate(
#		"dilemma_agents",
#		{ -food => "food + $payoff_q",
#		  memory => $frozen_memory,	},
#		"daid = $daid_q");
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

#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use Slash::Constants ':slashd';

use strict;

use vars qw( %task $me );

$task{$me}{timespec} = '0-59 * * * *';
$task{$me}{timespec_panic_1} = '';
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;

	my $dilemma_reader = getObject('Slash::Dilemma', { db_type => 'reader' });
	my $dilemma_db = getObject('Slash::Dilemma');
	my $dilemma_info = $dilemma_reader->getDilemmaInfo();
	return "stopped" if $dilemma_info->{alive} ne 'yes';
	my $start_tick = $dilemma_info->{last_tick};

	my $start_time = time;

	# Don't run the dilemma forever;  run for not quite a
	# minute and then exit, letting a new invocation
	# continue.  This way, shutting down slashd will stop
	# this task in a reasonable time.  Try to end at a
	# time right before the top of a minute.
	my $end_time = $start_time + 40;
	$end_time = int(($end_time+30) / 60)*60 - 10;

	while (time < $end_time) {
		$dilemma_info = $dilemma_reader->getDilemmaInfo();
		last if $dilemma_info->{alive} ne 'yes';

		my $food_per_time = $dilemma_info->{food_per_time};

		my $n_meets = $dilemma_info->{mean_meets};
		$n_meets = int($n_meets * (2/3 + rand(1)*(3/2-2/3)) + 0.5);
		$n_meets = 1 if $n_meets < 1;
		my $food_per_interaction = $food_per_time/$n_meets;

		for (1..$n_meets) {
			my $players = $dilemma_reader->getUniqueRandomAgents(2);
			$dilemma_db->agentsMeet({
				daids =>	$players,
				foodsize =>	$food_per_interaction,
			});
		}
		my $still_running = $dilemma_db->doTickHousekeeping();
		last unless $still_running;
	}

	$dilemma_info = $dilemma_db->getDilemmaInfo();

	my $legend_ar = [ ];
	my $alldata_ar = [ ];
	# X axis: ticks
	my $last_tick = $dilemma_info->{last_tick};
	push @$alldata_ar, [ 1 .. $last_tick ];
	# Y axis: data serieses
	my $y_max = 0;
	my $species = $dilemma_reader->getSpecieses();
	my @dsids = sort { $a <=> $b } keys %$species;
	for my $dsid (@dsids) {
		push @$alldata_ar, $dilemma_db->getStatsBySpecies($dsid);
		for my $n (@{$alldata_ar->[$#$alldata_ar]}) {
			$y_max = $n if $n > $y_max;
		}
		push @$legend_ar, $species->{$dsid}{name};
	}
	$y_max = int($y_max/10+1)*10;
	my $png = slashDisplay('graph', {
		last_tick	=> $last_tick,
		alldata		=> $alldata_ar,
		y_max		=> $y_max,
		set_legend	=> \&_set_legend,
		legend		=> $legend_ar,
	}, { Return => 1, Nocomm => 1, Page => 'dilemma' });
	my $filename = catfile($constants->{basedir}, "images/specieshistory.png");
	save2file($filename, $png);

	my $agent_count = $dilemma_db->countAliveAgents();
	return "alive: $dilemma_info->{alive} tick: $last_tick/$dilemma_info->{max_runtime} agents: $agent_count";
};

# helper method for graph(), because GD->set_legend doesn't
# take a reference, and TT can only pass a reference -- pudge
sub _set_legend {
	my($gd, $legend) = @_;
	$gd->set_legend(@$legend);
}

1;

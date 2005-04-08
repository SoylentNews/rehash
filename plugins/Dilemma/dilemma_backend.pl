#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use Slash::Constants ':slashd';

use strict;
use Time::HiRes;

use Compress::Zlib;

use vars qw( %task $me $task_exit_flag );

$task{$me}{timespec} = '0-59 * * * *';
$task{$me}{timespec_panic_1} = '';
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;

	my $cpu_percent_target = $constants->{dilemma_cpu_percent_target} || 50;
	$cpu_percent_target = 50 if $cpu_percent_target < 0 || $cpu_percent_target > 100;
	my $cpu_fraction_target = $cpu_percent_target / 100;
	my $wait_factor = 1/$cpu_fraction_target - 1;

	my $dilemma_db = getObject('Slash::Dilemma');
	my $tournament_ar = $dilemma_db->getActiveTournaments();
	my @start_active_trids = map { $_->{trid} } @$tournament_ar;
	return "stopped" if !@start_active_trids;

	my $start_time = time;

	# Don't run the dilemma forever;  run for not quite a
	# minute and then exit, letting a new invocation
	# continue.  This way, shutting down slashd will stop
	# this task in a reasonable time.  Try to end at a
	# time right before the top of a minute.
	my $end_time = $start_time + 40;
	$end_time = int(($end_time+30) / 60)*60 - 10;

	while (time < $end_time && !$task_exit_flag) {

		for my $tour (@$tournament_ar) {
			my $trid = $tour->{trid};
			my $tour_info = $dilemma_db->getDilemmaTournamentInfo($trid);
			my $food_per_tick = $tour_info->{food_per_tick};
			my $min_meets = $tour_info->{min_meets} || 1;
			my $max_meets = $tour_info->{max_meets};
			$max_meets = $min_meets if $max_meets < $min_meets;
			my $n_meets = int(rand(1) * ($max_meets-$min_meets))+$min_meets;
			my $food_per_interaction = $food_per_tick/$n_meets;

			for (1..$n_meets) {
				my $players = $dilemma_db->getUniqueRandomAgents(2);
				my $start_meet = Time::HiRes::time;
				my $meeting_hr = {
					trid =>		$trid,
					daids =>	$players,
					foodsize =>	$food_per_interaction,
				};
				$dilemma_db->agentsMeet($meeting_hr, $tour_info);
				cpu_sleep($start_meet, $wait_factor);
			}
			my $still_running = $dilemma_db->doTickHousekeeping($trid);
			last unless $still_running;
		}

		# Regenerate this list, since one or more tournaments may
		# have gone inactive thanks to what we just did.
		$tournament_ar = $dilemma_db->getActiveTournaments();
	}

	# Allow the reader to catch up.
	sleep 2;

	my %drew = ( );
	my $dilemma_reader = getObject('Slash::Dilemma', { db_type => 'reader' });
	for my $trid (@start_active_trids) {
		my $tour_info = $dilemma_reader->getDilemmaTournamentInfo($trid);
		if (need_a_draw($tour_info)) {
			draw_maingraph($tour_info);
			$dilemma_db->markTournamentGraphDrawn($trid);
			$drew{$trid} = 1;
		}
	}

	my $return_str = "";
	for my $trid (@start_active_trids) {
		my $tour_info = $dilemma_reader->getDilemmaTournamentInfo($trid);
		my $agent_count = $dilemma_reader->countAliveAgents($trid);
		$return_str .= sprintf "trid %d [tick: %d/%d agents: %d%s",
			$trid,
			$tour_info->{last_tick},
			$tour_info->{max_tick},
			$agent_count,
			($drew{$trid} ? " drew" : "");
		if (!$task_exit_flag
			&& $constants->{dilemma_logdatadump}
			&& ( $tour_info->{alive} ne 'yes'
				|| $info->{invocation_num} % 10 == 1 ) ) {
			# Every so often, or if we've just finished, then we dump it
			# into compressed XML.
			$return_str .= do_logdatadump(
				$virtual_user, $constants, $slashdb, $user, $info, $gSkin,
				$trid, $dilemma_reader, $wait_factor);
		}
		$return_str .= "] ";
	}
	$return_str =~ s/ $//;

	return $return_str;
};

# helper method for graph(), because GD->set_legend doesn't
# take a reference, and TT can only pass a reference -- pudge
sub _set_legend {
	my($gd, $legend) = @_;
	$gd->set_legend(@$legend);
}

sub cpu_sleep {
	my($start_time, $wait_factor) = @_;
	my $elapsed = Time::HiRes::time - $start_time;
	my $sleep_time = $elapsed * $wait_factor;
	return unless $sleep_time > 0;
	$sleep_time = 5 if $sleep_time > 5;
	Time::HiRes::sleep($sleep_time);
}

sub need_a_draw {
	my($tour_info) = @_;
	if ($tour_info->{active} eq 'no') {
		# This function will only be called if this tournament
		# used to be active. If it's not active anymore, then
		# it needs one final draw, regardless of when the last
		# one occurred.
		return 1;
	}
	my $constants = getCurrentStatic();
	my $last_tick = $tour_info->{last_tick};
	my $last_drawn_tick = $tour_info->{graph_drawn_tick};
	my $draw_ticks = $constants->{dilemma_draw_graph_ticks};
	my $do_draw = 0;
	if ($last_drawn_tick < $draw_ticks) {
		# Less than the draw val, always draw.
		$do_draw = 1;
	} elsif ($last_drawn_tick < $draw_ticks * 20) {
		# Between the draw val and 20x that val -- draw only if it's
		# been that val ticks since the last draw.
		$do_draw = 1 if $last_tick > $last_drawn_tick + $draw_ticks;
	} else {
		# Above 20x that val -- draw only if it's been 3x that val
		# ticks since the last draw.
		$do_draw = 1 if $last_tick > $last_drawn_tick + $draw_ticks*3;
	}
	return $do_draw;
}

sub draw_maingraph {
	my($tour_info) = @_;
	my $trid = $tour_info->{trid};
	my $constants = getCurrentStatic();
	my $dilemma_reader = getObject('Slash::Dilemma', { db_type => 'reader' });
	die "no trid" if !$trid;

	my $species = $dilemma_reader->getSpecieses($trid);
	my $legend_ar = [ ];
	my $alldata_ar = [ ];
	# Y axis: data serieses: the agent counts of each species...
	my $y_max = 0;
	my @dsids = sort { $a <=> $b } keys %$species;
	# Here's the big SELECT.  This can return megabytes.
	my $stats_hr = $dilemma_reader->getAllStats($trid);
	# First get the least and greatest mean food per agent
	# at each tick.
	my $last_tick = $tour_info->{last_tick};
	my $min_food_ratio_ar = [ (0) x $last_tick ];
	my $max_food_ratio_ar = [ (0) x $last_tick ];
	my $min_spread = $tour_info->{birth_food}/4;
	for my $t (0 .. $last_tick-1) {
		my $min = $tour_info->{birth_food};
		my $max = 0;
		my $t1 = $t+1;
		for my $dsid (@dsids) {
			my $na = $stats_hr->{num_alive}{$t1}{$dsid}{value};
			next unless $na > 0;
			my $sf = $stats_hr->{sumfood}{$t1}{$dsid}{value};
			my $mean = $sf/$na;
			$min = $mean if $mean < $min;
			$max = $mean if $max < $mean;
		}
		# The spread must always be at least a certain size,
		# namely, 1/4 of the birth_food, to prevent minor
		# changes from having over-large effect on the graph.
		#
		if ($max-$min < $min_spread) {
			my $middle = ($max+$min)/2;
			if ($middle < $min_spread/2) {
				$min = 0;
				$max = $min_spread;
			} elsif ($middle > $tour_info->{birth_food} - $min_spread/2) {
				$min = $tour_info->{birth_food} - $min_spread;
				$max = $tour_info->{birth_food};
			} else {
				$min = $middle - $min_spread/2;
				$max = $middle + $min_spread/2;
			}
		}
		$min_food_ratio_ar->[$t] = $min;
		$max_food_ratio_ar->[$t] = $max;
	}
#print STDERR "stats_hr: " . Dumper($stats_hr) if $trid == 2;
	for my $dsid (@dsids) {
		my $num_alive_ar = [ (0) x $last_tick ];
		my $food_ratio_ar = [ (0) x $last_tick ];
		for my $t (0 .. $last_tick-1) {
			my $t1 = $t+1;
			my $na = $stats_hr->{num_alive}{$t1}{$dsid}{value} || 0;
			$num_alive_ar->[$t] = $na;
			next unless $na > 0;
			my $sf = $stats_hr->{sumfood}{$t1}{$dsid}{value};
			$food_ratio_ar->[$t] = $sf/$na;
		}
		# Bump each tick's num_alive up fractionally by an amount
		# relative to where this species falls along the spectrum
		# of least mean food to most mean food at this tick.
		for my $t (0 .. $last_tick-1) {
			my $frac = 0;
			if ($food_ratio_ar->[$t]) {
				$frac = 0.8 *
					  ($food_ratio_ar->[$t] - $min_food_ratio_ar->[$t])
					/ ($max_food_ratio_ar->[$t] - $min_food_ratio_ar->[$t]);
			}
			$num_alive_ar->[$t] += $frac;
		}
#print STDERR "dsid=$dsid num_alive_ar: '@$num_alive_ar'\n" if $trid == 2;
#print STDERR "dsid=$dsid food_ratio_ar: '@$food_ratio_ar'\n" if $trid == 2;
#print STDERR "dsid=$dsid min_food_ratio_ar: '@$min_food_ratio_ar'\n" if $trid == 2;
#print STDERR "dsid=$dsid max_food_ratio_ar: '@$max_food_ratio_ar'\n" if $trid == 2;
		push @$alldata_ar, $num_alive_ar;
		for my $n (@{$alldata_ar->[$#$alldata_ar]}) {
			$y_max = $n if $n > $y_max;
		}
		push @$legend_ar, $species->{$dsid}{name};
	}
	$y_max = int($y_max/10+1)*10;
	# Y axis: prefix the agent counts with the average play
	unshift @$alldata_ar, $dilemma_reader->getAveragePlay($trid, { max => $y_max });
	unshift @$legend_ar, "avgplay";
	# X axis: ticks
	unshift @$alldata_ar, [ 1 .. $last_tick ];
	# Display the data
	my $template_data = {
		last_tick	=> $last_tick,
		alldata		=> $alldata_ar,
		y_max		=> $y_max,
		set_legend	=> \&_set_legend,
		legend		=> $legend_ar,
	};
	my $png = slashDisplay('graph', $template_data,
		{ Return => 1, Nocomm => 1, Page => 'dilemma' });
	my $path = catdir($constants->{basedir}, "images", "dilemma");
	mkpath($path, 0, 0775) unless -e $path;
	my $filename = catfile($path, sprintf("maingraph-%03d.png", $trid));
	save2file($filename, $png);
#print STDERR "png is " . length($png) . " bytes, disk file is " . (-s $filename) . " bytes\n";
}

sub do_logdatadump {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin,
		$trid, $dilemma_reader, $wait_factor) = @_;

return " do_logdatadump disabled for now";

	my $return_str = "";
	my($compbytes, $uncompbytes) = (0, 0);

	# Standard XML header...
	my $xml = qq{<?xml version="1.0"?><dilemmalogdump\nxmlns:dilemmalogdump="$gSkin->{absolutedir}/dilemmalogdump.dtd">\n};

	# Figure out which filename we're writing to, and open it up.
	my $filename = catfile($constants->{basedir}, "dilemmalogdump.xml.gz");
	my $gz = do_ldd_gz_init($filename) or return " no xml file, gz init failed";

	# Do the SELECTs to get the data we need.  That last one, which is
	# by far the huge chunk of the data, is an SQL statement handle;
	# we'll be going through it piece by piece and writing compressed
	# XML as we go.
	my $ldd_hr = $dilemma_reader->getLogDataDump($trid);
	my $species_info_hr = $ldd_hr->{species_info};
	my $agents_info_hr = $ldd_hr->{agents_info};
	my $meetlog_sth = $ldd_hr->{meetlog_sth};
	my $playlog_sth = $ldd_hr->{playlog_sth};

	# Insert the species info into the XML...
	for my $dsid (sort { $a <=> $b } keys %$species_info_hr) {
		$xml .= "<species>";
		$xml .= "<dsid>$dsid</dsid>";
		$xml .= "<name>" . xmlencode($species_info_hr->{$dsid}{name}) . "</name>";
		$xml .= "<code>" . xmlencode($species_info_hr->{$dsid}{code}) . "</code>";
		$xml .= "</species>\n";
	}

	# Insert the agent info into the XML...
	for my $daid (sort { $a <=> $b } keys %$agents_info_hr) {
		$xml .= "<agent>";
		$xml .= "<daid>$daid</daid>";
		$xml .= "<dsid>$agents_info_hr->{$daid}{dsid}</dsid>";
		$xml .= "<born>$agents_info_hr->{$daid}{born}</born>";
		$xml .= "</agent>\n";
	}

	# Insert the meeting log into the XML, one entry at a time.
	my $start_dump = Time::HiRes::time;
	my $playlog_hr = { };
	my $i = 0;
	while (my($meetlog_meetid, $trid, $tick, $foodsize) = $meetlog_sth->fetchrow()) {
		# Pull rows from the play log into its hashref until
		# we find one with a meetid higher than the meetid
		# we just read.
		if ($playlog_sth) {
			while (1) {
				my($playlog_meetid, $daid,
					$playtry, $playactual,
					$reward, $sawdaid) =
					$playlog_sth->fetchrow();
				if (!$daid) {
					# End of the play log.
					$playlog_sth->finish();
					undef $playlog_sth;
					last;
				}
				$playlog_hr->{$playlog_meetid}{$daid}{playtry} = $playtry;
				$playlog_hr->{$playlog_meetid}{$daid}{playactual} = $playactual;
				$playlog_hr->{$playlog_meetid}{$daid}{reward} = $reward;
				$playlog_hr->{$playlog_meetid}{$daid}{sawdaid} = $sawdaid;
				last if $playlog_meetid > $meetlog_meetid;
			}
		}
		$xml .= "<meeting>";
		$xml .= "<meetid>$meetlog_meetid</meetid>";
		$xml .= "<tick>$tick</tick>";
		$xml .= "<foodsize>$foodsize</foodsize>";
		if ($playlog_hr->{$meetlog_meetid} && %{$playlog_hr->{$meetlog_meetid}}) {
			my @daids = sort { $a <=> $b } keys %{$playlog_hr->{$meetlog_meetid}};
			for my $daid (@daids) {
				$xml .= "<agentplay>";
				$xml .= "<daid>$daid</daid>";
				$xml .= "<playtry>$playlog_hr->{$meetlog_meetid}{$daid}{playtry}</playtry>";
				$xml .= "<playactual>$playlog_hr->{$meetlog_meetid}{$daid}{playactual}</playactual>";
				$xml .= "<reward>$playlog_hr->{$meetlog_meetid}{$daid}{reward}</reward>";
				$xml .= "<sawdaid>$playlog_hr->{$meetlog_meetid}{$daid}{sawdaid}</sawdaid>";
				$xml .= "</agentplay>";
			}
			# Recycle the RAM for each meeting, since there may
			# be millions of 'em.
			delete $playlog_hr->{$meetlog_meetid};
		}
		$xml .= "</meeting>\n";
		# Dump the xml to disk, if it's gotten big enough
		if (length($xml) > 1024*1024) {
			do_ldd_gz_dump($gz, $xml);
			$uncompbytes += length($xml);
			$xml = "";
		}
		if (++$i >= 1000) {
			cpu_sleep($start_dump, $wait_factor);
			$start_dump = Time::HiRes::time;
			$i = 0;
		}
	}
	$meetlog_sth->finish();
	$xml .= "</dilemmalogdump>\n";
	do_ldd_gz_finish($gz, $xml);
	$uncompbytes += length($xml);
	$compbytes = -s $filename;
	return " wrote xml file $compbytes/$uncompbytes bytes";
}

sub do_ldd_gz_init {
	my($filename) = @_;
	binmode STDOUT;
	my $retval = Compress::Zlib::gzopen($filename, "wb");
	if (!$retval) {
		slashdLog("cannot open gz output stream to '$filename': $Compress::Zlib::gzerrno");
	}
	return $retval;
}

sub do_ldd_gz_dump {
	my($gz, $data) = @_;
	$gz->gzwrite($data);
}

sub do_ldd_gz_finish {
	my($gz, $data) = @_;
	my $bytes = do_ldd_gz_dump($gz, $data);
	$gz->gzclose();
	return $bytes;
}

1;

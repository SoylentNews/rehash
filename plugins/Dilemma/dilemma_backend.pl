#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use Slash::Constants ':slashd';

use strict;

use Compress::Zlib;

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
			my $meeting_hr = {
				daids =>	$players,
				foodsize =>	$food_per_interaction,
			};
			$dilemma_db->agentsMeet($meeting_hr, $dilemma_info);
		}
		my $still_running = $dilemma_db->doTickHousekeeping();
		last unless $still_running;
	}

	# Allow the reader to catch up.
	sleep 2;

	$dilemma_info = $dilemma_reader->getDilemmaInfo();

	my $legend_ar = [ ];
	my $alldata_ar = [ ];
	my $last_tick = $dilemma_info->{last_tick};
	# Y axis: data serieses: the agent counts of each species...
	my $y_max = 0;
	my $species = $dilemma_reader->getSpecieses();
	my @dsids = sort { $a <=> $b } keys %$species;
	for my $dsid (@dsids) {
		push @$alldata_ar, $dilemma_reader->getStatsBySpecies($dsid);
		for my $n (@{$alldata_ar->[$#$alldata_ar]}) {
			$y_max = $n if $n > $y_max;
		}
		push @$legend_ar, $species->{$dsid}{name};
	}
	$y_max = int($y_max/10+1)*10;
	# Y axis: prefix the agent counts with the average play
	unshift @$alldata_ar, $dilemma_reader->getAveragePlay({ max => $y_max });
	unshift @$legend_ar, "avgplay";
	# X axis: ticks
	unshift @$alldata_ar, [ 1 .. $last_tick ];
	# Display the data
	my $png = slashDisplay('graph', {
		last_tick	=> $last_tick,
		alldata		=> $alldata_ar,
		y_max		=> $y_max,
		set_legend	=> \&_set_legend,
		legend		=> $legend_ar,
	}, { Return => 1, Nocomm => 1, Page => 'dilemma' });
	my $filename = catfile($constants->{basedir}, "images/specieshistory.png");
	save2file($filename, $png);

	my $agent_count = $dilemma_reader->countAliveAgents();
	my $return_str = "alive: $dilemma_info->{alive} tick: $last_tick/$dilemma_info->{max_runtime} agents: $agent_count";

	# Every so often, or if we've just finished, then we dump it
	# into compressed XML.
	if ($constants->{dilemma_logdatadump}
		&& ( $dilemma_info->{alive} ne 'yes' || $info->{invocation_num} % 10 == 1 )
	) {
		$return_str .= do_logdatadump(
			$virtual_user, $constants, $slashdb, $user, $info, $gSkin,
			$dilemma_reader);
	}

	return $return_str;
};

# helper method for graph(), because GD->set_legend doesn't
# take a reference, and TT can only pass a reference -- pudge
sub _set_legend {
	my($gd, $legend) = @_;
	$gd->set_legend(@$legend);
}

sub do_logdatadump {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin, $dilemma_reader) = @_;

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
	my $ldd_hr = $dilemma_reader->getLogDataDump();
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
	my $playlog_hr = { };
	while (my($meetlog_meetid, $tick, $foodsize) = $meetlog_sth->fetchrow()) {
		# Pull rows from the play log into its hashref until
		# we find one with a meetid higher than the meetid
		# we just read.
		if ($playlog_sth) {
			while (1) {
				my($playlog_meetid, $daid, $play, $reward) =
					$playlog_sth->fetchrow();
				if (!$daid) {
					# End of the play log.
					$playlog_sth->finish();
					undef $playlog_sth;
					last;
				}
				$playlog_hr->{$playlog_meetid}{$daid}{play} = $play;
				$playlog_hr->{$playlog_meetid}{$daid}{reward} = $reward;
				last if $playlog_meetid > $meetlog_meetid;
			}
		}
		$xml .= "<meeting>";
		$xml .= "<meetid>$meetlog_meetid</meetid>";
		$xml .= "<tick>$tick</tick>";
		$xml .= "<foodsize>$foodsize</foodsize>";
		if ($playlog_hr->{$meetlog_meetid} && %{$playlog_hr->{$meetlog_meetid}}) {
			$xml .= "<agentplay>";
			my @daids = sort { $a <=> $b } keys %{$playlog_hr->{$meetlog_meetid}};
			for my $daid (@daids) {
				$xml .= "<daid>$daid</daid>";
				$xml .= "<play>$playlog_hr->{$meetlog_meetid}{$daid}{play}</play>";
				$xml .= "<reward>$playlog_hr->{$meetlog_meetid}{$daid}{reward}</reward>";
			}
			$xml .= "</agentplay>";
			# Recycle the RAM for each meeting, since there may
			# be millions of 'em.
			delete $playlog_hr->{$meetlog_meetid};
		}
		$xml .= "</meeting>\n";
		# Dump the xml to disk, if it's gotten big enough
		if (length($xml) > 16384) {
			my $new_cb = do_ldd_gz_dump($gz, $xml);
			$compbytes += $new_cb;
			$uncompbytes += length($xml);
			$xml = "";
		}
	}
	$meetlog_sth->finish();
	$xml .= "</dilemmalogdump>\n";
	my $new_cb = do_ldd_gz_finish($gz, $xml);
	$compbytes += $new_cb;
	$uncompbytes += length($xml);
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

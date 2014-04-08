#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use Slash::Constants ':slashd';

use strict;
use Time::HiRes;

use vars qw( %task $me );

$task{$me}{timespec} = '0-59 * * * *';
$task{$me}{timespec_panic_1} = '';
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;

	return "" if !$constants->{dbsparklines_disp};

	my @vus = $slashdb->getDBVUsForType("reader");
	my $secsback = $constants->{dbsparklines_secsback} || 30*60;

	for my $vu (@vus) {
		my $dbid = get_reader_dbid($slashdb, $vu);
		my $now = $slashdb->getTime();

		my $resolution = $secsback / $constants->{dbsparklines_width};
		my $bog_ar = $slashdb->getSparklineData($dbid, "query_bog_secs", $now,
			$resolution, $secsback,     $constants->{dbsparklines_ymax} ,  1);
		my $lag_ar = $slashdb->getSparklineData($dbid, "slave_lag_secs", $now,
			$resolution, $secsback, abs($constants->{dbsparklines_ymin}), -1);

		# The "inverted" versions of bog_ar and lag_ar are
		# this:  wherever the original is defined, the
		# ground is undef;  where the original is undef, the
		# ground is the maximum value (positive for bog,
		# negative for lag).
		my $bog_ground_ar = invert_ar($bog_ar, $constants->{dbsparklines_ymax});
		my $lag_ground_ar = invert_ar($lag_ar, $constants->{dbsparklines_ymin});

slashdLog("bog_ar=$#$bog_ar lag_ar=$#$lag_ar bog_ground_ar=$#$bog_ground_ar lag_ground_ar=$#$lag_ground_ar");
my $bar = "bar:"; for (@$bog_ar) { $bar .= " " . (defined($_) ? sprintf("%.2f", $_) : "U") }
slashdLog($bar);
my $lar = "lar:"; for (@$lag_ar) { $lar .= " " . (defined($_) ? sprintf("%.2f", $_) : "U") }
slashdLog($lar);
my $bgar = "bgar:"; for (@$bog_ground_ar) { $bgar .= " " . (defined($_) ? sprintf("%.2f", $_) : "U") }
slashdLog($bgar); # 2nd
my $lgar = "lgar:"; for (@$lag_ground_ar) { $lgar .= " " . (defined($_) ? sprintf("%.2f", $_) : "U") }
slashdLog($lgar); # 3rd

		my $png = slashDisplay('dbsparkline',
			{ alldata => [ $bog_ar, $lag_ar, $bog_ground_ar, $lag_ground_ar ] },
			{ Return => 1, Nocomm => 1 });

slashdLog("vu=$vu length(png)=" . length($png) . " size(bog_ar)=" . scalar(@$bog_ar) . " size(lag_ar)=" . scalar(@$lag_ar));
		my $dir = catdir($constants->{basedir}, "images/dbsparklines");
		mkpath($dir, 0, 0775) unless -e $dir;
		my $filename = catfile($dir,
			"${vu}_$constants->{dbsparklines_pngsuffix}.png");
slashdLog("filename='$filename'");
		save2file($filename, $png);
	}
};

# This should be in Static/MySQL.pm
{ # cheap closure cache
my $reader_dbid;
sub get_reader_dbid {
	my($slashdb, $vu) = @_;
	if (!$reader_dbid) {
		$reader_dbid = $slashdb->sqlSelectAllKeyValue(
			"virtual_user, id",
			"dbs",
			"type='reader'");
	}
	return $reader_dbid->{$vu};
}
} # end closure

sub invert_ar {
	my($ar, $subst) = @_;
	my @inverted = (
		map { defined($_) ? undef : $subst } @$ar
	);
	return \@inverted;
}

1;


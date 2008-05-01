#!/usr/bin/perl -w
#
# $Id$
#
# Slashd Task (c) OSTG 2004-2007

use strict;

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

use Time::HiRes;
use Slash::Display;
use Slash::Constants ':slashd';

use vars qw( %task $me $tags_peerclout
	$globj_types $clout_types $clout_info
	$nodid $nixid $nodc $nixc
	$A_months_back $B_months_back
	$debug $debug_uids );

$task{$me}{timespec} = '49 5 * * *';
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	return '' unless $constants->{plugin}{Tags};

	my $tagsdb = getObject('Slash::Tags');
	$nodid = $tagsdb->getTagnameidCreate($constants->{tags_upvote_tagname}   || 'nod');
	$nixid = $tagsdb->getTagnameidCreate($constants->{tags_downvote_tagname} || 'nix');

	$globj_types = $slashdb->getGlobjTypes();
	$clout_types = $slashdb->getCloutTypes();
	$clout_info  = $slashdb->getCloutInfo();
	my $total_inserts = 0;

	for my $clid (sort { $a <=> $b } grep { /^\d+$/ } keys %$clout_types) {
		my $class = $clout_info->{$clid}{class};
		my $clout = getObject($class);
		next unless $clout;
		sleep 5;
		$tags_peerclout = $slashdb->sqlSelectAllKeyValue(
			'uid, clout',
			'tags_peerclout',
			"clid=$clid AND gen = 0");
		if ($tags_peerclout && %$tags_peerclout) {
			$slashdb->sqlDelete('tags_peerclout', "gen > 0 AND clid=$clid");
			sleep 5; # wait for that to replicate
			my $g = 0;
			while (1) {
				my $lastgen_count = $slashdb->sqlCount('tags_peerclout',
					"clid=$clid AND gen=$g");
				slashdLog("gen $g for $clout_types->{$clid}: $lastgen_count");
				last unless $lastgen_count;
				my $hr_ar = $clout->get_nextgen($g);
				slashdLog("$class gen $g produces " . scalar(defined($hr_ar) ? @$hr_ar : 0) . " rows");
				my $insert_ar = $clout->process_nextgen($hr_ar, $tags_peerclout);
				slashdLog("$class gen $g insert_ar count: " . scalar(@$insert_ar));
				$total_inserts += scalar(@$insert_ar);
				++$g;
				my $total_rows = insert_nextgen($tags_peerclout, $clid, $g, $insert_ar);
				slashdLog("$class inserted $total_rows rows");
				sleep 5;
			}
			$clout->copy_peerclout_sql();
		}

	}

	return "$total_inserts inserts";
};

sub insert_nextgen {
	my($tags_peerclout, $clid, $gen, $insert_ar) = @_;
	my $slashdb = getCurrentDB();
	my $rows = 0;
	for my $hr (@$insert_ar) {
                ($hr->{clid}, $hr->{gen}) = ($clid, $gen);
if (!$rows) { use Data::Dumper; my $hd = Dumper($hr); $hd =~ s/\s+/ /g; slashdLog("insert hr: $hd"); }
                $rows += $slashdb->sqlInsert('tags_peerclout', $hr);
                $tags_peerclout->{ $hr->{uid} } = $hr->{clout};
        }
	return $rows;
}

1;


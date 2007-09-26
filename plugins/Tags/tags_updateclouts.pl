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

	for my $clid (sort { $a <=> $b } grep { /^\d+$/ } keys %$clout_types) {
		my $class = $clout_info->{$clid}{class};
		sleep 5;
		$tags_peerclout = $slashdb->sqlSelectAllKeyValue(
			'uid, clout',
			'tags_peerclout',
			"clid=$clid AND gen = 0");
		if ($tags_peerclout && %$tags_peerclout) {
			$slashdb->sqlDelete('tags_peerclout', 'gen > 0');
			sleep 5; # wait for that to replicate
			my $g = 0;
			while (1) {
				my $lastgen_count = $slashdb->sqlCount('tags_peerclout',
					"clid=$clid AND gen=$g");
				last unless $lastgen_count;
				my $hr_ar = $class->get_nextgen($g);
				slashdLog("$class gen $g produces " . scalar(@$hr_ar) . " rows");
				my $insert_ar = $class->process_nextgen($hr_ar);
				++$g;
				for my $hr (@$insert_ar) { $hr->{clid} = $clid }
				$class->insert_nextgen($g, $insert_ar);
				$class->update_tags_peerclout($insert_ar);
				sleep 5;
			}
			$class->copy_peerclout_sql();
		}

	}
};

1;


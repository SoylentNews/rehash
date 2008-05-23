#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;

use Slash::Constants ':slashd';

use vars qw( %task $me );

$task{$me}{timespec} = '* * * * *';
$task{$me}{timespec_panic_1} = ''; # if panic, this can wait
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtualuser, $constants, $slashdb, $user) = @_;

	my $searchtoo = getObject('Slash::SearchToo');

	my $backup_start_time = time;
	slashdLog("Backing up index");
	$searchtoo->copyBackup;
	$searchtoo->backup(1);
	my $backup_duration = time - $backup_start_time;
	if ($backup_duration > 60) {
		slashdErrnote("backup process took $backup_duration seconds; file cleanup may be required");
	}

	slashdLog("Fetching records to index");
	my $records = $searchtoo->getStoredRecords;

	my %seen;
	for my $type (sort { $a->{iid} <=> $b->{iid} } keys %$records) {
		my $records_type = $records->{$type};

		my(@iids_d, @delete, @iids_a, @add, @change, %add);
		slashdLog(sprintf( "Starting %d '$type' records", scalar @$records_type ));

		my $max = $#{$records_type};
		$max = 999 if $max > 999;
		for my $i (0 .. $max) {
			if ($records_type->[$i]{status} eq 'deleted') {
				push @delete, $records_type->[$i]{id};
				push @iids_d, $records_type->[$i]{iid};
			} else {
				next if $seen{$records_type->[$i]{id}};
				if ($records_type->[$i]{status} eq 'new') {
					$add{$records_type->[$i]{id}} = 1;
				}
				push @add, {
					id	=> $records_type->[$i]{id},
					status	=> $records_type->[$i]{status}
				};
				push @iids_a, $records_type->[$i]{iid};
				$seen{$records_type->[$i]{id}}++;
			}
		}

		for my $i (reverse(0 .. $#delete)) {
			if ($add{ $delete[$i] }) {
				splice(@delete, $i, 1);
				splice(@iids_d, $i, 1);
			}
		}

		for my $i (reverse(0 .. $#add)) {
			my $id = $add[$i]{id};
			if ($add[$i]{status} eq 'changed' && $add{ $add[$i]{id} }) {
				splice(@add,    $i, 1);
				splice(@iids_a, $i, 1);
			}
		}

		slashdLog(sprintf( "Fetching %d '$type' records", scalar @add ));
		$searchtoo->getRecords($type => \@add);

		my($deleted, $added) = (0, 0);

		slashdLog(sprintf( "Indexing %d '$type' records", scalar @add ));
		if (@add) {
			$added = $searchtoo->addRecords($type => \@add) || 0;
		}

		slashdLog(sprintf( "Deleting %d '$type' records", scalar @delete ));
		if (@delete) {
			$deleted = $searchtoo->deleteRecords($type => \@delete) || 0;
		}

		if (@iids_a && @iids_a != $added) {
			slashdLog(sprintf(
				"Warning, expected to index %d, indexed %d",
				scalar(@iids_a), $added
			));
		} else {
			$searchtoo->deleteStoredRecords(\@iids_a);
		}

		if (@iids_d && @iids_d != $deleted) {
			slashdLog(sprintf(
				"Warning, expected to delete %d, deleted %d",
				scalar(@iids_d), $deleted
			));
		} else {
			$searchtoo->deleteStoredRecords(\@iids_d);
		}

		$searchtoo->finish;
	}

	$searchtoo->backup(0);
	$searchtoo->moveLive;

	slashdLog("Moved new index live");
	slashdLog("Finished");
};

1;


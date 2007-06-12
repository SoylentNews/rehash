#!/usr/local/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

use Slash;
use Time::HiRes;
use Slash::Constants ':slashd';

use strict;

use vars qw( %task $me $task_exit_flag );

my $min_incr = 5;
my $max_mins = 60 * 12;
my $userpopname = 'FHPopularity2';

$task{$me}{timespec} = "50 * * * *";
$task{$me}{timespec_panic_1} = '';
$task{$me}{timespec_panic_2} = '';
$task{$me}{on_startup} = 1;
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
        my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;

	my $max_globjids = 500;
	my $quit_time = time + 20*60;
	my $max_min_incrs = int($max_mins/$min_incr)+1;
	my $utb = getObject("Slash::Tagbox::$userpopname") || return "cannot instantiate $userpopname";
	my $etb = getObject("Slash::Tagbox::FHEditorPop") || return "cannot instantiate FHEditorPop";
	my $tagsdb = getObject('Slash::Tags');
	my $tagdv = getObject('Slash::TagDataView');

	my $globjid_ar = $tagdv->getGlobjidsMissingHistory($max_mins, $max_min_incrs, $max_globjids);

	my $num_processed = 0;
	while (@$globjid_ar && !$task_exit_flag && time < $quit_time) {
		my $globjid = shift @$globjid_ar;
#		my $gtid = $slashdb->sqlSelect('gtid', 'globjs', "globjid=$globjid");
		my $createtime = $slashdb->sqlSelect('createtime', 'firehose',
			"globjid=$globjid");
		my $secs_hr = $slashdb->sqlSelectAllKeyValue(
			'secsin, 1',
			'firehose_history',
			"globjid=$globjid");
		my $min = 0;
		while ($min <= $max_mins && !$task_exit_flag && time < $quit_time) {
			my $sec = $min*60;
			if (!exists $secs_hr->{$sec}) {
				my $add_secs = $sec;
				# Special case: to make sure we catch the
				# first 'nod' given to some firehose
				# entries, its initial value includes any
				# tags added within the first 3 seconds.
				$add_secs = 3 if $add_secs < 3;
				my $mtnq = "DATE_ADD('$createtime', INTERVAL $add_secs SECOND)";
				my $upop = $utb->run($globjid, {
					return_only => 1,
					max_time_noquote => $mtnq,
				});
				my $epop = $etb->run($globjid, {
					return_only => 1,
					max_time_noquote => $mtnq,
				});
				$num_processed++ if $slashdb->sqlReplace('firehose_history', {
					globjid =>	$globjid,
					secsin =>	$sec,
#					gtid =>		$gtid,
					userpop =>	$upop,
					editorpop =>	$epop,
				});
			}
			Time::HiRes::sleep(0.05);
			$min += $min_incr;
		}
		Time::HiRes::sleep(0.2);
	}

	return "$num_processed processed";
};

1;


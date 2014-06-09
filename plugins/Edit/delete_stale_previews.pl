#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2009 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

use strict;
use utf8;

use Slash;
use Slash::Constants ':slashd';
use Slash::Utility;

use vars qw(%task $me $task_exit_flag);

$task{$me}{timespec} = '0 3 * * *';
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
        my($virtual_user, $constants, $slashdb, $user) = @_;

        my $tagsdb = getObject("Slash::Tags");

        my $previews = $slashdb->sqlSelectAllHashrefArray(
                'preview_id, preview_fhid',
                'preview',
                'createtime < DATE_SUB(NOW(), INTERVAL 24 HOUR)'
        );

        foreach my $preview (@$previews) {
                my ($fh_id, $globjid) = $slashdb->sqlSelect(
                        'id, globjid',
                        'firehose',
                        'id = ' . $preview->{preview_fhid} . " AND preview = 'yes'"
                );

                if ($fh_id && $globjid) {
                        $slashdb->sqlDo('START TRANSACTION');

			# preview
			$slashdb->sqlDelete('preview', "preview_id = " . $preview->{preview_id});

			# preview_param
			$slashdb->sqlDelete('preview_param', "preview_id = " . $preview->{preview_id});

			# firehose
			$slashdb->sqlDelete('firehose', "id = " . $fh_id . " and preview = 'yes'");

			# firehose_text
			$slashdb->sqlDelete('firehose_text', "id = " . $fh_id);

			$slashdb->sqlDo('COMMIT');

			# tags
			$tagsdb->deactivateAllTagsByGlobjid($globjid);
		}
	}
};

1;

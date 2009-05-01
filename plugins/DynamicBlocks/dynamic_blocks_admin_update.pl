#!/usr/local/bin/perl -w

# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2009 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

use strict;

use Slash;
use Slash::Constants ':slashd';
use Slash::Utility;

use vars qw(%task $me $task_exit_flag);

$task{$me}{timespec} = '0-59 * * * *';
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
        my($virtual_user, $constants, $slashdb, $user) = @_;

        my $dynamic_blocks_db = getObject('Slash::DynamicBlocks');
        return 'DynamicBlocks DB unset, aborting' unless $dynamic_blocks_db;

        my $admin_db = getObject('Slash::Admin');
        return 'Admin DB unset, aborting' unless $admin_db;

	# public admin
	my $admin_public_blocks_def = $dynamic_blocks_db->getBlockDefinition('', { type => 'admin', private => 'no'} );
        my $block_names = '';
        $block_names = $slashdb->sqlSelectColArrayref('name', 'dynamic_user_blocks', 'type_id = ' . $admin_public_blocks_def->{type_id});
        my $block = '';
	my $title = '';
        foreach my $name (@$block_names) {
		if ($name eq 'performancebox') {
                        $block = $admin_db->showPerformanceBox({ contents_only => 1});
                        $title = 'Performance';
                }

                if ($name eq 'authoractivity') {
                        $block = $admin_db->showAuthorActivityBox({ contents_only => 1});
                        $title = 'Author Activity';
                }

                if ($name eq 'admintodo') {
                        ($block) = $admin_db->showAdminTodo() =~ m{(<b><a href.+<hr>)};
                        $title = 'Admin Todo';
                }

                if (($name eq 'recenttagnames') && (my $tagsdb = getObject('Slash::Tags'))) {
                        $block = $tagsdb->showRecentTagnamesBox({ contents_only => 1 });
                        $title = 'Recent Tags';
                }

                if (($name eq 'firehoseusage') && (my $fh_db = getObject('Slash::FireHose'))) {
                        $block = $fh_db->ajaxFireHoseUsage();
                        $title = 'Firehose Usage';
                }

                my $old_block_content =
                        $slashdb->sqlSelect(
                                'block',
                                'dynamic_user_blocks',
                                'type_id = ' . $admin_public_blocks_def->{type_id} .
                                " and name = '$name'"
                        );

                $dynamic_blocks_db->setBlock( { block => $block, name => $name, title => $title } ) if ($old_block_content ne $block);
        }

	# private admin
	my $admin_private_blocks_def = $dynamic_blocks_db->getBlockDefinition('', { type => 'admin', private => 'yes'} );
        $block_names = '';
        $block_names = $slashdb->sqlSelectColArrayref('name', 'dynamic_user_blocks', 'type_id = ' . $admin_private_blocks_def->{type_id});
        foreach my $name (@$block_names) {
                my ($block_name, $uid) = split('-', $name);

                my $block = $admin_db->showStoryAdminBox("", { contents_only => 1, uid => $uid});
                my $old_block_content =
                        $slashdb->sqlSelect(
                                'block',
                                'dynamic_user_blocks',
                                'type_id = ' . $admin_private_blocks_def->{type_id} .
                                " and name = '$name'" .
                                " and uid = $uid"
                        );

                $dynamic_blocks_db->setBlock( { block => $block, name => $name, title => 'Story Admin' } ) if ($old_block_content ne $block);
        }

        return;
};

1;

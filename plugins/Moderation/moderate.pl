#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

# This script is not all that useful since moderation is largely
# done by ajax now.  Users with browsers that don't support it
# should be the only ones who submit the form that triggers
# moderate.pl.

use strict;
use Slash;
use Slash::Constants qw(:messages :strip);
use Slash::Display;
use Slash::Utility;

#################################################################
sub main {
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $op = getCurrentForm('op') || '';

	header(getData('header')) or return;

#	if (!$constants->{m1}) {
#		print getData('no_moderation');
#	} else {
#		my $mod_db = getObject("Slash::$constants->{m1_pluginname}");
#		if (!$mod_db->metamodEligible($user)) {
#			print getData('not-eligible');
#		} elsif ($op eq 'MetaModerate') {
#			$mod_db->metaModerate();
#			print getData('thanks');
#		} else {
#			displayTheComments();
#		}
#	}

	writeLog($op);
	footer();
}

##################################################################
sub moderate {
        my($form, $slashdb, $user, $constants, $discussion) = @_;
	my $moddb = getObject("Slash::$constants->{m1_pluginname}");

        my $moderate_check = $moddb->moderateCheck($form, $user, $constants, $discussion);
        if (!$moderate_check->{count} && $moderate_check->{msg}) {
                print $moderate_check->{msg} if $moderate_check->{msg};
                return;
        }

        if ($form->{meta_mod_only}) {
                print metamod_if_necessary();
                return;
        }

        my $hasPosted = $moderate_check->{count};

        titlebar("100%", getData('moderating'));
        slashDisplay('mod_header');

        my $sid = $form->{sid};
        my $was_touched = 0;
        my $meta_mods_performed = 0;
        my $total_deleted = 0;

        # Handle Deletions, Points & Reparenting
        # It would be nice to sort these by current score of the comments
        # ascending, maybe also by val ascending, or some way to try to
        # get the single-point-spends first and then to only do the
        # multiple-point-spends if the user still has points.
        my $can_del = ($constants->{authors_unlimited} && $user->{seclev} >= $constants->{authors_unlimited})
                || $user->{acl}{candelcomments_always};
        for my $key (sort keys %{$form}) {
                if ($can_del && $key =~ /^del_(\d+)$/) {
                        $total_deleted += deleteThread($sid, $1);
                } elsif (!$hasPosted && $key =~ /^reason_(\d+)$/) {
                        my $cid = $1;
                        my $ret_val = $moddb->moderateComment($sid, $cid, $form->{$key});
                        # If an error was returned, tell the user what
                        # went wrong.
                        if ($ret_val < 0) {
                                if ($ret_val == -1) {
                                        print getError('no points');
                                } elsif ($ret_val == -2){
                                        print getError('not enough points');
                                }
                        } else {
                                $was_touched += $ret_val;
                        }
                }
        }
        $slashdb->setDiscussionDelCount($sid, $total_deleted);
        $was_touched = 1 if $total_deleted;
        
        print metamod_if_necessary();
        
        slashDisplay('mod_footer', {
                metamod_elig => metamod_elig($user),
        });
        
        if ($hasPosted && !$total_deleted) {
                print $moderate_check->{msg};
        } elsif ($user->{seclev} && $total_deleted) {
                slashDisplay('del_message', {
                        total_deleted   => $total_deleted,
                        comment_count   => $slashdb->countCommentsBySid($sid),
                });
        }
        
        printComments($discussion, $form->{pid}, $form->{cid},
                { force_read_from_master => 1 } );
        
        if ($was_touched) {
                # This is for stories. If a sid is only a number
                # then it belongs to discussions, if it has characters
                # in it then it belongs to stories and we should
                # update to help with stories/hitparade.
                # -Brian
                if ($discussion->{sid}) {
                        $slashdb->setStory($discussion->{sid}, { writestatus => 'dirty' });
                }
        }
}

sub metamod_elig {
        my($user) = @_;
        my $constants = getCurrentStatic();
        if ($constants->{m2}) {
                my $metamod_db = getObject('Slash::Metamod');
                return $metamod_db->metamodEligible($user);
        }
        return 0;
}

sub metamod_if_necessary {
        my $constants = getCurrentStatic();
        my $user = getCurrentUser();
        my $retstr = '';
        if ($constants->{m2} && $user->{is_admin}) {
                my $metamod_db = getObject('Slash::Metamod');
                my $n_perf = 0;
                if ($n_perf = $metamod_db->metaModerate($user->{is_admin})) {
                        $retstr = getData('metamods_performed', { num => $n_perf });
                }
        }
        return $retstr;
}

#################################################################
createEnvironment();
main();

1;


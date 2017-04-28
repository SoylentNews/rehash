#!/usr/bin/perl
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

use strict;
use utf8;
use warnings;

use Data::JavaScript::Anon;

use Slash 2.003;	# require Slash 2.3.x
use Slash::Display;
use Slash::Utility;

##################################################################
sub main {
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();
	my $gSkin     = getCurrentSkin();

	my $ops = getOps();
	my $op = $form->{op} || '';
#	print STDERR "AJAX1 $$: $user->{uid}, $op\n";

	if (!$ops->{$op}) {
		errorLog("No Ajax op '$op' found");
		$op = 'default';
	}

#	print STDERR "AJAX2 $$: $user->{uid}, $op\n";

	$op = 'default' unless $ops->{$op}{function} || (
		$ops->{$op}{class} && $ops->{$op}{subroutine}
	);
#	print STDERR "AJAX3 $$: $user->{uid}, $op\n";

	$ops->{$op}{function} ||= loadCoderef($ops->{$op}{class}, $ops->{$op}{subroutine});
	$op = 'default' unless $ops->{$op}{function};

#	print STDERR "AJAX4 $$: $user->{uid}, $op\n";

	$form->{op} = $op;  # save for others to use

	my $reskey_name = $ops->{$op}{reskey_name} || 'ajax_base';
	$ops->{$op}{reskey_type} ||= 'use';

#	print STDERR "AJAX5 $$: $user->{uid}, $op\n";

	my $options = {};

	if ($reskey_name ne 'NA') {
		my $reskey = getObject('Slash::ResKey');
		my $rkey = $reskey->key($reskey_name); #, { debug => 1 });
		if (!$rkey) {
			print STDERR scalar(localtime) . " ajax.pl main no rkey for op='$op' name='$reskey_name'\n";
			return;
		}
		$options->{rkey} = $rkey;
		if ($ops->{$op}{reskey_type} eq 'createuse') {
			$rkey->createuse;
		} elsif ($ops->{$op}{reskey_type} eq 'touch') {
			$rkey->touch;
		} else  {
			$rkey->use;
		}
		if (!$rkey->success) {
			# feel free to send msgdiv => 'thisdivhere' to the ajax call,
			# and any reskey error messages will be sent to it
			if ($form->{msgdiv}) {
				http_send({ content_type => 'application/json' });
				(my $msgdiv = $form->{msgdiv}) =~ s/[^\w-]+//g;
				print Data::JavaScript::Anon->anon_dump({
					html	  => { $msgdiv => $rkey->errstr },
					eval_last => "\$('#$msgdiv').show()"
				});
			}
			$rkey->ERROR($op);
			return;
		}
	}
#	print STDERR "AJAX6 $$: $user->{uid}, $op\n";

	my $retval = $ops->{$op}{function}->(
		$slashdb, $constants, $user, $form, $options
	);

#	my $litval = strip_literal($retval); print STDERR "AJAX7 $$: $user->{uid}, $op ($litval)\n";

	http_send($options);
	if ($retval && length $retval) {
		print $retval;
	}

	# XXX: do anything on error?  a standard error dialog?  or fail silently?
}

##################################################################
sub getSectionPrefsHTML {
	my($slashdb, $constants, $user, $form) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	my %story023_default = (
		author	=> { },
		nexus	=> { },
		topic	=> { },
	);

	my %prefs = ( );

	for my $field (qw(
		story_never_nexus 	story_always_nexus	story_brief_always_nexus
		story_full_brief_nexus	story_full_best_nexus	story_brief_best_nexus
	)) {
		for my $id (
			grep /^\d+$/,
			split /,/,
			($user->{$field} || "")
		) {
			$prefs{$field}{$id} = 1;
		}
	}

	my $topic_tree = $reader->getTopicTree();
	my $nexus_tids_ar = $reader->getMainpageDisplayableNexuses();
	my $nexus_hr = { };
	my $skins = $reader->getSkins();

	my $hide_nexus;
	foreach(keys %$skins) {
		$hide_nexus->{$skins->{$_}->{nexus}} = 1 if $skins->{$_}{skinindex} eq "no";
	}

	for my $tid (@$nexus_tids_ar) {
		$nexus_hr->{$tid} = $topic_tree->{$tid}{textname} if !$hide_nexus->{$tid};
	}
	my @nexustid_order = sort {
		($b == $constants->{mainpage_nexus_tid}) <=> ($a == $constants->{mainpage_nexus_tid})
		||
		lc $nexus_hr->{$a} cmp lc $nexus_hr->{$b}
	} keys %$nexus_hr;

	my $first_val = "";
	my $multiple_values = 0;
	for my $tid (@nexustid_order) {
		if ($prefs{story_never_nexus}{$tid}) {
			$story023_default{nexus}{$tid} = 0;
		} elsif ($prefs{story_always_nexus}{$tid}) {
			$story023_default{nexus}{$tid} = 5;
		} elsif ($prefs{story_full_brief_nexus}{$tid}) {
			$story023_default{nexus}{$tid} = 4;
		} elsif ($prefs{story_brief_always_nexus}{$tid}) {
			$story023_default{nexus}{$tid} = 3;
		} elsif ($prefs{story_full_best_nexus}{$tid}) {
			$story023_default{nexus}{$tid} = 2;
		} elsif ($prefs{story_brief_best_nexus}) {
			$story023_default{nexus}{$tid} = 1;
		} else {
			if ($constants->{brief_sectional_mainpage}) {
				$story023_default{nexus}{$tid} = 4;
			} else {
				$story023_default{nexus}{$tid} = 2;
			}
		}
		$first_val = $story023_default{nexus}{$tid} if $first_val eq "";
		$multiple_values = 1 if $story023_default{nexus}{$tid} != $first_val;
	}

	my $master_value = !$multiple_values ? $first_val : "";

	return slashDisplay("prefs_sectional",
		{
			nexusref		=> $nexus_hr,
			nexustid_order		=> \@nexustid_order,
			story023_default	=> \%story023_default,
			multiple_values		=> $multiple_values,
			master_value		=> $master_value,
                        tabbed                  => $form->{'tabbed'},
		},
		{ Return => 1 }
	);
}

sub setSectionNexusPrefs {
	my($slashdb, $constants, $user, $form) = @_;

	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $nexus_tids_ar = $reader->getMainpageDisplayableNexuses();

	my @story_always_nexus 		= split ",", $user->{story_always_nexus} || "";
	my @story_full_brief_nexus 	= split ",", $user->{story_full_brief_nexus} || "";
	my @story_brief_always_nexus 	= split ",", $user->{story_brief_always_nexus} || "";
	my @story_full_best_nexus 	= split ",", $user->{story_full_best_nexus} || "";
	my @story_brief_best_nexus 	= split ",", $user->{story_brief_best_nexus} || "";
	my @story_never_nexus 		= split ",", $user->{story_never_nexus} || "";

	my $update = {};

	foreach my $key (keys %$form) {
		my $value = $form->{$key};
		if ($key =~ /^nexustid(\d+)$/) {
			my $tid = $1;
			if ($value >= 0 && $value <= 5 && $value =~ /^\d+$/) {
				$update->{$tid} = $value;
			}
		} elsif ($key eq "nexus_master") {
			if ($value >= 1 && $value <= 5 && $value =~ /^\d+$/) {
				foreach my $tid (@$nexus_tids_ar) {
					$update->{$tid} = $value;
				}
			}
		}
	}


	foreach my $tid (keys %$update) {
		my $value = $update->{$tid};

		# First remove tid in question from all arrays
		@story_always_nexus 		= grep { $_ != $tid } @story_always_nexus;
		@story_full_brief_nexus 	= grep { $_ != $tid } @story_full_brief_nexus;
		@story_brief_always_nexus 	= grep { $_ != $tid } @story_brief_always_nexus;
		@story_full_best_nexus 		= grep { $_ != $tid } @story_full_best_nexus;
		@story_brief_best_nexus 	= grep { $_ != $tid } @story_brief_best_nexus;
		@story_never_nexus 		= grep { $_ != $tid } @story_never_nexus;

		# Then add it to the correct array
		if ($value == 5) {
			push @story_always_nexus, $tid;
		} elsif ($value == 4) {
			push @story_full_brief_nexus, $tid;
		} elsif ($value == 3) {
			push @story_brief_always_nexus, $tid;
		} elsif ($value == 2) {
			push @story_full_best_nexus, $tid;
		} elsif ($value == 1) {
			push @story_brief_best_nexus, $tid;
		} elsif ($value == 0) {
			push @story_never_nexus, $tid;
		}
	}

	my $story_always_nexus       	= join ",", @story_always_nexus;
	my $story_full_brief_nexus   	= join ",", @story_full_brief_nexus;
	my $story_brief_always_nexus 	= join ",", @story_brief_always_nexus;
	my $story_full_best_nexus	= join ",", @story_full_best_nexus;
	my $story_brief_best_nexus	= join ",", @story_brief_best_nexus;
	my $story_never_nexus       	= join ",", @story_never_nexus;

	$slashdb->setUser($user->{uid}, {
			story_always_nexus => $story_always_nexus,
			story_full_brief_nexus => $story_full_brief_nexus,
			story_brief_always_nexus => $story_brief_always_nexus,
			story_full_best_nexus	=> $story_full_best_nexus,
			story_brief_best_nexus	=> $story_brief_best_nexus,
			story_never_nexus	=> $story_never_nexus
		}
	);

        #return getData('set_section_prefs_success_msg');
}

###################
# comments

sub submitReply {
	my($slashdb, $constants, $user, $form, $options) = @_;
	my $pid = $form->{pid} || 0;
	my $sid = $form->{sid} or return;

	$user->{state}{ajax_accesslog_op} = 'comments_submit_reply';

	my($error_message, $saved_comment);
	my $discussion = $slashdb->getDiscussion($sid);
	my $comment = preProcessComment($form, $user, $discussion, \$error_message);
	if (!$error_message) {
		unless ($options->{rkey}->use) {
			$error_message = $options->{rkey}->errstr;
		}
	}
	$saved_comment = saveComment($form, $comment, $user, $discussion, \$error_message)
		unless $error_message;
	my $cid = $saved_comment && $saved_comment ne '-1' ? $saved_comment->{cid} : 0;

	$options->{content_type} = 'application/json';
	my %to_dump = ( cid => $cid );

	if ($error_message) {
		$error_message = getData('inline preview warning') . $error_message
			unless $options->{rkey}->death;
		# go back to HumanConf if we still have errors left to display
		$error_message .= slashDisplay('hc_comment', { pid => $pid }, { Return => 1 });
		$to_dump{error} = $error_message;

		my $max_duration = $options->{rkey}->max_duration;
		if (defined($max_duration) && length($max_duration)) {
			$max_duration = 0 if $max_duration > 60;
			$to_dump{eval_last} = "D2.submitCountdown($pid,$max_duration);"
		}
	}

#use Data::Dumper; print STDERR Dumper \%to_dump;

	return Data::JavaScript::Anon->anon_dump(\%to_dump);
}

sub previewReply {
	my($slashdb, $constants, $user, $form, $options) = @_;
	my $pid = $form->{pid} || 0;
	my $sid = $form->{sid} or return;

	$user->{state}{ajax_accesslog_op} = 'comments_preview_reply';

	my $html = my $error_message = '';
	my $discussion = $slashdb->getDiscussion($sid);
	my $comment = preProcessComment($form, $user, $discussion, \$error_message);
	if ($comment && $comment ne '-1') {
		my $preview = postProcessComment({ %$user, %$form, %$comment }, 0, $discussion);
		$html = prevComment($preview, $user);
	}

	if ($html) {
		$error_message = getData('inline preview warning') . $error_message;
		$error_message .= slashDisplay('hc_comment', { pid => $pid }, { Return => 1 });
	}
	$options->{content_type} = 'application/json';
	my %to_dump = (
		error => $error_message,
	);
	$to_dump{html} = { "replyto_preview_$pid" => $html } if $html;
	$to_dump{eval_first} = "\$('#gotmodwarning_$pid').val(1);"
		if $form->{gotmodwarning} || ($error_message && $error_message eq
			Slash::Utility::Comments::getError("moderations to be lost")
		);

	my $max_duration = $options->{rkey}->max_duration;
	if (defined($max_duration) && length($max_duration)) {
		$max_duration = 0 if $max_duration > 60;
		$to_dump{eval_last} = "D2.submitCountdown($pid,$max_duration);"
	}

#use Data::Dumper; print STDERR Dumper \%to_dump; 

	return Data::JavaScript::Anon->anon_dump(\%to_dump);
}


sub replyForm {
	my($slashdb, $constants, $user, $form, $options) = @_;
	my $pid = $form->{pid} || 0;
	my $sid = $form->{sid} or return;

	$user->{state}{ajax_accesslog_op} = 'comments_reply_form';

	my($reply, $pid_reply);
	my $discussion = $slashdb->getDiscussion($sid);
	$reply = $slashdb->getCommentReply($sid, $pid) if $pid;
	# Haha, I stole your sub
	#$pid_reply = prepareQuoteReply($reply) if $pid && $reply;
	preProcessReplyForm($form, $reply);

	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('comments', { nostate => 1 }); #, debug => 1 });
	$rkey->create;

	my %to_dump;
	if ($rkey->success) {
		my $reply_html = slashDisplay('edit_comment', {
			discussion => $discussion,
			sid        => $sid,
			pid        => $pid,
			reply      => $reply,
			rkey       => $rkey
		}, { Return => 1 });
		%to_dump = (html => { "replyto_$pid" => $reply_html });
	} else {
		%to_dump = (html => { "replyto_$pid" => $rkey->errstr });
	}

	$options->{content_type} = 'application/json';
	$to_dump{eval_first} = "D2.comment_body_reply()[$pid] = '$pid_reply';" if $pid_reply;

#use Data::Dumper; print STDERR Dumper \%to_dump; 

	return Data::JavaScript::Anon->anon_dump(\%to_dump);
}


sub readRest {
	my($slashdb, $constants, $user, $form) = @_;
	my $cid = $form->{cid} or return;
	my $sid = $form->{sid} or return;

	$user->{state}{ajax_accesslog_op} = 'comments_read_rest';

	my $comment = $slashdb->getComment($cid) or return;
	return unless $comment->{sid} == $sid;

	my $texts   = $slashdb->getCommentTextCached(
		{ $cid => $comment },
		[ $cid ],
		{ full => 1 }
	) or return;

	return $texts->{$cid} || '';
}

sub fetchComments {
	my($slashdb, $constants, $user, $form, $options) = @_;

	my $cids          = [ grep { defined && /^\d+$/ } ($form->{_multi}{cids} ? @{$form->{_multi}{cids}} : $form->{cids}) ];
	my $id            = $form->{discussion_id} || 0;
	my $base_comment  = $form->{cid} || 0; # root id
	my $d2_seen       = $form->{d2_seen};
	my $placeholders  = [ grep { defined && /^\d+$/ } ($form->{_multi}{placeholders}  ? @{$form->{_multi}{placeholders}}  : $form->{placeholders}) ];
	my $read_comments = [ grep { defined && /^\d+$/ } ($form->{_multi}{read_comments} ? @{$form->{_multi}{read_comments}} : $form->{read_comments}) ];

	$user->{state}{ajax_accesslog_op} = "ajax_comments_fetch";
#use Data::Dumper; print STDERR Dumper [ $form, $cids, $id, $base_comment, $d2_seen, $read_comments ];
	return unless $id;

	$slashdb->saveCommentReadLog($read_comments, $id, $user->{uid}) if @$read_comments;

	# XXX error?
	return unless (@$cids || $d2_seen);

	my $discussion = $slashdb->getDiscussion($id);
	if ($discussion->{type} eq 'archived') {
		$user->{state}{discussion_archived} = 1;
	}
	$user->{mode} = 'thread';
	$user->{reparent} = 0;
	$user->{state}{max_depth} = $constants->{max_depth} + 3;

	my %select_options = (
		commentsort  => 0,
		threshold    => -1,
		no_d2        => 1
	);

	my $seen = parseCommentBitmap($d2_seen || $form->{d2_seen_ex});
	if ($d2_seen) {
		$select_options{existing} = $seen if keys %$seen;
		delete $select_options{no_d2};
	}

	my($comments) = selectComments(
		$discussion,
		$base_comment,
		\%select_options,
	);

	while ($base_comment && (!$comments || keys(%$comments) < 2)) {
		my $comment = $slashdb->getComment($base_comment);
		$base_comment = $comment->{pid};
		($comments) = selectComments(
			$discussion,
			$base_comment,
			\%select_options,
		);
	}

	return unless $comments && keys(%$comments) > 1;

	my $d2_seen_0 = $comments->{0}{d2_seen} || '';
	#delete $comments->{0}; # non-comment data

	my %data;
	if ($d2_seen || @$placeholders) {
		my $special_cids;
		if ($d2_seen) {
			$special_cids = $cids = [ sort { $a <=> $b } grep { $_ && !$seen->{$_} } keys %$comments ];
		} elsif (@$placeholders) {
			$special_cids = [ sort { $a <=> $b } @$placeholders ];
			if ($form->{d2_seen_ex}) {
				$d2_seen_0 = makeCommentBitmap({
					%$seen, map { $_ => 1 } @$placeholders
				});
			}
		}

		if (@$special_cids) {
			my @cid_data;
			for my $cid (@$special_cids) {
				my $comments_new = {
					uid     => $comments->{$cid}{uid},
					pid     => $comments->{$cid}{pid},
					points  => $comments->{$cid}{points},
					read    => $comments->{$cid}{has_read} || 0,
					kids    => []
				};
				if ($comments->{$cid}{subject_orig} && $comments->{$cid}{subject_orig} eq 'no') {
					$comments_new->{subject} = $comments->{$cid}{subject};
					$comments->{$cid}{subject} = 'Re:';
				}
				push @cid_data, $comments_new;
			}

			$data{new_cids_order} = [ @$special_cids ];
			$data{new_cids_data}  = \@cid_data;

			my %cid_map = map { ($_ => 1) } @$special_cids;
			$data{new_thresh_totals} = commentCountThreshold(
				{ map { ($_ => $comments->{$_}) } grep { $_ && $cid_map{$_} } keys %$comments },
				0,
				{ map { ($_ => 1) } grep { !$comments->{$_}{pid} } @$special_cids }
			);
		}
#use Data::Dumper; print STDERR Dumper \$comments, \%data;
	}

	# pieces_cids are comments that were oneline and need the extra display stuff for full
	# abbrev_cids are comments that were oneline/abbreviated and need to be non-abbrev
	# hidden_cids are comments that were hidden (noshow) and need to be displayed (full or oneline)

	my %pieces = split /[,;]/, $form->{pieces}      || '';
	my %abbrev = split /[,;]/, $form->{abbreviated} || '';
	my(@hidden_cids, @pieces_cids, @abbrev_cids, %get_pieces_cids, %keep_hidden);
	my(%html, %html_append_substr);

	# prune out hiddens we don't need, if threshold is sent (which means
	# we are not asking for a specific targetted comment(s) to highlight,
	# but just adjusting for a threshold or getting new comments
	if (defined($form->{threshold}) && defined($form->{highlightthresh})) {
		for (my $i = 0; $i < @$cids; $i++) {
			my $class = 'oneline';
			my $cid = $cids->[$i];
			my $comment = $comments->{$cid};
			if ($comment->{dummy}) {
				$class = 'hidden';
				$keep_hidden{$cid} = 1;
			} else {
				# for now we only readjust for children of ROOT (pid==0);
				# if we make this work for threads, we will need to know
				# the pid of the page, and adjust this accordingly
				my($T, $HT) = commentThresholds($comment, !$comment->{pid}, $user);
				if ($T < $form->{threshold}) {
					if ($user->{is_anon} || ($user->{uid} != $comment->{uid})) {
						$class = 'hidden';
						$keep_hidden{$cid} = 1;
					}
				}
				$class = 'full' if $HT >= $form->{highlightthresh}
					&& $class ne 'hidden';
			}
			$comment->{class} = $class;

			if ($class eq 'oneline') {
				$get_pieces_cids{$cid} = 1;
			}
		}
	} else {
		$comments->{$_}{class} = 'full' for @$cids;
	}

	for my $cid (@$cids) {
		if (exists $pieces{$cid}) {
			push @pieces_cids, $cid;
			if (exists $abbrev{$cid}) {
				push @abbrev_cids, $cid;
			}
		} elsif (!$keep_hidden{$cid}) {
			push @hidden_cids, $cid;
		}
	}

	my $comment_text = $slashdb->getCommentTextCached(
		$comments, [@hidden_cids, @abbrev_cids], { full => 1 },
	);

	for my $cid (keys %$comment_text) {
		$comments->{$cid}{comment} = $comment_text->{$cid};
	}

	# for dispComment
	$form->{mode} = 'archive';

	for my $cid (@hidden_cids) {
		$html{'comment_' . $cid} = dispComment($comments->{$cid}, {
			noshow_show => 1,
			pieces      => $get_pieces_cids{$cid}
		});
	}

	for my $cid (@pieces_cids) {
		@html{'comment_otherdetails_' . $cid, 'comment_sub_' . $cid} =
			dispComment($comments->{$cid}, {
				show_pieces => 1
			});
	}

	for my $cid (@abbrev_cids) {
		@html_append_substr{'comment_body_' . $cid} = substr($comments->{$cid}{comment}, $abbrev{$cid});
	}

# XXX update noshow_comments, pieces_comments -- pudge
#use Data::Dumper; print STDERR Dumper \@hidden_cids, \@pieces_cids, \@abbrev_cids, \%get_pieces_cids, \%keep_hidden, \%pieces, \%abbrev, \%html, \%html_append_substr, $form, \%data, $d2_seen_0;

	$user->{d2_comment_order} ||= 0;

	$options->{content_type} = 'application/json';
	my %to_dump = (
		read_comments      => $read_comments,  # send back so we can just mark them
		update_data        => \%data,
		html               => \%html,
		html_append_substr => \%html_append_substr,
		eval_first         => "D2.d2_comment_order($user->{d2_comment_order});"
	);

	if ($d2_seen_0) {
		my $total = $slashdb->countCommentsBySid($id);
		$total -= $d2_seen_0 =~ tr/,//; # total
		$total--; # off by one
		$to_dump{eval_first} .= "D2.d2_seen('$d2_seen_0'); D2.updateMoreNum($total);";
	}
	if (@$placeholders) {
		$to_dump{eval_first} .= "D2.placeholder_no_update(" . Data::JavaScript::Anon->anon_dump({ map { $_ => 1 } @$placeholders }) . ');';
	}
	if ($base_comment) {
		$to_dump{eval_first} .= "D2.base_comment($base_comment);";
	}
	writeLog($id);
#print STDERR "\n\n\n", Data::JavaScript::Anon->anon_dump(\%to_dump), "\n\n\n";
	return Data::JavaScript::Anon->anon_dump(\%to_dump);
}

sub updateD2prefs {
	my($slashdb, $constants, $user, $form) = @_;
	my %save;
	for my $pref (qw(threshold highlightthresh)) {
		$save{"d2_$pref"} = $form->{$pref} if defined $form->{$pref};
	}
	for my $pref (qw(comments_control)) {
		$save{$pref} = $form->{$pref} if defined $form->{$pref};
	}

	$slashdb->setUser($user->{uid}, \%save);
}

sub getModalPrefs {
	my($slashdb, $constants, $user, $form) = @_;

	my $reskey = getObject('Slash::ResKey');
	my $rkey;

	# anon calls get normal ajax_base
	my $reskey_resource = 'ajax_user';
	if ((caller(1))[3] =~ /\bgetModalPrefsAnon(HC)?$/) {
		$reskey_resource = $1 ? 'ajax_base_hc' : 'ajax_base';
	}

	unless ($form->{'section'} eq 'submit') {
		$rkey = $reskey->key($reskey_resource, { nostate => 1 });
		$rkey->create;
		if ($rkey->failure) {
			# XXX need to handle errors, esp. for HC
			return;
		} else {
			$user->{state}{reskey} = $rkey->reskey;
		}
	}

	if ($form->{'section'} eq 'messages') {
		my $messages  = getObject('Slash::Messages');
		my $deliverymodes   = $messages->getDescriptions('deliverymodes');
		my $messagecodes    = $messages->getDescriptions('messagecodes');
		my $bvdeliverymodes = $messages->getDescriptions('bvdeliverymodes');
		my $bvmessagecodes  = $messages->getDescriptions('bvmessagecodes_slev');

		foreach my $bvmessagecode (keys %$bvmessagecodes) {
			$bvmessagecodes->{$bvmessagecode}->{'valid_bvdeliverymodes'} = [];
			foreach my $bvdeliverymode (keys %$bvdeliverymodes) {
				# skip if we have no valid delivery modes (i.e. off)
				if (!$bvmessagecodes->{$bvmessagecode}->{'delivery_bvalue'}) {
					delete $bvmessagecodes->{$bvmessagecode};
					last;
				}
                                # build our list of valid delivery modes
                                if (($bvdeliverymodes->{$bvdeliverymode}->{'bitvalue'} & $bvmessagecodes->{$bvmessagecode}->{'delivery_bvalue'}) ||
                                    ($bvdeliverymodes->{$bvdeliverymode}->{'bitvalue'} == 0)) {
                                        push(@{$bvmessagecodes->{$bvmessagecode}->{'valid_bvdeliverymodes'}}, $bvdeliverymodes->{$bvdeliverymode}->{'code'});
                                }
			}
		}

		my $prefs = $messages->getPrefs($user->{'uid'});
		return
			slashDisplay('prefs_messages', {
				userm           => $user,
				prefs           => $prefs,
				messagecodes    => $messagecodes,
				deliverymodes   => $deliverymodes,
				bvmessagecodes  => $bvmessagecodes,
				bvdeliverymodes => $bvdeliverymodes,
                                tabbed          => $form->{'tabbed'},
			},
			{ Return => 1 }
		);
	} elsif ($form->{'section'} eq 'sectional') {
	       getSectionPrefsHTML($slashdb, $constants, $user, $form);

	} elsif ($form->{'section'} eq 'slashboxes') {
		my $section_descref = { };
		my $box_order;
		my $sections_description = $slashdb->getSectionBlocks();
		my $slashboxes_hr = { };
		my $slashboxes_textlist = $user->{slashboxes};
		my $userspace = $user->{mylinks} || "";

		if (!$slashboxes_textlist) {
			my($boxes, $skinBoxes) = $slashdb->getPortalsCommon();
			$slashboxes_textlist = join ",", @{$skinBoxes->{$constants->{mainpage_skid}}};
		}

		for my $bid (map { /^'?([^']+)'?$/; $1 } split(/,/, $slashboxes_textlist)) {
			$slashboxes_hr->{$bid} = 1;
		}

		for my $ary (sort { lc $a->[1] cmp lc $b->[1]} @$sections_description) {
			my($bid, $title, $boldflag) = @$ary;
			push @$box_order, $bid;
			$section_descref->{$bid}{checked} = $slashboxes_hr->{$bid} ? $constants->{markup_checked_attribute} : '';
			$title =~ s/<(.*?)>//g;
			$section_descref->{$bid}{title} = $title;
		}

		my $dynamic_blocks = getObject("Slash::DynamicBlocks");
		my $extra_blocks = [];
		if ($dynamic_blocks) {
			my $userblocks = $dynamic_blocks->getUserBlocks("name", $user->{uid}) || {};
			my $friendblocks = $dynamic_blocks->getFriendBlocks("name", $user->{uid}) || {};
			push(@$extra_blocks, grep { $slashboxes_textlist =~ $_; } (keys(%$userblocks), keys(%$friendblocks)));
		}

		return
			slashDisplay('prefs_slashboxes', {
				box_order	  => $box_order,
				section_descref	  => $section_descref,
				userspace	  => $userspace,
				extra_blocks      => $extra_blocks,
				tabbed		  => $form->{'tabbed'},
			},
			{ Return => 1 }
		);

	} elsif ($form->{'section'} eq 'new_slashboxes') {

		return
			slashDisplay('new_slashboxes', {
				user			=> $user,
				tabbed			=> $form->{'tabbed'},
			},
			{ Return => 1 }
		);

	} elsif ($form->{'section'} eq 'portal_slashboxes') {
		my $blocks;
		my $blocks_order;
		my $dynamic_blocks = getObject('Slash::DynamicBlocks');
		if ($dynamic_blocks) {
			$blocks = $dynamic_blocks->getPortalBlocks( 'name', { filter => 'basic' });
			if ($blocks) {
				my $blocks_unsort;
				foreach my $keyb (keys %$blocks) {
					my $pair = {
						name	=> $blocks->{$keyb}->{'name'},
						title	=> $blocks->{$keyb}->{'title'}
					};
					push @$blocks_unsort, $pair;
				}
				@$blocks_order = sort{$a->{title} cmp $b->{title} } @$blocks_unsort;
			}
		}

		return
			slashDisplay('portal_slashboxes', {
				user			=> $user,
				blocks_order		=> $blocks_order,
				tabbed			=> $form->{'tabbed'},
			},
			{ Return => 1 }
		);

	} elsif ($form->{'section'} eq 'user_slashboxes') {
		my $blocks;
		my $blocks_order;
		my $dynamic_blocks = getObject('Slash::DynamicBlocks');
		if ($dynamic_blocks) {
			$blocks = $dynamic_blocks->getUserBlocks( 'name', $user->{uid}, { filter => 'basic' });
			if ($blocks) {
				my $blocks_unsort;
				foreach my $keyb (keys %$blocks) {
					my $pair = {
						name	=> $blocks->{$keyb}->{'name'},
						title	=> $blocks->{$keyb}->{'title'}
					};
					push @$blocks_unsort, $pair;
				}
				@$blocks_order = sort{$a->{title} cmp $b->{title} } @$blocks_unsort;
			}
		}

		return
			slashDisplay('portal_slashboxes', {
				user			=> $user,
				blocks_order		=> $blocks_order,
				tabbed			=> $form->{'tabbed'},
			},
			{ Return => 1 }
		);

	} elsif ($form->{'section'} eq 'friend_slashboxes') {
		my $blocks;
		my $blocks_order;
		my $dynamic_blocks = getObject('Slash::DynamicBlocks');
		if ($dynamic_blocks) {
			$blocks = $dynamic_blocks->getFriendBlocks( 'name', $user->{uid} );
			if ($blocks) {
				my $blocks_unsort;
				foreach my $keyb (keys %$blocks) {
					my $pair = {
						name	=> $blocks->{$keyb}->{'name'},
						title	=> $blocks->{$keyb}->{'title'}
					};
					push @$blocks_unsort, $pair;
				}
				@$blocks_order = sort{$a->{title} cmp $b->{title} } @$blocks_unsort;
			}
		}

		return
			slashDisplay('portal_slashboxes', {
				user			=> $user,
				blocks_order		=> $blocks_order,
				tabbed			=> $form->{'tabbed'},
			},
			{ Return => 1 }
		);

	} elsif ($form->{'section'} eq 'preview_slashboxes') {
		my($slashdb, $constants, $user, $form) = @_;

		if ($form->{'preview_bid'} ) {
			my $userspace = $user->{mylinks} || "";

			return
				slashDisplay('preview_slashboxes', {
					preview_bid	=> $form->{'preview_bid'},
					user		=> $user,
					userspace	=> $userspace,
					tabbed		=> $form->{'tabbed'},
				},
				{ Return => 1 }
			);
		}

	} elsif ($form->{'section'} eq 'authors') {

		my $author_hr = $slashdb->getDescriptions('authors_recent');
		my @aid_order = sort { lc $author_hr->{$a} cmp lc $author_hr->{$b} } keys %$author_hr;
		my %story_never_author;
		map { $story_never_author{$_} = 1 } keys %$author_hr;
		map { $story_never_author{$_} = 0 } split(/,/, $user->{story_never_author});

		return
			slashDisplay('prefs_authors', {
				aid_order	   => \@aid_order,
				author_hr	   => $author_hr,
				story_never_author => \%story_never_author,
				tabbed		   => $form->{'tabbed'},
			},
			{ Return => 1 }
		);

	} elsif ($form->{'section'} eq 'admin') {
		return if !$user->{is_admin};

		return
			slashDisplay('prefs_admin', {
				user   => $user,
				tabbed => $form->{'tabbed'},
			},
			{ Return => 1 }
		);

	} elsif ($form->{'section'} eq 'fh') {

		my $firehose = getObject("Slash::FireHose");
		my $opts = $firehose->getAndSetOptions();
		$opts->{firehose_usermode} = $user->{firehose_usermode} if $user->{is_admin};

		return
			slashDisplay('fhadvprefpane', {
				options => $opts,
				user	=> $user,
			},
			{ Return => 1 }
		);
		
	} elsif ($form->{'section'} eq 'ifh') {

		my $firehose = getObject("Slash::FireHose");
		my $opts = $firehose->getAndSetOptions();
		$opts->{firehose_usermode} = $user->{firehose_usermode} if $user->{is_admin};

		return
			slashDisplay('fhadvprefpane', {
				options => $opts,
				user	=> $user,
			},
			{ Page => 'misc', Skin => 'idle', Return => 1 }
		);

	} elsif ($form->{'section'} eq 'modcommentlog') {
		my $moddb = getObject("Slash::$constants->{m1_pluginname}");
		if ($moddb) {
			# we hijack "tabbed" as our cid -- pudge
			my $return = $moddb->dispModCommentLog('cid', $form->{'tabbed'}, {
				show_m2s        => ($constants->{m2}
					? (defined($form->{show_m2s})
						? $form->{show_m2s}
						: $user->{m2_with_comm_mod}
					) : 0),
				need_m2_form    => $constants->{m2},
				need_m2_button  => $constants->{m2},
				title           => " "
			});
			$return ||= getData('no modcommentlog');
			return $return;
		}

	} elsif ($form->{section} eq 'firehoseview') {
		my $fh = getObject("Slash::FireHose");
		my $views = $fh->getUserViews({ tab_display => "yes"});
		my $views_hr = { };
		%$views_hr = map { $_->{id} => ucfirst($_->{viewname}) } @$views;
		my $fh_section;
		if ($form->{id}) {
			$fh_section = $fh->getFireHoseSection($form->{id});
			$fh_section = $fh->applyUserSectionPrefs($fh_section);
		}
		
		my ($name, $filter, $viewid, $display);
		$name = $form->{name};
		$filter = $form->{filter};

		if ($fh_section) {
			$name = $fh_section->{section_name};
			$filter = $fh_section->{section_filter};
			$viewid = $fh_section->{view_id};
			$display = $fh_section->{display};
		}

		return slashDisplay('fhviewprefs', { name => $name, id => $form->{id}, filter => $filter, views => $views_hr, fh_section => $fh_section, default_view => $viewid, display => $display }, { Return => 1} );

	} elsif ($form->{section} eq 'fhlayout') {
		return slashDisplay('prefs_fhlayout', {
                        tabbed                  => $form->{'tabbed'},
		}, { Return => 1});
	} elsif ($form->{section} eq 'fhexclusions') {

		my $author_hr = $slashdb->getDescriptions('authors_recent');
		my @aid_order = sort { lc $author_hr->{$a} cmp lc $author_hr->{$b} } keys %$author_hr;
		my %story_never_author;
		map { $story_never_author{$_} = 0 } keys %$author_hr;
		map { $story_never_author{$_} = 1 } split(/,/, $user->{story_never_author});

		return slashDisplay(
			'prefs_fhexclusions', {
				aid_order	   => \@aid_order,
				author_hr	   => $author_hr,
				story_never_author => \%story_never_author,
				tabbed		   => $form->{'tabbed'},
			},
			{ Return => 1 }
		);
	} elsif ($form->{'section'} =~ /^fhview/) {
		my($name) = $form->{section} =~ /^fhview(.*)/;
		my $fh = getObject("Slash::FireHose");
		my $view = "";
		if ($name) {
			$view = $fh->getUserViewByName($name);
		}
		$view = $fh->applyUserViewPrefs($view);

		my $story_check = 0;
		my $other_check = 0;

		if ($view) {
			if ($view->{datafilter} =~ /story/ && $view->{datafilter} !~/-story/) {
				$story_check = 1;
			} elsif ($view->{datafilter} =~/\-story/) {
				$other_check = 1;
				$story_check = 0;
			} else {
				$story_check = 1;
				$other_check = 1;
			}
		}
		
		slashDisplay(
			"prefs_fhview", {
				tabbed 		=> $form->{tabbed},
				view		=> $view,
				story_check 	=> $story_check,
				other_check 	=> $other_check,
			},
			{ Return => 1}
		);

	} elsif ($form->{section} eq 'submit') {
		my $edit = getObject("Slash::Edit");
		$rkey = $edit->rkey(0, 1);
		unless ($rkey->create) {
			errorLog($rkey->errstr);
			return;
		}
		$user->{state}{reskey} = $rkey->reskey;

		my $skey = $reskey->session;
		print STDERR "Edit Session $skey for UID: $user->{uid} (ajax)\n";
		$skey->set_cookie;

		return $edit->showEditor({ state => 'modal' });
	} elsif ($form->{'section'} eq 'adminblock') {
		return if !$user->{is_admin};

		my $logdb = getObject('Slash::DB', { db_type => 'log_slave' });
                my($expired, $uidstruct, $readonly);
                my $srcid;
                my $proxy_check = {};
                my @accesshits;
                my($user_edit, $user_editfield, $ipstruct, $ipstruct_order, $authors, $author_flag, $topabusers, $thresh_select, $section_select);
		my $uid = $user->{uid};
                my $authoredit_flag = ($user->{seclev} >= 10000) ? 1 : 0;
                my $sectionref = $slashdb->getDescriptions('skins');
                $sectionref->{''} = getData('all_sections', undef, 'users');
		my $field = $form->{'field'};
                my $id = $form->{'id'};
                my $fieldname = $form->{'fieldname'};
                my $userfield = $form->{'userfield'};
                my $check_proxy = $form->{'check_proxy'};	
	
		if ($field eq 'uid') {
                        $user_edit = $slashdb->getUser($id);
                        $user_editfield = $user_edit->{uid};
                        $srcid = convert_srcid( uid => $id );
                        $ipstruct = $slashdb->getNetIDStruct($user_edit->{uid});
                        @accesshits = $logdb->countAccessLogHitsInLastX($field, $user_edit->{uid}) if defined($logdb);
                        $section_select = createSelect('section', $sectionref, $user_edit->{section}, 1);

                } elsif ($field eq 'nickname') {
                        $user_edit = $slashdb->getUser($slashdb->getUserUID($id));
                        $user_editfield = $user_edit->{nickname};
                        $ipstruct = $slashdb->getNetIDStruct($user_edit->{uid});
                        @accesshits = $logdb->countAccessLogHitsInLastX('uid', $user_edit->{uid}) if defined($logdb);
                        $section_select = createSelect('section', $sectionref, $user_edit->{section}, 1);

                } elsif ($field eq 'md5id') {
                        $user_edit->{nonuid} = 1;
                        $user_edit->{md5id} = $id;
                        if ($fieldname && $fieldname =~ /^(ipid|subnetid)$/) {
                                $uidstruct = $slashdb->getUIDStruct($fieldname, $user_edit->{md5id});
                                @accesshits = $logdb->countAccessLogHitsInLastX($fieldname, $user_edit->{md5id}) if defined($logdb);
                        } else {
                                $uidstruct = $slashdb->getUIDStruct('md5id', $user_edit->{md5id});
                                @accesshits = $logdb->countAccessLogHitsInLastX($field, $user_edit->{md5id}) if defined($logdb);
                        }

                } elsif ($field eq 'ipid') {
                        $user_edit->{nonuid} = 1;
                        $user_edit->{ipid} = $id;
                        $srcid = convert_srcid( ipid => $id );
                        $user_editfield = $id;
                        $uidstruct = $slashdb->getUIDStruct('ipid', $user_edit->{ipid});
                        @accesshits = $logdb->countAccessLogHitsInLastX('host_addr', $user_edit->{ipid}) if defined($logdb);

                        if ($userfield =~/^\d+\.\d+\.\d+\.(\d+)$/) {
                                if ($1 ne "0"){
                                        $proxy_check->{available} = 1;
                                        $proxy_check->{results} = $slashdb->checkForOpenProxy($userfield) if $check_proxy;
                                }
                        }

                } elsif ($field eq 'subnetid') {
                        $user_edit->{nonuid} = 1;
                        $srcid = convert_srcid( ipid => $id );
                        if ($id =~ /^(\d+\.\d+\.\d+)(?:\.\d)?/) {
                                $id = $1 . ".0";
                                $user_edit->{subnetid} = $id;
                        } else {
                                $user_edit->{subnetid} = $id;
                        }

                        $user_editfield = $id;
                        $uidstruct = $slashdb->getUIDStruct('subnetid', $user_edit->{subnetid});
                        @accesshits = $logdb->countAccessLogHitsInLastX($field, $user_edit->{subnetid}) if defined($logdb);

                } elsif ($field eq "srcid") {
                        $user_edit->{nonuid} = 1;
                        $user_edit->{srcid}  = $id;
                        $srcid = $id;

                } else {
			$user_edit = $id ? $slashdb->getUser($id) : $user;
                        $user_editfield = $user_edit->{uid};
                        $ipstruct = $slashdb->getNetIDStruct($user_edit->{uid});
                        @accesshits = $logdb->countAccessLogHitsInLastX('uid', $user_edit->{uid}) if defined($logdb);
                }

                my $all_acls_ar = $slashdb->getAllACLNames();
                my $all_acls_hr = { map { ( $_, 1 ) } @$all_acls_ar };

                for my $acl (keys %{$user_edit->{acl}}) {
                        $all_acls_hr->{$acl} = 1;
                }

                my $all_aclam_hr = { };
                if (!$user_edit->{nonuid}) {
                        $all_aclam_hr = { map { ( "aclam_$_", "ACL: $_" ) } keys %$all_acls_hr };
                }

                my $all_al2types = $slashdb->getAL2Types;
                for my $key (keys %$all_al2types) {
                        next if $key eq 'comment'; # skip the 'comment' type
                        $all_aclam_hr->{"aclam_$key"} = $all_al2types->{$key}{title};
                }

                my $all_acls_longkeys_hr = { map { ( "aclam_$_", 1 ) } keys %$all_acls_hr };
                my $all_aclam_ar = [
                        sort {
                                (exists($all_acls_longkeys_hr->{$a}) ? -1 : 1) <=> (exists($all_acls_longkeys_hr->{$b}) ? -1 : 1)
                                ||
                                $all_aclam_hr->{$a} cmp $all_aclam_hr->{$b}
                        } keys %$all_aclam_hr
                ];

                my $user_aclam_hr = { };
                for my $acl (keys %{ $user_edit->{acl} }) {
                        $user_aclam_hr->{"aclam_$acl"} = 1;
                }
                my $al2_tid_comment = $all_al2types->{comment}{al2tid} || 0;
                my $al2_log_ar = [ ];
                my $al2_hr = { };

                if ($srcid) {
			# getAL2 works with either a srcids hashref or a single srcid
			$al2_hr = $slashdb->getAL2($srcid);
                        for my $al2 (keys %{ $al2_hr }) {
                                $user_aclam_hr->{"aclam_$al2"} = 1;
                        }
                        $al2_log_ar = $slashdb->getAL2Log($srcid);
                }

                my $al2_nick_hr = { };
                for my $al2_log (@$al2_log_ar) {
                        my $uid = $al2_log->{adminuid};
                        next if !$uid; # odd error, might want to flag this
                        $al2_nick_hr->{$uid} ||= $slashdb->getUser($uid, 'nickname');
                }

                $user_edit->{author} = ($user_edit->{author} && $user_edit->{author} == 1)
                        ? $constants->{markup_checked_attribute} : '';


                if (! $user->{nonuid}) {
                        my $threshcodes = $slashdb->getDescriptions('threshcode_values','',1);
                        $thresh_select = createSelect('defaultpoints', $threshcodes, $user_edit->{defaultpoints}, 1);
                }

                if (!ref $ipstruct) {
                        undef $ipstruct;
                } else {
                        @$ipstruct_order = sort { $ipstruct->{$b}{dmin} cmp $ipstruct->{$a}{dmin} } keys %$ipstruct;
                }

                my $m2total = ($user_edit->{m2fair} || 0) + ($user_edit->{m2unfair} || 0);
                if ($m2total) {
                        $user_edit->{m2unfairpercent} = sprintf("%.2f",
                                $user_edit->{m2unfair}*100/$m2total);
                }
                my $mod_total = ($user_edit->{totalmods} || 0) + ($user_edit->{stirred} || 0);

                if ($mod_total) {
                        $user_edit->{stirredpercent} = sprintf("%.2f",
                                $user_edit->{stirred}*100/$mod_total);
                }

                if ($constants->{subscribe} and my $subscribe = getObject('Slash::Subscribe')) {
                        $user_edit->{subscribe_payments} =
                                $subscribe->getSubscriptionsForUser($user_edit->{uid});
                        $user_edit->{subscribe_purchases} =
                                $subscribe->getSubscriptionsPurchasedByUser($user_edit->{uid},{ only_types => [ "grant", "gift" ] });
                }

                my $ipid = $user_edit->{ipid};
                my $subnetid = $user_edit->{subnetid};
                my $post_restrictions = {};
                my ($subnet_karma, $ipid_karma);

		if ($ipid && !$subnetid) {
                        $ipid = md5_hex($ipid) if length($ipid) != 32;
                        $proxy_check->{ipid} = $ipid;
                        $proxy_check->{currently} = $slashdb->getKnownOpenProxy($ipid, "ipid");
                        $subnetid = $slashdb->getSubnetFromIPIDBasedOnComments($ipid);
                }

                if ($subnetid) {
                        $subnetid = md5_hex($subnetid) if length($subnetid) != 32;
                        $post_restrictions = $slashdb->getNetIDPostingRestrictions("subnetid", $subnetid);
                        $subnet_karma = $slashdb->getNetIDKarma("subnetid", $subnetid);
                        $ipid_karma = $slashdb->getNetIDKarma("ipid", $ipid) if $ipid;
                }

                my $clout_types_ar = [ sort grep /\D/, keys %{$slashdb->getCloutTypes} ];

                # Last journal
                my $lastjournal = undef;
                my $lastjournal_title;
                if ($user_edit->{uid}) {
                        if (my $journal = getObject('Slash::Journal', { db_type => 'reader' })) {
                                my $j = $journal->getsByUid($user_edit->{uid}, 0, 1);
                                if ($j && @$j) {
                                        $j = $j->[0];
                                }

                                if ($j && @$j) {
                                        my @field = qw( date article description id posttype tid discussion );
                                        $lastjournal = { };
                                        for my $i (0..$#field) {
                                                $lastjournal->{$field[$i]} = $j->[$i];
                                        }
                                }
                        }
                }

		if ($lastjournal) {

                        $lastjournal->{article} = strip_mode($lastjournal->{article},
                                $lastjournal->{posttype});

                        my $art_shrunk = $lastjournal->{article};
                        my $maxsize = int($constants->{default_maxcommentsize} / 25);
                        $maxsize =  80 if $maxsize <  80;
                        $maxsize = 600 if $maxsize > 600;
                        $art_shrunk = chopEntity($art_shrunk, $maxsize);

                        my $approvedtags_break = $constants->{approvedtags_break} || [];
                        my $break_tag = join '|', @$approvedtags_break;

                        if (scalar(() = $art_shrunk =~ /<(?:$break_tag)>/gi) > 2) {
                                $art_shrunk =~ s/\A
                                (
                                        (?: <(?:$break_tag)> )?
                                        .*?   <(?:$break_tag)>
                                        .*?
                                        <(?:$break_tag)>.*
                                )
                                /$1/six;

                                if (length($art_shrunk) < 15) {
                                        undef $art_shrunk;
                                }
                                $art_shrunk = chopEntity($art_shrunk) if defined($art_shrunk);
                        }

                        if (defined $art_shrunk) {
                                if (length($art_shrunk) < length($lastjournal->{article})) {
                                        $art_shrunk .= " ...";
                                }
                                $art_shrunk = strip_html($art_shrunk);
                                $art_shrunk = balanceTags($art_shrunk);
                        }

                        $lastjournal->{article_shrunk} = $art_shrunk;

                        if ($lastjournal->{discussion}) {
                                $lastjournal->{commentcount} = $slashdb->getDiscussion(
                                        $lastjournal->{discussion}, 'commentcount');
                        }

                        $lastjournal_title =
                                slashDisplay('titlebar', {
                                        title => "Last Journal Entry",
                                }, { Page => 'users', Return => 1 });

                }

                # Submissions
		my $sub_limit = $constants->{submissions_all_page_size};
                my $sub_options = { limit_days => 365 };
                my $latestsubmissions;
                $latestsubmissions = $slashdb->getSubmissionsByUID($user_edit->{uid}, $sub_limit, $sub_options);
                my $submissions =
                        slashDisplay('listSubmissions', {
                                title       => "Recent Submissions",
                                admin_flag  => 1,
                                submissions => $latestsubmissions,
                        }, { Page => 'users', Return => 1 });


                # Tags
                my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });
                my $tagshist = [];
                if ($tags_reader) {
                        $tagshist = $tags_reader->getAllTagsFromUser($user_edit->{uid}, { orderby => 'created_at', orderdir => 'DESC', limit => 30, include_private => 1 });
                }
                my $recent_tags =
                        slashDisplay('usertaghistory', {
                                title => "Recent Tags",
                                tagshist => $tagshist,
                        }, { Page => 'users', Return => 1 });

                # Comments
                my $comments = undef;
                my $commentcount = 0;
                my $commentcount_time = 0;
                my $commentstruct = [];
                my $min_comment = 0;
                my $time_period = $constants->{admin_comment_display_days} || 30;
                my $cid_for_time_period = $slashdb->getVar("min_cid_last_$time_period\_days",'value', 1) || 0;
                my $admin_time_period_limit = $constants->{admin_daysback_commentlimit} || 100;
                my $admin_non_time_limit = $constants->{admin_comment_subsequent_pagesize} || 24;
                my $non_admin_limit = $constants->{user_comment_display_default};

                $commentcount = $slashdb->countCommentsByUID($user_edit->{uid});
                $commentcount_time = $slashdb->countCommentsByUID($user_edit->{uid}, { cid_at_or_after => $cid_for_time_period });
                $comments = $slashdb->getCommentsByUID($user_edit->{uid}, 25, 0);

                my @users_extra_cols_wanted       = qw( nickname );
                my @discussions_extra_cols_wanted = qw( type );
                my $uid_hr = { };
                my $sid_hr = { };

                if ($comments && @$comments) {
                        my %uids = ();
                        my %sids = ();

                        for my $c (@$comments) {
                                $uids{$c->{uid}}++;
                                $sids{$c->{sid}}++;
                        }
                        my $uids = join(", ", sort { $a <=> $b } keys %uids);
                        my $sids = join(", ", sort { $a <=> $b } keys %sids);
                        $uid_hr = $slashdb->sqlSelectAllHashref(
                                "uid",
                                "uid, " . join(", ", @users_extra_cols_wanted),
                                "users",
                                "uid IN ($uids)"
                        );

                        $sid_hr = $slashdb->sqlSelectAllHashref(
                                "id",
                                "id, " . join(", ", @discussions_extra_cols_wanted),
                                "discussions",
                                "id IN ($sids)"
                        );
                }

		my $cids_seen = {};
                my $kinds = $slashdb->getDescriptions('discussion_kinds');
                for my $comment (@$comments) {
                        $cids_seen->{$comment->{cid}}++;
                        my $type;
                        my $replies = $slashdb->countCommentsBySidPid($comment->{sid}, $comment->{cid});
                        my $discussion = $slashdb->getDiscussion($comment->{sid});
                        if (!$discussion || !$discussion->{dkid}) {
                                next;
                        } elsif ($kinds->{ $discussion->{dkid} } =~ /^journal(?:-story)?$/) {
                                $type = 'journal';
                        } elsif ($kinds->{ $discussion->{dkid} } eq 'poll') {
                                $type = 'poll';
                        } else {
                                $type = 'story';
                        }

                        $comment->{points} += $user_edit->{karma_bonus} if $user_edit->{karma_bonus} && $comment->{karma_bonus} eq 'yes';
                        $comment->{points} += $user_edit->{subscriber_bonus} if $user_edit->{subscriber_bonus} && $comment->{subscriber_bonus} eq 'yes';
                        $comment->{points} = $constants->{comment_minscore} if $comment->{points} < $constants->{comment_minscore};
                        $comment->{points} = $constants->{comment_maxscore} if $comment->{points} > $constants->{comment_maxscore};
                        vislenify($comment);

                        my $data = {
                                pid             => $comment->{pid},
                                url             => $discussion->{url},
                                disc_type       => $type,
                                disc_title      => $discussion->{title},
                                disc_time       => $discussion->{ts},
                                sid             => $comment->{sid},
                                cid             => $comment->{cid},
                                subj            => $comment->{subject},
                                cdate           => $comment->{date},
                                pts             => $comment->{points},
                                reason          => $comment->{reason},
                                uid             => $comment->{uid},
                                replies         => $replies,
                                ipid            => $comment->{ipid},
                                ipid_vis        => $comment->{ipid_vis},
                                karma           => $comment->{karma},
                                tweak           => $comment->{tweak},
                                tweak_orig      => $comment->{tweak_orig},

                        };

                        for my $col (@users_extra_cols_wanted) {
                                $data->{$col} = $uid_hr->{$comment->{uid}}{$col} if defined $uid_hr->{$comment->{uid}}{$col};
                        }

                        for my $col(@discussions_extra_cols_wanted) {
                                $data->{$col} = $sid_hr->{$comment->{sid}}{$col} if defined $sid_hr->{$comment->{sid}}{$col};
                        }

                        push @$commentstruct, $data;
                }

		@$commentstruct = sort {
                        $b->{disc_time} cmp $a->{disc_time} || $b->{sid} <=> $a->{sid}
                } @$commentstruct unless $user->{user_comment_sort_type} && $user->{user_comment_sort_type} == 1;

                my $cid_list = [ keys %$cids_seen ];
                my $cids_to_mods = {};
                my $mod_reader = getObject("Slash::$constants->{m1_pluginname}", { db_type => 'reader' });
                if ($constants->{m1} && $constants->{show_mods_with_comments}) {
                        my $comment_mods = $mod_reader->getModeratorCommentLog("DESC", $constants->{mod_limit_with_comments}, "cidin", $cid_list);

                        while (my $mod = shift @$comment_mods) {
                                push @{$cids_to_mods->{$mod->{cid}}}, $mod;
                        }
                }

		my $comments_pane;
                my $comments_title;
                if ($commentcount) {
                        $comments_pane =
                                slashDisplay('listComments', {
                                        admin_flag    => 1,
                                        commentstruct => $commentstruct || [],
                                        commentcount  => $commentcount,
                                        reasons       => $mod_reader->getReasons(),
                                        min_comment   => $min_comment,
                                        cids_to_mods  => $cids_to_mods,
                                        type          => "user",
                                        useredit      => $user_edit,
                                }, { Page => 'users', Return => 1 });

                        $comments_title =
                                slashDisplay('titlebar', {
                                        title => "Comments",
                                }, { Page => 'users', Return => 1 });
                }

		return
                        slashDisplay('prefs_adminblock', {
                                user               => $user,
                                useredit           => $user_edit,
                                field              => $field,
                                userfield          => $userfield,
                                fieldname          => $fieldname,
                                seclev_field       => 1,
                                authoredit_flag    => $authoredit_flag,
                                section_select     => $section_select,
                                thresh_select      => $thresh_select,
                                srcid              => $srcid,
                                all_aclam_ar       => $all_aclam_ar,
                                all_aclam_hr       => $all_aclam_hr,
                                user_aclam_hr      => $user_aclam_hr,
                                al2_old            => $al2_hr,
                                al2_log            => $al2_log_ar,
                                al2_tid_comment    => $al2_tid_comment,
                                al2_nick           => $al2_nick_hr,
                                subnet_karma       => $subnet_karma,
                                ipid_karma         => $ipid_karma,
                                post_restrictions  => $post_restrictions,
                                clout_types_ar     => $clout_types_ar,
                                proxy_check        => $proxy_check,
                                uidstruct          => $uidstruct,
                                ipstruct           => $ipstruct,
                                ipstruct_order     => $ipstruct_order,
                                accesshits         => \@accesshits,
                                lastjournal        => $lastjournal,
                                lastjournal_title  => $lastjournal_title,
                                hr_hours_back      => $constants->{istroll_ipid_hours} || 72,
                                submissions        => $submissions,
                                recent_tags        => $recent_tags,
                                commentcount       => $commentcount,
                                comments_pane      => $comments_pane,
                                comments_title     => $comments_title,
                                tabbed             => $form->{'tabbed'},
                        },
                        { Return => 1 }
                );

	} elsif ($form->{'section'} eq 'logout') {
		return if $user->{is_anon};

		userLogout($user->{uid});

		return
			slashDisplay('logout', {
				tabbed => $form->{'tabbed'},
			}, { Return => 1, Page => 'login'});

	} elsif ($form->{'section'} eq 'changePasswdModal') {
		return if $user->{is_anon};

		return
			slashDisplay('changePasswdModal', {
				tabbed => $form->{'tabbed'},
			}, { Return => 1, Page => 'login'});

	} elsif ($form->{'section'} eq 'sendPasswdModal') {
		my $login_reader = getObject("Slash::Login");
		$login_reader->displaySendPassword($form);

	} elsif ($form->{'section'} eq 'newUserModal') {
		my $login_reader = getObject("Slash::Login");
		$login_reader->displayNewUser($form);

	} elsif ($form->{'section'} eq 'userlogin') {
		my $return_to;
		($return_to = $form->{return_to}) =~ s/https?\://;
		$return_to = strip_urlattr($return_to);

		return
			slashDisplay('userlogin', {
				is_modal  => 1,
				return_to => $return_to,
				tabbed    => $form->{'tabbed'},
			}, { Return => 1, Page => 'login'});

	} else {
		return
			slashDisplay('prefs_' . $form->{'section'}, {
				user   => $user,
                                tabbed => $form->{'tabbed'},
			},
			{ Return => 1 }
		);
	}
}

sub saveModalPrefs {
	my($slashdb, $constants, $user, $form) = @_;

	# Ajax returns our form as key=value, so trick URI into decoding for us.
	require URI;
	my $url = URI->new('//e.a/?' . $form->{'data'});
	my %params = $url->query_form;

	my $reskey = getObject('Slash::ResKey');
	my $rkey;
	if ((caller(1))[3] =~ /\bsaveModalPrefsAnonHC$/) {
		# XXX We should change how values are sent from JS saveModalPrefs() so we
		# don't have to do this.
		$form->{hcanswer} = $params{hcanswer};
		$rkey = $reskey->key('ajax_base_hc');
		$user->{state}{reskey} = $rkey->reskey;

		# Defer use for certain ops.
		$rkey->use unless (($params{formname} eq 'sendPasswdModal') || ($params{formname} eq 'newUserModal'));	
	}

	# D2 display
	my $user_edits_table;
	if ($params{'formname'} eq 'd2_display') {
		$user_edits_table = {
			discussion2        => ($params{'discussion2'})        ? 'slashdot' : 'none',
			# i know the logic here is backward, but it still makes the most sense to me!
			# we only want to save the pref for people who turn it off, but the checkbox
			# is on by default, so if the value is true then it is on, and if false,
			# it is off -- pudge
			d2_reverse_switch     => $params{'d2_reverse_switch'}     ? 1 : undef,
			d2_keybindings_switch => $params{'d2_keybindings_switch'} ? undef : 1,
			d2_comment_q          => $params{'d2_comment_q'}         || undef,
			d2_comment_order      => $params{'d2_comment_order'}     || undef,
			nosigs                => ($params{'nosigs'}              ? 1 : 0),
			noscores              => ($params{'noscores'}            ? 1 : 0),
			domaintags            => ($params{'domaintags'} != 2     ? $params{'domaintags'} : undef),
		};
	}

	# D2 posting
	if ($params{'formname'} eq 'd2_posting') {
		$user_edits_table = {
			emaildisplay      => $params{'emaildisplay'} || undef,
			nobonus           => ($params{'nobonus'} ? 1 : undef),
			nosubscriberbonus => ($params{'nosubscriberbonus'} ? 1 : undef),
			posttype          => $params{'posttype'},
			textarea_rows     => ($params{'textarea_rows'} != $constants->{'textarea_rows'}
				? $params{'textarea_rows'} : undef),
			textarea_cols     => ($params{'textarea_cols'} != $constants->{'textarea_cols'}
				? $params{'textarea_cols'} : undef),
		};
	}

	# Messages
	if ($params{'formname'} eq 'metamoderate') {
		if ($constants->{m2} && $user->{is_admin}) {
			# metaModerate uses $form ... whether it should or not! -- pudge
			@$form{keys %params} = values %params;
			my $metamod_db = getObject('Slash::Metamod');
			$metamod_db->metaModerate($user->{is_admin}) if $metamod_db;
		}
	}

	# Messages
	if ($params{'formname'} eq 'messages') {
		my $messages  = getObject('Slash::Messages');
		my $messagecodes = $messages->getDescriptions('messagecodes');
		my %message_prefs;

		for my $code (keys %$messagecodes) {
			my $coderef = $messages->getMessageCode($code);
			if ((!exists($params{"deliverymodes_$code"})) ||
			    (!$messages->checkMessageUser($code, $slashdb->getUser($params{uid})))) {
				$message_prefs{$code} = -1;
			} else {
				$message_prefs{$code} = fixint($params{"deliverymodes_$code"});
			}
		}

		$messages->setPrefs($params{uid}, \%message_prefs);

		$user_edits_table = {
			message_threshold => $params{'message_threshold'},
		};
	}

	# Generic user
	if ($params{'formname'} eq 'user') {
		my $user_edit = $slashdb->getUser($params{uid});
		my $gSkin = getCurrentSkin();

		# Real Email
		if ($user_edit->{realemail} ne $params{realemail}) {
			if ($slashdb->existsEmail($params{realemail})) {
				$params{realemail} = $user_edit->{realemail};
			}
		}

		# Homepage
		my $homepage = $params{homepage};
		$homepage = '' if $homepage eq 'http://';
		$homepage = fudgeurl($homepage);
		$homepage = URI->new_abs($homepage, $gSkin->{absolutedir})
			       ->canonical
			       ->as_iri if $homepage ne '';
		$homepage = substr($homepage, 0, 100) if $homepage ne '';

		# Calendar
		my $calendar_url = $params{calendar_url};
		if (length $calendar_url) {
			$calendar_url =~ s/^webcal/http/i;
			$calendar_url = fudgeurl($calendar_url);
			$calendar_url = URI->new_abs($calendar_url, $gSkin->{absolutedir})
					   ->canonical
					   ->as_iri if $calendar_url ne '';
			$calendar_url =~ s|^http://||i;
			$calendar_url = substr($calendar_url, 0, 200) if $calendar_url ne '';
		}

		my(%extr, $err_message, %limit);
		$limit{sig} = 120;
		$limit{bio} = $constants->{users_bio_length} || 1024;

		for my $key (keys %limit) {
			my $dat = chopEntity($params{$key}, $limit{$key});
			$dat = strip_html($dat);
			$dat = balanceTags($dat, { deep_nesting => 2, length => $limit{$key} });
			$dat = addDomainTags($dat) if $dat;

			if ($key eq 'sig' && defined($dat) && length($dat) > 200) {
				$extr{sig} = undef;
			}

			if ((length($dat) > 1 && !filterOk('comments', 'postersubj', $dat, \$err_message)) ||
			    (!compressOk('comments', 'postersubj', $dat))) {
				$extr{$key} = undef;
			}
			else {
				$extr{$key} = $dat;
			}
		}

		$user_edits_table = {
			homepage	    => $homepage,
			realname	    => $params{realname},
			calendar_url	    => $calendar_url,
			yahoo		    => $params{yahoo},
			jabber		    => $params{jabber},
			aim		    => $params{aim},
			aimdisplay	    => $params{aimdisplay},
			icq		    => $params{icq},
			mobile_text_address => $params{mobile_text_address},
		};

		if ($constants->{wow}
			&& $form->{wow_main_name}
			&& $form->{wow_main_realm}) {
			my $wowdb = getObject("Slash::WoW");
			if ($wowdb) {
				$user_edits_table->{wow_main_name} = "\L\u$form->{wow_main_name}";
				$user_edits_table->{wow_main_realm} = $form->{wow_main_realm};
				my $charid = $wowdb->getCharidCreate($user_edits_table->{wow_main_realm},
					$user_edits_table->{wow_main_name});
				$wowdb->setChar($charid, { uid => $params{uid} }, { if_unclaimed => 1 })
					if $charid;
			}
		}

		for (keys %extr) {
			$user_edits_table->{$_} = $extr{$_} if defined $extr{$_};
		}

		for (keys %$user_edits_table) {
			$user_edits_table->{$_} = '' unless defined $user_edits_table->{$_};
		}

		if ($user_edit->{realemail} ne $params{realemail}) {
			$user_edits_table->{realemail} = chopEntity($params{realemail}, 50);
			my $new_fakeemail = '';

			if ($user->{emaildisplay}) {
				$new_fakeemail = getArmoredEmail($params{uid}, $user_edits_table->{realemail}) if $user->{emaildisplay} == 1;
				$new_fakeemail = $user_edits_table->{realemail} if $user->{emaildisplay} == 2;
			}
			$user_edits_table->{fakeemail} = $new_fakeemail;
		}

		my $reader = getObject('Slash::DB', { db_type => 'reader' });
		my $otherparams	 = $reader->getDescriptions('otherusersparam');
		for my $param (keys %$otherparams) {
			if (exists $params{$param}) {
				$user_edits_table->{$param} = $user->{$param} = $params{$param} || undef;
			}
		}
	}

	# Sections
	if ($params{'formname'} eq "sectional") {
		setSectionNexusPrefs($slashdb, $constants, $user, \%params);
	}

	# Homepage
	if ($params{'formname'} eq "home") {
		$user_edits_table = {
			maxstories	=> 30,
			lowbandwidth	=> ($params{lowbandwidth}    ? 1 : 0),
			simpledesign	=> ($params{simpledesign}    ? 1 : 0),
			noicons		=> ($params{noicons}	     ? 1 : 0),
			willing		=> ($params{willing}	     ? 1 : 0),
			tags_turnedoff	=> ($params{showtags}	     ? undef : 1),
			opt_osdn_navbar => ($params{opt_osdn_navbar} ? 1 : 0),
			index_classic	=> ($params{index_classic}   ? 1 : undef ),
		};

		if (defined $params{tzcode} && defined $params{tzformat}) {
			$user_edits_table->{tzcode} = $params{tzcode};
			$user_edits_table->{dfid}   = $params{tzformat};
			$user_edits_table->{dst}    = $params{dst};
		}

		if (!isAnon($params{uid}) && !$params{willing}) {
			$slashdb->setUser($params{uid}, { points => 0 });
		}
	}
	
	if ($params{'formname'} eq "fhlayout") {

		if ($form->{reset}) {
			if ($form->{resetsectionmenu}) {
				my $fh = getObject("Slash::FireHose");
				$fh->removeUserSections();
			} else {
				$user_edits_table = {};
				foreach (qw(tags_turnedoff firehose_nocolors firehose_nobylines firehose_nodates firehose_pause firehose_advanced firehose_pagesize index_classic firehose_picker_search firehose_noslashboxes firehose_hide_section_menu disable_ua_check firehose_noautomore firehose_nographics smallscreen lowbandwidth simpledesign)) {
					$user_edits_table->{$_} = undef;
				}
				foreach (qw(noicons dst dfid)) {
					$user_edits_table->{$_} = 0;
				}
				$user_edits_table->{tzcode} = "EST";
			}

		} else {
			$user_edits_table = {
				noicons				=> ($params{showicons} ? undef : 1),
				tags_turnedoff			=> ($params{showtags} ? undef : 1),
				firehose_nocolors		=> ($params{showcolors} ? undef: 1),
				firehose_nobylines		=> ($params{showbylines} ? undef: 1),
				firehose_nodates		=> ($params{showdates} ? undef: 1),
				firehose_advanced		=> ($params{advanced} ? 1 : undef),
				firehose_pagesize		=> ($params{pagesize} ? $params{pagesize} : "small"),
				index_classic			=> ($params{index_classic} ? 1 : undef ),
				firehose_disable_picker_search  => ($params{firehose_disable_picker_search} ? undef : 1),
				smallscreen			=> ($params{smallscreen} ? 1 : undef),
				lowbandwidth			=> ($params{lowbandwidth} ? 1 : undef),
				simpledesign                    => ($params{simpledesign} ? 1 : undef),
				firehose_noslashboxes		=> ($params{noslashboxes} ? undef: 1),
				firehose_hide_section_menu	=> ($params{nosectionmenu} ? undef: 1),
				disable_ua_check		=> ($params{disable_ua_check} ? undef: 1),
				firehose_nographics             => ($params{nographics} ? undef: 1),
				firehose_autoupdate	=> $params{autoupdate},
			};

			if (defined $params{tzcode} && defined $params{tzformat}) {
				$user_edits_table->{tzcode} = $params{tzcode};
				$user_edits_table->{dfid}   = $params{tzformat};
				$user_edits_table->{dst}    = $params{dst};
			}
		}

	}

	if ($params{'formname'} eq "fhview" ) {
		if ($params{viewid}) {
			my $fh = getObject("Slash::FireHose");
			my $view = $fh->getUserViewById($params{viewid});
			my $data = {};
			if ($view) {
				
				# Enforce rules we've set
				if ($view->{viewname} eq "stories") {
					$params{story_check} = 1;
				} elsif ($view->{viewname} eq "recent") {
					$params{other_check} = 1;
					$params{orderby} = "createtime";
					$params{orderdir} = "DESC";
				} elsif ($view->{viewname} eq "popular") {
					$params{orderby} = "popularity";
					$params{orderdir} = "DESC";
				} elsif ($view->{viewname} eq "search" || $view->{viewname} eq "stories") {
					$params{orderby} = "createtime";
					$params{orderdir} = "DESC";
				}
				
				foreach (qw(mode orderby orderdir color)) {
					$data->{$_} = defined $params{$_} ? $params{$_} : $view->{$_};
				}

				if ($user->{is_admin}) {
					foreach (qw(admin_unsigned usermode)) {
						$data->{$_} = $params{$_} ? "yes" : "no";
					}
				} else {
					$data->{usermode} = "yes";
					$data->{admin_unsigned} = "no"
				}
				if ($params{story_check} && $params{other_check}) {
					$data->{datafilter} = '';
				} elsif ($params{other_check} && !$params{story_check})  {
					$data->{datafilter} = "-story";
				} elsif ($params{story_check}) {
					$data->{datafilter} = "story";
				}
			}
			if ($form->{reset}) {
				$fh->removeUserPrefsForView($params{viewid});
			} else {
				$fh->setFireHoseViewPrefs($params{viewid}, $data);
			}
		}
	}

	if ($params{'formname'} eq "slashboxes") {
		my $slashboxes = $user->{slashboxes};
		my($boxes, $skinBoxes) = $slashdb->getPortalsCommon();
		my $default_slashboxes_textlist = join ",",
			@{$skinBoxes->{$constants->{mainpage_skid}}};

		$slashboxes = $default_slashboxes_textlist if !$slashboxes;
		my @slashboxes = split /,/, $slashboxes;
		my %slashboxes = ( );

		for my $i (0..$#slashboxes) {
			$slashboxes{$slashboxes[$i]} = $i;
		}

		for my $key (sort grep /^showbox_/, keys %params) {
			my($bid) = $key =~ /^showbox_(.+)$/;
			next if length($bid) < 1 || length($bid) > 30;
			if (! exists $slashboxes{$bid}) {
				$slashboxes{$bid} = 999;
			}
		}

		for my $bid (@slashboxes) {
			delete $slashboxes{$bid} unless $params{"showbox_$bid"};
		}

                for my $key (sort grep /^dynamic_/, keys %params) {
                        my($bid) = $key =~ /^dynamic_(.+)$/;
                        next if length($bid) < 1;
                        if (! exists $slashboxes{$bid}) {
                                $slashboxes{$bid} = 999;
                        }
                }

		@slashboxes = sort { $slashboxes{$a} <=> $slashboxes{$b} || $a cmp $b } keys %slashboxes;
		$#slashboxes = 19 if $#slashboxes > 19;
		$slashboxes = join ",", @slashboxes;
		$slashboxes = "" if ($slashboxes eq $default_slashboxes_textlist);

		$slashboxes =~ s/[^\w,-]//g;
		my @items = grep { $_ } split /,/, $slashboxes;
		$slashboxes = join ",", @items;

		if (length($slashboxes) > 1024) {
			$slashboxes = substr($slashboxes, 0, 1024);
			$slashboxes =~ s/,?\w*$//g;
		} elsif (length($slashboxes) < 1) {
			$slashboxes = '';
		}

		$user_edits_table->{slashboxes} = $slashboxes;

		$user_edits_table->{mylinks} = balanceTags(strip_html(
			chopEntity($params{mylinks} || '', 255)
		), { deep_nesting => 2, length => 255 });

		$user_edits_table->{mylinks} = '' unless defined $user_edits_table->{mylinks};
		$slashdb->setUser($params{uid}, $user_edits_table);

		return setModalUpdates();
	}

	if ($params{'formname'} eq "authors" || $params{'formname'} eq 'fhexclusions') {
		my $author_hr = $slashdb->getDescriptions('authors');
		my ($story_author_all, @story_never_author);

		for my $aid (sort { $a <=> $b } keys %$author_hr) {
			my $key = "aid$aid";
			$story_author_all++;
			push(@story_never_author, $aid) if ($params{'formname'} eq 'authors' ? !$params{$key} : $params{$key});
		}

		$#story_never_author = 299 if $#story_never_author  > 299;

		my $story_never_author = join(",", @story_never_author);
		$story_never_author =~ s/[^\w,-]//g;
		my @items = grep { $_ } split /,/, $story_never_author;
		$story_never_author = join ",", @items;

		my $len ||= $constants->{checklist_length} || 255;
		if (length($story_never_author) > $len) {
			$story_never_author = substr($story_never_author, 0, $len);
			$story_never_author =~ s/,?\w*$//g;
		} elsif (length($story_never_author) < 1) {
			$story_never_author = '';
		}
		if ($form->{reset}) {
			$user_edits_table = {
				story_never_author => '',
				firehose_exclusions => undef
			};
		} else {
			$user_edits_table = {
				story_never_author => $story_never_author,
				firehose_exclusions => $params{'firehose_exclusions'}
			};
		}
		

	}

	if ($params{'formname'} eq "admin") {
		return if !$user->{is_admin};

		$user_edits_table = {
			test_code         => ($params{'test_code'} ? 1 : undef),
			playing           => $params{playing},
			no_spell          => ($params{'no_spell'} ? 1 : undef),
			mod_with_comm     => ($params{'mod_with_comm'} ? 1 : undef),
			m2_with_mod       => ($params{'m2_with_mod'} ? 1 : undef),
			m2_with_comm_mod  => ($params{'m2_with_mod_on_comm'} ? 1 : undef),
		};
	}

	if ($params{'formname'} eq "firehoseview") {
		return if $user->{is_anon};
		my $fh = getObject("Slash::FireHose");

		my $data = {
			uid 	=> $user->{uid},
			section_name => $params{'section_name'},
			section_color => $params{'section_color'},
			section_filter => $params{'section_filter'},
			view_id	=> $params{'viewid'}
		};
		if (!$params{'id'}) {

			$fh->createFireHoseSection($data);
		} else {
			$fh->setFireHoseSectionPrefs($params{'id'}, $data);
		}
	}

	if ($params{'formname'} eq "adminblock") {
                return if !$user->{is_admin};

                my $user_editfield_flag;
                my $id;
                my $srcid;
                if ($params{'uid'}) {
                        $user_editfield_flag = 'uid';
                        $id = $params{'uid'};
                        $srcid = $id;
                }

                my $all_al2types = $slashdb->getAL2Types;
                my $al2_change = { };
                my @al2_old = ( ); 
                foreach my $param (keys %params) {
                        push(@al2_old, $params{$param}) if ($param =~ /al2_old_multiple\d+/);
                }
                my %al2_old = ( map { ($_, 1) } @al2_old );

                my @acl_old = ( );
                foreach my $param (keys %params) {
                        push(@acl_old, $params{$param}) if ($param =~ /acl_old_multiple\d+/);
                }
                my %acl_old = ( map { ($_, 1) } @acl_old );

                my @al2_new_formfields = ( );
                foreach my $param (keys %params) {
                        push(@al2_new_formfields, $params{$param}) if ($param =~ /aclams_new_multiple\d+/);
                }
                my @al2_new_submitted = map { s/^aclam_//; $_ } @al2_new_formfields;
                my @al2_new = grep { exists $all_al2types->{$_} } @al2_new_submitted;
                my %al2_new = ( map { ($_, 1) } @al2_new );
                my @acl_new = grep { !$al2_new{$_} } @al2_new_submitted;
                my %acl_new = ( map { ($_, 1) } @acl_new );

                for my $al2 (@al2_old, @al2_new) {
                        next if defined($al2_old{$al2}) && defined($al2_new{$al2}) && $al2_old{$al2} == $al2_new{$al2};
                        $al2_change->{$al2} = $al2_new{$al2} ? 1 : 0;
                }

                if ($params{'al2_new_comment'}) {
                        $al2_change->{comment} = $params{'al2_new_comment'};
                }
                $al2_change = undef if !keys %$al2_change;

                my $acl_change = { };
                for my $acl (@acl_old, @acl_new) {
                        next if $acl_old{$acl} == $acl_new{$acl};
                        $acl_change->{$acl} = $acl_new{$acl} ? 1 : 0;
                }
                $acl_change = undef if !keys %$acl_change;

                $slashdb->setAL2($srcid, $al2_change) if ($srcid);

                return if ($user_editfield_flag ne 'uid');

                my $seclev = $params{'seclev'};
                $seclev = $user->{seclev} if $seclev > $user->{seclev};

		$user_edits_table = {
                        seclev                => ($seclev ? $params{'seclev'} : 1),
                        author                => ($params{'author'} ? 1 : 0),
                        section               => $params{'section'},
                        tag_clout             => $params{'tag_clout'},
                        tokens                => $params{'tokens'},
                        m2info                => $params{'m2info'},
                        defaultpoints         => $params{'defaultpoints'},
                        shill_static_marquee  => ($params{'shill_static_marquee'} ? 1 : undef),
                        shill_rss_url         => ($params{'shill_rss_url'} ? $params{'shill_rss_url'} : undef),
                        u2_friends_bios       => ($params{'u2_friends_bios'} ? 1 : undef),

                };

                $user_edits_table->{acl} = $acl_change if $acl_change;

        }

	if ($params{'formname'} eq "changePasswdModal") {
		my $changepass = 0;
                my $error = 0;
                my $error_message = '';

		# inputmode 1: password, cookie, or session
		# inputmode 2: OpenID (not yet implemented)
		if ($params{inputmode} == 1) {
                        if ($params{'pass1'} || $params{'pass2'} || length($params{'pass1'}) || length($params{'pass2'})) {
                                $changepass = 1;
                        }

                        if ($changepass) {
                                if (!$error && ($params{pass1} ne $params{pass2})) {
                                        $error_message = getData('passnomatch');
                                        $error = 1;
                                }

                                if (!$error && (!$params{pass1} || length $params{pass1} < 6)) {
                                        $error_message = getData('passtooshort');
                                        $error = 1;
                                }

                                if (!$error && ($params{pass1} && length $params{pass1} > 20)) {
                                        $error_message = getData('passtoolong');
                                        $error = 1;
                                }

                                if (!$error) {
                                        my $return_uid = $slashdb->getUserAuthenticate($params{uid}, $params{oldpass}, 1);
                                        if (!$return_uid || $return_uid != $params{uid}) {
                                                $error_message = getData('oldpassbad');
                                                $error = 1;
                                        }
                                }
                        }

                        if (!$error) {
                                my $user_save = {};
                                $user_save->{passwd} = $params{pass1} if $changepass;
                                $user_save->{session_login} = $params{session_login};
                                $user_save->{cookie_location} = $params{cookie_location};

                                $slashdb->deleteLogToken($params{uid}, 1);

                                if ($user->{admin_clearpass} && !$user->{state}{admin_clearpass_thisclick}) {
                                        $user_save->{admin_clearpass} = '';
                                }

                                $slashdb->setUser($params{uid}, $user_save);
                                my $cookie = bakeUserCookie($params{uid}, $slashdb->getLogToken($params{uid}, 1));
                                setCookie('user', $cookie, $user_save->{session_login});
                        }

                }

                if ($error_message && $error) {
			my $updates = {
				'modal_message_feedback' => $error_message,
			};

			my $ret = setModalUpdates($updates);
			return $ret;
                }

        }

	if ($params{'formname'} eq 'sendPasswdModal') {
		my $updates = {};
		my $sp_updates = {};
		my $validated_uid = $constants->{anonymous_coward_uid};
		my $validated_nick = '';
		
		my $login_reader = getObject("Slash::Login");
		$sp_updates = $login_reader->sendPassword(\%params, \$validated_uid, \$validated_nick);

		foreach my $update (keys %$sp_updates) {
			$updates->{$update} = $sp_updates->{$update};
		}

		if (!$updates->{error}) {
			$rkey->use;

			if ($rkey->failure) {
				# This seems like a good way to determine if this is an HC retry, but is only
				# valid for 2 failures.
				my $rkey_info = $rkey->get();
				my $note_type = $rkey_info->{failures} ? 'modal_error' : 'modal_warn';

				$updates->{hc_error} = getData('hc_error', { error => $rkey->errstr, note_type => $note_type }, 'login');
				$updates->{unickname_error} = getData('modal_mail_reset_error', {}, 'login');
			} elsif ($user->{state}{hcinvalid}) {
				$updates->{hc_form} = '';
				$updates->{hc_error} = getData('hc_invalid_error', { centered => 1, note_type => 'modal_error' }, 'login');
				$updates->{modal_submit} = getData('submit_to_close', { centered => 1 }, 'login');
			} else {
				# Mail here
				$login_reader->sendMailPasswd($validated_uid);
				$updates->{hc_form} = '';
				$updates->{hc_error} = '';
				$updates->{modal_submit} = getData('submit_to_close', { centered => 1 }, 'login');
				$updates->{unickname} = '';
				$updates->{unickname_label} = '';
				$updates->{unickname_error} = '';
				$updates->{submit_error} = getData('modal_mail_mailed_note', { centered => 1, name => $validated_nick, note_type => 'modal_ok' }, 'login');
			}
		}

		if (keys %$updates) {
			my $ret = setModalUpdates($updates);
			return $ret;
		}
	}

	if ($params{'formname'} eq 'deleteOpenID') {
		my $login = getObject('Slash::Login');
		my $message = $login->deleteOpenID($params{'openid_url'});
		my %updates;
		$updates{changePasswdModal} = slashDisplay('changePasswdModal',
			{ tabbed => 1, openid_message => $message },
			{ Return => 1, Page => 'login'}
		);
		return setModalUpdates(\%updates);
	}

	if ($params{'formname'} eq 'newUserModal') {
		my $updates = {};
                my $returned_updates = {};

                my $login_reader = getObject("Slash::Login");
                $returned_updates = $login_reader->validateNewUserInfo(\%params);

		# New user info validated. Create.
		if (!keys %$returned_updates) {
			# Run HC
			$rkey->use;
			if ($rkey->failure) {
                                my $rkey_info = $rkey->get();
                                my $note_type = $rkey_info->{failures} ? 'modal_error' : 'modal_warn';
                                $updates->{hc_error} = getData('hc_error', { error => $rkey->errstr, note_type => $note_type }, 'login');
                                $updates->{submit_error} = getData('modal_createacct_reset_error', {}, 'login');
                        } elsif ($user->{state}{hcinvalid}) {
                                $updates->{hc_form} = '';
                                $updates->{hc_error} = getData('hc_invalid_error', { centered => 1 }, 'login');
                                $updates->{submit_error} = getData('modal_createacct_reset_error', {}, 'login');
				$updates->{faq_link} = '';
                                $updates->{modal_submit} = getData('submit_to_close', { centered => 1 }, 'login');
			} else {
				# HC was successful. Attempt create.
				$returned_updates = $login_reader->createNewUser($user, \%params);
			}
		}

		foreach my $update (keys %$returned_updates) {
                        $updates->{$update} = $returned_updates->{$update};
                }

		$updates->{nickname_error} = getData('modal_createacct_reset_nickname_error', {}, 'login');
		$updates->{openidform} = '';

                if (keys %$updates) {
                        my $ret = setModalUpdates($updates);
                        return $ret;
                }
	}

	if ($params{'formname'} ne "sectional"         &&
	    $params{'formname'} ne "firehoseview"      &&
	    $params{'formname'} ne "changePasswdModal" &&
	    $params{'formname'} ne "sendPasswdModal"   &&
	    $params{'formname'} ne "newUserModal") {
		$slashdb->setUser($params{uid}, $user_edits_table);
	}
}

sub setModalUpdates {
	my($updates) = @_;

	my $user = getCurrentUser();

	my $reskey_resource = 'ajax_user';
	if ((caller(2))[3] =~ /\bsaveModalPrefsAnon(HC)?$/) {
		$reskey_resource = $1 ? 'ajax_base_hc' : 'ajax_base';
	}

	if ($reskey_resource ne 'ajax_base_hc') {
		my $reskey = getObject('Slash::ResKey');
		my $rkey = $reskey->key($reskey_resource, { nostate => 1 });
		$rkey->create;

		if ($rkey->failure) {
			# XXX need to handle errors, esp. for HC
			# XXX Set a 'critical error' form element with a message and disable the input button? -Cbrown
			return;
		} else {
			$user->{state}{reskey} = $rkey->reskey;
		}
	}

	# Refresh the reskey
	$updates->{reskey} = slashDisplay('reskey_tag', {}, { Return => 1 });

	return Data::JavaScript::Anon->anon_dump({ html_replace => $updates });
}

sub getModalPrefsAnon {
	&getModalPrefs;
}
sub saveModalPrefsAnon {
	&saveModalPrefs;
}
sub getModalPrefsAnonHC {
	&getModalPrefs;
}
sub saveModalPrefsAnonHC {
	&saveModalPrefs;
}

sub editPreview {
	my($slashdb, $constants, $user, $form, $options) = @_;

	my $edit = getObject("Slash::Edit");
	my $rkey = $edit->rkey;
	my $errors = {};
	unless ($rkey->touch) { # XXX show editor on reskey error?
		$errors->{critical}{save_error} = $rkey->errstr;
	}

	$edit->savePreview;
	my $html;
	$html->{editor} = $edit->showEditor({ errors => $errors, previewing => 1, nowrap => 1});

	return Data::JavaScript::Anon->anon_dump({ html => $html });
}

sub editReset {
	my($slashdb, $constants, $user, $form, $options) = @_;

	my $edit = getObject("Slash::Edit");
	$edit->initEditor();

	my $html;
	$html->{editor} = $edit->showEditor({ previewing => 1, nowrap => 1});

	return Data::JavaScript::Anon->anon_dump({ html => $html });
}


sub editSave {
	my($slashdb, $constants, $user, $form, $options) = @_;

	my $edit = getObject("Slash::Edit");
	my $rkey = $edit->rkey;
	$edit->savePreview;
	my($retval, $type, $save_type, $errors, $preview) = $edit->saveItem($rkey);

	my($editor, $id);
	my $saved_item;
	my $item;
	if ($retval) {
		$id = $retval;
		my $num_id = $id;
		$num_id = $slashdb->getStoidFromSidOrStoid($id)  if ($type eq 'story');
		my $fh = getObject("Slash::FireHose");
		$item = $fh->getFireHoseByTypeSrcid($type, $num_id);
		my $options = { mode => 'full' };
		$options->{options} = { user_view_uid => $item->{uid} } if $type eq 'journal';
		$options->{options}{no_collapse} = 1 if $form->{state} ne 'inline';
		$saved_item = $fh->dispFireHose($item, $options);
		$saved_item .= slashDisplay("init_sprites", { sprite_root_id => 'editpreview'}, { Return => 1}) if $constants->{use_sprites};

	} else {
		$editor = $edit->showEditor({ errors => $errors, nowrap => 1 });
	}
	my $html;
	my($eval_first, $eval_last, $html_add_after, $html_add_before, $html_append) = ('','',{},{}, {});
	if ($editor) {
		$html->{editor} = $editor;
	} else {
		if ($form->{state} eq 'inline') {
			if ($preview->{src_fhid}) {
				$html_add_after->{"title-$preview->{src_fhid}"} = slashDisplay('editsave', { editor => $editor, id => $id, save_type => $save_type, type => $type, saved_item => $saved_item, no_display_item => 1, state => $form->{state} }, { Return => 1, Page => 'edit' });
			}
			$eval_first = "\$('#firehose-$item->{id}').remove(); \$('.edithidden').show().removeClass('edithidden');";
			$html_add_before->{editor} = $saved_item;
			$eval_last = "\$('#editor').remove(); use_sprites('#firehoselist')";
		} else {
			$html->{editor} = slashDisplay('editsave', { editor => $editor, id => $id, save_type => $save_type, type => $type, saved_item => $saved_item, state => $form->{state} }, { Return => 1, Page => 'edit' });
		}
	}
	return Data::JavaScript::Anon->anon_dump({
		html => $html,
		eval_first => $eval_first,
		eval_last => $eval_last,
		html_add_before => $html_add_before,
		html_add_after => $html_add_after,
		html_append => $html_append
	});
}

###################


##################################################################
sub default { }

##################################################################
sub getOps {
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();

	my $table_cache         = "_ajaxops_cache";
	my $table_cache_time    = "_ajaxops_cache_time";
	$slashdb->_genericCacheRefresh('ajaxops', $constants->{block_expire});
	if ($slashdb->{$table_cache_time} && $slashdb->{$table_cache}) {
		return $slashdb->{$table_cache};
	}

	my $ops = $slashdb->sqlSelectAllHashref(
		'op', 'op, class, subroutine, reskey_name, reskey_type', 'ajax_ops'
	);

	my %mainops = (
		comments_submit_reply  => {
			function        => \&submitReply,
			reskey_name     => 'comments',
			reskey_type     => 'touch',
		},
		comments_preview_reply  => {
			function        => \&previewReply,
			reskey_name     => 'comments',
			reskey_type     => 'touch',
		},

		edit_preview => {
			function	=> \&editPreview,
			reskey_name	=> 'NA',
			reskey_type	=> 'touch',
		},

		edit_reset => {
			function	=> \&editReset,
			reskey_name	=> 'ajax_base',
			reskey_type	=> 'createuse',
		},

		edit_save => {
			function	=> \&editSave,
			reskey_name	=> 'NA',
			reskey_type	=> 'touch',
		},

		comments_reply_form     => {
			function        => \&replyForm,
			reskey_name     => 'ajax_base',
			reskey_type     => 'createuse',
		},

		comments_read_rest      => {
			function        => \&readRest,
			reskey_name     => 'ajax_base',
			reskey_type     => 'createuse',
		},
		comments_fetch          => {
			function        => \&fetchComments,
			reskey_name     => 'ajax_base',
			reskey_type     => 'createuse',
		},
		comments_set_prefs      => {
			function        => \&updateD2prefs,
			reskey_name     => 'ajax_user_static',
			reskey_type     => 'createuse',
		},
		getSectionPrefsHTML     => {
			function        => \&getSectionPrefsHTML,
			reskey_name     => 'ajax_user',
			reskey_type     => 'createuse',
		},
		setSectionNexusPrefs    => {
			function        => \&setSectionNexusPrefs,
			reskey_name     => 'ajax_user',
			reskey_type     => 'createuse',
		},
#		tagsGetUserStory        => {
#			function        => \&tagsGetUserStory,
#			reskey_type     => 'createuse',
#		},
#		tagsCreateForStory      => {
#			function        => \&tagsCreateForStory,
#			reskey_type     => 'createuse',
#		},
		getModalPrefs           => {
			function        => \&getModalPrefs,
			reskey_name     => 'ajax_user_static',
			reskey_type     => 'createuse',
		},
		getModalPrefsAnon       => {
			function        => \&getModalPrefsAnon,
			reskey_name     => 'ajax_base_static',
			reskey_type     => 'createuse',
		},
		getModalPrefsAnonHC     => {
			function        => \&getModalPrefsAnonHC,
			reskey_name     => 'ajax_base_static',
			reskey_type     => 'createuse',
		},
		saveModalPrefs          => {
			function        => \&saveModalPrefs,
			reskey_name     => 'ajax_user',
			reskey_type     => 'use',
		},
		saveModalPrefsAnon      => {
			function        => \&saveModalPrefsAnon,
			reskey_name     => 'ajax_base',
			reskey_type     => 'use',
		},
		saveModalPrefsAnonHC    => {
			function        => \&saveModalPrefsAnonHC,
			reskey_name     => 'ajax_base_hc',
			reskey_type     => 'touch',
		},
		default	=> {
			function        => \&default,
		},
	);

	for (keys %mainops) {
		$ops->{$_} ||= $mainops{$_};
	}

	if ($slashdb->{$table_cache_time}) {
		$slashdb->{$table_cache} = $ops;
	}

	return $ops;
}

##################################################################
createEnvironment();
main();
1;

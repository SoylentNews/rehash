#!/usr/bin/perl
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use warnings;

use Data::JavaScript::Anon;

use Slash 2.003;	# require Slash 2.3.x
use Slash::Display;
use Slash::Utility;
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

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

#$Slash::ResKey::DEBUG = 2;

	$ops->{$op}{function} ||= loadCoderef($ops->{$op}{class}, $ops->{$op}{subroutine});
	$op = 'default' unless $ops->{$op}{function};

#	print STDERR "AJAX4 $$: $user->{uid}, $op\n";

	$form->{op} = $op;  # save for others to use

	my $reskey_name = $ops->{$op}{reskey_name} || 'ajax_base';
	$ops->{$op}{reskey_type} ||= 'use';

#	print STDERR "AJAX5 $$: $user->{uid}, $op\n";

	if ($reskey_name ne 'NA') {
		my $reskey = getObject('Slash::ResKey');
		my $rkey = $reskey->key($reskey_name);
		if (!$rkey) {
			print STDERR scalar(localtime) . " ajax.pl main no rkey for op='$op' name='$reskey_name'\n";
			return;
		}
		if ($ops->{$op}{reskey_type} eq 'createuse') {
			$rkey->createuse;
		} else {
			$rkey->use;
		}
		if (!$rkey->success) {
			if ($form->{msgdiv}) {
				header_ajax({ content_type => 'application/json' });
				(my $msgdiv = $form->{msgdiv}) =~ s/[^\w-]+//g;
				print Data::JavaScript::Anon->anon_dump({
					html	=> { $msgdiv => $rkey->errstr },
				});
			}
			printf STDERR "AJAXE %d: UID:%d, op:%s: %s (%s:%s:%s:%s:%s:%s:%s)\n",
				$$, $user->{uid}, $op, $rkey->errstr, $rkey->reskey,
				$rkey->type, $rkey->resname, $rkey->rkrid, $rkey->code, $rkey->static,
				$user->{srcids}{ 24 };
			return;
		}
	}
#	print STDERR "AJAX6 $$: $user->{uid}, $op\n";

	my $options = {};
	my $retval = $ops->{$op}{function}->(
		$slashdb, $constants, $user, $form, $options
	);

#	print STDERR "AJAX7 $$: $user->{uid}, $op ($retval)\n";

	if ($retval) {
		header_ajax($options);
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

	return slashDisplay("sectionpref",
		{
			nexusref		=> $nexus_hr,
			nexustid_order		=> \@nexustid_order,
			story023_default	=> \%story023_default,
			multiple_values		=> $multiple_values,
			master_value		=> $master_value,
		},
		{ Return => 1 }
	);
}

sub setSectionNexusPrefs() {
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

	return getData('set_section_prefs_success_msg');
}

###################
# comments

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

	my $cids         = [ grep /^\d+$/, split /,/, ($form->{cids} || '') ];
	my $id           = $form->{discussion_id} || 0;
	my $cid          = $form->{cid} || 0; # root id
	my $d2_seen      = $form->{d2_seen};
	my $placeholders = $form->{placeholders};
	my @placeholders;

	$user->{state}{ajax_accesslog_op} = "ajax_comments_fetch";
#use Data::Dumper; print STDERR Dumper [ $cids, $id, $cid, $d2_seen ];
	# XXX error?
	return unless $id && (@$cids || $d2_seen);

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

	my %seen;
	if ($d2_seen || $form->{d2_seen_ex}) {
		my $lastcid = 0;
		for my $cid (split /,/, $d2_seen || $form->{d2_seen_ex}) {
			$cid = $lastcid ? $lastcid + $cid : $cid;
			$seen{$cid} = 1;
			$lastcid = $cid;
		}
		if ($d2_seen) {
			$select_options{existing} = \%seen if keys %seen;
			delete $select_options{no_d2};
		}
	}

	my($comments) = Slash::selectComments(
		$discussion,
		$cid,
		\%select_options,
	);

	# XXX error?
	return unless $comments && keys %$comments;

	my $d2_seen_0 = $comments->{0}{d2_seen} || '';
	#delete $comments->{0}; # non-comment data

	my %data;
	if ($d2_seen || $placeholders) {
		my $special_cids;
		if ($d2_seen) {
			$special_cids = $cids = [ sort { $a <=> $b } grep { $_ && !$seen{$_} } keys %$comments ];
		} elsif ($placeholders) {
			@placeholders = split /[,;]/, $placeholders;
			$special_cids = [ sort { $a <=> $b } @placeholders ];
			if ($form->{d2_seen_ex}) {
				my @seen;
				my $lastcid = 0;
				my %check = (%seen, map { $_ => 1 } @placeholders);
				for my $cid (sort { $a <=> $b } keys(%check)) {
					push @seen, $lastcid ? $cid - $lastcid : $cid;
					$lastcid = $cid;
				}
				$d2_seen_0 = join ',', @seen;
			}
		}

		if (@$special_cids) {
			my @cid_data = map {{
				uid    => $comments->{$_}{uid},
				pid    => $comments->{$_}{pid},
				points => $comments->{$_}{points},
				kids   => []
			}} @$special_cids;

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
		$html{'comment_' . $cid} = Slash::dispComment($comments->{$cid}, {
			noshow_show => 1,
			pieces      => $get_pieces_cids{$cid}
		});
	}

	for my $cid (@pieces_cids) {
		@html{'comment_otherdetails_' . $cid, 'comment_sub_' . $cid} =
			Slash::dispComment($comments->{$cid}, {
				show_pieces => 1
			});
	}

	for my $cid (@abbrev_cids) {
		@html_append_substr{'comment_body_' . $cid} = substr($comments->{$cid}{comment}, $abbrev{$cid});
	}

# XXX update noshow_comments, pieces_comments -- pudge
#use Data::Dumper; print STDERR Dumper \@hidden_cids, \@pieces_cids, \@abbrev_cids, \%get_pieces_cids, \%keep_hidden, \%pieces, \%abbrev, \%html, \%html_append_substr, $form, \%data;

	$options->{content_type} = 'application/json';
	my %to_dump = (
		update_data        => \%data,
		html               => \%html,
		html_append_substr => \%html_append_substr
	);
	if ($d2_seen_0) {
		my $total = $slashdb->countCommentsBySid($id);
		$total -= $d2_seen_0 =~ tr/,//; # total
		$total--; # off by one
		$to_dump{eval_first} ||= '';
		$to_dump{eval_first} .= "d2_seen = '$d2_seen_0'; updateMoreNum($total);";
	}
	if ($placeholders) {
		$to_dump{eval_first} ||= '';
		$to_dump{eval_first} .= "placeholder_no_update = " . Data::JavaScript::Anon->anon_dump({ map { $_ => 1 } @placeholders }) . ';';
	}
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
				bvdeliverymodes => $bvdeliverymodes
			},
			{ Return => 1 }
		);
	} else {
		return
			slashDisplay('prefs_' . $form->{'section'}, {
				user => $user,
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

	# Specific to D2 display and posting prefs for the time being.
	my $user_edits_table;
	if ($params{'formname'} eq 'd2_display') {
		$user_edits_table = {
			discussion2       => ($params{'discussion2'})        ? 'slashdot' : 'none',
			d2_comment_q      => $params{'d2_comment_q'}         || undef,
			d2_comment_order  => $params{'d2_comment_order'}     || undef,
			nosigs            => ($params{'nosigs'}              ? 1 : 0),
			noscores          => ($params{'noscores'}            ? 1 : 0),
			domaintags        => ($params{'domaintags'} != 2     ? $params{'domaintags'} : undef),
			m2_with_comm_mod  => ($params{'m2_with_mod_on_comm'} ? 1 : undef),
		};
	}

	if ($params{'formname'} eq 'd2_posting') {
		my $karma_bonus      = ($params{'karma_bonus'}      !~ /^[\-+]?\d+$/) ? "+1" : $params{'karma_bonus'};
		my $subscriber_bonus = ($params{'subscriber_bonus'} !~ /^[\-+]?\d+$/) ? "+1" : $params{'subscriber_bonus'};

		$user_edits_table = {
			emaildisplay      => $params{'emaildisplay'} || undef,
			karma_bonus       => ($karma_bonus ne '+1' ? $karma_bonus : undef),
			nobonus           => ($params{'nobonus'} ? 1 : undef),
			subscriber_bonus  => ($subscriber_bonus || undef),
			nosubscriberbonus => ($params{'nosubscriberbonus'} ? 1 : undef),
			posttype          => $params{'posttype'},
			textarea_rows     => ($params{'textarea_rows'} != $constants->{'textarea_rows'}
				? $params{'textarea_rows'} : undef),
			textarea_cols     => ($params{'textarea_cols'} != $constants->{'textarea_cols'}
				? $params{'textarea_cols'} : undef),
			postanon          => ($params{'postanon'} ? 1 : undef),
			no_spell          => ($params{'no_spell'} ? 1 : undef),
		};
	}

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

	$slashdb->setUser($params{uid}, $user_edits_table);
}

# comments
###################


##################################################################
sub default { }

##################################################################
sub header_ajax {
	my($options) = @_;
	my $ct = $options->{content_type} || 'text/plain';

	my $r = Apache->request;
	$r->content_type($ct);
	$r->header_out('Cache-Control', 'no-cache');
	$r->send_http_header;
}

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
		saveModalPrefs          => {
			function        => \&saveModalPrefs,
			reskey_name     => 'ajax_user_static',
			reskey_type     => 'createuse',
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

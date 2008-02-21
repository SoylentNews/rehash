#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants qw(:messages :strip);
use Slash::Display;
use Slash::Utility;
use Slash::Hook;

##################################################################
sub main {
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $gSkin = getCurrentSkin();

	my $error_flag = 0;
	my $postflag = $user->{state}{post};

	my $op = lc($form->{op}) || '';

	my($formkey, $stories);

	######################################################
	my $ops	= {
		# there will only be a discussions creation form if 
		# the user is anon, or if there's an sid, therefore, we don't want 
		# a formkey if it's not a form 
		display		=> { 
			function		=> \&displayComments,
			seclev			=> 0,
			formname		=> 'discussions',
			checks			=> ($form->{sid} || $user->{is_anon}) ? [] : ['generate_formkey'],
		},
		change		=> { 
			function		=> \&displayComments,
			seclev			=> 0,
			formname		=> 'discussions',
			checks			=> ($form->{sid} || $user->{is_anon}) ? [] : ['generate_formkey'],
		},
		moderate		=> {
			function		=> \&moderate,
			seclev			=> 1,
			post			=> 1,
			formname		=> 'moderate',
			checks			=> ['generate_formkey'],        
		},
		reply			=> {
			function		=> \&editComment,
			formname 		=> 'comments',
			seclev			=> 0,
			checks			=> 
			[ qw ( max_post_check generate_formkey ) ],
		},
		edit 			=> {
			function		=> \&editComment,
			seclev			=> 0,
			formname 		=> 'comments',
			checks			=> 
			[ qw ( max_post_check update_formkeyid generate_formkey ) ],
		},
		preview => {
			function		=> \&editComment,
			seclev			=> 0,
			formname 		=> 'comments',
			checks			=> 
			[ qw ( update_formkeyid max_post_check ) ], 
		},
		post 			=> {
			function		=> \&editComment,
			seclev			=> 0,
			formname 		=> 'comments',
			checks			=> 
			[ qw ( update_formkeyid max_post_check generate_formkey	) ],
		},
		submit => {
			function		=> \&submitComment,
			seclev			=> 0,
			post			=> 1,
			formname 		=> 'comments',
			checks			=> 
			[ qw ( response_check update_formkeyid max_post_check valid_check interval_check formkey_check ) ],
		},
	};
	$ops->{default} = $ops->{display};

	if ($op =~ /^(?:creator_index|personal_index|user_created_index|index|create_discussion|delete_forum)/) {
		redirect($gSkin->{rootdir} . '/journal.pl');
		return;
	}

	if ($op eq 'setdiscussion2') {
		setDiscussion2($form, $slashdb, $user, $constants, $gSkin);
		return;
	}

	# This is here to save a function call, even though the
	# function can handle the situation itself
	my($discussion, $section);

	my $future_err = 0;
	if ($form->{sid}) {
		# SID compatibility
		if ($form->{sid} !~ /^\d+$/) {
			$discussion = $slashdb->getDiscussionBySid($form->{sid});
			$section = $discussion->{section};
			if ($constants->{tids_in_urls}) {
				my $tids = $slashdb->getTopiclistForStory($form->{sid});
				my $tid_string = join('&amp;tid=', @$tids);
				$user->{state}{tid} = $tid_string;
			}
		} else {
			$discussion = $slashdb->getDiscussion($form->{sid});
			$section = $discussion->{section};
			if ($constants->{tids_in_urls}) {
				# This is to get tid in comments. It would be a mess to
				# pass it directly to every comment -Brian
				$user->{state}{tid} = $discussion->{topic};
			}
		}

		my $kinds = $slashdb->getDescriptions('discussion_kinds');

		# Now check to make sure this discussion can be seen.
		if (!( $user->{author} || $user->{is_admin} || $user->{has_daypass} )
			&& $discussion && $kinds->{ $discussion->{dkid} } eq 'story') {
			my $null_it_out = 0;

			# The is_future field isn't automatically added by getDiscussion
			# like it is with getStory.  We have to add it manually here.
			$discussion->{is_future} = 1 if $slashdb->checkDiscussionIsInFuture($discussion);

			if ($discussion->{is_future}) {
				# Discussion is from the future;  decide here
				# whether the user is allowed to see it or not.
				# If not, we'll present the error a bit later.
				if (!$constants->{subscribe} || !$user->{is_subscriber}) {
					$future_err = 1;
					$null_it_out = 1;
					#XXXSECTIONTOPICS verify checkStoryViewable is still correct 
				} elsif (!$slashdb->checkStoryViewable($discussion->{sid})) {
					# If a discussion is in the future, it can only be
					# viewed if it's attached to a story (not a journal
					# etc.) and if that story is viewable.
					$future_err = 1;
					$null_it_out = 1;
				} elsif (!$user->{is_subscriber} || !$user->{state}{page_plummy}) {
					# If the user is not a subscriber or the page is
					# not able to have plums, sorry!
					$future_err = 1;
					$null_it_out = 1;
				}
				#XXXSECTIONTOPICS verify checkStoryViewable is still correct 
			} elsif ($discussion->{sid} && !$slashdb->checkStoryViewable($discussion->{sid})) {
				# Probably a Never Display'd story.
				$null_it_out = 1;
			}
			if ($null_it_out) {
				$form->{sid} = '';
				$discussion = '';
				$op = 'default';
				$section = '';
			}
		}
	}

	$form->{pid} ||= "0";

	# this is so messed up ... it's done again under header(), but
	# sometimes we need it done before header() is called, because,
	# like i said, this is so messed up ...
	{
		my $skid;
		if ($section) {
			my $skin = $slashdb->getSkin($section);
			$skid = $skin->{skid} if $skin;
		}
		setCurrentSkin($skid || determineCurrentSkin());
		Slash::Utility::Anchor::getSkinColors();
	}


	# If this is a comment post, we can't write the header yet,
	# because submitComment() _may_ want to do a redirect
	# instead of emitting a webpage.

	my $header_emitted = 0;
	my $title = $discussion ? $discussion->{'title'} : 'Comments';
	if ($op ne 'submit') {
		header($title, $section) or return;
		$header_emitted = 1;
	}

#print STDERR scalar(localtime) . " $$ A op=$op header_emitted=$header_emitted\n";

	if ($user->{is_anon} && $form->{upasswd} && length($form->{upasswd}) > 1) {
		if (!$header_emitted) {
			header($title, $section) or return;
			$header_emitted = 1;
		}
		print getError('login error');
		$op = 'preview';
	}
	$op = 'default' if
		   !$ops->{$op}
		|| !$ops->{$op}{function}
		|| $user->{seclev} < $ops->{$op}{seclev}
		|| !$postflag && $ops->{$op}{post};

	if ($future_err) {
		if (!$header_emitted) {
			header($title, $section) or return;
			$header_emitted = 1;
		}
		print getError("nosubscription");
	}

#print STDERR scalar(localtime) . " $$ B op=$op header_emitted=$header_emitted\n";

	# Admins don't jump through these formkey hoops.
	if ($user->{is_admin}) {
		my @checks = @{$ops->{$op}{checks}};
		@checks = grep
			!/^(response|interval|max_post)_check$/,
			@checks;
		@{$ops->{$op}{checks}} = @checks;
	}

	# Admins should only jump through the remaining formkey hoops
	# if this var is set.  (Should we leave this as a seclev<100
	# check, or just check {is_admin}?)
	my $formkey_msg = "";
	if ($constants->{admin_formkeys} || $user->{seclev} < 100) {
		$formkey = $form->{formkey};

		# this is needed for formkeyHandler to print the correct messages 
		# yeah, the next step is to loop through the array of $ops->{$op}{check}
		my $formname;
		my $options = {};

		# Disable HumanConf, if...
		$options->{no_hc} = 1 if
				# HumanConf is not running...
			   !$constants->{plugin}{HumanConf}
			|| !$constants->{hc}
				# ...or it's turned off for comments...
			|| $constants->{hc_sw_comments} == 0
				# ...or it's turned off for logged-in users
				# and this user is logged-in...
			|| $constants->{hc_sw_comments} == 1
			   && !$user->{is_anon}
				# ...or it's turned off for logged-in users
				# with high enough karma, and this user
				# qualifies.
			|| $constants->{hc_sw_comments} == 2
			   && !$user->{is_anon}
			   &&  $user->{karma} > $constants->{hc_maxkarma};
 
		my $done = 0;
		DO_CHECKS: while (!$done) {
			$formname = $ops->{$op}{formname}; 
			for my $check (@{$ops->{$op}{checks}}) {
				$ops->{$op}{update_formkey} = 1 if $check eq 'formkey_check';
				$error_flag = formkeyHandler($check, $formname, $formkey,
					\$formkey_msg, $options);
				# If there was an error, we have it stored in $formkey_msg
				# instead of printed directly.  Now that we know whether
				# there was one or not, we can print the header if need be
				# and then print the msg if need be.
				if ($error_flag) {
					if (!$header_emitted) {
						header($title, $section) or return;
						$header_emitted = 1;
					}
#print STDERR scalar(localtime) . " $$ B2 op=$op header_emitted=$header_emitted formkey_msg='$formkey_msg'\n";
					print $formkey_msg;
				}
				if ($error_flag == -1) {
					# Special error:  submit failed, go back to     
					# previewing.  If the error was retryable,
					# they get another chance to do human
					# confirmation right.  Otherwise they still
					# go through "preview" but after
					# reloadFormkeyHC gets called below,
					# {state}{hcinvalid} will be 1 which means
					# no way to continue.
					$op = 'preview';
					$error_flag = 0;
					next DO_CHECKS;
				} elsif ($error_flag) {
					# Genuine error, no need for more checks.
					$done = 1;
					last;
				}
			}
			# All checks passed.
			$done = 1;
		}

		if (!$error_flag && !$options->{no_hc}) {
			# If this formkey has HC associated, pull its info from the DB
			# so we can redisplay the question and image (or whatever).
			# reloadFormkeyHC() sets $form->{question} and $form->{html}
			# just like validFormkeyHC() does when called from the
			# generate_formkey op of formkeyHandler().
			my $hc = getObject("Slash::HumanConf");
			$hc->reloadFormkeyHC($formname) if $hc;
		}
	}

#print STDERR scalar(localtime) . " $$ C op=$op header_emitted=$header_emitted\n";

	if (!$error_flag) {
		# CALL THE OP
		my $retval = $ops->{$op}{function}->($form, $slashdb, $user, $constants, $discussion);

		# this has to happen - if this is a form that you updated
		# the formkey val ('formkey_check') you need to call
		# updateFormkey to update the timestamp (time of successful
		# submission) and note: maxCid and length aren't really
		# required - this is legacy from when formkeys was comments
		# specific, but it can't hurt to put some sort of length
		# in there.. perhaps the length of the primary field in
		# your form would be a good choice.
		if ($ops->{$op}{update_formkey}) {
			if ($retval) {
				my $field_length = $form->{postercomment}
					? length($form->{postercomment})
					: 0;

				# do something with updated? ummm.
				my $updated = $slashdb->updateFormkey($formkey, $field_length); 

			# updateFormkeyVal updated the formkey before the
			# function call, but the form somehow had an error
			# in the function it called unrelated to formkeys
			# so reset the formkey because this is _not_
			# a successful submission
			} else {
				my $updated = $slashdb->resetFormkey($formkey);
			}
		}
	}

	writeLog($form->{sid});

	footer();
}


#################################################################
sub _buildargs {
	my($form) = @_;
	my $uri;

	for (qw[op topic section all]) {
		my $x = "";
		$x =  $form->{$_} if defined $form->{$_} && $x eq "";
		$x =~ s/ /+/g;
		$uri .= "$_=$x&" unless $x eq "";
	}
	$uri =~ s/&$//;

	return fixurl($uri);
}

#################################################################
# this groups all the errors together in
# one template, called "errors;comments;default"
# Why not just getData??? -Brian
sub getError {
	my($value, $hashref, $nocomm) = @_;
	$hashref ||= {};
	$hashref->{value} = $value;
	return slashDisplay('errors', $hashref,
		{ Return => 1, Nocomm => $nocomm });
}

##################################################################
sub delete {
	my($form, $slashdb, $user, $constants) = @_;

	titlebar("100%", getData('deletecid'));

	my $delCount = deleteThread($form->{sid}, $form->{cid});

	$slashdb->setDiscussionDelCount($form->{sid}, $delCount);
	$slashdb->setStory($form->{sid}, { writestatus => 'dirty' });
}


##################################################################
sub displayComments {
	my($form, $slashdb, $user, $constants, $discussion) = @_;

	if (defined $form->{'savechanges'} && !$user->{is_anon}) {
		$slashdb->setUser($user->{uid}, {
			threshold	=> $user->{threshold},
			mode		=> $user->{mode},
			commentsort	=> $user->{commentsort}
		});
	}

	if ($constants->{m2} && defined($form->{show_m2s}) && $user->{is_admin}) {
		$slashdb->setUser($user->{uid},
			{ m2_with_comm_mod => $form->{show_m2s} });
	}

	if ($form->{cid}) {
		# Here is the deal, if a user who has a mode of nocomment asks for a 
		# comment we give it to them and assume the default mode (which 
		# according to the schema is 'thread'). -Brian
		$user->{mode} = 'thread' if $user->{mode} eq 'nocomment';
		printComments($discussion, $form->{cid}, $form->{cid});
	} elsif ($form->{sid}) {
		printComments($discussion, $form->{pid});
	} else {
		print getData('try_journals');
	}
}


##################################################################
# Welcome to one of the ancient beast functions.  The comment editor
# is the form in which you edit a comment.
sub editComment {
	my($form, $slashdb, $user, $constants, $discussion, $error_message) = @_;

	my $preview;
	my $error_flag = 0;
	my $label = getData('label');

	$form->{nobonus}  = $user->{nobonus}	unless $form->{nobonus_present};
	$form->{postanon} = $user->{postanon}	unless $form->{postanon_present};
	$form->{nosubscriberbonus} = $user->{is_subscriber} && $user->{nosubscriberbonus}
						unless $form->{nosubscriberbonus_present};

	if ($form->{lookup_sid}) {
		slashHook('comment_reply_lookup_sid', {} );
	}
	# The sid param is only stripped down to A-Za-z0-9/._ by
	# filter_params;  make sure it's numeric and exists.
	my $sid = $form->{sid};
	if ($sid) { $sid =~ /(\d+)/; $sid = $1 }
	if (!$sid) {
		# Need a discussion ID to reply to, or there's no point.
		print getError('no sid');
		return;
	}

	# Get the comment we may be responding to. Remember to turn off
	# moderation elements for this instance of the comment.
	my $pid = $form->{pid} || 0; # this is guaranteed numeric, from filter_params
	my $reply = $slashdb->getCommentReply($sid, $pid) || { };
	my $pid_reply = '';

	# An attempt to reply to a comment that doesn't exist is an error.
	if ($pid && !%$reply) {
		print getError('no such parent');
		return;
	} elsif ($pid) {
		$pid_reply = prepareQuoteReply($reply);
	}

	# calculate proper points value ... maybe this should be a public,
	# and *sane*, API?  like, no need to pass reasons, users, or min/max,
	# or even user (get those all automatically if not passed);
	# but that might be dangerous, since $reply/$comment is a little
	# bit specific -- pudge
	# Yeah, this API needs to be... saner. Agreed. - Jamie
	my $mod_reader = getObject("Slash::$constants->{m1_pluginname}", { db_type => 'reader' });
	$reply->{points} = getPoints(
		$reply, $user,
		$constants->{comment_minscore}, $constants->{comment_maxscore},
		$slashdb->countUsers({ max => 1 }), $mod_reader->getReasons
	) if %$reply;

	# If anon posting is turned off, forbid it.  The "post anonymously"
	# checkbox should not appear in such a case, but check that field
	# just in case the user fudged it.
	if (($user->{is_anon} || $form->{postanon})
		&& !$slashdb->checkAllowAnonymousPosting($user->{uid})) {
		print getError('anonymous disallowed');
		return;
	}

	if ($discussion->{type} eq 'archived') {
		print getError('archive_error');
		return;
	}

	if (lc($form->{op}) ne 'reply' || $form->{op} eq 'preview' || ($form->{postersubj} && $form->{postercomment})) {
		$preview = previewForm(\$error_message, $discussion) or $error_flag++;
	}

	if (%$reply && !$form->{postersubj}) {
		$form->{postersubj} = decode_entities($reply->{subject});
		$form->{postersubj} =~ s/^Re://i;
		$form->{postersubj} =~ s/\s\s/ /g;
		$form->{postersubj} = "Re:$form->{postersubj}";
	}
	
	my $extras = [];	
	my $disc_skin = $slashdb->getSkin($discussion->{primaryskid});
	
	$extras =  $slashdb->getNexusExtrasForChosen(
		{ $disc_skin->{nexus} => 1 },
		{ content_type => "comment" })
		if $disc_skin && $disc_skin->{nexus};

	my $gotmodwarning;
	$gotmodwarning = 1 if $form->{gotmodwarning}
		|| $error_message && $error_message eq getError("moderations to be lost");

	slashDisplay('edit_comment', {
		pid_reply	=> $pid_reply,
		error_message 	=> $error_message,
		label		=> $label,
		discussion	=> $discussion,
		indextype	=> $form->{indextype},
		preview		=> $preview,
		reply		=> $reply,
		gotmodwarning	=> $gotmodwarning,
		extras		=> $extras
	});
}


##################################################################
# Validate comment, looking for errors
sub validateComment {
	my($comm, $subj, $error_message, $preview, $wsfactor) = @_;
	$wsfactor ||= 1;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $moddb = getObject("Slash::$constants->{m1_pluginname}");
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	
	my $form_success = 1;
	my $message = '';

	if (!dbAvailable("write_comments")) {
		$$error_message = getError('comment_db_down');
		$form_success = 0;
		return;
	}

	my $srcids_to_check = $user->{srcids};

	# We skip the UID test for anonymous users (anonymous posting
	# is banned by setting nopost for the anonymous uid, and we
	# want to check that separately elsewhere).  Note that
	# checking the "post anonymously" checkbox doesn't eliminate
	# a uid check for a logged-in user.
	delete $srcids_to_check->{uid} if $user->{is_anon};

	# If the user is anonymous, or has checked the 'post anonymously'
	# box, check to see whether anonymous posting is turned off for
	# this srcid.
	my $read_only = 0;
	$read_only = 1 if ($user->{is_anon} || $form->{postanon})
		&& $reader->checkAL2($srcids_to_check, 'nopostanon');

	# Whether the user is anonymous or not, check to see whether
	# all posting is turned off for this srcid.
	$read_only ||= $reader->checkAL2($srcids_to_check, 'nopost');

	# If posting is disabled, return the error message.
	if ($read_only) {
		$$error_message = getError('readonly');
		$form_success = 0;
		# editComment('', $$error_message), return unless $preview;
		return;
	}

	# New check (March 2004):  depending on the settings of
	# a var and whether the user is posting anonymous, we
	# might scan the IP they're coming from to see if we can use
	# some commonly-used proxy ports to access our own site.
	# If we can, they're coming from an open HTTP proxy, which
	# we don't want to allow to post.
	if ($constants->{comments_portscan}
		&& ( $constants->{comments_portscan} == 2
			|| $constants->{comments_portscan} == 1 && $user->{is_anon} )
	) {
		my $is_trusted = $slashdb->checkAL2($user->{srcids}, 'trusted');
		if (!$is_trusted) {
#use Time::HiRes; my $start_time = Time::HiRes::time;
			my $is_proxy = $slashdb->checkForOpenProxy($user->{hostip});
#my $elapsed = sprintf("%.3f", Time::HiRes::time - $start_time); print STDERR scalar(localtime) . " comments.pl cfop returned '$is_proxy' for '$user->{hostip}' in $elapsed secs\n";
			if ($is_proxy) {
				$$error_message = getError('open proxy', {
					unencoded_ip	=> $ENV{REMOTE_ADDR},
					port		=> $is_proxy,
				});
				$form_success = 0;
				return;
			}
		}
	}

	# New check (July 2002):  there is a max number of posts per 24-hour
	# period, either based on IPID for anonymous users, or on UID for
	# logged-in users.  Logged-in users get a max number of posts that
	# is related to their karma.  The comments_perday_bykarma var
	# controls it (that var is turned into a hashref in MySQL.pm when
	# the vars table is read in, whose keys we loop over to find the
	# appropriate level).
	# See also comments_maxposts in formkeyErrors - Jamie 2005/05/30

	my $min_cid_1_day_old = $slashdb->getVar('min_cid_last_1_days','value', 1) || 0;
	
	if (($user->{is_anon} || $form->{postanon}) && $constants->{comments_perday_anon}
		&& !$user->{is_admin}) {
		my($num_comm, $sum_mods) = $reader->getNumCommPostedAnonByIPID(
			$user->{ipid}, 24, $min_cid_1_day_old);
		my $num_allowed = $constants->{comments_perday_anon};
		if ($sum_mods - $num_comm + $num_allowed <= 0) {

			$$error_message = getError('comments post limit daily', {
				limit => $constants->{comments_perday_anon}
			});
			$form_success = 0;
			return;

		}
	} elsif (!$user->{is_anon} && $constants->{comments_perday_bykarma}
		&& !$user->{is_admin}) {
		my($num_comm, $sum_mods) = $reader->getNumCommPostedByUID(
			$user->{uid}, 24, $min_cid_1_day_old);
		my $num_allowed = 9999;
		K_CHECK: for my $k (sort { $a <=> $b }
			keys %{$constants->{comments_perday_bykarma}}) {
			if ($user->{karma} <= $k) {
				$num_allowed = $constants->{comments_perday_bykarma}{$k};
				last K_CHECK;
			}
		}
		if ($sum_mods - $num_comm + $num_allowed <= 0) {

			$$error_message = getError('comments post limit daily', {
				limit => $num_allowed
			});
			$form_success = 0;
			return;

		}
	}

	if (isTroll()) {
		if ($constants->{comment_is_troll_disable_and_log}) {
			$user->{state}{is_troll} = 1;
		} else {
			$$error_message = getError('troll message', {
				unencoded_ip => $ENV{REMOTE_ADDR}      
			});
			return;
		}
	}

	if ($user->{is_anon} || $form->{postanon}) {
		my $uid_to_check = $user->{uid};
		if (!$user->{is_anon}) {
			$uid_to_check = getCurrentAnonymousCoward('uid');
		}
		if (!$slashdb->checkAllowAnonymousPosting($uid_to_check)) {
			$$error_message = getError('anonymous disallowed');
			return;
		}
	}

	if (!$user->{is_anon} && $form->{postanon} && $user->{karma} < 0) {
		$$error_message = getError('postanon_option_disabled');
		return;
	}

	my $post_restrictions = $reader->getNetIDPostingRestrictions("subnetid", $user->{subnetid});
	if ($user->{is_anon} || $form->{postanon}) {
		if ($post_restrictions->{no_anon}) {
			my $logged_in_allowed = !$post_restrictions->{no_post};
			$$error_message = getError('troll message', {
				unencoded_ip 		=> $ENV{REMOTE_ADDR},
				logged_in_allowed 	=> $logged_in_allowed      
			});
			return;
		}
	}

	if (!$user->{is_admin} && $post_restrictions->{no_post}) {
		$$error_message = getError('troll message', {
			unencoded_ip 		=> $ENV{REMOTE_ADDR},
		});
		return;
	}


	$$subj =~ s/\(Score(.*)//i;
	$$subj =~ s/Score:(.*)//i;

	$$subj =~ s/&(#?[a-zA-Z0-9]+);?/approveCharref($1)/sge;

	for ($$comm, $$subj) {
		my $d = decode_entities($_);
		$d =~ s/&#?[a-zA-Z0-9]+;//g;	# remove entities we don't know
		if ($d !~ /\w/) {		# require SOME non-whitespace
			$$error_message = getError('no body');
			return;
		}
	}

	unless (defined($$comm = balanceTags($$comm, { deep_nesting => 1 }))) {
		# only time this should return an error is if the HTML is busted
		$$error_message = getError('broken html');
		return ;
	}

	my $dupRows = $slashdb->findCommentsDuplicate($form->{sid}, $$comm);
	if ($dupRows) {
		$$error_message = getError('duplication error');
		$form_success = 0;
		return unless $preview;
	}

	my $kickin = $constants->{comments_min_line_len_kicks_in};
	if ($constants->{comments_min_line_len} && length($$comm) > $kickin) {

		my $max_comment_len = $constants->{default_maxcommentsize};
		my $check_prefix = substr($$comm, 0, $max_comment_len);
		my $check_prefix_len = length($check_prefix);
		my $min_line_len_max = $constants->{comments_min_line_len_max}
			|| $constants->{comments_min_line_len}*2;
		my $min_line_len = $constants->{comments_min_line_len}
			+ ($min_line_len_max - $constants->{comments_min_line_len})
				* ($check_prefix_len - $kickin)
				/ ($max_comment_len - $kickin); # /

		my $check_notags = strip_nohtml($check_prefix);
		# Don't count & or other chars used in entity tags;  don't count
		# chars commonly used in ascii art.  Not that it matters much.
		# Do count chars commonly used in source code.
		my $num_chars = $check_notags =~ tr/A-Za-z0-9?!(){}[]+='"@$-//;

		# Note that approveTags() has already been called by this point,
		# so all tags present are legal and uppercased.
		my $breaktags = $constants->{'approvedtags_break'}
			|| [qw(HR BR LI P OL UL BLOCKQUOTE DIV)];
		my $breaktags_1_regex = "<(?:" . join("|", @$breaktags) . ")>";
		my $breaktags_2_regex = "<(?:" . join("|", grep /^(P|BLOCKQUOTE)$/, @$breaktags) . ")>";
		my $num_lines = 0;
		$num_lines++ while $check_prefix =~ /$breaktags_1_regex/gi;
		$num_lines++ while $check_prefix =~ /$breaktags_2_regex/gi;

		if ($num_lines > 3) {
			my $avg_line_len = $num_chars/$num_lines;
			if ($avg_line_len < $min_line_len) {
				$$error_message = getError('low chars-per-line', {
					ratio 	=> sprintf("%0.1f", $avg_line_len),
				});
				$form_success = 0;
				return unless $preview;
			}
		}
	}

	# Test comment and subject using filterOk and compressOk.
	# If the filter is matched against the content, or the comment
	# compresses too well, display an error with the particular
	# message for the filter that was matched.
	my $fields = {
			postersubj 	=> 	$$subj,
			postercomment 	=>	$$comm,
	};

	for (keys %$fields) {
		# run through filters
		if (! filterOk('comments', $_, $fields->{$_}, \$message)) {
			$$error_message = getError('filter message', {
					err_message	=> $message,
			});
			return unless $preview;
			$form_success = 0;
			last;
		}
		# run through compress test
		if (! compressOk('comments', $_, $fields->{$_}, $wsfactor)) {
			# blammo luser
			$$error_message = getError('compress filter', {
					ratio	=> $_,
			});
			return unless $preview;
			$form_success = 0;
			last;
		}
	}

	if (	    $constants->{m1}
		&& !$user->{is_anon}
		&& !$form->{postanon}
		&& !$form->{gotmodwarning}
		&& !( $constants->{authors_unlimited}
			&& $user->{seclev} >= $constants->{authors_unlimited} )
		&& !$user->{acl}{modpoints_always}
		&&  $moddb
		&&  $moddb->countUserModsInDiscussion($user->{uid}, $form->{sid}) > 0
	) {
		$$error_message = getError("moderations to be lost");
		$form_success = 0;
		return;
	}

	$$error_message ||= '';
	# Return false if error condition...
	return if ! $form_success;

	# ...otherwise return true.
	return 1;
}


##################################################################
# Previews a comment for submission
sub previewForm {
	my($error_message, $discussion) = @_;
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	my $comment = preProcessComment($form, $user, $discussion, $error_message) or return;
	my $preview = postProcessComment({ %$comment, %$user }, 0, $discussion);

	if ($constants->{plugin}{Subscribe}) {
		$preview->{subscriber_bonus} =
			$user->{is_subscriber}
			&& (!$form->{nosubscriberbonus} || $form->{nosubscriberbonus} ne 'on')
			? 1 : 0;
	}

	return prevComment($preview, $user);
}

##################################################################
# Saves the Comment
# Here, $form->{sid} is a discussion id, not a story id.
# Also, header() is NOT called before this function is called,
# so (assuming we don't want to do a redirect) it must be
# called manually.
sub submitComment {
	my($form, $slashdb, $user, $constants, $discussion) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	$form->{nobonus}  = $user->{nobonus}	unless $form->{nobonus_present};
	$form->{postanon} = $user->{postanon}	unless $form->{postanon_present};
	$form->{nosubscriberbonus} = $user->{nosubscriberbonus}
						unless $form->{nosubscriberbonus_present};

	my $header_emitted = 0;
	my $sid = $form->{sid};

	# Couple of rules on how to treat the discussion depending on how mode is set -Brian
	$discussion->{type} = isDiscussionOpen($discussion);

	if ($discussion->{type} eq 'archived') {
		header('Comments', $discussion->{section}) or return;
		print getError('archive_error');
		return;
	}

 	my $error_message;
	my $comment = preProcessComment($form, $user, $discussion, $error_message);
	if (!$comment) {
		# The comment did not validate.  We're not actually going to
		# post the comment this time around, we are (probaly) just
		# going to walk through the editing cycle again.
		header('Comments', $discussion->{section}) or return;
		$slashdb->resetFormkey($form->{formkey});
		editComment(@_, $error_message);
		return 0;
	}

	# If we want a redirect to a new URL after comment posting success,
	# set some vars to indicate that.  Note that cleanRedirectUrlFromForm
	# both reads the URL from $form and confirms that it's been signed
	# with the correct confirmation password ('returnto_passwd').
	my $do_emit_html = 1;
	my $redirect_to = undef;
	if ($redirect_to = cleanRedirectUrlFromForm("commentpostsuccess")) {
		$do_emit_html = 0;
	}
	if ($do_emit_html) {
		header('Comments', $discussion->{section}) or return;
		$header_emitted = 1;
	}

	if ($header_emitted) {
		titlebar("100%", getData('submitted_comment'));
	}

#print STDERR scalar(localtime) . " $$ E header_emitted=$header_emitted do_emit_html=$do_emit_html redirect_to=" . (defined($redirect_to) ? $redirect_to : "undef") . "\n";

	# Set starting points to the AC's starting points, by default.
	# If the user is posting under their own name, we'll reset this
	# value (and add other modifiers) in a moment.
	my $pts = getCurrentAnonymousCoward('defaultpoints');

	my $karma_bonus = 0;
	my $subscriber_bonus = 0;
	my $tweak = 0;
	if (!$user->{is_anon} && !$form->{postanon}) {

		$pts = $user->{defaultpoints};

		if ($constants->{karma_posting_penalty_style} == 0) {
			$pts-- if $user->{karma} < 0;
			$pts-- if $user->{karma} < $constants->{badkarma};
                } else {
			$tweak-- if $user->{karma} < 0;
			$tweak-- if $user->{karma} < $constants->{badkarma};
		}
		# Enforce proper ranges on comment points.
		my($minScore, $maxScore) =
			($constants->{comment_minscore}, $constants->{comment_maxscore});
		$pts = $minScore if $pts < $minScore;
		$pts = $maxScore if $pts > $maxScore;
		$karma_bonus = 1 if $pts >= 1 && $user->{karma} > $constants->{goodkarma}
			&& !$form->{nobonus};
		$subscriber_bonus = 1 if $constants->{plugin}{Subscribe}
			&& $user->{is_subscriber}
			&& (!$form->{nosubscriberbonus} || $form->{nosubscriberbonus} ne 'on');
	}

	my $posters_uid = $user->{uid};
	if ($form->{postanon}
		&& $reader->checkAllowAnonymousPosting()
		&& $user->{karma} > -1
		&& ($discussion->{commentstatus} eq 'enabled'
			||
		    $discussion->{commentstatus} eq 'logged_in')) {
		$posters_uid = getCurrentAnonymousCoward('uid');
	}

#print STDERR scalar(localtime) . " $$ F header_emitted=$header_emitted do_emit_html=$do_emit_html\n";

	my $clean_comment = {
		subject		=> $comment->{subject},
		comment		=> $comment->{comment},
		sid		=> $comment->{sid},
		pid		=> $comment->{pid},
		ipid		=> $user->{ipid},
		subnetid	=> $user->{subnetid},
		uid		=> $posters_uid,
		points		=> $pts,
		tweak		=> $tweak,
		tweak_orig	=> $tweak,
		karma_bonus	=> $karma_bonus ? 'yes' : 'no',
	};
	
	if ($constants->{plugin}{Subscribe}) {
		$clean_comment->{subscriber_bonus} = $subscriber_bonus ? 'yes' : 'no';
	}

	my $maxCid = $slashdb->createComment($clean_comment);
	if ($constants->{comment_karma_disable_and_log}) {
		my $post_str = "";
		$post_str .= "NO_ANON " if $user->{state}{commentkarma_no_anon};
		$post_str .= "NO_POST " if $user->{state}{commentkarma_no_post};
		if ($posters_uid == $constants->{anonymous_coward_uid} && $user->{state}{commentkarma_no_anon}) {
			$slashdb->createCommentLog({
				cid	=> $maxCid,
				logtext	=> "COMMENTKARMA ANON: $post_str"
			});
		} elsif ($posters_uid != $constants->{anonymous_coward_uid} && $user->{state}{commentkarma_no_post}) {
			$slashdb->createCommentLog({
				cid	=> $maxCid,
				logtext	=> "COMMENTKARMA USER: $post_str"
			});
		}
	}
	if ($constants->{comment_is_troll_disable_and_log}) {
		$slashdb->createCommentLog({
			cid	=> $maxCid,
			logtext	=> "ISTROLL"
		});
	}

#print STDERR scalar(localtime) . " $$ G maxCid=$maxCid\n";

	# make the formkeys happy
	$form->{maxCid} = $maxCid;

	$slashdb->setUser($user->{uid}, {
		'-expiry_comm'	=> 'expiry_comm-1',
	}) if allowExpiry();

	if ($maxCid == -1) {
		# What vars should be accessible here?
		if (!$header_emitted) {
			header('Comments', $discussion->{section}) or return;
		}
		print getError('submission error');
		return(0);

	} elsif (!$maxCid) {
		# This site has more than 2**32 comments.  Wow.
		if (!$header_emitted) {
			header('Comments', $discussion->{section}) or return;
		}
		print getError('maxcid exceeded');
		return(0);
	}

	if ($do_emit_html) {
		slashDisplay('comment_submit', {
			metamod_elig => metamod_elig($user),
		});
	}

	my $saved_comment = $slashdb->getComment($maxCid);

	slashHook('comment_save_success', { comment => $saved_comment });

	my $moddb = getObject("Slash::$constants->{m1_pluginname}");
	if ($moddb) {
		my $text = $moddb->checkDiscussionForUndoModeration($sid);
		print $text if $text;
	}

	if ($do_emit_html) {
		printComments($discussion, $maxCid, $maxCid,
			{ force_read_from_master => 1, just_submitted => 1 }
		);
	}

	my $tc = $slashdb->getVar('totalComments', 'value', 1);
	$slashdb->setVar('totalComments', ++$tc);

	# This is for stories. If a sid is only a number
	# then it belongs to discussions, if it has characters
	# in it then it belongs to stories and we should
	# update to help with stories/hitparade.
	# -Brian
	if ($discussion->{sid}) {
		$slashdb->setStory($discussion->{sid}, { writestatus => 'dirty' });
	}

	$slashdb->setUser($clean_comment->{uid}, {
		-totalcomments => 'totalcomments+1',
	}) if !isAnon($clean_comment->{uid});

	my($messages, $reply, %users);
	my $kinds = $reader->getDescriptions('discussion_kinds');
	if ($form->{pid}
		|| $kinds->{ $discussion->{dkid} } =~ /^journal/
		|| $constants->{commentnew_msg}) {
		$messages = getObject('Slash::Messages');
		$reply = $slashdb->getCommentReply($form->{sid}, $maxCid);
	}

	$clean_comment->{pointsorig} = $clean_comment->{points};

	# reply to comment
	if ($messages && $form->{pid}) {
		my $parent = $slashdb->getCommentReply($sid, $form->{pid});
		my $users  = $messages->checkMessageCodes(MSG_CODE_COMMENT_REPLY, [$parent->{uid}]);
		if (_send_comment_msg($users->[0], \%users, $pts, $clean_comment)) {
			my $data  = {
				template_name	=> 'reply_msg',
				subject		=> { template_name => 'reply_msg_subj' },
				reply		=> $reply,
				parent		=> $parent,
				discussion	=> $discussion,
			};

			$messages->create($users->[0], MSG_CODE_COMMENT_REPLY, $data);
			$users{$users->[0]}++;
		}
	}

	# reply to journal
	if ($messages && $kinds->{ $discussion->{dkid} } =~ /^journal/) {
		my $users  = $messages->checkMessageCodes(MSG_CODE_JOURNAL_REPLY, [$discussion->{uid}]);
		if (_send_comment_msg($users->[0], \%users, $pts, $clean_comment)) {
			my $data  = {
				template_name	=> 'journrep',
				subject		=> { template_name => 'journrep_subj' },
				reply		=> $reply,
				discussion	=> $discussion,
			};

			$messages->create($users->[0], MSG_CODE_JOURNAL_REPLY, $data);
			$users{$users->[0]}++;
		}
	}

	# comment posted
	if ($messages && $constants->{commentnew_msg}) {
		my $users = $messages->getMessageUsers(MSG_CODE_NEW_COMMENT);

		my $data  = {
			template_name	=> 'commnew',
			subject		=> { template_name => 'commnew_subj' },
			reply		=> $reply,
			discussion	=> $discussion,
		};

		my @users_send;
		for my $usera (@$users) {
			next if $users{$usera};
			push @users_send, $usera;
			$users{$usera}++;
		}
		$messages->create(\@users_send, MSG_CODE_NEW_COMMENT, $data) if @users_send;
	}

	if ($constants->{validate_html}) {
		my $validator = getObject('Slash::Validator');
		my $test = parseDomainTags($comment->{comment});
		$validator->isValid($test, {
			data_type	=> 'comment',
			data_id		=> $maxCid,
			message		=> 1
		}) if $validator;
	}

	# OK -- if we make it all the way here, and there were
	# no errors so no header has been emitted, and we were
	# asked to redirect to a new URL, NOW we can finally
	# do it.
	if ($redirect_to) {
#print STDERR scalar(localtime) . " $$ H redirecting to '$redirect_to'\n";
		redirect($redirect_to);
	} else {
#print STDERR scalar(localtime) . " $$ H not redirecting, emitted=$header_emitted\n";
		if (!$header_emitted) {
			header('Comments', $discussion->{section}) or return;
		}
	}

	return(1);
}


##################################################################
# Decide whether or not to send a given message to a given user
sub _send_comment_msg {
	my($uid, $uids, $pts, $C) = @_;
	my $constants	= getCurrentStatic();
	my $reader	= getObject('Slash::DB', { db_type => 'reader' });
	my $user	= getCurrentUser();

	return unless $uid;			# no user
	return if $uids->{$uid};		# user not already being msgd
	return if $user->{uid} == $uid;		# don't msg yourself

	my $otheruser = $reader->getUser($uid);

	# use message_threshold in vars, unless user has one
	# a message_threshold of 0 is valid, but "" is not
	my $message_threshold = length($otheruser->{message_threshold})
		? $otheruser->{message_threshold}
		: length($constants->{message_threshold})
			? $constants->{message_threshold}
			: undef;

	my $mod_reader = getObject("Slash::$constants->{m1_pluginname}", { db_type => 'reader' });
	my $newpts = getPoints($C, $otheruser,
		$constants->{comment_minscore}, $constants->{comment_maxscore},
		$reader->countUsers({ max => 1 }), $mod_reader->getReasons,
	);

	# only if reply pts meets message threshold
	return if defined $message_threshold && $newpts < $message_threshold;

	return 1;
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

##################################################################
# Given a sid and cid, this will delete a comment, and all its replies
sub deleteThread {
	my($sid, $cid, $level, $comments_deleted) = @_;
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	$level ||= 0;

	my $count = 0;
	my @delList;
	$comments_deleted = \@delList if !$level;

	return unless ($constants->{authors_unlimited} && $user->{seclev} >= $constants->{authors_unlimited})
		|| $user->{acl}{candelcomments_always};

	my $delkids = $slashdb->getCommentChildren($cid);

	# Delete children of $cid.
	my %comment_hash;
	push @{$comments_deleted}, $cid;
	for (@{$delkids}) {
		my($cid) = @{$_};
		push @{$comments_deleted}, $cid;
		deleteThread($sid, $cid, $level+1, $comments_deleted);
	}
	for (@{$comments_deleted}) {
		$comment_hash{$_} = 1;
	}
	@{$comments_deleted} = keys %comment_hash;

	if (!$level) {
		for (@{$comments_deleted}) {
			$count += $slashdb->deleteComment($_);
		}
		# SID remains for display purposes, only.
		slashDisplay('deleted_cids', {
			sid			=> $sid,
			count			=> $count,
			comments_deleted	=> $comments_deleted,
		});
	}
	return $count;
}


##################################################################
sub setDiscussion2 {
	my($form, $slashdb, $user, $constants, $gSkin) = @_;
	return if $user->{is_anon};
	$slashdb->setUser($user->{uid}, {
		discussion2 => $form->{discussion2_slashdot} ? 'slashdot' : 'none'
	});

	my $referrer = $ENV{HTTP_REFERER};
	my $url;
	if ($referrer && $referrer =~ m|https?://(?:[\w.]+.)?$constants->{basedomain}/|) {
		$url = $referrer;
	} else {
		$url = $gSkin->{rootdir} . '/comments.pl';
		$url .= '?sid=' . $form->{sid};
		$url .= '&cid=' . $form->{cid} if $form->{cid};
		$url .= '&pid=' . $form->{pid} if $form->{pid};
	}

	redirect($url);
}


##################################################################
createEnvironment();
main();
1;

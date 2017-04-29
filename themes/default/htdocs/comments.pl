#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use utf8;
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

	my $op = $form->{op} || '';
	$op = lc($op);

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
			function		=> \&changeComment,
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
		unspam => {
			function		=> \&unspamComment,
			seclev			=> 100,
			formname		=> 'comments',
			checks			=> [],
		},
	};
	$ops->{default} = $ops->{display};

	if ($op =~ /^(?:creator_index|personal_index|user_created_index|index|create_discussion|delete_forum)/) {
		redirect($gSkin->{rootdir} . '/journal.pl');
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

	# Not needed --paulej72 20150427
	# this is so messed up ... it's done again under header(), but
	# sometimes we need it done before header() is called, because,
	# like i said, this is so messed up ...
	#{
	#	my $skid;
	#	if ($section) {
	#		my $skin = $slashdb->getSkin($section);
	#		$skid = $skin->{skid} if $skin;
	#	}
	#	setCurrentSkin($skid || determineCurrentSkin());
	#	Slash::Utility::Anchor::getSkinColors();
	#}


	# If this is a comment post, we can't write the header yet,
	# because submitComment() _may_ want to do a redirect
	# instead of emitting a webpage.

	my $header_emitted = 0;
	my $title = $constants->{sitename} . '  Comments';
	$title .= " | $discussion->{'title'}" if $discussion;
	if ($op ne 'submit' && $op ne 'unspam' && $op ne 'moderate'  && $op ne 'change' ) {
		header($title, $section) or return;
		$header_emitted = 1;
	}

#print STDERR scalar(localtime) . " $$ A op=$op header_emitted=$header_emitted\n";

	if ($user->{is_anon} && $form->{upasswd} && length($form->{upasswd}) > 1) {
		if (!$header_emitted) {
			header($title, $section) or return;
			$header_emitted = 1;
		}
		print Slash::Utility::Comments::getError('login error');
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
		print Slash::Utility::Comments::getError("nosubscription");
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
		my $retval = $ops->{$op}{function}->($form, $slashdb, $user, $constants, $discussion, $gSkin);

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

	$form->{pid} = 0 unless defined $form->{pid};
	if ($form->{cid}) {
		# Here is the deal, if a user who has a mode of nocomment asks for a 
		# comment we give it to them and assume the default mode (which 
		# according to the schema is 'thread'). -Brian
		$user->{mode} = 'thread-tng' if $user->{mode} eq 'nocomment';
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
# This sub is badly outdated and needs to be rewritten.
# Do not use it.
sub editComment {
	my($form, $slashdb, $user, $constants, $discussion, $gSkin, $error_message) = @_;

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
		print Slash::Utility::Comments::getError('no sid');
		return;
	}

	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $parent = $reader->getDiscussionParent($form->{sid});

	# Get the comment we may be responding to. Remember to turn off
	# moderation elements for this instance of the comment.
	my $pid = $form->{pid} || 0; # this is guaranteed numeric, from filter_params
	my $reply = $slashdb->getCommentReply($sid, $pid) || { };
	my $pid_reply = '';

	# An attempt to reply to a comment that doesn't exist is an error.
	if ($pid && !%$reply) {
		print Slash::Utility::Comments::getError('no such parent');
		return;
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
		print Slash::Utility::Comments::getError('anonymous disallowed');
		return;
	}

	if ($discussion->{type} eq 'archived') {
		print Slash::Utility::Comments::getError('archive_error');
		return;
	}

	if (lc($form->{op}) ne 'reply' || $form->{op} eq 'preview' || ($form->{postersubj} && $form->{postercomment})) {
		$preview = previewForm(\$error_message, $discussion) or $error_flag++;
	}

	preProcessReplyForm($form, $reply);
	
	my $extras = [];
	my $skid = $discussion->{primaryskid} || $constants->{mainpage_skid};
	my $disc_skin = $slashdb->getSkin($skid);
	# print STDERR scalar(localtime) . " $$ comment.pl 508 discussion primaryskid: " . $discussion->{primaryskid} . ", discussion id: " . $discussion->{id} . "\n" ;
	
	$extras =  $slashdb->getNexusExtrasForChosen(
		{ $disc_skin->{nexus} => 1 },
		{ content_type => "comment" })
		if $disc_skin && $disc_skin->{nexus};

	my $gotmodwarning;
	$gotmodwarning = 1 if $form->{gotmodwarning} ||
		($error_message && $error_message eq
			Slash::Utility::Comments::getError("moderations to be lost")
		);

	slashDisplay('edit_comment', {
		pid_reply	=> $pid_reply,
		error_message 	=> $error_message,
		label		=> $label,
		parent		=> $parent,
		discussion	=> $discussion,
		indextype	=> $form->{indextype},
		preview		=> $preview,
		reply		=> $reply,
		gotmodwarning	=> $gotmodwarning,
		extras		=> $extras,
	});
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
	return $$error_message if $comment eq '-1';
	my $preview = postProcessComment({ %$user, %$form, %$comment }, 0, $discussion);

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
	my($form, $slashdb, $user, $constants, $discussion, $gSkin) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	my $header_emitted = 0;

 	my $error_message;
	my $comment = preProcessComment($form, $user, $discussion, \$error_message);
	if ($comment eq '-1') { # die!
		header('Comments', $discussion->{section}) or return;
		print $$error_message;
		return;
	}

	if (!$comment) {
		# The comment did not validate.  We're not actually going to
		# post the comment this time around, we are (probaly) just
		# going to walk through the editing cycle again.
		header('Comments', $discussion->{section}) or return;
		$slashdb->resetFormkey($form->{formkey});
		editComment(@_, $error_message);
		return 0;
	}

	# Save the comment
	my $saved_comment = saveComment($form, $comment, $user, $discussion, $gSkin, \$error_message);
	
	# Bail if comment save fails
	if (!$saved_comment) {
 		header('Comments', $discussion->{section}) or return;
 		print $error_message if $error_message;
 		return;
	}

	# Setup redirect to new comment
	my $redirect = '';
	$redirect = $redirect."&threshold=".$form->{threshold} if defined($form->{threshold});
	$redirect = $redirect."&highlightthresh=".$form->{highlightthresh} if defined($form->{highlightthresh});
	$redirect = $redirect."&commentsort=".$form->{commentsort} if defined($form->{commentsort});
	$redirect = $redirect."&mode=".$form->{mode} if defined($form->{mode});
	$redirect = $redirect."&page=".$form->{page} if defined($form->{page});
	$redirect = $redirect."&noupdate=1";
	
	# Check if url has parameters or is naked
	# Add ? if naked
	if (index($discussion->{url}, '?') != -1 ) {
		$redirect = $discussion->{url}.$redirect;
	} else {
		$redirect = $discussion->{url}."?".$redirect;
	}
	
	$redirect = $redirect."#comment_".$saved_comment->{cid};
	

	# OK -- if we make it all the way here, and there were
	# no errors, NOW we can finally do it.
	
	redirect($redirect);

	return(1);
}


##################################################################
# Change Comment Options
# Actual save is in the perpareUser routine.  This function just 
# does a redirect with the proper options set.
# Also, header() is NOT called before this function is called.

sub changeComment {
	my($form, $slashdb, $user, $constants, $discussion, $gSkin) = @_;

	# Setup redirect to new comment
	my $redirect = '';
	$redirect = $redirect."&threshold=".$form->{threshold} if defined($form->{threshold});
	$redirect = $redirect."&highlightthresh=".$form->{highlightthresh} if defined($form->{highlightthresh});
	$redirect = $redirect."&commentsort=".$form->{commentsort} if defined($form->{commentsort});
	$redirect = $redirect."&mode=".$form->{mode} if defined($form->{mode});
	$redirect = $redirect."&page=".$form->{page} if defined($form->{page});
	$redirect = $redirect."&noupdate=1";	
	
	if (defined($form->{cid})) {
		$redirect = $gSkin->{rootdir}."/comments.pl?sid=".$form->{sid}."&cid=".$form->{cid}.$redirect;
	} else {	
		# Check if url has parameters or is naked
		# Add ? if naked
		if (index($discussion->{url}, '?') != -1 ) {
			$redirect = $discussion->{url}.$redirect;
		} else {
			$redirect = $discussion->{url}."?".$redirect;
		}
	}
	
	$redirect = $redirect."#commentwrap";
	
	redirect($redirect);

	return(1);
}

##################################################################
sub moderate {
	my($form, $slashdb, $user, $constants, $discussion, $gSkin) = @_;
	my $moddb = getObject("Slash::$constants->{m1_pluginname}");
	my $error = '';

	my $moderate_check = $moddb->moderateCheck($form, $user, $constants, $discussion);
	if (!$moderate_check->{count} && $moderate_check->{msg}) {
		$error .= $moderate_check->{msg} if $moderate_check->{msg};
		header('Comments', $discussion->{section}) or return;
		titlebar("100%", getData('moderating'));
	  print $error;		
		printComments($discussion, $form->{pid}, $form->{cid},
			{ force_read_from_master => 1 } );
		return;
	}


	my $hasPosted = $moderate_check->{count};



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
			my($cid, $can_mod, $ret_val, $comment) = (0, 0, 0);
			$cid = $1;
			
			# ugly refactor for debugging code
			if ($cid) {
				$comment = $moddb->getComment($cid);
			} else {
				$error .= Slash::Utility::Comments::getError('didnt get a cid')."<br/>";
			}

			if ($comment) {
				$can_mod = Slash::Utility::Comments::_can_mod($comment);
			} else {
				$error .=  Slash::Utility::Comments::getError('cannot find comment')."<br/>";
			} 

			if ($can_mod) {
				$ret_val = $moddb->moderateComment(
					$sid, $cid, $form->{$key}, { comment => $comment, no_display => 1 }, 
				);
			} else {
				# MC: This is useful for debugging general moderation problems, but isn't
				# so useful in general since overspends will cause this error!
				#print "user can't moderate comment";
				#print Slash::Utility::Comments::getError('user cannot moderate');
			} 
				
			# If an error was returned, tell the user what
			# went wrong.
			if ($ret_val < 0) {
				if ($ret_val == -1) {
					$error .= Slash::Utility::Comments::getError('no points')."<br/>";
				} elsif ($ret_val == -2){
					$error .= Slash::Utility::Comments::getError('not enough points')."<br/>";
				} elsif ($ret_val == -3){
					$error .= Slash::Utility::Comments::getError('no self mods')."<br/>";
				} elsif ($ret_val == -4){
					$error .= Slash::Utility::Comments::getError('not enough karma')."<br/>";
				} elsif ($ret_val == -5){
					$error .= Slash::Utility::Comments::getError('needs modded first')."<br/>";
				}
			} else {
				$was_touched += $ret_val;
			}
		}
	}
	$slashdb->setDiscussionDelCount($sid, $total_deleted);
	$was_touched = 1 if $total_deleted;


	if ($hasPosted && !$total_deleted) {
		$error .= $moderate_check->{msg}."<br/>";
	} elsif ($user->{seclev} && $total_deleted) {
		$error .= slashDisplay('del_message', {
			total_deleted   => $total_deleted,
			comment_count   => $slashdb->countCommentsBySid($sid),
			Return => 1,
		});
	}
  
	
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
		
	if ($error) {
		header('Comments', $discussion->{section}) or return;
		titlebar("100%", getData('moderating'));
	  print $error;		
		printComments($discussion, $form->{pid}, $form->{cid},
			{ force_read_from_master => 1 } );
	} else {
		
		# Get ID from button
		my $id=$form->{moderate};
		
		# Setup redirect to new comment
		my $redirect = '';
		$redirect = $redirect."&threshold=".$form->{threshold} if defined($form->{threshold});
		$redirect = $redirect."&highlightthresh=".$form->{highlightthresh} if defined($form->{highlightthresh});
		$redirect = $redirect."&commentsort=".$form->{commentsort} if defined($form->{commentsort});
		$redirect = $redirect."&mode=".$form->{mode} if defined($form->{mode});
		$redirect = $redirect."&page=".$form->{page} if defined($form->{page});
		$redirect = $redirect."&noupdate=1";
		
		if (defined($form->{cid})) {
			$redirect = $gSkin->{rootdir}."/comments.pl?sid=".$form->{sid}."&cid=".$form->{cid}.$redirect;
		} else {
			# Check if url has parameters or is naked
			# Add ? if naked
			if (index($discussion->{url}, '?') != -1 ) {
				$redirect = $discussion->{url}.$redirect;
			} else {
				$redirect = $discussion->{url}."?".$redirect;
			}
		}
		
		$redirect = $redirect."#".$id;
		
		# OK -- if we make it all the way here, and there were
		# no errors, NOW we can finally do it.
		
		redirect($redirect);
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

sub unspamComment {
	my ($form, $slashdb, $user, $constants, $discussion) = @_;
	my $rootdir = getCurrentSkin("rootdir");
	my $moddb = getObject("Slash::$constants->{m1_pluginname}");

	if(!$moddb) {
		print STDERR "\nERROR: Could not get moddb.\n";
		redirect("$rootdir/comments.pl?sid=$form->{sid}#$form->{cid}", 301);
		return;
	}
	
	my $cid = $form->{cid};
	if($cid !~ /^\d+$/) {
		print STDERR "\nGot non-numeric cid '$cid' in \$form. Bailing to simple display.\n";
		redirect("$rootdir/comments.pl?sid=$form->{sid}#$form->{cid}", 301);
		return;
	}

	my $spamreason = $moddb->sqlSelect( 'id',
					'modreasons',
					"name = 'Spam'");
	if(!$spamreason) {
		print STDERR "\nGot undef for \$spamreason. WTF?\n";
		redirect("$rootdir/comments.pl?sid=$form->{sid}#$form->{cid}", 301);
		return;
	}
	
	my $spamMods = $moddb->sqlSelectAllHashref('id',
					'*',
					'moderatorlog',
					" cid = $cid AND reason = $spamreason AND active = 1 ");
	
	# Here we do the following for each:
	# delete the moderation from the modlog
	# recalculate the comment score
	# restore the commenter's karma
	# remove any mod points from the user who modded it spam
	# ban the user who modded it spam
	# 	until 30 days in the future or
	#	not at all if the user is already banned or
	#	using the larger ban if the user has served out a previous ban
	foreach my $spamMod (values %$spamMods) {
		my ($modderUID, $modLogID) = ($spamMod->{uid}, $spamMod->{id});
		# Bail if we somehow got a bad entry without the proper data
		unless ($modderUID && $modLogID) {
			redirect("$rootdir/comments.pl?sid=$form->{sid}#$form->{cid}", 301);
			return;
		}

		# Undo Mod
		my $undo = $moddb->undoSingleModeration($spamMod);
		print STDERR "\nTried to undo mod $modLogID and failed. WTF?!\n" unless $undo;

		# Ban the user from moderating
		unless($form->{noban}) {
			my $banned = $moddb->modBanUID($modderUID);
			print STDERR "\nGot a bad return value on modBanUID: uid=$modderUID" unless $banned;
		}
	}

	# Now redirect them back where they were.
	redirect("$rootdir/comments.pl?sid=$form->{sid}#$form->{cid}", 301);
	return;
}

createEnvironment();
main();
1;


#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants qw(:messages :strip);
use Slash::Display;
use Slash::Utility;

##################################################################
sub main {
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $user = getCurrentUser();

	my $error_flag = 0;
	my $postflag = $user->{state}{post};

	my $op = lc($form->{op});

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
		'index'			=> {
			function		=> \&commentIndex,
			seclev			=> 0,
			formname 		=> 'discussions',
			checks			=> ($form->{sid} || $user->{is_anon}) ? [] : ['generate_formkey'],
		},
		creator_index			=> {
			function		=> \&commentIndexCreator,
			seclev			=> 0,
			formname 		=> 'discussions',
			checks			=> ['generate_formkey'],
		},
		personal_index			=> {
			function		=> \&commentIndexPersonal,
			seclev			=> 1,
			formname 		=> 'discussions',
			checks			=> ['generate_formkey'],
		},
		user_created_index			=> {
			function		=> \&commentIndexUserCreated,
			seclev			=> 0,
			formname 		=> 'discussions',
			checks			=> ['generate_formkey'],
		},
		moderate		=> {
			function		=> \&moderate,
			seclev			=> 1,
			post			=> 1,
			formname		=> 'moderate',
			checks			=> ['generate_formkey'],	
		},
		creatediscussion	=> {
			function		=> \&createDiscussion,
			seclev			=> 1,
			post			=> 1,
			formname 		=> 'discussions',
			checks			=> 
			[ qw ( max_post_check valid_check interval_check 
				formkey_check generate_formkey) ],
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
		preview			=> {
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
		submit			=> {
			function		=> \&submitComment,
			seclev			=> 0,
			post			=> 1,
			formname 		=> $form->{new_discussion} ? 'discussions' : 'comments',
			checks			=> $form->{new_discussion} ? [] : 
			[ qw ( response_check update_formkeyid max_post_check valid_check interval_check 
				formkey_check ) ],
		},
	};
	$ops->{default} = $ops->{display} ;
	
	my ($discussion, $section);

	if ($form->{sid}) {
		# SID compatibility
		if ($form->{sid} !~ /^\d+$/) {
			$discussion = $slashdb->getDiscussionBySid($form->{sid});
			$section = $discussion->{section};
			$user->{state}{tid} = $discussion->{topic};
		} else {
			$discussion = $slashdb->getDiscussion($form->{sid});
			$section = $discussion->{section};
		}
		# This is to get tid in comments. It would be a mess to pass it directly to every comment -Brian
		$user->{state}{tid} = $discussion->{topic};
		if (!$user->{is_admin} and $discussion->{sid}) {
			unless ($slashdb->checkStoryViewable($discussion->{sid})) {
				$form->{sid} = '';
				$discussion = '';
				$op = 'default';
				$section = '';
			}
		}
	}

	$form->{pid} ||= "0";

	header($discussion ? $discussion->{'title'} : 'Comments', $form->{section});

	if ($user->{is_anon} && length($form->{upasswd}) > 1) {
		print getError('login error');
		$op = 'preview';
	}
	$op = 'default' if ( ($user->{seclev} < $ops->{$op}{seclev}) || ! $ops->{$op}{function});
	$op = 'default' if (! $postflag && $ops->{$op}{post});

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
	if ($constants->{admin_formkeys} || $user->{seclev} < 100) {
		$formkey = $form->{formkey};

		# this is needed for formkeyHandler to print the correct messages 
		# yeah, the next step is to loop through the array of $ops->{$op}{check}
		my $formname;
		my $options = {};
		$options->{no_hc} = 1 if !$constants->{hc_sw_comments}
			|| (!$user->{is_anon}
			   && $user->{karma} > $constants->{hc_maxkarma});
 
		my $done = 0;
		DO_CHECKS: while (!$done) {
			$formname = $ops->{$op}{formname}; 
			for my $check (@{$ops->{$op}{checks}}) {
				$ops->{$op}{update_formkey} = 1 if $check eq 'formkey_check';
				$error_flag = formkeyHandler($check, $formname, $formkey,undef,$options);
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

	if (!$error_flag) {
		# CALL THE OP
		my $retval = $ops->{$op}{function}->($form, $slashdb, $user, $constants, $discussion);

		# this has to happen - if this is a form that you updated the formkey val ('formkey_check')
		# you need to call updateFormkey to update the timestamp (time of successful submission) and
		# note: maxCid and length aren't really required - this is legacy from when formkeys was 
		# comments specific, but it can't hurt to put some sort of length in there.. perhaps
		# the length of the primary field in your form would be a good choice.
		if ($ops->{$op}{update_formkey}) {
			if($retval) {
				my $field_length= $form->{postercomment} ? 
					length($form->{postercomment}) : length($form->{postercomment});

				# do something with updated? ummm.
				my $updated = $slashdb->updateFormkey($formkey, $field_length); 

			# updateFormkeyVal updated the formkey before the function call, 
			# but the form somehow had an error in the function it called 
			# unrelated to formkeys so reset the formkey because this is 
			# _not_ a successful submission
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

	# The content here should also probably go into a template.
	titlebar("99%", "Delete $form->{cid}");

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

	if ($form->{cid}) {
		printComments($discussion, $form->{cid}, $form->{cid});
	} elsif ($form->{sid}) {
		printComments($discussion, $form->{pid});
	} else {
		commentIndex(@_);
	}
}


##################################################################
# Index of recent discussions: Used if comments.pl is called w/ no
# parameters
sub commentIndex {
	my($form, $slashdb, $user, $constants) = @_;

	my $label = getData('label');

	my $searchdb = getObject('Slash::Search', $constants->{search_db_user});
	if ($form->{all}) {
		titlebar("100%", getData('all_discussions'));
		my $start = $form->{start} || 0;
		my $discussions = $searchdb->findDiscussion({ section => $form->section }, $constants->{discussion_display_limit} + 1, $start, $constants->{discussion_sort_order});
		if ($discussions && @$discussions) {
			my $forward;
			if (@$discussions == $constants->{discussion_display_limit} + 1) {
				pop @$discussions;
				$forward = $start + $constants->{discussion_display_limit};
			} else {
				$forward = 0;
			}

			# if there are less than discussion_display_limit remaning,
			# just set it to 0
			my $back;
			if ($start > 0) {
				$back = $start - $constants->{discussion_display_limit};
				$back = $back > 0 ? $back : 0;
			} else {
				$back = -1;
			}

			slashDisplay('discuss_list', {
				discussions	=> $discussions,
				label		=> $label,
				forward		=> $forward,
				args		=> _buildargs($form),
				start		=> $start,
				back		=> $back,
			});
		} else {
			print getData('nodiscussions');
			slashDisplay('discreate', {
				topic => $constants->{discussion_default_topic},
				label => $label,
			}) if $user->{seclev} >= $constants->{discussion_create_seclev};
		}
	} else {
		titlebar("100%", getData('active_discussions'));
		my $start = $form->{start} || 0;
		my $discussions = $searchdb->findDiscussion({ section => $form->{section}, type => 'open' }, $constants->{discussion_display_limit} + 1, $start, $constants->{discussion_sort_order});
		if ($discussions && @$discussions) {
			my $forward;
			if (@$discussions == $constants->{discussion_display_limit} + 1) {
				pop @$discussions;
				$forward = $start + $constants->{discussion_display_limit};
			} else {
				$forward = 0;
			}

			# if there are less than discussion_display_limit remaning,
			# just set it to 0
			my $back;
			if ($start > 0) {
				$back = $start - $constants->{discussion_display_limit};
				$back = $back > 0 ? $back : 0;
			} else {
				$back = -1;
			}

			slashDisplay('discuss_list', {
				discussions	=> $discussions,
				label		=> $label,
				forward		=> $forward,
				args		=> _buildargs($form),
				start		=> $start,
				back		=> $back,
			});
		} else {
			print getData('nodiscussions');
			slashDisplay('discreate', {
				topic => $constants->{discussion_default_topic},
				label	=> $label,
			}) if $user->{seclev} >= $constants->{discussion_create_seclev};
		}
	}
}

##################################################################
# Index of recent discussions: Used if comments.pl is called w/ no
# parameters
sub commentIndexUserCreated {
	my($form, $slashdb, $user, $constants) = @_;
	my $label = getData('label');

	my $searchdb = getObject('Slash::Search', $constants->{search_db_user});
	my $start = $form->{start} || 0;
	my $hashref = {};
	$hashref->{section} = $form->{section} if $form->{section};
	$hashref->{tid} = $form->{tid} if $form->{tid};
	$hashref->{type} = 'recycle'; 
	$hashref->{approved} = '1'; 

	my $discussions = $searchdb->findDiscussion($hashref, $constants->{discussion_display_limit} + 1, $start, $constants->{discussion_sort_order});
	if ($discussions && @$discussions) {
		my $forward;
		if (@$discussions == $constants->{discussion_display_limit} + 1) {
			pop @$discussions;
			$forward = $start + $constants->{discussion_display_limit};
		} else {
			$forward = 0;
		}

		# if there are less than discussion_display_limit remaning,
		# just set it to 0
		my $back;
		if ($start > 0) {
			$back = $start - $constants->{discussion_display_limit};
			$back = $back > 0 ? $back : 0;
		} else {
			$back = -1;
		}

	
		my $title = getData('user_discussions');

		$title .= ": " . $slashdb->getTopic($form->{tid},'alttext') . " ($form->{tid})" if $form->{tid};

		slashDisplay('udiscuss_list', {
			title 		=> $title,
			discussions	=> $discussions,
			label		=> $label,
			forward		=> $forward,
			args		=> _buildargs($form),
			start		=> $start,
			back		=> $back,
		});
	} else {
		print getData('nodiscussions');
		slashDisplay('discreate', {
			topic => $constants->{discussion_default_topic},
			label => $label,
		}) if $user->{seclev} >= $constants->{discussion_create_seclev};
	}
}

##################################################################
# Index of recent discussions: Used if comments.pl is called w/ no
# parameters
sub commentIndexCreator {
	my($form, $slashdb, $user, $constants) = @_;

	my $label = getData('label');
	my($uid, $nickname);
	if ($form->{uid} or $form->{nick}) {
		$uid		= $form->{uid} ? $form->{uid} : $slashdb->getUserUID($form->{nick});
		$nickname	= $slashdb->getUser($uid, 'nickname');
	} else {
		$uid		= $user->{uid};
		$nickname	= $user->{nickname};
	}

	if (isAnon($uid)) {
		return displayComments(@_);
	}
	my $searchdb = getObject('Slash::Search', $constants->{search_db_user});

	titlebar("90%", getData('user_discussion', { name => $nickname}));
	my $start = $form->{start} || 0;
	my $discussions = $searchdb->findDiscussion({ section => $form->{section}, type => 'recycle', uid => $uid }, $constants->{discussion_display_limit} + 1, $start, $constants->{discussion_sort_order});
	if ($discussions && @$discussions) {
		my $forward;
		if (@$discussions == $constants->{discussion_display_limit} + 1) {
			pop @$discussions;
			$forward = $start + $constants->{discussion_display_limit};
		} else {
			$forward = 0;
		}

		# if there are less than discussion_display_limit remaning,
		# just set it to 0
		my $back;
		if ($start > 0) {
			$back = $start - $constants->{discussion_display_limit};
			$back = $back > 0 ? $back : 0;
		} else {
			$back = -1;
		}

		slashDisplay('discuss_list', {
			discussions	=> $discussions,
			'label'		=> $label,
			forward		=> $forward,
			args		=> _buildargs($form),
			start		=> $start,
			supress_create	=> 1,
			back		=> $back,
		});
	} else {
		print getData('users_no_discussions');
	}
}

##################################################################
# Index of recent discussions: Used if comments.pl is called w/ no
# parameters
sub commentIndexPersonal {
	my($form, $slashdb, $user, $constants) = @_;

	my $label = getData('label');

	titlebar("90%", getData('user_discussion', { name => $user->{nickname}}));
	my $start = $form->{start} || 0;
	my $searchdb = getObject('Slash::Search', $constants->{search_db_user});
	my $discussions = $searchdb->findDiscussion({ section => $form->{section}, type => 'recycle', uid => $user->{uid} }, $constants->{discussion_display_limit} + 1, $start, $constants->{discussion_sort_order});
	if ($discussions && @$discussions) {
		my $forward;
		if (@$discussions == $constants->{discussion_display_limit} + 1) {
			pop @$discussions;
			$forward = $start + $constants->{discussion_display_limit};
		} else {
			$forward = 0;
		}

		# if there are less than discussion_display_limit remaning,
		# just set it to 0
		my $back;
		if ($start > 0) {
			$back = $start - $constants->{discussion_display_limit};
			$back = $back > 0 ? $back : 0;
		} else {
			$back = -1;
		}

		slashDisplay('discuss_list', {
			discussions	=> $discussions,
			'label'		=> $label,
			forward		=> $forward,
			args		=> _buildargs($form),
			start		=> $start,
			supress_create	=> 1,
			back		=> $back,
		});
	} else {
		print getData('users_no_discussions');
	}
}

##################################################################
# Yep, I changed the l33t method of adding discussions.
# "The Slash job, keeping trolls on their toes"
# -Brian
sub createDiscussion {
	my($form, $slashdb, $user, $constants) = @_;
	my $id;

	my $label = getData('label');

	if ($user->{seclev} >= $constants->{discussion_create_seclev}) {
		# if form.url is empty, try the referrer.  if it
		# matches comments.pl without any query string,
		# then (later, down below) set url to point to discussion
		# itself.
		# this only catches URLs without query string ...
		# we don't want to override prefs too easily.  this
		# can be modified to become more inclusive later,
		# if needed.  -- pudge
		my $newurl	= $form->{url}
			? $form->{url}
			: $ENV{HTTP_REFERER} =~ m|\Q$constants->{rootdir}/comments.pl\E$|
				? ""
				: $ENV{HTTP_REFERER};
		$form->{url}	= fudgeurl($newurl);
		$form->{title}	= strip_notags($form->{title});


		# for now, use the postersubj filters; problem is,
		# the error messages can come out a bit funny.
		# oh well.  -- pudge
		my($error, $err_message);
		if (! filterOk('comments', 'postersubj', $form->{title}, \$err_message)) {
			$error = getError('filter message', {
				err_message	=> $err_message
			});
		} elsif (! compressOk('comments', 'postersubj', $form->{title})) {
			$error = getError('compress filter', {
				ratio	=> 'postersubj',
			});
		} else {
			# BTW we are not setting section since at this point we wouldn't
			# trust users to set it correctly -Brian
			$id = $slashdb->createDiscussion({
				title	=> $form->{title},
				topic	=> $form->{topic},
				url	=> $form->{url} || 1,
				type	=> "recycle"
			});

			# fix URL to point to discussion if no referrer
			if (!$form->{url}) {
				$newurl = $constants->{rootdir} . "/comments.pl?sid=$id";
				$slashdb->setDiscussion($id, { url => $newurl });
			}
		}

		my $formats = $slashdb->getDescriptions('postmodes');
		my $postvar = $form->{posttype} ? $form : $user;
		my $format_select = createSelect(
			'posttype', $formats, $postvar->{posttype}, 1
		);

		# Update form with the new SID for comment creation and other
		# variables necessary. See "edit_comment;misc;default".
		my $newform = {
			sid	=> $id,
			pid	=> 0, 
			title	=> $form->{title},
			formkey => $form->{formkey},
		};
		# We COULD drop ID from the call below, but not right now.
		slashDisplay('newdiscussion', { 
			error 		=> $error, 
			'label'		=> $label,
			form		=> $newform,
			format_select	=> $format_select,
			id 		=> $id,
		});
	} else {
		slashDisplay('newdiscussion', {
			error => getError('seclevtoolow'),
		});
	}

	# commentIndex(@_);
}

##################################################################
# Welcome to one of the ancient beast functions.  The comment editor
# is the form in which you edit a comment.
sub editComment {
	my($form, $slashdb, $user, $constants, $discussion, $error_message) = @_;

	my $preview;
	my $error_flag = 0;

	# Get the comment we may be responding to. Remember to turn off
	# moderation elements for this instance of the comment.
	my $reply = $slashdb->getCommentReply($form->{sid}, $form->{pid});

	if (!$constants->{allow_anonymous} && $user->{is_anon}) {
		print getError('no anonymous posting');
		return;
	}

	if ($discussion->{type} eq 'archived') {
		print getData('archive_error');
		return;
	}

	if (lc($form->{op}) ne 'reply' || $form->{op} eq 'preview' || ($form->{postersubj} && $form->{postercomment})) {
		$preview = previewForm(\$error_message) or $error_flag++;
	}

	if ($form->{pid} && !$form->{postersubj}) {
		$form->{postersubj} = decode_entities($reply->{subject});
		$form->{postersubj} =~ s/^Re://i;
		$form->{postersubj} =~ s/\s\s/ /g;
		$form->{postersubj} = "Re:$form->{postersubj}";
	}

	my $formats = $slashdb->getDescriptions('postmodes');

	my $format_select = $form->{posttype}
		? createSelect('posttype', $formats, $form->{posttype}, 1)
		: createSelect('posttype', $formats, $user->{posttype}, 1);

	if ($form->{op} =~ /^reply$/i) {
		$form->{nobonus}  = $user->{nobonus};
		$form->{postanon} = $user->{postanon};
	}

	slashDisplay('edit_comment', {
		error_message 	=> $error_message,
		format_select	=> $format_select,
		preview		=> $preview,
		reply		=> $reply,
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

	my $form_success = 1;
	my $message = '';

	my $read_only;
	for (qw(ipid subnetid uid)) {
		# We skip the UID test for anonymous users.
		next if $_ eq 'uid' && $user->{is_anon};
		# Otherwise we perform the specific read-only test.
		$read_only = $slashdb->checkReadOnly('comments', {
        	        $_ => $user->{$_},
	        });
		# Bail if a specific test returns TRUE
		last if $read_only;
	}
        if ($read_only) {
                $$error_message = getError('readonly');
                $form_success = 0;
                # editComment('', $$error_message), return unless $preview;
                return;
        }

	# New check (July 2002):  there is a max number of posts per 24-hour
	# period, either based on IPID for anonymous users, or on UID for
	# logged-in users.  Logged-in users get a max number of posts that
	# is related to their karma.  The comments_perday_bykarma var
	# controls it (that var is turned into a hashref in MySQL.pm when
	# the vars table is read in, whose keys we loop over to find the
	# appropriate level).
	if ($user->{is_anon} && $constants->{comments_perday_anon}
		&& !$user->{is_admin}) {
		my $num_comm_posted = $slashdb->getNumCommPostedAnonByIPID(
			$user->{ipid}, 24);
		if ($num_comm_posted >= $constants->{comments_perday_anon}) {
			$$error_message = getError('comments post limit daily', {
				limit => $constants->{comments_perday_anon}
			});
			$form_success = 0;
			return;
		}
	} elsif (!$user->{is_anon} && $constants->{comments_perday_bykarma}
		&& !$user->{is_admin}) {
		my $num_comm_posted = $slashdb->getNumCommPostedByUID(
			$user->{uid}, 24);
		my $num_allowed = 9999;
		K_CHECK: for my $k (sort { $a <=> $b }
			keys %{$constants->{comments_perday_bykarma}}) {
			if ($user->{karma} <= $k) {
				$num_allowed = $constants->{comments_perday_bykarma}{$k};
				last K_CHECK;
			}
		}
		if ($num_comm_posted >= $num_allowed) {
			$$error_message = getError('comments post limit daily', {
				limit => $num_allowed
			});
			$form_success = 0;
			return;
		}
	}

	if (isTroll()) {
		$$error_message = getError('troll message', {
			unencoded_ip => $ENV{REMOTE_ADDR}      
		});
		return;
	}

	if (!$constants->{allow_anonymous} && ($user->{is_anon} || $form->{postanon})) {
		$$error_message = getError('anonymous disallowed');
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

	unless (defined($$comm = balanceTags($$comm, $constants->{nesting_maxdepth}))) {
		# If we didn't return from right here, one or more later
		# error messages would overwrite this one.
		$$error_message = getError('nesting too deep');
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

		my $max_comment_len = $slashdb->getUser(
			$constants->{anonymous_coward_uid},                  
			'maxcommentsize');
		my $check_prefix = substr($$comm, 0, $max_comment_len);
		my $check_prefix_len = length($check_prefix);
		my $min_line_len_max = $constants->{comments_min_line_len_max}
			|| $constants->{comments_min_line_len}*2;
		my $min_line_len = $constants->{comments_min_line_len}
			+ ($min_line_len_max - $constants->{comments_min_line_len})
				* ($check_prefix_len - $kickin)
				/ ($max_comment_len - $kickin);

		my $check_notags = strip_nohtml($check_prefix);
		# Don't count & or other chars used in entity tags;  don't count
		# chars commonly used in ascii art.  Not that it matters much.
		# Do count chars commonly used in source code.
		my $num_chars = $check_notags =~ tr/A-Za-z0-9?!(){}[]-+='"@$//;

		# Note that approveTags() has already been called by this point,
		# so all tags present are legal and uppercased.
		my $breaktags = $constants->{'approvedtags_break'}
			|| [qw(HR BR LI P OL UL BLOCKQUOTE DIV)];
		my $breaktags_1_regex = "<(?:" . join("|", @$breaktags) . ")>";
		my $breaktags_2_regex = "<(?:" . join("|", grep /^(P|BLOCKQUOTE)$/, @$breaktags) . ")>";
		my $num_lines = 0;
		$num_lines++ while $check_prefix =~ /$breaktags_1_regex/g;
		$num_lines++ while $check_prefix =~ /$breaktags_2_regex/g;

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

	$$error_message ||= '';
	# Return false if error condition...
	return if ! $form_success;

	# ...otherwise return true.
	return 1;
}


##################################################################
# Previews a comment for submission
sub previewForm {
	my($error_message) = @_;
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	$user->{sig} = "" if $form->{postanon};

	my $tempSubject = strip_notags($form->{postersubj});
	my $tempComment = $form->{postercomment};

	# The strip_mode needs to happen before the balanceTags() which is
	# called from validateComment.  This is because strip_mode calls
	# stripBadHtml, which calls approveTag repeatedly, which
	# eliminates malformed tags.  balanceTags should not ever see
	# malformed tags or it may choke.
	#
	# For the mode "CODE", validateComment() is called with a
	# "whitespace factor" half what is normally used.  Code is likely
	# to have many linebreaks and runs of whitespace; this makes the
	# compression filter more lenient about allowing them.

	$tempComment = strip_mode($tempComment, $form->{posttype});

	validateComment(
		\$tempComment, \$tempSubject, $error_message, 1,
		($form->{posttype} == CODE
			? $constants->{comments_codemode_wsfactor}
			: $constants->{comments_wsfactor} || 1) )
		or return;

	$tempComment = addDomainTags($tempComment);
	$tempComment = parseDomainTags($tempComment,
		!$form->{postanon} && $user->{fakeemail});

	my $sig = $user->{sig};
	if ($user->{sigdash} && $user->{sig}) {
		$sig = "--<BR>$sig";
	}

	my $preview = {
		nickname	=> $form->{postanon}
					? getCurrentAnonymousCoward('nickname')
					: $user->{nickname},
		pid		=> $form->{pid},
		homepage	=> $form->{postanon} ? '' : $user->{homepage},
		fakeemail	=> $form->{postanon} ? '' : $user->{fakeemail},
		'time'		=> $slashdb->getTime(),
		subject		=> $tempSubject,
		comment		=> $tempComment,
		sig		=> $sig,
	};

	my $tm = $user->{mode};
	$user->{mode} = 'archive';
	my $previewForm;
	if ($tempSubject && $tempComment) {
		$previewForm = slashDisplay('preview_comm', {
			preview => $preview,
		}, 1);
	}
	$user->{mode} = $tm;

	return $previewForm;
}

##################################################################
# Saves the Comment
# A note, right now form->{sid} is a discussion id, not a
# story id.
sub submitComment {
	my($form, $slashdb, $user, $constants, $discussion) = @_;
	if ($discussion->{type} eq 'archived') {
		print getData('archive_error');
		return;
	}

	my $error_message;

	my $tempSubject = strip_notags($form->{postersubj});
	my $tempComment = $form->{postercomment};

	# See the comment above validateComment() called from previewForm.
	# Same thing applies here.

	$tempComment = strip_mode($tempComment, $form->{posttype});

	unless (validateComment(
		\$tempComment, \$tempSubject, $error_message, 1,
		($form->{posttype} == CODE
			? $constants->{comments_codemode_wsfactor}
			: $constants->{comments_wsfactor} || 1) )
	) {
		$slashdb->resetFormkey($form->{formkey});
		editComment(@_, $error_message);
		return(0);
	}

	$tempComment = addDomainTags($tempComment);

#	# Slash is not a file exchange system
#	# still working on this...stay tuned for real commit
#	# (maybe in 2.x... sigh)
#	$tempComment = distressBinaries($tempComment);

	titlebar("95%", getData('submitted_comment'));

	my $pts = 0;

	if (!$user->{is_anon} && !$form->{postanon}) {
		$pts = $user->{defaultpoints};
		$pts-- if $user->{karma} < 0;
		$pts-- if $user->{karma} < $constants->{badkarma};
		$pts++ if $pts >= 1 && $user->{karma} > $constants->{goodkarma}
			&& !$form->{nobonus};
		# Enforce proper ranges on comment points.
		my($minScore, $maxScore) =
			($constants->{comment_minscore}, $constants->{comment_maxscore});
		$pts = $minScore if $pts < $minScore;
		$pts = $maxScore if $pts > $maxScore;
	}
	# This is here to prevent posting to discussions that don't exist/are nd -Brian
	unless ($user->{is_admin}) {
		unless ($slashdb->checkDiscussionPostable($form->{sid})) {
			print getError('submission error');
			return(0);
		}
	}

	my $clean_comment = {
		subject		=> $tempSubject,
		comment		=> $tempComment,
		sid		=> $form->{sid} , 
		pid		=> $form->{pid} ,
		ipid		=> $user->{ipid},
		subnetid	=> $user->{subnetid},
		uid		=> $form->{postanon} ? $constants->{anonymous_coward_uid} : $user->{uid},
		points		=> $pts,
	};

	my $maxCid = $slashdb->createComment($clean_comment);

	# make the formkeys happy
	$form->{maxCid} = $maxCid;

	$slashdb->setUser($user->{uid}, {
		'-expiry_comm'	=> 'expiry_comm-1',
	}) if allowExpiry();

	if ($maxCid == -1) {
		# What vars should be accessible here?
		print getError('submission error');
		return(0);

	} elsif (!$maxCid) {
		# What vars should be accessible here?
		#	- $maxCid?
		# What are the odds on this happening? Hmmm if it is we should
		# increase the size of int we used for cid.
		print getError('maxcid exceeded');
		return(0);
	} else {
		slashDisplay('comment_submit');
		undoModeration($form->{sid});
		printComments($discussion, $maxCid, $maxCid);

		my $tc = $slashdb->getVar('totalComments', 'value');
		$slashdb->setVar('totalComments', ++$tc);

		# This is for stories. If a sid is only a number
		# then it belongs to discussions, if it has characters
		# in it then it belongs to stories and we should
		# update to help with stories/hitparade.
		# -Brian
		if ($discussion->{sid}) {
			$slashdb->setStory($discussion->{sid}, { writestatus => 'dirty' });
		}

		$slashdb->setUser($user->{uid}, {
			-totalcomments => 'totalcomments+1',
		});

		my($messages, $reply, %users);
		if ($form->{pid} || $discussion->{url} =~ /\bjournal\b/ || $constants->{commentnew_msg}) {
			$messages = getObject('Slash::Messages');
			$reply = $slashdb->getCommentReply($form->{sid}, $maxCid);
		}

		# reply to comment
		if ($messages && $form->{pid}) {
			my $parent = $slashdb->getCommentReply($form->{sid}, $form->{pid});
			my $users  = $messages->checkMessageCodes(MSG_CODE_COMMENT_REPLY, [$parent->{uid}]);
			if (_send_comment_msg($users->[0], \%users, $pts)) {
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
		if ($messages && $discussion->{url} =~ /\bjournal\b/) {
			my $users  = $messages->checkMessageCodes(MSG_CODE_JOURNAL_REPLY, [$discussion->{uid}]);
			if (_send_comment_msg($users->[0], \%users, $pts)) {
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
			for my $usera (@$users) {
				next if $users{$usera};
				$messages->create($usera, MSG_CODE_NEW_COMMENT, $data);
				$users{$usera}++;
			}
		}
	}

	return(1);
}


##################################################################
# Decide whether or not to send a given message to a given user
sub _send_comment_msg {
	my($uid, $uids, $pts) = @_;
	my $constants	= getCurrentStatic();
	my $slashdb	= getCurrentDB();
	my $user	= getCurrentUser();

	return unless $uid;			# no user
	return if $uids->{$uid};		# user not already being msgd
	return if $user->{uid} == $uid;		# don't msg yourself

	my $user_message_threshold = $slashdb->getUser($uid, 'message_threshold');

	# use message_threshold in vars, unless user has one
	# a message_threshold of 0 is valid, but "" is not
	my $message_threshold = length($user_message_threshold)
		? $user_message_threshold
		: length($constants->{message_threshold})
			? $constants->{message_threshold}
			: undef;

	# only if reply pts meets message threshold
	return if defined $message_threshold && $pts < $message_threshold;

	return 1;
}


##################################################################
# Handles moderation
# gotta be a way to simplify this -Brian
sub moderate {
	my($form, $slashdb, $user, $constants, $discussion) = @_;

	my $sid = $form->{sid};
	my $was_touched = 0;

	if ($discussion->{type} eq 'archived'
		&& !$constants->{comments_moddable_archived}) {
		print getData('archive_error');
		return;
	}

	if (! $constants->{allow_moderation}) {
		print getData('no_moderation');
		return;
	}

	my $total_deleted = 0;
	my $hasPosted;

	# The content here should also probably go into a template.
	titlebar("99%", "Moderating...");

	$hasPosted = $slashdb->countCommentsBySidUID($sid, $user->{uid})
		unless $constants->{authors_unlimited}
			&& $user->{seclev} >= $constants->{authors_unlimited};

	slashDisplay('mod_header');

	# Handle Deletions, Points & Reparenting
	for my $key (sort keys %{$form}) {
		if ($user->{seclev} > 100 and $key =~ /^del_(\d+)$/) {
			$total_deleted += deleteThread($sid, $1);
		} elsif (!$hasPosted and $key =~ /^reason_(\d+)$/) {
			$was_touched += moderateCid($sid, $1, $form->{$key});
		}
	}
	$slashdb->setDiscussionDelCount($sid, $total_deleted);
	$was_touched = 1 if $total_deleted;

	slashDisplay('mod_footer');

	if ($hasPosted && !$total_deleted) {
		print getError('already posted');

	} elsif ($user->{seclev} && $total_deleted) {
		slashDisplay('del_message', {
			total_deleted	=> $total_deleted,
			comment_count	=> $slashdb->countCommentsBySid($sid),
		});
	}
	printComments($discussion, $form->{pid}, $form->{cid});

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


##################################################################
# Handles moderation
# Moderates a specific comment. Returns whether the comment score changed.
sub moderateCid {
	my($sid, $cid, $reason) = @_;
	return 0 unless $reason;

	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	my $comment_changed = 0;
	my $superAuthor = $constants->{authors_unlimited}
		&& $user->{seclev} >= $constants->{authors_unlimited};

	if ($user->{points} < 1 && !$superAuthor) {
		print getError('no points');
		return 0;
	}

	my $comment = $slashdb->getComment($cid);
	$comment->{time_unixepoch} = timeCalc($comment->{date}, "%s", 0);

	# The user should not have been been presented with the menu
	# to moderate if any of the following tests trigger, but,
	# an unscrupulous user could have faked their submission with
	# or without us presenting them the menu options.  So do the
	# tests again.

	unless ($superAuthor) {
		# Do not allow moderation of any comments with the same UID as the
		# current user (duh!).
		return if $user->{uid} == $comment->{uid};
		# Do not allow moderation of any comments (anonymous or otherwise)
		# with the same IP as the current user.
		return if $user->{ipid} eq $comment->{ipid};
		# If the var forbids it, do not allow moderation of any comments
		# with the same *subnet* as the current user.
		return if $constants->{mod_same_subnet_forbid}
			and $user->{subnetid} eq $comment->{subnetid};
		# Do not allow moderation of comments that are too old.
		return unless $comment->{time_unixepoch} >= time() - 3600*
			($constants->{comments_moddable_hours}
				|| 24*$constants->{archive_delay});
	}

	my $dispArgs = {
		cid	=> $cid,
		sid	=> $sid,
		subject => $comment->{subject},
		reason	=> $reason,
		points	=> $user->{points},
	};

	unless ($superAuthor) {
		my $mid = $slashdb->getModeratorLogID($cid, $user->{uid});
		if ($mid) {
			$dispArgs->{type} = 'already moderated';
			slashDisplay('moderation', $dispArgs);
			return 0;
		}
	}

	my $val = "-1";
	if ($reason == 9) { # Overrated
		$val = "-1";
	} elsif ($reason == 10) { # Underrated
		$val = "+1";
	} elsif ($reason > $constants->{badreasons}) {
		$val = "+1";
	}
	# Add moderation value to display arguments.
	$dispArgs->{'val'} = $val;

	my $scorecheck = $comment->{points} + $val;
	my $active = 1;
	# If the resulting score is out of comment score range, no further
	# actions need be performed.
	# Should we return here and go no further?
	if (	$scorecheck < $constants->{comment_minscore} ||
		$scorecheck > $constants->{comment_maxscore})
	{
		# We should still log the attempt for M2, but marked as
		# 'inactive' so we don't mistakenly undo it. Mods get modded
		# even if the action didn't "really" happen.
		#
		$active = 0;
		$dispArgs->{type} = 'score limit';
	}

	# Write the proper records to the moderatorlog.
	$slashdb->setModeratorLog($comment, $user->{uid}, $val, $reason, $active);

	if ($active) {
		# Increment moderators total mods and deduct their point for playing.
		# Word of note, if we are HERE, then the user either has points, or
		# is an author (and 'author_unlimited' is set) so point checks SHOULD
		# be unnecessary here.
		$user->{points}-- if $user->{points} > 0;
		$user->{totalmods}++;
		$slashdb->setUser($user->{uid}, {
			totalmods 	=> $user->{totalmods},
			points		=> $user->{points},
		});

		# Adjust comment posters karma and moderation stats.
		if ($comment->{uid} != $constants->{anonymous_coward_uid}) {
			my $cuser = $slashdb->getUser($comment->{uid}, [ qw| downmods upmods karma | ]);
			my $newkarma = $cuser->{karma} + $val;
			$cuser->{downmods}++ if $val < 0;
			$cuser->{upmods}++ if $val > 0;
			if ($val < 0) {
				$cuser->{karma} = $newkarma; 
			} else {
				$cuser->{karma} = $newkarma 
						if $newkarma <= $constants->{maxkarma};
			}
			$cuser->{karma} = $constants->{minkarma} 
					if $newkarma < $constants->{minkarma};

			$slashdb->setUser($comment->{uid}, {
				karma		=> $cuser->{karma},
				upmods		=> $cuser->{upmods},
				downmods	=> $cuser->{downmods},
			});
		}

		# Make sure our changes get propagated back to the comment.
		$comment_changed =
			$slashdb->setCommentCleanup($cid, $val, $reason,
				$comment->{reason});
		if (!$comment_changed) {
			# This shouldn't happen;  the only way we believe it
			# could is if $val is 0, the comment is already at
			# min or max score, the user's already modded this
			# comment, or some other reason making this mod invalid.
			# This is really just here as a safety check.
			$dispArgs->{type} = 'logic error';
			slashDisplay('moderation', $dispArgs);
			return 0;
		}

		# We know things actually changed, so update points for
		# display and send a message if appropriate.
		$dispArgs->{points} = $user->{points};
		$dispArgs->{type} = 'moderated';

		# Send messages regarding this moderation to user who posted
		# comment if they have that bit set.
		my $messages = getObject('Slash::Messages');
		if ($messages) {
			my $comm = $slashdb->getCommentReply($sid, $cid);
			my $users   = $messages->checkMessageCodes(
				MSG_CODE_COMMENT_MODERATE, [$comment->{uid}]
			);
			if (@$users) {
				my $discussion = $slashdb->getDiscussion($sid);
				if ($discussion->{sid}) {
					# Story discussion, link to it.
					$discussion->{realurl} =
						"$constants->{absolutedir}/article.pl?sid=$discussion->{sid}";
				} else {
					# Some other kind of discussion,
					# probably poll, journal entry, or
					# user-created;  don't trust its url. -- jamie
					# I really don't like this.  I want users
					# to be able to go to the poll or journal
					# directly.  we could consider matching a pattern
					# for journal.pl or pollBooth.pl etc.,
					# but that is not great.  maybe a field in discussions
					# for whether or not url is trusted. -- pudge
					$discussion->{realurl} =
						"$constants->{absolutedir}/comments.pl?sid=$discussion->{id}";
				}
				my $data  = {
					template_name	=> 'mod_msg',
					subject		=> {
						template_name => 'mod_msg_subj'
					},
					comment		=> $comm,
					discussion	=> $discussion,
					moderation	=> {
						user	=> $user,
						value	=> $val,
						reason	=> $reason,
					},
				};
				$messages->create($users->[0],
					MSG_CODE_COMMENT_MODERATE, $data
				);
			}
		}
	}

	# Now display the template with the moderation results.
	slashDisplay('moderation', $dispArgs);

# Now in theory if we are here this is ok.
# I think there is kludge in the above logic at the moment.
# -Brian
	return 1;
}


##################################################################
# Given an SID & A CID this will delete a comment, and all its replies
sub deleteThread {
	my($sid, $cid, $level, $comments_deleted) = @_;
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();

	$level ||= 0;

	my $count = 0;
	my @delList;
	$comments_deleted = \@delList if !$level;

	return unless $user->{seclev} >= 1000;

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
# If you moderate, and then post, all your moderation is undone.
sub undoModeration {
	my($sid) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	# We abandon this operation if:
	#	1) Moderation is off
	#	2) The user is anonymous (they aren't allowed to anyway).
	#	3) The user is an author with a high enough security level
	#	   and that option is turned on.
	return if !$constants->{allow_moderation} || $user->{is_anon} ||
		  ( $constants->{authors_unlimited} && $user->{seclev} >= $constants->{authors_unlimited}
		    && $user->{author} );

	if ($sid !~ /^\d+$/) {
		$sid = $slashdb->getDiscussionBySid($sid, 'header');
	}
	my $removed = $slashdb->undoModeration($user->{uid}, $sid);

	slashDisplay('undo_mod', {
		removed	=> $removed,
	});
}


##################################################################
# Troll Detection: checks to see if this IP or UID has been
# abusing the system in the last 24 hours.
# 1=Troll 0=Good Little Goober
sub isTroll {
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	return 0 if $user->{seclev} >= 100;

	my $good_behavior = 0;
	if (!$user->{is_anon} and $user->{karma} >= 1) {
		if ($form->{postanon}) {
			# If the user is signed in but posting anonymously,
			# their karma helps a little bit to offset their
			# trollishness.  But not much.
			$good_behavior = int(log($user->{karma})+0.5);
		} else {
			# If the user is signed in with karma at least 1 and
			# posts with their name, the IP ban doesn't apply.
			return 0;
		}
	}

	return $slashdb->getIsTroll($good_behavior);
}

##################################################################
createEnvironment();
main();
1;

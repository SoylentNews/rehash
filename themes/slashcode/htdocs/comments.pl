#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
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
		create_discussion	=> {
			function		=> \&createDiscussion,
			seclev			=> 1,
			post			=> 1,
			formname 		=> 'discussions',
			checks			=> 
			[ qw ( max_post_check valid_check interval_check 
				formkey_check regen_formkey ) ],
		},
		delete_forum		=> {
			function		=> \&deleteForum,
			seclev			=> 1000,
			formname		=> 'discussions',
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
			formname 		=> $form->{newdiscussion} ? 'discussions' : 'comments',
			checks			=> 
			[ qw ( update_formkeyid max_post_check ) ], 
		},
		post 			=> {
			function		=> \&editComment,
			seclev			=> 0,
			formname 		=> $form->{newdiscussion} ? 'discussions' : 'comments',
			checks			=> 
			[ qw ( update_formkeyid max_post_check generate_formkey	) ],
		},
		submit => {
			function		=> \&submitComment,
			seclev			=> 0,
			post			=> 1,
			formname 		=> $form->{newdiscussion} ? 'discussions' : 'comments',
			checks			=> 
			[ qw ( response_check update_formkeyid max_post_check valid_check interval_check formkey_check ) ],
		},
	};
	$ops->{default} = $ops->{display} ;
	
	# This is here to save a function call, even though the
	# function can handle the situation itself
	my ($discussion, $section);

	my $future_err = 0;
	if ($form->{sid}) {
		# SID compatibility
		if ($form->{sid} !~ /^\d+$/) {
			$discussion = $slashdb->getDiscussionBySid($form->{sid});
			$section = $discussion->{section};
			if ($constants->{tids_in_urls}) {
				my $tids = $slashdb->getStoryTopicsJustTids($form->{sid}); 
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
		# The is_future field isn't automatically added by getDiscussion
		# like it is with getStory.  We have to add it manually here.
		$discussion->{is_future} = 1 if $slashdb->checkDiscussionIsInFuture($discussion);
		# Now check to make sure this discussion can be seen.
		if (!($user->{author} || $user->{is_admin}) && $discussion) {
			my $null_it_out = 0;
			if ($discussion->{is_future}) {
				# Discussion is from the future;  decide here
				# whether the user is allowed to see it or not.
				# If not, we'll present the error a bit later.
				if (!$constants->{subscribe} || !$user->{is_subscriber}) {
					$future_err = 1;
					$null_it_out = 1;
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

	my $title = 'Comments';

	if ($discussion && $constants->{ubb_like_forums}
		&& ($discussion->{type} eq 'recycle')) {
		$title = $constants->{sitename} . ": Forums - "
			. $discussion->{'title'};
	} elsif ($discussion) {
		$title = $discussion->{'title'};
	} elsif ((!$discussion) && $constants->{ubb_like_forums}) {
		$title = 'Forums';
	}

	header($title, $section) or return;

	if ($user->{is_anon} && length($form->{upasswd}) > 1) {
		print getError('login error');
		$op = 'preview';
	}
	$op = 'default' if ( ($user->{seclev} < $ops->{$op}{seclev}) || ! $ops->{$op}{function});
	$op = 'default' if (! $postflag && $ops->{$op}{post});

	if ($future_err) {
		print getError("nosubscription");
	}

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
		$options->{no_hc} = 1 if
			   !$constants->{plugin}{HumanConf}
			|| !$constants->{hc}
			|| !$constants->{hc_sw_comments}
			|| (!$user->{is_anon}
			   && $user->{karma} > $constants->{hc_maxkarma});
 
		my $done = 0;
		DO_CHECKS: while (!$done) {
			$formname = $ops->{$op}{formname}; 
			for my $check (@{$ops->{$op}{checks}}) {
				$ops->{$op}{update_formkey} = 1 if $check eq 'formkey_check';
				$error_flag = formkeyHandler($check, $formname, $formkey,
					undef, $options);
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

	# The content here should also probably go into a template.
	titlebar("100%", "Delete $form->{cid}");

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

	if (defined($form->{show_m2s}) && $user->{is_admin}) {
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
	} elsif ($constants->{ubb_like_forums}) {
		commentIndexUserCreated(@_);
	} else {
		commentIndex(@_);
	}
}


##################################################################
# Index of recent discussions: Used if comments.pl is called w/ no
# parameters
sub commentIndex {
	my($form, $slashdb, $user, $constants, $error_message) = @_;

	my $label = getData('label');

	my $searchdb = getObject('Slash::Search', $constants->{search_db_user});
	if ($form->{all}) {
		titlebar("100%", getData('all_discussions'));
		my $start = $form->{start} || 0;
		my $discussions = $searchdb->findDiscussion({ section => $form->section }, $start,
			$constants->{discussion_display_limit} + 1, $constants->{discussion_sort_order}
		);
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
				error_message	=> $error_message,
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
		my $discussions = $searchdb->findDiscussion({ section => $form->{section}, type => 'open' },
			$start, $constants->{discussion_display_limit} + 1, $start, $constants->{discussion_sort_order}
		);
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
				error_message	=> $error_message,
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
	my($form, $slashdb, $user, $constants, $error_message) = @_;
	my $label = getData('label');

	# um, let's put this in the template
	# titlebar("100%", getData('user_discussions'));
	my $searchdb = getObject('Slash::Search', $constants->{search_db_user});
	my $start    = $form->{start} || 0;
	my $hashref  = {};
	my $sections;
	$hashref->{section}  = $form->{section} if $form->{section};
	$hashref->{tid}      = $form->{tid} if $form->{tid};
	$hashref->{type}     = 'recycle'; 
	$hashref->{approved} = '1'; 

	my $discussions = $searchdb->findDiscussion(
		$hashref, 
		$constants->{discussion_display_limit} + 1, 
		$start, $constants->{discussion_sort_order});

	my $section_select;	
	if ($constants->{ubb_like_forums}) {
		$sections = $slashdb->getDescriptions('forums');
		$section_select = createSelect('section', $sections, $form->{section}, 1);
		for (my $i=0; $i < @$discussions; $i++) {
			$discussions->[$i]{comment} = $slashdb->getForumDescription($discussions->[$i]{id});
			$discussions->[$i]{num_parents} = $slashdb->getForumParents($discussions->[$i]{id});
			$discussions->[$i]{last_comment} = $slashdb->getForumLastPostHashref($discussions->[$i]{id});
		}
	}

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

# REMOVE ?

#		$title .= ": " . $slashdb->getTopic($form->{tid},'alttext') . " ($form->{tid})" if $form->{tid};

		slashDisplay('udiscuss_list', {
			discussions	=> $discussions,
			error_message	=> $error_message,
			title 		=> getData('user_discussions'),
			'label'		=> $label,
			forward		=> $forward,
			args		=> _buildargs($form),
			start		=> $start,
			back		=> $back,
			sections	=> $sections,
			section_select  => $section_select,
		});
	} else {
		print getData('nodiscussions');
		slashDisplay('edit_comment', {
			newdiscussion	=> 1,
			label		=> $label,
			section_select  => $section_select,
		}) if $user->{seclev} >= $constants->{discussion_create_seclev};
	}
}

##################################################################
# Index of recent discussions: Used if comments.pl is called w/ no
# parameters
sub commentIndexCreator {
	my($form, $slashdb, $user, $constants, $error_message) = @_;

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

	titlebar("100%", getData('user_discussion', { name => $nickname}));
	my $start = $form->{start} || 0;
	my $discussions = $searchdb->findDiscussion({ section => $form->{section}, type => 'recycle', uid => $uid },
		$start, $constants->{discussion_display_limit} + 1, $constants->{discussion_sort_order}
	);
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
			indextype	=> 'creator',
			error_message	=> $error_message,
			'label'		=> $label,
			forward		=> $forward,
			args		=> _buildargs($form),
			start		=> $start,
			suppress_create	=> 1,
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
	my($form, $slashdb, $user, $constants, $error_message) = @_;

	my $label = getData('label');

	titlebar("100%", getData('user_discussion', { name => $user->{nickname}}));
	my $start = $form->{start} || 0;
	my $searchdb = getObject('Slash::Search', $constants->{search_db_user});
	my $discussions = $searchdb->findDiscussion({ section => $form->{section}, type => 'recycle', uid => $user->{uid} },
		$start, $constants->{discussion_display_limit} + 1, $constants->{discussion_sort_order}
	);
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
			indextype	=> 'personal', 
			error_message	=> $error_message,
			'label'		=> $label,
			forward		=> $forward,
			args		=> _buildargs($form),
			start		=> $start,
			suppress_create	=> 1,
			back		=> $back,
		});
	} else {
		print getData('users_no_discussions');
	}
}

##################################################################
# for ubb_like_forums
sub deleteForum {
	my($form, $slashdb, $user, $constants, $error_message) = @_;

	$slashdb->deleteDiscussion($form->{sid}) if $constants->{ubb_like_forums};
	commentIndexUserCreated(@_);

	return;
}

##################################################################
# This is where all of the real discussion creation occurs 
# Returns the discussion id of the created discussion
# -Brian
sub _createDiscussion {
	my($form, $slashdb, $user, $constants) = @_;
	my $id;

	if ($user->{seclev} >= $constants->{discussion_create_seclev} || $user->{is_admin}) {
		# if form.url is empty, try the referrer.  if it
		# matches comments.pl without any query string,
		# then (later, down below) set url to point to discussion
		# itself.
		# this only catches URLs without query string ...
		# we don't want to override prefs too easily.  this
		# can be modified to become more inclusive later,
		# if needed.  -- pudge
		my $newurl	   = $form->{url}
			? $form->{url}
			: $ENV{HTTP_REFERER} =~ m|\Q$constants->{rootdir}/comments.pl\E$|
				? ""
				: $ENV{HTTP_REFERER};
		$form->{url}	   = fudgeurl($newurl);
		# $form->{title}	= strip_notags($form->{title});
		$form->{title}	   = strip_notags($form->{postersubj});
		$form->{topic}   ||= $constants->{defaulttopic};
		$form->{section} ||= $constants->{defaultsection};


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
				section => $form->{section},
				url	=> $form->{url} || 1,
				type	=> "recycle"
			});

			# fix URL to point to discussion if no referrer
			if (!$form->{url}) {
				$newurl = $constants->{rootdir} . "/comments.pl?sid=$id";
				$slashdb->setDiscussion($id, { url => $newurl });
			}
		}
	} else {
		slashDisplay('newdiscussion', {
			error => getError('seclevtoolow'),
		});
	}

	return $id;
}

##################################################################
# Yep, I changed the l33t method of adding discussions.
# "The Slash job, keeping trolls on their toes"
# -Brian
sub createDiscussion {
	my($form, $slashdb, $user, $constants) = @_;

	my $label = getData('label');
	my $id = _createDiscussion($form, $slashdb, $user, $constants);
	commentIndex(@_);
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

	my($sections, $section_select);
	if ($constants->{ubb_like_forums} && $form->{section} && $form->{newdiscussion}) {
		$sections = $slashdb->getDescriptions('forums');
		$section_select = createSelect('section', $sections, $form->{section}, 1);
	}

	my $gotmodwarning;
	$gotmodwarning = 1 if (($error_message eq getError("moderations to be lost")) || $form->{gotmodwarning});
	slashDisplay('edit_comment', {
		error_message 	=> $error_message,
		label		=> $label,
		discussion	=> $discussion,
		indextype	=> $form->{indextype},
		preview		=> $preview,
		reply		=> $reply,
		gotmodwarning	=> $gotmodwarning,
		newdiscussion	=> $form->{newdiscussion},
		section_select  => $section_select,
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
	if (!dbAvailable("write_comments")) {
		$$error_message = getError('comment_db_down');
		$form_success = 0;
		return;
	}
	for (qw(ipid subnetid uid)) {
		# We skip the UID test for anonymous users.
		next if $_ eq 'uid' && $user->{is_anon};
		# Otherwise we perform the specific read-only test.
		$read_only = $slashdb->checkReadOnly('nopost', {
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
		my $is_trusted = $slashdb->checkIsTrusted($user->{ipid});
		if ($is_trusted ne 'yes') {
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
	if ($user->{is_anon} && $constants->{comments_perday_anon}
		&& !$user->{is_admin}) {
		my($num_comm, $sum_mods) = $slashdb->getNumCommPostedAnonByIPID(
			$user->{ipid}, 24);
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
		my($num_comm, $sum_mods) = $slashdb->getNumCommPostedByUID(
			$user->{uid}, 24);
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

	if ($constants->{allow_moderation}
		&& !$user->{is_anon}
		&& !$form->{postanon}
		&& !$form->{gotmodwarning}
		&& !( $constants->{authors_unlimited}
			&& $user->{seclev} >= $constants->{authors_unlimited} )
		&& !$user->{acl}{modpoints_always}
		&& $slashdb->countUserModsInDiscussion($user->{uid}, $form->{sid}) > 0
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
	my($error_message) = @_;
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	$user->{sig} = "" if $form->{postanon};
	my $label = getData('label');

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

	$tempComment = strip_mode($tempComment,
		# if no posttype given, pick a default
		$form->{posttype} || PLAINTEXT
	);

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
		$sig =~ s/^\s*-{1,5}\s*<(?:P|BR)>//i;
		$sig = "--<BR>$sig";
	}

	my $preview = {
		nickname		=> $form->{postanon}
						? getCurrentAnonymousCoward('nickname')
						: $user->{nickname},
		pid			=> $form->{pid},
		uid			=> $form->{postanon} ? '' : $user->{uid},
		homepage		=> $form->{postanon} ? '' : $user->{homepage},
		fakeemail		=> $form->{postanon} ? '' : $user->{fakeemail},
		journal_last_entry_date	=> $user->{journal_last_entry_date} || '',
		'time'			=> $slashdb->getTime(),
		subject			=> $tempSubject,
		comment			=> $tempComment,
		sig			=> $sig,
	};

	if ($constants->{plugin}{Subscribe}) {
		$preview->{subscriber_bonus} = $user->{is_subscriber} && $form->{nosubscriberbonus} ne 'on'
			? 1 : 0;
	}

	my $tm = $user->{mode};
	$user->{mode} = 'archive';
	my $previewForm;
	if ($form->{newdiscussion} && $user->{seclev} < $constants->{discussion_create_seclev}) { 
		$previewForm = slashDisplay('newdiscussion', {
			error => getError('seclevtoolow'),
		});
	} elsif ($tempSubject && $tempComment) {
		$previewForm = slashDisplay('preview_comm', {
			label	=> $label,
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

	$form->{nobonus}  = $user->{nobonus}	unless $form->{nobonus_present};
	$form->{postanon} = $user->{postanon}	unless $form->{postanon_present};
	$form->{nosubscriberbonus} = $user->{nosubscriberbonus}
						unless $form->{nosubscriberbonus_present};

	my $id = $form->{sid};
	my $label = getData('label');

	# Couple of rules on how to treat the discussion depending on how mode is set -Brian
	$discussion->{type} = isDiscussionOpen($discussion);

	if ($discussion->{type} eq 'archived') {
		print getData('archive_error');
		return;
	}

	my $error_message;

	my $tempSubject = strip_notags($form->{postersubj});
	my $tempComment = $form->{postercomment};

	# See the comment above validateComment() called from previewForm.
	# Same thing applies here.

	$tempComment = strip_mode($tempComment,
		# if no posttype given, pick a default
		$form->{posttype} || PLAINTEXT
	);

	unless (validateComment(
		\$tempComment, \$tempSubject, $error_message, 1,
		($form->{posttype} == CODE
			? $constants->{comments_codemode_wsfactor}
			: $constants->{comments_wsfactor} || 1) )
	) {
		$slashdb->resetFormkey($form->{formkey});
		if (! $form->{newdiscussion}) {
			editComment(@_, $error_message);
		} else {
			if ($form->{indextype} eq 'udiscuss') {
				commentIndexUserCreated(@_, $error_message);
			} elsif ($form->{indextype} eq 'personal') {
				commentIndexPersonal(@_, $error_message);
			} elsif ($form->{indextype} eq 'creator') {
				commentIndexCreator(@_, $error_message);
			} else {
				commentIndex(@_,$error_message);
			}
		}
		return(0);
	}

	$tempComment = addDomainTags($tempComment);

	if ($form->{newdiscussion}) {
		$id = _createDiscussion($form, $slashdb, $user, $constants);
		return 1 unless $id;
	}

#	# Slash is not a file exchange system
#	# still working on this...stay tuned for real commit
#	# (maybe in 2.x... sigh)
# 	# maybe during the next glacial cycle.
#	$tempComment = distressBinaries($tempComment);

	unless ($form->{newdiscussion}) {
		titlebar("100%", getData('submitted_comment'));
	}

	my $pts = 0;
	my $karma_bonus = 0;
	my $subscriber_bonus = 0;
	my $tweak = 0;
	if (!$user->{is_anon} && !$form->{postanon}) {
		$pts = $user->{defaultpoints};
		$tweak-- if $user->{karma} < 0;
		$tweak-- if $user->{karma} < $constants->{badkarma};
		# Enforce proper ranges on comment points.
		my($minScore, $maxScore) =
			($constants->{comment_minscore}, $constants->{comment_maxscore});
		$pts = $minScore if $pts < $minScore;
		$pts = $maxScore if $pts > $maxScore;
		$karma_bonus = 1 if $pts >= 1 && $user->{karma} > $constants->{goodkarma}
			&& !$form->{nobonus};
		$subscriber_bonus = 1 if $constants->{plugin}{Subscribe}
			&& $user->{is_subscriber}
			&& $form->{nosubscriberbonus} ne 'on';
	}
	# This is here to prevent posting to discussions that don't exist/are nd -Brian
	unless ($user->{is_admin} || $form->{newdiscussion}) {
		unless ($slashdb->checkDiscussionPostable($id)) {
			print getError('submission error');
			return(0);
		}
	}
	my $posters_uid = $user->{uid};
	if ($form->{postanon} && $constants->{allow_anonymous} && $user->{karma} > -1 && $discussion->{commentstatus} eq 'enabled') {
		$posters_uid = $constants->{anonymous_coward_uid} ;
	}

	my $clean_comment = {
		subject		=> $tempSubject,
		comment		=> $tempComment,
		sid		=> $id , 
		pid		=> $form->{pid} ,
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
		slashDisplay('comment_submit', {
			metamod_elig => scalar $slashdb->metamodEligible($user),
		}) if ! $form->{newdiscussion};
		undoModeration($id);
		printComments($discussion, $maxCid, $maxCid,
			{ force_read_from_master => 1, just_submitted => 1 }
		) if !$form->{newdiscussion};

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
		if ($form->{pid} || $discussion->{url} =~ /\bjournal\b/ || $constants->{commentnew_msg}) {
			$messages = getObject('Slash::Messages');
			$reply = $slashdb->getCommentReply($form->{sid}, $maxCid);
		}

		$clean_comment->{pointsorig} = $clean_comment->{points};

		# reply to comment
		if ($messages && $form->{pid}) {
			my $parent = $slashdb->getCommentReply($id, $form->{pid});
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
		if ($messages && $discussion->{url} =~ /\bjournal\b/) {
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
			for my $usera (@$users) {
				next if $users{$usera};
				$messages->create($usera, MSG_CODE_NEW_COMMENT, $data);
				$users{$usera}++;
			}
		}
		if ($form->{newdiscussion}) {
			if ($user->{seclev} >= $constants->{discussion_create_seclev}) {
				slashDisplay('newdiscussion', { 
					error 		=> $error_message, 
					'label'		=> $label,
					id 		=> $id,
				});
			} else {
				slashDisplay('newdiscussion', {
					error => getError('seclevtoolow'),
				});
			}
			undef $form->{postersubj};
			undef $form->{postercomment};
			if ($form->{indextype} eq 'udiscuss') {
				commentIndexUserCreated(@_, $error_message);
			} elsif ($form->{indextype} eq 'personal') {
				commentIndexPersonal(@_, $error_message);
			} elsif ($form->{indextype} eq 'creator') {
				commentIndexCreator(@_, $error_message);
			} else {
				commentIndex(@_,$error_message);
			}
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

	my $newpts = Slash::_get_points($C, $otheruser,
		$constants->{comment_minscore}, $constants->{comment_maxscore},
		$reader->countUsers({ max => 1 }), $reader->getReasons,
	);

	# only if reply pts meets message threshold
	return if defined $message_threshold && $newpts < $message_threshold;

	return 1;
}


##################################################################
# Handles moderation
# gotta be a way to simplify this -Brian
sub moderate {
	my($form, $slashdb, $user, $constants, $discussion) = @_;

	my $sid = $form->{sid};
	my $was_touched = 0;

	my $meta_mods_performed = 0;
	if ($user->{is_admin}) {
		$meta_mods_performed = metaModerate();		
	}

	if ($form->{meta_mod_only}) {
		titlebar("100%", "MetaModerating...");
		print getData("metamoderate_message");
		print getData("metamods_performed", { num => $meta_mods_performed }) if $meta_mods_performed;
		return;
	}

	if (!dbAvailable("write_comments")) {
		print getError("comment_db_down");
		return;
	}

	if ($discussion->{type} eq 'archived'
		&& !$constants->{comments_moddable_archived}) {
		print getData("metamods_performed", { num => $meta_mods_performed }) if $meta_mods_performed;
		print getData('archive_error');
		return;
	}

	if (! $constants->{allow_moderation}) {
		print getData("metamods_performed", { num => $meta_mods_performed }) if $meta_mods_performed;
		print getData('no_moderation');
		return;
	}

	my $total_deleted = 0;
	my $hasPosted;

	# The content here should also probably go into a template.
	titlebar("100%", "Moderating...");

	$hasPosted = $slashdb->countCommentsBySidUID($sid, $user->{uid})
		unless ($constants->{authors_unlimited}
				&& $user->{seclev} >= $constants->{authors_unlimited})
			|| $user->{acl}{modpoints_always};

	slashDisplay('mod_header');
	print getData("metamods_performed", { num => $meta_mods_performed }) if $meta_mods_performed;

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
			my $ret_val = $slashdb->moderateComment($sid, $cid, $form->{$key});
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

	slashDisplay('mod_footer', {
		metamod_elig => scalar $slashdb->metamodEligible($user),
	});

	if ($hasPosted && !$total_deleted) {
		print getError('already posted');

	} elsif ($user->{seclev} && $total_deleted) {
		slashDisplay('del_message', {
			total_deleted	=> $total_deleted,
			comment_count	=> $slashdb->countCommentsBySid($sid),
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

sub metaModerate {
	my($id) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	
	# for now at least no one should be hitting this unless they're an admin
	return 0 unless $user->{is_admin};

	# The user is only allowed to metamod the mods they were given.
	my @mods_saved = $slashdb->getModsSaved();
	my %mods_saved = map { ( $_, 1 ) } @mods_saved;

	# %m2s is the data structure we'll be building.
	my %m2s = ( );

	for my $key (keys %{$form}) {
		# Metamod form data can only be a '+' or a '-'.
		next unless $form->{$key} =~ /^[+-]$/;
		# We're only looking for the metamod inputs.
		next unless $key =~ /^mm(\d+)$/;
		my $mmid = $1;
		# Only the user's given mods can be used, unless they're an admin.
		next unless $mods_saved{$mmid} || $user->{is_admin};
		# This one's valid.  Store its data in %m2s.
		$m2s{$mmid}{is_fair} = ($form->{$key} eq '+') ? 1 : 0;
	}

	# The createMetaMod() method does all the heavy lifting here.
	# Re m2_multicount:  if this var is set, then our vote for
	# reason r on cid c applies potentially to *all* mods of
	# reason r on cid c.
	$slashdb->createMetaMod($user, \%m2s, $constants->{m2_multicount});
	return scalar keys %m2s;
}

##################################################################
# Given an SID & A CID this will delete a comment, and all its replies
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
# If you moderate, and then post, all your moderation is undone.
sub undoModeration {
	my($sid) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	# We abandon this operation, thus allowing mods to remain while
	# the post goes forward, if:
	#	1) Moderation is off
	#	2) The user is anonymous (posting anon is the only way
	#	   to contribute to a discussion after you moderate)
	#	3) The user has the "always modpoints" ACL
	#	4) The user has a sufficient seclev
	return if !$constants->{allow_moderation}
		|| $user->{is_anon}
		|| $user->{acl}{modpoints_always}
		|| $constants->{authors_unlimited} && $user->{seclev} >= $constants->{authors_unlimited};

	if ($sid !~ /^\d+$/) {
		$sid = $slashdb->getDiscussionBySid($sid, 'header');
	}
	my $removed = $slashdb->undoModeration($user->{uid}, $sid);

	for my $mod (@$removed) {
		$mod->{val} =~ s/^(\d)/+$1/;  # put "+" in front if necessary
		my $messages = getObject('Slash::Messages');
		$messages->send_mod_msg({
			type	=> 'unmod_msg',
			sid	=> $sid,
			cid	=> $mod->{cid},
			val	=> $mod->{val},
			reason	=> $mod->{reason}
		});
	}	

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

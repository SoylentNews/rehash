#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants qw(:messages);
use Slash::Display;
use Slash::Utility;
use Slash::XML;
use URI;

#################################################################
sub main {
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $formkey = $form->{formkey};
	my $formname = 'submissions';

	$form->{del}	||= 0;
	$form->{op}	||= '';
	my $error_flag = 0;
	my $success = 0;

	if (($form->{content_type} eq 'rss') and ($form->{op} eq 'list') and $constants->{submiss_view}) {
		my $success = displayRSS($slashdb, $constants, $user, $form);
		return if $success;
	}

	# this really should not be done now, but later, it causes
	# a lot of problems, but it causes a LOT of problems
	# when moved elsewhere and we get double-encoding!
	# so leave it here until you really know what you
	# are doing -- pudge
	$form->{from}   = strip_attribute($form->{from})  if $form->{from};
	$form->{subj}   = strip_attribute($form->{subj})  if $form->{subj};
	$form->{email}  = strip_attribute($form->{email}) if $form->{email};
	$form->{name}   = strip_nohtml($form->{name})     if $form->{name};

	# Show submission title on browser's titlebar.
	my($tbtitle) = $form->{title};
	$tbtitle =~ s/^"?(.+?)"?$/$1/ if $tbtitle;

	my $ops = {
		# initial form, no formkey needed due to 'preview' requirement
		blankform		=> {
			seclev		=> 0,
			checks		=> ['max_post_check', 'generate_formkey'],
			function 	=> \&blankForm,
		},
		previewstory	=> {
			seclev		=>  0,
			checks		=> ['update_formkeyid'],
			function 	=> \&previewStory,
		},
		pending	=> {
			seclev		=>  1,
			function 	=> \&yourPendingSubmissions,
		},
		submitstory	=> {
			function	=> \&saveSub,
			seclev		=> 0,
			post		=> 1,
			checks		=> [ qw (max_post_check valid_check response_check
						interval_check formkey_check) ],
		},
		list		=> {
			seclev		=> $constants->{submiss_view} ? 0 : 100,
			function	=> \&submissionEd,
		},
		viewsub		=> {
			seclev		=> $constants->{submiss_view} ? 0 : 100,
			function	=> \&previewForm,
		},
		update		=> {
			seclev		=> 100,
			function	=> \&updateSubmissions,
		},
		delete		=> {
			seclev		=> 100,
			function	=> \&deleteSubmissions,
		},
		merge		=> {
			seclev		=> 100,
			function	=> \&mergeSubmissions,
		},
	};

	$ops->{default} = $ops->{blankform};

	my $op = lc($form->{op});
	$op ||= 'default';
	$op = 'default' if (
		($user->{seclev} < $ops->{$op}{seclev})
			||
		! $ops->{$op}{function}
	);

	# the submissions tab should always be highlighted,
	# being submit.pl and all
	my $data = {
		admin => 1,
		tab_selected => 'submissions',
	};
	header(
		getData('header', { tbtitle => $tbtitle } ),
		'', $data
	) or return;

	if ($user->{seclev} < 100) {
		if ($ops->{$op}{checks}) {
			for my $check (@{$ops->{$op}{checks}}) {
				$ops->{$op}{update_formkey} = 1
					if ($check eq 'formkey_check');
				$error_flag = formkeyHandler(
					$check, $formname, $formkey
				);
				last if $error_flag;
			}
		}
	}

	# call the method
	$success = $ops->{$op}{function}->($constants, $slashdb, $user, $form) if ! $error_flag;

	if ($ops->{$op}{update_formkey} && $success && ! $error_flag) {
		my $updated = $slashdb->updateFormkey($formkey, $form->{tid}, length($form->{story}));
	}

	footer();
}

#################################################################
# update the notes and skin fields but don't delete anything.
sub updateSubmissions {
	my($constants, $slashdb, $user, $form) = @_;
	$slashdb->deleteSubmission({ nodelete => 1 });
	submissionEd(@_);
}

#################################################################
sub deleteSubmissions {
	my($constants, $slashdb, $user, $form) = @_;
	my @subids = $slashdb->deleteSubmission;
	submissionEd(@_, getData('updatehead', { subids => \@subids }));
}

#################################################################
sub blankForm {
	my($constants, $slashdb, $user, $form) = @_;
	yourPendingSubmissions(@_);
	displayForm($user->{nickname}, $user->{fakeemail}, $form->{skin}, getData('defaulthead'));
}

#################################################################
sub previewStory {
	my($constants, $slashdb, $user, $form) = @_;
	displayForm($form->{name}, $form->{email}, $form->{skin}, getData('previewhead'));
}

#################################################################
sub yourPendingSubmissions {
	my($constants, $slashdb, $user, $form) = @_;

	return if $user->{is_anon};

	if (my $submissions = $slashdb->getSubmissionsByUID($user->{uid}, "", { limit_days => 365 })) {
		slashDisplay('yourPendingSubs', {
			submissions	=> $submissions,
			width		=> '100%',
		});
	}
}

#################################################################
sub previewForm {
	my($constants, $slashdb, $user, $form) = @_;

	my $admin_flag = $user->{seclev} >= 100 ? 1 : 0;

	my $sub = $slashdb->getSubmission($form->{subid});
	
	my @topics;
	
	my $topic = $slashdb->getTopic($sub->{tid});
	push @topics, $sub->{tid} if $sub->{tid};

	my $nexus_id = $slashdb->getNexusFromSkid($sub->{primaryskid} || $constants->{mainpage_skid});
	push @topics, $nexus_id if $nexus_id;

	my $chosen_hr = genChosenHashrefForTopics(\@topics);
	
	my $extracolumns = $slashdb->getNexusExtrasForChosen($chosen_hr) || [ ];
	vislenify($sub); # add $sub->{ipid_vis}

	my $email_known = "";
	$email_known = "mailto" if $sub->{email} eq $user->{fakeemail};
	$sub->{email} = processSub($sub->{email}, $email_known);

	$slashdb->setSession(getCurrentUser('uid'), {
		lasttitle	=> $sub->{subj},
		last_subid	=> $form->{subid},
		last_sid	=> '',
	}) if $user->{is_admin};

	my $num_sim = $constants->{similarstorynumshow} || 5;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $storyref = {
		title =>	$sub->{subj},
		introtext =>	$sub->{story},
	};
	my $similar_stories = $reader->getSimilarStories($storyref, $num_sim);

	# Truncate that data to a reasonable size for display.

	if ($similar_stories && @$similar_stories) {
		for my $sim (@$similar_stories) {
			# Display a max of five words reported per story.
			$#{$sim->{words}} = 4 if $#{$sim->{words}} > 4;
			for my $word (@{$sim->{words}}) {
				# Max of 12 chars per word.
				$word = substr($word, 0, 12);
			}
			if (length($sim->{title}) > 35) {
				# Max of 35 char title.
				$sim->{title} = substr($sim->{title}, 0, 30);
				$sim->{title} =~ s/\s+\S+$//;
				$sim->{title} .= "...";
			}
		}
	}

	slashDisplay('previewForm', {
		submission	=> $sub,
		submitter	=> $sub->{uid},
		subid		=> $form->{subid},
		topic		=> $topic,
		ipid		=> $sub->{ipid},
		ipid_vis	=> $sub->{ipid_vis},
		admin_flag 	=> $admin_flag,
		extras 		=> $extracolumns,
		lockTest	=> lockTest($sub->{subj}),
		similar_stories	=> $similar_stories,
	});
}

#################################################################
sub mergeSubmissions {
	my($constants, $slashdb, $user, $form) = @_;

	my $submissions = $slashdb->getSubmissionsMerge;
	if (@$submissions) {
		my $stuff = slashDisplay('mergeSub',
			{ submissions => $submissions },
			{ Return => 1, Nocomm => 1 }
		);
		$slashdb->setSubmissionsMerge($stuff);
	}

	# need to do this even if nothing is checked, so we update notes etc.
	my @subids = $slashdb->deleteSubmission({ accepted => 1 });

	submissionEd(@_, getData('mergehead', { subids => \@subids }));
}

#################################################################
sub submissionEd {
	my($constants, $slashdb, $user, $form, $title) = @_;
	my($def_skin, $cur_skin, $def_note, $cur_note,
		$skins, @skins, @notes,
		%all_skins, %all_notes, %sn);

	$form->{del} = 0 if $user->{is_admin};

	$def_skin = getData('defaultskin');
	$def_note = getData('defaultnote');
	$cur_skin = $form->{skin} || $def_skin;
	$cur_note = $form->{note} || $def_note;
	$skins    = $slashdb->getSubmissionsSkins();

	for (@$skins) {
		my($skin, $note, $cnt) = @$_;
		$all_skins{$skin} = 1;
		$note ||= $def_note;
		$all_notes{$note} = 1;
		$sn{$skin}{$note} = $cnt;
	}

	for my $note_str (keys %all_notes) {
		$sn{$def_skin}{$note_str} = 0;
		for (grep { $_ ne $def_skin } keys %sn) {
			$sn{$def_skin}{$note_str} += $sn{$_}{$note_str};
		}
	}

	$all_skins{$def_skin} = 1;

	# self documentation, right?
	@skins =	map  { [$_->[0], ($_->[0] eq $def_skin ? '' : $_->[0])] }
			sort { $a->[1] cmp $b->[1] }
			map  { [$_, ($_ eq $def_skin ? '' : $_)] }
			keys %all_skins;

	@notes =	map  { [$_->[0], ($_->[0] eq $def_note ? '' : $_->[0])] }
			sort { $a->[1] cmp $b->[1] }
			map  { [$_, ($_ eq $def_note ? '' : $_)] }
			keys %all_notes;

	slashDisplay('subEdTable', {
		cur_skin	=> $cur_skin,
		cur_note	=> $cur_note,
		def_skin	=> $def_skin,
		def_note	=> $def_note,
		skins		=> \@skins,
		notes		=> \@notes,
		sn		=> \%sn,
		title		=> $title || ('Submissions ' . ($user->{is_admin} ? 'Admin' : 'List')),
		width		=> '100%',
	});

	my($submissions, %selection);
	$submissions = $slashdb->getSubmissionForUser;

	for my $sub (@$submissions) {
		$sub->{name}  =~ s/<(.*)>//g;
		$sub->{email} =~ s/<(.*)>//g;
		$sub->{is_anon} = isAnon($sub->{uid});

		my @strs = (
			substr($sub->{subj}, 0, 35),
			substr($sub->{name}, 0, 20),
			substr($sub->{email}, 0, 20)
		);
		$strs[0] .= '...' if length($sub->{subj}) > 35;
		$sub->{strs} = \@strs;

		my $skin = $slashdb->getSkin($sub->{primaryskid});

		$sub->{sskin}  =
			$sub->{primaryskid} ne $constants->{mainpage_skid} ?
				"&skin=$skin->{name}" : '';
		$sub->{stitle} = '&title=' . fixparam($sub->{subj});
		$sub->{skin}   = $skin->{name};
	}

	%selection = map { ($_, $_) }
		(qw(Hold Quik), '',	# '' is special
		(ref $constants->{submit_categories}
			? @{$constants->{submit_categories}} : ())
	);

	# Do we provide a submission list based on a custom sort?
	my @weighted;
	if ($constants->{submit_extra_sort_key}) {
		my $key = $constants->{submit_extra_sort_key};

		# Note, descending order. Is there a way to make this more
		# flexible? A var that chooses between ascending or descending
		# order?
		@weighted = sort { $b->{$key} <=> $a->{$key} } @{$submissions};
	}

	my $template = $user->{is_admin} ? 'Admin' : 'User';
	slashDisplay('subEd' . $template, {
		submissions	=> $submissions,
		selection	=> \%selection,
		weighted	=> \@weighted,
	});
}

#################################################################
sub displayRSS {
	my($slashdb, $constants, $user, $form) = @_;
	my $gSkin = getCurrentSkin();
	my($submissions, @items);
	$submissions = $slashdb->getSubmissionForUser();

	for (@$submissions) {
		# title should be cleaned up
		push(@items, {
			title	=> $_->{subj},
			'link'	=> "$gSkin->{absolutedir}/submit.pl?op=viewsub&subid=$_->{subid}",
		});
	}

	xmlDisplay('rss', {
		channel	=> {
			title	=> "$constants->{sitename} Submissions",
			'link'	=> "$gSkin->{absolutedir}/submit.pl?op=list",
		},
		image	=> 1,
		items	=> \@items,
	});
}


#################################################################
sub displayForm {
	my($username, $fakeemail, $skin, $title, $error_message) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $user = getCurrentUser();

	if (length($form->{story}) > $constants->{max_submission_size}) {
		titlebar('100%', getData('max_submissionsize_title'));
		print getData('max_submissionsize_err', { size => $constants->{max_submission_size}});
	}

	my %keys_to_check = ( story => 1, subj => 1 );
	if ($error_message ne '') {
		titlebar('100%', getData('filtererror', { err_message => $error_message}));
		print getData('filtererror', { err_message => $error_message });
	} else {
		my $message = "";
		for (keys %$form) {
			next unless $keys_to_check{$_};
			# run through filters
			if (! filterOk('submissions', $_, $form->{$_}, \$message)) {
				my $err = getData('filtererror', { err_message => $message});
				titlebar('100%', $err);
				print $err;
				last;
			}
			# run through compress test
			if (! compressOk('submissions', $_, $form->{$_})) {
				# blammo luser
				my $err = getData('compresserror');
				titlebar('100%', $err);
				print $err;
				last;
			}
		}
	}

	my $skins = $slashdb->getSkins();
	my $topic_values = $slashdb->getDescriptions('topics-submittable');
	my $skin_values = $slashdb->getDescriptions('skins-submittable');

	$form->{tid} ||= 0;
	unless ($form->{tid}) {
		my $current_hash = { %$topic_values };
		$current_hash->{0} = "Select Topic";
		$topic_values = $current_hash;
	}

	$form->{primaryskid} ||= $constants->{submission_default_skid} || 0;
	unless ($form->{primaryskid}) {
		my $current_hash = { %$skin_values };
		$current_hash->{0} = "Select Section";
		$skin_values = $current_hash;
	}

	my $topic = $slashdb->getTopic($form->{tid});

	my $known = "";
	if ($form->{email}) {
		$fakeemail = $form->{email};
	} elsif ($fakeemail eq $user->{fakeemail}) {
		$known = "mailto";
		# we assume this is like if form.email is passed in
		$fakeemail = strip_attribute($user->{fakeemail});
	}
	my @topics = ();
	my $nexus_id = $slashdb->getNexusFromSkid($form->{primaryskid} || $constants->{submission_default_skid} || $constants->{mainpage_skid});
	push @topics, $nexus_id if $nexus_id;
	push @topics, $form->{tid} if $form->{tid};

	my $chosen_hr = genChosenHashrefForTopics(\@topics);
	
	my $extracolumns = $slashdb->getNexusExtrasForChosen($chosen_hr) || [ ];

	my $fixedstory;
	if ($form->{sub_type} && $form->{sub_type} eq 'plain') {
		$fixedstory = strip_plaintext(url2html($form->{story}));
	} else {
		$fixedstory = strip_html(url2html($form->{story}));

		# some submitters like to add whitespace before and
		# after their introtext. This is never wanted. --Pater
		$fixedstory =~ s/^<(?:P|BR)(?:>|\s[^>]*>)//i;
		$fixedstory =~ s/<(?:P|BR)(?:>|\s[^>]*>)$//i;
	}
	$fixedstory = balanceTags($fixedstory);

	slashDisplay('displayForm', {
		fixedstory	=> $fixedstory,
		savestory	=> $form->{story} && $form->{subj} && $form->{tid},
		username	=> $form->{name} || $username,
		fakeemail	=> processSub($fakeemail, $known),
		uid		=> $user->{uid},
		extras 		=> $extracolumns,
		topic		=> $topic,
		width		=> '100%',
		title		=> $title,
		topic_values	=> $topic_values,
		skin_values	=> $skin_values,
		skins		=> $skins,
	});
}
#################################################################
sub saveSub {
	my($constants, $slashdb, $user, $form) = @_;

	$form->{name} ||= '';

	if (length($form->{subj}) < 2) {
		titlebar('100%', getData('error'));
		my $error_message = getData('badsubject');
		displayForm($form->{name}, $form->{email}, $form->{skin}, '', '', $error_message);
		return(0);
	}

	my %keys_to_check = ( story => 1, subj => 1 );
	my $message = "";
	for (keys %$form) {
		next unless $keys_to_check{$_};
		# run through filters
		if (! filterOk('submissions', $_, $form->{$_}, \$message)) {
			displayForm($form->{name}, $form->{email}, $form->{skin}, '', '', $message);
			return(0);
		}
		# run through compress test
		if (! compressOk($form->{$_})) {
			my $err = getData('compresserror');
			displayForm($form->{name}, $form->{email}, $form->{skin}, '', '');
			return(0);
		}
	}

	if ($form->{sub_type} && $form->{sub_type} eq 'plain') {
		$form->{story} = strip_plaintext(url2html($form->{story}));
	} else {
		$form->{story} = strip_html(url2html($form->{story}));
	}
	$form->{story} = balanceTags($form->{story});

	my $uid ||= $form->{name}
		? getCurrentUser('uid')
		: getCurrentStatic('anonymous_coward_uid');

	my $submission = {
		email		=> $form->{email},
		uid		=> $uid,
		name		=> $form->{name},
		story		=> $form->{story},
		subj		=> $form->{subj},
		tid		=> $form->{tid},
		primaryskid	=> $form->{primaryskid}
	};
	my @topics = ();
	my $nexus = $slashdb->getNexusFromSkid($form->{primaryskid} || $constants->{mainpage_skid});

	push @topics, $nexus;
	push @topics, $form->{tid} if $form->{tid};
	
	my $chosen_hr = genChosenHashrefForTopics(\@topics);

	my $extras = $slashdb->getNexusExtrasForChosen($chosen_hr) || [];

	
	if ($extras && @$extras) {
		for (@$extras) {
			my $key = $_->[1];
			$submission->{$key} = strip_nohtml($form->{$key}) if $form->{$key};
		}
	}
	my $messagesub = { %$submission };
	$messagesub->{subid} = $slashdb->createSubmission($submission);
	# $slashdb->formSuccess($form->{formkey}, 0, length($form->{subj}));

	my $messages = getObject('Slash::Messages');
	if ($messages) {
		my $users = $messages->getMessageUsers(MSG_CODE_NEW_SUBMISSION);
		my $data  = {
			template_name	=> 'messagenew',
			subject		=> { template_name => 'messagenew_subj' },
			submission	=> $messagesub,
		};
		for (@$users) {
# XXXSKIN - no "section" restriction
#			my $user_section = $slashdb->getUser($_, 'section');
#			next if ($user_section && $user_section ne $messagesub->{section});
			$messages->create($_, MSG_CODE_NEW_SUBMISSION, $data);
		}
	}

	slashDisplay('saveSub', {
		title		=> 'Saving',
		width		=> '100%',
		missingemail	=> length($form->{email}) < 3,
		anonsubmit	=> isAnon($uid) && length($form->{name}) < 3 && length($form->{email}) < 3,
	});
	yourPendingSubmissions(@_);

	return(1);
}

#################################################################
sub processSub {
	my($home, $known_to_be) = @_;

	my $proto = qr[^(?:mailto|http|https|ftp|gopher|telnet):];

	if 	($home =~ /\@/	&& ($known_to_be eq 'mailto' || $home !~ $proto)) {
		$home = "mailto:$home";
	} elsif	($home ne ''	&& ($known_to_be eq 'http'   || $home !~ $proto)) {
		$home = "http://$home";
	}

	return $home;
}

#################################################################
sub url2html {
	my($introtext) = @_;
	$introtext =~ s/\n\n/\n<P>/gi;
	$introtext .= " ";

	# this is kinda experimental ... esp. the $extra line
	# we know it can break real URLs, but probably will preserve
	# real URLs more often than it will break them
	$introtext =~  s{(?<!['"=>])(http|https|ftp|gopher|telnet)://([$URI::uric#]+)}{
		my($proto, $url) = ($1, $2);
		my $extra = '';
		$extra = $1 if $url =~ s/([?!;:.,']+)$//;
		$extra = ')' . $extra if $url !~ /\(/ && $url =~ s/\)$//;
		qq[<A HREF="$proto://$url">$proto://$url</A>$extra];
	}ogie;
	$introtext =~ s/\s+$//;
	return $introtext;
}

#################################################################

sub genChosenHashrefForTopics {
	my ($topics) = @_;
	my $constants = getCurrentStatic();
	my $chosen_hr ={};
	for my $tid (@$topics) {
		$chosen_hr->{$tid} = 
		$tid == $constants->{mainpage_tid}
		? 30
		: $constants->{topic_popup_defaultweight} || 10;
	}
	return $chosen_hr;
}

createEnvironment();
main();

1;

#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
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

	my $section = $form->{section};

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
# update the notes and sections fields but don't delete anything.
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
	displayForm($user->{nickname}, $user->{fakeemail}, $form->{section}, getData('defaulthead'));
}

#################################################################
sub previewStory {
	my($constants, $slashdb, $user, $form) = @_;
	displayForm($form->{name}, $form->{email}, $form->{section}, getData('previewhead'));
}

#################################################################
sub yourPendingSubmissions {
	my($constants, $slashdb, $user, $form) = @_;

	my $summary;
	return if $user->{is_anon};

	if (my $submissions = $slashdb->getSubmissionsPending()) {
		for my $submission (@$submissions) {
			$summary->{$submission->[4]}++;
		}
		slashDisplay('yourPendingSubs', {
			submissions	=> $submissions,
			width		=> '100%',
			summary		=> $summary,
		});
	}
}

#################################################################
sub previewForm {
	my($constants, $slashdb, $user, $form) = @_;

	my $admin_flag = $user->{seclev} >= 100 ? 1 : 0;

	my $sub = $slashdb->getSubmission($form->{subid});

	my $topic = $slashdb->getTopic($sub->{tid});
	$topic->{image} = "$constants->{imagedir}/topics/$topic->{image}"
                if $topic->{image} =~ /^\w+\.\w+$/;

	my $extracolumns = $slashdb->getSectionExtras($sub->{section}) || [ ];
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
		section		=> $form->{section} ||
				   $constants->{defaultsection},
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
	# mmmm, code comments in here sure would be nice
	my($constants, $slashdb, $user, $form, $title) = @_;
	my($def_section, $cur_section, $def_note, $cur_note,
		$sections, @sections, @notes,
		%all_sections, %all_notes, %sn);

	$form->{del} = 0 if $user->{is_admin};

	$def_section	= getData('defaultsection');
	$def_note	= getData('defaultnote');
	if ($user->{section} && !$form->{section}) {
		$cur_section = $user->{section};
	} else {
		$cur_section = $form->{section} || $def_section;
	}
	$cur_note	= $form->{note} || $def_note;
	$sections = $slashdb->getSubmissionsSections;

	for (@$sections) {
		my($section, $note, $cnt) = @$_;
		$all_sections{$section} = 1;
		$note ||= $def_note;
		$all_notes{$note} = 1;
		$sn{$section}{$note} = $cnt;
	}

	for my $note_str (keys %all_notes) {
		$sn{$def_section}{$note_str} = 0;
		for (grep { $_ ne $def_section } keys %sn) {
			$sn{$def_section}{$note_str} += $sn{$_}{$note_str};
		}
	}

	$all_sections{$def_section} = 1;

	# self documentation, right?
	@sections =	map  { [$_->[0], ($_->[0] eq $def_section ? '' : $_->[0])] }
			sort { $a->[1] cmp $b->[1] }
			map  { [$_, ($_ eq $def_section ? '' : $_)] }
			keys %all_sections;

	@notes =	map  { [$_->[0], ($_->[0] eq $def_note ? '' : $_->[0])] }
			sort { $a->[1] cmp $b->[1] }
			map  { [$_, ($_ eq $def_note ? '' : $_)] }
			keys %all_notes;

	slashDisplay('subEdTable', {
		cur_section	=> $cur_section,
		cur_note	=> $cur_note,
		def_section	=> $def_section,
		def_note	=> $def_note,
		sections	=> \@sections,
		notes		=> \@notes,
		sn		=> \%sn,
		title		=> $title || ('Submissions ' . ($user->{is_admin} ? 'Admin' : 'List')),
		width		=> '100%',
	});

	my($submissions, %selection);
	$submissions = $slashdb->getSubmissionForUser();

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

		$sub->{ssection} =
			$sub->{section} ne $constants->{defaultsection} ?
				"&section=$sub->{section}" : '';
		$sub->{stitle}  = '&title=' . fixparam($sub->{subj});
		$sub->{section} = ucfirst($sub->{section})
			unless $user->{is_admin};
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
	my($submissions, @items);
	$submissions = $slashdb->getSubmissionForUser();

	for (@$submissions) {
		# title should be cleaned up
		push(@items, {
			title	=> $_->{subj},
			'link'	=> "$constants->{absolutedir}/submit.pl?op=viewsub&subid=$_->{subid}",
		});
	}

	xmlDisplay('rss', {
		channel	=> {
			title	=> "$constants->{sitename} Submissions",
			'link'	=> "$constants->{absolutedir}/submit.pl?op=list",
		},
		image	=> 1,
		items	=> \@items,
	});
}


#################################################################
sub displayForm {
	my($username, $fakeemail, $section, $title, $error_message) = @_;
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


	my $topic_values = $slashdb->getDescriptions('topics_section', $section);
	$form->{tid} ||= 0;
	unless ($form->{tid}) {
		my $current_hash = { %$topic_values };
		$current_hash->{0} = "Select Topic";
		$topic_values = $current_hash;
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
	my $extracolumns = $slashdb->getSectionExtras($form->{section}
		|| $section || $constants->{defaultsection}) || [ ];

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
		section		=> $form->{section} || $section || $constants->{defaultsection},
		uid		=> $user->{uid},
		extras 		=> $extracolumns,
		topic		=> $topic,
		width		=> '100%',
		title		=> $title,
		topic_values	=> $topic_values,
	});
}

#################################################################
sub saveSub {
	my($constants, $slashdb, $user, $form) = @_;

	$form->{name} ||= '';

	if (length($form->{subj}) < 2) {
		titlebar('100%', getData('error'));
		my $error_message = getData('badsubject');
		displayForm($form->{name}, $form->{email}, $form->{section}, '', '', $error_message);
		return(0);
	}

	my %keys_to_check = ( story => 1, subj => 1 );
	my $message = "";
	for (keys %$form) {
		next unless $keys_to_check{$_};
		# run through filters
		if (! filterOk('submissions', $_, $form->{$_}, \$message)) {
			displayForm($form->{name}, $form->{email}, $form->{section}, '', '', $message);
			return(0);
		}
		# run through compress test
		if (! compressOk($form->{$_})) {
			my $err = getData('compresserror');
			displayForm($form->{name}, $form->{email}, $form->{section}, '', '');
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
		email	=> $form->{email},
		uid	=> $uid,
		name	=> $form->{name},
		story	=> $form->{story},
		subj	=> $form->{subj},
		tid	=> $form->{tid},
		section	=> $form->{section}
	};
	my $extras = $slashdb->getSectionExtras($submission->{section});
	if ($extras && @$extras) {
		for (@$extras) {
			my $key = $_->[1];
			$submission->{$key} = strip_nohtml($form->{$key}) if $form->{$key};
		}
	}
	$submission->{subid} = $slashdb->createSubmission($submission);
	# $slashdb->formSuccess($form->{formkey}, 0, length($form->{subj}));

	my $messages = getObject('Slash::Messages');
	if ($messages) {
		my $users = $messages->getMessageUsers(MSG_CODE_NEW_SUBMISSION);
		my $data  = {
			template_name	=> 'messagenew',
			subject		=> { template_name => 'messagenew_subj' },
			submission	=> $submission,
		};
		for (@$users) {
			my $user_section = $slashdb->getUser($_,'section');
			next if ($user_section && $user_section ne $submission->{section});
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
createEnvironment();
main();

1;

	#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use utf8;
use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants qw(:messages :web);
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
	
	slashProfInit();
	
	my @redirect_ops;

	push @redirect_ops, "title=" . strip_paramattr($form->{subj}) if $form->{subj};
	push @redirect_ops, "url=" . strip_paramattr($form->{url}) if $form->{url};
	if ($form->{subj} || $form->{url}) {
		push @redirect_ops, "new=1";
	}


	if ($constants->{submit_redirect_submit2}) {
		my $redirect_loc = "/submission";
		if (@redirect_ops) {
			$redirect_loc .= "?" . join('&', @redirect_ops);
		}
		redirect($redirect_loc);
	}

	my $submiss_view = $constants->{submiss_view} || $user->{is_admin};

	my %ops = (
		blankform		=> [1,			\&blankForm],
		previewstory		=> [1,			\&previewStory],
		pending			=> [!$user->{is_anon},	\&yourPendingSubmissions],
		submitstory		=> [1,			\&saveSub],
		list			=> [$submiss_view,	\&submissionEd],
		viewsub			=> [$submiss_view,	\&previewForm],
		update			=> [$user->{is_admin},	\&updateSubmissions],
		'delete'		=> [$user->{is_admin},	\&deleteSubmissions],
		merge			=> [$user->{is_admin},	\&mergeSubmissions],
		changesubmission	=> [$user->{is_admin},	\&changeSubmission],
	);

	$ops{default} = $ops{blankform};

	my $op = lc($form->{op} || 'default');
	$op = 'default' if !$ops{$op} || !$ops{$op}[ALLOWED];

	$form->{del} ||= 0;

	if ($form->{content_type} && $form->{content_type} =~ $constants->{feed_types}
		&& $op eq 'list' && $submiss_view) {
		return if displayRSS($slashdb, $constants, $user, $form);
	}

	# this really should not be done now, but later, it causes
	# a lot of problems, but it causes a LOT of problems
	# when moved elsewhere and we get double-encoding!
	# so leave it here until you really know what you
	# are doing -- pudge
	# I really know what I am doing. -- TMB
	$form->{from}   = strip_attribute($form->{from})  if $form->{from};
	#$form->{subj}   = strip_attribute($form->{subj})  if $form->{subj};
	$form->{email}  = strip_attribute($form->{email}) if $form->{email};
	$form->{name}   = strip_nohtml($form->{name})     if $form->{name};

	# Show submission title on browser's titlebar.
	my($tbtitle);
	if ($form->{subid} && $op ne "changesubmission") {
		$tbtitle = $slashdb->getSubmission($form->{subid}, [ 'subj' ]);
		$tbtitle = $tbtitle->{subj} if $tbtitle;
		$tbtitle =~ s/^"?(.+?)"?$/$1/ if $tbtitle;
	}

	# the submissions tab should always be highlighted,
	# being submit.pl and all
	header(
		getData('header', { tbtitle => $tbtitle } ), '', {
			tab_selected => 'submissions',
		}
	) or return;

	slashProf("submit-op");
	$ops{$op}[FUNCTION]->($constants, $slashdb, $user, $form);
	slashProf("","submit-op");

	footer();
	slashProfEnd();
}

#################################################################
# Update note, comment and skin with the option to delete based
# on extra form elements in the submission view.
sub changeSubmission {
	my($constants, $slashdb, $user, $form) = @_;
	my($gSkin, $subid) = (getCurrentSkin(), $form->{subid});
	my($option, $title);
		
	if (!$subid) {
		submissionEd(@_);
	} else {
		$option->{nodelete} = 1 unless $form->{"del_$form->{subid}"};

		# Must remove subid from $form when updating submission data
		# since Slash::DB::MySQL::deleteSubmission() will make extra
		# queries to the database if it exists.
		delete $form->{subid};
		my @subids = $slashdb->deleteSubmission($option);
		# Restore subid for proper functioning of the next page view.
		$form->{subid} = $subid;
		if (@subids) {
			$title = getData('updatehead', { subids => \@subids });
			submissionEd(@_, $title);
		} else {
			# Behavior here was unspecified. I chose this route, 
			# although returning to submissionEd() would simplify
			# things.		- Cliff
			submissionEd(@_, "");
		}
	}
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

	
	slashProf("pendingsubs");
	yourPendingSubmissions($constants, $slashdb, $user, $form, { skip_submit_body => 1 });
	slashProf("","pendingsubs");

	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('submit');
	if ($rkey->create) {
		slashProf("displayForm");
		displayForm($user->{nickname}, $user->{fakeemail}, $form->{skin}, getData('defaulthead'));
		slashProf("", "displayForm");
	} else {
		print $rkey->errstr;
	}		


}

#################################################################
sub previewStory {
	my($constants, $slashdb, $user, $form) = @_;

	my $error_message = '';

	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('submit');
	unless ($rkey->touch) {
		$error_message = $rkey->errstr;
		if ($rkey->death) {
			print $error_message;
			return 0;
		}
	}		
  #	print STDERR Data::Dumper->Dumper($form->{story});
	displayForm($form->{name}, $form->{email}, $form->{skin}, getData('previewhead'), '', $error_message);
}

#################################################################
sub yourPendingSubmissions {
	my($constants, $slashdb, $user, $form, $options) = @_;
	$options ||= {};
	return if $user->{is_anon};

	if (my $submissions = $slashdb->getSubmissionsByUID($user->{uid}, "", { limit_days => 90 })) {
		slashDisplay('yourPendingSubs', {
			submissions	=> $submissions,
			width		=> '100%',
		});
	}

}

#################################################################
sub getSubmissionSelections {
	my($constants) = @_;

	# Terminology mismatch..."selections" is legacy but the data is 
	# for submissions.note -- time for a nomenclature adjustment?
	# - Cliff
	my %selections = map { ($_, $_) }
		(qw(Hold Quik), '',	# '' is special
		(ref $constants->{submit_categories}
			? @{$constants->{submit_categories}} : ())
	);

	return \%selections;
}

#################################################################
sub previewForm {
	my($constants, $slashdb, $user, $form) = @_;

	my $admin_flag = $user->{seclev} >= 100 ? 1 : 0;

	my $sub = $slashdb->getSubmission($form->{subid});
	#$sub->{subj} = strip_literal($sub->{subj});
	
	$slashdb->updateSubMemory($form->{submatch}, $form->{subnote}) if $form->{submatch} && $user->{is_admin};
	my($sub_memory, $subnotes_ref);
	$sub_memory = $slashdb->getSubmissionMemory if $user->{is_admin};

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

	my $last_admin_text = $slashdb->getLastSessionText($user->{uid});
	my $lasttime = $slashdb->getTime();
	$slashdb->setUser($user->{uid}, { adminlaststorychange => $lasttime }) if $last_admin_text ne $sub->{subj};

	$slashdb->setSession(getCurrentUser('uid'), {
		lasttitle	=> $sub->{subj},
		last_subid	=> $form->{subid},
		last_sid	=> '',
	}) if $user->{is_admin};

	my $num_from_uid = 0;
	my $accepted_from_uid = 0;
	my $num_with_emaildomain = 0;
	my $accepted_from_emaildomain = 0;
	if ($user->{is_admin}) {
		$accepted_from_uid = $slashdb->countSubmissionsFromUID($sub->{uid}, { del => 2 });
		$num_from_uid = $slashdb->countSubmissionsFromUID($sub->{uid});
		$accepted_from_emaildomain = $slashdb->countSubmissionsWithEmaildomain($sub->{emaildomain}, { del => 2 });
		$num_with_emaildomain = $slashdb->countSubmissionsWithEmaildomain($sub->{emaildomain});
	}

	my $num_sim = $constants->{similarstorynumshow} || 5;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $storyref = {
		title =>	$sub->{subj},
		introtext =>	$sub->{story},
	};
	my $similar_stories = [];
	$similar_stories = $reader->getSimilarStories($storyref, $num_sim) if $user->{is_admin};

	# Truncate that data to a reasonable size for display.

	if ($similar_stories && @$similar_stories) {
		for my $sim (@$similar_stories) {
			# Display a max of five words reported per story.
			$#{$sim->{words}} = 4 if $#{$sim->{words}} > 4;
			for my $word (@{$sim->{words}}) {
				# Max of 12 chars per word.
				$word = substr($word, 0, 12);
			}
			$sim->{title} = chopEntity($sim->{title}, 35);
		}
	}

	my $url = "";
	$url = $slashdb->getUrl($sub->{url_id}) if $sub->{url_id};

	foreach my $memory (@$sub_memory) {
		my $match = $memory->{submatch};

		if ($sub->{email} =~ m/$match/i ||
			$sub->{name}  =~ m/$match/i ||
			$sub->{subj}  =~ m/$match/i ||
			$sub->{ipid}  =~ m/$match/i ||
			$sub->{story} =~ m/$match/i ||
			$url =~ m/$match/i ) {
				push @$subnotes_ref, $memory;
		}
	}

	slashDisplay('previewForm', {
		submission			=> $sub,
		submitter			=> $reader->getUser($sub->{uid}),
		subid				=> $form->{subid},
		topic				=> $topic,
		ipid				=> $sub->{ipid},
		ipid_vis			=> $sub->{ipid_vis},
		admin_flag 			=> $admin_flag,
		extras 				=> $extracolumns,
		lockTest			=> lockTest($sub->{subj}),
		similar_stories			=> $similar_stories,
		num_from_uid			=> $num_from_uid,
		num_with_emaildomain 		=> $num_with_emaildomain,
		accepted_from_uid 	  	=> $accepted_from_uid,
		accepted_from_emaildomain 	=> $accepted_from_emaildomain,
		note_options			=> getSubmissionSelections($constants),
		subnotes_ref			=> $subnotes_ref,
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
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	$form->{del} = 0 if $user->{is_admin};

	if (defined $form->{toggle_bin_refresh} && $user->{is_admin}) {
		$slashdb->setUser($user->{uid}, { opt_disable_submit_bin_refresh => $form->{toggle_bin_refresh} ? 1 : 0 });
	}

	$def_skin = getData('defaultskin');
	$def_note = getData('defaultnote');
	$cur_skin = $form->{skin} || $def_skin;
	$cur_note = $form->{note} || $def_note;
	$skins    = $reader->getSubmissionsSkins();

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
			$sn{$def_skin}{$note_str} += $sn{$_}{$note_str} || 0;
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

	my($submissions);
	$submissions = $slashdb->getSubmissionForUser;
	my $show_filters = scalar(@$submissions) > $constants->{subs_level} || $user->{is_admin} ? 1 : 0;

	slashDisplay('subEdTable', {
		cur_skin	=> $cur_skin,
		cur_note	=> $cur_note,
		show_filters	=> $show_filters,
		def_skin	=> $def_skin,
		def_note	=> $def_note,
		skins		=> \@skins,
		notes		=> \@notes,
		sn		=> \%sn,
		title		=> $title || ('Submissions ' . ($user->{is_admin} ? 'Admin' : 'List')),
		width		=> '100%',
	});

	
	my $pending;
	$pending = $slashdb->getStoriesSince();


	for my $sub (@$submissions) {
		$sub->{name}  =~ s/<(.*)>//g;
		$sub->{email} =~ s/<(.*)>//g;
		$sub->{is_anon} = isAnon($sub->{uid});

		my @strs = (
			$sub->{subj},
			chopEntity($sub->{name}, 20),
			chopEntity($sub->{email}, 20)
		);
		$sub->{strs} = \@strs;

		my $skin = $slashdb->getSkin($sub->{primaryskid});
		$sub->{sskin}  =
			$sub->{primaryskid} ne $constants->{mainpage_skid} ?
				"&skin=$skin->{name}" : '';
		$sub->{stitle} = '&title=' . fixparam($sub->{subj});
		
		$sub->{skin}   = $skin->{name};
	}

	for my $pen (@$pending) {
		my $skin = $slashdb->getSkin($pen->{primaryskid});
		$pen->{skin}   = $skin->{name};
		my $name = $slashdb->getUsersNicknamesByUID([$pen->{submitter}]);
		$pen->{name} = $name->{$pen->{submitter}}->{nickname};
	}

	# Do we provide a submission list based on a custom sort?
	my @weighted;
	if ($constants->{submit_extra_sort_key}) {
		my $key = $constants->{submit_extra_sort_key};

		# Note, descending order. Is there a way to make this more
		# flexible? A var that chooses between ascending or descending
		# order?
		@weighted = sort { $b->{$key} <=> $a->{$key} } @{$submissions};
	}

	my $showpending = 0;
	if(	($constants->{future_headlines} == 1 && $user->{is_subscriber}) ||
		($constants->{future_headlines} == 2 && $user->{is_anon} == 0) ||
		($constants->{future_headlines} == 3)
	){$showpending = 1;}

	my $template = $user->{is_admin} ? 'Admin' : 'User';
	slashDisplay('subEd' . $template, {
		submissions	=> $submissions,
		pending		=> $pending,
		showpending	=> $showpending,
		selection	=> getSubmissionSelections($constants),
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

	xmlDisplay($form->{content_type} => {
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

	if ($form->{story} && length($form->{story}) > $constants->{max_submission_size}) {
		titlebar('100%', getData('max_submissionsize_title'));
		print getData('max_submissionsize_err', { size => $constants->{max_submission_size}});
	}

	my %keys_to_check = ( story => 1, subj => 1 );
	if ($error_message && $error_message ne '') {
		titlebar('100%', "Error");
		print $error_message;
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
	my $topic_values = $slashdb->getDescriptions('non_nexus_topics-submittable');
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
	
	my @topics = ();
	my $nexus_id = $slashdb->getNexusFromSkid($form->{primaryskid} || $constants->{submission_default_skid} || $constants->{mainpage_skid});
	push @topics, $nexus_id if $nexus_id;
	push @topics, $form->{tid} if $form->{tid};

	my $chosen_hr = genChosenHashrefForTopics(\@topics);
	
	my $extracolumns = $slashdb->getNexusExtrasForChosen($chosen_hr) || [ ];
	my @required = map {$_->[1]} grep{$_->[4] eq "yes"} @$extracolumns;

	my @missing_required = grep{$_->[4] eq "yes" && !$form->{$_->[1]}} @$extracolumns;

	my $topic = $slashdb->getTopic($form->{tid});

	my $known = "";
	$fakeemail ||= '';
	if ($form->{email}) {
		$fakeemail = $form->{email};
	} elsif ($fakeemail && $user->{fakeemail} && $fakeemail eq $user->{fakeemail}) {
		$known = "mailto";
		# we assume this is like if form.email is passed in
		$fakeemail = strip_attribute($fakeemail);
	}

	my $fixedstory = fixStory($form->{story}, { sub_type => $form->{sub_type} });
	# don't let preview screen be used to pump up pagerank, if anyone
	# would waste their time doing so -- pudge
	$fixedstory = noFollow($fixedstory);

	slashDisplay('displayForm', {
		fixedstory	=> $fixedstory,
		savestory	=> $form->{story} && $form->{subj} && $form->{tid} && !@missing_required,
		missing_required => \@missing_required,
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

	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('submit');
	my $url_id;

	$form->{name} ||= '';

	if (length($form->{subj}) < 2) {
		titlebar('100%', getData('error'));
		my $error_message = getData('badsubject');
		displayForm($form->{name}, $form->{email}, $form->{skin}, '', $error_message);
		return(0);
	}

	my %keys_to_check = ( story => 1, subj => 1 );
	my $message = "";
	for (keys %$form) {
		next unless $keys_to_check{$_};
		# run through filters
		if (! filterOk('submissions', $_, $form->{$_}, \$message)) {
			displayForm($form->{name}, $form->{email}, $form->{skin}, '', $message);
			return(0);
		}
		# run through compress test
		if (! compressOk($form->{$_})) {
			my $err = getData('compresserror');
			displayForm($form->{name}, $form->{email}, $form->{skin}, '', '');
			return(0);
		}
	}

	if ($form->{url}) {
	
		if (!validUrl($form->{url})) {
			displayForm($form->{name}, $form->{email}, $form->{skin}, '', getData("invalidurl"));
			return(0);
		} else {
			my $url_data = {
				url		=> fudgeurl($form->{url}),
				initialtitle	=> strip_notags($form->{subj})
			};

			$url_id = $slashdb->getUrlCreate($url_data);
			my $url_id_q = $slashdb->sqlQuote($url_id);
			if ($constants->{plugin}{FireHose}) {
				my $firehose = getObject("Slash::FireHose");
				if (!$firehose->allowSubmitForUrl($url_id)) {
					my $submitted_items = $firehose->getFireHoseItemsByUrl($url_id);
					displayForm($form->{name}, $form->{email}, $form->{skin}, '', getData("duplicateurl", { submitted_items => $submitted_items } ));
					return(0);
				}
			}
		}
	}
	
	unless ($rkey->use) {
		my $error_message = $rkey->errstr;
		if ($rkey->death) {
			print $error_message;
		} else {
			displayForm($form->{name}, $form->{email}, $form->{skin}, '', $error_message);
		}
		return 0;
	}		

	$form->{story} = fixStory($form->{story}, { sub_type => $form->{sub_type} });

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
		primaryskid	=> $form->{primaryskid},
		mediatype	=> $form->{mediatype},
	};
	$submission->{url_id} = $url_id if $url_id;

	my @topics = ();
	my $nexus = $slashdb->getNexusFromSkid($form->{primaryskid} || $constants->{mainpage_skid});

	push @topics, $nexus;
	push @topics, $form->{tid} if $form->{tid};
	
	my $chosen_hr = genChosenHashrefForTopics(\@topics);

	my $extras = $slashdb->getNexusExtrasForChosen($chosen_hr) || [];

	my @missing_required = grep{$_->[4] eq "yes" && !$form->{$_->[1]}} @$extras;

	if (@missing_required) {
		displayForm($form->{name}, $form->{email}, $form->{skin}, '', '');
		return 0;
	}
	
	if ($extras && @$extras) {
		for (@$extras) {
			my $key = $_->[1];
			$submission->{$key} = strip_nohtml($form->{$key}) if $form->{$key};
		}
	}

	my $messagesub = { %$submission };
	$messagesub->{subid} = $slashdb->createSubmission($submission);

	if ($url_id) {
		my $globjid = $slashdb->getGlobjidCreate("submissions", $messagesub->{subid});
		$slashdb->addUrlForGlobj($url_id, $globjid);
	}

	if ($messagesub->{subid} && ($uid != getCurrentStatic('anonymous_coward_uid'))) {
		my $dynamic_blocks = getObject('Slash::DynamicBlocks');
		$dynamic_blocks->setUserBlock('submissions', $uid) if $dynamic_blocks;
	}

	my $messages = getObject('Slash::Messages');
	if ($messages) {
		my $users = $messages->getMessageUsers(MSG_CODE_NEW_SUBMISSION);
		my $data  = {
			template_name	=> 'messagenew',
			subject		=> { template_name => 'messagenew_subj' },
			submission	=> $messagesub,
		};
		$messages->create($users, MSG_CODE_NEW_SUBMISSION, $data) if @$users;
	}
	
	

	slashDisplay('saveSub', {
		title		=> 'Saving',
		width		=> '100%',
		missingemail	=> length($form->{email}) < 3,
		anonsubmit	=> isAnon($uid) && length($form->{name}) < 3 && length($form->{email}) < 3,
	});
	yourPendingSubmissions($constants, $slashdb, $user, $form, { skip_submit_body => 1 });


	return(1);
}

#################################################################
sub genChosenHashrefForTopics {
	my($topics) = @_;
	my $constants = getCurrentStatic();
	my $chosen_hr ={};
	for my $tid (@$topics) {
		$chosen_hr->{$tid} = 
			$tid == $constants->{mainpage_nexus_tid}
				? 30
				: $constants->{topic_popup_defaultweight} || 10;
	}
	return $chosen_hr;
}


createEnvironment();
main();

1;

package Slash::Edit;

use strict;
use Slash;
use Slash::Utility;
use Slash::Display;
use Slash::Hook;

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;


sub getOrCreatePreview {
	my($self) = @_;
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	return if $user->{is_anon};

	my $fh = getObject("Slash::FireHose");
	my $tagsdb = getObject("Slash::Tags");

	if (!$form->{from_id}) {
		my $id = $self->sqlSelect("MAX(preview_id)", "preview", "uid = $user->{uid} and active='yes'");
	
		if ($id && !$form->{new}) {
			return $id;
		} else {
			my $id = $self->createPreview({ uid => $user->{uid} });
			my $preview_globjid = $self->getGlobjidCreate('preview', $id);

			my $type = $user->{is_admin} ? "story" : "submission";
			$type = $form->{type} if $user->{is_admin} && $form->{type};

			my $fhid = $fh->createFireHose({ uid => $user->{uid}, preview => "yes", type => $type, globjid => $preview_globjid });

			my $fh_data = {};
			if ($type eq 'submission') {
				my $email_known = "mailto";
				$fh_data->{email} = processSub($user->{fakeemail}, $email_known) if $user->{fakeemail};
				$fh_data->{name} = $user->{nickname};
			}
			$fh->setFireHose($fhid, $fh_data) if keys %$fh_data > 0;
			$self->setPreview($id, { preview_fhid => $fhid });
			return $id;
		}
	} else {
		my $src_item = $fh->getFireHose($form->{from_id}); 
		my $id = $self->createPreview({ uid => $user->{uid} });
		my $preview_globjid = $self->getGlobjidCreate('preview', $id);
		my $preview = $self->getPreview($id);
		
		# Transfer primaryskid / tid as tags
		$self->createInitialTagsForPreview($src_item, $preview);
		
		# Transfer actual tags
		$tagsdb->transferTags($src_item->{globjid}, $preview_globjid, { src_uid => $src_item->{uid}, leave_old_activated => 1 });
		$tagsdb->transferTags($src_item->{globjid}, $preview_globjid, { leave_old_activated => 1 });

		my $type = $user->{is_admin} && $form->{type} ne "submission" ? "story" : "submission";
		my $fhid = $fh->createFireHose({ uid => $user->{uid}, preview => "yes", type => $type, globjid => $preview_globjid });

		my ($fh_data, $p_data);
		
		foreach (qw(introtext bodytext media title dept tid primaryskid createtime)) {
			$fh_data->{$_} = $src_item->{$_};
		}
		if ($src_item->{type} eq 'story') {
			$fh_data->{uid} = $src_item->{uid};
		} else {
			$fh_data->{uid} = $user->{uid};
		}
		$fh_data->{srcid} = $src_item->{srcid};

		$p_data->{submitter} = $src_item->{uid};

		if ($src_item->{type} ne "story" && $type eq "story") {
			my $url 	= $self->getUrl($src_item->{url_id});
			$fh_data->{introtext} = slashDisplay('formatHoseIntro', { forform =>1, introtext => $fh_data->{introtext}, item => $src_item, return_intro => 1, url => $url }, { Return => 1 });
		} 

		if ($src_item->{type} eq 'story') {
			my $story = $self->getStory($src_item->{srcid});
			$p_data->{neverdisplay} = 1 if $story->{neverdisplay};
			if ($story->{discussion}) {
				my $disc = $self->getDiscussion($story->{discussion});
				$p_data->{commentstatus} = $disc->{commentstatus};
			}
		}

		$p_data->{introtext} =  $fh_data->{introtext};
		$p_data->{preview_fhid} = $fhid;
		$p_data->{src_fhid} = $src_item->{id};
		$p_data->{subid} = $src_item->{srcid} if $src_item->{type} eq 'submission';


		$fh->setFireHose($fhid, $fh_data);

		$self->setPreview($id, $p_data);
		$preview = $self->getPreview($id);
		return $id;
			
	}
}

sub createInitialTagsForPreview {
	my($self, $item, $preview) = @_;
	my $user = getCurrentUser();
	return if $user->{is_anon} || !$preview || !$item || !$item->{id} || !$preview->{preview_id};

	my @tids;
	push @tids, $item->{tid} if $item->{tid};
	if ($item->{primaryskid}) {
		my $nexus = $self->getNexusFromSkid($item->{primaryskid});
		push @tids, $nexus if $nexus;
	}

	if ($item->{type} eq 'story') {
		my $tids = $self->getTopiclistForStory($item->{srcid});
		foreach (@$tids) {
			push @tids, $_;
		}
	}
	my $tree = $self->getTopicTree();
	my $tagsdb = getObject('Slash::Tags');
	my %tt = ( ); # topic tagnames
	for my $tid (@tids) {
		my $kw = $tree->{$tid}{keyword};
		next unless $tagsdb->tagnameSyntaxOK($kw); # must be a valid tagname
		$tt{$kw} = 1;
	}
	for my $tagname (sort keys %tt) {
		$tagsdb->createTag({ name => $tagname, table => 'preview', id => $preview->{preview_id} });
	}
}

sub savePreview {
	my($self, $options) = @_;
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $fh = getObject("Slash::FireHose");
	my $admindb = getObject("Slash::Admin");
	my $tagsdb = getObject("Slash::Tags");

	return if $user->{is_anon} || !$form->{id};
	
	my $preview = $self->getPreview($form->{id});
	return if !$preview && $preview->{preview_id};
	
	my $p_item = $fh->getFireHose($preview->{preview_fhid});

	#XXXEdit check if user / or eventually session has access to this preview
	return if $user->{uid} != $preview->{uid};

	my($p_data, $fh_data);

	$p_data->{introtext} 		= $form->{introtext};
	$fh_data->{createtime} 		= $form->{createtime};

	if ($p_item->{type} eq 'story') {
		$p_data->{bodytext} 		= $form->{bodytext};
		$p_data->{commentstatus} 	= $form->{commentstatus};
		$p_data->{neverdisplay} 	= $form->{display} ? '' : 1;
		
		$fh_data->{uid}		= $form->{uid};
		
		# XXXEdit maybe only use findTheTime for story type?

		$fh_data->{createtime} 	= $admindb->findTheTime($form->{createtime}, $form->{fastforward});
		$fh_data->{media} 	= $form->{media};
		$fh_data->{dept} 	= $form->{dept};
		$fh_data->{bodytext}	= $form->{bodytext};
		
		$fh_data->{dept} =~ s/[-\s]+/-/g;
		$fh_data->{dept} =~ s/^-//;
		$fh_data->{dept} =~ s/-$//;
		$fh_data->{dept} =~ s/ /-/gi;
	}

	if ($p_item->{type} eq 'submission') {
		my $email_known = "";
		$email_known = "mailto" if $form->{email} eq $user->{fakeemail};
		$fh_data->{email} = processSub($form->{email}, $email_known);
		$fh_data->{name} = $form->{name};
		$fh_data->{mediatype} = $form->{mediatype};
		$p_data->{url_text} = $form->{url};
		$p_data->{sub_type} = $form->{sub_type};
		if ($form->{url} && $form->{title}) {
			if (validUrl($form->{url})) {
				my $url_data = {
					url		=> fudgeurl($form->{url}),
					initialtitle	=> strip_notags($form->{subj})
				};

				$fh_data->{url_id} = $self->getUrlCreate($url_data);
			}
		}
	}

	$fh_data->{title} 	= $form->{title};

	$fh_data->{media} 	= $form->{media};
	$fh_data->{dept} 	= $form->{dept};
	$fh_data->{introtext}	= $form->{introtext};

	if ($p_item->{type} eq 'story') {	
		for my $field (qw( introtext bodytext media)) {
			local $Slash::Utility::Data::approveTag::admin = 2;

		# XXXEdit check this
		#	$fh_data->{$field} = $slashdb->autoUrl($form->{section}, $fh_data->{$field});
			$fh_data->{$field} = cleanSlashTags($fh_data->{$field});
			$fh_data->{$field} = strip_html($fh_data->{$field});
			$fh_data->{$field} = slashizeLinks($fh_data->{$field});
			$fh_data->{$field} = parseSlashizedLinks($fh_data->{$field});
			$fh_data->{$field} = balanceTags($fh_data->{$field});
		}
	} elsif ($p_item->{type} eq 'submission') {
		$fh_data->{introtext} = fixStory($form->{introtext}, { sub_type => $form->{sub_type} });
	}
	
	my $chosen_hr = $tagsdb->extractChosenFromTags($p_item->{globjid});
	my $rendered_hr = $self->renderTopics($chosen_hr);
	my $primaryskid = $self->getPrimarySkidFromRendered($rendered_hr);
	my $tids = $self->getTopiclistForStory('',
		{ topics_chosen => $chosen_hr });

	my $tid = $tids->[0];

	$fh_data->{tid} = $tid;
	$fh_data->{primaryskid} = $primaryskid;


	$self->setPreview($preview->{preview_id}, $p_data);
	$fh->setFireHose($preview->{preview_fhid}, $fh_data);

}

sub showEditor {
	my($self, $options) = @_;
	my $constants = getCurrentStatic();
	$options ||= {};

	my $preview_id = $self->getOrCreatePreview();
	my $editor;
	$editor .=  "PREVIEW ID: $preview_id<br>";

	my $preview = $self->getPreview($preview_id);
	

	my $fh = getObject("Slash::FireHose");
	my $p_item = $fh->getFireHose($preview->{preview_fhid});
	$editor .=  "PREVIEW FHID: $preview->{preview_fhid}<br>";
	if ($p_item && $p_item->{title} && $preview->{introtext}) {
		$editor .= "<div id='editpreview'>";
		$editor .= $fh->dispFireHose($p_item, { view_mode => 1, mode => "full" });
		$editor .= "</div>";
		$editor .= slashDisplay("init_sprites", { sprite_root_id => 'editpreview'}, { Return => 1}) if $constants->{use_sprites};
	}
	
	my $authors = $self->getDescriptions('authors', '', 1);
	$authors->{$p_item->{uid}} = $self->getUser($p_item->{uid}, 'nickname') if $p_item->{uid} && !defined($authors->{$p_item->{uid}});
	my $author_select = createSelect('uid', $authors, $p_item->{uid}, 1);
		
	my $display_check = $preview->{neverdisplay} ? '' : $constants->{markup_checked_attribute};

	
	if (!$preview->{commentstatus}) {
		$preview->{commentstatus} = $constants->{defaultcommentstatus};
	}


	my $description = $self->getDescriptions('commentcodes_extended');
	my $commentstatus_select = createSelect('commentstatus', $description, $preview->{commentstatus}, 1);
	
	$editor .= slashDisplay('editor', { 
		id 			=> $preview_id,
		preview			=> $preview, 
		item 			=> $p_item,
		author_select 		=> $author_select,
		commentstatus_select 	=> $commentstatus_select,
		display_check		=> $display_check,
		errors			=> $options->{errors}
	 }, { Page => 'edit', Return => 1 });

	return $editor;
}

sub validate {
	my($self, $preview, $item) = @_;
	my $constants = getCurrentStatic();
	my @messages;
	
	if ($item->{type} eq 'submission') {
		if (length($item->{title}) < 2) {
			push @messages, getData('badsubject');
		}
		my $message;

		my %keys_to_check = ( story => $preview->{introtext}, subj => $item->{title} );

		for (keys %keys_to_check) {
			next unless $keys_to_check{$_};
			# run through filters
			if (! filterOk('submissions', $_, $keys_to_check{$_}, \$message)) {
				push @messages, $message;
			}
			# run through compress test
			if (! compressOk($keys_to_check{$_})) {
				my $err = getData('compresserror');
				push @messages, $err;
			}
		}
		if ($preview->{url_text}) {
			if(!validUrl($preview->{url_text})) {
				push @messages, getData("invalidurl");
			}
			if ($item->{url_id}) {
				if ($constants->{plugin}{FireHose}) {
					my $firehose = getObject("Slash::FireHose");
					if (!$firehose->allowSubmitForUrl($item->{url_id})) {
						my $submitted_items = $firehose->getFireHoseItemsByUrl($item->{url_id});
						push @messages, getData("duplicateurl", { submitted_items => $submitted_items });
					}
				}
			}
		}
		if (!$item->{title} && !$preview->{introtext}) {
			push @messages, "Missing title or text";
		}
		# XXXEdit Check Nexus Extras eventually
		# XXXEdit test reskey success / failure here? or in saveItem?
	}
	use Data::Dumper;
	print STDERR Dumper(\@messages);
	return \@messages;	
}

sub saveItem {
	my($self) = @_;
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $fh = getObject("Slash::FireHose");
	return if $user->{is_anon} || !$form->{id};
	
	my $preview = $self->getPreview($form->{id});
	return if !$preview && $preview->{preview_id};

	#XXXEdit check if user / or eventually session has access to this preview
	return if $user->{uid} != $preview->{uid};

	my $fhitem = $fh->getFireHose($preview->{preview_fhid});

	my $errors = $self->validate($preview,$fhitem);

	my $create_retval = 0;
	my $save_type = 'new';

	if ($fhitem && $fhitem->{id} && !@$errors) {
		# creating a new story

		if ($fhitem->{type} eq "story") {
			my $src_item;
			$src_item = $fh->getFireHose($preview->{src_fhid}) if $preview->{src_fhid};

			# preview based on story so save edits when done
			if ($preview->{src_fhid} && $src_item && $src_item->{type} eq 'story') {
				$create_retval = $self->editUpdateStory($preview, $fhitem);
				$save_type = 'update';
			} else {   # not based on story save new
				$create_retval = $self->editCreateStory($preview, $fhitem);
			}
		
			

		} elsif ($fhitem->{type} eq 'submission') {
			$create_retval = $self->editCreateSubmission($preview, $fhitem);
		}
		push @$errors, "Save failed" if !$create_retval;
	}

	# XXXEdit eventually make sure this is ours before setting inactive

        # XXXEdit Turn all users previews inactive at this poin? 
	if ($create_retval) {
		$self->setPreview($preview->{preview_id}, { active => 'no'});
	}
	return ($create_retval, $fhitem->{type}, $save_type, $errors);
}

sub editUpdateStory {
	my($self, $preview, $fhitem) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $admindb = getObject("Slash::Admin");
	my $tagsdb = getObject("Slash::Tags");
	my $data;
	use Data::Dumper;

	my $story = $self->getStory($fhitem->{srcid});


	$data = {
		uid 		=> $fhitem->{uid},
		#sid
		title		=> $fhitem->{title},
		#section
		submitter	=> $preview->{submitter},
		dept		=> $fhitem->{dept},
		'time'		=> $fhitem->{createtime},
		bodytext 	=> $preview->{bodytext},
		introtext 	=> $preview->{introtext},
		#relatedtext
		media	 	=> $fhitem->{media},
		commentstatus	=> $preview->{commentstatus},
		#thumb
		-rendered	=> 'NULL',
		neverdisplay	=> $preview->{neverdisplay},
	};
	
	$data->{subid} = $preview->{subid} if $preview->{subid};
	$data->{fhid} = $preview->{src_fhid} if $preview->{fhid};
	
	for (qw(dept bodytext relatedtext)) {
		$data->{$_} = '' unless defined $data->{$_};  # allow to blank out
	}
		
	for my $field (qw( introtext bodytext media)) {
		local $Slash::Utility::Data::approveTag::admin = 2;

	# XXXEdit check this
	#	$data->{$field} = $slashdb->autoUrl($form->{section}, $data->{$field});
		$data->{$field} = cleanSlashTags($data->{$field});
		$data->{$field} = strip_html($data->{$field});
		$data->{$field} = slashizeLinks($data->{$field});
		$data->{$field} = parseSlashizedLinks($data->{$field});
		$data->{$field} = balanceTags($data->{$field});
	}
	
	for (qw(dept bodytext relatedtext)) {
		$data->{$_} = '' unless defined $data->{$_};  # allow to blank out
	}

	$self->setStory($story->{stoid}, $data);
	return $story->{sid};
	
	
}

sub editCreateStory {
	my($self, $preview, $fhitem) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $data;
	
	my $tagsdb = getObject("Slash::Tags");
	my $admindb = getObject("Slash::Admin");

	my $chosen_hr = { };
	my @topics;
	push @topics, $fhitem->{tid} if $fhitem->{tid};


	$chosen_hr = $tagsdb->extractChosenFromTags($fhitem->{globjid});

	$data = {
		uid 		=> $fhitem->{uid},
		#sid
		title		=> $fhitem->{title},
		#section
		submitter	=> $preview->{submitter},
		topics_chosen	=> $chosen_hr,
		dept		=> $fhitem->{dept},
		'time'		=> $admindb->findTheTime($fhitem->{createtime}, $preview->{fastforward}),
		bodytext 	=> $preview->{bodytext},
		introtext 	=> $preview->{introtext},
		#relatedtext
		media	 	=> $fhitem->{media},
		commentstatus	=> $preview->{commentstatus},
		#thumb
		-rendered	=> 'NULL',
		neverdisplay	=> $preview->{neverdisplay},
	};
	
	$data->{subid} = $preview->{subid} if $preview->{subid};
	$data->{fhid} = $preview->{src_fhid} if $preview->{fhid};
	
	for (qw(dept bodytext relatedtext)) {
		$data->{$_} = '' unless defined $data->{$_};  # allow to blank out
	}
		
	for my $field (qw( introtext bodytext media)) {
		local $Slash::Utility::Data::approveTag::admin = 2;

	# XXXEdit check this
	#	$data->{$field} = $slashdb->autoUrl($form->{section}, $data->{$field});
		$data->{$field} = cleanSlashTags($data->{$field});
		$data->{$field} = strip_html($data->{$field});
		$data->{$field} = slashizeLinks($data->{$field});
		$data->{$field} = parseSlashizedLinks($data->{$field});
		$data->{$field} = balanceTags($data->{$field});
	}
	
	for (qw(dept bodytext relatedtext)) {
		$data->{$_} = '' unless defined $data->{$_};  # allow to blank out
	}

	my $sid =  $self->createStory($data);
	
	if ($sid) {
		my $st = $self->getStory($sid);
		#XXXEdit add this later
		#$slashdb->setRelatedStoriesForStory($sid, $related_sids_hr, $related_urls_hr, $related_cids_hr, $related_firehose_hr);
		slashHook('admin_save_story_success', { story => $data });
		my $stoid = $st->{stoid};
		my $story_globjid = $self->getGlobjidCreate('stories', $stoid); 

		# XXXEdit Do we have to worry about user editing vs author uid on transfer
		$tagsdb->transferTags($fhitem->{globjid}, $story_globjid);
		$self->createSignoff($st->{stoid}, $data->{uid}, "saved");
		
		#XXXEdit Tags Auto save?
		my $admindb = getObject("Slash::Admin");
		if ($admindb) {
			$admindb->grantStoryPostingAchievements($data->{uid}, $data->{submitter});
			$admindb->addSpriteForSid($_);
		}

		
	}
	return $sid;
}

sub editCreateSubmission {
	my($self, $preview, $fhitem) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	my $tagsdb = getObject("Slash::Tags");


	my $submission = {
		email		=> $fhitem->{email},
		#XXXEdit check handling of uid / post anon
		uid		=> $fhitem->{uid},
		name		=> $fhitem->{name},
		story		=> $fhitem->{introtext},
		subj		=> $fhitem->{title},
		tid		=> $fhitem->{tid},
		primaryskid 	=> $fhitem->{primaryskid},
		mediatype	=> $fhitem->{mediatype}
		
	};
	# XXXEdit add url_id handling
	 $submission->{url_id} = $fhitem->{url_id} if $fhitem->{url_id};
	my $subid = $self->createSubmission($submission);
	my $sub_globjid = $self->getGlobjidCreate('submissions', $subid); 
	$tagsdb->transferTags($fhitem->{globjid}, $sub_globjid);

	return $subid;
}

sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if !$ENV{GATEWAY_INTERFACE} && $self->{_dbh};
}


1;

__END__

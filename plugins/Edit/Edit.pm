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

	if (!$form->{from_id}) {
		my $id = $self->sqlSelect("MAX(preview_id)", "preview", "uid = $user->{uid} and active='yes'");
	
		if ($id && !$form->{new}) {
			return $id;
		} else {
			my $id = $self->createPreview({ uid => $user->{uid} });
			my $preview_globjid = $self->getGlobjidCreate('preview', $id);

			my $type = $user->{is_admin} ? "story" : "submission";
			my $fhid = $fh->createFireHose({ uid => $user->{uid}, preview => "yes", type => $type, globjid => $preview_globjid });
			$self->setPreview($id, { preview_fhid => $fhid });
			return $id;
		}
	} else {
		my $src_item = $fh->getFireHose($form->{from_id}); 
		my $id = $self->createPreview({ uid => $user->{uid} });
		my $preview_globjid = $self->getGlobjidCreate('preview', $id);
		my $type = $user->{is_admin} ? "story" : "submission";
		my $fhid = $fh->createFireHose({ uid => $user->{uid}, preview => "yes", type => $type, globjid => $preview_globjid });

		my ($fh_data, $p_data);
		
		foreach (qw(introtext bodytext media title dept tid primaryskid)) {
			$fh_data->{$_} = $src_item->{$_};
		}

		$p_data->{submitter} = $src_item->{uid};

		if ($src_item->{type} ne "story" && $type eq "story") {
			my $url 	= $self->getUrl($src_item->{url_id});
			$fh_data->{introtext} = slashDisplay('formatHoseIntro', { forform =>1, introtext => $fh_data->{introtext}, item => $src_item, return_intro => 1, url => $url }, { Return => 1 });
			$p_data->{introtext} =  $fh_data->{introtext};
		}
		$p_data->{preview_fhid} = $fhid;
		$p_data->{src_fhid} = $src_item->{id};
		$p_data->{subid} = $src_item->{srcid} if $src_item->{type} eq 'submission';


		$fh->setFireHose($fhid, $fh_data);

		$self->setPreview($id, $p_data);
		return $id;
			
	}
}

sub savePreview {
	my($self, $options) = @_;
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $fh = getObject("Slash::FireHose");
	return if $user->{is_anon} || !$form->{id};
	
	my $preview = $self->getPreview($form->{id});
	return if !$preview && $preview->{preview_id};

	#XXXEdit check if user / or eventually session has access to this preview
	return if $user->{uid} != $preview->{uid};

	my($p_data, $fh_data);

	$p_data->{introtext} 		= $form->{introtext};
	$p_data->{bodytext} 		= $form->{bodytext};
	$p_data->{commentstatus} 	= $form->{commentstatus};
	$p_data->{neverdisplay} 	= $form->{display} ? '' : 1;

	$fh_data->{uid}		= $form->{uid};
	$fh_data->{title} 	= $form->{title};
	$fh_data->{createtime} 	= $form->{createtime} if $form->{createtime} =~ /\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d/;
	$fh_data->{media} 	= $form->{media};
	$fh_data->{dept} 	= $form->{dept};
	$fh_data->{introtext}	= $form->{introtext};
	$fh_data->{bodytext}	= $form->{bodytext};
	$fh_data->{title}	= $form->{title};
	
	
	$fh_data->{dept} =~ s/[-\s]+/-/g;
	$fh_data->{dept} =~ s/^-//;
	$fh_data->{dept} =~ s/-$//;
	$fh_data->{dept} =~ s/ /-/gi;

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


	$self->setPreview($preview->{preview_id}, $p_data);
	$fh->setFireHose($preview->{preview_fhid}, $fh_data);

}

sub showEditor {
	my($self, $options) = @_;
	my $constants = getCurrentStatic();

	my $preview_id = $self->getOrCreatePreview();
	my $editor;
	$editor .=  "PREVIEW ID: $preview_id<br>";

	my $preview = $self->getPreview($preview_id);
	

	my $fh = getObject("Slash::FireHose");
	my $p_item = $fh->getFireHose($preview->{preview_fhid});
	$editor .=  "PREVIEW FHID: $preview->{preview_fhid}<br>";
	if ($p_item && $p_item->{title} && $preview->{introtext}) {
		$editor .= $fh->dispFireHose($p_item, { view_mode => 1, mode => "full" });
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
		display_check		=> $display_check
	 }, { Page => 'edit', Return => 1 });

	return $editor;
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
	my $create_retval = 0;

	if ($fhitem && $fhitem->{id}) {
		# creating a new story
		if ($fhitem->{type} eq "story" && !$preview->{src_fhid}) {
			$create_retval = $self->editCreateStory($preview, $fhitem);
		}
	}

	# XXXEdit eventually make sure this is ours before setting inactive

        # XXXEdit Turn all users previews inactive at this poin? 
	if ($create_retval) {
		$self->setPreview($preview->{preview_id}, { active => 'no'});
	}

}

sub editCreateStory {
	my($self, $preview, $fhitem) = @_;
	my $data;
	$data = {
		uid 		=> $fhitem->{uid},
		#sid
		title		=> $fhitem->{title},
		#section
		submitter	=> $preview->{submitter},
		#topics_chosen
		dept		=> $fhitem->{dept},
		'time'		=> $fhitem->{createtime},
		bodytext 	=> $preview->{bodytext},
		introtext 	=> $preview->{introtext},
		#relatedtext
		media	 	=> $fhitem->{media},
		subid		=> $preview->{subid},
		fhid		=> $preview->{src_fhid},
		commentstatus	=> $preview->{commentstatus},
		primaryskid	=> $fhitem->{primaryskid},
		tid		=> $fhitem->{tid},
		#thumb
		-rendered	=> 'NULL',
		neverdisplay	=> $preview->{neverdisplay},
	};
	
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
		$self->createSignoff($st->{stoid}, $data->{uid}, "saved");
		
		#XXXEdit Tags Auto save?
		my $admindb = getObject("Slash::Admin");
		if ($admindb) {
			$admindb->grantStoryPostingAchievements($data->{uid}, $data->{submitter});
			$admindb->addSpriteForSid($_);
		}

		
	}
}

sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if !$ENV{GATEWAY_INTERFACE} && $self->{_dbh};
}


1;

__END__

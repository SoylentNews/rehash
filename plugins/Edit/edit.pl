#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use File::Temp 'tempfile';
use Image::Size;
use Time::HiRes;
use LWP::UserAgent;
use URI;

use Slash;
use Slash::Display;
use Slash::Hook;
use Slash::Utility;
use Slash::Admin::PopupTree;

sub main {
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $gSkin = getCurrentSkin();
	# lc just in case
	my $op = lc($form->{op});
	$op ||= 'start';

	my $tbtitle = '';

	my $ops = {
		start	=> {
			function	=> \&start,
			seclev		=> 100
		},
		edit	=> {
			function	=> \&edit,
			seclev		=> 100
		},
		preview => {
			function 	=> \&preview,
			seclev		=> 0
		},
		save	=> {
			function	=> \&save,
			seclev		=> 0
		},
		cancel => {
			function 	=> \&cancel,
			seclev		=> 0
		},
		'reset' => {
			function 	=> \&cancel,
			seclev		=> 0
		},
	};

	my $reskey = getObject('Slash::ResKey');
	my $skey = $reskey->session;
	print STDERR "Edit Session $skey for UID: $user->{uid}\n";
	$skey->set_cookie;

	my $edit = getObject("Slash::Edit");
	my $type = $edit->determineType;

	header("$constants->{sitename} - \u$type", '') or return;

	# it'd be nice to have a legit retval
	my $retval = $ops->{$op}{function}->($form, $slashdb, $user, $constants, $gSkin, $edit);

	# Display who is logged in right now.
	footer();
}


sub start {
	my($form, $slashdb, $user, $constants, $gSkin, $edit) = @_;

	my $rkey = $edit->rkey;
	unless ($rkey->create) {
		errorLog($rkey->errstr);
		print $rkey->errstr;
		return;
	}

	my $editor = $edit->showEditor();
	slashDisplay('editorwrap', { editor => $editor });
}

sub cancel {
	my($form, $slashdb, $user, $constants, $gSkin, $edit) = @_;
	$edit->initEditor();
	$form->{'new'} = 1;
	$form->{'url_text'} 	= 1;
	$form->{'title'} 	= '';
	$form->{'introtext'} 	= '';
	my $editor = $edit->showEditor();
	slashDisplay('editorwrap', { editor => $editor });
}

sub edit {
	my($form, $slashdb, $user, $constants, $gSkin, $edit) = @_;

	my $rkey = $edit->rkey;
	unless ($rkey->touch) {
		errorLog($rkey->errstr);
		print $rkey->errstr;
		return;
	}

	$edit->savePreview();
	my $editor = $edit->showEditor();
	slashDisplay('editorwrap', { editor => $editor });
}



sub preview {
	my($form, $slashdb, $user, $constants, $gSkin, $edit) = @_;

	my $rkey = $edit->rkey;
	unless ($rkey->touch) {
		errorLog($rkey->errstr);
		print $rkey->errstr;
		return;
	}

	$edit->savePreview;
	$edit->setRelated;
	my $editor = $edit->showEditor({ previewing => 1 });
	slashDisplay('editorwrap', { editor => $editor });
}

sub save {
	my($form, $slashdb, $user, $constants, $gSkin, $edit) = @_;

	my $rkey = $edit->rkey;
	$edit->savePreview;
	my($retval, $type, $save_type, $errors, $preview) = $edit->saveItem($rkey);

	my($editor, $id);
	my $saved_item;
	if ($retval) {
		my $num_id = $id = $retval;
		$num_id = $slashdb->getStoidFromSidOrStoid($id)  if ($type eq 'story');
		my $fh = getObject("Slash::FireHose");
		my $item = $fh->getFireHoseByTypeSrcid($type, $num_id);
		my $options = { mode => 'full' };
		$options->{options} = { user_view_uid => $item->{uid} } if $type eq 'journal';
		$options->{options}{no_collapse} = 1 if $form->{state} ne 'inline';
		$saved_item = $fh->dispFireHose($item, $options);
		$saved_item .= slashDisplay("init_sprites", { sprite_root_id => 'editpreview'}, { Return => 1}) if $constants->{use_sprites};


		$slashdb->setCommonStoryWords;
	} else { 
		$editor = $edit->showEditor({ errors => $errors });
	}
	my $save_result;
	$save_result = slashDisplay('editsave', { editor => $editor, id => $id, save_type => $save_type, type => $type, saved_item => $saved_item, state => $form->{state} }, { Return => 1 }) if !$editor;
	slashDisplay('editorwrap', { editor => $editor, save_result => $save_result });
}


createEnvironment();
main();
1;

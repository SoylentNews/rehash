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
		}
	};

	my $reskey = getObject('Slash::ResKey');
	my $skey = $reskey->session;
	print STDERR "Edit Session $skey for UID: $user->{uid}\n";
	$skey->set_cookie;

	header("Edit", '') or return;

	# it'd be nice to have a legit retval
	my $retval = $ops->{$op}{function}->($form, $slashdb, $user, $constants, $gSkin);

	# Display who is logged in right now.
	footer();
}


sub start {
	my($form, $slashdb, $user, $constants) = @_;

	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('edit-submit');
	unless ($rkey->create) {
		errorLog($rkey->errstr);
		return;
	}

	my $edit = getObject("Slash::Edit");
	my $editor = $edit->showEditor();
	slashDisplay('editorwrap', { editor => $editor });
}

sub edit {
	my($form, $slashdb, $user, $constants) = @_;

	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('edit-submit');
	unless ($rkey->touch) {
		errorLog($rkey->errstr);
		return;
	}

	my $edit = getObject("Slash::Edit");
	$edit->savePreview();
	my $editor = $edit->showEditor();
	slashDisplay('editorwrap', { editor => $editor });
}



sub preview {
	my($form, $slashdb, $user, $constants) = @_;

	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('edit-submit');
	unless ($rkey->touch) {
		errorLog($rkey->errstr);
		return;
	}

	my $edit = getObject("Slash::Edit");
	$edit->savePreview();
	my $editor = $edit->showEditor({ previewing => 1});
	slashDisplay('editorwrap', { editor => $editor });
}

sub save {
	my($form, $slashdb, $user, $constants) = @_;

	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('edit-submit');
	unless ($rkey->use) {
		errorLog($rkey->errstr);
		return;
	}

	my $edit = getObject("Slash::Edit");
	$edit->savePreview();
	my($retval, $type, $save_type, $errors) = $edit->saveItem();
	my($editor, $id);
	my $saved_item;
	if ($retval) {
		$id = $retval;
		my $num_id = $id;
		$num_id = $slashdb->getStoidFromSidOrStoid($id)  if ($type eq 'story');
		my $fh = getObject("Slash::FireHose");
		my $item = $fh->getFireHoseByTypeSrcid($type, $num_id);
		$saved_item = $fh->dispFireHose($item, { view_mode => 1, mode => 'full'});
	} else { 
		$editor = $edit->showEditor({ errors => $errors });
	}
	slashDisplay('editorwrap', { editor => $editor, id => $id, save_type => $save_type, type => $type, saved_item => $saved_item });
}


createEnvironment();
main();
1;

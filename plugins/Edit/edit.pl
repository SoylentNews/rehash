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
	$op ||= 'edit';

	my $tbtitle = '';

	my $ops = {
		edit	=> {
			function	=> \&edit,
			seclev		=> 100,
		},
		preview => {
			function 	=> \&preview,
			seclev		=> 100
		},
		save	=> {
			function	=> \&save,
			seclev		=> 100
		}
	};

	# redirect for non-admin users for now 
	if ($user->{seclev} < 100) {
		redirect("$gSkin->{rootdir}/users.pl");
		return;
	}

	header("Edit", '') or return;

	# it'd be nice to have a legit retval
	my $retval = $ops->{$op}{function}->($form, $slashdb, $user, $constants, $gSkin);

	# Display who is logged in right now.
	footer();
}


sub edit {
	my($form, $slashdb, $user, $constants) = @_;
	my $edit = getObject("Slash::Edit");
	my $editor = $edit->showEditor();
	slashDisplay('editorwrap', { editor => $editor });
}

sub preview {
	my($form, $slashdb, $user, $constants) = @_;
	my $edit = getObject("Slash::Edit");
	$edit->savePreview();
	my $editor = $edit->showEditor();
	slashDisplay('editorwrap', { editor => $editor });
	
}

sub save {
	my($form, $slashdb, $user, $constants) = @_;
	my $edit = getObject("Slash::Edit");
	$edit->savePreview();
	my ($retval, $type, $save_type, $errors) = $edit->saveItem();
	my ($editor, $id);
	if ($retval) {
		$id = $retval;
	} else { 
		$editor = $edit->showEditor({ errors => $errors });
	}
	slashDisplay('editorwrap', { editor => $editor, id => $id, save_type => $save_type, type => $type });

}


createEnvironment();
main();
1;

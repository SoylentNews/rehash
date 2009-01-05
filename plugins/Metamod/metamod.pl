#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

#################################################################
sub main {
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $op = getCurrentForm('op') || '';
	my $section = $slashdb->getSection($form->{section});

	if ($constants->{plugin}{FireHose} && $constants->{metamod_use_firehose}) {
		redirect("$constants->{rootdir}/firehose.pl?op=metamod");
	}

	header(getData('header'), $section->{section}) or return;

	if (!$constants->{m1}) {
		print getData('no_moderation');
	} else {
		my $metamod_db = getObject('Slash::Metamod');
		if (!$metamod_db->metamodEligible($user)) {
			print getData('not-eligible');
		} elsif ($op eq 'MetaModerate') {
			$metamod_db->metaModerate();
			print getData('thanks');
		} else {
			displayTheComments();
		}
	}

	writeLog($op);
	footer();
}

#################################################################
sub displayTheComments {
	my($id) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $moddb = getObject("Slash::$constants->{m1_pluginname}");
	my $metamod_db = getObject('Slash::Metamod');

	my $reasons = $moddb->getReasons();
	my $comments = $metamod_db->getMetamodsForUser(
		$user, $constants->{m2_comments}
	);

	# dispTheComments calls Slash::dispComment, which uses the dispComment
	# template, which processes the dispLinkComment template, which is
	# skipped when $user->{mode} eq 'metamod'.  I'd rather see that done
	# by setting a specific $user->{state} field and checking for it in
	# the dispComment template to avoid processing dispLinkComment.  The
	# point of skipping dispLinkComment is that comments displayed for
	# metamod don't need "Reply" and "Parent" links, on the theory that
	# they are just distracting.
	#
	# The dispComment template also calls Slash::Utility::Display::
	# linkComment, which passes $user->{mode} to the linkComment
	# template, which puts it into the comments.pl &mode= param of the
	# comments it links to.  But comments.pl doesn't know what to do
	# with a mode=metamod.

	$user->{mode} = 'metamod';

	slashDisplay('dispTheComments', {
		comments 	=> $comments,
		reasons		=> $reasons,
	});
}

#################################################################
createEnvironment();
main();

1;


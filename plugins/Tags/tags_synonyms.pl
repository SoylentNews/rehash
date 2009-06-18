#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2009 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

##################################################################
sub main {
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	setCurrentSkin(determineCurrentSkin());
	my $gSkin = getCurrentSkin();

	my $tagsdb = getObject('Slash::Tags');
	if (!$tagsdb || $user->{seclev} < 100) {
		redirect('/');
	}
	my $clout_types = $tagsdb->getCloutTypes();

	my $error = '';
	my $cloutname = $form->{cloutname} || '';
	my $clid = $cloutname ? $clout_types->{$cloutname} : 0;
	if ($clid) {
		my $pref_tnid = $form->{pref_tagname} ? $tagsdb->getTagnameidCreate($form->{pref_tagname}) : 0;
		my $syn_tnid =  $form->{syn_tagname}  ? $tagsdb->getTagnameidCreate($form->{syn_tagname})  : 0;
		if ($pref_tnid && $syn_tnid) {
			my($result, $msg) = add_syn($clid, $pref_tnid, $syn_tnid);
			if (!$result) {
				$error = $msg;
			}
			# If $result is true, $msg is an arrayref with interesting
			# data about the change that was made, but the data is
			# a subset of what's in $synall anyway.
		}
	}

	my $synall = $tagsdb->listSynonymsAll();
	header({ title => 'Tag Synonym Editor' });
	slashDisplay('synonyms', { error => $error, clout_types => $clout_types, synall => $synall },
		{ Page => 'tags' });
	footer();
}

sub add_syn {
	my($clid, $pref, $syn) = @_;
	my $tagsdb = getObject('Slash::Tags');
	return $tagsdb->renderTagnameSimilarityFromChosen($pref, $syn, $clid);
}

#################################################################
createEnvironment();
main();

1;


#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use File::Spec::Functions;
use Slash;
use Slash::Display;
use Slash::Utility;

sub main {
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $gSkin = getCurrentSkin();
	$ENV{REQUEST_URI} ||= '';

	# catch missing .shtml links and redirect
	# should only get here if static file not found
	if ($ENV{REQUEST_URI} =~ m{^/?\w+/(\d\d/\d\d/\d\d/\d+)\.shtml(?:\?(\S*))?$}) {
		my($sid, $extra) = ($1, $2);
		my $reader = getObject('Slash::DB', { db_type => 'reader' } );
		my $story = $reader->getStory($sid); # get section, check if story exists
		if ($story->{sid}) {
			my $skin = $reader->getSkin($story->{primaryskid});
			# XXXSKIN - hardcode as with Slash::Utility::Display
			my $skinname = $skin->{name} eq 'mainpage' ? 'articles' : $skin->{name};
			if (-e catfile($constants->{basedir}, $skinname, "$sid.shtml")) {
				my $url = "$gSkin->{rootdir}/$skinname/$sid.shtml";
				$url .= "?$extra" if $extra;
				redirect($url);
				return;
			}
		}
	}

	my $r = Apache->request;
	$r->status(404);

	my $url = strip_literal(substr($ENV{REQUEST_URI}, 1));
	my $admin = $constants->{adminmail};

	header('404 File Not Found', $form->{section}) or return;

	my($new_url, $errnum) = fixHref($ENV{REQUEST_URI}, 1);

	if ($errnum && $errnum !~ /^\d+$/) {
		slashDisplay('main', {
			url	=> $new_url,
			origin	=> $url,
			message	=> $errnum,
		});
	} else {
		slashDisplay('main', {
			url	=> $new_url,
			origin	=> $url,
			error	=> $errnum,
		});
	}

	writeLog($url);
	footer();
}

createEnvironment();
main();

1;

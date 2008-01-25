#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use File::Path;
use Slash::Constants ':slashd';

use vars qw( %task $me );

$task{$me}{timespec} = '3,33 * * * *';
$task{$me}{on_startup} = 1;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;

	skinHeaders(@_, '');
	my $skins = $slashdb->getSkins;
	for my $skid (keys %$skins) {
		mkpath "$constants->{basedir}/$skins->{$skid}{name}", 0, 0755;
		skinHeaders(@_, $skins->{$skid});
	}

	my $file = "$constants->{basedir}/slashhead-gen-full.inc";
	open my $fh, ">$file" or die "Can't open $file : $!";
	setCurrentForm('ssi', 1);
	my $header = header("", "", { noheader => 1, Return => 1 });
	setCurrentForm('ssi', 0);
	print $fh $header;
	close $fh;
	
	$file = "$constants->{basedir}/slashcssbase.inc";
	open $fh, ">$file" or die "Can't open $file : $!";
	my $cssbase = slashDisplay("html-header", { only_css => 1}, { Return => 1 });
	print $fh $cssbase;

	return;
};

sub skinHeaders {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin, $skin) = @_;

	my $skinname = '';
	if ($skin) {
		$skinname = $skin->{name};
		createCurrentHostname($skin->{hostname});
	}
	# What to do here if !$skin?  Does that mean to use $gSkin?
	# Or return without doing anything?  An empty string passed to
	# getHeadFootPages() means to use the template skin 'default'.
	# Apparently, for years, we've been passing open() a filename
	# like /u/l/s/s/foo/htdocs//slashhead.inc and it's been
	# quietly fixing the double-slash for us.  If I'm correct in
	# understanding how this has been working, we want to start
	# using File::Path to construct $file below. - Jamie 2005/11/23

	my $form = getCurrentForm();

	setCurrentForm('ssi', 1);
	my $head_pages = $slashdb->getHeadFootPages($skinname, 'header');

	foreach (@$head_pages) {
		my $file;

		if ($_->[0] eq 'misc') {
			$file = "$constants->{basedir}/$skinname/slashhead.inc";
		} else {
			$file = "$constants->{basedir}/$skinname/slashhead-$_->[0].inc";
		}

		open my $fh, ">$file" or die "Can't open $file : $!";
		my $header = header("", $skinname, { noheader => 1, Return => 1, Page => $_->[0], nopageid => 1 });
		print $fh $header;
		close $fh;
	}

	setCurrentForm('ssi', 0);
	my $foot_pages = $slashdb->getHeadFootPages($skinname, 'footer');

	foreach (@$foot_pages) {
		my $file;
		
		if ($_->[0] eq 'misc') {
			$file = "$constants->{basedir}/$skinname/slashfoot.inc";
		} else {
			$file = "$constants->{basedir}/$skinname/slashfoot-$_->[0].inc";
		}

		open my $fh, ">$file" or die "Can't open $file : $!";
		my $footer = footer({ Return => 1 });
		print $fh $footer;
		close $fh;
	}
}

1;


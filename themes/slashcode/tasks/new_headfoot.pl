#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
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

	skinHeaders(@_, "");
	my $skins = $slashdb->getSkins;
	for my $skid (keys %$skins) {
		mkpath "$constants->{basedir}/$skins->{$skid}{name}", 0, 0755;
		skinHeaders(@_, $skins->{$skid});
	}

	return ;
};

sub skinHeaders {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin, $skin) = @_;

	my($skinname);
	if ($skin) {
		$skinname = $skin->{name};
		createCurrentHostname($skin->{hostname});
	}

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
		my $header = header("", $skinname, { noheader => 1, Return => 1, Page => $_->[0] });
		print $fh $header;
		close $fh;
	}

	setCurrentForm('ssi', 0);
	open my $fh, ">$constants->{basedir}/$skinname/slashfoot.inc"
		or die "Can't open $constants->{basedir}/$skinname/slashfoot.inc: $!";
	my $footer = footer({ Return => 1 });
	print $fh $footer;
	close $fh;
}

1;


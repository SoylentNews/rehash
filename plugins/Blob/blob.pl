#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::Blob;
use Slash::Utility;

#################################################################
sub main {
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $gSkin = getCurrentSkin();
	my $blob = getObject("Slash::Blob", { db_type => 'reader' });
	
	unless ($form->{id}) {
		redirect("$gSkin->{rootdir}/404.pl");
		return;
	}
	
	my $data = $blob->get($form->{id});
	if (!$data || $user->{seclev} < $data->{seclev}) {
		redirect("$gSkin->{rootdir}/404.pl");
		return;
	}

	http_send({
		content_type	=> $data->{content_type},
		filename	=> $data->{filename},
		do_etag		=> 1,
		content		=> $data->{data}
	});
}
main();

#################################################################
1;

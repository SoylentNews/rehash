#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
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
	my $blob = getObject("Slash::Blob", { db_type => 'reader' });
	
	unless ($form->{id}) {
		redirect("$constants->{rootdir}/404.pl");
		return;
	}
	
	my $data = $blob->get($form->{id});
	if (!$data || $user->{seclev} < $data->{seclev}) {
		redirect("$constants->{rootdir}/404.pl");
		return;
	}

	my $r = Apache->request;
	$r->content_type($data->{content_type});
	$r->header_out('Cache-Control', 'private');
	$r->header_out('Content-Disposition', "attachment; filename=$data->{filename}")
		if $data->{filename};
	$r->status(200);
	$r->send_http_header;
	$r->rflush;
	$r->print($data->{data});
	$r->rflush;
	$r->status(200);
}
main();

#################################################################
1;

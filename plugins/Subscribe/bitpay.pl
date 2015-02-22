#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use utf8;
use Slash;
use Slash::Display;
use Slash::Utility;
use DateTime;
use DateTime::Format::MySQL;
use Slash::Constants qw(:web :messages);

sub main {
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	bitpay($form, $slashdb, $user, $constants);
	return;
}

sub bitpay {
	my ($form, $slashdb, $user, $constants) = @_;
	


	my $subscribe = getObject('Slash::Subscribe');
	my $invoice = $subscribe->bpCreateInvoice(
					price			=> $form->{amount},
					currency		=> "USD",
					notificationType	=> "json",
					transactionSpeed	=> "high",
					fullNotifications	=> "true",
					redirectURL		=> $constants->{bitpay_return},
					notificationURL		=> $constants->{bitpay_callback},
					posData			=> "{ \"uid\" : $form->{uid} , \"type\" : \"$form->{type}\" , \"puid\" : $form->{puid} , \"from\" : \"$form->{from}\", \"days\" : $form->{days} }",
	);

	redirect("$invoice->{url}", "302");
}


createEnvironment();
main();

1;

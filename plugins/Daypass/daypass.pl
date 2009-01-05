#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

##################################################################
sub main {
	my $gSkin = getCurrentSkin();
	my $daypass_reader = getObject('Slash::Daypass', { db_type => 'reader' });
	my $dps = $daypass_reader->getDaypassesAvailable();
	if (!$dps || !@$dps) {
		redirect($gSkin->{rootdir});
	}

	my $daypass_writer = getObject('Slash::Daypass');
	my $form = getCurrentForm();
	my $dpk = $form->{dpk} || "";
	if ($dpk) {
		# Strip this form field.
		$dpk =~ /^(\w+)$/;
		$dpk = $1 || "";
	}

	my($adnum, $minduration) = (0, 0);

	if ($dpk) {

		my $confcode = $daypass_writer->confirmDaypasskey($dpk);
		if ($confcode) {
			# Do the housekeeping required to echo the
			# conf code out to the client's browser,
			# and then don't continue with the rest of
			# this function (in particular, don't create a
			# new key).
			key_confirmed($confcode);
			return ;
		}
		# The user probably didn't watch enough of the
		# ad.  Let them keep watching!
		print STDERR scalar(localtime) . " daypass.pl $$ apparently early click\n";
		$adnum = $form->{adnum};
		$adnum =~ /^(\d+)$/;
		$adnum = $1 || 0;
		if (!$adnum) {
			# We don't know which ad they were watching (they
			# probably edited the URL) so fetch a new one.
print STDERR scalar(localtime) . " daypass.pl $$ no adnum found, refetching\n";
			$dpk = "";
		}

	}

	if (!$dpk) {

		my $dp_hr = $daypass_reader->getDaypass();
		if (!$dp_hr) {
			# Something went wrong.  We don't have a daypass for
			# the user to see.
print STDERR scalar(localtime) . " daypass.pl $$ cannot choose daypass\n";
			redirect($gSkin->{rootdir});
			return ;
		}
		$dpk = $daypass_writer->createDaypasskey($dp_hr);
		if (!$dpk) {
			# Something went wrong.  We can't show the user a key.
print STDERR scalar(localtime) . " daypass.pl $$ cannot show key\n";
			redirect($gSkin->{rootdir});
			return ;
		}
		$adnum = $dp_hr->{adnum};
		$minduration = $dp_hr->{minduration} || 0;

	}

	# Whether because the user just got a new key created for
	# them, or because they clicked too fast and we're reusing
	# their old key, they have a key in $dpk.

	header(getData('head')) or return;

	slashDisplay('main', {
		adnum		=> $adnum,
		dpk		=> $dpk,
		minduration	=> $minduration,
	});

	footer();
}

sub key_confirmed {
	my($confcode) = @_;
	# Pause to allow replication to catch up, so when
	# the user gets back to the homepage, they will
	# show up as having the daypass.
	sleep 2;
	setCookie('daypassconfcode', $confcode, '+24h');
	my $gSkin = getCurrentSkin();
	redirect($gSkin->{rootdir});
}

#################################################################
createEnvironment();
main();

1;


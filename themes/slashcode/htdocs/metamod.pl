#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
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
	my $op = getCurrentForm('op');
	my $section = $slashdb->getSection($form->{section});

	header(getData('header'), $section->{section});

	my $ineligible = $user->{is_anon} || $user->{rtbl} ||
			 !$slashdb->checkForMetaModerator($user);		

	if (!$constants->{allow_moderation}) {
		print getData('no_moderation');
	} elsif ($ineligible) {
		print getData('not-eligible');
	} else {
		#my $last =
		#	($slashdb->getModeratorLast($user->{uid}))->{lastmmid};
		#unless ($last) {
			#$last = $slashdb->getModeratorLogRandom($uid);
			#$slashdb->setUser($user->{uid}, {
			#	lastmmid => $last,
			#});
		#}

		if ($op eq 'MetaModerate') {
			metaModerate();
		} else {
			displayTheComments();
		}
	}

	writeLog($op);
	footer();
}

#################################################################
# This is deprecated and not used in this scope.
# 	- Cliff 08/24/01
#
#sub karmaBonus {
#	my $constants = getCurrentStatic();
#	my $user = getCurrentUser();
#
#	my $x = $constants->{m2_maxbonus} - $user->{karma};
#
#	return 0 unless $x > 0;
#	return 1 if rand($constants->{m2_maxbonus}) < $x;
#	return 0;
#}

#################################################################
sub metaModerate {
	my($id) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	my(%metamod, @mmids);
	my $y = $constants->{m2_comments};
	$metamod{unfair} = $metamod{fair} = 0;
	for (keys %{$form}) {
		# Meta mod form data can only be a '+' or a '-' so we apply some
		# protection from taint.
		next if $form->{$_} !~ /^[+-]$/; # bad input, bad!
		if (/^mm(\d+)$/) {
			# Sanity check. If this isn't right, then someone's
			# fiddling with the form.
			if ($y < 1) {
				print getData('unexpected_item');
				return;
			}		
			push(@mmids, $1) if $form->{$_};
			$metamod{unfair}++ if $form->{$_} eq '-';
			$metamod{fair}++ if $form->{$_} eq '+';
			$y--;
		}
	}

	my %m2victims;
	for (@mmids) {
		$m2victims{$_} = [ $slashdb->getModeratorLog($_, 'uid'),
				   $form->{"mm$_"} ];
	}

	# Obsoleted by consensus moderation:
	#	vars.m2_mincheck, vars.m2_maxunfair, vars.m2_toomanyunfair
	# M2 validation is now determined by long term analysis. This analysis
	# is now left to the slashd moderation Task, which can vary by theme.
	#
	# Note the use of a naked "10" here for the M2 flag. This is used
	# to denote M2 entries that have yet to be reconciled.
	my $changes = $slashdb->setMetaMod(\%m2victims, 10, scalar time);

	slashDisplay('metaModerate', {
		changes	=> $changes,
		count	=> $constants->{m2_comments} - $y,
		metamod	=> \%metamod,
	});

	$slashdb->setModeratorVotes($user->{uid}, \%metamod);
}

#################################################################
sub displayTheComments {
	my($id) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	my $comments = $slashdb->getMetamodComments(
		$user, $constants->{m2_comments}
	);

	# We set this to prevent the "Reply" and "Parent" links from
	# showing up. If the metamoderator needs context, they can use
	# the CID link.
	$user->{mode} = 'archive';

	slashDisplay('dispTheComments', {
		comments 	=> $comments,
	});
}

#################################################################
# This is going to break under replication
#
# Yeah, this should be a lot more flexible, but lets leave that
# issue for when we revamp security. For now, we'll just use
# $slashdb->checkForMetaModerator(). What we do lose is the
# reporting behind WHY a user can't M2, which isn't all that
# critical right now, since they will get an error of some sort.
#						- Cliff
#sub isEligible {
#	my $slashdb = getCurrentDB();
#	my $constants = getCurrentStatic();
#	my $user = getCurrentUser();
#
#	my $tuid = $slashdb->countUsers();
#	my $last = $slashdb->getModeratorLast($user->{uid});
#
#	my $result = slashDisplay('isEligible', {
#		user_count	=> $tuid,
#		'last'		=> $last,
#	}, { Return => 1, Nocomm => 1 });
#
#	if ($result ne 'Eligible') {
#		print $result;
#		return 0;
#	}
#
#	# Eligible for M2. Determine M2 comments by selecting random starting
#	# point in moderatorlog.
#	unless ($last->{'lastmmid'}) {
#		$last->{'lastmmid'} = $slashdb->getModeratorLogRandom();
#		$slashdb->setUser($user->{uid}, { lastmmid => $last->{'lastmmid'} });
#	}
#
#	return $last->{'lastmmid'}; # Hooray!
#}

#################################################################
createEnvironment();
main();


#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
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

	# this text must be in a template!
	header(getData('header'));

	if (! $slashdb->checkForMetaModerator($user)) {
		print getData('not-eligible');
	} else {
		my $last = ($slashdb->getModeratorLast($user->{uid}))->{lastmmid};
		unless ($last) {
			$last = $slashdb->getModeratorLogRandom();
			$slashdb->setUser($user->{uid}, {
				lastmmid => $last,
			});
       		}

		if ($op eq 'MetaModerate') {
			metaModerate($last);
		} else {
			displayTheComments($last);
		}
	}

	writeLog($op);
	footer();
}

#################################################################
sub karmaBonus {
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	my $x = $constants->{m2_maxbonus} - $user->{karma};

	return 0 unless $x > 0;
	return 1 if rand($constants->{m2_maxbonus}) < $x;
	return 0;
}

#################################################################
sub metaModerate {
	my($id) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	my $y = 0;	# Sum of elements from form.
	my(%metamod, @mmids);

	$metamod{unfair} = $metamod{fair} = 0;
	foreach (keys %{$form}) {
		# Meta mod form data can only be a '+' or a '-' so we apply some
		# protection from taint.
		next if $form->{$_} !~ /^[+-]$/; # bad input, bad!
		if (/^mm(\d+)$/) {
			push(@mmids, $1) if $form->{$_};
			$metamod{unfair}++ if $form->{$_} eq '-';
			$metamod{fair}++ if $form->{$_} eq '+';
		}
	}

	my %m2victims;
	foreach (@mmids) {
		if ($y < $constants->{m2_comments}) { 
			$y++;
			my $muid = $slashdb->getModeratorLog($_, 'uid');

			$m2victims{$_} = [$muid, $form->{"mm$_"}];
		}
	}

	# Perform M2 validity checks and set $flag accordingly. M2 is only recorded
	# if $flag is 0. Immediate and long term checks for M2 validity go here
	# (or in moderatord?).
	#
	# Also, it was probably unnecessary, but I want it to be understood that
	# an M2 session can be retrieved by:
	#		SELECT * from metamodlog WHERE uid=x and ts=y 
	# for a given x and y.
	my($flag, $ts) = (0, time);
	if ($y >= $constants->{m2_mincheck}) {
		# Test for excessive number of unfair votes (by percentage)
		# (Ignore M2 & penalize user)
		$flag = 2 if ($metamod{unfair}/$y >= $constants->{m2_maxunfair});
		# Test for questionable number of unfair votes (by percentage)
		# (Ignore M2).
		$flag = 1 if (!$flag && ($metamod{unfair}/$y >= $constants->{m2_toomanyunfair}));
	}

	my $changes = $slashdb->setMetaMod(\%m2victims, $flag, $ts);

	slashDisplay('metaModerate', {
		changes	=> $changes,
		count	=> $y,
		metamod	=> \%metamod,
	});

	$slashdb->setModeratorVotes($user->{uid}, \%metamod) unless $user->{is_anon};

	# Of course, I'm waiting for someone to make the eventual joke...
	my($change, $excon);
	if ($y > $constants->{m2_mincheck} && !$user->{is_anon}) {
		if (!$flag && karmaBonus()) {
			# Bonus Karma For Helping Out - the idea here, is to not 
			# let meta-moderators get the +1 posting bonus.
			($change, $excon) =
				("karma$constants->{m2_bonus}", "and karma<$constants->{m2_maxbonus}");
			$change = $constants->{m2_maxbonus}
				if $constants->{m2_maxbonus} < $user->{karma} + $constants->{m2_bonus};

		} elsif ($flag == 2) {
			# Penalty for Abuse
			($change, $excon) = ("karma$constants->{m2_penalty}", '');
		}

		# Update karma.
		# This is an abuse
		$slashdb->setUser($user->{uid}, { -karma => "karma$change" }) if $change;
	}
}

#################################################################
sub displayTheComments {
	my($id) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	$user->{points} = 0;
	my $comments = $slashdb->getMetamodComments($id, $user->{uid},
		$constants->{m2_comments});

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


# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Metamod;

use strict;
use Date::Format qw(time2str);
use Slash;
use Slash::Utility::Environment;

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

sub isInstalled {
	my($class) = @_;
	my $constants = getCurrentStatic();
	return 0 if ! $constants->{m2};
	return $class->SUPER::isInstalled();
}

########################################################

# Our .pm modules don't often do processing of %$form and it's not
# considered a good idea.  But for convenience, and because there's
# no real other way to do it, I'm putting it here anyway.

sub metaModerate {
	my($self, $is_admin) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	# The user is only allowed to metamod the mods they were given.
	my @m2_mods_saved = $self->getM2ModsSaved();
	my %m2_mods_saved = map { ( $_, 1 ) } @m2_mods_saved;

	# %m2s is the data structure we'll be building.
	my %m2s = ( );

	for my $key (keys %{$form}) {
		# Metamod form data can only be a '+' or a '-'.
		next unless $form->{$key} =~ /^[+-]$/;
		# We're only looking for the metamod inputs.
		next unless $key =~ /^mm(\d+)$/;
		my $mmid = $1;
		# Only the user's given mods can be used.
		next unless $m2_mods_saved{$mmid} || $is_admin;
		# This one's valid.  Store its data in %m2s.
		$m2s{$mmid}{is_fair} = ($form->{$key} eq '+') ? 1 : 0;
	}

	# The createMetaMod() method does all the heavy lifting here.
	# Re m2_multicount:  if this var is set, then our vote for
	# reason r on cid c applies potentially to *all* mods of
	# reason r on cid c.
	return $self->createMetaMod($user, \%m2s, $constants->{m2_multicount});
}

# Input: %$m2s is a hash whose keys are moderatorlog IDs (mmids) and
# values are hashrefs with keys "is_fair" (0=unfair, 1=fair).
# $m2_user is the user hashref for the user who is M2'ing.
# $multi_max is the maximum number of additional mods which each
# mod in %$m2s can apply to (see the constants m2_multicount).
# Return: nothing.
# Note that karma and token changes as a result of metamod are
# done in the run_moderatord task.

sub createMetaMod {
	my($self, $m2_user, $m2s, $multi_max, $options) = @_;
	my $constants = getCurrentStatic();
	my $moddb = getObject("Slash::$constants->{m1_pluginname}");
	$options ||= {};
	my $rows;

	# If this user has no saved mods, by definition nothing they try
	# to M2 is valid, unless of course they're an admin.
	return if !$m2_user->{m2_mods_saved} && !$m2_user->{is_admin} && !$options->{inherited};

	# The user is only allowed to metamod the mods they were given.
	my @m2_mods_saved = $self->getM2ModsSaved($m2_user);
	my %m2_mods_saved = map { ( $_, 1 ) } @m2_mods_saved;
	my $saved_mods_encountered = 0;
	my @m2s_mmids = sort { $a <=> $b } keys %$m2s;
	for my $mmid (@m2s_mmids) {
		delete $m2s->{$mmid} if !$m2_mods_saved{$mmid} && !$m2_user->{is_admin} &!$options->{inherited};
		$saved_mods_encountered++ if $m2_mods_saved{$mmid};
	}
	return if !keys %$m2s;

	# If we are allowed to multiply these M2's to apply to other
	# mods, go ahead.  multiMetaMod changes $m2s in place.  Note
	# that we first screened %$m2s to allow only what was saved for
	# this user;  having made sure they are not trying to fake an
	# M2 of something disallowed, now we can multiply them out to
	# possibly affect more.  Note that we save the original list --
	# when we tally how many metamods this user has done, we only
	# count their intentions, not the results.
	my %m2s_orig = ( map { $_, 1 } keys %$m2s );
	if ($multi_max) {
		$self->multiMetaMod($m2_user, $m2s, $multi_max);
	}

	# We need to know whether the M1 IDs are for moderations
	# that were up or down.
	my $m1_list = join(",", keys %$m2s);
	my $m2s_vals = $self->sqlSelectAllHashref("id", "id, val",
		"moderatorlog", "id IN ($m1_list)");
	for my $m1id (keys %$m2s_vals) {
		$m2s->{$m1id}{val} = $m2s_vals->{$m1id}{val};
	}

	# Whatever happens below, as soon as we get here, this user has
	# done their M2 for the day and gets their list of OK mods cleared.
	# The only exceptions are admins who didn't metamod any of their
	# saved mods, and inherited M2s.  In the case of inherited mods
	# the m2_user isn't actively m2ing, their m2s are just being
	# applied to another mod.

	if (!$options->{inherited} &&
		!$m2_user->{is_admin}
		|| ($m2_user->{is_admin} && $saved_mods_encountered)) {
		$rows = $self->sqlUpdate("users_info", {
			-lastm2 =>       'NOW()',
			m2_mods_saved => '',
		}, "uid=$m2_user->{uid} AND m2_mods_saved != ''");
		$self->setUser_delete_memcached($m2_user->{uid});
		if (!$rows) {
			# The update failed, presumably because the user clicked
			# the MetaMod button multiple times quickly to try to get
			# their decisions to count twice.  The user did not count
			# on our awesome powers of atomicity:  only one of those
			# clicks got to set m2_mods_saved to empty.  That one
			# wasn't us, so we do nothing.
			return ;
		}
	}
	my($voted_up_fair, $voted_down_fair, $voted_up_unfair, $voted_down_unfair)
		= (0, 0, 0, 0);
	for my $mmid (keys %$m2s) {
		my $mod_uid = $moddb->getModeratorLog($mmid, 'uid');
		my $is_fair = $m2s->{$mmid}{is_fair};

		# Increment the m2count on the moderation in question.  If
		# this increment pushes it to the current consensus threshold,
		# change its m2status from 0 ("eligible for M2") to 1
		# ("all done with M2'ing, but not yet reconciled").  Note
		# that we insist not only that the count be above the
		# current consensus point, but that it be odd, in case
		# something weird happens.

		$rows = 0;
		$rows = $self->sqlUpdate(
			"moderatorlog", {
				-m2count =>     "m2count+1",
				-m2status =>    "IF(m2count >= m2needed
							AND MOD(m2count, 2) = 1,
							1, 0)",
			},
			"id=$mmid AND m2status=0
			 AND m2count < m2needed AND active=1",
# XXX did assn_order's behaviour change in MySQL 4.1, is this why we have swaths of mods not reconciled?
			{ assn_order => [qw( -m2count -m2status )] },
		) unless $m2_user->{tokens} < $self->getVar("m2_mintokens", "value", 1) &&
			!$m2_user->{is_admin};

		$rows += 0; # if no error, returns 0E0 (true!), we want a numeric answer

		my $ui_hr = { };
		     if ($is_fair  && $m2s->{$mmid}{val} > 0) {
			++$voted_up_fair if $m2s_orig{$mmid};
			$ui_hr->{-up_fair}      = "up_fair+1";
		} elsif ($is_fair  && $m2s->{$mmid}{val} < 0) {
			++$voted_down_fair if $m2s_orig{$mmid};
			$ui_hr->{-down_fair}    = "down_fair+1";
		} elsif (!$is_fair && $m2s->{$mmid}{val} > 0) {
			++$voted_up_unfair if $m2s_orig{$mmid};
			$ui_hr->{-up_unfair}    = "up_unfair+1";
		} elsif (!$is_fair && $m2s->{$mmid}{val} < 0) {
			++$voted_down_unfair if $m2s_orig{$mmid};
			$ui_hr->{-down_unfair}  = "down_unfair+1";
		}
		$self->sqlUpdate("users_info", $ui_hr, "uid=$mod_uid");

		if ($rows) {
			# If a row was successfully updated, insert a row
			# into metamodlog.
			$self->sqlInsert("metamodlog", {
				mmid =>         $mmid,
				uid =>          $m2_user->{uid},
				val =>          ($is_fair ? '+1' : '-1'),
				-ts =>          "NOW()",
				active =>       1,
			});
		} else {
			# If a row was not successfully updated, probably the
			# moderation in question was assigned to more than
			# $consensus users, and the other users pushed it up to
			# the $consensus limit already.  Or this user has
			# gotten bad M2 and has negative tokens.  Or the mod is
			# no longer active.
			$self->sqlInsert("metamodlog", {
				mmid =>         $mmid,
				uid =>          $m2_user->{uid},
				val =>          ($is_fair ? '+1' : '-1'),
				-ts =>          "NOW()",
				active =>       0,
			});
		}

		$self->setUser_delete_memcached($mod_uid);
	}

	my $voted = $voted_up_fair || $voted_down_fair || $voted_up_unfair || $voted_down_unfair;
	$self->sqlUpdate("users_info", {
		-m2voted_up_fair        => "m2voted_up_fair     + $voted_up_fair",
		-m2voted_down_fair      => "m2voted_down_fair   + $voted_down_fair",
		-m2voted_up_unfair      => "m2voted_up_unfair   + $voted_up_unfair",
		-m2voted_down_unfair    => "m2voted_down_unfair + $voted_down_unfair",
	}, "uid=$m2_user->{uid}") if $voted;
	$self->setUser_delete_memcached($m2_user->{uid});
}

# Input: $m2_user and %$m2s are the same as for setMetaMod, below.
# $max is the max number of mods that an M2 vote can count on.
# Return: modified %$m2s in place.
sub multiMetaMod {
	my($self, $m2_user, $m2s, $max) = @_;
	return if !$max;

	my $constants = getCurrentStatic();
	my @orig_mmids = keys %$m2s;
	return if !@orig_mmids;
	my $orig_mmid_in = join(",", @orig_mmids);
	my $uid_q = $self->sqlQuote($m2_user->{uid});

	my $mod_reader = getObject("Slash::$constants->{m1_pluginname}", { db_type => 'reader' });
	my $reasons = $mod_reader->getReasons();
	my $m2able_reasons = join(",",
		sort grep { $reasons->{$_}{m2able} }
		keys %$reasons);
	return if !$m2able_reasons;
	my $max_limit = $max * scalar(@orig_mmids) * 2;

	# $id_to_cr is the cid-reason hashref.  From it we'll make
	# an SQL clause that matches any moderations whose cid and
	# reason both match any of the moderations passed in.
	my $id_to_cr = $self->sqlSelectAllHashref(
		"id",
		"id, cid, reason",
		"moderatorlog",
		"id IN ($orig_mmid_in)
		 AND active=1 AND m2status=0"
	);
	return if !%$id_to_cr;
	my @cr_clauses = ( );
	for my $mmid (keys %$id_to_cr) {
		push @cr_clauses, "(cid=$id_to_cr->{$mmid}{cid}"
			. " AND reason=$id_to_cr->{$mmid}{reason})";
	}
	my $cr_clause = join(" OR ", @cr_clauses);
	my $user_limit_clause = "";
	$user_limit_clause =  " AND uid != $uid_q AND cuid != $uid_q " unless $m2_user->{seclev} >= 100;
	# Get a list of other mods which duplicate one or more of the
	# ones we're modding, but aren't in fact the ones we're modding.
	my $others = $self->sqlSelectAllHashrefArray(
		"id, cid, reason",
		"moderatorlog",
		"($cr_clause)".
		$user_limit_clause.
		" AND m2status=0
		 AND reason IN ($m2able_reasons)
		 AND active=1
		 AND id NOT IN ($orig_mmid_in)",
		"ORDER BY RAND() LIMIT $max_limit"
	);
	# If there are none, we're done.
	return if !$others or !@$others;

	# To decide which of those other mods we can use, we need to
	# limit how many we use for each cid-reason pair.  That means
	# setting up a hashref whose keys are cid-reason pairs, and
	# counting until we hit a limit.  This is so that, in the odd
	# situation where a cid has been moderated a zillion times
	# with one reason, people who metamod one of those zillion
	# moderations will not have undue power (nor undue
	# consequences applied to themselves).

	# Set up the counting hashref, and the hashref to correlate
	# cid-reason back to orig mmid.
	my $cr_count = { };
	my $cr_to_id = { };
	for my $mmid (keys %$m2s) {
		my $cid = $id_to_cr->{$mmid}{cid};
		my $reason = $id_to_cr->{$mmid}{reason};
		$cr_count->{"$cid-$reason"} = 0;
		$cr_to_id->{"$cid-$reason"} = $mmid;
	}
	for my $other_hr (@$others) {
		my $new_mmid = $other_hr->{id};
		my $cid = $other_hr->{cid};
		my $reason = $other_hr->{reason};
		next if $cr_count->{"$cid-$reason"}++ >= $max;
		my $old_mmid = $cr_to_id->{"$cid-$reason"};
		# And here, we add another M2 with the same is_fair
		# value as the old one -- this is the whole purpose
		# for this method.
		my %old = %{$m2s->{$old_mmid}};
		$m2s->{$new_mmid} = \%old;
	} 
}       

########################################################

sub getM2Needed {
	my($self, $uid, $cid, $reason, $adjust) = @_;
	my $constants = getCurrentStatic();

	my $m2_base = undef;
	if ($constants->{m2_inherit}) {
		my $mod = $self->getModForM2Inherit($uid, $cid, $reason);
		if ($mod) {
			$m2_base = $mod->{m2needed};
		}
	}
	if (!defined $m2_base) {
		$m2_base = $self->getBaseM2Needed($cid, $reason)
			|| $constants->{m2_consensus};
	}

	my $m2needed = $adjust || 0;
	$m2needed += $m2_base;
	$m2needed = 1 if $m2needed < 1;         # minimum of 1
	$m2needed = int($m2needed/2)*2+1;       # always an odd number
	return $m2needed;
}

sub getBaseM2Needed {
	my($self, $cid, $reason, $options) = @_;
	my $constants = getCurrentStatic();
	my $consensus;
	if ($constants->{m2_use_sliding_consensus}) {
		my $cid_q = $self->sqlQuote($cid);
		my $reason_q = $self->sqlQuote($reason);
		my $count = $self->sqlCount("moderatorlog",
			"cid=$cid_q AND reason=$reason_q AND active=1");
		$count += $options->{count_modifier} if defined $options->{count_modifier};
		my $index = $count - 1;
		$index = 0 if $index < 1;
		$index = @{$constants->{m2_sliding_consensus}} - 1
		if $index > (@{$constants->{m2_sliding_consensus}} - 1);
		$consensus = $constants->{m2_sliding_consensus}[$index];
	} else {
		$consensus = $constants->{m2_consensus};
	}

	return $consensus;
}

sub adjustForNewMod {
	my($self, $uid, $cid, $reason, $active, $mod_id) = @_;
	my $constants = getCurrentStatic();

	# inherit and apply m2s if necessary
	if ($constants->{m2_inherit}) {
		my $i_m2s = $self->getInheritedM2sForMod($uid, $cid, $reason, $active, $mod_id);
		$self->applyInheritedM2s($mod_id, $i_m2s);
	}

	# cid_reason count changed, update m2needed for related mods
	if ($constants->{m2_use_sliding_consensus} && $active) {
		# Note: this only updates m2needed for moderations
		# that have m2status=0, not those that have already
		# reached consensus.  If we're strictly enforcing like
		# mods sharing one group of m2s, this behavior might have
		# to change.  If so it's likely to be var controlled.
		# A better solution is likely to inherit m2s when a new
		# mod is created of a given cid-reason if we want to have
		# the same m2s across all like m1s.  If the mod whose m2s
		# we are inheriting from has already reached consensus
		# we probably just want to inherit those m2s and not up
		# the m2needed value for either mods.
		my $post_m2_base = $self->getBaseM2Needed($cid, $reason);
		my $cid_q = $self->sqlQuote($cid);
		my $reason_q = $self->sqlQuote($reason);
		$self->sqlUpdate('moderatorlog',
			{ m2needed => $post_m2_base },
			"cid=$cid_q AND reason=$reason_q
			 AND m2status=0 AND active=1
			 AND m2needed < $post_m2_base");
	}
}

# Pass the id if we've already created the mod for which we are inheriting
# mods.  If getting the inherited m2s before the mod is created, omit
# passing the id as a parameter.

sub getInheritedM2sForMod {
	my($self, $mod_uid, $cid, $reason, $active, $id) = @_;
	return [] unless $active;
	my $mod = $self->getModForM2Inherit($mod_uid, $cid, $reason, $id);
	my $p_mid = defined $mod ? $mod->{id} : undef;
	return [] unless $p_mid;
	my $m2s = $self->sqlSelectAllHashrefArray("*", "metamodlog", "mmid=$p_mid");
	return $m2s;
}

sub getModForM2Inherit {
	my($self, $mod_uid, $cid, $reason, $id) = @_;
	my $mod_uid_q = $self->sqlQuote($mod_uid);
	my $constants = getCurrentStatic();
	my $mod_reader = getObject("Slash::$constants->{m1_pluginname}", { db_type => 'reader' });
	my $reasons = $mod_reader->getReasons();
	my $m2able_reasons = join(",",
		sort grep { $reasons->{$_}{m2able} }
		keys %$reasons);
	return [] if !$m2able_reasons;

	my $id_str = $id ? " AND id!=".$self->sqlQuote($id) : "";

	# Find the earliest active moderation that we can inherit m2s from
	# which isn't the mod we are inheriting them into.  This uses the
	# same criteria as multiMetaMod for determining which mods we can
	# propagate m2s to, or from in the case of inheriting
	my($mod) = $self->sqlSelectHashref("*","moderatorlog",
				"cid=".$self->sqlQuote($cid).
				" AND reason=".$self->sqlQuote($reason).
				" AND uid!=$mod_uid_q AND cuid!=$mod_uid_q".
				" AND reason in($m2able_reasons)".
				" AND active=1 $id_str",
				" ORDER BY id ASC LIMIT 1"
			);
	return $mod;
}

sub applyInheritedM2s {
	my($self, $mod_id, $m2s) = @_;

	foreach my $m2 (@$m2s) {
		my $m2_user = $self->getUser($m2->{uid});
		my $cur_m2 = {
			$mod_id => { is_fair => $m2->{val} == 1 ? 1 : 0 }
		};
		$self->createMetaMod($m2_user, $cur_m2, 0, { inherited => 1 });
	}
}

########################################################
# A friendlier interface to the "m2_mods_saved" param.  Has probably
# more sanity-checking than it needs.
sub getM2ModsSaved {
	my($self, $user) = @_;
	$user = getCurrentUser() if !$user;

	my $m2_mods_saved = $user->{m2_mods_saved} || "";
	return ( ) if !$m2_mods_saved;
	my %m2_mods_saved =
		map { ( $_, 1 ) }
		grep /^\d+$/,
		split ",", $m2_mods_saved;
	return sort { $a <=> $b } keys %m2_mods_saved;
}

sub setM2ModsSaved {
	my($self, $user, $m2_mods_saved_ar) = @_;
	$user = getCurrentUser() if !$user;

	my $m2_mods_saved_txt = join(",",
		sort { $a <=> $b }
		grep /^\d+$/,
		@$m2_mods_saved_ar);
	$self->setUser($user->{uid}, { m2_mods_saved => $m2_mods_saved_txt });
}

########################################################
# This is the method that returns the list of comments for a user to
# metamod, at any given time.  Its logic was changed significantly
# in August 2002.
sub getMetamodsForUser {
	my($self, $user, $num_comments) = @_;
	my $constants = getCurrentStatic();
	# First step is to see what the user already has marked down to
	# be metamoderated.  If there are any such id's, that still
	# aren't done being M2'd, keep those on the user's to-do list.
	# (I.e., once a user sees a list of mods, they keep seeing that
	# same list until they click the button;  reloading the page
	# won't give them new mods.)  If after this check, the list is
	# short of the requisite number, fill up the list, re-save it,
	# and return it.

	# Get saved list of mods to M2 (and check its formatting).

	my @m2_mods_saved = $self->getM2ModsSaved($user);

	# See which still need M2'ing.

	if (@m2_mods_saved) {
		my $m2_mods_saved = join(",", @m2_mods_saved);
		my $mods_not_done = $self->sqlSelectColArrayref(
			"id",
			"moderatorlog",
			"id IN ($m2_mods_saved) AND active=1 AND m2status=0"
		);
		@m2_mods_saved = grep /^\d+$/, @$mods_not_done;
	}

	# If we need more, get more.

	my $num_needed = $num_comments - scalar(@m2_mods_saved);
	if ($num_needed) {
		my %m2_mods_saved = map { ( $_, 1 ) } @m2_mods_saved;
		my $new_mods = $self->getMetamodsForUserRaw($user->{uid},
			$num_needed, \%m2_mods_saved);
		for my $id (@$new_mods) { $m2_mods_saved{$id} = 1 }
		@m2_mods_saved = sort { $a <=> $b } keys %m2_mods_saved;
	}
	$self->setM2ModsSaved($user, \@m2_mods_saved);

	# If we didn't get enough, that's OK, but note it in the
	# error log.

	if (scalar(@m2_mods_saved) < $num_comments) {
		errorLog("M2 gave uid $user->{uid} "
			. scalar(@m2_mods_saved)
			. " comments, wanted $num_comments: "
			. join(",", @m2_mods_saved)
		);
	}

	# OK, we have the list of moderations this user needs to M2,
	# and we have updated the user's data so the next time they
	# come back they'll see the same list.  Now just retrieve
	# the necessary data for those moderations and return it.

	return $self->_convertModsToComments(@m2_mods_saved);
}

{ # closure
my %anonymize = ( ); # gets set inside the function
sub _convertModsToComments {
	my($self, @mods) = @_;
	my $constants = getCurrentStatic();
	my $mainpage_skid = $constants->{mainpage_skid};

	return [ ] unless scalar(@mods);

	if (!scalar(keys %anonymize)) {
		%anonymize = (
			nickname =>     '-',
			uid =>          getCurrentStatic('anonymous_coward_uid'),
			points =>       0,
		);
	}

	my $mods_text = join(",", @mods);

	# We can and probably should get the cid/reason data in
	# getMetamodsForUserRaw(), but it's only a minor performance
	# slowdown for now.

	my $mods_hr = $self->sqlSelectAllHashref(
		"id",
		"id, cid, reason AS modreason",
		"moderatorlog",
		"id IN ($mods_text)"
	);
	my @cids = map { $mods_hr->{$_}{cid} } keys %$mods_hr;
	my $cids_text = join(",", @cids);

	# Get the comment data required to show the user the list of mods.

	my $comments_hr = $self->sqlSelectAllHashref(
		"cid",
		"comments.cid AS cid, comments.sid AS sid,
		 comments.uid AS uid,
		 date, subject, pid, reason, comment,
		 discussions.sid AS discussions_sid,
		 primaryskid,
		 title,
		 sig, nickname",
		"comments, comment_text, discussions, users",
		"comments.cid IN ($cids_text)
		 AND comments.cid = comment_text.cid
		 AND comments.uid = users.uid
		 AND comments.sid = discussions.id"
	);

	# If there are any mods whose comments no longer exist (we're
	# not too fussy about atomicity with these tables), ignore
	# them.

	my @orphan_mod_ids = grep {
		!exists $comments_hr->{ $mods_hr->{$_}{cid} }
	} keys %$mods_hr;
	delete @$mods_hr{@orphan_mod_ids};

	# Put the comment data into the mods hashref.

	for my $mod_id (keys %$mods_hr) {
		my $mod_hr = $mods_hr->{$mod_id};       # This mod.
		my $cid = $mod_hr->{cid};
		my $com_hr = $comments_hr->{$cid};      # This mod's comment.
		for my $key (keys %$com_hr) {
			next if exists($mod_hr->{$key});
			my $val = $com_hr->{$key};
			# Anonymize comment identity a bit for fairness.
			$val = $anonymize{$key} if exists $anonymize{$key};
			$mod_hr->{$key} = $val;
		}
		$com_hr->{primaryskid} ||= $mainpage_skid;
		my $rootdir = $self->getSkin($com_hr->{primaryskid})->{rootdir};
		# XXX With discussions.kinds we can trust the URL unless it's
		# a user-created discussion, now.
		if ($mod_hr->{discussions_sid}) {
			# This is a comment posted to a story discussion, so
			# we can link straight to the story, providing even
			# more context for this comment.
			$mod_hr->{url} = "$rootdir/article.pl?sid=$mod_hr->{discussions_sid}";
		} else {
			# This is a comment posted to a discussion that isn't
			# a story.  It could be attached to a poll, a journal
			# entry, or nothing at all (user-created discussion).
			# Whatever the case, we can't trust the url field, so
			# we should just link to the discussion itself.
			$mod_hr->{url} = "$rootdir/comments.pl?sid=$mod_hr->{sid}";
		}
		$mod_hr->{no_moderation} = 1;
	}

	# Copy the hashref into an arrayref, along the way doing a last-minute
	# check to make sure every comment has an sid.  We're going to sort
	# this arrayref first by sid, then by cid, and last by mod id, so mods
	# that share a story or even a comment will appear together, saving
	# the user a bit of confusion.

	my @final_mods = ( );
	for my $mod_id (
		sort {
			$mods_hr->{$a}{sid} <=> $mods_hr->{$b}{sid}
			||
			$mods_hr->{$a}{cid} <=> $mods_hr->{$b}{cid}
			||
			$a <=> $b
		} keys %$mods_hr
	) {
		# This "next" is a holdover from old code - is this really
		# necessary!?  Every cid has a discussion and every
		# discussion has an sid.
		next unless $mods_hr->{$mod_id}{sid};
		push @final_mods, $mods_hr->{$mod_id};
	}

	return \@final_mods;
}
}

# Get a list of moderations that the given uid is able to metamod,
# with the oldest not-yet-done mods given highest priority.
sub getMetamodsForUserRaw {
	my($self, $uid, $num_needed, $already_have_hr) = @_;
	my $uid_q = $self->sqlQuote($uid);
	my $constants = getCurrentStatic();
	my $m2_wait_hours = $constants->{m2_wait_hours} || 12;

	my $mod_reader = getObject("Slash::$constants->{m1_pluginname}", { db_type => 'reader' });
	my $reasons = $mod_reader->getReasons();
	my $m2able_reasons = join(",",
		sort grep { $reasons->{$_}{m2able} }
		keys %$reasons);
	return [ ] if !$m2able_reasons;

	# Prepare the lists of ids and cids to exclude.
	my $already_id_list = "";
	if (%$already_have_hr) {
		$already_id_list = join ",", sort keys %$already_have_hr;
	}
	my $already_cids_hr = { };
	my $already_cid_list = "";
	if ($already_id_list) {
		$already_cids_hr = $self->sqlSelectAllHashref(
			"cid",
			"cid",
			"moderatorlog",
			"id IN ($already_id_list)"
		);
		$already_cid_list = join(",", sort keys %$already_cids_hr);
	}

	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	# We need to consult two tables to get a list of moderatorlog IDs
	# that it's OK to M2:  moderatorlog of course, and metamodlog to
	# check that this user hasn't M2'd them before.  Because this is
	# necessarily a table scan on moderatorlog, speed will be essential.
	# We're going to do the select on moderatorlog first, then run its
	# results through the other two tables to exclude what we can't use.
	# However, since we can't predict how many of our hits will be
	# deemed "bad" (unusable), we may have to loop around more than
	# once to get enough.
	my $getmods_loops = 0;
	my @ids = ( );
	my $mod_hr;

	my $num_oldzone_needed = 0;
	my $oldzone = $self->getVar('m2_oldzone', 'value', 1);
	if ($oldzone) {
		$num_oldzone_needed = int(
			$num_needed *
			($constants->{m2_oldest_zone_percentile}
				* $constants->{m2_oldest_zone_mult})/100
			+ rand()
		);
		# just a sanity check...
		$num_oldzone_needed = $num_needed if $num_oldzone_needed > $num_needed;
	}
	my $num_normal_needed = $num_needed - $num_oldzone_needed;

	GETMODS: while ($num_needed > 0 && ++$getmods_loops <= 4) {
		my $limit = $num_needed*2+10; # get more, hope it's enough
		my $already_id_clause = "";
		$already_id_clause  = " AND  id NOT IN ($already_id_list)"
			if $already_id_list;
		my $already_cid_clause = "";
		$already_cid_clause = " AND cid NOT IN ($already_cid_list)"
			if $already_cid_list;
		my $only_old_clause = "";
		if ($num_oldzone_needed) {
			# We need older mods.
			$only_old_clause = " AND id <= $oldzone";
		}
		my $only_perdec_clause = '';
		my $perdec = $constants->{m2_only_perdec} || 10;
		if ($perdec < 10) {
			$only_perdec_clause = " AND FLOOR((id % 100)/10) <= $perdec";
		}
		$mod_hr = { };
		$mod_hr = $reader->sqlSelectAllHashref(
			"id",
			"id, cid,
			 RAND() AS rank",
			"moderatorlog",
			"uid != $uid_q AND cuid != $uid_q
			 AND m2status=0
			 AND reason IN ($m2able_reasons)
			 AND active=1
			 AND ts < DATE_SUB(NOW(), INTERVAL $m2_wait_hours HOUR)
			 $only_perdec_clause $already_id_clause $already_cid_clause $only_old_clause",
			"ORDER BY rank LIMIT $limit"
		);
		if (!$mod_hr || !scalar(keys %$mod_hr)) {
			# OK, we didn't get any.  If we were looking
			# just for old, then forget it and move on.
			# Otherwise, give up completely.
			if ($num_oldzone_needed) {
				$num_needed += $num_oldzone_needed;
				$num_oldzone_needed = 0;
				next GETMODS;
			} else {
				last GETMODS;
			}
		}

		# Exclude any moderations this user has already metamodded.
		my $mod_ids = join ",", keys %$mod_hr;
		my %mod_ids_bad = map { ( $_, 1 ) }
			$self->sqlSelectColArrayref("mmid", "metamodlog",
				"mmid IN ($mod_ids) AND uid = $uid_q");

		# Add the new IDs to the list.
		my @potential_new_ids =
			# In order by rank, in case we got more than needed.
			sort { $mod_hr->{$a}{rank} <=> $mod_hr->{$b}{rank} }
			keys %$mod_hr;
		# Walk through the new potential mod IDs, and add them in
		# one at a time.  Those which are for cids already on our
		# list, or for mods this user has already metamodded, don't
		# make the cut.
		my @new_ids = ( );
		for my $id (@potential_new_ids) {
			my $cid = $mod_hr->{$id}{cid};
			next if $already_cids_hr->{$cid};
			next if $mod_ids_bad{$id};
			push @new_ids, $id;
			$already_cids_hr->{$cid} = 1;
		}
		if ($num_oldzone_needed) {
			$#new_ids = $num_oldzone_needed-1 if $#new_ids > $num_oldzone_needed-1;
			$num_oldzone_needed -= scalar(@new_ids);
		} else {
			$#new_ids = $num_normal_needed-1 if $#new_ids > $num_normal_needed-1;
			$num_normal_needed -= scalar(@new_ids);
		}
		push @ids, @new_ids;
		$num_needed -= scalar(@new_ids);

		# If we tried to get all the oldzone mods we wanted, and
		# failed, give up trying now.  The rest of the looping we
		# do should be for non-oldzone mods (i.e. we only look
		# for the oldzone on the first pass through here).
		if ($num_oldzone_needed) {
			print STDERR scalar(localtime) . " could not get all oldzone mods needed: ids '@ids' num_needed '$num_needed' num_oldzone_needed '$num_oldzone_needed' num_normal_needed '$num_normal_needed'\n";
			$num_normal_needed += $num_oldzone_needed;
			$num_oldzone_needed = 0;
		}
	}
	if ($getmods_loops > 4) {
		use Data::Dumper;
		print STDERR "GETMODS looped the max number of times,"
			. " returning '@ids' for uid '$uid'"
			. " num_needed '$num_needed' num_oldzone_needed '$num_oldzone_needed' num_normal_needed '$num_normal_needed'"
			. " (maybe out of mods to M2?)"
			. " already_had: " . Dumper($already_have_hr);
	}

	return \@ids;
}

########################################################

sub getMetamodlogForUser {
	my($self, $uid, $limit) = @_;
	my $uid_q = $self->sqlQuote($uid);
	my $limit_clause = $limit ? " LIMIT $limit" : '';
	my $m2s_ar = $self->sqlSelectAllHashrefArray(
		'metamodlog.id, metamodlog.mmid, metamodlog.ts,
		 metamodlog.val, metamodlog.active,
		 comments.subject, comments.cid, comments.sid,
		 moderatorlog.m2status, moderatorlog.reason,
		 moderatorlog.val AS modval',
		'metamodlog, moderatorlog, comments',
		"metamodlog.mmid = moderatorlog.id
		 AND comments.cid = moderatorlog.cid
		 AND metamodlog.uid = $uid_q",
		"GROUP BY moderatorlog.cid, moderatorlog.reason
		 ORDER BY moderatorlog.ts DESC
		 $limit_clause"
	);

	my $constants = getCurrentStatic();
	if ($constants->{m2}) {
		my $metamod_db = getObject('Slash::Metamod');
		$metamod_db->addFairUnfairCounts($m2s_ar, 'mmid');
	}

	return $m2s_ar;
}

########################################################

# Add counts of fair and unfair metamods to an arrayref.  The
# column to key the mod id on is passed in (since it may differ:
# either moderatorlog.id or metamodlog.mmid may be the source).

sub addFairUnfairCounts {
	my($self, $ar, $keyname) = @_;
	my @ids =
		map { $_->{$keyname} }
		grep { $_->{$keyname} }
		@$ar;
	my $m2_fair = $self->getMetamodCountsForModsByType('fair', \@ids);
	my $m2_unfair = $self->getMetamodCountsForModsByType('unfair', \@ids);
	foreach my $hr (@$ar) {
		my $id = $hr->{$keyname};
		next unless $id;
		$hr->{m2fair}   = $m2_fair  ->{$id}{count}	|| 0;
		$hr->{m2unfair} = $m2_unfair->{$id}{count}	|| 0;
	}
}

# Return counts of fair and unfair metamods for a list of mods.

sub getMetamodCountsForModsByType {
        my($self, $type, $ids) = @_;
        my $id_str = join ',', @$ids;
        return {} unless @$ids;

        my($cols, $where);
        $cols = 'mmid, COUNT(*) AS count';
        $where = "mmid IN ($id_str) AND active=1 ";
        if ($type eq 'fair') {
                $where .= ' AND val > 0 ';
        } elsif ($type eq 'unfair') {
                $where .= ' AND val < 0 ';
        }
        my $modcounts = $self->sqlSelectAllHashref('mmid',
                $cols,
                'metamodlog',
                $where,
                'GROUP BY mmid');
        return $modcounts;
}

# Given an arrayref of moderation ids, a hashref keyed by moderation
# ids is returned.  The moderation ids point to arrays containing info
# metamoderations for that particular moderation id.

sub getMetamodsForMods {
        my($self, $ids, $limit) = @_;
        my $id_str = join ',', @$ids;
        return {} unless @$ids;
        # If the limit param is missing or zero, all matching
        # rows are returned.
        $limit = " LIMIT $limit" if $limit;
        $limit ||= "";

        my $m2s = $self->sqlSelectAllHashrefArray(
                "id, mmid, metamodlog.uid AS uid, val, ts, active, nickname",
                "metamodlog, users",
                "mmid IN ($id_str) AND metamodlog.uid=users.uid",
                "ORDER BY mmid DESC $limit");

        my $mods_to_m2s = {};
        for my $m2 (@$m2s) {
                push @{$mods_to_m2s->{$m2->{mmid}}}, $m2;
        }
        return $mods_to_m2s;
}

########################################################

sub metamodEligible {
	my($self, $user) = @_;
	my $constants = getCurrentStatic();

	# If the Metamod plugin hasn't been installed, or has been
	# turned off, nobody is eligible to metamod.
	return 0 if !$constants->{m2};

	# This should be true since admins should be able to do
	# anything at any time.  We now also provide admins controls
	# to metamod arbitrary moderations.
	return 1 if $user->{is_admin};

	# Easy tests the user can fail to be ineligible to metamod.
	return 0 if $user->{is_anon} || !$user->{willing} || $user->{karma} < 0;

	# Not eligible if metamodded too recently.
	my $m2_freq = $self->getVar('m2_freq', 'value', 1) || 86400;
	my $cutoff_str = time2str("%Y-%m-%d %H:%M:%S",
		time() - $m2_freq, 'GMT');
	return 0 if $user->{lastm2} ge $cutoff_str;

	# Last test, have to hit the DB for this one (but it's very quick).
	# XXXMULTIPLEMASTERS
	my $maxuid = $self->countUsers({ max => 1 });
	return 0 if $user->{uid} > $maxuid * $constants->{m2_userpercentage};

	# User is OK to metamod.
	return 1;
}

1;


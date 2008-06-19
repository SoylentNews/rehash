# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Moderation;

use strict;
use Date::Format qw(time2str);
use Slash;
use Slash::Utility;
use Slash::DB::Utility;
use Slash::Display;

use base 'Exporter';
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

our $VERSION = $Slash::Constants::VERSION;

sub new {
	my($class, $user) = @_;
	my $self = {};

	(my $modname = $class) =~ s/^Slash:://;

	my $plugin = getCurrentStatic('plugin');
	return unless $plugin->{$modname};

	my $constants = getCurrentStatic();
	return undef unless $constants->{m1}
		&& $constants->{m1_pluginname} eq $modname;

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect();

	return $self;
}

########################################################

sub getReasons {
	my($self) = @_;
	my $table_cache = "_reasons_cache";
	$self->{$table_cache} ||= $self->sqlSelectAllHashref(
		"id", "*", "modreasons"
	);
	return {( %{$self->{$table_cache}} )};
}

########################################################

# to-do:
#
# db down
# allow moderation
# archived (done)
# -1 == no points
# -2 == not enough points
# already posted
# $slashdb->setStory($discussion->{sid}, { writestatus => 'dirty' });

sub ajaxModerateCid {
	my($slashdb, $constants, $user, $form, $options) = @_;
	my $self = getObject('Slash::' . $constants->{m1_pluginname});
	my $cid = $form->{cid} or return;
	my $sid = $form->{sid} or return;
	my $reason = $form->{reason} or return;

	my $score  = "comment_score_$cid";
	my $select = "reasondiv_$cid";

	my $html = {};
	my $error;

	my $discussion = $self->getDiscussion($sid);
	my $moderate_check = $self->moderateCheck($form, $user, $constants, $discussion);

	if ($moderate_check->{msg}) {
		$html->{$select} = $moderate_check->{msg};
	} elsif ($moderate_check->{count}) {
		$html->{$select} = $moderate_check->{msg};
	} else {
		# XXX this should be in templates -- pudge
		my $ret_val = $self->moderateComment($sid, $cid, $reason, { no_display => 1 });
		if ($ret_val > 0) {
			my $comment = $self->getComment($cid) or return;
			my $reasons = $self->getReasons or return;
			my $points = getPoints(
				$comment, $user,
				$constants->{comment_minscore}, $constants->{comment_maxscore},
				$self->countUsers({ max => 1 }), $self->getReasons
			);

			$html->{$score}  = "Score:$points";
			$html->{$score} = qq[<a href="#" onclick="getModalPrefs('modcommentlog', 'Moderation Comment Log', $cid); return false">$html->{$score}</a>]
				if $constants->{modal_prefs_active} && !$user->{is_anon};
			$html->{$score} .= ", $reasons->{$comment->{reason}}{name}"
				if $comment->{reason} && $reasons->{$comment->{reason}};
			$html->{$score} = "($html->{$score})";

			my $ptstr = $user->{points} == 1 ? 'point' : 'points';
			$html->{$select} = "Moderated '$reasons->{$reason}{name}.'  $user->{points} $ptstr left.";
			$self->setStory($sid, { writestatus => 'dirty' });

		} elsif (!$ret_val) {
			$html->{$select} = "Error: No moderation performed.";

		} elsif ($ret_val == -1 || $ret_val == -2) {
			$html->{$select} = "Error: $user->{points} moderation points left.";
		}
	}

	$options->{content_type} = 'application/json';
	return Data::JavaScript::Anon->anon_dump({
		html    => $html,
		error   => $error,
	});
}

##################################################################
# moderateComment
#
# Handles moderation
# Moderates a specific comment.
# Returns 0 or 1 for whether the comment changed
# Returns a negative value when an error was encountered. The
# warning the user sees is handled within the .pl file.
#
# Currently defined error types:
# -1 - No points
# -2 - Not enough points
#
##################################################################

sub moderateComment {
	my($self, $sid, $cid, $reason, $options) = @_;
	return 0 unless dbAvailable("write_comments");
	return 0 unless $reason;
	$options ||= {};

	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	my $comment_changed = 0;
	my $superAuthor = $options->{is_superauthor}
		|| ( $constants->{authors_unlimited}
			&& $user->{seclev} >= $constants->{authors_unlimited} );

	# this check is done already, but we want to return a specific error
	if (1 > $user->{points} && !$user->{acl}{modpoints_always} && !$superAuthor) {
		return -1;
	}

	my $comment = $options->{comment} || $self->getComment($cid);

	# Start putting together the data we'll need to display to
	# the user.
	my $reasons = $self->getReasons();
	my $dispArgs = {
		cid     => $cid,
		sid     => $sid,
		subject => $comment->{subject},
		reason  => $reason,
		points  => $user->{points},
		reasons => $reasons,
	};

	unless ($superAuthor) {
		my $mid = $self->getModeratorLogID($cid, $user->{uid});
		if ($mid) {
			$dispArgs->{type} = 'already moderated';
			Slash::slashDisplay('moderation', $dispArgs)
				unless $options->{no_display};
			return 0;
		}
	}

	# Add moderation value to display arguments.
	my $val = $reasons->{$reason}{val};
	my $raw_val = $val;
	$val = "+1" if $val == 1;
	$dispArgs->{val} = $val;

	my $scorecheck = $comment->{points} + $val;
	my $active = 1;
	# If the resulting score is out of comment score range, no further
	# actions need be performed.
	# Should we return here and go no further?
	if (    $scorecheck < $constants->{comment_minscore} ||
		($scorecheck > $constants->{comment_maxscore} && $val + $comment->{tweak} > 0 ))
	{
		# We should still log the attempt for M2, but marked as
		# 'inactive' so we don't mistakenly undo it. Mods get modded
		# even if the action didn't "really" happen.
		#
		$active = 0;
		$dispArgs->{type} = 'score limit';
	}

	# Find out how many mod points this will really cost us.  As of
	# Oct. 2002, it might be more than 1.
	my $pointsneeded = $self->getModPointsNeeded(
		$comment->{points},
		$scorecheck,
		$reason);

	# If more than 1 mod point needed, we might not have enough,
	# so this might still fail.
	if ($pointsneeded > $user->{points} && !$user->{acl}{modpoints_always} && !$superAuthor) {
		return -2;
	}

	# Write the proper records to the moderatorlog.
	$self->createModeratorLog($comment, $user, $val, $reason, $active,
		$pointsneeded);

	if ($active) {

		# If we are here, then the user either has mod points, or
		# is an admin (and 'author_unlimited' is set).  So point
		# checks should be unnecessary here.

		# First, update values for the moderator.
		my $changes = { };
		$changes->{-points} = "GREATEST(points-$pointsneeded, 0)";
		my $tcost = $constants->{mod_unm2able_token_cost} || 0;
		$tcost = 0 if $reasons->{$reason}{m2able};
		$changes->{-tokens} = "tokens - $tcost" if $tcost;
		$changes->{-totalmods} = "totalmods + 1";
		$self->setUser($user->{uid}, $changes);
		$user->{points} -= $pointsneeded;
		$user->{points} = 0 if $user->{points} < 0;

		# Update stats.
		if ($tcost and my $statsSave = getObject('Slash::Stats::Writer')) {
			$statsSave->addStatDaily("mod_tokens_lost_unm2able", $tcost);
		}

		# Apply our changes to the comment.
		my $comment_change_hr =
			$self->setCommentForMod($cid, $val, $reason,
				$comment->{reason});
		if (!defined($comment_change_hr)) {
			# This shouldn't happen;  the only way we believe it
			# could is if $val is 0, the comment is already at
			# min or max score, the user's already modded this
			# comment, or some other reason making this mod invalid.
			# This is really just here as a safety check.
			$dispArgs->{type} = 'logic error';
			Slash::slashDisplay('moderation', $dispArgs)
				unless $options->{no_display};
			return 0;
		}

		# Finally, adjust the appropriate values for the user who
		# posted the comment.
		my $poster_was_anon = isAnon($comment->{uid});
		my $karma_change = $reasons->{$reason}{karma};
		$karma_change = 0 if $poster_was_anon;
		my $token_change = 0;
		if ($karma_change) {
			# If this was a downmod, it may cost the poster
			# something other than exactly 1 karma.
			if ($karma_change < 0) {
				($karma_change, $token_change) =
					$self->_calc_karma_token_loss(
						$karma_change, $comment_change_hr)
			}
		}
		if ($karma_change) {
			my $cu_changes = { };
			if ($val < 0) {
				$cu_changes->{-downmods} = "downmods + 1";
			} elsif ($val > 0) {
				$cu_changes->{-upmods} = "upmods + 1";
			}
			if ($karma_change < 0) {
				$cu_changes->{-karma} = "GREATEST("
					. "$constants->{minkarma}, karma + $karma_change)";
				$cu_changes->{-tokens} = "tokens + $token_change";
			} elsif ($karma_change > 0) {
				$cu_changes->{-karma} = "LEAST("
					. "$constants->{maxkarma}, karma + $karma_change)";
			}

			# Make the changes to the poster user.
			$self->setUser($comment->{uid}, $cu_changes);

			# Update stats.
			if ($karma_change < 0 and my $statsSave = getObject('Slash::Stats::Writer')) {
				$statsSave->addStatDaily("mod_tokens_lost_downmod",
					$token_change);
			}

		}

		# We know things actually changed, so update points for
		# display and send a message if appropriate.
		$dispArgs->{points} = $user->{points};
		$dispArgs->{type} = 'moderated';
		if (($comment->{points} + $comment->{tweak} + $raw_val) >= $constants->{comment_minscore} &&
		    ($comment->{points} + $comment->{tweak}) >= $constants->{comment_minscore}) {

			my $messages = getObject("Slash::Messages");
			$messages->send_mod_msg({
				type    => 'mod_msg',
				sid     => $sid,
				cid     => $cid,
				val     => $val,
				reason  => $reason,
				comment => $comment
			}) unless $options->{no_message};
		}
	}

	# Now display the template with the moderation results.
	Slash::slashDisplay('moderation', $dispArgs)
		unless $options->{no_display};

	return 1;
}

# setCommentForMod returns either undef (if the comment did not change)
# or (if it did) a hashref about the changed comment score.  It's
# currently called only by moderateComment.

sub setCommentForMod {
	my($self, $cid, $val, $newreason, $oldreason) = @_;
	my $raw_val = $val;
	$val += 0;
	return undef if !$val;
	$val = "+$val" if $val > 0;

	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $clear_ctp = 0;

	my $allreasons_hr = $self->sqlSelectAllHashref(
		"reason",
		"reason, COUNT(*) AS c",
		"moderatorlog",
		"cid=$cid AND active=1",
		"GROUP BY reason"
	);
	my $averagereason = $self->getCommentMostCommonReason($cid,
		$allreasons_hr,
		$newreason, $oldreason);

	# Changes we're going to make to this comment.  Note
	# that the pointsmax GREATEST() gets called after
	# points is assigned, thanks to assn_order.
	my $update = {
		-points =>      "points$val",
		-pointsmax =>   "GREATEST(pointsmax, points)",
		reason =>       $averagereason,
		lastmod =>      $user->{uid},
	};

	# If more than n downmods, a comment loses its karma bonus.
	my $reasons = $self->getReasons;
	my $num_downmods = 0;
	for my $reason (keys %$allreasons_hr) {
		$num_downmods += $allreasons_hr->{$reason}{c}
			if $reasons->{$reason}{val} < 0;
	}
	if ($num_downmods > $constants->{mod_karma_bonus_max_downmods}) {
		$update->{karma_bonus} = "no";
		# If we remove a karma_bonus, we must invalidate the
		# comment_text (because the noFollow changes).  Sadly
		# at this point we don't know (due to performance
		# requirements and atomicity) whether we are actually
		# changing the value of this column, but we have to
		# invalidate the cache anyway.
		$clear_ctp = 1;
	}

	# Make sure we apply this change to the right comment :)
	my $where = "cid=$cid ";
	my $points_extra_where = "";
	if ($val < 0) {
		$points_extra_where .= " AND points > $constants->{comment_minscore}";
	} else {
		$points_extra_where .= " AND points < $constants->{comment_maxscore}";
	}
	$where .= " AND lastmod <> $user->{uid}"
		unless $constants->{authors_unlimited}
			&& $user->{seclev} >= $constants->{authors_unlimited};

	# We do a two-query transaction here:  one select to get
	# the old points value, then the update as part of the
	# same transaction;  that way, we know, based on whether
	# the update succeeded, what the final points value is.
	# If this weren't a transaction, another moderation
	# could happen between the two queries and give us the
	# wrong answer.  On the other hand, if the caller didn't
	# want the point change, we don't need to get any of
	# that data.
	# We have to select cid here because LOCK IN SHARE MODE
	# only works when an indexed column is returned.
	# Of course, this isn't actually going to work at all
	# (unless you keep your main DB all-InnoDB and put the
	# MyISAM FULLTEXT indexes onto a slave search-only DB)
	# since the comments table is MyISAM.  Eventually, though,
	# we'll pull the indexed blobs out and into comments_text
	# and make the comments table InnoDB and this will work.
	# Oh well.  Meanwhile, the worst thing that will happen is
	# a few wrong points logged here and there.
	# XXX Hey, comments table is InnoDB now.  That comment
	# above needs to be revised, and it might be time to look
	# over the code too.

#       $self->{_dbh}{AutoCommit} = 0;
	$self->sqlDo("SET AUTOCOMMIT=0");

	my $hr = { };
	($hr->{cid}, $hr->{points_before}, $hr->{points_orig}, $hr->{points_max}, $hr->{karma}) =
		$self->sqlSelect("cid, points, pointsorig, pointsmax, karma",
			"comments", "cid=$cid", "LOCK IN SHARE MODE");
	$hr->{points_change} = $val;
	$hr->{points_after} = $hr->{points_before} + $val;

	my $karma_val;
	my $karma_change = $reasons->{$newreason}{karma};
	if (!$constants->{mod_down_karmacoststyle}) {
		$karma_val = $karma_change;
	} elsif ($val < 0) {
		$karma_val = ($hr->{points_before} + $karma_change) - $hr->{points_max};
	} else {
		$karma_val = $karma_change;
	}

	if ($karma_val < 0
		&& defined($constants->{comment_karma_limit})
		&& $constants->{comment_karma_limit} ne "") {
		my $future_karma = $hr->{karma} + $karma_val;
		if ($future_karma < $constants->{comment_karma_limit}) {
			$karma_val = $constants->{comment_karma_limit} - $hr->{karma};
		}
		$karma_val = 0 if $karma_val > 0; # just to make sure
	}

	if ($karma_val) {
		my $karma_abs_val = abs($karma_val);
		$update->{-karma}     = sprintf("karma%+d", $karma_val);
		$update->{-karma_abs} = sprintf("karma_abs%+d", $karma_abs_val);
	}

	my $changed = $self->sqlUpdate("comments", $update, $where.$points_extra_where, {
		assn_order => [ "-points", "-pointsmax" ]
	});
	$changed += 0;
	if (!$changed && $raw_val > 0) {
		$update->{-points} = "points";
		$update->{-tweak}  = "tweak$val";
		my $tweak_extra = " AND tweak$val <= 0";
		$changed = $self->sqlUpdate("comments", $update, $where.$tweak_extra, {
			assn_order => [ "-points", "-pointsmax" ]
		});
	}
	$changed += 0;
	if (!$changed) {
		# If the row in the comments table didn't change, then
		# the karma_bonus didn't change, so we know there is
		# no need to clear the comment text cache.
		$clear_ctp = 0;
	}

#       $self->{_dbh}->commit;
#       $self->{_dbh}{AutoCommit} = 1;
	$self->sqlDo("COMMIT");
	$self->sqlDo("SET AUTOCOMMIT=1");

	if ($clear_ctp and my $mcd = $self->getMCD()) {
		my $mcdkey = "$self->{_mcd_keyprefix}:ctp:";
		$mcd->delete("$mcdkey$cid", 3);
	}

	return $changed ? $hr : undef;
}

# This gets the mathematical mode, in other words the most common,
# of the moderations done to a comment.  If no mods, return undef.
# If a comment's net moderation is down, choose only one of the
# negative mods, and the opposite for up.  Tiebreakers break ties,
# first tiebreaker found wins.  "cid" is a key in moderatorlog
# so this is not a table scan.  It's currently called only by
# setCommentForMod and undoModeration.
sub getCommentMostCommonReason {
	my($self, $cid, $allreasons_hr, $new_reason, @tiebreaker_reasons) = @_;
	$new_reason = 0 if !$new_reason;
	unshift @tiebreaker_reasons, $new_reason if $new_reason;

	my $reasons = $self->getReasons();
	my $listable_reasons = join(",",
		sort grep { $reasons->{$_}{listable} }
		keys %$reasons);
	return undef if !$listable_reasons;

	# Build the hashref of reason counts for this comment, for all
	# listable reasons.  If allreasoncounts_hr was passed in, this
	# is easy (just grep out the nonlistable ones).  If not, we have
	# to do a DB query.
	my $hr = { };
	if ($allreasons_hr) {
		for my $reason (%$allreasons_hr) {
			$hr->{$reason} = $allreasons_hr->{$reason}
				if $reasons->{$reason}{listable};
		}
	} else {
		$hr = $self->sqlSelectAllHashref(
			"reason",
			"reason, COUNT(*) AS c",
			"moderatorlog",
			"cid=$cid AND active=1
			 AND reason IN ($listable_reasons)",
			"GROUP BY reason"
		);
	}

	# If no mods that are listable, return undef.
	return undef if !keys %$hr;

	# We need to know if the comment has been moderated net up,
	# net down, or to a net tie, and if not a tie, restrict
	# ourselves to choosing only reasons from that direction.
	# Note this isn't atomic with the actual application of, or
	# undoing of, the moderation in question.  Oh well!  If two
	# mods are applied at almost exactly the same time, there's
	# a one in a billion chance the comment will end up with a
	# wrong (but still plausible) reason field.  I'm not going
	# to worry too much about it.
	# Also, I'm doing this here, with a separate for loop to
	# screen out unacceptable reasons, instead of putting this
	# "if" into the same for loop above, because it may save a
	# query (if a comment is modded entirely with Under/Over).
	my($points, $pointsorig) = $self->sqlSelect(
		"points, pointsorig", "comments", "cid=$cid");
	if ($new_reason) {
		# This mod hasn't been taken into account in the
		# DB yet, but it's about to be applied.
		$points += $reasons->{$new_reason}{val};
	}
	my $needval = $points - $pointsorig;
	if ($needval) {
		   if ($needval >  1) { $needval =  1 }
		elsif ($needval < -1) { $needval = -1 }
		my $new_hr = { };
		for my $reason (keys %$hr) {
			$new_hr->{$reason} = $hr->{$reason}
				if $reasons->{$hr->{$reason}{reason}}{val} == $needval;
		}
		$hr = $new_hr;
	}

	# If no mods that are listable, return undef.
	return undef if !keys %$hr;

	# Sort first by popularity and secondarily by reason.
	# "reason" is a numeric field, so we sort $a<=>$b numerically.
	my @sorted_keys = sort {
		$hr->{$a}{c} <=> $hr->{$b}{c}
		||
		$a <=> $b
	} keys %$hr;
	my $top_count = $hr->{$sorted_keys[-1]}{c};
	@sorted_keys = grep { $hr->{$_}{c} == $top_count } @sorted_keys;
	# Now sorted_keys are only the top values, one or more of them,
	# any of which could be the winning reason.
	if (scalar(@sorted_keys) == 1) {
		# A clear winner.  Return it.
		return $sorted_keys[0];
	}
	# No clear winner. Are any of our tiebreakers contenders?
	my %sorted_hash = ( map { $_ => 1 } @sorted_keys );
	for my $reason (@tiebreaker_reasons) {
		# Yes, return the first tiebreaker we find.
		return $reason if $sorted_hash{$reason};
	}
	# Nope, we don't have a good way to resolve the tie. Pick whatever
	# comes first in the reason list (reasons are all numeric and
	# sorted_keys is already sorted, making this easy).
	return $sorted_keys[0];
}

##################################################################

=head2 dispModCommentLog(TYPE, ID)

Returns the HTML for a table detailing the history of moderation of a
particular comment and/or the reasons why a comment is scored like it is.
The "mod" in this method's title is intended to reflect that the info
it returns includes both moderations and comment-score-modifiers.

=over 4

=item Parameters

=over 4

=item TYPE

String describing type of the ID data:  cid, uid, cuid, ipid, subnetid,
bipid or bsubnetid.

=item ID

Cid or IPID.

=back

=item Return value

The HTML.

=item Dependencies

The 'modCommentLog' template.

=back

=cut

sub dispModCommentLog {
	my($self, $type, $value, $options) = @_;
	$options ||= {};
	my $title = $options->{title};
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	# If the user doesn't want even to see the numeric score of
	# a comment, they certainly don't want to see all this detail.
	return "" if $user->{noscores};

	my $seclev = $user->{seclev};
	my $mod_admin = $seclev >= $constants->{modviewseclev} ? 1 : 0;

	my $asc_desc = $type eq 'cid' ? 'ASC' : 'DESC';
	my $limit = $type eq 'cid' ? 0 : 100;
	my $both_mods = (($type =~ /ipid/) || ($type =~ /subnetid/) || ($type =~ /global/)) ? 1 : 0;
	my $skip_ip_disp = 0;
	if ($type =~ /^b(ip|subnet)id$/) {
		$skip_ip_disp = 1;
	} elsif ($type =~ /^(ip|subnet)id$/) {
		$skip_ip_disp = 2;
	}
	my $gmcl_opts = {};
	$gmcl_opts->{hours_back} = $options->{hours_back} if $options->{hours_back};
	$gmcl_opts->{order_col} = "reason" if $type eq "cid";

	my $mods = $self->getModeratorCommentLog($asc_desc, $limit,
		$type, $value, $gmcl_opts);

	my $timestamp_hr = exists $options->{hr_hours_back}
		? $self->getTime({ add_secs => -3600 * $options->{hr_hours_back} })
		: "";

	if (!$mod_admin) {
		# Eliminate inactive moderations from the list.
		$mods = [ grep { $_->{active} } @$mods ];
	}

	my($reasons, @return, @reasonHist);
	my $reasonTotal = 0;
	$reasons = $self->getReasons();

	# Note: Before 2001/01/27 or so, the only things being displayed
	# in this template were moderations, and if there were none,
	# we could short-circuit here if @$mods was empty.  But now,
	# the template handles that decision.
	my $seen_mods = {};
	for my $mod (@$mods) {
		$seen_mods->{$mod->{id}}++;
		vislenify($mod); # add $mod->{ipid_vis}
		#$mod->{ts} = substr($mod->{ts}, 5, -3);
	       $mod->{nickname2} = $self->getUser($mod->{uid2},
			'nickname') if $both_mods; # need to get 2nd nick
		next unless $mod->{active};
		$reasonHist[$mod->{reason}]++;
		$reasonTotal++;
	}

	my $listed_reason = 0;
	if ($type eq 'cid') {
		my $val_q = $self->sqlQuote($value);
		$listed_reason = $self->sqlSelect("reason", "comments", "cid=$val_q");
	}
	my @reasonsTop = $self->getTopModReasons($reasonTotal, $listed_reason, \@reasonHist);

	my $show_cid    = ($type eq 'cid') ? 0 : 1;
	my $show_modder = $mod_admin ? 1 : 0;
	my $mod_to_from = ($type eq 'uid') ? 'to' : 'from';

	my $modifier_hr = { };
	my $reason = 0;
	if ($type eq 'cid') {
		my $cid_q = $self->sqlQuote($value);
		my($min, $max) = ($constants->{comment_minscore},
				  $constants->{comment_maxscore});
		# XXXMULTIPLEMASTERS
		my $max_uid = $self->countUsers({ max => 1 });

		my $select = "cid, uid, karma_bonus, reason, points, pointsorig, tweak, tweak_orig";
		if ($constants->{plugin}{Subscribe} && $constants->{subscribe}) {
			$select .= ", subscriber_bonus";
		}
		my $comment = $self->sqlSelectHashref(
			$select,
			"comments",
			"cid=$cid_q");
		$comment->{comment} = $self->sqlSelect(
			"comment",
			"comment_text",
			"cid=$cid_q");
		$reason = $comment->{reason};

		my $user = getCurrentUser();
		my $points;
		($points, $modifier_hr) = getPoints($comment, $user, $min, $max, $max_uid, $reasons);
	}

	my $this_user;
	$this_user = $self->getUser($value) if $type eq "uid";
	my $cur_uid;
	$cur_uid = $value if $type eq "uid" || $type eq "cuid";

	my $mods_to_m2s;
	if ($constants->{m2}) {
		my $mod_ids = [keys %$seen_mods];
		if ($constants->{show_m2s_with_mods} && $options->{show_m2s}) {
			my $metamod_db = getObject('Slash::Metamod');
			$mods_to_m2s = $metamod_db->getMetamodsForMods($mod_ids, $constants->{m2_limit_with_mods});
		}
	}

	# Do the work to determine which moderations share the same m2s
	if (       $constants->{m2}
		&& $type eq 'cid'
		&& $constants->{show_m2s_with_mods}
		&& $constants->{m2_multicount}
		&& $options->{show_m2s}
	){
		foreach my $m (@$mods){
			my $key = '';
			foreach my $m2 (@{$mods_to_m2s->{$m->{id}}}) {
				$key .= "$m2->{uid} $m2->{val},";
			}
			$m->{m2_identity} = $key;
		}
		@$mods = sort {
			$a->{reason} <=> $b->{reason}
				||
			$b->{active} <=> $a->{active}
				||
			$a->{m2_identity} cmp $b->{m2_identity}
		} @$mods;
	}
	my $data = {
		type            => $type,
		mod_admin       => $mod_admin,
		mods            => $mods,
		reasonTotal     => $reasonTotal,
		reasonHist      => \@reasonHist,
		reasonsTop      => \@reasonsTop,
		reasons         => $reasons,
		reason          => $reason,
		modifier_hr     => $modifier_hr,
		show_cid        => $show_cid,
		show_modder     => $show_modder,
		mod_to_from     => $mod_to_from,
		both_mods       => $both_mods,
		timestamp_hr    => $timestamp_hr,
		skip_ip_disp    => $skip_ip_disp,
		this_user       => $this_user,
		title           => $title,
		cur_uid         => $cur_uid,
		value           => $value,
	};
	if ($constants->{m2}) {
		$data->{mods_to_m2s} = $mods_to_m2s;
		$data->{show_m2s} = $options->{show_m2s};
		$data->{need_m2_form} = $options->{need_m2_form};
		$data->{need_m2_button} = $options->{need_m2_button};
		$data->{meta_mod_only} = $options->{meta_mod_only};
	}
	return slashDisplay('modCommentLog', $data,
		{ Return => 1, Nocomm => 1 });
}

# This method is currently used only by dispModCommentLog.
#
# Takes a reason histogram, a list of counts of each reason mod.
# So $reasonHist[1] is the number of Offtopic moderations (at
# least if Offtopic is still reason 1).  Returns a list of hashrefs,
# the top 3 mods performed and their percentages, rounded to the
# nearest 10%, sorted largest to smallest.

sub getTopModReasons{
	my($self, $reasonTotal, $listed_reason, $reasonHist_ar) = @_;
	return ( ) unless $reasonTotal;
	my $top_needed = 3;
	my @reasonsTop = ( );

	# Algorithm by MJD in Perl Quiz of the Week #7
	# http://perl.plover.com/qotw/r/solution/007
	my @p = map { $_*10/$reasonTotal } @$reasonHist_ar;
	my @r = map { int($_+0.5) } @p;
	my @e = map { $p[$_] - $r[$_] } (0..$#r);
	my $total_error = 0;
	for (@e) { $total_error += $_ }
	# Round total_error to int, to avoid float rounding error
	my $sign = $total_error < 0 ? -1 : 1;
	$total_error *= $sign;
	$total_error = int($total_error+0.5);
	if ($total_error) {
		for (0..$#r) {
			next unless $e[$_] * $sign > 0;
			$r[$_] += $sign;
			$total_error--;
			last if $total_error <= 0;
		}
	}

	# This part I added, so if it breaks, don't blame MJD :) JRM
	my %reasonRound = map { ($_, $r[$_]*10) } (0..$#r);
	my @rr_keys = sort { $a <=> $b } keys %reasonRound;
	my $min = (sort { $b <=> $a } values %reasonRound)[$top_needed-1];
	for my $key (0..$#r) {
		$reasonRound{$key} = 0 if $reasonRound{$key} < $min;
	}
	my $have = 0;
	for my $key (0..$#r) {
		++$have if $reasonRound{$key} > $min;
	}
	for my $key (0..$#r) {
		if ($reasonRound{$key} == $min) {
			if ($have >= $top_needed) {
				$reasonRound{$key} = 0;
			} else {
				++$have;
			}
		}
	}
	for my $reason (1..$#r) {
		next unless $reasonRound{$reason};
		push @reasonsTop, {
			reason => $reason,
			percent => $reasonRound{$reason},
		};
	}
	@reasonsTop = sort {
		($b->{reason} == $listed_reason) <=> ($a->{reason} == $listed_reason)
		||
		$b->{percent} <=> $a->{percent}
		||
		$a->{reason} <=> $b->{reason}
	} @reasonsTop;

	return @reasonsTop;
}

sub moderateCheck {
	my($self, $form, $user, $constants, $discussion) = @_;

	# all of these can be removed in favor of reskeys, later
	if (!dbAvailable('write_comments')) {
		return { msg => Slash::Utility::Comments::getError('comment_db_down') };
	}

	if (!$constants->{m1}) {
		return { msg => Slash::Utility::Comments::getError('no_moderation') };
	}

	if ($discussion->{type} eq 'archived' &&
	   !$constants->{comments_moddable_archived} &&
	   !$form->{meta_mod_only}) {
		return { msg => Slash::Utility::Comments::getError('archive_error') };
	}

	my $return = {};
	$return->{count} = $self->countCommentsBySidUID($form->{sid}, $user->{uid})
		unless (   $constants->{authors_unlimited}
			&& $user->{seclev} >= $constants->{authors_unlimited}
		)       || $user->{acl}{modpoints_always};
	if ($return->{count}) {
		$return->{msg} = Slash::Utility::Comments::getError('already posted');
	}

	return $return;
}

sub checkDiscussionForUndoModeration {
	my($self, $sid) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	# We abandon this operation, thus allowing mods to remain while
	# the post goes forward, if:
	#       1) Moderation is off
	#       2) The user is anonymous (posting anon is the only way
	#          to contribute to a discussion after you moderate)
	#       3) The user has the "always modpoints" ACL
	#       4) The user has a sufficient seclev
	return if !$constants->{m1}
		|| $user->{is_anon}
		|| $user->{acl}{modpoints_always}
		|| $constants->{authors_unlimited} && $user->{seclev} >= $constants->{authors_unlimited};

	if ($sid !~ /^\d+$/) {
		$sid = $self->getDiscussionBySid($sid, 'header');
	}
	my $removed = $self->undoModeration($user->{uid}, $sid);

	if ($removed && @$removed) {
		my $messages = getObject('Slash::Messages');
		if ($messages) {
			for my $mod (@$removed) {
				$mod->{val} =~ s/^(\d)/+$1/;  # put "+" in front if necessary
				$messages->send_mod_msg({
					type    => 'unmod_msg',
					sid     => $sid,
					cid     => $mod->{cid},
					val     => $mod->{val},
					reason  => $mod->{reason}
				});
			}
		}
	}

	my $removed_text = slashDisplay('undo_mod', { removed => $removed }, { Return => 1, Page => 'comments' });
	return $removed_text;
}

sub undoModeration {
	my($self, $uid, $sid) = @_;
	my $constants = getCurrentStatic();

	return [] unless dbAvailable("write_comments");

	# querylog isn't going to work for this sqlSelectMany, since
	# we do multiple other queries while the cursor runs over the
	# rows it returns.  So don't bother doing the _querylog_start.

	# sid here really refers to discussions.id, NOT stories.sid
	my $cursor = $self->sqlSelectMany("cid,val,active,cuid,reason",
		"moderatorlog",
		"moderatorlog.uid=$uid AND moderatorlog.sid=$sid"
	);

	my $min_score = $constants->{comment_minscore};
	my $max_score = $constants->{comment_maxscore};
	my $min_karma = $constants->{minkarma};
	my $max_karma = $constants->{maxkarma};

	my @removed;
	while (my($cid, $val, $active, $cuid, $reason) = $cursor->fetchrow){

		# If moderation wasn't actually performed, we skip ahead one.
		next if ! $active;

		# We undo moderation even for inactive records (but silently for
		# inactive ones...).  Leave them in the table but inactive, so
		# they are still eligible to be metamodded.
		$self->sqlUpdate("moderatorlog",
			{ active => 0 },
			"cid=$cid AND uid=$uid"
		);

		# Remove any tags on that comment by this user, as well.
		$self->removeModTags($uid, $cid);

		# Restore modded user's karma, again within the proper boundaries.
		my $adjust = -$val;
		$adjust =~ s/^([^+-])/+$1/;
		my $adjust_abs = abs($adjust);
		$self->sqlUpdate(
			"users_info",
			{ -karma =>	$adjust > 0
					? "LEAST($max_karma, karma $adjust)"
					: "GREATEST($min_karma, karma $adjust)" },
			"uid=$cuid"
		) unless isAnon($cuid);

		# Adjust the comment score up or down, but don't push it
		# beyond the maximum or minimum.  Also recalculate its reason.
		# Its pointsmax logically can't change.
		my $points = $adjust > 0
			? "LEAST($max_score, points $adjust)"
			: "GREATEST($min_score, points $adjust)";
		my $new_reason = $self->getCommentMostCommonReason($cid)
			|| 0; # no active moderations? reset reason to empty
		my $comm_update = {
			-points =>      $points,
			reason =>       $new_reason,
		};
		$self->sqlUpdate("comments", $comm_update, "cid=$cid");

		push @removed, {
			cid     => $cid,
			reason  => $reason,
			val     => $val,
		};
	}

	return \@removed;
}

sub getModeratorLogID {
	my($self, $cid, $uid) = @_;
	my($mid) = $self->sqlSelect("id", "moderatorlog",
		"uid=$uid AND cid=$cid");
	return $mid;
}

sub getMaxModeratorlogId {
	my($self) = @_;
	return $self->sqlSelect("MAX(id)", "moderatorlog");
}

sub getModeratorLog {
	my $answer = Slash::DB::MySQL::_genericGet({
		table           => 'moderatorlog',
		arguments       => \@_,
	});
	return $answer;
}

sub countUserModsInDiscussion {
	my($self, $uid, $disc_id) = @_;
	my $uid_q = $self->sqlQuote($uid);
	my $disc_id_q = $self->sqlQuote($disc_id);
	return $self->sqlCount(
		"moderatorlog",
		"uid=$uid_q AND active=1 AND sid=$disc_id_q");
}

sub getModeratorCommentLog {
	my($self, $asc_desc, $limit, $t, $value, $options) = @_;
	my $constants = getCurrentStatic();
	# $t tells us what type of data $value is, and what type of
	# information we're looking to retrieve
	$options ||= {};
	$asc_desc ||= 'ASC';        $asc_desc = uc $asc_desc;
	$asc_desc = 'ASC' if $asc_desc ne 'DESC';
	my $order_col = $options->{order_col} || "ts";

	if ($limit and $limit =~ /^(\d+)$/) {
		$limit = "LIMIT $1";
	} else {
		$limit = "";
	}

	my $cidlist;
	if ($t eq "cidin") {
		if (ref $value eq "ARRAY" and @$value) {
			$cidlist = join(',', @$value);
		} elsif (!ref $value and $value) {
			$cidlist = $value;
		} else {
			return [];
		}
	}

	my $select_extra = (($t =~ /ipid/) || ($t =~ /subnetid/) || ($t =~ /global/))
		? ", comments.uid AS uid2, comments.ipid AS ipid2"
		: "";
	if ($constants->{m2}) {
		$select_extra .= ', moderatorlog.m2status AS m2status';
	}

	my $vq = $self->sqlQuote($value);
	my $where_clause = "";
	my $ipid_table = "moderatorlog";
	   if ($t eq 'uid')       { $where_clause = "comments.uid=users.uid AND     moderatorlog.uid=$vq";
				    $ipid_table = "comments"                                                        }
	elsif ($t eq 'cid')       { $where_clause = "moderatorlog.uid=users.uid AND moderatorlog.cid=$vq"           }
	elsif ($t eq 'cuid')      { $where_clause = "moderatorlog.uid=users.uid AND moderatorlog.cuid=$vq"          }
	elsif ($t eq 'cidin')     { $where_clause = "moderatorlog.uid=users.uid AND moderatorlog.cid IN ($cidlist)" }
	elsif ($t eq 'subnetid')  { $where_clause = "moderatorlog.uid=users.uid AND comments.subnetid=$vq"          }
	elsif ($t eq 'ipid')      { $where_clause = "moderatorlog.uid=users.uid AND comments.ipid=$vq"              }
	elsif ($t eq 'bsubnetid') { $where_clause = "moderatorlog.uid=users.uid AND moderatorlog.subnetid=$vq"      }
	elsif ($t eq 'bipid')     { $where_clause = "moderatorlog.uid=users.uid AND moderatorlog.ipid=$vq"          }
	elsif ($t eq 'global')    { $where_clause = "moderatorlog.uid=users.uid"                                    }
	return [ ] unless $where_clause;

	my $time_clause = "";
	$time_clause = " AND ts > DATE_SUB(NOW(), INTERVAL $options->{hours_back} HOUR)" if $options->{hours_back};

	my $qlid = $self->_querylog_start("SELECT", "moderatorlog, users, comments");
	my $sth = $self->sqlSelectMany(
		"comments.sid AS sid,
		 comments.cid AS cid,
		 comments.pid AS pid,
		 comments.points AS score,
		 comments.karma AS karma,
		 comments.tweak AS tweak,
		 comments.tweak_orig AS tweak_orig,
		 users.uid AS uid,
		 users.nickname AS nickname,
		 $ipid_table.ipid AS ipid,
		 moderatorlog.val AS val,
		 moderatorlog.reason AS reason,
		 moderatorlog.ts AS ts,
		 moderatorlog.active AS active,
		 moderatorlog.id AS id,
		 moderatorlog.points_orig AS points_orig
		 $select_extra",
		"moderatorlog, users, comments",
		"$where_clause
		 AND moderatorlog.cid=comments.cid
		 $time_clause",
		"ORDER BY $order_col $asc_desc $limit"
	);
	my(@comments, $comment, @ml_ids);
	# XXX can simplify this now, don't need to do fetchrow_hashref, can use utility method
	while ($comment = $sth->fetchrow_hashref) {
		push @comments, $comment;
	}
	$self->_querylog_finish($qlid);
	if ($constants->{m2}) {
		my $metamod_db = getObject('Slash::Metamod');
		$metamod_db->addFairUnfairCounts(\@comments, 'id');
	}
	return \@comments;
}

# At the time of creating a moderation, the caller can influence
# whether this moderation needs more or fewer M2 votes to reach
# consensus.  Passing in 0 for the 'm2needed' option means to use
# the default.  Passing in a positive or negative value means to
# add that to the default.  Fractional values are fine; the result
# will always be rounded to an odd number.
sub createModeratorLog {
	my($self, $comment, $user, $val, $reason, $active, $points_spent,
		$options) = @_;
	my $constants = getCurrentStatic();
	$active = 1 unless defined $active;
	$points_spent = 1 unless defined $points_spent;
	my $uid = $user->{uid};
	my $cid = $comment->{cid};

	my $metamod_db;
	$metamod_db = getObject('Slash::Metamod') if $constants->{m2};

	my $mod_hr = {
		uid     => $uid,
		ipid    => $user->{ipid} || '',
		subnetid => $user->{subnetid} || '',
		val     => $val,
		sid     => $comment->{sid},
		cid     => $cid,
		cuid    => $comment->{uid},
		reason  => $reason,
		-ts     => 'NOW()',
		active  => $active,
		spent   => $points_spent,
		points_orig => $comment->{points},
	};
	if ($active && $constants->{m2}) {
		$mod_hr->{m2needed} = $metamod_db->getM2Needed($uid, $cid, $reason,
			$options->{m2needed} || 0);
	}

	my $ret_val = $self->sqlInsert('moderatorlog', $mod_hr);
	if ($constants->{m2}) {
		my $mod_id = $self->getLastInsertId();
		$metamod_db->adjustForNewMod($uid, $cid, $reason, $active, $mod_id);
	}

	$self->createModTag($uid, $cid, $reason);

	return $ret_val;
}

sub deleteModeratorlog {
	my($self, $opts) = @_;
	my $where;

	if ($opts->{cid}) {
		$where = 'cid=' . $self->sqlQuote($opts->{cid});
	} elsif ($opts->{sid}) {
		$where = 'sid=' . $self->sqlQuote($opts->{sid});
	} else {
		return;
	}

	my $mmids = $self->sqlSelectColArrayref(
		'id', 'moderatorlog', $where
	);
	return unless @$mmids;

	my $mmid_in = join ',', @$mmids;
	# Delete from metamodlog first since (if built correctly) that
	# table has a FOREIGN KEY constraint pointing to moderatorlog.
	my $plugins = getCurrentStatic('plugin');
	if ($plugins->{Metamod}) {
		$self->sqlDelete('metamodlog', "mmid IN ($mmid_in)");
	}
	$self->sqlDelete('moderatorlog', $where);
}

########################################################

# these are technically static-only

sub getModderCommenterIPIDSummary {
	my ($self, $options) = @_;
	my $ac_uid = getCurrentStatic('anonymous_coward_uid');
	$options ||= {};

	my @where = ( "moderatorlog.cid=comments.cid" );
	push @where, "ts > date_sub(NOW(),INTERVAL $options->{days_back} DAY)" if $options->{days_back};
	push @where, "cuid != $ac_uid" if $options->{no_anon_comments};
	push @where, "cuid = $ac_uid" if $options->{only_anon_comments};
	push @where, "id >= $options->{start_at_id}" if $options->{start_at_id};
	push @where, "id <= $options->{end_at_id}" if $options->{end_at_id};
	push @where, "comments.ipid IS NOT NULL AND comments.ipid!=''" if $options->{need_ipid};

	my $where = join(" AND ", @where);

	my $mods = $self->sqlSelectAllHashref(
			[qw(uid ipid)],
			"moderatorlog.uid AS uid, comments.ipid AS ipid, COUNT(*) AS count",
			"moderatorlog, comments",
			$where,
			"GROUP BY uid, comments.ipid");

	return $mods;
}

sub getModderModdeeSummary {
	my ($self, $options) = @_;
	my $ac_uid = getCurrentStatic('anonymous_coward_uid');
	$options ||= {};

	my @where = ( );
	push @where, "ts > DATE_SUB(NOW(), INTERVAL $options->{days_back} DAY)" if $options->{days_back};
	push @where, "cuid != $ac_uid" if $options->{no_anon_comments};
	push @where, "id >= $options->{start_at_id}" if $options->{start_at_id};
	push @where, "id <= $options->{end_at_id}" if $options->{end_at_id};
	push @where, "ipid IS NOT NULL AND ipid != ''" if $options->{need_ipid};

	my $where = join(" AND ", @where);

	my $mods = $self->sqlSelectAllHashref(
			[qw(uid cuid)],
			"uid, cuid, COUNT(*) AS count",
			"moderatorlog",
			$where,
			"GROUP BY uid, cuid");

	return $mods;
}

########################################################
# For process_moderatord.pl
# Pass in option "sleep_between" of a few seconds, maybe up to a
# minute, if for some reason the deletion still makes slave
# replication lag... (but it shouldn't, anymore) - 2005/01/06
sub deleteOldModRows {
	my($self, $options) = @_;

	my $reader = getObject('Slash::DB', { db_type => "reader" });
	my $constants = getCurrentStatic();
	my $max_rows = $constants->{mod_delete_maxrows} || 1000;
	my $archive_delay_mod =
		   $constants->{archive_delay_mod}
		|| $constants->{archive_delay}
		|| 14;
	my $sleep_between = $options->{sleep_between} || 0;

	# Find the minimum ID in these tables that should remain, then
	# delete everything before it.  We do it this way to keep the
	# slave DBs tied up on the replication of the deletion query as
	# little as possible.  Turning off foreign key checking here is
	# just pretty lame, I know...

	$self->sqlDo("SET FOREIGN_KEY_CHECKS=0");

	# First delete from the bottom up for the moderatorlog.

	my $junk_bottom = $reader->sqlSelect('MIN(id)', 'moderatorlog');
	my $need_bottom = $reader->sqlSelectNumericKeyAssumingMonotonic(
		'moderatorlog', 'min', 'id',
		"ts >= DATE_SUB(NOW(), INTERVAL $archive_delay_mod DAY)");
	while ($need_bottom && $junk_bottom < $need_bottom) {
		$junk_bottom += $max_rows;
		$junk_bottom = $need_bottom if $need_bottom < $junk_bottom;
		$self->sqlDelete('moderatorlog', "id < $junk_bottom");
		sleep $sleep_between
			if $sleep_between;
	}

	$self->sqlDo("SET FOREIGN_KEY_CHECKS=1");
	return 0;
}

########################################################
# For process_moderatord.pl
# Slightly new logic.  Now users can accumulate tokens beyond the
# "trade-in" limit and the token_retention var is obviated.
# Any user with more than $tokentrade tokens is forced to cash
# them in for points, but they get to keep any excess tokens.
# And on 2002/10/23, even newer logic:  the number of desired
# conversions is passed in and the top that-many token holders
# get points.
sub convert_tokens_to_points {
	my($self, $n_wanted) = @_;

	my $reader = getObject("Slash::DB", { db_type => 'reader' });

	my $constants = getCurrentStatic();
	my %granted = ( );

	return unless $n_wanted;

	# Sanity check.
	my $n_users = $reader->countUsers();
	$n_wanted = int($n_users/10) if $n_wanted > int($n_users)/10;

	my $maxtokens = $constants->{maxtokens} || 60;
	my $tokperpt = $constants->{tokensperpoint} || 8;
	my $maxpoints = $constants->{maxpoints} || 5;
	my $pointtrade = $maxpoints;
	my $tokentrade = $pointtrade * $tokperpt;
	$tokentrade = $maxtokens if $tokentrade > $maxtokens; # sanity check
	my $half_tokentrade = int($tokentrade/2); # another sanity check

	my $uids = $reader->sqlSelectColArrayref(
		"uid",
		"users_info",
		"tokens >= $half_tokentrade",
		"ORDER BY tokens DESC, RAND() LIMIT $n_wanted",
	);

	# Locking tables is no longer required since we're doing the
	# update all at once on just one table and since we're using
	# + and - instead of using absolute values. - Jamie 2002/08/08

	$self->setModPoints($uids, \%granted, {
		pointtrade => $pointtrade,
		maxpoints  => $maxpoints,
		tokentrade => $tokentrade
	});


	# We used to do some fancy footwork with a cursor and locking
	# tables.  The only difference between that code and this is that
	# it only limited points to maxpoints for users with karma >= 0
	# and seclev < 100.  These aren't meaningful limitations, so these
	# updates should work as well.  - Jamie 2002/08/08
	# Actually I don't think these are needed at all. - Jamie 2003/09/09
	#
	# 2006/02/09:  I still don't think they're needed, and they are
	# causing lags in replication...
	#   Searching rows for update:
	#   The thread is doing a first phase to find all matching
	#   rows before updating them. This has to be done if the UPDATE
	#   is changing the index that is used to find the involved rows.
	# ...so I'm removing these.  I believe wherever the existing code
	# increases points or tokens, it updates the oldvalue to
	# LEAST(newvalue, maxvalue), so these adjustments should never
	# change anything.
	# 2006/02/12:  The lag is due to a MySQL bug in 4.1.16 that is
	# fixed in 4.1.18.  <http://bugs.mysql.com/bug.php?id=15935>
	# Still, we shouldn't need these.
#       $self->sqlUpdate(
#               "users_comments",
#               { points => $maxpoints },
#               "points > $maxpoints"
#       );
#       $self->sqlUpdate(
#               "users_info",
#               { tokens => $maxtokens },
#               "tokens > $maxtokens"
#       );

	return \%granted;
}

########################################################
# For process_moderatord
sub stirPool {
	my($self) = @_;

	# Old var "stir" still works, its value is in days.
	# But "mod_stir_hours" is preferred.
	my $constants = getCurrentStatic();
	my $stir_hours = $constants->{mod_stir_hours}
		|| $constants->{stir} * 24
		|| 96;
	my $tokens_per_pt = $constants->{mod_stir_token_cost} || 0;
	
	# This isn't atomic.  But it doesn't need to be.  We could lock the
	# tables during this operation, but all that happens if we don't
	# is that a user might use up a mod point that we were about to stir,
	# and it gets counted twice, later, in stats.  No big whup.
	
	my $stir_ar = $self->sqlSelectAllHashrefArray(
		"users_info.uid AS uid, points",
		"users_info, users_comments",
		"users_info.uid = users_comments.uid
		 AND points > 0
		 AND DATE_SUB(NOW(), INTERVAL $stir_hours HOUR) > lastgranted"
	);
	
	my $n_stirred = 0;
	for my $user_hr (@$stir_ar) {
		my $uid = $user_hr->{uid}; 
		my $pts = $user_hr->{points};
		my $tokens_pt_chg = $tokens_per_pt * $pts;

		my $change = { };
		$change->{points} = 0; 
		$change->{-lastgranted} = "NOW()";
		$change->{-stirred} = "stirred + $pts";
		# In taking tokens away, this subtraction itself will not
		# cause the value to go negative.
		$change->{-tokens} = "LEAST(tokens, GREATEST(tokens - $tokens_pt_chg, 0))"
			if $tokens_pt_chg;
		$self->setUser($uid, $change);

		$n_stirred += $pts;
	}

	return $n_stirred;
} 

########################################################
# For process_moderatord.pl
# 
# New as of 2002/09/05:  returns ordered first by hitcount, and
# second randomly, so when give_out_tokens() chops off the list
# halfway through the minimum number of clicks, the survivors
# are determined at random and not by (probably) uid order.
# 
# New as of 2002/09/11:  limit look-back distance to 48 hours,
# to make the effects of click-grouping more predictable, and
# not being erased all at once with accesslog expiration.
# 
# New as of 2003/01/30:  fetchEligibleModerators() has been
# split into fetchEligibleModerators_accesslog and
# fetchEligibleModerators_users.  The first pulls down the data
# we need from accesslog, which may be a different DBIx virtual
# user (different database).  The second uses that data to pull
# down the rest of the data we need from the users tables.
# Also, the var mod_elig_hoursback is no longer needed.
# Note that fetchEligibleModerators_accesslog can return a
# *very* large hashref.
# 
# New as of 2004/02/04:  fetchEligibleModerators_accesslog has
# been split into ~_insertnew, ~_deleteold, and ~_read.  They
# all are methods for the logslavedb, which may or may not be
# the same as the main slashdb.

sub fetchEligibleModerators_accesslog_insertnew {
	my($self, $lastmaxid, $newmaxid, $youngest_uid) = @_;
	return if $lastmaxid > $newmaxid;
	my $ac_uid = getCurrentStatic('anonymous_coward_uid');
	$self->sqlDo("INSERT INTO accesslog_artcom (uid, ts, c)"
		. " SELECT uid, FROM_UNIXTIME(FLOOR(AVG(UNIX_TIMESTAMP(ts)))) AS ts, COUNT(*) AS c"
		. " FROM accesslog"
		. " WHERE id BETWEEN $lastmaxid AND $newmaxid"
			. " AND (op='article' OR op='comments')"
		. " AND uid != $ac_uid AND uid <= $youngest_uid"
		. " GROUP BY uid");
}

sub fetchEligibleModerators_accesslog_deleteold {
	my($self) = @_; 
	my $constants = getCurrentStatic();
	my $hoursback = $constants->{accesslog_hoursback} || 60;
	$self->sqlDelete("accesslog_artcom",
		"ts < DATE_SUB(NOW(), INTERVAL $hoursback HOUR)");
}

sub fetchEligibleModerators_accesslog_read {
	my($self) = @_; 
	my $constants = getCurrentStatic();
	my $hitcount = defined($constants->{m1_eligible_hitcount})
		? $constants->{m1_eligible_hitcount} : 3;
	return $self->sqlSelectAllHashref(
		"uid",
		"uid, SUM(c) AS c",
		"accesslog_artcom",
		"",
		"GROUP BY uid HAVING c >= $hitcount");
}

# This is a method for the main slashdb, which may or may not be
# the same as the logslavedb.

sub fetchEligibleModerators_users {
	my($self, $count_hr) = @_;
	my $constants = getCurrentStatic();
	my $youngest_uid = $self->getYoungestEligibleModerator();
	my $minkarma = $constants->{mod_elig_minkarma} || 0;
	
	my @uids =
		sort { $a <=> $b } # don't know if this helps MySQL but it can't hurt... much
		grep { $_ <= $youngest_uid }
		keys %$count_hr;
	my @uids_start = @uids;
	
	# What is a good splice_count?  Well I was seeing entries show
	# up in the *.slow log for a size of 5000, so smaller is good.
	my $splice_count = 2000;
	while (@uids) {
		my @uid_chunk = splice @uids, 0, $splice_count;
		my $uid_list = join(",", @uid_chunk);
		my $uids_disallowed = $self->sqlSelectColArrayref(
			"users_info.uid AS uid",
			"users_info, users_prefs",
			"(karma < $minkarma OR willing != 1)
			 AND users_info.uid = users_prefs.uid
			 AND users_info.uid IN ($uid_list)"
		);
		for my $uid (@$uids_disallowed) {
			delete $count_hr->{$uid};
		}
		# If there is more to do, sleep for a moment so we don't
		# hit the DB too hard.
		sleep 1 if @uids;
	}

	my $return_ar = [
		map { [ $count_hr->{$_}{uid}, $count_hr->{$_}{c} ] }
		sort { $count_hr->{$a}{c} <=> $count_hr->{$b}{c}
			|| int(rand(3))-1 }
		grep { defined $count_hr->{$_} }
		@uids_start
	];
	return $return_ar;
}

########################################################
# For process_moderatord.pl
# Quick overview:  This method takes a list of uids who are eligible
# to be moderators and returns that same list, with the "worst"
# users made statistically less likely to be on it, and the "best"
# users more likely to remain on the list and appear more than once.
# Longer explanation:
# This method takes a list of uids who are eligible to be moderators
# (i.e., eligible to receive tokens which may end up giving them mod
# points).  It also takes several numeric values, positive numbers
# that are almost certainly slightly greater than 1 (e.g. 1.3 or so).
# For each uid, several values are calculated:  the total number of
# times the user has been M2'd "fair," the ratio of fair-to-unfair M2s,
# and the ratio of spent-to-stirred modpoints.  Multiple lists of
# the uids are made, from "worst" to "best," the "worst" user in each
# case having the probability of being eligible for tokens (remaining
# on the list) reduced and the "best" with that probability increased
# (appearing two or more times on the list).
# The list of which factors to use and the numeric values of those
# factors is in $wtf_hr ("what to factor");  its currently-defined
# keys are factor_ratio, factor_total and factor_stirred.
sub factorEligibleModerators {
	my($self, $orig_uids, $wtf, $info_hr) = @_;
	return $orig_uids if !$orig_uids || !@$orig_uids || scalar(@$orig_uids) < 10;
	
	$wtf->{upfairratio} ||= 0;      $wtf->{upfairratio} = 0         if $wtf->{upfairratio} == 1;
	$wtf->{downfairratio} ||= 0;    $wtf->{downfairratio} = 0       if $wtf->{downfairratio} == 1;
	$wtf->{fairtotal} ||= 0;        $wtf->{fairtotal} = 0           if $wtf->{fairtotal} == 1;
	$wtf->{stirratio} ||= 0;        $wtf->{stirratio} = 0           if $wtf->{stirratio} == 1;
	
	return $orig_uids if !$wtf->{fairratio} || !$wtf->{fairtotal} || !$wtf->{stirratio};
	
	my $start_time = Time::HiRes::time;
	
	my @return_uids = ( );
	
	my $uids_in = join(",", @$orig_uids);
	my $u_hr = $self->sqlSelectAllHashref(
		"uid",
		"uid, up_fair, down_fair, up_unfair, down_unfair, totalmods, stirred",
		"users_info",
		"uid IN ($uids_in)",
	);
	
	# Assign ratio values that will be used in the sorts in a moment.
	# We precalculate these because they're used in several places.
	# Note that we only calculate the *ratio* if there are a decent
	# number of votes, otherwise we leave it undef.
	for my $uid (keys %$u_hr) {
		# Upmod fairness ratio.
		my $ratio = undef;
		my $denom = $u_hr->{$uid}{up_fair} + $u_hr->{$uid}{up_unfair};
		if ($denom >= 5) {
			$ratio = $u_hr->{$uid}{up_fair} / $denom;
		}
		$u_hr->{$uid}{upfairratio} = $ratio;
		# Downmod fairness ratio.
		$ratio = undef;
		$denom = $u_hr->{$uid}{down_fair} + $u_hr->{$uid}{down_unfair};
		if ($denom >= 5) {
			$ratio = $u_hr->{$uid}{down_fair} / $denom;
		}
		$u_hr->{$uid}{downfairratio} = $ratio;
		# Spent-to-stirred ratio.
		$ratio = undef;
		$denom = $u_hr->{$uid}{totalmods} + $u_hr->{$uid}{stirred};
		if ($denom >= 10) {
			$ratio = $u_hr->{$uid}{totalmods} / $denom;
		}               
		$u_hr->{$uid}{stirredratio} = $ratio;
	}
	
	# Get some stats into the $u_hr hashref that will make some
	# code later on easier.  Sum the total number of fair votes,
	# so up_fair+down_fair = total_fair.  And sum the fair
	# ratios too, to give a very general idea of total fairness.
	for my $uid (%$u_hr) {
		$u_hr->{$uid}{total_fair} =
			  ($u_hr->{$uid}{up_fair} || 0)
			+ ($u_hr->{$uid}{down_fair} || 0);
		$u_hr->{$uid}{totalfairratio} = $u_hr->{$uid}{upfairratio}
			if defined($u_hr->{$uid}{upfairratio});
		if (defined($u_hr->{$uid}{downfairratio})) {
			$u_hr->{$uid}{totalfairratio} =
				($u_hr->{$uid}{totalfairratio} || 0)
				+ $u_hr->{$uid}{downfairratio};
		}
	}

	if ($wtf->{fairtotal}) {
		# Assign a token likeliness factor based on the absolute
		# number of "fair" M2s assigned to each user's moderations.
		# Sort by total m2fair first (that's the point of this
		# code).  If there's a tie in that, the secondary sort is
		# by ratio, and tertiary is random.
		my @new_uids = sort {
				$u_hr->{$a}{total_fair} <=> $u_hr->{$b}{total_fair}
				||
				( defined($u_hr->{$a}{totalfairratio})
					&& defined($u_hr->{$b}{totalfairratio})
				  ? $u_hr->{$a}{totalfairratio} <=> $u_hr->{$b}{totalfairratio}
				  : 0 )
				||
				int(rand(1)*2)*2-1
			} @$orig_uids;
		# Assign the factors in the hashref according to this
		# sort order.  Those that sort first get the lowest value,
		# the approximate middle gets 1, the last get highest.
		_set_factor($u_hr, $wtf->{fairtotal}, 'factor_m2total',
			\@new_uids);
	}

		# Assign a token likeliness factor based on the ratio of
		# "fair" to "unfair" M2s assigned to each user's
		# moderations.  In order not to be "prejudiced" against
		# users with no M2 history, those users get no change in
		# their factor (i.e. 1) by simply being left out of the
		# list.  Sort by ratio first (that's the point of this
		# code);  if there's a tie in ratio, the secondary sort
		# order is total m2fair, and tertiary is random.
		# Do this separately by first up fairness ratio, then
		# down fairness ratio.

	if ($wtf->{upfairratio}) {
		my @new_uids = sort {
				$u_hr->{$a}{upfairratio} <=> $u_hr->{$b}{upfairratio}
				||
				$u_hr->{$a}{total_fair} <=> $u_hr->{$b}{total_fair}
				||
				int(rand(1)*2)*2-1
			} grep { defined($u_hr->{$_}{upfairratio}) }
			@$orig_uids;
		# Assign the factors in the hashref according to this
		# sort order.  Those that sort first get the lowest value,
		# the approximate middle gets 1, the last get highest.
		_set_factor($u_hr, $wtf->{upfairratio}, 'factor_upfairratio',
			\@new_uids);
	}       
		
	if ($wtf->{downfairratio}) {
		my @new_uids = sort {
				$u_hr->{$a}{downfairratio} <=> $u_hr->{$b}{downfairratio}
				||
				$u_hr->{$a}{total_fair} <=> $u_hr->{$b}{total_fair}
				||      
				int(rand(1)*2)*2-1
			} grep { defined($u_hr->{$_}{downfairratio}) }
			@$orig_uids;
		# Assign the factors in the hashref according to this
		# sort order.  Those that sort first get the lowest value,
		# the approximate middle gets 1, the last get highest.
		_set_factor($u_hr, $wtf->{downfairratio}, 'factor_downfairratio',
			\@new_uids);
	}       
			
	if ($wtf->{stirratio}) {
		# Assign a token likeliness factor based on the ratio of
		# stirred to spent mod points.  In order not to be
		# "prejudiced" against users with little or no mod history,
		# those users get no change in their factor (i.e. 1) by
		# simply being left out of the list.  Sort by ratio first
		# (that's the point of this code); if there's a tie in
		# ratio, the secondary sort order is total spent, and
		# tertiary is random.
		my @new_uids = sort {
				$u_hr->{$a}{stirredratio} <=> $u_hr->{$b}{stirredratio}
				||
				$u_hr->{$a}{totalmods} <=> $u_hr->{$b}{totalmods}
				||
				int(rand(1)*2)*2-1
			} grep { defined($u_hr->{$_}{stirredratio}) }
			@$orig_uids;
		# Assign the factors in the hashref according to this
		# sort order.  Those that sort first get the lowest value,
		# the approximate middle gets 1, the last get highest.
		_set_factor($u_hr, $wtf->{stirratio}, 'factor_stirredratio',
			\@new_uids);
	}

	# If the caller wanted to keep stats, prep some stats.
	if ($info_hr) {
		$info_hr->{factor_lowest} = 1;
		$info_hr->{factor_highest} = 1;
	}

	# Now modify the list of uids.  Each uid in the list has the product
	# of its factors calculated.  If the product is exactly 1, that uid
	# is left alone.  If less than 1, there is a chance the uid will be
	# deleted from the list.  If more than 1, there is a chance it will
	# be doubled up in the list (or more than doubled for large factors).
	for my $uid (@$orig_uids) {
		my $factor = 1;
		for my $field (qw(
			factor_m2total
			factor_upfairratio factor_downfairratio
			factor_stirredratio
		)) {
			$factor *= $u_hr->{$uid}{$field}
				if defined($u_hr->{$uid}{$field});
		}
		# If the caller wanted to keep stats, send some stats.
		$info_hr->{factor_lowest} = $factor
			if $info_hr && $info_hr->{factor_lowest}
				&& $factor < $info_hr->{factor_lowest};
		$info_hr->{factor_highest} = $factor
			if $info_hr && $info_hr->{factor_highest}
				&& $factor > $info_hr->{factor_highest};
		# If the factor is, say, 1.3, then the count of this uid is
		# at least 1, and there is a 0.3 chance that it goes to 2.
		my $count = roundrand($factor);
		push @return_uids, ($uid) x $count;
	}

	return \@return_uids;
}

# This specialized utility function takes a list of uids and assigns
# values into the hashrefs that are their values in %$u_hr.  The
# @$uidlist determines the order that the values will be assigned.
# The first uid gets the value 1/$factor (and since $factor should
# be >1, this value will be <1).  The middle uid in @$uidlist will
# get the value approximately 1, and the last uid will get the value
# $factor.  After these assignments are made, any uid keys in %$u_hr
# *not* in @$uidlist will be given the value 1.  The 2nd-level hash
# key that these values are assigned to is $u_hr->{$uid}{$field}.
sub _set_factor {
	my($u_hr, $factor, $field, $uidlist) = @_;
	my $halfway = int($#$uidlist/2);
	return if $halfway <= 1;

	if ($factor != 1) {
		for my $i (0 .. $halfway) {
	
			# We'll use this first as a numerator, then as 
			# a denominator.
			my $between_1_and_factor = 1 + ($factor-1)*($i/$halfway);
		
			# Set the lower uid, which ranges from 1/$factor to
			# $factor/$factor.
			my $uid = $uidlist->[$i];
			$u_hr->{$uid}{$field} = $between_1_and_factor/$factor;
		
			# Set its counterpart the higher uid, which ranges from
			# $factor/$factor to $factor/1 (but we build this list
			# backwards, from $#uidlist down to $halfway-ish, so we
			# start at $factor/1 and come down to $factor/$factor).
			my $j = $#$uidlist-$i;
			$uid = $uidlist->[$j];
			$u_hr->{$uid}{$field} = $factor/$between_1_and_factor;
		
		}       
	}                       
		
	# uids which didn't get a value assigned just get "1".
	for my $uid (keys %$u_hr) {
		$u_hr->{$uid}{$field} = 1 if !defined($u_hr->{$uid}{$field});
	}
}

########################################################
# For run_moderatord.pl
sub updateTokens {
	my($self, $uid_hr, $options) = @_;
	my $constants = getCurrentStatic();
	my $maxtokens = $constants->{maxtokens} || 60;
	my $splice_count = $options->{splice_count} || 200;
	my $sleep_time = defined($options->{sleep_time}) ? $options->{sleep_time} : 0.5;

	my %adds = ( map { ($_, 1) } grep /^\d+$/, values %$uid_hr );
	for my $add (sort { $a <=> $b } keys %adds) {
		my @uids = sort { $a <=> $b }
			grep { $uid_hr->{$_} == $add }
			keys %$uid_hr;
		# At this points, @uids is the list of uids that need
		# to have $add tokens added.  Group them into slices
		# and bulk-add.  This is much more efficient than
		# calling setUser individually.
		while (@uids) {
			my @uid_chunk = splice @uids, 0, $splice_count;
			my $uids_in = join(",", @uid_chunk);
			$self->sqlUpdate("users_info",
				{ -tokens => "LEAST(tokens+$add, $maxtokens)" },
				"uid IN ($uids_in)");
			$self->setUser_delete_memcached(\@uid_chunk);
			# If there is more to do, sleep for a moment so we don't
			# hit the DB too hard.
			Time::HiRes::sleep($sleep_time) if @uids && $sleep_time;
		}
	}
}

# placeholders, used only in TagModeration
sub removeModTags {}
sub createModTag  {}

sub setModPoints {
	my($self, $uids, $granted, $opts) = @_;

	for my $uid (@$uids) {
		next unless $uid;
		my $rows = $self->setUser($uid, {
			-lastgranted    => 'NOW()',
			-tokens         => "GREATEST(0, tokens - $opts->{tokentrade})",
			-points         => "LEAST(points + $opts->{pointtrade}, $opts->{maxpoints})",
		});
		$granted->{$uid} = 1 if $rows;
	}
}

1;


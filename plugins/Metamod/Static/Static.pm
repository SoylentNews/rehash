# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Metamod::Static;

use strict;
use Slash::Utility;

use base 'Slash::Metamod';

our $VERSION = $Slash::Constants::VERSION;

sub isInstalled {
	my($class) = @_;
	return Slash::MetaMod->isInstalled();
}

########################################################

# Pass in option "sleep_between" of a few seconds, maybe up to a
# minute, if for some reason the deletion still makes slave
# replication lag... (but it shouldn't, anymore) - 2005/01/06

sub deleteOldM2Rows {
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

        # Now delete from the bottom up for the metamodlog.

        my $junk_bottom = $reader->sqlSelect('MIN(id)', 'metamodlog');
        my $need_bottom = $reader->sqlSelectNumericKeyAssumingMonotonic(
                'metamodlog', 'min', 'id',
                "ts >= DATE_SUB(NOW(), INTERVAL $archive_delay_mod DAY)");
        while ($need_bottom && $junk_bottom < $need_bottom) {
                $junk_bottom += $max_rows;
                $junk_bottom = $need_bottom if $need_bottom < $junk_bottom;
                $self->sqlDelete('metamodlog', "id < $junk_bottom");
                sleep $sleep_between
                        if $sleep_between && $junk_bottom < $need_bottom;
        }
        
        $self->sqlDo("SET FOREIGN_KEY_CHECKS=1");
        return 0;
}

sub getModResolutionSummaryForUser {
	my($self, $uid, $limit) = @_;
	my $uid_q = $self->sqlQuote($uid);
	my $limit_str = "";
	$limit_str = "LIMIT $limit" if $limit;
	my($fair, $unfair, $fairvotes, $unfairvotes) = (0,0,0,0);

	my $constants = getCurrentStatic();
	my $moddb = getObject("Slash::$constants->{m1_pluginname}");
	my $reasons = $moddb->getReasons();
	my @reasons_m2able = grep { $reasons->{$_}{m2able} } keys %$reasons;
	my $reasons_m2able = join(",", @reasons_m2able);
	
	return {} unless @reasons_m2able;
	my $reason_str = " AND reason IN ($reasons_m2able)";
		
	my $mod_ids = $self->sqlSelectColArrayref("id", "moderatorlog",
			"uid=$uid_q AND active=1 AND m2status=2 $reason_str",
			"ORDER BY id desc $limit_str");

	foreach my $mod (@$mod_ids){
		my $m2_ar = $self->getMetaModerations($mod);

		my $nunfair = scalar(grep { $_->{active} && $_->{val} == -1 } @$m2_ar);
		my $nfair   = scalar(grep { $_->{active} && $_->{val} ==  1 } @$m2_ar);

		$unfair++ if $nunfair > $nfair;
		$fair++ if $nfair > $nunfair;
		$fairvotes += $nfair;
		$unfairvotes += $nunfair;
	}
	return { fair => $fair, unfair => $unfair, fairvotes => $fairvotes, unfairvotes => $unfairvotes };
}

# Returns the meta-moderation information given the appropriate metamod id
# (primary key into the metamodlog table).

sub getMetaModerations {
	my($self, $mmid) = @_;

	return $self->sqlSelectAllHashrefArray(
		'*', 'metamodlog',
		"mmid=$mmid"
	);
}

########################################################

# Given a fractional value representing the fraction of fair M2
# votes, returns the token/karma consequences of that fraction
# in a hashref.  Makes the very complex var m2_consequences a
# little easier to use.  Note that the value returned has three
# fields:  a float, its sign, and an SQL expression which may be
# either an integer or an IF().
# The mod_hr passed in here is the same format as the items
# returned by getModsNeedingReconcile().

sub getM2Consequences {
	my($self, $frac, $mod_hr) = @_;
	my $constants = getCurrentStatic();

	my $c = $constants->{m2_consequences};
	my $retval = { };
	for my $ckey (sort { $a <=> $b } keys %$c) {
		if ($frac <= $ckey) {
			my @vals = @{$c->{$ckey}};
			for my $key (qw(        m2_fair_tokens
						m2_unfair_tokens
						m1_tokens
						m1_karma )) {
				$retval->{$key}{num} = shift @vals; 
			}
			$self->_csq_bonuses($frac, $retval, $mod_hr);
			for my $key (keys %$retval) {
				$self->_set_csq($key, $retval->{$key});
			}
			last;
		}
	}

	my $cr = $constants->{m2_consequences_repeats};
	if ($cr && %$cr) {
		my $repeats = $self->_csq_repeats($mod_hr);
		for my $min (sort { $b <=> $a } keys %$cr) {
			if ($min <= $repeats) {
				$retval->{m1_tokens}{num} += $cr->{$min};
				$self->_set_csq('m1_tokens', $retval->{m1_tokens});
				last;
			}
		}
	}

	return $retval;
}

sub _csq_repeats {
	my($self, $mod_hr) = @_;
	# Count the number of moderations performed by this user
	# on the same target user, in the same direction (up or
	# down), before the current mod we're reconciling, but of
	# course after the archive_delay_mod (or a max of 60 days).
	my $ac_uid = getCurrentStatic("anonymous_coward_uid");
	return $self->sqlCount(
		"moderatorlog",
		"active=1
		 AND uid=$mod_hr->{uid} AND cuid=$mod_hr->{cuid}
		 AND cuid != $ac_uid
		 AND val=$mod_hr->{val}
		 AND id < $mod_hr->{id}
		 AND ts >= DATE_SUB(NOW(), INTERVAL 60 DAY)");
}

sub _csq_bonuses {
	my($self, $frac, $retval, $mod_hr) = @_;
	my $constants = getCurrentStatic();

	my $num = $retval->{m1_tokens}{num};
	# Only moderations that are going to give a token bonus
	# already qualify to have that bonus hiked.
	return if $num <= 0;

	my $num_orig = $num;
	my @applied = qw( );

	# "Slashdot provides an existence proof that the basic idea
	# of distributed moderation is sound. ... There is still
	# room, however, for design advances that require only
	# modestly more moderator effort to produce far more timely
	# and accurate moderation overall."
	#
	# That and following quotes are taken from:
	# Lampe, C. and Resnick, P. "Slash(dot) and Burn: Moderation in a
	# Large Scale Conversation Space."  Proceedings of the Conference on
	# Computer Human Interaction (SIGCHI).  April 2004. Vienna, Austria.
	# ACM Press.
	#
	# The goal of _csq_bonuses is to reward moderators who take
	# a little extra effort, by giving them their next set of
	# mod points sooner.  It may work better if moderators are
	# told about these bonuses and are encouraged to take actions
	# to earn them.  Even if not, at least the moderators who
	# take it upon themselves to _do_ these actions will be able
	# to moderate more frequently.

	# If a comment was Fairly moderated *soon* after being posted,
	# give the moderator a bonus for being quick on the draw.
	#
	# "Among comments that received some moderation, the median time
	# until receiving the first moderation was 83 minutes... More
	# than 40% of comments that reached a +4 score took longer to do
	# so than 174 minutes, the time at which a typical conversation
	# was already half over."
	if ($mod_hr->{secs_before_mod} < $constants->{m2_consequences_bonus_earlymod_secs}) {
		$num *= $constants->{m2_consequences_bonus_earlymod_tokenmult} || 1;
		push @applied, 'earlymod';
	}

	# If a Fair moderation was applied to a comment not posted
	# too early in a discussion, give the moderator a bonus for
	# not just hanging out for the first few minutes of a story.
	#
	# "Of early comments [in the first quintile of their
	# discussion], 59% were moderated, compared to 25% for
	# comments in the middle [third quintile] of their
	# conversation and 7% for late comments [fifth quintile]."
	# Here, quintile 5 is the latest 20% of the discussion, and
	# quintile 1 is the earliest 20%.
	if (defined $mod_hr->{cid_percentile}) {
		if ($mod_hr->{cid_percentile} > 80) {
			$num *= $constants->{m2_consequences_bonus_quintile_5} || 1;
			push @applied, 'quintile_5';
		} elsif ($mod_hr->{cid_percentile} > 60) {
			$num *= $constants->{m2_consequences_bonus_quintile_4} || 1;
			push @applied, 'quintile_4';
		} elsif ($mod_hr->{cid_percentile} > 40) {
			$num *= $constants->{m2_consequences_bonus_quintile_3} || 1;
			push @applied, 'quintile_3';
		} elsif ($mod_hr->{cid_percentile} > 20) {
			$num *= $constants->{m2_consequences_bonus_quintile_2} || 1;
			push @applied, 'quintile_2';
		} else {
			$num *= $constants->{m2_consequences_bonus_quintile_1} || 1;
			push @applied, 'quintile_1';
		}
	}

	# If a Fair moderation was applied to a comment that was
	# a reply, rather than top-level, give the moderator a bonus
	# for not just scanning the most visible comments.
	#
	# "Of top-level comments, 48% received some moderation,
	# compared to 22% for response comments.  The mean final
	# score for top-level comments was 1.73, as compared to
	# 1.40 for responses."
	if ($mod_hr->{comment_pid}) {
		$num *= $constants->{m2_consequences_bonus_replypost_tokenmult} || 1;
		push @applied, 'reply';
	}

	# If a Fair moderation was applied to a comment while it
	# was at a low score, give the moderator a bonus.  Or
	# perhaps don't give the moderator quite so many tokens
	# for moderating a comment while it was at a high score.
	#
	# "Moderators may give insufficient attention to comments
	# with low scores... comments with lower starting scores
	# were less likely to be moderated.  For example, 30% of
	# comments starting at 2 received a moderation, compared
	# to only 29% of those starting at 1, 25% of those
	# starting at 0, and 9% of those starting at -1."
	#
	# I don't think that's much of a spread (from 0 to 2
	# anyway), and note this applies to the comment's score
	# at the time of moderation, not its original score
	# (since if a comment went from 0 to 4 and then got
	# moderated, the moderator only saw it at 4 anyway).
	my $constname = "m2_consequences_bonus_pointsorig_$mod_hr->{points_orig}";
	if (defined($constants->{$constname})) {
		$num *= $constants->{$constname};
		push @applied, "pointsorig_$mod_hr->{points_orig}";
	}

	return if $num == $num_orig;

	if ($frac < $constants->{m2_consequences_bonus_minfairfrac}) {
		# Only moderations that meet a certain minimum
		# level of Fairness qualify for the bonuses.
		# This mod did not meet that level.  So now, the
		# consequences change does not happen if it would
		# be advantageous to the moderator.
		return if $num_orig > $num;
	}

#printf STDERR "%s m2_consequences change from '%d' to '%.2f' because '%s' id %d cid %d uid %d\n",
#scalar(localtime), $num_orig, $num, join(" ", @applied), $mod_hr->{id}, $mod_hr->{cid}, $mod_hr->{uid};

	$retval->{csq_token_change}{num} ||= 0;
	$retval->{csq_token_change}{num} += $num - $num_orig;
	$retval->{m1_tokens}{num} = sprintf("%+.2f", $num);
}

sub _set_csq {
	my($self, $key, $hr) = @_;
	my $n = $hr->{num};
	if (!$n) {
		$hr->{chance} = $hr->{sign} = 0;
		$hr->{sql_base} = $hr->{sql_possible} = "";
		$hr->{sql_and_where} = undef;
		return ;
	}

	my $constants = getCurrentStatic();
	my $column = 'tokens';
	$column = 'karma' if $key =~ /karma$/;
	my $max = ($column eq 'tokens')
		? $constants->{m2_consequences_token_max}
		: $constants->{m2_maxbonus_karma};
	my $min = ($column eq 'tokens')
		? $constants->{m2_consequences_token_min}
		: $constants->{minkarma};

	my $sign = 1; $sign = -1 if $n < 0;
	$hr->{sign} = $sign;

	my $a = abs($n);
	my $i = int($a);

	$hr->{chance} = $a - $i;
	$hr->{num_base} = $i * $sign;
	$hr->{num_possible} = ($i+1) * $sign;
	if ($sign > 0) {
		$hr->{sql_and_where}{$column} = "$column < $max";
		$hr->{sql_base} = $i ? "LEAST($column+$i, $max)" : "";
		$hr->{sql_possible} = "LEAST($column+" . ($i+1) . ", $max)"
			if $hr->{chance};
	} else {
		$hr->{sql_and_where}{$column} = "$column > $min";
		$hr->{sql_base} = $i ? "GREATEST($column-$i, $min)" : "";
		$hr->{sql_possible} = "GREATEST($column-" . ($i+1) . ", $min)"
			if $hr->{chance};
	}
}

########################################################

# Get an arrayref of moderatorlog rows that are ready to have
# their M2's reconciled.  This used to be complex to figure out but
# now it's easy;  moderatorlog rows start with m2status=0, graduate
# to m2status=1 when they are ready to be reconciled by the task,
# and move to m2status=2 when they are reconciled.
sub getModsNeedingReconcile {
	my($self) = @_;

	my $batchsize = getCurrentStatic("m2_batchsize");
	my $limit = "";
	$limit = "LIMIT $batchsize" if $batchsize;

	my $mods_ar = $self->sqlSelectAllHashrefArray(
		'moderatorlog.id AS id, moderatorlog.ipid AS ipid,
			moderatorlog.subnetid AS subnetid,
			moderatorlog.uid AS uid, val,
			moderatorlog.sid AS sid,
			moderatorlog.ts AS ts,
			moderatorlog.cid AS cid, cuid,
			moderatorlog.reason AS reason,
			active, spent, m2count, m2status,
			points_orig,
		 comments.pid AS comment_pid,
		 comments.pointsorig AS comment_pointsorig,
		 UNIX_TIMESTAMP(moderatorlog.ts) AS mod_unixts,
		 UNIX_TIMESTAMP(comments.date) AS comment_unixts,
		 UNIX_TIMESTAMP(discussions.ts) AS discussion_unixts,
		 discussions.commentcount AS discussion_commentcount',
		'moderatorlog,comments,discussions',
		'm2status=1
			AND moderatorlog.cid = comments.cid
			AND moderatorlog.sid = discussions.id',
		"ORDER BY id $limit",
	);

	# Now get some extra data about each discussion and the
	# moderated comments in question.  We want the percentile
	# of each comment in its discussion, and also the time
	# in seconds between discussion opening and the comment
	# being posted.
	if ($mods_ar && @$mods_ar) {
		my %disc_ids = map { ($_->{sid}, 1) } @$mods_ar;
		my %sid_cids = ( );
		my $sid_in_clause = "sid IN (" . join(", ", keys %disc_ids) . ")";
		my $cid_ar = $self->sqlSelectAll(
			"sid, cid",
			"comments",
			$sid_in_clause,
			"ORDER BY sid, cid");
		for my $ar (@$cid_ar) {
			my($sid, $cid) = @$ar;
			push @{$sid_cids{$sid}}, $cid;
		}
		for my $mod (@$mods_ar) {
			# Generate the cid_percentile, where 0 is the
			# first comment in the discussion, and 100 is
			# the last comment (posted so far).
			my($sid, $cid) = ($mod->{sid}, $mod->{cid});
			my $cidlist_ar = $sid_cids{$sid};
			if (scalar(@$cidlist_ar < 10)) {
				$mod->{cid_percentile} = undef;
			} else {
				$mod->{cid_percentile} = _find_percentile(
					$cid, $cidlist_ar);
			}
			# Generate the number of seconds between
			# discussion opening and the comment being
			# posted.
			$mod->{secs_before_post} = $mod->{comment_unixts}
				- $mod->{discussion_unixts};
			# Generate the number of seconds between
			# the comment being posted and its being
			# moderated.
			$mod->{secs_before_mod} = $mod->{mod_unixts}
				- $mod->{comment_unixts};
		}
	}

	return $mods_ar;
}

sub _find_percentile {
	my($item, $list) = @_;
	my $n = $#$list;
	return undef if $n < 1;
	my $i = $n;
	for (0..$n-1) {
		$i = $_, last if $item <= $list->[$_];
	}
	return sprintf("%.1f", 100*($i/$n));
}

1;


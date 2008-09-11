#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Tagbox::FireHoseScores;

=head1 NAME

Slash::Tagbox::FireHoseScores - update scores on firehose entries

=head1 SYNOPSIS

	my $tagbox_tcu = getObject("Slash::Tagbox::FireHoseScores");
	my $feederlog_ar = $tagbox_tcu->feed_newtags($users_ar);
	$tagbox_tcu->run($affected_globjid);

=cut

use strict;

use Slash;
use Slash::Utility::Comments; # constrain_score(), maybe other things

our $VERSION = $Slash::Constants::VERSION;

use base 'Slash::Tagbox';

sub init {
	my($self) = @_;
	return 0 if ! $self->SUPER::init();
	my $slashdb = getCurrentDB();
	$self->{nodornixid}     = {(
		$self->{nodid},         1,
		$self->{nixid},         1,
	)};
	my $admins = $self->getAdmins();
	$self->{admins} = {
		map { ($_, 1) }
		grep { $slashdb->getUser($_, 'seclev') >= 100 }
		keys %$admins
	};

	# XXX See CommentScoreReason.pm, we should consolidate code

	my $tagsdb = getObject('Slash::Tags');
	my $moddb = getObject('Slash::TagModeration');
	$self->{reasons} = $moddb->getReasons();
	$self->{reason_tagnameid} = { };
	$self->{reason_ids} = [
		grep { $self->{reasons}{$_}{val} != 0 }
		keys %{$self->{reasons}}
	];
	for my $id (@{$self->{reason_ids}}) {
		my $name = lc $self->{reasons}{$id}{name};
		my $tagnameid = $tagsdb->getTagnameidCreate($name);
		$self->{reason_tagnameid}{$tagnameid} = $self->{reasons}{$id};
	}

	1;
}

sub init_tagfilters {
	my($self) = @_;
	$self->{filter_activeonly} = 1;
	$self->{filter_firehoseonly} = 1;
	$self->{filter_tagnameid} = [ @{$self}{qw( nodid nixid )} ];
	push @{ $self->{filter_tagnameid} }, keys %{ $self->{reason_tagnameid} };
}

sub get_affected_type	{ 'globj' }
sub get_clid		{ 'vote' }
sub get_userkeyregex	{ qr{^tag_clout$} }

# XXX handle
#sub feed_userchanges_process {
#	my($self, $users_ar) = @_;
#	my $constants = getCurrentStatic();
#	my $tagsdb = getObject('Slash::Tags');
#
#	my %max_tuid = ( );
#	my %uid_change_sum = ( );
#	my %globj_change = ( );
#	for my $hr (@$users_ar) {
#		next unless $hr->{user_key} eq 'tag_clout';
#		$max_tuid{$hr->{uid}} ||= $hr->{tuid};
#		$max_tuid{$hr->{uid}}   = $hr->{tuid}
#			if $max_tuid{$hr->{uid}} < $hr->{tuid};
#		$uid_change_sum{$hr->{uid}} ||= 0;
#		$uid_change_sum{$hr->{uid}} += abs(($hr->{value_old} || 1) - $hr->{value_new});
#	}
#	for my $uid (keys %uid_change_sum) {
#		my $tags_ar = $tagsdb->getAllTagsFromUser($uid);
#		for my $tag_hr (@$tags_ar) {
#			next unless $tag_hr->{tagnameid} == $self->{nodid} || $tag_hr->{tagnameid} == $self->{nixid};
#			$globj_change{$tag_hr->{globjid}}{max_tuid} ||= $max_tuid{$uid};
#			$globj_change{$tag_hr->{globjid}}{max_tuid}   = $max_tuid{$uid}
#				if $globj_change{$tag_hr->{globjid}}{max_tuid} < $max_tuid{$uid};
#			$globj_change{$tag_hr->{globjid}}{sum} ||= 0;
#			$globj_change{$tag_hr->{globjid}}{sum} += $uid_change_sum{$uid};
#		}
#	}
#	my $ret_ar = [ ];
#	for my $globjid (sort { $a <=> $b } keys %globj_change) {
#		push @$ret_ar, {
#			tuid =>         $globj_change{$globjid}{max_tuid},
#			affected_id =>  $globjid,
#			importance =>   $globj_change{$globjid}{sum},
#		};
#	}
#
#	main::tagboxLog("FireHoseScores->feed_userchanges returning " . scalar(@$ret_ar));
#	return $ret_ar;
#}

sub run_process {
	my($self, $affected_id, $tags_ar, $options) = @_;
	my $constants = getCurrentStatic();
	my $tagsdb = getObject('Slash::Tags');
	my $tagboxdb = getObject('Slash::Tagbox');
	my $firehose_db = getObject('Slash::FireHose');
	my $fhid = $firehose_db->getFireHoseIdFromGlobjid($affected_id);
	warn "Slash::Tagbox::FireHoseScores->run_process bad data, fhid='$fhid' db='$firehose_db'" if !$fhid || !$firehose_db;
	my $fhitem = $firehose_db->getFireHose($fhid);

	# Some target types gain popularity.
	my($type, $target_id) = $tagsdb->getGlobjTarget($affected_id);
	my($color_level, $extra_pop) = $self->getStartingColorLevel($type, $target_id);
	my $popularity = $firehose_db->getEntryPopularityForColorLevel($color_level) + $extra_pop;

	if ($options->{starting_only}) {
		return $popularity if $options->{return_only};
		$self->info_log("setting %d (%d) to %.6f STARTING_ONLY",
			$fhid, $affected_id, $popularity);
		return $firehose_db->setFireHose($fhid, { popularity => $popularity });
	}

#	my $tags_ar = $tagboxdb->getTagboxTags($self->{tbid}, $affected_id, 0, $options);
# XXX make automatic?
	$tagsdb->addCloutsToTagArrayref($tags_ar, 'vote');

	# Add up nods and nixes.

	# Some basic facts first.
	my $n_votes = scalar
		grep { $_->{tagnameid} == $self->{nodid} || $_->{tagnameid} == $self->{nixid} }
		@$tags_ar;

	# Admins may get reduced downvote clout.
	if ($constants->{firehose_admindownclout} && $constants->{firehose_admindownclout} != 1) {
		for my $tag_hr (@$tags_ar) {
			$tag_hr->{total_clout} *= $constants->{firehose_admindownclout}
				if    $tag_hr->{tagnameid} == $self->{nixid}
				   && $self->{admins}{ $tag_hr->{uid} };
		}
	}

	# Also, admins may get reduced upvote clout.
	if ($constants->{firehose_adminupclout} && $constants->{firehose_adminupclout} != 1) {
		for my $tag_hr (@$tags_ar) {
			$tag_hr->{total_clout} *= $constants->{firehose_adminupclout}
				if    $tag_hr->{tagnameid} == $self->{nodid}
				   && $self->{admins}{ $tag_hr->{uid} };
		}
	}

	# Early in a globj's lifetime, if there have been few votes,
	# upvotes count for more, and downvotes for less.
	my($up_mult, $down_mult) = (1, 1);
	my $age = time - $fhitem->{createtime_ut};
	if ($n_votes <= $constants->{tagbox_firehosescores_gracevotes}
		&& $age < $constants->{tagbox_firehosescores_gracetime}) {
		$age = 0 if $age < 0;
		$up_mult = 1+(
			  ($constants->{tagbox_firehosescores_gracemult} - 1)
			* ($constants->{tagbox_firehosescores_gracetime} - $age)
			/  $constants->{tagbox_firehosescores_gracetime}
		);
		$down_mult = 1/$up_mult;
	}

	# The main loop to calculate popularity.
	my $udc_cache = { };
	for my $tag_hr (@$tags_ar) {
		my $sign = 0;
		$sign =  1 if $tag_hr->{tagnameid} == $self->{nodid}   && !$options->{downvote_only};
		$sign = -1 if $tag_hr->{tagnameid} == $self->{nixid} && !$options->{upvote_only};
		next unless $sign;
		my $grace_mult = ($sign == 1) ? $up_mult : $down_mult;
		my $extra_pop = $tag_hr->{total_clout} * $sign * $grace_mult;
		my $udc_mult = $self->get_udc_mult($tag_hr->{created_at_ut}, $udc_cache);
#$self->info_log("extra_pop for %d: %.6f * %.6f * %.6f", $tag_hr->{tagid}, $extra_pop, $udc_mult, $grace_mult);
		$extra_pop *= $udc_mult;
		$popularity += $extra_pop;
	}

	# If this is spam, or contains a spam URL, its score goes way down.
	if ($fhitem->{is_spam} eq 'yes' || $firehose_db->itemHasSpamURL($fhitem)) {
		my $max = defined($constants->{firehose_spam_score})
			? $constants->{firehose_spam_score}
			: -50;
		$popularity = $max if $popularity > $max;
	}

	# Set the corresponding firehose row to have this popularity.
	if ($options->{return_only}) {
		return $popularity;
	}
	$self->info_log("setting %d (%d) to %.6f", $fhid, $affected_id, $popularity);
	$firehose_db->setFireHose($fhid, { popularity => $popularity });
}

sub getStartingColorLevel {
	my($self, $type, $target_id) = @_;
	my $target_id_q = $self->sqlQuote($target_id);
	my $constants = getCurrentStatic();
	my($color_level, $extra_pop) = (0, 0);
	if ($type eq "submissions") {
		$color_level = 5;
	} elsif ($type eq "journals") {
		my $journal = getObject("Slash::Journal");
		my $j = $journal->get($target_id);
		$color_level = $j->{promotetype} && $j->{promotetype} eq 'publicize'
			? 5  # requested to be publicized
			: 6; # not requested
	} elsif ($type eq 'urls') {
		# XXX should modify next line by users' vote clout
		$extra_pop = $self->sqlCount('bookmarks', "url_id=$target_id_q") || 0;
		$color_level = $self->sqlCount("firehose", "type='feed' AND url_id=$target_id")
			? 6  # feed
			: 7; # nonfeed
	} elsif ($type eq "stories") {
		my $story = $self->getStory($target_id);
		my $str_hr = $story->{story_topics_rendered};
		$color_level = 3;
		for my $nexus_tid (keys %$str_hr) {
			my $this_color_level = 999;
			my $param = $self->getTopicParam($nexus_tid, 'colorlevel') || undef;
			if (defined $param) {
				# Stories in this nexus get this specific color level.
				$this_color_level = $param;
			} else {
				# Stories in any nexus without a colorlevel specifically
				# defined in topic_param get a color level of 2.
				$this_color_level = 2;
			}
			# Stories on the mainpage get a color level of 1.
			$this_color_level = 1 if $nexus_tid == $constants->{mainpage_nexus_tid};
			# This firehose entry gets the minimum color level of 
			# all its nexuses.
			$color_level = $this_color_level if $this_color_level < $color_level;
		}
	} elsif ($type eq "comments") {
		my $comment = $self->getComment($target_id);
		my $score = constrain_score($comment->{points} + $comment->{tweak});
		if ($score >= 5) {
			$color_level = 4;
		} elsif ($score >= 4) {
			$color_level = 5
		} elsif ($score >= 1) {
			$color_level = 6
		} else {
			$color_level = 7;
		}
	}
	return($color_level, $extra_pop);
}

{ # closure
my $udc_mult_cache = { };
sub get_udc_mult {
	my($self, $time, $cache) = @_;

	# Round off time to the nearest 10 second interval, for caching.
	$time = int($time/10+0.5)*10;
	if (defined($udc_mult_cache->{$time})) {
		return $udc_mult_cache->{$time};
	}

	my $constants = getCurrentStatic();
	my $prevhour = int($time/3600-1)*3600;
	my $curhour = $prevhour+3600;
	my $nexthour = $prevhour+3600;
	my $tagsdb = getObject('Slash::Tags');
	$cache->{$prevhour} = $tagsdb->sqlSelect('udc', 'tags_udc', "hourtime=FROM_UNIXTIME($prevhour)") || 0
		if !defined $cache->{$prevhour};
	$cache->{$curhour}  = $tagsdb->sqlSelect('udc', 'tags_udc', "hourtime=FROM_UNIXTIME($curhour)")  || 0
		if !defined $cache->{$curhour};
	$cache->{$nexthour} = $tagsdb->sqlSelect('udc', 'tags_udc', "hourtime=FROM_UNIXTIME($nexthour)") || 0
		if !defined $cache->{$nexthour};
	my $prevudc = $cache->{$prevhour};
	my $curudc  = $cache->{$curhour};
	my $nextudc = $cache->{$nexthour};
	my $thru_frac = ($time-$prevhour)/3600;
	my $prevweight = ($thru_frac > 0.5) ? 0 : 0.5-$thru_frac;
	my $nextweight = ($thru_frac < 0.5) ? 0 : $thru_frac-0.5;
	my $curweight = 1-($prevweight+$nextweight);
	my $udc = $prevudc*$prevweight + $curudc*$curweight + $nextudc*$nextweight;
	if ($udc == 0) {
		# This shouldn't happen on a site with any reasonable amount of
		# up and down voting, unless the tags_udc task has failed to run
		# for the past hour or two.  If it does happen, punt.
		$self->info_log("punting prev %d %.6f cur %d %.6f next %d %.6f time %d thru %.6f prevw %.6f curw %.6f nextw %.6f",
			$prevhour, $cache->{$prevhour}, $curhour, $cache->{$curhour}, $nexthour,  $cache->{$nexthour},
			$time, $thru_frac, $prevweight, $curweight, $nextweight);
		$udc = $constants->{tagbox_firehosescores_udcbasis};
	}
	my $udc_mult = $constants->{tagbox_firehosescores_udcbasis}/$udc;
	my $max_mult = $constants->{tagbox_firehosescores_maxudcmult} || 5;
	$udc_mult = $max_mult if $udc_mult > $max_mult;
#	$self->info_log("%0.3f time %d p %.3f c %.3f n %.3f th %.3f pw %.3f cw %.3f nw %.3f udc %.3f\n",
#		$udc_mult, $time, $prevudc, $curudc, $nextudc, $thru_frac, $prevweight, $curweight, $nextweight, $udc);
	$udc_mult_cache->{$time} = $udc_mult;
	return $udc_mult;
}
} # end closure

1;


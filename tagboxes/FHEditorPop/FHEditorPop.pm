#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Tagbox::FHEditorPop;

=head1 NAME

Slash::Tagbox::FHEditorPop - keep track of popularity of firehose for editors

=head1 SYNOPSIS

	my $tagbox_tcu = getObject("Slash::Tagbox::FHEditorPop");
	my $feederlog_ar = $tagbox_tcu->feed_newtags($users_ar);
	$tagbox_tcu->run($affected_globjid);

=cut

use strict;

use Slash;

our $VERSION = $Slash::Constants::VERSION;

use base 'Slash::Tagbox';

sub init {
	my($self) = @_;
	return 0 if ! $self->SUPER::init();
	my $tagsdb = getObject('Slash::Tags');
	$self->{maybeid}	= $tagsdb->getTagnameidCreate('maybe');
	$self->{metanodid}	= $tagsdb->getTagnameidCreate('metanod');
	$self->{metanixid}	= $tagsdb->getTagnameidCreate('metanix');
	$self->{nodornixid}	= {(
		$self->{nodid},		1,
		$self->{nixid},		1,
		$self->{metanodid},	1,
		$self->{metanixid},	1,
	)};
	my $admins = $self->getAdmins();
	$self->{admins} = {
		map { ($_, 1) }
		grep { $tagsdb->getUser($_, 'seclev') >= 100 }
		keys %$admins
	};
	1;
}

sub init_tagfilters {
	my($self) = @_;
	$self->{filter_activeonly} = 1;
	$self->{filter_firehoseonly} = 1;
	$self->{filter_tagnameid} = [ @{$self}{qw( nodid nixid maybeid metanodid metanixid )} ];
}

sub get_affected_type	{ 'globj' }
sub get_clid		{ 'vote' }

sub feed_newtags_process {
	my($self, $tags_ar) = @_;
	my $constants = getCurrentStatic();

	my $ret_ar = [ ];
	for my $tag_hr (@$tags_ar) {
		my $is_admin = $self->{admins}{ $tag_hr->{uid} } || 0;
		my $ret_hr = {
			affected_id =>	$tag_hr->{globjid},
			importance =>	$is_admin ? ($constants->{tagbox_fheditorpop_edmult} || 10) : 1,
		};
		if ($tag_hr->{tdid})	{ $ret_hr->{tdid}  = $tag_hr->{tdid}  }
		else			{ $ret_hr->{tagid} = $tag_hr->{tagid} }
		push @$ret_ar, $ret_hr;
	}
	return [ ] if !@$ret_ar;

	return $ret_ar;
}

sub run_process {
	my($self, $affected_id, $tags_ar, $options) = @_;
	my $constants = getCurrentStatic();
	my $tagsdb = getObject('Slash::Tags');
	my $tagboxdb = getObject('Slash::Tagbox');
	my $firehose = getObject('Slash::FireHose');

	my $fhid = $firehose->getFireHoseIdFromGlobjid($affected_id);
	my $fhitem = $firehose->getFireHose($fhid);

	# All firehose entries start out with popularity 1.
	my $popularity = 1;

	# Some target types gain popularity.
	my($type, $target_id) = $tagsdb->getGlobjTarget($affected_id);
	my $target_id_q = $self->sqlQuote($target_id);

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
		   if ($score >= 3) {	$color_level = 4 }
		elsif ($score >= 2) {	$color_level = 5 }
		elsif ($score >= 1) {	$color_level = 6 }
		else {			$color_level = 7 }
	}
	$popularity = $firehose->getEntryPopularityForColorLevel($color_level) + $extra_pop;

	# Add up nods and nixes.

# XXX add this automatically?
#	$tagsdb->addCloutsToTagArrayref($tags_ar, 'vote');

	my $udc_cache = { };
	my($n_admin_maybes, $n_admin_nixes, $maybe_pop_delta) = (0, 0, 0);
	for my $tag_hr (@$tags_ar) {
		next if $options->{starting_only};
		next if $tag_hr->{inactivated};
		my $sign = 0;
		$sign =  1 if $tag_hr->{tagnameid} == $self->{nodid} && !$options->{downvote_only};
		$sign = -1 if $tag_hr->{tagnameid} == $self->{nixid} && !$options->{upvote_only};
		next unless $sign;
		my $is_admin = $self->{admins}{ $tag_hr->{uid} } || 0;
		my $editor_mult    =  $is_admin ? ($constants->{tagbox_fheditorpop_edmult}    || 10   ) : 1;
		my $noneditor_mult = !$is_admin ? ($constants->{tagbox_fheditorpop_nonedmult} ||  0.75) : 1;
		my $extra_pop = $tag_hr->{total_clout} * $editor_mult * $noneditor_mult * $sign;
		my $udc_mult = $self->get_udc_mult($tag_hr->{created_at_ut}, $udc_cache);
		$extra_pop *= $udc_mult;
		if ($is_admin && $sign == 1) {
			# If this admin nod comes with a 'maybe', don't change
			# popularity yet;  save it up and wait to see if any
			# admins end up 'nix'ing.
			if (grep {
				     $_->{tagnameid} == $self->{maybeid}
				&&   $_->{uid}       == $tag_hr->{uid}
				&&   $_->{globjid}   == $tag_hr->{globjid}
			} @$tags_ar) {
				++$n_admin_maybes;
				$maybe_pop_delta += $extra_pop;
				$extra_pop = 0;
			}
		} elsif ($is_admin && $sign == -1) {
			++$n_admin_nixes;
		}
		$popularity += $extra_pop;
	}
	if ($n_admin_maybes > 0) {
		if ($n_admin_nixes) {
			# If any admin nixes, then all the admin nod+maybes are
                        # ignored.  The nixes have already been counted normally.
		} else {
			# No admin nixes, so the maybes boost editor popularity by
			# some fraction of the usual amount.
			my $frac = $constants->{tagbox_fheditorpop_maybefrac} || 0.1;
			$popularity += $maybe_pop_delta * $frac;
		}
	}

	# If more than a certain number of users have tagged this item with
	# public non-voting tags and its popularity is low, there may be a
	# bad reason why.  Boost its editor score up so that an editor sees
	# it and can review it.
	if ($popularity >= ($constants->{tagbox_fheditorpop_susp_minscore} || 100)) {
		my $max_taggers = $constants->{tagbox_fheditorpop_susp_maxtaggers} || 7;
		my $flag_pop = $constants->{tagbox_fheditorpop_susp_flagpop} || 185;
		my %tagger_uids = ( );
		my $tagged_by_admin = 0;
		for my $tag_hr (@$tags_ar) {
			next if    $tag_hr->{tagnameid} == $self->{nodid}
				|| $tag_hr->{tagnameid} == $self->{nixid}
				|| $tag_hr->{private};
			my $uid = $tag_hr->{uid};
			$tagged_by_admin = 1, last if $self->{admins}{$uid};
			$tagger_uids{$uid} = 1;
		}
		if (!$tagged_by_admin && scalar(keys %tagger_uids) > $max_taggers) {
			$popularity = $flag_pop;
		}
	}

	# If this is spam, its score goes way down.
	if ($fhitem->{is_spam} eq 'yes' || $firehose->itemHasSpamURL($fhitem)) {
		my $max = defined($constants->{firehose_spam_score})
			? $constants->{firehose_spam_score}
			: -50;
		$popularity = $max if $popularity > $max;
	}

	# If this is a comment item that's been nodded/nixed by an editor,
	# its score goes way down (so no other editors have to bother with it).
	if ($fhitem->{type} eq 'comment') {
		for my $tag_hr (@$tags_ar) {
			if (	   $self->{admins}{ $tag_hr->{uid} }
				&& $self->{nodornixid}{ $tag_hr->{tagnameid} }
			) {
				$popularity = -50 if $popularity > -50;
				last;
			}
		}
	}

	# Set the corresponding firehose row to have this popularity.
	warn "Slash::Tagbox::FHEditorPop->run bad data, fhid='$fhid' db='$firehose'" if !$fhid || !$firehose;
	if ($options->{return_only}) {
		return $popularity;
	}
	$self->info_log("setting %d (%d) to %.6f", $fhid, $affected_id, $popularity);
	$firehose->setFireHose($fhid, { editorpop => $popularity });
}

{ # closure
my $udc_mult_cache = { };
sub get_udc_mult {
	my($self, $time, $cache) = @_;

	# Round off time to the nearest 10 second interval, for caching.
	$time = int($time/10+0.5)*10;
	if (defined($udc_mult_cache->{$time})) {
#		main::tagboxLog(sprintf("get_udc_mult %0.3f time %d cached",
#			$udc_mult_cache->{$time}, $time));
		return $udc_mult_cache->{$time};
	}

	my $constants = getCurrentStatic();
	my $prevhour = int($time/3600-1)*3600;
	my $curhour = $prevhour+3600;
	my $nexthour = $prevhour+3600;
	my $tagsdb = getObject('Slash::Tags');
	$cache->{$prevhour} = $tagsdb->sqlSelect('udc', 'tags_udc', "hourtime=FROM_UNIXTIME($prevhour)")
		if !defined $cache->{$prevhour};
	$cache->{$curhour}  = $tagsdb->sqlSelect('udc', 'tags_udc', "hourtime=FROM_UNIXTIME($curhour)")
		if !defined $cache->{$curhour};
	$cache->{$nexthour} = $tagsdb->sqlSelect('udc', 'tags_udc', "hourtime=FROM_UNIXTIME($nexthour)")
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
		# up and down voting.  If it does, punt.
		$self->info_log("get_udc_mult punting prev %d %.6f cur %d %.6f next %d %.6f time %d thru %.6f prevw %.6f curw %.6f nextw %.6f",
			$prevhour, $cache->{$prevhour}, $curhour, $cache->{$curhour}, $nexthour,  $cache->{$nexthour},
			$time, $thru_frac, $prevweight, $curweight, $nextweight);
		$udc = $constants->{tagbox_fheditorpop_udcbasis};
	}
	my $udc_mult = $constants->{tagbox_fheditorpop_udcbasis}/$udc;
	my $max_mult = $constants->{tagbox_fheditorpop_maxudcmult} || 5;
	$udc_mult = $max_mult if $udc_mult > $max_mult;
#	$self->info_log("get_udc_mult %0.3f time %d p %.3f c %.3f n %.3f th %.3f pw %.3f cw %.3f nw %.3f udc %.3f\n",
#		$udc_mult, $time, $prevudc, $curudc, $nextudc, $thru_frac, $prevweight, $curweight, $nextweight, $udc);
	$udc_mult_cache->{$time} = $udc_mult;
	return $udc_mult;
}
} # end closure

1;


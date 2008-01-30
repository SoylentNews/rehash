#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

# This goes by seclev right now but perhaps should define "editor"
# to be more about author than admin seclev.  In which case the
# getAdmins() calls should be getAuthors().

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
use Slash::DB;
use Slash::Utility::Environment;
use Slash::Tagbox;

use Data::Dumper;

use vars qw( $VERSION );
$VERSION = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

use base 'Slash::DB::Utility';	# first for object init stuff, but really
				# needs to be second!  figure it out. -- pudge
use base 'Slash::DB::MySQL';

sub new {
	my($class, $user) = @_;

	return undef if !$class->isInstalled();

	# Note that getTagboxes() would call back to this new() function
	# if the tagbox objects have not yet been created -- but the
	# no_objects option prevents that.  See getTagboxes() for details.
	my($tagbox_name) = $class =~ /(\w+)$/;
	my %self_hash = %{ getObject('Slash::Tagbox')->getTagboxes($tagbox_name, undef, { no_objects => 1 }) };
	my $self = \%self_hash;
	return undef if !$self || !keys %$self;

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect();

	return $self;
}

sub isInstalled {
	my($class) = @_;
	my $constants = getCurrentStatic();
	my($tagbox_name) = $class =~ /(\w+)$/;
	return $constants->{plugin}{Tags} && $constants->{tagbox}{$tagbox_name} || 0;
}

sub feed_newtags {
	my($self, $tags_ar) = @_;
	my $constants = getCurrentStatic();
	if (scalar(@$tags_ar) < 9) {
		main::tagboxLog("FHEditorPop->feed_newtags called for tags '" . join(' ', map { $_->{tagid} } @$tags_ar) . "'");
	} else {
		main::tagboxLog("FHEditorPop->feed_newtags called for " . scalar(@$tags_ar) . " tags " . $tags_ar->[0]{tagid} . " ... " . $tags_ar->[-1]{tagid});
	}
	my $tagsdb = getObject('Slash::Tags');

	# The algorithm of the importance of tags to this tagbox is simple.
	# 'nod' and 'nix', esp. from editors, are important.  Other tags are not.
	my $upvoteid   = $tagsdb->getTagnameidCreate($constants->{tags_upvote_tagname}   || 'nod');
	my $downvoteid = $tagsdb->getTagnameidCreate($constants->{tags_downvote_tagname} || 'nix');
	my $admins = $self->getAdmins();
	for my $uid (keys %$admins) {
		$admins->{$uid}{seclev} = $tagsdb->getUser($uid, 'seclev');
	}

	my $ret_ar = [ ];
	for my $tag_hr (@$tags_ar) {
		next unless $tag_hr->{tagnameid} == $upvoteid || $tag_hr->{tagnameid} == $downvoteid;
		my $seclev = exists $admins->{ $tag_hr->{uid} }
			? $admins->{ $tag_hr->{uid} }{seclev}
			: 1;
		my $ret_hr = {
			affected_id =>	$tag_hr->{globjid},
			importance =>	$seclev >= 100 ? ($constants->{tagbox_fheditorpop_edmult} || 10) : 1,
		};
		# We identify this little chunk of importance by either
		# tagid or tdid depending on whether the source data had
		# the tdid field (which tells us whether feed_newtags was
		# "really" called via feed_deactivatedtags).
		if ($tag_hr->{tdid})	{ $ret_hr->{tdid}  = $tag_hr->{tdid}  }
		else			{ $ret_hr->{tagid} = $tag_hr->{tagid} }
		push @$ret_ar, $ret_hr;
	}
	return [ ] if !@$ret_ar;

	# Tags applied to globjs that have a firehose entry associated
	# are important.  Other tags are not.
	my %globjs = ( map { $_->{affected_id}, 1 } @$ret_ar );
	my $globjs_str = join(', ', sort keys %globjs);
	my $fh_globjs_ar = $self->sqlSelectColArrayref(
		'globjid',
		'firehose',
		"globjid IN ($globjs_str)");
	return [ ] if !@$fh_globjs_ar; # if no affected globjs have firehose entries, short-circuit out
	my %fh_globjs = ( map { $_, 1 } @$fh_globjs_ar );
	$ret_ar = [ grep { $fh_globjs{ $_->{affected_id} } } @$ret_ar ];

	main::tagboxLog("FHEditorPop->feed_newtags returning " . scalar(@$ret_ar));
	return $ret_ar;
}

sub feed_deactivatedtags {
	my($self, $tags_ar) = @_;
	main::tagboxLog("FHEditorPop->feed_deactivatedtags called: tags_ar='" . join(' ', map { $_->{tagid} } @$tags_ar) .  "'");
	my $ret_ar = $self->feed_newtags($tags_ar);
	main::tagboxLog("FHEditorPop->feed_deactivatedtags returning " . scalar(@$ret_ar));
	return $ret_ar;
}

sub feed_userchanges {
	my($self, $users_ar) = @_;
	my $constants = getCurrentStatic();
	main::tagboxLog("FHEditorPop->feed_userchanges called: users_ar='" . join(' ', map { $_->{tuid} } @$users_ar) .  "'");

	# XXX need to fill this in, and check FirstMover feed_userchanges too

	return [ ];
}

sub run {
	my($self, $affected_id, $options) = @_;
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
	}
	$popularity = $firehose->getEntryPopularityForColorLevel($color_level) + $extra_pop;

	# Add up nods and nixes.
	my $upvoteid   = $tagsdb->getTagnameidCreate($constants->{tags_upvote_tagname}   || 'nod');
	my $downvoteid = $tagsdb->getTagnameidCreate($constants->{tags_downvote_tagname} || 'nix');
	my $admins = $self->getAdmins();
	my $tags_ar = $tagboxdb->getTagboxTags($self->{tbid}, $affected_id, 0, $options);
	$tagsdb->addCloutsToTagArrayref($tags_ar, 'vote');
	my $udc_cache = { };
	for my $tag_hr (@$tags_ar) {
		next if $options->{starting_only};
		my $sign = 0;
		$sign =  1 if $tag_hr->{tagnameid} == $upvoteid   && !$options->{downvote_only};
		$sign = -1 if $tag_hr->{tagnameid} == $downvoteid && !$options->{upvote_only};
		next unless $sign;
		my $seclev = exists $admins->{ $tag_hr->{uid} }
			? $admins->{ $tag_hr->{uid} }{seclev}
			: 1;
		my $editor_mult = $seclev >= 100 ? ($constants->{tagbox_fheditorpop_edmult} || 10) : 1;
		my $extra_pop = $tag_hr->{total_clout} * $editor_mult * $sign;
		my $udc_mult = get_udc_mult($tag_hr->{created_at_ut}, $udc_cache);
#main::tagboxLog(sprintf("extra_pop for %d: %.6f * %.6f", $tag_hr->{tagid}, $extra_pop, $udc_mult));
		$extra_pop *= $udc_mult;
		$popularity += $extra_pop;
	}

	# If this is spam, its score goes way down.
	my $firehose_db = getObject('Slash::FireHose');
	if ($fhitem->{is_spam} eq 'yes' || $firehose_db->itemHasSpamURL($fhitem)) {
		my $max = defined($constants->{firehose_spam_score})
			? $constants->{firehose_spam_score}
			: -50;
		$popularity = $max if $popularity > $max;
	}

	# Set the corresponding firehose row to have this popularity.
	warn "Slash::Tagbox::FHEditorPop->run bad data, fhid='$fhid' db='$firehose_db'" if !$fhid || !$firehose_db;
	if ($options->{return_only}) {
		return $popularity;
	}
	main::tagboxLog(sprintf("FHEditorPop->run setting %d (%d) to %.6f", $fhid, $affected_id, $popularity));
	$firehose_db->setFireHose($fhid, { editorpop => $popularity });
}

{ # closure
my $udc_mult_cache = { };
sub get_udc_mult {
	my($time, $cache) = @_;

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
		main::tagboxLog(sprintf("get_udc_mult punting prev %d %.6f cur %d %.6f next %d %.6f time %d thru %.6f prevw %.6f curw %.6f nextw %.6f",
			$prevhour, $cache->{$prevhour}, $curhour, $cache->{$curhour}, $nexthour,  $cache->{$nexthour},
			$time, $thru_frac, $prevweight, $curweight, $nextweight));
		$udc = $constants->{tagbox_fheditorpop_udcbasis};
	}
	my $udc_mult = $constants->{tagbox_fheditorpop_udcbasis}/$udc;
	my $max_mult = $constants->{tagbox_fhpopularity2_maxudcmult} || 5;
	$udc_mult = $max_mult if $udc_mult > $max_mult;
#	main::tagboxLog(sprintf("get_udc_mult %0.3f time %d p %.3f c %.3f n %.3f th %.3f pw %.3f cw %.3f nw %.3f udc %.3f\n",
#		$udc_mult, $time, $prevudc, $curudc, $nextudc, $thru_frac, $prevweight, $curweight, $nextweight, $udc));
	$udc_mult_cache->{$time} = $udc_mult;
	return $udc_mult;
}
} # end closure

1;


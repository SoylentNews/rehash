#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Tagbox::Metamod;

=head1 NAME

Slash::Tagbox::Metamod - update user values based on metamoderation of their mods

=head1 SYNOPSIS

	my $tagbox_tcu = getObject("Slash::Tagbox::Metamod");
	my $feederlog_ar = $tagbox_tcu->feed_newtags($users_ar);
	$tagbox_tcu->run($affected_globjid);

=cut

use strict;

use Slash;
use Slash::DB;
use Slash::Utility::Environment;

use Data::Dumper;

our $VERSION = $Slash::Constants::VERSION;

use base 'Slash::Tagbox';

sub init {
        my($self) = @_;
        $self->SUPER::init() if $self->can('SUPER::init');

	my $constants = getCurrentStatic();
	my $tagsdb = getObject('Slash::Tags');
	$self->{upvoteid}   = $tagsdb->getTagnameidCreate($constants->{tags_upvote_tagname}   || 'nod');
	$self->{downvoteid} = $tagsdb->getTagnameidCreate($constants->{tags_downvote_tagname} || 'nix');
	$self->{metanodid}  = $tagsdb->getTagnameidCreate('metanod');
	$self->{metanixid}  = $tagsdb->getTagnameidCreate('metanix');
	$self->{care_ids} = [ $self->{upvoteid}, $self->{downvoteid}, $self->{metamodid}, $self->{metanixid} ];
	$self->{modup_ids} = [ ];
	$self->{moddown_ids} = [ ];
	$self->{metamodup_ids} = [   $self->{upvoteid},   $self->{metanodid} ];
	$self->{metamoddown_ids} = [ $self->{downvoteid}, $self->{metanixid} ];
	my $reasons = $constants->{reasons};
	for my $id (sort keys %$reasons) {
		next unless $reasons->{$id}{val}; # skip 'Normal'
		my $name = lc $reasons->{$id}{name};
		my $nameid = $tagsdb->getTagnameidCreate($name);
		push @{$self->{care_ids}}, $nameid;
		if ($reasons->{$id}{val} > 0) {
			push @{$self->{modup_ids}}, $nameid;
		} else {
			push @{$self->{moddown_ids}}, $nameid;
		}
	}

	1;
}

sub feed_newtags {
	my($self, $tags_ar) = @_;
	my $constants = getCurrentStatic();
	if (scalar(@$tags_ar) < 9) {
		main::tagboxLog("Metamod->feed_newtags called for tags '" . join(' ', map { $_->{tagid} } @$tags_ar) . "'");
	} else {
		main::tagboxLog("Metamod->feed_newtags called for " . scalar(@$tags_ar) . " tags " . $tags_ar->[0]{tagid} . " ... " . $tags_ar->[-1]{tagid});
	}
	my $tagsdb = getObject('Slash::Tags');

	# We care about nod and nix (the precursors to metamod and metanix),
	# metanod and metanix, and all moderations.

	my $ret_ar = [ ];
	for my $tag_hr (@$tags_ar) {
		next unless grep { $_ == $tag_hr->{tagnameid} } @{$self->{care_ids}};
		my $ret_hr = {
			affected_id =>	$tag_hr->{globjid},
			importance =>	1,
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
	# are important (because only comments in the hose are eligible
	# to be metamodded).  Other tags are not.
	my %globjs = ( map { $_->{affected_id}, 1 } @$ret_ar );
	my $globjs_str = join(', ', sort keys %globjs);
	my $fh_globjs_ar = $self->sqlSelectColArrayref(
		'globjid',
		'firehose',
		"globjid IN ($globjs_str)");
	return [ ] if !@$fh_globjs_ar; # if no affected globjs have firehose entries, short-circuit out
	my %fh_globjs = ( map { $_, 1 } @$fh_globjs_ar );
	$ret_ar = [ grep { $fh_globjs{ $_->{affected_id} } } @$ret_ar ];

	main::tagboxLog("Metamod->feed_newtags returning " . scalar(@$ret_ar));
	return $ret_ar;
}

sub feed_deactivatedtags {
	my($self, $tags_ar) = @_;
	main::tagboxLog("Metamod->feed_deactivatedtags called: tags_ar='" . join(' ', map { $_->{tagid} } @$tags_ar) .  "'");
	my $ret_ar = $self->feed_newtags($tags_ar);
	main::tagboxLog("Metamod->feed_deactivatedtags returning " . scalar(@$ret_ar));
	return $ret_ar;
}

sub feed_userchanges {
	my($self, $users_ar) = @_;
	my $constants = getCurrentStatic();
	main::tagboxLog("Metamod->feed_userchanges called: users_ar='" . join(' ', map { $_->{tuid} } @$users_ar) .  "'");

	# XXX need to fill this in

	return [ ];
}

sub run {
	my($self, $affected_id, $options) = @_;
	my $constants = getCurrentStatic();
	my $tagsdb = getObject('Slash::Tags');
	my $tagboxdb = getObject('Slash::Tagbox');
	my $firehose_db = getObject('Slash::FireHose');

	# Make sure the globjid indeed has a firehose entry.
	my $fhid = $firehose_db->getFireHoseIdFromGlobjid($affected_id);
	if (!$fhid) {
		warn "Metamod->run bad data, no fhid for '$affected_id'";
		return ;
	}

	# Get some basic information about the tag array we're processing.

	my $tag_ar = $tagboxdb->getTagboxTags($self->{tbid}, $affected_id, 0);
	my $prev_max = $self->get_maxtagid_seen($affected_id);
	my $new_max = $tag_ar->[-1]{tagid};

	# Do the hard work:  process the tag array twice, once for the
	# previous time (if any) this tagbox was run on this globj,
	# and once for now.  Calculate the difference between the two runs:
	# that is what must be applied this time around.

	my $new_delta = $self->get_delta($tag_ar, $new_max);
	if (!defined($new_delta)) {
		main::tagboxLog("Metamod->run no consensus yet on $fhid ($affected_id)");
		# Don't bother setting maxtagid seen.  When consensus is
		# achieved, it'll run from the start anyway.
		return ;
	}
	my $old_delta = $self->get_delta($tag_ar, $prev_max);
	my $change_delta = $self->get_change($old_delta, $new_delta);

	if ($options->{return_only}) {
		return $change_delta;
	}

	# Apply the change and get a textual description of what was done;
	# mark it as having been done, and log it.

	my $change_str = $self->apply_change($change_delta);
	$self->set_maxtagid_seen($new_max);
	main::tagboxLog("Metamod->run change for $fhid ($affected_id) from $prev_max to $new_max: $change_str");
}

sub get_maxtagid_seen {
	my($self, $globjid) = @_;
	return 0 if !$globjid;
	return $self->sqlSelect('max_tagid_seen', 'tagbox_metamod_history',
		"globjid=$globjid") || 0;
}

sub set_maxtagid_seen {
	my($self, $globjid, $max_tagid) = @_;
	return 0 if !$globjid;
	return $self->sqlReplace('tagbox_metamod_history', {
		globjid		=> $globjid,
		max_tagid_seen	=> $max_tagid,
		-last_update	=> 'NOW()',
	});
}

# Given a tag array, and some basic information about how to process it,
# figure out which users require which values in their accounts changed.
# Note that this may be called before consensus is achieved in which
# case an empty delta is returned.

sub get_delta {
	my($self, $tag_ar, $max) = @_;
	my @tags = grep { $_->{tagid} <= $max } @$tag_ar;
	my($upfrac, $dissenters) = $self->calc_agreement(\@tags);
	return undef if !defined($upfrac);

	my $delta = { };

	my $metamod_reader = getObject('Slash::Metamod::Static', { db_type => 'reader' });
	my $up_csq = $metamod_reader->getM2Consequences($upfrac);
	my $down_csq = $metamod_reader->getM2Consequences(1 - $upfrac);
	for my $tag_hr (@tags) {
		my $id = $tag_hr->{tagnameid};
		next unless grep { $_ == $id } @{$self->{care_ids}};
		next if $tag_hr->{inactivated}; # XXX should check how long it was active, penalties may still apply
		my $uid = $tag_hr->{uid};
		for my $key (qw(
			tokens karma
			up_fair down_fair up_unfair down_unfair
			m2voted_majority m2voted_lonedissent
		)) {
			$delta->{$uid}{$key} ||= 0;
		}
		if (grep { $_ == $id } @{$self->{modup_ids}}) {
			$delta->{$uid}{tokens} += $up_csq->{m1_tokens};
			$delta->{$uid}{karma}  += $up_csq->{m1_karma};
			   if ($upfrac > 0.5) { ++$delta->{$uid}{up_fair} }
			elsif ($upfrac < 0.5) { ++$delta->{$uid}{up_unfair} }
		} elsif (grep { $_ == $id } @{$self->{moddown_ids}}) {
			$delta->{$uid}{tokens} += $down_csq->{m1_tokens};
			$delta->{$uid}{karma}  += $down_csq->{m1_karma};
			   if ($upfrac > 0.5) { ++$delta->{$uid}{down_unfair} }
			elsif ($upfrac < 0.5) { ++$delta->{$uid}{down_fair} }
		} elsif (grep { $_ == $id } @{$self->{metamodup_ids}}) {
			   if ($upfrac > 0.5) { $delta->{$uid}{tokens} += $up_csq->{m2_fair_tokens};
						++$delta->{$uid}{m2voted_majority} }
			elsif ($upfrac < 0.5) { $delta->{$uid}{tokens} += $down_csq->{m2_fair_tokens};
						++$delta->{$uid}{m2voted_lonedissent} if $dissenters < 2 }
		} elsif (grep { $_ == $id } @{$self->{metamoddown_ids}}) {
			   if ($upfrac < 0.5) { $delta->{$uid}{tokens} += $down_csq->{m2_fair_tokens};
						++$delta->{$uid}{m2voted_majority} }
			elsif ($upfrac > 0.5) { $delta->{$uid}{tokens} += $up_csq->{m2_fair_tokens};
						++$delta->{$uid}{m2voted_lonedissent} if $dissenters < 2 }
		}
	}
	return $delta;
}

# Taken from plugins/Metamod/Static/Static.pm

sub getM2Consequences {
	my($self, $frac) = @_;
	my $constants = getCurrentStatic();
	my $c = $constants->{m2_consequences};
	for my $ckey (sort { $a <=> $b } keys %$c) {
		if ($frac <= $ckey) {
			my $retval = { };
			my @vals = @{$c->{$ckey}};
			for my $key (qw( m2_fair_tokens m2_unfair_tokens m1_tokens m1_karma )) {
				$retval->{$key} = shift @vals;
			}
			return $retval;
		}
	}
	return undef;
}

# Given two deltas, get the change between them.

sub get_change {
	my($self, $old_delta, $new_delta) = @_;
	my $change_delta = { };
	$old_delta ||= { };
	$new_delta ||= { };
	my %all_uids = map { $_, 1 } (keys(%$old_delta), keys(%$new_delta));
	for my $uid (keys %all_uids) {
		my $old = $old_delta->{$uid} || { };
		my $new = $new_delta->{$uid} || { };
		my %all_fields = map { $_, 1 } (keys(%$old), keys(%$new));
		for my $field (keys %all_fields) {
			my $diff = ($new->{$field} || 0) - ($old->{$field} || 0);
			if ($diff) {
				$change_delta->{$uid} ||= { };
				$change_delta->{$uid}{$field} = sprintf("%+.6f", $diff);
			}
		}
	}
	return $change_delta;
}

sub apply_change {
	my($self, $change_delta) = @_;
	$change_delta ||= { };
	for my $uid (sort { $a <=> $b } keys %$change_delta) {
		my $update_hr = { };
		# No fancy random application of rounding (yet).
		for my $field (qw( tokens karma
			up_fair down_fair up_unfair down_unfair
			m2voted_up_fair m2voted_down_fair
			m2voted_up_unfair m2voted_down_unfair
			m2voted_majority m2voted_lonedissent
		)) {
			next unless $change_delta->{$uid}{$field};
			$update_hr->{"-$field"} = "ROUND($field $change_delta->{$uid}{$field})";
		}
		my $rows = $self->setUser($uid, $update_hr);
		main::tagboxLog("Metamod->run changed $rows rows for $uid: " . join(" ", sort keys %$update_hr));
	}
}

# Return two numbers:  the fraction of upvotes (0.0 = total agreement on down,
# 1.0 = total agreement on up, 0.5 = exactly split) and the number of dissenters
# in the minority.  If not enough votes have been cast yet, return (undef,undef).

sub calc_agreement {
	my($self, $tag_ar) = @_;
	my $constants = getCurrentStatic();
	my $adminmult = $constants->{tagbox_metamod_adminmult} || 10;
	my $admins = $self->getAdmins();
	my($modc, $metac) = (0, 0);
	my($upc, $downc) = (0, 0);
	my($upvotes, $downvotes) = (0, 0);
	for my $tag_hr (@$tag_ar) {
		next if $tag_hr->{inactivated};
		my $user = $self->getUser($tag_hr->{uid});
		my $is_admin = $admins->{$tag_hr->{uid}} ? 1 : 0;
		next if !$is_admin && $user->{tokens} < $constants->{m2_mintokens};
		my $mult = $is_admin ? $adminmult : 1;
		my $modfrac = $constants->{tagbox_metamod_modfrac} || 0.1;
		my $tnid = $tag_hr->{tagnameid};
		# A metamod up or down counts as 1 full vote in that direction.
		   if (grep { $tnid == $_ } @{$self->{metamodup_ids}}  ) { ++$metac; ++$upc;   $upvotes   += $mult }
		elsif (grep { $tnid == $_ } @{$self->{metamoddown_ids}}) { ++$metac; ++$downc; $downvotes += $mult }
		# A regular mod up or down counts as some fraction of a vote in
		# that direction.
		elsif (grep { $tnid == $_ } @{$self->{modup_ids}}  ) { ++$modc; ++$upc;   $upvotes   += $mult * $modfrac }
		elsif (grep { $tnid == $_ } @{$self->{moddown_ids}}) { ++$modc; ++$downc; $downvotes += $mult * $modfrac }
	}
	# If there aren't enough votes, there's no agreement.
	return (undef,undef) if $upvotes+$downvotes < 3;
	my $upfrac = $upvotes/($upvotes+$downvotes);
	my $dissenters = ($upfrac >= 0.5) ? $downc : $upc;
	return ($upfrac, $dissenters);
}

1;


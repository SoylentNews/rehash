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

our $VERSION = $Slash::Constants::VERSION;

use base 'Slash::Tagbox';

sub init {
        my($self) = @_;
        return 0 if ! $self->SUPER::init();

	my $constants = getCurrentStatic();
	my $tagsdb = getObject('Slash::Tags');
	$self->{metanodid}  = $tagsdb->getTagnameidCreate('metanod');
	$self->{metanixid}  = $tagsdb->getTagnameidCreate('metanix');

	# XXX set these 4 to be hashes and change all the grep{}s to hash lookups
	$self->{modup_ids} = [ ];
	$self->{moddown_ids} = [ ];
	$self->{metamodup_ids} = [   $self->{nodid}, $self->{metanodid} ];
	$self->{metamoddown_ids} = [ $self->{nixid}, $self->{metanixid} ];

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
		if ($self->{reasons}{$id}{val} > 0) {
			push @{$self->{modup_ids}}, $tagnameid;
		} elsif ($self->{reasons}{$id}{val} < 0) {
			push @{$self->{moddown_ids}}, $tagnameid;
		}
	}

	1;
}

sub init_tagfilters {
	my($self) = @_;

	# XXX should check how long tags were active, penalties may still apply
	$self->{filter_activeonly} = 1;

	$self->{filter_firehoseonly} = 1;
	$self->{filter_gtid} = $self->getGlobjTypes()->{comments};

        $self->{filter_tagnameid} = [ ];
        for my $tagnameid (keys %{ $self->{reason_tagnameid} }) {
                push @{ $self->{filter_tagnameid} }, $tagnameid;
        }
        for my $tagname (qw( nod nix metanod metanix )) {
                push @{ $self->{filter_tagnameid} }, $self->{"${tagname}id"};
        }

}

sub get_affected_type	{ 'globj' }
sub get_clid		{ 'moderate' }

sub run_process {
	my($self, $affected_id, $tags_ar, $options) = @_;
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

#	my $tags_ar = $tagboxdb->getTagboxTags($self->{tbid}, $affected_id, 0);
	if (!@$tags_ar) {
		$self->info_log("error, empty tags_ar for %d, skipping", $affected_id);
		return ;
	}

	my $prev_max = $self->get_maxtagid_seen($affected_id);
	my $new_max = $tags_ar->[-1]{tagid};

	# Do the hard work:  process the tag array twice, once for the
	# previous time (if any) this tagbox was run on this globj,
	# and once for now.  Calculate the difference between the two runs:
	# that is what must be applied this time around.

	my $new_delta = $self->get_delta($tags_ar, $new_max);
	if (!defined($new_delta)) {
		$self->info_log("no consensus yet on $fhid ($affected_id)");
		# Don't bother setting maxtagid seen.  When consensus is
		# achieved, it'll run from the start anyway.
		return ;
	}
	my $old_delta = $self->get_delta($tags_ar, $prev_max);
	my $change_delta = $self->get_change($old_delta, $new_delta);

	if ($options->{return_only}) {
		return $change_delta;
	}

	# Apply the change and get a textual description of what was done;
	# mark it as having been done, and log it.

	my $change_str = $self->apply_change($change_delta);
	$self->set_maxtagid_seen($affected_id, $new_max);
	$self->info_log("change for %d (%d) from %f to %f: %s",
		$fhid, $affected_id, $prev_max, $new_max, $change_str);
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
	my($self, $tags_ar, $max) = @_;
	my @tags = grep { $_->{tagid} <= $max } @$tags_ar;
	my($upfrac, $dissenters) = $self->calc_agreement(\@tags);
	return undef if !defined($upfrac);

	my $delta = { };

	my $up_csq = $self->getM2Consequences($upfrac);
	my $down_csq = $self->getM2Consequences(1 - $upfrac);
	for my $tag_hr (@tags) {
		my $id = $tag_hr->{tagnameid};
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
	my($self, $tags_ar) = @_;
	my $constants = getCurrentStatic();
	my $adminmult = $constants->{tagbox_metamod_adminmult} || 10;
	my $admins = $self->getAdmins();
	my($modc, $metac) = (0, 0);
	my($upc, $downc) = (0, 0);
	my($upvotes, $downvotes) = (0, 0);
	for my $tag_hr (@$tags_ar) {
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


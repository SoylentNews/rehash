# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Tagbox;

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;
use Slash::DB::Utility;
use Apache::Cookie;
use vars qw($VERSION);
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

use Data::Dumper;

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# FRY: And where would a giant nerd be? THE LIBRARY!

#################################################################
sub new {
	my($class, $user) = @_;
	my $self = {};

	my $plugin = getCurrentStatic('plugin');
	return unless $plugin->{Tags};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect();

	return $self;
}

#################################################################

# Return information about tagboxes, from the 'tagboxes' and
# 'tagbox_userkeyregexes' tables.
#
# If neither $id nor $field is specified, returns an arrayref of
# hashrefs, where each hashref has keys and values from the
# 'tagboxes' table, and additionally has the 'userkeyregexes' key
# with its value being an arrayref of (plain string) regexes from
# the tagbox_userkeyregexes.userkeyregex column.
#
# If $id is a true value, it must be a string, either the tbid or
# the name of a tagbox.  In this case only the hashref for that
# one tagbox's id is returned.
#
# If $field is a true value, it may be either a single string or
# an arrayref of strings.  In this case each hashref (or the one
# hashref) will have only the field(s) specified.  Requesting
# only the fields needed can have a very significant performance
# improvement (specifically, if the variant fields
# last_tagid_logged, last_userchange_logged, or last_run_completed
# are not needed, it will be much faster not to request them).

{ # closure XXX this won't work with multiple sites, fix
my $tagboxes = undef;
sub getTagboxes {
	my($self, $id, $field, $options) = @_;
	my @fields = ( );
	if ($field) {
		@fields = ref($field) ? @$field : ($field);
	}
	my %fields = ( map { ($_, 1) } @fields );

	# Update the data to current if necessary;  load it all if necessary.
	if ($tagboxes) {
		# The data in these four columns is never cached.  Only load it
		# from the DB if it is requested (i.e. if $field was empty so
		# all fields are needed, or if $field is an array with any).
		if (!@fields
			|| $fields{last_run_completed}
			|| $fields{last_tagid_logged}
			|| $fields{last_tdid_logged}
			|| $fields{last_tuid_logged}
		) {
			my $new_hr = $self->sqlSelectAllHashref('tbid',
				'tbid, last_run_completed,
				 last_tagid_logged, last_tdid_logged, last_tuid_logged',
				'tagboxes');
			for my $hr (@$tagboxes) {
				$hr->{last_run_completed} = $new_hr->{$hr->{tbid}}{last_run_completed};
				$hr->{last_tagid_logged}  = $new_hr->{$hr->{tbid}}{last_tagid_logged};
				$hr->{last_tuid_logged}   = $new_hr->{$hr->{tbid}}{last_tuid_logged};
				$hr->{last_tdid_logged}   = $new_hr->{$hr->{tbid}}{last_tdid_logged};
			}
		}
	} else {
		$tagboxes = $self->sqlSelectAllHashrefArray('*', 'tagboxes', '', 'ORDER BY tbid');
		my $regex_ar = $self->sqlSelectAllHashrefArray('name, userkeyregex',
			'tagbox_userkeyregexes',
			'', 'ORDER BY name, userkeyregex');
		for my $hr (@$tagboxes) {
			$hr->{userkeyregexes} = [
				map { $_->{userkeyregex} }
				grep { $_->{name} eq $hr->{name} }
				@$regex_ar
			];
		}
		# the getObject() below calls new() on each tagbox class,
		# which calls getTagboxes() with no_objects set.
		if (!$options->{no_objects}) {
#print STDERR "tagboxes a: " . Dumper($tagboxes);
			for my $hr (@$tagboxes) {
				my $object = getObject("Slash::Tagbox::$hr->{name}");
				$hr->{object} = $object;
			}
#print STDERR "tagboxes b: " . Dumper($tagboxes);
			# If any object failed to be created for some reason,
			# that tagbox never gets returned.
			$tagboxes = [ grep { $_->{object} } @$tagboxes ];
		}
	}
#print STDERR "tagboxes c: " . Dumper($tagboxes);

	# If one or more fields were asked for, then some of the
	# data in the other fields may not be current since we
	# may have skipped loading the last_* fields.  Make a
	# copy of the data so the $tagboxes closure is not
	# affected, then delete all but the fields requested
	# (returning stale data could lead to nasty bugs).
	my $tb = [ @$tagboxes ];

	# If just one specific tagbox was requested, take out all the
	# others.
	if ($id) {
		my @tb_tmp;
#print STDERR "tb: " . Dumper($tb);
		if ($id =~ /^\d+$/) {
			@tb_tmp = grep { $_->{tbid} == $id } @$tb;
		} else {
			@tb_tmp = grep { $_->{name} eq $id } @$tb;
		}
		return undef if !@tb_tmp;
		$tb = [ $tb_tmp[0] ];
	}

	# Clone the data so we don't affect the $tagboxes persistent
	# closure variable.
	my $tbc = [ ];
	for my $tagbox (@$tb) {
		my %tagbox_hash = %$tagbox;
		push @$tbc, \%tagbox_hash;
	}

	# If specific fields were requested, go through the data
	# and strip out the fields that were not requested.
	if (@fields) {
		for my $tagbox (@$tbc) {
			my @stale = grep { !$fields{$_} } keys %$tagbox;
			delete @$tagbox{@stale};
		}
	}

	# If one specific tagbox was requested, return its hashref.
	# Otherwise return an arrayref of all their hashrefs.
	return $tbc->[0] if $id;
	return $tbc;
}
}

{ # closure XXX this won't work with multiple sites, fix
my $userkey_masterregex;
sub userKeysNeedTagLog {
	my($self, $keys_ar) = @_;

	if (!defined $userkey_masterregex) {
		my $tagboxes = $self->getTagboxes();
		my @regexes = ( );
		for my $tagbox (@$tagboxes) {
			for my $regex (@{$tagbox->{userkeyregexes}}) {
				push @regexes, $regex;
			}
		}
		if (@regexes) {
			my $r = '(' . join('|', map { "($_)" } @regexes) . ')';
			$userkey_masterregex = qr{$r};
		} else {
			$userkey_masterregex = '';
		}
	}

	# If no tagboxes have regexes, nothing can match.
	return if !$userkey_masterregex;

	my @update_keys = ( );
	for my $k (@$keys_ar) {
		push @update_keys, $k if $k =~ $userkey_masterregex;
	}
	return @update_keys;
}
}

sub logDeactivatedTags {
	my($self, $deactivated_tagids) = @_;
	return 0 if !$deactivated_tagids;
	my $logged = 0;
	for my $tagid (@$deactivated_tagids) {
		$logged += $self->sqlInsert('tags_deactivated',
			{ tagid => $tagid });
	}
	return $logged;
}

sub logUserChange {
	my($self, $uid, $name, $old, $new) = @_;
	return $self->sqlInsert('tags_userchange', {
		-created_at =>	'NOW()',
		uid =>		$uid,
		user_key =>	$name,
		value_old =>	$old,
		value_new =>	$new,
	});
}

sub getMostImportantTagboxAffectedIDs {
	my($self, $num) = @_;
	$num ||= 10;
	return $self->sqlSelectAllHashrefArray(
		'tagboxes.tbid,
		 affected_id,
		 MAX(tagid) AS max_tagid,
		 MAX(tdid)  AS max_tdid,
		 MAX(tuid)  AS max_tuid,
		 SUM(importance*weight) AS sum_imp_weight',
		'tagboxes, tagboxlog_feeder',
		'tagboxes.tbid=tagboxlog_feeder.tbid',
		"GROUP BY tagboxes.tbid, affected_id
		 HAVING sum_imp_weight >= 1
		 ORDER BY sum_imp_weight DESC LIMIT $num");
}

sub getTagboxTags {
	my($self, $tbid, $affected_id, $extra_levels, $options) = @_;
	$extra_levels ||= 0;
	my $type = $options->{type} || $self->getTagboxes($tbid, 'affected_type')->{affected_type};
#print STDERR "getTagboxTags($tbid, $affected_id, $extra_levels), type=$type\n";
	my $hr_ar = [ ];
	my $colname = ($type eq 'user') ? 'uid' : 'globjid';
	my $max_time_clause = '';
	if ($options->{max_time_noquote}) {
		$max_time_clause = " AND created_at <= $options->{max_time_noquote}";
	} elsif ($options->{max_time}) {
		my $mtq = $self->sqlQuote($options->{max_time});
		$max_time_clause = " AND created_at <= $mtq";
	}
	$hr_ar = $self->sqlSelectAllHashrefArray(
		'*, UNIX_TIMESTAMP(created_at) AS created_at_ut',
		'tags',
		"$colname=$affected_id $max_time_clause",
		'ORDER BY tagid');

	# If extra_levels were requested, fetch them.  
	my $old_colname = $colname;
	while ($extra_levels) {
#print STDERR "el $extra_levels\n";
		my $new_colname = ($old_colname eq 'uid') ? 'globjid' : 'uid';
		my %new_ids = ( map { ($_->{$new_colname}, 1) } @$hr_ar );
		my $new_ids = join(',', sort { $a <=> $b } keys %new_ids);
#print STDERR "hr_ar=" . scalar(@$hr_ar) . " with $colname=$affected_id\n";
		$hr_ar = $self->sqlSelectAllHashrefArray(
			'*, UNIX_TIMESTAMP(created_at) AS created_at_ut',
			'tags',
			"$new_colname IN ($new_ids) $max_time_clause",
			'ORDER BY tagid');
#print STDERR "new_colname=$new_colname new_ids=" . scalar(keys %new_ids) . " (" . substr($new_ids, 0, 20) . ") hr_ar=" . scalar(@$hr_ar) . "\n";
		$old_colname = $new_colname;
		--$extra_levels;
#print STDERR "el $extra_levels\n";
	}
	$self->addGlobjEssentialsToHashrefArray($hr_ar);
	return $hr_ar;
}

sub addFeederInfo {
	my($self, $tbid, $info_hr) = @_;
	$info_hr->{-created_at} = 'NOW()';
	$info_hr->{tbid} = $tbid;
	die "attempt to create tagboxlog_feeder row with no non-NULL ids: " . Dumper($info_hr)
		if !( $info_hr->{tagid} || $info_hr->{tdid} || $info_hr->{tuid} );
	return $self->sqlInsert('tagboxlog_feeder', $info_hr);
}

sub markTagboxLogged {
	my($self, $tbid, $update_hr) = @_;
	$self->sqlUpdate('tagboxes', $update_hr, "tbid=$tbid");
}

sub markTagboxRunComplete {
	my($self, $affected_hr) = @_;

	my $delete_clause = "tbid=$affected_hr->{tbid} AND affected_id=$affected_hr->{affected_id}";
	my @id_clauses = ( );
	push @id_clauses, "tagid <= $affected_hr->{max_tagid}" if $affected_hr->{max_tagid};
	push @id_clauses, "tdid  <= $affected_hr->{max_tdid}"  if $affected_hr->{max_tdid};
	push @id_clauses, "tuid  <= $affected_hr->{max_tuid}"  if $affected_hr->{max_tuid};
	die "markTagboxRunComplete called with no max ids: " . Dumper($affected_hr)
		if !@id_clauses;
	my $id_clause = join(' OR ', @id_clauses);
	$delete_clause .= " AND ($id_clause)";

	$self->sqlDelete('tagboxlog_feeder', $delete_clause);
	$self->sqlUpdate('tagboxes',
		{ -last_run_completed => 'NOW()' },
		"tbid=$affected_hr->{tbid}");
}

#################################################################
sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if $self->{_dbh} && !$ENV{GATEWAY_INTERFACE};
}

1;

=head1 NAME

Slash::Tagbox - Slash Tagbox module

=head1 SYNOPSIS

	use Slash::Tagbox;

=head1 DESCRIPTION

This contains all of the routines currently used by Tagbox.

=head1 SEE ALSO

Slash(3).

=cut


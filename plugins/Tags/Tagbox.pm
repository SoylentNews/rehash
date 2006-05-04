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

# XXX need to cache this, except for last_tagid_logged/last_run_completed
sub getTagboxes {
	my($self, $id) = @_;
	my $ar = $self->sqlSelectAllHashrefArray('*', 'tagboxes');
	if (!$id) {
		return $ar;
	} elsif ($id =~ /^\d+$/) {
		my @tb = grep { $_->{tbid} == $id } @$ar;
		return @tb ? $tb[0] : undef;
	} else {
		my @tb = grep { $_->{name} eq $id } @$ar;
		return @tb ? $tb[0] : undef;
	}
}

sub getMostImportantTagboxAffectedIDs {
	my($self, $num) = @_;
	$num ||= 10;
	return $self->sqlSelectAllHashrefArray(
		'tagboxes.tbid,
		 affected_id,
		 MAX(tagid) AS max_tagid,
		 SUM(importance*weight) AS sum_imp_weight',
		'tagboxes, tagbox_feederlog',
		'tagboxes.tbid=tagbox_feederlog.tbid',
		"GROUP BY tagboxes.tbid, affected_id
		 ORDER BY sum_imp_weight DESC LIMIT $num");
}

sub getTagboxTags {
	my($self, $tbid, $affected_id, $extra_levels) = @_;
	$extra_levels ||= 0;
	my $type = $self->getTagboxes($tbid)->{affected_type};
	my $hr_ar = [ ];
	my $colname = ($type eq 'user') ? 'uid' : 'globjid';
	$hr_ar = $self->sqlSelectAllHashrefArray(
		'*',
		'tags',
		"$colname=$affected_id",
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
			'*',
			'tags',
			"$new_colname IN ($new_ids)",
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
	my($self, $tbid, $tagid, $affected_id, $importance) = @_;
	return $self->sqlInsert('tagbox_feederlog', {
		-tfid =>	'NULL',
		-created_at =>	'NOW()',
		tbid =>		$tbid,
		tagid =>	$tagid,
		affected_id =>	$affected_id,
		importance =>	$importance,
	});
}

sub markTagboxLogged {
	my($self, $tbid, $last_tagid_logged) = @_;
	$self->sqlUpdate('tagboxes',
		{ last_tagid_logged => $last_tagid_logged },
		"tbid=$tbid");
}

sub markTagboxRunComplete {
	my($self, $tbid, $affected_id, $max_tagid) = @_;
#print STDERR "markTagboxRunComplete: tbid=$tbid aff_id=$affected_id max=$max_tagid\n";
	$self->sqlDelete('tagbox_feederlog',
		"tbid=$tbid AND affected_id=$affected_id
		 AND tagid <= $max_tagid");
	$self->sqlUpdate('tagboxes',
		{ -last_run_completed => 'NOW()' },
		"tbid=$tbid");
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

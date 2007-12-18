# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::TagDataView;

=head1 NAME

Slash::TagDataView - Perl extension for TagDataView


=head1 SYNOPSIS

	use Slash::TagDataView;


=head1 DESCRIPTION

LONG DESCRIPTION.


=head1 EXPORTED FUNCTIONS

=cut

use strict;

use Slash;
use Slash::Utility::Environment;

use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub getGlobjidsMissingHistory {
	my($self, $max_mins, $max_min_incrs, $max_globjids) = @_;
	return $self->sqlSelectColArrayref(
                'firehose.globjid, COUNT(*) AS c',
                'firehose LEFT JOIN firehose_history USING (globjid)',
                "createtime BETWEEN DATE_SUB(NOW(), INTERVAL 1 MONTH)
                        AND DATE_SUB(NOW(), INTERVAL $max_mins MINUTE)",
                "GROUP BY firehose.globjid
                 HAVING c < $max_min_incrs
                 ORDER BY c, globjid DESC
                 LIMIT $max_globjids");
}

sub getUniqueTagCount {
	my($self, $type, $secs, $options) = @_;
	$type ||= 'tags';
	$secs ||= 3600;
	my $constants = getCurrentStatic();
	my $tagsdb = getObject('Slash::Tags') or return undef;
	my $upvoteid   = $tagsdb->getTagnameidCreate($constants->{tags_upvote_tagname}   || 'nod');
	my $downvoteid = $tagsdb->getTagnameidCreate($constants->{tags_downvote_tagname} || 'nix');

	my $tables = 'tags';
	my $count_clause = '*';
	my $where_clause = "created_at >= DATE_SUB(NOW(), INTERVAL $secs SECOND)";
	$where_clause .= ' AND inactivated IS NULL' unless $options->{include_inactive};
	if ($options->{only_firehose}) {
		$tables .= ', firehose';
		$where_clause .= ' AND tags.globjid=firehose.globjid';
	}

	   if ($type eq 'tags') {										}
	   if ($type eq 'users') {	$count_clause = 'DISTINCT tags.uid';					}
	elsif ($type eq 'tagnames') {	$count_clause = 'DISTINCT tagnameid';					}
	elsif ($type eq 'objects') {	$count_clause = 'DISTINCT tags.globjid';				}
	elsif ($type eq 'votes') {		$where_clause .= " AND tagnameid IN ($downvoteid, $upvoteid)";	}
	elsif ($type eq 'upvotes') {		$where_clause .= " AND tagnameid=$upvoteid";			}
	elsif ($type eq 'downvotes') {		$where_clause .= " AND tagnameid=$downvoteid";			}

	return $self->sqlSelect("COUNT($count_clause)", $tables, $where_clause);
}

# Does a raw count of tags without regard to clout.
# It's the caller's responsibility to strip out any data that
# should not be visible to the user, e.g. by calling
# checkStoryViewable() on each story.

sub getMostNonnegativeTaggedGlobjs {
	my($self, $options) = @_;
	my $constants = getCurrentStatic();
	my $lookback_secs = $options->{lookback_secs} || 86400;
	my $count = $options->{count} || 10;
	my $globj_types = $options->{globj_types} || 0;

	my $types_clause = '';
	if ($globj_types) {
		my $types_ar = $globj_types;
		$types_ar = [ split /,/, $types_ar ] if !ref($types_ar);
		my $types = $self->getGlobjTypes();
		my $typeids = join ',', grep $_, map {
			$_ =~ /^\d+$/ && defined $types->{$_}
				? $_
				: $types->{$_}
		} @$types_ar;
		$types_clause = " AND gtid IN ($typeids)";
	}

	my $tagsdb = getObject('Slash::Tags');
	my $tagnames = $tagsdb->getNegativeTags;
	$tagnames = ['nix'] unless @$tagnames;
	#$constants->{tags_negative_tagnames} || $constants->{tags_downvote_tagname} || 'nix';
	my $tagnameids = join ',', grep $_, map {
		s/\s+//g;
		$tagsdb->getTagnameidFromNameIfExists($_)
	} @$tagnames; # split /,/, $tagnames;
	my $tagnameid_clause = '';
	$tagnameid_clause = " AND tagnameid NOT IN ($tagnameids)" if $tagnameids;

	my $hr_ar = $self->sqlSelectAllHashrefArray(
		'tags.globjid, COUNT(*) AS c',
		'tags, globjs',
		"tags.globjid=globjs.globjid AND created_at >= DATE_SUB(NOW(), INTERVAL $lookback_secs SECOND)
		 $tagnameid_clause $types_clause",
		"GROUP BY tags.globjid ORDER BY c DESC, tags.globjid DESC LIMIT $count");
	$self->addGlobjEssentialsToHashrefArray($hr_ar);

	return $hr_ar;
}

1;

__END__

=head1 SEE ALSO

Slash(3).

=head1 VERSION

$Id$


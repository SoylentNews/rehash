# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Rating;

use strict;
use DBIx::Password;
use Slash;
use Slash::Constants;
use Slash::Utility;
use Slash::DB::Utility;

use vars qw($VERSION @EXPORT);
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

#Right, this is not needed at the moment but will be in the near future
sub new {
	my($class, $user) = @_;
	my $self = {};

	my $plugin = getCurrentStatic('plugin');
	return unless $plugin->{'Rating'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;

	return $self;
}

sub create_comment_vote {
	my ($data) = @_;
	my $slashdb = getCurrentDB();
	my $ratings_reader = getObject('Slash::Rating', { db_type => 'reader' });
	my $form = getCurrentForm();
	my $comment = $data->{comment};

	return unless defined $form->{comment_vote};

	my $active = "yes";
	my $val = 0;
	if ($form->{comment_vote} =~/^\d+$/) {
		$val = $form->{comment_vote};
	} else {
		$active = "no";
	}
	
	my $count = $ratings_reader->getDiscussionVoteCountForUser($comment->{uid}, $comment->{sid});
	$active = "no" if $count;
	
	my $comment_vote = {
		val  => $val,
		cid => $comment->{cid},
		active => $active
	};
	
	my $success = $slashdb->sqlInsert("comment_vote", $comment_vote);

}

sub getUniqueDiscussionsBetweenCids {
	my($self, $start_cid, $end_cid) = @_;
	my $discussions = $self->sqlSelectColArrayref(
		"DISTINCT comments.sid",
		"comments, comment_vote",
		"comments.cid=comment_vote.cid
		 AND comments.cid BETWEEN $start_cid AND $end_cid");
	return $discussions;
}

sub getDiscussionVoteCountForUser {
	my ($self, $uid, $sid) = @_;
	my $uid_q = $self->sqlQuote($uid);
	my $sid_q = $self->sqlQuote($sid);
	return $self->sqlCount("comments,comment_vote", "comments.cid=comment_vote.cid AND active='yes' AND uid=$uid_q AND sid=$sid_q");
}

sub updateDiscussionRatingStats {
	my($self, $discussions) = @_;
	return 0 unless $discussions && @$discussions;
	my $sid_clause = "sid IN (" . join(",", @$discussions) . ")";
	my $hr = $self->sqlSelectAllHashref(
		[qw( sid active )],
		"sid, active, COUNT(*) AS c, AVG(val) AS avgval",
		"comments, comment_vote",
		"comments.cid=comment_vote.cid
		 AND $sid_clause",
		"GROUP BY sid, active");
	
	my $rows = 0;
	for my $sid (keys %$hr) {
		my $sid_hr = $hr->{$sid};
		my $replace_hr = { discussion => $sid };
		$replace_hr->{active_votes} =  $sid_hr->{yes}{c} || 0;
		$replace_hr->{total_votes}  = ($sid_hr->{yes}{c} || 0) + ($sid_hr->{no}{c} || 0);
		$replace_hr->{avg_rating}   = $sid_hr->{yes}{avgval} || undef;
		$rows += $self->sqlReplace("discussion_rating", $replace_hr);
	}
	return $rows;
}

sub getCommentVoteForCid {
	my ($self, $cid) = @_;
	my $cid_q = $self->sqlQuote($cid);
	return $self->sqlSelectHashref("comment_vote", "cid=$cid_q");
}

sub getDiscussionRating {
	my ($self, $sid) = @_;
	my $siq_q = $self->sqlQuote($sid);
	return $self->sqlSelectHashref("discussion_rating", "discussion=$cid_q");
	
}

sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if !$ENV{GATEWAY_INTERFACE} && $self->{_dbh};
}

1;

__END__

# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Slash::Rating - Rating system

=head1 SYNOPSIS

	use Slash::Rating;

=head1 DESCRIPTION

This allows user reviews/ratings to accompany a disucssion.  Users vote/rate the discussion when
they create a comment.  The averages are then totalled by a task for display as you choose.

Blah blah blah.

=head1 AUTHOR

Tim Vroom

=head1 SEE ALSO

perl(1).

=cut

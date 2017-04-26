# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

# XXX right now we have checks for moderation in many places.
# we must consolidate as much as possible. -- pudge
# * Slash::ResKey::Checks::Moderate::doCheck()
# * Slash::Moderation...?
# * Slash::Moderation::moderateComment()
# * Slash::_moderateCheck()
# * Slash::_can_mod()

# Also:
# * comments.pl::moderate()

package Slash::ResKey::Checks::Moderate;

use warnings;
use strict;

use Slash::Utility;
use Slash::Constants ':reskey';

use base 'Slash::ResKey::Key';

our $VERSION = $Slash::Constants::VERSION;

sub doCheck {
	my($self) = @_;

	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	return(RESKEY_FAILURE, ['no comment']) if !$form->{cid} || !$form->{sid};

	return(RESKEY_FAILURE, ['no moderation']) unless $constants->{m1};

	return(RESKEY_FAILURE, ['no db']) unless dbAvailable("write_comments");

	my $mod_reader = getObject("Slash::$constants->{m1_pluginname}", { db_type => 'reader' });
	return(RESKEY_FAILURE, ['no moderation']) unless $mod_reader;

	my $comment = $mod_reader->getComment($form->{cid});
	my $discussion = $mod_reader->getDiscussion($form->{sid});

	# Do some easy and high-priority initial tests.  If any of
	# these is true, this comment is not moderatable, and these
	# override the ACL and seclev tests.
	return(RESKEY_FAILURE, ['no comment']) if !$comment || !$discussion;
	return(RESKEY_FAILURE, ['user not allowed']) if
		    $user->{is_anon}
		|| !$constants->{m1}
		||  $comment->{no_moderation};
	
	# More easy tests.  If any of these is true, the user has
	# authorization to mod any comments, regardless of any of
	# the tests that come later.
	return RESKEY_SUCCESS if
		    $constants->{authors_unlimited}
		&&  $user->{seclev} >= $constants->{authors_unlimited};
	return RESKEY_SUCCESS if
		    $user->{acl}{modpoints_always};

	# OK, the user is an ordinary user, so see if they have mod
	# points and do some other fairly ordinary tests to try to
	# rule out whether they can mod.
	return(RESKEY_FAILURE, ['no points']) if
		    $user->{points} <= 0;

	return(RESKEY_FAILURE, ['not allowed']) if
		   !$user->{willing}
		||  $comment->{uid} == $user->{uid}
		||  $comment->{lastmod} == $user->{uid}
		||  $comment->{ipid} eq $user->{ipid};
	return(RESKEY_FAILURE, ['ip not allowed']) if
		    $constants->{mod_same_subnet_forbid}
		&&  $comment->{subnetid} eq $user->{subnetid};
	return(RESKEY_FAILURE, ['comment not allowed']) if
		   !$constants->{comments_moddable_archived}
		&&  $discussion->{type} eq 'archived';

	my $mid = $mod_reader->getModeratorLogID($comment->{cid}, $user->{uid});
	return(RESKEY_FAILURE, ['user already modded comment']) if $mid;

	# Last test; this one involves a bit of calculation to set
	# time_unixepoch in the comment structure itself, which is
	# why we saved it for last.  timeCalc() may chew a bit of CPU.
	$comment->{time_unixepoch} ||= timeCalc($comment->{date}, '%s', 0);
	my $hours = $constants->{comments_moddable_hours}
		|| 24 * $constants->{archive_delay};
	return(RESKEY_FAILURE, ['time not allowed']) if
		$comment->{time_unixepoch} < time - 3600*$hours;

	# All the ordinary tests passed, there's nothing stopping
	# this user from modding this comment.
	return RESKEY_SUCCESS;
}


1;

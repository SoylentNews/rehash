# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash;

# BENDER: It's time to kick some shiny metal ass!

=head1 NAME

Slash - the BEAST

=head1 SYNOPSIS

	use Slash;  # figure the rest out ;-)

=head1 DESCRIPTION

Slash is the code that runs Slashdot.

=head1 FUNCTIONS

=cut

use strict;  # ha ha ha ha ha!
use Symbol 'gensym';

use Slash::Constants ':people';
use Slash::DB;
use Slash::Display;
use Slash::Utility;
use Fcntl;
use File::Spec::Functions;
use Time::Local;
use Time::HiRes;

use base 'Exporter';
use vars qw($VERSION @EXPORT);

$VERSION   	= '2.003000';  # v2.3.0
# note: those last two lines of functions will be moved elsewhere
@EXPORT		= qw(
	constrain_score
	getData
	gensym

	dispComment displayStory displayThread dispStory
	getOlderStories getOlderDays moderatorCommentLog printComments
);


# this is the worst damned warning ever, so SHUT UP ALREADY!
$SIG{__WARN__} = sub { warn @_ unless $_[0] =~ /Use of uninitialized value/ };

# BENDER: Fry, of all the friends I've had ... you're the first.


########################################################
# Behold, the beast that is threaded comments
sub selectComments {
	my($discussion, $cid, $options) = @_;
	my $slashdb = getCurrentDB();
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my($min, $max) = ($constants->{comment_minscore}, 
			  $constants->{comment_maxscore});
	my $num_scores = $max - $min + 1;

	my $comments; # One bigass hashref full of comments
	for my $x (0..$num_scores-1) {
		$comments->{0}{totals}[$x] = 0;
	}
	my $y = 0;
	for my $x ($min..$max) {
		$comments->{0}{total_keys}{$x} = $y;
		$y++;
	}

	# When we pull comment text from the DB, we only want to cache it if
	# there's a good chance we'll use it again.
	my $cache_read_only = 0;
	$cache_read_only = 1 if $discussion->{type} eq 'archived';
	$cache_read_only = 1 if timeCalc($discussion->{ts}, '%s') <
		time - 3600 * $constants->{comment_cache_max_hours};

	my $thisComment;
	my $gcfu_opt = {
		cache_read_only	=> $cache_read_only,
		one_cid_only	=> $options->{one_cid_only},
	};
	if ($options->{force_read_from_master}) {
		$thisComment = $slashdb->getCommentsForUser($discussion->{id}, $cid, $gcfu_opt);
	} else {
		$thisComment = $reader->getCommentsForUser($discussion->{id}, $cid, $gcfu_opt);
	}

	if (!$thisComment) {
		_print_cchp($discussion);
		return ( {}, 0 );
	}

	my $max_uid = $reader->countUsers({ max => 1 });
	my $reasons = $reader->getReasons();
	# We first loop through the comments and assign bonuses and
	# and such.
	for my $C (@$thisComment) {
		# By setting pid to zero, we remove the threaded
		# relationship between the comments. Don't ignore threads
		# in forums, or when viewing a single comment (cid > 0)
		$C->{pid} = 0 if $user->{commentsort} > 3
			&& $cid == 0
			&& $user->{mode} ne 'parents'; # Ignore Threads

		# I think instead we want something like this... (not this
		# precisely, it munges up other things).
		# I'm still looking into how to get parent links and
		# children to show up properly in flat mode. - Jamie 2002/07/30
#		$user->{state}{noreparent} = 1 if $user->{commentsort} > 3;

		$C->{points} = _get_points($C, $user, $min, $max, $max_uid, $reasons);

		# Let us fill the hash range for hitparade
		$comments->{0}{totals}[$comments->{0}{total_keys}{$C->{points}}]++;  
	}

	# If we are sorting by highest score we resort to figure in bonuses
	if ($user->{commentsort} == 3) {
		@$thisComment = sort {
			$b->{points} <=> $a->{points} || $a->{cid} <=> $b->{cid}
		} @$thisComment;
	} elsif ($user->{commentsort} == 1 || $user->{commentsort} == 5) {
		@$thisComment = sort {
			$b->{cid} <=> $a->{cid}
		} @$thisComment;
	} else {
		@$thisComment = sort {
			$a->{cid} <=> $b->{cid}
		} @$thisComment;
	}

	# This loop mainly takes apart the array and builds 
	# a hash with the comments in it.  Each comment is
	# is in the index of the hash (based on its cid).
	for my $C (@$thisComment) {
		# So we save information. This will only have data if we have 
		# happened through this cid while it was a pid for another
		# comments. -Brian
		my $tmpkids = $comments->{$C->{cid}}{kids};
		my $tmpvkids = $comments->{$C->{cid}}{visiblekids};

		# We save a copy of the comment in the root of the hash
		# which we will use later to find it via its cid
		$comments->{$C->{cid}} = $C;

		# Kids is what displayThread will actually use.
		$comments->{$C->{cid}}{kids} = $tmpkids;
		$comments->{$C->{cid}}{visiblekids} = $tmpvkids;

		# The comment pushes itself onto it own kids structure 
		# which should make it the first -Brian
		push @{$comments->{$C->{pid}}{kids}}, $C->{cid};

		# The next line deals with hitparade -Brian
		#$comments->{0}{totals}[$C->{points} - $min]++;  # invert minscore

		# This deals with what will appear.
		$comments->{$C->{pid}}{visiblekids}++
			if $C->{points} >= (defined $user->{threshold} ? $user->{threshold} : $min);

		# Can't mod in a discussion that you've posted in.
		# Just a point rule -Brian
		$user->{points} = 0 if $C->{uid} == $user->{uid}; # Mod/Post Rule
	}

	my $count = @$thisComment;

	# Cascade comment point totals down to the lowest score, so
	# (2, 1, 3, 5, 4, 2, 1) becomes (18, 16, 15, 12, 7, 3, 1).
	# We do a bit of a weird thing here, returning this data in
	# the fields for a fake comment with "cid 0"...
	for my $x (reverse(0..$num_scores-2)) {
		$comments->{0}{totals}[$x] += $comments->{0}{totals}[$x + 1];
	}

	# get the total visible kids for each comment --Pater
	countTotalVisibleKids($comments);

	_print_cchp($discussion, $count, $comments->{0}{totals});

	reparentComments($comments, $reader);
	return($comments, $count);
}

sub constrain_score {
	my ($score) = @_;
	my $constants = getCurrentStatic();
	my ($min, $max) = ($constants->{comment_minscore}, $constants->{comment_maxscore});
	$score = $min if $score < $min;
	$score = $max if $score > $max;
	return $score;
}

sub _get_points {
	my($C, $user, $min, $max, $max_uid, $reasons) = @_;
	my $hr = {
		score_start => constrain_score($C->{pointsorig} + $C->{tweak_orig}),
		moderations => constrain_score($C->{points} + $C->{tweak}) - constrain_score($C->{pointsorig} + $C->{tweak_orig}),
	};
	my $points = $hr->{score_start};

	# User can setup to give points based on size.
#	my $len = length($C->{comment});
	my $len = $C->{len};
	if ($len) {
		# comments.len should always be > 0, because Slash doesn't
		# accept zero-length comments.  If it is = 0, something is
		# wrong;  don't apply these score modifiers.  (What is
		# likely is that the admin hasn't properly updated the
		# comments table with this new column. - Jamie 2003/03/20)
		if ($user->{clbig} && $user->{clbig_bonus} && $len > $user->{clbig}) {
			$hr->{clbig} = $user->{clbig_bonus};
		}
		if ($user->{clsmall} && $user->{clsmall_bonus} && $len < $user->{clsmall}) {
			$hr->{clsmall} = $user->{clsmall_bonus};
		}
	}

	# If the user is AC and we give AC's a penalty/bonus
	if ($user->{people_bonus_anonymous} && isAnon($C->{uid})) {
		$hr->{people_bonus_anonymous} =
			$user->{people_bonus_anonymous};
	}

	# If you don't trust new users
	if ($user->{new_user_bonus} && $user->{new_user_percent}
		&& 100 - 100*$C->{uid}/$max_uid < $user->{new_user_percent}) {
		$hr->{new_user_bonus} = $user->{new_user_bonus};
	}

	# Adjust reasons. Do we need a reason?
	# Are you threatening me?
	my $reason_name = $reasons->{$C->{reason}}{name};
	if ($user->{"reason_alter_$reason_name"}) {
		$hr->{reason_bonus} =
			$user->{"reason_alter_$reason_name"};
	}

	# Keep your friends close but your enemies closer.
	# Or ignore them, we don't care.
	if ($user->{uid} != $C->{uid}) {
		if ($user->{people}{FRIEND()}{$C->{uid}}) {
			$hr->{people_bonus_friend} =
				$user->{people_bonus_friend};
		}
		if ($user->{people}{FOE()}{$C->{uid}}) {
			$hr->{people_bonus_foe} =
				$user->{people_bonus_foe}
		}
		if ($user->{people}{FREAK()}{$C->{uid}}) {
			$hr->{people_bonus_freak} =
				$user->{people_bonus_freak}
		}
		if ($user->{people}{FAN()}{$C->{uid}}) {
			$hr->{people_bonus_fan} =
				$user->{people_bonus_fan}
		}
		if ($user->{people}{FOF()}{$C->{uid}}) {
			$hr->{people_bonus_fof} =
				$user->{people_bonus_fof}
		}
		if ($user->{people}{EOF()}{$C->{uid}}) {
			$hr->{people_bonus_eof} =
				$user->{people_bonus_eof}
		}
	}

	# Karma bonus time
	if ($user->{karma_bonus} && $C->{karma_bonus} eq 'yes') {
		$hr->{karma_bonus} =
			$user->{karma_bonus};
	}

	# And, the poster-was-a-subscriber bonus
	if ($user->{subscriber_bonus} && $C->{subscriber_bonus} eq 'yes') {
		$hr->{subscriber_bonus} =
			$user->{subscriber_bonus};
	}

	for my $key (grep !/^score_/, keys %$hr) { $points += $hr->{$key} }
	$points = $max if $points > $max;
	$points = $min if $points < $min;
	$hr->{score_end} = $points;

	if (wantarray) {
		for my $key (grep !/^score_/, keys %$hr) {
			my $val = $hr->{$key} + 0;
			$hr->{$key} = "+$val" if $val > 0;
		}
		return ($points, $hr);
	} else {
		return $points;
	}
}

sub _print_cchp {
	my($discussion, $count, $hp_ar) = @_;
	return unless $discussion->{stoid};
	my $form = getCurrentForm();
	return unless $form->{ssi} eq 'yes' && $form->{cchp};
	my $file_suffix = $form->{cchp};
	$count ||= 0;
	$hp_ar ||= [ ];
	my $constants = getCurrentStatic();

	my($min, $max) = ($constants->{comment_minscore}, 
			  $constants->{comment_maxscore});
	my $num_scores = $max - $min + 1;
	push @$hp_ar, 0 while scalar(@$hp_ar) < $num_scores;
	my $hp_str = join(",", @$hp_ar);

	# If these totals are wanted, print them to the file, so
	# the freshenup.pl task (or whatever) can update without
	# having to redo the work we just did.  Make sure the
	# file exists first (if a malicious web user is able to
	# pass in a cchp value without having created a file that
	# we can write to, it will be ignored).
	my $filename = File::Spec->catfile($constants->{logdir},
		"cchp.$file_suffix");
	if (!-e $filename || !-w _
		|| ((stat _)[2] & 0007)) {
		warn "_print_cchp not trying to open '$filename': "
			. "missing, unwriteable or insecure\n";
	} else {
		if (!sysopen(my $fh, $filename,
			O_WRONLY # file must already exist
		)) {
			warn "_print_cchp cannot open '$filename', $!\n";
		} else {
			$count ||= 0;
			$hp_str ||= '0';
			print $fh "count $count, hitparade $hp_str\n";
			close $fh;
		}
	}
}

########################################################
sub reparentComments {
	my($comments, $reader) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	my $depth = $constants->{max_depth} || 7;

	return if $user->{state}{noreparent} || (!$depth && !$user->{reparent});

	# adjust depth for root pid or cid
	if (my $cid = $form->{cid} || $form->{pid}) {
		while ($cid && (my($pid) = $reader->getComment($cid, 'pid'))) {
			$depth++;
			$cid = $pid;
		}
	}

	# You know, we do assume comments are linear -Brian
	for my $x (sort { $a <=> $b } keys %$comments) {
		next if $x == 0; # exclude the fake "cid 0" comment

		my $pid = $comments->{$x}{pid};
		my $reparent;

		# do threshold reparenting thing
		if ($user->{reparent} && $comments->{$x}{points} >= $user->{threshold}) {
			my $tmppid = $pid;
			while ($tmppid && $comments->{$tmppid}{points} < $user->{threshold}) {
				$tmppid = $comments->{$tmppid}{pid};
				$reparent = 1;
			}

			if ($reparent && $tmppid >= ($form->{cid} || $form->{pid})) {
				$pid = $tmppid;
			} else {
				$reparent = 0;
			}
		}

		if ($depth && !$reparent) { # don't reparent again!
			# set depth of this comment based on parent's depth
			$comments->{$x}{depth} = ($pid ? $comments->{$pid}{depth} : 0) + 1;

			# go back each pid until we find one with depth less than $depth
			while ($pid && $comments->{$pid}{depth} >= $depth) {
				$pid = $comments->{$pid}{pid};
				$reparent = 1;
			}
		}

		if ($reparent) {
			# remove child from old parent
			if ($pid >= ($form->{cid} || $form->{pid})) {
				@{$comments->{$comments->{$x}{pid}}{kids}} =
					grep { $_ != $x }
					@{$comments->{$comments->{$x}{pid}}{kids}}
			}

			# add child to new parent
			$comments->{$x}{pid} = $pid;
			push @{$comments->{$pid}{kids}}, $x;
		}
	}
}

# I wonder if much of this logic should be moved out to the theme.
# This logic can then be placed at the theme level and would eventually
# become what is put into $comment->{no_moderation}. As it is, a lot
# of the functionality of the moderation engine is intrinsically linked
# with how things behave on Slashdot.	- Cliff 6/6/01
# I rearranged the order of these tests (check anon first for speed)
# and pulled some of the tests from dispComment/_hard_dispComment
# back here as well, just to have it all in one place. - Jamie 2001/08/17
# And now it becomes a function of its own - Jamie 2002/02/26
sub _can_mod {
	my($comment) = @_;
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	# set time_unixepoch to current time if we aren't passed a
	# comment this is the case for the check for the moderate button
	# on the article page 

	$comment->{time_unixepoch} = time unless $comment;
	$comment->{time_unixepoch} = timeCalc($comment->{date}, "%s", 0)
		unless $comment->{time_unixepoch};
	my $retval =
		   !$user->{is_anon}
		&& $constants->{allow_moderation}
		&& !$comment->{no_moderation}
		&& ( (
		       $user->{points} > 0
		    && $user->{willing}
		    && $comment->{uid} != $user->{uid}
		    && $comment->{lastmod} != $user->{uid}
		    && $comment->{ipid} ne $user->{ipid}
		    && (!$constants->{mod_same_subnet_forbid}
		    	|| $comment->{subnetid} ne $user->{subnetid} )
		    && (!$user->{state}{discussion_archived}
			|| $constants->{comments_moddable_archived})
		    && ($comment->{time_unixepoch} >= time() - 3600*
			($constants->{comments_moddable_hours}
			|| 24*$constants->{archive_delay}))
		) || (
		       $constants->{authors_unlimited}
		    && $user->{seclev} >= $constants->{authors_unlimited}
		) || (
		       $user->{acl}{modpoints_always}
		) );

	return $retval;
}

#========================================================================

=head2 printComments(SID [, PID, CID])

Prints all that comment stuff.

=over 4

=item Parameters

=over 4

=item SID

The story ID to print comments for.

=item PID

The parent ID of the comments to print.

=item CID

The comment ID to print.

=back

=item Return value

None.

=item Dependencies

The 'printCommentsMain', 'printCommNoArchive',
and 'printCommComments' template blocks.

=back

=cut

sub printComments {
	my($discussion, $pid, $cid, $options) = @_;
	my $user = getCurrentUser();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();

	if (!$discussion || !$discussion->{id}) {
		print getData('no_such_sid', {}, '');
		return 0;
	}
	# Couple of rules on how to treat the discussion depending on how mode is set -Brian
	$discussion->{type} = isDiscussionOpen($discussion);

	$pid ||= 0;
	$cid ||= 0;
	my $cidorpid = $cid || $pid;
	my $lvl = 0;

	# Get the Comments
	my $sco = { force_read_from_master => $options->{force_read_from_master} || 0 };
	$sco->{one_cid_only} = 1 if $cidorpid && (
		   $user->{mode} eq 'nocomment'
		|| ( $user->{mode} eq 'flat' && $user->{commentsort} > 3 )
		|| $options->{just_submitted}
	);
	# For now, until we are able to pull hitparade into discussions so we can
	# read it here, don't use the one_cid_only optimization feature.
	$sco->{one_cid_only} = 0;

	my($comments, $count) = selectComments($discussion, $cidorpid, $sco);

	if ($cidorpid && !exists($comments->{$cidorpid})) {
		# No such comment in this discussion.
		my $d = getData('no_such_comment', {
			sid => $discussion->{id},
			cid => $cid,
		}, '');
		print $d;
		return 0;
	}

	# Should I index or just display normally?
	my $cc = 0;
	$cc = $comments->{$cidorpid}{visiblekids}
		if $comments->{$cidorpid}
			&& $comments->{$cidorpid}{visiblekids};

	$lvl++ if $user->{mode} ne 'flat'
		&& $user->{mode} ne 'archive'
		&& $user->{mode} ne 'metamod'
		&& $cc > $user->{commentspill}
		&& ( $user->{commentlimit} > $cc ||
		     $user->{commentlimit} > $user->{commentspill} );

	if ($discussion->{type} eq 'archived'
		|| ($discussion->{is_future} && !$constants->{subscribe_future_post})
		|| ($discussion->{commentstatus} && $discussion->{commentstatus} ne 'enabled')
	) {
		# This was named "comment_read_only" but that's not very
		# descriptive;  let's call it what it is... -Jamie 2002/02/26
		if ($discussion->{type} eq 'archived') {
			$user->{state}{discussion_archived} = 1;
		}
		if ($discussion->{is_future} && !$constants->{subscribe_future_post}) {
			$user->{state}{discussion_future_nopost} = 1;
		}
		slashDisplay('printCommNoArchive', { discussion => $discussion });
	}

	slashDisplay('printCommentsMain', {
		comments	=> $comments,
		title		=> $discussion->{title},
		'link'		=> $discussion->{url},
		count		=> $count,
		sid		=> $discussion->{id},
		cid		=> $cid,
		pid		=> $pid,
		lvl		=> $lvl,
	});

	return if $user->{state}{nocomment} || $user->{mode} eq 'nocomment';

	my($comment, $next, $previous);
	if ($cid) {
		my($next, $previous);
		$comment = $comments->{$cid};
		if (my $sibs = $comments->{$comment->{pid}}{kids}) {
			for (my $x = 0; $x < @$sibs; $x++) {
				($next, $previous) = ($sibs->[$x+1], $sibs->[$x-1])
					if $sibs->[$x] == $cid;
			}
		}

		$next = $comments->{$next} if $next;
		$previous = $comments->{$previous} if $previous;
	}

	# Flat and theaded mode don't index, even on large stories, so they
	# need to use more, smaller pages. if $cid is 0, then we get the
	# totalviskids for the story 		--Pater
	my $total = ($user->{mode} eq 'flat' || $user->{mode} eq 'nested') ? $comments->{$cidorpid}{totalvisiblekids} : $cc;

	my $lcp = linkCommentPages($discussion->{id}, $pid, $cid, $total);

	my $comment_html = slashDisplay('printCommComments', {
		can_moderate	=> _can_mod($comment),
		comment		=> $comment,
		comments	=> $comments,
		'next'		=> $next,
		previous	=> $previous,
		sid		=> $discussion->{id},
		cid		=> $cid,
		pid		=> $pid,
		cc		=> $cc,
		lcp		=> $lcp,
		lvl		=> $lvl,
	}, { Return => 1 });

	# We have to get the comment text we need (later we'll search/replace
	# them into the text).
	my $comment_text = { };

	# Should we read/write the parsed comments to/from memcached?
	# This will be possible only if some particular prefs of this user
	# are set to the standard values.  If this is possible, then for
	# almost every comment, we can pull fully rendered text directly
	# from memcached and not have to touch the DB.
	# Currently, the only user prefs that affect comment rendering at
	# this level are whether domaintags are the default, and whether
	# maxcommentsize is the default.
	my $mcd = $slashdb->getMCD();
	$mcd = undef if
		   $form->{mode} eq 'archive'
		|| $user->{domaintags} != 2
		|| $user->{maxcommentsize} != $constants->{default_maxcommentsize};

	# loop here, pull what cids we can
	my $cids_needed_ar = $user->{state}{cids} || [ ];
	my($mcd_debug, $mcdkey, $mcdkeylen);
	if ($mcd) {
		# MemCached key prefix "ctp" means "comment_text, parsed".
		# Prepend our site key prefix to try to avoid collisions
		# with other sites that may be using the same servers.
		$mcdkey = "$mcd->{keyprefix}ctp:";
		$mcdkeylen = length($mcdkey);
		if ($constants->{memcached_debug}) {
			$mcd_debug = { start_time => Time::HiRes::time };
		}
	}
	$mcd_debug->{total} = scalar @$cids_needed_ar if $mcd_debug;
	if ($mcd) {
		if ($mcd && $constants->{memcached_debug} && $constants->{memcached_debug} > 2) {
			print STDERR scalar(gmtime) . " printComments memcached mcdkey '$mcdkey'\n";
		}
		my @keys_try =
			map { "$mcdkey$_" }
			grep { $_ != $form->{cid} }
			@$cids_needed_ar;
		$comment_text = $mcd->get_multi(@keys_try);
		my @old_keys = keys %$comment_text;
		if ($mcd && $constants->{memcached_debug} && $constants->{memcached_debug} > 1) {
			print STDERR scalar(gmtime) . " printComments memcached got keys '@old_keys' tried for '@keys_try'\n"
		}
		$mcd_debug->{hits} = scalar @old_keys if $mcd_debug;
		for my $old_key (@old_keys) {
			my $new_key = substr($old_key, $mcdkeylen);
			$comment_text->{$new_key} = delete $comment_text->{$old_key};
		}
		@$cids_needed_ar = grep { !exists $comment_text->{$_} } @$cids_needed_ar;
	}
	if ($mcd && $constants->{memcached_debug} && $constants->{memcached_debug} > 1) {
		print STDERR scalar(gmtime) . " printComments memcached mcd '$mcd' con '$constants->{memcached}' mcd '$mcd' dt '$user->{domaintags}' mcs '$user->{maxcommentsize}' still needed: '@$cids_needed_ar'\n";
	}

	# Now we get fresh with the comment text. We take all of the cids
	# that we have found and we then speed through the text replacing
	# the tags that were there to hold them.
	my $more_comment_text = $slashdb->getCommentText($cids_needed_ar) || {}
		if @$cids_needed_ar;
	if ($mcd && $constants->{memcached_debug} && $constants->{memcached_debug} > 1) {
		print STDERR scalar(gmtime) . " more_comment_text keys: '" . join(" ", sort keys %$more_comment_text) . "'\n";
	}

	for my $cid (keys %$more_comment_text) {
		if ($form->{mode} ne 'archive'
			&& $comments->{$cid}{len} > $user->{maxcommentsize}
			&& $form->{cid} ne $cid)
		{
			# We remove the domain tags so that strip_html will not
			# consider </a blah> to be a non-approved tag.  We'll
			# add them back at the last step.  In-between, we chop
			# the comment down to size, then massage it to make sure
			# we still have good HTML after the chop.
			$more_comment_text->{$cid} =~ s{</A[^>]+>}{</A>}gi;
			my $text = chopEntity($more_comment_text->{$cid},
				$user->{maxcommentsize});
			$text = strip_html($text);
			$text = balanceTags($text);
			$more_comment_text->{$cid} = addDomainTags($text);
		}

		# Now write the new data into our hashref and write it out to
		# memcached if appropriate.  For these purposes, if we were
		# cleared to read from memcached, the data we just got is also
		# valid to write to memcached.
		$comment_text->{$cid} = parseDomainTags($more_comment_text->{$cid},
			$comments->{$cid}{fakeemail});
		if ($mcd && $form->{cid} ne $cid) {
			my $exptime = $constants->{memcached_exptime_comtext};
			$exptime = 86400 if !defined($exptime);
			my $retval = $mcd->set("$mcdkey$cid", $comment_text->{$cid}, $exptime);
			if ($mcd && $constants->{memcached_debug} && $constants->{memcached_debug} > 1) {
				my $exp_at = $exptime ? scalar(gmtime(time + $exptime)) : "never";
				print STDERR scalar(gmtime) . " printComments memcached writing '$mcdkey$cid' length " . length($comment_text->{$cid}) . " retval=$retval expire: $exp_at\n";
			}
		}
	}

	if ($mcd && $constants->{memcached_debug} && $constants->{memcached_debug} > 1) {
		print STDERR scalar(gmtime) . " comment_text keys: '" . join(" ", sort keys %$comment_text) . "'\n";
	}

	if ($mcd_debug) {
		$mcd_debug->{hits} ||= 0;
		printf STDERR scalar(gmtime) . " printComments memcached"
			. " tried=" . ($mcd ? 1 : 0) . " total_cids=%d hits=%d misses=%d elapsed=%6.4f\n",
			$mcd_debug->{total} , $mcd_debug->{hits},
			$mcd_debug->{total} - $mcd_debug->{hits},
			Time::HiRes::time - $mcd_debug->{start_time};
	}

	# OK we have all the comment data in our hashref, so the search/replace
	# on the nearly-fully-rendered page will work now.
	$comment_html =~ s|<SLASH type="COMMENT-TEXT">(\d+)</SLASH>|$comment_text->{$1}|g;

	print $comment_html;
}

#========================================================================

=head2 moderatorCommentLog(TYPE, ID)

Prints a table detailing the history of moderation of a particular
comment and/or the reasons why a comment is scored like it is.
(The template name is modCommentLog and this shows info about not
just moderation but modifiers;  this function should probably be
renamed the same.)

=over 4

=item Parameters

=over 4

=item TYPE

String describing type of the ID data:  cid, uid, cuid, ipid, subnetid,
bipid or bsubnetid.

=item ID

Cid or IPID.

=back

=item Return value

The HTML.

=item Dependencies

The 'modCommentLog' template block.

=back

=cut

sub moderatorCommentLog {
	my($type, $value, $options) = @_;
	$options ||= {};
	my $title = $options->{title};
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	# If the user doesn't want even to see the numeric score of
	# a comment, they certainly don't want to see all this detail.
	return "" if $user->{noscores};

	my $seclev = $user->{seclev};
	my $mod_admin = $seclev >= $constants->{modviewseclev} ? 1 : 0;

	my $asc_desc = $type eq 'cid' ? 'ASC' : 'DESC';
	my $limit = $type eq 'cid' ? 0 : 100;
	my $both_mods = (($type =~ /ipid/) || ($type =~ /subnetid/) || ($type =~ /global/)) ? 1 : 0;
	my $skip_ip_disp = 0;
	if ($type =~ /^b(ip|subnet)id$/) {
		$skip_ip_disp = 1;
	} elsif ($type =~ /^(ip|subnet)id$/) {
		$skip_ip_disp = 2;
	}
	my $gmcl_opts = {};
	$gmcl_opts->{hours_back} = $options->{hours_back} if $options->{hours_back};
	$gmcl_opts->{order_col} = "reason" if $type eq "cid";

	my $mods = $slashdb->getModeratorCommentLog($asc_desc, $limit,
		$type, $value, $gmcl_opts);

	my $timestamp_hr = exists $options->{hr_hours_back}
		? $slashdb->getTime({ add_secs => -3600 * $options->{hr_hours_back} })
		: "";

	if (!$mod_admin) {
		# Eliminate inactive moderations from the list.
		$mods = [ grep { $_->{active} } @$mods ];
	}

	my($reasons, @return, @reasonHist);
	my $reasonTotal = 0;
	$reasons = $slashdb->getReasons();

	# Note: Before 2001/01/27 or so, the only things being displayed
	# in this template were moderations, and if there were none,
	# we could short-circuit here if @$mods was empty.  But now,
	# the template handles that decision.
	my $seen_mods = {};
	for my $mod (@$mods) {
		$seen_mods->{$mod->{id}}++;
		vislenify($mod); # add $mod->{ipid_vis}
		#$mod->{ts} = substr($mod->{ts}, 5, -3);
		$mod->{nickname2} = $slashdb->getUser($mod->{uid2},
			'nickname') if $both_mods; # need to get 2nd nick
		next unless $mod->{active};
		$reasonHist[$mod->{reason}]++;
		$reasonTotal++;
	}

	my $listed_reason = 0;
	if ($type eq 'cid') {
		my $val_q = $slashdb->sqlQuote($value);
		$listed_reason = $slashdb->sqlSelect("reason", "comments", "cid=$val_q");
	}
	my @reasonsTop = _getTopModReasons($reasonTotal, $listed_reason, \@reasonHist);

	my $show_cid    = ($type eq 'cid') ? 0 : 1;
	my $show_modder = $mod_admin ? 1 : 0;
	my $mod_to_from = ($type eq 'uid') ? 'to' : 'from';

	my $modifier_hr = { };
	my $reason = 0;
	if ($type eq 'cid') {
		my $cid_q = $slashdb->sqlQuote($value);
		my($min, $max) = ($constants->{comment_minscore}, 
				  $constants->{comment_maxscore});
		my $max_uid = $slashdb->countUsers({ max => 1 });

		my $select = "cid, uid, karma_bonus, reason, points, pointsorig, tweak, tweak_orig";
		if ($constants->{plugin}{Subscribe} && $constants->{subscribe}) {
			$select .= ", subscriber_bonus";
		}
		my $comment = $slashdb->sqlSelectHashref(
			$select,
			"comments",
			"cid=$cid_q");
		$comment->{comment} = $slashdb->sqlSelect(
			"comment",
			"comment_text",
			"cid=$cid_q");
		$reason = $comment->{reason};

		my $user = getCurrentUser();
		my $points;
		($points, $modifier_hr) = _get_points($comment, $user, $min, $max, $max_uid, $reasons);
	}

	my $this_user;
	$this_user = $slashdb->getUser($value) if $type eq "uid";
	my $cur_uid;
	$cur_uid = $value if $type eq "uid" || $type eq "cuid";

	my $mod_ids = [keys %$seen_mods];
	my $mods_to_m2s;
	if ($constants->{show_m2s_with_mods} && $options->{show_m2s}) {
		$mods_to_m2s = $slashdb->getMetamodsForMods($mod_ids, $constants->{m2_limit_with_mods});
	}
	
	# Do the work to determine which moderations share the same m2s
	if ($type eq "cid"
		&& $constants->{show_m2s_with_mods}
		&& $constants->{m2_multicount}
		&& $options->{show_m2s}){
		foreach my $m (@$mods){
			my $key = '';
			foreach my $m2 (@{$mods_to_m2s->{$m->{id}}}) {
				$key .= "$m2->{uid} $m2->{val},";
			}
			$m->{m2_identity} = $key;
		}
		@$mods = sort {
			$a->{reason} <=> $b->{reason}
				||
			$a->{m2_identity} cmp $b->{m2_identity}
		} @$mods;
	}
	my $data = {
		type		=> $type,
		mod_admin	=> $mod_admin, 
		mods		=> $mods,
		reasonTotal	=> $reasonTotal,
		reasonHist	=> \@reasonHist,
		reasonsTop	=> \@reasonsTop,
		reasons		=> $reasons,
		reason		=> $reason,
		modifier_hr	=> $modifier_hr,
		show_cid	=> $show_cid,
		show_modder	=> $show_modder,
		mod_to_from	=> $mod_to_from,
		both_mods	=> $both_mods,
		timestamp_hr	=> $timestamp_hr,
		skip_ip_disp    => $skip_ip_disp,
		this_user	=> $this_user,
		title		=> $title,
		mods_to_m2s	=> $mods_to_m2s,
		show_m2s	=> $options->{show_m2s},
		cur_uid		=> $cur_uid,
		value		=> $value,
		need_m2_form	=> $options->{need_m2_form},
		need_m2_button	=> $options->{need_m2_button},
		meta_mod_only	=> $options->{meta_mod_only},
	};
	slashDisplay('modCommentLog', $data, { Return => 1, Nocomm => 1 });
}

# Takes a reason histogram, a list of counts of each reason mod.
# So $reasonHist[1] is the number of Offtopic moderations (at
# least if Offtopic is still reason 1).  Returns a list of hashrefs,
# the top 3 mods performed and their percentages, rounded to the
# nearest 10%, sorted largest to smallest.
sub _getTopModReasons{
	my($reasonTotal, $listed_reason, $reasonHist_ar) = @_;
	return ( ) unless $reasonTotal;
	my $top_needed = 3;
	my @reasonsTop = ( );

	# Algorithm by MJD in Perl Quiz of the Week #7
	# http://perl.plover.com/qotw/r/solution/007
	my @p = map { $_*10/$reasonTotal } @$reasonHist_ar;
	my @r = map { int($_+0.5) } @p;
	my @e = map { $p[$_] - $r[$_] } (0..$#r);
	my $total_error = 0;
	for (@e) { $total_error += $_ }
	# Round total_error to int, to avoid float rounding error
	my $sign = $total_error < 0 ? -1 : 1;
	$total_error *= $sign;
	$total_error = int($total_error+0.5);
	if ($total_error) {
		for (0..$#r) {
			next unless $e[$_] * $sign > 0;
			$r[$_] += $sign;
			$total_error--;
			last if $total_error <= 0;
		}
	}

	# This part I added, so if it breaks, don't blame MJD :) JRM
	my %reasonRound = map { ($_, $r[$_]*10) } (0..$#r);
	my @rr_keys = sort { $a <=> $b } keys %reasonRound;
	my $min = (sort { $b <=> $a } values %reasonRound)[$top_needed-1];
	for my $key (0..$#r) {
		$reasonRound{$key} = 0 if $reasonRound{$key} < $min;
	}
	my $have = 0;
	for my $key (0..$#r) {
		++$have if $reasonRound{$key} > $min;
	}
	for my $key (0..$#r) {
		if ($reasonRound{$key} == $min) {
			if ($have >= $top_needed) {
				$reasonRound{$key} = 0;
			} else {
				++$have;
			}
		}
	}
	for my $reason (1..$#r) {
		next unless $reasonRound{$reason};
		push @reasonsTop, {
			reason => $reason,
			percent => $reasonRound{$reason},
		};
	}
	@reasonsTop = sort {
		($b->{reason} == $listed_reason) <=> ($a->{reason} == $listed_reason)
		||
		$b->{percent} <=> $a->{percent}
		||
		$a->{reason} <=> $b->{reason}
	} @reasonsTop;

	return @reasonsTop;
}

#========================================================================

=head2 displayThread(SID, PID, LVL, COMMENTS)

Displays an entire thread.  w00p!

=over 4

=item Parameters

=over 4

=item SID

The story ID.

=item PID

The parent ID.

=item LVL

What level of the thread we're at.

=item COMMENTS

Arrayref of all our comments.

=back

=item Return value

The thread.

=item Dependencies

The 'displayThread' template block.

=back

=cut

sub displayThread {
	my($sid, $pid, $lvl, $comments, $const) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	$lvl ||= 0;
	my $displayed = 0;
	my $mode = getCurrentUser('mode');
	my $indent = 1;
	my $full = my $cagedkids = !$lvl;
	my $hidden = my $skipped = 0;
	my $return = '';

	# FYI: 'archive' means we're to write the story to .shtml at the close
	# of the discussion without page breaks.  'metamod' means we're doing
	# metamoderation.
	if ($user->{mode} eq 'flat'
		|| $user->{mode} eq 'archive'
		|| $user->{mode} eq 'metamod'
		|| $user->{mode} eq 'parents'
		|| $user->{mode} eq 'child') {
		$indent = 0;
		$full = 1;
	} elsif ($user->{mode} eq 'nested') {
		$indent = 1;
		$full = 1;
	}

	unless ($const) {
		for (map { ($_ . "begin", $_ . "end") }
			qw(table cage cagebig indent comment)) {
			$const->{$_} = getData($_, '', '');
		}
	}

	for my $cid (@{$comments->{$pid}{kids}}) {
		my $comment = $comments->{$cid};

		$skipped++;
		# since nested and threaded show more comments, we can skip
		# ahead more, counting all the visible kids.	--Pater
		$skipped += $comment->{totalvisiblekids} if ($user->{mode} eq 'flat' || $user->{mode} eq 'nested');
		$form->{startat} ||= 0;
		next if $skipped <= $form->{startat};
		$form->{startat} = 0; # Once We Finish Skipping... STOP

		if ($comment->{points} < $user->{threshold}) {
			if ($user->{is_anon} || ($user->{uid} != $comment->{uid})) {
				$hidden++;
				next;
			}
		}

		my $highlight = 1 if $comment->{points} >= $user->{highlightthresh};
		my $finish_list = 0;

		if ($full || $highlight) {
			if ($lvl && $indent) {
				$return .= $const->{tablebegin} .
					dispComment($comment) . $const->{tableend};
				$cagedkids = 0;
			} else {
				$return .= dispComment($comment);
			}
			$displayed++;
		} else {
			my $pntcmt = @{$comments->{$comment->{pid}}{kids}} > $user->{commentspill};
			$return .= $const->{commentbegin} .
				linkComment($comment, $pntcmt, 1);
			$finish_list++;
		}

		if ($comment->{kids} && ($user->{mode} ne 'parents' || $pid)) {
			$return .= $const->{cagebegin} if $cagedkids;
			$return .= $const->{indentbegin} if $indent;
			$return .= displayThread($sid, $cid, $lvl+1, $comments, $const);
			$return .= $const->{indentend} if $indent;
			$return .= $const->{cageend} if $cagedkids;

			# in flat or nested mode, all visible kids will
			# be shown, so count them.	-- Pater
			$displayed += $comment->{totalvisiblekids} if ($user->{mode} eq 'flat' || $user->{mode} eq 'nested');
		}

		$return .= $const->{commentend} if $finish_list;

		last if $displayed >= $user->{commentlimit};
	}

	if ($hidden
		&& ! $user->{hardthresh}
		&& $user->{mode} ne 'archive'
		&& $user->{mode} ne 'metamod') {

		$return .= $const->{cagebigbegin} if $cagedkids;
		my $link = linkComment({
			sid		=> $sid,
			threshold	=> $constants->{comment_minscore},
			pid		=> $pid,
			subject		=> getData('displayThreadLink', { 
						hidden => $hidden 
					   }, ''),
			subject_only	=> 1,
		});
		$return .= slashDisplay('displayThread', { 'link' => $link },
			{ Return => 1, Nocomm => 1 });
		$return .= $const->{cagebigend} if $cagedkids;

	}

	return $return;
}

#========================================================================

=head2 dispComment(COMMENT)

Displays a particular comment.

=over 4

=item Parameters

=over 4

=item COMMENT

Hashref of comment data.
If the 'no_moderation' key of the COMMENT hashref exists, the
moderation elements of the comment will not be displayed.

=back

=item Return value

The comment to display.

=item Dependencies

The 'dispComment' template block.

=back

=cut

sub dispComment {
	my($comment) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $gSkin = getCurrentSkin();

	my($comment_shrunk, %reasons);

	if ($form->{mode} ne 'archive'
		&& $comment->{len} > $user->{maxcommentsize}
		&& $form->{cid} ne $comment->{cid})
	{
		$comment_shrunk = 1;
	}

	$comment->{sig} = parseDomainTags($comment->{sig}, $comment->{fakeemail});
	if ($user->{sigdash} && $comment->{sig}) {
		$comment->{sig} =~ s/^\s*-{1,5}\s*<(?:P|BR)>//i;
		$comment->{sig} = "--<BR>$comment->{sig}";
	}

	my $reasons = $reader->getReasons();

	my $can_mod = _can_mod($comment);

	# don't inherit these ...
	for (qw(sid cid pid date subject comment uid points lastmod
		reason nickname fakeemail homepage sig)) {
		$comment->{$_} = '' unless exists $comment->{$_};
	}

	# ipid/subnetid need munging into one text string
	if ($user->{seclev} >= 100 && $comment->{ipid} && $comment->{subnetid}) {
		vislenify($comment); # create $comment->{ipid_vis} and {subnetid_vis}
		if ($constants->{comments_hardcoded}) {
			$comment->{ipid_display} = <<EOT;
<BR><FONT FACE="$constants->{mainfontface}" SIZE=1>IPID:
<A HREF="$constants->{real_rootdir}/users.pl?op=userinfo&amp;userfield=$comment->{ipid}&amp;fieldname=ipid">$comment->{ipid_vis}</A>&nbsp;&nbsp;SubnetID: 
<A HREF="$constants->{real_rootdir}/users.pl?op=userinfo&amp;userfield=$comment->{subnetid}&amp;fieldname=subnetid">$comment->{subnetid_vis}</A></FONT>
EOT
		} else {
			$comment->{ipid_display} = slashDisplay(
				"ipid_display", { data => $comment },
				1);
		}
	} else {
		$comment->{ipid_display} = "";
	}

	# we need a display-friendly fakeemail string
	$comment->{fakeemail_vis} = ellipsify($comment->{fakeemail});
	push @{$user->{state}{cids}}, $comment->{cid};

	# stats for clampe
	if ($constants->{clampe_stats} && $ENV{SCRIPT_NAME}) {
		my $fname = catfile('clampe', $user->{ipid});
		my $comlog = "IPID: $user->{ipid} UID: $user->{uid} SID: $comment->{sid} CID: $comment->{cid} Dispmode: $user->{mode} Thresh: $user->{threshold} CIPID: $comment->{ipid} CUID: $comment->{uid}";
		doLog($fname, [$comlog]);	
	}

	return _hard_dispComment(
		$comment, $constants, $user, $form, $comment_shrunk,
		$can_mod, $reasons
	) if $constants->{comments_hardcoded} && !$user->{light};

	return slashDisplay('dispComment', {
		%$comment,
		comment_shrunk	=> $comment_shrunk,
		reasons		=> $reasons,
		can_mod		=> $can_mod,
		is_anon		=> isAnon($comment->{uid}),
	}, { Return => 1, Nocomm => 1 });
}

#========================================================================

=head2 dispStory(STORY, AUTHOR, TOPIC, FULL, OTHER)

Display a story.

=over 4

=item Parameters

=over 4

=item STORY

Hashref of data about the story.

=item AUTHOR

Hashref of data about the story's author.

=item TOPIC

Hashref of data about the story's topic.

=item FULL

Boolean for show full story, or just the
introtext portion.

=item OTHER

Hash with parameters such as alternate template.

=back

=item Return value

Story to display.

=item Dependencies

The 'dispStory' template block.

=back

=cut


sub dispStory {
	my($story, $author, $topic, $full, $other) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $gSkin = getCurrentSkin();
	my $template_name = $other->{story_template}
		? $other->{story_template} : 'dispStory';

	# Might this logic be better off in the template? Its sole purpose
	# is aesthetics.
	$other->{magic} = !$full
			&& index($story->{title}, ':') == -1
			&& $story->{primaryskid} ne $gSkin->{skid}
			&& $story->{primaryskid} ne $constants->{mainpage_skid}
		if !exists $other->{magic};

	$other->{preview} ||= 0;
	my %data = (
		story	=> $story,
		topic	=> $topic,
		author	=> $author,
		full	=> $full,
#		stid	=> $other->{stid},
		topics	=> $other->{topics_chosen},
		topiclist => $other->{topiclist},
		magic	=> $other->{magic},
		width	=> $constants->{titlebar_width},
		preview => $other->{preview}
	);
#use Data::Dumper; print STDERR scalar(localtime) . " dispStory data: " . Dumper(\%data);

	return slashDisplay($template_name, \%data, 1);
}

#========================================================================

=head2 displayStory(SID, FULL, OTHER)

Display a story by SID (frontend to C<dispStory>).

=over 4

=item Parameters

=over 4

=item SID

Story ID to display.

=item FULL

Boolean for show full story, or just the
introtext portion.

=item OTHER 

hash containing other parameters such as 
alternate template name, or titlebar magic.

=back

=item Return value

Rendered story

=back

=cut

sub displayStory {
	my($stoid, $full, $options) = @_;	

	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $gSkin = getCurrentSkin();
	
	my $return;
	my $story;
	if ($options->{get_cacheable}) {
		my $slashdb = getCurrentDB();
		$story = $slashdb->getStory($stoid, "", $options->{get_cacheable});
		$story->{is_future} = 0;
	} else {
		$story = $reader->getStory($stoid);
	}

	# There are many cases when we'd not want to return the pre-rendered text
	# from the DB.
	if (	   !$constants->{no_prerendered_stories}
		&& $constants->{cache_enabled}
		&& $story->{rendered} && !$options->{get_cacheable}
		&& !$form->{light} && !$user->{light}
		&& (!$form->{ssi} || $form->{ssi} ne 'yes')
		&& !$user->{noicons}
		&& !$form->{issue}
		&& $gSkin->{skid} == $constants->{mainpage_skid}
		&& !$full
		&& !$options->{is_future}	 # can $story->{is_future} ever matter?
	) {
		$return = $story->{rendered};
	} else {

		my $author = $reader->getAuthor($story->{uid},
				['nickname', 'fakeemail', 'homepage']);
		my $topic = $reader->getTopic($story->{tid});
		$story->{atstorytime} = "__TIME_TAG__";

		$story->{introtext} = parseSlashizedLinks($story->{introtext});
		$story->{introtext} = processSlashTags($story->{introtext});
		if ($full) {
			$story->{bodytext} = parseSlashizedLinks($story->{bodytext});
			$story->{bodytext} = processSlashTags($story->{bodytext}, { break => 1 });
			$options->{stid} = $reader->getTopiclistForStory($story->{sid});
			# if a secondary page, put bodytext where introtext would normally go
			# maybe this is not the right thing, but is what we are doing for now;
			# let me know if you have another idea -- pudge
			$story->{introtext} = delete $story->{bodytext} if $form->{pagenum} > 1;
		}

		$return = dispStory($story, $author, $topic, $full, $options);

	}
	my $df = ($user->{mode} eq "archive" || ($story->{is_archived} eq "yes" && $user->{is_anon}))
		? $constants->{archive_dateformat} : "";
	my $storytime = timeCalc($story->{'time'}, $df);
	my $atstorytime;
	if ($options->{is_future} && !($user->{author} || $user->{is_admin})) {
		$atstorytime = $constants->{subscribe_future_name};
	} else {
		$atstorytime = $user->{aton} . " " . timeCalc($story->{'time'}, $df);
	}
	$return =~ s/\Q__TIME_TAG__\E/$atstorytime/ unless $options->{get_cacheable};

	return $return;
}


#========================================================================

=head2 getOlderStories(STORIES, SECTION)

Get older stories for older stories box.

=over 4

=item Parameters

=over 4

=item STORIES

Array ref of the "essentials" of the stories to display, retrieved from
getStoriesEssentials.

=item SECTION

Section name or Hashref of section data.

=back

=item Return value

The older stories, formatted.

=item Dependencies

The 'getOlderStories' template block.

=back

=cut

sub getOlderStories {
	my($stories, $section, $stuff) = @_;
	my($count, $newstories);
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	for my $story (@$stories) {
		#Use one call and parse it, its cheaper :) -Brian
		my($day_of_week, $month, $day, $secs) = split m/ /, timeCalc($story->{time}, "%A %B %d %s");
		$day =~ s/^0//;
		$story->{day_of_week} = $day_of_week;
		$story->{month} = $month;
		$story->{day} = $day;
		$story->{secs} = $secs;
		$story->{issue} ||= timeCalc($story->{time}, '%Y%m%d');
		$story->{'link'} = linkStory({
			'link'  => $story->{title},
			sid     => $story->{sid},
			tid     => $story->{tid},
			section => $story->{section},
		});
	}

	my($today, $tomorrow, $yesterday, $week_ago) = getOlderDays($form->{issue});

	$form->{start} ||= 0;

	my $artcount = $user->{is_anon} ? $section->{artcount} : $user->{maxstories};

	# The template won't display all of what's passed to it (by default
	# only the first $section->{artcount}).  "start" is just an offset
	# that gets incremented.
	slashDisplay('getOlderStories', {
		stories		=> $stories,
		section		=> $section,
		cur_time	=> time,
		today		=> $today,
		tomorrow	=> $tomorrow,
		yesterday	=> $yesterday,
		week_ago	=> $week_ago,
		start		=> int($artcount/3) + $form->{start},	
		first_date	=> $stuff->{first_date},
		last_date	=> $stuff->{last_date}
	}, 1);
}

#========================================================================
sub getOlderDays {
	my($issue) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my($today, $tomorrow, $yesterday, $week_ago);
	# week prior to yesterday (oldest story we'll get back when we do
	# a getStoriesEssentials for yesterday's issue)
	if ($issue) {
		my($y, $m, $d) = $issue =~ /^(\d\d\d\d)(\d\d)(\d\d)$/;
		if ($y) {
			$today    = $reader->getDay(0);
			$tomorrow = timeCalc(scalar localtime(
				timelocal(0, 0, 12, $d, $m - 1, $y - 1900) + 86400
			), '%Y%m%d');
			$yesterday = timeCalc(scalar localtime(
				timelocal(0, 0, 12, $d, $m - 1, $y - 1900) - 86400
			), '%Y%m%d');
			$week_ago  = timeCalc(scalar localtime(
				timelocal(0, 0, 12, $d, $m - 1, $y - 1900) - 86400 * 8 
			), '%Y%m%d');
		}
	} else {
		$today     = $reader->getDay(0);
		$tomorrow  = $reader->getDay(-1);
		$yesterday = $reader->getDay(1);
		$week_ago  = $reader->getDay(8);
	}
	return($today, $tomorrow, $yesterday, $week_ago);
}

#========================================================================

=head2 getData(VALUE [, PARAMETERS, PAGE])

Returns snippets of data associated with a given page.

=over 4

=item Parameters

=over 4

=item VALUE

The name of the data-snippet to process and retrieve.

=item PARAMETERS

Data stored in a hashref which is to be passed to the retrieved snippet.

=item PAGE

The name of the page to which VALUE is associated.

=back

=item Return value

Returns data snippet with all necessary data interpolated.

=item Dependencies

Gets little snippets of data, determined by the value parameter, from
a data template. A data template is a colletion of data snippets
in one template, which are grouped together for efficiency. Each
script can have it's own data template (specified by the PAGE
parameter). If PAGE is unspecified, snippets will be retrieved from
the last page visited by the user as determined by Slash::Apache::User.

=item Notes

This is in Slash.pm instead of Slash::Utility because it depends on Slash::Display,
which also depends on Slash::Utility.  Slash::Utility can call Slash::getData
(note package name), because Slash.pm should always be loaded by scripts first
before loading Slash::Utility, so as long as nothing in Slash::Utility requires
getData for compilation, we should be good (except, note that the environment
Slash::Display depends on needs to be there, so you can't call getData before
createCurrentDB and friends are called ... see note in prepareUser).

=back

=cut

sub getData {
	my($value, $hashref, $page) = @_;
	my $cache = getCurrentCache();
	_dataCacheRefresh($cache);

	$hashref ||= {};
	$hashref->{value} = $value;
	$hashref->{returnme} = {};
	my $opts = { Return => 1, Nocomm => 1 };
	$opts->{Page} = $page || 'NONE' if defined $page;
	my $opts_getname = $opts; $opts_getname->{GetName} = 1;

	my $name = slashDisplayName('data', $hashref, $opts_getname);
	my $var  = $cache->{getdata}{ $name->{tempdata}{tpid} } ||= { };

	if (defined $var->{$value}) {
#		print STDERR "getData $$ value='$value' tpid='$name->{tempdata}{tpid}' len=" . length($var->{$value}) . " cache_hit\n";
		return $var->{$value};
	}

	my $str = slashDisplay($name, $hashref, $opts);
	return undef if !defined($str);

	if ($hashref->{returnme}{data_constant}) {
		$cache->{getdata}{_last_refresh} ||= time;
		$var->{$value} = $str;
	}
#	print STDERR "getData $$ value='$value' tpid='$name->{tempdata}{tpid}' len=" . length($str) . " cache_miss\n";
	return $str;
}

sub _dataCacheRefresh {
	my($cache) = @_;
	if ($cache->{getdata}{_last_refresh} < time - $cache->{getdata}{_expiration}) {
		$cache->{getdata} = {};
		$cache->{getdata}{_last_refresh} = time;
		$cache->{getdata}{_expiration} = getCurrentStatic('block_expire');
	}
}

########################################################
# this sucks, but it is here for now
sub _hard_dispComment {
	my($comment, $constants, $user, $form, $comment_shrunk, $can_mod, $reasons) = @_;
	my $gSkin = getCurrentSkin();

	my($comment_to_display, $score_to_display,
		$user_nick_to_display, $zoosphere_display, $user_email_to_display,
		$time_to_display, $comment_link_to_display, $userinfo_to_display)
		= ("") x 7;

	if ($comment_shrunk) {
		# Guess what should be in a template? -Brian
		my $link = linkComment({
			sid	=> $comment->{sid},
			cid	=> $comment->{cid},
			pid	=> $comment->{cid},
			subject	=> 'Read the rest of this comment...',
			subject_only => 1,
		}, 1);
		$comment_to_display = "$comment->{comment}<P><B>$link</B>";
	} elsif ($user->{nosigs}) {
		$comment_to_display = $comment->{comment};
	} else {
		$comment_to_display = "$comment->{comment}<BR>$comment->{sig}";
	}

	$time_to_display = timeCalc($comment->{date});
	unless ($user->{noscores}) {
		$score_to_display .= "(Score:";
		$score_to_display .= length($comment->{points}) ? $comment->{points} : "?";
		if ($comment->{reason}) {
			$score_to_display .= ", $reasons->{$comment->{reason}}{name}";
		}
		$score_to_display .= ")";
	}

	if ($comment->{sid} && $comment->{cid}) {
		$comment_link_to_display = qq| (<A HREF="$gSkin->{rootdir}/comments.pl?sid=$comment->{sid}&amp;cid=$comment->{cid}">#$comment->{cid}</A>)|;
	} else {
		$comment_link_to_display = " ";
	}

	if (isAnon($comment->{uid})) {
		$user_nick_to_display = strip_literal($comment->{nickname});
	} else {
		my $nick = fixparam($comment->{nickname});

		my $homepage = $comment->{homepage} || '';
		$homepage = '' if length($homepage) <= 8;
		my $homepage_maxlen = $constants->{comment_homepage_disp} || 50;
		if (length($homepage) > $homepage_maxlen) {
			my $halflen = $homepage_maxlen/2 - 5;
			$halflen = 10 if $halflen < 10;
			$homepage = substr($homepage, 0, $halflen) . "..." . substr($homepage, -$halflen);
		}
		$homepage = strip_literal($homepage);

		$userinfo_to_display = "";
		$userinfo_to_display = qq[<A HREF="$comment->{homepage}">$homepage</A>]
			if $homepage;
		if ($comment->{journal_last_entry_date} =~ /[1-9]/) {
			$userinfo_to_display .= " | " if $userinfo_to_display;
			$userinfo_to_display .= sprintf('Last Journal: <A HREF="%s/~%s/journal/">%s</A>',
				$constants->{real_rootdir},
				$nick,
				timeCalc($comment->{journal_last_entry_date})
			);
		}
		$userinfo_to_display = "<BR><FONT SIZE=\"-1\">($userinfo_to_display)</FONT>" if $userinfo_to_display;

		my $nick_literal = strip_literal($comment->{nickname});
		my $nick_param = fixparam($comment->{nickname});
		$user_nick_to_display = qq{<A HREF="$constants->{real_rootdir}/~$nick_param">$nick_literal ($comment->{uid})</A>};
		if ($constants->{plugin}{Subscribe} && $constants->{subscribe}
			&& $comment->{subscriber_bonus} eq 'yes') {
			if ($constants->{plugin}{FAQSlashdot}) {
				$user_nick_to_display .= qq{ <A HREF="/faq/com-mod.shtml#cm2600">*</A>};
			} else {
				$user_nick_to_display .= " *";
			}
		}
		if ($comment->{fakeemail}) {
			my $mail_literal = strip_literal($comment->{fakeemail_vis});
			my $mail_param = fixparam($comment->{fakeemail});
			$user_email_to_display = qq{ &lt;<A HREF="mailto:$mail_param">$mail_literal</A>&gt;};
		}
	}

	$zoosphere_display = " ";
	unless ($user->{is_anon} || isAnon($comment->{uid}) || $comment->{uid} == $user->{uid}) {
		my $person = $comment->{uid};
		if (!$user->{people}{FRIEND()}{$person} && !$user->{people}{FOE()}{$person} && !$user->{people}{FAN()}{$person} && !$user->{people}{FREAK()}{$person} && !$user->{people}{FOF()}{$person} && !$user->{people}{EOF()}{$person}) {
				$zoosphere_display .= qq|<A HREF="$gSkin->{rootdir}/zoo.pl?op=check&amp;type=friend&amp;uid=$person"><IMG BORDER="0" SRC="$constants->{imagedir}/neutral.gif" ALT="Alter Relationship" TITLE="Alter Relationship"></A>|;
		} else {
			if ($user->{people}{FRIEND()}{$person}) {
				my $title = $user->{people}{people_bonus_friend} ? "Friend ($user->{people}{people_bonus_friend})" : "Friend";
				$zoosphere_display .= qq|<A HREF="$gSkin->{rootdir}/zoo.pl?op=check&amp;uid=$person"><IMG BORDER="0" SRC="$constants->{imagedir}/friend.gif" ALT="$title" TITLE="$title"></A>|;
			}
			if ($user->{people}{FOE()}{$person}) {
				my $title = $user->{people}{people_bonus_foe} ? "Foe ($user->{people}{people_bonus_foe})" : "Foe";
				$zoosphere_display .= qq|<A HREF="$gSkin->{rootdir}/zoo.pl?op=check&amp;uid=$person"><IMG BORDER="0" SRC="$constants->{imagedir}/foe.gif" ALT="$title" TITLE="$title"></A>|;
			}
			if ($user->{people}{FAN()}{$person}) {
				my $title = $user->{people}{people_bonus_fan} ? "Fan ($user->{people}{people_bonus_fan})" : "Fan";
				$zoosphere_display .= qq|<A HREF="$gSkin->{rootdir}/zoo.pl?op=check&amp;uid=$person"><IMG BORDER="0" SRC="$constants->{imagedir}/fan.gif" ALT="$title" TITLE="$title"></A>|;
			}
			if ($user->{people}{FREAK()}{$person}) {
				my $title = $user->{people}{people_bonus_freak} ? "Freak ($user->{people}{people_bonus_freak})" : "Freak";
				$zoosphere_display .= qq|<A HREF="$gSkin->{rootdir}/zoo.pl?op=check&amp;uid=$person"><IMG BORDER="0" SRC="$constants->{imagedir}/freak.gif" ALT="$title" TITLE="$title"></A>|;
			}
			if ($user->{people}{FOF()}{$person}) {
				my $title = $user->{people}{people_bonus_fof} ? "Friend of a Friend ($user->{people}{people_bonus_fof})" : "Friend of a Friend";
				$zoosphere_display .= qq|<A HREF="$gSkin->{rootdir}/zoo.pl?op=check&amp;uid=$person"><IMG BORDER="0" SRC="$constants->{imagedir}/fof.gif" ALT="$title" TITLE="$title"></A>|;
			}
			if ($user->{people}{EOF()}{$person}) {
				my $title = $user->{people}{people_bonus_eof} ? "Foe of a Friend ($user->{people}{people_bonus_eof})" : "Foe of a Friend";
				$zoosphere_display .= qq|<A HREF="$gSkin->{rootdir}/zoo.pl?op=check&amp;uid=$person"><IMG BORDER="0" SRC="$constants->{imagedir}/eof.gif" ALT="$title" TITLE="$title"></A>|;
			}
		}
	}
	
	my $title = qq|<A NAME="$comment->{cid}"><B>$comment->{subject}</B></A>|;
	my $return = <<EOT;
			<TR><TD BGCOLOR="$user->{colors}{bg_2}">
				<FONT SIZE="3" COLOR="$user->{colors}{fg_2}">
				$title $score_to_display
				</FONT>
				<BR>by $user_nick_to_display$zoosphere_display$user_email_to_display
				on $time_to_display$comment_link_to_display
				$userinfo_to_display $comment->{ipid_display}
			</TD></TR>
			<TR><TD>
				$comment_to_display
			</TD></TR>
EOT

	# Do not display comment navigation and reply links if we are in
	# archive mode or if we are in metamod. Nicknames are always equal to
	# '-' in metamod. This logic is extremely old and could probably be
	# better formulated.
	if ($user->{mode} ne 'archive'
		&& $user->{mode} ne 'metamod'
		&& $comment->{nickname} ne "-") { # this last test probably useless
		my @link = ( );

		push @link, linkComment({
			sid	=> $comment->{sid},
			pid	=> $comment->{cid},
			op	=> 'Reply',
			subject	=> 'Reply to This',
			subject_only => 1,
		}) unless $user->{state}{discussion_archived};

		push @link, linkComment({
			sid	=> $comment->{sid},
			cid	=> $comment->{original_pid},
			pid	=> $comment->{original_pid},
			subject	=> 'Parent',
			subject_only => 1,
		}, 1) if $comment->{original_pid};

		push @link, createSelect("reason_$comment->{cid}",
			$reasons, '', 1, 1) if $can_mod
				&& $user->{mode} ne 'archive'
				&& ( !$user->{state}{discussion_archived}
					|| $constants->{comments_moddable_archived} );

		push @link, qq|<INPUT TYPE="CHECKBOX" NAME="del_$comment->{cid}">|
			if $user->{is_admin};

		my $link = join(" | ", @link);

		if (@link) {
			$return .= <<EOT;
				<TR><TD>
					<FONT SIZE="2">
					[ $link ]
					</FONT>
				</TD></TR>
EOT
		}

	}
	return $return;
}

1;

__END__

=head1 BENDER'S TOP TEN MOST FREQUENTLY UTTERED WORDS

=over 4

=item 1.

ass

=item 2.

daffodil

=item 3.

shiny

=item 4.

my

=item 5.

bite

=item 6.

pimpmobile

=item 7.

up

=item 8.

yours

=item 9.

chumpette

=item 10.

chump

=back

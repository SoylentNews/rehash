# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Utility::Comments;

=head1 NAME

Slash::Utility::Comments - Comments API for Slash


=head1 SYNOPSIS

=head1 DESCRIPTION

	use Slash::Utility;
	# do not use this module directly

=head1 EXPORTED FUNCTIONS

=cut

use strict;
use Fcntl;
use Slash::Utility::Access;
use Slash::Utility::Data;
use Slash::Utility::Display;
use Slash::Utility::Environment;
use Slash::Display;
use Slash::Hook;
use Slash::Constants qw(:strip :people :messages);

use base 'Exporter';

our $VERSION = $Slash::Constants::VERSION;
our @EXPORT  = qw(
	constrain_score dispComment displayThread printComments
	jsSelectComments commentCountThreshold commentThresholds 
	selectComments preProcessReplyForm makeCommentBitmap parseCommentBitmap
	getPoints preProcessComment postProcessComment prevComment saveComment
);


########################################################
# Behold, faster threaded comments
sub selectCommentsNew {
	my($discussion, $cid, $options) = @_;
	my $slashdb = getCurrentDB();
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $mod_reader = getObject("Slash::$constants->{m1_pluginname}", { db_type => 'reader' });
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my($min, $max) = ($constants->{comment_minscore}, $constants->{comment_maxscore});
	my $num_scores = $max - $min + 1;
	$cid ||= 0;

	my $commentsort = defined $options->{commentsort}
		? $options->{commentsort}
		: $user->{commentsort};

	# No "ignore threads" if you're asking for Threaded. That's fucking stupid.
	if($commentsort == 5 || $commentsort == 1) {
		$commentsort = 1;
	}
	else {
		$commentsort = 0;
	}

	my $comments; # Let's keep this as small as possible
	
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

	my ($thisComment, $pages);
	my $gcfu_opt = {
		cache_read_only => $cache_read_only,
		one_cid_only    => $options->{one_cid_only},
		# They should sort faster if we let the db give an attempt at pre-sorting
		order_dir	=> $commentsort == 1 ? "DESC" : "ASC",
		
	};
	# We also need to build a cid list for sending to saveCommentReadLog.
	# Let's cheat though and only put the one cid we care about in the array.
	# We don't have all the current comments so this needs to be a separate db call.
	my @cids = ();
	if ($options->{force_read_from_master}) {
		($thisComment, $pages) = $slashdb->getThreadedCommentsForUser($discussion->{id}, $cid, $gcfu_opt);
		push(@cids, $slashdb->sqlSelect("max(cid)", "comments", "sid=$discussion->{id}"));
	} else {
		($thisComment, $pages) = $reader->getThreadedCommentsForUser($discussion->{id}, $cid, $gcfu_opt);
		push(@cids, $reader->sqlSelect("max(cid)", "comments", "sid=$discussion->{id}"));
	}
	
	if (!$thisComment) {
		_print_cchp($discussion);
		return ( {}, 0 );
	}

	my $reasons = undef;
	if ($mod_reader) {
		$reasons = $mod_reader->getReasons();
	}

	my $max_uid = $reader->countUsers({ max => 1 });

	# We first loop through the comments and assign bonuses
	foreach my $C (@$thisComment) {
		$C->{points} = getPoints($C, $user, $min, $max, $max_uid, $reasons); # , $errstr
		$C->{legacy} = 0;
	}
	# Newest First
	if($commentsort == 1) {
		@$thisComment = sort {
			$b->{pid} <=> $a->{pid} || $b->{cid} <=> $a->{cid}
		} @$thisComment;
	}
	# Oldest First and invalid sort modes
	else {
		@$thisComment = sort {
			$a->{pid} <=> $b->{pid} || $a->{cid} <=> $b->{cid}
		} @$thisComment;
	}
	
	# This loop mainly takes apart the array and builds 
	# a hash with the comments in it.  Each comment is
	# in the index of the hash (based on its cid).
	foreach my $C (@$thisComment) {
		# Let us fill the hash range for hitparade
		$comments->{0}{totals}[$comments->{0}{total_keys}{$C->{points}}]++;

		# So we save information. This will only have data if we have 
		# happened through this cid while it was a pid for another
		# comments. -Brian
		my $tmpkids = $comments->{$C->{cid}}{kids};
		my $tmpvkids = $comments->{$C->{cid}}{visiblekids};

		# We save a copy of the comment in the root of the hash
		# which we will use later to find it via its cid
		$comments->{$C->{cid}} = $C;

		# Kids is what displayThread will actually use.
		$comments->{$C->{cid}}{kids} = $tmpkids || [];
		$comments->{$C->{cid}}{visiblekids} = $tmpvkids || 0;

		# The comment pushes itself onto its parent's
		# kids array.
		push @{$comments->{$C->{pid}}{kids}}, $C->{cid};

		# Increment the parent comment's count of visible kids.
		# All kids are now technically visible.
		# Previously invisible kids will now simply be collapsed.
		$comments->{$C->{pid}}{visiblekids}++;
	}
	
	# Now let's calcualte cumulative totals form the individual totals
	# Run from top down and add the total from x+1 to the current one
	for (my $x=($max-1); $x >= $min; $x--) {
		$comments->{0}{totals}[$comments->{0}{total_keys}{$x}] = $comments->{0}{totals}[$comments->{0}{total_keys}{$x}] + $comments->{0}{totals}[$comments->{0}{total_keys}{$x+1}];
	}
	
	# Should be unnecessary jiggery-fuckery but we'll leave it in for now.
	my @phantom_cids =
		grep { $_ > 0 && !defined $comments->{$_}{cid} }
			keys %$comments;
	delete @$comments{@phantom_cids};

	my $count = scalar(@$thisComment);

	_print_cchp($discussion, $count, $comments->{0}{totals});
	if(defined($form->{markunread}) && $form->{markunread}) {
		$slashdb->clearCommentReadLog($discussion->{id}, $user->{uid}) || print STDERR "\nclearCommentReadLog failed for discussion_id: $discussion->{id}, uid: $user->{uid}\n";
	}	
	if(!$form->{noupdate} && !$form->{cid} && $count > 0 && !defined($form->{cchp}) && !(isAnon($user->{uid}))) {
		$slashdb->saveCommentReadLog(\@cids, $discussion->{id}, $user->{uid}) or print STDERR "\nFIX ME: Could not saveCommentReadLog\n";
	}

	my $numPages = $pages ? scalar(@$pages) : 0;
	
	$count = $reader->sqlSelect('count(cid)', 'comments', "sid=$discussion->{id}");

	return($comments, $numPages, $count);
}

########################################################
# Behold, faster flat mode comments
sub selectCommentsFlat {
	my($discussion, $cid, $options) = @_;
	my $slashdb = getCurrentDB();
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $mod_reader = getObject("Slash::$constants->{m1_pluginname}", { db_type => 'reader' });
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my($min, $max) = ($constants->{comment_minscore},
			  $constants->{comment_maxscore});
	my $num_scores = $max - $min + 1;
	$cid ||= 0;

	my $commentsort = defined $options->{commentsort}
		? $options->{commentsort}
		: $user->{commentsort};

	# Ignore threads if you're asking for Flat. That's fucking stupid.
	if($commentsort == 1 || $commentsort == 5) {
		$commentsort = 1;
	}
	else {
		$commentsort = 0;
	}

	my $comments; # Let's keep this as small as possible
	
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

	my ($thisComment, $pages);
	my $gcfu_opt = {
		cache_read_only => $cache_read_only,
		one_cid_only    => $options->{one_cid_only},
		# They should sort faster if we let the db give an attempt at pre-sorting
		order_dir	=> $commentsort == 1 ? "DESC" : "ASC",
	};
	# We also need to build a cid list for sending to saveCommentReadLog.
	# Let's cheat though and only put the one cid we care about in the array.
	# We don't have all the current comments so this needs to be a separate db call.
	my @cids = ();
	if ($options->{force_read_from_master}) {
		($thisComment, $pages) = $slashdb->getFlatCommentsForUser($discussion->{id}, $cid, $gcfu_opt);
		push(@cids, $slashdb->sqlSelect("max(cid)", "comments", "sid=$discussion->{id}"));
	} else {
		($thisComment, $pages) = $reader->getFlatCommentsForUser($discussion->{id}, $cid, $gcfu_opt);
		push(@cids, $reader->sqlSelect("max(cid)", "comments", "sid=$discussion->{id}"));
	}
	
	if (!$thisComment) {
		_print_cchp($discussion);
		return ( {}, 0 );
	}

	my $reasons = undef;
	if ($mod_reader) {
		$reasons = $mod_reader->getReasons();
	}

	my $max_uid = $reader->countUsers({ max => 1 });

	# We first loop through the comments and assign bonuses
	foreach my $C (@$thisComment) {
		$C->{points} = getPoints($C, $user, $min, $max, $max_uid, $reasons); # , $errstr
		$C->{legacy} = 0;
	}
	# Newest First
	if($commentsort == 1) {
		@$thisComment = sort {
			$b->{cid} <=> $a->{cid}
		} @$thisComment;
	}
	# Oldest First and invalid sort modes
	else {
		@$thisComment = sort {
			$a->{cid} <=> $b->{cid}
		} @$thisComment;
	}
	
	# This loop mainly takes apart the array and builds 
	# a hash with the comments in it.  Each comment is
	# in the index of the hash (based on its cid).
	$comments->{0}{visiblekids} = 0;
	$comments->{0}{kids} = [];
	foreach my $C (@$thisComment) {
		# We save a copy of the comment in the root of the hash
		# which we will use later to find it via its cid
		$comments->{$C->{cid}} = $C;

		# Let us fill the hash range for hitparade
		$comments->{0}{totals}[$comments->{0}{total_keys}{$C->{points}}]++;

		# So we save information. This will only have data if we have 
		# happened through this cid while it was a pid for another
		# comments. -Brian
		#my $tmpkids = $comments->{$C->{cid}}{kids};
		#my $tmpvkids = $comments->{$C->{cid}}{visiblekids};

		# Kids is what displayThread will actually use.
		$comments->{$C->{cid}}{kids} = [];
		$comments->{$C->{cid}}{visiblekids} = 0;

		# The comment pushes itself onto its parent's
		# kids array for when cid is set and we need its thread.
		# Increment the parent comment's count of visible kids.
		# All kids are now technically visible.
		# Previously invisible kids will now simply be collapsed.
		
		if ($cid){
			push @{$comments->{$C->{pid}}{kids}}, $C->{cid};
			$comments->{$C->{pid}}{visiblekids}++;
		}

		# For normal mode root [0] is the parent for all and no other kids
		# are set.
		push(@{$comments->{0}{kids}}, $C->{cid});
		$comments->{0}{visiblekids}++;
	}
	# Now let's calcualte cumulative totals form the individual totals
	# Run from top down and add the total from x+1 to the current one
	for (my $x=($max-1); $x >= $min; $x--) {
		$comments->{0}{totals}[$comments->{0}{total_keys}{$x}] = $comments->{0}{totals}[$comments->{0}{total_keys}{$x}] + $comments->{0}{totals}[$comments->{0}{total_keys}{$x+1}];
	}
	
	# Should be unnecessary jiggery-fuckery but we'll leave it in for now.
	my @phantom_cids =
		grep { $_ > 0 && !defined $comments->{$_}{cid} }
			keys %$comments;
	delete @$comments{@phantom_cids};

	my $count = scalar(@$thisComment);

	_print_cchp($discussion, $count, $comments->{0}{totals});
	if(defined($form->{markunread}) && $form->{markunread}) {
		$slashdb->clearCommentReadLog($discussion->{id}, $user->{uid}) || print STDERR "\nclearCommentReadLog failed for discussion_id: $discussion->{id}, uid: $user->{uid}\n";
	}
	if(!$form->{noupdate} && !$form->{cid} && $count > 0 && !defined($form->{cchp}) && !(isAnon($user->{uid}))) {
		$slashdb->saveCommentReadLog(\@cids, $discussion->{id}, $user->{uid}) or print STDERR "\nFIX ME: Could not saveCommentReadLog\n";
	}

	$count = $reader->sqlSelect('count(cid)', 'comments', "sid=$discussion->{id}");

	return($comments, $pages, $count);
}

########################################################
# Behold, the beast that is threaded comments
sub selectComments {
	my($discussion, $cid, $options) = @_;
	my $slashdb = getCurrentDB();
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $mod_reader = getObject("Slash::$constants->{m1_pluginname}", { db_type => 'reader' });
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my($min, $max) = ($constants->{comment_minscore}, 
			  $constants->{comment_maxscore});
	my $num_scores = $max - $min + 1;
	$cid ||= 0;


	# it's a bit of a drag, but ... oh well! 
	# print_cchp gets messed up with d2, so we just punt and have
	# selectComments called twice if necessary, the first time doing
	# print_cchp, then blanking that out so it is not done again -- pudge
	my $shtml = 0;

	my $commentsort = defined $options->{commentsort}
		? $options->{commentsort}
		: $user->{commentsort};

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

	my $reasons = undef;
	if ($mod_reader) {
		$reasons = $mod_reader->getReasons();
	}

	my $max_uid = $reader->countUsers({ max => 1 });

	# We first loop through the comments and assign bonuses and
	# and such.
	# We also need to build a cid list for sending to saveCommentReadLog,
	# might as well do it now.
	my @cids = ();
	foreach my $C (@$thisComment) {
		push(@cids, $C->{cid});
		# By setting pid to zero, we remove the threaded
		# relationship between the comments. Don't ignore threads
		# in forums, or when viewing a single comment (cid > 0)
		$C->{pid} = 0 if $commentsort > 3
			&& !$cid
			&& $user->{mode} ne 'parents'; # Ignore Threads

		# I think instead we want something like this... (not this
		# precisely, it munges up other things).
		# I'm still looking into how to get parent links and
		# children to show up properly in flat mode. - Jamie 2002/07/30
		$C->{points} = getPoints($C, $user, $min, $max, $max_uid, $reasons); # , $errstr
		$C->{legacy} = 1;
	}

	my($oldComment, %old_comments);
	# If we are sorting by highest score we resort to figure in bonuses
	if ($commentsort == 3) {
		@$thisComment = sort {
			$b->{points} <=> $a->{points} || $a->{cid} <=> $b->{cid}
		} @$thisComment;
	} elsif ($commentsort == 1 || $commentsort == 5) {
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
	# in the index of the hash (based on its cid).
	foreach my $C (@$thisComment) {
		# Let us fill the hash range for hitparade
		$comments->{0}{totals}[$comments->{0}{total_keys}{$C->{points}}]++;  

		# So we save information. This will only have data if we have 
		# happened through this cid while it was a pid for another
		# comments. -Brian
		my $tmpkids = $comments->{$C->{cid}}{kids};
		my $tmpvkids = $comments->{$C->{cid}}{visiblekids};

		# We save a copy of the comment in the root of the hash
		# which we will use later to find it via its cid
		$comments->{$C->{cid}} = $C;

		# Kids is what displayThread will actually use.
		$comments->{$C->{cid}}{kids} = $tmpkids || [];
		$comments->{$C->{cid}}{visiblekids} = $tmpvkids || 0;

		# The comment pushes itself onto its parent's
		# kids array.
		push @{$comments->{$C->{pid}}{kids}}, $C->{cid};

		# Increment the parent comment's count of visible kids.
		# All kids are now technically visible.
		# Previously invisible kids will now simply be collapsed.
		$comments->{$C->{pid}}{visiblekids}++;
	}

	# After that loop, there may be comments in the $comments hashref
	# which have no visible parents and thus which incremented an
	# otherwise-empty comment's visiblekids field and appended to an
	# otherwise-empty kids arrayref.  For cleanliness' sake, eliminate
	# those comments.  We do leave "comment 0" alone, though.
	if (!$oldComment) {
		my @phantom_cids =
			grep { $_ > 0 && !defined $comments->{$_}{cid} }
			keys %$comments;
		delete @$comments{@phantom_cids};
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

	if ($oldComment) {
		my @new_seen;
		for my $this_cid (sort { $a <=> $b } keys %$comments) {
			next unless $this_cid;
			my $C = $comments->{$this_cid};

			# && !$options->{existing}{ $C->{pid} }
			while ($C->{pid}) {
				my $parent = $comments->{ $C->{pid} } || {};

				if (!$parent || !$parent->{kids} || !$parent->{cid} || !defined($parent->{pid}) || !defined($parent->{points})) {
					# parents of our main cid, so spend time
					# finding it ...
					if ($cid && $C->{pid} < $cid) {
						$parent = $old_comments{ $C->{pid} };
						push @new_seen, $C->{pid};
						$count++;
					} else {
						$parent = {
							cid      => $C->{pid},
							pid      => ($old_comments{ $C->{pid} } && $old_comments{ $C->{pid} }{ pid }) || 0,
							opid     => ($old_comments{ $C->{pid} } && $old_comments{ $C->{pid} }{ original_pid }) || 0,
							kids     => [ ],
							points   => -2,
							dummy    => 1,
							%$parent,
						};
						$parent->{opid} ||= $parent->{pid};
					}
					$comments->{ $C->{pid} } = $parent;
				}

				unless (grep { $_ == $C->{cid} } @{$parent->{kids}}) {
					push @{$parent->{kids}}, $C->{cid};
				}
				if ($parent->{pid} == 0) {
					unless (grep { $_ == $parent->{cid} } @{$comments->{0}{kids}}) {
						push @{$comments->{0}{kids}}, $parent->{cid};
					}
				} else {
				}
				$C = $parent;
			}
		}
	}

	_print_cchp($discussion, $count, $comments->{0}{totals});
	
	if(defined($form->{markunread}) && $form->{markunread}) {
		$slashdb->clearCommentReadLog($discussion->{id}, $user->{uid}) || print STDERR "\nclearCommentReadLog failed for discussion_id: $discussion->{id}, uid: $user->{uid}\n";
	}
	if(!$form->{noupdate} && !$form->{cid} && $count > 0 && !defined($form->{cchp}) && !(isAnon($user->{uid}))) {
		$slashdb->saveCommentReadLog(\@cids, $discussion->{id}, $user->{uid}) or print STDERR "\nFIX ME: Could not saveCommentReadLog\n";
	}

	return($comments, $count);
}

# save counts of comments at each threshold value
sub commentCountThreshold {
	my($comments, $pid, $roots_hash) = @_;
	my $user = getCurrentUser();
	$pid ||= 0;
	$roots_hash ||= {};

	my %thresh_totals;
	# init
	for my $i (-1..6) {
		# T cannot be higher than HT
		for my $j ($i..6) {
			# 1: hidden, 2: oneline, 3: full
			for my $m (1..3) {
				$thresh_totals{$i}{$j}{$m} ||= 0;
			}
		}
	}

	for my $cid (grep $_, keys %$comments) {
		next if $comments->{$cid}{dummy};

		my($T, $HT) = commentThresholds($comments->{$cid}, $roots_hash->{$cid}, $user);
		if ($cid == $pid) {
			$HT += 7; # THE root comment is always full
		}

		for my $i (-1..$T) {
			for my $j ($i..$HT) {
				$thresh_totals{$i}{$j}{3}++;
			}
			for my $j (($HT+1)..6) {
				next if $i > $j;  # T cannot be higher than HT
				$thresh_totals{$i}{$j}{2}++;
			}
		}

		for my $i (($T+1)..6) {
			for my $j ($i..6) {
				$thresh_totals{$i}{$j}{1}++;
			}
		}
	}
	return \%thresh_totals;
}

sub commentThresholds {
	my($comment, $root, $user) = @_;
	$user ||= getCurrentUser();

	my $T  = $comment->{points};
	my $HT = $T;

	if (!$user->{is_anon} && $user->{uid} == $comment->{uid}) {
		$T = 5;
	}

	if ($root) {
		$HT++;
	}

	return($T, $HT);
}


sub _get_thread {
	my($comments, $pid, $newcomments) = @_;
	$newcomments ||= {};
	$newcomments->{$pid} = $comments->{$pid};
	if ($comments->{$pid}{kids}) {
		for (@{$comments->{$pid}{kids}}) {
			_get_thread($comments, $_, $newcomments);
		}
	}
	return $newcomments;
}

sub parseCommentBitmap {
	my($bitmap) = @_;
	return {} unless $bitmap;
	my $lastcid = 0;
	my %comments;
	for my $cid (split /,/, $bitmap) {
		$cid = $lastcid ? $lastcid + $cid : $cid;
		$comments{$cid} = 1;
		$lastcid = $cid;
	}
	return \%comments;
}

sub makeCommentBitmap {
	my($comments, $old) = @_;
	my $lastcid = 0;
	my @bitmap;
	for my $cid (sort { $a <=> $b } ((ref($comments) eq 'HASH')
			? keys %$comments
			: @$comments
		)
	) {
		push @bitmap, $lastcid ? $cid - $lastcid : $cid;
		$lastcid = $cid;
	}

	my $bitmap = join ',', @bitmap;

	if ($old) {
		return $old unless $bitmap;

		my @old = split /,/, $old, 2;
		$old[0] = $old[0] - $lastcid;
		return join ',', $bitmap, @old;
	}

	return $bitmap;
}


# this really should have been getData all along
sub getError {
	my($value, $hashref, $nocomm) = @_;
	$hashref ||= {};
	$hashref->{value} = $value;

	# this is a cheap hack to NOT print titlebar in getError if we
	# are calling from ajax.pl ... easier than reorganizing the code
	# for now -- pudge 2008/03/04
	# turn off for now
	# not using ajax -- paulej72 2014/07/31
	# for (0..9) {
	#	 if ((caller($_))[1] =~ /\bajax\.pl$/) {
	#	 	$hashref->{no_titlebar} = 1;
	#	 	last;
	#	 }
	# }

	return slashDisplay('errors', $hashref,
		{ Return => 1, Nocomm => $nocomm, Page => 'comments' });
}

sub constrain_score {
	my($score) = @_;
	my $constants = getCurrentStatic();
	my($min, $max) = ($constants->{comment_minscore}, $constants->{comment_maxscore});
	$score = $min if $score < $min;
	$score = $max if $score > $max;
	return $score;
}

sub getPoints {
	my($C, $user, $min, $max, $max_uid, $reasons, $errstr) = @_;
#use Data::Dumper; print STDERR scalar(gmtime) . " getPoints errstr='$errstr' C: " . Dumper($C) if !defined($C->{pointsorig}) || !defined($C->{tweak_orig}) || !defined($C->{points}) || !defined($C->{tweak});
	my $hr = {
		score_start => constrain_score($C->{pointsorig} + $C->{tweak_orig}),
		moderations => constrain_score($C->{points} + $C->{tweak}) - constrain_score($C->{pointsorig} + $C->{tweak_orig}),
	};
	my $points = $hr->{score_start} || 0;
	my $constants = getCurrentStatic();
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	# User can setup to give points based on size.
	my $len = $C->{len} || length($C->{comment});
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
	if ($reasons && $C->{reason}) {
		my $reason_name = $reasons->{$C->{reason}}{name};
		if ($reason_name && $user->{"reason_alter_$reason_name"}) {
			$hr->{reason_bonus} =
				$user->{"reason_alter_$reason_name"};
		}
	} else {
		$hr->{reason_bonus} = 0;
	}

	# Keep your friends close but your enemies closer.
	# Or ignore them, we don't care.
	if ($user->{people} && $user->{uid} != $C->{uid}) {
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
	
	
	my $subscriber_bonus = 0;
	if ($constants->{plugin}{Subscribe} && $constants->{subscribe} && $constants->{subscriber_bonus}) {
		my $hide_subscription = $reader->getUser($C->{uid}, 'hide_subscription');
		if (isSubscriber($C->{uid}) && !$hide_subscription) {
			$subscriber_bonus = 1;
		}
	}
	
	# And, the poster-was-a-subscriber bonus
	if ($user->{subscriber_bonus} && $subscriber_bonus) {
		$hr->{subscriber_bonus} =
			$user->{subscriber_bonus};
	}

	for my $key (grep !/^score_/, keys %$hr) { $points += $hr->{$key} || 0 }
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
	return unless $form->{ssi} && $form->{ssi} eq 'yes' && $form->{cchp};
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

# I wonder if much of this logic should be moved out to the theme.
# This logic can then be placed at the theme level and would eventually
# become what is put into $comment->{no_moderation}. As it is, a lot
# of the functionality of the moderation engine is intrinsically linked
# with how things behave on Slashdot.	- Cliff 6/6/01
# I rearranged the order of these tests (check anon first for speed)
# and pulled some of the tests from dispComment
# back here as well, just to have it all in one place. - Jamie 2001/08/17
# And now it becomes a function of its own - Jamie 2002/02/26
sub _can_mod {
	my($comment) = @_;
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	# Do some easy and high-priority initial tests.  If any of
	# these is true, this comment is not moderatable, and these
	# override the ACL and seclev tests.
	return 0 if !$comment;
	return 0 unless defined($comment->{cid});
	
	return 0 if
		    $user->{is_anon}
		|| !$constants->{m1}
		||  $comment->{no_moderation}
		||  _is_mod_banned($user);
	
	# More easy tests.  If any of these is true, the user has
	# authorization to mod any comments, regardless of any of
	# the tests that come later.
	return 1 if
		    $constants->{authors_unlimited}
		&&  $user->{seclev} >= $constants->{authors_unlimited};
	return 1 if
		    $user->{acl}{modpoints_always};

	# OK, the user is an ordinary user, so see if they have mod
	# points and do some other fairly ordinary tests to try to
	# rule out whether they can mod.
	# No modding your own comments
	if(defined($user->{uid}) && defined($comment->{uid})) {
		return 0 if $user->{uid} eq $comment->{uid};
	}
	
	return 0 if $user->{points} <= 0 || !$user->{willing};
		
	return 0 if defined($comment->{ipid}) && $comment->{ipid} eq $user->{ipid};
		
	return 0 if
		    $constants->{mod_same_subnet_forbid}
		&&	defined($comment->{subnetid})
		&&  $comment->{subnetid} eq $user->{subnetid};
	
	return 0 if
		   !$constants->{comments_moddable_archived}
		&&  $user->{state}{discussion_archived};

	# Last test; this one involves a bit of calculation to set
	# time_unixepoch in the comment structure itself, which is
	# why we saved it for last.  timeCalc() is not the world's
	# fastest function.
	$comment->{time_unixepoch} ||= timeCalc($comment->{date}, "%s", 0);
	my $hours = $constants->{comments_moddable_hours}
		|| 24 * $constants->{archive_delay};
	return 0 if $comment->{time_unixepoch} < time - 3600*$hours;

	# All the ordinary tests passed, there's nothing stopping
	# this user from modding this comment.
	return 1;
}


sub _can_mod_any {
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	
	return 0 if
		    $user->{is_anon}
		||	!$constants->{m1}
		||	_is_mod_banned($user)
		||	$user->{state}->{discussion_future_nopost};
	
	# More easy tests.  If any of these is true, the user has
	# authorization to mod any comments, regardless of any of
	# the tests that come later.
	return 1 if
		    $constants->{authors_unlimited}
		&&  $user->{seclev} >= $constants->{authors_unlimited};
	return 1 if
		    $user->{acl}{modpoints_always};

	# OK, the user is an ordinary user, so see if they have mod
	# points and do some other fairly ordinary tests to try to
	# rule out whether they can mod.
	
	return 0 if $user->{points} <= 0 || !$user->{willing};
	
	return 0 if
		   !$constants->{comments_moddable_archived}
		&&  $user->{state}{discussion_archived};

	
	return 1;
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
	my $mode = defined($form->{mode}) ? $form->{mode} : $user->{mode};
	my $pretext = '';
	$options ||= {};

	

	if (!$discussion || !$discussion->{id}) {
		my $retval =  Slash::getData('no_such_sid', '', '');
		return $retval if $options->{Return};
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
		   $mode eq 'nocomment'
		|| $options->{just_submitted}
	);
	# For now, until we are able to pull hitparade into discussions so we can
	# read it here, don't use the one_cid_only optimization feature.
	$sco->{one_cid_only} = 0;

	my $comments;
	my ($count, $pages) = (0, 0);
	if(($discussion->{legacy} eq 'yes') || (defined($form->{cchp}))) {
		($comments, $count) = selectComments($discussion, $cidorpid, $sco);
		$lvl ++;
	}
	else {
		if($mode eq 'flat') {
			($comments, $pages, $count) = selectCommentsFlat($discussion, $cidorpid, $sco);
		}
		elsif($mode eq 'threadtos' || $mode eq 'threadtng' ) {
			($comments, $pages, $count) = selectCommentsNew($discussion, $cidorpid, $sco);
		}
		else {
			print STDERR "wtf, no such mode as $mode";
			return "wtf, no such mode";
		}
	}

	if ($cidorpid && !exists($comments->{$cidorpid})) {
		# No such comment in this discussion.
		my $d = Slash::getData('no_such_comment', {
			sid => $discussion->{id},
			cid => $cid,
		}, '');
		return $d if $options->{Return};
		print $d;
		return 0;
	}

	# Should I index or just display normally?
	my $cc = 0;
	$cc = $comments->{$cidorpid}{visiblekids}
		if $comments->{$cidorpid}
			&& $comments->{$cidorpid}{visiblekids};

	$lvl++ if $mode ne 'flat'
		&& ( $user->{commentlimit} > $cc );
	
	my $archive_text;
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
		$archive_text = slashDisplay('printCommNoArchive', { discussion => $discussion }, { Return => 1 });
	}

	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $parent = $reader->getDiscussionParent($form->{sid});
	$pretext .= slashDisplay('printCommentsMain', {
		comments	=> $comments,
		title		=> $discussion->{title},
		'link'		=> $discussion->{url},
		count		=> $count,
		pages		=> $pages,
		page		=> defined($form->{page}) ? $form->{page} : 1,
		mode		=> $mode,
		parent		=> $parent,
		sid		=> $discussion->{id},
		cid		=> $cid,
		pid		=> $pid,
		lvl		=> $lvl,
		options		=> $options,
		archive_text => $archive_text,
	}, { Return => $options->{Return}} );

	return $options->{Return} ? $pretext: '' if $user->{state}{nocomment} || $mode eq 'nocomment';

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
	# Index go bye-bye, just use $cc --TMB
	my $lcp = $pages ? linkCommentPages($discussion->{id}, $pid, $cid, $cc, $pages, $mode, $discussion->{legacy}) : "";
	if($form->{cid}) {
		$lcp = "";
	}
		# Saved for now --TMB
		#= ($user->{mode} eq 'flat' || $user->{mode} eq 'nested')
		#? $comments->{$cidorpid}{totalvisiblekids}
		#: $cc;

	# Figure out whether to show the moderation button.  We do, but
	# only if at least one of the comments is moderatable.
	# Short circuited because you have to loop through every last comment on archived pages --TMB
	# Well that needs some more tests so create a new sub to do them --paulej72
	my $can_mod_any = _can_mod_any();
	#my $can_mod_any = _can_mod($comment);
	#if (!$can_mod_any) {
	#	CID: for my $cid (keys %$comments) {
	#		if (_can_mod($comments->{$cid})) {
	#			$can_mod_any = 1;
	#			last CID;
	#		}
	#	}
	#}

	my $anon_dump;

	my $comment_html = $options->{Return} ?  $pretext : '';

	#$comment_html .= slashDisplay('printCommComments', {
	#	can_moderate	=> $can_mod_any,
	#	comment		=> $comment,
	#	comments	=> $comments,
	#	'next'		=> $next,
	#	previous	=> $previous,
	#	sid		=> $discussion->{id},
	#	cid		=> $cid,
	#	pid		=> $pid,
	#	cc		=> $cc,
	#	lcp		=> $lcp,
	#	lvl		=> $lvl,
	#	anon_dump	=> $anon_dump,
	#}, { Return => 1 });
	# NO MOAR TEMPLATES
	my $pccArgs = {
		can_moderate    => $can_mod_any,
		comment         => $comment,
		comments        => $comments,
		'next'          => $next,
		previous        => $previous,
		sid             => $discussion->{id},
		cid             => $cid,
		pid             => $pid,
		cc              => $cc,
		lcp             => $lcp,
		lvl             => $lvl,
		anon_dump       => $anon_dump
	};
	$comment_html .= printCommComments($pccArgs);

	return $comment_html if $options->{Return};
	print $comment_html;
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
	my $below = "";
	my $visible = 0;
	my $visiblepass = 0;

	# root comment should have more likelihood to be full

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
	} 

	unless ($const) {
		for (map { ($_ . "begin", $_ . "end") }
			qw(table cage cagebig indent comment fullcomment)) {
			$const->{$_} = Slash::getData($_, '', '');
		}
	}

	for my $cid (@{$comments->{$pid}{kids}}) {
		my $comment = $comments->{$cid};
		$below = "";
		$visible = 0;
		my $show = 0;
		if(defined($form->{cid}) && $comments->{$cid}->{pid} == $form->{cid}) { $show = 1; }

		$skipped++;
		# since threaded shows more comments, we can skip
		# ahead more, counting all the visible kids.	--Pater
		$skipped += $comment->{totalvisiblekids} if ($user->{mode} eq 'flat');
		$form->{startat} ||= 0;
		next if $skipped <= $form->{startat};
		$form->{startat} = 0; # Once We Finish Skipping... STOP

		$comment->{class} = "full";

		$user->{state}{comments}{totals}{full}++;# unless $comment->{dummy};

		my $finish_list = 0;

		my($noshow, $pieces) = (0, 0);
		
		# This has to go before we build this comment
		if ($comment->{kids} && ($user->{mode} ne 'parents' || $pid)) {
			# Ewww, recursion when rendering comments is not a good thing. --TMB
			my $thread = displayThread($sid, $cid, $lvl+1, $comments, $const);
			
			$visible ||= $thread->{visible};
			if (my $str = $thread->{data}) {
				$below .= $const->{cagebegin} if $cagedkids;
				if ($indent && $const->{indentbegin}) {
					(my $indentbegin = $const->{indentbegin}) =~ s/^(<[^<>]+)>$/$1 id="commtree_$cid" class="commtree">/;
					$below .= $indentbegin;
				}
				$below .= $str;
				$below .= $const->{indentend} if $indent;
				$below .= $const->{cageend} if $cagedkids;
			}
			# in flat mode, all visible kids will
			# be shown, so count them.	-- Pater
			$displayed += $comment->{totalvisiblekids} if ($user->{mode} eq 'flat');
		}
		$return .= "$const->{tablebegin}\n<li id=\"tree_$comment->{cid}\" class=\"comment\">\n";
		if ($lvl && $indent) {
			my $thiscomment = dispComment($comment, { noshow => $noshow, pieces => $pieces, visiblekid => $visible, show => $show, lvl => $lvl });
			$visible ||= $thiscomment->{visible};
			if(!$thiscomment->{visiblenopass} && !$visible && $user->{mode} eq 'threadtos' && !$show ) {
				my $kids = $comment->{children} ? ( $comment->{children} > 1 ? "($comment->{children} children)" : "($comment->{children} child)") : "";

				$return .= "<input id=\"commentBelow_$comment->{cid}\" type=\"checkbox\" class=\"commentBelow\" checked=\"checked\" autocomplete=\"off\" />\n".
				"<label class=\"commentBelow\" title=\"Load comment\" for=\"commentBelow_$comment->{cid}\"> </label>\n".
				"<div id=\"comment_below_$comment->{cid}\" class=\"commentbt commentDiv\"><div class=\"commentTop\"><div class=\"title\">".
				"<h4 class=\"noTH\"><label class=\"commentBelow\" for=\"commentBelow_$comment->{cid}\">Comment Below Threshold $kids</label></h4>
				</div></div></div>\n";
			}
			$return .= $thiscomment->{data} . $const->{tableend};
			$cagedkids = 0;
		}
		elsif($user->{mode} eq 'flat' && defined($comment->{points}) && $comment->{points} < $user->{threshold} && $comment->{uid} != $user->{uid}) {
			my $thiscomment = dispComment($comment, { noshow => $noshow, pieces => $pieces});
			$return .= "<input id=\"commentBelow_$comment->{cid}\" type=\"checkbox\" class=\"commentBelow\" checked=\"checked\" autocomplete=\"off\" />\n".
				"<label class=\"commentBelow\" title=\"Load comment\" for=\"commentBelow_$comment->{cid}\"> </label>\n".
				"<div id=\"comment_below_$comment->{cid}\" class=\"commentbt commentDiv\"><div class=\"commentTop\"><div class=\"title\">".
				"<h4 class=\"noTH\"><label class=\"commentBelow\" for=\"commentBelow_$comment->{cid}\">Comment Below Threshold</label></h4>
				</div></div></div>\n";
			$return .= $thiscomment->{data};
		}
		else {
			my $thiscomment = dispComment($comment, { noshow => $noshow, pieces => $pieces, visiblekid => 1, show => 1 });
			$return .= $thiscomment->{data};
		}
		$displayed++; # unless $comment->{dummy};

		#$return .= $const->{fullcommentend} if ($user->{mode} eq 'flat');
		$return .= $below;
		$return .= "$const->{commentend}" if $finish_list;
		#$return .= "$const->{fullcommentend}" if ($full  && $user->{mode} ne 'flat');
		$visiblepass ||= $visible;
	}
	$return .= $const->{fullcommentend} if ($user->{mode} eq 'flat');
	$return .= "$const->{fullcommentend}" if ($full  && $user->{mode} ne 'flat');
	my $newreturn = {
		data	=> $return,
		visible => $visiblepass,
	};
	return $newreturn;
}

#========================================================================

sub preProcessReplyForm {
	my($form, $reply) = @_;
	return if !$form->{pid} || !$reply->{subject} || $form->{postersubj};

	##########
	# TMB As a general rule, we want to leave entities alone.
	#$form->{postersubj} = decode_entities($reply->{subject});
	$form->{postersubj} = $reply->{subject};
	##########
	$form->{postersubj} =~ s/^Re://i;
	$form->{postersubj} =~ s/\s\s/ /g;
	$form->{postersubj} = "Re:$form->{postersubj}";
}

#========================================================================

sub preProcessComment {
	my($comm, $user, $discussion, $error_message) = @_; # probably $comm = $form
	my $constants = getCurrentStatic();
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	$discussion->{type} = isDiscussionOpen($discussion);
	if ($discussion->{type} eq 'archived') {
		$$error_message = getError('archive_error');
		return -1;
	}

	my $tempSubject = $comm->{postersubj};
	my $tempComment = $comm->{postercomment};

	$comm->{anon} = $user->{is_anon};
	if ($comm->{postanon}
		&& $reader->checkAllowAnonymousPosting
		&& $user->{karma} > -1
		&& ($discussion->{commentstatus} eq 'enabled'
			||
		    $discussion->{commentstatus} eq 'logged_in')) {
		$comm->{anon} = 1;
	}

	$comm->{sig} = $comm->{anon} ? '' : ($comm->{sig} || $user->{sig});

	# The strip_mode needs to happen before the balanceTags() which is
	# called from validateComment.  This is because strip_mode calls
	# stripBadHtml, which calls approveTag repeatedly, which
	# eliminates malformed tags.  balanceTags should not ever see
	# malformed tags or it may choke.
	#
	# For the mode "CODE", validateComment() is called with a
	# "whitespace factor" half what is normally used.  Code is likely
	# to have many linebreaks and runs of whitespace; this makes the
	# compression filter more lenient about allowing them.

	$comm->{posttype} = $user->{posttype} unless defined $comm->{posttype};
	if ($comm->{posttype} == PLAINTEXT || $comm->{posttype} == HTML) {
		$tempComment = url2html($tempComment);
	}

	$tempComment = strip_mode($tempComment,
		# if no posttype given, pick a default
		$comm->{posttype} || PLAINTEXT
	);

	validateComment($comm->{sid},
		\$tempComment, \$tempSubject, $error_message, 1,
		($comm->{posttype} == CODE
			? $constants->{comments_codemode_wsfactor}
			: $constants->{comments_wsfactor} || 1) )
		or return;

	$tempComment = addDomainTags($tempComment);

	my $comment = {
		subject		=> $tempSubject,
		comment		=> $tempComment,
		sid		=> $comm->{sid},
		pid		=> $comm->{pid},
		uid		=> $comm->{anon} ? getCurrentAnonymousCoward('uid') : $user->{uid},
		'time'		=> $reader->getTime,
		sig		=> $comm->{sig},
	};

	return $comment;	
}


sub postProcessComment {
	my($comm, $from_db, $discussion) = @_;
	my $slashdb = getCurrentDB();

	$comm->{sig} = parseDomainTags($comm->{sig}, $comm->{fakeemail});
	if ($comm->{sig}) {
		$comm->{sig} =~ s/^\s*-{1,5}\s*<(?:P|BR)>//i;
		$comm->{sig} = Slash::getData('sigdash', '', 'comments')
			. $comm->{sig};
	}
	
	$comm->{comment} = parseDomainTags($comm->{comment}, !$comm->{anon} && $comm->{fakeemail});
	$comm->{comment} = apply_rehash_tags($comm->{comment});

	# Check if spam_flag is set
    if ($comm->{spam_flag}) {
        $comm->{subject} = '** Flagged Comment **';
        $comm->{comment} = '** This comment has been flagged for review. **';
		$comm->{sig} = '';
    }

	if (!$from_db) {
		
		my $extras = [];
		my $disc_skin = $slashdb->getSkin($discussion->{primaryskid});
		$extras = $slashdb->getNexusExtrasForChosen(
			{ $disc_skin->{nexus} => 1 },
			{ content_type => "comment" })
			if $disc_skin && $disc_skin->{nexus};

		my $preview = {
			nickname		=> $comm->{anon}
							? getCurrentAnonymousCoward('nickname')
							: $comm->{nickname},
			uid			=> $comm->{anon}
							? getCurrentAnonymousCoward('uid')
							: $comm->{uid},
			pid			=> $comm->{pid},
			homepage		=> $comm->{anon} ? '' : $comm->{homepage},
			fakeemail		=> $comm->{anon} ? '' : $comm->{fakeemail},
			journal_last_entry_date	=> $comm->{journal_last_entry_date} || '',
			'time'			=> $slashdb->getTime,
			subject			=> $comm->{subject},
			comment			=> $comm->{comment},
			sig			=> $comm->{sig},
		};

		foreach my $extra (@$extras) {
			$preview->{$extra->[1]} = $comm->{$extra->[1]};
		}

		return $preview;
	}
}

sub prevComment {
	my($preview, $user) = @_;
	my $tm = $user->{mode};
	$user->{mode} = 'archive';

	my $label = Slash::getData('label', '', 'comments');

	my $previewForm = slashDisplay('preview_comm', {
		label	=> $label,
		preview => $preview,
	}, { Page => 'comments', Return => 1 });

	$user->{mode} = $tm;
	return $previewForm;
}

sub saveComment {
	my($comm, $comment, $user, $discussion, $error_message) = @_; # probably $comm = $form
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	$comm->{nobonus}  = $user->{nobonus}	unless $comm->{nobonus_present};
	$comm->{postanon} = $user->{postanon}	unless $comm->{postanon_present};


#print STDERR scalar(localtime) . " $$ E header_emitted=$header_emitted do_emit_html=$do_emit_html redirect_to=" . (defined($redirect_to) ? $redirect_to : "undef") . "\n";

	# Set starting points to the AC's starting points, by default.
	# If the user is posting under their own name, we'll reset this
	# value (and add other modifiers) in a moment.
	my $pts = getCurrentAnonymousCoward('defaultpoints');
	my $karma_bonus = 0;
	my $subscriber_bonus = 0;
	my $tweak = 0;

	if (!$comm->{anon}) {
		$pts = $user->{defaultpoints};

		if ($constants->{karma_posting_penalty_style} == 0) {
			$pts-- if $user->{karma} < 0;
			$pts-- if $user->{karma} < $constants->{badkarma};
		} else {
			$tweak-- if $user->{karma} < 0;
			$tweak-- if $user->{karma} < $constants->{badkarma};
		}
		# Enforce proper ranges on comment points.
		my($minScore, $maxScore) =
			($constants->{comment_minscore}, $constants->{comment_maxscore});
		$pts = $minScore if $pts < $minScore;
		$pts = $maxScore if $pts > $maxScore;
		$karma_bonus = 1 if $pts >= 1 && $user->{karma} > $constants->{goodkarma}
			&& !$comm->{nobonus};
		$subscriber_bonus = 1 if $constants->{plugin}{Subscribe}
			&& $constants->{subscriber_bonus}
			&& $user->{is_subscriber}
			&& (!$comm->{nosubscriberbonus} || $comm->{nosubscriberbonus} ne 'on');
	}

#print STDERR scalar(localtime) . " $$ F header_emitted=$header_emitted do_emit_html=$do_emit_html\n";

	my $clean_comment = {
		subject		=> $comment->{subject},
		comment		=> $comment->{comment},
		sid		=> $comment->{sid},
		pid		=> $comment->{pid},
		ipid		=> $user->{ipid},
		subnetid	=> $user->{subnetid},
		uid		=> $comment->{uid},
		points		=> $pts,
		tweak		=> $tweak,
		tweak_orig	=> $tweak,
		karma_bonus	=> $karma_bonus ? 'yes' : 'no',
	};

	if ($constants->{plugin}{Subscribe}) {
		$clean_comment->{subscriber_bonus} = $subscriber_bonus ? 'yes' : 'no';
	}

	my $maxCid = $slashdb->createComment($clean_comment);
	if ($constants->{comment_karma_disable_and_log}) {
		my $post_str = "";
		$post_str .= "NO_ANON " if $user->{state}{commentkarma_no_anon};
		$post_str .= "NO_POST " if $user->{state}{commentkarma_no_post};
		if (isAnon($comment->{uid}) && $user->{state}{commentkarma_no_anon}) {
			$slashdb->createCommentLog({
				cid	=> $maxCid,
				logtext	=> "COMMENTKARMA ANON: $post_str"
			});
		} elsif (!isAnon($comment->{uid}) && $user->{state}{commentkarma_no_post}) {
			$slashdb->createCommentLog({
				cid	=> $maxCid,
				logtext	=> "COMMENTKARMA USER: $post_str"
			});
		}
	}
	if ($constants->{comment_is_troll_disable_and_log}) {
		$slashdb->createCommentLog({
			cid	=> $maxCid,
			logtext	=> "ISTROLL"
		});
	}

#print STDERR scalar(localtime) . " $$ G maxCid=$maxCid\n";

	# make the formkeys happy
	$comm->{maxCid} = $maxCid;

	$slashdb->setUser($user->{uid}, {
		'-expiry_comm'	=> 'expiry_comm-1',
	}) if allowExpiry();

	if ($maxCid == -1) {
		$$error_message = getError('submission error');
		return -1;

	} elsif (!$maxCid) {
		# This site has more than 2**32 comments?  Wow.
		$$error_message = getError('maxcid exceeded');
		return -1;
	}


	my $saved_comment = $slashdb->getComment($maxCid);
	slashHook('comment_save_success', { comment => $saved_comment });

	my $moddb = getObject("Slash::$constants->{m1_pluginname}");
	if ($moddb) {
		my $text = $moddb->checkDiscussionForUndoModeration($comm->{sid});
		print $text if $text;
	}

	my $tc = $slashdb->getVar('totalComments', 'value', 1);
	$slashdb->setVar('totalComments', ++$tc);


	if ($discussion->{sid}) {
		$slashdb->setStory($discussion->{sid}, { writestatus => 'dirty' });
	}

	$slashdb->setUser($clean_comment->{uid}, {
		-totalcomments => 'totalcomments+1',
	}) if !isAnon($clean_comment->{uid});

	my($messages, $reply, %users);
	my $kinds = $reader->getDescriptions('discussion_kinds');
	if ($comm->{pid}
		|| $kinds->{ $discussion->{dkid} } =~ /^journal/
		|| $constants->{commentnew_msg}) {
		$messages = getObject('Slash::Messages');
		$reply = $slashdb->getCommentReply($comm->{sid}, $maxCid);
	}

	$clean_comment->{pointsorig} = $clean_comment->{points};

	# reply to comment
	if ($messages && $comm->{pid}) {
		my $parent = $slashdb->getCommentReply($comm->{sid}, $comm->{pid});
		my $users  = $messages->checkMessageCodes(MSG_CODE_COMMENT_REPLY, [$parent->{uid}]);
		if (_send_comment_msg($users->[0], \%users, $pts, $clean_comment)) {
			my $data  = {
				template_name   => 'reply_msg',
				template_page   => 'comments',
				subject		=> {
					template_name 	=> 'reply_msg_subj',
					template_page 	=> 'comments',
				},
				reply		=> $reply,
				parent		=> $parent,
				discussion      => $discussion,
			};
			$messages->create($users->[0], MSG_CODE_COMMENT_REPLY, $data);
			$users{$users->[0]}++;
		}
	}

	# reply to journal
	if ($messages && $kinds->{ $discussion->{dkid} } =~ /^journal/) {
		my $users  = $messages->checkMessageCodes(MSG_CODE_JOURNAL_REPLY, [$discussion->{uid}]);
		if (_send_comment_msg($users->[0], \%users, $pts, $clean_comment)) {
			my $data  = {
				template_name	=> 'journrep',
				template_page	=> 'comments',
				subject	 => {
					template_name	=> 'journrep_subj',
					template_page	=> 'comments',
				},
				reply		=> $reply,
				discussion	=> $discussion,
			};

			$messages->create($users->[0], MSG_CODE_JOURNAL_REPLY, $data);
			$users{$users->[0]}++;
		}
	}

	# comment posted
	if ($messages && $constants->{commentnew_msg}) {
		my $users = $messages->getMessageUsers(MSG_CODE_NEW_COMMENT);

		my $data  = {
			template_name	=> 'commnew',
			template_page	=> 'comments',
			subject		=> {
				template_name	=> 'commnew_subj',
				template_page	=> 'comments',
			},
			reply		=> $reply,
			discussion	=> $discussion,
		};

		my @users_send;
		for my $usera (@$users) {
			next if $users{$usera};
			push @users_send, $usera;
			$users{$usera}++;
		}
		$messages->create(\@users_send, MSG_CODE_NEW_COMMENT, $data) if @users_send;
	}

	my $dynamic_blocks = getObject('Slash::DynamicBlocks');
	if ($dynamic_blocks) {
		$dynamic_blocks->setUserBlock('comments', $user->{uid});
	}

	if ($constants->{validate_html}) {
		my $validator = getObject('Slash::Validator');
		my $test = parseDomainTags($comment->{comment});
		$validator->isValid($test, {
			data_type	=> 'comment',
			data_id		=> $maxCid,
			message		=> 1
		}) if $validator;
	}

	return $saved_comment;
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
	my($comment, $options) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $mod_reader = getObject("Slash::$constants->{m1_pluginname}", { db_type => 'reader' });
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $gSkin = getCurrentSkin();
	my $maxcommentsize = $constants->{default_maxcommentsize};

	my $comment_shrunk;

	if ($form->{mode} ne 'archive'
		&& !defined($comment->{abbreviated})
		&& $comment->{len} > ($maxcommentsize + 256)
		&& $form->{cid} ne $comment->{cid}
		&& $comment->{legacy})
	{
		$comment_shrunk = 1;
	}

	postProcessComment($comment, 1);

	if (!$comment->{karma_bonus} || $comment->{karma_bonus} eq 'no') {
		for ($comment->{sig}, $comment->{comment}) {
			$_ = noFollow($_);
		}
	}
	
	my $subscriber_badge=0;
	if ($constants->{plugin}{Subscribe} && $constants->{subscribe}) {
		my $hide_subscription = $reader->getUser($comment->{uid}, 'hide_subscription');
		if (isSubscriber($comment->{uid}) && !$hide_subscription) {
			$subscriber_badge = 1;
		}
	}

	my $reasons = undef;
	my $ordered = undef;
	if ($mod_reader) {
		$reasons = $mod_reader->getReasons();
		$ordered = $mod_reader->getReasonsOrder();
	}

	my $reasons_html = "";
	foreach my $item (@$ordered) {
		 $reasons_html .= "<option value=\"$item\">".strip_literal($reasons->{$item}{name})."</option>\n";
	}

	my $can_mod = _can_mod($comment);

	# do not inherit these ...
	# THIS DOES NOT DO THAT, RETARD --TMB

	# ipid/subnetid need munging into one text string
	if ($user->{seclev} >= 100 && $comment->{ipid} && $comment->{subnetid}) {
		vislenify($comment); # create $comment->{ipid_vis} and {subnetid_vis}
		$comment->{ipid_display} = slashDisplay(
			"ipid_display", { data => $comment },
			1);
	} else {
		$comment->{ipid_display} = "";
	}

	# we need a display-friendly fakeemail string
	$comment->{fakeemail_vis} = ellipsify($comment->{fakeemail});
	push @{$user->{state}{cids}}, $comment->{cid};

	$comment->{class} ||= 'full';

	if ($options->{show_pieces}) {
		my @return;
		push @return, slashDisplay('dispCommentDetails', {
			%$comment,
			comment_shrunk	=> $comment_shrunk,
			reasons		=> $reasons,
			can_mod		=> $can_mod,
			is_anon		=> isAnon($comment->{uid}),
			options		=> $options
		}, { Return => 1, Nocomm => 1 });
		push @return, slashDisplay('dispLinkComment', {
			%$comment,
			comment_shrunk	=> $comment_shrunk,
			reasons		=> $reasons,
			ordered		=> $ordered,
			can_mod		=> $can_mod,
			is_anon		=> isAnon($comment->{uid}),
			options		=> $options
		}, { Return => 1, Nocomm => 1 });
		return @return;
	}

	my $marked_spam = $mod_reader->getSpamCount($comment->{cid}, $reasons);
	my $discussion = $mod_reader->getDiscussion($comment->{sid});
	my $dim = $mod_reader->getCommentReadLog($discussion->{id}, $user->{uid});

	my $return;
	#$return = slashDisplay('dispComment', {
	#	%$comment,
	#	marked_spam	=> $marked_spam,
	#	comment_shrunk	=> $comment_shrunk,
	#	reasons		=> $reasons,
	#	ordered		=> $ordered,
	#	can_mod		=> $can_mod,
	#	is_anon		=> isAnon($comment->{uid}),
	#	options		=> $options,
	#	cid_now		=> $dim->{cid_now},
	#	subscriber_badge => $subscriber_badge
	#}, { Return => 1, Nocomm => 1 });
	
	#COMMENT TEMPLATES MUST DIE
	my $args = {
		%$comment,
		marked_spam      => $marked_spam,
		comment_shrunk   => $comment_shrunk,
		reasons          => $reasons,
		reasons_html     => $reasons_html,
		can_mod          => $can_mod,
		is_anon          => isAnon($comment->{uid}),
		options          => $options,
		cid_now          => $dim->{cid_now},
		subscriber_badge => $subscriber_badge,
		children         => $comment->{children},
		lvl              => $options->{lvl},
	};
	$return = dispCommentNoTemplate($args);
	my $newreturn = {
		data		=> $return->{data},
		visible		=> $return->{visible},
		visiblenopass	=> $return->{visiblenopass},
	};
	return $newreturn;
}

##################################################################
# Validate comment, looking for errors
sub validateComment {
	my($sid, $comm, $subj, $error_message, $preview, $wsfactor) = @_;

	$wsfactor ||= 1;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $moddb = getObject("Slash::$constants->{m1_pluginname}");
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	
	my $form_success = 1;
	my $message = '';

	if (!dbAvailable("write_comments")) {
		$$error_message = getError('comment_db_down');
		$form_success = 0;
		return;
	}

	unless ($slashdb->checkDiscussionPostable($sid)) {
		$$error_message = getError('submission error');
		$form_success = 0;
		return;
	}

	my $srcids_to_check = $user->{srcids};

	# We skip the UID test for anonymous users (anonymous posting
	# is banned by setting nopost for the anonymous uid, and we
	# want to check that separately elsewhere).  Note that
	# checking the "post anonymously" checkbox doesn't eliminate
	# a uid check for a logged-in user.
	delete $srcids_to_check->{uid} if $user->{is_anon};

	# If the user is anonymous, or has checked the 'post anonymously'
	# box, check to see whether anonymous posting is turned off for
	# this srcid.
	my $read_only = 0;
	$read_only = 1 if ($user->{is_anon} || $form->{postanon})
		&& $reader->checkAL2($srcids_to_check, 'nopostanon');

	# Whether the user is anonymous or not, check to see whether
	# all posting is turned off for this srcid.
	$read_only ||= $reader->checkAL2($srcids_to_check, 'nopost');

	# If posting is disabled, return the error message.
	if ($read_only) {
		$$error_message = getError('readonly');
		$form_success = 0;
		# editComment('', $$error_message), return unless $preview;
		return;
	}

	# New check (March 2004):  depending on the settings of
	# a var and whether the user is posting anonymous, we
	# might scan the IP they're coming from to see if we can use
	# some commonly-used proxy ports to access our own site.
	# If we can, they're coming from an open HTTP proxy, which
	# we don't want to allow to post.
	# XXX : this can become a reskey check -- pudge 2008-03
	if ($constants->{comments_portscan}
		&& ( $constants->{comments_portscan} == 2
			|| $constants->{comments_portscan} == 1 && $user->{is_anon} )
	) {
		my $is_trusted = $slashdb->checkAL2($user->{srcids}, 'trusted');
		if (!$is_trusted) {
#use Time::HiRes; my $start_time = Time::HiRes::time;
			my $is_proxy = $slashdb->checkForOpenProxy($user->{hostip});
#my $elapsed = sprintf("%.3f", Time::HiRes::time - $start_time); print STDERR scalar(localtime) . " comments.pl cfop returned '$is_proxy' for '$user->{hostip}' in $elapsed secs\n";
			if ($is_proxy) {
				$$error_message = getError('open proxy', {
					unencoded_ip	=> $ENV{REMOTE_ADDR},
					port		=> $is_proxy,
				});
				$form_success = 0;
				return;
			}
		}
	}

	# New check (July 2002):  there is a max number of posts per 24-hour
	# period, either based on IPID for anonymous users, or on UID for
	# logged-in users.  Logged-in users get a max number of posts that
	# is related to their karma.  The comments_perday_bykarma var
	# controls it (that var is turned into a hashref in MySQL.pm when
	# the vars table is read in, whose keys we loop over to find the
	# appropriate level).
	# See also comments_maxposts in formkeyErrors - Jamie 2005/05/30

	my $min_cid_1_day_old = $slashdb->getVar('min_cid_last_1_days','value', 1) || 0;
	
	if (($user->{is_anon} || $form->{postanon}) && $constants->{comments_perday_anon}
		&& !$user->{is_admin}) {
		my($num_comm, $sum_mods) = $reader->getNumCommPostedAnonByIPID(
			$user->{ipid}, 24, $min_cid_1_day_old);
		my $num_allowed = $constants->{comments_perday_anon};
		if ($sum_mods - $num_comm + $num_allowed <= 0) {

			$$error_message = getError('comments post limit daily', {
				limit => $constants->{comments_perday_anon}
			});
			$form_success = 0;
			return;

		}
	} elsif (!$user->{is_anon} && $constants->{comments_perday_bykarma}
		&& !$user->{is_admin}) {
		my($num_comm, $sum_mods) = $reader->getNumCommPostedByUID(
			$user->{uid}, 24, $min_cid_1_day_old);
		my $num_allowed = 9999;
		K_CHECK: for my $k (sort { $a <=> $b }
			keys %{$constants->{comments_perday_bykarma}}) {
			if ($user->{karma} <= $k) {
				$num_allowed = $constants->{comments_perday_bykarma}{$k};
				last K_CHECK;
			}
		}
		if ($sum_mods - $num_comm + $num_allowed <= 0) {

			$$error_message = getError('comments post limit daily', {
				limit => $num_allowed
			});
			$form_success = 0;
			return;

		}
	}

	if (isTroll()) {
		if ($constants->{comment_is_troll_disable_and_log}) {
			$user->{state}{is_troll} = 1;
		} else {
			$$error_message = getError('troll message', {
				unencoded_ip => $ENV{REMOTE_ADDR}
			});
			return;
		}
	}

	if ($user->{is_anon} || $form->{postanon}) {
		my $uid_to_check = $user->{uid};
		if (!$user->{is_anon}) {
			$uid_to_check = getCurrentAnonymousCoward('uid');
		}
		if (!$slashdb->checkAllowAnonymousPosting($uid_to_check)) {
			$$error_message = getError('anonymous disallowed');
			return;
		}
	}

	if (!$user->{is_anon} && $form->{postanon} && $user->{karma} < 0) {
		$$error_message = getError('postanon_option_disabled');
		return;
	}

	my $post_restrictions = $reader->getNetIDPostingRestrictions("subnetid", $user->{subnetid});
	if ($user->{is_anon} || $form->{postanon}) {
		if ($post_restrictions->{no_anon}) {
			my $logged_in_allowed = !$post_restrictions->{no_post};
			$$error_message = getError('troll message', {
				unencoded_ip 		=> $ENV{REMOTE_ADDR},
				logged_in_allowed 	=> $logged_in_allowed  
			});
			return;
		}
	}

	if (!$user->{is_admin} && $post_restrictions->{no_post}) {
		$$error_message = getError('troll message', {
			unencoded_ip 		=> $ENV{REMOTE_ADDR},
		});
		return;
	}


	$$subj =~ s/\(Score(.*)//i;
	$$subj =~ s/Score:(.*)//i;

	unless (defined($$comm = balanceTags($$comm, { deep_nesting => 1, deep_su => 1 }))) {
		# only time this should return an error is if the HTML is busted
		$$error_message = getError('broken html');
		return ;
	}

	my $dupRows = $slashdb->findCommentsDuplicate($form->{sid}, $$comm);
	if ($dupRows) {
		$$error_message = getError('duplication error');
		$form_success = 0;
		return unless $preview;
	}

	my $kickin = $constants->{comments_min_line_len_kicks_in};
	if ($constants->{comments_min_line_len} && length($$comm) > $kickin) {

		my $max_comment_len = $constants->{default_maxcommentsize};
		my $check_prefix = substr($$comm, 0, $max_comment_len);
		my $check_prefix_len = length($check_prefix);
		my $min_line_len_max = $constants->{comments_min_line_len_max}
			|| $constants->{comments_min_line_len}*2;
		my $min_line_len = $constants->{comments_min_line_len}
			+ ($min_line_len_max - $constants->{comments_min_line_len})
				* ($check_prefix_len - $kickin)
				/ ($max_comment_len - $kickin); # /

		##########
		#	TMB Added decode_entities to prevent that specific kind of cheating.
		my $check_notags = decode_entities(strip_nohtml($check_prefix));
		# Don't count & or other chars used in entity tags;  don't count
		# chars commonly used in ascii art.  Not that it matters much.
		# Do count chars commonly used in source code.
		##########
		#	TMB Count anything but whitespace as this is NOT unicode happy.
		#	my $num_chars = $check_notags =~ tr/A-Za-z0-9?!(){}[]+='"@$-//;
		##########
		#	TMB Testing a unicode-friendly version
		#	Counts characters that aren't horizontal or vertical spaces, unicode control characters, or unicode formatting characters.
		#	my $num_chars = $check_notags =~ tr/ \t\r\n\f//c;
		my $num_chars = $check_notags =~ s/[^\h\v\p{Cc}\p{Cf}]//g;

		# Note that approveTags() has already been called by this point,
		# so all tags present are legal and uppercased.
		my $breaktags = $constants->{'approvedtags_break'}
			|| [qw(HR BR LI P OL UL BLOCKQUOTE DIV)];
		my $breaktags_1_regex = "<(?:" . join("|", @$breaktags) . ")>";
		my $breaktags_2_regex = "<(?:" . join("|", grep /^(P|BLOCKQUOTE)$/, @$breaktags) . ")>";
		my $num_lines = 0;
		$num_lines++ while $check_prefix =~ /$breaktags_1_regex/gi;
		$num_lines++ while $check_prefix =~ /$breaktags_2_regex/gi;

		if ($num_lines > 3) {
			my $avg_line_len = $num_chars/$num_lines;
			if ($avg_line_len < $min_line_len) {
				$$error_message = getError('low chars-per-line', {
					ratio 	=> sprintf("%0.1f", $avg_line_len),
				});
				$form_success = 0;
				return unless $preview;
			}
		}
	}

	# Test comment and subject using filterOk and compressOk.
	# If the filter is matched against the content, or the comment
	# compresses too well, display an error with the particular
	# message for the filter that was matched.
	my $fields = {
			postersubj 	=> 	$$subj,
			postercomment 	=>	$$comm,
	};

	for (keys %$fields) {
		# run through filters
		if (! filterOk('comments', $_, $fields->{$_}, \$message)) {
			$$error_message = getError('filter message', {
					err_message	=> $message,
			});
			return unless $preview;
			$form_success = 0;
			last;
		}
		# run through compress test
		if (! compressOk('comments', $_, $fields->{$_}, $wsfactor)) {
			# blammo luser
			$$error_message = getError('compress filter', {
					ratio	=> $_,
			});
			return unless $preview;
			$form_success = 0;
			last;
		}
	}

	if ( $constants->{m1}
		&& !$user->{is_anon}
		&& !$form->{postanon}
		&& !$form->{gotmodwarning}
		&& !( $constants->{authors_unlimited}
			&& $user->{seclev} >= $constants->{authors_unlimited} )
		&& !$user->{acl}{modpoints_always}
		&& !$constants->{moderate_or_post}
		&&  $moddb
		&&  $moddb->countUserModsInDiscussion($user->{uid}, $form->{sid}) > 0
	) {
		$$error_message = getError("moderations to be lost");
		$form_success = 0;
		return;
	}

	$$error_message ||= '';
	# Return false if error condition...
	return if ! $form_success;

	# ...otherwise return true.
	return 1;
}

##################################################################
# Decide whether or not to send a given message to a given user
sub _send_comment_msg {
	my($uid, $uids, $pts, $C) = @_;
	my $constants	= getCurrentStatic();
	my $reader	= getObject('Slash::DB', { db_type => 'reader' });
	my $user	= getCurrentUser();

	return unless $uid;			# no user
	return if $uids->{$uid};		# user not already being msgd
	return if $user->{uid} == $uid;		# don't msg yourself

	my $otheruser = $reader->getUser($uid);

	# use message_threshold in vars, unless user has one
	# a message_threshold of 0 is valid, but "" is not
	my $message_threshold = length($otheruser->{message_threshold})
		? $otheruser->{message_threshold}
		: length($constants->{message_threshold})
			? $constants->{message_threshold}
			: undef;

	my $mod_reader = getObject("Slash::$constants->{m1_pluginname}", { db_type => 'reader' });
	my $newpts = getPoints($C, $otheruser,
		$constants->{comment_minscore}, $constants->{comment_maxscore},
		$reader->countUsers({ max => 1 }), $mod_reader->getReasons,
	);

	# only if reply pts meets message threshold
	return if defined $message_threshold && $newpts < $message_threshold;

	return 1;
}

##################################################################
# Troll Detection: checks to see if this IP or UID has been
# abusing the system in the last 24 hours.
# 1=Troll 0=Good Little Goober
sub isTroll {
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	return 0 if $user->{seclev} >= 100;

	my $good_behavior = 0;
	if (!$user->{is_anon} and $user->{karma} >= 1) {
		if ($form->{postanon}) {
			# If the user is signed in but posting anonymously,
			# their karma helps a little bit to offset their
			# trollishness.  But not much.
			$good_behavior = int(log($user->{karma})+0.5);
		} else {
			# If the user is signed in with karma at least 1 and
			# posts with their name, the IP ban doesn't apply.
			return 0;
		}
	}

	return $slashdb->getIsTroll($good_behavior);
}


sub _is_mod_banned {
	my $user = shift;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	my $banned = $reader->sqlSelect("1", 'users_info', "uid = $user->{uid} and mod_banned > NOW()");
	return ($banned || 0);
}

sub printCommComments {
	my $args = shift;
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $gSkin = getCurrentSkin();
	my $html_out = "";
	
	my $can_del = ($constants->{authors_unlimited} && $user->{is_admin} && $user->{seclev} >= $constants->{authors_unlimited}) || $user->{acl}->{candelcomments_always};
	my $moderate_form = $args->{can_moderate} || $can_del || $user->{acl}->{candelcomments_always};
	my $moderate_button = $args->{can_moderate} && $user->{mode} ne 'archive' && ( !$user->{state}->{discussion_archived} || $constants->{comments_moddable_archived});
	my $next_prev_links = nextPrevLinks($args->{next}, $args->{prev}, $args->{comment});
	my $mod_comment_log = "";

	if($moderate_form) {
		$html_out .= "<form id=\"commentform\" name=\"commentform\" action=\"$gSkin->{rootdir}/comments.pl\" method=\"post\">\n";
		if(defined($form->{threshold})) { $html_out .= "<input type=\"hidden\" name=\"threshold\" value=\"$form->{threshold}\">\n"; }
		if(defined($form->{highlightthresh})) { $html_out .= "<input type=\"hidden\" name=\"highlightthresh\" value=\"$form->{highlightthresh}\">\n"; }
		if(defined($form->{commentsort})) { $html_out .= "<input type=\"hidden\" name=\"commentsort\" value=\"$form->{commentsort}\">\n"; }
		if(defined($form->{mode})) { $html_out .= "<input type=\"hidden\" name=\"mode\" value=\"$form->{mode}\">\n"; }
		if(defined($form->{page})) { $html_out .= "<input type=\"hidden\" name=\"page\" value=\"$form->{page}\">\n"; }
	}

	if(!$constants->{modal_prefs_active}) {
		my $moddb = getObject("Slash::$constants->{m1_pluginname}");
		if($moddb) {
			$mod_comment_log .= $moddb->dispModCommentLog('cid', $args->{cid}, { need_m2_form => 0, need_m2_button => 0, show_m2s => 0, title => " " });
		}
	}

	if($args->{cid}) {
		my $commentdata = dispComment($args->{comment});
		$html_out .= "<ul id=\"commentlisting\" >\n<li id=\"tree_$args->{cid}\" class=\"comment\">\n".
		$commentdata->{data}.
		"\n<div class=\"comment_footer\">\n$next_prev_links\n</div>\n$mod_comment_log\n";
	}
	
	$html_out .= $args->{lcp};

	my ($dthread, $thread);
	if($args->{comments}) {
		$dthread = displayThread($args->{sid}, $args->{pid}, $args->{lvl}, $args->{comments});
		$thread = $dthread->{data};
	}
	if($thread) {
		if(!$args->{cid}) { $html_out .= "<ul id=\"commentlisting\" >$thread</ul>\n"; }
		else {	$html_out .= $thread; }
	}
	if($args->{cid}) {$html_out .= "</ul>\n"; }
	
	$html_out .= $args->{lcp}."<div id=\"discussion_buttons\">\n";
	
	if(!$user->{state}->{discussion_archived} && !$user->{state}->{discussion_future_nopost}) {
		$html_out .= "<span class=\"nbutton\"><b>".
		linkComment({
			sid => $args->{sid},
			cid => $args->{cid},
			op => 'reply',
			subject => 'Reply',
			subject_only => 1
		}).
		"</b></span>\n";
	}

	if(!$user->{is_anon}) {
		$html_out .= "<span class=\"nbutton\"><b><a href=\"$gSkin->{rootdir}/my/comments\">Prefs</a></b></span>\n";
	}

	$html_out .= "<span class=\"nbutton\"><b><a href=\"$gSkin->{rootdir}/faq.pl?op=moderation\">Moderator Help</a></b></span>\n";

	if($moderate_form) {
		$html_out .= "<input type=\"hidden\" name=\"op\" value=\"moderate\">\n";
		$html_out .= "<input type=\"hidden\" name=\"sid\" value=\"$args->{sid}\">\n";
		$html_out .= "<input type=\"hidden\" name=\"cid\" value=\"$args->{cid}\">\n" if $args->{cid};
		$html_out .= "<input type=\"hidden\" name=\"pid\" value=\"$args->{pid}\">\n" if $args->{pid};
		$html_out .= "<button type=\"submit\" name=\"moderate\" value=\"discussion_buttons\">Moderate</button>\n";
		if($can_del) {
			$html_out .= "<span class=\"nbutton\"><b><a href=\"#\" onclick=\"\$('#commentform').submit(); return false\">Delete</a></b></span>\nChecked comments will be deleted!";
		}

	}

	if($moderate_form) {
		$html_out .= "</div>\n</form>\n";
	}
	else {
		$html_out .= "</div>";
	}
		
	$html_out .= "<script src=\"$constants->{real_rootdir}/expandAll.js\" type=\"text/javascript\"></script>";	

	return $html_out;
}

sub nextPrevLinks {
	my ($next, $prev, $comment) = @_;
	my $html_out = "";
	if($prev) { $html_out .= "&lt;&lt;".linkComment($prev, 1); }
	if($prev && ($comment->{pid} || $next)) { $html_out .= " | "; }
	if($comment->{pid}) { linkComment($comment, 1); }
	if($next && ($comment->{pid} || $prev)) { $html_out .= " | "; }
	if($next) { $html_out .= linkComment($next, 1)."&gt;&gt;"; }
	return $html_out;
}

sub dispCommentNoTemplate {
	my $args = shift;
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $gSkin = getCurrentSkin();
	my $slashdb = getCurrentDB();

	my $html_out = "";
	my $show = 0;
	my $visible = 0;
	my $visiblenopass = 0;
	my $legacykids = 0;

	if(defined($form->{cid}) && $form->{cid} == $args->{cid}) { $show = 1; }
	if($user->{mode} ne 'flat' && defined($args->{options}->{show}) && $args->{options}->{show}){ $show = 1; }
	if($user->{uid} == $args->{uid} && !$user->{is_anon} && $user->{mode} ne 'threadtos') { $show = 1; }
	
	if(!defined($args->{children}) || !$args->{children}) {
		$legacykids = $slashdb->sqlSelect("1", "comments", "pid = $args->{cid} group by pid");
	}
	
	my $treeHiderOn = $user->{mode} ne 'flat' && ($args->{children} || $legacykids);
	my $treeHiderOffText = !$treeHiderOn ? " class=\"noTH\"" : " class=\"noJS\"";

	
	# Now shit starts getting squirrely.
	if(!defined($args->{options}->{noCollapse}) || !$args->{options}->{noCollapse}) {
		if(defined($args->{points}) && $args->{points} >= $user->{threshold} && !$show && $user->{mode} eq 'threadtos') {
			$visiblenopass = 1;
		}
		if(defined($args->{points}) && $args->{points} >= $user->{highlightthresh} && !$show && $user->{mode} eq 'threadtos') {
			$visible = 1;
		}
		
		my $checked = "";
		if($treeHiderOn) {
			if($args->{lvl} > 1 && $user->{mode} eq 'threadtos' && !$show) { $checked = "checked=\"checked\""; }
			if($user->{mode} eq 'threadtos' && $args->{points} < $user->{threshold} && !$show) { $checked = "checked=\"checked\""; }
			if($user->{mode} eq 'threadtos' && ($args->{points} >= $user->{highlightthresh} || $show)) { $checked = ""; }
			if(defined($args->{options}->{visiblekid}) && $args->{options}->{visiblekid}) {$checked = "";}
			$html_out .= "<input id=\"commentTreeHider_$args->{cid}\" type=\"checkbox\" class=\"commentTreeHider\" autocomplete=\"off\" $checked />\n";
		}

		$html_out .= "<input id=\"commentHider_$args->{cid}\" type=\"checkbox\" class=\"commentHider\" ";
		if(defined($args->{points}) && $user->{mode} eq "threadtng" && $args->{points} < $user->{highlightthresh} && !$show && !$checked) {
			$html_out .= " checked=\"checked\" ";
		}
		elsif($user->{mode} eq 'threadtos' && defined($args->{points}) && $args->{points} < $user->{highlightthresh} && !$show && $args->{lvl} > 1 && !$checked) {
			$html_out .= " checked=\"checked\" ";
		}
		elsif($user->{mode} eq 'flat' && defined($args->{points}) && $args->{points} < $user->{highlightthresh} && !$show && !$checked) {
			$html_out .= " checked=\"checked\"";
		}
		$html_out .= " autocomplete=\"off\" />\n<label class=\"commentHider\" title=\"Expand/Collapse comment\" for=\"commentHider_$args->{cid}\"> </label>";

		if($treeHiderOn) {
			$html_out .= "<label class=\"commentTreeHider\" title=\"Show/Hide comment tree\" for=\"commentTreeHider_$args->{cid}\"> </label>\n";
			$html_out .= "<label class=\"expandAll noJS\" title=\"Show all comments in tree\" cid=\"$args->{cid}\"></label>"; 
		}
	}

	my $points = defined($args->{points}) ? $args->{points} : "?";
	my $no_collapse = defined($args->{options}->{noCollapse}) ? "noCollapse" : "";
	my $dimmed = "";
	if($no_collapse ne "noCollapse" && $args->{cid} <= $args->{cid_now} && !$user->{is_anon} && $user->{dimread}) {
		$dimmed = "dimmed";
	}
	my $time = timeCalc($args->{time});
	
	my $prenick = !$args->{is_anon} ? "<a href=\"$constants->{real_rootdir}/~".strip_paramattr(fixnickforlink($args->{nickname}))."/\">" : "";
	my $postnick = !$args->{is_anon} ? " ($args->{uid})</a>" : "";
	my $noZooPN = !$args->{is_anon} ? "</a>" : "";
	my $noZoo = " by $prenick".strip_literal($args->{nickname})."$noZooPN on $time\n";
	$postnick .= (!$args->{is_anon} && $args->{subscriber_badge}) ? " <span class=\"zooicon\"><a href=\"$gSkin->{rootdir}/subscribe.pl\"><img src=\"$constants->{imagedir}/star.png\" alt=\"Subscriber Badge\" title=\"Subscriber Badge\" width=\"$constants->{badge_icon_size}\" height=\"$constants->{badge_icon_size}\"></a></span>" : "";
	$postnick .= !$args->{is_anon} ? zooIcons({ person => $args->{uid}, bonus => 1}) : "";
	my $nick .= "by $prenick".strip_literal($args->{nickname})."$postnick \n";
	
	$html_out .= "<div id=\"comment_$args->{cid}\" class=\"commentDiv score$points $no_collapse $dimmed\">\n".
	"<div id=\"comment_top_$args->{cid}\" class=\"commentTop\">\n<div class=\"title\">\n<h4 id=\"$args->{cid}\"$treeHiderOffText><label class=\"commentHider\" for=\"commentHider_$args->{cid}\">".strip_title($args->{subject})."</label>\n";
	if($treeHiderOn) {
		$html_out .= "<label class=\"commentTreeHider\" for=\"commentTreeHider_$args->{cid}\">".strip_title($args->{subject})."</label>\n";
	}
	unless(defined($user->{noscores}) && $user->{noscores}) {
		my $reason = (defined($args->{reasons}) && defined($args->{reason}) && $args->{reason}) ? ", ".$args->{reasons}->{$args->{reason}}->{name} : "";
		$html_out .= "<span id=\"comment_score_$args->{cid}\" class=\"score\">(Score: $points$reason)</span> \n";
	}

	$html_out .= "<span class=\"by\">$noZoo</span>\n";
	
	if($treeHiderOn) {
		$html_out .= "<span class=\"commentTreeHider\">";
		$html_out .= $args->{children} ? ( $args->{children} > 1 ? "($args->{children} children)" : "($args->{children} child)") : "";
		$html_out .= "</span>\n";
	}

	if($args->{cid} > $args->{cid_now} && !$user->{is_anon} && $user->{highnew}) {
		$html_out .= " <div class=\"newBadge\">*New*</div>";
	}

	if($args->{marked_spam} && $user->{seclev} >= 500) {
		$html_out .= " <div class=\"spam\"> <a href=\"$constants->{real_rootdir}/comments.pl?op=unspam&amp;sid=$args->{sid}&amp;cid=$args->{cid}&amp;noban=1\">[Unspam-Only]</a> or <a href=\"$constants->{real_rootdir}/comments.pl?op=unspam&amp;sid=$args->{sid}&amp;cid=$args->{cid}\">[Unspam-AND-Ban]</a></div>\n";
	}

	my $details = dispCommentDetails({
		is_anon => $args->{is_anon},
		fakeemail => $args->{fakeemail},
		fakeemail_vis => $args->{fakeemail_vis},
		'time' => $time,
		cid => $args->{cid},
		sid => $args->{sid},
		homepage => $args->{homepage},
		journal_last_entry_date => $args->{journal_last_entry_date},
		nickname => $args->{nickname},
		ipid_display => $args->{ipid_display},
	});
	$html_out .= "</h4>\n</div>\n<div class=\"details\">$nick\n<span class=\"otherdetails\" id=\"comment_otherdetails_$args->{cid}\">$details</span>\n</div>\n</div>\n";

	my $sig;
	if ($args->{sig} && !$user->{nosigs} && !$args->{comment_shrunk}){
		$sig = "<div id=\"comment_sig_$args->{cid}\" class=\"sig\">$args->{sig}</div> \n";
	}

	my $shrunk;
	if ($args->{comment_shrunk}){
		$shrunk = "<div id=\"comment_shrunk_$args->{cid}\" class=\"commentshrunk\">" . dispLinkComment({
			sid     => $args->{sid},
			cid     => $args->{cid},
			pid     => $args->{cid},
			subject => 'Read the rest of this comment...',
			subject_only => 1
		}) . "</div> \n";
	}

	$html_out .= "<div class=\"commentBody\">\n<div id=\"comment_body_$args->{cid}\">$args->{comment}</div> \n$sig$shrunk</div>\n";

	$html_out .= dispLinkComment({
			original_pid => $args->{original_pid},
			cid => $args->{cid},
			pid => $args->{pid},
			sid => $args->{sid},
			options => $args->{options},
			reasons_html => $args->{reasons_html},
			can_mod => $args->{can_mod},
		})."\n</div>\n\n";

	if($user->{mode} eq 'flat') { $visible = 0; $visiblenopass = 0; }
	my $return = {
		data		=> $html_out,
		visible		=> $visible,
		visiblenopass	=> $visiblenopass,
	};
	return $return;
}

sub zooIcons {
	my $args = shift;
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $gSkin = getCurrentSkin();
	my $slashdb = getCurrentDB();
	my $user_person = $slashdb->getUser($args->{person});
	my $implied = defined($args->{implied}) ? $args->{implied} : -90210;
	my $bonus = defined($args->{bonus}) ? $args->{bonus} : 0;
	my $html_out = " ";
	my $zootitle = "";
	
	if($args->{person} && !$args->{implied} && $user_person->{acl}->{employee} && $user_person->{badge_id}) {
		my $badges = $slashdb->getBadgeDescriptions();
		my $badgeurl = defined($badges->{$user_person->{badge_id}}->{badge_url}) ? strip_urlattr($badges->{$user_person->{badge_id}}->{badge_url}) : "";
		my $badgeicon = $badges->{$user_person->{badge_id}}->{badge_icon} ? strip_urlattr($badges->{$user_person->{badge_id}}->{badge_icon}) : "";
		my $badgetitle = $badges->{$user_person->{badge_id}}->{badge_title} ? strip_attribute($badges->{$user_person->{badge_id}}->{badge_title}) : "";
		$html_out .= "<span class=\"badgeicon\"><a href=\"$badgeurl\"><img src=\"$constants->{imagedir}/$badgeicon\" alt=\"$badgetitle\" title=\"$badgetitle\" width=\"$constants->{badge_icon_size}\" height=\"$constants->{badge_icon_size}\"></a></span>";
	}
	elsif($args->{person} && $user->{uid} != $args->{person} && !$user->{is_anon}) {
		# Neutral
		if(!$user->{people}->{FRIEND()}->{$args->{person}} && !$user->{people}->{FOE()}->{$args->{person}} &&
			!$user->{people}->{FAN()}->{$args->{person}} && !$user->{people}->{FREAK()}->{$args->{person}} &&
			!$user->{people}->{FOF()}->{$args->{person}} && !$user->{people}->{EOF()}->{$args->{person}} ) {

			$html_out .= "<span class=\"zooicon neutral\"><a href=\"$gSkin->{rootdir}/zoo.pl?op=check&amp;uid=$args->{person}&amp;type=friend\"><img src=\"$constants->{imagedir}/neutral.$constants->{badge_icon_ext}\" alt=\"Neutral\" title=\"Neutral\" width=\"$constants->{badge_icon_size}\" height=\"$constants->{badge_icon_size}\"></a></span>";
		}
		else {
			# Friend
			if($user->{people}->{FRIEND()}->{$args->{person}} && $implied != FRIEND() ) {
				if($bonus && $user->{people_bonus_friend}) {
					$zootitle = "Friend ($user->{people_bonus_friend})";
				}
				else {
					$zootitle = "Friend";
				}
				$html_out .= "<span class=\"zooicon friend\"><a href=\"$gSkin->{rootdir}/zoo.pl?op=check&amp;uid=$args->{person}\"><img src=\"$constants->{imagedir}/friend.$constants->{badge_icon_ext}\" alt=\"$zootitle\" title=\"$zootitle\" width=\"$constants->{badge_icon_size}\" height=\"$constants->{badge_icon_size}\"></a></span> ";
			}
			# Foe
			if($user->{people}->{FOE()}->{$args->{person}} && $implied != FOE() ) {
				if($bonus && $user->{people_bonus_foe}) {
					$zootitle = "Foe ($user->{people_bonus_foe})";
				}
				else {
					$zootitle = "Foe";
				}
				$html_out .= "<span class=\"zooicon foe\"><a href=\"$gSkin->{rootdir}/zoo.pl?op=check&amp;uid=$args->{person}\"><img src=\"$constants->{imagedir}/foe.$constants->{badge_icon_ext}\" alt=\"$zootitle\" title=\"$zootitle\" width=\"$constants->{badge_icon_size}\" height=\"$constants->{badge_icon_size}\"></a></span> ";
			}
			# Fan
			if($user->{people}->{FAN()}->{$args->{person}} && $implied != FAN() ) {
				if($bonus && $user->{people_bonus_fan}) {
					$zootitle = "Fan ($user->{people_bonus_fan})";
				}
				else {
					$zootitle = "Fan";
				}
				$html_out .= "<span class=\"zooicon fan\"><a href=\"$gSkin->{rootdir}/zoo.pl?op=check&amp;uid=$args->{person}\"><img src=\"$constants->{imagedir}/fan.$constants->{badge_icon_ext}\" alt=\"$zootitle\" title=\"$zootitle\" width=\"$constants->{badge_icon_size}\" height=\"$constants->{badge_icon_size}\"></a></span> ";
			}
			# Freak
			if($user->{people}->{FREAK()}->{$args->{person}} && $implied != FREAK() ) {
				if($bonus && $user->{people_bonus_freak}) {
					$zootitle = "Freak ($user->{people_bonus_freak})";
				}
				else {
					$zootitle = "Freak";
				}
				$html_out .= "<span class=\"zooicon freak\"><a href=\"$gSkin->{rootdir}/zoo.pl?op=check&amp;uid=$args->{person}\"><img src=\"$constants->{imagedir}/freak.$constants->{badge_icon_ext}\" alt=\"$zootitle\" title=\"$zootitle\" width=\"$constants->{badge_icon_size}\" height=\"$constants->{badge_icon_size}\"></a></span> ";
			}
			# Friend of Friend
			if($user->{people}->{FOF()}->{$args->{person}} && $implied != FOF() ) {
				if($bonus && $user->{people_bonus_fof}) {
					$zootitle = "Friend of Friend ($user->{people_bonus_fof})";
				}
				else {
					$zootitle = "Friend of Friend";
				}
				$html_out .= "<span class=\"zooicon fof\"><a href=\"$gSkin->{rootdir}/zoo.pl?op=check&amp;uid=$args->{person}\"><img src=\"$constants->{imagedir}/fof.$constants->{badge_icon_ext}\" alt=\"$zootitle\" title=\"$zootitle\" width=\"$constants->{badge_icon_size}\" height=\"$constants->{badge_icon_size}\"></a></span> ";
			}
			# Foe of Friend
			if($user->{people}->{EOF()}->{$args->{person}} && $implied != EOF() ) {
				if($bonus && $user->{people_bonus_eof}) {
					$zootitle = "Foe of Friend ($user->{people_bonus_eof})";
				}
				else {
					$zootitle = "Foe of Friend";
				}
				$html_out .= "<span class=\"zooicon eof\"><a href=\"$gSkin->{rootdir}/zoo.pl?op=check&amp;uid=$args->{person}\"><img src=\"$constants->{imagedir}/eof.$constants->{badge_icon_ext}\" alt=\"$zootitle\" title=\"$zootitle\" width=\"$constants->{badge_icon_size}\" height=\"$constants->{badge_icon_size}\"></a></span> ";
			}
		}
	}
	return $html_out;
}

sub dispCommentDetails {
	my $args = shift;
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $html_out = "";

	if( (!defined($args->{is_anon}) || !$args->{is_anon}) && (defined($args->{fakeemail}) && $args->{fakeemail}) ) {
		$html_out .= "&lt;<a href=\"mailto:".strip_paramattr_nonhttp($args->{fakeemail})."\">".strip_literal($args->{fakeemail_vis})."</a>&gt;";
	}

	$html_out .= " on ".$args->{time};
	
	if($args->{cid} && $args->{sid}) {
		$html_out .= " (".linkComment({
			sid => $args->{sid},
			cid => $args->{cid},
			subject => "#$args->{cid}",
			subject_only => 1,
		}, 0, { noextra => 1 }).")";
	}
	
	$html_out .= "<small>";
	my $has_homepage = $args->{homepage} && length($args->{homepage}) > 8;
	my $has_journal = $args->{journal_last_entry_date} =~ /[1-9]/ ? 1 : 0;
	if(!$args->{is_anon} && ($has_homepage || $has_journal)) {
		if($has_homepage) {
			$html_out .= " <a href=\"$args->{homepage}\" class=\"user_homepage_display\">Homepage</a>";
		}
		if($has_journal) {
			$html_out .= " <a href=\"$constants->{real_rootdir}/~".strip_paramattr(fixnickforlink($args->{nickname}))."/journal/\" title=\"".timeCalc($args->{journal_last_entry_date})."\">Journal</a>";
		}
	}

	$html_out .= " ".$args->{ipid_display}."\n</small>";
	
	return $html_out;
}

sub dispLinkComment {
	my $args = shift;
	my $html_out = "";
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	if($user->{mode} eq 'metamod' || $user->{mode} eq 'archive') { return ""; }
	if(!$user->{is_admin} && !$args->{original_pid} && $user->{state}->{discussion_archived}) { return ""; }

	my $do_parent = defined($args->{original_pid}) ? $args->{original_pid} : 0;
	my $can_del = (defined($constants->{authors_unlimited}) && $user->{seclev} >= $constants->{authors_unlimited})
			|| (defined($user->{acl}->{candelcomments_always}) && $user->{acl}->{candelcomments_always});
	
	if(!$args->{options}->{show_pieces}) {
		$html_out .= "<div class=\"commentSub\" id=\"comment_sub_$args->{cid}\">";
	}
	if(!$args->{options}->{pieces}) {
		if(!$user->{state}->{discussion_archived} && !$user->{state}->{discussion_future_nopost}) {
			$html_out .= "<span id=\"reply_link_$args->{cid}\" class=\"nbutton\"><b>".
				linkComment({
					sid => $args->{sid},
					pid => $args->{pid},
					cid => $args->{cid},
					op => 'Reply',
					subject => 'Reply to This',
					subject_only => 1,
				})."</b></span> \n";
		}
		if($do_parent) {
			$html_out .= "<span class=\"nbutton\"><b>".
				linkComment({
					sid => $args->{sid},
					cid => $do_parent,
					pid => $do_parent,
					subject => 'Parent',
					subject_only => 1,
				}, 1)."</b></span> \n";
		}
		if($args->{can_mod}) {
			$html_out .= "<div id=\"reasondiv_$args->{cid}\" class=\"modsel\">\n"
				."<select id=\"reason_$args->{cid}\" name=\"reason_$args->{cid}\">\n$args->{reasons_html}</select> \n"
				."</div> \n<button type=\"submit\" name=\"moderate\" value=\"comment_$args->{cid}\">Moderate</button> \n";
		}

		if($can_del) {
			$html_out .= "<input type=\"checkbox\" name=\"del_$args->{cid}\"> Check to Delete";
		}
	}
	if(!$args->{options}->{show_pieces}) { $html_out .= "</div>\n"; }
	return $html_out;;
}
1;

__END__


=head1 SEE ALSO

Slash(3).

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
	jsSelectComments commentCountThreshold commentThresholds discussion2
	selectComments preProcessReplyForm makeCommentBitmap parseCommentBitmap
	getPoints preProcessComment postProcessComment prevComment saveComment
);


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
# print STDERR scalar(gmtime) . " selectComments cid undef for $discussion\n" if !defined($cid);
	$cid ||= 0;

	my $discussion2 = discussion2($user);

#slashProf("sC setup");

	# it's a bit of a drag, but ... oh well! 
	# print_cchp gets messed up with d2, so we just punt and have
	# selectComments called twice if necessary, the first time doing
	# print_cchp, then blanking that out so it is not done again -- pudge
	my $shtml = 0;
	if ($discussion2 && $form->{ssi} && $form->{ssi} eq 'yes' && $form->{cchp}) {
		$user->{discussion2} = 'none';
		selectComments($discussion, $cid, $options);
		$user->{discussion2} = $discussion2;
		$shtml = 1;
		delete $form->{cchp};
	}

	my $comments_read = !$user->{is_anon}
		? $slashdb->getCommentReadLog($discussion->{id}, $user->{uid})
		: {};

	my $commentsort = defined $options->{commentsort}
		? $options->{commentsort}
		: $user->{commentsort};
	my $threshold = defined $options->{threshold}
		? $options->{threshold}
		: $user->{threshold};


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
	$gcfu_opt->{discussion2} = $discussion2;
#slashProf("sC getCommentsForUser");
	if ($options->{force_read_from_master}) {
		$thisComment = $slashdb->getCommentsForUser($discussion->{id}, $cid, $gcfu_opt);
	} else {
		$thisComment = $reader->getCommentsForUser($discussion->{id}, $cid, $gcfu_opt);
	}
#slashProf("", "sC getCommentsForUser");
#slashProfBail() if $cid || @$thisComment < 100;

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
	for my $C (@$thisComment) {
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
#		$user->{state}{noreparent} = 1 if $commentsort > 3;
#my $errstr = "selectComments discid=$discussion->{id} cid=$cid options=" . Dumper($options); $errstr =~ s/\s+/ /g;
		$C->{points} = getPoints($C, $user, $min, $max, $max_uid, $reasons); # , $errstr
	}

	my $d2_comment_q = $user->{d2_comment_q};
	if ($discussion2 && !$d2_comment_q) {
		if ($user->{is_anon}) {
			$d2_comment_q = 5; # medium
		}
	}

#slashProf("sC main sort", "sC setup");
	my($oldComment, %old_comments);
	if ($discussion2 && !$options->{no_d2}) {
		my $limits = $slashdb->getDescriptions('d2_comment_limits');
		my $max = $d2_comment_q ? $limits->{ $d2_comment_q } : 0;
		$max = int($max/2) if $shtml;
		my @new_comments;
		$options->{existing} ||= {};
		@$thisComment = sort { $a->{cid} <=> $b->{cid} } @$thisComment;

		# we need to filter which comments are descendants of $cid
		my %cid_seen;
		if ($cid) {
			# for display later
			$user->{state}{d2_defaultclass}{$cid} = 'full';
			# this only works because we are already in cid order
			for my $C (@$thisComment) {
				if ($cid == $C->{cid} || $cid_seen{$C->{pid}}) {
					$cid_seen{$C->{cid}} = 1;
				}
			}
		}

		my $sort_comments;
		if (!$user->{d2_comment_order}) { # score
			$sort_comments = [ sort {
				$b->{points} <=> $a->{points}
					||
				$a->{cid} <=> $b->{cid}
			} @$thisComment ];
		} else { # date / cid
			$sort_comments = $thisComment;
		}


		for my $C (@$sort_comments) {
			next if $options->{existing}{$C->{cid}};

			if ($max && @new_comments >= $max) {
				if ($cid) {
					# still include $cid even if it would
					# otherwise be excluded (should only
					# matter if not sorting by date
					push @new_comments, $C if $cid == $C->{cid};
				} else {
					last;
				}
			} else {
				next if $cid && !$cid_seen{$C->{cid}};
				push @new_comments, $C;
			}
		}

		$comments->{0}{d2_seen} = makeCommentBitmap({
			%{$options->{existing}}, map { $_->{cid} => 1 } @new_comments
		});

		@new_comments = sort { $a->{cid} <=> $b->{cid} } @new_comments;
		($oldComment, $thisComment) = ($thisComment, \@new_comments);
		%old_comments = map { $_->{cid} => $_ } @$oldComment;

	} else {
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
	}
##slashProf("sC fudging", "sC main sort");
#slashProf("", "sC main sort");

	# This loop mainly takes apart the array and builds 
	# a hash with the comments in it.  Each comment is
	# in the index of the hash (based on its cid).
	for my $C (@$thisComment) {
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

		$comments->{$C->{cid}}{has_read} = $comments_read->{$C->{cid}};
		$user->{state}{d2_defaultclass}{$C->{cid}} = 'oneline'
			if $user->{d2_reverse_switch} && $comments_read->{$C->{cid}}
			&& $C->{cid} != $cid;

		# The comment pushes itself onto its parent's
		# kids array.
		push @{$comments->{$C->{pid}}{kids}}, $C->{cid};

		# The next line deals with hitparade -Brian
		#$comments->{0}{totals}[$C->{points} - $min]++;  # invert minscore

		# Increment the parent comment's count of visible kids,
		# if this comment is indeed visible.
		$comments->{$C->{pid}}{visiblekids}++
			if $C->{points} >= (defined $threshold ? $threshold : $min);

		# Can't mod in a discussion that you've posted in.
		# Just a point rule -Brian
		$user->{points} = 0 if $C->{uid} == $user->{uid}; # Mod/Post Rule
	}
##slashProf("sC more fudging", "sC fudging");

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

##slashProf("sC counting", "sC more fudging");
	# Cascade comment point totals down to the lowest score, so
	# (2, 1, 3, 5, 4, 2, 1) becomes (18, 16, 15, 12, 7, 3, 1).
	# We do a bit of a weird thing here, returning this data in
	# the fields for a fake comment with "cid 0"...
	for my $x (reverse(0..$num_scores-2)) {
		$comments->{0}{totals}[$x] += $comments->{0}{totals}[$x + 1];
	}

	# get the total visible kids for each comment --Pater
	countTotalVisibleKids($comments) unless $discussion2;

##slashProf("sC d2 fudging", "sC counting");
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
						$user->{state}{d2_defaultclass}{$C->{pid}} = 'oneline';
						$parent = $old_comments{ $C->{pid} };
						$parent->{has_read} = $comments_read->{$C->{pid}};
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
							has_read => $comments_read->{$C->{pid}},
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

		# fix d2_seen to include new cids ... these will all be after
		# the last element in seen, which makes this simpler
		$comments->{0}{d2_seen} = makeCommentBitmap(\@new_seen, $comments->{0}{d2_seen});
	}

##slashProf("", "sC d2 fudging");

	_print_cchp($discussion, $count, $comments->{0}{totals});

#slashProf("sC reparenting");
	reparentComments($comments, $reader, $options);
#slashProf("", "sC reparenting");

	return($comments, $count);
}

sub jsSelectComments {
#slashProf("jsSelectComments");
	# version 0.9 is broken; 0.6 and 1.00 seem to work -- pudge 2006-12-19
	require Data::JavaScript::Anon;
	my($slashdb, $constants, $user, $form, $gSkin) = @_;
	$slashdb   ||= getCurrentDB();
	$constants ||= getCurrentStatic();
	$user      ||= getCurrentUser();
	$form      ||= getCurrentForm();
	$gSkin     ||= getCurrentSkin();

	my $id = $form->{sid};
	return unless $id;

	my $threshold = defined $user->{d2_threshold} ? $user->{d2_threshold} : $user->{threshold};
	my $highlightthresh = defined $user->{d2_highlightthresh} ? $user->{d2_highlightthresh} : $user->{highlightthresh};
	for ($threshold, $highlightthresh) {
		$_ = 6  if $_ > 6;
		$_ = -1 if $_ < -1;
	}
	$highlightthresh = $threshold if $highlightthresh < $threshold;

	# only differences:
	#    sco: force_read, one_cid_only, threshold (was -1 here, matters?)
	my($comments) = $user->{state}{selectComments}{comments};

	my $d2_seen_0 = $comments->{0}{d2_seen} || '';

	my @roots = @{$comments->{0}{kids} || []};
	my %roots_hash = ( map { $_ => 1 } @roots );
	my $thresh_totals;

	if ($form->{full}) {
		my $comment_text = $slashdb->getCommentTextCached(
			$comments, [ grep $_, keys %$comments ],
		);

		for my $cid (keys %$comment_text) {
			$comments->{$cid}{comment} = $comment_text->{$cid};
		}
	} else {
		my $comments_new;
		my @keys = qw(pid points uid);
		for my $cid (grep $_, keys %$comments) {
			@{$comments_new->{$cid}}{@keys} = @{$comments->{$cid}}{@keys};
			$comments_new->{$cid}{read} = $comments->{$cid}{has_read} ? 1 : 0;
			$comments_new->{$cid}{opid} = $comments->{$cid}{original_pid};
			$comments_new->{$cid}{kids} = [sort { $a <=> $b } @{$comments->{$cid}{kids}}];

			# we only care about it if it is not original ... we could
			# in theory guess at what it is and just use a flag, but that
			# could be complicated, esp. if we are several levels deep -- pudge
			if ($comments->{$cid}{subject_orig} && $comments->{$cid}{subject_orig} eq 'no') {
				$comments_new->{$cid}{subject} = $comments->{$cid}{subject};
			}
		}

		$thresh_totals = commentCountThreshold($comments, 0, \%roots_hash);
		$comments = $comments_new;
	}

	my $anon_comments = Data::JavaScript::Anon->anon_dump($comments);
	my $anon_roots    = Data::JavaScript::Anon->anon_dump(\@roots);
	my $anon_rootsh   = Data::JavaScript::Anon->anon_dump(\%roots_hash);
	my $anon_thresh   = Data::JavaScript::Anon->anon_dump($thresh_totals || {});
	s/\s+//g for ($anon_thresh, $anon_roots, $anon_rootsh);

	$user->{is_anon}          ||= 0;
	$user->{is_admin}         ||= 0;
	$user->{is_subscriber}    ||= 0;
	$user->{state}{d2asp}     ||= 0;
	$user->{d2_comment_order} ||= 0;
	my $root_comment = $user->{state}{selectComments}{cidorpid} || 0;

	my $extra = '';
	if ($d2_seen_0) {
		my $total = $slashdb->countCommentsBySid($id);
		$total -= $d2_seen_0 =~ tr/,//; # total
		$total--; # off by one
		$extra .= "D2.d2_seen('$d2_seen_0');\nD2.more_comments_num($total);\n";
	}
	if ($user->{d2_keybindings_switch}) {
		$extra .= "D2.d2_keybindings_off(1);\n";
	}
	if ($user->{d2_reverse_switch}) {
		$extra .= "D2.d2_reverse_shift(1);\n";
	}

	# maybe also check if this ad should be running with some other var?
	# from ads table? -- pudge
	if ( $constants->{run_ads}
	 && !$user->{state}{page_adless}
	 && !$user->{state}{page_buying}
	 &&  $user->{currentSkin} ne 'admin'
	 &&  $constants->{run_ads_inline_comments}
	) {
		(my $url = $constants->{run_ads_inline_comments}) =~ s/<topic>/$gSkin->{name}/g;
		$extra .= "D2.adTimerUrl('$url');\n";
	}
#slashProf("", "jsSelectComments");

	return <<EOT;
D2.comments($anon_comments);

D2.thresh_totals($anon_thresh);

D2.root_comment($root_comment);
D2.root_comments($anon_roots);
D2.root_comments_hash($anon_rootsh);

D2.d2_comment_order($user->{d2_comment_order});
D2.user_uid($user->{uid});
D2.user_is_anon($user->{is_anon});
D2.user_is_admin($user->{is_admin});
D2.user_is_subscriber($user->{is_subscriber});
D2.user_threshold($threshold);
D2.user_highlightthresh($highlightthresh);
D2.user_d2asp($user->{state}{d2asp});

D2.discussion_id($id);

$extra
EOT
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
	for (0..9) {
		if ((caller($_))[1] =~ /\bajax\.pl$/) {
			$hashref->{no_titlebar} = 1;
			last;
		}
	}

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

	# And, the poster-was-a-subscriber bonus
	if ($user->{subscriber_bonus} && $C->{subscriber_bonus} eq 'yes') {
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

########################################################
sub reparentComments {
	my($comments, $reader, $options) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	my $threshold = defined $options->{threshold}
		? $options->{threshold}
		: $user->{threshold};

	my $max_depth_allowed = $user->{state}{max_depth} || $constants->{max_depth} || 7;

	# even if !reparent, we still want to be here so we can set comments at max depth
	return if $user->{state}{noreparent} || (!$max_depth_allowed && !$user->{reparent});

	# Adjust the max_depth_allowed for the root pid or cid.
	# Actually I'm not sure this should be done at all.
	# My guess is that it does the opposite of what's desired
	# when $form->{cid|pid} is set.  And besides, max depth we
	# display is for display, so it should be based on how much
	# we're displaying, not on absolute depth of this thread.
	my $root_cid_or_pid = discussion2($user) ? 0 : ($form->{cid} || $form->{pid} || 0);
	if ($root_cid_or_pid) {
		my $tmpcid = $root_cid_or_pid;
		while ($tmpcid) {
			my $pid = $reader->getComment($tmpcid, 'pid') || 0;
			last unless $pid;
			$max_depth_allowed++;
			$tmpcid = $pid;
		}
	}

	# The below algorithm assumes that comments are inserted into
	# the database with cid's that increase chronologically, in order
	# words that for any two comments where A's cid > B's cid, that
	# A's timestamp > B's timestamp also.

	for my $x (sort { $a <=> $b } keys %$comments) {
		next if $x == 0; # exclude the fake "cid 0" comment

		my $pid = $comments->{$x}{pid} || 0;
		my $reparent = 0;

		# First, if this comment is above the user's desired threshold
		# (and thus will likely be shown), but its parent is below
		# the desired threshold (and thus will not likely be shown),
		# bounce it up the chain until we can reparent it to a comment
		# that IS being shown.  Effectively we pretend the invisible
		# comments between this comment and its (great-etc.) grandparent
		# do not exist.
		#
		# But, if all its (great-etc.) grandparents are either invisible
		# or chronologically precede the root comment, don't reparent it
		# at all.
		# XXX either $comments->{$x}{points} or $threshold is sometimes undefined here, not sure which or why
		if ($user->{reparent} && $comments->{$x}{points} >= $threshold) {
			my $tmppid = $pid;
			while ($tmppid
				&& $comments->{$tmppid} && defined($comments->{$tmppid}{points})
				&& $comments->{$tmppid}{points} < $threshold) {
				$tmppid = $comments->{$tmppid}{pid} || 0;
				$reparent = 1;
			}

			if ($reparent && $tmppid >= $root_cid_or_pid) {
				$pid = $tmppid;
			} else {
				$reparent = 0;
			}
		}

		# Second, if the above did not find a suitable (great)grandparent,
		# we try a second method of collapsing to a (great)grandparent:
		# check whether the depth of this comment is too great to show
		# nested so deeply, and if so, ratchet it back.  Note that since
		# we are iterating through %$comments in cid order, the parents of
		# this comment will already have gone through this code and thus
		# already should have their {depth}s set.  (At least that's the
		# theory, I'm not sure that part really works.)
		if ($max_depth_allowed && !$reparent) {
			# set depth of this comment based on parent's depth
			$comments->{$x}{depth} = ($pid ? ($comments->{$pid}{depth} ||= 0) : 0) + 1;

			# go back each pid until we find one with depth less than $max_depth_allowed
			while ($pid && defined($comments->{$pid})
				&& ($comments->{$pid}{depth} ||= 0) >= $max_depth_allowed) {
				$pid = $comments->{$pid}{pid};
				$reparent = 1;
			}
		}

		if ($reparent) {
			# remove child from old parent
			if ($pid >= $root_cid_or_pid) {
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

	# Do some easy and high-priority initial tests.  If any of
	# these is true, this comment is not moderatable, and these
	# override the ACL and seclev tests.
	return 0 if !$comment;
	return 0 if
		    $user->{is_anon}
		|| !$constants->{m1}
		||  $comment->{no_moderation};
	
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
	return 0 if
		    $user->{points} <= 0
		|| !$user->{willing}
		||  $comment->{uid} == $user->{uid}
		||  $comment->{lastmod} == $user->{uid}
		||  $comment->{ipid} eq $user->{ipid};
	return 0 if
		    $constants->{mod_same_subnet_forbid}
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
	my $pretext = '';
	$options ||= {};

	

	if (!$discussion || !$discussion->{id}) {
		my $retval =  Slash::getData('no_such_sid', '', '');
		return $retval if $options->{Return};
		return 0;
	}

	my $discussion2 = discussion2($user);

#slashProfInit();
#slashProf("printComments: $discussion2, $discussion->{id}");

	if ($discussion2 && $user->{mode} ne 'metamod') {
		$user->{mode} = $form->{mode} = 'thread';
		$user->{commentsort} = 0;
		$user->{reparent} = 0;
		$user->{state}{max_depth} = $constants->{max_depth} + 3;
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

#slashProf("selectComments");
	my($comments, $count) = selectComments($discussion, $cidorpid, $sco);
#slashProf("", "selectComments");
	if ($discussion2) {
		$user->{state}{selectComments} = {
			cidorpid	=> $cidorpid,
			comments        => $comments,
			count           => $count
		};
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
		$pretext .= slashDisplay('printCommNoArchive', { discussion => $discussion }, { Return => $options->{Return}});
	}

#slashProf("printCommentsMain");
	$pretext .= slashDisplay('printCommentsMain', {
		comments	=> $comments,
		title		=> $discussion->{title},
		'link'		=> $discussion->{url},
		count		=> $count,
		sid		=> $discussion->{id},
		cid		=> $cid,
		pid		=> $pid,
		lvl		=> $lvl,
		options		=> $options,
	}, { Return => $options->{Return}} );
#slashProf("", "printCommentsMain");

	return $options->{Return} ? $pretext: '' if $user->{state}{nocomment} || $user->{mode} eq 'nocomment';

	my($comment, $next, $previous);
	if ($cid && !$discussion2) {
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
	my $total = ($user->{mode} eq 'flat' || $user->{mode} eq 'nested')
		? $comments->{$cidorpid}{totalvisiblekids}
		: $cc;

	my $lcp = $discussion2
		? ''
		: linkCommentPages($discussion->{id}, $pid, $cid, $total);

	# Figure out whether to show the moderation button.  We do, but
	# only if at least one of the comments is moderatable.
	my $can_mod_any = _can_mod($comment);
	if (!$can_mod_any) {
		CID: for my $cid (keys %$comments) {
			if (_can_mod($comments->{$cid})) {
				$can_mod_any = 1;
				last CID;
			}
		}
	}

#slashProf("printCommComments");
	my $anon_dump;
	if ($discussion2) {
		require Data::JavaScript::Anon;
		$anon_dump = \&Data::JavaScript::Anon::anon_dump;
	}

#use Data::Dumper; $Data::Dumper::Sortkeys = 1; print STDERR "printCommComments, comment: " . Dumper($comment) . "comments: " . Dumper($comments->{34}) . "discussion2: " . Dumper($discussion2);
	my $comment_html = $options->{Return} ?  $pretext : '';


	$comment_html .= slashDisplay('printCommComments', {
		can_moderate	=> $can_mod_any,
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
		discussion2	=> $discussion2,
		anon_dump	=> $anon_dump,
	}, { Return => 1 });

#slashProf("getCommentTextCached", "printCommComments");
	# We have to get the comment text we need (later we'll search/replace
	# them into the text).
	my $comment_text = $slashdb->getCommentTextCached(
		$comments, [ grep { !$comments->{$_}{dummy} } @{$user->{state}{cids}} ],
		{ mode => $form->{mode}, cid => $form->{cid}, discussion2 => $discussion2 }
	);
#slashProf("comment regexes", "getCommentTextCached");

	# OK we have all the comment data in our hashref, so the search/replace
	# on the nearly-fully-rendered page will work now.
	$comment_html =~ s|<SLASH type="COMMENT-TEXT">(\d+)</SLASH>|$comment_text->{$1}|g;

	# for abbreviated comments, remove some stuff
	if ($discussion2) {
		my @abbrev     = grep { defined($comments->{$_}{abbreviated}) && $comments->{$_}{abbreviated} != -1 } keys %$comments;
		my @not_abbrev = grep { defined($comments->{$_}{abbreviated}) && $comments->{$_}{abbreviated} == -1 } keys %$comments;
		my %abbrev_and_not = map { $_ => 1 } (@abbrev, @not_abbrev);
		$comment_html =~ s|(<div id="comment_shrunk_(\d+)" class="commentshrunk">.+?</div>)|$abbrev_and_not{$2} ? '' : $1|eg;
		$comment_html =~ s|((<div id="comment_sig_(\d+)" class="sig) hide">)|$abbrev_and_not{$3} ? qq{$2">} : $1|eg;

#		for my $cid (@abbrev, @not_abbrev) {
#			$comment_html =~ s|<div id="comment_shrunk_$cid" class="commentshrunk">.+?</div>||;
#			$comment_html =~ s|<div id="comment_sig_$cid" class="sig hide">|<div id="comment_sig_$cid" class="sig">|;
#		}

		if (@abbrev) {
			my $abbrev_comments = join ',', map { "$_:$comments->{$_}{abbreviated}" } @abbrev;
			$comment_html =~ s|D2\.abbrev_comments\({}\);|D2.abbrev_comments({$abbrev_comments});|;
		}
	}

#slashProf("", "comment regexes");
#slashProf("", "printComments: $discussion2, $discussion->{id}");
#slashProfEnd();
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
#slashProf("displayThread");
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

	my $discussion2 = discussion2($user);
	my $threshold = $discussion2 && defined $user->{d2_threshold} ? $user->{d2_threshold} : $user->{threshold};
	my $highlightthresh = $discussion2 && defined $user->{d2_highlightthresh} ? $user->{d2_highlightthresh} : $user->{highlightthresh};
	$highlightthresh = $threshold if $highlightthresh < $threshold;
	# root comment should have more likelihood to be full
	$highlightthresh-- if !$pid;

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
			qw(table cage cagebig indent comment fullcomment)) {
			$const->{$_} = Slash::getData($_, '', '');
		}
	}

	for my $cid (@{$comments->{$pid}{kids}}) {
		my $comment = $comments->{$cid};

		$skipped++;
		# since nested and threaded show more comments, we can skip
		# ahead more, counting all the visible kids.	--Pater
		$skipped += $comment->{totalvisiblekids} if ($user->{mode} eq 'flat' || $user->{mode} eq 'nested');
		$form->{startat} ||= 0;
		next if $skipped <= $form->{startat} && !$discussion2;
		$form->{startat} = 0; # Once We Finish Skipping... STOP

		my $class = 'oneline';
		if ($comment->{dummy}) {
			$class = 'hidden';
		} elsif ($comment->{points} < $threshold) {
			if ($user->{is_anon} || ($user->{uid} != $comment->{uid})) {
				if ($discussion2) {
					$class = 'hidden';
					$hidden++;
				} else {
					$hidden++;
					next;
				}
			}
		}

		my $highlight = ($comment->{points} >= $highlightthresh && $class ne 'hidden') ? 1 : 0;
		$class = 'full' if $highlight;
		if ($discussion2 && $user->{state}{d2_defaultclass}{$cid}) {
			$class = $user->{state}{d2_defaultclass}{$cid};
		}
		$comment->{class} = $class;

		$user->{state}{comments}{totals}{$class}++ unless $comment->{dummy};

		my $finish_list = 0;

		if ($full || $highlight || $discussion2) {
			if ($discussion2 && $class eq 'oneline' && $comment->{subject_orig} eq 'no') {
				$comment->{subject} = 'Re:';
			}

			my($noshow, $pieces) = (0, 0);
			if ($discussion2) { # && $user->{acl}{d2testing}) {
				if ($class eq 'hidden') {
					$noshow = 1;
					$user->{state}{comments}{noshow} ||= [];
					push @{$user->{state}{comments}{noshow}}, $cid;
				} elsif ($class eq 'oneline') {
					$pieces = 1;
					$user->{state}{comments}{pieces} ||= [];
					push @{$user->{state}{comments}{pieces}}, $cid;
				}
			}

			if ($lvl && $indent) {
				$return .= $const->{tablebegin} .
					dispComment($comment, { noshow => $noshow, pieces => $pieces }) .
					$const->{tableend};
				$cagedkids = 0;
			} else {
				$return .= dispComment($comment, { noshow => $noshow, pieces => $pieces });
			}
			$displayed++ unless $comment->{dummy};
		} else {
			my $pntcmt = @{$comments->{$comment->{pid}}{kids}} > $user->{commentspill};
			$return .= $const->{commentbegin} .
				linkComment($comment, $pntcmt, { date => 1 });
			$finish_list++;
		}
		$return .= $const->{fullcommentend} if ($user->{mode} eq 'flat');

		if ($comment->{kids} && ($user->{mode} ne 'parents' || $pid)) {
			if (my $str = displayThread($sid, $cid, $lvl+1, $comments, $const)) {
				$return .= $const->{cagebegin} if $cagedkids;
				if ($indent && $const->{indentbegin}) {
					(my $indentbegin = $const->{indentbegin}) =~ s/^(<[^<>]+)>$/$1 id="commtree_$cid">/;
					$return .= $indentbegin;
				}
				$return .= $str;
				$return .= $const->{indentend} if $indent;
				$return .= $const->{cageend} if $cagedkids;
			}
			# in flat or nested mode, all visible kids will
			# be shown, so count them.	-- Pater
			$displayed += $comment->{totalvisiblekids} if ($user->{mode} eq 'flat' || $user->{mode} eq 'nested');
		}

		$return .= "$const->{commentend}" if $finish_list;
		$return .= "$const->{fullcommentend}" if (($full || $highlight || $discussion2) && $user->{mode} ne 'flat');

		last if $displayed >= $user->{commentlimit} && !$discussion2;
	}

	if ($hidden && ($discussion2 || (!$user->{hardthresh} && $user->{mode} ne 'archive' && $user->{mode} ne 'metamod'))) {
		my $link = linkComment({
			sid		=> $sid,
			threshold	=> $constants->{comment_minscore},
			pid		=> $pid,
			subject		=> Slash::getData('displayThreadLink', { 
						hidden => $hidden 
					   }, ''),
			subject_only	=> 1,
		});
		if ($discussion2) {
			push @{$user->{state}{comments}{hiddens}}, $pid;
			$return .= slashDisplay('displayThread', {
				'link'		=> $link,
				discussion2	=> $discussion2,
				pid		=> $pid,
				hidden		=> $hidden
			}, { Return => 1, Nocomm => 1 });
		} else {
			$return .= $const->{cagebigbegin} if $cagedkids;
			$return .= slashDisplay('displayThread',
				{ 'link' => $link },
				{ Return => 1, Nocomm => 1 }
			);
			$return .= $const->{cagebigend} if $cagedkids;
		}
	}
#slashProf("", "displayThread");

	return $return;
}

#========================================================================

sub preProcessReplyForm {
	my($form, $reply) = @_;
	return if !$form->{pid} || !$reply->{subject} || $form->{postersubj};

	$form->{postersubj} = decode_entities($reply->{subject});
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

	my $tempSubject = strip_notags($comm->{postersubj});
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

	if (!$from_db) {
		$comm->{comment} = parseDomainTags($comm->{comment},
			!$comm->{anon} && $comm->{fakeemail});

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
	$comm->{nosubscriberbonus} = $user->{nosubscriberbonus}
						unless $comm->{nosubscriberbonus_present};

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
		print $text if $text && !discussion2($user);
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
				subject         => {
					template_name => 'reply_msg_subj',
					template_page => 'comments',
				},
				reply           => $reply,
				parent          => $parent,
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
				template_name   => 'journrep',
				template_page   => 'comments',
				subject         => {
					template_name => 'journrep_subj',
					template_page => 'comments',
				},
				reply           => $reply,
				discussion      => $discussion,
			};

			$messages->create($users->[0], MSG_CODE_JOURNAL_REPLY, $data);
			$users{$users->[0]}++;
		}
	}

	# comment posted
	if ($messages && $constants->{commentnew_msg}) {
		my $users = $messages->getMessageUsers(MSG_CODE_NEW_COMMENT);

		my $data  = {
			template_name   => 'commnew',
			template_page   => 'comments',
			subject         => {
				template_name => 'commnew_subj',
				template_page => 'comments',
			},
			reply           => $reply,
			discussion      => $discussion,
		};

		my @users_send;
		for my $usera (@$users) {
			next if $users{$usera};
			push @users_send, $usera;
			$users{$usera}++;
		}
		$messages->create(\@users_send, MSG_CODE_NEW_COMMENT, $data) if @users_send;
	}

	my $achievements = getObject('Slash::Achievements');
	if ($achievements) {
		$achievements->setUserAchievement('comment_posted', $user->{uid});
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
	my $maxcommentsize = $options->{maxcommentsize} || $constants->{default_maxcommentsize};

	my $comment_shrunk;

	if ($form->{mode} ne 'archive'
		&& !defined($comment->{abbreviated})
		&& $comment->{len} > $maxcommentsize
		&& $form->{cid} ne $comment->{cid})
	{
		$comment_shrunk = 1;
	}

	postProcessComment($comment, 1);

#X
# 	$comment->{sig} = parseDomainTags($comment->{sig}, $comment->{fakeemail});
# 	if ($comment->{sig}) {
# 		$comment->{sig} =~ s/^\s*-{1,5}\s*<(?:P|BR)>//i;
# 		$comment->{sig} = Slash::getData('sigdash', {}, 'comments')
# 			. $comment->{sig};
# 	}
#Y

	if (!$comment->{karma_bonus} || $comment->{karma_bonus} eq 'no') {
		for ($comment->{sig}, $comment->{comment}) {
			$_ = noFollow($_);
		}
	}

	my $reasons = undef;
	if ($mod_reader) {
		$reasons = $mod_reader->getReasons();
	}

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
<span class="user_ipid_display">[<a href="$constants->{real_rootdir}/users.pl?op=userinfo&amp;userfield=$comment->{ipid}&amp;fieldname=ipid">$comment->{ipid_vis}</a>
<a href="$constants->{real_rootdir}/users.pl?op=userinfo&amp;userfield=$comment->{subnetid}&amp;fieldname=subnetid">$comment->{subnetid_vis}</a>]</span>
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

	$comment->{class} ||= 'full';

#use Data::Dumper; print STDERR "dispComment hard='$constants->{comments_hardcoded}' can_mod='$can_mod' comment: " . Dumper($comment) . "reasons: " . Dumper($reasons);

	my $discussion2 = discussion2($user);

	return _hard_dispComment(
		$comment, $constants, $user, $form, $comment_shrunk,
		$can_mod, $reasons, $options, $discussion2
	) if $constants->{comments_hardcoded};

	if ($options->{show_pieces}) {
		my @return;
		push @return, slashDisplay('dispCommentDetails', {
			%$comment,
			comment_shrunk	=> $comment_shrunk,
			reasons		=> $reasons,
			can_mod		=> $can_mod,
			is_anon		=> isAnon($comment->{uid}),
			discussion2	=> $discussion2,
			options		=> $options
		}, { Return => 1, Nocomm => 1 });
		push @return, slashDisplay('dispLinkComment', {
			%$comment,
			comment_shrunk	=> $comment_shrunk,
			reasons		=> $reasons,
			can_mod		=> $can_mod,
			is_anon		=> isAnon($comment->{uid}),
			discussion2	=> $discussion2,
			options		=> $options
		}, { Return => 1, Nocomm => 1 });
		return @return;
	}

	return slashDisplay('dispComment', {
		%$comment,
		comment_shrunk	=> $comment_shrunk,
		reasons		=> $reasons,
		can_mod		=> $can_mod,
		is_anon		=> isAnon($comment->{uid}),
		discussion2	=> $discussion2,
		options		=> $options
	}, { Return => 1, Nocomm => 1 });
}

########################################################
# this sucks, but it is here for now
sub _hard_dispComment {
	my($comment, $constants, $user, $form, $comment_shrunk, $can_mod, $reasons, $options, $discussion2) = @_;
	my $gSkin = getCurrentSkin();

	my($comment_to_display, $score_to_display,
		$user_nick_to_display, $zoosphere_display, $user_email_to_display,
		$time_to_display, $comment_link_to_display, $userinfo_to_display,
		$comment_links)
		= ("") x 9;

	$comment_to_display = qq'<div id="comment_body_$comment->{cid}">$comment->{comment}</div>';
	my $sighide = $comment_shrunk ? ' hide' : '';
	$comment_to_display .= qq'<div id="comment_sig_$comment->{cid}" class="sig$sighide">$comment->{sig}</div>' if $comment->{sig} && !$user->{nosigs};

	if ($comment_shrunk) {
		my $readtext = 'Read the rest of this comment...';
		my $link;
		if ($discussion2) {
			$link = qq'<a class="readrest" href="$gSkin->{rootdir}/comments.pl?sid=$comment->{sid}&amp;cid=$comment->{cid}" onclick="return D2.readRest($comment->{cid})">$readtext</a>';
		} else {
			$link = linkComment({
				sid	=> $comment->{sid},
				cid	=> $comment->{cid},
				pid	=> $comment->{cid},
				subject	=> $readtext,
				subject_only => 1,
			}, 1);
		}
		$comment_to_display .= qq'<div id="comment_shrunk_$comment->{cid}" class="commentshrunk">$link</div>';
	}

	$time_to_display = timeCalc($comment->{date});
	unless ($user->{noscores}) {
		$score_to_display .= "Score:";
		if (length $comment->{points}) {
			$score_to_display .= $comment->{points};
			if ($constants->{modal_prefs_active}) {
				my $func = "getModalPrefs('modcommentlog', 'Moderation Comment Log', $comment->{cid})";
				$score_to_display = qq[<a href="#" onclick="$func; return false">$score_to_display</a>];
			}
		} else {
			$score_to_display .= '?';
		}
		if ($reasons && $comment->{reason}) {
			$score_to_display .= ", $reasons->{$comment->{reason}}{name}";
		}
		$score_to_display = " ($score_to_display)";
	}

	if ($comment->{sid} && $comment->{cid}) {
		my $link = linkComment({
			sid	=> $comment->{sid},
			cid	=> $comment->{cid},
			subject	=> "#$comment->{cid}",
			subject_only => 1,
		}, 1, { noextra => 1 });
		$comment_link_to_display = qq| ($link)|;
	} else {
		$comment_link_to_display = " ";
	}

	if (isAnon($comment->{uid})) {
		$user_nick_to_display = strip_literal($comment->{nickname});
	} else {
		my $nick_literal = strip_literal($comment->{nickname});
		my $nick_param   = strip_paramattr($comment->{nickname});

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
		my $nofollow = '';
		if (!$comment->{karma_bonus} || $comment->{karma_bonus} eq 'no') {
			$nofollow = ' rel="nofollow"';
		}
		$userinfo_to_display = qq[<a href="$comment->{homepage}" title="$comment->{homepage}" class="user_homepage_display"$nofollow>Homepage</a>]
			if $homepage;
		if ($comment->{journal_last_entry_date} =~ /[1-9]/) {
			$userinfo_to_display .= "\n" if $userinfo_to_display;
			$userinfo_to_display .= sprintf('<a href="%s/~%s/journal/" title="%s" class="user_journal_display">Journal</a>',
				$constants->{real_rootdir},
				$nick_param,
				timeCalc($comment->{journal_last_entry_date})
			);
		}
		#$userinfo_to_display = "<br>($userinfo_to_display)" if $userinfo_to_display;

		$user_nick_to_display = qq{<a href="$constants->{real_rootdir}/~$nick_param">$nick_literal ($comment->{uid})</a>};
		if ($constants->{plugin}{Subscribe} && $constants->{subscribe}
			&& $comment->{subscriber_bonus} eq 'yes') {
			if ($constants->{plugin}{FAQSlashdot}) {
				$user_nick_to_display .= qq{ <a href="/faq/com-mod.shtml#cm2600">*</a>};
			} else {
				$user_nick_to_display .= " *";
			}
		}
		if ($comment->{fakeemail}) {
			my $mail_literal = strip_literal($comment->{fakeemail_vis});
			my $mail_param = strip_paramattr($comment->{fakeemail});
			$user_email_to_display = qq{ &lt;<a href="mailto:$mail_param">$mail_literal</a>&gt;};
		}
	}

	my $otherdetails = $options->{pieces} ? '' : <<EOT;
		$user_email_to_display
		on $time_to_display$comment_link_to_display
		<small>$userinfo_to_display $comment->{ipid_display}</small>
EOT

	# Do not display comment navigation and reply links if we are in
	# archive mode or if we are in metamod. Nicknames are always equal to
	# '-' in metamod. This logic is extremely old and could probably be
	# better formulated.
	my $commentsub = '';
	if (!$options->{noshow} && !$options->{pieces}
		&& $user->{mode} ne 'archive'
		&& $user->{mode} ne 'metamod'
		&& $comment->{nickname} ne "-") { # this last test probably useless
		my @link = ( );

		my($prefix, $a_id, $a_class, $suffix) = ('', '', '', '');
		my $is_idle = $gSkin->{name} eq 'idle';
		if ($is_idle) {
			$a_class = 'vbutton bg_666666 rd_5';
			$a_id = "reply_link_$comment->{cid}";
		} else {
			$prefix = qq'<span id="reply_link_$comment->{cid}" class="nbutton"><p><b>';
			$suffix = qq'</b></p></span>'
		}

		push @link, ($prefix . linkComment({
			a_id	=> $a_id,
			a_class	=> $a_class,
			sid	=> $comment->{sid},
			pid	=> $comment->{cid},
			op	=> 'Reply',
			subject	=> 'Reply to This',
			subject_only => 1,
			onclick	=> ($discussion2 ? "D2.replyTo($comment->{cid}); return false;" : '')
		}) . $suffix) unless $user->{state}{discussion_archived};

		if (! $is_idle) {
			$prefix = qq'<span class="nbutton"><p><b>';
		}

		push @link, ($prefix . linkComment({
			a_class	=> $a_class,
			sid	=> $comment->{sid},
			cid	=> $comment->{original_pid},
			pid	=> $comment->{original_pid},
			subject	=> 'Parent',
			subject_only => 1,
			onclick	=> ($discussion2 ? "return D2.selectParent($comment->{original_pid})" : '')
		}, 1) . $suffix) if $comment->{original_pid};

#use Data::Dumper; print STDERR "_hard_dispComment createSelect can_mod='$can_mod' disc_arch='$user->{state}{discussion_archived}' modd_arch='$constants->{comments_moddable_archived}' cid='$comment->{cid}' reasons: " . Dumper($reasons);

		push @link, qq'<div id="reasondiv_$comment->{cid}" class="modsel">' .
			createSelect("reason_$comment->{cid}", $reasons, {
				'return'	=> 1,
				nsort		=> 1, 
				onchange	=> ($discussion2 ? 'return D2.doModerate(this)' : '')
			}) . "</div>" if $can_mod
				&& ( !$user->{state}{discussion_archived}
					|| $constants->{comments_moddable_archived} );

		push @link, qq|<input type="checkbox" name="del_$comment->{cid}">|
			if $user->{is_admin};

		my $link = join(" ", @link);

		if (@link) {
			$commentsub = $link;
		}

	}

	### short-circuit
	if ($options->{show_pieces}) {
		return($otherdetails, $commentsub);
	}


	$zoosphere_display = " ";
	if ($comment->{badge_id}) {
		my $reader = getObject('Slash::DB', { db_type => 'reader' });
		my $badges = $reader->getBadgeDescriptions;
		if (my $badge = $badges->{ $comment->{badge_id} }) {
			my $badge_url   = strip_urlattr($badge->{badge_url});
			my $badge_icon  = strip_paramattr($badge->{badge_icon});
			my $badge_title = strip_attribute($badge->{badge_title});
			$zoosphere_display .= qq|<span class="badgeicon"><a href="$badge_url"><img src="$constants->{imagedir}/$badge_icon" alt="$badge_title" title="$badge_title"></a></span>|;
		}
	}
	unless ($user->{is_anon} || isAnon($comment->{uid}) || $comment->{uid} == $user->{uid}) {
		my $person = $comment->{uid};
		my $zooicon = qq|<span class="zooicon __IMG__" title="__TITLE__"><a href="$gSkin->{rootdir}/zoo.pl?op=check&amp;type=friend&amp;uid=$person" title="__TITLE__">|;
			$zooicon .= qq|__TITLE__</a></span>|;
		if (!$user->{people}{FRIEND()}{$person} && !$user->{people}{FOE()}{$person} && !$user->{people}{FAN()}{$person} && !$user->{people}{FREAK()}{$person} && !$user->{people}{FOF()}{$person} && !$user->{people}{EOF()}{$person}) {
				($zoosphere_display .= $zooicon) =~ s/__IMG__/neutral/g;
				$zoosphere_display =~ s/__TITLE__/Alter Relationship/g;
		} else {
			if ($user->{people}{FRIEND()}{$person}) {
				my $title = $user->{people}{people_bonus_friend} ? "Friend ($user->{people}{people_bonus_friend})" : "Friend";
				($zoosphere_display .= $zooicon) =~ s/__IMG__/friend/g;
				$zoosphere_display =~ s/__TITLE__/$title/g;
			}
			if ($user->{people}{FOE()}{$person}) {
				my $title = $user->{people}{people_bonus_foe} ? "Foe ($user->{people}{people_bonus_foe})" : "Foe";
				($zoosphere_display .= $zooicon) =~ s/__IMG__/foe/g;
				$zoosphere_display =~ s/__TITLE__/$title/g;
			}
			if ($user->{people}{FAN()}{$person}) {
				my $title = $user->{people}{people_bonus_fan} ? "Fan ($user->{people}{people_bonus_fan})" : "Fan";
				($zoosphere_display .= $zooicon) =~ s/__IMG__/fan/g;
				$zoosphere_display =~ s/__TITLE__/$title/g;
			}
			if ($user->{people}{FREAK()}{$person}) {
				my $title = $user->{people}{people_bonus_freak} ? "Freak ($user->{people}{people_bonus_freak})" : "Freak";
				($zoosphere_display .= $zooicon) =~ s/__IMG__/freak/g;
				$zoosphere_display =~ s/__TITLE__/$title/g;
			}
			if ($user->{people}{FOF()}{$person}) {
				my $title = $user->{people}{people_bonus_fof} ? "Friend of a Friend ($user->{people}{people_bonus_fof})" : "Friend of a Friend";
				(my $tmp = $zooicon) =~ s/__IMG__/fof/g;
				$tmp =~ s/__TITLE__/$title/g;
				$tmp =~ s/width="\d+" /width="$constants->{badge_icon_size_wide}" /g;
				$zoosphere_display .= $tmp;
			}
			if ($user->{people}{EOF()}{$person}) {
				my $title = $user->{people}{people_bonus_eof} ? "Foe of a Friend ($user->{people}{people_bonus_eof})" : "Foe of a Friend";
				(my $tmp = $zooicon) =~ s/__IMG__/eof/g;
				$tmp =~ s/__TITLE__/$title/g;
				$tmp =~ s/width="\d+" /width="$constants->{badge_icon_size_wide}" /g;
				$zoosphere_display .= $tmp;
			}
		}
	}

	my $class = $comment->{class}; 
	my $classattr = $discussion2 ? qq[ class="$class"] : '';
	my $contain = $class eq 'full' && $discussion2 ? ' contain' : '';

	my $head = $discussion2 ? <<EOT1 : <<EOT2;
			<h4><a id="comment_link_$comment->{cid}" name="comment_link_$comment->{cid}" href="$gSkin->{rootdir}/comments.pl?sid=$comment->{sid}&amp;cid=$comment->{cid}" onclick="return D2.setFocusComment($comment->{cid})">$comment->{subject}</a>
EOT1
			<h4><a name="$comment->{cid}">$comment->{subject}</a>
EOT2

	my $return = '';
	$return = <<EOT if !$options->{noshow_show};
<li id="tree_$comment->{cid}" class="comment$contain">
<div id="comment_status_$comment->{cid}" class="commentstatus"></div>
<div id="comment_$comment->{cid}"$classattr>
EOT

	my $new_old_comment = $comment->{has_read} ? 'oldcomment' : 'newcomment';

	$return .= <<EOT if !$options->{noshow};
	<div id="comment_top_$comment->{cid}" class="commentTop $new_old_comment">
		<div class="title">
$head
$comment_links
		 	<span id="comment_score_$comment->{cid}" class="score">$score_to_display</span></h4>
		</div>
		<div class="details">
			<span class="by">by $user_nick_to_display</span>$zoosphere_display
			<span class="otherdetails" id="comment_otherdetails_$comment->{cid}">$otherdetails</span>
		</div>
	</div>
	<div class="commentBody">	
		$comment_to_display
	</div>

	<div class="commentSub" id="comment_sub_$comment->{cid}">
$commentsub
EOT

	$return .= "</div>\n" if !$options->{noshow};
	$return .= "</div>\n\n" if !$options->{noshow_show};

	if ($discussion2 && !$options->{noshow_show}) {
		$return .= <<EOT;
<div id="replyto_$comment->{cid}"></div>

<ul id="group_$comment->{cid}">
	<li id="hiddens_$comment->{cid}" class="hide"></li>
</ul>

EOT
	}

	return $return;
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

	$$subj =~ s/&(#?[a-zA-Z0-9]+);?/approveCharref($1)/sge;

	for ($$comm, $$subj) {
		my $d = decode_entities($_);
		$d =~ s/&#?[a-zA-Z0-9]+;//g;	# remove entities we don't know
		if ($d !~ /\w/) {		# require SOME non-whitespace
			$$error_message = getError('no body');
			return;
		}
	}

	unless (defined($$comm = balanceTags($$comm, { deep_nesting => 1 }))) {
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

		my $check_notags = strip_nohtml($check_prefix);
		# Don't count & or other chars used in entity tags;  don't count
		# chars commonly used in ascii art.  Not that it matters much.
		# Do count chars commonly used in source code.
		my $num_chars = $check_notags =~ tr/A-Za-z0-9?!(){}[]+='"@$-//;

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

	if (	    $constants->{m1}
		&& !$user->{is_anon}
		&& !$form->{postanon}
		&& !$form->{gotmodwarning}
		&& !( $constants->{authors_unlimited}
			&& $user->{seclev} >= $constants->{authors_unlimited} )
		&& !$user->{acl}{modpoints_always}
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


########################################################
# is discussion2 active?
sub discussion2 {
	my $user = $_[0] || getCurrentUser();
	return $user->{discussion2} eq 'slashdot'
		? $user->{discussion2} : 0;
}


1;

__END__


=head1 SEE ALSO

Slash(3).

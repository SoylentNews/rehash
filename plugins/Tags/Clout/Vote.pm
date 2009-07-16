package Slash::Clout::Vote;

use strict;
use warnings;
use Date::Parse qw( str2time );
use Slash::Utility;

use base 'Slash::Clout';

our $VERSION = $Slash::Constants::VERSION;

sub init {
        my($self) = @_;

        $self->SUPER::init(@_) if $self->can('SUPER::init');

        # Hard-coded constants should be in the vars table.
        # cumfrac is the cumulative fraction of how much weight is propagated
        # for each matching tag.  E.g. if $cumfrac is 0.5, the first match may
        # propagate up to 50% of the weight, the second another 25%, the
        # third another 12.5% etc.
        $self->{cumfrac} = 0.6;
	my $constants = getCurrentStatic();
	$self->{debug_uids} = { map { ($_, 1) } split / /,
		($constants->{tags_updateclouts_debuguids} || '')
	};
	$self->{debug} = 0;
	1;
}

sub getUserClout {
	my($self, $user_stub) = @_;
	return 0 if isAnon($user_stub->{uid});
	my $clout;
	my $karma = $user_stub->{karma};
	if ($karma >= 1) {
		# Full graduated clout for positive karma.
		$clout = log($karma+5); # karma 1 clout 1.8 ; karma 50 clout 4.0
	} elsif ($karma == 0) {
		# Karma of 0 means low clout.
		$clout = 0.3;
	} elsif ($karma >= -2) {
		# Mild negative karma means extremely low clout.
		$clout = ($karma+3)*0.01;
	} else {
		# Significant negative karma means no clout.
		$clout = 0;
	}

	my $clout_mult = 1;
	if (defined($user_stub->{tag_clout})) {
		$clout_mult = $user_stub->{tag_clout};
	}
	$clout *= $clout_mult;

	my $created_at_ut;
	if (defined($user_stub->{created_at_ut})) {
		$created_at_ut = $user_stub->{created_at_ut};
	} else {
		$created_at_ut = str2time( $user_stub->{created_at} ) || 0;
	}
	my $secs_since = time - $created_at_ut;
	my $frac = $secs_since / (30*86400);
	$frac = 0.1 if $frac < 0.1;
	$frac = 1   if $frac > 1;
	$clout *= $frac;

	return $clout;
}

sub get_nextgen {
	my($self, $g) = @_;

	# Populate the firehose_ogaspt table with the necessary data.
	my $constants = getCurrentStatic();
	my $subscribe_future_secs = $constants->{subscribe_future_secs};
	my $slashdb = getCurrentDB();
	my $globj_types = $slashdb->getGlobjTypes();
	$slashdb->sqlDelete('firehose_ogaspt');
	# First, the pub dates for submissions that made it into stories.
	$slashdb->sqlDo("INSERT INTO firehose_ogaspt
		SELECT globjid, MIN(DATE_SUB(stories.time, INTERVAL $subscribe_future_secs SECOND))
			FROM stories, story_param, globjs
			WHERE stories.stoid=story_param.stoid
				AND in_trash='no'
				AND story_param.name='subid'
				AND globjs.gtid='$globj_types->{submissions}'
				AND story_param.value=globjs.target_id
				AND stories.time >= DATE_SUB(NOW(), INTERVAL $self->{months_back} MONTH)
			GROUP BY globjid");
	# Then, the same for journal entries that made it into stories.
	$slashdb->sqlDo("INSERT INTO firehose_ogaspt
		SELECT globjid, MIN(DATE_SUB(stories.time, INTERVAL $subscribe_future_secs SECOND))
			FROM stories, story_param, globjs
			WHERE stories.stoid=story_param.stoid
				AND in_trash='no'
				AND story_param.name='journal_id'
				AND globjs.gtid='$globj_types->{journals}'
				AND story_param.value=globjs.target_id
				AND stories.time >= DATE_SUB(NOW(), INTERVAL $self->{months_back} MONTH)
			GROUP BY globjid");
	# Those queries run in under a second each.  But, wait a decent
	# amount of time for them to replicate.
	sleep 10;

	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $mintagid = $reader->sqlSelect('MIN(tagid)', 'tags',
		"created_at >= DATE_SUB(NOW(), INTERVAL $self->{months_back} MONTH)");
	my $hr_ar = $reader->sqlSelectAllHashrefArray(
		"sourcetag.uid AS sourcetag_uid,
		 UNIX_TIMESTAMP(newtag.created_at)-UNIX_TIMESTAMP(sourcetag.created_at)
			AS timediff,
		 UNIX_TIMESTAMP(sourcetag.created_at) AS sourcetag_created_at_ut,
		 UNIX_TIMESTAMP(newtag.created_at) AS newtag_created_at_ut,
		 IF(newtag.inactivated IS NULL,
			-1,
			UNIX_TIMESTAMP(newtag.inactivated)-UNIX_TIMESTAMP(newtag.created_at))
			AS duration,
		 newtag.uid AS newtag_uid,
		 simil,
		 users_info.tag_clout,
		 IF(firehose_ogaspt.pubtime IS NULL,
			NULL,
			UNIX_TIMESTAMP(firehose_ogaspt.pubtime)-UNIX_TIMESTAMP(newtag.created_at))
			AS timebeforepub,
		 seclev,
		 karma, tokens, UNIX_TIMESTAMP(users_info.created_at) AS created_at_ut,
		 sourcetag.tagnameid AS sourcetag_tagnameid,
		 newtag.tagnameid AS newtag_tagnameid,
		 sourcetag.globjid,
		 gtid",
		"tags AS sourcetag LEFT JOIN firehose_ogaspt USING (globjid),
		 tags_peerclout AS sourcetpc,
		 users, users_info,
		 tagnames_similar, globjs,
		 tags AS newtag LEFT JOIN tags_peerclout AS newtpc USING (uid)",
		"sourcetag.inactivated IS NULL
		 AND sourcetag.uid=sourcetpc.uid
		 AND sourcetag.globjid=globjs.globjid
		 AND sourcetag.globjid=newtag.globjid
			 AND tagnames_similar.type = 2
			 AND sourcetag.tagnameid=tagnames_similar.src_tnid
			 AND tagnames_similar.dest_tnid=newtag.tagnameid
		 AND simil != 0
		 AND sourcetag.tagid >= $mintagid
		 AND sourcetag.tagid != newtag.tagid
		 AND newtag.tagid >= $mintagid
		 AND newtag.uid=users.uid
		 AND newtag.uid=users_info.uid
		 AND newtpc.uid IS NULL
		 AND sourcetpc.gen=$g
		 AND sourcetpc.clid=$self->{clid}",
		"ORDER BY newtag.tagid");
	return $hr_ar;
}

sub process_nextgen {
	my($self, $hr_ar, $tags_peerclout) = @_;

	$self->count_uid_nodnix($hr_ar);

	my %newtag_uid = ( map { $_->{newtag_uid}, 1 } @$hr_ar );
	my @newtag_uid = sort { $a <=> $b } keys %newtag_uid;
	my $user_nodnixes_min = 3;
	my $user_nodnixes_full = 60;

	my $insert_ar = [ ];
	my $i = 0;
	for my $newtag_uid (@newtag_uid) {
		my $start_time = Time::HiRes::time;
		my $user_nodnixes_count = ($self->{nodc}{$newtag_uid} || 0) + ($self->{nixc}{$newtag_uid} || 0);
		my $user_nodnixes_mult = 0;
		if ($user_nodnixes_count >= $user_nodnixes_full) {
			$user_nodnixes_mult = 1;
		} elsif ($user_nodnixes_count >= $user_nodnixes_min) {
			$user_nodnixes_mult = ($user_nodnixes_count+1-$user_nodnixes_min) /
				($user_nodnixes_full+1-$user_nodnixes_min);
		}
		if ($self->{debug_uids}{$newtag_uid}) {
			print STDERR sprintf("%s tags_updateclouts %s process_nextgen starting uid=%d user_nodnixes_count=%d _mult=%.6f\n",
				scalar(gmtime), ref($self), $newtag_uid, $user_nodnixes_count, $user_nodnixes_mult);
			++$self->{debug};
		}

		my $peer_weight = 0;
		my(@match, $tag_clout, $created_at, $karma, $tokens, $uid_mults);
		@match = grep { $_->{newtag_uid} == $newtag_uid } @$hr_ar;
		my $match0 = $match[0];
		if ($user_nodnixes_mult > 0) {
			($tag_clout, $created_at, $karma, $tokens) =
				($match0->{tag_clout}, $match0->{created_at_ut}, $match0->{karma}, $match0->{tokens});
			$uid_mults = $self->get_mults(\@match);
			$uid_mults->{'-1'} = $self->get_mult_timebeforepub(\@match);
			$peer_weight = $self->get_total_weight($tags_peerclout, $uid_mults,
				$tag_clout, $created_at, $karma, $tokens, $newtag_uid)
				* $user_nodnixes_mult;
		}

		my $base_weight = $self->getUserClout($match0);

		my $total_weight = $peer_weight + $base_weight;

		push @$insert_ar, {
			uid =>		$newtag_uid,
			clout =>	$total_weight,
		};
		my $elapsed = Time::HiRes::time - $start_time;

		if ($self->{debug}) {
			use Data::Dumper; my $umd = Dumper($uid_mults); $umd =~ s/\s+/ /g;
			print STDERR sprintf("%s tags_updateclouts %s process_nextgen uid=%d peer_weight=%.6f base_=%.6f total_weight=%.6f in %.6f secs, mults: %s\n",
				scalar(gmtime), ref($self), $newtag_uid,
                                $peer_weight, $base_weight, $total_weight,
                                $elapsed, $umd);
		}
		++$i;
		if ($i % 100 == 0 || $self->{debug}) {
			print STDERR sprintf("%s tags_updateclouts %s process_nextgen processed %d uid=%d matched=%d in %.6f secs\n",
				scalar(gmtime), ref($self), $i, $newtag_uid, scalar(@match), $elapsed);
		}
		if ($self->{debug_uids}{$newtag_uid}) {
			print STDERR sprintf("%s tags_updateclouts %s process_nextgen done uid=%d\n",
				scalar(gmtime), ref($self), $newtag_uid);
			--$self->{debug};
		}
		Time::HiRes::sleep(0.01);
	}

	return $insert_ar;
}

sub count_uid_nodnix {
	my($self, $hr_ar) = @_;
	$self->{nodc} = $self->{nixc} = { };
	my %uid_needed = ( );
	for my $hr (@$hr_ar) {
		my $uid = $hr->{sourcetag_uid};
		$uid_needed{$uid} = 1 if !exists $self->{nodc}{$uid};
		$uid = $hr->{newtag_uid};
		$uid_needed{$uid} = 1 if !exists $self->{nodc}{$uid};
	}
	return unless keys %uid_needed;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my @uids_needed = sort { $a <=> $b } keys %uid_needed;
	my $splice_count = 20;
	while (@uids_needed) {
		my @uid_chunk = splice @uids_needed, 0, $splice_count;
		my $uid_str = join(",", @uid_chunk);
		my $nod_hr = $reader->sqlSelectAllKeyValue(
			'uid, COUNT(*)',
			'tags',
			"tagnameid='$self->{nodid}' AND uid IN ($uid_str)
			 AND created_at >= DATE_SUB(NOW(), INTERVAL $self->{months_back} MONTH)",
			'GROUP BY uid');
		my $nix_hr = $reader->sqlSelectAllKeyValue(
			'uid, COUNT(*)',
			'tags',
			"tagnameid='$self->{nixid}' AND uid IN ($uid_str)
			 AND created_at >= DATE_SUB(NOW(), INTERVAL $self->{months_back} MONTH)",
			'GROUP BY uid');
		if (grep { $self->{debug_uids}{$_} } @uid_chunk) {
			my $nod_d = Dumper($nod_hr); $nod_d =~ s/\s+/ /g;
			my $nix_d = Dumper($nix_hr); $nix_d =~ s/\s+/ /g;
			print STDERR sprintf("%s tags_updateclouts %s count_uid_nodnix splice nod_d=%s nix_d=%s\n",
				scalar(gmtime), ref($self),
				$nod_d, $nix_d);
		}
		for my $uid (@uid_chunk) {
			$self->{nodc}{$uid} = $nod_hr->{$uid} || 0;
			$self->{nixc}{$uid} = $nix_hr->{$uid} || 0;
			if ($self->{debug_uids}{$uid}) {
				print STDERR sprintf("%s tags_updateclouts %s count_uid_nodnix uid=%d nod=%s nix=%s nodc=%s nixc=%s\n",
					scalar(gmtime), ref($self), $uid,
					$nod_hr->{$uid}, $nix_hr->{$uid},
					$self->{nodc}{$uid}, $self->{nixc}{$uid});
			}
		}
		sleep 1 if @uids_needed;
	}
}

sub get_mults {
	my($self, $match_ar) = @_;

	my $uid_mults = { };
	for my $hr (@$match_ar) {
		my $mult = $self->get_mult($hr);
		$uid_mults->{ $hr->{sourcetag_uid} } ||= [ ];
		push @{$uid_mults->{ $hr->{sourcetag_uid} }}, $mult;
	}
	return $uid_mults;
}

sub get_mult {
	my($self, $hr) = @_;

	my $mult = $hr->{simil};
	my $slashdb = getCurrentDB();
	my $globj_types = $slashdb->getGlobjTypes();

	# If this tag-match is too old, it earns the new user less credit.
	my $older_tag = $hr->{sourcetag_created_at_ut};
	$older_tag = $hr->{newtag_created_at_ut} if $hr->{newtag_created_at_ut} < $older_tag;
	my $tag_age = time - $older_tag;
	my $max_days = $self->{months_back} * 30 + 1;
	if ($tag_age < 7 * 86400) {
		# tags within the past week get full credit
	} elsif ($tag_age < 30 * 86400) {
		# tags up to a month old get almost full credit
		$mult *= 0.8 + ($tag_age -  7*86400)*0.2 / (30       *86400 - 7*86400);
	} elsif ($tag_age < $max_days * 86400) {
		# credit falls off linearly from there to the max time
		$mult *= 0.0 + ($tag_age - 30*86400)*0.8 / ($max_days*86400 -30*86400);
	} else {
		$mult  = 0;
	}

	# If the new user's tag was not active for very long, they get no credit.
	# XXX need to check here whether the opposite is in the list, and if
	# so, also no credit.
	if ($hr->{duration} < 0) {
		# duration of -1 means never inactivated, so full credit.
	} elsif ($hr->{duration} > 3600) {
		$mult *= 0.1;
	} else {
		$mult = 0;
	}

	# If the new user's tag came before the source user, they get full
	# credit;  too far after the source user, they get reduced credit.
	if ($hr->{timediff} < -3600) {
		$mult *= 1.0;
	} elsif ($hr->{timediff} < 0) {
		$mult *= 0.9;
	} elsif ($hr->{timediff} < 300) {
		$mult *= 0.2;
	} elsif ($hr->{timediff} < 900) {
		$mult *= 0.1;
	} elsif ($hr->{timediff} < 3600) {
		$mult *= 0.05;
	} else {
		$mult *= 0.01;
	}

	# Tagging different types gets different mults.
	my $type = $globj_types->{ $hr->{gtid} };
	if ($type eq 'comments') {
		# fair bit of credit for matching mods on comments
		# XXX may need to adjust this if it turns out that we're
		# assigning most of our weight via comment mods
		$mult *= 0.6;
	} else {
		# full credit for other stuff (mostly nod/nix on firehose
		# items)
	}

	# If this is a nod-nix (dis)agreement, weight by the source and
	# new users' ratios of nod/nix. Agreement or disagreement on a
	# rare choice (for either user) is considered more indicative.
	my($su,  $nu)  = ($hr->{sourcetag_uid},       $hr->{newtag_uid});
	my($stn, $ntn) = ($hr->{sourcetag_tagnameid}, $hr->{newtag_tagnameid});
	my($nodid, $nixid) = ($self->{nodid}, $self->{nixid});
	if (    ( $stn == $nodid || $stn == $nixid )
	&&      ( $ntn == $nodid || $ntn == $nixid ) ) {
		my($su, $nu) = ($hr->{sourcetag_uid}, $hr->{newtag_uid});
		my $snod = $self->{nodc}{$su};
		my $snix = $self->{nixc}{$su};
		my $nnod = $self->{nodc}{$nu};
		my $nnix = $self->{nixc}{$nu};
		my $sfrac = ($stn == $nodid ? $snix : $snod) / ($snod+$snix+1);
		my $nfrac = ($ntn == $nodid ? $nnix : $nnod) / ($nnod+$nnix+1);
		if ($self->{debug}) {
			print STDERR sprintf("%s tags_updateclouts %s get_mult su=%d nu=%d sfrac=%.6f nfrac=%.6f\n",
				scalar(gmtime), ref($self), $su, $nu, $sfrac, $nfrac);
		}
		$mult *= $sfrac * $nfrac;
	}
	if ($self->{debug}) {
		print STDERR sprintf("%s tags_updateclouts %s get_mult returning %.6f\n",
			scalar(gmtime), ref($self), $mult);
	}

	return $mult;
}

sub get_mult_timebeforepub {
	my($self, $match_ar) = @_;
	
	my $tbp_mults = [ ];
	for my $hr (@$match_ar) {
		next unless $hr->{duration} == -1 && defined $hr->{timebeforepub};
		my $nodnix;
		if ($hr->{sourcetag_tagnameid} == $self->{nodid}) {
			$nodnix = 1;
		} elsif ($hr->{sourcetag_tagnameid} == $self->{nixid}) {
			$nodnix = -1;
		} else {
			next;
		}
		my $tbp = $hr->{timebeforepub};
		if ($tbp < 0) { 
			next; # no credit for nodding stories after they are published
		} elsif ($tbp < 600) {
			# 0.1 credits for nodding stories up to 10 minutes before pub
			push @$tbp_mults, $nodnix * 0.1;
		} elsif ($tbp < 36000) {
			# between 10 minutes and 4 hours, partial credit
			# XXX yes this really should be tweaked
			push @$tbp_mults, $nodnix * (0.1 + ($tbp-600)*0.9/((3600*4)-600));
		} else {
			# more than 4 hours, full credit
			push @$tbp_mults, $nodnix * 1.0;
		}
	}
	return $tbp_mults;
}

sub get_total_weight {
		# uid_mults is a hashref where the key is the source uid and
		# the value is an arrayref of mults from that uid
	my($self, $tags_peerclout, $uid_mults,
		$clout, $created_at, $karma, $tokens, $new_uid) = @_;
		
	return 0 if $clout == 0 || $tokens < -1000 || $karma < -10;

	my $constants = getCurrentStatic();
	my $any_weight = 0; 
	my @total_mults = ( );
		
	# Start by treating the "-1" uid separately.  That's the uid for
	# tags that were applied to a firehose item that got posted as
	# a story.  The fact of story-posting is handled separately from
	# correlations with other users' tags.
	if ($uid_mults->{'-1'}) {
		if (@{$uid_mults->{'-1'}}) {
			my @balanced = $self->balance_weight_vectors(@{$uid_mults->{'-1'}});
			my $m = $constants->{tags_tagpeerval_postingbonus}
				* $self->sum_weight_vectors(@balanced);
			push @total_mults, $m;
			$any_weight = 1;
			if ($self->{debug}) {
				print STDERR sprintf("%s tags_updateclouts %s get_total_weight uid=%d balance_weight_vectors(-1)=%.6f\n",
					scalar(gmtime), ref($self), $new_uid, $m);
			}
		}
		delete $uid_mults->{'-1'};
	}
	
	# Start by sorting source uids by decreasing weight.
	my @nodef = grep { !defined $tags_peerclout->{$_} } keys %$uid_mults; $#nodef = 20 if $#nodef > 20;
	print STDERR sprintf("%s tags_updateclouts %s get_total_weight for uid=%d nodef: '%s'\n",
		scalar(gmtime), ref($self), $new_uid, join(' ', @nodef))
		if @nodef;
	my @source_uids = sort { $tags_peerclout->{$b} <=> $tags_peerclout->{$a} } keys %$uid_mults;

	# If all source uids have weight 0, we know the answer quickly.
	for my $uid (@source_uids) {
		if ($tags_peerclout->{$uid} > 0) {
			$any_weight = 1;
			last;
		}
	}
	if ($self->{debug}) {
		my $src_count = scalar(@source_uids);
		my @src_abridged = @source_uids;
		$#src_abridged = 19 if $#src_abridged >= 19;
		my $src_min = $uid_mults->{ $src_abridged[-1] };
		my $src_max = $uid_mults->{ $src_abridged[ 0] };
		my $abridged_str = join(' ', @src_abridged);
		print STDERR sprintf("%s tags_updateclouts %s get_total_weight uid=%d any_weight=%d count=%d min=%.6f max=%.6f uids: '%d'\n",
			scalar(gmtime), ref($self), $new_uid, $any_weight,
			$src_count, $src_min, $src_max, $abridged_str);
	}
	return 0 if !$any_weight;

	# Get the mult for each of those
	for my $uid (@source_uids) {
		my @balanced = $self->balance_weight_vectors(@{$uid_mults->{$uid}});
		my $m = $tags_peerclout->{$uid} * $self->sum_weight_vectors(@balanced);
		push @total_mults, $m;
		if ($self->{debug}) {
			print STDERR sprintf("%s tags_updateclouts %s get_total_weight uid=%d source_uid=%d (clout %.6f) mult: %.6f for balanced: %s\n",
				scalar(gmtime), ref($self), $new_uid, $uid, $m,
				join(' ', map { sprintf("%.6f", $_) } @balanced));
		}
	}

	# Then (using the same decreasing-multipliers algorithm) get the
	# total of all those mults.
	my @balanced = $self->balance_weight_vectors(@total_mults);
	my $total = $self->sum_weight_vectors(@balanced);
	if ($self->{debug}) {
		print STDERR sprintf("%s tags_updateclouts %s get_total_weight uid=%d initial total=%.6f\n",
			scalar(gmtime), ref($self), $new_uid, $total);
	}
	
	# If this user was created recently, less weight for them.
	my $daysold = (time - $created_at)/86400;
	if ($daysold < 30) {
		$total *= 0.05 * $daysold/30;
	} elsif ($daysold < 90) {
		$total *= 0.3  * $daysold/90;
	} elsif ($daysold < 180) {
		$total *=        $daysold/180;
	}
	
	# If the user has low tokens, less weight for them.
	if ($tokens < -100) {
		$total *= 0.05 * ($tokens+1000)/1000;
	} elsif ($tokens < -10) {
		$total *= 0.6  * ($tokens+100) /100;
	}
	
	# If the user has low karma, less weight for them.
	if ($karma <= 0) {
		$total *= 0.1  * ($karma+10)/10;
	} elsif ($karma < 3) {
		$total *= 0.1;
	} elsif ($karma < 12) {
		$total *= 0.7  * ($karma- 3)/(12- 3);
	} elsif ($karma < 30) {
		$total *= 0.9  * ($karma-12)/(30-12);
	}
	
	# If the user has low clout, less weight for them.
	$total *= $clout;

	if ($self->{debug}) {
		print STDERR sprintf("%s tags_updateclouts %s get_total_weight uid=%d final total=%.6f\n",
			scalar(gmtime), ref($self), $new_uid, $total);
	}
	
	# If the result is _very_ low, just count it as 0 (this may allow
	# optimizations later).
	$total = 0 if $total < 0.00001;
	
	return $total;
}

sub balance_weight_vectors {
	my($self, @w) = @_;
	@w = sort { abs($b) <=> abs($a) || $b > $a } @w;
	my $w_pos_mag = 0; for my $w (@w) { $w_pos_mag += $w if $w > 0 };
	my $w_neg_mag = 0; for my $w (@w) { $w_neg_mag -= $w if $w < 0 };
	return @w if !$w_pos_mag && !$w_neg_mag;

	my @ret;
	# Swinging more than 60-40% one way or the other reduces the
	# minority's values.
	my $total = $w_pos_mag+$w_neg_mag;
	if ($w_pos_mag > $total * 0.60) {
		my $neg_reduc_factor = $w_neg_mag*3/$w_pos_mag;
		@ret = map { $_ < 0 ? $_*$neg_reduc_factor : $_ } @w;
	} elsif ($w_neg_mag > $total * 0.60) {
		my $pos_reduc_factor = $w_pos_mag*3/$w_neg_mag;
		@ret = map { $_ > 0 ? $_*$pos_reduc_factor : $_ } @w;
	} else {
		# No change.
		@ret = @w;
	}
	if ($self->{debug} || $w_pos_mag > 10_000 || $w_neg_mag > 10_000) {
		my @w2 = @w;   $#w2 = 4 if $#w2 > 4;
		my @r2 = @ret; $#r2 = 4 if $#r2 > 4;
		print STDERR sprintf("%s tags_updateclouts %s balance_weight_vectors posmag=%0.5g negmag=%0.5g from '%s' to '%s'\n",
			scalar(gmtime), ref($self), $w_pos_mag, $w_neg_mag,
			join(' ', map { sprintf("%.6f", $_) } @w2),
			join(' ', map { sprintf("%.6f", $_) } @r2));
	}
	return @ret;
}

sub sum_weight_vectors {
	my($self, @v) = @_;
	my @w = sort { abs($b) <=> abs($a) || $b > $a } @v;
	$#w = 50 if $#w > 50; # beyond this point contributions are tiny
	my $weight = 0;
	my $cur_magnitude = 1;
	for my $w (@w) {
		$cur_magnitude *= $self->{cumfrac};
		$weight += $cur_magnitude * $w;
	}
	$weight = 0 if $weight < 0;
	if ($self->{debug}) {
		print STDERR sprintf("%s tags_updateclouts %s sum_weight_vectors weight=%.6f w='%s'\n",
			scalar(gmtime), ref($self), $weight, join(' ', map { sprintf("%.6f", $_) } @w));
	}
	return $weight;
}

sub update_tags_peerclout {
	my($self, $insert_ar, $tags_peerclout) = @_;
	for my $hr (@$insert_ar) {
		$tags_peerclout->{ $hr->{uid} } = $hr->{clout};
	}
}

sub copy_peerclout_sql {
	my($self) = @_;
	my $slashdb = getCurrentDB();
	$slashdb->sqlDo("SET AUTOCOMMIT=0");
        $slashdb->sqlDo("UPDATE users_clout SET clout=NULL WHERE clid='$self->{clid}'");
        $slashdb->sqlDo("REPLACE INTO users_clout (clout_id, uid, clid, clout) SELECT NULL, uid, '$self->{clid}', clout FROM tags_peerclout WHERE clid='$self->{clid}'");
	$slashdb->sqlDo("COMMIT");
	$slashdb->sqlDo("SET AUTOCOMMIT=1");
}

1;


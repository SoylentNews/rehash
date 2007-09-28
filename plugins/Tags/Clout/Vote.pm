package Slash::Clout::Vote;

use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

my $cumfrac = 0.45;
my $months_back = 4;
my $clid = 2;

sub getUserClout {
	my($class, $user_stub) = @_;
	my $clout = $user_stub->{karma} >= -3
		? log($user_stub->{karma}+10)/50
		: 0;
	$clout *= $user_stub->{tag_clout};
	my $secs_since = time - $user_stub->{created_at_ut};
	my $frac = $secs_since / 120*86400;
	$frac = 0.1 if $frac < 0.1;
	$frac = 1   if $frac > 1;
	$clout *= $frac;
	return $clout;
}

sub get_nextgen {
	my($class, $g) = @_;

	# Populate the firehose_ogaspt table with the necessary data.
	my $constants = getCurrentStatic();
	my $subscribe_future_secs = $constants->{subscribe_future_secs};
	my $slashdb = getCurrentDB();
	$slashdb->sqlDelete('firehose_ogaspt');
	# First, the pub dates for submissions that made it into stories.
	$slashdb->sqlDo("INSERT INTO firehose_ogaspt
		SELECT globjid, MIN(DATE_SUB(stories.time, INTERVAL $subscribe_future_secs SECOND))
			FROM stories, story_param, globjs
			WHERE stories.stoid=story_param.stoid
				AND in_trash='no'
				AND story_param.name='subid'
				AND globjs.gtid='$globjtypes->{submissions}'
				AND story_param.value=globjs.target_id
				AND stories.time >= DATE_SUB(NOW(), INTERVAL $months_back MONTH)
			GROUP BY globjid");
	# Then, the same for journal entries that made it into stories.
	$slashdb->sqlDo("INSERT INTO firehose_ogaspt
		SELECT globjid, MIN(DATE_SUB(stories.time, INTERVAL $subscribe_future_secs SECOND))
			FROM stories, story_param, globjs
			WHERE stories.stoid=story_param.stoid
				AND in_trash='no'
				AND story_param.name='journal_id'
				AND globjs.gtid='$globjtypes->{journals}'
				AND story_param.value=globjs.target_id
				AND stories.time >= DATE_SUB(NOW(), INTERVAL $months_back MONTH)
			GROUP BY globjid");
	# Those queries run in under a second each.  But, wait a decent
	# amount of time for them to replicate.
	sleep 10;

	my $reader = getObject('Slash::DB', { db_type => 'reader' });
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
		 users_info.tag_clout AS clout,
		 UNIX_TIMESTAMP(users_info.created_at) AS created_at_ut,
		 IF(firehose_ogaspt.pubtime IS NULL,
			NULL,
			UNIX_TIMESTAMP(firehose_ogaspt.pubtime)-UNIX_TIMESTAMP(newtag.created_at))
			AS timebeforepub,
		 karma, tokens,
		 sourcetag.tagnameid AS sourcetag_tagnameid,
		 newtag.tagnameid AS newtag_tagnameid,
		 sourcetag.globjid,
		 gtid",
		"tags AS sourcetag LEFT JOIN firehose_ogaspt USING (globjid),
		 tags_peerclout AS sourcetpc, users_info,
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
		 AND sourcetag.tagid != newtag.tagid
		 AND newtag.created_at >= DATE_SUB(NOW(), INTERVAL $months_back MONTH)
		 AND newtag.uid=users_info.uid
		 AND newtpc.uid IS NULL
		 AND sourcetpc.gen=$g",
		"ORDER BY newtag.tagid");
	return $hr_ar;
}

sub process_nextgen {
	my($class, $hr_ar) = @_;
	my %newtag_uid = ( map { $_->{newtag_uid}, 1 } @$hr_ar );
	my @newtag_uid = sort { $a <=> $b } keys %newtag_uid;
	my $user_nodnixes_min = 3;
	my $user_nodnixes_full = 60;

	my $insert_ar = [ ];
	my $i = 0;
	for my $newtag_uid (@newtag_uid) {
		my $user_nodnixes_count = $nodc->{$newtag_uid} + $nixc->{$newtag_uid};
		my $user_nodnixes_mult = 0;
		if ($user_nodnixes_count >= $user_nodnixes_full) {
			$user_nodnixes_mult = 1;
		} elsif ($user_nodnixes_count >= $user_nodnixes_min) {
			$user_nodnixes_mult = ($user_nodnixes_count+1-$user_nodnixes_min)
				/ ($user_nodnixes_full+1-$user_nodnixes_min);
		}
		my $weight = 0;
		my(@match, $clout, $created_at, $karma, $tokens, $uid_mults);
		if ($debug_uids->{$newtag_uid}) {
			slashdLog("$class starting uid=%d user_nodnixes_mult=%.3f", $newtag_uid, $user_nodnixes_mult);
		}
		if ($user_nodnixes_mult > 0) {
			@match = grep { $_->{newtag_uid} == $newtag_uid } @$hr_ar;
			my $match0 = $match[0];
			($clout, $created_at, $karma, $tokens) =
				($match0->{clout}, $match0->{created_at_ut}, $match0->{karma}, $match0->{tokens});
			$uid_mults = $class->get_mults(\@match);
			$uid_mults->{'-1'} = $class->get_mult_timebeforepub(\@match);
			$weight = $class->get_total_weight($uid_mults, $clout, $created_at, $karma, $tokens)
				* $user_nodnixes_mult;
		}
		push @$insert_ar, {
			uid =>		$newtag_uid,
			clout =>	$weight,
		};
		if ($debug_uids->{$newtag_uid}) {
			$debug = 1;
			slashdLog(sprintf("$class uid=%d user_nodnixes_mult=%.3f weight=%.6f mults: %s",
				$newtag_uid, $user_nodnixes_mult,
				$class->get_total_weight($uid_mults, $clout, $created_at, $karma, $tokens),
				Dumper($uid_mults)));
			$debug = 0;
		}
		++$i;
		if ($i % 1000 == 0) {
			slashdLog("$class process_nextgen processed $i (uid $newtag_uid, matched " . scalar(@match) . ")");
		}
		Time::HiRes::sleep(0.01);
	}

	return $insert_ar;
}

sub count_uid_nodnix {
	my($class, $hr_ar) = @_;
	my %uid_needed = ( );
	for my $hr (@$hr_ar) {
		my $uid = $hr->{sourcetag_uid};
		$uid_needed{$uid} = 1 if !exists $nodc->{$uid};
		$uid = $hr->{newtag_uid};
		$uid_needed{$uid} = 1 if !exists $nodc->{$uid};
	}
	return unless keys %uid_needed;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my @uids_needed = sort { $a <=> $b } keys %uid_needed;
	my $splice_count = 2000;
	while (@uids_needed) {
		my @uid_chunk = splice @uids_needed, 0, $splice_count;
		my $uid_str = join(",", @uid_chunk);
		my $nod_hr = $reader->sqlSelectAllKeyValue(
			'uid, COUNT(*)',
			'tags',
			"tagnameid='$tagnameid->{nod}' AND uid IN ($uid_str)
			 AND created_at >= DATE_SUB(NOW(), INTERVAL $months_back MONTH)",
			'GROUP BY uid');
		my $nix_hr = $reader->sqlSelectAllKeyValue(
			'uid, COUNT(*)',
			'tags',
			"tagnameid='$tagnameid->{nix}' AND uid IN ($uid_str)
			 AND created_at >= DATE_SUB(NOW(), INTERVAL $months_back MONTH)",
			'GROUP BY uid');
		for my $uid (@uid_chunk) {
			$nodc->{$uid} = $nod_hr->{$uid} || 0;
			$nixc->{$uid} = $nix_hr->{$uid} || 0;
		}
		sleep 1 if @uids_needed;
	}
}

sub get_mults {
	my($class, $match_ar) = @_;

	my $uid_mults = { };
	for my $hr (@$match_ar) {
		my $mult = $class->get_mult($hr);
		$uid_mults->{ $hr->{sourcetag_uid} } ||= [ ];
		push @{$uid_mults->{ $hr->{sourcetag_uid} }}, $mult;
	}
	return $uid_mults;
}

sub get_mult {
	my($class, $hr) = @_;

	my $mult = $hr->{simil};

	# If this tag-match is too old, it earns the new user less credit.
	my $older_tag = $hr->{sourcetag_created_at_ut};
	$older_tag = $hr->{newtag_created_at_ut} if $hr->{newtag_created_at_ut} < $older_tag;
	my $tag_age = time - $older_tag;
	my $max_days = $months_back * 30 + 1;
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
	my $type = $globjtypes->{ $hr->{gtid} };
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
	my($nodid, $nixid) = ($stn == $tagnameid->{nod}, $stn == $tagnameid->{nix});
	if (    ( $stn == $nodid || $stn == $nixid )
	&&      ( $ntn == $nodid || $ntn == $nixid ) ) {
		my($su, $nu) = ($hr->{sourcetag_uid}, $hr->{newtag_uid});
		my $snod = $nodc->{$su};
		my $snix = $nixc->{$su};
		my $nnod = $nodc->{$nu};
		my $nnix = $nixc->{$nu};
		my $sfrac = ($stn == $nodid ? $snix : $snod) / ($snod+$snix+1);
		my $nfrac = ($ntn == $nodid ? $nnix : $nnod) / ($nnod+$nnix+1);
		if ($debug) {
			slashdLog("$class get_mult su='$su' nu='$nu' sfrac='$sfrac' nfrac='$nfrac'");
		}
		$mult *= $sfrac * $nfrac;
	}

	return $mult;
}

sub get_mult_timebeforepub {
	my($class, $match_ar) = @_;
	
	my $tbp_mults = [ ];
	for my $hr (@$match_ar) {
		next unless $hr->{duration} == -1 && defined $hr->{timebeforepub};
		my $nodnix;
		if ($hr->{sourcetag_tagnameid} == $tagnameid->{nod}) {
			$nodnix = 1;
		} elsif ($hr->{sourcetag_tagnameid} == $tagnameid->{nix}) {
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
	my($class, $uid_mults, $clout, $created_at, $karma, $tokens) = @_;
		
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
			my @balanced = $class->balance_weight_vectors(@{$uid_mults->{'-1'}});
			push @total_mults, $constants->{tags_tagpeerval_postingbonus}
				* $class->sum_weight_vectors(@balanced);
			$any_weight = 1;
		}
		delete $uid_mults->{'-1'};
	}
	
	# Start by sorting source uids by decreasing weight.
	my @source_uids = sort { $tags_peerweight->{$b} <=> $tags_peerweight->{$a} } keys %$uid_mults;

	# If all source uids have weight 0, we know the answer quickly.
	for my $uid (@source_uids) {
		if ($tags_peerweight->{$uid} > 0) {
			$any_weight = 1;
			last;
		}
	}
	return 0 if !$any_weight;

	# Get the mult for each of those
	for my $uid (@source_uids) {
		my @balanced = $class->balance_weight_vectors(@{$uid_mults->{$uid}});
		push @total_mults, $tags_peerweight->{$uid} * $class->sum_weight_vectors(@balanced);
		if ($debug) {
			my @t2 = map { sprintf("%.5g", @_) } @total_mults;
			slashdLog("$class source_uid=$uid ($tags_peerweight->{$uid}) total_mults='@t2'");
		}
	}

	# Then (using the same decreasing-multipliers algorithm) get the
	# total of all those mults.
	my @balanced = $class->balance_weight_vectors(@total_mults);
	my $total = $class->sum_weight_vectors(@balanced);
	if ($debug) {
		slashdLog("$class total=$total");
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
	
	# If the result is _very_ low, just count it as 0 (this may allow
	# optimizations later).
	$total = 0 if $total < 0.00001;
	
	return $total;
}

sub balance_weight_vectors {
	my $class = shift @_;
	my @w = sort { abs($b) <=> abs($a) || $b > $a } @_;
	my $w_pos_mag = 0; for my $w (@w) { $w_pos_mag += $w if $w > 0 };
	my $w_neg_mag = 0; for my $w (@w) { $w_neg_mag -= $w if $w < 0 };
	return @_ if !$w_pos_mag && !$w_neg_mag;

	my @ret;
	# Swinging more than 60-40% one way or the other reduces the
	# minority's values.
	my $total = $w_pos_mag+$w_neg_mag;
	if ($w_pos_mag > $total * 0.60) {
		my $neg_reduc_factor = $w_neg_mag*3/$w_pos_mag;
		@ret = map { $_ < 0 ? $_*$neg_reduc_factor : $_ } @_;
	} elsif ($w_neg_mag > $total * 0.60) {
		my $pos_reduc_factor = $w_pos_mag*3/$w_neg_mag;
		@ret = map { $_ > 0 ? $_*$pos_reduc_factor : $_ } @_;
	} else {
		# No change.
		@ret = @_;
	}
	if ($debug) {
		my @w2 = map { sprintf("%5d", @_) } @w;   $#w2 = 4 if $#w2 > 4;
		my @r2 = map { sprintf("%5d", @_) } @ret; $#r2 = 4 if $#r2 > 4;
		slashdLog(sprintf("$class balance_weight_vectors pos=%.5g neg=%.5g from '%s' to '%s'",
			$w_pos_mag, $w_neg_mag, join(' ', @w2), join(' ', @r2)));
	}
	return @ret;
}

sub sum_weight_vectors {
	my $class = shift @_;
	my @w = sort { abs($b) <=> abs($a) || $b > $a } @_;
	$#w = 50 if $#w > 50; # beyond this point contributions are tiny
	my $weight = 0;
	my $cur_magnitude = 1;
	for my $w (@w) {
		$cur_magnitude *= $cumfrac;
		$weight += $cur_magnitude * $w;
	}
	$weight = 0 if $weight < 0;
	if ($debug) {
		slashdLog("$class sum_weight_vectors weight='$weight' w='@w'");
	}
	return $weight;
}

sub insert_nextgen {
	my($class, $g, $insert_ar) = @_;
	my $slashdb = getCurrentDB();
	# XXX Should turn off autocommit for this loop
	for my $hr (@$insert_ar) {
		$hr->{gen} = $g;
		$slashdb->sqlInsert('tags_peerclout', $hr);
	}
}

sub update_tags_peerclout {
	my($class, $insert_ar) = @_;
	for my $hr (@$insert_ar) {
		$tags_peerclout->{ $hr->{uid} } = $hr->{clout};
	}
}

sub copy_peerweight_sql {
	my($class) = $_;
	my $slashdb = getCurrentDB();
	$slashdb->sqlDo("SET AUTOCOMMIT=0");
        $slashdb->sqlDo("UPDATE users_clout SET clout=NULL WHERE clid='$clid'");
        $slashdb->sqlDo("INSERT INTO users_clout (clout_id, uid, clid, clout) SELECT NULL, uid, '$clid', clout FROM tags_peerclout WHERE clid='$clid'");
	$slashdb->sqlDo("COMMIT");
	$slashdb->sqlDo("SET AUTOCOMMIT=1");
}

1;


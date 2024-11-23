#!/usr/bin/perl -w

use strict;
use warnings;
use utf8;
use JSON;
use Slash;
use Slash::Utility;
use Slash::Constants qw(:web :messages);
use Data::Dumper;
use Encode qw(_utf8_on);

sub main {
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $gSkin     = getCurrentSkin();

	# lc just in case
	my $endpoint = lc($form->{m});

	my $endpoints = {
		
		admin		=> {
			function	=> \&admin,
			seclev		=> 0,
		},
		user		=> {
			function	=> \&user,
			seclev		=> 1,
		},
		comment		=> {
			function	=> \&comment,
			seclev		=> 1,
		},
		story		=> {
			function	=> \&story,
			seclev		=> 1,
		},
		journal		=> {
			function	=> \&journal,
			seclev		=> 1,
		},
		auth		=> {
			function	=> \&auth,
			seclev		=> 0,
		},
		mod		=> {
			function	=> \&mod,
			seclev		=> 1,
		},
		default		=> {
			function	=> \&nullop,
			seclev		=> 1,
		}


	};

	$endpoint = 'default' unless $endpoints->{$endpoint};

	  # Check security level
    if ($user->{seclev} < $endpoints->{$endpoint}{seclev}) {
        my $retval = encode_json({ error => 'Insufficient privileges' });
        binmode(STDOUT, ':encoding(utf8)');
        http_send({ content_type => 'application/json; charset=UTF-8',  cache_control => 'no-cache', pragma => 'no-cache' });
        _utf8_on($retval);
        print $retval;
        return;
    }

    my $retval = $endpoints->{$endpoint}{function}->($form, $slashdb, $user, $constants, $gSkin);

    binmode(STDOUT, ':encoding(utf8)');
    http_send({ content_type => 'application/json; charset=UTF-8',  cache_control => 'no-cache', pragma => 'no-cache' });
    _utf8_on($retval);
    print $retval;
}

sub auth {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
	my $op = lc($form->{op});
	
	my $ops = {
		default		=> {
			function	=> \&nullop,
			seclev		=> 1,
		},
		login		=> {
			function	=> \&login,
			seclev		=> 0,
		},
		logout		=> {
			function	=> \&logout,
			seclev		=> 1,
		},
	};

	$op = 'default' unless $ops->{$op};

	if ($user->{seclev} < $ops->{$op}{seclev}) {
        return encode_json({ error => 'Insufficient privileges' });
    }

        return $ops->{$op}{function}->($form, $slashdb, $user, $constants, $gSkin);
}

sub mod {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
	my $op = lc($form->{op});

	my $ops = {
		default		=> {
			function	=> \&nullop,
			seclev		=> 0,
		},
		reasons		=> {
			function	=> \&getModReasons,
			seclev		=> 0,
		},
	};

	$op = 'default' unless $ops->{$op};

	if ($user->{seclev} < $ops->{$op}{seclev}) {
        return encode_json({ error => 'Insufficient privileges' });
    }

	return $ops->{$op}{function}->($form, $slashdb, $user, $constants, $gSkin);
}

sub user {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
	my $op = lc($form->{op});

	my $ops = {
		default		=> {
			function	=> \&nullop,
			seclev		=> 1,
		},
		max_uid		=> {
			function	=> \&maxUid,
			seclev		=> 1,
		},
		get_uid		=> {
			function	=> \&nameToUid,
			seclev		=> 1,
		},
		get_nick	=> {
			function	=> \&uidToName,
			seclev		=> 1,
		},
		get_user	=> {
			function	=> \&getPubUserInfo,
			seclev		=> 1,
		},
	};

	$op = 'default' unless $ops->{$op};

	if ($user->{seclev} < $ops->{$op}{seclev}) {
        return encode_json({ error => 'Insufficient privileges' });
    }

	return $ops->{$op}{function}->($form, $slashdb, $user, $constants, $gSkin);
}

sub story {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
	my $op = lc($form->{op});

	my $ops = {
		default		=> {
			function	=> \&nullop,
			seclev		=> 1,
		},
		latest		=> {
			function	=> \&getLatestStories,
			seclev		=> 1,
		},
		single	=> {
			function	=> \&getSingleStory,
			seclev		=> 1,
		},
		pending	=> {
			function	=> \&getPendingBoth,
			seclev		=> 1,
		},
		post	=> {
			function	=> \&postStory,
			seclev		=> 1,
		},
		reskey		=> {
			function	=> \&getStoryReskey,
			seclev		=> 1,
		},
		nexuslist	=> {
			function	=> \&getNexusList,
			seclev		=> 1,
		},
		topiclist	=> {
			function	=> \&getTopicsList,
			seclev		=> 1,
		},
	};

	$op = 'default' unless $ops->{$op};

	if ($user->{seclev} < $ops->{$op}{seclev}) {
        return encode_json({ error => 'Insufficient privileges' });
    }

	return $ops->{$op}{function}->($form, $slashdb, $user, $constants, $gSkin);
}

sub comment {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
	my $op = lc($form->{op});

	my $ops = {
		default		=> {
			function	=> \&nullop,
			seclev		=> 1,
		},
		latest		=> {
			function	=> \&getLatestComments,
			seclev		=> 1,
		},
		single		=> {
			function	=> \&getSingleComment,
			seclev		=> 1,
		},
		discussion	=> {
			function	=> \&getDiscussion,
			seclev		=> 1,
		},
		post		=> {
			function	=> \&postComment,
			seclev		=> 1,
		},
		reskey		=> {
			function	=> \&getCommentReskey,
			seclev		=> 1,
		},
	};

	$op = 'default' unless $ops->{$op};


	if ($user->{seclev} < $ops->{$op}{seclev}) {
        return encode_json({ error => 'Insufficient privileges' });
    }

	return $ops->{$op}{function}->($form, $slashdb, $user, $constants, $gSkin);
}

sub journal {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
	my $op = lc($form->{op});

	my $ops = {
		default		=> {
			function	=> \&nullop,
			seclev		=> 1,
		},
		latest		=> {
			function	=> \&getLatestJournals,
			seclev		=> 1,
		},
		single		=> {
			function	=> \&getSingleJournal,
			seclev		=> 1,
		},
	};

	$op = 'default' unless $ops->{$op};

	if ($user->{seclev} < $ops->{$op}{seclev}) {
        return encode_json({ error => 'Insufficient privileges' });
    }

	return $ops->{$op}{function}->($form, $slashdb, $user, $constants, $gSkin);
}


sub admin {
    my ($form, $slashdb, $user, $constants, $gSkin) = @_;
    my $op = lc($form->{op});

    my $ops = {
        flag_spam	=> {
            function	=> \&flag_spam,
            seclev		=> 100,
        },
		  get_comments_audit => {
            function => \&get_comments_audit,
            seclev   => 0,
        },
        default		=> {
            function	=> \&nullop,
            seclev		=> 0,
        },
    };

    $op = 'default' unless $ops->{$op};

    # Check security level
    if ($user->{seclev} < $ops->{$op}{seclev}) {
        return encode_json({ error => 'Insufficient privileges' });
    }

    return $ops->{$op}{function}->($form, $slashdb, $user, $constants, $gSkin);
}

sub get_comments_audit {
    my ($form, $slashdb, $user, $constants, $gSkin) = @_;
    my $cid = $form->{cid};
    my $limit = $form->{limit};

    # Call getCommentsAudit to retrieve the audit entries
    my $sth = $slashdb->getCommentsAudit($cid, $limit);

    # Fetch all rows
    my @rows;
    while (my $row = $sth->fetchrow_hashref) {
        push @rows, $row;
    }

    return encode_json({ success => 1, data => \@rows });
}

sub flag_spam {
    my ($form, $slashdb, $user, $constants, $gSkin) = @_;
    my $cid = $form->{cid};
    my $spam_flag = $form->{spam_flag};
    my $mod_reason = $form->{mod_reason};

    # Ensure cid, spam_flag, and mod_reason are provided
    unless ($cid) {
        return encode_json({ error => 'Comment ID not provided' });
    }
    unless (defined $spam_flag) {
        return encode_json({ error => 'Spam flag value not provided' });
    }
    unless ($mod_reason) {
        return encode_json({ error => 'Moderation reason not provided' });
    }

    # Call doFlagSpam to handle the database operations
    my $result = $slashdb->doFlagSpam($cid, $spam_flag, $user->{uid}, $mod_reason);

    if ($result) {
        return encode_json({ success => 'Comment spam flag updated' });
    } else {
        return encode_json({ error => 'Failed to update comment spam flag' });
    }
}

sub getTopicsList {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
        my $json = JSON->new->utf8->allow_nonref;
	my $wholeshebang = $slashdb->getTopics();
	my $topics = [];
	foreach(sort { $a <=> $b } keys(%$wholeshebang) ) {
		push(@$topics, $wholeshebang->{$_});
	}

	return $json->pretty->encode($topics);
}

sub getNexusList {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
        my $json = JSON->new->utf8->allow_nonref;
	my $wholeshebang = $slashdb->getSkins();
	my $nexuses = [];
	foreach(sort { $a <=> $b } keys(%$wholeshebang) ) {
		push(@$nexuses, $wholeshebang->{$_});
	}
	return $json->pretty->encode($nexuses);
	
}

sub login {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
	my $json = JSON->new->utf8->allow_nonref;
	
	my $tmpuid = $slashdb->getUserUID($form->{nick});

	my ($uid, $cookvalue) = $slashdb->getUserAuthenticate($tmpuid, $form->{pass}, 0, 0);
	my $baked = bakeUserCookie($uid, $cookvalue);
	setCookie('user', $baked,
		$slashdb->getUser($uid, 'session_login')
	);
	
	return $json->pretty->encode($baked);
}

sub logout {
}

sub getPendingBoth {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
	my $json = JSON->new->utf8->allow_nonref;
	my $submissions = $slashdb->getSubmissionForUser;
	my $pending = $slashdb->getStoriesSince;

	foreach my $sub (@$submissions) {
		delete $sub->{ipid};
		delete $sub->{weight};
		delete $sub->{subnetid};
		delete $sub->{signature};
		delete $sub->{note};
		delete $sub->{del};
		delete $sub->{email};
		delete $sub->{emaildomain};
		delete $sub->{mediatype};
		delete $sub->{comment};
	}

	return $json->pretty->encode({ submissions => $submissions, pending_stories => $pending });
}

sub getStoryReskey {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
	my $json = JSON->new->utf8->allow_nonref;
	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('submit');
	return $json->pretty->encode($rkey->errstr) unless $rkey->create;
	return $json->pretty->encode( { reskey => $rkey->reskey } );
}

sub getCommentReskey {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
	my $json = JSON->new->utf8->allow_nonref;
	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('comments');
	return $json->pretty->encode($rkey->errstr) unless $rkey->create;
	return $json->pretty->encode( { reskey => $rkey->reskey } );
}

sub postStory {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
	my $json = JSON->new->utf8->allow_nonref;
	my $error_message;

	return &nullop unless $form->{story} && $form->{subj} && $form->{tid} && $form->{sub_type} && $form->{primaryskid} && $form->{reskey};


	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('submit', { reskey => $form->{reskey} } );
	return $json->pretty->encode( { error_here => $rkey->errstr } ) unless $rkey->use;

	$form->{name} ||= 'Anonymous Coward';
	my $uid;
	if($form->{name} eq $user->{nickname}) {
		$uid = $user->{uid};
	} else {
		$uid = getCurrentStatic('anonymous_coward_uid');
	}

	if (length($form->{subj}) < 2) {
		$error_message = getData('badsubject');
		return $json->pretty->encode($error_message);
	}

	my %keys_to_check = ( story => 1, subj => 1 );
	for (keys %$form) {
		next unless $keys_to_check{$_};
		return $json->pretty->encode($error_message) unless filterOk('submissions', $_, $form->{$_}, \$error_message);

		my $compressOK = compressOk($form->{$_});
		$error_message = getData('compresserror');
		return $json->pretty->encode($error_message) unless $compressOK;
	}
	
	# This needs to go away once filters are in place for rendering.
	$form->{story} = fixStory($form->{story}, { sub_type => $form->{sub_type} });
	#return blah if $form->{preview} == 1;

	my $submission = {
		email		=> $form->{email},
		uid		=> $uid,
		name		=> $form->{name},
		story		=> $form->{story},
		subj		=> $form->{subj},
		tid		=> $form->{tid},
		primaryskid	=> $form->{primaryskid},
		mediatype	=> $form->{mediatype},
	};
	
	my @topics = ();
	my $nexus = $slashdb->getNexusFromSkid($form->{primaryskid} || $constants->{mainpage_skid});
	push @topics, $nexus;
	push @topics, $form->{tid} if $form->{tid};
	my $chosen_hr = genChosenHashrefForTopics(\@topics);
	my $extras = $slashdb->getNexusExtrasForChosen($chosen_hr) || [];
	my @missing_required = grep{$_->[4] eq "yes" && !$form->{$_->[1]}} @$extras;
	return $json->pretty->encode( { missing_required => @missing_required } ) if @missing_required;

	if ($extras && @$extras) {
		for (@$extras) {
			my $key = $_->[1];
			$submission->{$key} = strip_nohtml($form->{$key}) if $form->{$key};
		}
	}

	my $messagesub = { %$submission };
	$messagesub->{subid} = $slashdb->createSubmission($submission);
	return $json->pretty->encode("Failed to create submission") unless $messagesub->{subid};

	if ($messagesub->{subid} && ($uid != getCurrentStatic('anonymous_coward_uid'))) {
		my $dynamic_blocks = getObject('Slash::DynamicBlocks');
		$dynamic_blocks->setUserBlock('submissions', $uid) if $dynamic_blocks;
	}

	my $messages = getObject('Slash::Messages');
	if ($messages) {
		my $users = $messages->getMessageUsers(MSG_CODE_NEW_SUBMISSION);
		my $data  = {
			template_name	=> 'messagenew',
			subject		=> { template_name => 'messagenew_subj' },
			submission	=> $messagesub,
		};
		$messages->create($users, MSG_CODE_NEW_SUBMISSION, $data) if @$users;
	}
	
	return $json->pretty->encode($messagesub);
}

sub postComment {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
	$form->{pid} = 0 unless $form->{pid};
	my $json = JSON->new->utf8->allow_nonref;
	my ($error_message, $preview);

	return &nullop unless $form->{sid} && $form->{postersubj} && $form->{postercomment} && $form->{posttype} && $form->{reskey};

	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('comments', { reskey => $form->{reskey} } );
		
	my $discussion;
	if ($form->{sid} !~ /^\d+$/){$discussion = $slashdb->getDiscussionBySid($form->{sid});}
	else{$discussion = $slashdb->getDiscussion($form->{sid});}
	return $json->pretty->encode("No such discussion") unless $discussion;
	return $json->pretty->encode("You can't post to that discussion yet.") if $discussion->{is_future};

	$preview = previewForm(\$error_message, $discussion) if (($form->{preview}) && ($form->{preview} eq 1));
	return $json->pretty->encode($error_message) if $error_message;
	return $json->pretty->encode($preview) if $preview;
	
	my $comment = preProcessComment($form, $user, $discussion, \$error_message);

	if($comment eq '-1' || !$comment){return $json->pretty->encode($error_message);}

	return $json->pretty->encode($rkey->errstr) unless $rkey->use;

	my $saved_comment = saveComment($form, $comment, $user, $discussion, \$error_message);

	if(!$saved_comment){return $json->pretty->encode($error_message);}
	delete $saved_comment->{ipid};
	delete $saved_comment->{subnetid};
	delete $saved_comment->{signature},
	return $json->pretty->encode($saved_comment);
}

sub getSingleJournal {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
	my $journal_reader = getObject('Slash::Journal', { db_type => 'reader' });

	my $journal = $journal_reader->get($form->{id});
	delete $journal->{srcid_32};
	delete $journal->{srcid_24};
	
	$journal->{nickname} = $slashdb->sqlSelect(
				'nickname',
				'users',
				" uid = $journal->{uid} ");
	$journal->{link} = "$gSkin->{absolutedir}/~$journal->{nickname}/journal/$journal->{id}";

	my $json = JSON->new->utf8->allow_nonref;
	return $json->pretty->encode($journal);
}

sub getLatestJournals {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
	my $journal_reader = getObject('Slash::Journal', { db_type => 'reader' });

	my $journals = $journal_reader->getRecent($form->{limit}, $form->{uid});

	my $items;
	for my $id (sort {$b <=> $a} keys %$journals) {
		delete $journals->{$id}->{srcid_32};
		delete $journals->{$id}->{srcid_24};

		$journals->{$id}->{nickname} = $slashdb->sqlSelect(
					'nickname',
					'users',
					" uid = $journals->{$id}->{uid} ");
		$journals->{$id}->{link} = "$gSkin->{absolutedir}/~$journals->{$id}->{nickname}/journal/$id";
		
		my $texts = $slashdb->sqlSelectArrayRef(
					'introtext, article',
					'journals_text',
					" id = $id ");
		($journals->{$id}->{introtext}, $journals->{$id}->{article}) = @$texts;
		
		push @$items, $journals->{$id};
	}

	my $json = JSON->new->utf8->allow_nonref;
	return $json->pretty->encode($items);
}

sub getLatestComments {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
	
	my $select = "* ";
	my $id = "cid";
	my $table = "comments ";
	my $where = "1 = 1 "; # we need a where but this needs to default to always true
	my $other = "ORDER BY cid DESC LIMIT 50 ";

	if($form->{since} && $form->{since} =~ /^\d+$/) {
		my $cid_q = $slashdb->sqlQuote($form->{since} - 1);
		$where = "cid > $cid_q ";
	}

	my $comments_h = $slashdb->sqlSelectAllHashref($id, $select, $table, $where, $other);
	my $comments = [];
	foreach my $cid (sort sort {$a <=> $b} keys %$comments_h) {
		my $comment = $comments_h->{$cid};		
		my $cid_q = $slashdb->sqlQuote($cid);

		delete $comment->{subnetid};
		delete $comment->{has_read};
		delete $comment->{time};
		delete $comment->{ipid};
		delete $comment->{signature};
		delete $comment->{lastmod} if $comment->{lastmod};

		$comment->{comment} = $slashdb->sqlSelect("comment", "comment_text", "cid = $cid_q");
		push(@$comments, $comment);
	}

	my $json = JSON->new->utf8->allow_nonref;
	return $json->pretty->encode($comments);
}

sub getSingleComment {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
	my $tables = "comments";
	my $cid_q = $slashdb->sqlQuote($form->{cid});
	my $where = "cid=$cid_q ";
	my $select = "* ";
	my $comment = $slashdb->sqlSelectHashref($select, $tables, $where);
	$comment->{comment} = $slashdb->sqlSelect("comment", "comment_text", "cid = $cid_q");

	delete $comment->{subnetid};
	delete $comment->{has_read};
	delete $comment->{time};
	delete $comment->{ipid};
	delete $comment->{signature};
	delete $comment->{lastmod} if $comment->{lastmod};
	my $json = JSON->new->utf8->allow_nonref;
	return $json->pretty->encode($comment);
}

sub getDiscussion {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
	my $discussion = $slashdb->getDiscussion($form->{sid});
	if (!$discussion || !$discussion->{commentcount} ||  $discussion->{commentstatus} eq 'disabled' ) { return; }

	my($comments, $count) = selectComments($discussion);
	# Add comment text
	foreach my $cid (keys %$comments) {
		next if $cid eq "0";
		my $cid_q = $slashdb->sqlQuote($cid);
		$comments->{$cid}{comment} = $slashdb->sqlSelect("comment", "comment_text", "cid = $cid_q");
		delete $comments->{$cid}{subnetid};
		delete $comments->{$cid}{has_read};
		delete $comments->{$cid}{time};
		delete $comments->{$cid}{ipid};
		delete $comments->{$cid}{lastmod} if $comments->{$cid}{lastmod};
		delete $comments->{signature} if $comments->{signature};
	}

	my $json = JSON->new->utf8->allow_nonref;
	return $json->pretty->encode($comments);
}

sub getSingleStory {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
	my $story = $slashdb->getStory($form->{sid});
	if( ($story->{is_future}) || ($story->{in_trash} ne "no") ){return;};
	return unless $slashdb->checkStoryViewable($story->{stoid});
	my $sSkin = $slashdb->getSkin($story->{primaryskid});
	$story->{nexus} = $sSkin->{name};
	delete $story->{story_topics_rendered};
	delete $story->{is_future};
	delete $story->{in_trash};
	delete $story->{thumb_signoff_needed};
	delete $story->{rendered};
	delete $story->{qid};
	$story->{bodytext} = $story->{introtext} unless $story->{bodytext};
	$story->{body_length} = length($story->{bodytext});
	my $json = JSON->new->utf8->allow_nonref;
	return $json->pretty->encode($story);
}

sub getLatestStories {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
	my $json = JSON->new->utf8->allow_nonref;
	my $options;
	($options->{limit}, $options->{limit_extra}) = (($form->{limit} || 10), 0);
	$options->{limit} = 10 unless $options->{limit} =~ /^\d+$/;
	$options->{limit} = 1 unless $options->{limit} > 1;
	$options->{limit} = 50 unless $options->{limit} <= 50;

	my $topics = $slashdb->getTopics();
	if(! defined($topics->{$form->{tid}})) {
		return $json->pretty->encode("no such topic: $form->{tid}");
	} elsif($topics->{$form->{tid}}->{searchable} ne 'yes') {
		return $json->pretty->encode("tid $form->{tid} is not searchable");
	} else {
		$options->{tid} = $form->{tid};
	}

	my $stories = $slashdb->getStoriesEssentials($options);
	foreach my $story (@$stories) {
		($story->{introtext}, $story->{bodytext}, $story->{title}, $story->{relatedtext}, $story->{tid}, $story->{dept}) = $slashdb->sqlSelect("introtext, bodytext, title, relatedtext, stories.tid, stories.dept", "story_text LEFT JOIN stories ON stories.stoid = story_text.stoid", "story_text.stoid = $story->{stoid}");
		$story->{bodytext} = $story->{introtext} unless $story->{bodytext};
		$story->{body_length} = length($story->{bodytext});
		my $sSkin = $slashdb->getSkin($story->{primaryskid});
	        $story->{nexus} = $sSkin->{name};
		delete $story->{is_future};
		delete $story->{hitparade};
	}
	return $json->pretty->encode($stories);
}

sub nullop {
	my $error = { RTFM => 'http://wiki.soylentnews.org/wiki/ApiDocs' };
	my $json = JSON->new->utf8->allow_nonref;
	return $json->pretty->encode($error);
}

sub maxUid {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
	my $json = JSON->new->utf8->allow_nonref;
	my $max = {};
	$max->{max_uid} = $slashdb->sqlSelect(
					'max(uid)',
					'users');
	return $json->pretty->encode($max);
}

sub nameToUid {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
	my $json = JSON->new->utf8->allow_nonref;
	my $nick = $slashdb->sqlQuote($form->{nick});
	my $uid = {};
	$uid->{uid} = $slashdb->sqlSelect(
					'uid',
					'users',
					" nickname = $nick ");
	return $json->pretty->encode($uid);
}

sub uidToName {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
	my $json = JSON->new->utf8->allow_nonref;
	my $uid = $form->{uid};
	my $nick = {};
	$nick->{nick} = $slashdb->sqlSelect(
					'nickname',
					'users',
					" uid = $uid ");
	return $json->pretty->encode($nick);
}

sub getPubUserInfo {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
	my $askUser = $slashdb->getUser($form->{uid});

	my @allowed = (
		'jabber',
		'fakeemail',
		'uid',
		'nickname',
		'icq',
		'sig',
		'homepage',
		'registered',
		'realname',
		'karma',
		'journal_last_entry_date',
		'aim',
		'created_at',
		'calendar_url',
		'people',
		'yahoo',
		'bio',
		'totalcomments',

	);
	my $subscriber = 0;
	unless($askUser->{hide_subscription}) {
		use DateTime;
		use DateTime::Format::MySQL;
		my $dt_today   = DateTime->today;
		my $dt_sub = DateTime::Format::MySQL->parse_date($askUser->{subscriber_until});
		
		if ( $dt_sub >= $dt_today ){
			$subscriber = 1;
		}
	}

	my $repUser = {};
	$repUser->{is_subscriber} = $subscriber;
	foreach my $field (@allowed) {
		$repUser->{$field} = $askUser->{$field};
	}

	my $json = JSON->new->utf8->allow_nonref;
	return $json->pretty->encode($repUser);
}

# Copied over from comments.pl. Wish it'd been in Comments.pm instead.
sub previewForm {
	my($error_message, $discussion) = @_;
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	my $comment = preProcessComment($form, $user, $discussion, $error_message) or return;
	return $$error_message if $comment eq '-1';
	my $preview = postProcessComment({ %$user, %$form, %$comment }, 0, $discussion);

	if ($constants->{plugin}{Subscribe}) {
		$preview->{subscriber_bonus} =
			$user->{is_subscriber}
			&& (!$form->{nosubscriberbonus} || $form->{nosubscriberbonus} ne 'on')
			? 1 : 0;
	}

	return prevComment($preview, $user);
}

# Copied over from submit.pl
sub genChosenHashrefForTopics {
	my($topics) = @_;
	my $constants = getCurrentStatic();
	my $chosen_hr ={};
	for my $tid (@$topics) {
		$chosen_hr->{$tid} = 
			$tid == $constants->{mainpage_nexus_tid}
				? 30
				: $constants->{topic_popup_defaultweight} || 10;
	}
	return $chosen_hr;
}

sub getModReasons {
	my ($form, $slashdb, $user, $constants, $gSkin) = @_;
	my $json = JSON->new->utf8->allow_nonref;
	my $wholeshebang = $slashdb->sqlSelectAllHashref("id", "id, name, val, ordered, needs_prior_mod", "modreasons", "id <> 100");


	return $json->pretty->encode($wholeshebang);
}
#createEnvironment();
main();
1;

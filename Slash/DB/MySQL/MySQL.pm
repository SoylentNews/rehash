# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::DB::MySQL;
use strict;
use Socket;
use Digest::MD5 'md5_hex';
use Time::HiRes;
use Date::Format qw(time2str);
use Data::Dumper;
use Slash::Utility;
use Storable qw(thaw freeze);
use URI ();
use Slash::Custom::ParUserAgent;
use vars qw($VERSION $_proxy_port);
use base 'Slash::DB';
use base 'Slash::DB::Utility';
use Slash::Constants ':messages';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# Fry: How can I live my life if I can't tell good from evil?

# For the getDescriptions() method
my %descriptions = (
	'sortcodes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='sortcodes'") },

	'generic'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='$_[2]'") },

	'genericstring'
		=> sub { $_[0]->sqlSelectMany('code,name', 'string_param', "type='$_[2]'") },

	'statuscodes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='statuscodes'") },

	'yes_no'
		=> sub { $_[0]->sqlSelectMany('code,name', 'string_param', "type='yes_no'") },

	'submission-notes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'string_param', "type='submission-notes'") },

	'submission-state'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='submission-state'") },

	'months'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='months'") },

	'years'
		=> sub { $_[0]->sqlSelectMany('name,name', 'code_param', "type='years'") },

	'blocktype'
		=> sub { $_[0]->sqlSelectMany('name,name', 'code_param', "type='blocktype'") },

	'tzcodes'
		=> sub { $_[0]->sqlSelectMany('tz,off_set', 'tzcodes') },

	'tzdescription'
		=> sub { $_[0]->sqlSelectMany('tz,description', 'tzcodes') },

	'dateformats'
		=> sub { $_[0]->sqlSelectMany('id,description', 'dateformats') },

	'datecodes'
		=> sub { $_[0]->sqlSelectMany('id,format', 'dateformats') },

	'discussiontypes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='discussiontypes'") },

	'commentmodes'
		=> sub { $_[0]->sqlSelectMany('mode,name', 'commentmodes') },

	'threshcodes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='threshcodes'") },

	'threshcode_values'
		=> sub { $_[0]->sqlSelectMany('code,code', 'code_param', "type='threshcodes'") },

	'postmodes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='postmodes'") },

	'issuemodes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='issuemodes'") },

	'vars'
		=> sub { $_[0]->sqlSelectMany('name,name', 'vars') },

	'topics'
		=> sub { $_[0]->sqlSelectMany('tid,textname', 'topics') },

	'non_nexus_topics'
		=> sub { $_[0]->sqlSelectMany('topics.tid AS tid,textname', 'topics LEFT JOIN topic_nexus on topic_nexus.tid=topics.tid', "topic_nexus.tid IS NULL") },

	'maillist'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='maillist'") },

	'session_login'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='session_login'") },

	'cookie_location'
		=> sub { $_[0]->sqlSelectMany('code,name', 'string_param', "type='cookie_location'") },

	'sortorder'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='sortorder'") },

	'displaycodes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='displaycodes'") },

	'displaycodes_sectional'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='displaycodes_sectional'") },

	'commentcodes'
		=> sub { my $user = getCurrentUser(); 
			my $where = " OR type='commentcodes_extended'" if $user->{is_admin} || $user->{is_subscriber};
			$_[0]->sqlSelectMany('code,name', 'string_param', "type='commentcodes'" . $where) 
		},

	'skins'
		=> sub { $_[0]->sqlSelectMany('skid,title', 'skins') },

	'skins-all'
		=> sub { $_[0]->sqlSelectMany('skid,title', 'skins') },

	'skins-submittable'
		=> sub { $_[0]->sqlSelectMany('skid,title', 'skins', "submittable='yes'") },

	'static_block'
		=> sub { $_[0]->sqlSelectMany('bid,bid', 'blocks', "$_[2] >= seclev AND type != 'portald'") },

	'portald_block'
		=> sub { $_[0]->sqlSelectMany('bid,bid', 'blocks', "$_[2] >= seclev AND type = 'portald'") },

	'static_block_section'
		=> sub { $_[0]->sqlSelectMany('bid,bid', 'blocks', "$_[2]->{seclev} >= seclev AND section='$_[2]->{section}' AND type != 'portald'") },

	'portald_block_section'
		=> sub { $_[0]->sqlSelectMany('bid,bid', 'blocks', "$_[2]->{seclev} >= seclev AND section='$_[2]->{section}' AND type = 'portald'") },

	'color_block'
		=> sub { $_[0]->sqlSelectMany('bid,bid', 'blocks', "type = 'color'") },

	'authors'
		=> sub { $_[0]->sqlSelectMany('uid,nickname', 'authors_cache', "author = 1") },

	'all-authors'
		=> sub { $_[0]->sqlSelectMany('uid,nickname', 'authors_cache') },

	'admins'
		=> sub { $_[0]->sqlSelectMany('uid,nickname', 'users', 'seclev >= 100') },

	'users'
		=> sub { $_[0]->sqlSelectMany('uid,nickname', 'users') },

	'templates'
		=> sub { $_[0]->sqlSelectMany('tpid,name', 'templates') },

	'keywords'
		=> sub { $_[0]->sqlSelectMany('id,CONCAT(keyword, " - ", name)', 'related_links') },

	'pages'
		=> sub { $_[0]->sqlSelectMany('distinct page,page', 'templates') },

	'templateskins'
		=> sub { $_[0]->sqlSelectMany('DISTINCT skin, skin', 'templates') },

	'plugins'
		=> sub { $_[0]->sqlSelectMany('value,description', 'site_info', "name='plugin'") },

	'site_info'
		=> sub { $_[0]->sqlSelectMany('name,value', 'site_info', "name != 'plugin'") },

	'forms'
		=> sub { $_[0]->sqlSelectMany('value,value', 'site_info', "name = 'form'") },

	'journal_discuss'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='journal_discuss'") },

	'section_extra_types'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='extra_types'") },

	'otherusersparam'
		=> sub { $_[0]->sqlSelectMany('code,name', 'string_param', "type='otherusersparam'") },

	'bytelimit'
		=> sub { $_[0]->sqlSelectMany('code, name', 'code_param', "type='bytelimit'") },

	'bytelimit_sub'
		=> sub { $_[0]->sqlSelectMany('code, name', 'code_param', "type='bytelimit' OR type='bytelimit_sub'") },

	countries => sub {
		$_[0]->sqlSelectMany(
			'code,CONCAT(code," (",name,")") as name',
			'string_param',
			'type="iso_countries"',
			'ORDER BY name'
		);
	},

	'forums'
		=> sub { $_[0]->sqlSelectMany('subsections.id, subsections.title', 'section_subsections, subsections', "section_subsections.subsection=subsections.id AND section_subsections.section='forums'") },

);

########################################################
sub _whereFormkey {
	my($self) = @_;

	my $ipid = getCurrentUser('ipid');
	my $uid = getCurrentUser('uid');
	my $where;

	# anonymous user without cookie, check host, not ipid
	if (isAnon($uid)) {
		$where = "ipid = '$ipid'";
	} else {
		$where = "uid = '$uid'";
	}

	return $where;
};

########################################################
# Notes:
#  formAbuse, use defaults as ENV, be able to override
#  	(pudge idea).
#  description method cleanup. (done)
#  fetchall_rowref vs fetch the hashses and push'ing
#  	them into an array (good arguments for both)
#	 break up these methods into multiple classes and
#   use the dB classes to override methods (this
#   could end up being very slow though since the march
#   is kinda slow...).
#	 the getAuthorEdit() methods need to be refined
########################################################

########################################################
sub init {
	my($self) = @_;
	# These are here to remind us of what exists
	$self->{_codeBank} = {};

	$self->{_boxes} = {};
	$self->{_sectionBoxes} = {};

	$self->{_comment_text} = {};
	$self->{_comment_text_full} = {};

	$self->{_story_comm} = {};

	# Do all cache elements contain '_cache_' in it, if so, we should 
	# probably perform a delete on anything matching, here.
}

########################################################
# Yes, this is ugly, and we can ditch it in about 6 months
# Turn off autocommit here
sub sqlTransactionStart {
	my($self, $arg) = @_;
	$self->sqlDo($arg);
}

########################################################
# Put commit here
sub sqlTransactionFinish {
	my($self) = @_;
	$self->sqlDo("UNLOCK TABLES");
}

########################################################
# In another DB put rollback here
sub sqlTransactionCancel {
	my($self) = @_;
	$self->sqlDo("UNLOCK TABLES");
}

########################################################
# Bad need of rewriting....
sub createComment {
	my($self, $comment) = @_;
	return -1 unless dbAvailable("write_comments");
	my $comment_text = $comment->{comment};
	delete $comment->{comment};
	$comment->{signature} = md5_hex($comment_text);
	$comment->{-date} = 'NOW()';
	$comment->{len} = length($comment_text);
	$comment->{pointsorig} = $comment->{points} || 0;
	$comment->{pointsmax}  = $comment->{points} || 0;

#	$self->{_dbh}{AutoCommit} = 0;
	$self->sqlDo("SET AUTOCOMMIT=0");

	my $cid;
	if ($self->sqlInsert('comments', $comment)) {
		$cid = $self->getLastInsertId();
	} else {
#		$self->{_dbh}->rollback;
#		$self->{_dbh}{AutoCommit} = 1;
		$self->sqlDo("ROLLBACK");
		$self->sqlDo("SET AUTOCOMMIT=1");
		errorLog("$DBI::errstr");
		return -1;
	}

	unless ($self->sqlInsert('comment_text', {
			cid	=> $cid,
			comment	=>  $comment_text,
	})) {
#		$self->{_dbh}->rollback;
#		$self->{_dbh}{AutoCommit} = 1;
		$self->sqlDo("ROLLBACK");
		$self->sqlDo("SET AUTOCOMMIT=1");
		errorLog("$DBI::errstr");
		return -1;
	}

	# should this be conditional on the others happening?
	# is there some sort of way to doublecheck that this value
	# is correct?  -- pudge
	# This is fine as is; if the insert failed, we've already
	# returned out of this method. - Jamie
	unless ($self->sqlUpdate(
		"discussions",
		{ -commentcount	=> 'commentcount+1' },
		"id=$comment->{sid}",
	)) {
#		$self->{_dbh}->rollback;
#		$self->{_dbh}{AutoCommit} = 1;
		$self->sqlDo("ROLLBACK");
		$self->sqlDo("SET AUTOCOMMIT=1");
		errorLog("$DBI::errstr");
		return -1;
	} 

#	$self->{_dbh}->commit;
#	$self->{_dbh}{AutoCommit} = 1;
	$self->sqlDo("COMMIT");
	$self->sqlDo("SET AUTOCOMMIT=1");

	return $cid;
}

########################################################
# Right now, $from and $reason don't matter, but they
# might someday.
sub getModPointsNeeded {
	my($self, $from, $to, $reason) = @_;

	# Always 1 point for a downmod.
	return 1 if $to < $from;

	my $constants = getCurrentStatic();
	my $pn = $constants->{mod_up_points_needed} || {};
	return $pn->{$to} || 1;
}

########################################################
# At the time of creating a moderation, the caller can decide
# whether this moderation needs more or fewer M2 votes to
# reach consensus.  Passing in 0 for $m2needed means to use
# the default.  Passing in a positive or negative value means
# to add that to the default.  Fractional values are fine;
# the result will always be rounded to an odd number.
sub createModeratorLog {
	my($self, $comment, $user, $val, $reason, $active, $points_spent, $m2needed) = @_;

	my $constants = getCurrentStatic();

	$active = 1 unless defined $active;
	$points_spent = 1 unless defined $points_spent;

	my $m2_base = 0;
	if ($constants->{m2_inherit}) {
		my $mod = $self->getModForM2Inherit($user->{uid}, $comment->{cid}, $reason);
		if ($mod) {
			$m2_base = $mod->{m2needed};
		} else {
			$m2_base = $self->getBaseM2Needed($comment->{cid}, $reason) || getCurrentStatic('m2_consensus');
		}
	} else {
		$m2_base = $self->getBaseM2Needed($comment->{cid}, $reason) || getCurrentStatic('m2_consensus');
	}

	$m2needed ||= 0;
	$m2needed += $m2_base;
	$m2needed = 1 if $m2needed < 1;		# minimum of 1
	$m2needed = int($m2needed/2)*2+1;	# always an odd number

	$m2needed = 0 unless $active;

	my $ret_val = $self->sqlInsert("moderatorlog", {
		uid	=> $user->{uid},
		ipid	=> $user->{ipid} || "",
		subnetid => $user->{subnetid} || "",
		val	=> $val,
		sid	=> $comment->{sid},
		cid	=> $comment->{cid},
		cuid	=> $comment->{uid},
		reason  => $reason,
		-ts	=> 'NOW()',
		active 	=> $active,
		spent	=> $points_spent,
		points_orig => $comment->{points},
		m2needed => $m2needed,
	});

	my $mod_id = $self->getLastInsertId();

	# inherit and apply m2s if necessary
	if ($constants->{m2_inherit}) {
		my $i_m2s = $self->getInheritedM2sForMod($user->{uid}, $comment->{cid}, $reason, $active, $mod_id);
		$self->applyInheritedM2s($mod_id, $i_m2s);
	}
	# cid_reason count changed, update m2needed for related mods
	if ($constants->{m2_use_sliding_consensus} and $active) {
		# Note: this only updates m2needed for moderations that have m2status=0 not those that have already reached consensus.
		# If we're strictly enforcing like mods sharing one group of m2s this behavior might have to change.  If so it's likely to
		# be var controlled.  A better solution is likely to inherit m2s when a new mod is created of a given cid-reason if we
		# want to have the same m2s across all like m1s.  If the mod whose m2s we are inheriting from has already reached consensus
                # we probably just want to inherit those m2s and not up the m2needed value for either mods.

		my $post_m2_base = $self->getBaseM2Needed($comment->{cid}, $reason);

		$self->sqlUpdate("moderatorlog", { m2needed => $post_m2_base }, "cid=".$self->sqlQuote($comment->{cid})." and reason=".$self->sqlQuote($reason)." and m2status=0 and active=1" );
	}
	return $ret_val;
}

sub getBaseM2Needed {
	my($self, $cid, $reason, $options) = @_;
	my $constants = getCurrentStatic();
	my $consensus;
	if ($constants->{m2_use_sliding_consensus}) {
		my $count = $self->sqlCount("moderatorlog", "cid=".$self->sqlQuote($cid)." and reason=".$self->sqlQuote($reason)." and active=1");
		$count += $options->{count_modifier} if defined $options->{count_modifier};
		my $index = $count - 1;
		$index = 0 if $index < 1;
		$index = @{$constants->{m2_sliding_consensus}} - 1
		if $index > (@{$constants->{m2_sliding_consensus}} - 1);
		$consensus = $constants->{m2_sliding_consensus}[$index];
	} else {
		$consensus = $constants->{'m2_consensus'};
	}

	return $consensus;
}


# Pass the id if we've already created the mod for which we are inheriting mods.
# If getting the inherited m2s before the mod is created omit passing the id
# as a parameter. 
sub getInheritedM2sForMod {
	my($self, $mod_uid, $cid, $reason, $active, $id) = @_;
	return [] unless $active;
	my $mod = $self->getModForM2Inherit($mod_uid, $cid, $reason, $id);
	my $p_mid = defined $mod ? $mod->{id} : undef;
	return [] unless $p_mid;
	my $m2s = $self->sqlSelectAllHashrefArray("*", "metamodlog", "mmid=$p_mid ");
	return $m2s;
}

sub getModForM2Inherit {
	my($self, $mod_uid, $cid, $reason, $id) = @_;
	my $mod_uid_q = $self->sqlQuote($mod_uid);
	my $reasons = $self->getReasons();
	my $m2able_reasons = join(",",
		sort grep { $reasons->{$_}{m2able} }
		keys %$reasons);
	return [] if !$m2able_reasons;

	my $id_str = $id ? " AND id!=".$self->sqlQuote($id) : "";

	# Find the earliest active moderation that we can inherit m2s from
        # which isn't the mod we are inheriting them into.  This uses the
	# same criteria as multiMetaMod for determining which mods we can
	# propagate m2s to, or from in the case of inheriting
	my ($mod) = $self->sqlSelectHashref("*","moderatorlog",
				"cid=".$self->sqlQuote($cid).
				" AND reason=".$self->sqlQuote($reason).
				" AND uid!=$mod_uid_q AND cuid!=$mod_uid_q".
				" AND reason in($m2able_reasons)".
				" AND active=1 $id_str",
				" ORDER BY id ASC LIMIT 1"
			);
	return $mod;
}

sub applyInheritedM2s {
	my($self, $mod_id, $m2s) = @_;

	foreach my $m2(@$m2s){
		my $m2_user=$self->getUser($m2->{uid});
		my $cur_m2 = { 
				$mod_id => 	{ is_fair => $m2->{val} == 1 ? 1 : 0 }
			     };
		$self->createMetaMod($m2_user, $cur_m2, 0, { inherited => 1});
	}

}


########################################################
# A friendlier interface to the "mods_saved" param.  Has probably
# more sanity-checking than it needs.
sub getModsSaved {
	my($self, $user) = @_;
	$user = getCurrentUser() if !$user;

	my $mods_saved = $user->{mods_saved} || "";
	return ( ) if !$mods_saved;
	my %mods_saved =
		map { ( $_, 1 ) }
		grep /^\d+$/,
		split ",", $mods_saved;
	return sort { $a <=> $b } keys %mods_saved;
}

sub setModsSaved {
	my($self, $user, $mods_saved_ar) = @_;
	$user = getCurrentUser() if !$user;

	my $mods_saved_txt = join(",",
		sort { $a <=> $b }
		grep /^\d+$/,
		@$mods_saved_ar);
	$self->setUser($user->{uid}, { mods_saved => $mods_saved_txt });
}

########################################################
# This is the method that returns the list of comments for a user to
# metamod, at any given time.  Its logic was changed significantly
# in August 2002.
sub getMetamodsForUser {
	my($self, $user, $num_comments) = @_;
	my $constants = getCurrentStatic();
	# First step is to see what the user already has marked down to
	# be metamoderated.  If there are any such id's, that still
	# aren't done being M2'd, keep those on the user's to-do list.
	# (I.e., once a user sees a list of mods, they keep seeing that
	# same list until they click the button;  reloading the page
	# won't give them new mods.)  If after this check, the list is
	# short of the requisite number, fill up the list, re-save it,
	# and return it.

	# Get saved list of mods to M2 (and check its formatting).

	my @mods_saved = $self->getModsSaved($user);

	# See which still need M2'ing.

	if (@mods_saved) {
		my $mods_saved = join(",", @mods_saved);
		my $mods_not_done = $self->sqlSelectColArrayref(
			"id",
			"moderatorlog",
			"id IN ($mods_saved) AND active=1 AND m2status=0"
		);
		@mods_saved = grep /^\d+$/, @$mods_not_done;
	}

	# If we need more, get more.

	my $num_needed = $num_comments - scalar(@mods_saved);
	if ($num_needed) {
		my %mods_saved = map { ( $_, 1 ) } @mods_saved;
		my $new_mods = $self->getMetamodsForUserRaw($user->{uid},
			$num_needed, \%mods_saved);
		for my $id (@$new_mods) { $mods_saved{$id} = 1 }
		@mods_saved = sort { $a <=> $b } keys %mods_saved;
	}
	$self->setModsSaved($user, \@mods_saved);

	# If we didn't get enough, that's OK, but note it in the
	# error log.

	if (scalar(@mods_saved) < $num_comments) {
		errorLog("M2 gave uid $user->{uid} "
			. scalar(@mods_saved)
			. " comments, wanted $num_comments: "
			. join(",", @mods_saved)
		);
	}

	# OK, we have the list of moderations this user needs to M2,
	# and we have updated the user's data so the next time they
	# come back they'll see the same list.  Now just retrieve
	# the necessary data for those moderations and return it.

	return $self->_convertModsToComments(@mods_saved);
}

{ # closure
my %anonymize = ( ); # gets set inside the function
sub _convertModsToComments {
	my($self, @mods) = @_;
	my $constants = getCurrentStatic();

	return { } unless scalar(@mods);

	if (!scalar(keys %anonymize)) {
		%anonymize = (
			nickname =>	'-',
			uid =>		getCurrentStatic('anonymous_coward_uid'),
			points =>	0,
		);
	}

	my $mods_text = join(",", @mods);

	# We can and probably should get the cid/reason data in
	# getMetamodsForUserRaw(), but it's only a minor performance
	# slowdown for now.

	my $mods_hr = $self->sqlSelectAllHashref(
		"id",
		"id, cid, reason AS modreason",
		"moderatorlog",
		"id IN ($mods_text)"
	);
	my @cids = map { $mods_hr->{$_}{cid} } keys %$mods_hr;
	my $cids_text = join(",", @cids);

	# Get the comment data required to show the user the list of mods.

	my $comments_hr = $self->sqlSelectAllHashref(
		"cid",
		"comments.cid AS cid, comments.sid AS sid,
		 comments.uid AS uid,
		 date, subject, pid, reason, comment,
		 discussions.sid AS discussions_sid,
		 primaryskid,
		 title,
		 sig, nickname",
		"comments, comment_text, discussions, users",
		"comments.cid IN ($cids_text)
		 AND comments.cid = comment_text.cid
		 AND comments.uid = users.uid
		 AND comments.sid = discussions.id"
	);

	# Put the comment data into the mods hashref.

	for my $mod_id (keys %$mods_hr) {
		my $mod_hr = $mods_hr->{$mod_id};	# This mod.
		my $cid = $mod_hr->{cid};
		my $com_hr = $comments_hr->{$cid};	# This mod's comment.
		for my $key (keys %$com_hr) {
			next if exists($mod_hr->{$key});
			my $val = $com_hr->{$key};
			# Anonymize comment identity a bit for fairness.
			$val = $anonymize{$key} if exists $anonymize{$key};
			$mod_hr->{$key} = $val;
		}
		my $rootdir = $self->getSkin($com_hr->{primaryskid})->{rootdir};
		if ($mod_hr->{discussions_sid}) {
			# This is a comment posted to a story discussion, so
			# we can link straight to the story, providing even
			# more context for this comment.
			$mod_hr->{url} = "$rootdir/article.pl?sid=$mod_hr->{discussions_sid}";
		} else {
			# This is a comment posted to a discussion that isn't
			# a story.  It could be attached to a poll, a journal
			# entry, or nothing at all (user-created discussion).
			# Whatever the case, we can't trust the url field, so
			# we should just link to the discussion itself.
			$mod_hr->{url} = "$rootdir/comments.pl?sid=$mod_hr->{sid}";
		}
		$mod_hr->{no_moderation} = 1;
	}

	# Copy the hashref into an arrayref, along the way doing a last-minute
	# check to make sure every comment has an sid.  We're going to sort
	# this arrayref first by sid, then by cid, and last by mod id, so mods
	# that share a story or even a comment will appear together, saving
	# the user a bit of confusion.

	my @final_mods = ( );
	for my $mod_id (
		sort {
			$mods_hr->{$a}{sid} <=> $mods_hr->{$b}{sid}
			||
			$mods_hr->{$a}{cid} <=> $mods_hr->{$b}{cid}
			||
			$a <=> $b
		} keys %$mods_hr
	) {
		# This "next" is a holdover from old code - is this really
		# necessary!?  Every cid has a discussion and every
		# discussion has an sid.
		next unless $mods_hr->{$mod_id}{sid};
		push @final_mods, $mods_hr->{$mod_id};
	}

	return \@final_mods;
}
}

sub getReasons {
	my($self) = @_;
	# Return a copy of the cache, just in case anyone munges it up.
	my $reasons = {( %{getCurrentStatic('reasons')} )};
	return $reasons;
}

# Get a list of moderations that the given uid is able to metamod,
# with the oldest not-yet-done mods given highest priority.
sub getMetamodsForUserRaw {
	my($self, $uid, $num_needed, $already_have_hr) = @_;
	my $uid_q = $self->sqlQuote($uid);
	my $constants = getCurrentStatic();
	my $m2_wait_hours = $constants->{m2_wait_hours} || 12;

	my $reasons = $self->getReasons();
	my $m2able_reasons = join(",",
		sort grep { $reasons->{$_}{m2able} }
		keys %$reasons);
	return [ ] if !$m2able_reasons;

	# Prepare the lists of ids and cids to exclude.
	my $already_id_list = "";
	if (%$already_have_hr) {
		$already_id_list = join ",", sort keys %$already_have_hr;
	}
	my $already_cids_hr = { };
	my $already_cid_list = "";
	if ($already_id_list) {
		$already_cids_hr = $self->sqlSelectAllHashref(
			"cid",
			"cid",
			"moderatorlog",
			"id IN ($already_id_list)"
		);
		$already_cid_list = join(",", sort keys %$already_cids_hr);
	}

	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	# We need to consult two tables to get a list of moderatorlog IDs
	# that it's OK to M2:  moderatorlog of course, and metamodlog to
	# check that this user hasn't M2'd them before.  Because this is
	# necessarily a table scan on moderatorlog, speed will be essential.
	# We're going to do the select on moderatorlog first, then run its
	# results through the other two tables to exclude what we can't use.
	# However, since we can't predict how many of our hits will be
	# deemed "bad" (unusable), we may have to loop around more than
	# once to get enough.
	my $getmods_loops = 0;
	my @ids = ( );
	my $mod_hr;

	my $num_oldzone_needed = 0;
	my $oldzone = $self->getVar('m2_oldzone', 'value', 1);
	if ($oldzone) {
		$num_oldzone_needed = int(
			$num_needed *
			($constants->{m2_oldest_zone_percentile}
				* $constants->{m2_oldest_zone_mult})/100
			+ rand()
		);
		# just a sanity check...
		$num_oldzone_needed = $num_needed if $num_oldzone_needed > $num_needed;
	}
	my $num_normal_needed = $num_needed - $num_oldzone_needed;

	GETMODS: while ($num_needed > 0 && ++$getmods_loops <= 4) {
		my $limit = $num_needed*2+10; # get more, hope it's enough
		my $already_id_clause = "";
		$already_id_clause  = " AND  id NOT IN ($already_id_list)"
			if $already_id_list;
		my $already_cid_clause = "";
		$already_cid_clause = " AND cid NOT IN ($already_cid_list)"
			if $already_cid_list;
		my $only_old_clause = "";
		if ($num_oldzone_needed) {
			# We need older mods.
			$only_old_clause = " AND id <= $oldzone";
		}
		$mod_hr = { };
		$mod_hr = $reader->sqlSelectAllHashref(
			"id",
			"id, cid,
			 RAND() AS rank",
			"moderatorlog",
			"uid != $uid_q AND cuid != $uid_q
			 AND m2status=0
			 AND reason IN ($m2able_reasons)
			 AND active=1
			 AND ts < DATE_SUB(NOW(), INTERVAL $m2_wait_hours HOUR)
			 $already_id_clause $already_cid_clause $only_old_clause",
			"ORDER BY rank LIMIT $limit"
		);
		if (!$mod_hr || !scalar(keys %$mod_hr)) {
			# OK, we didn't get any.  If we were looking
			# just for old, then forget it and move on.
			# Otherwise, give up completely.
			if ($num_oldzone_needed) {
				$num_needed += $num_oldzone_needed;
				$num_oldzone_needed = 0;
				next GETMODS;
			} else {
				last GETMODS;
			}
		}

		# Exclude any moderations this user has already metamodded.
		my $mod_ids = join ",", keys %$mod_hr;
		my %mod_ids_bad = map { ( $_, 1 ) }
			$self->sqlSelectColArrayref("mmid", "metamodlog",
				"mmid IN ($mod_ids) AND uid = $uid_q");

		# Add the new IDs to the list.
		my @potential_new_ids =
			# In order by rank, in case we got more than needed.
			sort { $mod_hr->{$a}{rank} <=> $mod_hr->{$b}{rank} }
			keys %$mod_hr;
		# Walk through the new potential mod IDs, and add them in
		# one at a time.  Those which are for cids already on our
		# list, or for mods this user has already metamodded, don't
		# make the cut.
		my @new_ids = ( );
		for my $id (@potential_new_ids) {
			my $cid = $mod_hr->{$id}{cid};
			next if $already_cids_hr->{$cid};
			next if $mod_ids_bad{$id};
			push @new_ids, $id;
			$already_cids_hr->{$cid} = 1;
		}
		if ($num_oldzone_needed) {
			$#new_ids = $num_oldzone_needed-1 if $#new_ids > $num_oldzone_needed-1;
			$num_oldzone_needed -= scalar(@new_ids);
		} else {
			$#new_ids = $num_normal_needed-1 if $#new_ids > $num_normal_needed-1;
			$num_normal_needed -= scalar(@new_ids);
		}
		push @ids, @new_ids;
		$num_needed -= scalar(@new_ids);

		# If we tried to get all the oldzone mods we wanted, and
		# failed, give up trying now.  The rest of the looping we
		# do should be for non-oldzone mods (i.e. we only look
		# for the oldzone on the first pass through here).
		if ($num_oldzone_needed) {
			print STDERR scalar(localtime) . " could not get all oldzone mods needed: ids '@ids' num_needed '$num_needed' num_oldzone_needed '$num_oldzone_needed' num_normal_needed '$num_normal_needed'\n";
			$num_normal_needed += $num_oldzone_needed;
			$num_oldzone_needed = 0;
		}
	}
	if ($getmods_loops > 4) {
		print STDERR "GETMODS looped the max number of times,"
			. " returning '@ids' for uid '$uid'"
			. " num_needed '$num_needed' num_oldzone_needed '$num_oldzone_needed' num_normal_needed '$num_normal_needed'"
			. " (maybe out of mods to M2?)"
			. " already_had: " . Dumper($already_have_hr);
	}

	return \@ids;
}

########################################################
# ok, I was tired of trying to mold getDescriptions into 
# taking more args.
sub getTemplateList {
	my($self, $skin, $page) = @_;

	my $templatelist = {};
	my $where = "seclev <= " . getCurrentUser('seclev');
	$where .= " AND skin = '$skin'" if $skin;
	$where .= " AND page = '$page'" if $page;

	my $qlid = $self->_querylog_start("SELECT", "templates");
	my $sth = $self->sqlSelectMany('tpid,name', 'templates', $where); 
	while (my($tpid, $name) = $sth->fetchrow) {
		$templatelist->{$tpid} = $name;
	}
	$self->_querylog_finish($qlid);

	return $templatelist;
}

########################################################
sub countUserModsInDiscussion {
	my($self, $uid, $disc_id) = @_;
	my $uid_q = $self->sqlQuote($uid);
	my $disc_id_q = $self->sqlQuote($disc_id);
	return $self->sqlCount(
		"moderatorlog",
		"uid=$uid_q AND active=1 AND sid=$disc_id_q");
}

########################################################
sub getModeratorCommentLog {
	my($self, $asc_desc, $limit, $t, $value, $options) = @_;
	# $t tells us what type of data $value is, and what type of
	# information we're looking to retrieve
	$options ||= {};
	$asc_desc ||= 'ASC';
	$asc_desc = uc $asc_desc;
	$asc_desc = 'ASC' if $asc_desc ne 'DESC';
	my $order_col = $options->{order_col} || "ts";

	if ($limit and $limit =~ /^(\d+)$/) {
		$limit = "LIMIT $1";
	} else {
		$limit = "";
	}

	my $cidlist;
	if ($t eq "cidin") {
		if (ref $value eq "ARRAY" and @$value) {
			$cidlist = join(',', @$value);
		} elsif (!ref $value and $value) {
			$cidlist = $value;
		} else {
			return [];
		}
	}

	my $select_extra = (($t =~ /ipid/) || ($t =~ /subnetid/) || ($t =~ /global/))
		? ", comments.uid AS uid2, comments.ipid AS ipid2"
		: "";

	my $vq = $self->sqlQuote($value);
	my $where_clause = "";
	my $ipid_table = "moderatorlog";
	   if ($t eq 'uid')       { $where_clause = "comments.uid=users.uid AND     moderatorlog.uid=$vq";
				    $ipid_table = "comments"							    }
	elsif ($t eq 'cid')       { $where_clause = "moderatorlog.uid=users.uid AND moderatorlog.cid=$vq"	    }
	elsif ($t eq 'cuid')      { $where_clause = "moderatorlog.uid=users.uid AND moderatorlog.cuid=$vq"	    }
	elsif ($t eq 'cidin')     { $where_clause = "moderatorlog.uid=users.uid AND moderatorlog.cid IN ($cidlist)" }
	elsif ($t eq 'subnetid')  { $where_clause = "moderatorlog.uid=users.uid AND comments.subnetid=$vq"	    }
	elsif ($t eq 'ipid')      { $where_clause = "moderatorlog.uid=users.uid AND comments.ipid=$vq"		    }
	elsif ($t eq 'bsubnetid') { $where_clause = "moderatorlog.uid=users.uid AND moderatorlog.subnetid=$vq"	    }
	elsif ($t eq 'bipid')     { $where_clause = "moderatorlog.uid=users.uid AND moderatorlog.ipid=$vq"	    }
	elsif ($t eq 'global')    { $where_clause = "moderatorlog.uid=users.uid"				    }
	return [ ] unless $where_clause;

	my $time_clause = "";
	$time_clause = " AND ts > DATE_SUB(NOW(), INTERVAL $options->{hours_back} HOUR)" if $options->{hours_back};

	my $qlid = $self->_querylog_start("SELECT", "moderatorlog, users, comments");
	my $sth = $self->sqlSelectMany(
		"comments.sid AS sid,
		 comments.cid AS cid,
		 comments.pid AS pid,
		 comments.points AS score,
		 comments.karma AS karma,
		 comments.tweak AS tweak,
		 comments.tweak_orig AS tweak_orig,
		 users.uid AS uid,
		 users.nickname AS nickname,
		 $ipid_table.ipid AS ipid,
		 moderatorlog.val AS val,
		 moderatorlog.reason AS reason,
		 moderatorlog.ts AS ts,
		 moderatorlog.active AS active,
		 moderatorlog.m2status AS m2status,
		 moderatorlog.id AS id,
		 moderatorlog.points_orig AS points_orig 
		 $select_extra",
		"moderatorlog, users, comments",
		"$where_clause
		 AND moderatorlog.cid=comments.cid 
		 $time_clause",
		"ORDER BY $order_col $asc_desc $limit"
	);
	my(@comments, $comment,@ml_ids);
	while ($comment = $sth->fetchrow_hashref) {
		push @ml_ids, $comment->{id};
		push @comments, $comment;
	}
	$self->_querylog_finish($qlid);
	my $m2_fair = $self->getMetamodCountsForModsByType("fair", \@ml_ids);
	my $m2_unfair = $self->getMetamodCountsForModsByType("unfair", \@ml_ids);
	foreach my $c (@comments) {
		$c->{m2fair}   = $m2_fair->{$c->{id}}{count} || 0;
		$c->{m2unfair} = $m2_unfair->{$c->{id}}->{count} || 0;
	}
	return \@comments;
}

sub getMetamodCountsForModsByType {
	my($self, $type, $ids) = @_;
	my $id_str = join ',', @$ids;
	return {} unless @$ids;

	my($cols, $where);
	$cols = "mmid, COUNT(*) AS count";
	$where = "mmid IN ($id_str) AND active=1 ";
	if ($type eq "fair") {
		$where .= " AND val > 0 ";
	} elsif ($type eq "unfair") {
		$where .= " AND val < 0 ";
	}
	my $modcounts = $self->sqlSelectAllHashref('mmid',
		$cols,
		'metamodlog',
		$where,
		'GROUP BY mmid');
	return $modcounts;
}


# Given an arrayref of moderation ids, a hashref
# keyed by moderation ids is returned.  The moderation ids 
# point to arrays containing info metamoderations for that 
# particular moderation id.

sub getMetamodsForMods {
	my($self, $ids, $limit) = @_;
	my $id_str = join ',', @$ids;
	return {} unless @$ids;
	# If the limit param is missing or zero, all matching
	# rows are returned.
	$limit = " LIMIT $limit" if $limit;
	$limit ||= "";

	my $m2s = $self->sqlSelectAllHashrefArray(
		"id, mmid, metamodlog.uid AS uid, val, ts, active, nickname",
		"metamodlog, users",
		"mmid IN ($id_str) AND metamodlog.uid=users.uid",
		"ORDER BY mmid DESC $limit");

	my $mods_to_m2s = {};
	for my $m2 (@$m2s) {
		push @{$mods_to_m2s->{$m2->{mmid}}}, $m2;
	}
	return $mods_to_m2s;
}

########################################################
sub getMetamodlogForUser {
	my($self, $uid, $limit) = @_;
	my $uid_q = $self->sqlQuote($uid);
	my $limit_clause = $limit ? " LIMIT $limit" : "";
	my $m2s = $self->sqlSelectAllHashrefArray(
			"metamodlog.id, metamodlog.mmid, metamodlog.ts, metamodlog.val, metamodlog.active, 
			 comments.subject, comments.cid, comments.sid,  
			 moderatorlog.m2status, moderatorlog.reason, moderatorlog.val as modval",
			"metamodlog, moderatorlog, comments",
			"metamodlog.mmid = moderatorlog.id AND comments.cid = moderatorlog.cid AND metamodlog.uid = $uid_q ",
			"GROUP BY moderatorlog.cid, moderatorlog.reason ORDER BY moderatorlog.ts desc"
		  );
	my @m2_ids;
	foreach my $m (@$m2s) {
		push @m2_ids, $m->{mmid};
	}

	my $m2_fair = $self->getMetamodCountsForModsByType("fair", \@m2_ids);
	my $m2_unfair = $self->getMetamodCountsForModsByType("unfair", \@m2_ids);

	foreach my $m (@$m2s) {
		$m->{m2fair}   = $m2_fair->{$m->{mmid}}{count} || 0;
		$m->{m2unfair} = $m2_unfair->{$m->{mmid}}->{count} || 0;
	}

	return $m2s;
}

########################################################
sub getModeratorLogID {
	my($self, $cid, $uid) = @_;
	my($mid) = $self->sqlSelect("id", "moderatorlog",
		"uid=$uid AND cid=$cid");
	return $mid;
}

########################################################
sub undoModeration {
	my($self, $uid, $sid) = @_;
	my $constants = getCurrentStatic();

	# The chances of getting here when comments are slim 
	# since comment posting and moderation should be halted.  
	# Regardless check just in case.
	return [] unless dbAvailable("write_comments");

	# querylog isn't going to work for this sqlSelectMany, since
	# we do multiple other queries while the cursor runs over the
	# rows it returns.  So don't bother doing the _querylog_start.

	# SID here really refers to discussions.id, NOT stories.sid
	my $cursor = $self->sqlSelectMany("cid,val,active,cuid,reason",
			"moderatorlog",
			"moderatorlog.uid=$uid AND moderatorlog.sid=$sid"
	);

	my $min_score = $constants->{comment_minscore};
	my $max_score = $constants->{comment_maxscore};
	my $min_karma = $constants->{minkarma};
	my $max_karma = $constants->{maxkarma};

	my @removed;
	while (my($cid, $val, $active, $cuid, $reason) = $cursor->fetchrow){

		# If moderation wasn't actually performed, we skip ahead one.
		next if ! $active;

		# We undo moderation even for inactive records (but silently for
		# inactive ones...).  Leave them in the table but inactive, so
		# they are still eligible to be metamodded.
		$self->sqlUpdate("moderatorlog",
			{ active => 0 },
			"cid=$cid AND uid=$uid"
		);

		# Restore modded user's karma, again within the proper boundaries.
		my $adjust = -$val;
		$adjust =~ s/^([^+-])/+$1/;
		my $adjust_abs = abs($adjust);
		$self->sqlUpdate(
			"users_info",
			{ -karma =>	$adjust > 0
					? "LEAST($max_karma, karma $adjust)"
					: "GREATEST($min_karma, karma $adjust)" },
			"uid=$cuid"
		) unless isAnon($cuid);

		# Adjust the comment score up or down, but don't push it
		# beyond the maximum or minimum.  Also recalculate its reason.
		# Its pointsmax logically can't change.
		my $points = $adjust > 0
			? "LEAST($max_score, points $adjust)"
			: "GREATEST($min_score, points $adjust)";
		my $new_reason = $self->getCommentMostCommonReason($cid)
			|| 0; # no active moderations? reset reason to empty
		my $comm_update = {
			-points =>	$points,
			reason =>	$new_reason,
		};
		$self->sqlUpdate("comments", $comm_update, "cid=$cid");

		push @removed, {
			cid	=> $cid,
			reason	=> $reason,
			val	=> $val,
		};
	}

	return \@removed;
}

########################################################
# If no tid is given, returns the whole tree.  Otherwise,
# returns the data for the topic with that numeric id.
sub getTopicTree {
	my($self, $tid_wanted, $options) = @_;
	my $constants = getCurrentStatic();

	my $table_cache		= "_topictree_cache";
	my $table_cache_time	= "_topictree_cache_time";
	_genericCacheRefresh($self, 'topictree',
		$options->{no_cache} ? -1 : $constants->{block_expire}
	);
	if ($self->{$table_cache_time}) {
		if ($tid_wanted) {
			return $self->{$table_cache}{$tid_wanted} || undef;
		} else {
			return $self->{$table_cache};
		}
	}

	# Cache needs to be built, so build it.
	my $tree_ref = $self->{$table_cache} ||= {};
	my $topics = $self->sqlSelectAllHashref("tid", "*", "topics");
	my $topic_nexus = $self->sqlSelectAllHashref("tid", "*", "topic_nexus");
	my $topic_nexus_dirty = $self->sqlSelectAllHashref("tid", "*", "topic_nexus_dirty");
	my $topic_parents = $self->sqlSelectAllHashrefArray("*", "topic_parents");

	for my $tid (keys %$topics) {
		$tree_ref->{$tid} = $topics->{$tid};
	}
	for my $tid (keys %$topic_nexus) {
		$tree_ref->{$tid}{nexus} = 1;
		for my $key (keys %{$topic_nexus->{$tid}}) {
			$tree_ref->{$tid}{$key} = $topic_nexus->{$tid}{$key};
		}
	}
	for my $tid (keys %$topic_nexus_dirty) {
		$tree_ref->{$tid}{nexus_dirty} = 1;
	}
	for my $tp_hr (@$topic_parents) {
		my($parent, $child, $m_w) = @{$tp_hr}{qw( parent_tid tid min_weight )};
		$tree_ref->{$child}{parent}{$parent} = $m_w;
		$tree_ref->{$parent}{child}{$child} = $m_w;
	}
	for my $tid (keys %$tree_ref) {
		next unless exists $tree_ref->{$tid}{child};
		my $c_hr = $tree_ref->{$tid}{child};
		my @child_ids = sort {
			$tree_ref->{$a}{textname} cmp $tree_ref->{$b}{textname}
			||
			$tree_ref->{$a}{keyword} cmp $tree_ref->{$b}{keyword}
			||
			$a <=> $b
		} keys %$c_hr;
		$tree_ref->{$tid}{children} = [ @child_ids ];
	}

	my $skins = $self->getSkins();
	for my $skid (keys %$skins) {
		next unless $skins->{$skid}{nexus};
		$tree_ref->{$skins->{$skid}{nexus}}{skid} = $skid;
	}

	$self->{$table_cache} = $tree_ref;
	$self->{$table_cache_time} = time;
	if ($tid_wanted) {
		return $tree_ref->{$tid_wanted} || undef;
	} else {
		return $tree_ref;
	}
}

########################################################
# Given two topic IDs, returns 1 if the first is a parent
# (or grandparent, etc.) and 0 if it is not.  For this
# method's purposes, a topic is not a parent of itself.
# If an optional 'weight' is specified, all links followed
# must have a min_weight less than or equal to that weight.
# Or if an optional 'min_min_weight' is specified, all
# links followed must have a min_weight greater than or
# equal to it.  Both implies both, of course.
# XXXSECTIONTOPICS this could be cached for efficiency, no idea how much time that would save
sub isTopicParent {
	my($self, $parent, $child, $options) = @_;
	my $tree = $self->getTopicTree();
	return 0 unless $tree->{$parent} && $tree->{$child};
	return 0 if $parent == $child;

	my $max_min_weight = $options->{weight}         || 2**31-1;
	my $min_min_weight = $options->{min_min_weight} || 0;
	my @topics = ( $child );
	my %new_topics;
	while (@topics) {
		%new_topics = ( );
		for my $tid (@topics) {
			next unless $tree->{$tid}{parent};
			# This topic has one or more parents.  Add
			# them to the list we're following up, but
			# only if the link from this topic to the
			# parent does not specify a minimum weight
			# higher or lower than required.
			my $p_hr = $tree->{$tid}{parent};
			my @parents =
				grep { $p_hr->{$_} >= $min_min_weight }
				grep { $p_hr->{$_} <= $max_min_weight }
				keys %$p_hr;
			for my $p (@parents) {
				return 1 if $p == $parent;
				$new_topics{$p} = 1;
			}
		}
		@topics = keys %new_topics;
	}
	return 0;
}

########################################################
sub getNexusTids {
	my($self) = @_;
	my $tree = $self->getTopicTree();
	return grep { $tree->{$_}{nexus} } sort { $a <=> $b } keys %$tree;
}

########################################################
# Starting with $start_tid, which may or may not be a nexus,
# walk down all its child topics and return their tids.
# Note that the original tid, $start_tid, is not itself returned.
sub getAllChildrenTids {
	my($self, $start_tid) = @_;
	my $tree = $self->getTopicTree();
	my %all_children = ( );
	my @cur_children = ( $start_tid );
	my %grandchildren;
	while (@cur_children) {
		%grandchildren = ( );
		for my $child (@cur_children) {
			# This topic is a nexus, and a child of the
			# start nexus.  Note it so it gets returned.
			$all_children{$child} = 1;
			# Now walk through all its children, marking
			# nexuses as grandchildren that must be
			# walked through on the next pass.
			for my $gchild (keys %{$tree->{$child}{child}}) {
				$grandchildren{$gchild} = 1;
			}
		}
		@cur_children = keys %grandchildren;
	}
	delete $all_children{$start_tid};
	return sort { $a <=> $b } keys %all_children;
}

########################################################
# Starting with $start_tid, a nexus ID, walk down all its child nexuses
# and return their tids.  Note that the original tid, $start_tid, is
# not itself returned.
sub getNexusChildrenTids {
	my($self, $start_tid) = @_;
	my $tree = $self->getTopicTree();
	my %all_children = ( );
	my @cur_children = ( $start_tid );
	my %grandchildren;
	while (@cur_children) {
		%grandchildren = ( );
		for my $child (@cur_children) {
			# This topic is a nexus, and a child of the
			# start nexus.  Note it so it gets returned.
			$all_children{$child} = 1;
			# Now walk through all its children, marking
			# nexuses as grandchildren that must be
			# walked through on the next pass.
			for my $gchild (keys %{$tree->{$child}{child}}) {
				next unless $tree->{$gchild}{nexus};
				$grandchildren{$gchild} = 1;
			}
		}
		@cur_children = keys %grandchildren;
	}
	delete $all_children{$start_tid};
	return [ sort { $a <=> $b } keys %all_children ];
}

########################################################
sub deleteRelatedLink {
	my($self, $id) = @_;

	$self->sqlDelete("related_links", "id=$id");
}

########################################################
sub getNexusExtras {
	my($self, $tid) = @_;
	return [ ] unless $tid;

	my $tid_q = $self->sqlQuote($tid);
	my $answer = $self->sqlSelectAll(
		'extras_textname, extras_keyword, type',
		'topic_nexus_extras', 
		"tid = $tid_q"
	);

	return $answer;
}

########################################################
sub getNexuslistFromChosen {
	my($self, $chosen_hr) = @_;
	return [ ] unless $chosen_hr;
	my $rendered_hr = $self->renderTopics($chosen_hr);
	my @nexuses = $self->getNexusTids();
	@nexuses = grep { $rendered_hr->{$_} } @nexuses;
	return [ @nexuses ];
}

########################################################
# XXXSECTIONTOPICS we should remove duplicates from the list
# returned.  If 2 or more nexuses have the same extras_keyword,
# that keyword should only be returned once.
sub getNexusExtrasForChosen {
	my($self, $chosen_hr) = @_;
	return [ ] unless $chosen_hr;

	my $nexuses = $self->getNexuslistFromChosen($chosen_hr);
	my $seen_extras = {};
	my $extras = [ ];
	for my $nexusid (@$nexuses) {
		my $ex_ar = $self->getNexusExtras($nexusid);
		foreach my $extra (@$ex_ar) {
			unless ($seen_extras->{$extra->[1]}) {
				push @$extras, $extra;
				$seen_extras->{$extra->[1]}++;
			}
		}
	}
	
	return $extras;
}

########################################################
# There's still no interface for adding 'list' type extras.
# Maybe later.
sub setNexusExtras {
	my($self, $tid, $extras) = @_;
	return unless $tid;

	my $tid_q = $self->sqlQuote($tid);
	$self->sqlDelete("topic_nexus_extras", "tid=$tid_q");

	for (@{$extras}) {
		$self->sqlInsert('topic_nexus_extras', {
			tid		=> $tid,
			extras_keyword 	=> $_->[0],
			extras_textname	=> $_->[1],
			type		=> 'text',
		});
	}
}

sub setNexusCurrentQid {
	my($self, $nexus_id, $qid) = @_;
	return $self->sqlUpdate("topic_nexus", { current_qid => $qid }, "tid = $nexus_id");
}

########################################################
sub getSectionExtras {
	my($self, $section) = @_;
	errorLog("getSectionExtras called");
	return undef;
}


########################################################
sub setSectionExtras {
	my($self, $section, $extras) = @_;
	errorLog("setSectionExtras called");
	return undef;
}

########################################################
sub getContentFilters {
	my($self, $formname, $field) = @_;

	my $field_string = $field ne '' ? " AND field = '$field'" : " AND field != ''";

	my $filters = $self->sqlSelectAll("*", "content_filters",
		"regex != '' $field_string AND form = '$formname'");
	return $filters;
}

sub getCurrentQidForSkid {
	my($self, $skid) = @_;
	my $tree = $self->getTopicTree();
	my $nexus_id = $self->getNexusFromSkid($skid);
	my $nexus = $tree->{$nexus_id};
	return $nexus ? $nexus->{current_qid} : 0;
}


########################################################
sub createPollVoter {
	my($self, $qid, $aid) = @_;
	my $constants = getCurrentStatic();

	my $qid_quoted = $self->sqlQuote($qid);
	my $aid_quoted = $self->sqlQuote($aid);
	my $md5;
	if ($constants->{poll_fwdfor}) { 
		$md5 = md5_hex($ENV{REMOTE_ADDR} . $ENV{HTTP_X_FORWARDED_FOR});
	} else {
		$md5 = md5_hex($ENV{REMOTE_ADDR});
	}
	$self->sqlInsert("pollvoters", {
		qid	=> $qid,
		id	=> $md5,
		-'time'	=> 'NOW()',
		uid	=> $ENV{SLASH_USER}
	});

	$self->sqlUpdate("pollquestions", {
			-voters =>	'voters+1',
		}, "qid=$qid_quoted");
	$self->sqlUpdate("pollanswers", {
			-votes =>	'votes+1',
		}, "qid=$qid_quoted AND aid=$aid_quoted");
}

########################################################
sub createSubmission {
	my($self, $submission) = @_;

	return unless $submission && $submission->{story};

	my $constants = getCurrentStatic();
	my $data;
	$data->{story} = delete $submission->{story};
	$data->{subj} = delete $submission->{subj};
	$data->{ipid} = getCurrentUser('ipid');
	$data->{subnetid} = getCurrentUser('subnetid');
	$data->{email} ||= delete $submission->{email} || '';
	$data->{uid} ||= delete $submission->{uid} || getCurrentStatic('anonymous_coward_uid'); 
	$data->{'-time'} = delete $submission->{'time'};
	$data->{'-time'} ||= 'NOW()';
	$data->{primaryskid} = delete $submission->{primaryskid} || $constants->{mainpage_skid};
	$data->{tid} = delete $submission->{tid} || $constants->{mainpage_skid};
	# To help cut down on duplicates generated by automated routines. For
	# crapflooders, we will need to look into an alternate methods. 
	# Filters of some sort, maybe?
	$data->{signature} = md5_hex($data->{story});

	$self->sqlInsert('submissions', $data);
	my $subid = $self->getLastInsertId;

	# The next line makes sure that we get any section_extras in the DB - Brian
	$self->setSubmission($subid, $submission) if keys %$submission;

	return $subid;
}

########################################################
# Handles admin logins (checks the sessions table for a cookie that
# matches).  Called during authentication
sub getSessionInstance {
	my($self, $uid, $session_in) = @_;
	my $admin_timeout = getCurrentStatic('admin_timeout');
	my $session_out = '';

	if ($session_in) {
		$self->sqlDelete("sessions",
			"NOW() > DATE_ADD(lasttime, INTERVAL $admin_timeout MINUTE)"
		);

		my $session_in_q = $self->sqlQuote($session_in);

		my($uid) = $self->sqlSelect(
			'uid',
			'sessions',
			"session=$session_in_q"
		);

		if ($uid) {
			$self->sqlDelete("sessions",
				"uid = '$uid' AND session != $session_in_q"
			);
			$self->sqlUpdate('sessions',
				{ -lasttime => 'now()' },
				"session = $session_in_q"
			);
			$session_out = $session_in;
		}
	}
	if (!$session_out) {
		my($title, $last_sid, $last_subid) = $self->sqlSelect(
			'lasttitle, last_sid, last_subid', 
			'sessions',
			"uid=$uid"
		);
		$_ ||= '' for ($title, $last_sid, $last_subid);

		# Why not have sessions have UID be unique and use 
		# sqlReplace() here? Minor quibble, just curious.
		# - Cliff
		# We need the ID that was inserted, and I don't think
		# LAST_INSERT_ID() works for a REPLACE, or at least
		# it isn't documented that way. - Jamie
		# http://www.mysql.com/doc/en/mysql_insert_id.html
		$self->sqlDelete("sessions", "uid=$uid");
		$self->sqlInsert('sessions', {
			-uid		=> $uid,
			-logintime	=> 'NOW()',
			-lasttime	=> 'NOW()',
			lasttitle	=> $title,
			last_sid	=> $last_sid,
			last_subid	=> $last_subid
		});
		$session_out = $self->getLastInsertId({ table => 'sessions', prime => 'session' });
	}
	return $session_out;

}

########################################################
sub setContentFilter {
	my($self, $formname) = @_;

	my $form = getCurrentForm();
	$formname ||= $form->{formname};

	$self->sqlUpdate("content_filters", {
			regex		=> $form->{regex},
			form		=> $formname,
			modifier	=> $form->{modifier},
			field		=> $form->{field},
			ratio		=> $form->{ratio},
			minimum_match	=> $form->{minimum_match},
			minimum_length	=> $form->{minimum_length},
			err_message	=> $form->{err_message},
		}, "filter_id=$form->{filter_id}"
	);
}

########################################################
# This creates an entry in the accesslog
sub createAccessLog {
	my($self, $op, $dat, $status) = @_;
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $r = Apache->request;
	my $bytes = $r->bytes_sent; 

	$user ||= {};
	$user->{state} ||= {};
	
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	if ($op eq 'image' && $constants->{accesslog_imageregex}) {
		return if $constants->{accesslog_imageregex} eq 'NONE';
		my $uri = $r->uri;
#		print STDERR scalar(localtime) . " createAccessLog image url '" . ($r->uri) . "'\n";
		return unless $uri =~ $constants->{accesslog_imageregex};
		$dat ||= $uri;
	}

	my $uid;
	if ($ENV{SLASH_USER}) {
		$uid = $ENV{SLASH_USER};
	} else {
		$uid = $user->{uid} || $constants->{anonymous_coward_uid};
	}
	my $skin_name = getCurrentSkin('name');
	# XXXSKIN - i think these are no longer special cases ...
	# The following two are special cases
#	if ($op eq 'index' || $op eq 'article') {
#		$section = ($form && $form->{section})
#			? $form->{section}
#			: $constants->{section};
#	}

	my($ipid, $subnetid) = (getCurrentUser('ipid'), getCurrentUser('subnetid'));
	if (!$ipid || !$subnetid) {
		($ipid, $subnetid) = get_ipids($r->connection->remote_ip);
	}

	if ( $op eq 'index' && $dat =~ m|^([^/]*)| ) {
		my $firstword = $1;
		if ($reader->getSkidFromName($firstword)) {
			$skin_name = $firstword;
		}
	}

	if ($dat =~ /(.*)\/(\d{2}\/\d{2}\/\d{2}\/\d{4,7}).*/) {
		$dat = $2;
		$op = 'article';
		my $firstword = $1;
		if ($reader->getSkidFromName($firstword)) {
			$skin_name = $firstword;
		}
	}

	my $duration;
	if ($Slash::Apache::User::request_start_time) {
		$duration = Time::HiRes::time - $Slash::Apache::User::request_start_time;
		$Slash::Apache::User::request_start_time = 0;
		$duration = 0 if $duration < 0; # sanity check
	} else {
		$duration = 0;
	}
	my $local_addr = inet_ntoa(
		( unpack_sockaddr_in($r->connection()->local_addr()) )[1]
	);
	$status ||= $r->status;
	my $skid = $reader->getSkidFromName($skin_name);
	my $insert = {
		host_addr	=> $ipid,
		subnetid	=> $subnetid,
		dat		=> $dat,
		uid		=> $uid,
		skid		=> $skid,
		bytes		=> $bytes,
		op		=> $op,
		-ts		=> 'NOW()',
		query_string	=> $ENV{QUERY_STRING} || 'none',
		user_agent	=> $ENV{HTTP_USER_AGENT} || 'undefined',
		duration	=> $duration,
		local_addr	=> $local_addr,
		static		=> $user->{state}{_dynamic_page} ? 'no' : 'yes',
		secure		=> $user->{state}{ssl} || 0,
		referer		=> $r->header_in("Referer"),
		status		=> $status,
	};
	return if !$user->{is_admin} && $constants->{accesslog_disable};
	if ($constants->{accesslog_insert_cachesize} && !$user->{is_admin}) {
		# Save up multiple accesslog inserts until we can do them all at once.
		push @{$self->{_accesslog_insert_cache}}, $insert;
		my $size = scalar(@{$self->{_accesslog_insert_cache}});
		if ($size >= $constants->{accesslog_insert_cachesize}) {
			$self->_writeAccessLogCache;
		}
	} else {
		$self->sqlInsert('accesslog', $insert, { delayed => 1 });
	}
}

sub _writeAccessLogCache {
	my($self) = @_;
	return unless ref($self->{_accesslog_insert_cache})
		&& @{$self->{_accesslog_insert_cache}};
#	$self->{_dbh}{AutoCommit} = 0;
	$self->sqlDo("SET AUTOCOMMIT=0");
	while (my $hr = shift @{$self->{_accesslog_insert_cache}}) {
		$self->sqlInsert('accesslog', $hr, { delayed => 1 });
	}
#	$self->{_dbh}->commit;
#	$self->{_dbh}{AutoCommit} = 1;
	$self->sqlDo("COMMIT");
	$self->sqlDo("SET AUTOCOMMIT=1");
}

##########################################################
# This creates an entry in the accesslog for admins -Brian
sub createAccessLogAdmin {
	my($self, $op, $dat, $status) = @_;
	return if $op =~ /^images?$/;
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $r = Apache->request;

	# $ENV{SLASH_USER} wasn't working, was giving us some failed inserts
	# with uid NULL.
	my $uid = $user->{uid};
	my $gSkin = getCurrentSkin();
	errorLog("gSkin is empty") unless $gSkin;
	my $skid = $gSkin->{skid} || 0;
#	# XXXSKIN - i think these are no longer special cases ...
#	# The following two are special cases
#	if ($op eq 'index' || $op eq 'article') {
#		$section = ($form && $form->{section})
#			? $form->{section}
#			: $constants->{section};
#	}
	# And just what was the admin doing? -Brian
	$op = $form->{op} if $form->{op};
	$status ||= $r->status;

	$self->sqlInsert('accesslog_admin', {
		host_addr	=> $r->connection->remote_ip,
		dat		=> $dat,
		uid		=> $uid,
		skid		=> $skid,
		bytes		=> $r->bytes_sent,
		op		=> $op,
		form		=> freeze($form),
		-ts		=> 'NOW()',
		query_string	=> $ENV{QUERY_STRING} || '0',
		user_agent	=> $ENV{HTTP_USER_AGENT} || '0',
		secure		=> Slash::Apache::ConnectionIsSecure(),
		status		=> $status,
	}, { delayed => 1 });
}


########################################################
# pass in additional optional descriptions
sub getDescriptions {
	my($self, $codetype, $optional, $flag, $altdescs) =  @_;
	return unless $codetype;
	my $codeBank_hash_ref = {};
	$optional ||= '';
	$altdescs ||= '';

	# I am extending this, without the extension the cache was
	# not always returning the right data -Brian
	my $cache = '_getDescriptions_' . $codetype . $optional . $altdescs;

	if ($flag) {
		undef $self->{$cache};
	} else {
		return $self->{$cache} if $self->{$cache};
	}

	$altdescs ||= {};
	my $descref = $altdescs->{$codetype} || $descriptions{$codetype};
	if (!$descref) { errorLog("getDescriptions - no descref for codetype '$codetype'") }
	return $codeBank_hash_ref unless $descref;

	# I don't really feel like editing the entire %descriptions hash to
	# list each table with each codetype, so for now at least, I'm just
	# lumping all them together.  Which seems to be fine because on the
	# sites whose querylogs we've examined so far, 'descriptions'
	# accounts for, as you might expect, a miniscule amount of DB traffic.
	my $qlid = $self->_querylog_start('SELECT', 'descriptions');
	my $sth = $descref->(@_);
	return { } if !$sth;

	# allow $descref to return a hashref, instead of a statement handle
	if (ref($sth) =~ /::st$/) {
		while (my($id, $desc) = $sth->fetchrow) {
			$codeBank_hash_ref->{$id} = $desc;
		}
		$sth->finish;
	} else {
		@{$codeBank_hash_ref}{keys %$sth} = values %$sth;
	}

	$self->_querylog_finish($qlid);

	$self->{$cache} = $codeBank_hash_ref if getCurrentStatic('cache_enabled');
	return $codeBank_hash_ref;
}

########################################################
sub deleteUser {
	my($self, $uid) = @_;
	return unless $uid;
	$self->setUser($uid, {
		bio		=> '',
		nickname	=> 'deleted user',
		matchname	=> 'deleted user',
		realname	=> 'deleted user',
		realemail	=> '',
		fakeemail	=> '',
		newpasswd	=> '',
		homepage	=> '',
		passwd		=> '',
		people		=> '',
		sig		=> '',
		seclev		=> 0
	});
	my $rows = $self->sqlDelete("users_param", "uid=$uid");
	$self->setUser_delete_memcached($uid);
	return $rows;
}

########################################################
# Get user info from the users table.
sub getUserAuthenticate {
	my($self, $uid_try, $passwd, $kind, $temp_ok) = @_;
	my($newpass, $cookpasswd);

	return undef unless $uid_try && $passwd;

	# if $kind is 1, then only try to auth password as plaintext
	# if $kind is 2, then only try to auth password as encrypted
	# if $kind is 3, then only try to auth user with logtoken
	# if $kind is undef or 0, try as logtoken (the most common case),
	#	then encrypted, then as plaintext
	my($EITHER, $PLAIN, $ENCRYPTED, $LOGTOKEN) = (0, 1, 2, 3);
	my($UID, $PASSWD, $NEWPASSWD) = (0, 1, 2);
	$kind ||= $EITHER;

	my $uid_try_q = $self->sqlQuote($uid_try);
	my $uid_verified = 0;

	if ($kind == $LOGTOKEN || $kind == $EITHER) {
		# get existing logtoken, if exists
		if ($passwd eq $self->getLogToken($uid_try) || (
			$temp_ok && $passwd eq $self->getLogToken($uid_try, 0, 1)
		)) {
			$uid_verified = $uid_try;
			$cookpasswd = $passwd;
		}

	}

	if ($kind != $LOGTOKEN && !$uid_verified) {
		my $cryptpasswd = encryptPassword($passwd);
		my @pass = $self->sqlSelect(
			'uid,passwd,newpasswd',
			'users',
			"uid=$uid_try_q"
		);

		# try ENCRYPTED -> ENCRYPTED
		if ($kind == $EITHER || $kind == $ENCRYPTED) {
			if ($passwd eq $pass[$PASSWD]) {
				$uid_verified = $pass[$UID];
				# get existing logtoken, if exists, or new one
				$cookpasswd = $self->getLogToken($uid_verified, 1);
			}
		}

		# try PLAINTEXT -> ENCRYPTED
		if (($kind == $EITHER || $kind == $PLAIN) && !$uid_verified) {
			if ($cryptpasswd eq $pass[$PASSWD]) {
				$uid_verified = $pass[$UID];
				# get existing logtoken, if exists, or new one
				$cookpasswd = $self->getLogToken($uid_verified, 1);
			}
		}

		# try PLAINTEXT -> NEWPASS
		if (($kind == $EITHER || $kind == $PLAIN) && !$uid_verified) {
			if ($passwd eq $pass[$NEWPASSWD]) {
				$self->sqlUpdate('users', {
					newpasswd	=> '',
					passwd		=> $cryptpasswd
				}, "uid=$uid_try_q");
				$newpass = 1;

				$uid_verified = $pass[$UID];
				# delete existing logtokens
				$self->deleteLogToken($uid_verified, 1);
				# create new logtoken
				$cookpasswd = $self->setLogToken($uid_verified);
			}
		}
	}

	# If we tried to authenticate and failed, log this attempt to
	# the badpasswords table.
	if (!$uid_verified) {
		$self->createBadPasswordLog($uid_try, $passwd);
	}

	# return UID alone in scalar context
	return wantarray ? ($uid_verified, $cookpasswd, $newpass) : $uid_verified;
}

########################################################
# Log a bad password in a login attempt.
sub createBadPasswordLog {
	my($self, $uid, $password_wrong) = @_;
	my $constants = getCurrentStatic();

	# Failed login attempts as the anonymous coward don't count.
	return if !$uid || $uid == $constants->{anonymous_coward_uid};

	# Bad passwords that don't come through the web,
	# we don't bother to log.
	my $r = Apache->request;
	return unless $r;

	# We also store the realemail field of the actual user account
	# at the time the password was tried, so later, if the password
	# is cracked and the account stolen, there is a record of who
	# the real owner is.
	my $realemail = $self->getUser($uid, 'realemail') || '';

	my($ip, $subnet) = get_ipids($r->connection->remote_ip, 1);
	$self->sqlInsert("badpasswords", {
		uid =>          $uid,
		password =>     $password_wrong,
		ip =>           $ip,
		subnet =>       $subnet,
		realemail =>	$realemail,
	} );

	my $warn_limit = $constants->{bad_password_warn_user_limit} || 0;
	my $bp_count = $self->getBadPasswordCountByUID($uid);

	# We only warn a user at the Xth bad password attempt.  We don't want to
	# generate a message for every bad attempt over a threshold
	if ($bp_count && $bp_count == $warn_limit) {

		my $messages = getObject("Slash::Messages");
		return unless $messages;
		my $users = $messages->checkMessageCodes(
			MSG_CODE_BADPASSWORD, [$uid]
		);
		if (@$users) {
			my $uid_q = $self->sqlQuote($uid);
			my $nick = $self->sqlSelect("nickname", "users", "uid=$uid_q");
			my $bp = $self->getBadPasswordIPsByUID($uid);
			my $data  = {
				template_name =>	'badpassword_msg',
				subject =>		'Bad login attempts warning',
				nickname =>		$nick,
				uid =>			$uid,
				bp_count =>		$bp_count,
				bp_ips =>		$bp
			};

			$messages->create($users->[0],
				MSG_CODE_BADPASSWORD, $data, 0, '', 'now'
			);
		}
	}
}

########################################################
sub getBadPasswordsByUID {
	my($self, $uid) = @_;
	my $uid_q = $self->sqlQuote($uid);
	my $ar = $self->sqlSelectAllHashrefArray(
		"ip, password, DATE_FORMAT(ts, '%Y-%m-%d %h:%i:%s') AS ts",
		"badpasswords",
		"uid=$uid_q AND ts > DATE_SUB(NOW(), INTERVAL 1 DAY)");
	return $ar;
}

########################################################
sub getBadPasswordCountByUID {
	my($self, $uid) = @_;
	my $uid_q = $self->sqlQuote($uid);
	return $self->sqlCount("badpasswords",
		"uid=$uid_q AND ts > DATE_SUB(NOW(), INTERVAL 1 DAY)");
}

########################################################
sub getBadPasswordIPsByUID {
	my($self, $uid) = @_;
	my $uid_q = $self->sqlQuote($uid);
	my $ar = $self->sqlSelectAllHashrefArray(
		"ip, COUNT(*) AS c,
		 MIN(DATE_FORMAT(ts, '%Y-%m-%d %h:%i:%s')) AS mints,
		 MAX(DATE_FORMAT(ts, '%Y-%m-%d %h:%i:%s')) AS maxts",
		"badpasswords",
		"uid=$uid_q AND ts > DATE_SUB(NOW(), INTERVAL 1 DAY)",
		"GROUP BY ip ORDER BY c DESC");
}

########################################################
# Make a new password, save it in the DB, and return it.
sub getNewPasswd {
	my($self, $uid) = @_;
	my $newpasswd = changePassword();
	$self->sqlUpdate('users', {
		newpasswd => $newpasswd
	}, 'uid=' . $self->sqlQuote($uid));
	return $newpasswd;
}

########################################################
# reset's a user's account forcing them to get the
# new password via their registered mail account.  
sub resetUserAccount {
	my($self, $uid) = @_;
	my $newpasswd = changePassword();
	$self->sqlUpdate('users', {
		newpasswd => $newpasswd,
		passwd	  => encryptPassword($newpasswd)
	}, 'uid=' . $self->sqlQuote($uid));
	return $newpasswd;
}

########################################################
# get proper cookie location
sub _getLogTokenCookieLocation {
	my($self, $uid) = @_;
	my $user = getCurrentUser();

	my $temp_str = $user->{state}{login_temp} || 'no';

	my $cookie_location = $temp_str eq 'yes'
		? 'classbid'
		: $self->getUser($uid, 'cookie_location');
	my $locationid = get_ipids('', '', $cookie_location);
	return($locationid, $temp_str);
}

########################################################
# Get a logtoken from the DB, or create a new one
sub getLogToken {
	my($self, $uid, $new, $force_temp) = @_;

	my $uid_q = $self->sqlQuote($uid);

	# set the temp value for login_temp, if forced
	my $user = getCurrentUser();
	my $temp = $user->{state}{login_temp};
	$user->{state}{login_temp} = 'yes' if $temp eq 'no' && $force_temp;

	my($locationid, $temp_str) = $self->_getLogTokenCookieLocation($uid);

	my $where = "uid=$uid_q AND " .
	            "locationid='$locationid' AND " .
	            "temp='$temp_str'";

	my $value = $self->sqlSelect(
		'value', 'users_logtokens',
		$where . ' AND expires >= NOW()'
	);

	# reset the temp value for login_temp, if forced
	$user->{state}{login_temp} = 'no' if $temp eq 'no' && $force_temp && !$value;

	# bump expiration for temp logins
	if ($value && $temp_str eq 'yes') {
		my $minutes = getCurrentStatic('login_temp_minutes');
		$self->sqlUpdate('users_logtokens', {
			-expires 	=> "DATE_ADD(NOW(), INTERVAL $minutes MINUTE)"
		}, $where);
	}

	# if $new, then create a new value if none exists
	$value ||= $self->setLogToken($uid) if $new;

	return $value;
}

########################################################
# Make a new logtoken, save it in the DB, and return it 
sub setLogToken {
	my($self, $uid) = @_;

	my $logtoken = createLogToken();
	my($locationid, $temp_str) = $self->_getLogTokenCookieLocation($uid);

	my $interval = '1 YEAR';
	if ($temp_str eq 'yes') {
		my $minutes = getCurrentStatic('login_temp_minutes');
		$interval = "$minutes MINUTE";
	}

	$self->sqlReplace('users_logtokens', {
		uid		=> $uid,
		value		=> $logtoken,
		locationid	=> $locationid,
		temp		=> $temp_str,
		-expires 	=> "DATE_ADD(NOW(), INTERVAL $interval)"
	});
	return $logtoken;
}

########################################################
# Delete logtoken(s)
sub deleteLogToken {
	my($self, $uid, $all) = @_;

	my $uid_q = $self->sqlQuote($uid);
	my $where = "uid=$uid_q";

	if (!$all) {
		my($locationid, $temp_str) = $self->_getLogTokenCookieLocation($uid);
		$where .= " AND locationid='$locationid' AND temp='$temp_str'";
	}

	$self->sqlDelete('users_logtokens', $where);
}

########################################################
# Get user info from the users table.
# May be worth it to cache this at some point
sub getUserUID {
	my($self, $name) = @_;

# We may want to add BINARY to this. -Brian
#
# The concern is that MySQL's "=" matches text chars that are not
# bit-for-bit equal, e.g. a-umlaut may "=" a, but that BINARY
# matching is apparently significantly slower than non-BINARY.
# Adding the ORDER at least makes the results predictable so this
# is not exploitable -- no one can add a later account that will
# make an earlier one inaccessible.  A better method would be to
# grab all uid/nicknames that MySQL thinks match, and then to
# compare them (in order) in perl until a real bit-for-bit match
# is found. -jamie
# Actually there is a way to optimize a table for binary searches
# I believe -Brian

	my($uid) = $self->sqlSelect(
		'uid',
		'users',
		'nickname=' . $self->sqlQuote($name),
		'ORDER BY uid ASC'
	);

	return $uid;
}

########################################################
# Get user info from the users table with email address.
# May be worth it to cache this at some point
sub getUserEmail {
	my($self, $email) = @_;

	my($uid) = $self->sqlSelect('uid', 'users',
		'realemail=' . $self->sqlQuote($email)
	);

	return $uid;
}


#################################################################
# Corrected all of the above (those messages will go away soon.
# -Brian, Tue Jan 21 14:49:30 PST 2003
# 
sub getCommentsByGeneric {
	my($self, $where_clause, $num, $min, $options) = @_;
	$options ||= {};
	$min ||= 0;
	my $limit = " LIMIT $min, $num " if $num;
	my $force_index = "";
	$force_index = " FORCE INDEX(uid_date) " if $options->{force_index};
	
	$where_clause = "($where_clause) AND date > DATE_SUB(NOW(), INTERVAL $options->{limit_days} DAY)"
		if $options->{limit_days};
	$where_clause .= " AND cid >= $options->{cid_at_or_after} " if $options->{cid_at_or_after};
	my $sort_field = $options->{sort_field} || "date";
	my $sort_dir = $options->{sort_dir} || "DESC";

	my $comments = $self->sqlSelectAllHashrefArray(
		'*', "comments $force_index", $where_clause,
		"ORDER BY $sort_field $sort_dir $limit");

	return $comments;
}

#################################################################
sub getCommentsByUID {
	my($self, $uid, $num, $min, $options) = @_;
	my $constants = getCurrentStatic();
	$options ||= {};
	$options->{force_index} = 1 if $constants->{user_comments_force_index};
	return $self->getCommentsByGeneric("uid=$uid", $num, $min, $options);
}

#################################################################
sub getCommentsByIPID {
	my($self, $id, $num, $min, $options) = @_;
	return $self->getCommentsByGeneric("ipid='$id'", $num, $min, $options);
}

#################################################################
sub getCommentsBySubnetID {
	my($self, $id, $num, $min, $options) = @_;
	return $self->getCommentsByGeneric("subnetid='$id'", $num, $min, $options);
}

#################################################################
# Avoid using this one unless absolutely necessary;  if you know
# whether you have an IPID or a SubnetID, those queries take a
# fraction of a second, but this "OR" is a table scan.
sub getCommentsByIPIDOrSubnetID {
	my($self, $id, $num, $min, $options) = @_;
	my $constants = getCurrentStatic();
	my $where = "(ipid='$id' OR subnetid='$id') ";
	$where .= " AND cid >= $constants->{comments_forgetip_mincid} " if $constants->{comments_forgetip_mincid};
	return $self->getCommentsByGeneric(
	       $where, $num, $min, $options);
}


#################################################################
# Get list of DBs, original plan: never cache
# Now (July 2003) the plan is that we want to cache this lightly.
# At one call to this method per click, this select ends up being
# pretty expensive despite its small data return size and despite
# its having a near-100% hit rate in MySQL 4.x's query cache.
# Since we only update the dbs table with a periodic check anyway,
# we're never going to get an _instantaneous_ failover from reader
# to writer, so caching this just makes failover slightly _less_
# immediate.  I can live with that.  - Jamie 2003/07/24

{ # closure surrounding getDBs and getDB

# shared between sites, not a big deal
my $_getDBs_cached_nextcheck;
sub getDBs {
	my($self) = @_;

	my %databases;
	my $cache = getCurrentCache();
	if ($cache->{'dbs'} && (($_getDBs_cached_nextcheck || 0) > time)) {
		%databases = %{ $cache->{'dbs'} };
#		print STDERR gmtime() . " $$ getDBs returning cache"
#			. " time='" . time . "'"
#			. " nextcheck in " . ($_getDBs_cached_nextcheck - time) . " secs\n";
		return \%databases;
	}
	my $dbs = $self->sqlSelectAllHashref('id', '*', 'dbs');

	# rearrange to list by "type"
	for (keys %$dbs) {
		my $db = $dbs->{$_};
		$databases{$db->{type}} ||= [];
		push @{$databases{$db->{type}}}, $db;
	}

	# The amount of time to cache this has to be hardcoded,
	# since we obviously aren't able to get it from the DB
	# at this level.  Adjust to taste.  Assuming you have an
	# angel script, this should be roughly similar to how
	# often that angel runs.
	$_getDBs_cached_nextcheck = time + 10;
	$cache->{'dbs'} = \%databases;
#	print STDERR gmtime() . " $$ getDBs setting cache\n";

	return \%databases;
}

#################################################################
# get virtual user of a db type, for use when $user->{state}{dbs}
# not filled in
sub getDB {
	my($self, $db_type) = @_;

	my $cache = getCurrentCache();
	if ($cache->{'dbs'} && (($_getDBs_cached_nextcheck || 0) > time)) {
		my $vu_ar = $cache->{'dbs'}{$db_type};
#		print STDERR gmtime() . " $$ getDB returning cache for '$db_type'"
#			. " time='" . time . "'"
#			. " nextcheck in " . ($_getDBs_cached_nextcheck - time) . " secs\n";
		return "" if !$vu_ar || !@$vu_ar;
		return $vu_ar->[ rand @$vu_ar ];
	}

	my $users = $self->sqlSelectColArrayref('virtual_user', 'dbs',
		'type=' . $self->sqlQuote($db_type) . " AND isalive='yes'");
	return $users->[rand @$users];
}

} # end closure surrounding getDBs and getDB

#################################################################
# get list of DBs, never cache
# (do caching in getSlashConf)
sub getClasses {
	my($self) = @_;
	my $classes = $self->sqlSelectAllHashref('class', '*', 'classes');
	return $classes;
}

#################################################################
# Just create an empty content_filter
sub createContentFilter {
	my($self, $formname) = @_;

	$self->sqlInsert("content_filters", {
		regex		=> '',
		form		=> $formname,
		modifier	=> '',
		field		=> '',
		ratio		=> 0,
		minimum_match	=> 0,
		minimum_length	=> 0,
		err_message	=> ''
	});

	my $filter_id = $self->getLastInsertId({ table => 'content_filters', prime => 'filter_id' });

	return $filter_id;
}

sub existsEmail {
	my($self, $email) = @_;

	# Returns count of users matching $email.
	return ($self->sqlSelect('uid', 'users',
		'realemail=' . $self->sqlQuote($email)))[0];
}

#################################################################
# Replication issue. This needs to be a two-phase commit.
# Ok, this is now a transaction. This means that if we lose the DB
# while this is going on, we won't end up with a half created user.
# -Brian
sub createUser {
	my($self, $matchname, $email, $newuser) = @_;
	return unless $matchname && $email && $newuser;

	$email =~ s/\s//g; # strip whitespace from emails

	return if ($self->sqlSelect(
		"uid", "users",
		"matchname=" . $self->sqlQuote($matchname)
	))[0] || $self->existsEmail($email);

#	$self->{_dbh}{AutoCommit} = 0;
	$self->sqlDo("SET AUTOCOMMIT=0");

	$self->sqlInsert("users", {
		uid		=> '',
		realemail	=> $email,
		nickname	=> $newuser,
		matchname	=> $matchname,
		seclev		=> 1,
		passwd		=> encryptPassword(changePassword())
	});

	my $uid = $self->getLastInsertId({ table => 'users', prime => 'uid' });
	unless ($uid) {
#		$self->{_dbh}->rollback;
#		$self->{_dbh}{AutoCommit} = 1;
		$self->sqlDo("ROLLBACK");
		$self->sqlDo("SET AUTOCOMMIT=1");
	}
	return unless $uid;
	$self->sqlInsert("users_info", {
		uid 			=> $uid,
		-lastaccess		=> 'now()',
		-created_at		=> 'now()',
	});
	$self->sqlInsert("users_prefs", { uid => $uid });
	$self->sqlInsert("users_comments", { uid => $uid });
	$self->sqlInsert("users_index", { uid => $uid });
	$self->sqlInsert("users_hits", { uid => $uid });

	# All param fields should be set here, as some code may not behave
	# properly if the values don't exist.
	#
	# You know, I know this might be slow, but maybe this thing could be
	# initialized by a template? Wild thought, but that would prevent
	# site admins from having to edit CODE to set this stuff up.
	#
	#	- Cliff
	# Initialize the expiry variables...
	# ...users start out as registered...
	my $constants = getCurrentStatic();

	my $initdomain = fullhost_to_domain($email);
	$self->setUser($uid, {
		'registered'		=> 1,
		'expiry_comm'		=> $constants->{min_expiry_comm},
		'expiry_days'		=> $constants->{min_expiry_days},
		'user_expiry_comm'	=> $constants->{min_expiry_comm},
		'user_expiry_days'	=> $constants->{min_expiry_days},
		initdomain		=> $initdomain,
		created_ipid		=> getCurrentUser('ipid'),
	});

#	$self->{_dbh}->commit;
#	$self->{_dbh}{AutoCommit} = 1;
	$self->sqlDo("COMMIT");
	$self->sqlDo("SET AUTOCOMMIT=1");

	$self->sqlInsert("users_count", { uid => $uid });

	$self->setUser_delete_memcached($uid);

	return $uid;
}


########################################################
sub setVar {
	my($self, $name, $value) = @_;
	my $name_q = $self->sqlQuote($name);
	my $retval;
	if (ref $value) {
		my $update = { };
		for my $k (qw( value description )) {
			$update->{$k} = $value->{$k} if defined $value->{$k};
		}
		return 0 unless $update;
		$retval = $self->sqlUpdate('vars', $update, "name=$name_q");
	} else {
		$retval = $self->sqlUpdate('vars', {
			value		=> $value
		}, "name=$name_q");
	}
	return $retval;
}

########################################################
sub setSession {
	my($self, $name, $value) = @_;
	$self->sqlUpdate('sessions', $value, 'uid=' . $self->sqlQuote($name));
}

########################################################
sub setBlock {
	_genericSet('blocks', 'bid', '', @_);
}

########################################################
sub setRelatedLink {
	_genericSet('related_links', 'id', '', @_);
}

########################################################
sub setDiscussion {
	_genericSet('discussions', 'id', '', @_);
}

########################################################
sub setDiscussionBySid {
	_genericSet('discussions', 'sid', '', @_);
}

########################################################
sub setPollQuestion {
	_genericSet('pollquestions', 'qid', '', @_);
}

########################################################
sub setTemplate {
	my($self, $tpid, $hash) = @_;
	# Instructions don't get passed to the DB.
	delete $hash->{instructions};
	# Nor does a version (yet).
	delete $hash->{version};

	for (qw| page name skin |) {
		next unless $hash->{$_};
		if ($hash->{$_} =~ /;/) {
			errorLog("Semicolon found, $_='$hash->{$_}', setTemplate aborted");
			return;
		}
	}
	_genericSet('templates', 'tpid', '', @_);
}

########################################################
sub getCommentChildren {
	my($self, $cid) = @_;
	my($scid) = $self->sqlSelectAll('cid', 'comments', "pid=$cid");

	return $scid;
}

########################################################
# Does what it says, deletes one comment.
# For optimization's sake (not that Slashdot really deletes a lot of
# comments, currently one every four years!) commentcount and hitparade
# are updated from comments.pl's delete() function.
sub deleteComment {
	my($self, $cid, $discussion_id) = @_;
	my @comment_tables = qw( comment_text comments );
	# We have to update the discussion, so make sure we have its id.
	if (!$discussion_id) {
		($discussion_id) = $self->sqlSelect("sid", 'comments', "cid=$cid");
	}
	my $total_rows = 0;
	for my $table (@comment_tables) {
		$total_rows += $self->sqlDelete($table, "cid=$cid");
	}
	$self->deleteModeratorlog({ cid => $cid });
	if ($total_rows != scalar(@comment_tables)) {
		# Here is the thing, an orphaned comment with no text blob
		# would fuck up the comment count.
		# Bad juju, no cookie -Brian
		errorLog("deleteComment cid $cid from $discussion_id,"
			. " only $total_rows deletions");
		return 0;
	}
	return 1;
}

########################################################
sub deleteModeratorlog {
	my($self, $opts) = @_;
	my $where;

	if ($opts->{cid}) {
		$where = 'cid=' . $self->sqlQuote($opts->{cid});
	} elsif ($opts->{sid}) {
		$where = 'sid=' . $self->sqlQuote($opts->{sid});
	} else {
		return;
	}

	my $mmids = $self->sqlSelectColArrayref(
		'id', 'moderatorlog', $where
	);
	return unless @$mmids;

	my $mmid_in = join ',', @$mmids;
	# Delete from metamodlog first since (if built correctly) that
	# table has a FOREIGN KEY constraint pointing to moderatorlog.
	$self->sqlDelete('metamodlog', "mmid IN ($mmid_in)");
	$self->sqlDelete('moderatorlog', $where);
}

########################################################
sub getCommentPid {
	my($self, $sid, $cid) = @_;

	$self->sqlSelect('pid', 'comments', "sid='$sid' AND cid=$cid");
}

########################################################
# This has been grandfathered in to the new section-topics regime
# because it's fairly important.  Ultimately this should go away
# because we want to start asking "is this story in THIS nexus,"
# not "is it viewable anywhere on the site."  But as long as it
# is still around, try to make it work retroactively. - Jamie 2004/05
# XXXSECTIONTOPICS get rid of this eventually
# If no $start_tid is passed in, this will return "sectional" stories
# as viewable, i.e. a story in _any_ nexus will be viewable.
sub checkStoryViewable {
	my($self, $sid, $start_tid, $options) = @_;
	return unless $sid;

	# If there is no sid in the DB, assume that it is an old poll
	# or something that has a "fake" sid, which are always
	# "viewable."  When we fully integrate user-created discussions
	# and polls into the tid/nexus system, this can go away.
	# Also at the same time, convert sid into stoid.
	my $stoid = $self->getStoidFromSidOrStoid($sid);
	return 0 unless $stoid;

	return 0 if $self->sqlCount(
		"story_param",
		"stoid = '$stoid' AND name='neverdisplay' AND value > 0");

	my @nexuses;
	if ($start_tid) {
		push @nexuses, $start_tid;
	} else {
		@nexuses = $self->getNexusTids();
	}
	my $nexus_clause = join ',', @nexuses;

	# If stories.time is not involved, this goes very fast;  we
	# just look for rows in a single table, and either they're
	# there or not.
	if ($options->{no_time_restrict}) {
		my $count = $self->sqlCount(
			"story_topics_rendered",
			"stoid = '$stoid' AND tid IN ($nexus_clause)");
		return $count > 0 ? 1 : 0;
	}

	# We need to look at stories.time, so this is a join.

	$options ||= {};
	my($column_time, $where_time) = $self->_stories_time_clauses({
		try_future => 1, must_be_subscriber => 1
	});

	my $time_clause  = $options->{no_time_restrict} ? "" : " AND $where_time";

	my $count = $self->sqlCount(
		"stories, story_topics_rendered",
		"stories.stoid = '$stoid'
		 AND stories.stoid = story_topics_rendered.stoid 
		 AND story_topics_rendered.tid IN ($nexus_clause) 
		 $time_clause",
	);
	return $count >= 1 ? 1 : 0;
}

sub checkStoryInNexus {
	my($self, $stoid, $nexus_tid) = @_;
	my $stoid_q = $self->sqlQuote($stoid);
	my $tid_q = $self->sqlQuote($nexus_tid);
	return $self->sqlCount("story_topics_rendered",
		"stoid=$stoid AND tid=$tid_q");
}

########################################################
# Returns 1 if and only if a discussion is viewable only to subscribers
# (and admins).
sub checkDiscussionIsInFuture {
	my($self, $discussion) = @_;
	return 0 unless $discussion && $discussion->{sid};
	my($column_time, $where_time) = $self->_stories_time_clauses({
		try_future =>		1,
		must_be_subscriber =>	0,
		column_name =>		"ts",
	});
	my $count = $self->sqlCount(
		'discussions',
		"id='$discussion->{id}' AND type != 'archived'
		 AND $where_time
		 AND ts >= NOW()"
	);
	return $count;
}

########################################################
# Ugly yes, needed at the moment, yes
# $id is a discussion id. -Brian
sub checkDiscussionPostable {
	my($self, $id) = @_;
	return 0 unless $id;
	my $constants = getCurrentStatic();

	# This should do it. 
	my($column_time, $where_time) = $self->_stories_time_clauses({
		try_future =>		$constants->{subscribe_future_post},
		must_be_subscriber =>	1,
		column_name =>		"ts",
	});
	my $count = $self->sqlCount(
		'discussions',
		"id='$id' AND type != 'archived' AND $where_time",
	);
	return 0 unless $count;

	# Now, we are going to get paranoid and run the story checker against it
	my $sid;
	if ($sid = $self->getDiscussion($id, 'sid')) {
		return $self->checkStoryViewable($sid);
	}

	return 1;
}

########################################################
sub setSection {
	errorLog("setSection called");
	_genericSet('sections', 'section', '', @_);
}

########################################################
sub createSection {
	my($self, $hash) = @_;
	errorLog("createSection called");
	$self->sqlInsert('sections', $hash);
}

########################################################
sub setDiscussionDelCount {
	my($self, $sid, $count) = @_;
	return unless $sid;

	my $where = '';
	if ($sid =~ /^\d+$/) {
		$where = "id=$sid";
	} else {
		$where = "sid=" . $self->sqlQuote($sid);
	}
	$self->sqlUpdate(
		'discussions',
		{
			-commentcount	=> "commentcount-$count",
			flags		=> "dirty",
		},
		$where
	);
}

########################################################
# Long term, this needs to be modified to take in account
# of someone wanting to delete a submission that is
# not part in the form
sub deleteSubmission {
	my($self, $options, $nodelete) = @_;  # $nodelete param is obsolete
	my $uid = getCurrentUser('uid');
	my $form = getCurrentForm();
	my @subid;

	$options = {} unless ref $options;
	$options->{nodelete} = $nodelete if defined $nodelete;

	if ($form->{subid} && !$options->{nodelete}) {
		$self->sqlUpdate("submissions", { del => 1 },
			"subid=" . $self->sqlQuote($form->{subid})
		);

		# Brian mentions that this isn't atomic and that two updates
		# executing this code with the same UID will cause problems.
		# I say, that if you have 2 processes executing this code 
		# at the same time, with the same uid, that you have a SECURITY
		# BREACH. Caveat User.			- Cliff

		# I don't understand what would be a security
		# breach.  If someone has two windows open and
		# deletes from one, and while that request is
		# pending does it from the other, that's no
		# security breach. -- pudge

		$self->setUser($uid,
			{ deletedsubmissions => 
				getCurrentUser('deletedsubmissions') + 1,
		});
		push @subid, $form->{subid};
	}

	for (keys %{$form}) {
		# $form has several new internal variables that match this regexp, so 
		# the logic below should always check $t.
		next unless /^(\w+)_(\d+)$/;
		my($t, $n) = ($1, $2);
		if ($t eq "note" || $t eq "comment" || $t eq "skid") {
			$form->{"note_$n"} = "" if $form->{"note_$n"} eq " ";
			if ($form->{$_}) {
				my %sub = (
					note		=> $form->{"note_$n"},
					comment		=> $form->{"comment_$n"},
					primaryskid	=> $form->{"skid_$n"}
				);

				if (!$sub{note}) {
					delete $sub{note};
					$sub{-note} = 'NULL';
				}

				$self->sqlUpdate("submissions", \%sub,
					"subid=" . $self->sqlQuote($n));
			}
		} elsif ($t eq 'del' && !$options->{nodelete}) {
			if ($options->{accepted}) {
				$self->sqlUpdate("submissions", { del => 2 },
					'subid=' . $self->sqlQuote($n));
			} else {
				$self->sqlUpdate("submissions", { del => 1 },
					'subid=' . $self->sqlQuote($n));
				$self->setUser($uid,
					{ -deletedsubmissions => 'deletedsubmissions+1' }
				);
			}
			push @subid, $n;
		}
	}

	return @subid;
}

########################################################
sub deleteSession {
	my($self, $uid) = @_;
	return unless $uid;
	$uid = defined($uid) || getCurrentUser('uid');
	if (defined $uid) {
		$self->sqlDelete("sessions", "uid=$uid");
	}
}

########################################################
sub deleteDiscussion {
	my($self, $did) = @_;

	$self->sqlDelete("discussions", "id=$did");
	my $comment_ids = $self->sqlSelectAll('cid', 'comments', "sid=$did");
	$self->sqlDelete("comments", "sid=$did");
	$self->sqlDelete("comment_text",
		  "cid IN ("
		. join(",", map { $_->[0] } @$comment_ids)
		. ")"
	) if @$comment_ids;
	$self->deleteModeratorlog({ sid => $did });
}

########################################################
sub deleteAuthor {
	my($self, $uid) = @_;
	$self->sqlDelete("sessions", "uid=$uid");
}

########################################################
sub deleteTopic {
	my($self, $tid, $newtid) = @_;
	my $tid_q = $self->sqlQuote($tid);
	my $newtid_q = $self->sqlQuote($newtid);

	return 0;  # too dangerous to use right now

	# Abort if $tid == $newtid !

	my @delete_tables = qw(
		topics topic_nexus topic_nexus_dirty topic_nexus_extras
	);

	# if we have a replacement tid ($newtid), replace with it, otherwise ... ?

	# i have no idea what discussions.topic or pollquestions.topic
	# is so i am ignoring them -- pudge

	if ($newtid) {
		### check to see if this would create a children/parent loop!
		my @children = $self->getAllChildrenTids($tid);
		if (grep { $_ == $newtid } @children) {
			# Houston we have a problem.  Throw an informative
			# error here. - Jamie
		}

		# We have to do two things in the topic_parents table.  In both
		# cases, we ignore failed UPDATEs, which will happen if the new
		# tid/parent_tid unique key collides with an existing row, which
		# would indicate that the topic in question has a relationship
		# with the new topic already.  Ignoring the failure means that
		# the already-existing min_weight will be unchanged, which is
		# what we want.  Afterwards we delete any rows which failed to
		# UPDATE.
		# The first thing is to update the to-be-deleted topic's children
		# to instead point to its replacement.
		$self->sqlUpdate('topic_parents',
			{ parent_tid => $newtid },
			"parent_tid=$tid_q",
			{ ignore => 1 });
		$self->sqlDelete('topic_parents', "parent_tid=$tid_q");
		# Second, update the to-be-deleted topic's parents to instead
		# be pointed-to by its replacement.  In case one of the topic's
		# parents _is_ the replacement, don't make it loop to itself
		# (and the resulting busted row will be deleted, same as above).
		$self->sqlUpdate('topic_parents',
			{ tid => $newtid },
			"tid=$tid_q AND parent_tid != $newtid_q",
			{ ignore => 1 });
		$self->sqlDelete('topic_parents', "tid=$tid_q");

		for my $table (qw(stories submissions journals)) {
			$self->sqlUpdate($table, {
				tid => $newtid
			}, "tid=$tid_q");
		}

		# need to rerender ?
		for my $table (qw(chosen rendered)) {
			$self->sqlDelete("story_topics_$table", "tid=$tid_q");
			$self->sqlInsert('story_topics_$table', {
				tid => $newtid
			}, {
				ignore => 1
			});
		}

	} else {  # delete these?
		# push @delete_tables, qw(story_topics_chosen story_topics_rendered);
	        # what to do with stories, submissions, journals
	}

	for my $table (@delete_tables) {
		$self->sqlDelete($table, "tid=$tid_q");
	}

	$self->setVar('topic_tree_lastchange', time());
}

########################################################
sub revertBlock {
	my($self, $bid) = @_;
	my $bid_q = $self->sqlQuote($bid);
	my $block = $self->sqlSelect("block", "backup_blocks", "bid = $bid_q");
	$self->sqlUpdate("blocks", { block => $block }, "bid = $bid_q");
}

########################################################
sub deleteBlock {
	my($self, $bid) = @_;
	my $bid_q = $self->sqlQuote($bid);
	$self->sqlDelete("blocks", "bid = $bid_q");
}

########################################################
sub deleteTemplate {
	my($self, $tpid) = @_;
	my $tpid_q = $self->sqlQuote($tpid);
	$self->sqlDelete("templates", "tpid = $tpid_q");
}

########################################################
sub deleteSection {
	my($self, $section) = @_;
	errorLog("deleteSection called");
	my $section_q = $self->sqlQuote($section);
	$self->sqlDelete("sections", "section=$section_q");
}

########################################################
sub deleteContentFilter {
	my($self, $id) = @_;
	my $id_q = $self->sqlQuote($id);
	$self->sqlDelete("content_filters", "filter_id=$id_q");
}

########################################################
sub saveTopic {
	my($self, $topic) = @_;
	my($tid) = $topic->{tid} || 0;

	# This seems like a wasted query to me... *shrug* -Cliff
	my($rows) = $self->sqlSelect('COUNT(*)', 'topics', "tid=$tid");

	my $image = $topic->{image2} || $topic->{image};

	my $data = {
		keyword		=> $topic->{keyword},
		textname	=> $topic->{textname},
		series		=> $topic->{series} eq 'yes' ? 'yes' : 'no',
		image		=> $image,
		width		=> $topic->{width},
		height		=> $topic->{height},
	};

	if ($rows == 0) {
		$self->sqlInsert('topics', $data);
		$tid = $self->getLastInsertId;
	} else {
		$self->sqlUpdate('topics', $data, "tid=$tid");
	}

	my @parents;
	if ($topic->{_multi}{parent_topic} && ref($topic->{_multi}{parent_topic}) eq 'ARRAY') {
		@parents = grep { $_ } @{$topic->{_multi}{parent_topic}};
	} elsif ($topic->{parent_topic}) {
		push @parents, $topic->{parent_topic};
	}
	my $parent_str = join ',', @parents;

	$self->sqlDelete('topic_parents', "tid=$tid AND parent_tid NOT IN ($parent_str)");
	for my $parent (@parents) {
		$self->sqlInsert('topic_parents', {
			tid		=> $tid,
			parent_tid	=> $parent
		});
	}

	if ($topic->{nexus}) {
		$self->sqlInsert('topic_nexus', { tid => $tid });
	} else {
		$self->sqlDelete('topic_nexus', "tid=$tid");
	}

	$self->setVar('topic_tree_lastchange', time());

	return $tid;
}

##################################################################
# Another hated method -Brian
sub saveBlock {
	my($self, $bid) = @_;
	my($rows) = $self->sqlSelect('count(*)', 'blocks',
		'bid=' . $self->sqlQuote($bid)
	);

	my $form = getCurrentForm();
	if ($form->{save_new} && $rows > 0) {
		return $rows;
	}

	if ($rows == 0) {
		$self->sqlInsert('blocks', { bid => $bid, seclev => 500 });
	}

	my($portal, $retrieve) = (0, 0, 0);

	# If someone marks a block as a portald block then potald is a portald
	# something tell me I may regret this...  -Brian
	$form->{type} = 'portald' if $form->{portal} == 1;

	# this is to make sure that a  static block doesn't get
	# saved with retrieve set to true
	$form->{retrieve} = 0 if $form->{type} ne 'portald';

	# If a block is a portald block then portal=1. type
	# is done so poorly -Brian
	$form->{portal} = 1 if $form->{type} eq 'portald';

	$form->{block} = $self->autoUrl($form->{section}, $form->{block})
		unless $form->{type} eq 'template';

	if ($rows == 0 || $form->{blocksavedef}) {
		$self->sqlUpdate('blocks', {
			seclev		=> $form->{bseclev},
			block		=> $form->{block},
			description	=> $form->{description},
			type		=> $form->{type},
			ordernum	=> $form->{ordernum},
			title		=> $form->{title},
			url		=> $form->{url},
			rdf		=> $form->{rdf},
			rss_template	=> $form->{rss_template},
			items		=> $form->{items},
			skin		=> $form->{skin},
			retrieve	=> $form->{retrieve},
			all_skins	=> $form->{all_skins},
			autosubmit	=> $form->{autosubmit},
			portal		=> $form->{portal},
		}, 'bid=' . $self->sqlQuote($bid));
		$self->sqlUpdate('backup_blocks', {
			block		=> $form->{block},
		}, 'bid=' . $self->sqlQuote($bid));
	} else {
		$self->sqlUpdate('blocks', {
			seclev		=> $form->{bseclev},
			block		=> $form->{block},
			description	=> $form->{description},
			type		=> $form->{type},
			ordernum	=> $form->{ordernum},
			title		=> $form->{title},
			url		=> $form->{url},
			rdf		=> $form->{rdf},
			rss_template	=> $form->{rss_template},
			items		=> $form->{items},
			skin		=> $form->{skin},
			retrieve	=> $form->{retrieve},
			portal		=> $form->{portal},
			autosubmit	=> $form->{autosubmit},
			all_skins	=> $form->{all_skins},
		}, 'bid=' . $self->sqlQuote($bid));
	}


	return $rows;
}

########################################################
sub saveColorBlock {
	my($self, $colorblock) = @_;
	my $form = getCurrentForm();

	my $bid_q = $self->sqlQuote($form->{color_block} || 'colors');

	if ($form->{colorsave}) {
		# save into colors and colorsback
		$self->sqlUpdate('blocks', {
				block => $colorblock,
			}, "bid = $bid_q"
		);

	} elsif ($form->{colorsavedef}) {
		# save into colors and colorsback
		$self->sqlUpdate('blocks', {
				block => $colorblock,
			}, "bid = $bid_q"
		);
		$self->sqlUpdate('backup_blocks', {
				block => $colorblock,
			}, "bid = $bid_q"
		);

	} elsif ($form->{colororig}) {
		# reload original version of colors
		my $block = $self->sqlSelect("block", "backup_blocks", "bid = $bid_q");
		$self->sqlUpdate('blocks', {
				block => $block
			}, "bid = $bid_q"
		);
	}
}

########################################################
sub getSectionBlock {
	my($self, $section) = @_;
	errorLog("getSectionBlock called");
	my $block = $self->sqlSelectAllHashrefArray("section,bid,ordernum,title,portal,url,rdf,retrieve",
		"blocks", "section=" . $self->sqlQuote($section),
		"ORDER by ordernum"
	);

	return $block;
}

########################################################
sub getSectionBlocks {
	my($self) = @_;

	my $blocks = $self->sqlSelectAll("bid,title,ordernum", "blocks", "portal=1", "order by title");

	return $blocks;
}

########################################################
sub getAuthorDescription {
	my($self) = @_;
	my $authors = $self->sqlSelectAll('storycount, uid, nickname, homepage, bio',
		'authors_cache',
		'author = 1',
		'GROUP BY uid ORDER BY storycount DESC'
	);

	return $authors;
}

########################################################
# Someday we'll support closing polls, in which case this method
# may return 0 sometimes.
sub isPollOpen {
	my($self, $qid) = @_;
	return 0 unless $self->hasPollActivated($qid);
	return 1;
}

#####################################################
sub hasPollActivated{
	my($self, $qid) = @_;
	return $self->sqlCount("pollquestions", "qid='$qid' and date <= now() and polltype!='nodisplay'");
}


########################################################
# Has this "user" already voted in a particular poll?  "User" here is
# specially taken to mean a conflation of IP address (possibly thru proxy)
# and uid, such that only one anonymous reader can post from any given
# IP address.
sub hasVotedIn {
	my($self, $qid) = @_;
	my $constants = getCurrentStatic();

	my $md5;
	if ($constants->{poll_fwdfor}) {
		$md5 = md5_hex($ENV{REMOTE_ADDR} . $ENV{HTTP_X_FORWARDED_FOR});
	} else {
		$md5 = md5_hex($ENV{REMOTE_ADDR});
	}
	my $qid_quoted = $self->sqlQuote($qid);
	# Yes, qid/id/uid is a key in pollvoters.
	my($voters) = $self->sqlSelect('id', 'pollvoters',
		"qid=$qid_quoted AND id='$md5' AND uid=$ENV{SLASH_USER}"
	);

	# Should be a max of one row returned.  In any case, if any
	# data is returned, this "user" has already voted.
	return $voters ? 1 : 0;
}

########################################################
# Yes, I hate the name of this. -Brian
# Presumably because it also saves poll answers, and number of
# votes cast for those answers, and optionally attaches the
# poll to a story.  Can we think of a better name than
# "savePollQuestion"? - Jamie
# sub saveMuTantSpawnSatanPollCrap {
#    -Brian
sub savePollQuestion {
	my($self, $poll) = @_;

	$poll->{section}  ||= getCurrentStatic('defaultsection');
	$poll->{voters}   ||= "0";
	$poll->{autopoll} ||= "no";
	$poll->{polltype} ||= "section";

	my $qid_quoted = "";
	$qid_quoted = $self->sqlQuote($poll->{qid}) if $poll->{qid};

	my $stoid;
	$stoid = $self->getStoidFromSidOrStoid($poll->{sid}) if $poll->{sid};
	my $sid_quoted = "";
	$sid_quoted = $self->sqlQuote($poll->{sid}) if $poll->{sid};
	$self->setStory_delete_memcached([ $stoid ]) if $stoid;

	# get hash of fields to update based on the linked story
	my $data = $self->getPollUpdateHashFromStory($poll->{sid}, {
		topic		=> 1,
		primaryskid	=> 1,
		date		=> 1,
		polltype	=> 1
	}) if $poll->{sid};

	# replace form values with those from story
	foreach (keys %$data){
		$poll->{$_} = $data->{$_};
	}

	if ($poll->{qid}) {
		$self->sqlUpdate("pollquestions", {
			question	=> $poll->{question},
			voters		=> $poll->{voters},
			topic		=> $poll->{topic},
			autopoll	=> $poll->{autopoll},
			primaryskid	=> $poll->{primaryskid},
			date		=> $poll->{date},
			polltype        => $poll->{polltype}
		}, "qid	= $qid_quoted");
		$self->sqlUpdate("stories", {
			qid		=> $poll->{qid}
		}, "sid = $sid_quoted") if $sid_quoted;
	} else {
		$self->sqlInsert("pollquestions", {
			question	=> $poll->{question},
			voters		=> $poll->{voters},
			topic		=> $poll->{topic},
			primaryskid	=> $poll->{primaryskid},
			autopoll	=> $poll->{autopoll},
			uid		=> getCurrentUser('uid'),
			date		=> $poll->{date},
			polltype        => $poll->{polltype}
		});
		$poll->{qid} = $self->getLastInsertId();
		$qid_quoted = $self->sqlQuote($poll->{qid});
		$self->sqlUpdate("stories", {
			qid		=> $poll->{qid}
		}, "sid = $sid_quoted") if $sid_quoted;
	}
	$self->setStory_delete_memcached([ $stoid ]) if $stoid;

	# Loop through 1..8 and insert/update if defined
	for (my $x = 1; $x < 9; $x++) {
		if ($poll->{"aid$x"}) {
			my $votes = $poll->{"votes$x"};
			$votes = 0 if $votes !~ /^-?\d+$/;
			$self->sqlReplace("pollanswers", {
				aid	=> $x,
				qid	=> $poll->{qid},
				answer	=> $poll->{"aid$x"},
				votes	=> $votes,
			});

		} else {
			$self->sqlDo("DELETE from pollanswers
				WHERE qid=$qid_quoted AND aid=$x");
		}
	}

	# Go on and unset any reference to the qid in sections, if it 
	# needs to exist the next statement will correct this. -Brian
	$self->sqlUpdate('sections', { qid => '0' }, " qid = $poll->{qid} ")
		if $poll->{qid};

	if ($poll->{qid} && $poll->{polltype} eq "section" && $poll->{date} le $self->getTime()) {
		$self->setSection($poll->{section}, { qid => $poll->{qid} });
	}

	return $poll->{qid};
}

sub updatePollFromStory {
	my($self, $sid, $opts) = @_;
	my($data, $qid) = $self->getPollUpdateHashFromStory($sid, $opts);
	if ($qid){
		$self->sqlUpdate("pollquestions", $data, "qid=" . $self->sqlQuote($qid));
	}
}

#XXXSECTIONTOPICS section and tid still need to be handled
sub getPollUpdateHashFromStory {
	my($self, $id, $opts) = @_;
	my $stoid = $self->getStoidFromSidOrStoid($id);
	return undef unless $stoid;
	my $story_ref = $self->sqlSelectHashref(
		"sid,qid,time,primaryskid,tid",
		"stories",
		"stoid=$stoid");
	my $data;
	my $viewable = $self->checkStoryViewable($stoid);
	if ($story_ref->{qid}) {
		$data->{date}		= $story_ref->{time} if $opts->{date};
		$data->{polltype}	= $viewable ? "story" : "nodisplay" if $opts->{polltype};
		$data->{topic}		= $story_ref->{tid} if $opts->{topic};
		$data->{primaryskid}	= $story_ref->{primaryskid} if $opts->{primaryskid};
	}
	# return the hash of fields and values to update for the poll
	# if asked for the array return the qid of the poll too
	return wantarray ? ($data, $story_ref->{qid}) : $data;
}

########################################################
# A note, this does not remove the issue of a story
# still having a poll attached to it (orphan issue)
sub deletePoll {
	my($self, $qid) = @_;
	return if !$qid;

	my $qid_quoted = $self->sqlQuote($qid);
	my $did = $self->sqlSelect(
		'discussion', 
		'pollquestions',
		"qid=$qid_quoted"
	);

	$self->deleteDiscussion($did) if $did;

	$self->sqlDo("DELETE FROM pollanswers   WHERE qid=$qid_quoted");
	$self->sqlDo("DELETE FROM pollquestions WHERE qid=$qid_quoted");
	$self->sqlDo("DELETE FROM pollvoters    WHERE qid=$qid_quoted");
}

########################################################
sub getPollQuestionList {
	my($self, $offset, $other) = @_;
	my($where);

	my $justStories = $other->{type} eq "story" ? 1 : 0 ;

	$offset = 0 if $offset !~ /^\d+$/;
	my $admin = getCurrentUser('is_admin');

	# $others->{section} takes precidence over $others->{exclude_section}. Both
	# keys are mutually exclusive and should not be used in the same call.
	delete $other->{exclude_section} if exists $other->{section};
	for (qw(section exclude_section)) {
		# Usage issue. Some folks may add an "s" to the key name.
		$other->{$_} ||= $other->{"${_}s"} if exists $other->{"${_}s"};
		if (exists $other->{$_} && $other->{$_}) {
			if (!ref $other->{$_}) {
				$other->{$_} = [$other->{$_}];
			} elsif (ref $other->{$_} eq 'HASH') {
				my @list = sort keys %{$other->{$_}};
				$other->{$_} = \@list;
			}
			# Quote the data.
			$_ = $self->sqlQuote($_) for @{$other->{$_}};
		}
	}

	$where .= "autopoll = 'no'";
	$where .= " AND pollquestions.discussion  = discussions.id ";
	$where .= sprintf ' AND primaryskid IN (%s)', join(',', @{$other->{section}})
		if $other->{section};
	$where .= sprintf ' AND primaryskid NOT IN (%s)', join(',', @{$other->{exclude_section}})
		if $other->{exclude_section} && @{$other->{section}};
	$where .= " AND pollquestions.topic = $other->{topic} " if $other->{topic};

	$where .= " AND date <= NOW() " unless $admin;
	my $limit = $other->{limit} || 20;

	my $cols = 'pollquestions.qid as qid, question, date, voters, discussions.commentcount as commentcount, 
			polltype, date>now() as future,pollquestions.topic';
	$cols .= ", stories.title as title, stories.sid as sid" if $justStories;

	my $tables = 'pollquestions,discussions';
	$tables .= ',stories' if $justStories;

	$where .= ' AND pollquestions.qid = stories.qid' if $justStories;

	my $questions = $self->sqlSelectAll(
		$cols,
		$tables,
		$where,
		"ORDER BY date DESC LIMIT $offset, $limit"
	);

	return $questions;
}

########################################################
sub getPollAnswers {
	my($self, $qid, $val) = @_;
	my $qid_quoted = $self->sqlQuote($qid);
	my $values = join ',', @$val;
	my $answers = $self->sqlSelectAll($values, 'pollanswers',
		"qid=$qid_quoted", 'ORDER BY aid');

	return $answers;
}

########################################################
sub markNexusClean {
	my($self, $tid) = @_;
	my $tid_q = $self->sqlQuote($tid);
	$self->sqlDelete('topic_nexus_dirty', "tid = $tid_q");
}

########################################################
sub markNexusDirty {
	my($self, $tid) = @_;
	$self->sqlInsert('topic_nexus_dirty', { tid => $tid }, { ignore => 1 });
}

########################################################
sub markSkinClean {
	my($self, $id) = @_;
	my $nexus = $self->getNexusFromSkid($self->getSkidFromName($id));
	errorLog("no nexus found for id '$id'") if !$nexus;
	$self->sqlDelete('topic_nexus_dirty', "tid = $nexus");
}

########################################################
sub markSkinDirty {
	my($self, $id) = @_;
	my $nexus = $self->getNexusFromSkid($self->getSkidFromName($id));
	errorLog("no nexus found for id '$id'") if !$nexus;
	$self->sqlInsert('topic_nexus_dirty', { tid => $nexus }, { ignore => 1 });
}

########################################################
sub markStoryClean {
	my($self, $id) = @_;
	my $stoid = $self->getStoidFromSidOrStoid($id);
	$self->sqlDelete('story_dirty', "stoid = $stoid");
}

########################################################
sub markStoryDirty {
	my($self, $id) = @_;
	my $stoid = $self->getStoidFromSidOrStoid($id);
	$self->setStory_delete_memcached([ $stoid ]);
	$self->sqlInsert('story_dirty', { stoid => $stoid }, { ignore => 1 });
}

########################################################
sub deleteStory {
	my($self, $id) = @_;
	return $self->setStory($id, { in_trash => 'yes' });
}

########################################################
sub setStory {
	my($self, $id, $hashref) = @_;

	my $table_prime = 'stoid';
	my $param_table = 'story_param';
	my $tables = [qw(
		stories story_text
	)];
	my $cache = _genericGetCacheName($self, $tables);
	my @param = ( );
	my %update_tables = ( );

	# Grandfather in an old-style sid.
	my $stoid = $self->getStoidFromSidOrStoid($id);
	return 0 unless $stoid;

	# Delete the memcached entry before doing this, because
	# whatever is there now is invalid.
	$self->setStory_delete_memcached([ $stoid ]);

	# We modify data before we're done.  Make a copy.
	my %h = %$hashref;
	$hashref = \%h;

	# Grandfather in these two API parameters, writestatus and
	# is_dirty.  The preferred way to set is_archived is
	# to pass in { is_archived => 1 }.  The preferred way
	# to set a story as dirty is { is_dirty => 1 } To mark
	# a story as clean or ok set it to { is_dirty => 0 }
	# Of course, markStoryClean and -Dirty work too

	my($dirty_change, $dirty_newval);
	if ($hashref->{writestatus}) {
		$dirty_change = 1;
		$dirty_newval =	  $hashref->{writestatus} eq 'dirty'	? 1 : 0;
		my $is_archived = $hashref->{writestatus} eq 'archived' ? 1 : 0;
		delete $hashref->{writestatus};
		$hashref->{is_archived} = 'yes' if $is_archived;
	}
	if (defined $hashref->{is_dirty}) {
		$dirty_change = 1;
		$dirty_newval = $hashref->{is_dirty};
		delete $hashref->{is_dirty}
	}

	$hashref->{is_archived} = $hashref->{is_archived} ? 'yes' : 'no' if defined $hashref->{is_archived};
	$hashref->{in_trash} = $hashref->{in_trash} ? 'yes' : 'no' if defined $hashref->{in_trash};

	my $chosen_hr = delete $hashref->{topics_chosen};
	if ($chosen_hr) {
		# If a topics_chosen hashref was given, we write not just that,
		# but also topics_rendered, primaryskid and tid.
		$self->setStoryTopicsChosen($stoid, $chosen_hr);
		my $info_hr = { };
		$info_hr->{neverdisplay} = 1 if $hashref->{neverdisplay};
		my($primaryskid, $tids) = $self->setStoryRenderedFromChosen($stoid, $chosen_hr,
			$info_hr);
		$hashref->{primaryskid} = $primaryskid;
		$hashref->{tid} = $tids->[0] || 0;
	}

	$hashref->{day_published} = $hashref->{'time'}
		if $hashref->{'time'};

	for (keys %$hashref) {
		(my $clean_val = $_) =~ s/^-//;
		my $key = $self->{$cache}{$clean_val};
		if ($key) {
			push @{$update_tables{$key}}, $_;
		} else {
			push @param, [$_, $hashref->{$_}];
		}
	}

	my $ok;
	for my $table (keys %update_tables) {
		my %minihash;
		for my $key (@{$update_tables{$table}}){
			$minihash{$key} = $hashref->{$key}
				if defined $hashref->{$key};
		}
		$ok = $self->sqlUpdate($table, \%minihash, "stoid=$stoid");
#print STDERR "setStory ok '$ok' after sqlUpdate table '$table' stoid '$stoid' minihash keys '" . join(" ", sort keys %minihash) . "'\n" if !$ok;
	}

	for (@param)  {
		if (defined $_->[1] && length $_->[1]) {
			$self->sqlReplace($param_table, {
				stoid	=> $stoid,
				name	=> $_->[0],
				value	=> $_->[1]
			});
		} else {
			my $name_q = $self->sqlQuote($_->[0]);
			$self->sqlDelete($param_table,
				"stoid = $stoid AND name = $name_q"
			);
		}
	}

	if ($dirty_change) {
		if ($dirty_newval) {
			$self->markStoryDirty($stoid);
		} else {
			$self->markStoryClean($stoid);
		}
	}

	# Delete the memcached entry after having done that,
	# to make sure nothing incorrect was set while we were
	# in the middle of updating the DB.
	$self->setStory_delete_memcached([ $stoid ]);

	return $ok;
}

########################################################
sub setStory_delete_memcached {
	my($self, $stoid_list) = @_;
	my $mcd = $self->getMCD();
	return unless $mcd;
	my $constants = getCurrentStatic();
	my $mcddebug = $constants->{memcached_debug};

	$stoid_list = [ $stoid_list ] if !ref($stoid_list);
	for my $stoid (@$stoid_list) {
		my $mcdkey = "$self->{_mcd_keyprefix}:st:";
		# The "3" means "don't accept new writes to this key for 3 seconds."
		$mcd->delete("$mcdkey$stoid", 3);
		if ($mcddebug > 1) {
			print STDERR scalar(gmtime) . " $$ setS_deletemcd deleted '$mcdkey$stoid'\n";
		}
	}
}

########################################################
# the the last time a user submitted a form successfuly
sub getSubmissionLast {
	my($self, $formname) = @_;

	my $where = $self->_whereFormkey();
	my($last_submitted) = $self->sqlSelect(
		"max(submit_ts)",
		"formkeys",
		"$where AND formname = '$formname'");
	$last_submitted ||= 0;

	return $last_submitted;
}

########################################################
# get the last timestamp user created  or
# submitted a formkey
sub getLastTs {
	my($self, $formname, $submitted) = @_;

	my $tscol = $submitted ? 'submit_ts' : 'ts';
	my $where = $self->_whereFormkey();
	$where .= " AND formname =  '$formname'";
	$where .= ' AND value = 1' if $submitted;

	my($last_created) = $self->sqlSelect(
		"max($tscol)",
		"formkeys",
		$where);
	$last_created ||= 0;
}

########################################################
sub _getLastFkCount {
	my($self, $formname) = @_;

	my $where = $self->_whereFormkey();
	my($idcount) = $self->sqlSelect(
		"max(idcount)",
		"formkeys",
		"$where AND formname = '$formname'");
	$idcount ||= 0;

}

########################################################
# gives a true or false of whether the system has given
# out more than the allowed unused formkeys per form
# over the formkey timeframe
sub getUnsetFkCount {
	my($self, $formname) = @_;
	my $constants = getCurrentStatic();

	my $formkey_earliest = time() - $constants->{formkey_timeframe};
	my $where = $self->_whereFormkey();
	$where .=  " AND formname = '$formname'";
	$where .= " AND ts >= $formkey_earliest";
	$where .= " AND value = 0";

	my $unused = 0;

	my $max_unused = $constants->{"max_${formname}_unusedfk"};

	if ($max_unused) {
		($unused) = $self->sqlSelect(
			"count(*) >= $max_unused",
			"formkeys",
			$where);

		return $unused;

	} else {
		return(0);
	}
}

########################################################
sub updateFormkeyId {
	my($self, $formname, $formkey, $uid, $rlogin, $upasswd) = @_;

	# here we check to see if a user has logged in just now, and
	# has any formkeys assigned to him; if so, we assign them to
	# his newly-granted UID
	if (! isAnon($uid) && $rlogin && length($upasswd) > 1) {
		my $constants = getCurrentStatic();
		my $last_count = $self->_getLastFkCount($formname);
		$self->sqlUpdate("formkeys", {
				uid	=> $uid,
				idcount	=> $last_count,
			},
			"formname='$formname' AND uid = $constants->{anonymous_coward_uid} AND formkey=" .
			$self->sqlQuote($formkey)
		);
	}
}

########################################################
sub createFormkey {
	my($self, $formname) = @_;

	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $ipid = getCurrentUser('ipid');
	my $subnetid = getCurrentUser('subnetid');

	my $last_count = $self->_getLastFkCount($formname);
	my $last_submitted = $self->getLastTs($formname, 1);

	my $formkey = "";
	my $num_tries = 50;
	while (1) {
		$formkey = getFormkey();
		my $rows = $self->sqlInsert('formkeys', {
			formkey         => $formkey,
			formname        => $formname,
			uid             => $ENV{SLASH_USER},
			ipid            => $ipid,
			subnetid        => $subnetid,
			value           => 0,
			ts              => time(),
			last_ts         => $last_submitted,
			idcount         => $last_count,
		});
		last if $rows;
		# The INSERT failed because $formkey is already being
		# used.  Keep retrying as long as is reasonably possible.
		if (--$num_tries <= 0) {
			# Give up!
			print STDERR scalar(localtime)
				. "createFormkey failed: $formkey\n";
			$formkey = "";
			last;
		}
	}
	# save in form object for printing to user
	$form->{formkey} = $formkey;
	return $formkey ? 1 : 0;
}

########################################################
sub checkResponseTime {
	my($self, $formname) = @_;

	my $constants = getCurrentStatic();
	my $form = getCurrentForm();

	my $now =  time();

	my $response_limit = $constants->{"${formname}_response_limit"} || 0;

	# 1 or 0
	my($response_time) = $self->sqlSelect("$now - ts", 'formkeys',
		'formkey = ' . $self->sqlQuote($form->{formkey}));

	if ($constants->{DEBUG}) {
		print STDERR "SQL select $now - ts from formkeys where formkey = '$form->{formkey}'\n";
		print STDERR "LIMIT REACHED $response_time\n";
	}

	return ($response_time < $response_limit && $response_time > 0) ? $response_time : 0;
}

########################################################
# This used to return boolean, 1=valid, 0=invalid.  Now it returns
# "ok", "invalid", or "invalidhc".  The two "invalid*" responses
# function somewhat the same (but print different error messages,
# and "invalidhc" can be retried several times before the formkey
# is invalidated).
sub validFormkey {
	my($self, $formname, $options) = @_;

	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $uid = getCurrentUser('uid');
	my $subnetid = getCurrentUser('subnetid');

	undef $form->{formkey} unless $form->{formkey} =~ /^\w{10}$/;
	return 'invalid' if !$form->{formkey};
	my $formkey_quoted = $self->sqlQuote($form->{formkey});

	my $formkey_earliest = time() - $constants->{formkey_timeframe};

	my $where = $self->_whereFormkey();
	$where = "($where OR subnetid = '$subnetid')"
		if $constants->{lenient_formkeys} && isAnon($uid);
	my($is_valid) = $self->sqlSelect(
		'COUNT(*)',
		'formkeys',
		"formkey = $formkey_quoted
		 AND $where
		 AND ts >= $formkey_earliest AND formname = '$formname'"
	);
	print STDERR "ISVALID $is_valid\n" if $constants->{DEBUG};
	return 'invalid' if !$is_valid;
 
	# If we're using the HumanConf plugin, check for its validity
	# as well.
	return 'ok' if $options->{no_hc};
	my $hc = getObject("Slash::HumanConf");
	return 'ok' if !$hc;
	return $hc->validFormkeyHC($formname);
}

##################################################################
sub getFormkeyTs {
	my($self, $formkey, $ts_flag) = @_;

	my $constants = getCurrentStatic();

	my $tscol = $ts_flag == 1 ? 'submit_ts' : 'ts';

	my($ts) = $self->sqlSelect(
		$tscol,
		"formkeys",
		"formkey=" . $self->sqlQuote($formkey));

	print STDERR "FORMKEY TS $ts\n" if $constants->{DEBUG};
	return($ts);
}

##################################################################
# two things at once. Validate and increment
sub updateFormkeyVal {
	my($self, $formname, $formkey) = @_;

	my $constants = getCurrentStatic();

	my $formkey_quoted = $self->sqlQuote($formkey);

	my $where = "value = 0";

	# Before the transaction-based version was written, we
	# did something like this, which Patrick noted seemed
	# to cause difficult-to-track errors.
	# my $speed_limit = $constants->{"${formname}_speed_limit"};
	# my $maxposts = $constants->{"max_${formname}_allowed"} || 0;
	# my $min = time() - $speed_limit;
	# $where .= " AND idcount < $maxposts";
	# $where .= " AND last_ts <= $min";

	# print STDERR "MIN $min MAXPOSTS $maxposts WHERE $where\n" if $constants->{DEBUG};

	# increment the value from 0 to 1 (shouldn't ever get past 1)
	# this does two things: increment the value (meaning the formkey
	# can't be used again) and also gives a true/false value
	my $updated = $self->sqlUpdate("formkeys", {
		-value		=> 'value+1',
		-idcount	=> 'idcount+1',
	}, "formkey=$formkey_quoted AND $where");

	$updated = int($updated);

	print STDERR "UPDATED formkey var $updated\n" if $constants->{DEBUG};
	return($updated);
}

##################################################################
# use this in case the function you call fails prior to updateFormkey
# but after updateFormkeyVal
sub resetFormkey {
	my($self, $formkey, $formname) = @_;

	my $constants = getCurrentStatic();

	my $update_ref = {
		-value          => 0,
		-idcount        => 'idcount-1',
# Since the beginning, ts has been updated here whenever a formkey needs to
# be reset.  As far as I can tell, this serves no purpose except to reset
# the 20-second clock before a comment can be posted after a failed attempt
# to submit.  This has probably been causing numerous reports of spurious
# 20-second failure errors.  In the core code, comments and submit are the
# only formnames that check ts, both in response_limit, and
# comments_response_limit is the only one defined anyway. - Jamie 2002/11/19
#		ts              => time(),
		submit_ts       => '0',
	};
	$update_ref->{formname} = $formname if $formname;

	# reset the formkey to 0, and reset the ts
	my $updated = $self->sqlUpdate("formkeys", 
		$update_ref, 
		"formkey=" . $self->sqlQuote($formkey));

	print STDERR "RESET formkey $updated\n" if $constants->{DEBUG};
	return $updated;
}

##################################################################
sub updateFormkey {
	my($self, $formkey, $length) = @_;
	$formkey  ||= getCurrentForm('formkey');

	my $constants = getCurrentStatic();

	# update formkeys to show that there has been a successful post,
	# and increment the value from 0 to 1 (shouldn't ever get past 1)
	# meaning that yes, this form has been submitted, so don't try i t again.
	my $updated = $self->sqlUpdate("formkeys", {
		submit_ts	=> time(),
		content_length	=> $length,
	}, "formkey=" . $self->sqlQuote($formkey));

	print STDERR "UPDATED formkey $updated\n" if $constants->{DEBUG};
	return($updated);
}

##################################################################
sub checkPostInterval {
	my($self, $formname) = @_;
	$formname ||= getCurrentUser('currentPage');

	my $constants = getCurrentStatic();
	my $speedlimit = $constants->{"${formname}_speed_limit"} || 0;
	my $formkey_earliest = time() - $constants->{formkey_timeframe};

	my $where = $self->_whereFormkey();
	$where .= " AND formname = '$formname' ";
	$where .= "AND ts >= $formkey_earliest";

	my $now = time();
	my($interval) = $self->sqlSelect(
		"$now - max(submit_ts)",
		"formkeys",
		$where);

	$interval ||= 0;
	print STDERR "CHECK INTERVAL $interval speedlimit $speedlimit\n" if $constants->{DEBUG};

	return ($interval < $speedlimit && $speedlimit > 0) ? $interval : 0;
}

##################################################################
sub checkMaxReads {
	my($self, $formname) = @_;
	my $constants = getCurrentStatic();

	my $maxreads = $constants->{"max_${formname}_viewings"} || 0;
	my $formkey_earliest = time() - $constants->{formkey_timeframe};

	my $where = $self->_whereFormkey();
	$where .= " AND formname = '$formname'";
	$where .= " AND ts >= $formkey_earliest";
	$where .= " HAVING count >= $maxreads";

	my($limit_reached) = $self->sqlSelect(
		"COUNT(*) AS count",
		"formkeys",
		$where);

	return $limit_reached ? $limit_reached : 0;
}

##################################################################
sub checkMaxPosts {
	my($self, $formname) = @_;
	my $constants = getCurrentStatic();
	$formname ||= getCurrentUser('currentPage');

	my $formkey_earliest = time() - $constants->{formkey_timeframe};
	my $maxposts = 0;
	if ($constants->{"max_${formname}_allowed"}) {
		$maxposts = $constants->{"max_${formname}_allowed"};
	} elsif ($formname =~ m{/}) {
		# If the formname is in the format "users/nu", that means
		# it also counts as a formname of "users" for this purpose.
		(my $formname_main = $formname) =~ s{/.*}{};
		if ($constants->{"max_${formname_main}_allowed"}) {
			$maxposts = $constants->{"max_${formname_main}_allowed"};
		}
	}

	if ($formname eq 'comments') {
		my $user = getCurrentUser();
		if (!isAnon($user)) {
			my($num_comm, $sum_mods) = getNumCommPostedByUID();
			if ($sum_mods > 0) {
				$maxposts += $sum_mods;
			} elsif ($sum_mods < 0) {
				my $min = int($maxposts/2);
				$maxposts += $sum_mods;
				$maxposts = $min if $maxposts < $min;
			}
		}
	}

	my $where = $self->_whereFormkey();
	$where .= " AND submit_ts >= $formkey_earliest";
	$where .= " AND formname = '$formname'",
	$where .= " HAVING count >= $maxposts";

	my($limit_reached) = $self->sqlSelect(
		"COUNT(*) AS count",
		"formkeys",
		$where);
	$limit_reached ||= 0;

	if ($constants->{DEBUG}) {
		print STDERR "LIMIT REACHED (times posted) $limit_reached\n";
		print STDERR "LIMIT REACHED limit_reached maxposts $maxposts\n";
	}

	return $limit_reached;
}

##################################################################
sub checkMaxMailPasswords {
	my($self, $user_check) = @_;
	my $constants = getCurrentStatic();

	my $max_hrs = $constants->{mailpass_max_hours} || 48;
	my $time = time;
	my $user_last_ts = $user_check->{mailpass_last_ts} || $time;
	my $user_hrs = ($time - $user_last_ts) / 3600;
	if ($user_hrs > $max_hrs) {
		# It's been more than max_hours since the user last got
		# a password sent, so it's OK.
		return 0;
	}

	my $max_num = $constants->{mailpass_max_num} || 2;
	my $user_mp_num = $user_check->{mailpass_num};
	if ($user_mp_num < $max_num) {
		# It's been within the last max_hours since the user last
		# got a password sent, but they haven't used up their
		# allotment, so it's OK.
		return 0;
	}

	# User has gotten too many passwords mailed to them recently.
	return 1;
}

##################################################################
sub setUserMailPasswd {
	my($self, $user_set) = @_;
	my $constants = getCurrentStatic();

	my $max_hrs = $constants->{mailpass_max_hours} || 48;
	my $time = time;
	my $user_last_ts = $user_set->{mailpass_last_ts} || $time;
	my $user_hrs = ($time - $user_last_ts) / 3600;
	if ($user_hrs > $max_hrs) {
		# It's been more than max_hours since the user last got
		# a password sent, so reset the clock and the counter.
		$self->setUser($user_set->{uid}, {
			mailpass_last_ts	=> $time,
			mailpass_num		=> 1,
		});
	} else {
		my $user_mp_num = $self->getUser($user_set->{uid},
			'mailpass_num');
		my $data = {
			mailpass_num		=> $user_mp_num+1,
		};
		$data->{mailpass_last_ts} = $time
			if !$user_set->{mailpass_last_ts};
		$self->setUser($user_set->{uid}, $data);
	}
	return 1;
}

##################################################################
sub checkTimesPosted {
	my($self, $formname, $max, $formkey_earliest) = @_;

	my $where = $self->_whereFormkey();
	my($times_posted) = $self->sqlSelect(
		"count(*) as times_posted",
		'formkeys',
		"$where AND submit_ts >= $formkey_earliest AND formname = '$formname'");

	return $times_posted >= $max ? 0 : 1;
}

##################################################################
# the form has been submitted, so update the formkey table
# to indicate so
sub formSuccess {
	my($self, $formkey, $cid, $length) = @_;

	# update formkeys to show that there has been a successful post,
	# and increment the value from 0 to 1 (shouldn't ever get past 1)
	# meaning that yes, this form has been submitted, so don't try i t again.
	$self->sqlUpdate("formkeys", {
			-value          => 'value+1',
			cid             => $cid,
			submit_ts       => time(),
			content_length  => $length,
		}, "formkey=" . $self->sqlQuote($formkey)
	);
}

##################################################################
sub formFailure {
	my($self, $formkey) = @_;
	$self->sqlUpdate("formkeys", {
			value   => -1,
		}, "formkey=" . $self->sqlQuote($formkey)
	);
}

##################################################################
# logs attempts to break, fool, flood a particular form
sub createAbuse {
	my($self, $reason, $script_name, $query_string, $uid, $ipid, $subnetid) = @_;

	my $user = getCurrentUser();
	$uid      ||= $user->{uid};
	$ipid     ||= $user->{ipid};
	$subnetid ||= $user->{subnetid};

	# logem' so we can banem'
	$self->sqlInsert("abusers", {
		uid		=> $uid,
		ipid		=> $ipid,
		subnetid	=> $subnetid,
		pagename	=> $script_name,
		querystring	=> $query_string || '',
		reason		=> $reason,
		-ts		=> 'now()',
	});
}

##################################################################
# Instead of setting nopost directly, with a goofy reason, the
# accesslist table should have a column "now_expired", which
# checkReadOnly knows to check.  But the expired-user code has
# other problems to fix first... - Jamie 2003/03/23
sub setExpired {
	my($self, $uid) = @_;
	if  ($uid && !$self->checkExpired($uid)) {
		$self->setUser($uid, { expired => 1 });
		$self->setAccessList({ uid => $uid }, [qw( nopost )], 'expired');
	}
}

##################################################################
sub setUnexpired {
	my($self, $uid) = @_;
	if ($uid && $self->checkExpired($uid)) {
		$self->setUser($uid, { expired => 0 });
		$self->setAccessList({ uid => $uid }, [ ], '');
	}
}

##################################################################
sub checkExpired {
	my($self, $uid) = @_;
	return 0 if !$uid;
	my $rows = $self->sqlCount(
		"accesslist",
		"uid = '$uid' AND now_nopost = 'yes' AND reason = 'expired'"
	);
	return $rows ? 1 : 0;
}

##################################################################
sub checkReadOnly {
	my($self, $access_type, $user_check) = @_;
	# We munge access_type directly into the SQL so make SURE it is
	# one of the supported columns.
	$access_type = 'nopost' if !$access_type
		|| $access_type !~ /^(ban|nopost|nosubmit|norss|nopalm|proxy|trusted)$/;

	$user_check ||= getCurrentUser();
	my $constants = getCurrentStatic();

	my $where_ary = [ ];

	# Please check to make sure this is what you want;
	# isAnon already checks for numeric uids -- pudge
	# This looks right;  if the {uid} field of %$user_check
	# is not defined, we ignore uid and put together our
	# test based on another field. -- Jamie
	if ($user_check->{uid} && $user_check->{uid} =~ /^\d+$/) {
		if (!isAnon($user_check->{uid})) {
			$where_ary = [ "uid = $user_check->{uid}" ];
		} else {
			# This is probably an error... I don't think
			# the code ever gets here but we should
			# probably bail at this point, returning 1
			# to indicate a problem. - Jamie 2003/03/03
			$where_ary = [ "ipid = '$user_check->{ipid}'" ];
		}
	} elsif ($user_check->{md5id}) {
		# To do this with a WHERE is very slow!  Both the ipid
		# and the subnetid columns are indexed, but if you OR
		# them, MySQL does a table scan.  So instead of that,
		# we're going to do two checks and boolean OR the result.
		$where_ary = [
			"ipid = '$user_check->{md5id}'",
			"subnetid = '$user_check->{md5id}'",
		];
	} elsif ($user_check->{ipid}) {
		my $tmpid = $user_check->{ipid} =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}/ ? 
				md5_hex($user_check->{ipid}) : $user_check->{ipid}; 
		$where_ary = [ "ipid = '$tmpid'" ];

	} elsif ($user_check->{subnetid}) {
		my $tmpid = $user_check->{subnetid} =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}/ ? 
				md5_hex($user_check->{subnetid}) : $user_check->{subnetid}; 
		$where_ary = [ "subnetid = '$tmpid'" ];
	} else {
		my $tmpid = $user_check->{ipid} =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}/ ? 
				md5_hex($user_check->{ipid}) : $user_check->{ipid}; 
		$where_ary = [ "ipid = '$tmpid'" ];
	}

	for my $where (@$where_ary) {
		# Setting nopost blocks posting, nosubmit blocks submitting.
		$where .= " AND now_$access_type = 'yes'";
		# For when we get user expiration working.
		$where .= " AND reason != 'expired'";
	}

	# If any rows in the table match any of the where clauses,
	# then we're readonly.
	my $where;
	while ($where = shift @$where_ary) {
		return 1 if $self->sqlCount("accesslist", $where);
	}
	# Nothing matched, so we're not.
	return 0;
}

sub getKnownOpenProxy {
	my($self, $ip, $ip_col) = @_;
	return 0 unless $ip;
	my $col = "ip";
	$col = "ipid" if $ip_col eq "ipid";
	my $ip_q = $self->sqlQuote($ip);
	my $hours_back = getCurrentStatic('comments_portscan_cachehours') || 48;
	my $port = $self->sqlSelect("port",
		"open_proxies",
		"$col = $ip_q AND ts >= DATE_SUB(NOW(), INTERVAL $hours_back HOUR)");
#print STDERR scalar(localtime) . " getKnownOpenProxy returning " . (defined($port) ? "'$port'" : "undef") . " for ip '$ip'\n";
	return $port;
}

sub setKnownOpenProxy {
	my($self, $ip, $port) = @_;
	return 0 unless $ip;
	my $xff;
	if ($port) {
		my $r = Apache->request;
		$xff = $r->header_in('X-Forwarded-For') if $r;
#use Data::Dumper; print STDERR "sKOP headers_in: " . Dumper([ $r->headers_in ]) if $r;
	}
	$xff ||= undef;
	$xff = $1 if $xff && length($xff) > 15
		&& $xff =~ /(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/;
#print STDERR scalar(localtime) . " setKnownOpenProxy doing sqlReplace ip '$ip' port '$port'\n";
	return $self->sqlReplace("open_proxies", {
		ip =>	$ip,
		port =>	$port,
		-ts =>	'NOW()',
		xff =>	$xff,
		-ipid => "md5('$ip')"
	});
}

sub checkForOpenProxy {
	my($self, $ip) = @_;
	# If we weren't passed an IP address, default to whatever
	# the current IP address is.
	if (!$ip && $ENV{GATEWAY_INTERFACE}) {
		my $r = Apache->request;
		$ip = $r->connection->remote_ip if $r;
	}
	# If we don't have an IP address, it can't be an open proxy.
	return 0 if !$ip;
	# Known secure IPs also don't count as open proxies.
	my $constants = getCurrentStatic();
	my $gSkin = getCurrentSkin();
	my $secure_ip_regex = $constants->{admin_secure_ip_regex};
	return 0 if $secure_ip_regex && $ip =~ /$secure_ip_regex/;

	# If the IP address is already one we have listed, use the
	# existing listing.
	my $port = $self->getKnownOpenProxy($ip);
	if (defined $port) {
#print STDERR scalar(localtime) . " cfop no need to check ip '$ip', port is '$port'\n";
		return $port;
	}
#print STDERR scalar(localtime) . " cfop ip '$ip' not known, checking\n";

	# No known answer;  probe the IP address and get an answer.
	my $ports = $constants->{comments_portscan_ports} || '80 8080 8000 3128';
	my @ports = grep /^\d+$/, split / /, $ports;
	return 0 if !@ports;
	my $timeout = $constants->{comments_portscan_timeout} || 5;
	my $connect_timeout = int($timeout/scalar(@ports)+0.2);
	my $ok_url = "$gSkin->{absolutedir}/ok.txt";

	my $pua = Slash::Custom::ParUserAgent->new();
	$pua->redirect(1);
	$pua->max_redirect(3);
	$pua->max_hosts(scalar(@ports));
	$pua->max_req(scalar(@ports));
	$pua->timeout($connect_timeout);

#use LWP::Debug;
#use Data::Dumper;
#LWP::Debug::level("+trace"); LWP::Debug::level("+debug");

	my $start_time = time;

	local $_proxy_port = undef;
	sub _cfop_callback {
		my($data, $response, $protocol) = @_;
#print STDERR scalar(localtime) . " _cfop_callback protocol '$protocol' port '$_proxy_port' succ '" . ($response->is_success()) . "' data '$data' content '" . ($response->is_success() ? $response->content() : "(fail)") . "'\n";
		if ($response->is_success() && $data eq "ok\n") {
			# We got a success, so the IP is a proxy.
			# We should know the proxy's port at this
			# point;  if not, that's remarkable, so
			# print an error.
			my $orig_req = $response->request();
			$_proxy_port = $orig_req->{_slash_proxytest_port};
			if (!$_proxy_port) {
				print STDERR scalar(localtime) . " _cfop_callback got data but no port, protocol '$protocol' port '$_proxy_port' succ '" . ($response->is_success()) . "' data '$data' content '" . $response->content() . "'\n";
			}
			$_proxy_port ||= 1;
			# We can quit listening on any of the
			# other ports that may have connected,
			# returning immediately from the wait().
			# So we want to return C_ENDALL.  Except
			# C_ENDALL doesn't seem to _work_, it
			# crashes in _remove_current_connection.
			# Argh.  So we use C_LASTCON.
			return LWP::Parallel::UserAgent::C_LASTCON;
		}
#print STDERR scalar(localtime) . " _cfop_callback protocol '$protocol' succ '0'\n";
	}

#print STDERR scalar(localtime) . " cfop beginning registering\n";
	for my $port (@ports) {
		# We switch to a new proxy every time thru.
		$pua->proxy('http', "http://$ip:$port/");
		my $req = HTTP::Request->new(GET => $ok_url);
		$req->{_slash_proxytest_port} = $port;
#print STDERR scalar(localtime) . " cfop registering for proxy '$pua->{proxy}{http}'\n";
		$pua->register($req, \&_cfop_callback);
	}
#print STDERR scalar(localtime) . "pua: " . Dumper($pua);
	my $elapsed = time - $start_time;
	my $wait_timeout = $timeout - $elapsed;
	$wait_timeout = 1 if $wait_timeout < 1;
	$pua->wait($wait_timeout);
#print STDERR scalar(localtime) . " cfop done with wait, returning " . (defined $_proxy_port ? 'undef' : "'$port'") . "\n";
	$_proxy_port = 0 if !$_proxy_port;

	# Store this value so we don't keep probing the IP.
	$self->setKnownOpenProxy($ip, $_proxy_port);

	return $_proxy_port;
}

##################################################################
# For backwards compatibility, returns just the number of comments if
# called in scalar context, or a list of (number of comments, sum of
# the mods done to them) in list context.
sub getNumCommPostedAnonByIPID {
	my($self, $ipid, $hours, $start_cid) = @_;
	my $constants = getCurrentStatic();
	$ipid = $self->sqlQuote($ipid);
	$hours ||= 24;
	my $cid_clause = $start_cid ? " AND cid >= $start_cid" : "";
	my $ac_uid = $self->sqlQuote(getCurrentStatic("anonymous_coward_uid"));
	my $table_extras = "";
	$table_extras .= " IGNORE INDEX(uid_date)" if $constants->{ignore_uid_date_index};
	my $ar = $self->sqlSelectArrayRef(
		"COUNT(*) AS count, SUM(pointsorig-points) AS sum",
		"comments $table_extras",
		"ipid=$ipid
		 AND uid=$ac_uid
		 AND date >= DATE_SUB(NOW(), INTERVAL $hours HOUR)
		 $cid_clause"
	);
	my($num_comm, $sum_mods) = @$ar;
	$sum_mods ||= 0;
	if (wantarray()) {
		return ($num_comm, $sum_mods);
	} else {
		return $num_comm;
	}
}

##################################################################
# For backwards compatibility, returns just the number of comments if
# called in scalar context, or a list of (number of comments, sum of
# the mods done to them) in list context.
sub getNumCommPostedByUID {
	my($self, $uid, $hours, $start_cid) = @_;
	$uid = $self->sqlQuote($uid);
	$hours ||= 24;
	my $cid_clause = $start_cid ? " AND cid >= $start_cid" : "";
	my $ar = $self->sqlSelectArrayRef(
		"COUNT(*) AS count, SUM(points-pointsorig) AS sum",
		"comments",
		"uid=$uid
		 AND date >= DATE_SUB(NOW(), INTERVAL $hours HOUR)
		 $cid_clause"
	);
	my($num_comm, $sum_mods) = @$ar
		if ref($ar) eq 'ARRAY';
	$sum_mods ||= 0;
	if (wantarray()) {
		return ($num_comm, $sum_mods);
	} else {
		return $num_comm;
	}
}

##################################################################
sub getUIDStruct {
	my($self, $column, $id) = @_;

	my $uidstruct;
	my $where = [ ];
	$id = md5_hex($id) if length($id) != 32;
	if ($column eq 'md5id') {
		$where = [( "ipid = '$id'", "subnetid = '$id'" )];
	} elsif ($column =~ /^(ipid|subnetid)$/) {
		$where = [( "$column = '$id'" )];
	} else {
		return [ ];
	}

	my $uidlist;
	$uidlist = [ ];
	for my $w (@$where) {
		push @$uidlist, @{$self->sqlSelectAll("DISTINCT uid", "comments", $w)};
	}

	for (@$uidlist) {
		my $uid;
		$uid->{nickname} = $self->getUser($_->[0], 'nickname');
		$uid->{comments} = 1;
		$uidstruct->{$_->[0]} = $uid;
	}

	$uidlist = [ ];
	for my $w (@$where) {
		push @$uidlist, @{$self->sqlSelectAll("DISTINCT uid", "submissions", $w)};
	}

	for (@$uidlist) {
		if (exists $uidstruct->{$_->[0]}) {
			$uidstruct->{$_->[0]}{submissions} = 1;
		} else {
			my $uid;
			$uid->{nickname} = $self->getUser($_->[0], 'nickname');
			$uid->{submissions} = 1;
			$uidstruct->{$_->[0]} = $uid;
		}
	}

	$uidlist = [ ];
	for my $w (@$where) {
		push @$uidlist, @{$self->sqlSelectAll("DISTINCT uid", "moderatorlog", $w)};
	}

	for (@$uidlist) {
		if (exists $uidstruct->{$_->[0]}) {
			$uidstruct->{$_->[0]}{moderatorlog} = 1;
		} else {
			my $uid;
			$uid->{nickname} = $self->getUser($_->[0], 'nickname');
			$uid->{moderatorlog} = 1;
			$uidstruct->{$_->[0]} = $uid;
		}
	}

	return $uidstruct;
}

##################################################################
sub getNetIDStruct {
	my($self, $id) = @_;

	my $ipstruct;
	my $vislength = getCurrentStatic('id_md5_vislength');
	my $column4 = "ipid";
	$column4 = "SUBSTRING(ipid, 1, $vislength)" if $vislength;

	my $iplist = $self->sqlSelectAll(
		"ipid,
		MIN(SUBSTRING(date, 1, 10)) AS dmin,
		MAX(SUBSTRING(date, 1, 10)) AS dmax,
		COUNT(*) AS c, $column4 as ipid_vis",
		"comments",
		"uid = '$id' AND ipid != ''",
		"GROUP BY ipid ORDER BY dmax DESC, dmin DESC, c DESC, ipid ASC LIMIT 100");

	for (@$iplist) {
		my $ip;
		$ip->{dmin} = $_->[1];
		$ip->{dmax} = $_->[2];
		$ip->{count} = $_->[3];
		$ip->{ipid_vis} = $_->[4];
		$ip->{comments} = 1;
		$ipstruct->{$_->[0]} = $ip;
	}

	$iplist = $self->sqlSelectAll(
		"ipid,
		MIN(SUBSTRING(time, 1, 10)) AS dmin,
		MAX(SUBSTRING(time, 1, 10)) AS dmax,
		COUNT(*) AS c, $column4 as ipid_vis",
		"submissions",
		"uid = '$id' AND ipid != ''",
		"GROUP BY ipid ORDER BY dmax DESC, dmin DESC, c DESC, ipid ASC LIMIT 100");

	for (@$iplist) {
		if (exists $ipstruct->{$_->[0]}) {
			$ipstruct->{$_->[0]}{dmin} = ($ipstruct->{$_->[0]}{dmin} lt $_->[1]) ? $ipstruct->{$_->[0]}{dmin} : $_->[1];
			$ipstruct->{$_->[0]}{dmax} = ($ipstruct->{$_->[0]}{dmax} gt $_->[2]) ? $ipstruct->{$_->[0]}{dmax} : $_->[2];
			$ipstruct->{$_->[0]}{count} += $_->[3];
			$ipstruct->{$_->[0]}{submissions} = 1;
		} else {
			my $ip;
			$ip->{dmin} = $_->[1];
			$ip->{dmax} = $_->[2];
			$ip->{count} = $_->[3];
			$ip->{ipid_vis} = $_->[4];
			$ip->{submissions} = 1;
			$ipstruct->{$_->[0]} = $ip;
		}
	}

	$iplist = $self->sqlSelectAll(
		"ipid,
		MIN(SUBSTRING(ts, 1, 10)) AS dmin,
		MAX(SUBSTRING(ts, 1, 10)) AS dmax,
		COUNT(*) AS c, $column4 as ipid_vis",
		"moderatorlog",
		"uid = '$id' AND ipid != ''",
		"GROUP BY ipid ORDER BY dmax DESC, dmin DESC, c DESC, ipid ASC LIMIT 100");

	for (@$iplist) {
		if (exists $ipstruct->{$_->[0]}) {
			$ipstruct->{$_->[0]}{dmin} = ($ipstruct->{$_->[0]}{dmin} lt $_->[1]) ? $ipstruct->{$_->[0]}{dmin} : $_->[1];
			$ipstruct->{$_->[0]}{dmax} = ($ipstruct->{$_->[0]}{dmax} gt $_->[2]) ? $ipstruct->{$_->[0]}{dmax} : $_->[2];
			$ipstruct->{$_->[0]}{count} += $_->[3];
			$ipstruct->{$_->[0]}{moderatorlog} = 1;
		} else {
			my $ip;
			$ip->{dmin} = $_->[1];
			$ip->{dmax} = $_->[2];
			$ip->{count} = $_->[3];
			$ip->{ipid_vis} = $_->[4];
			$ip->{moderatorlog} = 1;
			$ipstruct->{$_->[0]} = $ip;
		}
	}

	return $ipstruct;
}

########################################################
sub getSubnetFromIPID {
	my($self, $ipid) = @_;
	my $ipid_q = $self->sqlQuote($ipid);
	my($subnet) = $self->sqlSelect("subnetid", "comments", "ipid = $ipid_q AND subnetid IS NOT NULL and subnetid!=''", "LIMIT 1");
	return $subnet;
}

########################################################
sub getBanList {
	my($self, $refresh) = @_;
	my $constants = getCurrentStatic();
	my $debug = $constants->{debug_db_cache};
	my $mcd = $self->getMCD();
	my $mcdkey = "$self->{_mcd_keyprefix}:al:ban" if $mcd;
	my $banlist_ref;

	# Randomize the expire time a bit;  it's not good for the DB
	# to have every process re-ask for this at the exact same time.
	my $expire_time = $constants->{banlist_expire};
	$expire_time += int(rand(60)) if $expire_time;
	_genericCacheRefresh($self, 'banlist', $expire_time);
	my $banlist_ref = $self->{_banlist_cache} ||= {};
	$banlist_ref = $self->{_banlist_cache} ||= {};

	if (!keys %$banlist_ref && $mcd) {
		$banlist_ref = $mcd->get($mcdkey);
		return $banlist_ref if $banlist_ref;
	}

	%$banlist_ref = () if $refresh;

	if (!keys %$banlist_ref) {
		if ($debug) {
			print STDERR scalar(gmtime) . " gBL pid $$ (re)fetching Ban data\n";
		}
		my $list = $self->sqlSelectAll(
			"ipid, subnetid, uid",
			"accesslist",
			"now_ban = 'yes'");
		for (@$list) {
			$banlist_ref->{$_->[0]} = 1 if $_->[0];
			$banlist_ref->{$_->[1]} = 1 if $_->[1];
			$banlist_ref->{$_->[2]} = 1 if $_->[2]
				&& $_->[2] != $constants->{anon_coward_uid};
		}
		# why this? in case there are no banned users.
		# (this should be unnecessary;  we could use another var to
		# indicate whether the cache is fresh, besides checking its
		# number of keys at the top of this "if")
		$banlist_ref->{_junk_placeholder} = 1;
		$self->{_banlist_cache_time} = time() if !$self->{_banlist_cache_time};

		if ($mcd) {
			$mcd->set($mcdkey, $banlist_ref, $constants->{banlist_expire} || 900);
		}
	}

	if ($debug) {
		my $time = time;
		my $diff = $time - $self->{_banlist_cache_time};
		print STDERR scalar(gmtime) . " pid $$ gBL time='$time' diff='$diff' self->_banlist_cache_time='$self->{_banlist_cache_time}' self->{_banlist_cache} keys: " . scalar(keys %{$self->{_banlist_cache}}) . "\n";
	}

	return $banlist_ref;
}

########################################################
sub getNetIDPostingRestrictions {
	my($self, $type, $value) = @_;
	my $constants = getCurrentStatic();
	my $restrictions = { no_anon => 0, no_post => 0 };
	if ($type eq "subnetid") {
		my $subnet_karma_comments_needed = $constants->{subnet_comments_posts_needed};
		my($subnet_karma, $subnet_post_cnt) = $self->getNetIDKarma("subnetid", $value);
		my($sub_anon_max, $sub_anon_min, $sub_all_max, $sub_all_min ) = @{$constants->{subnet_karma_post_limit_range}};
		if ($subnet_post_cnt >= $subnet_karma_comments_needed) {
			if ($subnet_karma >= $sub_anon_min && $subnet_karma <= $sub_anon_max) {
				$restrictions->{no_anon} = 1;
			}
			if ($subnet_karma >= $sub_all_min && $subnet_karma <= $sub_all_max) {
				$restrictions->{no_post} = 1;
			}
		}
	}
	return $restrictions;
}

########################################################
sub getNorssList {
	my($self, $refresh) = @_;
	my $constants = getCurrentStatic();
	my $debug = $constants->{debug_db_cache};

	_genericCacheRefresh($self, 'norsslist', $constants->{banlist_expire});
	my $norsslist_ref = $self->{_norsslist_cache} ||= {};

	%$norsslist_ref = () if $refresh;

	if (!keys %$norsslist_ref) {
		if ($debug) {
			print STDERR scalar(gmtime) . " gNL pid $$ (re)fetching Norss data\n";
		}
		my $list = $self->sqlSelectAll(
			"ipid, subnetid",
			"accesslist",
			"now_norss = 'yes'");
		for (@$list) {
			$norsslist_ref->{$_->[0]} = 1 if $_->[0];
			$norsslist_ref->{$_->[1]} = 1 if $_->[1];
		}
		# why this? in case there are no RSS-banned users.
		# (this should be unnecessary;  we could use another var to
		# indicate whether the cache is fresh, besides checking its
		# number of keys at the top of this "if")
		$norsslist_ref->{_junk_placeholder} = 1;
		$self->{_norsslist_cache_time} = time() if !$self->{_norsslist_cache_time};
	}

	if ($debug) {
		my $time = time;
		my $diff = $time - $self->{_norsslist_cache_time};
		print STDERR scalar(gmtime) . " pid $$ gNL time='$time' diff='$diff' self->_norsslist_cache_time='$self->{_norsslist_cache_time}' self->{_norsslist_cache} keys: " . scalar(keys %{$self->{_norsslist_cache}}) . "\n";
	}

	return $norsslist_ref;
}

########################################################
sub getNopalmList {
	my($self, $refresh) = @_;
	my $constants = getCurrentStatic();
	my $debug = $constants->{debug_db_cache};

	_genericCacheRefresh($self, 'nopalmlist', $constants->{banlist_expire});
	my $nopalmlist_ref = $self->{_nopalmlist_cache} ||= {};

	%$nopalmlist_ref = () if $refresh;

	if (!keys %$nopalmlist_ref) {
		if ($debug) {
			print STDERR scalar(gmtime) . " gNL pid $$ (re)fetching Nopalm data\n";
		}
		my $list = $self->sqlSelectAll(
			"ipid, subnetid",
			"accesslist",
			"now_nopalm = 'yes'");
		for (@$list) {
			$nopalmlist_ref->{$_->[0]} = 1 if $_->[0];
			$nopalmlist_ref->{$_->[1]} = 1 if $_->[1];
		}
		# why this? in case there are no Palm-banned users.
		# (this should be unnecessary;  we could use another var to
		# indicate whether the cache is fresh, besides checking its
		# number of keys at the top of this "if")
		$nopalmlist_ref->{_junk_placeholder} = 1;
		$self->{_nopalmlist_cache_time} = time() if !$self->{_nopalmlist_cache_time};
	}

	if ($debug) {
		my $time = time;
		my $diff = $time - $self->{_nopalmlist_cache_time};
		print STDERR scalar(gmtime) . " pid $$ gNL time='$time' diff='$diff' self->_nopalmlist_cache_time='$self->{_nopalmlist_cache_time}' self->{_nopalmlist_cache} keys: " . scalar(keys %{$self->{_nopalmlist_cache}}) . "\n";
	}

	return $nopalmlist_ref;
}

##################################################################
sub getAccessList {
	my($self, $min, $access_type) = @_;
	$min ||= 0;
	my $max = $min + 100;

	$access_type = 'nopost' if !$access_type
		|| $access_type !~ /^(ban|nopost|nosubmit|norss|nopalm|proxy|trusted)$/;
	$self->sqlSelectAllHashrefArray(
		'*',
		'accesslist',
		"now_$access_type = 'yes'",
		"ORDER BY ts DESC LIMIT $min, $max");
}

##################################################################
sub getTopAbusers {
	my($self, $min) = @_;
	$min ||= 0;
	my $max = $min + 100;
	my $other = "GROUP BY ipid ORDER BY abusecount DESC LIMIT $min,$max";
	$self->sqlSelectAll("COUNT(*) AS abusecount,uid,ipid,subnetid",
		"abusers", "", $other);
}

##################################################################
sub getAbuses {
	my($self, $key, $id) = @_;
	my $id_q = $self->sqlQuote($id);
	$self->sqlSelectAll('ts,uid,ipid,subnetid,pagename,reason',
		'abusers',  "$key = $id_q", 'ORDER by ts DESC');
}

##################################################################
# grabs the number of rows in the last X rows of accesslog, in order
# to get an idea of recent hits
# If called wanting a scalar, just returns the total number of
# hits.
# If called wanting an array, returns an array whose first
# item is the total number of hits, and whose next 5 items
# (indexed 1 thru 5 of course) are the number of hits with
# status codes 1xx, 2xx, 3xx, 4xx and 5xx respectively.
sub countAccessLogHitsInLastX {
	my($self, $field, $check, $x) = @_;
	$x ||= 1000;
	$check = md5hex($check) if length($check) != 32 && $field ne 'uid';
	my $where = '';

	my($max) = $self->sqlSelect("MAX(id)", "accesslog");
	my $min = $max - $x;

	if ($field eq 'uid') {
		$where = "uid=$check ";
	} elsif ($field eq 'md5id') {
		$where = "(host_addr='$check' OR subnetid='$check') ";
	} else {
		$where = "$field='$check' ";
	}

	$where .= "AND id BETWEEN $min AND $max";

	if (wantarray) {
		my $hr = $self->sqlSelectAllHashref(
			"statusxx",
			"FLOOR(status/100)*100 AS statusxx, COUNT(*) AS c",
			"accesslog",
			$where,
			"GROUP BY statusxx");
		my @retval = ( 0 );
		for my $statusxx (qw( 100 200 300 400 500 )) {
			my $c = $hr->{$statusxx}{c} || 0;
			$retval[0] += $c;
			push @retval, $c;
		}
		return @retval;
	} else {
		return $self->sqlCount("accesslog", $where);
	}
}

##################################################################
# Pass this private utility method a user hashref and, based on the
# uid/ipid/subnetid fields, it returns:
# 1. an arrayref of WHERE clauses that can be used to select rows
#    from accesslist that apply to this user;
# 2. a hashref meant to be passed to sqlUpdate() if it is desired
#    to create a row in accesslist for this user.
sub _get_insert_and_where_accesslist {
	my($self, $user_check) = @_;

	my($where_ary, $insert_hr);

	$user_check ||= getCurrentUser();
	if ($user_check) {
		if ($user_check->{uid} =~ /^\d+$/ && !isAnon($user_check->{uid})) {
			$where_ary = [ "uid = $user_check->{uid}" ];
			$insert_hr->{uid} = $user_check->{uid};
		} elsif ($user_check->{ipid}) {
			$where_ary = [ "ipid = '$user_check->{ipid}'" ];
			$insert_hr->{ipid} = $user_check->{ipid};
		} elsif ($user_check->{subnetid}) {
			$where_ary = [ "subnetid = '$user_check->{subnetid}'" ];
			$insert_hr->{subnetid} = $user_check->{subnetid};
		} elsif ($user_check->{md5id}) {
			$where_ary = [
				"ipid = '$user_check->{md5id}'",
				"subnetid = '$user_check->{md5id}'",
			];
			$insert_hr->{ipid} = $insert_hr->{subnetid} = $user_check->{md5id};
		} else {
			return undef;
		}
	}

	return($where_ary, $insert_hr);
}

##################################################################
# returns a hashref with reason and ts fields
sub getAccessListInfo {
	my($self, $access_type, $user_check) = @_;
	$access_type = 'nopost' if !$access_type
		|| $access_type !~ /^(ban|nopost|nosubmit|norss|nopalm|proxy|trusted)$/;

	my $constants = getCurrentStatic();
	my $ref = {};
	my($where_ary) = $self->_get_insert_and_where_accesslist($user_check);
	for my $where (@$where_ary) {
		$where .= " AND now_$access_type = 'yes'";
	}

	my $info = undef;
	for my $where (@$where_ary) {
		$ref = $self->sqlSelectAll("reason, ts, adminuid, estimated_users", 'accesslist', $where);
		for my $row (@$ref) {
			$info ||= { };
			if (!exists($info->{reason}) || $info->{reason} eq '') {
				$info->{reason}	= $row->[0];
				$info->{ts}	= $row->[1];
				$info->{adminuid} = $row->[2];
				$info->{estimated_users} = $row->[3];
			} elsif ($info->{reason} ne $row->[0]) {
				$info->{reason}	= 'multiple';
				$info->{ts}	= 'multiple';
				$info->{adminuid} = 0;
				$info->{estimated_users} = $row->[3];
				# At this point we're done, since the
				# reason and time can't change anymore,
				# so short-circuit out of the loop.
				return $info;
			}
		}
	}

	return $info;
}

##################################################################
# Add (set to "yes") zero or more columns in accesslist for a particular
# user, and remove (set to "no") zero or more columns.  Note that "user"
# can be identified by uid, ipid, or subnetid.  The old reason will be
# overwritten with whatever's passed in.
sub changeAccessList {
	my($self, $user_check, $now_here, $now_gone, $reason) = @_;

	my($where_ary) = $self->_get_insert_and_where_accesslist($user_check);
	my $where = join(" OR ", @$where_ary);
	my $ar = $self->sqlSelectAllHashrefArray("*", "accesslist", $where);

	if (!@$ar) {
		# No existing columns;  just add what has to be added.
		return $self->setAccessList($user_check, $now_here, $reason);
	}

	# We have existing columns.  Pull out the union of the "yes"
	# columns, change that by the $now_here and $now_gone we were
	# passed, and write it back.
	my @cols = map { /^now_(\w+)$/; $1 } grep { /^now_/ } keys %{$ar->[0]};
	my %new_now = ( );
	for my $col (@cols) {
		$new_now{$col} = 'no';
	}
	for my $col (@cols) {
		for my $row (@$ar) {
			$new_now{$col} = 'yes' if $row->{"now_$col"} eq 'yes';
		}
	}
	for my $col (@$now_here) { $new_now{$col} = 'yes' }
	for my $col (@$now_gone) { delete $new_now{$col}  }
	my @new_now = grep { $new_now{$_} eq 'yes' } keys %new_now;
	return $self->setAccessList($user_check, \@new_now, $reason);
}

##################################################################
sub setAccessList {
	# Old comment: Do not use this method to set/unset expired or isproxy
	# New comment: Feel free to use this method to set isproxy.  "Expired"
	# is still not functional. - Jamie 2003/03/04
	my($self, $user_check, $new_now, $reason) = @_;
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	# "Expired" isn't implemented yet.
	return if $reason eq 'expired';

	my $where = "reason != 'expired'";

	my($where_ary, $insert_hr) = $self->_get_insert_and_where_accesslist($user_check);
	# Hopefully the $user_check we're given will specify its data type
	# but in case we're passed just an {md5id}, we will get two clauses
	# returned in $where_ary and we'll need to join them.
	$where .= " AND (" . join(" OR ", @$where_ary) . ")";

	# Set up the update hashref and the assignment order for it.
	my $update_hr = { -ts => "NOW()" };
	my %new_now_hash = map { ($_, 1) } @$new_now;
	my @assn_order = ( );
	for my $col (qw( ban nopost nosubmit norss nopalm proxy trusted )) {
		$update_hr->{"-was_$col"} = "now_$col";
		push @assn_order, "-was_$col";
		$update_hr->{"now_$col"} = $new_now_hash{$col} ? "yes" : "no";
		push @assn_order, "now_$col";
	}
	$update_hr->{reason} = $reason;

	my $adminuid = getCurrentUser('uid');
	$adminuid = 0 if isAnon($adminuid);
	$insert_hr->{adminuid} = $update_hr->{adminuid} = $adminuid;

	# Insert if necessary, then do the update.
	my $rows = $self->sqlCount("accesslist", $where) || 0;
	if ($rows == 0) {
		# No row currently exists for this uid, ipid or subnetid.
		# If we are setting anything to "yes" or have a reason,
		# then we need to go ahead, otherwise there is no point
		# to this.
		if (exists $update_hr->{reason}
			||
			scalar grep { $update_hr->{$_} eq 'yes' }
				grep /^now_/, keys %$update_hr
		) {
			# Insert a row.  Then we will update it.  Set
			# $rows to indicate that this was done.
			$rows = $self->sqlInsert("accesslist", $insert_hr);
		}
	}
	if ($rows) {
		# If there is 1 or more rows to update, or if there weren't
		# but we inserted one, then do this update.
		$rows = $self->sqlUpdate("accesslist", $update_hr, $where,
			{ assn_order => [ @assn_order ] });
	}
	return $rows ? 1 : 0;
}

#################################################################
# Should probably cache this instead of relying on MySQL's query cache.
sub checkIsProxy {
	my($self, $ipid) = @_;

	my $ipid_q = $self->sqlQuote($ipid);
	my $rows = $self->sqlCount("accesslist",
		"ipid=$ipid_q AND now_proxy = 'yes'") || 0;

	return $rows ? 'yes' : 'no';
}

#################################################################
# Should probably cache this instead of relying on MySQL's query cache.
sub checkIsTrusted {
	my($self, $ipid) = @_;

	my $ipid_q = $self->sqlQuote($ipid);
	my $rows = $self->sqlCount("accesslist",
		"ipid=$ipid_q AND now_trusted = 'yes'") || 0;

	return $rows ? 'yes' : 'no';
}

##################################################################
# Check to see if the formkey already exists
# i know this slightly overlaps what checkForm does, but checkForm
# returns data i don't want, and checks for formname which isn't
# necessary, since formkey is a unique key
sub existsFormkey {
	my($self, $formkey) = @_;
	my $keycheck = $self->sqlSelect("formkey", "formkeys", "formkey='$formkey'");
	return $keycheck eq $formkey ? 1 : 0;
}


##################################################################
# Check to see if the form already exists
sub checkForm {
	my($self, $formkey, $formname) = @_;
	$self->sqlSelect(
		"value,submit_ts",
		"formkeys",
		"formkey=" . $self->sqlQuote($formkey)
			. " AND formname = '$formname'"
	);
}

##################################################################
# Current admin users
sub currentAdmin {
	my($self) = @_;
	my $aids = $self->sqlSelectAll(
		'nickname,lasttime,lasttitle,last_subid,last_sid,sessions.uid',
		'sessions,users',
		'sessions.uid=users.uid GROUP BY sessions.uid'
	);

	return $aids;
}

# XXXSECTIONTOPICS pulled getTopNewsstoryTopics out.  Was only referenced in
# top topics in topics.pl which is now gone.  If we bring that back we'll
# want to rewrite getTopNewsstoryTopics 

sub getTopPollTopics {
	my($self, $limit) = @_;
	my $all = 1 if !$limit;

	$limit =~ s/\D+//g;
	$limit = 10 if !$limit || $limit == 1;
	my $sect_clause;
	my $other  = $all ? '' : "LIMIT $limit";
	my $topics = $self->sqlSelectAllHashrefArray(
		"topics.tid AS tid, alttext, COUNT(*) AS cnt, default_image, MAX(date) AS tme",
		'topics,pollquestions',
		"polltype != 'nodisplay'
		AND autopoll = 'no' 
		AND date <= NOW()
		AND topics.tid=pollquestions.topic
		GROUP BY topics.tid
		ORDER BY tme DESC
		$other"
	);

	# fix names
	for (@$topics) {
		$_->{count}  = delete $_->{cnt};
		$_->{'time'} = delete $_->{tme};
	}
	return $topics;
}


##################################################################
# Get poll
# Until today, this has returned an arrayref of arrays, each
# subarray having 5 values (question, answer, aid, votes, qid).
# Since sid can no longer point to more than one poll, there
# can now be only one question, so there's no point in repeating
# it;  the return format is now a hashref.  Only one place in the
# core code calls this (Slash::Utility::Display::pollbooth) and
# only one template (pollbooth;misc;default) uses its values;
# both have been updated of course.  - Jamie 2002/04/03
sub getPoll {
	my($self, $qid) = @_;
	my $qid_quoted = $self->sqlQuote($qid);
	# First select info about the question...
	my $pollq = $self->sqlSelectHashref(
		"*", "pollquestions",
		"qid=$qid_quoted");
	# Then select all the answers.
	my $answers_hr = $self->sqlSelectAllHashref(
		"aid",
		"aid, answer, votes",
		"pollanswers",
		"qid=$qid_quoted"
	);
	# Do the sort in perl, it's faster than asking the DB to do
	# an ORDER BY.
	my @answers = ( );
	for my $aid (sort
		{ $answers_hr->{$a}{aid} <=> $answers_hr->{$b}{aid} }
		keys %$answers_hr) {
		push @answers, {
			answer =>	$answers_hr->{$aid}{answer},
			aid =>		$answers_hr->{$aid}{aid},
			votes =>	$answers_hr->{$aid}{votes},
		};
	}
	return {
		pollq =>	$pollq,
		answers =>	\@answers
	};
}

##################################################################
sub getSubmissionsSkins {
	my($self, $skin) = @_;
	my $del = getCurrentForm('del');

	my $skin_clause = $skin ? " AND skins.name = '$skin' " : '';

	my $hash = $self->sqlSelectAll("skins.name, note, COUNT(*)",
		'submissions LEFT JOIN skins ON skins.skid = submissions.primaryskid',
		"del=$del AND submittable='yes' $skin_clause",
		"GROUP BY primaryskid, note");

	return $hash;
}

##################################################################
# Get submission count
sub getSubmissionsPending {
	my($self, $uid) = @_;
	my $submissions;

	$uid ||= getCurrentUser('uid');

	$submissions = $self->sqlSelectAll(
		"time, subj, primaryskid, tid, del",
		"submissions",
		"uid=$uid",
		"ORDER BY time ASC"
	);

	return $submissions;
}

##################################################################
# Get submission count
# XXXSECTIONTOPICS might need to do something for $articles_only option
# currently not used anywhere in code so not implemented for now.

sub getSubmissionCount {
	my($self) = @_;
	my($count);
	$count = $self->sqlSelect("count(*)", "submissions",
		"(length(note)<1 or isnull(note)) and del=0"
	);
	return $count;
}

##################################################################
# Get all portals
sub getPortals {
	my($self) = @_;
	my $mainpage_name = $self->getSkin( getCurrentStatic('mainpage_skid') )->{name};
	my $portals = $self->sqlSelectAll('block,title,blocks.bid,url','blocks',
		"skin='$mainpage_name' AND type='portald'",
		'GROUP BY bid ORDER BY ordernum');

	return $portals;
}

##################################################################
# Get standard portals
sub getPortalsCommon {
	my($self) = @_;

	return($self->{_boxes}, $self->{_skinBoxes}) if keys %{$self->{_boxes}};
	$self->{_boxes} = {};
	$self->{_skinBoxes} = {};

	# XXXSECTIONTOPICS not sure what the right thing is, here
	my $skins = $self->getDescriptions('skins-all');

	my $qlid = $self->_querylog_start("SELECT", "blocks");
	my $sth = $self->sqlSelectMany(
			'bid,title,url,skin,portal,ordernum,all_skins',
			'blocks',
			'',
			'ORDER BY ordernum ASC'
	);
	# We could get rid of tmp at some point
	my %tmp;
	while (my $SB = $sth->fetchrow_hashref) {
		$self->{_boxes}{$SB->{bid}} = $SB;  # Set the Slashbox
		next unless $SB->{ordernum} > 0;  # Set the index if applicable
		if ($SB->{all_skins}) {
			for my $skin (keys %$skins) {
				push @{$tmp{$skin}}, $SB->{bid};
			}
		} else {
			my $skin = $self->getSkin($SB->{skin});
			push @{$tmp{$skin->{skid}}}, $SB->{bid};
		}
	}
	$self->{_skinBoxes} = \%tmp;
	$sth->finish;
	$self->_querylog_finish($qlid);

	return($self->{_boxes}, $self->{_skinBoxes});
}

##################################################################
# Heaps are not optimized for count; use main comments table
sub countCommentsByGeneric {
	my($self, $where_clause, $options) = @_;
	$where_clause = "($where_clause) AND date > DATE_SUB(NOW(), INTERVAL $options->{limit_days} DAY)"
		if $options->{limit_days};
	$where_clause .= " AND cid >= $options->{cid_at_or_after} " if $options->{cid_at_or_after};
	return $self->sqlCount('comments', $where_clause, $options);
}

##################################################################
sub countCommentsBySid {
	my($self, $sid, $options) = @_;
	return 0 if !$sid;
	return $self->countCommentsByGeneric("sid=$sid", $options);
}

##################################################################
sub countCommentsByUID {
	my($self, $uid, $options) = @_;
	return 0 if !$uid;
	return $self->countCommentsByGeneric("uid=$uid", $options);
}

##################################################################
sub countCommentsBySubnetID {
	my($self, $subnetid, $options) = @_;
	return 0 if !$subnetid;
	return $self->countCommentsByGeneric("subnetid='$subnetid'", $options);
}

##################################################################
sub countCommentsByIPID {
	my($self, $ipid, $options) = @_;
	return 0 if !$ipid;
	return $self->countCommentsByGeneric("ipid='$ipid'", $options);
}

##################################################################
sub countCommentsByIPIDOrSubnetID {
	my($self, $id, $options) = @_;
	return 0 if !$id;
	my $ipid_cnt = $self->countCommentsByGeneric("ipid='$id'", $options);
	return wantarray ? ($ipid_cnt, "ipid") : $ipid_cnt if $ipid_cnt;

	my $subnet_cnt = $self->countCommentsByGeneric("subnetid='$id'", $options);
	return wantarray ? ($subnet_cnt, "subnetid") : $subnet_cnt;
}

##################################################################
sub countCommentsBySidUID {
	my($self, $sid, $uid, $options) = @_;
	return 0 if !$sid or !$uid;
	return $self->countCommentsByGeneric("sid=$sid AND uid=$uid", $options);
}

##################################################################
sub countCommentsBySidPid {
	my($self, $sid, $pid, $options) = @_;
	return 0 if !$sid or !$pid;
	return $self->countCommentsByGeneric("sid=$sid AND pid=$pid", $options);
}

##################################################################
# Search on block comparison! No way, easier on everything
# if we just do a match on the signature (AKA MD5 of the comment)
# -Brian
sub findCommentsDuplicate {
	my($self, $sid, $comment) = @_;
	my $sid_quoted = $self->sqlQuote($sid);
	my $signature_quoted = $self->sqlQuote(md5_hex($comment));
	return $self->sqlCount('comments', "sid=$sid_quoted AND signature=$signature_quoted");
}

##################################################################
# counts the number of stories
sub countStory {
	my($self, $tid) = @_;
	my($value) = $self->sqlSelect("count(*)",
		'stories',
		"tid=" . $self->sqlQuote($tid));

	return $value;
}


##################################################################
# Handles moderation
# Moderates a specific comment. 
# Returns 0 or 1 for whether the comment changed
# Returns a negative value when an error was encountered. The
# warning the user sees is handled within the .pl file
#
# Currently defined error types:
# -1 - No points
# -2 - Not enough points
#
##################################################################

sub moderateComment {
	my($self, $sid, $cid, $reason, $options) = @_;
	return 0 unless dbAvailable("write_comments");
	return 0 unless $reason;
	$options ||= {};

	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	my $comment_changed = 0;
	my $superAuthor = $options->{is_superauthor}
		|| ( $constants->{authors_unlimited}
			&& $user->{seclev} >= $constants->{authors_unlimited} );

	if ($user->{points} < 1 && !$superAuthor) {
		return -1;
	}

	my $comment = $self->getComment($cid);

	$comment->{time_unixepoch} = timeCalc($comment->{date}, "%s", 0);

	# The user should not have been been presented with the menu
	# to moderate if any of the following tests trigger, but,
	# an unscrupulous user could have faked their submission with
	# or without us presenting them the menu options.  So do the
	# tests again.
	unless ($superAuthor) {
		# Do not allow moderation of any comments with the same UID as the
		# current user (duh!).
		return 0 if $user->{uid} == $comment->{uid};
		# Do not allow moderation of any comments (anonymous or otherwise)
		# with the same IP as the current user.
		return 0 if $user->{ipid} eq $comment->{ipid};
		# If the var forbids it, do not allow moderation of any comments
		# with the same *subnet* as the current user.
		return 0 if $constants->{mod_same_subnet_forbid}
			and $user->{subnetid} eq $comment->{subnetid};
		# Do not allow moderation of comments that are too old.
		return 0 unless $comment->{time_unixepoch} >= time() - 3600*
			($constants->{comments_moddable_hours}
				|| 24*$constants->{archive_delay});
	}

	# Start putting together the data we'll need to display to
	# the user.
	my $reasons = $self->getReasons();
	my $dispArgs = {
		cid	=> $cid,
		sid	=> $sid,
		subject => $comment->{subject},
		reason	=> $reason,
		points	=> $user->{points},
		reasons	=> $reasons,
	};

	unless ($superAuthor) {
		my $mid = $self->getModeratorLogID($cid, $user->{uid});
		if ($mid) {
			$dispArgs->{type} = 'already moderated';
			Slash::slashDisplay('moderation', $dispArgs)
				unless $options->{no_display};
			return 0;
		}
	}

	# Add moderation value to display arguments.
	my $val = $reasons->{$reason}{val};
	my $raw_val = $val;
	$val = "+1" if $val == 1;
	$dispArgs->{val} = $val;

	my $scorecheck = $comment->{points} + $val;
	my $active = 1;
	# If the resulting score is out of comment score range, no further
	# actions need be performed.
	# Should we return here and go no further?
	if (	$scorecheck < $constants->{comment_minscore} ||
		($scorecheck > $constants->{comment_maxscore} && $val + $comment->{tweak} > 0 ))
	{
		# We should still log the attempt for M2, but marked as
		# 'inactive' so we don't mistakenly undo it. Mods get modded
		# even if the action didn't "really" happen.
		#
		$active = 0;
		$dispArgs->{type} = 'score limit';
	}

	# Find out how many mod points this will really cost us.  As of
	# Oct. 2002, it might be more than 1.
	my $pointsneeded = $self->getModPointsNeeded(
		$comment->{points},
		$scorecheck,
		$reason);

	# If more than 1 mod point needed, we might not have enough,
	# so this might still fail.
	if ($pointsneeded > $user->{points} && !$superAuthor) {
		return -2;
	}

	# Write the proper records to the moderatorlog.
	$self->createModeratorLog($comment, $user, $val, $reason, $active,
		$pointsneeded);

	if ($active) {

		# If we are here, then the user either has mod points, or
		# is an admin (and 'author_unlimited' is set).  So point
		# checks should be unnecessary here.

		# First, update values for the moderator.
		my $changes = { };
		$changes->{-points} = "GREATEST(points-$pointsneeded, 0)";
		my $tcost = $constants->{mod_unm2able_token_cost} || 0;
		$tcost = 0 if $reasons->{$reason}{m2able};
		$changes->{-tokens} = "tokens - $tcost" if $tcost;
		$changes->{-totalmods} = "totalmods + 1";
		$self->setUser($user->{uid}, $changes);
		$user->{points} -= $pointsneeded;
		$user->{points} = 0 if $user->{points} < 0;

		# Update stats.
		if ($tcost and my $statsSave = getObject('Slash::Stats::Writer')) {
			$statsSave->addStatDaily("mod_tokens_lost_unm2able", $tcost);
		}

		# Apply our changes to the comment.  That last argument
		# is tricky;  we're passing in true for $need_point_change
		# only if the comment was posted non-anonymously.  (If it
		# was posted anonymously, we don't need to know the
		# details of how its point score changed thanks to this
		# mod, because it won't affect anyone's karma.)
		my $poster_was_anon = isAnon($comment->{uid});
		my $karma_change = $reasons->{$reason}{karma};
		$karma_change = 0 if $poster_was_anon;

		my $comment_change_hr =
			$self->setCommentForMod($cid, $val, $reason,
				$comment->{reason});
		if (!defined($comment_change_hr)) {
			# This shouldn't happen;  the only way we believe it
			# could is if $val is 0, the comment is already at
			# min or max score, the user's already modded this
			# comment, or some other reason making this mod invalid.
			# This is really just here as a safety check.
			$dispArgs->{type} = 'logic error';
			Slash::slashDisplay('moderation', $dispArgs)
				unless $options->{no_display};
			return 0;
		}

		# Finally, adjust the appropriate values for the user who
		# posted the comment.
		my $token_change = 0;
		if ($karma_change) {
			# If this was a downmod, it may cost the poster
			# something other than exactly 1 karma.
			if ($karma_change < 0) {
				($karma_change, $token_change) =
					$self->_calc_karma_token_loss(
						$karma_change, $comment_change_hr)
			}
		}
		if ($karma_change) {
			my $cu_changes = { };
			if ($val < 0) {
				$cu_changes->{-downmods} = "downmods + 1";
			} elsif ($val > 0) {
				$cu_changes->{-upmods} = "upmods + 1";
			}
			if ($karma_change < 0) {
				$cu_changes->{-karma} = "GREATEST("
					. "$constants->{minkarma}, karma + $karma_change)";
				$cu_changes->{-tokens} = "tokens + $token_change";
			} elsif ($karma_change > 0) {
				$cu_changes->{-karma} = "LEAST("
					. "$constants->{maxkarma}, karma + $karma_change)";
			}

			# Make the changes to the poster user.
			$self->setUser($comment->{uid}, $cu_changes);

			# Update stats.
			if ($karma_change < 0 and my $statsSave = getObject('Slash::Stats::Writer')) {
				$statsSave->addStatDaily("mod_tokens_lost_downmod",
					$token_change);
			}

		}

		# We know things actually changed, so update points for
		# display and send a message if appropriate.
		$dispArgs->{points} = $user->{points};
		$dispArgs->{type} = 'moderated';
		if (($comment->{points} + $comment->{tweak} + $raw_val) >= $constants->{comment_minscore} &&
		    ($comment->{points} + $comment->{tweak}) >= $constants->{comment_minscore}) {

			my $messages = getObject("Slash::Messages");
			$messages->send_mod_msg({
				type	=> 'mod_msg',
				sid	=> $sid,
				cid	=> $cid,
				val	=> $val,
				reason	=> $reason,
				comment	=> $comment
			}) unless $options->{no_message};
		}
	}

	# Now display the template with the moderation results.
	Slash::slashDisplay('moderation', $dispArgs)
		unless $options->{no_display};

	return 1;
}

sub displaystatusForStories {
	my ($self, $stoids) = (@_);
	my $constants = getCurrentStatic();
	my $ds = {};
	return {} unless $stoids and @$stoids;
	my $stoid_list = join ',', @$stoids;

	my @sections_nexuses = grep {$_ != $constants->{mainpage_nexus_tid}} $self->getNexusTids();
	my $section_nexus_list = join ',',@sections_nexuses;

	my $mainpage = $self->sqlSelectAllHashref(
		'stoid',
		'DISTINCT stories.stoid',
		'stories, story_topics_rendered AS str ',
		"stories.stoid=str.stoid AND str.tid=$constants->{mainpage_nexus_tid} " .
		"AND stories.stoid IN ($stoid_list)",
	);
	my $sectional = $self->sqlSelectAllHashref(
		'stoid',
		'DISTINCT stories.stoid',
		'stories, story_topics_rendered AS str ',
		"stories.stoid=str.stoid AND str.tid in($section_nexus_list) " .
		"AND stories.stoid IN ($stoid_list)",
	);
	my $nd = $self->sqlSelectAllKeyValue(
		"stoid, value",
		"story_param",
		"name='neverdisplay' AND stoid IN ($stoid_list)");

	foreach (@$stoids) {
		if ($nd->{$_}) {
			$ds->{$_} = -1;
		} elsif ($mainpage->{$_}) {
			$ds->{$_} = 0;
		} elsif ($sectional->{$_} ) {
			$ds->{$_} = 1;
		} else {
			$ds->{$_} = -1;
		}
	}
	return $ds;
}

# XXXSECTIONTOPICS
# Allow computation of old displaystatus value.  Hopefully this can
# go away completely and we can come up with a different name and
# get rid of displaystatus altogether.  For now use this to simplify
# conversion later
# XXXSKIN - i think this is broken, maybe only because checkStoryViewable is broken?
sub _displaystatus {
	my($self, $stoid, $options) = @_;
	$options ||= {};
	my $mp_tid = getCurrentStatic('mainpage_nexus_tid');
	if (!$mp_tid) { warn "no mp_tid"; $mp_tid = 1 }
	my $viewable = $self->checkStoryViewable($stoid, "", $options);
	return -1 if !$viewable;
	my $mainpage = $self->checkStoryViewable($stoid, $mp_tid, $options);
	my $displaystatus = $mainpage ? 0 : 1;
	return $displaystatus;
}

sub _calc_karma_token_loss {
	my($self, $reason_karma_change, $comment_change_hr) = @_;
	my $constants = getCurrentStatic();
	my($kc, $tc); # karma change, token change
	$kc = $reason_karma_change;
	if ($constants->{mod_down_karmacoststyle}) {
		if ($constants->{mod_down_karmacoststyle} == 1) {
			my $change = abs($comment_change_hr->{points_max}
				- $comment_change_hr->{points_after});
			$kc *= $change;
		}
	}
	if ($kc < 0 
		&& defined $constants->{comment_karma_limit}
		&& $constants->{comment_karma_limit} ne "") {
		my $future_karma = $comment_change_hr->{karma} + $kc;
		if ($future_karma < $constants->{comment_karma_limit}) {
			$kc = $constants->{comment_karma_limit}
				- $comment_change_hr->{karma};
		}
		$kc = 0 if $kc > 0;
	}
	$tc = $kc;
	return ($kc, $tc);
}

##################################################################
sub metamodEligible {
	my($self, $user) = @_;

	# This should be true since admins should be able to do
	# anything at anytime.  We now also provide admins controls
	# to metamod arbitrary moderations
	return 1 if $user->{is_admin};

	# Easy tests the user can fail to be ineligible to metamod.
	return 0 if $user->{is_anon} || !$user->{willing} || $user->{karma} < 0;

	# Not eligible if metamodded too recently.
	my $constants = getCurrentStatic();
	my $m2_freq = $self->getVar('m2_freq', 'value', 1) || 86400;
	my $cutoff_str = time2str("%Y-%m-%d %H:%M:%S",
		time() - $m2_freq, 'GMT');
	return 0 if $user->{lastmm} ge $cutoff_str;

	# Last test, have to hit the DB for this one.
	my($maxuid) = $self->countUsers({ max => 1 });
	return 0 if $user->{uid} >
		  $maxuid * $constants->{m2_userpercentage};

	# User is OK to metamod.
	return 1;
}

##################################################################
sub getAuthorNames {
	my($self) = @_;
	my $authors = $self->getDescriptions('authors');
	my @authors;
	for (values %$authors){
		push @authors, $_;
	}

	return [sort(@authors)];
}

##################################################################
# XXXSKIN - is this going to do something?
# Not sure what I had meant for this to do.
sub getUniqueSkinsFromStories {
	my($self, $stories) = @_;

	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
}

##################################################################
# XXXSECTIONTOPICS lots of section stuff in here that still needs
# to be looked at as well as the exclusion of topics/sections
#
# AND -- this is important -- this data needs to be cached in
# story_nextprev.  The code for that table isn't written yet:  a
# utils/ script needs to populate it, and freshenup needs to
# update it whenever a dirty story is rewritten.  Until we
# get subqueries this will be a two-select process:
# 	$order =
# 	SELECT order FROM story_nextprev WHERE stoid=$stoid AND tid=$tid
# where $tid is the nexus that the order is to be considered in,
# and then
# 	@next_stoids =
# 	SELECT stoid FROM story_nextprev
# 		WHERE tid=$tid AND order > $order LIMIT $n
# with < instead of > to get the previous stoids of course.
sub getStoryByTime {
	my($self, $sign, $story, $options) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	$options    = {} if !$options || ref($options) ne 'HASH';
	my $limit   = $options->{limit}   || 1;
	my $topic   = $options->{topic}   || '';
	my $section = $options->{section} || '';
	my $where;
	my $name  = 'story_by_time';
	_genericCacheRefresh($self, $name, $constants->{story_expire} || 600); # use same cache time as for stories
	my $cache = $self->{"_${name}_cache"} ||= {};

	$self->{"_${name}_cache_time"} = time() if !keys %$cache;

	# We only do getStoryByTime() for stories that are more recent
	# than twice the story archiving delay (or bytime_delay if defined).
	# If the DB has to scan back thousands of stories, this can really bog.
	# We solve this by having the first clause in the WHERE be an
	# impossible condition for any stories that are too old (this is more
	# straightforward than parsing the timestamp in perl).
	my $time = $story->{time};
	my $bytime_delay = $constants->{bytime_delay} || $constants->{archive_delay}*2;
	$bytime_delay = 7 if $bytime_delay < 7;

	my $order = $sign eq '<' ? 'DESC' : 'ASC';
	my $key = $sign;

	my $mp_tid = $constants->{mainpage_nexus_tid} || 1;
	if (!$section && !$topic && $user->{sectioncollapse}) {
		my $nexuses = $self->getNexusChildrenTids($mp_tid);
		my $nexus_clause = join ',', @$nexuses, $mp_tid;
		$where .= " AND story_topics_rendered.tid IN ($nexus_clause)";
		$key .= '|>=';
	} else {
		$where .= " AND story_topics_rendered.tid = $mp_tid";
		$key .= '|=';
	}

	$where .= " AND stories.stoid != '$story->{stoid}'";
	$key .= "|$story->{stoid}";

	if (!$topic && !$section) {
		$where .= " AND story_topics_rendered.tid NOT IN ($user->{extid})" if $user->{extid};
		$where .= " AND uid NOT IN ($user->{exaid})" if $user->{exaid};
		# don't cache if user has own prefs -- pudge
		$key = $user->{extid} || $user->{exaid} || $user->{exsect} ? '' : $key . '|';
	} elsif ($topic) {
		$where .= " AND story_topics_rendered.tid = '$topic'";
		$key .= "|$topic";
	}

	$key .= "|$time" if $key;

	my $now = $self->sqlQuote( time2str('%Y-%m-%d %H:%M:00', time, 'GMT') );
	
	return $cache->{$key} if $key && defined $cache->{$key};

	my $returnable = $self->sqlSelectHashref(
		'stories.stoid, sid, title, stories.tid',
		'stories, story_text, story_topics_rendered',
		"stories.stoid = story_text.stoid
		 AND stories.stoid = story_topics_rendered.stoid
		 AND '$time' > DATE_SUB($now, INTERVAL $bytime_delay DAY)
		 AND time $sign '$time'
		 AND time <= $now
		 AND in_trash = 'no'
		 $where",

		"GROUP BY stories.stoid ORDER BY time $order LIMIT $limit"
	);
	# needs to be defined as empty
	$cache->{$key} = $returnable || '' if $key;

	return $returnable;
}

##################################################################
#
sub getStorySidFromDiscussion {
	my ($self, $discussion) = (@_);
	return $self->sqlSelect("sid", "stories", "discussion = ".$self->sqlQuote($discussion));
}

##################################################################
# admin.pl only
sub getStoryByTimeAdmin {
	my($self, $sign, $story, $limit) = @_;
	my $where = "";
	my $user = getCurrentUser();
	my $mp_tid = getCurrentStatic('mainpage_nexus_tid');
	$limit ||= 1;

	# '=' is also sometimes used for $sign; in that case,
	# order is irrelevant -- pudge
	my $order = $sign eq '<' ? 'DESC' : 'ASC';

	$where .= " AND sid != '$story->{sid}'";

	my $time = $story->{'time'};
	my $returnable = $self->sqlSelectAllHashrefArray(
		'stories.stoid, title, sid, time',
		'stories, story_text',
		"stories.stoid=story_text.stoid
		 AND time $sign '$time' AND in_trash = 'no' $where",
		"ORDER BY time $order LIMIT $limit"
	);
	foreach my $story (@$returnable) {
		$story->{displaystatus} = $self->_displaystatus($story->{stoid}, { no_time_restrict => 1 });
	}
	return $returnable;
}

########################################################
# Input: $m2_user and %$m2s are the same as for setMetaMod, below.
# $max is the max number of mods that an M2 vote can count on.
# Return: modified %$m2s in place.
sub multiMetaMod {
	my($self, $m2_user, $m2s, $max) = @_;
	return if !$max;

	my $constants = getCurrentStatic();
	my @orig_mmids = keys %$m2s;
	return if !@orig_mmids;
	my $orig_mmid_in = join(",", @orig_mmids);
	my $uid_q = $self->sqlQuote($m2_user->{uid});
	my $reasons = $self->getReasons();
	my $m2able_reasons = join(",",
		sort grep { $reasons->{$_}{m2able} }
		keys %$reasons);
	return if !$m2able_reasons;
	my $max_limit = $max * scalar(@orig_mmids) * 2;

	# $id_to_cr is the cid-reason hashref.  From it we'll make
	# an SQL clause that matches any moderations whose cid and
	# reason both match any of the moderations passed in.
	my $id_to_cr = $self->sqlSelectAllHashref(
		"id",
		"id, cid, reason",
		"moderatorlog",
		"id IN ($orig_mmid_in)
		 AND active=1 AND m2status=0"
	);
	return if !%$id_to_cr;
	my @cr_clauses = ( );
	for my $mmid (keys %$id_to_cr) {
		push @cr_clauses, "(cid=$id_to_cr->{$mmid}{cid}"
			. " AND reason=$id_to_cr->{$mmid}{reason})";
	}
	my $cr_clause = join(" OR ", @cr_clauses);
	my $user_limit_clause = "";
	$user_limit_clause =  " AND uid != $uid_q AND cuid != $uid_q " unless $m2_user->{seclev} >= 100;
	# Get a list of other mods which duplicate one or more of the
	# ones we're modding, but aren't in fact the ones we're modding.
	my $others = $self->sqlSelectAllHashrefArray(
		"id, cid, reason",
		"moderatorlog",
		"($cr_clause)".
		$user_limit_clause.
		" AND m2status=0
		 AND reason IN ($m2able_reasons)
		 AND active=1
		 AND id NOT IN ($orig_mmid_in)",
		"ORDER BY RAND() LIMIT $max_limit"
	);
	# If there are none, we're done.
	return if !$others or !@$others;

	# To decide which of those other mods we can use, we need to
	# limit how many we use for each cid-reason pair.  That means
	# setting up a hashref whose keys are cid-reason pairs, and
	# counting until we hit a limit.  This is so that, in the odd
	# situation where a cid has been moderated a zillion times
	# with one reason, people who metamod one of those zillion
	# moderations will not have undue power (nor undue
	# consequences applied to themselves).

	# Set up the counting hashref, and the hashref to correlate
	# cid-reason back to orig mmid.
	my $cr_count = { };
	my $cr_to_id = { };
	for my $mmid (keys %$m2s) {
		my $cid = $id_to_cr->{$mmid}{cid};
		my $reason = $id_to_cr->{$mmid}{reason};
		$cr_count->{"$cid-$reason"} = 0;
		$cr_to_id->{"$cid-$reason"} = $mmid;
	}
	for my $other_hr (@$others) {
		my $new_mmid = $other_hr->{id};
		my $cid = $other_hr->{cid};
		my $reason = $other_hr->{reason};
		next if $cr_count->{"$cid-$reason"}++ >= $max;
		my $old_mmid = $cr_to_id->{"$cid-$reason"};
		# And here, we add another M2 with the same is_fair
		# value as the old one -- this is the whole purpose
		# for this method.
		my %old = %{$m2s->{$old_mmid}};
		$m2s->{$new_mmid} = \%old;
	}
}

########################################################
# Input: %$m2s is a hash whose keys are moderatorlog IDs (mmids) and
# values are hashrefs with keys "is_fair" (0=unfair, 1=fair).
# $m2_user is the user hashref for the user who is M2'ing.
# $multi_max is the maximum number of additional mods which each
# mod in %$m2s can apply to (see the constants m2_multicount).
# Return: nothing.
# Note that karma and token changes as a result of metamod are
# done in the run_moderatord task.
sub createMetaMod {
	my($self, $m2_user, $m2s, $multi_max, $options) = @_;
	my $constants = getCurrentStatic();
	$options ||= {}; 
	my $rows;

	# If this user has no saved mods, by definition nothing they try
	# to M2 is valid, unless of course they're an admin.
	return if !$m2_user->{mods_saved} && !$m2_user->{is_admin} && !$options->{inherited};

	# The user is only allowed to metamod the mods they were given.
	my @mods_saved = $self->getModsSaved($m2_user);
	my %mods_saved = map { ( $_, 1 ) } @mods_saved;
	my $saved_mods_encountered = 0;
	my @m2s_mmids = sort { $a <=> $b } keys %$m2s;
	for my $mmid (@m2s_mmids) {
		delete $m2s->{$mmid} if !$mods_saved{$mmid} && !$m2_user->{is_admin} &!$options->{inherited};
		$saved_mods_encountered++ if $mods_saved{$mmid};
	}
	return if !keys %$m2s;

	# If we are allowed to multiply these M2's to apply to other
	# mods, go ahead.  multiMetaMod changes $m2s in place.  Note
	# that we first screened %$m2s to allow only what was saved for
	# this user;  having made sure they are not trying to fake an
	# M2 of something disallowed, now we can multiply them out to
	# possibly affect more.  Note that we save the original list --
	# when we tally how many metamods this user has done, we only
	# count their intentions, not the results.
	my %m2s_orig = ( map { $_, 1 } keys %$m2s );
	if ($multi_max) {
		$self->multiMetaMod($m2_user, $m2s, $multi_max);
	}

	# We need to know whether the M1 IDs are for moderations
	# that were up or down.
	my $m1_list = join(",", keys %$m2s);
	my $m2s_vals = $self->sqlSelectAllHashref("id", "id, val",
		"moderatorlog", "id IN ($m1_list)");
	for my $m1id (keys %$m2s_vals) {
		$m2s->{$m1id}{val} = $m2s_vals->{$m1id}{val};
	}

	# Whatever happens below, as soon as we get here, this user has
	# done their M2 for the day and gets their list of OK mods cleared.
	# The only exceptions are admins who didn't metamod any of their saved mods
	# also we don't clear a users mods if the m2s being applied are inherited.
	# In the case of inherited mods the m2_user isn't actively m2ing, their
	# m2s are just being applied to another mod

	if (!$options->{inherited} &&
		!$m2_user->{is_admin}
		|| ($m2_user->{is_admin} && $saved_mods_encountered)) {
		$rows = $self->sqlUpdate("users_info", {
			-lastmm =>	'NOW()',
			mods_saved =>	'',
		}, "uid=$m2_user->{uid} AND mods_saved != ''");
		$self->setUser_delete_memcached($m2_user->{uid});
		if (!$rows) {
			# The update failed, presumably because the user clicked
			# the MetaMod button multiple times quickly to try to get
			# their decisions to count twice.  The user did not count
			# on our awesome powers of atomicity:  only one of those
			# clicks got to set mods_saved to empty.  That one wasn't
			# us, so we do nothing.
			return ;
		}
	}
	my($voted_up_fair, $voted_down_fair, $voted_up_unfair, $voted_down_unfair)
		= (0, 0, 0, 0);
	for my $mmid (keys %$m2s) {
		my $mod_uid = $self->getModeratorLog($mmid, 'uid');
		my $is_fair = $m2s->{$mmid}{is_fair};

		# Increment the m2count on the moderation in question.  If
		# this increment pushes it to the current consensus threshold,
		# change its m2status from 0 ("eligible for M2") to 1
		# ("all done with M2'ing, but not yet reconciled").  Note
		# that we insist not only that the count be above the
		# current consensus point, but that it be odd, in case
		# something weird happens.

		$rows = 0;
		$rows = $self->sqlUpdate(
			"moderatorlog", {
				-m2count =>	"m2count+1",
				-m2status =>	"IF(m2count >= m2needed
							AND MOD(m2count, 2) = 1,
							1, 0)",
			},
			"id=$mmid AND m2status=0
			 AND m2count < m2needed AND active=1",
			{ assn_order => [qw( -m2count -m2status )] },
		) unless $m2_user->{tokens} < $self->getVar("m2_mintokens", "value", 1) &&
			 !$m2_user->{is_admin};

		$rows += 0; # if no error, returns 0E0 (true!), we want a numeric answer

		my $ui_hr = { };
		     if ($is_fair  && $m2s->{$mmid}{val} > 0) {
			++$voted_up_fair if $m2s_orig{$mmid};
			$ui_hr->{-up_fair}	= "up_fair+1";
		} elsif ($is_fair  && $m2s->{$mmid}{val} < 0) {
			++$voted_down_fair if $m2s_orig{$mmid};
			$ui_hr->{-down_fair}	= "down_fair+1";
		} elsif (!$is_fair && $m2s->{$mmid}{val} > 0) {
			++$voted_up_unfair if $m2s_orig{$mmid};
			$ui_hr->{-up_unfair}	= "up_unfair+1";
		} elsif (!$is_fair && $m2s->{$mmid}{val} < 0) {
			++$voted_down_unfair if $m2s_orig{$mmid};
			$ui_hr->{-down_unfair}	= "down_unfair+1";
		}
		$self->sqlUpdate("users_info", $ui_hr, "uid=$mod_uid");

		if ($rows) {
			# If a row was successfully updated, insert a row
			# into metamodlog.
			$self->sqlInsert("metamodlog", {
				mmid =>		$mmid,
				uid =>		$m2_user->{uid},
				val =>		($is_fair ? '+1' : '-1'),
				-ts =>		"NOW()",
				active =>	1,
			});
		} else {
			# If a row was not successfully updated, probably the
			# moderation in question was assigned to more than
			# $consensus users, and the other users pushed it up to
			# the $consensus limit already.  Or this user has
			# gotten bad M2 and has negative tokens.  Or the mod is
			# no longer active.
			$self->sqlInsert("metamodlog", {
				mmid =>		$mmid,
				uid =>		$m2_user->{uid},
				val =>		($is_fair ? '+1' : '-1'),
				-ts =>		"NOW()",
				active =>	0,
			});
		}

		$self->setUser_delete_memcached($mod_uid);
	}

	my $voted = $voted_up_fair || $voted_down_fair || $voted_up_unfair || $voted_down_unfair;
	$self->sqlUpdate("users_info", {
		-m2voted_up_fair	=> "m2voted_up_fair	+ $voted_up_fair",
		-m2voted_down_fair	=> "m2voted_down_fair	+ $voted_down_fair",
		-m2voted_up_unfair	=> "m2voted_up_unfair	+ $voted_up_unfair",
		-m2voted_down_unfair	=> "m2voted_down_unfair	+ $voted_down_unfair",
	}, "uid=$m2_user->{uid}") if $voted;
	$self->setUser_delete_memcached($m2_user->{uid});
}

########################################################
sub countUsers {
	my($self, $options) = @_;
	my $users;
	if ($options && $options->{max}) {
		$users = $self->sqlSelect("MAX(uid)", "users_count");
	} else {
		$users = $self->sqlCount("users_count");
	}
	return $users;
}

########################################################
sub createVar {
	my($self, $name, $value, $desc) = @_;
	$self->sqlInsert('vars', {
		name =>		$name,
		value =>	$value,
		description =>	$desc,
	});
}

########################################################
sub deleteVar {
	my($self, $name) = @_;

	$self->sqlDo("DELETE from vars WHERE name=" .
		$self->sqlQuote($name));
}

########################################################
# This is a little better. Most of the business logic
# has been removed and now resides at the theme level.
#	- Cliff 7/3/01
# It used to return a boolean indicating whether the
# comment was changed.  Now it returns either undef
# (if the comment did not change) or a true value (if
# it did).  If $need_point_change is true, it will
# query the DB to obtain the comment scores before and
# after the change and return that data in a hashref.
# If not, it will just return 1.
sub setCommentForMod {
	my($self, $cid, $val, $newreason, $oldreason) = @_;
	my $raw_val = $val;
	$val += 0;
	return undef if !$val;
	$val = "+$val" if $val > 0;

	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	my $allreasons_hr = $self->sqlSelectAllHashref(
		"reason",
		"reason, COUNT(*) AS c",
		"moderatorlog",
		"cid=$cid AND active=1",
		"GROUP BY reason"
	);
	my $averagereason = $self->getCommentMostCommonReason($cid,
		$allreasons_hr,
		$newreason, $oldreason);

	# Changes we're going to make to this comment.  Note
	# that the pointsmax GREATEST() gets called after
	# points is assigned, thanks to assn_order.
	my $update = {
		-points =>	"points$val",
		-pointsmax =>	"GREATEST(pointsmax, points)",
		reason =>	$averagereason,
		lastmod =>	$user->{uid},
	};

	# If more than n downmods, a comment loses its karma bonus.
	my $reasons = $self->getReasons;
	my $num_downmods = 0;
	for my $reason (keys %$allreasons_hr) {
		$num_downmods += $allreasons_hr->{$reason}{c}
			if $reasons->{$reason}{val} < 0;
	}
	if ($num_downmods > $constants->{mod_karma_bonus_max_downmods}) {
		$update->{karma_bonus} = "no";
	}

	# Make sure we apply this change to the right comment :)
	my $where = "cid=$cid ";
	my $points_extra_where = "";
	if ($val < 0) {
		$points_extra_where .= " AND points > $constants->{comment_minscore}";
	} else {
		$points_extra_where .= " AND points < $constants->{comment_maxscore}";
	}
	$where .= " AND lastmod <> $user->{uid}"
		unless $constants->{authors_unlimited}
			&& $user->{seclev} >= $constants->{authors_unlimited};

	# We do a two-query transaction here:  one select to get
	# the old points value, then the update as part of the
	# same transaction;  that way, we know, based on whether
	# the update succeeded, what the final points value is.
	# If this weren't a transaction, another moderation
	# could happen between the two queries and give us the
	# wrong answer.  On the other hand, if the caller didn't
	# want the point change, we don't need to get any of
	# that data.
	# We have to select cid here because LOCK IN SHARE MODE
	# only works when an indexed column is returned.
	# Of course, this isn't actually going to work at all
	# since the comments table is MyISAM.  Eventually, though,
	# we'll pull the indexed blobs out and into comments_text
	# and make the comments table InnoDB and this will work.
	# Oh well.  Meanwhile, the worst thing that will happen is
	# a few wrong points logged here and there.

#	$self->{_dbh}{AutoCommit} = 0;
	$self->sqlDo("SET AUTOCOMMIT=0");

	my $hr = { };
	($hr->{cid}, $hr->{points_before}, $hr->{points_orig}, $hr->{points_max}, $hr->{karma}) =
		$self->sqlSelect("cid, points, pointsorig, pointsmax, karma",
			"comments", "cid=$cid", "LOCK IN SHARE MODE");
	$hr->{points_change} = $val;
	$hr->{points_after} = $hr->{points_before} + $val;

	my $karma_val;
	my $karma_change = $reasons->{$newreason}{karma};
	if (!$constants->{mod_down_karmacoststyle}) {
		$karma_val = $karma_change;
	} elsif ($val < 0) {
		$karma_val = ($hr->{points_before} + $karma_change) - $hr->{points_max};
	} else {
		$karma_val = $karma_change;
	}

	if ($karma_val < 0
		&& defined($constants->{comment_karma_limit})
		&& $constants->{comment_karma_limit} ne "") {
		my $future_karma = $hr->{karma} + $karma_val;
		if ($future_karma < $constants->{comment_karma_limit}) {
			$karma_val = $constants->{comment_karma_limit} - $hr->{karma};
		}
		$karma_val = 0 if $karma_val > 0; # just to make sure
	}

	if ($karma_val) {
		my $karma_abs_val = abs($karma_val);
		$update->{-karma}     = sprintf("karma%+d", $karma_val);
		$update->{-karma_abs} = sprintf("karma_abs%+d", $karma_abs_val);
	}

	my $changed = $self->sqlUpdate("comments", $update, $where.$points_extra_where, {
		assn_order => [ "-points", "-pointsmax" ]
	});
	$changed += 0;
	if (!$changed && $raw_val > 0) {
		$update->{-points}="points";
		$update->{-tweak}="tweak$val";
		my $tweak_extra = " AND tweak$val <= 0";
		$changed = $self->sqlUpdate("comments", $update, $where.$tweak_extra, {
			assn_order => [ "-points", "-pointsmax" ]
		});
	}
	$changed += 0;

#	$self->{_dbh}->commit;
#	$self->{_dbh}{AutoCommit} = 1;
	$self->sqlDo("COMMIT");
	$self->sqlDo("SET AUTOCOMMIT=1");

	return $changed ? $hr : undef;
}

########################################################
# This gets the mathematical mode, in other words the most common,
# of the moderations done to a comment.  If no mods, return undef.
# If a comment's net moderation is down, choose only one of the
# negative mods, and the opposite for up.  Tiebreakers break ties,
# first tiebreaker found wins.  "cid" is a key in moderatorlog
# so this is not a table scan.
sub getCommentMostCommonReason {
	my($self, $cid, $allreasons_hr, $new_reason, @tiebreaker_reasons) = @_;
	$new_reason = 0 if !$new_reason;
	unshift @tiebreaker_reasons, $new_reason if $new_reason;

	my $reasons = $self->getReasons();
	my $listable_reasons = join(",",
		sort grep { $reasons->{$_}{listable} }
		keys %$reasons);
	return undef if !$listable_reasons;

	# Build the hashref of reason counts for this comment, for all
	# listable reasons.  If allreasoncounts_hr was passed in, this
	# is easy (just grep out the nonlistable ones).  If not, we have
	# to do a DB query.
	my $hr = { };
	if ($allreasons_hr) {
		for my $reason (%$allreasons_hr) {
			$hr->{$reason} = $allreasons_hr->{$reason}
				if $reasons->{$reason}{listable};
		}
	} else {
		$hr = $self->sqlSelectAllHashref(
			"reason",
			"reason, COUNT(*) AS c",
			"moderatorlog",
			"cid=$cid AND active=1
			 AND reason IN ($listable_reasons)",
			"GROUP BY reason"
		);
	}

	# If no mods that are listable, return undef.
	return undef if !keys %$hr;

	# We need to know if the comment has been moderated net up,
	# net down, or to a net tie, and if not a tie, restrict
	# ourselves to choosing only reasons from that direction.
	# Note this isn't atomic with the actual application of, or
	# undoing of, the moderation in question.  Oh well!  If two
	# mods are applied at almost exactly the same time, there's
	# a one in a billion chance the comment will end up with a
	# wrong (but still plausible) reason field.  I'm not going
	# to worry too much about it.
	# Also, I'm doing this here, with a separate for loop to
	# screen out unacceptable reasons, instead of putting this
	# "if" into the same for loop above, because it may save a
	# query (if a comment is modded entirely with Under/Over).
	my($points, $pointsorig) = $self->sqlSelect(
		"points, pointsorig", "comments", "cid=$cid");
	if ($new_reason) {
		# This mod hasn't been taken into account in the
		# DB yet, but it's about to be applied.
		$points += $reasons->{$new_reason}{val};
	}
	my $needval = $points - $pointsorig;
	if ($needval) {
		   if ($needval >  1) { $needval =  1 }
		elsif ($needval < -1) { $needval = -1 }
		my $new_hr = { };
		for my $reason (keys %$hr) {
			$new_hr->{$reason} = $hr->{$reason}
				if $reasons->{$hr->{$reason}{reason}}{val} == $needval;
		}
		$hr = $new_hr;
	}

	# If no mods that are listable, return undef.
	return undef if !keys %$hr;

	# Sort first by popularity and secondarily by reason.
	# "reason" is a numeric field, so we sort $a<=>$b numerically.
	my @sorted_keys = sort {
		$hr->{$a}{c} <=> $hr->{$b}{c}
		||
		$a <=> $b
	} keys %$hr;
	my $top_count = $hr->{$sorted_keys[-1]}{c};
	@sorted_keys = grep { $hr->{$_}{c} == $top_count } @sorted_keys;
	# Now sorted_keys are only the top values, one or more of them,
	# any of which could be the winning reason.
	if (scalar(@sorted_keys) == 1) {
		# A clear winner.  Return it.
		return $sorted_keys[0];
	}
	# No clear winner. Are any of our tiebreakers contenders?
	my %sorted_hash = ( map { $_ => 1 } @sorted_keys );
	for my $reason (@tiebreaker_reasons) {
		# Yes, return the first tiebreaker we find.
		return $reason if $sorted_hash{$reason};
	}
	# Nope, we don't have a good way to resolve the tie. Pick whatever
	# comes first in the reason list (reasons are all numeric and
	# sorted_keys is already sorted, making this easy).
	return $sorted_keys[0];
}

########################################################
sub getCommentReply {
	my($self, $sid, $pid) = @_;
	my $sid_quoted = $self->sqlQuote($sid);
	my $reply = $self->sqlSelectHashref(
		"date,date as time,subject,comments.points as points,comments.tweak as tweak,
		comment_text.comment as comment,realname,nickname,
		fakeemail,homepage,comments.cid as cid,sid,
		users.uid as uid,reason",
		"comments,comment_text,users,users_info,users_comments",
		"sid=$sid_quoted
		AND comments.cid=$pid
		AND users.uid=users_info.uid
		AND users.uid=users_comments.uid
		AND comment_text.cid=$pid
		AND users.uid=comments.uid"
	) || {};

	# For a comment we're replying to, there's no need to mod.
	$reply->{no_moderation} = 1;

	return $reply;
}

########################################################
sub getCommentsForUser {
	my($self, $sid, $cid, $options) = @_;

	# Note that the "cache_read_only" option is not used at the moment.
	# Slash has done comment caching in the past but does not do it now.
	# If in the future we see fit to re-enable it, it's valuable to have
	# some of this logic left over -- the places where this method is
	# called that have that bit set should be kept that way.
	my $cache_read_only = $options->{cache_read_only} || 0;
	my $one_cid_only = $options->{one_cid_only} || 0;

	my $sid_quoted = $self->sqlQuote($sid);
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	my $select = " cid, date, date as time, subject, nickname, "
		. "homepage, fakeemail, users.uid AS uid, sig, "
		. "comments.points AS points, pointsorig, "
		. "tweak, tweak_orig, "
		. "pid, pid AS original_pid, sid, lastmod, reason, "
		. "journal_last_entry_date, ipid, subnetid, "
		. "karma_bonus, "
		. "len, CONCAT('<SLASH type=\"COMMENT-TEXT\">', cid ,'</SLASH>') as comment";
	if ($constants->{plugin}{Subscribe} && $constants->{subscribe}) {
		$select .= ", subscriber_bonus";
	}
	my $tables = "comments, users";
	my $where = "sid=$sid_quoted AND comments.uid=users.uid ";

	if ($cid && $one_cid_only) {
		$where .= "AND cid=$cid";
	} elsif ($user->{hardthresh}) {
		my $threshold_q = $self->sqlQuote($user->{threshold});
		$where .= "AND (comments.points >= $threshold_q";
		$where .= "  OR comments.uid=$user->{uid}"	unless $user->{is_anon};
		$where .= "  OR cid=$cid"			if $cid;
		$where .= ")";
	}

	my $comments = $self->sqlSelectAllHashrefArray($select, $tables, $where);

	my $archive = $cache_read_only;

	return $comments;
}

########################################################
# This is here to save us a database lookup when drawing comment pages.
#
# I tweaked this to go a little faster by allowing $cid to be either
# an integer (old mode, retained for backwards compatibility, returns
# the text) or a reference to an array of integers (new mode, returns
# a hashref of cid=>text).  Either way it stores all the answers it
# gets into cache.  But passing it an arrayref of 100 cids is faster
# than calling it 100 times with one cid.  Works fine with an arrayref
# of 0 or 1 entries, of course.  - Jamie
# Note that this does NOT store all its answers into cache anymore.
# - Jamie 2003/04
sub getCommentText {
	my($self, $cid) = @_;
	return unless $cid;

	if (ref $cid) {
		return unless scalar @$cid;
		if (ref $cid ne "ARRAY") {
			errorLog("_getCommentText called with ref to non-array: $cid");
			return { };
		}
		my %return;
		my $in_list = join(",", @$cid);
		my $comment_array;
		$comment_array = $self->sqlSelectAll(
			"cid, comment",
			"comment_text",
			"cid IN ($in_list)"
		) if @$cid;
		for my $comment_hr (@$comment_array) {
			$return{$comment_hr->[0]} = $comment_hr->[1];
		}

		return \%return;
	} elsif ($cid) {
		return $self->sqlSelect("comment", "comment_text", "cid=$cid");
	}
}

########################################################
sub getComments {
	my($self, $sid, $cid) = @_;
	my $sid_quoted = $self->sqlQuote($sid);
	$self->sqlSelect("uid, pid, subject, points, reason, ipid, subnetid",
		'comments',
		"cid=$cid AND sid=$sid_quoted"
	);
}

#######################################################
sub getSubmissionsByNetID {
	my($self, $id, $field, $limit, $options) = @_;
	my $mp_tid = getCurrentStatic('mainpage_nexus_tid');

	$limit = "LIMIT $limit" if $limit;
	my $where;

	if ($field eq 'ipid') {
		$where = "ipid='$id'";
	} elsif ($field eq 'subnetid') {
		$where = "subnetid='$id'";
	} else {
		$where = "ipid='$id' OR subnetid='$id'";
	}
	$where = "($where) AND time > DATE_SUB(NOW(), INTERVAL $options->{limit_days} DAY)"
		if $options->{limit_days};
	$where .= " AND del = 2" if $options->{accepted_only};

	my $subs = $self->sqlSelectAllHashrefArray(
		'uid, name, subid, ipid, subj, time, del, tid',
		'submissions', $where,
		"ORDER BY time DESC $limit");

	for my $sub (@$subs) {
		$sub->{sid} = $self->sqlSelect(
			'value',
			'submission_param',
			"subid=".$self->sqlQuote($sub->{subid})." AND name='sid'") if $sub->{del} == 2;
		if ($sub->{sid}) {
			my $sid_q = $self->sqlQuote($sub->{sid});
			my $story_ref = $self->sqlSelectHashref("stories.stoid, title, time",
				"stories, story_text",
				"sid=$sid_q AND stories.stoid=story_text.stoid");
			$story_ref->{displaystatus} = $self->_displaystatus($story_ref->{stoid});
			@$sub{'story_title','story_time','displaystatus'} = @$story_ref{'title','time','displaystatus'} if $story_ref;
		}
	}

	return $subs;
}

########################################################
sub getSubmissionsByUID {
	my($self, $id, $limit, $options) = @_;
	$limit = " LIMIT $limit " if $limit;
	my $where = "uid=$id";
	$where = "($where) AND time > DATE_SUB(NOW(), INTERVAL $options->{limit_days} DAY)"
		if $options->{limit_days};
	$where .= " AND del = 2" if $options->{accepted_only};

	my $subs = $self->sqlSelectAllHashrefArray(
		'uid,name,subid,ipid,subj,time,del,tid,primaryskid',
		'submissions', $where,
		"ORDER BY time DESC $limit");

	for my $sub (@$subs) {
		$sub->{sid} = $self->sqlSelect(
			'value',
			'submission_param', 
			"subid=" . $self->sqlQuote($sub->{subid}) . " AND name='sid'") if $sub->{del} == 2;
		if ($sub->{sid}) {
			my $sid_q = $self->sqlQuote($sub->{sid});
			my $story_ref = $self->sqlSelectHashref("stories.stoid, title, time",
				"stories, story_text",
				"sid=$sid_q AND stories.stoid=story_text.stoid");
			$story_ref->{displaystatus} = $self->_displaystatus($story_ref->{stoid});
			@$sub{'story_title','story_time','displaystatus'} = @$story_ref{'title','time','displaystatus'} if $story_ref;
		}
	}
	return $subs;
}

########################################################
sub countSubmissionsByUID {
	my($self, $id) = @_;

	my $count = $self->sqlCount('submissions', "uid='$id'");
	return $count;
}

########################################################
sub countSubmissionsByNetID {
	my($self, $id, $field) = @_;

	my $where;

	if ($field eq 'ipid') {
		$where = "ipid='$id'";
	} elsif ($field eq 'subnetid') {
		$where = "subnetid='$id'";
	} else {
		my $ipid_cnt = $self->sqlCount("submissions", "ipid='$id'");
		return wantarray ? ($ipid_cnt, "ipid") : $ipid_cnt if $ipid_cnt;
		my $subnetid_cnt = $self->sqlCount("submissions", "subnetid='$id'");
		return wantarray ? ($subnetid_cnt, "subnetid") : $subnetid_cnt;
	}

	my $count = $self->sqlCount('submissions', $where);

	return wantarray ? ($count, $field) : $count;
}

########################################################
# Needs to be more generic in the long run. 
# Be nice if we could just pull certain elements -Brian
sub getStoriesBySubmitter {
	my($self, $id, $limit) = @_;

	my $id_q = $self->sqlQuote($id);
	my $mp_tid = getCurrentStatic('mainpage_nexus_tid');
	my $nexuses = $self->getNexusChildrenTids($mp_tid);
	my $nexus_clause = join ',', @$nexuses, $mp_tid;

	$limit = 'LIMIT ' . $limit if $limit;
	my $answer = $self->sqlSelectAllHashrefArray(
		'sid, title, time',
		'stories, story_text, story_topics_rendered',
		"stories.stoid = story_topics_rendered.stoid
		 AND stories.stoid = story_text.stoid
		 AND submitter=$id_q AND time < NOW()
		 AND story_topics_rendered.tid IN ($nexus_clause) 
		 AND in_trash = 'no'",
		"GROUP BY stories.stoid ORDER by time DESC $limit");
	return $answer;
}

########################################################
sub countStoriesBySubmitter {
	my($self, $id) = @_;
	
	my $id_q = $self->sqlQuote($id);
	my $mp_tid = getCurrentStatic('mainpage_nexus_tid');
	my $nexuses = $self->getNexusChildrenTids($mp_tid);
	my $nexus_clause = join ',', @$nexuses, $mp_tid;

	my ($count) = $self->sqlSelect('count(*)',
		'stories, story_topics_rendered',
		"stories.stoid=story_topics_rendered.stoid',
		 AND submitter=$id_q AND time < NOW()
		 AND story_topics_rendered.tid IN ($nexus_clause) 
		 AND in_trash = 'no'
		 GROUP BY stories.stoid");

	return $count;
}

########################################################
sub _stories_time_clauses {
	my($self, $options) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $try_future =		$options->{try_future}		|| 0;
	my $future_secs =		defined($options->{future_secs})
						? $options->{future_secs}
						: $constants->{subscribe_future_secs};
	my $must_be_subscriber =	$options->{must_be_subscriber}	|| 0;
	my $column_name =		$options->{column_name}		|| "time";
	my $exact_now =			$options->{exact_now}		|| 0;
	my $fake_secs_ahead =		$options->{fake_secs_ahead}	|| 0;

	my($is_future_column, $where);

	# Tweak $future_secs here somewhat, based on something...?  Nah.

	# First decide whether we're looking into the future or not.  If we
	# are going to try for this sort of thing, then either we must NOT
	# be limiting it to subscribers only, OR the user must be a subscriber
	# and this page must be plummy (able to have plums).
	my $future = 0;
	$future = 1 if $try_future
		&& $constants->{subscribe}
		&& $future_secs
		&& (!$must_be_subscriber
			|| ($user->{is_subscriber} && $user->{state}{page_plummy}));

	# If we have NOW() in the WHERE clause, the query cache can't hold
	# onto this.  Since story times are rounded to the minute, we can
	# also round our selection time to the minute, so the query cache
	# can work for the full 60 seconds.
	my $now = $exact_now ? 'NOW()'
		: $self->sqlQuote( time2str(
			'%Y-%m-%d %H:%M:00',
			time + $fake_secs_ahead,
			'GMT') );

	if ($future) {
		$is_future_column = "IF($column_name <= $now, 0, 1) AS is_future";
		if ($future_secs) {
			$where = "$column_name <= DATE_ADD($now, INTERVAL $future_secs SECOND)";
		} else {
			$where = "$column_name <= $now";
		}
	} else {
		$is_future_column = '0 AS is_future';
		$where = "$column_name < $now";
	}

	return ($is_future_column, $where);
}

########################################################
# This method may overwrite $options if it wants.
sub getStoriesEssentials {
	my($self, $options) = @_;

	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $gSkin = getCurrentSkin();
	my $mp_tid = $constants->{mainpage_nexus_tid};
	my $can_restrict_by_min_stoid = 1;
#use Data::Dumper;
#print STDERR "gSE gSkin: " . Dumper($gSkin);

	# Here, limit is how many we want "for the main display"
	# and limit_extra is how many we want "spillover into the
	# Older Stuff column."  Those are just rough concepts.
	# Of course the caller can use the returned data however
	# it wants, this is just a convenient way to think of it.
	
	my $offset = $options->{offset} || 0;
	$offset = 0 unless $offset =~ /^\d+$/;
	$can_restrict_by_min_stoid = 0 if $offset;

	my $limit = $options->{limit} || $gSkin->{artcount_max};
	$limit += $options->{limit_extra}
		|| int(($gSkin->{artcount_min} + $gSkin->{artcount_max})/2);
#print STDERR "gSE limit '$limit' oplim '$options->{limit}' acmax '$gSkin->{artcount_max}' oplimex '$options->{limit_extra}' acmin '$gSkin->{artcount_min}'\n";
	$can_restrict_by_min_stoid = 0 if $limit > 100
		|| $options->{limit}       > $gSkin->{artcount_max}
		|| $options->{limit_extra} > $gSkin->{artcount_max};

	# If we're about to be asked to restrict the selection to
	# just one tid, the mainpage, and sectioncollapse is turned
	# on, then what's actually wanted is all tids that are
	# children of the mainpage.  Fake that into place.
	my $want_mainpage_children = 0;
	if ($options->{sectioncollapse} && $options->{tid}) {
		if (ref($options->{tid}) eq 'ARRAY') {
			if (scalar(@{$options->{tid}}) == 1
				&& $options->{tid}[0] == $mp_tid) {
				$want_mainpage_children = 1;
			}
		} else {
			if ($options->{tid} == $mp_tid) {
				$want_mainpage_children = 1;
			}
		}
	}
	if ($want_mainpage_children) {
		my $nexuses = $self->getNexusChildrenTids($mp_tid);
		unshift @$nexuses, $mp_tid;
		$options->{tid} = $nexuses;
	}

	# This is just used by tasks/precache_gse.pl.
	my $fake_secs_ahead = $options->{fake_secs_ahead} || 0;

	# Restrict the selection to include or exclude based on
	# up to three types of data.  The data fed to this loop
	# tells it which table to look in, which column in the
	# table to use, and which option name in $options to use.
	my @restrictions = ( );
	for my $key (qw(
		story_topics_rendered.tid	story_topics_rendered.tid_exclude
		stories.stoid			stories.stoid_exclude
		stories.uid			stories.uid_exclude
	)) {
		my($table, $col, $optname) = $key =~ /^(\w+)\.((\w+)(?:_exclude)?)$/;
		my $not = $key =~ /_exclude$/ ? "NOT" : "";
#print STDERR "gSE key '$key' table '$table' col '$col' optname '$optname' not '$not'\n";
		next unless $options->{$optname};
		my $opt_ar = ref($options->{$optname})
			?   $options->{$optname}
			: [ $options->{$optname} ];
		push @restrictions, "$table.$col $not IN (" . join(", ", @$opt_ar) . ")";

		# These restrictions may affect whether the
		# gse_min_stoid var can be used to limit our query.
		# If we've already given up on using it, no need to
		# check again.
		next if !$can_restrict_by_min_stoid;
		# If we're doing any kind of restriction other than
		# limiting to precisely one tid which is the
		# mainpage_nexus_tid, then give up on using it.
		if ($optname ne 'tid' || $not) {
			$can_restrict_by_min_stoid = 0;
		} else {
			if (ref($options->{tid}) eq 'ARRAY') {
				if (scalar(@{$options->{tid}}) > 1
					|| $options->{tid}[0] != $mp_tid) {
					$can_restrict_by_min_stoid = 0;
				}
			} else {
				if ($options->{tid} != $mp_tid) {
					$can_restrict_by_min_stoid = 0;
				}
			}
		}
	}
	my $restrict_clause = join(" AND ", @restrictions);
#print STDERR "gSE restrict_clause '$restrict_clause' can_restrict_by_min_stoid '$can_restrict_by_min_stoid'\n";

	my $future_secs = defined($options->{future_secs}) ? $options->{future_secs} : undef;
	my($column_time, $where_time) = $self->_stories_time_clauses({
		try_future => 1,
		future_secs => $future_secs,
		must_be_subscriber => 0,
		fake_secs_ahead => $fake_secs_ahead,
	});
	my $columns;
	if ($options->{return_min_stoid_only}) {
		$columns = "stories.stoid";
		$can_restrict_by_min_stoid = 0;
	} else {
		$columns = "stories.stoid, sid, time, commentcount, hitparade,"
			. " primaryskid, body_length, word_count, discussion, $column_time";
	}
	my $tables = "stories, story_topics_rendered";
	my $other = "GROUP BY stories.stoid ORDER BY time DESC LIMIT $offset, $limit";
#print STDERR "gSE r_m_s_o '$options->{return_min_stoid_only}' other '$other' columns '$columns'\n";

	my $where = "stories.stoid = story_topics_rendered.stoid AND in_trash = 'no' AND $where_time";
	$where .= " AND ($restrict_clause)" if $restrict_clause;

	my $issue = $options->{issue} || "";
	$issue = "" if $issue !~ /^\d{8}$/;
	my $issue_clause = "";
	if ($issue) {
		my $issue_lookback_days = $constants->{issue_lookback_days} || 7;
		my $issue_oldest =   timeCalc("${issue}000000", "%Y-%m-%d %T",
			- $user->{off_set} - 84600*$issue_lookback_days);
		my $issue_youngest = timeCalc("${issue}235959", "%Y-%m-%d %T",
			- $user->{off_set});
		$issue_clause = "time BETWEEN '$issue_oldest' AND '$issue_youngest'";
		$can_restrict_by_min_stoid = 0;
	}
	$where .= " AND $issue_clause" if $issue_clause;

	# Use the min_stoid value, if available and appropriate
	# to use, to dramatically optimize performance on this query.
	my $min_stoid = $constants->{gse_min_stoid} || 0;
	$min_stoid = 0 if !$can_restrict_by_min_stoid;
	if ($min_stoid) {
		$where .= " AND stories.stoid >= '$min_stoid' ";
	}
#print STDERR "gSE final where: '$where'\n";

	my @stories = ( );
	my $qlid = $self->_querylog_start("SELECT", $tables);
	my $cursor = $self->sqlSelectMany($columns, $tables, $where, $other);
	while (my $story = $cursor->fetchrow_hashref) {
		push @stories, $story;
		last if @stories >= $limit;
	}
	$cursor->finish;
	$self->_querylog_finish($qlid);

	if ($options->{return_min_stoid_only}) {
		my $min = $stories[0]{stoid} || 0;
		return 0 if !$min;
		for my $story (@stories) {
			$min = $story->{stoid} if $story->{stoid} < $min;
		}
		return $min;
	}

	return \@stories;
}

########################################################
sub getSubmissionsMerge {
	my($self) = @_;
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my(@submissions);

	my $uid = getCurrentUser('uid');

	# get submissions
	# from deleteSubmission
	for (keys %{$form}) {
		# $form has several new internal variables that match this regexp, so 
		# the logic below should always check $t.
		next unless /^del_(\d+)$/;
		my $n = $1;

		my $sub = $self->getSubmission($n);
		push @submissions, $sub;

		# update karma
		# from createStory
		if (!isAnon($sub->{uid})) {
			my($userkarma) =
				$self->sqlSelect('karma', 'users_info', "uid=$sub->{uid}");
			my $newkarma = (($userkarma + $constants->{submission_bonus})
				> $constants->{maxkarma})
					? $constants->{maxkarma}
					: "karma+$constants->{submission_bonus}";
			$self->sqlUpdate('users_info', {
				-karma => $newkarma },
			"uid=$sub->{uid}");
			$self->setUser_delete_memcached($sub->{uid});
		}
	}

	return \@submissions;
}

########################################################
sub setSubmissionsMerge {
	my($self, $content) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	my $time = timeCalc(scalar localtime, "%m/%d %H:%M %Z", 0);
	my $subid = $self->createSubmission({
		subj	=> "Merge: $user->{nickname} ($time)",
		tid	=> $constants->{defaulttopic},
		story	=> $content,
		name	=> $user->{nickname},
	});
	$self->setSubmission($subid, {
		storyonly => 1,
		separate  => 1,
	});
}

########################################################
# 
sub getSubmissionForUser {
	my($self) = @_;

	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $del  = $form->{del} || 0;

	# Master WHERE array, each element in the list must be true for a valid
	# result.
	my @where = (
		'submissions.uid=users_info.uid',
		"$del=del"
	);

	# Build note logic and add it to master WHERE array.
	my $logic = $form->{note}
		? "note=" . $self->sqlQuote($form->{note})
		: "ISNULL(note) OR note=' '";
	push @where, "($logic)";

	push @where, 'tid=' . $self->sqlQuote($form->{tid}) if $form->{tid};

	if ($form->{skin}) {
		my $skin = $self->getSkin($form->{skin});
		push @where, "primaryskid = $skin->{skid}";
	}

	my $submissions = $self->sqlSelectAllHashrefArray(
		'submissions.*, karma',
		'submissions,users_info',
		join(' AND ', @where),
		'ORDER BY time'
	);

	for my $sub (@$submissions) {
		my $append = $self->sqlSelectAllKeyValue(
			'name,value',
			'submission_param',
			"subid=" . $self->sqlQuote($sub->{subid})
		);
		for my $key (keys %$append) {
			$sub->{$key} = $append->{$key};
		}
	}

	formatDate($submissions, 'time', 'time', '%m/%d  %H:%M');

	# Drawback - This method won't return param data for these submissions
	# without a little more work.
	return $submissions;
}

########################################################
sub calcTrollPoint {
	my ($self, $type, $good_behavior) = @_;
	my $constants = getCurrentStatic();
	$good_behavior ||= 0;
	my $trollpoint =0;

	$trollpoint = -abs($constants->{istroll_downmods_ip}) - $good_behavior if $type eq "ipid";
	$trollpoint = -abs($constants->{istroll_downmods_subnet}) - $good_behavior if $type eq "subnetid";
	$trollpoint = -abs($constants->{istroll_downmods_user}) - $good_behavior if $type eq "uid";

	return $trollpoint;
}

########################################################
sub calcModval {
	my($self, $where_clause, $halflife, $minicache) = @_;
	my $constants = getCurrentStatic();

	return undef unless $where_clause;

	# There's just no good way to do this with a join; it takes
	# over 1 second and if either comment posting or moderation
	# is reasonably heavy, the DB can get bogged very fast.  So
	# let's split it up into two queries.  Dagnabbit.
	# And in case we're being asked about a user who has posted
	# many many comments (or heaven forfend, some bug lets this
	# method be called for the anonymous coward), put a couple
	# of sanity check limits on this query.
	my $min_cid = $self->sqlSelect("MIN(cid)", "moderatorlog") || 0;
	my $cid_ar = $self->sqlSelectColArrayref(
		"cid",
		"comments",
		"cid >= $min_cid AND $where_clause",
		"ORDER BY cid DESC LIMIT 250"
	);
	return 0 if !$cid_ar or !@$cid_ar;

	# If a minicache was passed in, see if we match it;  if so,
	# we can save a query.  In reality, this means that if an IP
	# is the only IP posting from its subnet, we don't need to
	# get the moderatorlog valsum twice.
	my $cid_text = join(",", @$cid_ar);
	if ($minicache and defined($minicache->{$cid_text})) {
		return $minicache->{$cid_text};
	}

	# We've got the cids that fit the where clause;  find all
	# moderations of those cids.
	my $hr = $self->sqlSelectAllHashref(
		"hoursback",
		"CEILING((UNIX_TIMESTAMP(NOW())-
			UNIX_TIMESTAMP(ts))/3600) AS hoursback,
			SUM(val) AS valsum",
		"moderatorlog",
		"moderatorlog.cid IN ($cid_text)
			AND moderatorlog.active=1",
		"GROUP BY hoursback",
	);

	my $max_halflives = $constants->{istroll_max_halflives};
	my $modval = 0;
	for my $hoursback (keys %$hr) {
		my $val = $hr->{$hoursback}{valsum};
		next unless $val;
		if ($hoursback <= $halflife) {
			$modval += $val;
		} elsif ($hoursback <= $halflife*$max_halflives) {
			# Logarithmically weighted.
			$modval += $val / (2 ** ($hoursback/$halflife));
		} elsif ($hoursback > $halflife*12) {
			# So old it's not worth looking at.
		} else {
			# Half-lives, half-lived...
			$modval += $val / (2 ** $max_halflives);
		}
	}

	$minicache->{$cid_text} = $modval if $minicache;
	$modval;
}

sub getNetIDKarma {
	my($self, $type, $id) = @_;
	my($count, $karma);
	if ($type eq "ipid") {
		($count, $karma) = $self->sqlSelect("COUNT(*),sum(karma)","comments","ipid='$id'");
		return wantarray ? ($karma, $count) : $karma;
	} elsif ($type eq "subnetid") {
		($count, $karma) = $self->sqlSelect("COUNT(*),sum(karma)","comments","subnetid='$id'");
		return wantarray ? ($karma, $count) : $karma;
	} else {
		($count, $karma) = $self->sqlSelect("COUNT(*),sum(karma)","comments","ipid='$id'");
		return wantarray ? ($karma, $count) : $karma if $count;

		($count, $karma) = $self->sqlSelect("COUNT(*),sum(karma)","comments","subnetid='$id'");
		return wantarray ? ($karma, $count) : $karma;
	}
}

########################################################
########################################################
# (And now a word from CmdrTaco)
#
# I'm putting this note here because I hate posting stories about
# Slashcode on Slashdot.  It's just distracting from the news, and the
# vast majority of Slashdot readers simply don't care about it. I know
# that this is interpreted as me being all men-in-black, but thats
# bull pucky.  I don't want Slashdot to be about Slashdot or
# Slashcode.  A few people have recently taken to reading CVS and then
# trolling Slashdot with the deep dark secrets that they think they
# have found within.  They don't bother going so far as to bother
# *asking* before freaking.  We have a mailing list if people want to
# ask questions.  We love getting patches when people have better ways
# to do things.  But answers are much more likely if you ask us to our
# faces instead of just sitting in the back of class and bitching to
# everyone sitting around you.  I'm not going to try to have an
# offtopic discussion in an unrelated story.  And I'm not going to
# bother posting a story to appease the 1% of readers for whom this
# story matters one iota.  So this seems to be a reasonable way for me
# to reach you.
#
# What I'm talking about this time is all this IPID crap.  It's a
# temporary kludge that people simply don't understand. It isn't
# intended to be permanent, or secure.  These 2 misconceptions are the
# source of the problem.
#
# The IPID stuff was designed when we only kept 2 weeks of comments in
# the DB at a time.  We need to track IPs and Subnets to prevent DoS
# script attacks.  Again, I know conspiracy theorists freak out, but
# the reality is that without this,  we get constant scripted
# trolling.  This simply isn't up for debate.  We've been doing this
# for years.  It's not new.  We *used* to just store the plain old IP.
#
# The problem is that I don't want IPs staring me in the face. So we
# MD5d em. This wasn't for "security" in the strict sense of the word.
# It just was meant to make it inconvenient for now.  Not impossible. 
# Now I don't have any IPs.  Instead we have reasonably abstracted
# functions that should let us create a more secure system when we
# have the time.
#
# What really needs to happen is that these IDs need to be generated
# with some sort of random rolling key. Of course lookups need to be
# computationally fast within the limitations of our existing
# database.  Ideas?  Or better yet, Diffs?
#
# Lastly I have to say, I find it ironic that we've tracked IPs for
# years.  But nobody complained until we *stopped* tracking IPs and
# put the hooks in place to provide a *secure* system.  You'd think
# people were just looking for an excuse to bitch...
########################################################
########################################################

########################################################
sub getIsTroll {
	my($self, $good_behavior) = @_;
	$good_behavior ||= 0;
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	my $ipid_hoursback = $constants->{istroll_ipid_hours} || 72;
	my $uid_hoursback = $constants->{istroll_uid_hours} || 72;
	my($modval, $trollpoint);
	my $minicache = { };

	# Check for modval by IPID.
	$trollpoint = $self->calcTrollPoint("ipid", $good_behavior);
	$modval = $self->calcModval("ipid = '$user->{ipid}'",
		$ipid_hoursback, $minicache);
	return 1 if $modval <= $trollpoint;

	# Check for modval by subnet.
	$trollpoint = $self->calcTrollPoint("subnetid", $good_behavior);
	$modval = $self->calcModval("subnetid = '$user->{subnetid}'",
		$ipid_hoursback, $minicache);
	return 1 if $modval <= $trollpoint;

	# At this point, if the user is not logged in, then we don't need
	# to check the AC's downmods by user ID;  they pass the tests.
	return 0 if $user->{is_anon};

	# Check for modval by user ID.
	$trollpoint = $self->calcTrollPoint("uid",$good_behavior);
	$modval = $self->calcModval("comments.uid = $user->{uid}", $uid_hoursback);
	return 1 if $modval <= $trollpoint;

	# All tests passed, user is not a troll.
	return 0;
}

########################################################
sub createDiscussion {
	my($self, $discussion) = @_;
	return unless $discussion->{title} && $discussion->{url};

	$discussion->{type} ||= 'open';
	$discussion->{commentstatus} ||= getCurrentStatic('defaultcommentstatus');
	$discussion->{primaryskid} ||= 0;
	$discussion->{topic} ||= 0;
	$discussion->{sid} ||= '';
	$discussion->{stoid} ||= 0;
	$discussion->{ts} ||= $self->getTime();
	$discussion->{uid} ||= getCurrentUser('uid');
	# commentcount and flags set to defaults

	if ($discussion->{section}) {
		my $section = delete $discussion->{section};
		if (!$discussion->{primaryskid}) {
			$discussion->{primaryskid} = $self->getSkin($section)->{skid};
		}
	}

	# Either create the discussion or bail with a "0"
	unless ($self->sqlInsert('discussions', $discussion)) {
		return 0;
	}

	my $discussion_id = $self->getLastInsertId();

	return $discussion_id;
}

########################################################
sub createStory {
	my($self, $story) = @_;

	my $constants = getCurrentStatic();
#	$self->{_dbh}{AutoCommit} = 0;
	$self->sqlDo("SET AUTOCOMMIT=0");

	# yes, this format is correct, don't change it :-)
	# but sids are rapidly becoming obsolete :)
	my $sidformat = '%02d/%02d/%02d/%02d%0d2%02d';
	# Create a sid based on the current time.
	my $start_time = time;
	my @lt = localtime($start_time);
	$lt[5] %= 100; $lt[4]++; # year and month
	$story->{sid} = sprintf($sidformat, @lt[reverse 0..5]);

	my $suid;
	$story->{submitter}	= $story->{submitter} ?
		$story->{submitter} : $story->{uid};
	$story->{is_dirty}	= 1;

	my $sid_ok = 0;
	while ($sid_ok == 0) {
		$sid_ok = $self->sqlInsert('stories',
			{ sid => $story->{sid} },
			{ ignore => 1 } ); # don't need error messages
		if ($sid_ok == 0) { # returns 0E0 on collision, which == 0
			# Look back in time until we find a free second.
			# This is faster than waiting forward in time :)
			--$start_time;
			@lt = localtime($start_time);
			$lt[5] %= 100; $lt[4]++; # year and month
			$story->{sid} = sprintf($sidformat, @lt[reverse 0..5]);
		}
	}

	# If this came from a submission, update submission and grant
	# karma to the user
	my $stoid = $self->getLastInsertId({ table => 'stories', prime => 'stoid' });
	$story->{stoid} = $stoid;
	$self->grantStorySubmissionKarma($story);

	my $error = "";
	if (! $self->sqlInsert('story_text', { stoid => $stoid })) {
		$error = "sqlInsert failed for story_text: " . $self->sqlError();
	}

	# Write the chosen topics into story_topics_chosen.  We do this
	# here because it returns the primaryskid and we will write that
	# into the stories table with setStory in just a moment.
	my($primaryskid, $tids);
	if (!$error) {
		my $success = $self->setStoryTopicsChosen($stoid, $story->{topics_chosen});
		$error = "Failed to set chosen topics for story '$stoid'\n" if !$success;
	}
	if (!$error) {
		my $info_hr = { };
		$info_hr->{neverdisplay} = 1 if $story->{neverdisplay};
		($primaryskid, $tids) = $self->setStoryRenderedFromChosen($stoid,
			$story->{topics_chosen}, $info_hr);
		$error = "Failed to set rendered topics for story '$stoid'\n" if !defined($primaryskid);
	}
	delete $story->{topics_chosen};
	my $commentstatus = delete $story->{commentstatus};
	if (!$error) {
		$story->{stoid} = $stoid;
		$story->{body_length} = length($story->{bodytext});
		$story->{word_count} = countWords($story->{introtext}) + countWords($story->{bodytext});
		$story->{primaryskid} = $primaryskid;
		$story->{tid} = $tids->[0];
		
		if (! $self->setStory($stoid, $story)) {
			$error = "setStory failed after creation: " . $self->sqlError();
		}
	}
	if (!$error) {
		my $rootdir;
		if ($story->{primaryskid}) {
			my $storyskin = $self->getSkin($story->{primaryskid});
			$rootdir = $storyskin->{rootdir};
		} else {
			# The story is set never-display so its discussion's rootdir
			# probably doesn't matter.  Just go with the default.
			my $storyskin = $self->getSkin($constants->{mainpage_skid});
			$rootdir = $storyskin->{rootdir};
		}
		my $comment_codes = $self->getDescriptions("commentcodes");

		my $discussion = {
			title		=> $story->{title},
			primaryskid	=> $primaryskid,
			topic		=> $tids->[0],
			# XXXSECTIONTOPICS pudge, check this, rootdir look right to you?
			url		=> "$rootdir/article.pl?sid=$story->{sid}"
						. ($tids->[0] && $constants->{tids_in_urls}
						  ? "&tid=$tids->[0]" : ""),
			stoid		=> $stoid,
			sid		=> $story->{sid},
			#XXXSECTIONTOPICS do something here
			commentstatus	=> $comment_codes->{$commentstatus}
					   ? $commentstatus
					   : $constants->{defaultcommentstatus},
			ts		=> $story->{'time'}
		};
		my $id = $self->createDiscussion($discussion);
		if (!$id) {
			$error = "Failed to create discussion for story: " . Dumper($discussion);
		}
		if (!$error && !$self->setStory($stoid, { discussion => $id })) {
			$error = "Failed to set discussion '$id' for story '$stoid'\n";
		}
	}

	if ($error) {
		# Rollback doesn't even work in 4.0.x, since some tables
		# are non-transactional...
		$self->sqlDo("ROLLBACK");
		$self->sqlDo("SET AUTOCOMMIT=1");
		chomp $error;
		print STDERR scalar(localtime) . " createStory error: $error\n";
		return "";
	}

	$self->sqlDo("COMMIT");
	$self->sqlDo("SET AUTOCOMMIT=1");

	return $story->{sid};
}

sub grantStorySubmissionKarma {
	my($self, $story) = @_;
	return 0 unless $story->{subid};
	my($submitter_uid) = $self->sqlSelect(
		'uid', 'submissions',
		'subid=' . $self->sqlQuote($story->{subid})
	);
	if (!isAnon($submitter_uid)) {
		my $constants = getCurrentStatic();
		$self->sqlUpdate('users_info',
			{ -karma => "LEAST(karma + $constants->{submission_bonus},
				$constants->{maxkarma})" },
			"uid=$submitter_uid");
		$self->setUser_delete_memcached($submitter_uid);
	}
	my $submission_info = { del => 2 };
	$submission_info->{stoid} = $story->{stoid} if $story->{stoid};
	$submission_info->{sid}   = $story->{sid}   if $story->{sid};
	$self->setSubmission($story->{subid}, $submission_info);
}

##################################################################
# XXXSECTIONTOPICS need to take either kind of id, ignore old
# topic data types, accept new chosen data type in topics_chosen,
# and render it and grab primaryskid, top tid
sub updateStory {
	my($self, $sid, $data) = @_;
#use Data::Dumper; print STDERR "MySQL.pm updateStory just called sid '$sid' data: " . Dumper($data);
	my $constants = getCurrentStatic();
	my $gSkin = getCurrentSkin();
#	$self->{_dbh}{AutoCommit} = 0;
	$self->sqlDo("SET AUTOCOMMIT=0");

	$data->{body_length} = length($data->{bodytext});
	$data->{word_count} = countWords($data->{introtext}) + countWords($data->{bodytext});

	my $error = "";

	my $stoid = $self->getStoidFromSidOrStoid($sid);
	$error = "no stoid for sid '$sid'" unless $stoid;
	my $sid_q = $self->sqlQuote($sid);

#use Data::Dumper; print STDERR "MySQL.pm updateStory before setStory data: " . Dumper($data);
	if (!$error) {
		if (!$self->setStory($stoid, $data)) {
			$error = "Failed to setStory '$sid' '$stoid'\n";
		}
	}

	if (!$error) {
		my $comment_codes = $self->getDescriptions("commentcodes");
		my $rootdir = $self->getSkin($data->{primaryskid})->{rootdir};
		my $topiclist = $self->getTopiclistFromChosen($data->{topics_chosen});
#use Data::Dumper; print STDERR "MySQL.pm updateStory topiclist '@$topiclist' topics_chosen: " . Dumper($data->{topics_chosen});
		my $dis_data = {
			stoid		=> $stoid,
			sid		=> $sid,
			title		=> $data->{title},
			primaryskid	=> $data->{primaryskid},
			url		=> "$rootdir/article.pl?sid=$sid"
						. ($topiclist->[0] && $constants->{tids_in_urls}
						  ? "&tid=$topiclist->[0]" : ""),
			ts		=> $data->{'time'},
			topic		=> $topiclist->[0],
			commentstatus	=> $comment_codes->{$data->{commentstatus}}
						? $data->{commentstatus}
						: getCurrentStatic('defaultcommentstatus'),
		};

		if (!$error && !$self->setDiscussionBySid($sid, $dis_data)) {
			$error = "Failed to set discussion data for story\n";
		}
	}

	if (!$error) {
		my $days_to_archive = $constants->{archive_delay};
		$self->sqlUpdate('discussions', { type => 'open' },
			"stoid='$stoid' AND type='archived'
			 AND ((TO_DAYS(NOW()) - TO_DAYS(ts)) <= $constants->{archive_delay})"
		);
		$self->setVar('writestatus', 'dirty');
		# XXXSECTIONTOPICS no, this should mark all skins that reference all rendered nexuses, not just the primary
		$self->markSkinDirty($data->{primaryskid});
	}

	if ($error) {
		$self->sqlDo("ROLLBACK");
		$self->sqlDo("SET AUTOCOMMIT=1");
		chomp $error;
		print STDERR scalar(localtime) . " updateStory error on sid '$sid': $error\n";
		return "";
	}

	$self->sqlDo("COMMIT");
	$self->sqlDo("SET AUTOCOMMIT=1");

	$self->updatePollFromStory($sid, {
		date		=> 1,
		topic		=> 1,
		section		=> 1,
		polltype	=> 1
	});

	return $sid;

}

sub _getSlashConf_rawvars {
	my($self) = @_;
	my $vu = $self->{virtual_user};
	return undef unless $vu;
	my $mcd = $self->getMCD({ no_getcurrentstatic => 1 });
	my $mcdkey;
	my $got_from_memcached = 0;
	my $vars_hr;
	if ($mcd) {
		$mcdkey = "$self->{_mcd_keyprefix}:vars";
		if ($vars_hr = $mcd->get($mcdkey)) {
			$got_from_memcached = 1;
		}
	}
	$vars_hr ||= $self->sqlSelectAllKeyValue('name, value', 'vars');
	if ($mcd && !$got_from_memcached) {
		# Cache this for about 10 minutes.
		my $expire_time = $vars_hr->{story_expire} || 600;
		$mcd->set($mcdkey, $vars_hr, $expire_time);
	}
	return $vars_hr;
}

########################################################
# Now, the idea is to not cache here, since we actually
# cache elsewhere (namely in %Slash::Apache::constants) - Brian
# I'm caching this in memcached now though. - Jamie
sub getSlashConf {
	my($self) = @_;

	# Get the raw vars data (possibly from a memcached cache).

	my $vars_hr = $self->_getSlashConf_rawvars();
	return if !defined $vars_hr;
	my %conf = %$vars_hr;

	# Now start adding and tweaking the data for various reasons:
	# convenience, fixing bad data, etc.

	# This allows you to do stuff like constant.plugin.Zoo in a template
	# and know that the plugin is installed -Brian
	my $plugindata = $self->sqlSelectColArrayref('value', 'site_info',
		"name='plugin'");
	for my $plugin (@$plugindata) {
		$conf{plugin}{$plugin} = 1;
	}
	$conf{reasons} = $self->sqlSelectAllHashref(
		"id", "*", "modreasons"
	);

	$conf{rootdir}		||= "//$conf{basedomain}";
	$conf{real_rootdir}	||= $conf{rootdir};  # for when rootdir changes
	$conf{real_section}	||= $conf{section};  # for when section changes
	$conf{absolutedir}	||= "http://$conf{basedomain}";
		# If absolutedir_secure is not defined, it defaults to the
		# same as absolutedir.
	$conf{absolutedir_secure} ||= $conf{absolutedir};
	$conf{adminmail_mod}	||= $conf{adminmail};
	$conf{adminmail_post}	||= $conf{adminmail};
	$conf{adminmail_ban}	||= $conf{adminmail};
	$conf{basedir}		||= "$conf{datadir}/public_html";
	$conf{imagedir}		||= "$conf{rootdir}/images";
	$conf{rdfimg}		||= "$conf{imagedir}/topics/topicslash.gif";
	$conf{index_handler}	||= 'index.pl';
	$conf{cookiepath}	||= URI->new($conf{rootdir})->path . '/';
	$conf{maxkarma}		  =  999 unless defined $conf{maxkarma};
	$conf{minkarma}		  = -999 unless defined $conf{minkarma};
	$conf{expiry_exponent}	  = 1 unless defined $conf{expiry_exponent};
	$conf{panic}		||= 0;
	$conf{textarea_rows}	||= 10;
	$conf{textarea_cols}	||= 50;
	$conf{allow_deletions}  ||= 1;
	$conf{authors_unlimited}  = 100 if !defined $conf{authors_unlimited}
		|| $conf{authors_unlimited} == 1;
		# m2_consensus must be odd
	$conf{m2_consensus}       = 2*int(($conf{m2_consensus} || 5)/2) + 1
		if !$conf{m2_consensus}
		   || ($conf{m2_consensus}-1)/2 != int(($conf{m2_consensus}-1)/2);
	$conf{nick_chars}	||= q{ abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789$_.+!*'(),-};
	$conf{nick_maxlen}	||= 20;
	$conf{cookie_location}  ||= 'classbid';
	$conf{login_temp_minutes} ||= 10;
	# For all fields that it is safe to default to -1 if their
	# values are not present...
	for (qw[min_expiry_days max_expiry_days min_expiry_comm max_expiry_comm]) {
		$conf{$_}	= -1 unless exists $conf{$_};
	}

	# no trailing newlines on directory variables
	# possibly should rethink this for basedir,
	# since some OSes don't use /, and if we use File::Spec
	# everywhere this won't matter, but still should be do
	# it for the others, since they are URL paths
	# -- pudge
	for (qw[rootdir absolutedir imagedir basedir]) {
		$conf{$_} =~ s|/+$||;
	}

	my $fixup = sub {
		return [ ] if !$_[0];
		[
			map {(
				s/^\s+//,
				s/\s+$//,
				$_
			)[-1]}
			split /\|/, $_[0]
		];
	};
	my $fixup_hash = sub {
		my $ar = $fixup->(@_);
		my $hr = { };
		return $hr if !$ar;
		for my $str (@$ar) {
			my($k, $v) = split(/=/, $str);
			$v = 1 if !defined($v);
			$v = [ split ",", $v ] if $v =~ /,/;
			$hr->{$k} = $v;
		}
		$hr;
	};

	my %conf_fixup_arrays = (
		# var name			# default array value
		# --------			# -------------------
						# See <http://www.iana.org/assignments/uri-schemes>
		approved_url_schemes =>		[qw( ftp http gopher mailto news nntp telnet wais https )],
		approvedtags =>			[qw( B I P A LI OL UL EM BR TT STRONG BLOCKQUOTE DIV ECODE DL DT DD)],
		approvedtags_break =>		[qw( P LI OL UL BR BLOCKQUOTE DIV HR DL DT DD)],
		charrefs_bad_entity =>		[qw( zwnj zwj lrm rlm )],
		charrefs_bad_numeric =>		[qw( 8204 8205 8206 8207 8236 8237 8238 )],
		charrefs_good_entity =>		[qw( amp lt gt euro pound yen )],
		charrefs_good_numeric =>	[ ],
		cur_performance_stat_ops =>	[ ],
		lonetags =>			[qw( P LI BR IMG DT DD)],
		fixhrefs =>			[ ],
		hc_possible_fonts =>		[ ],
		lonetags =>			[ ],
		m2_sliding_consensus =>		[ ],
		op_exclude_from_countdaily =>   [qw( rss )],
		op_extras_countdaily =>   	[ ],
		mod_stats_reports =>		[ $conf{adminmail_mod} ],
		stats_reports =>		[ $conf{adminmail} ],
		stats_sfnet_groupids =>		[ 4421 ],
		submit_categories =>		[ ],
		skins_recenttopics =>           [ ],
		subnet_karma_post_limit_range => [ ]
	);
	my %conf_fixup_hashes = (
		# var name			# default hash of keys/values
		# --------			# --------------------
		ad_messaging_sections =>	{ },
		comments_perday_bykarma =>	{  -1 => 2,		25 => 25,	99999 => 50          },
		karma_adj =>			{ -10 => 'Terrible',	-1 => 'Bad',	    0 => 'Neutral',
						   12 => 'Positive',	25 => 'Good',	99999 => 'Excellent' },
		mod_up_points_needed =>		{ },
		m2_consequences =>		{ 0.00 => [qw(  0    +2   -100 -1   )],
						  0.15 => [qw( -2    +1    -40 -1   )],
						  0.30 => [qw( -0.5  +0.5  -20  0   )],
						  0.35 => [qw(  0     0    -10  0   )],
						  0.49 => [qw(  0     0     -4  0   )],
						  0.60 => [qw(  0     0     +1  0   )],
						  0.70 => [qw(  0     0     +2  0   )],
						  0.80 => [qw( +0.01 -1     +3  0   )],
						  0.90 => [qw( +0.02 -2     +4  0   )],
						  1.00 => [qw( +0.05  0     +5 +0.5 )],	},
		m2_consequences_repeats =>	{ 3 => -4, 5 => -12, 10 => -100 },
	);
	for my $key (keys %conf_fixup_arrays) {
		if (defined($conf{$key})) {
			$conf{$key} = $fixup->($conf{$key});
		} else {
			$conf{$key} = $conf_fixup_arrays{$key};
		}
	}
	for my $key (keys %conf_fixup_hashes) {
		if (defined($conf{$key})) {
			$conf{$key} = $fixup_hash->($conf{$key});
		} else {
			$conf{$key} = $conf_fixup_hashes{$key};
		}
	}

	for my $var (qw(email_domains_invalid submit_domains_invalid)) {
		if ($conf{$var}) {
			my $regex = sprintf('[^\w-](?:%s)$',
				join '|', map quotemeta, split ' ', $conf{$var});
			$conf{$var} = qr{$regex};
		}
	}

	if ($conf{comment_nonstartwordchars}) {
		# Expand this into a complete regex.  We catch not only
		# these chars in their raw form, but also all HTML entities
		# (because Windows/MSIE refuses to break before any word
		# that starts with either the chars, or their entities).
		# Build the regex with qr// and match entities for
		# optimal speed.
		my $src = $conf{comment_nonstartwordchars};
		my @chars = ( );
		my @entities = ( );
		for my $i (0..length($src)-1) {
			my $c = substr($src, $i, 1);
			push @chars, "\Q$c";
			push @entities, ord($c);
			push @entities, sprintf("x%x", ord($c));
		}
		my $dotchar =
			'(?:'
			       . '[' . join("", @chars) . ']'
			       . '|&#(?:' . join("|", @entities) . ');'
		       . ')';
		my $regex = '(\s+)' . "((?:<[^>]+>)*$dotchar+)" . '(\S)';
		$conf{comment_nonstartwordchars_regex} = qr{$regex}i;
	}

	for my $regex (qw(
		accesslog_imageregex
		x_forwarded_for_trust_regex
	)) {
		next if !$conf{$regex} || $conf{$regex} eq 'NONE';
		$conf{$regex} = qr{$conf{$regex}};
	}

	if ($conf{approvedtags_attr}) {
		my $approvedtags_attr = $conf{approvedtags_attr};
		$conf{approvedtags_attr} = {};
		my @tags = split(/\s+/, $approvedtags_attr);
		foreach my $tag(@tags){
			my ($tagname,$attr_info) = $tag=~/([^:]*):(.*)$/;
			my @attrs = split( ",", $attr_info );
			my $ord=1;
			foreach my $attr(@attrs){
				my($at,$extra) = split( /_/, $attr );
				$at = uc($at);
				$tagname = uc($tagname);
				$conf{approvedtags_attr}->{$tagname}{$at}{ord}=$ord;
				$conf{approvedtags_attr}->{$tagname}{$at}{req}=1 if $extra=~/R/;
				$conf{approvedtags_attr}->{$tagname}{$at}{url}=1 if $extra=~/U/;
				$ord++
			}
		}   

	}

	# We only need to do this on startup.
	$conf{classes} = $self->getClasses();

	return \%conf;
}

##################################################################
# It would be best to write a Slash::MemCached class, preferably as
# a plugin, but let's just do this for now.
sub getMCD {
	my($self, $options) = @_;

	# If we already created it for this object, or if we tried to
	# create it and failed and assigned it 0, return that.
	return $self->{_mcd} if defined($self->{_mcd});

	# If we aren't using memcached, return false.
	my $constants;
	if ($options->{no_getcurrentstatic}) {
		# If our caller needs getMCD because it's going to
		# set up vars, we can't rely on getCurrentStatic.
		# So get the vars we need directly.
		my @needed = qw( memcached memcached_debug
			memcached_keyprefix memcached_servers
			sitename );
		my $in_clause = join ",", map { $self->sqlQuote($_) } @needed;
		$constants = $self->sqlSelectKeyValue(
			"name, value",
			"vars",
			"name IN ($in_clause)");
	} else {
		$constants = getCurrentStatic();
	}
	return 0 if !$constants->{memcached} || !$constants->{memcached_servers};

	# OK, let's try memcached.  The memcached_servers var is in the format
	# "10.0.0.15:11211 10.0.0.15:11212 10.0.0.17:11211=3".

	my @servers = split / /, $constants->{memcached_servers};
	for my $server (@servers) {
		if ($server =~ /(.+)=(\d+)$/) {
			$server = [ $1, $2 ];
		}
	}
	require Cache::Memcached;
	$self->{_mcd} = Cache::Memcached->new({
		servers =>	[ @servers ],
		debug =>	$constants->{memcached_debug} > 1 ? 1 : 0,
	});
	if (!$self->{_mcd}) {
		# Can't connect; not using it.
		return $self->{_mcd} = 0;
	}
	if ($constants->{memcached_keyprefix}) {
		$self->{_mcd_keyprefix} = $constants->{memcached_keyprefix};
	} else {
		# If no keyprefix defined in vars, use the first and
		# last letter from the sitename.
		$constants->{sitename} =~ /([A-Za-z]).*(\w)/;
		$self->{_mcd_keyprefix} = ($2 ? lc("$1$2") : ($1 ? lc($1) : ""));
	}
	return $self->{_mcd};
}

##################################################################
sub getMCDStats {
	my($self) = @_;
	my $mcd = $self->getMCD();
	return undef unless $mcd && $mcd->can("stats");

	my $stats = $mcd->stats();
	for my $server (keys %{$stats->{hosts}}) {
		_getMCDStats_percentify($stats->{hosts}{$server}{misc},
			qw(	get_hits	cmd_get		get_hit_percent ));
		_getMCDStats_percentify($stats->{hosts}{$server}{malloc},
			qw(	total_alloc	arena_size	total_alloc_percent ));
	}
	_getMCDStats_percentify($stats->{total},
			qw(	get_hits	cmd_get		get_hit_percent ));
	_getMCDStats_percentify($stats->{total},
			qw(	malloc_total_alloc	malloc_arena_size	malloc_total_alloc_percent ));
	return $stats;
}

sub _getMCDStats_percentify {
	my($hr, $num, $denom, $dest) = @_;
	my $perc = "-";
	$perc = sprintf("%.1f", $hr->{$num}*100 / $hr->{$denom}) if $hr->{$denom};
	$hr->{$dest} = $perc;
}

##################################################################
# What an ugly ass method that should go away  -Brian
# It's ugly, but performs many necessary functions, and anything
# that replaces it to perform those functions won't be any prettier
# -- pudge
sub autoUrl {
	my $self = shift;
	my $section = shift;
	local $_ = join ' ', @_;
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	s/([0-9a-z])\?([0-9a-z])/$1'$2/gi if $form->{fixquotes};
	s/\[([^\]]+)\]/linkNode($1)/ge if $form->{autonode};

	my $initials = substr $user->{nickname}, 0, 1;
	my $more = substr $user->{nickname}, 1;
	$more =~ s/[a-z]//g;
	$initials = uc($initials . $more);
	my($now) = timeCalc(scalar localtime, '%m/%d %H:%M %Z', 0);

	# Assorted Automatic Autoreplacements for Convenience
	s|<disclaimer:(.*)>|<B><A HREF="/about.shtml#disclaimer">disclaimer</A>:<A HREF="$user->{homepage}">$user->{nickname}</A> owns shares in $1</B>|ig;
	s|<update>|<B>Update: <date></B> by <author>|ig;
	s|<date>|$now|g;
	s|<author>|<B><A HREF="$user->{homepage}">$initials</A></B>:|ig;

	# The delimiters below were once "[%...%]" but that's legacy code from
	# before Template, and we've since changed it to what you see below.
	s/\{%\s*(.*?)\s*%\}/$self->getUrlFromTitle($1)/eg if $form->{shortcuts};

	# Assorted ways to add files:
	s|<import>|importText()|ex;
	s/<image(.*?)>/importImage($section)/ex;
	s/<attach(.*?)>/importFile($section)/ex;
	return $_;
}

#################################################################
# link to Everything2 nodes --- should be elsewhere (as should autoUrl)
sub linkNode {
	my($title) = @_;
	my $link = URI->new("http://www.everything2.com/");
	$link->query("node=$title");

	return qq|$title<sup><a href="$link">?</a></sup>|;
}

##################################################################
# autoUrl & Helper Functions
# Image Importing, Size checking, File Importing etc
sub getUrlFromTitle {
	my($self, $title) = @_;
	my($sid) = $self->sqlSelect('sid',
		'stories',
		"title LIKE '\%$title\%'",
		'ORDER BY time DESC LIMIT 1'
	);
	my $rootdir = getCurrentSkin('rootdir');
	return "$rootdir/article.pl?sid=$sid";
}

##################################################################
sub getTime {
	my($self, $options) = @_;

	my $add_secs = $options->{add_secs} || 0;

	my $t;
	if (!$add_secs) {
		$t = $self->sqlSelect('NOW()');
	} else {
		$t = $self->sqlSelect("DATE_ADD(NOW(), INTERVAL $add_secs SECOND)");
	}

	return $t;
}

##################################################################
sub getTimeAgo {
	my ($self, $time) = @_;
	my $q_time = $self->sqlQuote($time);
	my $units_given = 0;
	my $remainder = $self->sqlSelect("UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP($q_time)");

	my $diff = {};
	$diff->{is_future} = 1 if $remainder < 0;
	$diff->{is_past}   = 1 if $remainder > 0;
	$diff->{is_now}    = 1 if $remainder == 0;
	$remainder = abs($remainder);
	$diff->{days} = int($remainder / 86400);
	$remainder -= $diff->{days}* 86400;
	$diff->{hours} = int($remainder / 3600);
	$remainder -= $diff->{hours} * 3600;
	$diff->{minutes} = int($remainder / 60);
	$remainder -= $diff->{minutes} * 60;
	$diff->{seconds} = $remainder;
	
	return $diff;
}

##################################################################
# And if a webserver had a date that is off... -Brian
# ...it wouldn't matter; "today's date" is a timezone dependent concept.
# If you live halfway around the world from whatever timezone we pick,
# this will be consistently off by hours, so we shouldn't spend an SQL
# query to worry about minutes or seconds - Jamie
sub getDay {
	my($self, $days_back) = @_;
	$days_back ||= 0;
	my $day = timeCalc(scalar(localtime(time-86400*$days_back)), '%Y%m%d'); # epoch time, %Q
	return $day;
}

##################################################################
# XXXSECTIONTOPICS this should be working fine now 2004/07/08
sub getStoryList {
	my($self, $first_story, $num_stories) = @_;
	$first_story ||= 0;
	$num_stories ||= 40;

	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();
	my $gSkin = getCurrentSkin();
	my $is_mainpage = $gSkin->{skid} == $constants->{mainpage_skid} ? 1 : 0;

	my $columns = "hits, stories.commentcount AS commentcount,
		stories.stoid, stories.sid,
		story_text.title, stories.uid, stories.tid,
		time, stories.in_trash, primaryskid,
		IF(skins.skid IS NULL, '_none', skins.name) AS skinname";
	my $tables = 'stories, story_text';
	my @where = ( 'stories.stoid = story_text.stoid' );

	# If this is a "sectional" (one skin only) admin.pl storylist,
	# then restrict ourselves to only stories matching its nexus.
	if (!$is_mainpage) {
		$tables .= ', story_topics_rendered AS str';
		push @where,
			'stories.stoid = str.stoid',
			"str.tid = $gSkin->{nexus}";
	}

	# We also need the primaryskid for each story LEFT JOINed
	# to the skins table (because a primaryskid of 0 means no
	# skin, which is fine but it won't match a row in skins).
	# This is really just so we get skinname, which honestly
	# we could just iterate into the data using getSkins()
	# afterwards...
	$tables .= ' LEFT JOIN skins ON skins.skid=stories.primaryskid';

	# How far ahead in time to look?  We have three vars that control
	# this:  one boolean that decides whether infinite or not, and if
	# not, two others that give lookahead time in seconds.
	if ($constants->{admin_story_lookahead_infinite}) {
		# We want all future stories.  So don't limit by time at all.
	} else {
		my $lookahead = $is_mainpage
			? $constants->{admin_story_lookahead_mainpage}
			: $constants->{admin_story_lookahead_default};
		$lookahead ||= 72 * 3600;
		push @where, "time < DATE_ADD(NOW(), INTERVAL $lookahead SECOND)";
	}

	my $other = "ORDER BY time DESC LIMIT $first_story, $num_stories";

	my $where = join ' AND ', @where;

	# Fetch the count, and fetch the data.

	my $count = $self->sqlSelect("COUNT(*)", $tables, $where);
	my $list = $self->sqlSelectAllHashrefArray($columns, $tables, $where, $other);

	# Set some data tidbits for each story on the list.  Don't set
	# displaystatus yet;  we'll do that next, with a method that
	# fetches a lot of data all at once for efficiency.
	my $stoids = [];
	my $tree = $self->getTopicTree();
	for my $story (@$list) {
		$story->{skinname} ||= 'mainpage';
		$story->{topic} = $tree->{$story->{tid}}{keyword} if $story->{tid};
		push @$stoids, $story->{stoid};
	}
	# Now set displaystatus.
	my $ds = $self->displaystatusForStories($stoids);
	for my $story (@$list) {
		$story->{displaystatus} = $ds->{$story->{stoid}};
	}

	return($count, $list);
}

# XXXSECTIONTOPICS Stub method which needs to be filled in
sub getPrimaryTids {
	my ($self, $stoids);
	return {};
}

##################################################################
# This will screw with an autopoll -Brian
sub getSidForQID {
	my($self, $qid) = @_;
	return $self->sqlSelect("sid", "stories",
				"qid=" . $self->sqlQuote($qid),
				"ORDER BY time DESC");
}

##################################################################
sub getPollVotesMax {
	my($self, $qid) = @_;
	my $qid_quoted = $self->sqlQuote($qid);
	my($answer) = $self->sqlSelect("MAX(votes)", "pollanswers",
		"qid=$qid_quoted");
	return $answer;
}

########################################################
sub getTZCodes {
	my($self) = @_;
	my $answer = _genericGetsCache('tzcodes', 'tz', '', @_);
	return $answer;
}

########################################################
sub getDSTRegions {
	my($self) = @_;
	my $answer = _genericGetsCache('dst', 'region', '', @_);

	for my $region (keys %$answer) {
		my $dst = $answer->{$region};
		$answer->{$region} = {
			start	=> [ @$dst{map { "start_$_" } qw(hour wnum wday month)} ],
			end	=> [ @$dst{map { "end_$_" } qw(hour wnum wday month)} ],
		};
	}

	return $answer;
}

##################################################################
sub getSlashdStatus {
	my($self) = @_;
	my $answer = _genericGet({
		table		=> 'slashd_status',
		table_prime	=> 'task',
		arguments	=> \@_,
	});
	return $answer;
}

##################################################################
sub getAccesslog {
	my($self) = @_;
	my $answer = _genericGet({
		table		=> 'accesslog',
		table_prime	=> 'id',
		arguments	=> \@_,
	});
	return $answer;
}

##################################################################
sub getSlashdStatuses {
	my($self) = @_;
	my $answer = _genericGets('slashd_status', 'task', '', @_);
	return $answer;
}

##################################################################
sub getMaxCid {
	my($self) = @_;
	return $self->sqlSelect("MAX(cid)", "comments");
}

##################################################################
sub getMaxModeratorlogId {
	my($self) = @_;
	return $self->sqlSelect("MAX(id)", "moderatorlog");
}

##################################################################
sub getRecentComments {
	my($self, $options) = @_;
	my $constants = getCurrentStatic();
	my($min, $max) = ($constants->{comment_minscore},
		$constants->{comment_maxscore});
	$min = $options->{min} if defined $options->{min};
	$max = $options->{max} if defined $options->{max};
	my $sid = $options->{sid} if defined $options->{sid};
	$max = $min if $max < $min;
	my $startat = $options->{startat} || 0;
	my $num = $options->{num} || 100; # should be a var

	my $max_cid = $self->getMaxCid();
	my $start_cid = $max_cid - ($startat+($num*5-1));
	my $end_cid = $max_cid - $startat;

	my($limit_clause, $where_extra);
	if ($sid) {
		$where_extra  = " AND comments.sid = ".$self->sqlQuote($sid);
		$limit_clause = " LIMIT $startat, $num ";
	} else {
		$where_extra  = " AND comments.cid BETWEEN $start_cid and $end_cid ";
		$limit_clause = " LIMIT $num"; 
	}

	my $ar = $self->sqlSelectAllHashrefArray(
		"comments.sid AS sid, comments.cid AS cid,
		 date, comments.ipid AS ipid,
		 comments.subnetid AS subnetid, subject,
		 comments.uid AS uid, points AS score,
		 lastmod, comments.reason AS reason,
		 users.nickname AS nickname,
		 comment_text.comment AS comment,
		 SUM(val) AS sum_val,
		 IF(moderatorlog.cid IS NULL, 0, COUNT(*))
		 	AS num_mods",
		"comments, users, comment_text
		 LEFT JOIN moderatorlog
		 	ON comments.cid=moderatorlog.cid
			AND moderatorlog.active=1",
		"comments.uid=users.uid
		 AND comments.cid = comment_text.cid
		 AND comments.points BETWEEN $min AND $max
		 $where_extra",
		"GROUP BY comments.cid
		 ORDER BY comments.cid DESC
		 $limit_clause"
	);

	return $ar;
}

########################################################

# This method is used to grandfather in old-style sid's,
# automatically converting them to stoids.
sub getStoidFromSidOrStoid {
	my($self, $id) = @_;
	return $id if $id =~ /^\d+$/;
	return $self->getStoidFromSid($id);
}

# This method does the conversion efficiently.  There are three
# likely levels of caching here, to minimize the impact of this
# backwards-compatibility feature as much as possible:  a RAM
# cache in this Slash::DB::MySQL object (set to never expire,
# since this data is tiny and never changes);  memcached (ditto,
# but just with a very long expiration time); and MySQL's query
# cache (which expires only when the stories table is written,
# hopefully only every few minutes).  Only if all those fail
# will it actually put any load on the DB.
sub getStoidFromSid {
	my($self, $sid) = @_;
	if (my $stoid = $self->{_sid_conversion_cache}{$sid}) {
#print STDERR "getStoidFromSid $$ returning from cache $sid=$stoid\n";
		return $stoid;
	}
	my($mcd, $mcdkey);
	if ($mcd = $self->getMCD()) {
		$mcdkey = "$self->{_mcd_keyprefix}:sid:";
		if (my $answer = $mcd->get("$mcdkey$sid")) {
			$self->{_sid_conversion_cache}{$sid} = $answer;
#print STDERR "getStoidFromSid $$ returning from memcached $sid=$answer\n";
			return $answer;
		}
	}
	my $sid_q = $self->sqlQuote($sid);
	my $stoid = $self->sqlSelect("stoid", "stories", "sid=$sid_q");
	$self->{_sid_conversion_cache}{$sid} = $stoid;
	$mcd->set("$mcdkey$sid", $stoid, 7 * 86400) if $mcd;
#print STDERR "getStoidFromSid $$ returning from db $sid=$stoid\n";
	return $stoid;
}

sub getStory {
	my($self, $id, $val, $force_cache_freshen) = @_;
	my $constants = getCurrentStatic();

	# If our story cache is too old, expire it.
	_genericCacheRefresh($self, 'stories', $constants->{story_expire});
	my $table_cache = '_stories_cache';
	my $table_cache_time= '_stories_cache_time';

	# Accept either a stoid or a sid.
	my $stoid = $self->getStoidFromSidOrStoid($id);

	# Go grab the data if we don't have it, or if the caller
	# demands that we grab it anyway.
	my $is_in_local_cache = exists $self->{$table_cache}{"stoid$stoid"};
	my $use_local_cache = $is_in_local_cache && !$force_cache_freshen;
	my $mcd;
	my $got_it_from_db = 0;
	my $got_it_from_memcached = 0;
	my $use_memcached = 0;
#print STDERR "getStory $$ A id=$id is_in_local_cache=$is_in_local_cache use_local_cache=$use_local_cache force_cache_freshen=$force_cache_freshen\n";
	if (!$use_local_cache) {
		$mcd = $self->getMCD();
		my $try_memcached = $mcd && !$force_cache_freshen;
		if ($try_memcached) {
			# Try to get the story from memcached;  if success,
			# write it into local cache where we will pluck it
			# out and return it.
			my $mcdkey = "$self->{_mcd_keyprefix}:st:";
			if (my $answer = $mcd->get("$mcdkey$stoid")) {
				# Cache the result.
				$self->{$table_cache}{"stoid$stoid"} = $answer;
				$is_in_local_cache = 1;
				$got_it_from_memcached = 1;
#print STDERR "getStory $$ A2 id=$id mcd=$mcd try=$try_memcached answer='" . join(" ", sort keys %$answer) . "'\n";
			}
		}
#print STDERR "getStory $$ A3 id=$id mcd=$mcd try=$try_memcached keyprefix=$self->{_mcd_keyprefix} stoid=$stoid\n";
	}
#print STDERR "getStory $$ B id=$id is_in_local_cache=$is_in_local_cache use_local_cache=$use_local_cache\n";
	if (!$is_in_local_cache || $force_cache_freshen) {
		# Load it from the DB, write it into local cache,
		# where we will pluck it out and return it.
		my($append, $answer, $id_clause);
		$id_clause = "stoid=$stoid";
		my($column_clause) = $self->_stories_time_clauses({
			try_future => 1, must_be_subscriber => 0
		});
		$answer = $self->sqlSelectHashref("*, $column_clause",
			'stories', $id_clause);
		if (!$answer || ref($answer) ne 'HASH' || !$answer->{stoid}) {
			# If there's no data for us to return,
			# we shouldn't touch the cache.
			return undef;
		}
		$append = $self->sqlSelectHashref('*', 'story_text', $id_clause);
		for my $key (keys %$append) {
			$answer->{$key} = $append->{$key};
		}
		$append = $self->sqlSelectAllKeyValue('name,value',
			'story_param', $id_clause);
		for my $key (keys %$append) {
			$answer->{$key} = $append->{$key};
		}
		# If this is the first data we're writing into the cache,
		# mark the time -- this data, and any other stories we
		# write into the cache for the next n seconds, will be
		# expired at that time.
		$self->{$table_cache_time} = time() if !$self->{$table_cache_time};
		# Cache the data (using two pointers to the same data).
		$self->{$table_cache}{"stoid$stoid"} = $answer;
		# Note that we got this from the DB, in which case it's
		# authoritative enough to write into memcached later.
		$got_it_from_db = 1;
	}
#print STDERR "getStory $$ C id=$id table_cache='" . join(" ", sort keys %{ $self->{$table_cache}{"stoid$stoid"} }) . "'\n";

	# The data is in the table cache now.
	my $hr = $self->{$table_cache}{"stoid$stoid"};
	my $retval;
	if ($val && !ref $val) {
		# Caller only asked for one return value.
		if (exists $hr->{$val}) {
			$retval = $hr->{$val};
		}
	} else {
		# Caller asked for multiple return values.  It really doesn't
		# matter what specifically they asked for, we always return
		# the same thing:  a hashref with all the values.
		my %return = %$hr;
		$retval = \%return;
	}

	# If the story in question is in the future, we now zap it from the
	# cache -- on the theory that (1) requests for stories from the future
	# should be few in number and (2) the fake column indicating that it
	# is from the future is something we don't want to cache because its
	# "true" value will become incorrect within a few minutes.  We don't
	# just set the value to expire at a particular time because (1) that
	# would involve converting the story's timestamp to unix epoch, and
	# (2) we can't expire individual stories, we'd have to expire the
	# whole story cache, and that would not be good for performance.
	if ($hr->{is_future}) {
		delete $self->{$table_cache}{"stoid$stoid"};
#print STDERR "getStory $$ is_future, delete ram cache for $stoid\n";
	} elsif ($got_it_from_db and $mcd ||= $self->getMCD()) {
		# The fact that we're keeping it in our cache means it may
		# be valuable to have in the memcached cache too, and
		# either it's not in memcached already or we just got a
		# fresh copy that's worth writing over what's there with.
		my $mcdkey = "$self->{_mcd_keyprefix}:st:";
		$mcd->set("$mcdkey$stoid", $hr, $constants->{story_expire});
#print STDERR "getStory $$ set memcached " . scalar(keys %$hr) . " keys for $stoid: '" . join(" ", sort keys %$hr) . "'\n";
	}
#print STDERR "getStory $$ got from " . ($got_it_from_db ? "DB" : $got_it_from_memcached ? "MEMCACHED" : "LOCALCACHE") . " returning " . scalar(keys %$hr) . " keys for $stoid\n";
	# Now return what we need to return.
	return $retval;
}

########################################################
sub setCommonStoryWords {
	my($self) = @_;
	my $form      = getCurrentForm();
	my $constants = getCurrentStatic();
	my $words;

	if (ref($form->{_multi}{set_common_word}) eq 'ARRAY') {
		$words = $form->{_multi}{set_common_word};
	} elsif ($form->{set_common_word}) {
		$words = $form->{set_common_word};
	}
	if ($words) {
		my %common_words = map { $_ => 1 } split " ", ($self->getVar('common_story_words', 'value', 1) || "");

		if (ref $words eq "ARRAY") {
			$common_words{$_} = 1 foreach @$words;
		} else {
			$common_words{$words} = 1;
		}

		# assuming our storage limits are the same as for uncommon words
		my $maxlen = $constants->{uncommonstorywords_maxlen} || 65000; 

		my $common_words = substr(join(" ", keys %common_words), 0, $maxlen); if (length($common_words) == $maxlen) { $common_words =~ s/\s+\S+\Z//; }
		$self->setVar("common_story_words", $common_words);
	}
}

########################################################
sub getSimilarStories {
	my($self, $story, $max_wanted) = @_;
	$max_wanted ||= 100;
	my $constants = getCurrentStatic();
	my($title, $introtext, $bodytext) =
		($story->{title} || "",
		 $story->{introtext} || "",
		 $story->{bodytext} || "");
	my $not_original_sid = $story->{sid} || "";
	$not_original_sid = " AND stories.sid != "
		. $self->sqlQuote($not_original_sid)
		if $not_original_sid;

	my $text = "$title $introtext $bodytext";
	# Find a list of all the words in the current story.
	my $data = {
		title		=> { text => $title,		weight => 5.0 },
		introtext	=> { text => $introtext,	weight => 3.0 },
		bodytext	=> { text => $bodytext,		weight => 1.0 },
	};
	my $text_words = findWords($data);
	# Load up the list of words in recent stories (the only ones we
	# need to concern ourselves with looking for).
	my @recent_uncommon_words = split " ",
		($self->getVar("uncommonstorywords", "value") || "");
	my %common_words = map { $_ => 1 } split " ", ($self->getVar("common_story_words", "value", 1) || "");
	@recent_uncommon_words = grep {!$common_words{$_}} @recent_uncommon_words;

	# If we don't (yet) know the list of uncommon words, return now.
	return [ ] unless @recent_uncommon_words;
	# Find the intersection of this story and recent stories.
	my @text_uncommon_words =
		sort {
			$text_words->{$b}{weight} <=> $text_words->{$a}{weight}
			||
			$a cmp $b
		}
		grep { $text_words->{$_}{count} }
		grep { length($_) > 3 }
		@recent_uncommon_words;
#print STDERR "text_words: " . Dumper($text_words);
#print STDERR "uncommon intersection: '@text_uncommon_words'\n";
	# If there is no intersection, return now.
	return [ ] unless @text_uncommon_words;
	# If that list is too long, don't use all of them.
	my $maxwords = $constants->{similarstorymaxwords} || 30;
	$#text_uncommon_words = $maxwords-1
		if $#text_uncommon_words > $maxwords-1;
	# Find previous stories which have used these words.
	my $where = "";
	my @where_clauses = ( );
	for my $word (@text_uncommon_words) {
		my $word_q = $self->sqlQuote('%' . $word . '%');
		push @where_clauses, "story_text.title LIKE $word_q";
		push @where_clauses, "story_text.introtext LIKE $word_q";
		push @where_clauses, "story_text.bodytext LIKE $word_q";
	}
	$where = join(" OR ", @where_clauses);
	my $n_days = $constants->{similarstorydays} || 30;
	my $stories = $self->sqlSelectAllHashref(
		"sid",
		"stories.sid AS sid, stories.stoid AS stoid,
			title, introtext, bodytext, time",
		"stories, story_text",
		"stories.stoid = story_text.stoid $not_original_sid
		 AND stories.time >= DATE_SUB(NOW(), INTERVAL $n_days DAY)
		 AND ($where)"
	);
#print STDERR "similar stories: " . Dumper($stories);

	for my $sid (keys %$stories) {
		# Add up the weights of each story in turn, for how closely
		# they match with the current story.  Include a multiplier
		# based on the length of the match.
		my $s = $stories->{$sid};
		$stories->{$sid}{displaystatus} = $self->_displaystatus($stories->{$sid}{stoid}, { no_time_restrict => 1 });
		$s->{weight} = 0;
		for my $word (@text_uncommon_words) {
			my $word_weight = 0;
			my $wr = qr{(?i:\b\Q$word\E)};
			my $m = log(length $word);
			$word_weight *= 1.5 if $text_words->{$word}{is_url};
			$word_weight *= 2.5 if $text_words->{$word}{is_url_with_path};
			$word_weight += 2.0*$m * (() = $s->{title} =~     m{$wr}g);
			$word_weight += 1.0*$m * (() = $s->{introtext} =~ m{$wr}g);
			$word_weight += 0.5*$m * (() = $s->{bodytext} =~  m{$wr}g);
			$s->{word_hr}{$word} = $word_weight if $word_weight > 0;
			$s->{weight} += $word_weight;
		}
		# Round off weight to 0 decimal places (to an integer).
		$s->{weight} = sprintf("%.0f", $s->{weight});
		# Store (the top-scoring-ten of) the words that connected
		# the original story to this story.
		$s->{words} = [
			sort { $s->{word_hr}{$b} <=> $s->{word_hr}{$a} }
			keys %{$s->{word_hr}}
		];
		$#{$s->{words}} = 9 if $#{$s->{words}} > 9;
	}
	# If any stories match and are above the threshold, return them.
	# Pull out the top $max_wanted scorers.  Then sort them by time.
	my $minweight = $constants->{similarstoryminweight} || 4;
	my @sids = sort {
		$stories->{$b}{weight} <=> $stories->{$a}{weight}
		||
		$stories->{$b}{'time'} cmp $stories->{$a}{'time'}
		||
		$a cmp $b
	} grep { $stories->{$_}{weight} >= $minweight } keys %$stories;
#print STDERR "all sids @sids stories " . Dumper($stories);
	return [ ] if !@sids;
	$#sids = $max_wanted-1 if $#sids > $max_wanted-1;
	# Now that we have only the ones we want, push them onto the
	# return list sorted by time.
	my $ret_ar = [ ];
	for my $sid (sort {
		$stories->{$b}{'time'} cmp $stories->{$a}{'time'}
		||
		$stories->{$b}{weight} <=> $stories->{$a}{weight}
		||
		$a cmp $b
	} @sids) {
		push @$ret_ar, {
			sid =>		$sid,
			weight =>	sprintf("%.0f", $stories->{$sid}{weight}),
			title =>	$stories->{$sid}{title},
			'time' =>	$stories->{$sid}{'time'},
			words =>	$stories->{$sid}{words},
			displaystatus => $stories->{$sid}{displaystatus},
		};
	}
#print STDERR "ret_ar " . Dumper($ret_ar);
	return $ret_ar;
}

########################################################
# For run_moderatord.pl and plugins/Stats/adminmail.pl
sub getYoungestEligibleModerator {
	my($self) = @_;
	my $constants = getCurrentStatic();
	my $youngest_uid = $self->countUsers({ max => 1 })
		* ($constants->{m1_eligible_percentage} || 0.8);
	return int($youngest_uid);
}

########################################################
sub getAuthor {
	my($self) = @_;
	_genericCacheRefresh($self, 'authors_cache', getCurrentStatic('block_expire'));
	my $answer = _genericGetCache({
		table		=> 'authors_cache',
		table_prime	=> 'uid',
		arguments	=> \@_,
	});
	return $answer;
}

########################################################
# This of course is modified from the norm
sub getAuthors {
	my $answer = _genericGetsCache('authors_cache', 'uid', '', @_);
	return $answer;
}

########################################################
# copy of getAuthors, for admins ... needed for anything?
sub getAdmins {
	my($self, $cache_flag) = @_;

	my $table = 'admins';
	my $table_cache = '_' . $table . '_cache';
	my $table_cache_time = '_' . $table . '_cache_time';
	my $table_cache_full = '_' . $table . '_cache_full';

	if (keys %{$self->{$table_cache}} && $self->{$table_cache_full} && !$cache_flag) {
		my %return = %{$self->{$table_cache}};
		return \%return;
	}

	$self->{$table_cache} = {};
	my $qlid = $self->_querylog_start("SELECT", "users, users_info");
	my $sth = $self->sqlSelectMany(
		'users.uid,nickname,fakeemail,homepage,bio',
		'users,users_info',
		'seclev >= 100 and users.uid = users_info.uid'
	);
	while (my $row = $sth->fetchrow_hashref) {
		$self->{$table_cache}{ $row->{'uid'} } = $row;
	}

	$self->{$table_cache_full} = 1;
	$sth->finish;
	$self->_querylog_finish($qlid);
	$self->{$table_cache_time} = time();

	my %return = %{$self->{$table_cache}};
	return \%return;
}

########################################################
sub getComment {
	my $answer = _genericGet({
		table		=> 'comments',
		table_prime	=> 'cid',
		arguments	=> \@_,
	});
	return $answer;
}

########################################################
sub getPollQuestion {
	my $answer = _genericGet({
		table		=> 'pollquestions',
		table_prime	=> 'qid',
		arguments	=> \@_,
	});
	return $answer;
}

########################################################
sub getRelatedLink {
	my $answer = _genericGet({
		table		=> 'related_links',
		arguments	=> \@_,
	});
	return $answer;
}

########################################################
sub getDiscussion {
	my $answer = _genericGet({
		table		=> 'discussions',
		arguments	=> \@_,
	});
	return $answer;
}

########################################################
sub getDiscussionBySid {
	my $answer = _genericGet({
		table		=> 'discussions',
		table_prime	=> 'sid',
		arguments	=> \@_,
	});
	return $answer;
}

########################################################
sub getRSS {
	my $answer = _genericGet({
		table		=> 'rss_raw',
		arguments	=> \@_,
	});
	return $answer;
}

########################################################
sub setRSS {
	_genericSet('rss_raw', 'id', '', @_);
}

########################################################
sub getBlock {
	my($self) = @_;
	_genericCacheRefresh($self, 'blocks', getCurrentStatic('block_expire'));
	my $answer = _genericGetCache({
		table		=> 'blocks',
		table_prime	=> 'bid',
		arguments	=> \@_,
	});
	return $answer;
}

########################################################
sub getTemplateNameCache {
	my($self) = @_;
	my %cache;
	my $templates = $self->sqlSelectAll('tpid, name, page, skin', 'templates');
	for (@$templates) {
		my($tpid, $name, $page, $skin) = @$_;
		$cache{$name}{$page}{$skin} = $tpid;
	}
	return \%cache;
}

########################################################
sub existsTemplate {
	# if this is going to get called a lot, we already
	# have the template names cached -- pudge
	# It's only called by Slash::Install and in
	# Slash::Utility::Anchor::ssiHeadFoot, so it won't
	# waste time during a web hit. - Jamie
	my($self, $template) = @_;
	my @clauses = ( );
	for my $field (qw( name page skin )) {
		push @clauses, "$field=" . $self->sqlQuote($template->{$field});
	}
	my $clause = join(" AND ", @clauses);
	my $answer = $self->sqlSelect('tpid', 'templates', $clause);
	return $answer;
}

########################################################
sub getTemplate {
	my($self) = @_;
	_genericCacheRefresh($self, 'templates', getCurrentStatic('block_expire'));
	my $answer = _genericGetCache({
		table		=> 'templates',
		table_prime	=> 'tpid',
		arguments	=> \@_,
	});
	return $answer;
}

########################################################
sub getTemplateListByText {
	my($self, $text) = @_;

	my %templatelist;
	my $where = 'template LIKE ' . $self->sqlQuote("%${text}%");
	my $templates =	$self->sqlSelectMany('tpid, name', 'templates', $where); 
	while (my($tpid, $name) = $templates->fetchrow) {
		$templatelist{$tpid} = $name;
	}

	return \%templatelist;
}


########################################################
# This is a bit different
sub getTemplateByName {
	my($self, $name, $options) = @_; # $values, $cache_flag, $page, $section, $ignore_errors) = @_;
	return if ref $name;    # no scalar refs, only text names

	# $options is $values if arrayref or scalar, stays $options if hashref
	my $values;
	if ($options) {
		my $ref = ref $options;
		if (!$ref || $ref eq 'ARRAY') { 
			$values = $options;
			$options = {};
		} elsif ($ref eq 'HASH') {
			$values = $options->{values};
		} else {        
			$options = {};
		}               
	} else {                
		$options = {};  
	}               

	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	_genericCacheRefresh($self, 'templates', $constants->{block_expire});

	my $table_cache      = '_templates_cache';
	my $table_cache_time = '_templates_cache_time';
	my $table_cache_id   = '_templates_cache_id';

	# First, we get the cache -- read in ALL templates and store their
	# data in $self
	# get new cache unless we have a cache already AND we want to use it
	unless ($self->{$table_cache_id} &&
		($constants->{cache_enabled} || $constants->{cache_enabled_template})
	) {
		$self->{$table_cache_id} = getTemplateNameCache($self);
	}               

	#Now, lets determine what we are after
	my($page, $skin) = (@{$options}{qw(page skin)});
	unless ($page) {
		$page = getCurrentUser('currentPage');
		$page ||= 'misc';
	}
	unless ($skin) {
		$skin = "light" if $user->{light};
		$skin ||= getCurrentSkin('name');
		$skin ||= 'default';
	}

	#Now, lets figure out the id
	#name|page|skin => name|page|default => name|misc|skin => name|misc|default
	# That frat boy march with a paddle
	my $id = $self->{$table_cache_id}{$name}{$page }{  $skin  };
	$id  ||= $self->{$table_cache_id}{$name}{$page }{'default'};
	$id  ||= $self->{$table_cache_id}{$name}{'misc'}{  $skin  };
	$id  ||= $self->{$table_cache_id}{$name}{'misc'}{'default'};
	if (!$id) {
		if (!$options->{ignore_errors}) {
			# Not finding a template is reasonably serious.  Let's make the
			# error log entry pretty descriptive.
			my @caller_info = ( );
			for (my $lvl = 1; $lvl < 99; ++$lvl) {
				my @c = caller($lvl);
				last unless @c;
				next if $c[0] =~ /^Template/;
				push @caller_info, "$c[0] line $c[2]";
				last if scalar(@caller_info) >= 3;
			}
			errorLog("Failed template lookup on '$name;$page\[misc\];$skin\[default\]'"
				. ", callers: " . join(", ", @caller_info));
		}
		return ;
	}

	my $type;
	if (ref($values) eq 'ARRAY') {
		$type = 0;
	} else {
		$type  = $values ? 1 : 0;
	}

	if ( !$options->{cache_flag} && exists($self->{$table_cache}{$id}) && keys(%{$self->{$table_cache}{$id}}) ) {
		if ($type) {
			return $self->{$table_cache}{$id}{$values};
		} else {
			my %return = %{$self->{$table_cache}{$id}};
			return \%return;
		}
	}

	$self->{$table_cache}{$id} = {};
	my $answer = $self->sqlSelectHashref('*', "templates", "tpid=$id");
	$answer->{'_modtime'} = time();
	$self->{$table_cache}{$id} = $answer;

	$self->{$table_cache_time} = time();

	if ($type) {
		return $self->{$table_cache}{$id}{$values};
	} else { 
		if ($self->{$table_cache}{$id}) {
			my %return = %{$self->{$table_cache}{$id}};
			return \%return;
		} 
	}

	return $answer; 
}

########################################################
# Convert a list of chosen topics to a list of rendered topics.
# Input is a hashref with keys tids and values weights;
# output is the same.
#
# This works for either stories or submissions.  Or whatever
# other data we end up attaching chosen and rendered topics to.
#
# The algorithm is simple:  walk up the tree, following all
# child->parent links that don't demand a minimum weight higher
# than the weight assigned to that child.  As we walk up the
# tree, at each node, the weight is the maximum of all weights
# that have propagated up to that node, unless the node is in
# the original chosen list, in which case its weight is always
# the chosen weight, no more or less.  (Yes, it's simple, but
# recursion is always subtly tricky!)  Note that existence of a
# node in the input hashref is significant, regardless of
# weight, since a weight of 0 has meaning.  But existence of a
# node in the output hashref with weight 0 would be nonsense,
# since any rendered topic must have weight > 0, so any nodes
# with weight 0 on input will not appear in the output.
#
# The reason for this is hard to explain, because it's an
# essential part of the whole topic tree system.  The purpose
# here is to take a list of topics chosen by a human, and generate
# a list of topics that the code can do a SELECT on to determine
# whether a story falls into a particular category.  This is
# what makes getting the list of all stories in a particular
# nexus doable in anything like reasonable time.
#
# XXXSECTIONTOPICS this could be optimized:  roughly speaking,
# it's O(n**2) right now and it should be O(n).  But in
# reality the difference is a few microseconds every time
# an admin clicks Save.
sub renderTopics {
	my($self, $chosen_hr) = @_;
	return { } if !%$chosen_hr;

	my $tree = $self->getTopicTree();
	my %rendered = %$chosen_hr;
	my $done = 0;
	while (!$done) {
		# Each time through this loop, assume it's our
		# last unless something happens.
		$done = 1;
		for my $tid (keys %rendered) {
			next if $rendered{$tid} == 0;
			my $p_hr = $tree->{$tid}{parent};
			for my $pid (keys %$p_hr) {
				# Chosen weight always overrides
				# any propagated weight.
				next if exists $chosen_hr->{$pid};
				# If we already had this node at
				# this weight or higher, skip.
				next if $rendered{$pid} >= $rendered{$tid};
				# If the connection from the child
				# to parent topic demands a min weight
				# higher than this weight, skip.
				next if $rendered{$tid} < $p_hr->{$pid};
				# OK this is new, propagate up.
				$rendered{$pid} = $rendered{$tid};
				# We made a change; we're not done.
				$done = 0;
			}
		}
	}

	# A rendered topic with weight 0 is a contradiction in
	# terms.
	my @zeroes = grep { $rendered{$_} == 0 } keys %rendered;
	delete $rendered{$_} for @zeroes;

	return \%rendered;
}

########################################################
# Get chosen topics for a story in hashref form
sub getStoryTopicsChosen {
	my($self, $stoid) = @_;
	return $self->sqlSelectAllKeyValue(
		"tid, weight",
		"story_topics_chosen",
		"stoid='$stoid'");
}

########################################################
# Get rendered topics for a story in hashref form
sub getStoryTopicsRendered {
	my($self, $stoid) = @_;
	return $self->sqlSelectAllKeyValue(
		"tid, weight",
		"story_topics_rendered",
		"stoid='$stoid'");
}

########################################################
# Given a story ID, and assumes the story_topics_chosen table
# is set up correctly for it.  Renders those chosen topics
# and replaces them into the story_topics_rendered table.
# Returns a list whose first element is the primary skid
# (XXXSECTIONTOPICS this is not totally unambiguous) and
# whose remaining elements are the topics in topiclist order.
# Pass in $chosen_hr to save a query.
sub setStoryRenderedFromChosen {
	my($self, $stoid, $chosen_hr, $info) = @_;

	$self->setStory_delete_memcached([ $stoid ]);
	$chosen_hr ||= $self->getStoryTopicsChosen($stoid);
	my $rendered_hr = $self->renderTopics($chosen_hr);
	my $primaryskid = $self->getPrimarySkidFromRendered($rendered_hr);
	my $tids = $self->getTopiclistForStory($stoid,
		{ topics_chosen => $chosen_hr });

	$self->sqlDelete("story_topics_rendered", "stoid = $stoid");
	if (!$info->{neverdisplay}) {
		for my $key (sort keys %$rendered_hr) {
			unless ($self->sqlInsert("story_topics_rendered", 
				{ stoid => $stoid, tid => $key, weight => $rendered_hr->{$key} }
			)) {
				# and we should ROLLBACK here
				return undef;
			}
		}
	}
	$self->setStory_delete_memcached([ $stoid ]);

	return($primaryskid, $tids);
}

sub getPrimarySkidFromRendered {
	my($self, $rendered_hr) = @_;

	my @nexuses = $self->getNexusTids();

	# Eliminate any nexuses not in this set of rendered topics.
	@nexuses = grep { $rendered_hr->{$_} } @nexuses;

	# Nexuses that don't have (at least) one skin that points
	# to them aren't in the running to influence primaryskid.
	@nexuses = grep { $self->getSkidFromNexus($_) } @nexuses;

	# No rendered nexuses with associated skins, none at all,
	# means primaryskid 0, which means "none".
	return 0 if !@nexuses;

	# Eliminate the mainpage's nexus.
	my $mp_skid = getCurrentStatic("mainpage_skid");
	my $mp_nexus = $self->getNexusFromSkid($mp_skid);
	@nexuses = grep { $_ != $mp_nexus } @nexuses;

	# If nothing left, just return the mainpage.
	return $mp_skid if !@nexuses;

	# Sort by rendered weight.
	@nexuses = sort {
		$rendered_hr->{$b} <=> $rendered_hr->{$a}
		||
		$a <=> $b
	} @nexuses;
#print STDERR "getPrimarySkidFromRendered finds nexuses '@nexuses' for: " . Dumper($rendered_hr);

	# Top answer is ours.
	return $self->getSkidFromNexus($nexuses[0]);
}

########################################################
# Takes a hashref of chosen topics, and an optional skid.
# Arranges the topics in order of of topics chosen for the
# story, arranges them in order of most appropriate to least,
# and returns an arrayref of their topic IDs in that order.  If a
# skid is provided, topics that have that skid as a parent are
# given priority.  This list ("topiclist") is typically used for
# displaying a list of icons for a story or submission, displaying
# a verbal list of topics in search results, that kind of thing.
sub getTopiclistFromChosen {
	my($self, $chosen_hr, $options) = @_;
	my $tree = $self->getTopicTree();

	# Determine which of the chosen topics is in the preferred skin
	# (using the weights given).  These will get priority.
	my $skid = $options->{skid} || 0;
	my %in_skid = ( );
	if ($skid) {
		my $nexus = $self->getNexusFromSkid($skid);
		%in_skid = map { $_, 1 }
			grep { $self->isTopicParent($nexus, $_,
				{ weight => $chosen_hr->{$_} }) }
			keys %$chosen_hr;
	}

	my @tids = sort {
			# Highest priority is whether this topic is
			# NOT a nexus (nexus topics go at the end).
		   (exists $tree->{$a}{nexus} ? 1 : 0) <=> (exists $tree->{$b}{nexus} ? 1 : 0)
			# Next highest priority is whether this topic
			# has an icon.
		|| ($tree->{$a}{image} ? 1 : 0) <=> ($tree->{$b}{image} ? 1 : 0)
			# Next highest priority is whether this topic
			# (at this weight) is in the preferred skid.
		|| $in_skid{$b} <=> $in_skid{$a}
			# Next priority is the topic's weight
		|| $chosen_hr->{$b} <=> $chosen_hr->{$a}
			# Next priority is alphabetical sort
		|| $tree->{$a}{textname} cmp $tree->{$b}{textname}
			# Last priority is primary key sort
		|| $a <=> $b
	} keys %$chosen_hr;
	return \@tids;
}

########################################################
# Takes a story ID and optional skid.  Looks through the list
# of topics chosen for the story, arranges them in order of
# most appropriate to least, and returns an arrayref of their
# topic IDs in that order.  If a skid is provided, topics
# that have that skid as a parent are given priority.
# This list ("topiclist") is typically used for displaying a
# list of icons for a story, displaying a verbal list of
# topics in search results, that kind of thing.
# Skid is passed in $options-{skid}
# If the caller already has the chosen topics, a key-value
# hashref may be passed in $options->{topics_chosen} to
# save a query.
sub getTopiclistForStory {
	my($self, $id, $options) = @_;

	# Grandfather in an old-style sid.
	my $stoid = $self->getStoidFromSidOrStoid($id);
	return undef unless $stoid;

	my $chosen_hr = $options->{topics_chosen} || $self->getStoryTopicsChosen($stoid);
	return $self->getTopiclistFromChosen($chosen_hr, $options);
}

########################################################
sub getTopic {
	my $answer = _genericGetCache({
		table		=> 'topics',
		table_prime	=> 'tid',
		arguments	=> \@_,
	});
	return $answer;
}

########################################################
sub getTopics {
	my $answer = _genericGetsCache('topics', 'tid', '', @_);

	return $answer;
}

########################################################
# As of 2004/04:
# $add_names of 1 means to return the alt text, which is the
# human-readable name of a topic.  This is currently used
# only in article.pl to add these words and phrases to META
# information on the webpage.
# $add_names of 2 means to return the name, which is a
# (not-guaranteed-unique) short single keyword.  This is
# currently used only in adminmail.pl to append something
# descriptive to the numeric tid for the topichits_123_foo
# stats.
sub getStoryTopics {
	my($self, $id, $add_names) = @_;
	my($topicdesc);

	my $stoid = $self->getStoidFromSidOrStoid($id);
	return undef unless $stoid;

	my $topics = $self->sqlSelectAll(
		'tid',
		'story_topics_chosen',
		"stoid=$stoid"
	);

	# All this to avoid a join. :/
	#
	# Poor man's hash assignment from an array for the short names.
	$topicdesc =  {
		map { @{$_} }
		@{$self->sqlSelectAll(
			'tid, keyword',
			'topics'
		)}
	} if $add_names == 2;

	# We use a Description for the long names. 
	$topicdesc = $self->getDescriptions('topics') 
		if !$topicdesc && $add_names;

	my $answer;
	for my $topic (@$topics) {
		$answer->{$topic->[0]} = $add_names && $topicdesc
			? $topicdesc->{$topic->[0]} : 1;
	}

	return $answer;
}

########################################################
sub setStoryTopicsChosen {
	my($self, $id, $topic_ref) = @_;

	# Grandfather in an old-style sid.
	my $stoid = $self->getStoidFromSidOrStoid($id);
	return 0 unless $stoid;

	# There are atomicity issues here if two admins click Update at
	# the same time.  We really should wrap the delete-insert
	# as a single COMMIT.  Not that it matters much.  - Jamie

	$self->setStory_delete_memcached([ $stoid ]);
	$self->sqlDelete("story_topics_chosen", "stoid = $stoid");
	for my $key (sort { $a <=> $b } keys %{$topic_ref}) {
		unless ($self->sqlInsert("story_topics_chosen", 
			{ stoid => $stoid, tid => $key, weight => $topic_ref->{$key} }
		)) {
			# and we should ROLLBACK here
			return 0;
		}
	}
	$self->setStory_delete_memcached([ $stoid ]);

	return 1;
}

########################################################
sub getTemplates {
	my $answer = _genericGetsCache('templates', 'tpid', '', @_);
	return $answer;
}

########################################################
sub getContentFilter {
	my $answer = _genericGet({
		table		=> 'content_filters',
		table_prime	=> 'filter_id',
		arguments	=> \@_,
	});
	return $answer;
}

########################################################
sub getSubmission {
	my $answer = _genericGet({
		table		=> 'submissions',
		table_prime	=> 'subid',
		param_table	=> 'submission_param',
		arguments	=> \@_,
	});
	return $answer;
}

########################################################
sub setSubmission {
	_genericSet('submissions', 'subid', 'submission_param', @_);
}

# Grandfathered in... will remove eventually I hope - Jamie 2004/05

sub getSection {
	my($self, $section, $value, $no_cache) = @_;
	my $options = { };
	$options->{force_refresh} = 1 if $no_cache;

	$section = 'mainpage' if !$section || $section eq 'index'; # convert old-style to new
	my $skin = $self->getSkin($section, $options);

#use Data::Dumper; print STDERR "getSection skin for '$section' is: " . Dumper($skin);

	return undef if !$skin;

	$skin = { %$skin };  # copy, don't change!

	# Now, for historical reasons, we pad this out with the
	# information that was in there before. - Jamie 2004/05
	$skin->{artcount} = $skin->{artcount_max};
	$skin->{contained} = [ ];
	$skin->{id} = $skin->{skid};
	$skin->{last_update} = $skin->{last_rewrite};
	$skin->{qid} = 0; # XXXSECTIONTOPICS this is wrong
	$skin->{rewrite} = $skin->{max_rewrite_secs};
	$skin->{section} = $skin->{name};
	$skin->{type} = $skin->{name} =~ /^(index|mainpage)$/ ? 'collected' : 'contained'; # XXXSECTIONTOPICS this is a hack guess and probably wrong in at least one case
	my $tree = $self->getTopicTree();
	$skin->{writestatus} = $tree->{$skin->{nexus}}{nexus_dirty} ? 'dirty' : 'ok'; # XXXSECTIONTOPICS check this

	return $skin->{$value} if $value;
	return $skin;
}

########################################################
# Allow lookup of a skin by either numeric primary key ID,
# or by name.  skins.name is a unique column so that will
# not present a problem.
sub getSkin {
	my($self, $skid, $options) = @_;
	if (!$skid) {
		errorLog("cannot getSkin for empty skid");
		$skid = getCurrentStatic('mainpage_skid');
	}
	my $skins = $self->getSkins($options);
	if ($skid !~ /^\d+$/) {
		for my $id (sort keys %$skins) {
			if ($skins->{$id}{name} eq $skid) {
				return $skins->{$id};
			}
		}
		return undef;
	}
	return $skins->{$skid};
}

########################################################
sub getSkins {
	my($self, $options) = @_;
	my $constants = getCurrentStatic();

	my $table_cache		= "_skins_cache";
	my $table_cache_time	= "_skins_cache_time";
	my $expiration = $constants->{block_expire};
	$expiration = -1 if $options->{force_refresh};
	_genericCacheRefresh($self, 'skins', $expiration);
	return $self->{$table_cache} if $self->{$table_cache_time};

	my $skins_ref = $self->sqlSelectAllHashref(    "skid",        "*", "skins");
	my $colors    = $self->sqlSelectAllHashref([qw( skid name )], "*", "skin_colors", "", "GROUP BY skid, name");
	for my $skid (keys %$skins_ref) {
		# Set rootdir etc., based on hostname/url, or mainpage's if none
		my $host_skid  = $skins_ref->{$skid}{hostname} ? $skid : $constants->{mainpage_skid};
		my $url_skid   = $skins_ref->{$skid}{url}      ? $skid : $constants->{mainpage_skid};
		my $color_skid = $colors->{$skid}              ? $skid : $constants->{mainpage_skid};

		# Convert an index_handler of foo.pl to an index_static of
		# foo.shtml, for convenience.
		($skins_ref->{$skid}{index_static} = $skins_ref->{$skid}{index_handler}) =~ s/\.pl$/.shtml/;

		# Massage the skin_colors data into this hashref in an
		# appropriate place.
		for my $name (keys %{$colors->{$color_skid}}) {
			$skins_ref->{$skid}{hexcolors}{$name} = $colors->{$color_skid}{$name}{hexcolor};
		}

		$skins_ref->{$skid}{basedomain} = $skins_ref->{$host_skid}{hostname};

		$skins_ref->{$skid}{absolutedir} = $skins_ref->{$url_skid}{url} || "http://$skins_ref->{$skid}{basedomain}";
		$skins_ref->{$skid}{absolutedir} =~ s{/+$}{};

		my $rootdir_uri = URI->new($skins_ref->{$skid}{absolutedir});

		$rootdir_uri->scheme('');
		$skins_ref->{$skid}{rootdir} = $rootdir_uri->as_string;
		$skins_ref->{$skid}{rootdir} =~ s{/+$}{};

		# XXXSKIN - untested; can we reuse $rootdir_uri ?
		if ($constants->{use_https_for_absolutedir_secure}) {
			$rootdir_uri->scheme('https');
			$skins_ref->{$skid}{absolutedir_secure} = $rootdir_uri->as_string;
			$skins_ref->{$skid}{absolutedir_secure} =~ s{/+$}{};
		} else {
			$skins_ref->{$skid}{absolutedir_secure} = $skins_ref->{$skid}{absolutedir};
		}
	}

	$self->{$table_cache} = $skins_ref;
	$self->{$table_cache_time} = time;
	return $skins_ref;
}

########################################################
# Look up a skin's ID number when passed its name.  And if
# passed in what looks like an ID number, return that!
sub getSkidFromName {
	my($self, $name) = @_;
	return $name if $name =~ /^\d+$/;
	my $skins = $self->getSkins();
	for my $skid (keys %$skins) {
		return $skid if $skins->{$skid}{name} eq $name;
	}
	# No match.
	return 0;
}

########################################################
# Look up a skin's ID number when passed the tid of a nexus.
# Note that a nexus may have 0, 1, 2, or more skins!  This
# just returns the first one found.
sub getSkidFromNexus {
	my($self, $tid) = @_;
	return 0 unless $tid;
	my $skins = $self->getSkins();
	for my $skid (sort { $a <=> $b } keys %$skins) {
		return $skid if $skins->{$skid}{nexus} == $tid;
	}
	# No match.
	return 0;
}

########################################################
sub getNexusFromSkid {
	my($self, $skid) = @_;
	my $skin = $self->getSkin($skid);
	return ($skin && $skin->{nexus}) ? $skin->{nexus} : 0;
}

########################################################
sub getModeratorLog {
	my $answer = _genericGet({
		table		=> 'moderatorlog',
		arguments	=> \@_,
	});
	return $answer;
}

########################################################
sub getVar {
	my $answer = _genericGetCache({
		table		=> 'vars',
		table_prime	=> 'name',
		arguments	=> \@_,
	});
	return $answer;
}

########################################################
sub setUser {
	my($self, $uid, $hashref, $options) = @_;
	return 0 unless $uid;

	my $constants = getCurrentStatic();

	my(@param, %update_tables, $cache);
	my $tables = [qw(
		users users_comments users_index
		users_info users_prefs
		users_hits
	)];

	# special cases for password, exboxes, people
	if (exists $hashref->{passwd}) {
		# get rid of newpasswd if defined in DB
		$hashref->{newpasswd} = '';
		$hashref->{passwd} = encryptPassword($hashref->{passwd});
	}

	# Power to the People
	$hashref->{people} = freeze($hashref->{people}) if $hashref->{people};

	# hm, come back to exboxes later; it works for now
	# as is, since external scripts handle it -- pudge
	# a VARARRAY would make a lot more sense for this, no need to
	# pack either -Brian
	if (0 && exists $hashref->{exboxes}) {
		if (ref $hashref->{exboxes} eq 'ARRAY') {
			$hashref->{exboxes} = sprintf("'%s'", join "','", @{$hashref->{exboxes}});
		} elsif (ref $hashref->{exboxes}) {
			$hashref->{exboxes} = '';
		} # if nonref scalar, just let it pass
	}

	$cache = _genericGetCacheName($self, $tables);

	for (keys %$hashref) {
		(my $clean_val = $_) =~ s/^-//;
		my $key = $self->{$cache}{$clean_val};
		if ($key) {
			push @{$update_tables{$key}}, $_;
		} else {
			push @param, [$_, $hashref->{$_}];
		}
	}

	# Delete from memcached once before we update the DB.  We only need to
	# delete if we're touching a table other than users_hits (since nothing
	# in that table is stored in memcached).
	my $mcd = $self->getMCD();
	my $mcd_need_delete = 0;
	if ($mcd) {
		$mcd_need_delete = 1 if grep { $_ ne 'users_hits' } keys %update_tables;
		$self->setUser_delete_memcached($uid) if $mcd_need_delete;
	}

	my $rows = 0;
	for my $table (keys %update_tables) {
		my $where = "uid=$uid";
		my %minihash = ( );
		for my $key (@{$update_tables{$table}}) {
			if (defined $hashref->{$key}) {
				$minihash{$key} = $hashref->{$key};
				if ($options->{and_where}) {
					my $and_where = undef;
					(my $clean_val = $key) =~ s/^-//;
					if (defined($options->{and_where}{$clean_val})) {
						$and_where = $options->{and_where}{$clean_val};
					} elsif (defined($options->{and_where}{"-$clean_val"})) {
						$and_where = $options->{and_where}{"-$clean_val"};
					}
					if (defined($and_where)) {
						$where .= " AND ($and_where)";
					}
				}
			}
		}
		$rows += $self->sqlUpdate($table, \%minihash, $where)
			if keys %minihash;
	}
	# What is worse, a select+update or a replace?
	# I should look into that. (REPLACE is faster) -Brian
	for (@param)  {
		if ($_->[1] eq "") {
			$rows += $self->sqlDelete('users_param', 
				"uid = $uid AND name = " . $self->sqlQuote($_->[0]));
		} elsif ($_->[0] eq "acl") {
			my(@delete, @add);
			my $acls = $_->[1];
			for my $key (sort keys %$acls) {
				if ($acls->{$key}) {
					push @add, $key;
				} else {
					push @delete, $key;
				}
			} 
			if (@delete) {
				my $string = join(',', @{$self->sqlQuote(\@delete)});
				$self->sqlDelete("users_acl", "acl IN ($string) AND uid=$uid");
				$mcd_need_delete = 1;
			}
			if (@add) {
				# Doing all the inserts at once is cheaper than
				# separate calls to sqlInsert().
				my $string;
				for my $acl (@add) {
					my $qacl = $self->sqlQuote($acl);
					$string .= qq| ($uid, $qacl),|
				}
				chop($string); # remove trailing comma
				my $qlid = $self->_querylog_start('INSERT', 'users_acl');
				$self->sqlDo("INSERT IGNORE INTO users_acl (uid, acl) VALUES $string");
				$self->_querylog_finish($qlid);
				$mcd_need_delete = 1;
			}
		} else {
			$rows += $self->sqlReplace('users_param', {
				uid	=> $uid,
				name	=> $_->[0],
				value	=> $_->[1],
			}) if defined $_->[1];
		}
	}

	# And delete from memcached again after we update the DB
	$mcd_need_delete = 1 if $rows;
	$self->setUser_delete_memcached($uid) if $mcd_need_delete;

	return $rows;
}

sub setUser_delete_memcached {
	my($self, $uid_list) = @_;
	my $mcd = $self->getMCD();
	return unless $mcd;
	my $constants = getCurrentStatic();
	my $mcddebug = $mcd && $constants->{memcached_debug};

	$uid_list = [ $uid_list ] if !ref($uid_list);
	for my $uid (@$uid_list) {
		my $mcdkey = "$self->{_mcd_keyprefix}:u:";
		# The "3" means "don't accept new writes to this key for 3 seconds."
		$mcd->delete("$mcdkey$uid", 3);
		if ($mcddebug > 1) {
			print STDERR scalar(gmtime) . " $$ setU_deletemcd deleted '$mcdkey$uid'\n";
		}
	}
}

########################################################
# Get a list of nicknames
sub getUsersNicknamesByUID {
	my($self, $people) = @_;
	return unless (ref($people) eq 'ARRAY') && scalar(@$people);
	my $list = join(",", @$people);
	return $self->sqlSelectAllHashref("uid", "uid,nickname", "users", "uid IN ($list)");
}

########################################################
# Get the complete list of all acl/uid pairs used on this site.
# (We assume this to be on the order of < 10K rows returned.)
# The list is returned as a hashref whose keys are the acl names
# and whose values are an arrayref of uids that have that acl
# permission.
sub getAllACLs {
	my($self) = @_;
	my $ar = $self->sqlSelectAll("uid, acl", "users_acl");
	return undef unless $ar && @$ar;
	my $hr = { };
	for my $row (@$ar) {
		my($uid, $acl) = @$row;
		push @{$hr->{$acl}}, $uid;
	}
	return $hr;
}

########################################################
# We want getUser to look like a generic, despite the fact that
# it is decidedly not :)
# New as of 9/2003: if memcached is active, we no longer do piecemeal
# DB loads of anything less than the full user data.  We grab the
# users_hits table from the DB and everything else from memcached.
sub getUser {
	my($self, $uid, $val) = @_;
	my $answer;
	my $uid_q = $self->sqlQuote($uid);

	my $constants = getCurrentStatic();
	my $mcd = $self->getMCD();
	my $mcddebug = $mcd && $constants->{memcached_debug};
	my $start_time;
	my $mcdkey = "$self->{_mcd_keyprefix}:u:" if $mcd;
	my $mcdanswer;

	if ($mcddebug > 1) {
		my $v = Dumper($val); $v =~ s/\s+/ /g;
		print STDERR scalar(gmtime) . " $$ getUser('$uid' ($uid_q), $v) mcd='$mcd'\n";
	}

	# If memcached debug enabled, start timer

	$start_time = Time::HiRes::time if $mcddebug;

	# Figure out, based on what columns we were asked for, which tables
	# we'll need to consult.  _getUser_get_table_data() caches this data,
	# so it's pretty quick to return everything we might need.  Note
	# that, with memcached, it might turn out that we don't need to use
	# the where clause or whatever;  that's OK.
	my $gtd = $self->_getUser_get_table_data($uid_q, $val);

	if ($mcddebug > 1) {
		print STDERR scalar(gmtime) . " $$ getUser can '$gtd->{can_use_mcd}' key '$mcdkey$uid' gtd: " . Dumper($gtd);
	}

	my $rawmcdanswer;
	my $used_shortcut = 0;
	if ($gtd->{can_use_mcd}
		and $mcd
		and $rawmcdanswer = $mcd->get("$mcdkey$uid")) {

		# Excellent, we can pull some data (maybe all of it)
		# from memcached.  The data at this point is already
		# in $rawmcdanswer, now we just need to determine
		# which portion of it to use.
		my $cols_still_need = [ ];
		if ($gtd->{all}) {

			# Quick shortcut.  Everything comes from
			# memcached except the users_hits table.
			# users_param and users_acl tables.
			$answer = \%{ $rawmcdanswer };
			my $users_hits = $self->sqlSelectAllHashref(
				"uid", "*", "users_hits",
				"uid=$uid_q")->{$uid};
#			my $users_param = $self->sqlSelectAll(
#				"name, value", "users_param",
#				"uid=$uid_q");
#			my $users_acl = $self->sqlSelectColArrayref(
#				"acl", "users_acl",
#				"uid=$uid_q");
			for my $col (keys %$users_hits) {
				$answer->{$col} = $users_hits->{$col};
			}
#			for my $duple (@$users_param) {
#				$answer->{$duple->[0]} = $duple->[1];
#			}
#			for my $acl (@$users_acl) {
#				push @{$answer->{acl}}, $acl;
#			}
			$used_shortcut = 1;

		} else {

			for my $col (@{$gtd->{cols_needed_ar}}) {
				if (exists($rawmcdanswer->{$col})) {
					# This column we can pull from mcd.
					$mcdanswer->{$col} = $rawmcdanswer->{$col};
					# If we get anything from mcd, we should
					# get all the params data, so we no longer
					# need to get them later.
					$gtd->{all} = 0;
				} else {
					# This one we'll need from DB.
					push @$cols_still_need, $col;
				}
			}

			# Now whatever's left, we get from the DB.  If all went
			# well, this will just be the data from the users_hits
			# table (but we don't make that assumption, it works
			# the same whatever data was stored in memcached).
			if (@$cols_still_need) {
				my $table_hr = $self->_getUser_get_select_from_where(
					$uid_q, $cols_still_need);
				if ($mcddebug > 1) {
					print STDERR scalar(gmtime) . " $$ getUser still_need: '@$cols_still_need' table_hr: " . Dumper($table_hr);
				}
				$answer = $self->_getUser_do_selects(
					$uid_q,
					$table_hr->{select_clause},
					$table_hr->{from_clause},
					$table_hr->{where_clause},
					$gtd->{all} ? "all" : $table_hr->{params_needed});
			}

			# Now merge the memcached and DB data.
			for my $col (keys %$answer) {
				$mcdanswer->{$col} = $answer->{$col};
			}
			$answer = $mcdanswer;

		}

		if ($mcddebug > 1) {
			print STDERR scalar(gmtime) . " $$ getUser hit, won't write_memcached\n";
		}

	} else {

		# Turns out we have to go to the DB for everything.
		# Fortunately, the info we need to select it all has
		# been precalculated and cached for us.
		# We're doing an optimization here for the common case
		# of an empty $val.  If we're being asked for everything
		# about the user, select_clause will contain a list of
		# every column, but it will be faster to just ask the DB
		# for "*".
		if ($mcddebug > 1) {
			print STDERR scalar(gmtime) . " $$ getUser miss, about to select: val '$val' all '$gtd->{all}' can '$gtd->{can_use_mcd}'\n";
		}
		$answer = $self->_getUser_do_selects(
			$uid_q,
			($val ? $gtd->{select_clause} : "*"),
			$gtd->{from_clause},
			$gtd->{where_clause},
			$gtd->{all} ? "all" : $gtd->{params_needed});

		# If we just got all the data for the user, and
		# memcached is active, write it into the cache.
		if ($mcddebug > 2) {
			print STDERR scalar(gmtime) . " $$ getUser val '$val' all '$gtd->{all}' c_u_m '$gtd->{can_use_mcd}' answer: " . Dumper($answer);
		}
		if (!$val && $gtd->{all} && $gtd->{can_use_mcd}) {
			# This method overwrites $answer, notably it
			# deletes the /^hits/ keys.  So make a copy
			# to pass to it.
			my %answer_copy = %$answer;
			$self->_getUser_write_memcached(\%answer_copy);
		}

	}

	# If no such user, we can return now.
	# 2004/04/02 - we're seeing this message a lot, not sure why so much.
	# Adding more debug info to check - Jamie
	# I'm guessing it's the "com_num_X_at_or_after_cid" check.
	if (!$answer || !%$answer) {
		if ($mcddebug) {
			my $elapsed = sprintf("%6.4f", Time::HiRes::time - $start_time);
			my $rawdump = Dumper($rawmcdanswer); chomp $rawdump;
			print STDERR scalar(gmtime) . " $$ mcd getUser '$mcdkey$uid' elapsed=$elapsed no such user can '$gtd->{can_use_mcd}' rawmcdanswer: $rawdump val: " . Dumper($val);
		}
		return undef;
	}

	# Fill in the uid field.
	$answer->{uid} ||= $uid;

	if ($mcddebug > 2) {
		print STDERR scalar(gmtime) . " $$ getUser answer: " . Dumper($answer);
	}

	if (ref($val) eq 'ARRAY') {
		# Specific column(s) are needed.
		my $return_hr = { };
		for my $col (@$val) {
			$return_hr->{$col} = $answer->{$col};
		}
		$answer = $return_hr;
	} elsif ($val) {
		# Exactly one specific column is needed.
		$answer = $answer->{$val};
	}

	if ($mcddebug) {
		my $elapsed = sprintf("%6.4f", Time::HiRes::time - $start_time);
		if (defined($mcdanswer) || $used_shortcut) {
			print STDERR scalar(gmtime) . " $$ mcd getUser '$mcdkey$uid' elapsed=$elapsed cache HIT" . ($used_shortcut ? " shortcut" : "") . "\n";;
		} else {
			print STDERR scalar(gmtime) . " $$ mcd getUser '$mcdkey$uid' elapsed=$elapsed cache MISS can '$gtd->{can_use_mcd}' rawmcdanswer: " . Dumper($rawmcdanswer);
		}
	}

	return $answer;
}

#
# _getUser_do_selects
#

sub _getUser_do_selects {
	my($self, $uid_q, $select, $from, $where, $params) = @_;
	my $mcd = $self->getMCD();
	my $constants = getCurrentStatic();
	my $mcddebug = $mcd && $constants->{memcached_debug};

	# Here's the big select, the one that does something like:
	# SELECT foo, bar, baz FROM users, users_blurb, users_snork
	# WHERE users.uid=123 AND users_blurb.uid=123 AND so on.
	# Note if we're being asked to get only params, we skip this.
	my $answer = { };
	if ($mcddebug > 1) {
		print STDERR scalar(gmtime) . " $$ mcd gU_ds selecthashref: '$select' '$from' '$where'\n";
	}
	$answer = $self->sqlSelectHashref($select, $from, $where) if $select && $from && $where;
	if ($mcddebug > 1) {
		print STDERR scalar(gmtime) . " $$ mcd gU_ds got answer '$select' '$from' '$where'\n";
	}

	# Now get the params and the ACLs.  In the special case
	# where we are being asked to get "all" params (not an
	# arrayref of specific params), we also get the ACLs too.
	my $param_ar = [ ];
	if ($params eq "all") {
		# ...we could rewrite this to use sqlSelectAllKeyValue,
		# if we wanted...
		$param_ar = $self->sqlSelectAllHashrefArray(
			"name, value",
			"users_param",
			"uid = $uid_q");
		if ($mcddebug > 1) {
			print STDERR scalar(gmtime) . " $$ mcd gU_ds got all params\n";
		}
		my $acl_ar = $self->sqlSelectColArrayref(
			"acl",
			"users_acl",
			"uid = $uid_q");
		for my $acl (@$acl_ar) {
			$answer->{acl}{$acl} = 1;
		}
		if ($mcddebug > 1) {
			print STDERR scalar(gmtime) . " $$ mcd gU_ds got all " . scalar(@$acl_ar) . " acls\n";
		}
	} elsif (ref($params) eq 'ARRAY' && @$params) {
		my $param_list = join(",", map { $self->sqlQuote($_) } @$params);
		# ...we could rewrite this to use sqlSelectAllKeyValue,
		# if we wanted...
		$param_ar = $self->sqlSelectAllHashrefArray(
			"name, value",
			"users_param",
			"uid = $uid_q AND name IN ($param_list)");
		if ($mcddebug > 1) {
			print STDERR scalar(gmtime) . " $$ mcd gU_ds got specific params '@$params'\n";
		}
	}
	for my $hr (@$param_ar) {
		$answer->{$hr->{name}} = $hr->{value};
	}
	if ($mcddebug > 1) {
		print STDERR scalar(gmtime) . " $$ mcd gU_ds " . scalar(@$param_ar) . " params added to answer, keys now: '" . join(" ", sort keys %$answer) . "'\n";
	}

	# We have a bit of cleanup to do before returning;
	# thaw the people element, and clean up possibly broken
	# exsect/exaid/extid.
	for my $key (qw( exaid extid exsect )) {
		next unless $answer->{$key};
		$answer->{$key} =~ s/,'[^']+$//;
		$answer->{$key} =~ s/,'?$//;
	}
	if ($mcddebug > 1) {
		print STDERR scalar(gmtime) . " $$ mcd gU_ds answer ex-keys done\n";
	}
	if ($answer->{people}) {
		$answer->{people} = thaw($answer->{people});
		if ($mcddebug > 1) {
			print STDERR scalar(gmtime) . " $$ mcd gU_ds answer people thawed\n";
		}
	}

	return $answer;
}

#
# _getUser_compare_mcd_db
#

sub _getUser_compare_mcd_db {
	my($self, $uid_q, $answer, $mcdanswer) = @_;
	my $constants = getCurrentStatic();

	my $errtext = "";

	local $Data::Dumper::Sortkeys = 1;
	my %union_keys = map { ($_, 1) } (keys %$answer, keys %$mcdanswer);
	my @union_keys = sort grep !/^-/, keys %union_keys;
	for my $key (@union_keys) {
		my $equal = 0;
		my($db_an_dumped, $mcd_an_dumped);
		if (!ref($answer->{$key}) && !ref($mcdanswer->{$key})) {
			if ($answer->{$key} eq $mcdanswer->{$key}) {
				$equal = 1;
			} else {
				$db_an_dumped = "'$answer->{$key}'";
				$mcd_an_dumped = "'$mcdanswer->{$key}'";
			}
		} else {
			$db_an_dumped = Dumper($answer->{$key});	$db_an_dumped =~ s/\s+/ /g;
			$mcd_an_dumped = Dumper($mcdanswer->{$key});	$mcd_an_dumped =~ s/\s+/ /g;
			$equal = 1 if $db_an_dumped eq $mcd_an_dumped;
		}
		if (!$equal) {
			$errtext .= "\tKEY '$key' DB:  $db_an_dumped\n";
			$errtext .= "\tKEY '$key' MCD: $mcd_an_dumped\n";
		}
	}

	if ($errtext) {
		$errtext = scalar(gmtime) . " $$ getUser mcd diff on uid $uid_q:"
			. "\n$errtext";
		print STDERR $errtext;
	}
}

########################################################
#
# Begin closure.  This is OK to use these variables to store the
# caches, instead of getCurrentCache(), because all sites running
# on a given webhead are running the same code and so need to be
# at the same version of Slash.  The only way this cached data could
# differ between different sites being served by the same webhead,
# is if they are at different versions (and if the users_* schema
# changed between those versions).
{

my %gsfwcache = ( );
my %gtdcache = ( );
my $all_users_tables = [ qw(
	users		users_comments		users_index
	users_info	users_prefs		users_hits	) ];
my $users_hits_colnames;

#
# _getUser_get_select_from_where
#
# Given a list of needed columns, return the SELECT clause,
# FROM clause, and WHERE clause necessary to hit the DB to
# get them.

sub _getUser_get_select_from_where {
	my($self, $uid_q, $cols_needed) = @_;
	my $cols_needed_sorted = [ sort @$cols_needed ];
	my $gsfwcachekey = join("|", @$cols_needed_sorted);

	my $mcd = $self->getMCD();
	my $constants = getCurrentStatic();
	my $mcddebug = $mcd && $constants->{memcached_debug};

	if ($mcddebug > 1) {
		print STDERR scalar(gmtime) . " $$ gU_gsfw uid $uid_q cols '@$cols_needed_sorted' def=" . (defined($gsfwcache{$gsfwcachekey}) ? 1 : 0) . "\n";
	}
	if (!defined($gsfwcache{$gsfwcachekey})) {
		my $cache_name = _genericGetCacheName($self, $all_users_tables);

		if ($mcddebug > 1) {
			print STDERR scalar(gmtime) . " $$ gU_gsfw cache_name '$cache_name'\n";
		}

		# Need to figure out which tables we need, based on
		# which cols we need (and we already know that).
		# In earlier versions of this code, we stripped
		# a "-" prefix from the keys passed in, but "-col"
		# should never be passed to getUser, only setUser,
		# so we don't have to do that.
		my %need_table = ( );
		my $params_needed = [ ];
		if ($mcddebug > 2) {
			print STDERR scalar(gmtime) . " $$ gU_gsfw cache name '$cache_name' cache: " . Dumper($self->{$cache_name});
		}
		my $cols_main_needed_sorted = [ ];
		for my $col (@$cols_needed_sorted) {
			if ($mcddebug > 1) {
				print STDERR scalar(gmtime) . " $$ gU_gsfw col '$col' table '$self->{$cache_name}{$col}'\n";
			}
			if (my $table_name = $self->{$cache_name}{$col}) {
				$need_table{$table_name} = 1;
				push @$cols_main_needed_sorted, $col;
			} else {
				push @$params_needed, $col;
			}
		}
		my $tables_needed = [ sort keys %need_table ];

		# Determine the FROM clause (comma-separated tables) and the
		# WHERE clause (AND users_foo.uid=) to pull data from the DB.
		my $select_clause = join(",", grep { $_ ne 'uid' } @$cols_main_needed_sorted);
		my $from_clause = join(",", @$tables_needed);

		$gsfwcache{$gsfwcachekey} = {
			tables_needed =>	$tables_needed,
			select_clause =>	$select_clause,
			from_clause =>		$from_clause,
			params_needed =>	$params_needed,
		};
		if ($mcddebug > 2) {
			print STDERR scalar(gmtime) . " $$ gU_gsfw cache_name '$cache_name' gsfwcache: " . Dumper($gsfwcache{$gsfwcachekey});
		}
	}
	my $return_hr = $gsfwcache{$gsfwcachekey};
	$return_hr->{where_clause} = "("
		. join(" AND ",
			map { "$_.uid=$uid_q" } @{$return_hr->{tables_needed}}
		  )
		. ")";
	return $return_hr;
}

#
# _getUser_get_table_data
#

sub _getUser_get_table_data {
	my($self, $uid_q, $val) = @_;
	my $constants = getCurrentStatic();
	my $mcd = $self->getMCD();
	my $mcddebug = $mcd && $constants->{memcached_debug};
	my $cache_name = _genericGetCacheName($self, $all_users_tables);

	my $gtdcachekey;
	my $tables_needed;
	my $cols_needed;

	# First, normalize the list of columns we need.
	if (ref($val) eq 'ARRAY') {
		# Specific column(s) are needed.
		$cols_needed = $val;
	} elsif ($val) {
		# Exactly one specific column is needed.
		$cols_needed = [ $val ];
	} else {
		# All columns are needed.  Special case of gtdcachekey.
		$gtdcachekey = "__ALL__";
		# And we only need to do this processing if this case
		# is not in the cache yet.
		if (!$gtdcache{$gtdcachekey}) {
			$cols_needed = [ sort keys %{$self->{$cache_name}} ];
			$tables_needed = $all_users_tables;
		}
	}

	if ($mcddebug > 1) {
		print STDERR scalar(gmtime) . " $$ _getU_gtd gtdcachekey '$gtdcachekey' cols_needed: " . ($cols_needed ? "'@$cols_needed'" : "(all)") . " for val:" . Dumper($val);
	}

	# Now, check to see if we know all the answers for that exact
	# list.  If so, we can skip some processing.
	$gtdcachekey ||= join("|", @$cols_needed);
	if (!$gtdcache{$gtdcachekey}) {
		my $params_needed = [ ];
		my $where;
		my $table_list;
		my %need_table = ( );

		my $table_hr = $self->_getUser_get_select_from_where(
			$uid_q, $cols_needed);
		$tables_needed = $table_hr->{tables_needed}
			if !$tables_needed || !@$tables_needed;

		# Determine whether we need data from memcached, or the DB,
		# or both.
		my($can_use_mcd, $need_db);
		if (!$mcd) {
			$need_db = 1; $can_use_mcd = 0;
		} else {
			if (grep { $_ eq 'users_hits' } @$tables_needed) {
				$need_db = 1;
			}
			if (grep { $_ ne 'users_hits' } @$tables_needed) {
				$can_use_mcd = 1;
			}
		}

		# We've got the data, now write it into the cache;  we'll
		# return it in a moment.
		my $hr = $gtdcache{$gtdcachekey} = { };
		$hr->{tables_needed_ar} =	$tables_needed;
		$hr->{tables_needed_hr} =	{ map { $_, 1 }
						      @$tables_needed };
		$hr->{cols_needed_ar} =		$cols_needed;
		$hr->{cols_needed_hr} =		{ map { $_, $self->{$cache_name}{$_} }
						      @$cols_needed };
		$hr->{params_needed} =		$table_hr->{params_needed};
		$hr->{select_clause} =		$table_hr->{select_clause};
		$hr->{from_clause} =		$table_hr->{from_clause};
		$hr->{need_db} =		$need_db;
		$hr->{can_use_mcd} =		$can_use_mcd;
	}

	my $return_hr = $gtdcache{$gtdcachekey};
	$return_hr->{where_clause} = "("
		. join(" AND ",
			map { "$_.uid=$uid_q" } @{$return_hr->{tables_needed_ar}}
		  )
		. ")";

	$return_hr->{all} = 1 if $gtdcachekey eq '__ALL__';

	if ($mcddebug > 1) {
		print STDERR scalar(gmtime) . " $$ _getU_gtd returning: " . Dumper($return_hr);
	}

	return $return_hr;
}

#
# _getUser_write_memcached
#

sub _getUser_write_memcached {
	my($self, $userdata) = @_;
	my $uid = $userdata->{uid};
	return unless $uid;
	my $mcd = getMCD();
	return unless $mcd;
	my $constants = getCurrentStatic();
	my $mcddebug = $mcd && $constants->{memcached_debug};

	# We don't write users_hits data into memcached.  Strip those
	# columns out.
	if (!$users_hits_colnames || !@$users_hits_colnames) {
		my $cache_name = _genericGetCacheName($self, $all_users_tables);
		$users_hits_colnames = [ ];
		for my $col (keys %{$self->{$cache_name}}) {
			push @$users_hits_colnames, $col
				if $self->{$cache_name}{$col} eq 'users_hits';
		}
	}
	for my $col (@$users_hits_colnames) {
		delete $userdata->{$col};
	}
	if ($mcddebug > 2) {
		print STDERR scalar(gmtime) . " $$ _getU_writemcd users_hits_colnames '@$users_hits_colnames' userdata: " . Dumper($userdata);
	}

	my $mcdkey = "$self->{_mcd_keyprefix}:u:";

	my $exptime = $constants->{memcached_exptime_user};
	$exptime = 1200 if !defined($exptime);
	$mcd->set("$mcdkey$uid", $userdata, $exptime);

	if ($mcddebug > 2) {
		print STDERR scalar(gmtime) . " $$ _getU_writemcd wrote to '$mcdkey$uid' exptime '$exptime': " . Dumper($userdata);
	}
}

}
# end closure
#
########################################################


########################################################
# This could be optimized by not making multiple calls
# to getKeys or by fixing getKeys() to return multiple
# values
sub _genericGetCacheName {
	my($self, $tables) = @_;
	my $cache;

	if (ref($tables) eq 'ARRAY') {
		$cache = '_' . join ('_', sort(@$tables), 'cache_tables_keys');
		unless (keys %{$self->{$cache}}) {
			for my $table (@$tables) {
				my $keys = $self->getKeys($table) || [ ];
				for (@$keys) {
					$self->{$cache}{$_} = $table;
				}
			}
		}
	} else {
		$cache = '_' . $tables . 'cache_tables_keys';
		unless (keys %{$self->{$cache}}) {
			my $keys = $self->getKeys($tables) || [ ];
			for (@$keys) {
				$self->{$cache}{$_} = $tables;
			}
		}
	}
	return $cache;
}

########################################################
# Now here is the thing. We want setUser to look like
# a generic, despite the fact that it is not :)
# We assum most people called set to hit the database
# and just not the cache (if one even exists)
sub _genericSet {
	my($table, $table_prime, $param_table, $self, $id, $value) = @_;

	my $ok;
	if ($param_table) {
		my $cache = _genericGetCacheName($self, $table);

		my(@param, %updates);
		for (keys %$value) {
			(my $clean_val = $_) =~ s/^-//;
			my $key = $self->{$cache}{$clean_val};
			if ($key) {
				$updates{$_} = $value->{$_};
			} else {
				push @param, [$_, $value->{$_}];
			}
		}
		$self->sqlUpdate($table, \%updates, $table_prime . '=' . $self->sqlQuote($id))
			if keys %updates;
		# What is worse, a select+update or a replace?
		# I should look into that. if EXISTS() the
		# need for a fully sql92 database.
		# transactions baby, transactions... -Brian
		for (@param)  {
			$self->sqlReplace($param_table,
				{ $table_prime => $id, name => $_->[0], value => $_->[1] });
		}
	} else {
		$ok = $self->sqlUpdate($table, $value, $table_prime . '=' . $self->sqlQuote($id));
	}

	my $table_cache = '_' . $table . '_cache';
	return $ok unless keys %{$self->{$table_cache}}
		       && keys %{$self->{$table_cache}{$id}};

	my $table_cache_time = '_' . $table . '_cache_time';
	$self->{$table_cache_time} = time();
	for (keys %$value) {
		$self->{$table_cache}{$id}{$_} = $value->{$_};
	}
	$self->{$table_cache}{$id}{'_modtime'} = time();

	return $ok;
}

########################################################
# You can use this to reset caches in a timely manner :)
sub _genericCacheRefresh {
	my($self, $table, $expiration) = @_;
	my $debug = getCurrentStatic('debug_db_cache');
	if (!$expiration) {
		if ($debug) {
			print STDERR scalar(gmtime) . " pid $$ _gCR table='$table' expiration false (never expire), no refresh\n";
		}
		return;
	}
	my $table_cache = '_' . $table . '_cache';
	my $table_cache_time = '_' . $table . '_cache_time';
	my $table_cache_full = '_' . $table . '_cache_full';
	if (!$self->{$table_cache_time}) {
		if ($debug) {
			print STDERR scalar(gmtime) . " pid $$ _gCR table='$table' expiration='$expiration'"
				. " self->$table_cache_time false, no refresh\n";
		}
		return;
	}
	my $time = time();
	my $diff = $time - $self->{$table_cache_time};

	if ($diff > $expiration) {
		if ($debug) {
			print STDERR scalar(gmtime) . " pid $$ _gCR EXPIRING table='$table' expiration='$expiration'"
				. " time='$time' diff='$diff' self->${table}_cache_time='$self->{$table_cache_time}'\n";
		}
		$self->{$table_cache} = {};
		$self->{$table_cache_time} = 0;
		$self->{$table_cache_full} = 0;
	} elsif ($debug) {
		print STDERR scalar(gmtime) . " pid $$ _gCR NOT_EXPIRING table='$table' expiration='$expiration'"
			. " time='$time' diff='$diff' self->${table}_cache_time='$self->{$table_cache_time}'\n";
	}
}

########################################################
# This is protected and don't call it from your
# scripts directly.
sub _genericGetCache {
	return _genericGet(@_) unless getCurrentStatic('cache_enabled');
	my($passed) = @_;
	my $table = $passed->{'table'};
	my $table_prime = $passed->{'table_prime'} || 'id';
	my $param_table = $passed->{'param_table'};
	my($self, $id, $values, $cache_flag) = @{$passed->{'arguments'}};

	my $table_cache = '_' . $table . '_cache';
	my $table_cache_time= '_' . $table . '_cache_time';

	my $type;
	if (ref($values) eq 'ARRAY') {
		$type = 0;
	} else {
		$type  = $values ? 1 : 0;
	}

	# If the value(s) wanted is (are) in that table's cache, and
	# the cache_flag is not set to true (meaning "don't use cache"),
	# then return the cached value now.
	if (keys %{$self->{$table_cache}{$id}} && !$cache_flag) {
		if ($type) {
			return $self->{$table_cache}{$id}{$values};
		} else {
			my %return = %{$self->{$table_cache}{$id}};
			return \%return;
		}
	}

	$self->{$table_cache}{$id} = {};
	$passed->{'arguments'} = [$self, $id];
	my $answer = _genericGet($passed);
	$answer->{'_modtime'} = time();
	$self->{$table_cache}{$id} = $answer;
	$self->{$table_cache_time} = time();

	if ($type) {
		return $self->{$table_cache}{$id}{$values};
	} else {
		if ($self->{$table_cache}{$id}) {
			my %return = %{$self->{$table_cache}{$id}};
			return \%return;
		} else {
			return;
		}
	}
}

########################################################
# This is protected and don't call it from your
# scripts directly.
sub _genericClearCache {
	my($table, $self) = @_;
	my $table_cache= '_' . $table . '_cache';

	$self->{$table_cache} = {};
}

########################################################
# This is protected and don't call it from your
# scripts directly.
sub _genericGet {
	my($passed) = @_;
	my $table = $passed->{'table'};
	my $table_prime = $passed->{'table_prime'} || 'id';
	my $param_table = $passed->{'param_table'};
#	my $col_table = $passed->{'col_table'};
	my($self, $id, $val) = @{$passed->{'arguments'}};
	my($answer, $type);
	my $id_db = $self->sqlQuote($id);

	if ($param_table) {
	# With Param table
		if (ref($val) eq 'ARRAY') {
			my $cache = _genericGetCacheName($self, $table);

			my($values, @param);
			for (@$val) {
				(my $clean_val = $_) =~ s/^-//;
				if ($self->{$cache}{$clean_val}) {
					$values .= "$_,";
				} else {
					push @param, $_;
				}
			}
			chop($values);

			$answer = $self->sqlSelectHashref($values, $table, "$table_prime=$id_db");
			for (@param) {
				my $val = $self->sqlSelect('value', $param_table, "$table_prime=$id_db AND name='$_'");
				$answer->{$_} = $val;
			}

		} elsif ($val) {
			my $cache = _genericGetCacheName($self, $table);
			(my $clean_val = $val) =~ s/^-//;
			my $table = $self->{$cache}{$clean_val};
			if ($table) {
				($answer) = $self->sqlSelect($val, $table, "uid=$id");
			} else {
				($answer) = $self->sqlSelect('value', $param_table, "$table_prime=$id_db AND name='$val'");
			}

		} else {
			$answer = $self->sqlSelectHashref('*', $table, "$table_prime=$id_db");
			my $append = $self->sqlSelectAllKeyValue('name,value',
				$param_table, "$table_prime=$id_db");
			for my $key (keys %$append) {
				$answer->{$key} = $append->{$key};
			}
#			$answer->{$col_table->{label}} = $self->sqlSelectColArrayref($col_table->{key}, $col_table->{table}, "$col_table->{table_index}=$id_db")  
#				if $col_table;
		}
	} else {
	# Without Param table
		if (ref($val) eq 'ARRAY') {
			my $values = join ',', @$val;
			$answer = $self->sqlSelectHashref($values, $table, "$table_prime=$id_db");
		} elsif ($val) {
			($answer) = $self->sqlSelect($val, $table, "$table_prime=$id_db");
		} else {
			$answer = $self->sqlSelectHashref('*', $table, "$table_prime=$id_db");
#			$answer->{$col_table->{label}} = $self->sqlSelectColArrayref($col_table->{key}, $col_table->{table}, "$col_table->{table_index}=$id_db")  
#				if $col_table;
		}
	}


	return $answer;
}

########################################################
# This is protected and don't call it from your
# scripts directly.
sub _genericGetsCache {
	return _genericGets(@_) unless getCurrentStatic('cache_enabled');

	my($table, $table_prime, $param_table, $self, $cache_flag) = @_;
	my $table_cache = '_' . $table . '_cache';
	my $table_cache_time = '_' . $table . '_cache_time';
	my $table_cache_full = '_' . $table . '_cache_full';

	if (keys %{$self->{$table_cache}} && $self->{$table_cache_full} && !$cache_flag) {
		my %return = %{$self->{$table_cache}};
		return \%return;
	}

	# Lets go knock on the door of the database
	# and grab the data since it is not cached
	# On a side note, I hate grabbing "*" from a database
	# -Brian
	$self->{$table_cache} = {};
	$self->{$table_cache} = _genericGets($table, $table_prime, $param_table, $self);
	$self->{$table_cache_full} = 1;
	$self->{$table_cache_time} = time();

	my %return = %{$self->{$table_cache}};
	return \%return;
}

########################################################
# This is protected and don't call it from your
# scripts directly.
sub _genericGets {
	my($table, $table_prime, $param_table, $self, $values) = @_;
	my(%return, $sth, $params, $qlid);

	if (ref($values) eq 'ARRAY') {
		my $get_values;

		if ($param_table) {
			my $cache = _genericGetCacheName($self, $table);
			for (@$values) {
				(my $clean_val = $_) =~ s/^-//;
				if ($self->{$cache}{$clean_val}) {
					push @$get_values, $_;
				} else {
					my $val = $self->sqlSelectAll("$table_prime, name, value",
						$param_table, "name='$_'");
					for my $row (@$val) {
						push @$params, $row;
					}
				}
			}
		} else {
			$get_values = $values;
		}
		if ($get_values) {
			my $val = join ',', @$get_values;
			$val .= ",$table_prime" unless grep $table_prime, @$get_values;
			$qlid = $self->_querylog_start('SELECT', $table);
			$sth = $self->sqlSelectMany($val, $table);
		}
	} elsif ($values) {
		if ($param_table) {
			my $cache = _genericGetCacheName($self, $table);
			(my $clean_val = $values) =~ s/^-//;
			my $use_table = $self->{$cache}{$clean_val};

			if ($use_table) {
				$values .= ",$table_prime" unless $values eq $table_prime;
				$qlid = $self->_querylog_start('SELECT', $table);
				$sth = $self->sqlSelectMany($values, $table);
			} else {
				my $val = $self->sqlSelectAll("$table_prime, name, value",
					$param_table, "name=$values");
				for my $row (@$val) {
					push @$params, $row;
				}
			}
		} else {
			$values .= ",$table_prime" unless $values eq $table_prime;
			$qlid = $self->_querylog_start('SELECT', $table);
			$sth = $self->sqlSelectMany($values, $table);
		}
	} else {
		if ($param_table) {
			$params = $self->sqlSelectAll("$table_prime, name, value", $param_table);
		}
		$qlid = $self->_querylog_start('SELECT', $table);
		$sth = $self->sqlSelectMany('*', $table);
	}

	if ($sth) {
		while (my $row = $sth->fetchrow_hashref) {
			$return{ $row->{$table_prime} } = $row;
		}
		$sth->finish;
		$self->_querylog_finish($qlid);
	}

	if ($params) {
		for (@$params) {
			$return{$_->[0]}{$_->[1]} = $_->[2]
		}
	}

	return \%return;
}

########################################################
# This is only called by Slash/DB/t/story.t and it doesn't even serve much purpose
# there...I assume we can kill it?  - Jamie
# Actually, we should keep it around since it is a generic method -Brian
# I am using it for something on OSDN.com -- pudge
sub getStories {
	my $answer = _genericGets('stories', 'sid', 'story_param', @_);
	return $answer;
}

########################################################
sub getRelatedLinks {
	my $answer = _genericGets('related_links', 'id', '', @_);
	return $answer;
}

########################################################
sub getHooksByParam {
	my($self, $param) = @_;
	my $answer = $self->sqlSelectAllHashrefArray('*', 'hooks', 'param =' . $self->sqlQuote($param) );
	return $answer;
}

########################################################
sub getHook {
	my $answer = _genericGet({
		table		=> 'hooks',
		arguments	=> \@_,
	});
	return $answer;
}

########################################################
sub createHook {
	my($self, $hash) = @_;

	$self->sqlInsert('hooks', $hash);
}

########################################################
sub deleteHook {
	my($self, $id) = @_;

	$self->sqlDelete('hooks', 'id =' . $self->sqlQuote($id));  
}

########################################################
sub setHook {
	my($self, $id, $value) = @_;
	$self->sqlUpdate('hooks', $value, 'id=' . $self->sqlQuote($id));
}

########################################################
sub getSessions {
	my $answer = _genericGets('sessions', 'session', '', @_);
	return $answer;
}

########################################################
sub createBlock {
	my($self, $hash) = @_;
	$self->sqlInsert('blocks', $hash);

	return $hash->{bid};
}

########################################################
sub createRelatedLink {
	my($self, $hash) = @_;
	$self->sqlInsert('related_links', $hash);
}

########################################################
sub createTemplate {
	my($self, $hash) = @_;
	for (qw| page name skin |) {
		next unless $hash->{$_};
		if ($hash->{$_} =~ /;/) {
			errorLog("Semicolon found, $_='$hash->{$_}', createTemplate aborted");
			return;
		}
	}
	# Debugging while we transition section-topics.
	if ($hash->{section}) {
		errorLog("section passed to createTemplate, not skin");
		die "section passed to createTemplate, not skin";
	}
	# Instructions field does not get passed to the DB.
	delete $hash->{instructions};
	# Neither does the version field (for now).
	delete $hash->{version};

	$self->sqlInsert('templates', $hash);
	my $tpid = $self->getLastInsertId({ table => 'templates', prime => 'tpid' });
	return $tpid;
}

########################################################
sub createMenuItem {
	my($self, $hash) = @_;
	$self->sqlInsert('menus', $hash);
}

########################################################
# It'd be faster for getMenus() to just "SELECT *" and parse
# the results into a perl hash, than to "SELECT DISTINCT" and
# then make separate calls to getMenuItems. XXX - Jamie
sub getMenuItems {
	my($self, $script) = @_;
	return $self->sqlSelectAllHashrefArray('*', 'menus', "page=" . $self->sqlQuote($script) , " ORDER by menuorder");
}

########################################################
sub getMiscUserOpts {
	my($self) = @_;

	my $user_seclev = getCurrentUser('seclev') || 0;
	my $hr = $self->sqlSelectAllHashref("name", "*", "misc_user_opts",
		"seclev <= $user_seclev");
	my $ar = [ ];
	for my $row (
		sort { $hr->{$a}{optorder} <=> $hr->{$b}{optorder} } keys %$hr
	) {
		push @$ar, $hr->{$row};
	}
	return $ar;
}

########################################################
sub getMenus {
	my($self) = @_;

	my $menu_names = $self->sqlSelectAll("DISTINCT menu", "menus", '', "ORDER BY menu");

	my $menus;
	for (@$menu_names) {
		my $script = $_->[0];
		my $menu = $self->sqlSelectAllHashrefArray('*', "menus", "menu=" . $self->sqlQuote($script), 'ORDER by menuorder');
		$menus->{$script} = $menu;
	}

	return $menus;
}

########################################################
sub sqlReplace {
	my($self, $table, $data) = @_;
	my($names, $values);
 
	for (keys %$data) {
		if (/^-/) {
			$values .= "\n  $data->{$_},";
			s/^-//;
		} else {
			$values .= "\n  " . $self->sqlQuote($data->{$_}) . ',';
		}
		$names .= "$_,";
	}
 
	chop($names);
	chop($values);
 
	my $sql = "REPLACE INTO $table ($names) VALUES($values)\n";
	$self->sqlConnect();
	my $qlid = $self->_querylog_start('REPLACE', $table);
	my $rows = $self->sqlDo($sql);
	$self->_querylog_finish($qlid);
	errorLog($sql) if !$rows;
	return $rows;
}

##################################################################
# This should be rewritten so that at no point do we
# pass along an array -Brian
sub getKeys {
	my($self, $table) = @_;
	my $keys = $self->sqlSelectColumns($table)
		if $self->sqlTableExists($table);

	return $keys;
}

########################################################
sub sqlTableExists {
	my($self, $table) = @_;
	return unless $table;

	$self->sqlConnect() or return undef;
	my $tab = $self->{_dbh}->selectrow_array(qq!SHOW TABLES LIKE "$table"!);

	return $tab;
}

########################################################
sub sqlSelectColumns {
	my($self, $table) = @_;
	return unless $table;

	$self->sqlConnect() or return undef;
	my $rows = $self->{_dbh}->selectcol_arrayref("SHOW COLUMNS FROM $table");
	return $rows;
}

########################################################
sub getRandomSpamArmor {
	my($self) = @_;

	my $ret = $self->sqlSelectAllHashref(
		'armor_id', '*', 'spamarmors', 'active=1'
	);
	my @armor_keys = keys %{$ret};

	# array index automatically int'd
	return $ret->{$armor_keys[rand($#armor_keys + 1)]};
}

########################################################
sub clearAccountVerifyNeededFlags {
	my($self, $uid) = @_;
	$self->setUser($uid, {
		waiting_for_account_verify 	=> "",
		account_verify_request_time 	=> "" 
	});
}

########################################################
sub sqlShowProcessList {
	my($self) = @_;

	$self->sqlConnect();
	my $proclist = $self->{_dbh}->prepare("SHOW FULL PROCESSLIST");

	return $proclist;
}

########################################################
sub sqlShowStatus {
	my($self) = @_;

	$self->sqlConnect();
	my $status = $self->{_dbh}->prepare("SHOW STATUS");

	return $status;
}

########################################################
sub sqlShowInnodbStatus {
	my($self) = @_;

	$self->sqlConnect();
	my $status = $self->{_dbh}->prepare("SHOW INNODB STATUS");

	return $status;
}

########################################################
# Get a unique string for an admin session
#sub generatesession {
#	# crypt() may be implemented differently so as to
#	# make the field in the db too short ... use the same
#	# MD5 encrypt function?  is this session thing used
#	# at all anymore?
#	my $newsid = crypt(rand(99999), $_[0]);
#	$newsid =~ s/[^A-Za-z0-9]//i;
#
#	return $newsid;
#}


########################################################
sub DESTROY {
	my($self) = @_;

	# Flush accesslog insert cache, if necessary.
	$self->_writeAccessLogCache;

	# Flush the querylog cache too, if necessary (see
	# Slash::DB::Utility).
	$self->_querylog_writecache;

	$self->SUPER::DESTROY if $self->can("SUPER::DESTROY"); # up up up up up up
}


1;

__END__

=head1 NAME

Slash::DB::MySQL - MySQL Interface for Slash

=head1 SYNOPSIS

	use Slash::DB::MySQL;

=head1 DESCRIPTION

This is the MySQL specific stuff. To get the real
docs look at Slash::DB.

=head1 SEE ALSO

Slash(3), Slash::DB(3).

=cut

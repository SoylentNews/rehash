# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
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
use vars qw($VERSION);
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

	'isolatemodes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='isolatemodes'") },

	'issuemodes'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='issuemodes'") },

	'vars'
		=> sub { $_[0]->sqlSelectMany('name,name', 'vars') },

	'topics'
		=> sub { $_[0]->sqlSelectMany('tid,alttext', 'topics') },

	'topic_images_section'
		=> sub { $_[0]->sqlSelectMany('concat(tid, "|", section), topic_image', 'topic_image_sections') },

	'topics_all'
		=> sub { $_[0]->sqlSelectMany('tid,alttext', 'topics') },

	'topics_section'
		=> sub {
				my $SECT = $_[0]->getSection($_[2]);
				my $where;
				if ($SECT->{type} eq 'collected') {
					$where = " section IN ('" . join("','", @{$SECT->{contained}}) . "')" 
						if $SECT->{contained} && @{$SECT->{contained}};
				} else {
					$where = " section = " . $_[0]->sqlQuote($SECT->{section});
				}
				$where .= " AND " if $where;
				$_[0]->sqlSelectMany('topics.tid,topics.alttext', 'topics, section_topics', "$where section_topics.tid=topics.tid") 
			},

	'topics_section_type'
		=> sub { $_[0]->sqlSelectMany('topics.tid as tid,topics.alttext as alttext', 'topics, section_topics', "section='$_[2]' AND section_topics.tid=topics.tid AND type= '$_[3]'") },

	'section_subsection'
		=> sub { $_[0]->sqlSelectMany('subsections.id, subsections.alttext', 'subsections, section_subsections', 'section_subsections.section=' . $_[0]->sqlQuote($_[2]) . ' AND subsections.id = section_subsections.subsection', 'ORDER BY alttext') },

	'section_subsection_names'
		=> sub { $_[0]->sqlSelectMany('title, id', 'subsections') },

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

	'sections'
		=> sub { $_[0]->sqlSelectMany('section,title', 'sections', 'type="contained"', 'order by title') },

	'sections-contained'
		=> sub { $_[0]->sqlSelectMany('section,title', 'sections', 'type="contained"', 'order by title') },

	'sections-all'
		=> sub { $_[0]->sqlSelectMany('section,title', 'sections', '', 'order by title') },

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

	'templatesbypage'
		=> sub { $_[0]->sqlSelectMany('tpid,name', 'templates', "page = '$_[2]'") },

	'templatesbysection'
		=> sub { $_[0]->sqlSelectMany('tpid,name', 'templates', "section = '$_[2]'") },

	'keywords'
		=> sub { $_[0]->sqlSelectMany('id,CONCAT(keyword, " - ", name)', 'related_links') },

	'pages'
		=> sub { $_[0]->sqlSelectMany('distinct page,page', 'templates') },

	'templatesections'
		=> sub { $_[0]->sqlSelectMany('distinct section, section', 'templates') },

	'sectionblocks'
		=> sub { $_[0]->sqlSelectMany('bid,title', 'blocks', 'portal=1') },

	'plugins'
		=> sub { $_[0]->sqlSelectMany('value,description', 'site_info', "name='plugin'") },

	'site_info'
		=> sub { $_[0]->sqlSelectMany('name,value', 'site_info', "name != 'plugin'") },

	'topic-sections'
		=> sub { $_[0]->sqlSelectMany('section,type', 'section_topics', "tid = '$_[2]'") },

	'forms'
		=> sub { $_[0]->sqlSelectMany('value,value', 'site_info', "name = 'form'") },

	'journal_discuss'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='journal_discuss'") },

	'section_extra_types'
		=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='extra_types'") },

	'section-types'
		=> sub { $_[0]->sqlSelectMany('code,name', 'string_param', "type='section_types'") },

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
	$self->{_storyBank} = {};
	$self->{_codeBank} = {};
	$self->{_sectionBank} = {};

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
sub createModeratorLog {
	my($self, $comment, $user, $val, $reason, $active, $points_spent) = @_;

	$active = 1 unless defined $active;
	$points_spent = 1 unless defined $points_spent;
	$self->sqlInsert("moderatorlog", {
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
	});
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
		if ($mod_hr->{discussions_sid}) {
			# This is a comment posted to a story discussion, so
			# we can link straight to the story, providing even
			# more context for this comment.
			$mod_hr->{url} = getCurrentStatic('rootdir')
				. "/article.pl?sid=$mod_hr->{discussions_sid}";
		} else {
			# This is a comment posted to a discussion that isn't
			# a story.  It could be attached to a poll, a journal
			# entry, or nothing at all (user-created discussion).
			# Whatever the case, we can't trust the url field, so
			# we should just link to the discussion itself.
			$mod_hr->{url} = getCurrentStatic('rootdir')
				. "/comments.pl?sid=$mod_hr->{sid}";
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

	my $reasons = $self->getReasons();
	my $m2able_reasons = join(",",
		sort grep { $reasons->{$_}{m2able} }
		keys %$reasons);
	return [ ] if !$m2able_reasons;

	my $consensus = $constants->{m2_consensus};
	my $waitpow = $constants->{m2_consensus_waitpow} || 1;

	my $days_back = $constants->{archive_delay_mod};
	my $days_back_cushion = int($days_back/10);
	$days_back_cushion = $constants->{m2_min_daysbackcushion} || 2
		if $days_back_cushion < ($constants->{m2_min_daysbackcushion} || 2);
	$days_back -= $days_back_cushion;

	# XXX I'm considering adding a 'WHERE m2status=0' clause to the
	# MIN/MAX selects below.  This might help choose mods more
	# smoothly and make failure (as archive_delay_mod is approached)
	# less dramatic too.  On the other hand it might screw things
	# up, making older mods at N-1 M2's never make it to N.  I've
	# run tests on changes like this before and there's almost no
	# way to predict accurately what it will do on a live site
	# without doing it... -Jamie 2002/11/16
	my $min_old = $self->getVar('m2_modlogid_min_old', 'value', 1) || 0;
	my $max_old = $self->getVar('m2_modlogid_max_old', 'value', 1) || 0;
	my $min_new = $self->getVar('m2_modlogid_min_new', 'value', 1) || 0;
	my $max_new = $self->getVar('m2_modlogid_max_new', 'value', 1) || 0;
	my $min_mid = $max_old+1;
	my $max_mid = $min_new-1;
	my $old_range = $max_old-$min_old; $old_range = 1 if $old_range < 1;
	my $mid_range = $max_mid-$min_mid; $mid_range = 1 if $mid_range < 1;
	my $new_range = $max_new-$min_new; $new_range = 1 if $new_range < 1;

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
	my $range_offset = 0.9;
	$range_offset = $constants->{m2_range_offset}
		if defined($constants->{m2_range_offset});
	my $twice_range_offset = $range_offset * 2;
	my $if_expr = "";
	if ($waitpow != 1) {
		$if_expr = <<EOT;
			IF(	id BETWEEN $min_old AND $max_mid,
				IF(
					id BETWEEN $min_old and $max_old,
					POW(         (id-$min_old)/$old_range,     $waitpow),
					POW(GREATEST((id-$min_mid)/$mid_range, 0), $waitpow)
						+ $range_offset
				),
				POW(GREATEST((id-$min_new)/$new_range, 0), $waitpow)
					+ $twice_range_offset			)
EOT
	} else {
		$if_expr = <<EOT;
			IF(	id BETWEEN $min_old AND $max_mid,
				IF(
					id BETWEEN $min_old and $max_old,
					(id-$min_old)/$old_range,
					(id-$min_mid)/$mid_range
						+ $range_offset
				),
				(id-$min_new)/$new_range
					+ $twice_range_offset			)
EOT
	}
	GETMODS: while ($num_needed > 0 && ++$getmods_loops <= 3) {
		my $limit = $num_needed*2+10; # get more, hope it's enough
		my $already_id_clause = "";
		$already_id_clause  = " AND  id NOT IN ($already_id_list)"
			if $already_id_list;
		my $already_cid_clause = "";
		$already_cid_clause = " AND cid NOT IN ($already_cid_list)"
			if $already_cid_list;
		$mod_hr = { };
		$mod_hr = $reader->sqlSelectAllHashref(
			"id",
			"id, cid,
			 m2count + $consensus * $if_expr + RAND() AS rank",
			"moderatorlog",
			"uid != $uid_q AND cuid != $uid_q
			 AND m2status=0
			 AND reason IN ($m2able_reasons)
			 AND active=1
			 $already_id_clause $already_cid_clause",
			"ORDER BY rank LIMIT $limit"
		);
		last GETMODS if !$mod_hr || !scalar(keys %$mod_hr);

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
		$#new_ids = $num_needed-1 if $#new_ids > $num_needed-1;
		push @ids, @new_ids;
		$num_needed -= scalar(@new_ids);
	}
	if ($getmods_loops > 3) {
		print STDERR "GETMODS looped the max number of times,"
			. " returning '@ids' for uid '$uid'"
			. " num_needed '$num_needed'"
			. " (maybe out of mods to M2?)"
			. " already_had: " . Dumper($already_have_hr);
	}

	return \@ids;
}

########################################################
# ok, I was tired of trying to mold getDescriptions into 
# taking more args.
sub getTemplateList {
	my($self, $section, $page) = @_;

	my $templatelist = {};
	my $where = "seclev <= " . getCurrentUser('seclev');
	$where .= " AND section = '$section'" if $section;
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
	my($self, $asc_desc, $limit, $type, $value, $options) = @_;
	$options ||= {};
	$asc_desc ||= 'ASC';
	$asc_desc = uc $asc_desc;
	$asc_desc = 'ASC' if $asc_desc ne 'DESC';

	if ($limit and $limit =~ /^(\d+)$/) {
		$limit = "LIMIT $1";
	} else {
		$limit = "";
	}

	my $select_extra = (($type =~ /ipid/) || ($type =~ /subnetid/) || ($type =~ /global/)) ? ", comments.uid as uid2, comments.ipid as ipid2" : "";

	my $vq = $self->sqlQuote($value);
	my $where_clause = "";
	my $ipid_table = "moderatorlog";
	   if ($type eq 'uid')       {	$where_clause = "moderatorlog.uid=$vq      AND comments.uid=users.uid";
					$ipid_table = "comments"						    }
	elsif ($type eq 'cid')       {	$where_clause = "moderatorlog.cid=$vq      AND moderatorlog.uid=users.uid"  }
	elsif ($type eq 'cuid')      {	$where_clause = "moderatorlog.cuid=$vq     AND moderatorlog.uid=users.uid"  }
	elsif ($type eq 'subnetid')  {	$where_clause = "comments.subnetid=$vq     AND moderatorlog.uid=users.uid"  }
	elsif ($type eq 'ipid')      {	$where_clause = "comments.ipid=$vq         AND moderatorlog.uid=users.uid"  }
	elsif ($type eq 'bsubnetid') {	$where_clause = "moderatorlog.subnetid=$vq AND moderatorlog.uid=users.uid"  }
	elsif ($type eq 'bipid')     {	$where_clause = "moderatorlog.ipid=$vq     AND moderatorlog.uid=users.uid"  }
	elsif ($type eq 'global')    {	$where_clause =				      "moderatorlog.uid=users.uid"  }
	return [ ] unless $where_clause;

	my $time_clause = "";
	$time_clause = " AND ts > DATE_SUB(NOW(), INTERVAL $options->{hours_back} HOUR)" if $options->{hours_back};

	my $qlid = $self->_querylog_start("SELECT", "moderatorlog, users, comments");
	my $sth = $self->sqlSelectMany("comments.sid AS sid,
		 comments.cid AS cid,
		 comments.points AS score,
		 users.uid AS uid,
		 users.nickname AS nickname,
		 $ipid_table.ipid AS ipid,
		 moderatorlog.val AS val,
		 moderatorlog.reason AS reason,
		 moderatorlog.ts AS ts,
		 moderatorlog.active AS active,
		 moderatorlog.m2status AS m2status,
		 moderatorlog.id AS id
		 $select_extra",
		"moderatorlog, users, comments",
		"$where_clause
		 AND moderatorlog.cid=comments.cid 
		 $time_clause",
		"ORDER BY ts $asc_desc $limit"
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
	$cols = "mmid, count(*) as count";
	$where = "mmid in ($id_str) AND active=1 ";
	if ($type eq "fair") {
		$where .= " AND val > 0 ";
	} elsif ($type eq "unfair") {
		$where .= " AND val < 0 ";
	}
 	my $modcounts = $self->sqlSelectAllHashref('mmid', $cols ,'metamodlog', $where, 'group by mmid');
	return $modcounts;	
}

########################################################
sub getModeratorLogID {
	my($self, $cid, $uid) = @_;
	# We no longer need the SID as CID is now unique.
	my($mid) = $self->sqlSelect(
		"id", "moderatorlog", "uid=$uid and cid=$cid"
	);
	return $mid;
}

########################################################
sub undoModeration {
	my($self, $uid, $sid) = @_;
	my $constants = getCurrentStatic();

	# querylog isn't going to work for this sqlSelectMany, since
	# we do multiple other queries while the cursor runs over the
	# rows it returns.  So don't bother doing the _querylog_start.

	# SID here really refers to discussions.id, NOT stories.sid
	my $cursor = $self->sqlSelectMany("cid,val,active,cuid,reason",
			"moderatorlog",
			"moderatorlog.uid=$uid and moderatorlog.sid=$sid"
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
			"cid=$cid and uid=$uid"
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
		my $reason = $self->getCommentMostCommonReason($cid)
			|| 0; # no active moderations? reset reason to empty
		my $comm_update = {
			-points =>	$points,
			reason =>	$reason,
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
sub deleteSectionTopicsByTopic {
	my($self, $tid, $type) = @_;
	# $type ||= 1; # ! is the default type
	# arghghg no, it's not, and this caused
	# saving a topic to not work. 
	# not fun  at 12:19 AM
	$type ||= 0;

	$self->sqlDelete("section_topics", "tid=$tid");
}

########################################################
sub deleteRelatedLink {
	my($self, $id) = @_;

	$self->sqlDelete("related_links", "id=$id");
}

########################################################
sub createSectionTopic {
	my($self, $section, $tid, $type) = @_;
	$type ||= 'topic_1'; # ! is the default type

	$self->sqlInsert("section_topics", {
		section =>	$section,
		tid =>		$tid,
		type =>		$type,
	});
}

########################################################
sub getSectionExtras {
	my($self, $section) = @_;
	return unless $section;

	my $answer = $self->sqlSelectAll(
		'name,value,type,section', 
		'section_extras', 
		'section = '. $self->sqlQuote($section)
	);

	return $answer;
}


########################################################
sub setSectionExtras {
	my($self, $section, $extras) = @_;
	return unless $section;

	my $section_q = $self->sqlQuote($section);
	$self->sqlDelete("section_extras", "section=$section_q");
	
	for (@{$extras}) {
		$self->sqlInsert('section_extras', {
			section	=> $section,
			name 	=> $_->[0],
			value	=> $_->[1],
		});
	}
}

########################################################
sub getContentFilters {
	my($self, $formname, $field) = @_;

	my $field_string = $field ne '' ? " AND field = '$field'" : " AND field != ''";

	my $filters = $self->sqlSelectAll("*", "content_filters",
		"regex != '' $field_string and form = '$formname'");
	return $filters;
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

	my $data;
	$data->{story} = $submission->{story};
	$data->{subj} = $submission->{subj};
	$data->{ipid} = getCurrentUser('ipid');
	$data->{subnetid} = getCurrentUser('subnetid');
	$data->{email} ||= $submission->{email} ? $submission->{email} : ''; 
	$data->{uid} ||= $submission->{uid} ? $submission->{uid} 
		: getCurrentStatic('anonymous_coward_uid'); 
	$data->{section} ||= getCurrentStatic('defaultsection'); 
	$data->{'-time'} = 'now()' unless $submission->{'time'};

	# To help cut down on duplicates generated by automated routines. For
	# crapflooders, we will need to look into an alternate methods. 
	# Filters of some sort, maybe?
	$data->{signature} = md5_hex($submission->{story});

	$self->sqlInsert('submissions', $data);
	my $subid = $self->getLastInsertId;

	# The next line makes sure that we get any section_extras in the DB - Brian
	$self->setSubmission($subid, $submission);

	return $subid;
}

#################################################################
sub getStoryDiscussions {
	my($self, $section, $limit, $start) = @_;
	$limit ||= 50; # Sanity check in case var is gone
	$start ||= 0; # Sanity check in case var is gone
	my $tables = "discussions, stories",
	my $where = "displaystatus != -1
		AND discussions.sid=stories.sid
		AND time <= NOW()
		AND stories.writestatus != 'delete'
		AND stories.writestatus != 'archived'";

	if ($section) {
		$where .= " AND discussions.section = '$section'"
	} else {
		$tables .= ", sections";
		$where .= " AND sections.section = discussions.section ";
	}

	my $discussion = $self->sqlSelectAll(
		"discussions.sid, discussions.title, discussions.url",
		$tables,
		$where,
		"ORDER BY time DESC LIMIT $start, $limit"
	);

	return $discussion;
}

#################################################################
# Less then 2, since 2 would be a read only discussion
sub getDiscussions {
	my($self, $section, $limit, $start) = @_;
	$limit ||= 50; # Sanity check in case var is gone
	$start ||= 0; # Sanity check in case var is gone
	my $tables = "discussions";

	my $where = "type != 'archived' AND ts <= now()";

	if ($section) {
		$where .= " AND discussions.section = '$section'"
	} else {
		$tables .= ", sections";
		$where .= " AND sections.section = discussions.section ";
	}

	my $discussion = $self->sqlSelectAll(
		"discussions.id, discussions.title, discussions.url",
		$tables,
		$where,
		"ORDER BY ts DESC LIMIT $start, $limit"
	);

	return $discussion;
}

#################################################################
# Less then 2, since 2 would be a read only discussion
sub getDiscussionsByCreator {
	my($self, $section, $uid, $limit, $start) = @_;
	return unless $uid;
	$limit ||= 50; # Sanity check in case var is gone
	$start ||= 0; # Sanity check in case var is gone
	my $tables = "discussions";

	my $where = "type != 'archived' AND ts <= now() AND uid = $uid";

	if ($section) {
		$where .= " AND discussions.section = '$section'"
	} else {
		$tables .= ", sections";
		$where .= " AND sections.section = discussions.section ";
	}

	my $discussion = $self->sqlSelectAll("id, title, url",
		$tables,
		$where,
		"ORDER BY ts DESC LIMIT $start, $limit"
	);

	return $discussion;
}

#################################################################
sub getDiscussionsUserCreated {
	my($self, $section, $limit, $start, $all, $order_by_activity) = @_;

	$limit ||= 50; # Sanity check in case var is gone
	$start ||= 0; # Sanity check in case var is gone
	my $tables = "discussions, users";

	my $where = "type = 'recycle' AND ts <= now() AND users.uid = discussions.uid";
	$where .= " AND section = '$section'"
		if $section;
	$where .= " AND commentcount > 0"
		unless $all;

	if ($section) {
		$where .= " AND discussions.section = '$section'";
	} else {
		$tables .= ", sections";
		$where .= " AND sections.section = discussions.section ";
	}

	my $discussion = $self->sqlSelectAll("discussions.id, discussions.title, discussions.ts, users.nickname",
		$tables,
		$where,
		"ORDER BY ts DESC LIMIT $start, $limit"
	);

	return $discussion;
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

	my $uid;
	if ($ENV{SLASH_USER}) {
		$uid = $ENV{SLASH_USER};
	} else {
		$uid = $user->{uid} || $constants->{anonymous_coward_uid};
	}
	my $section = $constants->{section};
	# The following two are special cases
	if ($op eq 'index' || $op eq 'article') {
		$section = ($form && $form->{section})
			? $form->{section}
			: $constants->{section};
	}

	my($ipid, $subnetid) = (getCurrentUser('ipid'), getCurrentUser('subnetid'));
	if (!$ipid || !$subnetid) {
		($ipid, $subnetid) = get_ipids($r->connection->remote_ip);
	}

	if ($op eq 'index' && $dat =~ m|^([^/]*)/|) {
		$section = $1;
	}

	if ($dat =~ /(.*)\/(\d{2}\/\d{2}\/\d{2}\/\d{4,7}).*/) {
		$section = $1;
		$dat = $2;
		$op = 'article';
#		$self->sqlUpdate('stories', { -hits => 'hits+1' },
#			'sid=' . $self->sqlQuote($dat)
#		);
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
	my $insert = {
		host_addr	=> $ipid,
		subnetid	=> $subnetid,
		dat		=> $dat,
		uid		=> $uid,
		section		=> $section,
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
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $r = Apache->request;

	# $ENV{SLASH_USER} wasn't working, was giving us some failed inserts
	# with uid NULL.
	my $uid = $user->{uid};
	my $section = $constants->{section};
	# The following two are special cases
	if ($op eq 'index' || $op eq 'article') {
		$section = ($form && $form->{section})
			? $form->{section}
			: $constants->{section};
	}
	# And just what was the admin doing? -Brian
	$op = $form->{op} if $form->{op};
	$status ||= $r->status;

	$self->sqlInsert('accesslog_admin', {
		host_addr	=> $r->connection->remote_ip,
		dat		=> $dat,
		uid		=> $uid,
		section		=> $section,
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
	return $codeBank_hash_ref unless $descref;

	# I don't really feel like editing the entire %descriptions hash to
	# list each table with each codetype, so for now at least, I'm just
	# lumping all them together.  Which seems to be fine because on the
	# sites whose querylogs we've examined so far, 'descriptions'
	# accounts for, as you might expect, a miniscule amount of DB traffic.
	my $qlid = $self->_querylog_start('SELECT', 'descriptions');
	my $sth = $descref->(@_);
	return { } if !$sth;
	while (my($id, $desc) = $sth->fetchrow) {
		$codeBank_hash_ref->{$id} = $desc;
	}
	$sth->finish;
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

	my($ip, $subnet) = get_ipids($r->connection->remote_ip, 1);
	$self->sqlInsert("badpasswords", {
		uid =>          $uid,
		password =>     $password_wrong,
		ip =>           $ip,
		subnet =>       $subnet,
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
	my($self, $where_clause, $num, $min) = @_;
	$min ||= 0;
	my $limit = " LIMIT $min, $num " if $num;

	my $comments = $self->sqlSelectAllHashrefArray('*','comments', $where_clause, " ORDER BY date DESC $limit");

	return $comments;
}

#################################################################
sub getCommentsByUID {
	my($self, $uid, $num, $min) = @_;
	return $self->getCommentsByGeneric("uid=$uid", $num, $min);
}

#################################################################
sub getCommentsByIPID {
	my($self, $id, $num, $min) = @_;
	return $self->getCommentsByGeneric("ipid='$id'", $num, $min);
}

#################################################################
sub getCommentsBySubnetID {
	my($self, $id, $num, $min) = @_;
	return $self->getCommentsByGeneric("subnetid='$id'", $num, $min);
}

#################################################################
# Avoid using this one unless absolutely necessary;  if you know
# whether you have an IPID or a SubnetID, those queries take a
# fraction of a second, but this "OR" is a table scan.
sub getCommentsByIPIDOrSubnetID {
	my($self, $id, $min) = @_;
	return $self->getCommentsByGeneric(
		"ipid='$id' OR subnetid='$id'", $min);
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
	# Instructions don't get passed to the DB.
	delete $_[2]->{instructions};
	# Nor does a version (yet).
	delete $_[2]->{version};

	for (qw| page name section |) {
		next unless $_[2]->{$_};
		if ($_[2]->{$_} =~ /;/) {
			errorLog("A semicolon was found in the $_ while trying to update a template");
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
	$self->sqlDelete('moderatorlog', $where);
	$self->sqlDelete('metamodlog', "mmid IN ($mmid_in)");
}

########################################################
sub getCommentPid {
	my($self, $sid, $cid) = @_;

	$self->sqlSelect('pid', 'comments', "sid='$sid' and cid=$cid");
}

########################################################
# Ugly yes, needed at the moment, yes
sub checkStoryViewable {
	my($self, $sid) = @_;
	return unless $sid;

	my($column_time, $where_time) = $self->_stories_time_clauses({
		try_future => 1, must_be_subscriber => 1
	});

	# if there is no sid in the DB, assume that it is an old poll
	# or something that has a "fake" sid
	my $exists = $self->sqlCount(
		'stories',
		"sid='$sid'"
	);
	return 1 unless $exists;

	my $count = $self->sqlCount(
		'stories',
		"sid='$sid' AND displaystatus != -1 AND $where_time",
	);
	return $count;
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
	_genericSet('sections', 'section', '', @_);
}

########################################################
sub setSubSection {
	_genericSet('subsections', 'id', '', @_);
}

########################################################
sub createSection {
	my($self, $hash) = @_;

	$self->sqlInsert('sections', $hash);
}

########################################################
sub createSubSection {
	my($self, $section, $subsection, $artcount) = @_;

	$self->sqlInsert('subsections', {
		title		=> $subsection,
		artcount	=> $artcount || 0,
	});

	my $ssid = $self->sqlSelect('id','subsections',
		"title='$subsection'");

	$self->sqlInsert('section_subsections', {
		section		=> $section,
		subsection	=> $ssid,
	});
}

########################################################
# This is a really dumb method, I hope I am not to blame (I don't think I am though...) -Brian
sub removeSubSection {
#	my($self, $section, $subsection) = @_;
#
#	my $where;
#	if ($subsection =~ /^\d+$/) {
#		$where = 'id=' . $self->sqlQuote($subsection);
#	} else {
#		$where = sprintf 'name=%s AND title=%s',
#			$self->sqlQuote($section),
#			$self->sqlQuote($subsection);
#	}
#
#	$self->sqlDelete('subsections', $where);
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
	my($self, $subid, $nodelete) = @_;
	my $uid = getCurrentUser('uid');
	my $form = getCurrentForm();
	my @subid;

	$nodelete ||= 0;

	if ($form->{subid} && !$nodelete) {
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
		if ($t eq "note" || $t eq "comment" || $t eq "section") {
			$form->{"note_$n"} = "" if $form->{"note_$n"} eq " ";
			if ($form->{$_}) {
				my %sub = (
					note	=> $form->{"note_$n"},
					comment	=> $form->{"comment_$n"},
					section	=> $form->{"section_$n"}
				);

				if (!$sub{note}) {
					delete $sub{note};
					$sub{-note} = 'NULL';
				}

				$self->sqlUpdate("submissions", \%sub,
					"subid=" . $self->sqlQuote($n));
			}
		} elsif ($t eq 'del' && !$nodelete) {
			$self->sqlUpdate("submissions", { del => 1 },
				'subid=' . $self->sqlQuote($n));
			$self->setUser($uid,
				{ -deletedsubmissions => 'deletedsubmissions+1' }
			);
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
	my($self, $tid) = @_;
	my $tid_q = $self->sqlQuote($tid);
	$self->sqlDelete("topics", "tid=$tid_q");
}

########################################################
sub revertBlock {
	my($self, $bid) = @_;
	my $bid_q = $self->sqlQuote($bid);
	my $block = $self->sqlSelect("block", "backup_blocks", "bid=bid_q");
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
	my($rows) = $self->sqlSelect('count(*)', 'topics', "tid=$tid");

	my $image = $topic->{image2} ? $topic->{image2} : $topic->{image};

	# Save image info, first. We'll need the ID, later.
	my $imgid = $self->sqlSelect('id', 'topic_images',
		'name=' . $self->sqlQuote($topic->{name}) .
		' AND image=' . $self->sqlQuote($image)
	);

	my $data = {
		name		=> $topic->{name},
		image		=> $image,
		width		=> $topic->{width},
		height		=> $topic->{height},
	};

	my $data2 = {
		name		=> $topic->{name},
		default_image	=> $imgid,
		alttext		=> $topic->{alttext},
		parent_topic	=> $topic->{parent_topic},
		series		=> $topic->{series} ? 1 : 0,
	};


	# Using the topic as the name here probably isn't what is intended, but
	# it should work just fine for now.     -Cliff
	if (!$imgid) {
		$self->sqlInsert('topic_images', $data);
		$data2->{default_image} = $self->getLastInsertId;
	} else {
		$self->sqlUpdate('topic_images', $data, "id=$imgid");
	}

	if ($rows == 0) {
		$self->sqlInsert('topics', $data2);
		$tid = $self->getLastInsertId;
	} else {
		$self->sqlUpdate('topics', $data2, "tid=$tid");
	}

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
			section		=> $form->{section},
			retrieve	=> $form->{retrieve},
			all_sections	=> $form->{all_sections},
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
			section		=> $form->{section},
			retrieve	=> $form->{retrieve},
			portal		=> $form->{portal},
			autosubmit	=> $form->{autosubmit},
			all_sections	=> $form->{all_sections},
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

	my $sid_quoted = "";
	$sid_quoted = $self->sqlQuote($poll->{sid}) if $poll->{sid};

	# get hash of fields to update based on the linked story
	my $data = $self->getPollUpdateHashFromStory($poll->{sid}, {
		topic		=> 1,
		section		=> 1,
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
			section		=> $poll->{section},
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
			section		=> $poll->{section},
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

sub updatePollFromStory{
	my($self, $sid, $opts) = @_;
	my($data, $qid) = $self->getPollUpdateHashFromStory($sid, $opts);
	if ($qid){
		$self->sqlUpdate("pollquestions", $data, "qid=" . $self->sqlQuote($qid));
	}
}
sub getPollUpdateHashFromStory{
	my($self, $sid, $opts) = @_;
	my $story_ref=$self->sqlSelectHashref("sid,qid,time,section,tid,displaystatus", "stories", "sid=" . $self->sqlQuote($sid));
	my $data;

	if ($story_ref->{qid}) {
		$data->{date}		= $story_ref->{time} if $opts->{date};
		$data->{polltype}	= $story_ref->{displaystatus} >= 0 ? "story" : "nodisplay" if $opts->{polltype};
		$data->{topic}		= $story_ref->{tid} if $opts->{topic};
		$data->{section}	= $story_ref->{section} if $opts->{section};
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
	$where .= sprintf ' AND section IN (%s)', join(',', @{$other->{section}})
		if $other->{section};
	$where .= sprintf ' AND section NOT IN (%s)', join(',', @{$other->{exclude_section}})
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

# Deprecated -Brian
#########################################################
#sub getPollQuestions {
## This may go away. Haven't finished poll stuff yet
##
#	my($self, $limit) = @_;
#
#	$limit = 25 if (!defined($limit));
#
#	my $poll_hash_ref = {};
#	my $sql = "SELECT qid,question FROM pollquestions ORDER BY date DESC ";
#	$sql .= " LIMIT $limit " if $limit;
#	my $sth = $self->{_dbh}->prepare_cached($sql);
#	$sth->execute;
#	while (my($id, $desc) = $sth->fetchrow) {
#		$poll_hash_ref->{$id} = $desc;
#	}
#	$sth->finish;
#
#	return $poll_hash_ref;
#}

########################################################
sub deleteStory {
	my($self, $sid) = @_;
	$self->setStory($sid,
		{ writestatus => 'delete' }
	);
}

########################################################
sub setStory {
	my($self, $sid, $hashref) = @_;
	my(@param, %update_tables, $cache);
	# ??? should we do this?  -- pudge
	my $table_prime = 'sid';
	my $param_table = 'story_param';
	my $tables = [qw(
		stories story_text
	)];

	$cache = _genericGetCacheName($self, $tables);
	if ($hashref->{displaystatus} == 0) {
		my $section = $hashref->{section} ? $hashref->{section} : $self->getStory($sid, 'section');
	}

	$hashref->{day_published} = $hashref->{'time'}
		if ($hashref->{'time'});

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
		$ok = $self->sqlUpdate($table, \%minihash, 'sid=' . $self->sqlQuote($sid));
	}

	for (@param)  {
		if (defined $_->[1] && length $_->[1]) {
			$self->sqlReplace($param_table, {
				sid	=> $sid,
				name	=> $_->[0],
				value	=> $_->[1]
			});
		} else {
			my $sid_q = $self->sqlQuote($sid);
			my $name_q = $self->sqlQuote($_->[0]);
			$self->sqlDelete($param_table,
				"sid = $sid_q AND name = $name_q"
			);
		}
	}

	return $ok;
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

##################################################################
# For backwards compatibility, returns just the number of comments if
# called in scalar context, or a list of (number of comments, sum of
# the mods done to them) in list context.
sub getNumCommPostedAnonByIPID {
	my($self, $ipid, $hours) = @_;
	$ipid = $self->sqlQuote($ipid);
	$hours ||= 24;
	my $ac_uid = $self->sqlQuote(getCurrentStatic("anonymous_coward_uid"));
	my $ar = $self->sqlSelectArrayRef(
		"COUNT(*) AS count, SUM(pointsorig-points) AS sum",
		"comments",
		"ipid=$ipid
		 AND uid=$ac_uid
		 AND date >= DATE_SUB(NOW(), INTERVAL $hours HOUR)"
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
	my($self, $uid, $hours) = @_;
	$uid = $self->sqlQuote($uid);
	$hours ||= 24;
	my $ar = $self->sqlSelectArrayRef(
		"COUNT(*) AS count, SUM(points-pointsorig) AS sum",
		"comments",
		"uid=$uid
		 AND date >= DATE_SUB(NOW(), INTERVAL $hours HOUR)"
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
sub getBanList {
	my($self, $refresh) = @_;
	my $constants = getCurrentStatic();
	my $debug = $constants->{debug_db_cache};
	
	_genericCacheRefresh($self, 'banlist', $constants->{banlist_expire});
	my $banlist_ref = $self->{_banlist_cache} ||= {};

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
	}

	if ($debug) {
		my $time = time;
		my $diff = $time - $self->{_banlist_cache_time};
		print STDERR scalar(gmtime) . " pid $$ gBL time='$time' diff='$diff' self->_banlist_cache_time='$self->{_banlist_cache_time}' self->{_banlist_cache} keys: " . scalar(keys %{$self->{_banlist_cache}}) . "\n";
	}

	return $banlist_ref;
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
	my $where = "GROUP BY ipid ORDER BY abusecount DESC LIMIT $min,$max";
	$self->sqlSelectAll("count(*) AS abusecount,uid,ipid,subnetid", "abusers $where");
}

##################################################################
sub getAbuses {
	my($self, $key, $id) = @_;
	my $where = {
		uid => "uid = $id",
		ipid => "ipid = '$id'",
		subnetid => "subnetid = '$id'",
	};

	$self->sqlSelectAll('ts,uid,ipid,subnetid,pagename,reason',
		'abusers',  "$where->{$key}", 'ORDER by ts DESC');

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
	$x ||= 10000;
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
			$insert_hr->{ipid} = $user_check->{ipid};
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
sub checkIsProxy {
	my($self, $ipid) = @_;

	my $ipid_q = $self->sqlQuote($ipid);
	my $rows = $self->sqlCount("accesslist",
		"ipid=$ipid_q AND now_proxy = 'yes'") || 0;

	return $rows ? 'yes' : 'no';
}

#################################################################
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

########################################################
#
sub getTopNewsstoryTopics {
	my($self, $limit, $section) = @_;
        $section = "" if $section eq "index";
	my $all = 1 if !$limit;

	$limit =~ s/\D+//g;
	$limit = 10 if !$limit || $limit == 1;
        my $sect_clause =" AND section='$section' " if $section;
	my $other  = $all ? '' : "LIMIT $limit";
	my $topics = $self->sqlSelectAllHashrefArray(
		"topics.tid AS tid, alttext, COUNT(*) AS cnt, default_image, MAX(time) AS tme",
		'topics,stories',
		"writestatus != 'delete'
		AND displaystatus >= 0
		AND time <= NOW()
		AND topics.tid=stories.tid
		$sect_clause
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
sub getSubmissionsSections {
	my($self, $section) = @_;
	my $del = getCurrentForm('del');

	my $section_clause = $section? " AND section = '$section' " : ''; 

	my $hash = $self->sqlSelectAll("section,note,count(*)", 'submissions', "del=$del $section_clause GROUP BY section,note");

	return $hash;
}

##################################################################
# Get submission count
sub getSubmissionsPending {
	my($self, $uid) = @_;
	my $submissions;

	$uid ||= getCurrentUser('uid');

	$submissions = $self->sqlSelectAll(
		"time, subj, section, tid, del",
		"submissions",
		"uid=$uid",
		"ORDER BY time ASC"
	);

	return $submissions;
}

##################################################################
# Get submission count
sub getSubmissionCount {
	my($self, $articles_only) = @_;
	my($count);
	my $section = getCurrentUser('section');
	if ($articles_only) {
		$count = $self->sqlSelect('count(*)', 'submissions',
			"del=0 and section='articles' and note != ''"
		);
	} elsif ($section) {
		$section = $self->sqlQuote($section);
		$count = $self->sqlSelect("count(*)", "submissions",
			"(length(note)<1 or isnull(note)) and del=0 AND section = $section"
		);
	} else {
		$count = $self->sqlSelect("count(*)", "submissions",
			"(length(note)<1 or isnull(note)) and del=0"
		);
	}
	return $count;
}

##################################################################
# Get all portals
sub getPortals {
	my($self) = @_;
	my $portals = $self->sqlSelectAll('block,title,blocks.bid,url','blocks',"section='index' AND type='portald'", 'GROUP BY bid ORDER BY ordernum');

	return $portals;
}

##################################################################
# Get standard portals
sub getPortalsCommon {
	my($self) = @_;
	return($self->{_boxes}, $self->{_sectionBoxes}) if keys %{$self->{_boxes}};
	$self->{_boxes} = {};
	$self->{_sectionBoxes} = {};

	my $sections = $self->getDescriptions('sections-all');

	my $qlid = $self->_querylog_start("SELECT", "blocks");
	my $sth = $self->sqlSelectMany(
			'bid,title,url,section,portal,ordernum,all_sections',
			'blocks',
			'',
			'ORDER BY ordernum ASC'
	);
	# We could get rid of tmp at some point
	my %tmp;
	while (my $SB = $sth->fetchrow_hashref) {
		$self->{_boxes}{$SB->{bid}} = $SB;  # Set the Slashbox
		next unless $SB->{ordernum} > 0;  # Set the index if applicable
		if ($SB->{all_sections}) {
			for my $section (keys %$sections) {
				push @{$tmp{$section}}, $SB->{bid};
			}
		} else {
			push @{$tmp{$SB->{section}}}, $SB->{bid};
		}
	}
	$self->{_sectionBoxes} = \%tmp;
	$sth->finish;
	$self->_querylog_finish($qlid);

	return($self->{_boxes}, $self->{_sectionBoxes});
}

##################################################################
# Heaps are not optimized for count; use main comments table
sub countCommentsByGeneric {
	my($self, $where_clause) = @_;
	return $self->sqlCount('comments', $where_clause);
}

##################################################################
sub countCommentsBySid {
	my($self, $sid) = @_;
	return 0 if !$sid;
	return $self->countCommentsByGeneric("sid=$sid");
}

##################################################################
sub countCommentsByUID {
	my($self, $uid) = @_;
	return 0 if !$uid;
	return $self->countCommentsByGeneric("uid=$uid");
}

##################################################################
sub countCommentsBySubnetID {
	my($self, $subnetid) = @_;
	return 0 if !$subnetid;
	return $self->countCommentsByGeneric("subnetid='$subnetid'");
}

##################################################################
sub countCommentsByIPID {
	my($self, $ipid) = @_;
	return 0 if !$ipid;
	return $self->countCommentsByGeneric("ipid='$ipid'");
}

##################################################################
sub countCommentsByIPIDOrSubnetID {
	my($self, $id) = @_;
	return 0 if !$id;
	return $self->countCommentsByGeneric("ipid='$id' OR subnetid='$id'");
}

##################################################################
sub countCommentsBySidUID {
	my($self, $sid, $uid) = @_;
	return 0 if !$sid or !$uid;
	return $self->countCommentsByGeneric("sid=$sid AND uid=$uid");
}

##################################################################
sub countCommentsBySidPid {
	my($self, $sid, $pid) = @_;
	return 0 if !$sid or !$pid;
	return $self->countCommentsByGeneric("sid=$sid AND pid=$pid");
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
	my($self, $sid, $cid, $reason) = @_;
	return 0 unless $reason;

	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	my $comment_changed = 0;
	my $superAuthor = $constants->{authors_unlimited}
		&& $user->{seclev} >= $constants->{authors_unlimited};

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
		return if $user->{uid} == $comment->{uid};
		# Do not allow moderation of any comments (anonymous or otherwise)
		# with the same IP as the current user.
		return if $user->{ipid} eq $comment->{ipid};
		# If the var forbids it, do not allow moderation of any comments
		# with the same *subnet* as the current user.
		return if $constants->{mod_same_subnet_forbid}
			and $user->{subnetid} eq $comment->{subnetid};
		# Do not allow moderation of comments that are too old.
		return unless $comment->{time_unixepoch} >= time() - 3600*
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
			Slash::slashDisplay('moderation', $dispArgs);
			return 0;
		}
	}

	# Add moderation value to display arguments.
	my $val = $reasons->{$reason}{val};
	$val = "+1" if $val == 1;
	$dispArgs->{val} = $val;

	my $scorecheck = $comment->{points} + $val;
	my $active = 1;
	# If the resulting score is out of comment score range, no further
	# actions need be performed.
	# Should we return here and go no further?
	if (	$scorecheck < $constants->{comment_minscore} ||
		$scorecheck > $constants->{comment_maxscore})
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
			Slash::slashDisplay('moderation', $dispArgs);
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
		my $messages = getObject("Slash::Messages");
		$messages->send_mod_msg({
			type	=> 'mod_msg',
			sid	=> $sid,
			cid	=> $cid,
			val	=> $val,
			reason	=> $reason,
			comment	=> $comment
		});
	}

	# Now display the template with the moderation results.
	Slash::slashDisplay('moderation', $dispArgs);

	return 1;
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
	$tc = $kc;
	return ($kc, $tc);
}

##################################################################
sub metamodEligible {
	my($self, $user) = @_;

	# Easy tests the user can fail to be ineligible to metamod.
	return 0 if $user->{is_anon} || !$user->{willing} || $user->{karma} < 0;

	# Technically I believe the next bit should always be right under
	# the doctrine that an admin should be able to to anything but
	# maybe the cat ate a plant tonight
	# and thus Jim Jones really did it with the monkey wrench in the
	# blue room -Brian
	#return 1 if $user->{is_admin};

	# Not eligible if metamodded too recently.
	my $constants = getCurrentStatic();
	my $m2_freq = $constants->{m2_freq} || 86400;
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
#
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
# any reason to force a refresh?
#	%$cache = () if $refresh;

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

	if (!$section && !$topic && $user->{sectioncollapse}) {
		$where .= ' AND displaystatus>=0';
		$key .= '|>=';
	} else {
		$where .= ' AND displaystatus=0';
		$key .= '|=';
	}

	$where .= " AND sid != '$story->{sid}'";
	$key .= "|$story->{sid}";

	if (!$topic && !$section) {
		$where .= " AND tid not in ($user->{extid})" if $user->{extid};
		$where .= " AND uid not in ($user->{exaid})" if $user->{exaid};
		$where .= " AND section not in ($user->{exsect})" if $user->{exsect};
		# don't cache if user has own prefs -- pudge
		$key = $user->{extid} || $user->{exaid} || $user->{exsect} ? '' : $key . '|';
	} elsif ($section) {
		$where .= " AND section = '$section'";
		$key .= "|$section";
	} elsif ($topic) {
		$where .= " AND tid = '$topic'";
		$key .= "|$topic";
	}

	$key .= "|$time" if $key;

	return $cache->{$key} if $key && defined $cache->{$key};

#	print STDERR "SELECT title, sid, section, tid FROM stories WHERE " .
#		"'$time' > DATE_SUB(NOW(), INTERVAL $bytime_delay DAY) AND time $sign '$time' AND time < NOW() AND writestatus != 'delete' $where " .
#		"ORDER BY time $order LIMIT $limit\n";

	my $returnable = $self->sqlSelectHashref(
		'title, sid, section, tid',
		'stories',

		"'$time' > DATE_SUB(NOW(), INTERVAL $bytime_delay DAY)
		 AND time $sign '$time'
		 AND time < NOW()
		 AND writestatus != 'delete'
		 $where",

		"ORDER BY time $order LIMIT $limit"
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
	my($where);
	my $user = getCurrentUser();
	$limit ||= 1;

	# '=' is also sometimes used for $sign; in that case,
	# order is irrelevant -- pudge
	my $order = $sign eq '<' ? 'DESC' : 'ASC';

	$where .= " AND sid != '$story->{sid}'";

	my $time = $story->{'time'};
	my $returnable = $self->sqlSelectAllHashrefArray(
		'title, sid, time, displaystatus',
		'stories',
		"time $sign '$time' AND writestatus != 'delete' $where",
		"ORDER BY time $order LIMIT $limit"
	);

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

	# Get a list of other mods which duplicate one or more of the
	# ones we're modding, but aren't in fact the ones we're modding.
	my $others = $self->sqlSelectAllHashrefArray(
		"id, cid, reason",
		"moderatorlog",
		"($cr_clause)
		 AND uid != $uid_q AND cuid != $uid_q
		 AND m2status=0
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
	my($self, $m2_user, $m2s, $multi_max) = @_;
	my $constants = getCurrentStatic();
	my $consensus = $constants->{m2_consensus};
	my $rows;

	# If this user has no saved mods, by definition nothing they try
	# to M2 is valid.
	return if !$m2_user->{mods_saved};

	# The user is only allowed to metamod the mods they were given.
	my @mods_saved = $self->getModsSaved($m2_user);
	my %mods_saved = map { ( $_, 1 ) } @mods_saved;
	my @m2s_mmids = sort { $a <=> $b } keys %$m2s;
	for my $mmid (@m2s_mmids) {
		delete $m2s->{$mmid} if !$mods_saved{$mmid};
	}

	# If we are allowed to multiply these M2's to apply to other
	# mods, go ahead.  multiMetaMod changes $m2s in place.  Note
	# that we first screened %$m2s to allow only what was saved for
	# this user;  having made sure they are not trying to fake an
	# M2 of something disallowed, now we can multiply them out to
	# possibly affect more.
	if ($multi_max) {
		$self->multiMetaMod($m2_user, $m2s, $multi_max);
	}

	# Whatever happens below, as soon as we get here, this user has
	# done their M2 for the day and gets their list of OK mods cleared.
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

	my($voted_fair, $voted_unfair) = (0, 0);
	for my $mmid (keys %$m2s) {
		my $mod_uid = $self->getModeratorLog($mmid, 'uid');
		my $is_fair = $m2s->{$mmid}{is_fair};

		# Increment the m2count on the moderation in question.  If
		# this increment pushes it to the current consensus threshold,
		# change its m2status from 0 ("eligible for M2") to 1
		# ("all done with M2'ing, but not yet reconciled").  Note
		# that we insist not only that the count be above the
		# current consensus point, but that it be odd -- if we
		# recently lowered the var m2_consensus, there may be some
		# mods "trapped" with an even number of M2s.

		$rows = 0;
		$rows = $self->sqlUpdate(
			"moderatorlog", {
				-m2count =>	"m2count+1",
				-m2status =>	"IF(m2count >= $consensus
							AND MOD(m2count, 2) = 1,
							1, 0)",
			},
			"id=$mmid AND m2status=0
			 AND m2count < $consensus AND active=1",
			{ assn_order => [qw( -m2count -m2status )] },
		) unless $m2_user->{tokens} < $self->getVar("m2_mintokens", "value", 1);

		$rows += 0; # if no error, returns 0E0 (true!), we want a numeric answer
		my $ui_hr = { };
		if ($is_fair)	{ ++$voted_fair;   $ui_hr->{-m2fair}   = "m2fair+1" }
		else		{ ++$voted_unfair; $ui_hr->{-m2unfair} = "m2unfair+1" }
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

	$self->sqlUpdate("users_info", {
		-m2fairvotes	=> "m2fairvotes+$voted_fair",
		-m2unfairvotes	=> "m2unfairvotes+$voted_unfair",
	}, "uid=$m2_user->{uid}") if $voted_fair || $voted_unfair;
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
	$self->sqlInsert('vars', {name => $name, value => $value, description => $desc});
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
	my $where = "cid=$cid AND points ";
	if ($val < 0) {
		$where .= " > $constants->{comment_minscore}";
	} else {
		$where .= " < $constants->{comment_maxscore}";
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
	($hr->{cid}, $hr->{points_before}, $hr->{points_orig}, $hr->{points_max}) =
		$self->sqlSelect("cid, points, pointsorig, pointsmax",
			"comments", "cid=$cid", "LOCK IN SHARE MODE");
	$hr->{points_change} = $val;
	$hr->{points_after} = $hr->{points_before} + $val;

	my $karma_val;
	if (!$constants->{mod_down_karmacoststyle}) {
		$karma_val = $val;
	} elsif ($val < 0) {
		$karma_val = ($hr->{points_before}+$val) - $hr->{points_max};
	} else {
		$karma_val = $val;
	}
	if ($karma_val) {
		my $karma_abs_val = abs($karma_val);
		$update->{-karma}     = sprintf("karma%+d", $karma_val);
		$update->{-karma_abs} = sprintf("karma_abs%+d", $karma_abs_val);
	}

	my $changed = $self->sqlUpdate("comments", $update, $where, {
		assn_order => [ "-points", "-pointsmax" ]
	});

#	$self->{_dbh}->commit;
#	$self->{_dbh}{AutoCommit} = 1;
	$self->sqlDo("COMMIT");
	$self->sqlDo("SET AUTOCOMMIT=1");

	return $changed ? $hr : undef;
}

########################################################
# This gets the mathematical mode, in other words the most common,
# of the moderations done to a comment.  If no mods, return undef.
# Tiebreakers break ties, first tiebreaker found wins.  "cid"
# is a key in moderatorlog so this is not a table scan.
# A clever thing to do here would be to check the comment's
# "points" vs. "pointsorig";  if the score has overall gone
# up, only consider positive mod reasons, and if down, only
# negative.  If zero, use the current logic.  Maybe later...
sub getCommentMostCommonReason {
	my($self, $cid, $allreasons_hr, @tiebreaker_reasons) = @_;

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
		"date,date as time,subject,comments.points as points,
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
        my($self, $id, $field, $limit) = @_;

	$limit = "LIMIT $limit" if $limit;
	my $where;

	if ($field eq 'ipid') {
		$where = "ipid='$id'";
	} elsif ($field eq 'subnetid') {
		$where = "subnetid='$id'";
	} else {
		$where = "ipid='$id' OR subnetid='$id'";
	}

	my $answer = $self->sqlSelectAllHashrefArray(
		'uid,name,subid,subj,time',
		'submissions', $where,
		"ORDER BY time DESC $limit");

	return $answer;
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
		$where = "ipid='$id' OR subnetid='$id'";
	}

	my $count = $self->sqlCount('submissions', $where);

	return $count;
}

########################################################
# Needs to be more generic in the long run. 
# Be nice if we could just pull certain elements -Brian
sub getStoriesBySubmitter {
	my($self, $id, $limit) = @_;

	$limit = 'LIMIT ' . $limit if $limit;
	my $answer = $self->sqlSelectAllHashrefArray(
		'sid,title,time',
		'stories', "submitter='$id' AND time < NOW() AND (writestatus = 'ok' OR writestatus = 'dirty') and displaystatus >= 0 ",
		"ORDER by time DESC $limit");
	return $answer;
}

########################################################
sub countStoriesBySubmitter {
	my($self, $id) = @_;

	my $count = $self->sqlCount('stories', "submitter='$id'  AND time < NOW() AND (writestatus = 'ok' OR writestatus = 'dirty') and displaystatus >= 0");

	return $count;
}

########################################################
sub _stories_time_clauses {
	my($self, $options) = @_;
	my $try_future =		$options->{try_future}		|| 0;
	my $must_be_subscriber =	$options->{must_be_subscriber}	|| 0;
	my $column_name =		$options->{column_name}		|| "time";
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	my($is_future_column, $where);

	my $secs = $constants->{subscribe_future_secs};
	# Tweak $secs here somewhat, based on something...?  Nah.

	# First decide whether we're looking into the future or not.  If we
	# are going to try for this sort of thing, then either we must NOT
	# be limiting it to subscribers only, OR the user must be a subscriber
	# and this page must be plummy (able to have plums).
	my $future = 0;
	$future = 1 if $try_future
		&& $constants->{subscribe}
		&& $secs
		&& (!$must_be_subscriber
			|| ($user->{is_subscriber} && $user->{state}{page_plummy}));

	# XXX Would we be well-served here to, by default, only scan back
	# n days?  This would mean a quicker check of the table because
	# the time index is the one being used and if we have it BETWEEN
	# n days ago and now, it will be much faster.  Of course if that
	# fails to return enough rows we would have to re-run the query,
	# passing in an option to _stories_time_clauses that means "don't
	# limit the front end of time, give me everything before the time
	# given." - Jamie
	if ($future) {
		$is_future_column = "IF($column_name < NOW(), 0, 1) AS is_future";
		if ($secs) {
			$where = "$column_name < DATE_ADD(NOW(), INTERVAL $secs SECOND)";
		} else {
			$where = "$column_name < NOW()";
		}
	} else {
		$is_future_column = '0 AS is_future';
		$where = "$column_name < NOW()";
	}

	return ($is_future_column, $where);
}

########################################################
# Be nice if we could control more of what this 
# returns -Brian
# ok, I extended it to take an sid so I could get 
# just one particlar story (getStory doesn't cut it)
# since I don't want the story text but what 
# this method gives for the feature story) -Patrick
# ..and an exclude sid for excluding and sid should feature
# stories be enabled
# misc would be better served by calling it options -Brian
sub getStoriesEssentials {
	my($self, $limit, $section, $tid, $misc) = @_;
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();
	$section ||= $constants->{section};

	# Default limit value
	$limit ||= 15;
	# Make sure that, however many stories the caller wants to display,
	# there are some left over for the "Older Stories" box, if any.
	# (It's the caller's responsibility to display only as many stories
	# as it wants to.)
	$limit += 15;

	my($column_time, $where_time) = $self->_stories_time_clauses({
		try_future => 1, must_be_subscriber => 0
	});
	my $columns = "sid, section, title, time, commentcount, hitparade,"
		. " tid, body_length, word_count, discussion, $column_time";

	my $where = "$where_time ";

	# Added this to narrow the query a bit more, I need
	# see about the impact on this -Brian
	$where .= "AND writestatus != 'delete' ";

	# Now we want to read along here (i.e., no complaining, read this first). 
	# We are always in a section. The behavior for a contained section is
	# to display what sections are contained. In the case of no sections
	# in the container, it is assumed to be all. This would be the Slashdot
	# special since it is optimized there to never do any sort of lookup with 
	# section. Any other section is just a contained section and works like
	# any other section. If "sectioncollapse" is enabled for the user we just
	# collapse all of stories in the contained set of sections.
	# Got any questions? Just ask, don't bitch about this. -Brian
	# Huh huh, you said "bitch" -- pudge
	my $SECT = $self->getSection($section);
	if ($SECT->{type} eq 'collected') {
		$where .= " AND stories.section IN ('" . join("','", @{$SECT->{contained}}) . "')" 
			if $SECT->{contained} && @{$SECT->{contained}};

		if ($user->{sectioncollapse}) {
			$where .= " AND displaystatus >= 0 ";
		} else {
			$where .= " AND displaystatus = 0 ";
		}
		$where .= " AND section not in ($user->{exsect}) "
			if $user->{exsect};
	} else {
		$where .= " AND stories.section = " . $self->sqlQuote($SECT->{section});
		$where .= " AND displaystatus >= 0 ";
	}

	$where .= " AND tid = "        . $self->sqlQuote($tid)                 if $tid;
	$where .= " AND sid = "        . $self->sqlQuote($misc->{sid})         if $misc->{sid};
	$where .= " AND sid != "       . $self->sqlQuote($misc->{exclude_sid}) if $misc->{exclude_sid};
	$where .= " AND subsection = " . $self->sqlQuote($misc->{subsection})  if $misc->{subsection};

	# User Config Vars
	$where .= " AND tid not in ($user->{extid}) "
		if $user->{extid};
	$where .= " AND stories.uid not in ($user->{exaid}) "
		if $user->{exaid};

	# Order
	my $other = " ORDER BY time DESC ";

	# Since stories may potentially have thousands of rows, we
	# cannot simply select the whole table and cursor through it, it might
	# seriously suck resources.  Normally we can just add a LIMIT $limit,
	# but if we're in "issue" form we have to be careful where we're
	# starting/ending so we only limit by time in the DB and do the rest
	# in perl.
	# Note that, in order to be sure that in issue mode we show enough data
	# (indeed any data at all) in the Older Stuff box, we need to grab a
	# great deal of data here and trust that the Older Stuff box will trim
	# it down to what's necessary.
	if ($form->{issue} && $form->{issue} =~ /^\d{8}$/) {
		my $issue_start = timeCalc("$form->{issue}000000", "%Y-%m-%d %T",
			-$user->{off_set} - 86400*7);
		my $issue_end   = timeCalc("$form->{issue}235959", "%Y-%m-%d %T",
			-$user->{off_set}          );
		$where .= " AND time BETWEEN '$issue_start' AND '$issue_end'";
	} else {
		$other .= "LIMIT $limit ";
	}

	my(@stories, @story_ids, @discussion_ids, $count);
	my $qlid = $self->_querylog_start("SELECT", "stories");
	my $cursor = $self->sqlSelectMany($columns, 'stories', $where, $other)
		or
	errorLog(<<EOT);
error in getStoriesEssentials
	columns: $columns
	story_table: stories
	where: $where
	other: $other
EOT

	while (my $story = $cursor->fetchrow_hashref) {
#		if ($form->{issue}) {
#			my $issue= timeCalc($story->{time}, '%Y%m%d');
#			$story->{issue} = $issue;
#		}
		push @stories, $story;
		last if ++$count >= $limit;
	}
	$cursor->finish;
	$self->_querylog_finish($qlid);

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
		section => $form->{section} || $constants->{section},
	});
	$self->setSubmission($subid, {
		storyonly => 1,
		separate  => 1,
	});
}

########################################################
# What an ugly method
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

	# What was here before was a bug since you could end up in a
	# section that was different then what the form was passing in (the
	# result was something like WHERE section="foo" AND section="bar").
	# Look in CVS for the previous code. Now, this what we are doing. If
	# form.section is passed in we override anything about the section
	# and display what the user asked for. The exception is for a
	# section admin. In that case user.section is all they should see
	# and is all that we let them see. Now, if the user is not a
	# section admin and form.section is not set we make a call to
	# getSection() which will pass us back whatever section we are
	# in. Now in the case of a site with an "index" section that is
	# a collected section that has no members, aka Slashdot, we will
	# return everything for every section. Otherwise we return just
	# sections from the collection.  In a contained section we just
	# return what is in that section (say like "science" on Slashdot).
	# Mail me about questions. -Brian
	my $SECT = $self->getSection($user->{section} || $form->{section});
	if ($SECT->{type} eq 'collected') {
		push @where, "section IN ('" . join("','", @{$SECT->{contained}}) . "')" 
			if $SECT->{contained} && @{$SECT->{contained}};
	} else {
		push @where, "section = " . $self->sqlQuote($SECT->{section});
	}

	my $submissions = $self->sqlSelectAllHashrefArray(
		'submissions.*, karma',
		'submissions,users_info',
		join(' AND ', @where),
		'ORDER BY time'
	);

	for my $sub (@$submissions) {
		my $append = $self->sqlSelectAll(
			'name,value',
			'submission_param',
			"subid=" . $self->sqlQuote($sub->{subid})
		);

		for (@$append) {
			$sub->{$_->[0]} = $_->[1];
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
	return unless $discussion->{title} && $discussion->{url} && $discussion->{topic};

	#If no type is specified we assume the value is zero
	$discussion->{section} ||= getCurrentStatic('defaultsection');
	$discussion->{type} ||= 'open';
	$discussion->{commentstatus} ||= getCurrentStatic('defaultcommentstatus');
	$discussion->{sid} ||= '';
	$discussion->{ts} ||= $self->getTime();
	$discussion->{uid} ||= getCurrentUser('uid');
	# commentcount and flags set to defaults

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
	my $sidformat = '%02d/%02d/%02d/%02d%0d2%02d';
	# Create a sid based on the current time.
	my $start_time = time;
	my @lt = localtime($start_time);
	$lt[5] %= 100; $lt[4]++; # year and month
	$story->{sid} = sprintf($sidformat, @lt[reverse 0..5]);

	# If this came from a submission, update submission and grant
	# Karma to the user
	my $suid;
	if ($story->{subid}) {
		my($suid) = $self->sqlSelect(
			'uid', 'submissions',
			'subid=' . $self->sqlQuote($story->{subid})
		);

		# i think i got this right -- pudge
 		if (!isAnon($suid)) {
	 		my($userkarma) =
				$self->sqlSelect('karma', 'users_info', "uid=$suid");
			my $newkarma = (($userkarma + $constants->{submission_bonus})
				> $constants->{maxkarma})
					? $constants->{maxkarma}
					: "karma+$constants->{submission_bonus}";
			$self->sqlUpdate('users_info', {
				-karma => $newkarma },
			"uid=$suid");
			$self->setUser_delete_memcached($suid);
		}

		$self->setSubmission($story->{subid}, {
			del	=> 2,
			sid	=> $story->{sid}
		});
	}

	$story->{submitter}	= $story->{submitter} ?
		$story->{submitter} : $story->{uid};
	$story->{writestatus}	= 'dirty',

	my $sid_ok = 0;
	while ($sid_ok == 0) {
		$sid_ok = $self->sqlInsert('stories',
			{ sid => $story->{sid} },
			{ ignore => 1 } ); # don't print error messages
		if ($sid_ok == 0) { # returns 0E0 on collision, which == 0
			# Look back in time until we find a free second.
			# This is faster than waiting forward in time :)
			--$start_time;
			@lt = localtime($start_time);
			$lt[5] %= 100; $lt[4]++; # year and month
			$story->{sid} = sprintf($sidformat, @lt[reverse 0..5]);
		}
	}
	unless ($self->sqlInsert('story_text', { sid => $story->{sid}})) {
		print STDERR "Failed to Insert story Text\n";
		goto error;
	}
	$story->{body_length} = length($story->{bodytext});
	$story->{word_count} = countWords($story->{introtext}) + countWords($story->{bodytext});
	unless ($self->setStory($story->{sid}, $story)) {
		print STDERR "Failed to Insert most of story\n";
		goto error;
	}
	my $section = $self->getSection($story->{section});
	my $rootdir = $section->{rootdir} || $constants->{rootdir};
	my $comment_codes = $self->getDescriptions("commentcodes");

	my $discussion = {
		title		=> $story->{title},
		section		=> $story->{section},
		topic		=> $story->{tid},
		url		=> "$rootdir/article.pl?sid=$story->{sid}&tid=$story->{topic}",
		sid		=> $story->{sid},
		commentstatus	=> $comment_codes->{$story->{commentstatus}} ? $story->{commentstatus} : getCurrentStatic('defaultcommentstatus'),
		ts		=> $story->{'time'}
	};
	my $id = $self->createDiscussion($discussion);
	unless ($id) {
		print STDERR "Failed to create discussion for story: " . Dumper($discussion);
		goto error;
	}
	unless ($self->setStory($story->{sid}, { discussion => $id })) {
		print STDERR "Failed to set discussion '$id' for story '$story->{sid}'\n";
		goto error;
	}
	# Take all secondary topics and shove them into the array for the story
	unless ($self->setStoryTopics($story->{sid}, createStoryTopicData($self))) {
		print STDERR "Failed to set topics for story '$story->{sid}'\n";
		goto error;
	}

#	$self->{_dbh}->commit;
#	$self->{_dbh}{AutoCommit} = 1;
	$self->sqlDo("COMMIT");
	$self->sqlDo("SET AUTOCOMMIT=1");

	return $story->{sid};

	error: {
#		$self->{_dbh}->rollback;
#		$self->{_dbh}{AutoCommit} = 1;
		$self->sqlDo("ROLLBACK");
		$self->sqlDo("SET AUTOCOMMIT=1");
		return "";
	}
}

##################################################################
sub updateStory {
	my($self, $sid, $data) = @_;
	my $constants = getCurrentStatic();
#	$self->{_dbh}{AutoCommit} = 0;
	$self->sqlDo("SET AUTOCOMMIT=0");

	$data->{body_length} = length($data->{bodytext});
	$data->{word_count} = countWords($data->{introtext}) + countWords($data->{bodytext});

	my $sid_q = $self->sqlQuote($sid);
	my $prev_section = $self->sqlSelect(
		"section", "stories",
		"sid=$sid_q");
	my $old_section_param = $self->sqlSelect(
		"value", "story_param",
		"sid=$sid_q AND name = 'old_shtml_sections'");
	if ($prev_section && $prev_section ne $data->{section}) {
		$old_section_param .= "$prev_section,";
		$data->{old_shtml_sections} = $old_section_param;
	}

	unless ($self->setStory($sid, $data)) {
		print STDERR "Failed to set topics for story\n";
		goto error;
	}

	my $comment_codes = $self->getDescriptions("commentcodes");
	my $dis_data = {
		sid		=> $sid,
		title		=> $data->{title},
		section		=> $data->{section},
		url		=> "$constants->{rootdir}/article.pl?sid=$sid",
		ts		=> $data->{'time'},
		topic		=> $data->{tid},
		commentstatus	=> $comment_codes->{$data->{commentstatus}} ? $data->{commentstatus} : getCurrentStatic('defaultcommentstatus'),
	};

	unless ($self->setStoryTopics($sid, createStoryTopicData($self))) {
		print STDERR "Failed to set topics for story\n";
		goto error;
	}


	unless ($self->setDiscussionBySid($sid, $dis_data)) {
		print STDERR "Failed to set discussion data for story\n";
		goto error;
	}

	my $days_to_archive = $constants->{'archive_delay'};
	$self->sqlUpdate('discussions', { type => 'open' },
		"sid='$sid' AND type='archived' AND ((TO_DAYS(NOW()) - TO_DAYS(ts)) <= $constants->{archive_delay})"
	);

	if ($data->{displaystatus} < 1) {
		$self->setVar('writestatus', 'dirty');
		$self->setSection($data->{section}, { writestatus => 'dirty' });
	}

#	$self->{_dbh}->commit;
#	$self->{_dbh}{AutoCommit} = 1;
	$self->sqlDo("COMMIT");
	$self->sqlDo("SET AUTOCOMMIT=1");
        $self->updatePollFromStory($sid, {
        	date		=> 1,
        	topic		=> 1,
        	section		=> 1,
        	polltype	=> 1
        });

	return $sid;

	error: {
#		$self->{_dbh}->rollback;
#		$self->{_dbh}{AutoCommit} = 1;
		$self->sqlDo("ROLLBACK");
		$self->sqlDo("SET AUTOCOMMIT=1");
		return "";
	}
}

########################################################
# Now, the idea is to not cache here, since we actually
# cache elsewhere (namely in %Slash::Apache::constants)
sub getSlashConf {
	my($self) = @_;

	# get all the data, yo! However make sure we can return if any DB
	# errors occur.
	my $confdata = $self->sqlSelectAll('name, value', 'vars');
	return if !defined $confdata;
	my %conf = map { $_->[0], $_->[1] } @{$confdata};
	# This allows you to do stuff like constant.plugin.Zoo in a template
	# and know that the plugin is installed -Brian
	my $plugindata = $self->sqlSelectColArrayref('value', 'site_info',
		"name='plugin'");
	for (@$plugindata) {
		$conf{plugin}{$_} = 1;
	}
	$conf{reasons} = $self->sqlSelectAllHashref(
		"id", "*", "modreasons"
	);

	# the rest of this function is where is where we fix up
	# any bad or missing data in the vars table
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
		lonetags =>			[qw( P LI BR IMG DT DD)],
		fixhrefs =>			[ ],
		hc_possible_fonts =>		[ ],
		lonetags =>			[ ],
		op_exclude_from_countdaily =>   [qw( rss )],
		op_extras_countdaily =>   	[ ],
		mod_stats_reports =>		[ $conf{adminmail_mod} ],
		stats_reports =>		[ $conf{adminmail} ],
		stats_sfnet_groupids =>		[ 4421 ],
		submit_categories =>		[ ],
		sections_recenttopics =>        [ ],
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
						  1.00 => [qw( +0.05  0     +5 +0.5 )],	}
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

	if ($conf{x_forwarded_for_trust_regex}) {
		$conf{x_forwarded_for_trust_regex} = qr{$conf{x_forwarded_for_trust_regex}};
	}

	# for fun ... or something
	$conf{colors} = $self->sqlSelect("block", "blocks", "bid='colors'");

	# We only need to do this on startup.
	$conf{classes} = $self->getClasses();

	return \%conf;
}

##################################################################
# It would be best to write a Slash::MemCached class, preferably as
# a plugin, but let's just do this for now.
sub getMCD {
	my($self) = @_;

	# If we already created it for this object, or if we tried to
	# create it and failed and assigned it 0, return that.
	return $self->{_mcd} if defined($self->{_mcd});

	# If we aren't using memcached, return false.
	my $constants = getCurrentStatic();
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
		$self->{_mcd}{keyprefix} = $constants->{memcached_keyprefix};
	} else {
		# If no keyprefix defined in vars, use the first and
		# last letter from the sitename.
		$constants->{sitename} =~ /([A-Za-z]).*(\w)/;
		$self->{_mcd}{keyprefix} = ($2 ? lc("$1$2") : ($1 ? lc($1) : ""));
	}
	return $self->{_mcd};
}

##################################################################
sub getMCDStats {
	my($self) = @_;
	my $mcd = $self->getMCD();
	return undef unless $mcd;

	# Right now (11/04/2003) this depends on a custom patch to
	# Cache::Memcached.  I hope to have that in the CPAN version
	# soon.  Until it is, unless you have my patch, this isn't
	# going to work, sorry. - Jamie
	return undef unless $mcd->can("stats");

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
		"title like '\%$title\%'",
		'ORDER BY time DESC LIMIT 1'
	);
	my $rootdir = getCurrentStatic('rootdir');
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
# Should this really be in here? -- krow
# dunno ... sigh, i am still not sure this is best
# (see getStories()) -- pudge
# As of now, getDay is only used in Slash.pm getOlderStories() - Jamie
# And if a webserver had a date that is off... -Brian
# ...it wouldn't matter; "today's date" is a timezone dependent concept.
# If you live halfway around the world from whatever timezone we pick,
# this will be consistently off by hours, so we shouldn't spend an SQL
# query to worry about minutes or seconds - Jamie
sub getDay {
#	my($now) = $self->sqlSelect('to_days(now())');
	my($self, $days_back) = @_;
	$days_back ||= 0;
	my $day = timeCalc(scalar(localtime(time-86400*$days_back)), '%Y%m%d'); # epoch time, %Q
	return $day;
}

##################################################################
sub getStoryList {
	my($self, $first_story, $num_stories) = @_;
	$first_story ||= 0;
	$num_stories ||= 40;

	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();

	# CHANGE DATE_ FUNCTIONS
	my $columns = 'hits, stories.commentcount as commentcount, stories.sid, stories.title, stories.uid, '
		. 'time, name, stories.subsection,stories.section, displaystatus, stories.writestatus';
	my $tables = 'stories LEFT JOIN topics ON stories.tid=topics.tid'; # 'stories, topics';
	my $where = ''; # stories.tid=topics.tid ";
	my @where;
	# See getSubmissionsForUser() on why the following is like this. -Brian
	my $SECT = $self->getSection($user->{section} || $form->{section});
	if ($SECT->{type} eq 'collected') {
		push @where, "stories.section IN ('" . join("','", @{$SECT->{contained}}) . "')" 
			if $SECT->{contained} && @{$SECT->{contained}};
	} else {
		push @where, "stories.section = " . $self->sqlQuote($SECT->{section});
	}
	push @where, "time < DATE_ADD(NOW(), INTERVAL 72 HOUR) "
		if $form->{section} eq '' && !$constants->{show_all_future_stories_admin};
	my $other = "ORDER BY time DESC LIMIT $first_story, $num_stories";

	$where = join ' AND ', @where;
	my $count = $self->sqlSelect("COUNT(*)", $tables, $where);

	my $list = $self->sqlSelectAll($columns, $tables, $where, $other);

	return($count, $list);
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
sub getStory {
	my($self, $id, $val, $force_cache_freshen) = @_;
	my $constants = getCurrentStatic();

	# If our story cache is too old, expire it.
	_genericCacheRefresh($self, 'stories', $constants->{story_expire});
	my $table_cache = '_stories_cache';
	my $table_cache_time= '_stories_cache_time';

	# Go grab the data if we don't have it, or if the caller
	# demands that we grab it anyway.
	my $is_in_cache = exists $self->{$table_cache}{$id};
	if (!$is_in_cache || $force_cache_freshen) {
		# We avoid the join here. Sure, it's two calls to the db,
		# but why do a join if it's not needed?
		my($append, $answer, $db_id);
		$db_id = $self->sqlQuote($id);
		my($column_clause) = $self->_stories_time_clauses({
			try_future => 1, must_be_subscriber => 0
		});
		$answer = $self->sqlSelectHashref("*, $column_clause", 'stories', "sid=$db_id");
		$append = $self->sqlSelectHashref('*', 'story_text', "sid=$db_id");
		for my $key (keys %$append) {
			$answer->{$key} = $append->{$key};
		}
		$append = $self->sqlSelectAll('name,value', 'story_param', "sid=$db_id");
		for my $ary_ref (@$append) {
			$answer->{$ary_ref->[0]} = $ary_ref->[1];
		}
		if (!$answer || ref($answer) ne 'HASH') {
			# If there's no data for this sid, then there's no data
			# for us to return, and we shouldn't touch the cache.
			return undef;
		}
		# If this is the first data we're writing into the cache,
		# mark the time -- this data, and any other stories we
		# write into the cache for the next n seconds, will be
		# expired at that time.
		$self->{$table_cache_time} = time() if !$self->{$table_cache_time};
		# Cache the data.
		$self->{$table_cache}{$id} = $answer;
	}

	# The data is in the table cache now.
	my $retval;
	if ($val && !ref $val) {
		# Caller only asked for one return value.
		if (exists $self->{$table_cache}{$id}{$val}) {
			$retval = $self->{$table_cache}{$id}{$val};
		}
	} else {
		# Caller asked for multiple return values.  It really doesn't
		# matter what specifically they asked for, we always return
		# the same thing:  a hashref with all the values.
		my %return = %{$self->{$table_cache}{$id}};
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
	if ($self->{$table_cache}{$id}{is_future}) {
		delete $self->{$table_cache}{$id};
	}
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
		
		my $common_words = substr(join(" ", keys %common_words), 0, $maxlen);
		if (length($common_words) == $maxlen) {
			$common_words =~ s/\s+\S+\Z//;
		}
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
		push @where_clauses, "stories.title LIKE $word_q";
		push @where_clauses, "story_text.introtext LIKE $word_q";
		push @where_clauses, "story_text.bodytext LIKE $word_q";
	}
	$where = join(" OR ", @where_clauses);
	my $n_days = $constants->{similarstorydays} || 30;
	my $stories = $self->sqlSelectAllHashref(
		"sid",
		"stories.sid AS sid, title, introtext, bodytext,
			time, displaystatus",
		"stories, story_text",
		"stories.sid = story_text.sid $not_original_sid
		 AND stories.time >= DATE_SUB(NOW(), INTERVAL $n_days DAY)
		 AND ($where)"
	);
#print STDERR "similar stories: " . Dumper($stories);

	for my $sid (keys %$stories) {
		# Add up the weights of each story in turn, for how closely
		# they match with the current story.  Include a multiplier
		# based on the length of the match.
		my $s = $stories->{$sid};
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
	my $templates = $self->sqlSelectAll('tpid,name,page,section', 'templates');
	for (@$templates) {
		$cache{$_->[1], $_->[2], $_->[3]} = $_->[0];
	}
	return \%cache;
}

########################################################
sub existsTemplate {
	# if this is going to get called a lot, we already
	# have the template names cached -- pudge
	my($self, $template) = @_;
	my $answer = $self->sqlSelect('tpid', 'templates', "name = '$template->{name}' AND section = '$template->{section}' AND page = '$template->{page}'");
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
	my($self, $name, $values, $cache_flag, $page, $section, $ignore_errors) = @_;
	return if ref $name;	# no scalar refs, only text names
	my $constants = getCurrentStatic();
	_genericCacheRefresh($self, 'templates', $constants->{'block_expire'});

	my $table_cache = '_templates_cache';
	my $table_cache_time= '_templates_cache_time';
	my $table_cache_id= '_templates_cache_id';

	#First, we get the cache
	$self->{$table_cache_id} =
		($constants->{cache_enabled} || $constants->{cache_enabled_template})
			&& $self->{$table_cache_id}
		? $self->{$table_cache_id} : getTemplateNameCache($self);

	#Now, lets determine what we are after
	unless ($page) {
		$page = getCurrentUser('currentPage');
		$page ||= 'misc';
	}
	unless ($section) {
		$section = getCurrentUser('currentSection');
		$section ||= 'default';
	}

	#Now, lets figure out the id
	#name|page|section => name|page|default => name|misc|section => name|misc|default
	# That frat boy march with a paddle
	my $id = $self->{$table_cache_id}{$name, $page,  $section };
	$id  ||= $self->{$table_cache_id}{$name, $page,  'default'};
	$id  ||= $self->{$table_cache_id}{$name, 'misc', $section };
	$id  ||= $self->{$table_cache_id}{$name, 'misc', 'default'};
	if (!$id) {
		if (!$ignore_errors) {
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
			errorLog("Failed template lookup on '$name;$page\[misc\];$section\[default\]'"
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

	if (!$cache_flag && exists $self->{$table_cache}{$id} && keys %{$self->{$table_cache}{$id}}) {
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
sub getTopic {
	my $answer = _genericGetCache({
		table		=> 'topics',
		table_prime	=> 'tid',
		arguments	=> \@_,
	});
	return $answer;
}

########################################################
sub getSectionTopicType {
	my($self, $tid) = @_;

	return [] unless $tid;
	my $type = $self->sqlSelectAll('section,type', 'section_topics', "tid = $tid");

	return $type || [];
}

########################################################
sub getTopics {
	my $answer = _genericGetsCache('topics', 'tid', '', @_);

	return $answer;
}

########################################################
sub getTopicImage {
	my $answer = _genericGetCache({
		table		=> 'topic_images',
		table_prime	=> 'id',
		arguments	=> \@_,
	});

	return $answer;
}

########################################################
sub getTopicImageBySection {
	my($self, $topic, $section, $values, $cache) = @_;
	my $image_sections = $self->getDescriptions("topic_images_section");
	# Yes the hash lookup is right, review the getDescription call if you have questions
	my $image_id = $image_sections->{"$topic->{tid}|$section"} || $topic->{default_image};	
	my $answer = _genericGetCache({
		table		=> 'topic_images',
		table_prime	=> 'id',
		arguments	=> [($self,$image_id,$values,$cache)],
	});

	return $answer;
}

########################################################
# Brian, make this cache -Brian
sub getStoryTopicsJustTids {
	my($self, $sid, $options) = @_;
	return $self->{_story_topics}{$sid} if $self->{_story_topics}{$sid} && !$options->{no_parents};
	my $where = "1=1";
	$where .= " AND is_parent = 'no'" if $options->{no_parents};
	$where .= " AND sid = " . $self->sqlQuote($sid);
	my $answer = $self->sqlSelectColArrayref('tid', 'story_topics', $where);
	$self->{_story_topics}{$sid} = $answer;

	return  $answer;
}

########################################################
# add_names = 1, or any other non-zero/non-two value  -> Topic Alt text.
# add_names = 2 -> Topic Name.
sub getStoryTopics {
	my($self, $sid, $add_names) = @_;
	my($topicdesc);

	my $topics = $self->sqlSelectAll(
		'tid',
		'story_topics',
		'sid=' . $self->sqlQuote($sid)
	);

	# All this to avoid a join. :/
	#
	# Poor man's hash assignment from an array for the short names.
	$topicdesc =  {
		map { @{$_} }
		@{$self->sqlSelectAll(
			'tid, name',
			'topics'
		)}
	} if $add_names == 2;

	# We use a Description for the long names. 
	$topicdesc = $self->getDescriptions('topics') 
		if !$topicdesc && $add_names;

	my $answer;
	$answer->{$_->[0]} = $add_names && $topicdesc ? $topicdesc->{$_->[0]}:1
		for @{$topics};

	return $answer;
}

########################################################
# There are atomicity issues here if two admins click Update at
# the same time :) - Jamie 2003/05/13
sub setStoryTopics {
	my($self, $sid, $topic_ref) = @_;

	$self->sqlDo("DELETE from story_topics where sid = '$sid'");

	for my $key (sort keys %{$topic_ref}) {
		unless ($self->sqlInsert("story_topics", 
			{ sid => $sid, tid => $key, is_parent => $topic_ref->{$key} }
		)) {
			return 0;
		}
	}

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

########################################################
sub getSection {
	my($self, $section, $value, $no_cache) = @_;
	$section ||= getCurrentStatic('section');
	my $data = {
		table           => 'sections',
		table_prime     => 'section',
		arguments       => [($self, $section, $value)],
		col_table       => { label => 'contained', table => 'sections_contained', table_index => 'container', key => 'section'},
	};
	my $answer;
	if ($no_cache) {
		$answer = _genericGet($data);
	} else {
		$answer = _genericGetCache($data);
	}

	if (ref $answer) {
		# add rootdir, form figured dynamically -- pudge
		$answer->{rootdir} = set_rootdir(
			$answer->{url}, getCurrentStatic('rootdir')
		);
	}

	return $answer;
}

########################################################
sub getSubSection {
	my $answer = _genericGetCache({
		table		=> 'subsections',
		arguments	=> \@_,
	});
	return $answer;
}

########################################################
# Entire thing needs to be rewritten. Col tables need to
# be written into the Gets() methods. -Brian
sub getSections {
	my $answer = _genericGets('sections', 'section', '', @_);

	my $rootdir = getCurrentStatic('rootdir');
	for my $section (keys %$answer) {
		# add rootdir, form figured dynamically -- pudge
		$answer->{$section}{rootdir} = set_rootdir(
			$answer->{$section}{url}, $rootdir
		);
	}

	return $answer;
}

########################################################
sub getSubSections {
	my $answer = _genericGetsCache('subsections', 'id', '', @_);
	return $answer;
}

########################################################
sub getSubSectionsBySection {
	my($self, $section) = @_;

	my $answer = $self->sqlSelectAllHashrefArray(
		'*',
		'section_subsections, subsections',
		'section_subsections.section=' . $self->sqlQuote($section) . ' AND subsections.id = section_subsections.subsection'
	);

	return $answer;
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
		my $mcdkey = "$mcd->{keyprefix}u:";
		# The "1" means "don't accept new writes to this key for 1 second."
		$mcd->delete("$mcdkey$uid", 1);
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
	my $mcdkey = "$mcd->{keyprefix}u:" if $mcd;
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
				"uid=$uid_q")->{uid};
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
			print STDERR scalar(gmtime) . " $$ getUser answer: " . Dumper($answer);
		}
		if (!$val && $gtd->{all} && $gtd->{can_use_mcd}) {
			$self->_getUser_write_memcached($answer);
		}
		
	}

	# If no such user, we can return now.
	if (!$answer || !%$answer) {
		if ($mcddebug) {
			my $elapsed = sprintf("%6.4f", Time::HiRes::time - $start_time);
			print STDERR scalar(gmtime) . " $$ mcd getUser '$mcdkey$uid' elapsed=$elapsed no such user can '$gtd->{can_use_mcd}' rawmcdanswer: " . Dumper($rawmcdanswer);
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
			print STDERR scalar(gmtime) . " $$ mcd gU_ds got all acls\n";
		}
	} elsif (ref($params) eq 'ARRAY' && @$params) {
		my $param_list = join(",", map { $self->sqlQuote($_) } @$params);
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
		print STDERR scalar(gmtime) . " $$ mcd gU_ds params added to answer\n";
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
		print STDERR scalar(gmtime) . " $$ _getU_gtd cols_needed: " . ($cols_needed ? "'@$cols_needed'" : "(all)") . "\n";
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

	my $mcdkey = "$mcd->{keyprefix}u:";

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
			$self->sqlReplace($param_table, { $table_prime => $id, name => $_->[0], value => $_->[1] });
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
# You can use this to reset cache's in a timely
# manner :)
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
	my $col_table = $passed->{'col_table'};
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
			my $append = $self->sqlSelectAll('name,value', $param_table, "$table_prime=$id_db");
			for (@$append) {
				$answer->{$_->[0]} = $_->[1];
			}
			$answer->{$col_table->{label}} = $self->sqlSelectColArrayref($col_table->{key}, $col_table->{table}, "$col_table->{table_index}=$id_db")  
				if $col_table;
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
			$answer->{$col_table->{label}} = $self->sqlSelectColArrayref($col_table->{key}, $col_table->{table}, "$col_table->{table_index}=$id_db")  
				if $col_table;
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
					my $val = $self->sqlSelectAll("$table_prime, name, value", $param_table, "name='$_'");
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
				my $val = $self->sqlSelectAll("$table_prime, name, value", $param_table, "name=$values");
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
# single big select for ForumZilla ... if someone wants to
# improve on this, please go ahead
sub fzGetStories {
	my($self, $section) = @_;
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();

	my $section_where;
	if ($section) {
		my $section_dbi = $self->sqlQuote($section || '');
		$section_where = "(S.displaystatus>=0 AND S.section=$section_dbi) ";
	} elsif ($user->{sectioncollapse}) {
		$section_where = "S.displaystatus>=0 ";
	} else {
		$section_where = "S.displaystatus=0 ";
	}

# right now, we do not get lastcommentdate ... this is too big a drain
# on the server. -- pudge
#,MAX(comments.date) AS lastcommentdate
#LEFT OUTER JOIN comments ON discussions.id = comments.sid

# stories as S for when we did a join, keep in case we do another
# at some point -- pudge
	my $data = $slashdb->sqlSelectAllHashrefArray(<<S, <<F, <<W, <<E);
S.sid, S.title, S.time, S.commentcount
S
stories AS S
F
    time < NOW()
AND S.writestatus != 'delete' 
AND $section_where
W
GROUP BY S.sid
ORDER BY S.time DESC
LIMIT 10
E

	# note that LIMIT could be a var -- pudge
	return $data;
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
	for (qw| page name section |) {
		next unless $hash->{$_};
		if ($hash->{$_} =~ /;/) {
			errorLog("A semicolon was found in the $_ while trying to create a template");
			return;
		}
	}
	# Instructions field does not get passed to the DB.
	delete $hash->{instructions};
	# Neither does the version field (for now).
	delete $hash->{version};

	$self->sqlInsert('templates', $hash);
	my $tpid  = $self->getLastInsertId({ table => 'templates', prime => 'tpid' });
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
# for ubb_like_forums
sub getForumDescription {
	my($self, $forum_id) = @_;

	my $desc = $self->sqlSelect('comment', 'comments, comment_text', "comments.cid=comment_text.cid AND sid=$forum_id", 'ORDER BY comments.cid ASC LIMIT 1');

	return $desc;
}

########################################################
# for ubb_like_forums
sub getForumParents {
	my($self, $forum_id) = @_;

	my $num_parents = $self->sqlSelect('count(*)', 'comments', "sid=$forum_id AND pid=0");

	return $num_parents;
}

########################################################
# for ubb_like_forums
sub getForumFirstPostHashref {
	my($self, $forum_id) = @_;

	return $self->sqlSelectHashref("*", 'comments', "sid=$forum_id", 'ORDER BY comments.cid ASC LIMIT 1');
}

########################################################
# for ubb_like_forums
sub getForumLastPostHashref {
	my($self, $forum_id) = @_;

	return $self->sqlSelectHashref("*", 'comments', "sid=$forum_id", 'ORDER BY comments.cid DESC LIMIT 1');
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

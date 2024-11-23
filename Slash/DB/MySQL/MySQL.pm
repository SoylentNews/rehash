# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::DB::MySQL;

use strict;

use Socket;
use Digest::MD5 'md5_hex';
use Encode 'encode_utf8';
use Time::HiRes;
use Date::Calc qw(Add_Delta_Days Add_Delta_DHMS Add_Delta_YM Monday_of_Week Week_of_Year);
use Date::Format qw(time2str);
use DateTime ();
use Data::Dumper;
use Storable qw(thaw nfreeze);
use URI ();
use APR::SockAddr ();

use Slash::Utility;
use Slash::Constants ':messages';

use vars qw($_proxy_port);

use base 'Slash::DB';
use base 'Slash::DB::Utility';

our $VERSION = $Slash::Constants::VERSION;

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

	'story023'
		=> sub { $_[0]->sqlSelectMany('code,name', 'string_param', "type='story023'") },

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
		=> sub { $_[0]->sqlSelectMany('topics.tid AS tid,textname', 'topics LEFT JOIN topic_nexus ON topic_nexus.tid=topics.tid', "topic_nexus.tid IS NULL") },

	'highlighted-topics-submittable'
		=> sub { $_[0]->sqlSelectMany('topics.tid AS tid, IF(topic_nexus.tid IS NULL, textname, CONCAT("*",textname))', 'topics LEFT JOIN topic_nexus ON topic_nexus.tid=topics.tid', "submittable='yes'") },


	'non_nexus_topics-submittable'
		=> sub { $_[0]->sqlSelectMany('topics.tid AS tid,textname', 'topics LEFT JOIN topic_nexus ON topic_nexus.tid=topics.tid', "topic_nexus.tid IS NULL AND submittable='yes'") },


	'non_nexus_topics-storypickable'
		=> sub { $_[0]->sqlSelectMany('topics.tid AS tid,textname', 'topics LEFT JOIN topic_nexus ON topic_nexus.tid=topics.tid', "topic_nexus.tid IS NULL AND storypickable='yes'") },


	'nexus_topics'
		=> sub { $_[0]->sqlSelectMany('topics.tid AS tid,textname', 'topics, topic_nexus', 'topic_nexus.tid=topics.tid') },

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
		=> sub { $_[0]->sqlSelectMany('code,name', 'string_param', "type='commentcodes'") },

	'commentcodes_extended'
		=> sub { $_[0]->sqlSelectMany('code,name', 'string_param', "type='commentcodes' OR type='commentcodes_extended'") },

	'skins'
		=> sub { $_[0]->sqlSelectMany('skid,title', 'skins') },

	'skins-all'
		=> sub { $_[0]->sqlSelectMany('skid,title', 'skins') },

	'skins-submittable'
		=> sub { $_[0]->sqlSelectMany('skid,title', 'skins', "submittable='yes'") },

	'skins-searchable'
		=> sub { $_[0]->sqlSelectMany('skid,title', 'skins', "searchable='yes'") },

	'skins-storypickable'
		=> sub { $_[0]->sqlSelectMany('skid,title', 'skins', "storypickable='yes'") },

	'topics-submittable'
		=> sub { $_[0]->sqlSelectMany('tid,textname', 'topics', "submittable='yes'") },

	'topics-searchable'
		=> sub { $_[0]->sqlSelectMany('tid,textname', 'topics', "searchable='yes'") },

	'topics-storypickable'
		=> sub { $_[0]->sqlSelectMany('tid,textname', 'topics', "storypickable='yes'") },

	'static_block'
		=> sub { $_[0]->sqlSelectMany('bid,bid', 'blocks', "$_[2] >= seclev AND type != 'portald' AND shill = 'no'") },

	'portald_block'
		=> sub { $_[0]->sqlSelectMany('bid,bid', 'blocks', "$_[2] >= seclev AND type = 'portald' AND shill = 'no'") },

	'static_block_section'
		=> sub { $_[0]->sqlSelectMany('bid,bid', 'blocks', "$_[2]->{seclev} >= seclev AND section='$_[2]->{section}' AND type != 'portald' AND shill = 'no'") },

	'portald_block_section'
		=> sub { $_[0]->sqlSelectMany('bid,bid', 'blocks', "$_[2]->{seclev} >= seclev AND section='$_[2]->{section}' AND type = 'portald' AND shill = 'no'") },

	'color_block'
		=> sub { $_[0]->sqlSelectMany('bid,bid', 'blocks', "type = 'color' AND shill = 'no'") },

	'authors'
		=> sub { $_[0]->sqlSelectMany('uid,nickname', 'authors_cache', "author = 1") },

	'authors_recent'
		=> sub { $_[0]->sqlSelectMany('authors_cache.uid,authors_cache.nickname', 'authors_cache,stories','author=1 and authors_cache.uid=stories.uid AND stories.time >= DATE_SUB(NOW(), INTERVAL 6 MONTH)','GROUP BY authors_cache.uid') },

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

	'countries'
		=> sub { $_[0]->sqlSelectMany(
				'code,CONCAT(code," (",name,")") as name',
				'string_param',
				'type="iso_countries"',
				'ORDER BY name'
			);
		},

	'us_states'
		=> sub { $_[0]->sqlSelectMany(
				'code,CONCAT(code," (",name,")") as name',
				'string_param',
				'type="us_states"',
				'ORDER BY name'
			);
		},

	'ca_provinces'
		=> sub { $_[0]->sqlSelectMany(
				'code,CONCAT(code," (",name,")") as name',
				'string_param',
				'type="ca_provinces"',
				'ORDER BY name'
			);
		},

	'states_and_provinces'
		=> sub { $_[0]->sqlSelectMany(
				'code,CONCAT(code," (",name,")") as name',
				'string_param',
				'type="ca_provinces" OR type="us_states"',
				'ORDER BY name'
			);
		},

	'forums'
		=> sub { $_[0]->sqlSelectMany('subsections.id, subsections.title', 'section_subsections, subsections', "section_subsections.subsection=subsections.id AND section_subsections.section='forums'") },

	'discussion_kinds'
		=> sub { $_[0]->sqlSelectMany('dkid, name', 'discussion_kinds') },

	'd2_comment_q'
		=> sub { $_[0]->sqlSelectMany('code, name', 'code_param', "type='d2_comment_q' AND code != 0") },

	'd2_comment_q_all'
		=> sub { $_[0]->sqlSelectMany('code, name', 'code_param', "type='d2_comment_q'") },

	'd2_comment_limits'
		=> sub { $_[0]->sqlSelectMany('code, name', 'code_param', "type='d2_comment_limits'") },

	'd2_comment_order'
		=> sub { $_[0]->sqlSelectMany('code, name', 'code_param', "type='d2_comment_order'") },
	'mediatypes'
		=> sub { $_[0]->sqlSelectMany('code, name', 'string_param', "type='mediatypes'")}
);

########################################################
sub _whereFormkey {
	my($self, $options) = @_;

	my $ipid = getCurrentUser('ipid');
	my $uid = getCurrentUser('uid');
	my $where;

	# anonymous user without cookie, check host, not ipid
	if (isAnon($uid) || $options->{force_ipid}) {
		$where = "ipid = '$ipid'";
	} else {
		$where = "uid = '$uid'";
	}

	return $where;
};

########################################################

# XXX I'm pretty sure these next 3 methods can be eliminated
# from the code. Or, they can actually be written properly and
# everyplace we do sqlDo("AUTOCOMMIT=0") we can use these
# instead.  Of course the Finish/Cancel would do
# COMMIT/ROLLBACK. - Jamie, August 2006

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
sub getBadgeDescriptions {
	my($self) = @_;
	return $self->{_badge_cache} ||= $self->sqlSelectAllHashref(
		'badge_id', 'badge_id,badge_icon,badge_text,badge_url', 'badge_ids'
	);
}

########################################################
sub createComment {
	my($self, $comment) = @_;
	return -1 unless dbAvailable("write_comments");
	my $constants = getCurrentStatic();
	my $comment_text = $comment->{comment};
	delete $comment->{comment};
	$comment->{signature} = md5_hex( encode_utf8($comment_text) );
	$comment->{-date} = 'NOW()';
	$comment->{len} = length($comment_text);
	$comment->{pointsorig} = $comment->{points} || 0;
	$comment->{pointsmax}  = $comment->{points} || 0;

	$comment->{sid} = $self->getStoidFromSidOrStoid($comment->{sid})
		or return -1;

	if ($comment->{pid}) {
		# If we're being asked to parent^Wchild this comment to another,
		# verify that the other comment exists and is in this
		# same discussion.
		my $pid_sid = 0;
		my $pid_q = $self->sqlQuote($comment->{pid});
		$pid_sid = $self->sqlSelect('sid', 'comments', "cid=$pid_q");
		return -1 unless $pid_sid && $pid_sid == $comment->{sid};

		my $pid_subject = '';
		$pid_subject = $self->sqlSelect("subject", "comments",
			"cid=" . $self->sqlQuote($comment->{pid}));

		# Set the opid to parent's opid unless parent is the op, in which case set it to this comment's pid
		my $pid_opid = $self->sqlSelect("opid", "comments", "cid=" . $self->sqlQuote($comment->{pid}));
		$comment->{opid} = $pid_opid ? $pid_opid : $comment->{pid};

		# see comments.pl:editComment()
		$pid_subject =~ s/^Re://i;
		$pid_subject =~ s/\s\s/ /g;
		if (length $pid_subject &&
			$comment->{subject} =~ /^Re:\Q$pid_subject\E$/) {
			$comment->{subject_orig} = 'no';
		}
	}
	# If we didn't have a pid, we are the op
	else {
		$comment->{opid} = 0;
	}

	$comment->{subject} = $self->truncateStringForCharColumn($comment->{subject},
		'comments', 'subject');

	$comment->{badge_id} = 0;
	my $user_comm = $self->getUser($comment->{uid});
	$comment->{badge_id} = $user_comm->{acl}{employee} && $user_comm->{badge_id}
		? $user_comm->{badge_id}
		: 0;

	$self->sqlDo("SET AUTOCOMMIT=0");

	my $cid;
	if ($self->sqlInsert('comments', $comment)) {
		$cid = $self->getLastInsertId();
	} else {
		$self->sqlDo("ROLLBACK");
		$self->sqlDo("SET AUTOCOMMIT=1");
		errorLog("$DBI::errstr");
		return -1;
	}

	unless ($self->sqlInsert('comment_text', {
		cid	=> $cid,
		comment	=> $comment_text,
	})) {
		$self->sqlDo("ROLLBACK");
		$self->sqlDo("SET AUTOCOMMIT=1");
		errorLog("$DBI::errstr");
		return -1;
	}
	
	# Now we need to update the children counts of all this comment's parents unless this is a top level comment
	if($comment->{opid}) {
		# For now just write the error to the log if we fail.
		# Children counts are useful not crucial.
		my $update_children_status = $self->updateChildrenCounts($comment->{pid});
		if( $update_children_status->{status} == 0 ) {
			errorLog("$update_children_status->{errortxt}");
		}
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
		$self->sqlDo("ROLLBACK");
		$self->sqlDo("SET AUTOCOMMIT=1");
		errorLog("$DBI::errstr");
		return -1;
	}

	$self->sqlDo("COMMIT");
	$self->sqlDo("SET AUTOCOMMIT=1");

	return $cid;
}

sub createCommentLog {
	my($self, $data) = @_;
	$data->{'-ts'} = "NOW()";
	$self->sqlInsert("comment_log", $data);
}

sub getRecentCommentLog {
	my($self, $options) = @_;
	$self->sqlSelectAllHashrefArray("*", "comment_log, comments",
		"comment_log.cid=comments.cid", "ORDER BY ts DESC LIMIT 100"
	); 
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

sub getCSSValuesHashForCol {
	my($self, $col) = @_;
	my $values = $self->sqlSelectColArrayref($col, 'css', '', '', { distinct => 1 });
	my $result = { map { $_ => 1 } @$values };
	return $result;
}

sub getCSS {
	my($self, $layout) = @_;
	my $user = getCurrentUser();
	my $page = $user->{currentPage};
	my $skin = getCurrentSkin('name');
	my $admin = $user->{is_admin};
	my $theme = ($user->{simpledesign} || $user->{pda}) ? "light" : $user->{css_theme};
	my $secure = apacheConnectionSSL();
	$layout ||= '';
	my $constants = getCurrentStatic();

	my $expire_time = $constants->{css_expire} || 3600;
	$expire_time += int(rand(60)) if $expire_time;
	_genericCacheRefresh($self, 'css', $expire_time);
	_genericCacheRefresh($self, 'css_pages', $expire_time);
	_genericCacheRefresh($self, 'css_skins', $expire_time);
	_genericCacheRefresh($self, 'css_themes', $expire_time);

	my $css_ref 	 	= $self->{_css_cache} ||= {};
	my $css_pages_ref	= $self->{_css_pages_cache};
	my $css_skins_ref	= $self->{_css_skins_cache};
	my $css_themes_ref	= $self->{_css_themes_cache};
	my $css_layouts_ref	= $self->{_css_layouts_cache};

	$css_pages_ref = $self->getCSSValuesHashForCol('page') if !$css_pages_ref;
	$css_skins_ref = $self->getCSSValuesHashForCol('skin') if !$css_skins_ref;
	$css_themes_ref = $self->getCSSValuesHashForCol('theme') if !$css_themes_ref;
	$css_layouts_ref = $self->getCSSValuesHashForCol('layout') if !$css_layouts_ref;

	my $lowbandwidth = ($user->{lowbandwidth} || $user->{pda}) ? "yes" : "no";

	$page   = '' if !$css_pages_ref->{$page};
	$skin   = '' if !$css_skins_ref->{$skin};
	$theme  = '' if !$css_themes_ref->{$theme};
	$layout = '' if !$css_layouts_ref->{$layout};

	return $css_ref->{$skin}{$page}{$admin}{$theme}{$lowbandwidth}{$layout}{$secure}
		if exists $css_ref->{$skin}{$page}{$admin}{$theme}{$lowbandwidth}{$layout}{$secure};

	my @clauses;

	my $page_q = $self->sqlQuote($page);
	my $page_in = $page ? "(page = '' or page = $page_q)" : "page = ''";
	push @clauses, $page_in;

	my $skin_in = $skin ? "(skin = '' or skin = '$skin')" : "skin = ''";
	push @clauses, $skin_in;

	push @clauses, "admin='no'" if !$admin;

	my $theme_q  = $self->sqlQuote($theme);
	my $theme_in = $theme ? "(theme='' or theme=$theme_q)" : "theme=''";
	push @clauses, $theme_in;

	push @clauses, "lowbandwidth='$lowbandwidth'" if $lowbandwidth eq "no";

	my $layout_q = $self->sqlQuote($layout);
	push @clauses, "layout=$layout_q";

	my $where = "css.ctid=css_type.ctid AND ";
	$where .= join ' AND ', @clauses;

	my $css = $self->sqlSelectAllHashrefArray("rel,type,media,file,title,ie_cond,skin",
		"css, css_type", $where, "ORDER BY css_type.ordernum, css.ordernum");
	# MC: We don't really need different CSS for SSL do we?
	#if ($secure) {
	#	for my $hr (@$css) { $hr->{file} =~ s/\.css/.ssl.css/ }
	#}
	
	$css_ref->{$skin}{$page}{$admin}{$theme}{$lowbandwidth}{$layout}{$secure} = $css;
	return $css;
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
sub getTopicParam {
	my($self, $tid_wanted, $val, $force_cache_freshen) = @_;
	my $constants = getCurrentStatic();
	my $table_cache		= "_topicparam_cache";
	my $table_cache_time	= "_topicparam_cache_time";

	return undef unless $tid_wanted;

	_genericCacheRefresh($self, 'topicparam', $constants->{block_expire});

	my $is_in_local_cache = exists $self->{$table_cache}{$tid_wanted};
	my $use_local_cache = $is_in_local_cache && !$force_cache_freshen;

	if (!$is_in_local_cache || $force_cache_freshen) {
		my $tid_clause = "tid=".$self->sqlQuote($tid_wanted);
		my $params = $self->sqlSelectAllKeyValue('name,value', 'topic_param', $tid_clause);
		$self->{$table_cache_time} = time() if !$self->{$table_cache_time};
		$self->{$table_cache}{$tid_wanted} = $params;
	}
	my $hr = $self->{$table_cache}{$tid_wanted};
	my $retval;
	if ($val && !ref $val) {
		if (exists $hr->{$val}) {
			$retval = $hr->{$val};
		}
	} else {
		my %return = %$hr;
		$retval = \%return;
	}
	return $retval;
}

########################################################
# If no tid is given, returns the whole tree.  Otherwise,
# returns the data for the topic with that numeric id.
#
# Feb 2005 - Topic params no longer kept in tree, should
# be fetched with getTopicParam
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
	if (my $regex = $constants->{debughash_getTopicTree}) {
		$tree_ref = debugHash($regex, $tree_ref) unless tied($tree_ref);
	}

	my $topics = $self->sqlSelectAllHashref("tid", "*", "topics");
	my $topic_nexus = $self->sqlSelectAllHashref("tid", "*", "topic_nexus");
	my $topic_nexus_dirty = $self->sqlSelectAllHashref("tid", "*", "topic_nexus_dirty");
	my $topic_parents = $self->sqlSelectAllHashrefArray("*", "topic_parents");

	for my $tid (keys %$topics) {
		$tree_ref->{$tid} = $topics->{$tid};
		$tree_ref->{$tid}{submittable} = $topics->{$tid}{submittable} eq "yes" ? 1 : 0;
		$tree_ref->{$tid}{searchable} = $topics->{$tid}{searchable} eq "yes" ? 1 : 0;
		$tree_ref->{$tid}{storypickable} = $topics->{$tid}{storypickable} eq "yes" ? 1 : 0;
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
		if (exists $tree_ref->{$tid}{child}) {
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
		if (exists $tree_ref->{$tid}{parent}) {
			my $p_hr = $tree_ref->{$tid}{parent};
			my @parent_ids = sort {
				$tree_ref->{$a}{textname} cmp $tree_ref->{$b}{textname}
				||
				$tree_ref->{$a}{keyword} cmp $tree_ref->{$b}{keyword}
				||
				$a <=> $b
			} keys %$p_hr;
			$tree_ref->{$tid}{parents} = [ @parent_ids ];
		}
	}

	my $skins = $self->getSkins();
	for my $skid (keys %$skins) {
		next unless $skins->{$skid}{nexus};
		$tree_ref->{$skins->{$skid}{nexus}}{skid} = $skid;
	}

	$self->confirmTopicTree($tree_ref);

	$self->{$table_cache} = $tree_ref;
	$self->{$table_cache_time} = time;
	if ($tid_wanted) {
		return $tree_ref->{$tid_wanted} || undef;
	} else {
		return $tree_ref;
	}
}

########################################################
# Given a topic tree, check it for loops (trees should not have
# loops).  Die if there's an error.
sub confirmTopicTree {
	my($self, $tree) = @_;

	# First, get the "central tree."  This is the tree that excludes
	# recursively all leaf nodes.  A leaf node is a topic which
	# has fewer than two other topics attached to it.  Such a node
	# obviously cannot be part of any loop.	By removing the outer
	# layer so to speak of such topics, then repeating the removal
	# until the tree does not change, we are left with a smaller
	# tree (possibly empty) which will be faster to check for loops.
	# For example, if a tree consists of A->B->C, the first pass
	# will strip off A and C since they have only one node connecting
	# to a non-leaf;  the second pass strips off B since it now has
	# zero nodes connecting to non-leafs.

#my $start_time = Time::HiRes::time;
	my $n_tree_keys = scalar(keys %$tree);
	my %leaf = ( );
	while (1) {
		my $n_start_leaf_keys = scalar(keys %leaf);
#print STDERR scalar(keys %leaf) . " leaf keys START: " . join(" ", sort { $a <=> $b } keys %leaf) . "\n";
		for my $tid (sort { $a <=> $b } keys %$tree) {
			next if $leaf{$tid};
			my $links = 0;
			my @parents = ( ); my @children = ( );
			if ($tree->{$tid}{parents}) {
				@parents = grep { !$leaf{$_} } @{ $tree->{$tid}{parents} };
				$links += scalar @parents;
			}
			if ($tree->{$tid}{children}) {
				@children = grep { !$leaf{$_} } @{ $tree->{$tid}{children} };
				$links += scalar @children;
			}
#print STDERR "tid $tid has $links non-leaf: parents '@parents' children '@children'\n";
			if ($links < 2) {
				$leaf{$tid} = 1;
			}
		}
#print STDERR scalar(keys %leaf) . " leaf keys END: " . join(" ", sort { $a <=> $b } keys %leaf) . "\n";
		# If that didn't turn up any new leaf nodes, or if
		# that's the whole tree, we've found them all.
		last if scalar(keys %leaf) == $n_start_leaf_keys
			|| scalar(keys %leaf) == $n_tree_keys;
	}

#print STDERR scalar(localtime) . " tree " . scalar(keys %$tree) . " nodes, of which " . scalar(keys %leaf) . " are leaf nodes\n";

	# If the entire tree is made up of leaf nodes, we're done already.
	return 1 if scalar(keys %leaf) == scalar(keys %$tree);

	# We walk the remaining tree recursively.  First scanning down for
	# children, then up for parents.  Along the way, we mark vetted
	# topics, as they are vetted, in the $vetted hashref.
	sub _vet_node_children {
		my($tree, $leaf, $vetted, $tid, $parents) = @_;
		return if $vetted->{$tid};
		if ($parents->{$tid}) {
			die "Topic tree error: loop found at tid $tid, parents "
				. join(" ", sort { $a <=> $b } keys %$parents );
		}
		return unless $tree->{$tid}{children};
		my @children = grep { !$leaf->{$_} && !$vetted->{$_} } @{ $tree->{$tid}{children} };
		for my $child (@children) {
			my %parents_copy = %$parents;
			$parents_copy{$tid} = 1;
#print STDERR "tid $tid child-recursing down to $child with parents: " . join(" ", sort { $a <=> $b } keys %parents_copy ) . "\n";
			_vet_node_children($tree, $leaf, $vetted, $child, \%parents_copy);
		}
#print STDERR "vetted for children: $tid (parents: " . join(" ", sort { $a <=> $b } keys %$parents ) . ")\n";
		$vetted->{$tid} = 1;
	}
	sub _vet_node_parents {
		my($tree, $leaf, $vetted, $tid, $children) = @_;
		return if $vetted->{$tid};
		if ($children->{$tid}) {
			die "Topic tree error: loop found at tid $tid, children "
				. join(" ", sort { $a <=> $b } keys %$children );
		}
		return unless $tree->{$tid}{parents};
		my @parents = grep { !$leaf->{$_} && !$vetted->{$_} } @{ $tree->{$tid}{parents} };
		for my $parent (@parents) {
			my %children_copy = %$children;
			$children_copy{$tid} = 1;
#print STDERR "tid $tid parent-recursing up to $parent with children: " . join(" ", sort { $a <=> $b } keys %children_copy ) . "\n";
			_vet_node_parents($tree, $leaf, $vetted, $parent, \%children_copy);
		}
#print STDERR "vetted for parents: $tid (children: " . join(" ", sort { $a <=> $b } keys %$children ) . ")\n";
		$vetted->{$tid} = 1;
	}
	my %vetted_children = ( );
	my %vetted_parents = ( );
	for my $tid (sort { $a <=> $b } grep { !$leaf{$_} } keys %$tree) {
#print STDERR "BEGIN vetting $tid (" . scalar(keys %vetted_children) . " vetted children, " . scalar(keys %vetted_parents) . " vetted parents)\n";
		_vet_node_children($tree, \%leaf, \%vetted_children, $tid, { });
		_vet_node_parents($tree, \%leaf, \%vetted_parents, $tid, { });
	}

#print STDERR sprintf("%s tree vetted in %0.6f secs\n", scalar(localtime), Time::HiRes::time - $start_time);

	return 1;
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
# Starting with $start_tid, which may or may not be a nexus,
# walk up all its parent topics and return their tids.
# Note that the original tid, $start_tid, is not itself returned.
sub getAllParentsTids {
	my($self, $start_tid) = @_;
	my $tree = $self->getTopicTree();
	my %all_parents = ( );
	my @cur_parents = ( $start_tid );
	my %grandparents;
	while (@cur_parents) {
		%grandparents = ( );
		for my $parent (@cur_parents) {
			# This topic is a nexus, and a parent of the
			# start nexus.  Note it so it gets returned.
			$all_parents{$parent} = 1;
			# Now walk through all its parents, marking
			# nexuses as grandparents that must be
			# walked through on the next pass.
			for my $gparent (keys %{$tree->{$parent}{parent}}) {
				$grandparents{$gparent} = 1;
			}
		}
		@cur_parents = keys %grandparents;
	}
	delete $all_parents{$start_tid};
	return sort { $a <=> $b } keys %all_parents;
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
				# skip if the min_weight from this parent to
				# this child is negative (indicating the
				# child topic _forbids_ the parent topic)
				next if $tree->{$child}{child}{$gchild} < 0;
				# only add nexus topics
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
# Returns a boolean indicating whether it would be safe to add
# a new topic with parent and child tids as specified.  "Safe"
# means there would be no loops;  if false is returned, the
# topic must not be added because it would introduce loops.
# Works for any combination of parent/child tids including
# none of either or both (in which case it's always safe).
sub wouldBeSafeToAddTopic {
	my($self, $parent_tids_ar, $child_tids_ar) = @_;
	return 1 if !$parent_tids_ar || !$child_tids_ar
		|| !@$parent_tids_ar || !@$child_tids_ar;
	my %all_new_parents = ( );
	for my $parent (@$parent_tids_ar) {
		$all_new_parents{$parent} = 1;
		my @new_parents = $self->getAllParentsTids($parent);
		for my $gparent (@new_parents) {
			$all_new_parents{$gparent} = 1;
		}
	}
	my %all_new_children = ( );
	for my $child (@$child_tids_ar) {
		$all_new_children{$child} = 1;
		my @new_children = $self->getAllChildrenTids($child);
		for my $gchild (@new_children) {
			$all_new_children{$gchild} = 1;
		}
	}
	# If the intersection of all the new parents and all the new
	# children contains at least one topic, then it's unsafe.
	for my $child (keys %all_new_children) {
		return 0 if $all_new_parents{$child};
	}
	# Otherwise, it's safe.
	return 1;
}

########################################################
# Returns a boolean indicating whether it would be safe to add
# a parent<->child link between two topics (i.e. add a row to
# the topic_parents table).  "Safe" means there would be no
# loops;  if false is returned, the link must not be added
# because it would introduce loops.
sub wouldBeSafeToAddTopicLink {
	my($self, $parent_tid, $child_tid) = @_;

	return 0 if !$parent_tid || !$child_tid || $parent_tid == $child_tid;

	my %all_parents = ( $parent_tid, 1 );
	my @new_parents = $self->getAllParentsTids($parent_tid);
	for my $parent (@new_parents) {
		$all_parents{$parent} = 1;
	}

	my %all_children = ( $child_tid, 1 );
	my @new_children = $self->getAllChildrenTids($child_tid);
	for my $child (@new_children) {
		$all_children{$child} = 1;
	}

	# If there are any topics which are both a child of the
	# child and a parent of the parent (or if the child and
	# parent are already parent and child!) then there's a
	# loop.
	for my $tid (keys %all_children) {
		return 0 if $all_parents{$tid};
	}
	# Otherwise, it's safe.
	return 1;
}

########################################################
sub deleteRelatedLink {
	my($self, $id) = @_;

	$self->sqlDelete("related_links", "id=$id");
}

########################################################
sub getNexusExtras {
	my($self, $tid, $options) = @_;
	return [ ] unless $tid;
	$options ||= {};

	my $content_type = $options->{content_type} || "story";
	my $content_type_q = $self->sqlQuote($content_type);

	my $content_type_clause = "";
	$content_type_clause = " AND content_type = $content_type_q " if $content_type ne "all";

	my $tid_q = $self->sqlQuote($tid);
	my $answer = $self->sqlSelectAll(
		'extras_textname, extras_keyword, type, content_type, required, ordering, extras_id',
		'topic_nexus_extras',
		"tid = $tid_q $content_type_clause ",
		"ORDER by ordering, extras_id"
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
	my($self, $chosen_hr, $options) = @_;
	return [ ] unless $chosen_hr;
	$options ||= {};
	$options->{content_type} ||= "story";

	my $nexuses = $self->getNexuslistFromChosen($chosen_hr);
	my $seen_extras = {};
	my $extras = [ ];
	my $index = 0;
	for my $nexusid (@$nexuses) {
		my $ex_ar = $self->getNexusExtras($nexusid, $options);
		foreach my $extra (@$ex_ar) {
			unless (defined $seen_extras->{$extra->[1]}) {
				push @$extras, $extra;
				$seen_extras->{$extra->[1]}++;
			} elsif ($extra->[4] eq "yes"){
				$extras->[$seen_extras->{$extra->[1]}] = "yes";
			}
			$index++;
		}
	}

	return $extras;
}

sub createNexusExtra {
	my($self, $tid, $extra) = @_;
	$extra ||= {};
	return unless $tid && $extra->{extras_keyword};

	$extra->{tid} = $tid;
	$extra->{type}          ||= "text";
	$extra->{content_type}  ||= "story";
	$extra->{required}      ||= "no";

	$self->sqlInsert("topic_nexus_extras", $extra);
}

sub updateNexusExtra {
	my($self, $extras_id, $extra) = @_;
	return unless $extras_id && $extra;

	$extra->{type}          ||= "text";
	$extra->{content_type}  ||= "story";
	$extra->{required}      ||= "no";

	my $extras_id_q = $self->sqlQuote($extras_id);
	$self->sqlUpdate("topic_nexus_extras", $extra, "extras_id = $extras_id_q");
}

sub deleteNexusExtra {
	my($self, $extras_id) = @_;
	return unless $extras_id;
	my $extras_id_q = $self->sqlQuote($extras_id);
	$self->sqlDelete('topic_nexus_extras', "extras_id = $extras_id_q");
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

########################################################
sub createSubmission {
	my($self, $submission) = @_;

	return unless $submission;

	my $constants = getCurrentStatic();
	my $data;
	$data->{story} = delete $submission->{story} || '';
	$data->{subj} = delete $submission->{subj} || '';
	$data->{subj} = $self->truncateStringForCharColumn($data->{subj}, 'submissions', 'subj');
	$data->{comment} = delete $submission->{comment} || '';
	$data->{dept} = delete $submission->{dept} || '';
	$data->{dept} = $self->truncateStringForCharColumn($data->{dept}, 'submissions', 'dept');
	$data->{ipid} = getCurrentUser('ipid');
	$data->{subnetid} = getCurrentUser('subnetid');
	$data->{email} = delete $submission->{email} || '';
	$data->{email} = $self->truncateStringForCharColumn($data->{email}, 'submissions', 'email');
	$data->{emaildomain} = email_to_domain($data->{email});
	$data->{emaildomain} = $self->truncateStringForCharColumn($data->{emaildomain}, 'submissions', 'emaildomain');
	$data->{uid} = delete $submission->{uid} || getCurrentStatic('anonymous_coward_uid');
	$data->{'-time'} = delete $submission->{'time'};
	$data->{'-time'} ||= 'NOW()';
	$data->{primaryskid} = delete $submission->{primaryskid} || $constants->{mainpage_skid};
	$data->{tid} = delete $submission->{tid} || $constants->{mainpage_skid};
	# To help cut down on duplicates generated by automated routines. For
	# crapflooders, we will need to look into an alternate methods.
	# Filters of some sort, maybe?
	my $md5_sig = $data->{story} . $data->{subj};
	$data->{signature} = md5_hex( encode_utf8($md5_sig) );

	$self->sqlInsert('submissions', $data);
	my $subid = $self->getLastInsertId;

	# The next line makes sure that we get any section_extras in the DB - Brian
	$self->setSubmission($subid, $submission) if $subid && keys %$submission;

	return $subid;
}

########################################################
# this is just for tracking what admins are currently looking at,
# and when they last accessed the site
sub getSessionInstance {
	my($self, $uid) = @_;

	my $admin_timeout = getCurrentStatic('admin_timeout');

	$self->sqlDelete("sessions",
		"NOW() > DATE_ADD(lasttime, INTERVAL $admin_timeout MINUTE)"
	);

	my($lasttitle, $last_sid, $last_subid, $last_fhid, $last_action) = $self->sqlSelect(
		'lasttitle, last_sid, last_subid, last_fhid, last_action',
		'sessions',
		"uid=$uid"
	);

	if(!$lasttitle) {
	$self->sqlReplace('sessions', {
		-uid		=> $uid,
		lasttitle	=> $lasttitle    || '',
		last_sid	=> $last_sid     || '',
		last_subid	=> $last_subid   || '0',
		last_fhid	=> $last_fhid	 || '0',
		last_action	=> $last_action	 || '',
	});
	}
}

########################################################
sub getLastSessionText {
	my($self, $uid) = @_;
	my $uid_q = $self->sqlQuote($uid);
	return $self->sqlSelect("lasttitle", "sessions", "uid=$uid_q", "ORDER BY lasttime DESC LIMIT 1");
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
	return if !dbAvailable('write_accesslog');
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $r = Apache2::RequestUtil->request;
	my $bytes = $r->bytes_sent;

	$user ||= {};
	$user->{state} ||= {};

	return if $op eq 'css' && $constants->{accesslog_css_skip};

	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	if ($op =~ /^(?:image|css|js)$/ && $constants->{accesslog_imageregex}) {
		return if $constants->{accesslog_imageregex} eq 'NONE';
		my $uri = $r->uri;
		return unless $uri =~ $constants->{accesslog_imageregex};
		$dat ||= $uri;
	}

	return if $op eq 'slashdot-it'
		&& ( !$constants->{slashdotit_accesslog}
			|| ( $constants->{slashdotit_accesslog} < 1
				&& rand() > $constants->{slashdotit_accesslog} ) );

	my $uid = $user->{uid} || $constants->{anonymous_coward_uid};
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

	my $duration;
	if ($Slash::Apache::User::request_start_time) {
		$duration = Time::HiRes::time - $Slash::Apache::User::request_start_time;
		$Slash::Apache::User::request_start_time = 0;
		$duration = 0 if $duration < 0; # sanity check
	} else {
		$duration = 0;
	}
	my $pagemark = $user->{state}{pagemark} || 0;
	$pagemark = 0 if $op =~ /^ajax/;
	my $local_addr = $r->connection()->local_addr->ip_get;
	$status ||= $r->status;
	my $skid = $reader->getSkidFromName($skin_name);

	my $query_string = $ENV{QUERY_STRING} || 'none';
	my $referrer     = $r->headers_in->get("Referer");
	if (!$referrer && $query_string =~ /\bfrom=(\w+)\b/) {
		$referrer = $1;
	}

	my $insert = {
		host_addr	=> $ipid,
		subnetid	=> $subnetid,
		dat		=> $dat,
		uid		=> $uid,
		skid		=> $skid,
		bytes		=> $bytes,
		op		=> $op,
		-ts		=> 'NOW()',
		query_string	=> $self->truncateStringForCharColumn($query_string, 'accesslog', 'query_string'),
		user_agent	=> $ENV{HTTP_USER_AGENT} ? $self->truncateStringForCharColumn($ENV{HTTP_USER_AGENT}, 'accesslog', 'user_agent') : 'undefined',
		duration	=> $duration,
		pagemark	=> $pagemark,
		local_addr	=> $local_addr,
		static		=> $user->{state}{_dynamic_page} ? 'no' : 'yes',
		secure		=> $user->{state}{ssl} || 0,
		referer		=> $referrer,
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
	return if !dbAvailable('write_accesslog');
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
	return if !dbAvailable('write_accesslog');
	return if $op =~ /^images?$/;
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $r = Apache2::RequestUtil->request;

	# $ENV{SLASH_USER} wasn't working, was giving us some failed inserts
	# with uid NULL.
	my $uid = $user->{uid};
	my $gSkin = getCurrentSkin();
	errorLog("gSkin is empty") unless $gSkin;
	my $skid = $gSkin->{skid} || 0;
	# And just what was the admin doing? -Brian
	$op = $form->{op} if $form->{op};
	$status ||= $r->status;
	my $form_freeze = nfreeze($form);
	##########
	#	TMB: logs are in the db, db can handle unicode
	my $form_insert = '';
	if($form_freeze) {
		$form_insert = $self->truncateStringForCharColumn($form_freeze, 'accesslog_admin', 'form');
	}
	##########

	$self->sqlInsert('accesslog_admin', {
		host_addr	=> $r->connection->remote_ip,
		dat		=> $dat,
		uid		=> $uid,
		skid		=> $skid,
		bytes		=> $r->bytes_sent,
		op		=> $op,
		form		=> $form_insert,
		-ts		=> 'NOW()',
		query_string	=> $ENV{QUERY_STRING} ? $self->truncateStringForCharColumn($ENV{QUERY_STRING}, 'accesslog_admin', 'query_string') : '0',
		user_agent	=> $ENV{HTTP_USER_AGENT} ? $self->truncateStringForCharColumn($ENV{HTTP_USER_AGENT}, 'accesslog_admin', 'user_agent') : 'undefined',
		secure		=> Slash::Apache::ConnectionIsSecure(),
		status		=> $status,
	}, { delayed => 1 });
}

sub ajaxPageProfile {
	return '' if !dbAvailable('write_accesslog');
	my $constants = getCurrentStatic();
	my $logdb = getObject('Slash::DB', { virtual_user => $constants->{log_db_user} });
	return '' if !$logdb;
	my $form = getCurrentForm();
	my $pagemark = $form->{pagemark} || 0;
	$pagemark = 0 if $pagemark !~ /^\d+$/;
	my $dom = $form->{dom} || 0;
	$dom = 0 if $dom !~ /^[\d\.]+$/;
	$dom /= 1000; # convert ms to sec
	my $js = $form->{js} || 0;
	$js = 0 if $js !~ /^[\d\.]+$/;
	$js /= 1000; # convert ms to sec
	$logdb->sqlInsert('pagemark', {
		pagemark => $pagemark,
		-ts => 'NOW()',
		dom => $dom,
		js => $js,
	}, { ignore => 1 });
	return '';
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
		newpasswd_ts	=> undef,
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
sub getUserCrossSiteAuthenticate {
	my($self, $site, $params, $user) = @_;
	$user ||= getCurrentUser();
	my $gSkin = getCurrentSkin();

	my $tstamp = $params->{tstamp} || 0;
	$tstamp =~ s/\.\d+$//;
	$tstamp = 0 if $tstamp !~ /^\d+$/;

	errorLog("xsite: wrong host"), return unless $site->{host} eq $gSkin->{hostname};

	errorLog("xsite: no timestamp/nonce"), return unless $tstamp && $params->{'rand'};

	errorLog("xsite: expired timestamp"), return unless $tstamp + 60 >= time();

	unless ($self->sqlInsert('xsite_auth_log', {
		site    => $site->{site},
		-ts     => "FROM_UNIXTIME($tstamp)",
		nonce   => $params->{'rand'}
	})) {
		errorLog("xsite: duplicate nonce");
		return;
	};

	my $new = 0;
	my $uid = $self->sqlSelect('uid', 'users_param',
		"name=" . $self->sqlQuote($site->{auth_param_name}) .
		" AND value=" . $self->sqlQuote($params->{user_id})
	);

	if (!$uid) {
		my $newnick = sprintf($site->{user_name_format}, $params->{shortname} || $params->{user_id});
		my $matchname = nick2matchname($newnick);
		my $email = $params->{shortname}
			? sprintf($site->{email_format}, $params->{shortname})
			: '';

		# for matchname, we don't care if someone already has an
		# "sfpudge", that should not stop us from making a "SF:pudge"
		$uid = $self->createUser(
			$matchname, $email, $newnick, { skipchecks => 1 }
		);
		$new = 1;

		if ($uid) {
			# XXX consider disallowing these accounts from
			# authenticating on other domains
			my $data = {};
			$data->{creation_ipid} = $user->{ipid};
			$data->{ $site->{auth_param_name} } = $params->{user_id};
			$data->{acl}{nopasswd} = 1;
			$self->setUser($uid, $data);
		}
	}

	return unless $uid; # dunno!

	my $logtoken = $self->getLogToken($uid, 1);

	# return UID alone in scalar context
	return wantarray ? ($uid, $logtoken, $new) : $uid;
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
	# if $kind is 4, then only try to auth user with "public" logtoken,
	#   that can be used outside and separate of login session
	# if $kind is undef or 0, try as logtoken (the most common case),
	#	then encrypted, then as plaintext
	my($EITHER, $PLAIN, $ENCRYPTED, $LOGTOKEN, $PUBLIC) = (0, 1, 2, 3, 4);
	my($UID, $PASSWD, $NEWPASSWD) = (0, 1, 2);
	$kind ||= $EITHER;

	my $uid_try_q = $self->sqlQuote($uid_try);
	my $uid_verified = 0;

	if ($kind == $PUBLIC) {
		if ($passwd eq $self->getLogToken($uid_try, 0, 2) ||
			$passwd eq $self->getLogToken($uid_try, 0, 9)
		) {
			$uid_verified = $uid_try;
			$cookpasswd = $passwd;
		}

	} elsif ($kind == $LOGTOKEN || $kind == $EITHER) {
		# get existing logtoken, if exists
		if ($passwd eq $self->getLogToken($uid_try) || (
			$temp_ok && $passwd eq $self->getLogToken($uid_try, 0, 1)
		)) {
			$uid_verified = $uid_try;
			$cookpasswd = $passwd;
		}
	}

	if ($kind != $PUBLIC && $kind != $LOGTOKEN && !$uid_verified) {
		my($db_uid, $db_passwd, $db_newpasswd) = $self->sqlSelect(
			'uid,passwd,newpasswd',
			'users',
			"uid=$uid_try_q"
		);

		# try ENCRYPTED -> ENCRYPTED
		if ($kind == $EITHER || $kind == $ENCRYPTED) {
			if (comparePassword($passwd, $db_passwd, $uid_try, 0, ($kind == $ENCRYPTED))) {
				$uid_verified = $db_uid;
				# get existing logtoken, if exists, or new one
				$cookpasswd = $self->getLogToken($uid_verified, 1);
			}
		}

		# try PLAINTEXT -> ENCRYPTED
		if (($kind == $EITHER || $kind == $PLAIN) && !$uid_verified) {
			if (comparePassword($passwd, $db_passwd, $uid_try, ($kind == $PLAIN), 0)) {
				$uid_verified = $db_uid;
				# get existing logtoken, if exists, or new one
				$cookpasswd = $self->getLogToken($uid_verified, 1);
			}
		}

		# try PLAINTEXT -> NEWPASS
		if (($kind == $EITHER || $kind == $PLAIN) && !$uid_verified) {
			if (comparePassword($passwd, $db_newpasswd, $uid_try, ($kind == $PLAIN), 0)) {
				my $cryptpasswd = encryptPassword($passwd, $uid_try);
				$self->sqlUpdate('users', {
					newpasswd	=> '',
					passwd		=> $cryptpasswd
				}, "uid=$uid_try_q");
				$newpass = 1;

				$uid_verified = $db_uid;
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
		$self->createBadPasswordLog($uid_try, "");
	}

	# return UID alone in scalar context
	return wantarray ? ($uid_verified, $cookpasswd, $newpass) : $uid_verified;
}

########################################################
# Log a bad password in a login attempt.
sub createBadPasswordLog {
	my($self, $uid, $password_wrong) = @_;
	$password_wrong = "";
	my $constants = getCurrentStatic();

	# Failed login attempts as the anonymous coward don't count.
	return if !$uid || $uid == $constants->{anonymous_coward_uid};

	# Bad passwords that don't come through the web,
	# we don't bother to log.
	my $r = Apache2::RequestUtil->request;
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
				template_name	=> 'badpassword_msg',
				subject		=> 'Bad login attempts warning',
				nickname	=> $nick,
				uid		=> $uid,
				bp_count	=> $bp_count,
				bp_ips		=> $bp
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
		"GROUP BY ip ORDER BY c DESC"
	);
}

########################################################
# Make a new password, save it in the DB, and return it.
sub getNewPasswd {
	my($self, $uid) = @_;
	my $newpasswd = changePassword();
	$self->sqlUpdate('users', {
		newpasswd     => encryptPassword($newpasswd, $uid),
		-newpasswd_ts => 'NOW()',
	}, 'uid=' . $self->sqlQuote($uid));
	return $newpasswd;
}

########################################################
# reset's a user's account forcing them to get the
# new password via their registered mail account.
sub resetUserAccount {
	my($self, $uid) = @_;
	my $newpasswd = changePassword();
	my $enc = encryptPassword($newpasswd, $uid);
	$self->sqlUpdate('users', {
		passwd       => $enc,
		newpasswd    => $enc,
		newpasswd_ts => undef, # should this be NOW() ?
	}, 'uid=' . $self->sqlQuote($uid));
	return $newpasswd;
}

########################################################
# get proper cookie location
sub _getLogTokenCookieLocation {
	my($self, $uid) = @_;
	my $user = getCurrentUser();

	my $temp_str   = $user->{state}{login_temp}   || 'no';
	my $public_str = $user->{state}{login_public} || 'no';

	my $cookie_location = $temp_str eq 'yes'
		? 'classbid'
		: $self->getUser($uid, 'cookie_location');
	return($temp_str, $public_str);
}

########################################################
# Get a logtoken from the DB, or create a new one
sub _logtoken_read_memcached {
	my($self, $uid, $temp_str, $public_str) = @_;
	my $mcd = $self->getMCD();
	return undef unless $mcd;
	my $mcdkey = "$self->{_mcd_keyprefix}:lt:";
	my $lt_str = $uid
		. ":" . ($temp_str   eq 'yes' ? 1 : 0)
		. ":" . ($public_str eq 'yes' ? 1 : 0);
	my $value = $mcd->get("$mcdkey$lt_str");
#print STDERR scalar(gmtime) . " $$ _lt_read_mcd lt_str=$lt_str value='$value'\n";
	return $value;
}

sub _logtoken_write_memcached {
	my($self, $uid, $temp_str, $public_str, $value, $seconds) = @_;
	# Take a few seconds off this expiration time, because it's what's
	# in the DB that's authoritative;  for those last few seconds,
	# requests will have to go to the DB.
	$seconds -= 3;
	return unless $seconds > 0;

	my $mcd = $self->getMCD();
	return unless $mcd;
	my $mcdkey = "$self->{_mcd_keyprefix}:lt:";
	my $lt_str = $uid
		. ":" . ($temp_str   eq 'yes' ? 1 : 0)
		. ":" . ($public_str eq 'yes' ? 1 : 0);
	$mcd->set("$mcdkey$lt_str", $value, $seconds);
#print STDERR scalar(gmtime) . " $$ _lt_write_mcd lt_str=$lt_str value='$value' seconds=$seconds\n";
}

sub _logtoken_delete_memcached {
	my($self, $uid, $temp_str, $public_str) = @_;
	my $mcd = $self->getMCD();
	return unless $mcd;

	my $mcdkey = "$self->{_mcd_keyprefix}:lt:";
	if ($temp_str && $public_str) {
		# Delete just this one logtoken for this user.
		my $lt_str = $uid
			. ":" . ($temp_str   eq 'yes' ? 1 : 0)
			. ":" . ($public_str eq 'yes' ? 1 : 0);
		$mcd->delete("$mcdkey$lt_str");
#print STDERR scalar(gmtime) . " $$ _lt_delete_mcd deleted lt_str=$lt_str\n";
	} else {
		# Not having a temp_str and public_str and locationid passed in
		# means we must delete all logtokens for this user.  Select
		# them from the DB and delete them one at a time.
		my $uid_q = $self->sqlQuote($uid);
		my $logtokens_ar = $self->sqlSelectAllHashrefArray(
			"temp",
			"users_logtokens",
			"uid=$uid_q");
		for my $data (@$logtokens_ar) {
			my($temp_str) = ($data->{temp});
			$public_str ||= 0;
			my $lt_str = $uid
				. ":" . ($temp_str   eq 'yes' ? 1 : 0)
				. ":" . ($public_str eq 'yes' ? 1 : 0);
			# The 3 means "don't accept new writes to this key for 3 seconds."
			$mcd->delete("$mcdkey$lt_str");
#print STDERR scalar(gmtime) . " $$ _lt_delete_mcd deleted lt_str=$lt_str\n";
		}
	}
}

# yes, $special should probably not be a numeral .... -- pudge
sub getLogToken {
	my($self, $uid, $new, $special, $bump_public) = @_;

	my $user = getCurrentUser();
	my $uid_q = $self->sqlQuote($uid);

	$special ||= 0;
	my $force_temp   = $special == 1;
	my $force_public = $special == 2;
	my $force_plain  = $special == 9;

	my $login_temp   = $user->{state}{login_temp};
	my $login_public = $user->{state}{login_public};

	# set the temp value, if forced
	if ($force_plain) {
		$user->{state}{login_temp}   = 'no';
		$user->{state}{login_public} = 'no';
	} elsif ($force_temp) {
		$user->{state}{login_temp}   = 'yes';
	} elsif ($force_public) {
		$user->{state}{login_public} = 'yes';
	}

	my($temp_str, $public_str) = $self->_getLogTokenCookieLocation($uid);

	my $where = join(" AND ",
		"uid=$uid_q",
		"temp='$temp_str'",
		"public='$public_str'");
	my $value = $self->_logtoken_read_memcached($uid, $temp_str, $public_str) || '';
#print STDERR scalar(gmtime) . " $$ getLogToken value from mcd '$value' for uid=$uid temp_str=$temp_str public_str=$public_str locationid=$locationid\n";
	if (!$value) {
		my $thiswhere = $where;
		$thiswhere .= ' AND expires >= NOW()' if $public_str ne 'yes';
		$value = $self->sqlSelect(
			'value', 'users_logtokens',
			$thiswhere
		) || '';
	}
#print STDERR scalar(gmtime) . " $$ getLogToken value '$value'\n";

	# always bump expiration for temp logins
	if ($value && $temp_str eq 'yes') {
		my $minutes = getCurrentStatic('login_temp_minutes') || 10;
		$self->updateLogTokenExpires($uid, $temp_str, $public_str, $value, $minutes*60);
#print STDERR scalar(gmtime) . " $$ getLogToken called updateLogTokenExpires for temp, uid=$uid value=$value\n";
	}

	# bump expiration for public (aka RSS) logins if the caller requested it
	if ($value && $public_str eq 'yes' && $bump_public) {
		my $days = getCurrentStatic('login_nontemp_days') || 365;
		$self->updateLogTokenExpires($uid, $temp_str, $public_str, $value, $days*86400);
#print STDERR scalar(gmtime) . " $$ getLogToken called updateLogTokenExpires for public, uid=$uid value=$value\n";
	}

	# if $new, then create a new value if none exists
	if ($new && !$value) {
		$value = $self->setLogToken($uid) || '';
#print STDERR scalar(gmtime) . " $$ getLogToken called set, value='$value'\n";
	}

	# reset the temp values
	$user->{state}{login_temp}   = $login_temp unless $value;
	$user->{state}{login_public} = $login_public;

#print STDERR scalar(gmtime) . " $$ getLogToken returning, value='$value'\n";
	return $value;
}

########################################################
# Make a new logtoken, save it in the DB, and return it
sub setLogToken {
	my($self, $uid) = @_;

	my $logtoken = createLogToken();

	my $constants = getCurrentStatic();
	my $nontemp_days = $constants->{login_nontemp_days} || 365;
	my($interval, $seconds) = ("$nontemp_days DAY", $nontemp_days * 86400);
	my($temp_str, $public_str) = $self->_getLogTokenCookieLocation($uid);

	if ($temp_str eq 'yes') {
		my $minutes = getCurrentStatic('login_temp_minutes') || 1;
		($interval, $seconds) = ("$minutes MINUTE", $minutes * 60);
	}

	my $rows = $self->sqlReplace('users_logtokens', {
		uid		=> $uid,
		temp		=> $temp_str,
		public		=> $public_str,
		value		=> $logtoken,
		-expires 	=> "DATE_ADD(NOW(), INTERVAL $interval)"
	});
	if ($rows) {
		$self->_logtoken_write_memcached($uid, $temp_str, $public_str,
			$logtoken, $seconds);
	}

	# prune logtokens table, each user should not have too many
	my $uid_q = $self->sqlQuote($uid);
	my $max = getCurrentStatic('logtokens_max') || 2;
	my $where = "uid = $uid_q AND temp = '$temp_str' AND public = '$public_str'";
	my $total = $self->sqlCount('users_logtokens', $where);
	if ($total > $max) {
		my $limit = $total - $max;
		my $logtokens = $self->sqlSelectAllHashref(
			'lid', 'lid, uid, temp, public, users_logtokens', 
			$where,
			"ORDER BY expires LIMIT $limit"
		);
		my @lids = sort { $a <=> $b } keys %$logtokens;
		for my $lid (@lids) {
			my $lt = $logtokens->{$lid};
			$self->_logtoken_delete_memcached(
				$lt->{uid},
				$lt->{temp},
				$lt->{public},
			);
		}
		my $lids_text = join(",", @lids);
		$self->sqlDelete('users_logtokens', "lid IN ($lids_text)");
	}



#print STDERR scalar(gmtime) . " $$ setLogToken replaced uid=$uid temp=$temp_str public=$public_str locationid=$locationid logtoken='$logtoken' rows='$rows'\n";
	return $logtoken;
}

########################################################
# Update the expiration time of a logtoken
sub updateLogTokenExpires {
	my($self, $uid, $temp_str, $public_str, $value, $seconds) = @_;
	my $uid_q = $self->sqlQuote($uid);
	my $where = join(" AND ",
		"uid=$uid_q",
		"temp='$temp_str'",
		"public='$public_str'");

	my $rows = $self->sqlUpdate('users_logtokens', {
		-expires 	=> "DATE_ADD(NOW(), INTERVAL $seconds SECOND)"
	}, $where);
#print STDERR scalar(gmtime) . " $$ updateLogTokenExpires where='$where' seconds=$seconds rows='$rows'\n";
	$self->_logtoken_write_memcached($uid, $temp_str, $public_str,
		$value, $seconds);
	return $rows;
}

########################################################
# Delete logtoken(s)
sub deleteLogToken {
	my($self, $uid, $all) = @_;

	my $uid_q = $self->sqlQuote($uid);
	my $where = "uid=$uid_q";

	if (!$all) {
		my($temp_str, $public_str) = $self->_getLogTokenCookieLocation($uid);
		$where .= " AND temp='$temp_str' AND public='$public_str'";
		$self->_logtoken_delete_memcached($uid, $temp_str, $public_str);
		$self->sqlDelete('users_logtokens', $where);
	} else {
		$self->_logtoken_delete_memcached($uid);
		$self->sqlDelete('users_logtokens', $where);
	}
#print STDERR scalar(gmtime) . " $$ deleteLogToken where='$where'\n";
}

########################################################
#
sub getUIDByOpenID {
	my($self, $openid_url) = @_;
	return unless $openid_url;

	my($uid) = $self->sqlSelect(
		'uid',
		'users_openid',
		'openid_url=' . $self->sqlQuote($openid_url)
	);
	return $uid;
}

sub getOpenIDsByUID {
	my($self, $uid) = @_;
	return unless $uid;

	my $openid_urls = $self->sqlSelectAll(
		'openid_url',
		'users_openid',
		'uid=' . $self->sqlQuote($uid)
	);
	return [] if !$openid_urls || !@$openid_urls;

	return [ map { {
		url => $_->[0],
		normalized_openid_url => normalizeOpenID($_->[0])
	} } @$openid_urls ];
}

sub setOpenID {
	my($self, $uid, $openid_url) = @_;
	return unless $uid && $openid_url;

	return $self->sqlInsert('users_openid', {
		openid_url => $openid_url,
		uid        => $uid
	});
}

sub deleteOpenID {
	my($self, $uid, $openid_url) = @_;
	return unless $uid && $openid_url;

	return $self->sqlDelete('users_openid',
		'openid_url=' . $self->sqlQuote($openid_url) .
		' AND uid=' . $self->sqlQuote($uid)
	);
}

sub deleteOpenIDs {
	my($self, $uid) = @_;
	return unless $uid;

	return $self->sqlDelete('users_openid',
		'uid=' . $self->sqlQuote($uid)
	);
}

sub setOpenIDResKey {
	my($self, $openid_url, $reskey) = @_;
	return unless $openid_url && $reskey;

	$self->sqlInsert('users_openid_reskeys', {
		openid_url => $openid_url,
		reskey     => $reskey
	});

}

sub checkOpenIDResKey {
	my($self, $reskey) = @_;
	return unless $reskey;

	my($openid_url) = $self->sqlSelect(
		'openid_url',
		'users_openid_reskeys',
		'reskey=' . $self->sqlQuote($reskey)
	);

	return $openid_url;
}

sub convertNamedTZToSlashTZ {
	my($self, $tz) = @_;
	my $dt;

	eval { $dt = DateTime->now( time_zone => $tz ) };
	return unless $dt;

	my $offset = $dt->offset or return;

	my $column = $dt->is_dst ? 'dst_off_set' : 'off_set';
	my $new_tz = $self->sqlSelect('tz', 'tzcodes', "$column=$offset");
	if (!$new_tz && $column eq 'dst_off_set') {
		# could be that we are in DST but the TZ has no DST offset ...
		$new_tz = $self->sqlSelect('tz', 'tzcodes', "off_set=$offset");
	}
	return $new_tz;
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

sub getUserUIDWithMatchname {
	my($self, $name) = @_;

	my $newnick = $self->sqlQuote(nickFix($name));
	my $matchname = $self->sqlQuote(nick2matchname($newnick));

	my $uid = $self->sqlSelect(
		'uid',
		'users',
		"nickname = $newnick || matchname = $matchname",
		'ORDER BY uid ASC'
	);

	return $uid;
}

sub getOtherUserParams {
	my($self, $data) = @_;
	
	my $user    = getCurrentUser();
	my $form    = getCurrentForm();
	my $params  = $self->getDescriptions('otherusersparam');

	for my $param (keys %$params) {
		# set user too for output in this request
		$data->{$param} = $user->{$param} = defined($form->{$param})
			? $form->{$param}
			: $params->{$param};
	}
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
		$where, $num, $min, $options
	);
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
	my $constants = getCurrentStatic();
	my $cache = getCurrentCache();
	my $dbs_cache_time = 5; # this was 10, let's try 5

	if ($cache->{dbs} && (($_getDBs_cached_nextcheck || 0) > time)) {
#use Data::Dumper;
#$Data::Dumper::Sortkeys = 1;
#print STDERR scalar(gmtime) . " $$ returning cached: " . Dumper($cache->{dbs});
		return \%{ $cache->{dbs} };
	}

	my $dbs = $self->sqlSelectAllHashref('id', '*', 'dbs');

	# If the DB was down previously, over how long a period does it
	# get brought back up to speed?
	my $dbs_revive_seconds = $constants->{dbs_revive_seconds} || 30;

	# Calculate the real weight for each DB and write it into its
	# hashref.
	for my $dbid (keys %$dbs) {
		my $db = $dbs->{$dbid};

		my $weight_start = $db->{weight};
		$weight_start = 1 if !$weight_start || $weight_start < 1;

		# If we had cached data for this, then even though it expired,
		# pull in the _last_seen_dead field.  We'll overwrite it if
		# necessary and write it back into the cache in a moment.
		if ($cache->{dbs} && $cache->{dbs}{$dbid}) {
#print STDERR scalar(gmtime) . " $$ dbid=$dbid lsd=" . ($cache->{dbs}{$dbid}{_last_seen_dead} || 0) . "\n";
			$db->{_last_seen_dead} = $cache->{dbs}{$dbid}{_last_seen_dead} || 0;
		}
		# Now calculate the factor for the DB being dead or alive,
		# which will always be a number between 0 and 1.
		my $weight_alive_factor = 1;
		if ($db->{isalive} ne 'yes') {
			$weight_alive_factor = 0;
			$db->{_last_seen_dead} = time;
#print STDERR scalar(gmtime) . " $$ dbid=$dbid dead, lsd set to $db->{_last_seen_dead}\n";
		} else {
			# This DB is alive.
			my $time_alive = time - ($db->{_last_seen_dead} || 0);
#print STDERR scalar(gmtime) . " $$ dbid=$dbid alive, time_alive=$time_alive, revive=$dbs_revive_seconds\n";
			if ($time_alive < $dbs_revive_seconds) {
				# This DB was not alive recently, so
				# bring its weight_alive_factor back up
				# to the normal level over a period of
				# $dbs_revive_seconds seconds.
				$weight_alive_factor = $time_alive / $dbs_revive_seconds;
			}
		}

		# We square the weight_alive_factor because that eases the
		# DB back up to speed, starting it slow when its caches
		# are empty and accelerating once they've had a chance to
		# fill.
		$db->{weight_final} = $weight_start
			* $weight_alive_factor ** 2
			* $db->{weight_adjust};
#printf STDERR scalar(gmtime) . " $$ dbid=$dbid weights: %.3f %.3f %.3f %.3f\n", $weight_start, $weight_alive_factor**2, $db->{weight_adjust}, $db->{weight_final};
	}

	# The amount of time to cache this has to be hardcoded, since
	# we obviously aren't able to get it from the DB at this level.
	# This could be adjusted, but it should be on the same order as
	# how often the balance_readers task runs (which right now is
	# hardcoded to 5 seconds).
	$_getDBs_cached_nextcheck = time + $dbs_cache_time;

	# Cache it.
	$cache->{dbs} = \%{ $dbs };
#print STDERR gmtime() . " $$ getDBs setting cache: " . Dumper($dbs);

	return $dbs;
}

#################################################################
# get virtual user of a db type, for use when $user->{state}{dbs}
# not filled in
sub getDB {
	my($self, $db_type) = @_;

	my $dbs = $self->getDBs();

	# Get a list of all usable dbids with this type.
	my @dbids_usable =
		sort { $a <=> $b }
		grep {    $dbs->{$_}{type} eq $db_type
			   && $dbs->{$_}{weight_final} > 0 }
		keys %$dbs;
#print STDERR scalar(gmtime) . " $$ dbids_usable for type '$db_type': '@dbids_usable'\n";

	# If there is exactly zero or one DB that's usable, this is easy.
	my $n_usable = scalar @dbids_usable;
	if ($n_usable == 0) {
		return undef;
	} elsif ($n_usable == 1) {
		return $dbs->{$dbids_usable[0]}{virtual_user};
	}

	# Add up the total weight of all usable DBs.
	my $weight_total = 0;
	for my $dbid (@dbids_usable) {
#printf STDERR "dbid=$dbid weight_final=$dbs->{$dbid}{weight_final}\n";
		$weight_total += $dbs->{$dbid}{weight_final};
	}

	# Do the random pick.
	my $x = rand(1) * $weight_total;
#printf STDERR "weight_total=%.3f x=%.3f\n", $weight_total, $x;

	# Iterate through the usable dbids until we get to the one that
	# was chosen.  Actually, we don't include the last one in our
	# checking;  if we get to the last one, we return it.  This is
	# probably about a nanosecond faster, but more importantly, in
	# case of a logic error or weird floating-point roundoff thing,
	# it does something reasonable.
	for my $i (0 .. $n_usable-2) {
		my $dbid = $dbids_usable[$i];
		$x -= $dbs->{$dbid}{weight_final};
		if ($x <= 0) {
#print STDERR "returning $i of $n_usable, dbid=$dbid\n";
			return $dbs->{$dbid}{virtual_user};
		}
	}
	# It wasn't any of the others, and we know all the choices are
	# good, so it must be the last one.
#print STDERR "returning last option, dbid=$dbids_usable[-1]\n";
	return $dbs->{ $dbids_usable[-1] }{virtual_user};
}

} # end closure surrounding getDBs and getDB

#################################################################

# Utility function to return an array of all the virtual users for
# all the DBs of one specific type.

sub getDBVUsForType {
	my($self, $type) = @_;
	my $dbs = $self->getDBs();
	return map { $dbs->{$_}{virtual_user} }
		grep { $dbs->{$_}{type} eq $type }
		keys %$dbs;
}

#################################################################

# Writing to the dbs_readerstatus table.

sub createDBReaderStatus {
	my($self, $hr) = @_;
	return $self->sqlInsert("dbs_readerstatus", $hr);
}

#################################################################

# Methods for reading and writing the dbs_readerstatus_queries table.

sub getDBReaderStatusQueryId {
	my($self, $text) = @_;
	my $id = $self->getDBReaderStatusQueryId_raw($text)
		|| $self->createDBReaderStatusQuery($text);
	return $id;
}

sub getDBReaderStatusQueryId_raw {
	my($self, $text) = @_;
	my $text_q = $self->sqlQuote($text);
	return $self->sqlSelect("rsqid", "dbs_readerstatus_queries",
		"text = $text_q");
}

sub createDBReaderStatusQuery {
	my($self, $text) = @_;
	$self->sqlInsert("dbs_readerstatus_queries",
		{ rsqid => undef, text => $text },
		{ ignore => 1 });
	return $self->getLastInsertId();
}

#################################################################
sub getDBVirtualUsers {
	my($self) = @_;
	return $self->sqlSelectColArrayref('virtual_user', 'dbs')
}

#################################################################
# get list of DBs, never cache
# (do caching in getSlashConf)
# See code comment in getObject().
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

#################################################################
sub existsEmail {
	my($self, $email) = @_;

	# Returns count of users matching $email.
	return ($self->sqlSelect('uid', 'users',
		'realemail=' . $self->sqlQuote($email)))[0];
}

#################################################################
sub existsUid {
	my($self, $uid) = @_;
	return $self->sqlSelect('uid', 'users', 'uid=' . $self->sqlQuote($uid));
}

#################################################################
# Ok, this is now a transaction. This means that if we lose the DB
# while this is going on, we won't end up with a half created user.
# -Brian
sub createUser {
	my($self, $matchname, $email, $newuser, $opts) = @_;
	return unless $matchname && $newuser;
	$opts ||= {};
	return if !$email && !$opts->{skipchecks};

	$email =~ s/\s//g; # strip whitespace from emails

	if (!$opts->{skipchecks}) {
		return if ($self->sqlSelect(
			"uid", "users",
			"matchname=" . $self->sqlQuote($matchname)
		))[0] || $self->existsEmail($email);
	}

	$self->sqlDo("SET AUTOCOMMIT=0");

	$self->sqlInsert("users", {
		uid		=> undef,
		realemail	=> $email || '',
		nickname	=> $newuser,
		matchname	=> $matchname,
		seclev		=> 1,
		passwd		=> encryptPassword(changePassword())
	});

	my $uid = $self->getLastInsertId({ table => 'users', prime => 'uid' });
	unless ($uid) {
		$self->sqlDo("ROLLBACK");
		$self->sqlDo("SET AUTOCOMMIT=1");
	}
	return unless $uid;

	# Since TEXT/BLOB columns can't have a DEFAULT value, and since in
	# strict mode MySQL 5.0 will no longer silently supply the empty
	# string as a default for TEXT NOT NULL, we need to explicitly set
	# those columns to the empty string upon creation.
	$self->sqlInsert("users_info", {
		uid 			=> $uid,
		-lastaccess		=> 'NOW()',
		-created_at		=> 'NOW()',
		bio			=> '',
	});
	$self->sqlInsert("users_prefs", { uid => $uid });
	$self->sqlInsert("users_comments", { uid => $uid });
	$self->sqlInsert("users_hits", { uid => $uid });
	$self->sqlInsert("users_index", {
		uid			=> $uid,
		story_never_topic	=> '',
		slashboxes		=> '',
		story_always_topic	=> '',
	});

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

	my $initdomain = email_to_domain($email);

	my $newuser_data = {
		'registered'		=> 1,
		'expiry_comm'		=> $constants->{min_expiry_comm},
		'expiry_days'		=> $constants->{min_expiry_days},
		'user_expiry_comm'	=> $constants->{min_expiry_comm},
		'user_expiry_days'	=> $constants->{min_expiry_days},
		initdomain		=> $initdomain,
		created_ipid		=> getCurrentUser('ipid') || '',
	};
	$newuser_data->{index_classic} = 1 if $ENV{HTTP_USER_AGENT} =~ /msie [2-6]/i;

	$self->setUser($uid, $newuser_data);

	$self->sqlDo("COMMIT");
	$self->sqlDo("SET AUTOCOMMIT=1");

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
	$self->setVar_delete_memcached();
	return $retval;
}

########################################################
sub setSession {
	my($self, $name, $value) = @_;
	if (!$value->{lasttime}) {
		$value->{'-lasttime'} = "NOW()"
	}
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
	my($self, $id, $discussion) = @_;
	if ($discussion->{kind}) {
		my $kinds = $self->getDescriptions('discussion_kinds');
		my $kind = delete $discussion->{kind};
		my %r_kinds;
		@r_kinds{values %$kinds} = keys %$kinds;
		$discussion->{dkid} = $r_kinds{$kind} if $r_kinds{$kind};
	}
	_genericSet('discussions', 'id', '', @_);
}

########################################################
sub setDiscussionBySid {
	_genericSet('discussions', 'sid', '', @_);
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
sub getCommentsStartingAt {
	my($self, $start_at, $options) = @_;
	my $limit = ($options->{limit} && $options->{limit}) ? "LIMIT $options->{limit}" : "";
	my $order = ($options->{order} && $options->{order} eq "DESC") ? "DESC" : "ASC";
	my($comments) = $self->sqlSelectAllHashrefArray('*', 'comments', "cid >= $start_at", "ORDER BY cid $order $limit");
	return $comments;
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
	my $constants = getCurrentStatic();
	if ($constants->{m1}) {
		my $moddb = getObject("Slash::$constants->{m1_pluginname}");
		if ($moddb) {
			$moddb->deleteModeratorlog({ cid => $cid });
		}
	}
	if ($total_rows != scalar(@comment_tables)) {
		# XXX This should be wrapped in a transaction
		# instead of just throwing an error that may never
		# be seen.  However it gets tricky because some sites
		# may still have comment_text as a MyISAM table for
		# the FULLTEXT search index, and transactions don't
		# work across table types.  SearchToo may alleviate
		# this problem soon. - Jamie 2006/10
		errorLog("deleteComment cid $cid from $discussion_id,"
			. " only $total_rows deletions");
		return 0;
	}
	return 1;
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

# MC: If a story hasn't had the required number of signoffs, its not viewable
sub checkStoryViewable {
	my($self, $sid, $start_tid, $options) = @_;
	return unless $sid;

	my $stoid = $self->getStoidFromSidOrStoid($sid);
	return 0 unless $stoid;

	return 0 if $self->sqlCount(
		"story_param",
		"stoid = '$stoid' AND name='neverdisplay'");

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
		"stoid=$stoid_q AND tid=$tid_q");
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
		 AND ts > NOW()"
	);
	return $count;
}

########################################################
# $id is a discussion id. -Brian
sub checkDiscussionPostable {
	my($self, $id) = @_;
	return 0 unless $id;
	my $constants = getCurrentStatic();

	# This should do it.
	my($column_time, $where_time) = $self->_stories_time_clauses({
		try_future		=> $constants->{subscribe_future_post},
		must_be_subscriber	=> 1,
		column_name		=> 'ts',
	});
	my $count = $self->sqlCount(
		'discussions',
		"id='$id' AND type != 'archived' AND $where_time",
	);
	return 0 unless $count;

	# Now, we are going to get paranoid and run the story checker against it
	my $discussion = $self->getDiscussion($id, [ qw(dkid sid) ]);
	if ($discussion->{sid}) {
		my $kinds = $self->getDescriptions('discussion_kinds');
		if ($kinds->{ $discussion->{dkid} } eq 'story') {
			return $self->checkStoryViewable($discussion->{sid});
		}
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
	my $constants = getCurrentStatic();
	my @subid;

	$options = {} unless ref $options;
	$options->{nodelete} = $nodelete if defined $nodelete;

	# This might need some cleaning up if nothing is using it.
	if ($form->{subid} && !$options->{nodelete}) {
		my $subid_q = $self->sqlQuote($form->{subid});

		# Try updating del to 1, but only if it's still 0
		my $rows = $self->sqlUpdate("submissions",
			{ del => 1 }, "subid=$subid_q AND del=0"
		);

		if ($rows) {
			$self->setUser($uid,
				{ -deletedsubmissions => 'deletedsubmissions+1' }
			);

			push @subid, $form->{subid};
		}
	}

	for (keys %{$form}) {
		# $form has several new internal variables that match this regexp, so
		# the logic below should always check $t.
		next unless /^(\w+)_(\d+)$/;
		my($t, $n) = ($1, $2);
		my $n_q = $self->sqlQuote($n);

		if ($t eq "note" || $t eq "comment" || $t eq "skid") {
			$form->{"note_$n"} = "" if ($form->{"note_$n"} eq " " || !defined($form->{"note_$n"}) ); 
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

				$self->sqlUpdate('submissions',
					\%sub, "subid=$n_q"
				);
			}

		} elsif ($t eq 'del' && !$options->{nodelete}) {
			if ($options->{accepted}) {
				$self->sqlUpdate('submissions',
					{ del => 2 }, "subid=$n_q"
				);
				push @subid, $n;

			} else {
				# Try updating del to 1, but only if it's still 0
				my $rows = $self->sqlUpdate('submissions',
					{ del => 1 }, "subid=$n_q AND del=0"
				);
				if ($rows) {
					$self->setUser($uid,
						{ -deletedsubmissions => 'deletedsubmissions+1' }
					);
					push @subid, $n;
				}
			}
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
	my $constants = getCurrentStatic();
	if ($constants->{m1}) {
		my $moddb = getObject("Slash::$constants->{m1_pluginname}");
		if ($moddb) {
			$moddb->deleteModeratorlog({ sid => $did });
		}
	}
}

########################################################
# Delete a topic.  At least for now (2004/09), we are requiring a
# replacement topic ID to be specified, so parents and children of
# the deleted topic can be re-established.
sub deleteTopic {
	my($self, $tid, $newtid) = @_;
	my $constants = getCurrentStatic();
	my $tid_q = $self->sqlQuote($tid);
	my $newtid_q = $self->sqlQuote($newtid);
	my $tree = $self->getTopicTree();

	my $ok = 1;
	my $errmsg = "";

	if (!$tid) {
		$ok = 0; $errmsg = "no topic to delete was given";
	}
	if ($ok && !$newtid) {
		$ok = 0; $errmsg = "no replacement topic given";
	}
	if ($ok && $tid == $newtid) {
		$ok = 0; $errmsg = "cannot replace topic with itself";
	}
	if ($ok && !$tree->{$tid}) {
		$ok = 0; $errmsg = "topic to delete not found";
	}
	if ($ok && !$tree->{$newtid}) {
		$ok = 0; $errmsg = "replacement topic not found";
	}
	if ($ok) {
		my @tid_children    = $self->getAllChildrenTids($tid);
		my @newtid_children = $self->getAllChildrenTids($newtid);
		my @tid_parents     = $self->getAllParentsTids($tid);
		my @newtid_parents  = $self->getAllParentsTids($newtid);
		my %tid_parents     = map { ($_, 1) } @tid_parents;
		my %newtid_parents  = map { ($_, 1) } @newtid_parents;
		my $badtid;
		if (($badtid) = grep { $tid_parents{$_} } @newtid_children) {
			$ok = 0; $errmsg = "replacement topic is a (grand,etc.?)parent of deleted topic child $badtid";
		} elsif (($badtid) = grep { $newtid_parents{$_} } @tid_children) {
			$ok = 0; $errmsg = "replacement topic is a (grand,etc.?)child of deleted topic parent $badtid";
		}
	}

	if (!$ok) {
		return($ok, $errmsg);
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
	# to instead point to its replacement.  In case one of the
	# topic's children _is_ the replacement, don't make it loop to
	# itself (and the resulting busted row will be deleted).
	$self->sqlUpdate('topic_parents',
		{ parent_tid => $newtid },
		"parent_tid=$tid_q AND tid != $newtid_q",
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

	# Now update existing objects that had the old tid as a topic to
	# have the new tid.  Stories are a special case so skip those
	# for now.
	# These tables have topics stored as 'tid'.
	$self->sqlUpdate("submissions",		{ tid => $newtid },	"tid=$tid_q");
	if ($constants->{plugin}{Journal}) {
		$self->sqlUpdate("journals",	{ tid => $newtid },	"tid=$tid_q");
	}
	$self->sqlUpdate("discussions",		{ topic => $newtid },	"topic=$tid_q");
	$self->sqlUpdate("pollquestions",	{ topic => $newtid },	"topic=$tid_q");

	# OK, for stories, it's a little more complicated because we have
	# not just a tid column, but two other tables.  First we mark
	# stories as needing to be re-rendered.
	$self->markTopicsDirty([ $tid, $newtid ]);
	# Then change the stories.tid column.
	$self->sqlUpdate("stories",       { tid => $newtid },   "tid=$tid_q");
	# Now change everything in the chosen and rendered tables.
	# Stories with both old and new already existing will have this
	# fail because (stoid,tid) is a unique index, but that is OK.
	$self->sqlUpdate("story_topics_chosen",   { tid => $newtid }, "tid=$tid_q", { ignore => 1 });
	$self->sqlUpdate("story_topics_rendered", { tid => $newtid }, "tid=$tid_q", { ignore => 1 });
	# Delete any rows that failed to change because of the
	# unique index.
	$self->sqlDelete("story_topics_chosen",   "tid=$tid_q");
	$self->sqlDelete("story_topics_rendered", "tid=$tid_q");

	# Finally, we nuke the topic from the topic tables themselves
	# (except topic_parents which we have already taken care of).
	$self->sqlDelete("topics", "tid=$tid_q");
	$self->sqlUpdate("topic_nexus",		{ tid => $newtid }, "tid=$tid_q", { ignore => 1 });
	$self->sqlDelete("topic_nexus",		"tid=$tid_q");
	$self->sqlUpdate("topic_nexus_dirty",	{ tid => $newtid }, "tid=$tid_q", { ignore => 1 });
	$self->sqlDelete("topic_nexus_dirty",	"tid=$tid_q");
	$self->sqlUpdate("topic_nexus_extras",	{ tid => $newtid }, "tid=$tid_q", { ignore => 1 });
	$self->sqlDelete("topic_nexus_extras",	"tid=$tid_q");
	$self->sqlUpdate("topic_param",		{ tid => $newtid }, "tid=$tid_q", { ignore => 1 });
	$self->sqlDelete("topic_param",		"tid=$tid_q");

	$self->setVar('topic_tree_lastchange', time());

	return (1, "");
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
	# this is designed to take lots of data and filter it,
	# so we can't just take additional params and put them in
	# the param table; for now, put them in $options -- pudge
	my($self, $topic, $options) = @_;

	# Used to not require this.  Make sure it's passed in.
	my $tid = $topic->{tid};
	return 0 if !$tid;

	my $image = $topic->{image2} || $topic->{image};
	my $submittable = $topic->{submittable} || 'no';
	my $searchable  = $topic->{searchable}  || 'no';
	my $storypickable  = $topic->{storypickable} || 'no';

	my $data = {
		keyword		=> $topic->{keyword},
		textname	=> $topic->{textname},
		series		=> $topic->{series} eq 'yes' ? 'yes' : 'no',
		image		=> $image,
		width		=> $topic->{width} || '',
		height		=> $topic->{height} || '',
		submittable	=> $submittable eq 'no' ? 'no' : 'yes',
		searchable	=> $searchable eq 'no' ? 'no' : 'yes',
		storypickable	=> $storypickable eq 'no' ? 'no' : 'yes',
	};

	my $rows = $self->sqlCount('topics', "tid=$tid");
	if ($rows == 0) {
		$data->{tid} = $tid;
		my $inserted = $self->sqlInsert('topics', $data);
		return 0 if !$inserted;
	} else {
		$self->sqlUpdate('topics', $data, "tid=$tid");
	}

	if ($options->{param}) {
		my $params = $options->{param};
		for my $name (keys %$params) {
			if (defined $params->{$name} && length $params->{$name}) {
				$self->sqlReplace('topic_param', {
					tid	=> $tid,
					name	=> $name,
					value	=> $params->{$name}
				});
			} else {
				my $name_q = $self->sqlQuote($name);
				$self->sqlDelete('topic_param',
					"tid = $tid AND name = $name_q"
				);
			}
		}
	}

	my %dirty_topics;
	##### XXXSECTIONTOPICS check for recursives
	for my $x (qw(parent child)) {
		my %relations;
		my $name = $x . '_topic';
		if ($topic->{_multi}{$name} && ref($topic->{_multi}{$name}) eq 'ARRAY') {
			%relations = map { $_ => undef } grep { $_ } @{$topic->{_multi}{$name}};

		} elsif ($topic->{$name}) {
			if (ref($topic->{$name}) eq 'HASH') {
				%relations = map { $_ => $topic->{$name}{$_} } grep { $_ } keys %{$topic->{$name}};
			} elsif (ref($topic->{$name}) eq 'ARRAY') {
				%relations = map { $_ => undef } grep { $_ } @{$topic->{$name}};
			} else {
				%relations = ($topic->{$name} => undef);
			}
		}

		my $del_str = join ',', keys %relations;
		if ($x eq 'parent') {
			my $tids = $self->sqlSelectColArrayref("parent_tid", "topic_parents", "tid=$tid");
			$dirty_topics{$_}++ for @$tids;
			$self->sqlDelete('topic_parents', "tid=$tid AND parent_tid NOT IN ($del_str)") if $del_str;
		} elsif ($x eq 'child') {
			my $tids = $self->sqlSelectColArrayref("tid", "topic_parents", "parent_tid=$tid");
			$dirty_topics{$_}++ for @$tids;
			$self->sqlDelete('topic_parents', "parent_tid=$tid AND tid NOT IN ($del_str)") if $del_str;
		}

		for my $thistid (keys %relations) {
			$dirty_topics{$thistid}++;
			my %relation = (
				tid		=> $tid,
				parent_tid	=> $thistid,
			);
			$relation{min_weight} = $relations{$thistid} if defined $relations{$thistid};

			if ($x eq 'child') {
				@relation{qw(tid parent_tid)} = @relation{qw(parent_tid tid)};
			}

			$self->sqlInsert('topic_parents', \%relation, { ignore => 1 });
			# update changed weights
			$self->sqlUpdate('topic_parents',
				{ min_weight => $relation{min_weight} },
				"tid = $relation{tid} AND parent_tid = $relation{parent_tid}",
			) if $relation{min_weight};
		}
	}

	if ($topic->{nexus}) {
		$self->sqlInsert('topic_nexus', { tid => $tid }, { ignore => 1 });
	} else {
		$self->sqlDelete('topic_nexus', "tid=$tid");
	}

	$self->markTopicsDirty([ $tid, keys %dirty_topics ]);

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

	$form->{autosubmit} ||= 'no';
	$form->{hidden} ||= 0;
	$form->{always_on} ||= 0;
	$form->{default_block} ||= 0;
	$form->{all_skins} ||= 0;
	$form->{portal} ||= 0;
	$form->{retrieve} ||= 0;
	$form->{items} ||= 0;

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
			default_block		=> $form->{default_block},
			hidden		=> $form->{hidden},
			always_on		=> $form->{always_on},
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
			default_block		=> $form->{default_block},
			hidden		=> $form->{hidden},
			always_on		=> $form->{always_on},
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
	my $section_q = $self->sqlQuote($section);
	return $self->sqlSelectAllHashrefArray(
		"section, bid, ordernum, title, portal, url, rdf, retrieve",
		"blocks",
		"section=$section_q",
		"ORDER BY ordernum"
	);
}

########################################################
sub getSectionBlocks {
	my($self) = @_;
	return $self->sqlSelectAll(
		"bid, title, always_on",
		"blocks",
		"hidden != 1 AND shill = 'no'",
		"ORDER BY ordernum ASC, id ASC");
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
	my($self, $skid) = @_;
	my $skid_q = $self->sqlQuote($skid);
	$self->sqlUpdate(
		"skins",
		{ -last_rewrite => 'NOW()' },
		"skid = $skid_q");
	my $nexus = $self->getNexusFromSkid($self->getSkidFromName($skid));
	errorLog("no nexus found for id '$skid'") if !$nexus;
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
# When a topic is marked as dirty, every story that references it
# must be marked as needing to have its topics re-rendered.
sub markTopicsDirty {
	my($self, $tids) = @_;
	return if !$tids || !@$tids;
	my $tid_list = join(",", @$tids);
	my $stoids_c = $self->sqlSelectColArrayref(
		"DISTINCT(stoid)",
		"story_topics_chosen",
		"tid IN ($tid_list)");
	my $stoids_r = $self->sqlSelectColArrayref(
		"DISTINCT(stoid)",
		"story_topics_rendered",
		"tid IN ($tid_list)");
	my %stoids = map { ($_, 1) } (@$stoids_c, @$stoids_r);
	my $stoids_ar = [ sort { $a <=> $b } keys %stoids ];
	$self->markStoriesRenderDirty($stoids_ar);
	# Mark the topic tree as dirty so its PNG will be updated.
	$self->setVar('topic_tree_lastchange', time());
}

########################################################
sub markStoriesRenderClean {
	my($self, $stoids) = @_;
	return if !$stoids || !@$stoids;
	my $stoid_list = join(",", @$stoids);
	$self->sqlDelete('story_render_dirty', "stoid IN ($stoid_list)");
}

########################################################
sub markStoriesRenderDirty {
	my($self, $stoids) = @_;
	$self->setStory_delete_memcached_by_stoid($stoids);
	$self->sqlDo("SET AUTOCOMMIT=0");
	for my $stoid (@$stoids) {
		$self->sqlInsert('story_render_dirty',
			{ stoid => $stoid },
			{ delayed => 1, ignore => 1 });
	}
	$self->sqlDo("COMMIT");
	$self->sqlDo("SET AUTOCOMMIT=1");
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
	$self->setStory_delete_memcached_by_stoid([ $stoid ]);
	$self->sqlInsert('story_dirty', { stoid => $stoid }, { ignore => 1 });

	my $rendered_tids = $self->getStoryTopicsRendered($stoid);
	return unless $rendered_tids && @$rendered_tids;
	$self->setStory_delete_memcached_by_tid($rendered_tids);
}

########################################################
sub deleteStory {
	my($self, $id) = @_;
	my $constants = getCurrentStatic();
	return $self->setStory($id, { in_trash => 'yes' });
}

########################################################
# This sets a value on a story rather than the initial writing of the story
########################################################
sub setStory {
	my($self, $id, $change_hr, $options) = @_;
	my $constants = getCurrentStatic();
	my @fh_update_fields;

	my $param_table = 'story_param';
	my $cache = _genericGetCacheName($self, [qw( stories story_text )]);

	# Grandfather in an old-style sid.
	my $stoid = $self->getStoidFromSidOrStoid($id);
	return 0 unless $stoid;

	# Delete the memcached entry before doing this, because
	# whatever is there now is invalid.
	$self->setStory_delete_memcached_by_stoid([ $stoid ]);

	# We modify data before we're done.  Make a copy.
	my %ch = %$change_hr;
	$change_hr = \%ch;

	# Grandfather in these two API parameters, writestatus and
	# is_dirty.  The preferred way to set is_archived is
	# to pass in { is_archived => 1 }.  The preferred way
	# to set a story as dirty is { is_dirty => 1 } To mark
	# a story as clean or ok set it to { is_dirty => 0 }
	# Of course, markStoryClean and -Dirty work too

	my($dirty_change, $dirty_newval);

	if ($change_hr->{writestatus}) {
		$dirty_change = 1;
		$dirty_newval =	  $change_hr->{writestatus} eq 'dirty'	? 1 : 0;
		my $is_archived = $change_hr->{writestatus} eq 'archived' ? 1 : 0;
		delete $change_hr->{writestatus};
		$change_hr->{is_archived} = 'yes' if $is_archived;
	}
	if (defined $change_hr->{is_dirty}) {
		$dirty_change = 1;
		$dirty_newval = $change_hr->{is_dirty};
		delete $change_hr->{is_dirty}
	}

	if ($change_hr->{introtext} && $change_hr->{introtext} =~ /href=\"SELF\"/) {
		my $link_url = $self->_getStorySelfLink($stoid, $change_hr);
		$change_hr->{introtext} =~ s/href=\"SELF\"/href="$link_url"/;
	}

	if (defined $change_hr->{media}) {
		if($change_hr->{media} && $change_hr->{media} =~ /<(embed|object)/i) {
			$change_hr->{mediatype} = "video";
		} elsif ($change_hr->{media} && $change_hr->{media} =~ /<img/i) {
			$change_hr->{mediatype} = "image";
		} else {
			$change_hr->{mediatype} = "";
		}
	}

	$change_hr->{is_archived} = $change_hr->{is_archived} ? 'yes' : 'no'
		if defined $change_hr->{is_archived};
	$change_hr->{in_trash} = $change_hr->{in_trash} ? 'yes' : 'no'
		if defined $change_hr->{in_trash};

	# We always touch stories.last_update, even for writes that only
	# affect story_text and story_param, _unless_ the change is only
	# commentcount, hitparade, or hits (which may matter sometime in the
	# future, I hope), in which case we need to tell the table to
	# keep the value the same.
	# Note:  this isn't exactly right.  If the stories table is the
	# only one being written to, we shouldn't set last_update
	# manually, we should let it be set if and only if another column
	# changes.  Doing it this way doesn't really hurt anything though.

	if (!exists($change_hr->{last_update})
		&& !exists($change_hr->{-last_update})) {
		my @non_cchp = grep !/^(commentcount|hitparade|hits)$/, keys %$change_hr;
		@fh_update_fields = grep /^(title|uid|time|introtext|bodytext|primaryskid|tid|neverdisplay|media|mediatype|thumb|offmainpage|notes)$/, keys %$change_hr;
		
		if (@non_cchp > 0) {
			$change_hr->{-last_update} = 'NOW()';
		} else {
			$change_hr->{-last_update} = 'last_update';
		}
	}

	# If a topics_chosen change_hr was given, we write not just that,
	# but also topics_rendered, primaryskid and tid.

	my $chosen_hr = delete $change_hr->{topics_chosen};

	if ($chosen_hr && keys %$chosen_hr) {
		$self->setStoryTopicsChosen($stoid, $chosen_hr);
		my $info_hr = { };
		$info_hr->{neverdisplay} = 1 if $change_hr->{neverdisplay};
		my($primaryskid, $tids) = $self->setStoryRenderedFromChosen($stoid, $chosen_hr,
			$info_hr);
		$change_hr->{primaryskid} = $primaryskid;
		$change_hr->{tid} = $tids->[0] || 0;
	}

	# The day_published column gets automatically updated along
	# with time.

	$change_hr->{day_published} = $change_hr->{'time'} if $change_hr->{'time'};

	# what about stories set to ND?  this is not supported by our OAI code,
	# i think, but let's update anyway -- pudge
	if (grep /^(title|uid|time|introtext|bodytext|primaryskid|tid|neverdisplay|notes)$/, keys %$change_hr) {
		# this is the only place this ever changes
		$change_hr->{-archive_last_update} = 'NOW()';
	}

	# Now we know exactly what columns have to change.  Figure out
	# which tables they belong to.

	my %colname_lookup = ( );
	my %update_tables = ( );
	my @param = ( );
	for my $possibly_prefixed_colname (sort keys %$change_hr) {
		(my $clean_colname = $possibly_prefixed_colname) =~ s/^-//;
		$colname_lookup{$possibly_prefixed_colname} = $clean_colname;
		my $table = $self->{$cache}{$clean_colname};
		if ($table) {
			push @{$update_tables{$table}}, $possibly_prefixed_colname;
		} else {
			push @param, [$possibly_prefixed_colname, $change_hr->{$possibly_prefixed_colname}];
		}
	}

	# Get the list of non-param tables that need to be changed.
	# If there are one or more of them, go ahead and do the
	# non-param changes.
	my $success = 1;
	my @tables = sort keys %update_tables;
	my $do_param_updates = @param ? 1 : 0;
	# If we have to change both param and non-param tables, we
	# need to wrap this in a transaction!
	my $transaction_started = 0;
	if (@tables && @param) {
		$self->sqlDo("SET AUTOCOMMIT=0");
		$transaction_started = 1;
	}
#use Data::Dumper; $Data::Dumper::Sortkeys = 1;
#print STDERR scalar(localtime) . " tables='@tables' param: " . Dumper(\@param);
#print STDERR "change_hr: " . Dumper($change_hr);

	if (@tables) {

		# Update the non-param column names to prepend their table names.
		# This may mean inserting the table name between "-" and the
		# actual name of a column.
		my $fullchange_hr = { };
		for my $possibly_prefixed_colname (sort keys %$change_hr) {
			my $clean_colname = $colname_lookup{$possibly_prefixed_colname};
			my $table = $self->{$cache}{$clean_colname};
			next unless $table; # skip params
			my($dash) = $possibly_prefixed_colname =~ /^(-?)/;
			$fullchange_hr->{"$dash$table.$clean_colname"} = $change_hr->{$possibly_prefixed_colname};
		}

		# Now we can construct the WHERE clause.
		my @where = ( );
		# All the rows changed must share a common stoid.
		for my $table (sort keys %update_tables) {
			push @where, "$table.stoid = $stoid";
		}
		# The last_update option has special meaning.
		if ($options->{last_update}) {
			my $lu_q = $self->sqlQuote($options->{last_update});
			push @where, "stories.last_update = $lu_q";
		}
		my $where = join(" AND ", @where);

#print STDERR "B tables='@tables' where='$where' fullchange_hr: " . Dumper($fullchange_hr);

		# Do the atomic change of all the non-param tables.
		my $rows_matched = $self->sqlUpdate(
			[ @tables ],
			$fullchange_hr,
			$where);
#print STDERR "C rows_matched='$rows_matched'\n";

		# If there were some such changes that had to happen, but
		# they failed (probably because last_update was off), then
		# skip any param changes upcoming.  Note that this really
		# is the number of *matched* rows, which is what we want
		# (not the number of *changed* rows) since
		# mysql_client_found_rows is true by default (see
		# `perldoc DBD::mysql`).
		if ($rows_matched < 1) {
			$do_param_updates = 0;
			$success = 0;
		}

	} elsif ($options->{last_update}) {

		# The only updates we're being asked to do are params.
		# But if we were asked to verify the last_update col,
		# then we have to do that now.  (Normally, if some
		# non-param changes were tried, we'd do that check in
		# the sqlUpdate just above.)
		if (!$transaction_started) {
			$self->sqlDo("SET AUTOCOMMIT=0");
			$transaction_started = 1;
		}
		my $lu = $self->sqlSelect("last_update", "stories",
			"stoid=$stoid");
print STDERR scalar(gmtime) . " stoid '$stoid' lu '$lu' options_lu '$options->{last_update}'\n";
		if ($lu ne $options->{last_update}) {
			$self->sqlDo("ROLLBACK");
			$self->sqlDo("SET AUTOCOMMIT=1");
			$transaction_started = 0;
			$do_param_updates = 0;
			$success = 0;
		}

	}

#print STDERR "E success=$success d_p_u='$do_param_updates' param='@param'\n";
	if ($success && $do_param_updates) {
		for my $duple (@param)  {
			my($name, $value) = @$duple;
			last unless $success;
			if (defined($value) && length($value)) {
				$success = $self->sqlReplace($param_table, {
					stoid	=> $stoid,
					name	=> $name,
					value	=> $value,
				});
			} else {
				my $name_q = $self->sqlQuote($name);
				$success = $self->sqlDelete($param_table,
					"stoid = $stoid AND name = $name_q"
				);
			}
#print STDERR "F did ($name,$value) success=$success\n";
		}
	}

	# Finish up the transaction.
	if ($transaction_started) {
		if ($success) {
			$self->sqlDo("COMMIT");
		} else {
			$self->sqlDo("ROLLBACK");
		}
		$self->sqlDo("SET AUTOCOMMIT=1");
	}

#print STDERR "G success=$success dirty_change=$dirty_change dirty_newval=$dirty_newval\n";

	# If we were asked to mark the story dirty or clean, do so now.
	if ($dirty_change) {
		if ($dirty_newval || !$success) {
			$self->markStoryDirty($stoid);
		} else {
			$self->markStoryClean($stoid);
		}
	}

	# Delete the memcached entry after having done that,
	# to make sure nothing incorrect was set while we were
	# in the middle of updating the DB.
	$self->setStory_delete_memcached_by_stoid([ $stoid ]);
	return $success;
}

########################################################
sub setStory_delete_memcached_by_stoid {
	my($self, $stoid_list) = @_;
	my $mcd = $self->getMCD();
	return unless $mcd;
	my $constants = getCurrentStatic();
	my $mcddebug = $constants->{memcached_debug};

	# Make sure the list of stoids is unique.
	$stoid_list = [ $stoid_list ] if !ref($stoid_list);
	return if !$stoid_list || !@$stoid_list;
	my %stoids = ( map { ($_, 1) } @$stoid_list );
	$stoid_list = [ sort { $a <=> $b } keys %stoids ];

	my @mcdkeys = (
		"$self->{_mcd_keyprefix}:st:",
		"$self->{_mcd_keyprefix}:stc:",
		"$self->{_mcd_keyprefix}:str:",
	);

	for my $stoid (@$stoid_list) {
		for my $mcdkey (@mcdkeys) {
			$mcd->delete("$mcdkey$stoid");
			if ($mcddebug > 1) {
				print STDERR scalar(gmtime) . " $$ setS_deletemcd deleted '$mcdkey$stoid'\n";
			}
		}
	}
}

sub setStory_delete_memcached_by_tid {
	my($self, $tid_list) = @_;
	my $mcd = $self->getMCD();
	return 0 unless $mcd && $tid_list && @$tid_list;

	my $constants = getCurrentStatic();
	my $mins_ahead = $constants->{gse_precache_mins_ahead} + 1; # plus one to be sure
	my $the_time = time;
	my $the_minute = $the_time - $the_time % 60;

	for my $i (0..$mins_ahead-1) {
		for my $tid (@$tid_list) {
			my $mcdkey = "$self->{_mcd_keyprefix}:gse:$tid:$the_minute";
			# The "3" means "don't accept new writes to this key
			# for 3 seconds."
			$mcd->delete($mcdkey);
		}
		$the_minute += 60;
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
	my $num_tries = 10;
	while (1) {
		$formkey = getFormkey();
		my $rows = $self->sqlInsert('formkeys', {
			formkey         => $formkey,
			formname        => $formname,
			uid             => getCurrentUser('uid'),
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

	my $now = $self->getTime({ unix_format => 1 });

	my $response_limit = $constants->{"${formname}_response_limit"} || 0;
	return 0 if !$response_limit;

	my($response_time) = $self->sqlSelect("$now - ts", 'formkeys',
		'formkey = ' . $self->sqlQuote($form->{formkey}));

	if ($constants->{DEBUG}) {
		print STDERR "SQL select $now - ts from formkeys where formkey = '$form->{formkey}'\n";
		print STDERR "LIMIT REACHED $response_time\n";
	}

	return ($response_time && $response_time > 0 && $response_time < $response_limit)
		? $response_time : 0;
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
	my $timeframe = $self->getFormkeyTimeframe();

	my $formkey_earliest = time() - $timeframe;

	my $where = $self->_whereFormkey();
	$where = "($where OR subnetid = '$subnetid')"
		if $constants->{lenient_formkeys} && isAnon($uid);
	
	my($is_valid);
	if ($timeframe) {
		$is_valid = $self->sqlSelect(
			'COUNT(*)',
			'formkeys',
			"formkey = $formkey_quoted
			 AND $where
			 AND ts >= $formkey_earliest AND formname = '$formname'"
		);
		print STDERR "ISVALID $is_valid\n" if $constants->{DEBUG};
		return 'invalid' if !$is_valid;
	} else {
		$is_valid = 1;
	}
	
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
		-idcount        => 'GREATEST(0, idcount-1)',
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
	my $formkey_q = $self->sqlQuote($formkey);
	my $updated = $self->sqlUpdate("formkeys", $update_ref, "formkey=$formkey_q");

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
sub getFormkeyTimeframe {
	my($self) = @_;
	my $constants = getCurrentStatic();
	
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	my $counts_as_anon;
	if (($user->{is_anon} || $user->{karma} < $constants->{formkey_minloggedinkarma} || $form->{postanon}) && !$user->{is_subscriber}){
		$counts_as_anon = 1;
	} else {
		$counts_as_anon = 0;
	}

	my $formkey_timeframe = $counts_as_anon ? $constants->{formkey_timeframe_anon} : 0;
	$formkey_timeframe ||= $constants->{formkey_timeframe} || 0;
	if ($user->{is_subscriber} && exists $constants->{formkey_timeframe_sub}){
		$formkey_timeframe = $constants->{formkey_timeframe_sub};
	}
	print STDERR "Timeframe: $formkey_timeframe, caa: $counts_as_anon \n" if $constants->{DEBUG};

	return $formkey_timeframe ? $formkey_timeframe : 0;
}

##################################################################
sub checkPostInterval {
	my($self, $formname) = @_;
	$formname ||= getCurrentUser('currentPage');
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();

	my $counts_as_anon;
	if (($user->{is_anon} || $user->{karma} < $constants->{formkey_minloggedinkarma} || $form->{postanon}) && !$user->{is_subscriber}){
		$counts_as_anon = 1;
	} else {
		$counts_as_anon = 0;
	}

	my $speedlimit_name = "${formname}_speed_limit";
	my $speedlimit_anon_name = "${formname}_anon_speed_limit";
	my $speedlimit_sub_name = "${formname}_sub_speed_limit";
	my $speedlimit = $counts_as_anon ? $constants->{$speedlimit_anon_name} : 0;
	$speedlimit ||= $constants->{$speedlimit_name} || 0;
	if ($user->{is_subscriber} && exists $constants->{$speedlimit_sub_name}){
		$speedlimit = $constants->{$speedlimit_sub_name};
	}
	
	# If this user has access modifiers applied, check for possible
	# different speed limits based on those.  First match, if any,
	# wins.
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $srcids = $user->{srcids};
	my $al2_hr = $srcids ? $reader->getAL2($srcids) : { };
	my $al2_name_used = "_none_";
	AL2_NAME: for my $al2_name (sort keys %$al2_hr) {
		my $sl_name_al2 = $counts_as_anon
			? "${speedlimit_anon_name}_$al2_name"
			: "${speedlimit_name}_$al2_name";
		if (defined $constants->{$sl_name_al2}) {
			$al2_name_used = $al2_name;
			$speedlimit = $constants->{$sl_name_al2};
			last AL2_NAME;
		}
	}

	# Anonymous comment posting can be forced slower progressively.
	if ($formname eq 'comments'
		&& $counts_as_anon
		&& $constants->{comments_anon_speed_limit_mult}
	) {
		my $multiplier = $constants->{comments_anon_speed_limit_mult};
		my $num_comm = $reader->getNumCommPostedAnonByIPID($user->{ipid});
		$speedlimit *= ($multiplier ** $num_comm) if $multiplier != 1;
		$speedlimit = int($speedlimit + 0.5);
	}

	my $time = $self->getTime({ unix_format => 1 });
	my $timeframe = $self->getFormkeyTimeframe();
	$timeframe = $speedlimit if $speedlimit > $timeframe;
	my $formkey_earliest = $time - $timeframe;

	my $options = {};
	$options->{force_ipid} = 1 if $form->{postanon};
	my $where = $self->_whereFormkey($options);
	$where .= " AND formname = '$formname'";
	$where .= " AND ts >= $formkey_earliest";

	my($interval) = $self->sqlSelect(
		"$time - MAX(submit_ts)",
		"formkeys",
		$where);

	$interval ||= 0;
	print STDERR "CHECK INTERVAL $interval speedlimit $speedlimit al2_used $al2_name_used f_e $formkey_earliest uid $user->{uid} c_a_n $counts_as_anon\n" if $constants->{DEBUG};

	return ($interval < $speedlimit && $speedlimit > 0) ? $interval : 0;
}

##################################################################
sub checkMaxReads {
	my($self, $formname) = @_;
	my $constants = getCurrentStatic();

	my $maxreads = $constants->{"max_${formname}_viewings"} || 0;
	my $formkey_earliest = time() - $self->getFormkeyTimeframe();

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

	my $formkey_earliest = time() - $self->getFormkeyTimeframe();
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
	my $user_mp_num = $user_check->{mailpass_num} || 0;
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
		my $user_mp_num = $self->getUser($user_set->{uid}, 'mailpass_num') || 0;
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
		"COUNT(*) AS times_posted",
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
sub setExpired {
	my($self, $uid) = @_;
	die "setExpired API not updated for AL2";
#	if  ($uid && !$self->checkExpired($uid)) {
#		$self->setUser($uid, { expired => 1 });
#		$self->setAccessList({ uid => $uid }, [qw( nopost )], 'expired');
#	}
}

##################################################################
sub setUnexpired {
	my($self, $uid) = @_;
	die "setUnexpired API not updated for AL2";
#	if ($uid && $self->checkExpired($uid)) {
#		$self->setUser($uid, { expired => 0 });
#		$self->setAccessList({ uid => $uid }, [ ], '');
#	}
}

##################################################################
sub checkExpired {
	my($self, $uid) = @_;
	die "checkExpired API not updated for AL2";
#	return 0 if !$uid;
#	my $rows = $self->sqlCount(
#		"accesslist",
#		"uid = '$uid' AND now_nopost = 'yes' AND reason = 'expired'"
#	);
#	return $rows ? 1 : 0;
}

###################################################################
# Just a convenience method, a wrapper around checkReadOnly that is
# almost as easy to call as $constants->{allow_anonymous} used to be.
# (This should only be passed a UID known to be anonymous.)
sub checkAllowAnonymousPosting {
	my($self, $anon_uid) = @_;
	$anon_uid ||= getCurrentAnonymousCoward('uid');
	return !$self->checkAL2({ uid => $anon_uid }, 'nopost');
}

sub getKnownOpenProxy {
	my($self, $ip, $ip_col) = @_;
	return 0 unless $ip;
	my $col = "ip";
	$col = "ipid" if $ip_col && $ip_col eq "ipid";
	my $ip_q = $self->sqlQuote($ip);
	my $hours_back = getCurrentStatic('comments_portscan_cachehours') || 48;
	my $port = $self->sqlSelect("port",
		"open_proxies",
		"$col = $ip_q AND ts >= DATE_SUB(NOW(), INTERVAL $hours_back HOUR)");
#print STDERR scalar(localtime) . " getKnownOpenProxy returning " . (defined($port) ? "'$port'" : "undef") . " for ip '$ip'\n";
	# XXX also checkAL2(srcid, 'openproxy') here?
	return $port;
}

sub setKnownOpenProxy {
	my($self, $ip, $port, $duration) = @_;
	return 0 unless $ip;
	my $xff;
	if ($port) {
		my $r = Apache2::RequestUtil->request;
		$xff = $r->headers_in->get('X-Real-IP') if $r;
#use Data::Dumper; print STDERR "sKOP headers_in: " . Dumper([ $r->headers_in ]) if $r;
	}
	$xff = undef unless $xff && length($xff) >= 7
		&& $xff =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/;
	$duration = undef if !$duration;
	# XXX also setAL2(srcid, 'openproxy', {some admin uid}) here?
#print STDERR scalar(localtime) . " setKnownOpenProxy doing sqlReplace ip '$ip' port '$port'\n";
	return $self->sqlReplace("open_proxies", {
		ip =>	$ip,
		port =>	$port,
		dur =>	$duration,
		-ts =>	'NOW()',
		xff =>	$xff,
		-ipid => "MD5('$ip')"
	});
}

sub checkForOpenProxy {
	my($self, $ip) = @_;

	# MC: Depreicated, old portscanner code was here. Gone.
	return 0;
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
		"COUNT(*) AS count, SUM(points-pointsorig) AS sum",
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
# Performance on this is pretty much guaranteed to be horrid.
# Code which is not admin-only should not call this.
sub getSubnetFromIPIDBasedOnComments {
	my($self, $ipid) = @_;
	my $ipid_q = $self->sqlQuote($ipid);
	my($subnet) = $self->sqlSelect('subnetid', 'comments',
		"ipid = $ipid_q AND subnetid IS NOT NULL AND subnetid != ''",
		'LIMIT 1');
	return $subnet;
}

########################################################
# XXXSRCID For performance reasons, this should be generated periodically
# for all subnets that have posted recently, and the values of any such
# restrictions written using setAL2.  Lookups would then be very fast.
sub getNetIDPostingRestrictions {
	my($self, $type, $value) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $restrictions = { no_anon => 0, no_post => 0 };

	if ($type eq "subnetid") {
		my $subnet_karma_comments_needed = $constants->{subnet_comments_posts_needed} || 5;
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

	if ($constants->{comment_karma_disable_and_log}) {
		$user->{state}{commentkarma_no_post} = 1 if $restrictions->{no_post};
		$user->{state}{commentkarma_no_anon} = 1 if $restrictions->{no_anon};
		$restrictions = { no_anon => 0, no_post => 0 };
	}
	
	return $restrictions;
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
	$banlist_ref = $self->{_banlist_cache} ||= {};

	if ($refresh) {
		# If the caller asked us to refresh from the DB,
		# then zap the cache.
		%$banlist_ref = ();
	} elsif ($mcd && !keys %$banlist_ref) {
		# If the caller said it was OK to use the cache, but
		# there's nothing in the cache, try MCD first.
		if ($banlist_ref && scalar(keys %$banlist_ref)) {
			$banlist_ref = $mcd->get($mcdkey);
			$self->{_banlist_cache} = $banlist_ref;
			$self->{_banlist_cache_time} ||= time();
			return $banlist_ref;
		}
	}

	# If there's nothing in the cache, fill it from the DB.

	if (!keys %$banlist_ref) {
		if ($debug) {
			print STDERR scalar(gmtime) . " pid $$ gBL (re)fetching ban\n";
		}
		my $list = $self->getAL2List('ban');
		for (@$list) {
			$banlist_ref->{$_} = 1;
		}
		# Just in case the anonymous coward got accidentally onto
		# the list:  we don't allow the A.C. to be banned from
		# the entire site!
		delete $banlist_ref->{ $constants->{anon_coward_uid} };
		# why this? in case there are no banned users.
		# (this should be unnecessary;  we could use another var to
		# indicate whether the cache is fresh, besides checking its
		# number of keys at the top of this "if")
		$banlist_ref->{_junk_placeholder} = 1;
		$self->{_banlist_cache_time} = time() if !$self->{_banlist_cache_time};

		if ($mcd) {
			$mcd->set($mcdkey, $banlist_ref, $constants->{banlist_expire} || 900);
			if ($debug) {
				print STDERR scalar(gmtime) . " gBL pid $$ set mcd key '$mcdkey' keycount " . scalar(keys %$banlist_ref) . "\n";
			}
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
sub getNorssList {
	my($self, $refresh) = @_;
	my $constants = getCurrentStatic();
	my $debug = $constants->{debug_db_cache};
	my $mcd = $self->getMCD();
	my $mcdkey = "$self->{_mcd_keyprefix}:al:norss" if $mcd;
	my $norsslist_ref;

	# Randomize the expire time a bit;  it's not good for the DB
	# to have every process re-ask for this at the exact same time.
	my $expire_time = $constants->{banlist_expire};
	$expire_time += int(rand(60)) if $expire_time;
	_genericCacheRefresh($self, 'norsslist', $expire_time);
	$norsslist_ref = $self->{_norsslist_cache} ||= {};

	if ($refresh) {
		# If the caller asked us to refresh from the DB,
		# then zap the cache.
		%$norsslist_ref = ();
	} elsif ($mcd && !keys %$norsslist_ref) {
		# If the caller said it was OK to use the cache, but
		# there's nothing in the cache, try MCD first.
		$norsslist_ref = $mcd->get($mcdkey);
		if ($norsslist_ref && scalar(keys %$norsslist_ref)) {
			$norsslist_ref = $mcd->get($mcdkey);
			$self->{_norsslist_cache} = $norsslist_ref;
			$self->{_norsslist_cache_time} ||= time();
			return $norsslist_ref;
		}
	}

	# If there's nothing in the cache, fill it from the DB.

	if (!keys %$norsslist_ref) {
		if ($debug) {
			print STDERR scalar(gmtime) . " pid $$ gNL (re)fetching norss\n";
		}
		my $list = $self->getAL2List('norss');
		for (@$list) {
			$norsslist_ref->{$_} = 1;
		}
		# why this? in case there are no RSS-banned users.
		# (this should be unnecessary;  we could use another var to
		# indicate whether the cache is fresh, besides checking its
		# number of keys at the top of this "if")
		$norsslist_ref->{_junk_placeholder} = 1;
		$self->{_norsslist_cache_time} = time() if !$self->{_norsslist_cache_time};

		if ($mcd) {
			$mcd->set($mcdkey, $norsslist_ref, $constants->{banlist_expire} || 900);
			if ($debug) {
				print STDERR scalar(gmtime) . " gNL pid $$ set mcd key '$mcdkey' keycount " . scalar(keys %$norsslist_ref) . "\n";
			}
		}
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
	my $mcd = $self->getMCD();
	my $mcdkey = "$self->{_mcd_keyprefix}:al:nopalm" if $mcd;
	my $nopalmlist_ref;

	# Randomize the expire time a bit;  it's not good for the DB
	# to have every process re-ask for this at the exact same time.
	my $expire_time = $constants->{banlist_expire};
	$expire_time += int(rand(60)) if $expire_time;
	_genericCacheRefresh($self, 'nopalmlist', $expire_time);
	$nopalmlist_ref = $self->{_nopalmlist_cache} ||= {};

	if ($refresh) {
		# If the caller asked us to refresh from the DB,
		# then zap the cache.
		%$nopalmlist_ref = ();
	} elsif ($mcd && !keys %$nopalmlist_ref) {
		# If the caller said it was OK to use the cache, but
		# there's nothing in the cache, try MCD first.
		$nopalmlist_ref = $mcd->get($mcdkey);
		if ($nopalmlist_ref && scalar(keys %$nopalmlist_ref)) {
			$nopalmlist_ref = $mcd->get($mcdkey);
			$self->{_nopalmlist_cache} = $nopalmlist_ref;
			$self->{_nopalmlist_cache_time} ||= time();
			return $nopalmlist_ref;
		}
	}

	if (!keys %$nopalmlist_ref) {
		if ($debug) {
			print STDERR scalar(gmtime) . " gNL pid $$ (re)fetching nopalm\n";
		}
		my $list = $self->getAL2List('nopalm');
		for (@$list) {
			$nopalmlist_ref->{$_} = 1;
		}
		# why this? in case there are no Palm-banned users.
		# (this should be unnecessary;  we could use another var to
		# indicate whether the cache is fresh, besides checking its
		# number of keys at the top of this "if")
		$nopalmlist_ref->{_junk_placeholder} = 1;
		$self->{_nopalmlist_cache_time} = time() if !$self->{_nopalmlist_cache_time};

		if ($mcd) {
			$mcd->set($mcdkey, $nopalmlist_ref, $constants->{banlist_expire} || 900);
			if ($debug) {
				print STDERR scalar(gmtime) . " gNL pid $$ set mcd key '$mcdkey' keycount " . scalar(keys %$nopalmlist_ref) . "\n";
			}
		}
	}

	if ($debug) {
		my $time = time;
		my $diff = $time - $self->{_nopalmlist_cache_time};
		print STDERR scalar(gmtime) . " pid $$ gNL time='$time' diff='$diff' self->_nopalmlist_cache_time='$self->{_nopalmlist_cache_time}' self->{_nopalmlist_cache} keys: " . scalar(keys %{$self->{_nopalmlist_cache}}) . "\n";
	}

	return $nopalmlist_ref;
}

##################################################################
sub countSubmissionsFromUID {
	my($self, $uid, $options) = @_;
	return 0 if !$uid || isAnon($uid);
	my $constants = getCurrentStatic();
	my $days_back = $options->{days_back} || $constants->{submission_count_days};
	my $uid_q = $self->sqlQuote($uid);
	my $del_clause = '';
	$del_clause = " AND del = ".$self->sqlQuote($options->{del}) if defined $options->{del};
	return $self->sqlCount("submissions",
		"uid=$uid_q
		 AND time >= DATE_SUB(NOW(), INTERVAL $days_back DAY) $del_clause");
}

sub countSubmissionsFromIPID {
	my($self, $ipid, $options) = @_;
	return 0 if !$ipid;
	my $constants = getCurrentStatic();
	my $days_back = $options->{days_back} || $constants->{submission_count_days};
	my $ipid_q = $self->sqlQuote($ipid);
	my $del_clause = '';
	$del_clause = " AND del = ".$self->sqlQuote($options->{del}) if defined $options->{del};
	return $self->sqlCount("submissions",
		"ipid=$ipid_q
		 AND time >= DATE_SUB(NOW(), INTERVAL $days_back DAY) $del_clause");
}

sub countSubmissionsWithEmaildomain {
	my($self, $emaildomain, $options) = @_;
	return 0 if !$emaildomain;
	my $constants = getCurrentStatic();
	my $days_back = $options->{days_back} || $constants->{submission_count_days};
	my $emaildomain_q = $self->sqlQuote($emaildomain);
	my $del_clause = '';
	$del_clause = " AND del = ".$self->sqlQuote($options->{del}) if defined $options->{del};
	return $self->sqlCount("submissions USE INDEX (time_emaildomain)",
		"emaildomain=$emaildomain_q
		 AND time >= DATE_SUB(NOW(), INTERVAL $days_back DAY) $del_clause"
	);
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
# Pass this private utility method a hashref or arrayref and, based
# on the uid/ipid/subnetid fields in that data, it returns:
# 1. a WHERE clause that can be used to select rows from al2
#    that apply to this user;
# 2. an arrayref of srcid's suitable for passing to sqlUpdate() etc.
sub _get_where_and_valuelist_al2 {
	my($self, $srcids) = @_;
	$srcids ||= getCurrentUser('srcids');

	my @values = ( );
	if (ref($srcids) eq 'HASH') {
		@values = values %$srcids;
	} elsif (ref($srcids) eq 'ARRAY') {
		@values = @$srcids;
	}
#	else {
#		use Data::Dumper;
#		warn "logic error: arg to _get_where_and_valuelist_al2 was: " . Dumper($srcids);
#		# We will return an appropriate error value below.
#	}

	# A srcid type that get_srcid_sql_in() does not accept is the
	# raw IP number.  Eliminate those.
	@values = grep { !/\./ } @values;

	# Get the SQL that matches those srcids.
	@values = map { get_srcid_sql_in($_) } @values;

	if (!@values) {
		# Error.  Return a where clause that matches nothing.
		return(
			'1=0',
			[ ]
		);
	}

	return(
		"srcid IN (" . join(",", @values) . ")",
		[ @values ]
	);
}

##################################################################

{ # closure
my %_al2_types = ( );
sub _load_al2_types {
	my($self) = @_;
	%_al2_types = %{ $self->sqlSelectAllHashref('name', '*', 'al2_types') };
}
sub getAL2Types {
	my($self) = @_;
	$self->_load_al2_types if !keys %_al2_types;
	# Return a copy of the cache, just in case anyone munges it up.
	my $types = {( %_al2_types )};
	return $types;
}
} # end closure

{ # closure
my $_al2_type_aliases = undef;
sub _load_al2_type_aliases {
	my($self) = @_;
	my $alias_text = getCurrentStatic('al2_type_aliases') || '';
	$_al2_type_aliases = { };
	return if !$alias_text;
	my @aliases = grep { $_ } split /\s+/, $alias_text;
	for my $alias (@aliases) {
		my($src, $implied) = $alias =~ /^(\w+)->(\w+)$/;
		if ($src && $implied) {
			$_al2_type_aliases->{$src} ||= [ ];
			push @{ $_al2_type_aliases->{$src} }, $implied;
		}
	}
}
sub getAL2TypeAliases {
	my($self) = @_;
	$self->_load_al2_type_aliases if !defined($_al2_type_aliases);
	# Return a copy of the cache, just in case anyone munges it up.
	my $aliases = {( %$_al2_type_aliases )};
	return $aliases;
}
} # end closure

{ # closure
my %_al2_types_by_id = ( );
sub getAL2TypeById {
	my($self, $al2tid) = @_;
	return undef if !$al2tid;
	# Return from cache if available.
	return $_al2_types_by_id{$al2tid} if defined($_al2_types_by_id{$al2tid});
	# Need to scan the hash.
	my $al2types = $self->getAL2Types;
	my $name = '';
	for my $n (keys %$al2types) {
		if ($al2types->{$n}{al2tid} eq $al2tid) {
			$name = $n;
			last;
		}
	}
	if (!$name) {
		return undef;
	} else {
		# Cache only valid answers.  If new types are added,
		# they will appear in the cache.
		$_al2_types_by_id{$al2tid} = $al2types->{$name};
		return $al2types->{$name};
	}
}
} # end closure

##################################################################

# $slashdb->setAL2('201234567890abcd',
# 	{ norss => 0, trusted => 1, comment => 'we love these guys' },
# 	{ adminuid => 78724 });

# This method always succeeds unless srcid is 0.  It returns
# 1 if a row was actually added to al2, 0 if there was merely an
# existing row that was updated.

sub setAL2 {
	my($self, $srcid, $type_hr, $options) = @_;
	return undef if !$srcid;
	my $adminuid = $options->{adminuid} || getCurrentUser('uid') || 0;
	my $ts_sql = $options->{ts} ? $self->sqlQuote($options->{ts}) : 'NOW()';

	my $al2types = $self->getAL2Types;
	my $srcid_sql_in = get_srcid_sql_in($srcid);
#if (!$srcid_sql_in) {
#use Data::Dumper; $Data::Dumper::Sortkeys = 1;
#print STDERR "srcid=$srcid srcid_sql_in=$srcid_sql_in for type_hr: " . Dumper($type_hr);
#}
	# First check the al2 table to get an updatecount for any
	# existing row for this srcid.  It's quite possible there
	# is none, which is fine.
	my($oldcount, $oldvalue) = $self->sqlSelect('updatecount, value',
		'al2', "srcid=$srcid_sql_in");
	my $did_add_row = defined($oldcount) ? 0 : 1;
	$oldcount ||= 0; $oldvalue ||= 0;
#print STDERR "setAL2 did_add_row=$did_add_row, after select value oldvalue=$oldvalue\n";
	# Now INSERT the rows for all these changes into al2_log,
	# one row for each field in type_hr
	my $newvalue = $oldvalue;
	# Run the loop to log the changes in type id order.
	my @types =
		map { $_->{name} }
		grep { $_ && $_->{name} }
		map { $self->getAL2TypeById($_) }
		sort { $a <=> $b }
		map { $al2types->{$_}{al2tid} }
		grep { exists $al2types->{$_} }
		keys %$type_hr;
	for my $type (@types) {
		# undef for a type field means "don't change or log anything"
		next if !defined $type_hr->{$type};
		my $value = $type_hr->{$type};
		# Drop a row in the log for this type.
		my $rows = $self->createAL2Log({
			srcid_sql_in =>	$srcid_sql_in,
			ts_sql =>	$ts_sql,
			adminuid =>	$adminuid,
			type =>		$type,
			value =>	$value,
		});
		# XXXSRCID error-checking! failure here should abort
		# this whole method, and I want to wrap this
		# method in a transaction so I can ROLLBACK in that case.
		# Now update the new value that we're going to write
		# back, for this type.
		my $bitpos = $al2types->{$type}{bitpos};
		# undef for a bit position means "don't change value
		# of any bits"
		next if !defined($bitpos);
		my $bitmask = 1 << $bitpos;
		if ($value) {
			$newvalue |=  $bitmask;
		} else {
			$newvalue &= ~$bitmask;
		}
#print STDERR "setAL2 after type=$type newvalue=$newvalue\n";
	}
	# Now do an INSERT IGNORE into al2 just to be sure that a
	# row exists for the next operation we're going to do.  If
	# there was no row before, $oldcount will be 0 which is the
	# value we're going to insert, which is what we want.
	$self->sqlInsert('al2', {
			-srcid =>	$srcid_sql_in,
			updatecount =>	0,
		}, { ignore => 1 });
	# Now UPDATE the row with that srcid, which might be the one
	# we just inserted or might not, to reflect the new data.
	# If updatecount is not what we expect, it means atomicity
	# is broken because some other process updated it since the
	# first SELECT that got the updatecount.  That's fine, we
	# let that other process's change stand and trust that the
	# task will update the value soon enough.
	my $updated = $self->sqlUpdate('al2', {
			-srcid =>	$srcid_sql_in,
			value =>	$newvalue,
			-updatecount =>	'updatecount+1',
		}, "srcid=$srcid_sql_in AND updatecount=$oldcount");
#print STDERR "setAL2 rows updated=$updated\n";
	if ($updated) {
		# XXXSRCID Invalidate memcached cache here if and only
		# if the sqlUpdate succeeded.  Failure is not an error
		# however.
	}
	return $did_add_row;
}

sub createAL2Log {
	my($self, $hr) = @_;
	my $al2types = $self->getAL2Types;
	my $al2tid = $al2types->{ $hr->{type} }{al2tid};

	# The "val" column is an ENUM that's either the word "set" or
	# "clear", but in the case of the "comment" type, it's NULL.
	my $val = $hr->{value} ? 'set' : 'clear';
	$val = undef if $hr->{type} eq 'comment';

	my $rows = $self->sqlInsert("al2_log", {
		-srcid =>	$hr->{srcid_sql_in},
		-ts =>		$hr->{ts_sql} || 'NOW()',
		adminuid =>	$hr->{adminuid} || getCurrentUser('uid'),
		al2tid =>	$al2tid,
		val =>		$val,
	});
#	if (!$rows) {
#		use Data::Dumper; $Data::Dumper::Sortkeys = 1;
#		warn scalar(localtime) . " $$ createAL2Log log insert failed for hr: " . Dumper($hr);
#	}
	if ($rows && $hr->{type} eq 'comment') {
		# The type named 'comment' is a special case:  we insert
		# a row into al2_log_comments as well.
		my $al2lid = $self->getLastInsertId();
		$rows = $self->sqlInsert("al2_log_comments", {
			al2lid =>	$al2lid,
			comment =>	$hr->{value},
		});
		if (!$rows) {
			warn scalar(localtime) . " $$ createAL2Log comment insert failed '$al2lid' '$hr->{srcid_sql_in}'";
		}
	}
	return $rows;
}

# Passing in multiple srcids here is A-OK because typically the user
# will _have_ multiple srcids (ipid, subnetid, and maybe uid).
# Multiple srcids can be passed in as an arrayref or as the values in
# a hashref.  Or, it works fine with a single srcid, either scalar or
# in a hashref.

sub getAL2 {
	my($self, $srcids) = @_;

	# If an empty value is passed in for srcids, use the current user.
	if (!$srcids) {
		$srcids = getCurrentUser('srcids');
	} elsif (ref($srcids) eq 'ARRAY' && !@$srcids) {
		$srcids = getCurrentUser('srcids');
	} elsif (ref($srcids) eq 'HASH' && !keys(%$srcids)) {
		$srcids = getCurrentUser('srcids');

	# If a scalar is passed in for srcids, make it into a simple hashref.
	} elsif (!ref($srcids)) {
		$srcids = { get_srcid_type($srcids) => $srcids };
	}

	# XXXSRCID Try to use memcached to retrieve this data.
	my($where) = $self->_get_where_and_valuelist_al2($srcids);
	my $values = $self->sqlSelectColArrayref('value', 'al2', $where);

	# The al2.value column ORs together for all the AL2 rows that
	# apply for a user.  E.g. if the subnet has 'nopost' set, the
	# IP has 'nosubmit' and the uid has 'trusted', all three of
	# those will be returned.
	my $bitvector = 0;
	for my $value (@$values) {
		$bitvector |= $value;
	}

	# Return a hashref with one field set for each bit set.
	my $al2types = $self->getAL2Types;
	my $retval = { };
	for my $name (keys %$al2types) {
		if (defined($al2types->{$name}{bitpos})
			&& ( $bitvector & ( 1 << $al2types->{$name}{bitpos} ) )
		) {
			$retval->{$name} = $al2types->{$name};
		}
	}

	# If there are any al2 type aliases, return dummy hashref fields
	# for them too.
	my $aliases = $self->getAL2TypeAliases();
	for my $src (keys %$aliases) {
		if ($retval->{$src}) {
			my $implied_ar = $aliases->{$src};
			for my $imp (@$implied_ar) {
				$retval->{$imp} ||= { implied_by => $src };
			}
		}
	}

	return $retval;
}

# Passing in more than one srcid in a hashref is allowed, but the
# typical use for this will be just one at a time.

sub getAL2Log {
	my($self, $srcid) = @_;
	my $constants = getCurrentStatic();

	if (!ref($srcid)) {
		$srcid = { get_srcid_type($srcid) => $srcid };
	}
	my($where) = $self->_get_where_and_valuelist_al2($srcid);

	# Do the main select on al2_log to pull in all the changes made
	# for this srcid.
	my $rows = $self->sqlSelectAllHashrefArray(
		'*, UNIX_TIMESTAMP(ts) AS ts_ut',
		'al2_log', $where,
		"ORDER BY al2lid");
	my @al2lids = ( );
	for my $row (@$rows) {
		push @al2lids, $row->{al2lid};
	}

	# Do a second select on al2_log_comments to pull in any comment
	# data there may be and attach it to each row.
	if (@al2lids) {
		# XXXSRCID This could be a weensy bit more efficient by
		# having an @al2lids_comment which only includes those
		# rows for which al2tid == $all_al2types->{comment}{al2tid}
		my $al2lids_where = join(", ", @al2lids);
		my $comments = $self->sqlSelectAllKeyValue('al2lid, comment',
			'al2_log_comments',
			"al2lid IN ($al2lids_where)");
		for my $row (@$rows) {
			if ($comments->{ $row->{al2lid} }) {
				$row->{comment} = $comments->{ $row->{al2lid} };
			}
		}
	}

	# For convenience, pull the al2_type information for each row and
	# attach that as well.
	for my $row (@$rows) {
		my $al2tid = $row->{al2tid};
		my $al2type = $self->getAL2TypeById($al2tid);
		if (!$al2type) {
			# Sanity checking.
			warn "no al2type for '$al2tid'";
			next;
		}
		$row->{bitpos} = $al2type->{bitpos};
		$row->{name}   = $al2type->{name};
		$row->{title}  = $al2type->{title};
	}

	return $rows;
}

# Convenience method to return an arrayref of all comments that
# have been posted for a srcid. Adminuids and timestamps for
# those comments are not included, just the text.  Returns the
# comments in chronological order.

sub getAL2Comments {
	my($self, $srcids) = @_;
	my $com_ar = [ ];
	my $al2_log = $self->getAL2Log($srcids);
	return $com_ar unless $al2_log && @$al2_log;
	for my $row (@$al2_log) {
		next unless $row->{comment};
		push @$com_ar, $row->{comment};
	}
	return $com_ar;
}

sub checkAL2 {
	my($self, $srcids, $type) = @_;
	my $type_ar = ref($type) ? $type : [ $type ];

	# If the caller is querying about a type that does not
	# exist for this site, that's OK, it just means that no
	# srcid can have it.  If none of the types given exist,
	# we can return without querying the DB.
	my $types = $self->getAL2Types();
	my $any_exist = 0;
	for my $t (@$type_ar) {
		$any_exist = 1, last if exists $types->{$t};
	}
	return 0 unless $any_exist;

	# It's at least possible that the srcids have one or more
	# of these types, so run the check.
	my $data = $self->getAL2($srcids);
	for my $t (@$type_ar) {
		return 1 if exists $types->{$t} && $data->{$type};
	}
	return 0;
}

sub getAL2List {
	my($self, $type_name, $offset, $count) = @_;
	$offset ||= 0; $count ||= 0;
	my $where = "";
	if ($type_name) {
		# Return only al2 entries with this kind of access modifier.
		# (or access restriction).
		my $al2types = $self->getAL2Types;
		my $bitpos = $al2types->{$type_name}{bitpos};
		# Sanity check, probably redundant.
		if (!$al2types->{$type_name} || !defined($al2types->{$type_name}{bitpos})) {
			warn scalar(localtime) . " $$ getAL2List failed sanity check '$type_name'";
			return [ ];
		}
		my $mask = 1 << $bitpos;
		# It may seem silly to limit the value column twice, but
		# it can speed things up.  MySQL will only use an index
		# for a clause where a column appears unmodified on one
		# side of an (in)equality.  We provide the "value > x"
		# clause even though the second clause limits the results
		# more strictly, so MySQL can make a reasonable decision
		# about whether to use that first clause to pull rows
		# using an index instead of doing a table scan.
		$where = "value >= $mask AND (value & $mask) > 0";
	}
	my $other = "";
	# XXXSRCID Double-check this logic, I wrote it in a taxi
	if ($count) {
		$other = "LIMIT $offset, $count";
	}
	my $srcids = $self->sqlSelectColArrayref(
		get_srcid_sql_out('srcid'),
		"al2", $where, $other);
	return $srcids;
}

#################################################################
# Grandfathered to work with AL2.  Deprecated.  Calling checkAL2()
# directly is preferred.
sub checkIsProxy {
	my($self, $ipid) = @_;
	my $result = $self->checkAL2(convert_srcid(ipid => $ipid), 'proxy')
		? 'yes' : 'no';
	return $result;
}

#################################################################
# Grandfathered to work with AL2.  Deprecated.  Calling checkAL2()
# directly is preferred.
sub checkIsTrusted {
	my($self, $ipid) = @_;
	my $result = $self->checkAL2(convert_srcid(ipid => $ipid), 'trusted')
		? 'yes' : 'no';
	return $result;
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
		'nickname,lasttime,lasttitle,last_subid,last_sid,sessions.uid,last_fhid,last_action',
		'sessions,users',
		'sessions.uid=users.uid GROUP BY sessions.uid'
	);

	return $aids;
}

##################################################################
# Current Active admin users
sub currentActiveAdmin {
	my($self) = @_;
	my $aids = $self->sqlSelectAll(
		'nickname,lasttime,lasttitle,last_subid,last_sid,sessions.uid,last_fhid,last_action',
		'sessions,users',
		'sessions.uid=users.uid AND lasttime IS NOT NULL GROUP BY sessions.uid'
	);

	return $aids;
}

##################################################################
sub getSubmissionsSkins {
	my($self, $skin) = @_;
	my $del = getCurrentForm('del') || 0;

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
	return $self->sqlCount("submissions",
		"(LENGTH(note) < 1 OR note IS NULL) AND del=0");
}

##################################################################
# Get all portals
sub getPortals {
	my($self) = @_;
	my $mainpage_name = $self->getSkin( getCurrentStatic('mainpage_skid') )->{name};
	my $portals = $self->sqlSelectAll('block,title,blocks.bid,url','blocks',
		"skin='$mainpage_name' AND type='portald' AND shill = 'no'",
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
			'bid,title,url,skin,portal,ordernum,all_skins,default_block,hidden,always_on',
			'blocks',
			"hidden != 1 AND (default_block = 1 OR always_on = 1) AND shill = 'no'",
			'ORDER BY ordernum ASC, id ASC'
	);
	# We could get rid of tmp at some point
	my %tmp;
	while (my $SB = $sth->fetchrow_hashref) {
		$self->{_boxes}{$SB->{bid}} = $SB;  # Set the Slashbox
		# Set the skinBoxes
		if ($SB->{all_skins}) {
			for my $skid (keys %$skins) {
				push @{$tmp{$skid}}, $SB->{bid};
			}
		} else {
			# $SB->{skin} is an skid
			push @{$tmp{$SB->{skin}}}, $SB->{bid};
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
	my $signature_quoted = $self->sqlQuote(md5_hex( encode_utf8($comment) ) );
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

sub displaystatusForStories {
	my($self, $stoids) = (@_);
	my $constants = getCurrentStatic();
	my $ds = {};
	return {} unless $stoids and @$stoids;
	my $stoid_list = join ',', @$stoids;

	my @sections_nexuses = grep {$_ != $constants->{mainpage_nexus_tid}} $self->getNexusTids();
	my $section_nexus_list = join ',', @sections_nexuses;

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
		"stories.stoid=str.stoid AND str.tid IN ($section_nexus_list) " .
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
	_genericCacheRefresh($self, $name, $constants->{story_expire} || 600);
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
		# XXXSECTIONTOPICS this is almost right, but not quite

#		# story_never_topic is not implemented yet
#		$where .= " AND story_topics_rendered.tid NOT IN ($user->{story_never_topic})" if $user->{story_never_topic};

		$where .= " AND uid NOT IN ($user->{story_never_author})" if $user->{story_never_author};
		# don't cache if user has own prefs -- pudge
		$key = $user->{story_never_topic}
			|| $user->{story_never_author}
			|| $user->{story_never_nexus}
			? ''
			: "$key|";
	} elsif ($topic) {
		$where .= " AND story_topics_rendered.tid = '$topic'";
		$key .= "|$topic";
	}

	$key .= "|$time" if $key;

	my $now = $self->sqlQuote( time2str('%Y-%m-%d %H:%M:00', time, 'GMT') );

	return $cache->{$key} if $key && defined $cache->{$key};

	my $returnable = $self->sqlSelectHashref(
		'stories.stoid, sid, title, stories.tid',
		"story_text, story_topics_rendered,
		 stories LEFT JOIN story_param ON (stories.stoid=story_param.stoid
			AND story_param.name='neverdisplay')",
		"stories.stoid = story_text.stoid
		 AND stories.stoid = story_topics_rendered.stoid
		 AND '$time' > DATE_SUB($now, INTERVAL $bytime_delay DAY)
		 AND time $sign '$time'
		 AND time <= $now
		 AND in_trash = 'no'
		 AND story_param.stoid IS NULL
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
	my($self, $discussion) = (@_);
	return $self->sqlSelect("sid", "stories", "discussion = ".$self->sqlQuote($discussion));
}

##################################################################
# admin.pl only
sub getStoryByTimeAdmin {
	my($self, $sign, $story, $limit, $options) = @_;
	my $constants = getCurrentStatic();
	my $where = "";
	my $user = getCurrentUser();
	my $mp_tid = getCurrentStatic('mainpage_nexus_tid');
	$limit ||= 1;

	$options ||= {};
	$story   ||= {};

	# '=' is also sometimes used for $sign; in that case,
	# order is irrelevant -- pudge
	my $order = $sign eq '<' ? 'DESC' : 'ASC';

	$where .= " AND sid != '$story->{sid}'" if !$options->{no_story} && $story->{sid};
	my $timebase = $story ? $self->sqlQuote($story->{time}) : "NOW()";
	$where .= " AND DATE_SUB($timebase, INTERVAL $options->{hours_back} HOUR) " if $options->{hours_back};
	$where .= " AND DATE_ADD($timebase, INTERVAL $options->{hours_forward} HOUR) " if $options->{hours_forward};

	my $time = $story->{'time'};
	$time = $self->getTime() if !$story->{time} && $options->{no_story};

	my $limittext = $limit ? " LIMIT $limit" : "";

	my $returnable = $self->sqlSelectAllHashrefArray(
		'stories.stoid, title, sid, time, primaryskid',
		'stories, story_text',
		"stories.stoid=story_text.stoid
		 AND time $sign '$time' AND in_trash = 'no' $where",
		"ORDER BY time $order $limittext"
	);
	foreach my $story (@$returnable) {
		$story->{displaystatus} = $self->_displaystatus($story->{stoid}, { no_time_restrict => 1 });
	}
	return $returnable;
}

########################################################
sub countUsers {
	my($self, $options) = @_;
	my $count = undef;
	my $mcd = $self->getMCD();
	my $mcdkey;
	my $max = $options && $options->{max};
	my $actual = $options && $options->{write_actual};

	if ($max) {
		# Caller wants the maximum uid we've assigned so far.
		if ($mcd) {
			$mcdkey = "$self->{_mcd_keyprefix}:ucm";
			if ($count = $mcd->get($mcdkey)) {
				return $count;
			}
		}
		# This is extremely fast, InnoDB doesn't even look at
		# the table.
		$count = $self->sqlSelect("MAX(uid)", "users");
		if ($mcd) {
			$mcd->set($mcdkey, $count, 1200);
		}
		return $count;
	}

	# Caller wants the actual count of all users (which may be
	# smaller, due to gaps).  First see if we can pull the data
	# from memcached.
	$mcdkey = "$self->{_mcd_keyprefix}:uc" if $mcd;
	if (!$actual && $mcd) {
		if ($count = $mcd->get($mcdkey)) {
			return $count;
		}
	}
	# Nope, wasn't in memcached.  Next see whether we need to
	# actually do the count, or if we can use the var (which
	# is faster than COUNT(*) on an InnoDB table).
	if ($actual) {
		$count = $self->sqlCount('users');
	} else {
		$count = $self->getVar('users_count', 'value', 1) || 1;
	}
	# We have the value now.  Since either memcached failed us
	# or we now have a more authoritative (actual) value,
	# overwrite memcached with this.  Also, if we just got the
	# actual value, write it into the var.
	if ($mcd) {
		# We only really need the user count approximately,
		# so cache it.
		$mcd->set($mcdkey, $count, 1200);
	}
	if ($actual) {
		$self->setVar('users_count', $count);
	}
	return $count;
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
sub getCommentReply {
	my($self, $sid, $pid) = @_;

	my $constants = getCurrentStatic();

	# If we're not replying to anything, we already know the answer.
	return { } if !$pid;

	my $sid_quoted = $self->sqlQuote($sid);
	my $select =
		"date, date AS time, subject,
		 comments.points AS points, comments.tweak AS tweak, pointsorig, tweak_orig,
		 comment_text.comment AS comment, realname, nickname,
		 fakeemail, homepage, comments.cid AS cid, sid,
		 users.uid AS uid, reason, karma_bonus, spam_flag";
	if ($constants->{plugin}{Subscribe} && $constants->{subscribe}) {
		$select .= ", subscriber_bonus";
	}
	my $reply = $self->sqlSelectHashref(
		$select,
		"comments, comment_text, users, users_info, users_comments",
		"sid=$sid_quoted
		 AND comments.cid=$pid
		 AND users.uid=users_info.uid
		 AND users.uid=users_comments.uid
		 AND comment_text.cid=$pid
		 AND users.uid=comments.uid"
	) || {};

	# For a comment we're replying to, there's no need to mod.
	$reply->{no_moderation} = 1 if %$reply;

	return $reply;
}

########################################################
sub getThreadedCommentsForUser {
	my $form = getCurrentForm();
	my($self, $sid, $cid, $options) = @_;
	$options ||= {};

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
	my $other = "";
	my $order_dir = "";
	$order_dir = uc($options->{order_dir}) eq "DESC" ? "DESC" : "ASC" if $options->{order_dir};
	
	# First thing's first, pull counts for each root-level comment
	my $counts = $self->sqlSelectAllHashrefArray("cid, children", "comments", "sid=$sid_quoted AND pid=0", "ORDER BY cid $order_dir");

	my ($pagecount, $page) = (0, 0);
	my $cids; # array ref of arrays containing cids for each page where page number = array index + 1

	foreach my $count (@$counts) {
		push(@{$cids->[$page]}, $count->{cid});
		$pagecount += $count->{children} + 1;
		if($pagecount >= $user->{commentlimit}) {
			$pagecount = 0;
			$page++;
		}
	}
	$page++;
	
	my ($thesecids, $theseopids);
	if ($cids) {
		# If they asked for a page and didn't give us a martian page number
		if(defined $form->{page} && int($form->{page}) <= scalar @$cids && int($form->{page}) > 0 && !$cid) {
			my $index = int($form->{page}) - 1;
			$thesecids = join( ' OR comments.cid=', @{ $cids->[$index] } );
			$theseopids = join( ' OR comments.opid=', @{ $cids->[$index] } );
		}
		# Or if they asked for one comment pull only that opid's thread
		elsif($cid) {
			$thesecids = $cid;
			$theseopids = $self->sqlSelect("opid", "comments", "cid=$cid");
			if($theseopids == "0") {$theseopids = $cid;}
		}
		# Otherwise use the first page
		else {
			$thesecids = join( ' OR comments.cid=', @{$cids->[0]} );
			$theseopids = join( ' OR comments.opid=', @{$cids->[0]} );
		}
	}

	$other.= "ORDER BY opid ASC, cid $order_dir";

	my $select = " comments.cid, date, date as time, subject, nickname, "
		. "homepage, fakeemail, users.uid AS uid, sig, "
		. "comments.points AS points, pointsorig, "
		. "tweak, tweak_orig, subject_orig, children, "
		. "pid, pid AS original_pid, sid, lastmod, reason, "
		. "journal_last_entry_date, ipid, subnetid, "
		. "karma_bonus, spam_flag, "
		. "len, badge_id, comment_text.comment as comment";
	if ($constants->{plugin}{Subscribe} && $constants->{subscribe}) {
		$select .= ", subscriber_bonus";
	}
	# Because fuck a bunch of doing search and replace to add comment text.
	# That shit is insanely expensive compared to this.
	my $tables = "comments LEFT JOIN comment_text ON comments.cid=comment_text.cid LEFT JOIN users ON comments.uid=users.uid";
	
	my $where;
	if ($cids) {
		$where= "sid=$sid_quoted AND (comments.cid=$thesecids OR comments.opid=$theseopids)";
	}
	else {
		$where= "sid=$sid_quoted";
	}

	if ($cid && $one_cid_only) {
		$where .= " AND comments.cid=$cid";
	} elsif ($user->{hardthresh}) {
		my $threshold_q = $self->sqlQuote($user->{threshold});
		$where .= "AND (comments.points >= $threshold_q";
		$where .= "  OR comments.uid=$user->{uid}"      unless $user->{is_anon};
		$where .= "  OR comments.cid=$cid"		       if $cid;
		$where .= ")";
	}

	my $comments = $self->sqlSelectAllHashrefArray($select, $tables, $where, $other);
	return ($comments, scalar($cids));
}

########################################################
sub getFlatCommentsForUser {
	my $form = getCurrentForm();
	my($self, $sid, $cid, $options) = @_;
	$options ||= {};

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
	my $other = "";
	my $order_dir = defined($options->{order_dir}) && uc($options->{order_dir}) eq "DESC" ? "DESC" : "ASC";
	
	# First thing's first, find out how many pages we're gonna say there are in the return value
	my $fpages =  $self->sqlSelect("count(*)", "comments", "sid=$sid_quoted") / $user->{commentlimit};
	my $pages = $fpages != int($fpages) ? int($fpages) + 1 : $fpages;

	if(defined($form->{page}) && $form->{page} > 1 && $form->{page} <= $pages && !$cid) {
		my $skip = int($form->{page} - 1) * $user->{commentlimit};
		$other = "ORDER BY comments.cid $order_dir LIMIT $skip, $user->{commentlimit}";
	}
	else {
		$other = "ORDER BY comments.cid $order_dir LIMIT $user->{commentlimit}";
	}

	my $select = " comments.cid, date, date as time, subject, nickname, "
		. "homepage, fakeemail, users.uid AS uid, sig, "
		. "comments.points AS points, pointsorig, "
		. "tweak, tweak_orig, subject_orig, children, "
		. "pid, pid AS original_pid, sid, lastmod, reason, "
		. "journal_last_entry_date, ipid, subnetid, "
		. "karma_bonus, spam_flag, "
		. "len, badge_id, comment_text.comment as comment";
	if ($constants->{plugin}{Subscribe} && $constants->{subscribe}) {
		$select .= ", subscriber_bonus";
	}
	# Because fuck a bunch of doing search and replace to add comment text.
	# That shit is insanely expensive compared to this.
	my $tables = "comments LEFT JOIN comment_text ON comments.cid=comment_text.cid LEFT JOIN users ON comments.uid=users.uid";
	
	my $where;
	# If they asked for one comment pull only that opid's thread
	if ($cid) {
		my $theseopid = $self->sqlSelect("opid", "comments", "cid=$cid");
		if($theseopid == "0") {$theseopid = $cid;}
		$where = "sid=$sid_quoted AND (comments.cid=$cid OR comments.opid=$theseopid)";
	}
	else {
		$where = "sid=$sid_quoted";
	}

	if ($cid && $one_cid_only) {
		$where .= " AND comments.cid=$cid";
	}

	my $comments = $self->sqlSelectAllHashrefArray($select, $tables, $where, $other);
	

	return ($comments, $pages);
}

########################################################
sub getCommentsForUser {
	my($self, $sid, $cid, $options) = @_;
	$options ||= {};

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
	my $other = "";

	my $order_dir = "";
	$order_dir = uc($options->{order_dir}) eq "DESC" ? "DESC" : "ASC" if $options->{order_dir};

	$other.= "ORDER BY $options->{order_col} $order_dir" if $options->{order_col};
	$other.= " LIMIT $options->{limit}" if $options->{limit};

	my $select = " comments.cid, date, date as time, subject, nickname, "
		. "homepage, fakeemail, users.uid AS uid, sig, "
		. "comments.points AS points, pointsorig, "
		. "tweak, tweak_orig, subject_orig, "
		. "pid, pid AS original_pid, sid, lastmod, reason, "
		. "journal_last_entry_date, ipid, subnetid, "
		. "karma_bonus, spam_flag, "
		. "len, badge_id, comment_text.comment as comment";
	if ($constants->{plugin}{Subscribe} && $constants->{subscribe}) {
		$select .= ", subscriber_bonus";
	}
	# Because fuck a bunch of doing search and replace to add comment text.
	# That shit is insanely expensive compared to this.
	my $tables = "comments LEFT JOIN comment_text ON comments.cid=comment_text.cid LEFT JOIN users ON comments.uid=users.uid";
	my $where = "sid=$sid_quoted";

	if ($cid && $one_cid_only) {
		$where .= "AND comments.cid=$cid";
	} elsif ($user->{hardthresh}) {
		my $threshold_q = $self->sqlQuote($user->{threshold});
		$where .= " AND (comments.points >= $threshold_q";
		$where .= " OR comments.uid=$user->{uid}"	unless $user->{is_anon};
		$where .= " OR comments.cid=$cid"			if $cid;
		$where .= ")";
	}

	$where .= " AND points >= pointsorig " if $options->{skip_downmodded};
	$where .= " AND points > pointsorig " if $options->{only_upmodded};

	my $comments = $self->sqlSelectAllHashrefArray($select, $tables, $where, $other);

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
sub getCommentTextCached {
	my($self, $comments, $cids_needed_ar, $opt) = @_;

	return {} if ! $cids_needed_ar;
	$cids_needed_ar = [$cids_needed_ar] if ! ref $cids_needed_ar;
	$cids_needed_ar = [ grep { $_ } @$cids_needed_ar ];
	return {} if ! @$cids_needed_ar;

	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	$opt ||= {};

	my $possible_chop  = !$opt->{full} && !($opt->{mode} && $opt->{mode} eq 'archive');
	my $abbreviate_ok  = 0;
	my $abbreviate_len = 256;
	my $max_len = $constants->{default_maxcommentsize};

	# We have to get the comment text we need (later we'll search/replace
	# them into the text).
	my $comment_text = {};

	# Should we read/write the parsed comments to/from memcached?
	# This will be possible only if some particular prefs of this user
	# are set to the standard values.  If this is possible, then for
	# almost every comment, we can pull fully rendered text directly
	# from memcached and not have to touch the DB.
	# Currently, the only user prefs that affect comment rendering at
	# this level are whether domaintags are the default, and whether
	# maxcommentsize is the default.
	my $mcd = $self->getMCD();
	$mcd = undef if
		   $opt->{mode} && $opt->{mode} eq 'archive'
		|| $user->{domaintags} eq "0"
		|| $user->{domaintags} eq "1";

	# loop here, pull what cids we can
	my($mcd_debug, $mcdkey, $mcdkey_abbrev, $mcdkey_full, $mcdkeylen);
	if ($mcd) {
		# MemCached key prefix "ctp" means "comment_text, parsed".
		# "f" is same thing but *full* comment, not chopped.
		# "a" means "abbreviated" (keep same len as mcdkey)
		# Prepend our site key prefix to try to avoid collisions
		# with other sites that may be using the same servers.
		$mcdkey_abbrev = "$self->{_mcd_keyprefix}:cta:";
		$mcdkey        = "$self->{_mcd_keyprefix}:ctp:";
		$mcdkey_full   = "$self->{_mcd_keyprefix}:ctf:";
		$mcdkeylen = length($mcdkey);
		if ($constants->{memcached_debug}) {
			$mcd_debug = { start_time => Time::HiRes::time };
		}
	}

	$mcd_debug->{total} = scalar @$cids_needed_ar if $mcd_debug;

	if ($mcd) {
		if ($mcd && $constants->{memcached_debug} && $constants->{memcached_debug} > 2) {
			print STDERR scalar(gmtime) . " getCommentTextCached memcached mcdkey '$mcdkey'\n";
		}
		my @keys_try =
			map {
				$abbreviate_ok && $comments->{$_}{class} eq 'oneline' && !($opt->{cid} && $_ == $opt->{cid})
					? $mcdkey_abbrev . $_
					: $possible_chop && !($opt->{cid} && $_ == $opt->{cid})
						? $mcdkey . $_
						: $mcdkey_full . $_
			}
			@$cids_needed_ar;
		$comment_text = $mcd->get_multi(@keys_try);
		my @old_keys = keys %$comment_text;

		if ($mcd && $constants->{memcached_debug} && $constants->{memcached_debug} > 1) {
			print STDERR scalar(gmtime) . " getCommentTextCached memcached got keys '@old_keys' tried for '@keys_try'\n"
		}
		$mcd_debug->{hits} = scalar @old_keys if $mcd_debug;
		for my $old_key (@old_keys) {
			# XXX We've seen a fairly rare (few times a day)
			# occurrence of "substr outside of string at" the
			# next line, and I'm not sure why.  Throw a warning
			# if we see it, to try to debug.
			if (length($old_key) < $mcdkeylen) {
				print STDERR scalar(gmtime) . " getCommentTextCached bad get_multi key '$old_key' (of '@old_keys')\n"
			}
			my $new_key = substr($old_key, $mcdkeylen);

			# strip out offset for abbrev
			if (substr($old_key, 0, $mcdkeylen) eq $mcdkey_abbrev) {
				if ($comment_text->{$old_key} =~ s/^(-?\d+)://) {
					$comments->{$new_key}{abbreviated} = $1;
				}
			}

			$comment_text->{$new_key} = delete $comment_text->{$old_key};
		}
		@$cids_needed_ar = grep { !exists $comment_text->{$_} } @$cids_needed_ar;
	}

	if ($mcd && $constants->{memcached_debug} && $constants->{memcached_debug} > 1) {
		print STDERR scalar(gmtime) . " getCommentTextCached memcached mcd '$mcd' con '$constants->{memcached}' mcd '$mcd' dt '$user->{domaintags}' mcs '$user->{maxcommentsize}' still needed: '@$cids_needed_ar'\n";
	}


	# Now we get fresh with the comment text. We take all of the cids
	# that we have found and we then speed through the text replacing
	# the tags that were there to hold them.
	my $more_comment_text = $self->getCommentText($cids_needed_ar) || {};
	if ($mcd && $constants->{memcached_debug} && $constants->{memcached_debug} > 1) {
		print STDERR scalar(gmtime) . " more_comment_text keys: '" . join(" ", sort keys %$more_comment_text) . "'\n";
	}

	for my $cid (keys %$more_comment_text) {
		my $abbreviate = $abbreviate_ok && $comments->{$cid}{class} eq 'oneline';
		my $original_text = $more_comment_text->{$cid};
		my $this_max_len = $abbreviate ? $abbreviate_len : $max_len;
		
		if (	   $possible_chop
			&& !($opt->{cid} && $opt->{cid} eq $cid)
			&& ($comments->{$cid}{len} > ($this_max_len + 256))
		) {
			# We remove the domain tags so that strip_html will not
			# consider </a blah> to be a non-approved tag.  We'll
			# add them back at the last step.  In-between, we chop
			# the comment down to size, then massage it to make sure
			# we still have good HTML after the chop.
			my $abbrev_text = parseDomainTags($more_comment_text->{$cid}, 0, 1, 1);
			my $this_len = $this_max_len;
			if ($abbreviate) {
				my $str = $abbrev_text;
				# based on revertQuote() which no longer exists
				# ... we replace the unused content with <<LEN>>
				# and then we know how much we removed, and
				# discard $str when done
				my $bail = 0;
				while ($str =~ m|((<p>)?<div class="quote">)(.+)$|sig) {
					my($found, $p, $rest) = ($1, $2, $3);
					my $pos = pos($str) - (length($found) + length($rest));
					pos($str) = $pos + length($found);

					my $c = 0;
					$bail = 1;
					while ($str =~ m|(<(/?)div.*?>(</p>)?)|sig) {
						my($found, $end, $p2) = ($1, $2, $3);
						if ($end && !$c) {
							$bail = 0;  # if we don't get here, something is wrong
							my $len = length($found);
							my $thislen = pos($str)-$pos;
							substr($str, $pos, $thislen) = "<<$thislen>>";
							pos($str) = 0;
							last;
						} elsif ($end) {
							$c--;
						} else {
							$c++;
						}
					}
					if ($bail) {
						use Data::Dumper;
						warn "Stuck in endless loop: " . Dumper({
							found	=> $found,
							p	=> $p,
							rest	=> $rest,
							'pos'	=> $pos,
							str	=> $str,
						});
						last;
					}
				}

				unless ($bail) {
					$str =~ s/(?<!<)(<[^<>]+>)/'<<'.length($1).'>>'/ge;

					# count up where we're at
					my $plen = $this_len = 0;
					while ($str =~ /([^<>]|<<(\d+)>>)/g) {
						my $len1 = length $1;
						if ($2) {
							$this_len += $2;
						} else {
							$this_len += $len1;
							$plen += $len1;
						}
						last if $plen >= $this_max_len + 256; # rest getting cut anyway
					}
				}
			}
			$abbrev_text = chopEntity($abbrev_text, $this_len);

			# the comments have already gone through approveTag
			# and strip_html to remove disallowed user content,
			# but we might have added disallowed user content
			# after the fact, so we want to make sure it is kept
			# here -- pudge
			local $Slash::Utility::Data::approveTag::admin = 1;
			$abbrev_text = strip_html($abbrev_text);
			$abbrev_text = balanceTags($abbrev_text, { admin => 1 });
			$abbrev_text = addDomainTags($abbrev_text);

			$more_comment_text->{$cid} = $abbrev_text;
		}

		# Now write the new data into our hashref and write it out to
		# memcached if appropriate.  For these purposes, if we were
		# cleared to read from memcached, the data we just got is also
		# valid to write to memcached.
		$comment_text->{$cid} = parseDomainTags($more_comment_text->{$cid},
			$comments->{$cid}{fakeemail});

		# If the comment should have noFollow on its links, apply
		# them here.
		my $karma_bonus = $comments->{$cid}{karma_bonus};
		if (!$karma_bonus || $karma_bonus eq 'no') {
			$comment_text->{$cid} = noFollow($comment_text->{$cid});
		}

		if ($abbreviate) {
			my $text_a = $original_text;
			my $text_b = $comment_text->{$cid};

			$text_a = parseDomainTags($text_a, $comments->{$cid}{fakeemail});
			if (!$karma_bonus || $karma_bonus eq 'no') {
				$text_a = noFollow($text_a);
			}

			# normalize whitespace between tags
			s/> </></g for ($text_a, $text_b);
			# -1: no change, 0+: the offset at which they are different
			$comments->{$cid}{abbreviated} = $text_a ne $text_b ? 0 : -1;

			if (!$comments->{$cid}{abbreviated}) {
				$text_a = $original_text;
				$text_b = $comment_text->{$cid};

				my $len_b = length($text_b);
				if (substr($text_a, 0, $len_b) eq $text_b) {
					$comments->{$cid}{abbreviated} = $len_b;
				} else {
					($text_a, $text_b) = ($text_b, $text_a) if length($text_a) < length($text_b);

					my $ent_in = my $tag_in = -1;
					for my $i (0 .. length($text_a)) {
						my $c = substr($text_a, $i, 1);
						my $d = substr($text_b, $i, 1);

						if ($c ne $d) {
							$comments->{$cid}{abbreviated} =
								$tag_in >= 0 ? $tag_in :
								$ent_in >= 0 ? $ent_in :
								$i;
							last;
						} else {
							if ($c eq '<') {
								$tag_in = $i;
							} elsif ($tag_in >= 0) {
								$tag_in = -1 if $c eq '>';
							} elsif ($tag_in < 0) {
								if ($c eq '&') {
									$ent_in = $i;
								} elsif ($ent_in) {
									$ent_in = -1 if $c eq ';';
								}
							}
						}
					}

					if ($comments->{$cid}{abbreviated} < length($comment_text->{$cid})) {
						substr($comment_text->{$cid}, $comments->{$cid}{abbreviated}, 0) = '<span class="substr"> </span>';
					}
				}
			}
		}

		if ($mcd) {
			my $exptime = $constants->{memcached_exptime_comtext};
			$exptime = 86400 if !defined($exptime);
			my $append = '';
			my $mcdkey_cid = $mcdkey . $cid;
			if (defined $comments->{$cid}{abbreviated}) {
				$append = $comments->{$cid}{abbreviated} . ':';
				$mcdkey_cid = $mcdkey_abbrev . $cid;
			} elsif (!$possible_chop || ($opt->{cid} && $opt->{cid} eq $cid)) {
				$mcdkey_cid = $mcdkey_full . $cid;
			}
			my $retval = $mcd->set($mcdkey_cid, $append . $comment_text->{$cid}, $exptime);
			if ($mcd && $constants->{memcached_debug} && $constants->{memcached_debug} > 1) {
				my $exp_at = $exptime ? scalar(gmtime(time + $exptime)) : "never";
				print STDERR scalar(gmtime) . " getCommentTextCached memcached writing '$mcdkey_cid' length " . length($comment_text->{$cid}) . " retval=$retval expire: $exp_at\n";
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

	return $comment_text;
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
sub saveCommentReadLog {
	my($self, $comments, $discussion_id, $uid) = @_;

	$uid ||= getCurrentUser('uid');
	return if isAnon($uid);

	my($mcd, $mcdkey);
	if (@$comments) {
		$mcd = $self->getMCD;
		$mcdkey = "$self->{_mcd_keyprefix}:cmr:$uid:$discussion_id";
	}
	else {
		print STDERR "\nFIX ME: saveCommentReadLog called without \$comments being supplied.\n";
		return;
	}

	if ($mcd) {
		$mcd->delete("$mcdkey:now");
		$mcd->delete("$mcdkey:new");
	}

	# cache inserts?
	my @sorted = sort { $b <=> $a } @$comments;
	my $cidnow;
	$cidnow = $self->sqlSelect('cid_now',
		'users_comments_read_log',
		'uid=' . $self->sqlQuote($uid) .
		' AND discussion_id=' . $self->sqlQuote($discussion_id));
	my $oldcidnew = $self->sqlSelect('cid_new',
		'users_comments_read_log',
		'uid=' . $self->sqlQuote($uid) .
		' AND discussion_id=' . $self->sqlQuote($discussion_id));
	my $cidnew = $sorted[0];
	if(!defined($cidnow)) {
		$self->sqlInsert('users_comments_read_log', {
			uid		=> $uid,
			discussion_id	=> $discussion_id,
			cid_now		=> '0',
			cid_new		=> $cidnew,
		});
	}
	else {
		$self->sqlUpdate('users_comments_read_log', {
			cid_now		=> $oldcidnew,
			cid_new		=> $cidnew },
			"uid = $uid AND discussion_id = $discussion_id"
		);
	}

	if ($mcd) {
		$mcd->set("$mcdkey:now", $cidnow);
		$mcd->set("$mcdkey:new", $cidnew);
	}

	return 1;
}

#######################################################
# Clears the read status of one discussion for one user
sub clearCommentReadLog {
	my($self, $discussion_id, $uid, $no_mcd) = @_;

	$uid ||= getCurrentUser('uid');
	return 1 if isAnon($uid);

	my($mcd, $mcdkey);
	if(!$no_mcd) {
		$mcd = $self->getMCD;
		$mcdkey = "$self->{_mcd_keyprefix}:cmr:$uid:$discussion_id";
	}

	if ($mcd) {
		$mcd->delete("$mcdkey:now");
		$mcd->delete("$mcdkey:new");
	}
	
	my $where = "discussion_id = $discussion_id AND uid = $uid";
	if (!$self->sqlDelete("users_comments_read_log", $where)) {
		return 0;
	}
	return 1;
}

#######################################################
sub getCommentReadLog {
	my($self, $discussion_id, $uid, $no_mcd) = @_;
	my $cids = {};
	
	$uid ||= getCurrentUser('uid');

	if (isAnon($uid)) {
		$cids->{cid_now} = 0;
		$cids->{cid_new} = 0;
		return $cids;
	}

	my($mcd, $mcdkey);
	$mcd = $self->getMCD;

	if ($mcd) {
		$mcdkey = "$self->{_mcd_keyprefix}:cmr:$uid:$discussion_id";
		$cids->{cid_now} = $mcd->get("$mcdkey:now");
		$cids->{cid_new} = $mcd->get("$mcdkey:new");
	}
	else {
		$cids = $self->sqlSelectHashref(
			'cid_now, cid_new',
			'users_comments_read_log',
			'uid=' . $self->sqlQuote($uid) .
			' AND discussion_id=' . $self->sqlQuote($discussion_id)
		);
	}
	
	if (!$cids) {
		$cids->{cid_now} = 0;
		$cids->{cid_new} = 0;
	}
	
	return $cids;
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
			@$sub{'story_title', 'story_time', 'displaystatus'} = @$story_ref{'title', 'time', 'displaystatus'} if $story_ref;
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
			@$sub{'story_title', 'story_time', 'displaystatus'} = @$story_ref{'title', 'time', 'displaystatus'} if $story_ref;
		}
	}
	return $subs;
}

########################################################
sub countSubmissionsByUID {
	my($self, $id, $options) = @_;
	
	my $where = "uid=$id";
	$where .= " AND del = 2" if $options->{accepted_only};
	my $count = $self->sqlCount('submissions', $where);
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
	my($self, $id, $limit, $offset) = @_;
	
	my $id_q = $self->sqlQuote($id);
	my $mp_tid = getCurrentStatic('mainpage_nexus_tid');
	my @nexuses = $self->getNexusTids();
	my $nexus_clause = join ',', @nexuses, $mp_tid;

	if ($limit) {
		$limit = 'LIMIT ' . $limit;
		$offset = $offset || 0;
		$offset = 'OFFSET ' . $offset;
	} else {
		$offset = "";
	}
	
	my $answer = $self->sqlSelectAllHashrefArray(
		'sid, title, time',
		'stories, story_text, story_topics_rendered',
		"stories.stoid = story_topics_rendered.stoid
		 AND stories.stoid = story_text.stoid
		 AND submitter=$id_q AND time < NOW()
		 AND story_topics_rendered.tid IN ($nexus_clause)
		 AND in_trash = 'no'",
		"GROUP BY stories.stoid ORDER by time DESC $limit $offset");
	return $answer;
}

########################################################
sub countStoriesBySubmitter {
	my($self, $id) = @_;

	my $id_q = $self->sqlQuote($id);
	my $mp_tid = getCurrentStatic('mainpage_nexus_tid');
	my @nexuses = $self->getNexusTids();
	my $nexus_clause = join ',', @nexuses, $mp_tid;

	my($count) = $self->sqlSelect('count(*)',
		'stories, story_topics_rendered',
		"stories.stoid = story_topics_rendered.stoid
		 AND submitter=$id_q AND time < NOW()
		 AND story_topics_rendered.tid IN ($nexus_clause)
		 AND in_trash = 'no'");

	return $count;
}

########################################################
# Count how many stories are "posted out", i.e. have been
# set up to run in the near future by the editor(s).
sub countStoriesPostedOut {
	my($self, $options) = @_;
	my $constants = getCurrentStatic();

	# start checking for stories 5 minutes from now
	my $window_start = defined($options->{postedout_start_secs})
		? $options->{postedout_start_secs}
		: $constants->{postedout_start_secs} || 300;
	# stories posted more than 6 hours out don't count
	my $window_end = defined($options->{postedout_end_secs})
		? $options->{postedout_end_secs}
		: $constants->{postedout_end_secs} || 6*3600;

	# optionally require that the stories be in a nexus
	my($tables, $nexus_clause) = ('stories', '');
	my $req_nexus = $options->{postedout_thisnexusonly}
		|| $constants->{postedout_thisnexusonly}
		|| 0;
	if ($req_nexus) {
		$tables = 'stories, story_topics_rendered';
		$nexus_clause = " AND stories.stoid=story_topics_rendered.stoid
			AND story_topics_rendered.tid=$req_nexus";
	}

	my $count = $self->sqlCount(
		$tables,
		"time BETWEEN DATE_ADD(NOW(), INTERVAL $window_start SECOND)
		 AND DATE_ADD(NOW(), INTERVAL $window_end   SECOND)
		 AND in_trash='no'
		 $nexus_clause");
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
	my $the_time =			$options->{the_time}		|| time;
	my $fake_secs_ahead =		$options->{fake_secs_ahead}	|| 0;

	my($is_future_column, $where);

	# Tweak $future_secs here somewhat, based on something...?  Nah.

	# First decide whether we're looking into the future or not.  If we
	# are going to try for this sort of thing, then either we must NOT
	# be limiting it to subscribers only, OR the user must be a subscriber
	# and this page must be plummy (able to have plums), OR the user must
	# have a daypass.
	my $future = 0;
	$future = 1 if $try_future
		&& $constants->{subscribe}
		&& $future_secs
		&&	( !$must_be_subscriber
			|| ( $user->{is_subscriber} && $user->{state}{page_plummy} )
			|| $user->{has_daypass} );

	# If we have NOW() in the WHERE clause, the query cache can't hold
	# onto this.  Since story times are rounded to the minute, we can
	# also round our selection time to the minute, so the query cache
	# can work for the full 60 seconds.
	my $now = $exact_now ? 'NOW()'
		: $self->sqlQuote( time2str(
			'%Y-%m-%d %H:%M:00',
			$the_time + $fake_secs_ahead,
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
		$where = "$column_name <= $now";
	}

	return ($is_future_column, $where);
}

########################################################
# This method searches the stories table in reverse chronological
# order, finding stories which match particular criteria (primarily:
# being in the right nexus(es)) and returns "essentials" about them
# (which is almost everything except story_text columns).
#
# This method's input is its $options hashref, which may be
# overwritten before it exits.  All options are optional
# (duh) and reasonable defaults will be used.  Legal keys
# and their values are as follows.
# These arguments are integers:
#	offset		Skip the first n stories
#	limit		Number of stories wanted for their primary
#			use (like the central column of index.pl)
#	limit_extra	Number of stories wanted for their
#			secondary use (like the Older Stories box)
#	fake_secs_ahead	Seconds into the future to pretend it is now
#			(used to precache this query for speed, not
#			useful for returning actual data for a user).
#	future_secs	Seconds into the future that this user is
#			authorized to look.  0 means not authorized,
#			but undef or missing means to use the default
#			for subscribers (ends up being var
#			'subscribe_future_secs').
#	issue		If present, must be in yyyymmdd format;
#			the latest story returned cannot be after the
#			end of that day in the user's timezone (nor
#			earlier than a week before).
# The following six arguments can be either a scalar int or
# an arrayref of zero or more ints:
#	tid		A story must be in at least one of these
#			topics (usually but not necessarily nexuses)
#			to be returned.  Default: mainpage nexus.
#	tid_exclude	A story must NOT be in any of these topics.
#	uid		A story must be posted by one of these users.
#	uid_exclude	A story must NOT be posted by any of these users.
#	stoid		A story must have one of these stoids.
#	stoid_exclude	A story must NOT have one of these stoids.
# These arguments are boolean:
#	sectioncollapse	If true, this method expands the tid argument
#			to include not only the nexus(es) given, but
#			all nexuses (if any) under them.
#	return_min_stoid_only	If true, doesn't return all the story
#				data, just the MIN(stoid) of the data
#				that WOULD have been returned.  Used
#				to set an optimization var, not useful
#				for returning actual data for a user.
#
# The method's output is an arrayref of hashrefs, each one representing
# a story, sorted into reverse chronological order.
#
# memcached plays a subtle role here.  There are many options that are
# passed in, but most commonly this method is called for a single nexus
# and all the other options default (not section-collapsed, not issue,
# nothing excluded, etc).  We cache the final results (all stories
# returned) in that case.  The reason we do not cache with many (any)
# options is that any change to any story necessitates invalidating all
# memcached data that might now or might previously have referenced
# that story.  There is no way to delete all memcached keys that match
# a regex or prefix (and this is by design:  it may never have this
# capability), so by keeping only 1-2 keys for each tid, instead of
# keeping a key for every possible option, we make that deletion
# tractable and even easy.
#
# There are only two elements to a memcached gSE key:  the tid of the
# single topic that all the stories are rendered into, and the unix
# timestamp of the 0th second of the first minute that the story data
# is valid for.  That key is set to expire shortly after the minute is
# over, so any key will really be used only for 60 seconds and then
# ignored until it is purged by memcached's reclamation.  Another way
# to do this would be to only set the data once it is valid, i.e. to
# never set it until its minute has arrived.  But thanks to the
# set_gse_min_stoid task, we are precaching the results of this method
# in both the MySQL query cache and in memcached;  but those results
# must not be accessed until their time has arrived.
#
# So: the memcached key is:
# 	$keyprefix:gse:$tid:$unix_timestamp_minute_start
# and its value is the same data returned by this method:  an arrayref
# of hashrefs, one per story.

sub getStoriesEssentials {
	my($self, $options) = @_;

	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $gSkin = getCurrentSkin();
	if (!$gSkin->{skid}) {
		# XXX Throw a warning here?  Might not be a bad idea.
		$gSkin = $self->getSkin($constants->{mainpage_skid});
	}

	my $mcd = $self->getMCD();
	my $min_stoid = $self->getVar('gse_min_stoid', 'value', 1) || 0;
	my $fallback_min_stoid = 0;
	$fallback_min_stoid = $self->getVar('gse_fallback_min_stoid', 'value', 1) || 0 if $constants->{gse_mp_max_days_back};
	my $mp_tid = $constants->{mainpage_nexus_tid};

	# Canonicalize all arguments passed in.  First the scalars.
	my $offset = $options->{offset} || 0;
	my $limit = $options->{limit} || $gSkin->{artcount_max};
	my $limit_extra = defined($options->{limit_extra})
		? $options->{limit_extra}
		: int(($gSkin->{artcount_min} + $gSkin->{artcount_max})/2);
	my $fake_secs_ahead = $options->{fake_secs_ahead} || 0;
	my $future_secs = defined($options->{future_secs})
		? $options->{future_secs}
		: undef;
	my $issue = $options->{issue} && $options->{issue} =~ /^\d{8}$/
		? $options->{issue}
		: "";
	my $sectioncollapse = $options->{sectioncollapse} || 0;
	my $return_min_stoid_only = $options->{return_min_stoid_only} || 0;
	my $tid_extras = $options->{tid_extras} || 0;

	# Now set some secondary variables.
	my $the_time = $self->getTime({ unix_format => 1 });
	my $the_minute = ($the_time+$fake_secs_ahead) - ($the_time+$fake_secs_ahead) % 60;
	my $lim_sum = $limit + $limit_extra + $offset;
	my $min_stoid_margin = $gSkin->{artcount_max}
		+ int(($gSkin->{artcount_min} + $gSkin->{artcount_max})/2);

	my $limit_overly_large = $lim_sum > $min_stoid_margin * 3 + 10 ? 1 : 0;
#print STDERR "gSE $$ min_stoid A '$min_stoid' lim_sum '$lim_sum' min_stoid_margin '$min_stoid_margin'\n";

	# Now canonicalize the scalar-or-arrayrefs.  This returns an arrayref
	# of the zero or more values that need to be included in the WHERE
	# clause.  Note that the excluded-values are calculated first, and
	# those are passed in to the included-values because exclusion takes
	# priority and will remove items from the latter.

	my $tid_x =   $self->_gse_canonicalize($options->{tid_exclude});
	my $tid =     $self->_gse_canonicalize($options->{tid},		$tid_x, $mp_tid);

	my $uid_x =   $self->_gse_canonicalize($options->{uid_exclude});
	my $uid =     $self->_gse_canonicalize($options->{uid},		$uid_x);
	my $stoid_x = $self->_gse_canonicalize($options->{stoid_exclude});
	my $stoid =   $self->_gse_canonicalize($options->{stoid},	$stoid_x);

	# $tid always contains at least one topic since it defaults to
	# $mp_tid.  But in the weird case where the caller has passed in
	# exactly the same list of topics for both tid and tid_exclude,
	# they cancel out.  In that case, $tid will be empty and no
	# data can possibly be returned.  Handle that pathological case
	# now, so the rest of this method can assume that there is at
	# least one topic in $tid.
	return [ ] if !@$tid;

	# We now have enough information to determine whether memcached may
	# have all the data we're looking for.  Try it!  (Calculate the
	# mcdkey now because, even if we can't read from the cache, we may
	# be able to write into it later.)
	my $mcdkey;
	$mcdkey = "$self->{_mcd_keyprefix}:gse:$tid->[0]:$the_minute" if $mcd;
	my $try_mcd = ($mcd
		&& !$tid_extras
		&& $offset == 0
		&& !defined($options->{limit})
		&& !defined($options->{limit_extra})
		&& $fake_secs_ahead == 0
		&& !defined($future_secs)
		&& !$issue && !$sectioncollapse && !$return_min_stoid_only
		&& !@$tid_x
		&& !@$uid && !@$uid_x
		&& !@$stoid && !@$stoid_x
	);


	if ($try_mcd) {
		my $data = $mcd->get($mcdkey);
#print STDERR "gSE $$ mcdkey '$mcdkey' data element count '" . ($data ? scalar(@$data) : "n/a") . "'\n";
		return $data if $data;
	}

	# Nope, memcached is not going to help us.  Keep going.

	# Now, if sectioncollapse is set, expand the tid to include all of
	# its nexus children.  (Note that $tid may have included duplicate
	# values;  after this function call, it no longer will.)
	$tid = $self->_gse_sectioncollapse($tid, $tid_x) if $sectioncollapse;

	# Figure out whether min_stoid is usable.
	# If we're not looking just at the mainpage tid, it's not (yet --
	# maybe later we'll have multiple min_stoids).
	if ($tid->[0] == $mp_tid) {
		$min_stoid = $min_stoid if !$tid_extras;
	} else {
		$min_stoid = $fallback_min_stoid if !$tid_extras;
	}
	# If we're excluding nexuses, topics, authors, or stories, it's not.
	$min_stoid = $fallback_min_stoid if @$tid_x || @$uid_x || @$stoid_x;
	# If the $limit + $limit_extra + $offset is too large, it's not.
	$min_stoid = 0 if $limit_overly_large;
	# If we're in issue mode, and it's an issue more than 3 days old,
	# then nope.
	$min_stoid = 0 if $issue && issueAge($issue) > 3;
	# And of course, if we're being asked to calculate a new one,
	# ignore the old one.
	$min_stoid = 0 if $return_min_stoid_only;
#print STDERR "gSE $$ min_stoid B '$min_stoid' tid '@$tid' overly '$limit_overly_large' rmso '$return_min_stoid_only'\n";

	if ($tid->[0] != $mp_tid) {
		$min_stoid = 0;
	} 

	# Build the WHERE clauses necessary and do the first select(s),
	# on story_topics_rendered.
	# There will always be at least one tid, since it defaults
	# to the mainpage_nexus_tid.  First, get all the stoids
	# that match that (those) tid(s).
	my @tid_in = ( );
	push @tid_in, "story_topics_rendered.tid IN (" . join(",", @$tid) . ")";
	push @tid_in, "story_topics_rendered.stoid >= '$min_stoid'" if $min_stoid;
	my $tid_in_where = join(" AND ", @tid_in);

	# This is the standard utility function that returns the SQL
	# needed to add both to the columns to select, and to the
	# where clause, to properly limit story selection by time.
	my($column_time, $where_time) = $self->_stories_time_clauses({
		try_future =>		1,
		future_secs =>		$future_secs,
		must_be_subscriber =>	0,
		the_time =>		$the_time,
		fake_secs_ahead =>	$fake_secs_ahead,
	});

	# Determine which columns are needed.
	my $columns = "stories.stoid";
	if (!$return_min_stoid_only) {
		$columns .= ", sid, time, commentcount, hitparade,"
			. " primaryskid, body_length, word_count, "
			. " discussion, $column_time";
	}

	# We'll set this later.
	my $tables;

	# The WHERE clause will be built up from the @stories_where
	# list (ANDed together).  This clause has to limit our results
	# very carefully, by time (possibly in two ways), and by the
	# other criteria that have been given.
	my @stories_where = ( );
	push @stories_where, "in_trash = 'no' AND $where_time";
	if (@$uid) {
		# XXXSECTIONTOPIC This is wrong, this clause should be OR'd
		# with the rest if it is present.
		push @stories_where, "uid IN ("       . join(",", @$uid)     . ")";
	} elsif (@$uid_x) {
		# This is correct, this should be AND'd.
		push @stories_where, "uid NOT IN ("   . join(",", @$uid_x)   . ")";
	}
	if ($issue) {
		my $issue_lookback_days = $constants->{issue_lookback_days} || 7;
		my $issue_oldest =   timeCalc("${issue}000000", "%Y-%m-%d %T",
			- $user->{off_set} - 84600*$issue_lookback_days);
		my $issue_youngest = timeCalc("${issue}235959", "%Y-%m-%d %T",
			- $user->{off_set});
		push @stories_where, "time BETWEEN '$issue_oldest' AND '$issue_youngest'";
	}

	# Always return results in descending order, but if the caller
	# is just looking for the min_stoid, skip straight to that row
	# so we don't return too much.
	my $other = "ORDER BY time DESC";
	if ($return_min_stoid_only) {
		# In this case, we offset to the end of the list
		# and then just select a row count of 1.
		$other .= " LIMIT " . ($limit + $limit_extra + $offset) . ", 1";
	} else {
		$other .= " LIMIT $offset, " . ($limit + $limit_extra);
	}

	# Decide whether we're going to do two SELECTs or one.
	my $separate_selects;

	if (!$min_stoid && $constants->{gse_skip_count_if_no_min_stoid}) {
		$separate_selects = 0;
	} else {

		# Do a COUNT() on how many rows in story_topics_rendered
		# we are potentially looking at.  If that number is smaller
		# than the gse_table_join_row_cutoff var, we do multiple
		# SELECTs to pull out the data we need.  If larger, we let
		# MySQL do the JOIN itself (so we don't pass an absurd amount
		# of data over the wire, basically).

		my $stoid_count = $self->sqlSelect(
			"COUNT(DISTINCT stoid)",
			"story_topics_rendered",
			"$tid_in_where");
		my $cutoff = $constants->{gse_table_join_row_cutoff} || 1000;
		$separate_selects = $stoid_count < $cutoff ? 1 : 0;

	}

	if ($separate_selects) {

		# We're going to do separate SELECTs.  First we do the 1 or 2
		# SELECTs on story_topics_rendered which determine for us the
		# list of stoids we're using.  Then we set some variables and
		# exit this if clause, where the big ol' final SELECT will
		# get the data we need.

#print STDERR "gSE $$ separate SELECTs, min_stoid=$min_stoid\n";

		my $stoids_ar = $self->sqlSelectColArrayref(
			"DISTINCT stoid",
			"story_topics_rendered",
			$tid_in_where);

		# If that returned no stories, we can short-circuit the rest
		# of this method because we know the answer already.
		if (!@$stoids_ar) {
			if ($return_min_stoid_only) {
				return 0;
			} else {
				return [ ];
			}
		}

#print STDERR "gSE $$ stoids_ar returned: '@$stoids_ar' t_i_w '$tid_in_where' tid '@$tid'\n";
		# Now, if necessary, do another select to eliminate any
		# stoids with tids that are unwanted.
		if (@$stoids_ar && @$tid_x) {
			my @tid_left_out = ( );
			push @tid_left_out, "tid IN (" . join(",", @$tid_x) . ")";
			push @tid_left_out, "stoid >= '$min_stoid'" if $min_stoid;
			my $tid_left_out_where = join(" AND ", @tid_left_out);
			my $stoids_x_ar = $self->sqlSelectColArrayref(
				"DISTINCT stoid",
				"story_topics_rendered",
				$tid_left_out_where);
			# Remove the stoids just found from the ones
			# found a moment ago.
			my %stoids_x_hash = ( map { ($_, 1) } @$stoids_x_ar );
			@$stoids_ar = grep { !$stoids_x_hash{$_} } @$stoids_ar;
		}

		# Now we have the list of stoids that point to the rows that we
		# should _consider_ for the stories table.  We haven't narrowed it
		# down all the way yet.  First thing we can do is check $stoid and
		# $stoid_x to possibly narrow the list directly.  After that, for
		# example, if the caller wants only stories posted by a certain
		# uid, the story_topics_rendered table has no way of knowing which
		# those are;  we'll add in those limitations when we do the SQL
		# select on the stories table later.
		if (@$stoid) {
			my %stoid_hash = ( map { ($_, 1) } @$stoid );
			@$stoids_ar = grep {  $stoid_hash{$_}   } @$stoids_ar;
		} elsif (@$stoid_x) {
			my %stoid_x_hash = ( map { ($_, 1) } @$stoid_x );
			@$stoids_ar = grep { !$stoid_x_hash{$_} } @$stoids_ar;
		}

		# Now we sort the list of stoids, to make sure a random reordering
		# does not invalidate the MySQL query cache.
		@$stoids_ar = sort { $a <=> $b } @$stoids_ar;

		# Add our contribution to the WHERE clause here.
		push @stories_where, "stoid IN (" . join(",", @$stoids_ar) . ")";

		# We're only looking at one table, which makes this part easy.
		$tables = "stories";

#print STDERR "gSE $$ stoids_ar, stoid, stoid_x, uid, uid_x: " . Dumper([ $stoids_ar, $stoid, $stoid_x, $uid, $uid_x ]);

	} else {

		# We're going to try to get all the data we need in one
		# big SELECT.  Prep the variables for the upcoming SELECT
		# so it does the right thing.

#print STDERR "gSE $$ one SELECT, min_stoid=$min_stoid\n";

		# Need both tables.
		$tables = "stories";

		if (@$tid_x) {
			# If we are excluding any topics, then add a LEFT JOIN
			# No Left JOIN, do a sub query --paulej72
			my $tid_x_str = join(",", @$tid_x);
			push @stories_where, "stories.stoid NOT IN (SELECT story_topics_rendered.stoid FROM story_topics_rendered WHERE story_topics_rendered.tid IN ($tid_x_str) GROUP BY story_topics_rendered.stoid)";
		}

		# If we'd done multiple SELECTs, this logic would have been
		# done on the story_topics_rendered table;  as it is, these
		# phrases have to go into the JOIN.
		# No JOIN, do a sub query --paulej72

		# The logic can return multiple story_topics_rendered rows
		# with the same stoid, and if it does, group them together
		# so each story only gets returned once.
		#
		# TMB
		# Wouldn't it make sense to put the GROUP BY on the fucking *SUBQUERY* then?
		# At ~25k stories it makes the goddamned difference between being a >15s query and a <0.1s query.
		push @stories_where, "stories.stoid IN (SELECT story_topics_rendered.stoid FROM story_topics_rendered WHERE $tid_in_where GROUP BY story_topics_rendered.stoid)";
	}

	# Pull together the where clauses into one clause.
	my $where = join(" AND ", map { "($_)" } @stories_where);

	# DO THE SELECT!
	my $stories = $self->sqlSelectAllHashrefArray($columns, $tables, $where, $other);

	if ($options->{return_min_stoid_only}) {
		return $stories->[0]{stoid} || 0;
	}

	# If we tried and failed to get this data from memcached, now it
	# can be written.  But it's only valid for the duration of the
	# current minute!
	if ($try_mcd) {
		my $expire_time = ($the_minute + 60) - time;
		if ($expire_time > 0) {
			# We kludge in a few extra seconds so a system
			# that's slow, or overloaded, or whose clocks
			# are not all set identically, has no chance of
			# a massive load spike at the end of each
			# minute.
			$expire_time += 3;
			$mcd->set($mcdkey, $stories, $expire_time);
#print STDERR "gSE $$ mcd->set mcdkey '$mcdkey' story count '" . scalar(@$stories) . "' expire_time '$expire_time'\n";
		}
	}

	return $stories;
}

sub _gse_canonicalize {
	my($self, $optvalue, $exclude_ar, $mp_tid) = @_;
	my $retval = $optvalue;
	if (defined($retval)) {
		$retval = [ $retval ] if !ref($retval);
	} else {
		$retval = [ ];
	}
	if ($mp_tid && (
		   !@$retval
		|| scalar(@$retval) == 1 && !$retval->[0]
	)) {
		# Only use the replacement mp_tid if it was passed in,
		# and if the option value was false, or an arrayref
		# with either zero elements or a single element that's
		# false.
		$retval = [ $mp_tid ];
	}
	if (@$retval && $exclude_ar && @$exclude_ar) {
		my %exclude = map { ($_, 1) } @$exclude_ar;
		$retval = [ grep { !$exclude{$_} } @$retval ];
	}
	# Exclude any undef or 0 values in the arrayref.
	$retval = [ grep { $_ } @$retval ];
#my $od = Dumper($optvalue); $od =~ s/\s+/ /g;
#my $rd = Dumper($retval); $rd =~ s/\s+/ /g;
#print STDERR "gse_can $$ optvalue '$od' mp_tid '$mp_tid' retval '$rd'\n";
	return $retval;
}

sub _gse_sectioncollapse {
	my($self, $opt_ar, $tid_x_ar) = @_;
	my %nexuses = map { ($_, 1) } @$opt_ar;
	for my $tid (keys %nexuses) {
		# XXX Should optimize this by writing a version of
		# getNexusChildrenTids() which takes multiple inputs
		# and chases them all down together.  Not a huge
		# deal since sectioncollapse is probably going away.
		for my $new (@{ $self->getNexusChildrenTids($tid) }) {
			$nexuses{$new} = 1;
		}
	}
	my %tid_x = ( );
	%tid_x = map {( $_, 1 )} @$tid_x_ar if $tid_x_ar;
	my @all = sort { $a <=> $b }
		grep { !$tid_x{$_} }
		keys %nexuses;
	return \@all;
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
	my($self, $story, $comment ) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	my $time = timeCalc(scalar localtime, "%m/%d %H:%M %Z", 0);
	my $subid = $self->createSubmission({
		subj	=> "Merge: " . strip_literal($user->{nickname}) . " ($time)",
		tid	=> $constants->{defaulttopic},
		story	=> $story,
		comment => $comment,
		name	=> strip_literal($user->{nickname}),
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

	if ($form->{filter}) {
		push @where, "subj LIKE '%" . $form->{filter}. "%'";
	}

	my $limit = ($form->{limit} && $form->{limit} =~ /\d+/)
		? "LIMIT $form->{limit}" : '';

	my $submissions = $self->sqlSelectAllHashrefArray(
		'submissions.*, karma',
		'submissions,users_info',
		join(' AND ', @where),
		"ORDER BY time $limit"
	);

	for my $sub (@$submissions) {
		my $append = $self->sqlSelectAllKeyValue(
			'name,value',
			'submission_param',
			"subid=" . $self->sqlQuote($sub->{subid})
		);
		$sub->{orig_time} = $sub->{'time'};
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
	my($self, $type, $good_behavior) = @_;
	my $constants = getCurrentStatic();
	$good_behavior ||= 0;
	my $trollpoint = 0;

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

# XXXSRCID This really should be weighted for time.  Double-check
# with EXPLAIN and real-world data to make sure the indexes on
# those columns are being used.
sub getNetIDKarma {
	my($self, $type, $id) = @_;
	my($count, $karma);
	my $constants = getCurrentStatic();
	#if ($type eq "ipid") {
	#	($count, $karma) = $self->sqlSelect("COUNT(*),sum(karma)", "comments", "ipid='$id' AND date > (NOW() - INTERVAL 1 MONTH)");
	#	return wantarray ? ($karma, $count) : $karma;
	#} elsif ($type eq "subnetid") {
	#	($count, $karma) = $self->sqlSelect("COUNT(*),sum(karma)", "comments", "subnetid='$id'  AND date > (NOW() - INTERVAL 1 MONTH)");
	#	return wantarray ? ($karma, $count) : $karma;
	#} else {
	#	($count, $karma) = $self->sqlSelect("COUNT(*),sum(karma)", "comments", "ipid='$id'  AND date > (NOW() - INTERVAL 1 MONTH)");
	#	return wantarray ? ($karma, $count) : $karma if $count;
		# This was fucking retarded. You've already returned values by here and never executed the next two lines. --TMB
	#	($count, $karma) = $self->sqlSelect("COUNT(*),sum(karma)", "comments", "subnetid='$id'  AND date > (NOW() - INTERVAL 1 MONTH)");
	#	return wantarray ? ($karma, $count) : $karma;
	#}

	my $typeclause = "";
	if($type eq "ipid") {
		$typeclause = "ipid = '$id'";
	}
	elsif($type eq "subnetid") {
		$typeclause = "subnetid = '$id'";
	}
	else {
		if($id) {
			$typeclause = "ipid = '$id'";
		}
		else {return wantarray ? (0, 0) : 0;}
	}

	my ($fulldays, $halfdays, $quarterdays, $stophere) = ($constants->{bad_karma_full_weight}, $constants->{bad_karma_half_weight}, $constants->{bad_karma_quarter_weight}, $constants->{bad_karma_zero_weight});

	my $positive = "select ifnull(sum(karma), 0) from comments where $typeclause and karma > 0 and date >= now() - interval $stophere day";
	my $fullweight = "select ifnull(sum(karma), 0) from comments where $typeclause and karma < 0 and date >= now() - interval $fulldays day and date >= now() - interval $stophere day";
	my $halfweight = "select ifnull(cast(sum(karma) / 2 as signed), 0) from comments where $typeclause and karma < 0 and date >= now() - interval $halfdays day and date < now() - interval $fulldays day and date >= now() - interval $stophere day";
	my $quarterweight = "select ifnull(cast(sum(karma) / 4 as signed), 0) from comments where $typeclause and karma < 0 and date >= now() - interval $quarterdays day and date < now() - interval $halfdays day and date >= now() - interval $stophere day";
	my $karmaclause = "($positive) + ($fullweight) + ($halfweight) + ($quarterweight)";
	my $what = "count(*) as 'count', ($karmaclause) as karma";

	($count, $karma) = $self->sqlSelect(
		"$what",
		"comments",
		"$typeclause"
	);

	return wantarray ? ($karma, $count) : $karma;
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
	$trollpoint = $self->calcTrollPoint("uid", $good_behavior);
	$modval = $self->calcModval("comments.uid = $user->{uid}", $uid_hoursback);
	return 1 if $modval <= $trollpoint;

	# All tests passed, user is not a troll.
	return 0;
}

########################################################
sub createDiscussion {
	my($self, $discussion) = @_;
	return unless $discussion->{title} && $discussion->{url};

	if ($discussion->{kind}) {
		my $kinds = $self->getDescriptions('discussion_kinds');
		my $kind = delete $discussion->{kind};
		my %r_kinds;
		@r_kinds{values %$kinds} = keys %$kinds;
		$discussion->{dkid} = $r_kinds{$kind} if $r_kinds{$kind};
	}

	$discussion->{type} ||= 'open';
	# XXXSKIN this should be pulled from gSkin not constants
	$discussion->{commentstatus} ||= getCurrentStatic('defaultcommentstatus');
	$discussion->{primaryskid} ||= 0;
	$discussion->{topic} ||= 0;
	$discussion->{sid} ||= '';
	$discussion->{stoid} ||= 0;
	$discussion->{ts} ||= $self->getTime();
	$discussion->{uid} = getCurrentUser('uid')
		unless defined $discussion->{uid} && length $discussion->{uid};
	$discussion->{legacy} ||= 'no';
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
	$self->sqlDo("SET AUTOCOMMIT=0");

	my $error = "";

	$story->{submitter} = $story->{submitter} ?  $story->{submitter} : $story->{uid};
	$story->{is_dirty} = 1;

	if (!defined($story->{title})) {
		$error = "createStory needs a defined title";
	} else {
		# Rather than call truncateStringForCharColumn() here,
		# we prefer to throw an error.  Unlike createComment,
		# we would prefer that overlong subjects not be silently
		# chopped off.  Consider the consequences of saving a
		# story with the headline "Chris Nandor is a Freakishly
		# Ugly Twisted Criminal, Claims National Enquirer" and
		# later realizing it had been truncated after 50 chars.
		my $title_len = $self->sqlGetCharColumnLength('story_text', 'title');
		if ($title_len && length($story->{title}) > $title_len) {
			$error = "createStory title too long: " . length($story->{title}) . " > $title_len";
		}
	}

	my $stoid;
	if (!$error) {
		$story->{sid} = createSid();
		my $sid_ok = 0;
		while ($sid_ok == 0) {
			# we rely on logic in setStory() later to properly
			# set up the data for a story, so we can't someday
			# just change this to do an insert of all the story
			# data, we do need to continue pass it through
			# setStory()
			$sid_ok = $self->sqlInsert('stories',
				{ sid => $story->{sid} },
				{ ignore => 1 } ); # don't need error messages
			if ($sid_ok == 0) { # returns 0E0 on collision, which == 0
				# Keep looking...
				$story->{sid} = createSid($story->{sid});
			}
		}
		# If this came from a submission, update submission and grant
		# karma to the user
		$stoid = $self->getLastInsertId({ table => 'stories', prime => 'stoid' });
		$story->{stoid} = $stoid;
		$self->grantStorySubmissionKarma($story);
	}

	if (!$error) {
		if (! $self->sqlInsert('story_text', { stoid => $stoid })) {
			$error = "sqlInsert failed for story_text: " . $self->sqlError();
		}
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
		if ($story->{subid}) {
			if ($self->sqlSelect('id', 'journal_transfer',
				'subid=' . $self->sqlQuote($story->{subid})
			)) {
				my $sub = $self->getSubmission($story->{subid});
				if ($sub) {
					for (qw(discussion journal_id by by_url)) {
						$story->{$_} = $sub->{$_};
					}
				}
			}
		}

		$story->{body_length} = defined($story->{bodytext}) ? length($story->{bodytext}) : 0;
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
		my $comment_codes = $self->getDescriptions('commentcodes_extended');

		my $discussion = {
			kind		=> 'story',
			uid		=> $story->{uid},
			title		=> $story->{title},
			primaryskid	=> $primaryskid,
			topic		=> $tids->[0],
			url		=> $self->getUrlFromSid(
						$story->{sid},
						$story->{primaryskid},
						$tids->[0],
						$story->{title}
					   ),
			stoid		=> $stoid,
			sid		=> $story->{sid},
			commentstatus	=> $comment_codes->{$commentstatus}
					   ? $commentstatus
					   : $constants->{defaultcommentstatus},
			ts		=> $story->{'time'},
		};

		my $id;
		if ($story->{discussion} && $story->{journal_id}) {
			# updating now for journals tips off users that this will
			# be a story soon, esp. ts, url, title, kind ... i don't
			# care personally, does it matter?  if so we can task some
			# of these changes, if we need to make them -- pudge

			# update later in task
			delete @{$discussion}{qw(title url ts)};
			delete $discussion->{uid}; # leave it "owned" by poster

			$id = $story->{discussion};
			$discussion->{kind} = 'journal-story';
			$discussion->{type} = 'open'; # should be already
			$discussion->{archivable} = 'yes'; # for good measure

			if (!$self->setDiscussion($id, $discussion)) {
				$error = "Failed to set discussion data for story\n";

			} elsif ($story->{journal_id}) {
				$self->sqlUpdate('journal_transfer', {
					stoid	=> $stoid,
					updated	=> 0,
				}, 'id=' . $self->sqlQuote($story->{journal_id}));
			}

		} else {
			$id = $self->createDiscussion($discussion);
			if (!$id) {
				$error = "Failed to create discussion for story";
			}
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

sub getUrlFromSid {
	my($self, $sid, $primaryskid, $tid, $title) = @_;
	my $constants = getCurrentStatic();

	my $storyskin = $self->getSkin($primaryskid || $constants->{mainpage_skid});
	my $rootdir = $storyskin->{rootdir};
	
	return "$rootdir/article.pl?sid=$sid" .
			($tid && $constants->{tids_in_urls} ? "&tid=$tid" : '');
}


sub grantStorySubmissionKarma {
	my($self, $story) = @_;
	my $constants = getCurrentStatic();
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

	if (!defined($data->{title})) {
		$error = "createStory needs a defined title";
	} else {
		# See comment in createStory() for why we do this.
		my $title_len = $self->sqlGetCharColumnLength('story_text', 'title');
		if (length($data->{title}) > $title_len) {
			$error = "createStory title too long: " . length($data->{title}) . " > $title_len";
		}
	}

	my $stoid;
	if (!$error) {
		$stoid = $self->getStoidFromSidOrStoid($sid);
		$error = "no stoid for sid '$sid'" unless $stoid;
	}
	my $sid_q = $self->sqlQuote($sid);

#use Data::Dumper; print STDERR "MySQL.pm updateStory before setStory data: " . Dumper($data);
	if (!$error) {
		if (!$self->setStory($stoid, $data)) {
			$error = "Failed to setStory '$sid' '$stoid'\n";
		}
	}

	if (!$error) {
		my $comment_codes = $self->getDescriptions('commentcodes_extended');
		my $topiclist = $self->getTopiclistFromChosen($data->{topics_chosen});
#use Data::Dumper; print STDERR "MySQL.pm updateStory topiclist '@$topiclist' topics_chosen: " . Dumper($data->{topics_chosen});
		my $dis_data = {
			stoid		=> $stoid,
			sid		=> $sid,
			title		=> $data->{title},
			primaryskid	=> $data->{primaryskid},
			url		=> $self->getUrlFromSid(
						$sid,
						$data->{primaryskid},
						$topiclist->[0],
						$data->{title}
					   ),
			ts		=> $data->{'time'},
			topic		=> $topiclist->[0],
			commentstatus	=> $comment_codes->{$data->{commentstatus}}
						? $data->{commentstatus}
						: getCurrentStatic('defaultcommentstatus'),
		};

		my $story = $self->getStory($stoid);
		# will be updated later by journal_fix.pl
		if ($story->{journal_id}) {
			delete @{$dis_data}{qw(title url ts)};
		}

		if (!$error) {
			if (!$self->setDiscussionBySid($sid, $dis_data)) {
				$error = "Failed to set discussion data for story\n";

			# reset so task picks it up again if necessary;
			# simplest way to make sure data is correct
			# and avoid race condition with task
			} elsif ($story->{journal_id}) {
				$self->sqlUpdate('journal_transfer', {
					updated	=> 0,
				}, 'id=' . $self->sqlQuote($story->{journal_id}));
			}
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

	if (my $pollbooth_db = getObject('Slash::PollBooth')) {
		$pollbooth_db->updatePollFromStory($sid, {
			date		=> 1,
			topic		=> 1,
			section		=> 1,
			polltype	=> 1
		});
	}

	return $sid;

}

########################################################

sub hasUserSignedStory {
	my($self, $stoid, $uid) = @_;
	my $stoid_q = $self->sqlQuote($stoid);
	my $uid_q   = $self->sqlQuote($uid);
	return $self->sqlCount("signoff", "stoid=$stoid_q AND uid=$uid_q");
}

sub createSignoff {
	my($self, $stoid, $uid, $signoff_type) = @_;
	my $constants = getCurrentStatic();
	my $send_message = $constants->{signoff_notify};

	$signoff_type ||= '';
	$self->sqlInsert("signoff", { stoid => $stoid, uid => $uid, signoff_type => $signoff_type });
	$self->setStory($stoid, { thumb_signoff_needed => 0 });
}

sub getUserSignoffHashForStoids {
	my($self, $uid, $stoids) = @_;
	return {} if !@$stoids;
	my $stoid_list = join ',', @$stoids;
	$self->sqlSelectAllHashref(
		"stoid",
		"stoid, COUNT(*) AS cnt",
		"signoff",
		"stoid in ($stoid_list) AND uid = $uid",
		"GROUP BY stoid",
	);
}

sub getSignoffCountHashForStoids {
	my($self, $stoids, $adminsonly) = @_;
	return {} if !@$stoids;	
	my $stoid_list = join ',', @$stoids;
	my $user_limit_clause = $adminsonly ? ' AND seclev >= 100' : '';

	my $signoff_hash = $self->sqlSelectAllHashref(
		"stoid", 
		"stoid, COUNT(DISTINCT signoff.uid) AS cnt",
		"signoff, users",
		"users.uid = signoff.uid AND stoid IN ($stoid_list) $user_limit_clause",
		"GROUP BY stoid"
	);
	
	return $signoff_hash;
}

sub getSignoffsForStory {
	my($self, $stoid) = @_;
	return [] if !$stoid;
	my $stoid_q = $self->sqlQuote($stoid);
	return $self->sqlSelectAllHashrefArray(
		"signoff.*, users.nickname, signoff_type",
		"signoff, users",
		"signoff.stoid=$stoid_q AND users.uid=signoff.uid ORDER BY signoff.soid"
	);
}

sub deleteSignoffsForStory {
	my($self, $stoid) = @_;
	my $constants = getCurrentStatic();
	my $stoid_q = $self->sqlQuote($stoid);
	$self->sqlDelete("signoff", "stoid=$stoid_q");
}

sub getSignoffsInLastMinutes {
	my ($self, $mins) = @_;
	$mins ||= getCurrentStatic("admin_timeout");
	return $self->sqlSelectAllHashrefArray(
		"*",
		"signoff",
		"signoff_time >= DATE_SUB(NOW(), INTERVAL $mins MINUTE)"
	);
}

########################################################
sub _getSlashConf_rawvars {
	my($self, $secure) = @_;
	$secure = $secure ? 1 : 0;
	my $vu = $self->{virtual_user};
	return undef unless $vu;
	my $mcd = $self->getMCD({ no_getcurrentstatic => 1 });
	my $mcdkey;
	my $got_from_memcached = 0;
	my $vars_hr;
	if ($mcd) {
		$mcdkey = "$self->{_mcd_keyprefix}:vars$secure";
		if ($vars_hr = $mcd->get($mcdkey)) {
			$got_from_memcached = 1;
		}
	}
	$vars_hr ||= $self->sqlSelectAllKeyValue('name, value', 'vars');
	if ($mcd && !$got_from_memcached) {
		# Cache this for about 3 minutes.   should be a var.
		my $expire_time = 180;
		$mcd->set($mcdkey, $vars_hr, $expire_time);
	}
	return $vars_hr;
}

########################################################
# Now, the idea is to not cache here, since we actually
# cache elsewhere (namely in %Slash::Apache::constants) - Brian
# I'm caching this in memcached now though. - Jamie
sub getSlashConf {
	my($self, $secure) = @_;

	# Get the raw vars data (possibly from a memcached cache).

	my $vars_hr = $self->_getSlashConf_rawvars($secure);
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
	my $tagboxdata = $self->sqlSelectColArrayref('value', 'site_info',
		"name='tagbox'");
	for my $tagbox (@$tagboxdata) {
		$conf{tagbox}{$tagbox} = 1;
	}

	# This really should be a separate piece of data returned by
	# getReasons() the same way getTopicTree() works.  It's only part
	# of $constants for historical, er, reasons.
	if ($conf{m1}) {
		$conf{reasons} = $self->sqlSelectAllHashref("id", "*", "modreasons");
		$conf{reasons_order} = $self->sqlSelectColArrayref("id", "modreasons","","ORDER BY ordered ASC");
	}

	$conf{rootdir}		||= "//$conf{basedomain}";
	$conf{real_rootdir}	||= $conf{rootdir};  # for when rootdir changes
	$conf{real_section}	||= $conf{section};  # for when section changes
	$conf{absolutedir}	||= "http://$conf{basedomain}";
	$conf{imagedir}		||= "$conf{rootdir}/images";
		# If absolutedir_secure is not defined, it defaults to the
		# same as absolutedir.  Same for imagedir_secure.
	$conf{absolutedir_secure} ||= $conf{absolutedir};
	$conf{imagedir_secure}	||= $conf{imagedir};
	$conf{css_extension}      = 'css';
#	if (defined &Slash::Apache::ConnectionIsSSL && Slash::Apache::ConnectionIsSSL())
	if ($secure) {
		# On Secure HTTP connections, force absolutedir/imagedir to
		# be the secure versions.
		$conf{imagedir} = $conf{imagedir_secure};
		$conf{absolutedir} = $conf{absolutedir_secure};
		$conf{css_extension} = 'ssl.css';
	}
	$conf{cssdir}           ||= $conf{css_use_imagedir} ? $conf{imagedir} : $conf{rootdir};
	$conf{rdfimg}		||= "$conf{imagedir}/topics/topicslash.gif";
	$conf{adminmail_mod}	||= $conf{adminmail};
	$conf{adminmail_post}	||= $conf{adminmail};
	$conf{adminmail_ban}	||= $conf{adminmail};
	$conf{basedir}		||= "$conf{datadir}/public_html";
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
	for (qw[rootdir absolutedir imagedir imagedir_secure basedir]) {
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
		anonymous_coward_uids =>	[ $conf{anonymous_coward_uid} ],
						# See <http://www.iana.org/assignments/uri-schemes>
		approved_url_schemes =>		[qw( ftp http gopher mailto news nntp telnet wais https )],
		approvedtags =>			[qw( b i p br a ol ul li dl dt dd em strong tt blockquote div ecode quote)],
		approvedtags_break =>		[qw( p br ol ul li dl dt dd blockquote div img hr spoiler)],
		# all known tags, plus table, pre, and slash; this can be overridden
		# in vars, but since we make this all known tags by default ...
		# easier to just keep it in here
		approvedtags_admin =>		[qw( b i p br a ol ul li dl dt dd em strong tt blockquote div ecode
				img hr big small sub sup span
				dfn code samp kbd var cite address ins del
				h1 h2 h3 h4 h5 h6
				table thead tbody tfoot tr th td pre
				slash strike abbr sarc sarcasm user spoiler
		)],
		charrefs_bad_entity =>		[qw( zwnj zwj lrm rlm )],
		charrefs_bad_numeric =>		[qw( 8204 8205 8206 8207 8236 8237 8238 )],
		charrefs_good_entity =>		[qw( amp lt gt euro pound yen rsquo lsquo rdquo ldquo ndash mdash )],
		charrefs_good_numeric =>	[ ],
		cur_performance_stat_ops =>	[ ],
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
		subnet_karma_post_limit_range => [ ],
		search_ignore_skids =>		[ ],
	);
	my %conf_fixup_hashes = (
		# var name			# default hash of keys/values
		# --------			# --------------------
		ad_messaging_sections =>	{ },
		comments_perday_bykarma =>	{  -1 => 2,		25 => 25,	99999 => 50          },
		karma_adj =>			{ -10 => 'Terrible',	-1 => 'Bad',	    0 => 'Neutral',
						   12 => 'Positive',	25 => 'Good',	99999 => 'Excellent' },
		mod_up_points_needed =>		{ },
						#          m2_f_t m2_u_t  m1_t m1_k
		m2_consequences =>		{ 0.00 => [qw( -5    +2   -100 -1   )],
						  0.15 => [qw( -2    +1    -40 -1   )],
						  0.30 => [qw( -0.5  +0.5  -20  0   )],
						  0.35 => [qw(  0     0    -10  0   )],
						  0.49 => [qw(  0     0     -4  0   )],
						  0.60 => [qw(  0     0     +1  0   )],
						  0.70 => [qw(  0     0     +2  0   )],
						  0.80 => [qw( +0.01 -1     +3  0   )],
						  0.90 => [qw( +0.02 -2     +4  0   )],
						  1.00 => [qw( +0.05 -5     +5 +0.5 )],	},
		m2_consequences_repeats =>	{ 3 => -4, 5 => -12, 10 => -100 },
		# 40=0|30=Mainpage|20=0|10=Sectional|0=0
		topic_popup_weights	=>	{ 40 => 0, 30 => 'Mainpage', 20 => 0, 10 => 'Sectional', 0 => 0 },
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
		lowbandwidth_bids_regex
	)) {
		next if !$conf{$regex} || $conf{$regex} eq 'NONE';
		$conf{$regex} = qr{$conf{$regex}};
	}

	# anchor
	for my $regex (qw(
		feed_types
	)) {
		next if !$conf{$regex};
		$conf{$regex} = qr{^(?:$conf{$regex})$};
	}


	for my $var (qw(approvedtags approvedtags_break lonetags)) {
		$conf{$var} = [ map lc, @{$conf{$var}} ];
	}

	for my $attrname (qw(approvedtags_attr approvedtags_attr_admin)) {
		if ($conf{$attrname}) {
			my $approvedtags_attr = $conf{$attrname};
			$conf{$attrname} = {};
			my @tags = split /\s+/, $approvedtags_attr;
			foreach my $tag (@tags){
				my($tagname, $attr_info) = $tag =~ /([^:]*)(?:\:(.*))?$/;
				my @attrs = split ',', ($attr_info || '');
				my $ord = 1;
				foreach my $attr (@attrs){
					my($at, $extra) = split /_/, $attr;
					$extra ||= '';
					$at = lc $at;
					$tagname = lc $tagname;
					$conf{$attrname}{$tagname}{$at}{ord} = $ord;
					$conf{$attrname}{$tagname}{$at}{req} = 1 if $extra =~ /R/;
					$conf{$attrname}{$tagname}{$at}{req} = 2 if $extra =~ /N/; # "necessary"
					$conf{$attrname}{$tagname}{$at}{url} = 1 if $extra =~ /U/;
					$ord++;
				}
			}
		}
	}
	if ($conf{approvedtags_attr} && $conf{approvedtags_attr_admin}) {
		for (keys %{$conf{approvedtags_attr}}) {
			# only add to _admin if not already in it
			$conf{approvedtags_attr_admin}{$_} ||= $conf{approvedtags_attr}{$_};
		}
	}

	# We only need to do this on startup.  This var isn't really used;
	# see the code comment in getObject().
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
		$constants = $self->sqlSelectAllKeyValue(
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
	require Cache::Memcached::Fast;
	$self->{_mcd} = Cache::Memcached::Fast->new({
		servers =>	[ @servers ],
		utf8 => 1,
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
# Extremely ugly but necessary if we want stats on memcached
sub getMCDold {
	my($self, $options) = @_;

	# If we already created it for this object, or if we tried to
	# create it and failed and assigned it 0, return that.
	return $self->{_mcdold} if defined($self->{_mcdold});

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
		$constants = $self->sqlSelectAllKeyValue(
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
	$self->{_mcdold} = Cache::Memcached->new({
		servers =>	[ @servers ],
	##########
	#	TMB I think we're okay just pulling stats even in a non-debug state
	#	debug =>	$constants->{memcached_debug} > 1 ? 1 : 0,
		debug => 1,
	});
	if (!$self->{_mcdold}) {
		# Can't connect; not using it.
		return $self->{_mcdold} = 0;
	}
	if ($constants->{memcached_keyprefix}) {
		$self->{_mcd_keyprefix} = $constants->{memcached_keyprefix};
	} else {
		# If no keyprefix defined in vars, use the first and
		# last letter from the sitename.
		$constants->{sitename} =~ /([A-Za-z]).*(\w)/;
		$self->{_mcd_keyprefix} = ($2 ? lc("$1$2") : ($1 ? lc($1) : ""));
	}
	return $self->{_mcdold};
}

##################################################################
sub getMCDStats {
	my($self) = @_;
	my $mcd = $self->getMCDold();
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
# Putting the left-hand side of the s///'s into an array, and the
# right-hand side into a data template, would be a slightly-
# prettier compromise.  I'm just saying. - Jamie
sub autoUrl {
	my($self, $section, @data) = @_;
	my $data = @data ? join(' ', map { $_ || '' } @data) : '';
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	$data =~ s/([0-9a-z])\?([0-9a-z])/$1'$2/gi if $form->{fixquotes};

	my $initials = substr $user->{nickname}, 0, 1;
	my $more = substr $user->{nickname}, 1;
	$more =~ s/[a-z]//g;
	$initials = uc($initials . $more);
	my($now) = timeCalc(scalar localtime, '%m/%d %H:%M %Z', 0);

	# Assorted Automatic Autoreplacements for Convenience
	my $nick = strip_literal($user->{nickname});
	$data =~ s|<disclaimer:(.*)>|<b><a href="/about.pl#disclaimer">disclaimer</a>:<a href="$user->{homepage}">$nick</a> owns shares in $1</b>|ig;
	$data =~ s|<update>|<b>Update: <date></b> by <author>|ig;
	$data =~ s|<date>|$now|g;
	$data =~ s|<author>|<b><a href="$user->{homepage}">$initials</a></b>:|ig;

	# Assorted ways to add files:
	$data =~ s|<import>|importText()|ex;
	$data =~ s/<image(.*?)>/importImage($section)/ex;
	$data =~ s/<attach(.*?)>/importFile($section)/ex;
	return $data;
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
# What time does the database think it is?  Various parts of the
# code are synched to that time, which may be different from the
# time that the machine we're running on thinks it is.
#
# We use two closure'd variables here and do a little dance just to
# avoid calling SELECT NOW() more than once every ten minutes.
# This optimization only saves a very cheap call, but it may be a
# very frequent call too, and there's just no need, clocks can't
# possibly drift very much.
#
# Options are:
#	add_secs	Seconds to add to the actual GMT time
#	unix_format	Return a unix epoch integer instead of
#			an SQL format string

{ # closure
my($last_db_time_offset, $last_db_time_confirm) = (undef, undef);
sub getTime {
	my($self, $options) = @_;
	my $my_time = time();
	if (!$last_db_time_confirm
		|| $my_time > $last_db_time_confirm + 600) {
		my $db_unix_time = timeCalc($self->sqlSelect('NOW()'), "%s", 0);
		$last_db_time_offset = $db_unix_time - $my_time;
		$last_db_time_confirm = $my_time;
	}
	my $total_offset = $last_db_time_offset + ($options->{add_secs} || 0);
	if ($options->{unix_format}) {
		return time() + $total_offset;
	} else {
		return timeCalc(0, "%Y-%m-%d %T", $total_offset);
	}
}
} # end closure

##################################################################
sub getTimeAgo {
	my($self, $time) = @_;
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
	my($self, $days_back, $options) = @_;
	$days_back ||= 0;

	my($db_levels, $db_order) = getDayBreakLevels();

	my $level = 'day';
	$level = parseDayBreakLevel($options->{orig_day}) || $level
		if $options->{orig_day};
	my $fmt = $db_levels->{$level}{fmt};

	my $day = $self->getDayFromDay(timeCalc(scalar(localtime), $fmt), $days_back);

	return $day;
}

sub getDayFromDay {
	my($self, $day, $days_back) = @_;
	$day =~ s/-//g;

	my($db_levels, $db_order) = getDayBreakLevels();

	my $return_day;
	if ($day =~ $db_levels->{hour}{re}) {
		$return_day = sprintf $db_levels->{hour}{sfmt}, Add_Delta_DHMS($1, $2, $3, $4, 0, 0, 0, -$days_back, 0, 0);

	} elsif ($day =~ $db_levels->{day}{re}) {
		$return_day = sprintf $db_levels->{day}{sfmt}, Add_Delta_Days($1, $2, $3, -$days_back);

	} elsif ($day =~ $db_levels->{week}{re}) {
		my($y, $m, $d) = Monday_of_Week($2+1, $1);
		my($week, $year) = Week_of_Year(
			Add_Delta_Days($y, $m, $d, -($days_back*7))
		);
		$week--; # Date::Format starts at 0, Date::Calc at 1
		$return_day = sprintf $db_levels->{week}{sfmt}, $year, $week;

	} elsif ($day =~ $db_levels->{month}{re}) {
		$return_day = sprintf $db_levels->{month}{sfmt}, Add_Delta_YM($1, $2, 1, 0, -$days_back);

	} elsif ($day =~ $db_levels->{year}{re}) {
		$return_day = sprintf $db_levels->{year}{sfmt}, Add_Delta_YM($1, 1, 1, -$days_back, 0);
	} else {
		errorLog("No format found for $day");
	}

	return $return_day;
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
		time, stories.in_trash, primaryskid, notes
		";
	my $tables = 'story_text, stories';
	my @where = ( 'stories.stoid = story_text.stoid' );
	my $other = "";
	# If this is a "sectional" (one skin only) admin.pl storylist,
	# then restrict ourselves to only stories matching its nexus.
	if (!$is_mainpage) {
		$tables .= " INNER JOIN story_topics_rendered AS str ON str.stoid = stories.stoid";
		push @where,
			"(str.tid = $gSkin->{nexus} OR stories.primaryskid = $gSkin->{skid})";
		$other = "GROUP BY stoid ";
	}

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

	$other .= "ORDER BY time DESC LIMIT $first_story, $num_stories";

	my $where = join ' AND ', @where;

	# Fetch the count, and fetch the data.

	my $count = $self->sqlSelect("COUNT(DISTINCT stories.stoid)", $tables, $where);
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
	my($self, $stoids);
	return {};
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
	for my $field (qw( last_completed next_begin )) {
		$answer->{"${field}_secs"} = timeCalc($answer->{$field}, "%s", 0);
	}
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
	for my $task (keys %$answer) {
		for my $field (qw( last_completed next_begin )) {
			$answer->{$task}{"${field}_secs"} = timeCalc($answer->{$task}{$field}, "%s", 0);
		}
	}
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
	my $primaryskid;
	$min = $options->{min} if defined $options->{min};
	$max = $options->{max} if defined $options->{max};
	my $sid = $options->{sid} if defined $options->{sid};
	$primaryskid = $options->{primaryskid};
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
	if ($primaryskid) {
		$where_extra = " AND comment.sid IN (SELECT discussions.id from discussions WHERE discussions.primaryskid = ".$self->sqlQuote($primaryskid).") ";
	}

	my $ar = $self->sqlSelectAllHashrefArray(
		"comments.sid AS sid, comments.cid AS cid,
		 date, comments.ipid AS ipid,
		 comments.subnetid AS subnetid, subject,
		 comments.uid AS uid, points AS score,
		 lastmod, comments.reason AS reason,
		 (SELECT nickname FROM users WHERE comments.uid=users.uid) AS nickname,
		 (SELECT primaryskid FROM discussions WHERE comments.sid=discussions.id) as primaryskid,
		 (SELECT comment FROM comment_text WHERE comments.cid=comment_text.cid) AS comment,
		 SUM(val) AS sum_val,
		 IF(moderatorlog.cid IS NULL, 0, COUNT(*))
		 	AS num_mods",
		"comments LEFT JOIN moderatorlog
		 	ON comments.cid=moderatorlog.cid
			AND moderatorlog.active=1",
		"comments.points BETWEEN $min AND $max
		 $where_extra",
		"GROUP BY comments.cid
		 ORDER BY comments.cid DESC
		 $limit_clause"
	);

	return $ar;
}

sub getSpamMods {
	my($self, $options) = @_;

	my $startat = $options->{startat} || 0;
	my $num = $options->{num} || 100; # should be a var
	

	my $ar = $self->sqlSelectAllHashrefArray(
		"comments.sid AS sid, comments.cid AS cid,
		 date, comments.ipid AS ipid,
		 comments.subnetid AS subnetid, subject,
		 comments.uid AS uid, points AS score,
		 lastmod, comments.reason AS reason,
		 (SELECT nickname FROM users WHERE comments.uid=users.uid) AS nickname,
		 (SELECT primaryskid FROM discussions WHERE comments.sid=discussions.id) as primaryskid,
		 (SELECT comment FROM comment_text WHERE comments.cid=comment_text.cid) AS comment,
		 SUM(val) AS sum_val,
		 IF(moderatorlog.cid IS NULL, 0, COUNT(*))
		 	AS num_mods",
		"comments LEFT JOIN moderatorlog
		 	ON comments.cid=moderatorlog.cid
			AND moderatorlog.active=1",
		"moderatorlog.reason = 11
		 AND moderatorlog.active = 1",
		"GROUP BY comments.cid
		 ORDER BY comments.cid DESC
		 LIMIT $startat, $num"
	);
	
}

sub getDiscussionParent {
	# $did is the discussion id
	my ($self, $did) = @_;
	my $parent = {};
	my $slashdb = getCurrentDB();
	if( my $stoid = $self->getStoidByDiscussionId($did) ) {
		my $story = $self->getStory($stoid);
		$story->{atstorytime} = " on ".timeCalc($story->{time});
		$parent->{type} = 'story';
		$parent->{content} = $story->{bodytext} ? $story->{introtext}.$story->{bodytext} : $story->{introtext};
		$parent->{content} = apply_rehash_tags($parent->{content});
		$parent->{story} = $story;
		$parent->{author} = $slashdb->getAuthor(
			$story->{uid},
			[qw( nickname fakeemail homepage )]
		);
	}
	elsif( my $jid = $self->getJidByDiscussionId($did) ) {
		$parent->{type} = 'journal';
		my $journal_reader = getObject('Slash::Journal', { db_type => 'reader' });
		my $article = $journal_reader->get($jid);
		$parent->{content} = $journal_reader->fixJournalText($article->{article}, $article->{posttype}, $article->{uid});
		$parent->{content} = apply_rehash_tags($parent->{content});
		$parent->{author} = $slashdb->getUser(
			$article->{uid},
			[qw( nickname fakeemail homepage )]
		);
	}
	elsif(undef){
		$parent->{type} = 'poll';
	}
	else{return undef};
	$parent->{content} = parseSlashizedLinks($parent->{content});
	return $parent;
}

sub getStoidByDiscussionId {
	my ($self, $did) = @_;
	return undef if !$did;
	return undef unless $did =~ /^\d+$/;
	if(my $stoid = $self->{_did_conversion_cache}{$did."s"}) {
		return $stoid;
	}
	my($mcd, $mcdkey);
	if($mcd = $self->getMCD) {
		$mcdkey = "$self->{_mcd_keyprefix}:dids:";
		my $answer = $mcd->get("$mcdkey$did");
		if (defined $answer) {
			$answer = undef if $answer eq '0';
			$self->{_did_conversion_cache}{$did."s"} = $answer;
			return $answer;
		}
	}
	my $did_q = $self->sqlQuote($did);
	my $stoid = $self->sqlSelect("stoid", "stories", "discussion=$did_q");
	$self->{_did_conversion_cache}{$did."s"} = $stoid;
	my $exptime = 86400;
	$mcd->set("$mcdkey$did", $stoid || 0, $exptime) if $mcd;
	return $stoid;	
}



sub getJidByDiscussionId {
	my ($self, $did) = @_;
	return undef if !$did;
	return undef unless $did =~ /^\d+$/;
	if(my $jid = $self->{_did_conversion_cache}{$did."j"}) {
		return $jid;
	}
	my($mcd, $mcdkey);
	if($mcd = $self->getMCD) {
		$mcdkey = "$self->{_mcd_keyprefix}:didj:";
		my $answer = $mcd->get("$mcdkey$did");
		if (defined $answer) {
			$answer = undef if $answer eq '0';
			$self->{_did_conversion_cache}{$did."j"} = $answer;
			return $answer;
		}
	}
	my $did_q = $self->sqlQuote($did);
	my $jid = $self->sqlSelect("id", "journals", "discussion=$did_q");
	$self->{_did_conversion_cache}{$did."j"} = $jid;
	my $exptime = 86400;
	$mcd->set("$mcdkey$did", $jid || 0, $exptime) if $mcd;
	return $jid;	
}

########################################################

# This method is used to grandfather in old-style sid's,
# automatically converting them to stoids.
sub getStoidFromSidOrStoid {
	my($self, $id) = @_;
	return undef unless $id;
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
	return undef if !$sid;
	return undef if $sid !~ regexSid(1);
	if (my $stoid = $self->{_sid_conversion_cache}{$sid}) {
		return $stoid;
	}
	my($mcd, $mcdkey);
	if ($mcd = $self->getMCD()) {
		$mcdkey = "$self->{_mcd_keyprefix}:sid:";
		my $answer = $mcd->get("$mcdkey$sid");
		if (defined $answer) {
			$answer = undef if $answer eq '0';
			$self->{_sid_conversion_cache}{$sid} = $answer;
			return $answer;
		}
	}
	my $sid_q = $self->sqlQuote($sid);
	my $stoid = $self->sqlSelect("stoid", "stories", "sid=$sid_q");
	$self->{_sid_conversion_cache}{$sid} = $stoid;
	my $exptime = 86400;
	$mcd->set("$mcdkey$sid", $stoid || 0, $exptime) if $mcd;
	return $stoid;
}

########################################################

# This doesn't check time on the story cache, it just stores data.
#
sub _write_stories_cache {
	my($self, $story) = @_;
	return if !$story || ref($story) ne 'HASH' || !$story->{stoid}
		|| $story->{is_future};
	my $stoid = $story->{stoid};
	my $sid = $story->{sid};
	$self->{_stories_cache}{"stoid$stoid"} = $story;
	$self->{_sid_conversion_cache}{$sid} = $stoid;
}

# This method is basically a bulk getStory() call, minus the "val"
# parameter.  I'd like to call it getStories() since it is just the
# multi-key version of getStory(), but that method name is already
# taken.  Oh well.
sub getStoriesData {
	my($self, $stoids, $force_cache_freshen) = @_;
	my $constants = getCurrentStatic();
	# If our story cache is too old, expire it.
	_genericCacheRefresh($self, 'stories', $constants->{story_expire});
	my $stories_cache = $self->{_stories_cache};
	my $table_cache = '_stories_cache';
	my $table_cache_time = '_stories_cache_time';

	# Sort the list of needed stoids, partly for neatness, partly
	# to make sure we can't trash the data the arrayref points to,
	# but mostly to be friendly to MySQL's query cache later.
	$stoids = [ sort { $a <=> $b } @$stoids ];

	# Declare some variables we may set and use later.
	my $mcd;
	my $mcdkey;

	# Here's the value we'll be building up and returning.
	my $retval = { };

	# First let's figure out whether we need anything from outside
	# the local cache -- if it's all in local cache, we're basically
	# done, this method will just be copying some hashrefs from one
	# place to another.  So first, whatever we have in local cache
	# (assuming using it isn't forbidden by the caller), copy into
	# our return value, then count up how many we need and how many
	# we have.
	my $n_stoids_needed = scalar(@$stoids);
	if (!$force_cache_freshen) {
		for my $stoid (@$stoids) {
			$retval->{$stoid} = $stories_cache->{"stoid$stoid"}
				if $stories_cache->{"stoid$stoid"};
		}
	}
	my $n_in_local_cache = scalar(keys %$retval);

	if ($n_in_local_cache < $n_stoids_needed
		&& !$force_cache_freshen
		and $mcd = $self->getMCD() ) {

		# The local cache is missing at least one story's data,
		# and we are allowed to use memcached, and we have a
		# valid handle to memcached.  So, try to get the missing
		# stories from memcached.

		$mcdkey = "$self->{_mcd_keyprefix}:st:";
		my @keys_needed =
			map { "$mcdkey$_" }
			grep { !exists $stories_cache->{"stoid$_"} }
			@$stoids;
		my $answer = $mcd->get_multi(@keys_needed);
		# Convert the keys of the memcached data back into the
		# raw stoids.
		my @answer_stoids =
			sort { $a <=> $b }
			map { /^\Q$mcdkey\E(\d+)$/; $1 }
			grep { /^\Q$mcdkey\E\d+$/ }
			keys %$answer;
		for my $stoid (
			grep { !exists $retval->{$_} }
			@answer_stoids
		) {
			$retval->{$stoid} = $answer->{"$mcdkey$stoid"};
		}
		$n_in_local_cache = scalar(keys %$retval);
	}

	my @stoids_memcached_could_use = ( );

	if ($n_in_local_cache < $n_stoids_needed) {
		# The local cache is still missing at least one story's
		# data.  At this point we have to turn to the DB.

		my($append, $answer, $stoid_clause);
		my @stoids_needed =
			sort
			grep { !exists $retval->{$_} }
			@$stoids;
		if (!@stoids_needed) {
			print STDERR scalar(localtime) . " $$ logic error (possibly mispointed nexus?) no stoids_needed, stoids '@$stoids'\n";
			return { };
		}
		$stoid_clause = "stoid IN ("
			. join(",", @stoids_needed)
			. ")";
		my($column_clause) = $self->_stories_time_clauses({
			try_future => 1, must_be_subscriber => 0
		});
		$answer = $self->sqlSelectAllHashref(
			"stoid",
			"*, $column_clause",
			"stories",
			$stoid_clause);
		$append = $self->sqlSelectAllHashref(
			"stoid",
			"*",
			"story_text",
			$stoid_clause);

		for my $append_stoid (keys %$append) {
			for my $column (keys %{$append->{$append_stoid}}) {
				$answer->{$append_stoid}{$column} =
					$append->{$append_stoid}{$column};
			}
		}
		$append = $self->sqlSelectAllHashref(
			[qw( stoid name )],
			'stoid, name, value',
			'story_param',
			$stoid_clause);
		for my $append_stoid (keys %$append) {
			for my $name (keys %{$append->{$append_stoid}}) {
				my $value = $append->{$append_stoid}{$name}{value};
				$answer->{$append_stoid}{$name} = $value;
			}
		}

		$append = $self->getStoriesTopicsRenderedHash(\@stoids_needed);
		for my $append_stoid (keys %$append) {
			$answer->{$append_stoid}{story_topics_rendered} = $append->{$append_stoid};
		}
		# Put the data where we'll be returning it.
		for my $stoid (@stoids_needed) {
			$retval->{$stoid} = $answer->{$stoid};
		}

		# The stories not in the future should be written
		# into both the local cache and memcached.
		for my $stoid (@stoids_needed) {
			my $story = $retval->{$stoid};
			next if !$story || ref($story) ne 'HASH' || !$story->{stoid}
				|| $story->{is_future};
			# If this is the first data we're writing into the
			# cache, mark the time -- this data, and any other
			# stories we write into the cache for the next
			# n seconds, will be expired at that time.
			$self->{$table_cache_time} ||= time();
			# Cache the data.
			$self->_write_stories_cache($story);
			# We got this data from the DB, so it's
			# authoritative enough to write into memcached,
			# if memcached is available.
			$mcd->set("$mcdkey$stoid", $story, $constants->{memcached_exptime_story} || 600)
				if $mcd;
		}
	}

	# All the data is in both $retval and the local cache now, except
	# stories in the future which were not written into the local
	# cache.  So return it.

	return $retval;
}

# Once getStoriesData() is tested and working, this method should
# reduce to a very simple wrapper:
# return $self->getStoriesData([ $self->getStoidFromSidOrStoid($id) ],
#	$val, $force_cache_freshen)
sub getStory {
	my($self, $id, $val, $force_cache_freshen) = @_;
	my $constants = getCurrentStatic();

	# If our story cache is too old, expire it.
	_genericCacheRefresh($self, 'stories', $constants->{story_expire});
	my $table_cache = '_stories_cache';
	my $table_cache_time = '_stories_cache_time';

	# Accept either a stoid or a sid.
	my $stoid = $self->getStoidFromSidOrStoid($id);
	return undef unless $stoid;

	# Go grab the data if we don't have it, or if the caller
	# demands that we grab it anyway.
	my $is_in_local_cache = exists $self->{$table_cache}{"stoid$stoid"};
	my $use_local_cache = $is_in_local_cache && !$force_cache_freshen;
	my $mcd;
	my $got_it_from_db = 0;
	my $got_it_from_memcached = 0;
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
				if (ref($answer) eq 'HASH' && $answer->{stoid}) {
					# Cache the result.
					$self->_write_stories_cache($answer);
					$is_in_local_cache = 1;
					$got_it_from_memcached = 1;
				}
#print STDERR "getStory $$ A2 id=$id mcd=$mcd try=$try_memcached got_it_from_mcd=$got_it_from_memcached answer: " . Dumper($answer);
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

		$append = $self->getStoriesTopicsRenderedHash([$stoid]);
		$answer->{story_topics_rendered} = $append->{$stoid};
		
		# If this is the first data we're writing into the cache,
		# mark the time -- this data, and any other stories we
		# write into the cache for the next n seconds, will be
		# expired at that time.
		$self->{$table_cache_time} = time() if !$self->{$table_cache_time};
		# Cache the data.
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
		# Caller asked for multiple return values, or maybe the
		# whole thing.  It really doesn't matter what specifically
		# they asked for, we always return the same thing:
		# a hashref with all the values.
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
		$mcd->set("$mcdkey$stoid", $hr, $constants->{memcached_exptime_story} || 600);
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
sub getUncommonStoryWords {
	my($self) = @_;
	return $self->sqlSelectColArrayref("word", "uncommonstorywords") || [ ];
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
	my $recent_uncommon_words = $self->getUncommonStoryWords();
	my %common_words = map { $_ => 1 } split " ", ($self->getVar("common_story_words", "value", 1) || "");
	$recent_uncommon_words = [ grep { !$common_words{$_} } @$recent_uncommon_words ];

	# If we don't (yet) know the list of uncommon words, return now.
	return [ ] unless @$recent_uncommon_words;
	# Find the intersection of this story and recent stories.
	my @text_uncommon_words =
		sort {
			$text_words->{$b}{weight} <=> $text_words->{$a}{weight}
			||
			$a cmp $b
		}
		grep { $text_words->{$_}{count} }
		grep { length($_) > 3 }
		@$recent_uncommon_words;
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
			$word_weight += 2.0*$m * (() = $s->{title} =~     m{$wr}g) if $s->{title};
			$word_weight += 1.0*$m * (() = $s->{introtext} =~ m{$wr}g) if $s->{introtext};
			$word_weight += 0.5*$m * (() = $s->{bodytext} =~  m{$wr}g) if $s->{bodytext};
			$word_weight *= 1.5 if $text_words->{$word}{is_url};
			$word_weight *= 2.5 if $text_words->{$word}{is_url_with_path};
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
		'users.uid,nickname,fakeemail,homepage,bio,seclev',
		'users,users_info',
		'seclev >= 100 AND users.uid = users_info.uid'
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
	# MC: So ... I don't even get how this works
	# theorically, getCurrentSkin('name') would
	# retrieve the skin from the Apache VHOST
	# configuration, but we don't use that functionalit
	
	#unless ($skin) {
	#	$skin ||= getCurrentSkin('name');
	#	$skin ||= 'default';
	#}

	# Instead, we get the skin based on the user, then failing that,
	# get the theme as based in the skin table ...
	unless ($skin) {
		$skin = getCurrentUser('skin');
		$skin ||= getCurrentSkin()->{theme};
		$skin ||= $constants->{'default_skin'};
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
		my @caller_info = ( );
		if (!$options->{ignore_errors}) {
			# Not finding a template is reasonably serious.  Let's make the
			# error log entry pretty descriptive.
			for (my $lvl = 1; $lvl < 99; ++$lvl) {
				my @c = caller($lvl);
				last unless @c;
				next if $c[0] =~ /^Template/;
				push @caller_info, "$c[0] line $c[2]";
				last if scalar(@caller_info) >= 3;
			}
		}

		my $name_str  = sprintf(
			'%s;%s[misc];%s[default]', $name, $page, $skin
		);

		my $error_str = sprintf(
			q{Failed template lookup (%%s) on '%s', keys: %%s, callers: %s},
			$name_str, join(", ", @caller_info)
		);

		if (0) { # try refresh, off by default
			if (!$options->{ignore_errors}) {
				errorLog(sprintf($error_str,
					'refreshing cache',
					scalar keys %{$self->{$table_cache_id}}
				));
			}


			$self->{$table_cache_id} = getTemplateNameCache($self);
			$id    = $self->{$table_cache_id}{$name}{$page }{  $skin  };
			$id  ||= $self->{$table_cache_id}{$name}{$page }{'default'};
			$id  ||= $self->{$table_cache_id}{$name}{'misc'}{  $skin  };
			$id  ||= $self->{$table_cache_id}{$name}{'misc'}{'default'};
		}

		if (!$id && !$options->{ignore_errors}) {
			errorLog(sprintf($error_str,
				'returning false',
				scalar keys %{$self->{$table_cache_id}}
			));
		}

		return if !$id;
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
# Additionally, any chosen topic that has parent links with a
# min_weight of -1 forces the rendered weight of those parent
# topics to 0, exactly as if every parent of that chosen topic
# was also chosen with a weight of 0.
#
# XXXSECTIONTOPICS this could be optimized:  roughly speaking,
# it's O(n**2) right now and it should be O(n).  But in
# reality the difference is a few microseconds every time
# an admin clicks Save.
sub renderTopics {
	my($self, $chosen_hr) = @_;
	return { } if !$chosen_hr || ! keys %$chosen_hr;
	my $tree = $self->getTopicTree();

	# We start with a copy of the chosen hashref, which we
	# modify in Pass One.
	my %ch = %$chosen_hr;
	# In Pass One, any topics chosen with a weight > 0, which
	# have a connection to one or more parent topics via a
	# min_weight of -1, have those parent topics added or
	# replaced in the copy of the chosen hashref with weights
	# of 0.  This is not recursive.
	my %tids_to_zero = ( );
	for my $tid (keys %ch) {
		next if $ch{$tid} == 0 || !$tree->{$tid}{parent};
		my $p_hr = $tree->{$tid}{parent};
		my @parents_via_negativeone =
			grep { $p_hr->{$_} == -1 }
			keys %$p_hr;
		for my $pid (@parents_via_negativeone) {
			# This chosen topic has a connection to this
			# parent topic with min_weight of exactly -1.
			# So this parent topic gets zeroed.
			$tids_to_zero{$pid} = 1;
		}
	}
	for my $pid (keys %tids_to_zero) {
		$ch{$pid} = 0;
	}

	# In Pass Two, we start by making a copy of the (possibly
	# altered with added 0's) chosen hashref.  Then we propagate
	# all values up to parents.
	my %rendered = %ch;
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
				next if exists $ch{$pid};
				# If we already had this node at
				# this weight or higher, skip.
				next if ($rendered{$pid} || 0) >= ($rendered{$tid} || 0);
				# If the connection from the child
				# to parent topic demands a min weight
				# higher than this weight, skip.
				next if $rendered{$tid} < $p_hr->{$pid} || $p_hr->{$pid} < 0;
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
# Collect all the changes that need to be made for a number of
# stories (possibly thousands) into one big hashref.
sub buildStoryRenderHashref {
	my($self, $stoids) = @_;
	return { } if !$stoids || !@$stoids;

	my %return_hash = ( );
	my $stoids_in_clause = join(",", @$stoids);

	# Pull in all the chosen hash data at once.
	my $chosen_ar = $self->sqlSelectAll(
		"stoid, tid, weight",
		"story_topics_chosen",
		"stoid IN ($stoids_in_clause)");
	my %chosen = ( );
	for my $triple_ar (@$chosen_ar) {
		my($stoid, $tid, $weight) = @$triple_ar;
		$chosen{$stoid}{$tid} = $weight;
	}

	# Convert each chosen hash data to rendered data and the
	# auxilliary data that goes along with it.
	for my $stoid (@$stoids) {
		$return_hash{$stoid}{rendered} = $self->renderTopics($chosen{$stoid});
		$return_hash{$stoid}{primaryskid} = $self->getPrimarySkidFromRendered($return_hash{$stoid}{rendered});
		$return_hash{$stoid}{tids} = $self->getTopiclistFromChosen($chosen{$stoid});
	}

#use Data::Dumper; $Data::Dumper::Sortkeys = 1;
#print STDERR scalar(localtime) . " $$ buildStoryRenderHashref s_i_c '$stoids_in_clause' chosen: " . Dumper(\%chosen);
#print STDERR "return_hash: " . Dumper(\%return_hash);

	return \%return_hash;
}

########################################################
# Apply all the topic rendering changes for a bunch of stories
# all at the same time.
sub applyStoryRenderHashref {
	my($self, $render_hr) = @_;
	return if !$render_hr || !%$render_hr;
	my @stoids = sort { $a <=> $b } keys %$render_hr;
	my $all_in_clause = join(",", @stoids);

	# Do the changes for the stories table.  We try to do this in
	# as few UPDATEs as possible, grouping together the stories
	# that share both a primaryskid and tid.
	my %primaryskid_tid = ( );
	for my $stoid (@stoids) {
		my $primaryskid = $render_hr->{$stoid}{primaryskid} || 0;
		my $tid = $render_hr->{$stoid}{tids}[0] || 0;
		$primaryskid_tid{$primaryskid}{$tid} ||= [ ];
		push @{ $primaryskid_tid{$primaryskid}{$tid} }, $stoid;
	}
	# Change the stories.{primaryskid,tid} columns, in bulk where
	# possible.
	for my $primaryskid (sort { $a <=> $b } keys %primaryskid_tid) {
		for my $tid (sort { $a <=> $b } keys %{$primaryskid_tid{$primaryskid}}) {
			my $stoid_ar = $primaryskid_tid{$primaryskid}{$tid};
			my $in_clause = join(",", @$stoid_ar);
			$self->sqlUpdate(
				"stories",
				{ primaryskid => $primaryskid, tid => $tid },
				"stoid IN ($in_clause)");
		}
	}
	# Delete and reinsert the story_topics_rendered data, and mark the
	# stories all as dirty.
	$self->sqlDo("SET AUTOCOMMIT=0");
	$self->sqlDelete("story_topics_rendered", "stoid IN ($all_in_clause)");
	for my $stoid (@stoids) {
		my $str_hr = $render_hr->{$stoid}{rendered};
		for my $tid (sort { $a <=> $b } keys %$str_hr) {
			$self->sqlInsert('story_topics_rendered',
				{ stoid => $stoid, tid => $tid },
				{ delayed => 1, ignore => 1 });
		}
		$self->sqlInsert('story_dirty', { stoid => $stoid },
			{ delayed => 1, ignore => 1 });
	}
	$self->sqlDo("COMMIT");
	$self->sqlDo("SET AUTOCOMMIT=1");

	# Mark all the stories invalid in memcached.
	$self->setStory_delete_memcached_by_stoid([ @stoids ]);
}

########################################################
# Get chosen topics for a story in hashref form
sub getStoryTopicsChosen {
	my($self, $stoid) = @_;
	my $mcd = $self->getMCD();
	my $mcdkey;
	my $answer;
	if ($mcd) {
		$mcdkey = "$self->{_mcd_keyprefix}:stc:";
		$answer = $mcd->get("$mcdkey$stoid");
		return $answer if $answer;
	}
	$answer = $self->sqlSelectAllKeyValue(
		"tid, weight",
		"story_topics_chosen",
		"stoid='$stoid'");
	if ($mcd) {
		my $exptime = getCurrentStatic('memcached_exptime_story') || 600;
		$mcd->set("$mcdkey$stoid", $answer, $exptime);
	}
	return $answer;
}

########################################################
# Get rendered topics for a story in hashref form
sub getStoryTopicsRendered {
	my($self, $stoid) = @_;
	my $mcd = $self->getMCD();
	my $mcdkey;
	my $answer;
	if ($mcd) {
		$mcdkey = "$self->{_mcd_keyprefix}:str:";
		$answer = $mcd->get("$mcdkey$stoid");
		return $answer if $answer;
	}
	$answer = $self->sqlSelectColArrayref(
		"tid",
		"story_topics_rendered",
		"stoid='$stoid'");
	if ($mcd) {
		my $exptime = getCurrentStatic('memcached_exptime_story') || 600;
		$mcd->set("$mcdkey$stoid", $answer, $exptime);
	}
	return $answer;
}

########################################################
sub getStoriesTopicsRenderedHash {
	my($self, $stoids) = @_;
	my $stoid_list = join ',', @$stoids;

	my $rows = $self->sqlSelectAll("stoid,tid", "story_topics_rendered", "stoid in($stoid_list)");

	my $story_topics = {};

	foreach my $row(@$rows) {
		$story_topics->{$row->[0]}{$row->[1]} = 1;
	}

	return $story_topics;
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
	my $constants = getCurrentStatic();

	$self->setStory_delete_memcached_by_stoid([ $stoid ]);
	$chosen_hr ||= $self->getStoryTopicsChosen($stoid);
	my $rendered_hr = $self->renderTopics($chosen_hr);
	my $primaryskid = $self->getPrimarySkidFromRendered($rendered_hr);
	my $tids = $self->getTopiclistForStory($stoid,
		{ topics_chosen => $chosen_hr });

	$self->sqlDelete("story_topics_rendered", "stoid = $stoid");
	if (!$info->{neverdisplay}) {
		for my $key (sort keys %$rendered_hr) {
			unless ($self->sqlInsert("story_topics_rendered",
				{ stoid => $stoid, tid => $key }
			)) {
				# and we should ROLLBACK here
				return undef;
			}
		}
	}
	$self->setStory_delete_memcached_by_stoid([ $stoid ]);

	my $rendered_tids = [ keys %$rendered_hr ];
	$self->setStory_delete_memcached_by_tid($rendered_tids);

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

	# Determine which of the chosen topics are eligible.  Those with
	# weight 0 are to be excluded.
	my @eligible_tids = grep { $chosen_hr->{$_} > 0 } keys %$chosen_hr;

	# Determine which of the chosen topics is in the preferred skin
	# (using the weights given).  These will get priority.
	my $skid = $options->{skid} || 0;
	my %in_skid = ( );
	if ($skid) {
		my $nexus = $self->getNexusFromSkid($skid);
		%in_skid = map { $_, 1 }
			grep { $self->isTopicParent($nexus, $_,
				{ weight => $chosen_hr->{$_} }) }
			@eligible_tids
	}

	# Sort the eligible tids into the desired order.
	my @tids = sort {
			# Highest priority is whether this topic is
			# NOT a nexus (nexus topics go at the end).
		   (exists $tree->{$a}{nexus} ? 1 : 0) <=> (exists $tree->{$b}{nexus} ? 1 : 0)
			# Next highest priority is whether this topic
			# has an icon.  Topics with icons come first.
		|| ($tree->{$b}{image} ? 1 : 0) <=> ($tree->{$a}{image} ? 1 : 0)
			# Next highest priority is whether this topic
			# (at this weight) is in the preferred skid.
		|| ($in_skid{$b} || 0) <=> ($in_skid{$a} || 0)
			# Next priority is the topic's weight
		|| $chosen_hr->{$b} <=> $chosen_hr->{$a}
			# Next priority is alphabetical sort
		|| $tree->{$a}{textname} cmp $tree->{$b}{textname}
			# Last priority is primary key sort
		|| $a <=> $b
	} @eligible_tids;

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
	return [] unless $stoid;

	my $chosen_hr = $options->{topics_chosen} || $self->getStoryTopicsChosen($stoid);
	return $self->getTopiclistFromChosen($chosen_hr, $options);
}

########################################################
# returns the tid of the *first instance* of a keyword,
# as keyword is not unique, so be careful
sub getTidByKeyword {
	my($self, $name) = @_;

	return $self->sqlSelect(
		'tid', 'topics',
		'keyword = '. $self->sqlQuote($name),
		'ORDER BY tid'
	) || 0;
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
# this is used only for the topic editor in admin.pl;
# for everything else, use getTopicParam()
sub getTopicParamsForTid {
	my($self, $tid) = @_;
	my $tid_q = $self->sqlQuote($tid);
	return $self->sqlSelectAllHashrefArray("*", "topic_param", "tid = $tid_q");
}

# getStoryTopics returns a hashref whose keys are the tids
# chosen for a story.  The values depend on $add_names:
#
# $add_names of 1 means to return the alt text, which is the
# human-readable name of a topic.  This is currently used
# only in article.pl to add these words and phrases to META
# information on the webpage.
#
# $add_names of 2 means to return the name, which is a
# (not-guaranteed-unique) short single keyword.  This is
# currently used only in adminmail.pl to append something
# descriptive to the numeric tid for the topichits_123_foo
# stats.
#
# Any other $add_names value means to return '1' for values.

sub getStoryTopics {
	my($self, $id, $add_names) = @_;

	my $stoid = $self->getStoidFromSidOrStoid($id);
	return undef unless $stoid;

	my $topics = $self->sqlSelectColArrayref(
		'tid',
		'story_topics_chosen',
		"stoid=$stoid"
	);

	my $field = '';
	if ($add_names == 1) {		$field = 'textname'	}
	elsif ($add_names == 2) {	$field = 'keyword'	}

	my $tree = $self->getTopicTree();
	my $answer = { };
	for my $tid (@$topics) {
		$answer->{$tid} = $field ? $tree->{$tid}{$field} : 1;
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

	$self->setStory_delete_memcached_by_stoid([ $stoid ]);
	$self->sqlDelete("story_topics_chosen", "stoid = $stoid");
	for my $key (sort { $a <=> $b } keys %{$topic_ref}) {
		unless ($self->sqlInsert("story_topics_chosen",
			{ stoid => $stoid, tid => $key, weight => $topic_ref->{$key} }
		)) {
			# and we should ROLLBACK here
			return 0;
		}
	}
	$self->setStory_delete_memcached_by_stoid([ $stoid ]);

	return 1;
}

########################################################

# returns undef on error, else the number of stories that were
# marked dirty as a result of the change.

sub breakTopicParent {
	my($self, $child_tid, $parent_tid) = @_;

	my $min_weight = $self->sqlSelect('min_weight', 'topic_parents',
		"tid=$child_tid AND parent_tid=$parent_tid");

	if ($min_weight == -1) {
		# This child->parent link exists only to _prevent_ stories
		# with the child from existing in the parent, unless
		# explicitly asked otherwise;  thus, nothing need be done
		# for old stories on breaking the link.
		$self->sqlDelete('topic_parents', "tid=$child_tid AND parent_tid=$parent_tid");
		$self->setVar("topic_tree_lastchange", time);
		return 0;
	}

	if (!$min_weight) {
		# Apparently we were asked to break a link which does
		# not exist.
		warn "breakTopicParent called for $child_tid -> $parent_tid which has no min_weight";
		return undef;
	}

	# stc = child topic chosen for a story, with
	#   weight >= min_weight for this link
	# str = parent topic rendered for that story
	# stc2 = parent topic _not_ chosen for that story
	# If that is the case, this child->parent link may be the sole reason that
	# the parent topic is rendered, and so we set it manually.

	my $stoid_weight = $self->sqlSelectAllKeyValue('str.stoid, stc.weight',
		'story_topics_chosen AS stc,
		 story_topics_rendered AS str LEFT JOIN story_topics_chosen AS stc2
			ON (str.stoid=stc2.stoid AND str.tid=stc2.tid)',
		"stc.stoid=str.stoid
		 AND stc.weight >= $min_weight
		 AND stc.tid=$child_tid
		 AND str.tid=$parent_tid
		 AND stc2.tid IS NULL");

	my @stoids = sort { $a <=> $b } keys %$stoid_weight;
	if (@stoids) {
		$self->sqlDo('SET AUTOCOMMIT=0');
		for my $stoid (@stoids) {
			$self->sqlInsert('story_topics_chosen', {
				stoid => $stoid,
				tid => $parent_tid,
				weight => $stoid_weight->{$stoid},
			}, { ignore => 1, delayed => 1 });
		}
		$self->sqlDo('COMMIT');
		$self->sqlDo('SET AUTOCOMMIT=1');
		$self->markStoriesRenderDirty(\@stoids);
	}
	$self->sqlDelete('topic_parents', "tid=$child_tid AND parent_tid=$parent_tid");

	$self->setVar("topic_tree_lastchange", time);

	return scalar @stoids;
}

sub addTopicParent {
	my($self, $child_tid, $parent_tid, $min_weight) = @_;
	return $self->sqlInsert('topic_parents', {
		tid => $child_tid,
		parent_tid => $parent_tid,
		min_weight => $min_weight,
	});
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
sub getUrl {
	my $answer = _genericGet({
		table		=> 'urls',
		table_prime 	=> 'url_id',
		arguments	=> \@_
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
		if ($ENV{MOD_PERL}) {
			errorLog("cannot getSkin for empty skid='$skid'");
		}
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

	my $colors    = $self->sqlSelectAllHashref([qw( skid name )], "*", "skin_colors", "", "GROUP BY skid, name");
	my $skins_ref = $self->sqlSelectAllHashref(    "skid",        "*", "skins",       "", "ORDER BY skid");
	if (my $regex = $constants->{debughash_getSkins}) {
		$skins_ref = debugHash($regex, $skins_ref);
	}

	for my $skid (keys %$skins_ref) {
		# Set rootdir etc., based on hostname/url, or mainpage's if none
		my $host_skid  = $skins_ref->{$skid}{hostname} ? $skid : $constants->{mainpage_skid};
		my $url_skid   = $skins_ref->{$skid}{url}      ? $skid : $constants->{mainpage_skid};
		my $color_skid = $colors->{$skid}              ? $skid : $constants->{mainpage_skid};

		# Blank index_handler defaults to index.pl.
		$skins_ref->{$skid}{index_handler} ||= 'index.pl';

		# Adjust min and max and warn if wacky value.
		$skins_ref->{$skid}{artcount_max} = $skins_ref->{$skid}{artcount_min}
			if $skins_ref->{$skid}{artcount_max} < $skins_ref->{$skid}{artcount_min};
		warn "skin $skid has artcount_max of 0" if !$skins_ref->{$skid}{artcount_max};

		# Convert an index_handler of foo.pl to an index_static of
		# foo.shtml, for convenience.
		($skins_ref->{$skid}{index_static} = $skins_ref->{$skid}{index_handler}) =~ s/\.pl$/.shtml/;

		# Massage the skin_colors data into this hashref in an
		# appropriate place.
		for my $name (keys %{$colors->{$color_skid}}) {
			$skins_ref->{$skid}{skincolors}{$name} = $colors->{$color_skid}{$name}{skincolor};
		}

		$skins_ref->{$skid}{basedomain} = $skins_ref->{$host_skid}{hostname};

		$skins_ref->{$skid}{absolutedir} = $skins_ref->{$url_skid}{url}
			|| "http://$skins_ref->{$skid}{basedomain}";
		$skins_ref->{$skid}{absolutedir} =~ s{/+$}{};

		my $rootdir_uri = URI->new($skins_ref->{$skid}{absolutedir});

		$rootdir_uri->scheme('');
		$skins_ref->{$skid}{rootdir} = $rootdir_uri->as_iri;
		$skins_ref->{$skid}{rootdir} =~ s{/+$}{};
#if (!$skins_ref->{$skid}{rootdir}) { print STDERR scalar(localtime) . " MySQL.pm No rootdir for skid $skid hostname $skins_ref->{$skid}{hostname}\n" }

		# XXXSKIN - untested; can we reuse $rootdir_uri ?
		if ($constants->{use_https_for_absolutedir_secure}) {
			$rootdir_uri->scheme('https');
			$skins_ref->{$skid}{absolutedir_secure} = $rootdir_uri->as_iri;
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
	return 0 if !$name;
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

	# special cases for password, people, and slashboxes
	if (exists $hashref->{passwd}) {
		# get rid of newpasswd if defined in DB
		$hashref->{newpasswd} = '';
		$hashref->{newpasswd_ts} = undef,
		$hashref->{passwd} = encryptPassword($hashref->{passwd}, $uid);
	}
	if ($hashref->{people}) {
		$hashref->{people} = nfreeze($hashref->{people});
		$hashref->{"-people"} = "0x" . unpack("H*", delete($hashref->{people}));
	}
	if (exists $hashref->{slashboxes}) {
		my @slashboxes = grep /^[\w-]+$/, split /,/, $hashref->{slashboxes};
		$hashref->{slashboxes} = join ",", @slashboxes;
	}

	$cache = _genericGetCacheName($self, $tables);

	for (keys %$hashref) {
		(my $clean_val = $_) =~ s/^-//;
		my $key = $self->{$cache}{$clean_val};
		if ($key) {
			push @{$update_tables{$key}}, $_;
		} else {
			push @param, [ $_, $hashref->{$_} ];
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

	# We should probably START TRANSACTION here.

	# If one or more tagboxes require logging of changes to some user
	# keys, note which keys require changes and retrieve their current
	# values.
	my %old_values = ( );
	my %new_values = ( );
	if ($constants->{plugin}{Tags}) {
		my @update_keys = sort map { s/^-//; $_ } keys %$hashref;
		my $tagboxdb = getObject('Slash::Tagbox');
		my @log_keys = $tagboxdb->userKeysNeedTagLog(\@update_keys);
		%old_values = ( map { ($_, undef) } @log_keys );
	}

	my $rows = 0;
	for my $table (keys %update_tables) {
		my $where = "uid=$uid";
		my %minihash = ( );
		for my $key (@{$update_tables{$table}}) {
			if (exists $hashref->{$key}) {
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
		# If a tagbox needs copies of before-and-after data, first
		# get a copy of the old data.
		my @columns_needed = sort grep { exists $old_values{$_} } map { s/^-//; $_ } keys %minihash;
		if (@columns_needed) {
			my $old_hr = $self->sqlSelectHashref(
				join(',', @columns_needed), $table, $where);
			for my $k (keys %$old_hr) {
				$old_values{$k} = $old_hr->{$k};
			}
		}
		# Do the update.
		my $this_rows = $self->sqlUpdate($table, \%minihash, $where)
			if keys %minihash;
		# After the update, get the new values if the update was
		# successful.
		if (@columns_needed) {
			if ($this_rows) {
				my $new_hr = $self->sqlSelectHashref(
					join(',', @columns_needed), $table, $where);
				for my $k (keys %$new_hr) {
					$new_values{$k} = $new_hr->{$k};
				}
			} else {
				for my $k (@columns_needed) {
					delete $old_values{$k};
				}
			}
		}
		$rows += $this_rows;
	}
	# What is worse, a select+update or a replace?
	# I should look into that. (REPLACE is faster) -Brian
	for my $param_ar (@param) {
		my($name, $value) = @$param_ar;
		# XXX $name can start with '-' here and if so any update should
		# reflect that.  This is why our DB has users_param entries for
		# name="-deletedsubmissions".
		my $name_q = $self->sqlQuote($name);
		if (!defined($value) || $value eq "") {
			if (exists $old_values{$name}) {
				$old_values{$name} = $self->sqlSelect('value', 'users_param',
					"uid = $uid AND name = $name_q");
			}
			my $this_rows = $self->sqlDelete('users_param',
				"uid = $uid AND name = $name_q");
			if (exists $old_values{$name}) {
				if ($this_rows) {
					$new_values{$name} = undef;
				} else {
					delete $old_values{$name};
				}
			}
			$rows += $this_rows;
		} elsif ($name eq "acl") {
			my(@delete, @add);
			my $acls = $value;
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
					$string .= qq| ($uid, $qacl),|;
				}
				chop($string); # remove trailing comma
				my $qlid = $self->_querylog_start('INSERT', 'users_acl');
				$self->sqlDo("INSERT IGNORE INTO users_acl (uid, acl) VALUES $string");
				$self->_querylog_finish($qlid);
				$mcd_need_delete = 1;
			}
		} else {
# XXX No idea what caused this but we should look into it.  Personally
# I lean toward MySQL bug that I bet is fixed in later versions;
# off the top of my head I can't come up with a way that our handling
# of the users_param table could _actually_ deadlock.
# [Mon Nov 28 22:29:23 2005] [error] /journal.pl:Slash::DB::MySQL:/usr/local/lib/perl5/site_perl/5.8.6/i686-linux/Slash/DB/MySQL.pm:12600:virtuser='slashdot' -- hostinfo='[ip redacted] via TCP/IP' -- Deadlock found when trying to get lock; Try restarting transaction -- REPLACE INTO users_param (uid,value,name) VALUES(\n  '[uid redacted]',\n  '1133216962',\n  'lastlooktime')
# [Mon Nov 28 22:29:23 2005] [error] Which was called by:Slash::DB::MySQL:/usr/local/lib/perl5/site_perl/5.8.6/i686-linux/Slash/DB/MySQL.pm:11410
			if (exists $old_values{$name}) {
				$old_values{$name} = $self->sqlSelect('value', 'users_param',
					"uid = $uid AND name = $name_q");
			}
			my $this_rows = 0;
			$this_rows = $self->sqlReplace('users_param', {
				uid	=> $uid,
				name	=> $name,
				value	=> $value,
			}) if defined $value;
			if (exists $old_values{$name}) {
				if ($this_rows) {
					$new_values{$name} = $value;
				} else {
					delete $old_values{$name};
				}
			}
			$rows += $this_rows;
		}
	}

	if ($rows && keys(%old_values)) {
		my $tagboxdb = getObject('Slash::Tagbox');
		for my $name (keys %old_values) {
			$tagboxdb->logUserChange($uid, $name, $old_values{$name}, $new_values{$name})
				if $old_values{$name} ne $new_values{$name};
		}
	}

	# And then COMMIT here.

	# And delete from memcached again after we update the DB
	$mcd_need_delete = 1 if $rows;
	$self->setUser_delete_memcached($uid) if $mcd_need_delete;

	return $rows;
}

sub setVar_delete_memcached {
	my($self) = @_;
	my $mcd = $self->getMCD();
	return unless $mcd;
	my $mcdkey = "$self->{_mcd_keyprefix}:vars";
	$mcd->delete($mcdkey);
	my $constants = getCurrentStatic();
	my $mcddebug = $constants->{memcached_debug};
	if ($mcddebug > 1) {
		print STDERR scalar(gmtime) . " $$ setV_deletemcd deleted\n";
	}
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
		$mcd->delete("$mcdkey$uid");
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
# XXX That assumption may no longer be valid.  We need to
# XXX consider whether this needs to change.
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
# Get the complete list of all ACLs used on this site,
# but without returning any data about which user(s) have
# them.
# XXX This _really_ should be cached for on the order of 5 minutes.
sub getAllACLNames {
	my($self) = @_;
	my $acls = $self->sqlSelectColArrayref('acl', 'users_acl', '',
		'GROUP BY acl ORDER BY acl');
	$acls ||= [ ];
	return $acls;
}

########################################################
# We want getUser to look like a generic, despite the fact that
# it is decidedly not :)
# New as of 9/2003: if memcached is active, we no longer do piecemeal
# DB loads of anything less than the full user data.  We grab the
# users_hits table from the DB and everything else from memcached.
sub getUser {
	my($self, $uid, $val) = @_;
	return undef unless $uid;
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
			# And adjust the users_hits.lastclick value, a timestamp,
			# to work the same in 4.1 and later as it did in 4.0.
			# This is vital to make a Slash::Apache::Log::UserLog
			# test work properly.  See also updateLastaccess.
			$answer->{lastclick} =~ s/\D+//g if $answer->{lastclick};
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
					$uid,
					$table_hr->{select_clause},
					$table_hr->{from_clause},
					$table_hr->{where_clause},
					$gtd->{all} ? "all" : $table_hr->{params_needed});
				return undef if !$answer;
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
			$uid,
			($val ? $gtd->{select_clause} : "*"),
			$gtd->{from_clause},
			$gtd->{where_clause},
			$gtd->{all} ? "all" : $gtd->{params_needed});
		return undef if !$answer;

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

	# Fill in the uid field (possibly done in _getUser_do_selects already).
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
			# Just to prevent "uninitialized" warnings on debug print
			$val ||= '';
			$gtd->{all} ||= '';
			$gtd->{can_use_mcd} ||= '';
			print STDERR scalar(gmtime) . " $$ mcd getUser '$mcdkey$uid' elapsed=$elapsed cache MISS can '$gtd->{can_use_mcd}' val '$val' gtd-all='$gtd->{all}' gtd-cum='$gtd->{can_use_mcd}' rawmcdanswer: " . Dumper($rawmcdanswer);
		}
	}

	return $answer;
}

#
# _getUser_do_selects
#

sub _getUser_do_selects {
	my($self, $uid, $select, $from, $where, $params) = @_;
	my $uid_q = $self->sqlQuote($uid);
	my $mcd = $self->getMCD();
	my $constants = getCurrentStatic();
	my $mcddebug = $mcd && $constants->{memcached_debug};

	# Here's the big select, the one that does something like:
	# SELECT foo, bar, baz FROM users, users_blurb, users_snork
	# WHERE users.uid=123 AND users_blurb.uid=123 AND so on.
	# Note if we're being asked to get only params, we skip this.
	my $answer = { uid => $uid };
	if ($mcddebug > 1) {
		print STDERR scalar(gmtime) . " $$ mcd gU_ds selecthashref: '$select' '$from' '$where'\n";
	}
	if ($select && $from && $where) {
		$answer = $self->sqlSelectHashref($select, $from, $where);
		# If this user's data is missing from one or more of the
		# core tables, don't go looking for it elsewhere;  the
		# user doesn't exist.
		return undef if !$answer;
	}
	if ($mcddebug > 1) {
		print STDERR scalar(gmtime) . " $$ mcd gU_ds got answer '$select' '$from' '$where'\n";
	}

	# Now get the params and the ACLs.  In the special case
	# where we are being asked to get "all" params (not an
	# arrayref of specific params), we also get the ACLs
	# and clouts too.
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
		
		if ($constants->{plugin}{Tags}) {
			# Get the clouts from users_clout.  Rows can be missing from
			# this table and often are, in which case they are filled in
			# with data from the clout classes' getUserClout methods.
			my $clout_types = $self->getCloutTypes();
			my $clout_info = $self->getCloutInfo();
			my $clout_hr = $self->sqlSelectAllKeyValue(
				'clid, clout',
				'users_clout',
				"uid = $uid_q");
			for my $clid (grep /^\d+$/, keys %$clout_types) {
				my $this_clout;
				if (defined($clout_hr->{$clid})) {
					$this_clout = $clout_hr->{$clid};
				} else {
					my $this_info = $clout_info->{$clid};
					my $clout_obj = getObject($this_info->{class}, { db_type => 'reader' }); warn "no obj for '$this_info->{class}'" unless $clout_obj;
					$this_clout = $clout_obj->getUserClout($answer) if $clout_obj;
				}
					$answer->{clout}{ $clout_types->{$clid} } = $this_clout
					if defined($this_clout);
			}
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

	if ($mcddebug > 1) {
		print STDERR scalar(gmtime) . " $$ mcd gU_ds answer ex-keys done\n";
	}

	# We have a bit of cleanup to do before returning:
	# thaw the people element.
	if ($answer->{people}) {
		$answer->{people} = thaw($answer->{people});
		if ($mcddebug > 1) {
			print STDERR scalar(gmtime) . " $$ mcd gU_ds answer people thawed\n";
		}
	}
	# And adjust the users_hits.lastclick value, a timestamp,
	# to work the same in 4.1 and later as it did in 4.0.
	# This is vital to make a Slash::Apache::Log::UserLog
	# test work properly.  See also updateLastaccess.
	$answer->{lastclick} =~ s/\D+//g if $answer->{lastclick};

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
			if ($mcddebug > 1) {
				print STDERR scalar(gmtime) . " $$ mcd _getU_gtd need_db='$need_db' can_use_mcd='$can_use_mcd' tables_needed='@$tables_needed' gtdcachekey='$gtdcachekey'\n";
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
			$self->sqlReplace($param_table, {
				$table_prime => $id,
				name         => $_->[0],
				value        => $_->[1]
			});
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

if (!defined $id) {
	my @caller_info = ( );
	for (my $lvl = 1; $lvl < 99; ++$lvl) {
		my @c = caller($lvl);
		last unless @c;
		next if $c[0] =~ /^Template/;
		push @caller_info, "$c[1] $c[0] line $c[2] $c[3]";
		last if scalar(@caller_info) >= 5;
	}
	print STDERR "_genericGetCache called with table=$table, table_prime=$table_prime, and undef id: @caller_info\n";
	return undef;
}

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
					my $val = $self->sqlSelectAll(
						"$table_prime, name, value",
						$param_table,
						"name='$_'"
					);
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
			$val .= ",$table_prime" if ! grep { $_ eq $table_prime } @$get_values;
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
				# "values" is a misleading name here since it
				# must be exactly one value (column name).
				my $values_q = $self->sqlQuote($values);
				my $val = $self->sqlSelectAll(
					"$table_prime, name, value",
					$param_table,
					"name=$values_q"
				);
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
		while (my $row = $sth->fetchrow_hashref) { if (!defined($row->{$table_prime})) { my @caller_info = ( ); for (my $lvl = 1; $lvl < 99; ++$lvl) { my @c = caller($lvl); last unless @c; next if $c[0] =~ /^Template/; push @caller_info, "$c[0] line $c[2]"; last if scalar(@caller_info) >= 8; } use Data::Dumper; my $t = gmtime() . " _genericGets table_prime='$table_prime' table='$table' param_table='$param_table' values: " . Dumper($values) . " row: " . Dumper($row) . " caller_info='@caller_info'"; $t =~ s/\s+/ /g; print STDERR "$t\n"; }
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
sub sqlGetColumnData {
	my($self, $table, $col) = @_;
	return unless $table;

	$self->sqlConnect() or return undef;
	my $hr = $self->{_dbh}->selectall_hashref("SHOW COLUMNS FROM $table", 'Field');
	if ($col) {
		# Return only one column's data.
		return exists($hr->{$col}) ? $hr->{$col} : undef;
	}
	# Return all columns' data in a big hashref.
	return $hr;
}

########################################################
{ # closure
my $_textcollen_hr = { };
sub sqlGetCharColumnLength {
	my($self, $table, $col) = @_;
	return undef unless $table && $col;
	return $_textcollen_hr->{$table}{$col} if exists $_textcollen_hr->{$table}{$col};
	$self->sqlConnect() or return undef;
	my $hr = $self->sqlGetColumnData($table, $col);
	return $_textcollen_hr->{$table}{$col} = undef if !$hr;
	my $type = $hr->{Type};
	return $_textcollen_hr->{$table}{$col} = undef unless $type && $type =~ /^(?:var)?char\((\d+)\)$/i;
	return $_textcollen_hr->{$table}{$col} = $1;
}
} # end closure

########################################################
# There are a few places in our schema where site admins may prefer
# to customize data lengths by changing them in the SQL, e.g. they
# may want submissions.subject or comments.subject to allow for
# more or fewer than 50 characters.  Rather than hard-code those
# sizes, or force admins to adjust vars when they adjust the schema,
# Slash reads the lengths of those columns' CHAR/VARCHAR types
# directly from the database.  Note that MySQL 5.0 in one of the
# STRICT modes throws an error on oversized data, so we prefer to
# explicitly truncate strings rather than just trying to insert and
# hoping it works.
# <http://dev.mysql.com/doc/refman/5.0/en/server-sql-mode.html>
sub truncateStringForCharColumn {
	my($self, $str, $table, $col) = @_;
	return $str unless $table && $col;
	return $str if !defined($str) || $str eq '';
	my $maxlen = $self->sqlGetCharColumnLength($table, $col);
	return $str if !$maxlen;
	return substr($str, 0, $maxlen);
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
sub getMainpageDisplayableNexuses {
	my($self) = @_;
	my $constants = getCurrentStatic();
	my $nexus_list = $constants->{mainpage_displayable_nexuses} || '';
	return [ split /\s*,\s*/, $nexus_list ] if $nexus_list;
	return $self->getStorypickableNexusChildren(0, 1);
}

########################################################
sub getStorypickableNexusChildren {
	my($self, $tid, $include_tid) = @_;
	my $constants = getCurrentStatic();
	$tid ||= $constants->{mainpage_nexus_tid};
	my $topic_tree = $self->getTopicTree();
	my $nexus_tids_ar = $self->getNexusChildrenTids($constants->{mainpage_nexus_tid});
	push @$nexus_tids_ar, $tid if $include_tid;
	@$nexus_tids_ar = sort grep {$topic_tree->{$_}{storypickable}} @$nexus_tids_ar;
	return $nexus_tids_ar;
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
# Get a global object ID (globjid), creating it if necessary.
# Takes two arguments, the name of the main table of the object
# (e.g. 'stories' or 'comments'), and the ID of the object in
# that table (e.g. a stoid or a cid).

sub getGlobjidCreate {
	my($self, $name, $target_id, $options) = @_;
	my $db;
	if ($options && $options->{reader_ok}) {
		$db = getObject('Slash::DB', { db_type => 'reader' });
	} else {
		$db = getCurrentDB();
	}
	my $globjid = $db->getGlobjidFromTargetIfExists($name, $target_id);
	return $globjid if $globjid;
	return $self->createGlobjid($name, $target_id);
}

sub getGlobjidFromTargetIfExists {
	my($self, $name, $target_id) = @_;
	return 0 if !$name || !$target_id;
	my $globjtypes = $self->getGlobjTypes();
	my $gtid = $globjtypes->{$name};
	return 0 if !$gtid;

	my $constants = getCurrentStatic();
	my $table_cache		= "_globjs_cache";
	my $table_cache_time	= "_globjs_cache_time";
	_genericCacheRefresh($self, 'globjs', $constants->{block_expire});
	if ($self->{$table_cache_time} && $self->{$table_cache}{$gtid}{$target_id}) {
		return $self->{$table_cache}{$gtid}{$target_id};
	}

	my $mcd = $self->getMCD();
	my $mcdkey = "$self->{_mcd_keyprefix}:globjid:" if $mcd;
	if ($mcd) {
		my $globjid = $mcd->get("$mcdkey$gtid:$target_id");
		if ($globjid) {
			if ($self->{$table_cache_time}) {
				$self->{$table_cache}{$gtid}{$target_id} = $globjid;
			}
			return $globjid;
		}
	}
	my $target_id_q = $self->sqlQuote($target_id);
	my $globjid = $self->sqlSelect('globjid', 'globjs',
		"gtid='$gtid' AND target_id=$target_id_q");
	return 0 if !$globjid;
	$self->{$table_cache}{$gtid}{$target_id} = $globjid;
	$self->{$table_cache_time} ||= time;
	$mcd->set("$mcdkey$gtid:$target_id", $globjid, $constants->{memcached_exptime_tags}) if $mcd;
	return $globjid;
}

sub createGlobjid {
	my($self, $name, $target_id) = @_;
	my $globjtypes = $self->getGlobjTypes();
	my $gtid = $globjtypes->{$name};
	return 0 if !$gtid;
	my $rows = $self->sqlInsert('globjs', {
			globjid =>	undef,
			gtid =>		$gtid,
			target_id =>	$target_id
		}, { ignore => 1 });
	if (!$rows) {
		# Insert failed, presumably because this tag already
		# exists.  The caller should have checked for this
		# before attempting to create the tag, but maybe the
		# reader that was checked didn't have this tag
		# replicated yet.  Pull the information directly
		# from this writer DB.
		return $self->getGlobjidFromTargetIfExists($name, $target_id);
	}
	# The insert succeeded.  Return the ID that was just added.
	return $self->getLastInsertId();
}

# Returns a hashref in which the keys are either numeric gtid's OR
# the names of maintables, and the values are the opposite.  So if
# the globj_types table consists of the single row (1, 'stories'),
# then this method will return the hashref: { stories => '1',
# '1' => 'stories' }.

sub getGlobjTypes {
	my($self) = @_;

	my $constants = getCurrentStatic();
	my $table_cache		= "_globjtypes_cache";
	my $table_cache_time	= "_globjtypes_cache_time";
	_genericCacheRefresh($self, 'globjtypes', $constants->{block_expire});
	return $self->{$table_cache} if $self->{$table_cache_time};

	# Cache needs to be built, so build it.
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $hr = $reader->sqlSelectAllKeyValue('gtid, maintable', 'globj_types');
	my @gtids = keys %$hr;
	for my $gtid (@gtids) { $hr->{$hr->{$gtid}} = $gtid }

	$self->{$table_cache} = $hr;
	$self->{$table_cache_time} = time;
	return $hr;
}

# Given a globjid, returns its globj_type and target_id.  Returns
# undef if the object does not exist.
# XXX should memcached

sub getGlobjTarget {
	my($self, $globjid) = @_;
	my($gtid, $target_id) = $self->sqlSelect(
		'gtid, target_id',
		'globjs',
		"globjid=$globjid");
	return undef unless $gtid;
	my $types = $self->getGlobjTypes;
	return undef unless $types->{$gtid};
	return ($types->{$gtid}, $target_id);
}

# Given an arrayref of globjids, returns a hashref where each key is a
# globjid and its value is an arrayref of its globj_type,target_id.
# XXX should memcached

sub getGlobjTargets {
	my($self, $globjid_ar) = @_;
	return { } if !$globjid_ar || !@$globjid_ar;

	my $target_hr = { };
	my $in_str = join(',', grep /^\d+$/, @$globjid_ar);
	my $ar_ar = $self->sqlSelectAll('globjid, gtid, target_id', 'globjs', "globjid IN ($in_str)");
	my $types = $self->getGlobjTypes;
	for my $ar (@$ar_ar) {
		$target_hr->{ $ar->[0] } = [ $types->{ $ar->[1] }, $ar->[2] ];
	}
	return $target_hr;
}

# Returns the string associated with a single globj's admin note.
# XXX should memcached

sub getGlobjAdminnote {
	my($self, $globjid) = @_;
	return undef if !$globjid;
	my $globjid_q = $self->sqlQuote($globjid);
	return $self->sqlSelect('adminnote',
		'globj_adminnotes',
		"globjid=$globjid_q");
}

# Returns a hashref for multiple globjs' admin notes:  key is the
# globjid, value is the string of the note.

sub getGlobjAdminnotes {
	my($self, $globjid_ar) = @_;
	return { } if !$globjid_ar || !@$globjid_ar;
	my $in_clause = join(',', map { $self->sqlQuote($_) } @$globjid_ar);
	return $self->sqlSelectAllKeyValue(
		'globjid, adminnote',
		'globj_adminnotes',
		"globjid IN ($in_clause)");
}

# Sets the admin note associated with a single globj.  If undef
# or the empty string are passed in for the note, the row is
# removed from the table (and undef will be returned if the
# note is later requested).

sub setGlobjAdminnote {
	my($self, $globjid, $note) = @_;
	return 0 if !$globjid;
	if (defined($note) && length($note)) {
		return $self->sqlReplace(
			'globj_adminnotes',
			{ globjid => $globjid, adminnote => $note });
	}
	my $globjid_q = $self->sqlQuote($globjid);
	return $self->sqlDelete('globj_adminnotes', "globjid = $globjid_q");
}

sub addGlobjTargetsToHashrefArray {
	my($self, $ar) = @_;
	my @globjids =
		map { $_->{globjid} }
		grep { $_->{globjid} && !$_->{globj_type} } # skip if already added
		@$ar;
	my $target = $self->getGlobjTargets(\@globjids);
	for my $hr (@$ar) {
		next unless $hr->{globjid};	# skip if bogus data
		next unless $target->{ $hr->{globjid} }; # skip if globj missing (?!)
		next if $hr->{globj_type};	# skip if already added
		my($type, $target_id) = @{ $target->{ $hr->{globjid} } };
		next unless $type;		# skip if bogus data
		$hr->{globj_type} = $type;
		$hr->{globj_target_id} = $target_id;
	}
}

# I'm reusing the word "essentials" from the method getStoriesEssentials
# because this is a similar idea.  We want to get a standard set of data
# about a list of objects.  But we recognize that there is something
# nontrivial going on behind the scenes (in gSE, lots of options and
# optimization; in aGETHA, conditional selects).  And that the standard
# set of data is based on general needs and may evolve in future.  And
# that this method kind of straddles the boundary between system logic
# and application logic.
#
# Generally speaking, for each new globj type added to the globj_types
# table, a new _addGlobjEssentials_foo call will have to appear here.
#
# Data returned is of course not guaranteed to be data which the current
# user is allowed to view.  E.g. a list of stories should be grepped
# on checkStoryViewable(), and submissions probably eliminated entirely,
# before shown to a nonadmin user.
#
# Currently, the standard set of data which is added to each hashref is:
# * title = Text string which best serves as the title for the object.
#           This may contain raw data entered by an admin... or by a
#           user or an untrusted URL, so it MUST BE STRIPPED for output.
# * url = URL to view the object
#           This is guaranteed to be a valid URI.
# * created_at = Timestamp when the object was created

sub addGlobjEssentialsToHashrefArray {
	my($self, $ar) = @_;

	# Add the fields globj_type and globj_target_id to each object.
	# If this was already done, this runs very quickly.
	$self->addGlobjTargetsToHashrefArray($ar);
	# Select all the needed information about each object and drop it
	# into %data.

	my %data = ( );

	# Some of these are not written (yet).
	$self->_addGlobjEssentials_submissions($ar, \%data);
	$self->_addGlobjEssentials_journals($ar, \%data);
	$self->_addGlobjEssentials_urls($ar, \%data);
#	$self->_addGlobjEssentials_feeds($ar, \%data);
	$self->_addGlobjEssentials_stories($ar, \%data);
#	$self->_addGlobjEssentials_vendors($ar, \%data);
#	$self->_addGlobjEssentials_miscs($ar, \%data);
	$self->_addGlobjEssentials_comments($ar, \%data);
#	$self->_addGlobjEssentials_discussions($ar, \%data);
	$self->_addGlobjEssentials_projects($ar, \%data);

	# Scan over the arrayref and insert the information from %data
	# for each object.

	for my $object (@$ar) {
		my $globjid = $object->{globjid};
		next unless exists $data{$globjid};
		$object->{url} = $data{$globjid}{url};
		$object->{title} = $data{$globjid}{title};
		$object->{created_at} = $data{$globjid}{created_at};
	}
}

sub _addGlobjEssentials_getids {
	my($ar, $type) = @_;
	my %ids = (
		map { ( $_->{globj_target_id}, $_->{globjid} ) }
		grep { $_->{globj_type} eq $type }
		@$ar
	);
	return \%ids;
}

sub _addGlobjEssentials_stories {
	my($self, $ar, $data_hr) = @_;
	my $stoids_hr = _addGlobjEssentials_getids($ar, 'stories');
	my @stoids = keys %$stoids_hr;
	for my $stoid (@stoids) {
		my $globjid = $stoids_hr->{$stoid};
		my $story = $self->getStory($stoid);
		my $data_ar = linkStory({ stoid => $stoid });
		my($url, $title) = @$data_ar;
#print STDERR "for stoid $stoid url='$url' title='$title' time='$story->{time}'\n";
		$data_hr->{$globjid}{url} = $url;
		$data_hr->{$globjid}{title} = $title;
		$data_hr->{$globjid}{created_at} = $story->{time};
	}
}

sub _addGlobjEssentials_urls {
	my($self, $ar, $data_hr) = @_;
	my $constants = getCurrentStatic();
	my $urls_hr = _addGlobjEssentials_getids($ar, 'urls');
	my @url_ids = keys %$urls_hr;
	my $id_str = join(',', @url_ids);
	my $urldata_hr = $id_str
		? $self->sqlSelectAllHashref('url_id',
			'url_id, url, createtime, initialtitle, validatedtitle',
			'urls',
			"url_id IN ($id_str)")
		: { };
	my $hoseid_hr = { };
	for my $url_id (@url_ids) {
		my $globjid = $urls_hr->{$url_id};
		$data_hr->{$globjid}{url} = $urldata_hr->{$url_id}{url};
		$data_hr->{$globjid}{title} = $urldata_hr->{$url_id}{validatedtitle}
			|| $urldata_hr->{$url_id}{initialtitle};
		$data_hr->{$globjid}{created_at} = $urldata_hr->{$url_id}{createtime};
	}
}

sub _addGlobjEssentials_submissions {
	my($self, $ar, $data_hr) = @_;
	my $skins = $self->getSkins();
	my $submissions_hr = _addGlobjEssentials_getids($ar, 'submissions');
	my @subids = keys %$submissions_hr;
	my $subid_str = join(',', @subids);
	my $submissiondata_hr = $subid_str
		? $self->sqlSelectAllHashref('subid',
			'subid, subj, time, primaryskid',
			'submissions',
			"subid IN ($subid_str)")
		: { };
	for my $subid (@subids) {
		my $globjid = $submissions_hr->{$subid};
		my $skin = $skins->{ $submissiondata_hr->{$subid}{primaryskid} };
		$data_hr->{$globjid}{url} = "$skin->{rootdir}/submit.pl?op=viewsub&subid=$subid";
		$data_hr->{$globjid}{title} = $submissiondata_hr->{$subid}{subj};
		$data_hr->{$globjid}{created_at} = $submissiondata_hr->{$subid}{time};
	#	use Data::Dumper; print STDERR "submission subid=$subid globjid=$globjid. skin, submissiondata, data_hr: " . Dumper($skin) . Dumper($submissiondata_hr->{$subid}) . Dumper($data_hr->{$globjid});
	}
}

sub _addGlobjEssentials_journals {
	my($self, $ar, $data_hr) = @_;
	my $constants = getCurrentStatic();
	my $journals_hr = _addGlobjEssentials_getids($ar, 'journals');
	my @journal_ids = sort { $a <=> $b } keys %$journals_hr;
	my $id_str = join(',', @journal_ids);
	my $journaldata_hr = $id_str
		? $self->sqlSelectAllHashref('id',
			'id, journals.uid, date, description, nickname',
			'journals, users',
			"id IN ($id_str) AND journals.uid=users.uid")
		: { };
	for my $id (@journal_ids) {
		my $globjid = $journals_hr->{$id};
		my $fixnick = $journaldata_hr->{$id}{nickname};
if (!defined $fixnick) { print STDERR scalar(gmtime) . " _addGlobjEssentials_journals no nick for journal $id\n"; }
		$fixnick = fixparam($fixnick || '');
		$data_hr->{$globjid}{url} = "$constants->{real_rootdir}/~$fixnick/journal/$id";
		$data_hr->{$globjid}{title} = $journaldata_hr->{$id}{description};
		$data_hr->{$globjid}{created_at} = $journaldata_hr->{$id}{date};
	}
}

sub _addGlobjEssentials_comments {
	my($self, $ar, $data_hr) = @_;
	my $constants = getCurrentStatic();
	my $comments_hr = _addGlobjEssentials_getids($ar, 'comments');
	my @comment_ids = sort { $a <=> $b } keys %$comments_hr;
	my $id_str = join(',', @comment_ids);
	my $commentdata_hr = $id_str
		? $self->sqlSelectAllHashref('cid',
			'cid, sid, date, subject',
			'comments',
			"cid IN ($id_str)")
		: { };
	for my $cid (@comment_ids) {
		my $globjid = $comments_hr->{$cid};
		$data_hr->{$globjid}{url} = "$constants->{rootdir}/comments.pl?sid=$commentdata_hr->{$cid}{sid}&cid=$cid";
		$data_hr->{$globjid}{title} = $commentdata_hr->{$cid}{subject};
		$data_hr->{$globjid}{created_at} = $commentdata_hr->{$cid}{date};
	}
}

sub _addGlobjEssentials_projects {
	my($self, $ar, $data_hr) = @_;
	my $constants = getCurrentStatic();
	my $projects_hr = _addGlobjEssentials_getids($ar, 'projects');
	my @project_ids = sort { $a <=> $b } keys %$projects_hr;
	my $id_str = join(',', @project_ids);
	my $projectdata_hr = $id_str
		? $self->sqlSelectAllHashref('id',
			'id, url, textname, projects.createtime',
			'projects, urls',
			"id IN ($id_str) AND projects.url_id=urls.url_id")
		: { };
	for my $id (@project_ids) {
		my $globjid = $projects_hr->{$id};
		$data_hr->{$globjid}{url} = $projectdata_hr->{$id}{url};
		$data_hr->{$globjid}{title} = $projectdata_hr->{$id}{textname};
		$data_hr->{$globjid}{created_at} = $projectdata_hr->{$id}{createtime};
	}
}

# Returns a hashref in which the keys are either numeric clid's OR
# the names of clout types, and the values are the opposite.  So if
# the clid_types table is the row (1, 'vote', 'Slash::Foo'),
# then this method will return the hashref: { vote => '1',
# '1' => 'vote' }.
# XXX is the 'name' column really necessary or can I just have all
# the code refer to the class name?

sub getCloutTypes {
	my($self) = @_;

	my $constants = getCurrentStatic();
	my $table_cache		= "_clouttypes_cache";
	my $table_cache_time	= "_clouttypes_cache_time";
	_genericCacheRefresh($self, 'clouttypes', $constants->{block_expire});
	return $self->{$table_cache} if $self->{$table_cache_time};

	# Cache needs to be built, so build it.
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $hr = $reader->sqlSelectAllKeyValue('clid, name', 'clout_types');
	my @clids = keys %$hr;
	for my $clid (@clids) { $hr->{$hr->{$clid}} = $clid }

	$self->{$table_cache} = $hr;
	$self->{$table_cache_time} = time;
	return $hr;
}

# If the clid_types table is the row (1, 'vote', 'Slash::Clout::Vote'),
# then this method will return the hashref: { 1 =>
# { name => 'vote' }, { class => 'Slash::Clout::Vote' }, { clid => 1 } }

sub getCloutInfo {
	my($self) = @_;

	my $constants = getCurrentStatic();
	my $table_cache		= "_cloutclass_cache";
	my $table_cache_time	= "_cloutclass_cache_time";
	_genericCacheRefresh($self, 'cloutclass', $constants->{block_expire});
	return $self->{$table_cache} if $self->{$table_cache_time};

	# Cache needs to be built, so build it.
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $hr = $reader->sqlSelectAllHashref('clid', '*', 'clout_types');

	$self->{$table_cache} = $hr;
	$self->{$table_cache_time} = time;
	return $hr;
}

sub getActiveAdminCount {
	my($self) = @_;
	my $admin_timeout = getCurrentStatic('admin_timeout');
	return $self->sqlSelect("COUNT(DISTINCT sessions.uid)",
		"sessions,users_param",
		"sessions.uid=users_param.uid
		 AND name='adminlaststorychange'
		 AND DATE_SUB(NOW(), INTERVAL $admin_timeout MINUTE) <= value"
	);
}

sub getRelatedStoriesForStoid {
	my($self, $stoid) = @_;
	my $stoid_q = $self->sqlQuote($stoid);
	return $self->sqlSelectAllHashrefArray(
		"*",
		"related_stories",
		"stoid=$stoid_q",
		"ORDER BY ordernum asc"
	);
}

sub setRelatedStoriesForStory {
	my($self, $sid_or_stoid, $rel_sid_hr, $rel_url_hr, $rel_cid_hr, $rel_fh_hr) = @_;
	my $constants = getCurrentStatic();
	my $stoid = $self->getStoidFromSidOrStoid($sid_or_stoid);
	my $stoid_q = $self->sqlQuote($stoid);
	my $story = $self->getStory($stoid);

	my $prev_rel_stories = $self->getRelatedStoriesForStoid($stoid);

	my @unparented_cids;

	foreach my $prev_rel (@$prev_rel_stories) {
		if ($prev_rel->{rel_stoid}) {
			my $rel_stoid_q = $self->sqlQuote($prev_rel->{rel_stoid});
			$self->sqlDelete("related_stories", "stoid=$rel_stoid_q AND rel_stoid=$stoid_q");
		}
	}
	
	$self->sqlDelete("related_stories", "stoid = $stoid_q");
	
	foreach my $rel_cid (keys %$rel_cid_hr) {
		my $disc = $self->getDiscussion($rel_cid_hr->{$rel_cid}{sid});
		if ($disc->{sid} && !$rel_sid_hr->{$disc->{sid}}) {
			$rel_sid_hr->{$disc->{sid}} = $self->getStory($disc->{sid});
		}
		if ($disc->{sid}) {
			push @{$rel_sid_hr->{$disc->{sid}}{cids}}, $rel_cid;
		} else {
			push @unparented_cids, $rel_cid;
		}
	}

	my $i = 1;
	foreach my $rel (sort keys %$rel_sid_hr) {
		my $rel_stoid = $self->getStoidFromSidOrStoid($rel);
		$self->sqlInsert("related_stories", {
			stoid		=> $stoid,
			rel_sid		=> $rel,
			rel_stoid	=> $rel_stoid,
			ordernum 	=> $i
		});
		
		$i++;

		if ($rel_sid_hr->{$rel}{cids}) {
			foreach my $cid (sort {$a <=> $b } @{$rel_sid_hr->{$rel}{cids}}) {
				$self->sqlInsert("related_stories", {
					stoid 		=> $stoid,
					cid		=> $cid,
					ordernum 	=> $i
				});
				$i++;
			}
		}

		# Insert reciprocal link if it doesn't already exist
		my $rel_stoid_q = $self->sqlQuote($rel_stoid);
		my $ordnum = $self->sqlSelect("MAX(ordernum)", "related_stories", "stoid= $rel_stoid_q AND (url='' or url is null)") || 0;
		$self->sqlUpdate("related_stories", {
					-ordernum => "ordernum + 1"
				}, "(url != '' OR url is not null) AND stoid = $rel_stoid_q"
		);
		$ordnum++;
		my $sid_q = $self->sqlQuote($story->{sid});
		if (!$self->sqlCount("related_stories", "stoid = $rel_stoid_q AND rel_sid = $sid_q")) {
			$self->sqlInsert("related_stories", {
				stoid		=> $rel_stoid,
				rel_sid		=> $story->{sid},
				rel_stoid	=> $stoid,
				ordernum	=> $ordnum
			});
			$self->markStoryDirty($rel_stoid);
		}
	}

	foreach my $cid (sort {$a <=> $b } @unparented_cids) {
		$self->sqlInsert("related_stories", {
			stoid	 => $stoid,
			cid 	 => $cid,
			ordernum => $i,
		});
		$i++;
	}

	foreach my $rel_url (keys %$rel_url_hr) {
		$self->sqlInsert("related_stories", {
			stoid   => $stoid,
			url     => $rel_url,
			title	=> $rel_url_hr->{$rel_url},
			ordernum => $i
		});
		$i++;
	}

}

sub updateSubMemory {
	my($self, $submatch, $subnote) = @_;

	my $user = getCurrentUser();

	return if !$submatch;

	my $noid = $self->sqlSelect('noid','submissions_notes',
		'submatch=' . $self->sqlQuote($submatch));


	$self->sqlInsert('submissions_notes', {
		submatch        => $submatch,
		subnote         => $subnote,
		uid             => $user->{uid},
		'-time'         => 'NOW()',
		});
}

sub getSubmissionMemory {
	my($self) = @_;

	return $self->sqlSelectAllHashrefArray('submatch, subnote, time, uid',
		'submissions_notes',
		"subnote IS NOT NULL AND subnote != ''",
		'ORDER BY time DESC'
	);
}


sub getUrlCreate {
	my($self, $data) = @_;
	$data ||= {};
	return 0 if !$data->{url};
	my $id = $self->getUrlIfExists($data->{url});
	return $id if $id;
	return $self->createUrl($data);
}

sub createUrl {
	my($self, $data) = @_;
	$data ||= {};
	$data->{url_digest} = md5_hex($data->{url});
	$data->{'-createtime'} = 'NOW()',
	$self->sqlInsert("urls", $data);
	my $id = $self->getLastInsertId();
	return $id;
}

sub setUrl {
	my($self, $url_id, $data) = @_;
	my $url_id_q = $self->sqlQuote($url_id);

	my %data_update = %$data;
	delete $data_update{url_id};
	$data_update{url_digest} = md5_hex($data->{url}) if exists $data->{url};

	$self->sqlUpdate("urls", \%data_update, "url_id=$url_id_q");
}

sub getUrlIfExists {
	my($self, $url) = @_;
	my $md5 = md5_hex($url);
	my $urlid = $self->sqlSelect("url_id", "urls", "url_digest = '$md5'");
	return $urlid;
}

sub addUrlForGlobj {
	my($self, $url_id, $globjid) = @_;
	$self->sqlInsert("globj_urls", { url_id => $url_id, globjid => $globjid }, { ignore => 1 });
}

sub getClassForAjaxOp {
	my($self, $op) = @_;
	my $op_q = $self->sqlQuote($op);
	return $self->sqlSelect("class", "ajax_ops", "op=$op_q");
}

sub insertMediaFile {
	my($self, $stoid, $name) = @_;
	return $self->sqlInsert("stories_media", { stoid => $stoid, name => $name }, { ignore => 1 });
}

sub updateMediaFile {
	my($self, $name, $data) = @_;
	$self->sqlUpdate("stories_media", $data, "name=$name");
}

sub getMediaFiles {
	my($self, $stoid) = @_;
	return $self->sqlSelectAllHashrefArray('smid, name',
				'stories_media',
				"stoid=$stoid"
		);
}

sub getMediaFile {
	my($self, $data) = @_;

	if ($data =~ /\d+/) {
		return $self->sqlSelect("width, height, location", "stories_media", "smid=$data");
	} else {
		return $self->sqlSelect("width, height, location", "stories_media", "name=$data");
	}
}

sub addFileToQueue {
	my($self, $file) = @_;
	$self->sqlInsert("file_queue", $file);
}

sub numPendingFilesForStory {
	my($self, $stoid) = @_;
	my $stoid_q = $self->sqlQuote($stoid);
	$self->sqlCount("file_queue", "stoid=$stoid_q");
}

sub addStaticFile {
	my($self, $data) = @_;
	my $constants = getCurrentStatic();
	$data ||= {};
	
	# Guess at file type if it isn't set
	if ($data->{name} =~ /\.(jpg|gif|png)$/) {
		$data->{filetype} ||= "image";
	} elsif ($data->{name} =~ /\.(jpg|gif|png)$/) {
		$data->{filetype} ||= "audio";
	}
	$data->{name} =~ s/^\Q$constants->{basedir}\E\/images//g;

	$self->sqlInsert("static_files", $data);
	my $sfid = $self->getLastInsertId;
	return $sfid;
}

sub getStaticFilesForStory {
	my($self, $stoid) = @_;
	my $stoid_q = $self->sqlQuote($stoid);
	return $self->sqlSelectAllHashrefArray("*", "static_files", "stoid=$stoid_q");
}

sub getStaticFile {
	my $answer = _genericGetCache({
		table		=> 'static_files',
		table_prime	=> 'sfid',
		arguments	=> \@_,
	});
	return $answer;
}

sub isCommentPromoted {
	my($self, $cid) = @_;
	return $self->sqlCount("comment_promote_log", "cid=" . $self->sqlQuote($cid));
}

sub logCommentPromotion {
	my($self, $cid) = @_;
	$self->sqlInsert("comment_promote_log", { cid => $cid, -ts => "NOW()" });
}


sub doFlagSpam {
    my ($self, $cid, $spam_flag, $mod_uid, $mod_reason) = @_;

    # Begin transaction
    $self->sqlDo("SET AUTOCOMMIT=0");

    # Prepare the data for the update
    my $data = { spam_flag => $spam_flag };
    my $where = "cid = " . $self->sqlQuote($cid);

    # Update the spam flag using sqlUpdate
    my $result = $self->sqlUpdate('comments', $data, $where);

    if ($result) {
        # Log the reason in the comments_audit table
        $self->logCommentAudit($cid, $mod_uid, $mod_reason, $spam_flag);

        # Commit transaction
        $self->sqlDo("COMMIT");
        $self->sqlDo("SET AUTOCOMMIT=1");

        return 1;  # Success
    } else {
        # Rollback transaction
        $self->sqlDo("ROLLBACK");
        $self->sqlDo("SET AUTOCOMMIT=1");

        return 0;  # Failure
    }
}

sub logCommentAudit {
    my ($self, $cid, $mod_uid, $mod_reason, $spam_flag) = @_;
    my $data = {
        cid        => $cid,
        -date       => 'NOW()',  # Use a reference to a raw SQL expression
        mod_uid    => $mod_uid,
        mod_reason => $mod_reason,
        spam_flag  => $spam_flag,
    };
    $self->sqlInsert("comments_audit", $data);
}

sub getCommentsAudit {
    my ($self, $cid, $limit) = @_;

    # Default limit to 100 if not provided
    $limit = 100 unless defined $limit;

    my $select = '*';
    my $from = 'comments_audit';
    my $where = $cid ? "cid = " . $self->sqlQuote($cid) : undef;
    my $other = $cid ? '' : "ORDER BY date DESC" . ($limit ? " LIMIT $limit" : '');

    return $self->sqlSelectMany($select, $from, $where, $other);
}

sub createProject {
	my($self, $data) = @_;
	$self->sqlInsert("projects", $data);
	my $pid = $self->getLastInsertId();
	return $pid;
}

sub getProject {
	my $answer = _genericGetCache({
		table		=> 'projects',
		table_prime	=> 'id',
		arguments	=> \@_,
	});
	return $answer;
}

sub setProject {
	_genericSet('projects', 'id', '', @_);
}

sub getProjectByName {
	my ($self, $name) = @_;
	my $name_q = $self->sqlQuote($name);
	return $self->sqlSelectHashref("*","projects", "unixname=$name_q");
}

sub createPreview {
	my($self, $preview) = @_;
	return unless $preview && $preview->{uid};
	
	my $data;

	$data->{'-createtime'} 	= 'NOW()';

	$data->{uid} 		= delete $preview->{uid};
	$data->{introtext} 	= delete $preview->{introtext} || '';
	$data->{bodytext} 	= delete $preview->{bodytext} || '';
	$data->{preview_fhid} 	= delete $preview->{preview_fhid} || '';
	$data->{src_fhid} 	= delete $preview->{src_fhid} || '';
	$data->{title} 		= delete $preview->{title} || '';

	$self->sqlInsert('preview', $data);
	my $preview_id = $self->getLastInsertId();

	# The next line makes sure that we get any section_extras in the DB - Brian
	$self->setPreview($preview_id, $preview) if $preview_id && keys %$preview;

	return $preview_id;
}

sub getPreview {
	my $answer = _genericGet({
		table		=> 'preview',
		table_prime	=> 'preview_id',
		param_table	=> 'preview_param',
		arguments	=> \@_,
	});
	return $answer;
}


sub setPreview {
	_genericSet('preview', 'preview_id', 'preview_param', @_);
}

sub deletePreview {
	my($self, $id) = @_;
	my $id_q = $self->sqlQuote($id);
	my $preview = $self->getPreview($id);

	# XXXEdit Delete preview fhitem too eventually
	
	$self->sqlDelete("preview","preview_id=$id_q");
	$self->sqlDelete("preview_param","preview_id=$id_q");
}


sub _getStorySelfLink {
	my($self, $stoid, $change_hr) = @_; 
	my $story = $self->getStory($stoid);
	my $data = {};
	my $link  = $change_hr->{title} || $story->{title};
	my $tid   = $change_hr->{tid} || $story->{tid};
	my $skin  = $change_hr->{primaryskid} || $story->{primary_skid};

	my $story_link_ar = linkStory({
		sid 	=> $story->{sid},
		link 	=> $link,
		tid	=> $tid,
		skin	=> $skin
	});
	return $story_link_ar->[0];
}

sub getShillInfo {
	my($self, $shill_id) = @_;
	my $shill_id_q = $self->sqlQuote($shill_id);
	
	return $self->sqlSelectHashref('*', 'shill_ids', "shill_id=$shill_id_q");

}


=head2 getDBSchemaVersions 

 Usage     : Dumps a list of known database versions
 Purpose   : used to determine if an upgrade needs to be run or not
 Returns   : hashref of master schema version + plugins schemas
 Argument  : none

See Also   : 

=cut

sub getDBSchemaVersions
{
	my ($self) = @_;

	# Everything has a schema version of 0 if not explicately set
	return $self->sqlSelectAllKeyValue('name, value', 'site_info', 'name like \'db_schema%\''); 
}

########################################################
# This is kind of expensive but I don't know a better way to do it.
########################################################
sub updateChildrenCounts {
	my ($self, $firstparentcid) = @_;
	my @cids;
	my $firstparent = $self->getComment($firstparentcid);
	my $comment = $firstparent;
	
	# Load @cids with a list of all parent cids so we can increment their `children` columns
	while(1) {
		push(@cids, $comment->{cid});
		if($comment->{pid} == 0){ last; }
		$comment = $self->getComment($comment->{pid});
	}

	my $wherecid = join(' OR cid = ', @cids);
	my $result;
	
	unless($self->sqlDo("UPDATE comments SET children = children + 1 WHERE cid = $wherecid")) {
		return { status => 0, errortxt => $DBI::errstr };
	}
	
	return { status => 1 };
}

########################################################
# Ok, it's fucking 2014, we can afford an UPDATE per page
# view to have accurate login information, and not this shit
# slash currently does
########################################################

sub updateLastAccessTimestamp {
	my ($self, $uid) = @_;
	
	return $self->sqlUpdate(
		'users_info',
		{ -lastaccess_ts => 'CURRENT_TIMESTAMP'},
		"uid=$uid"
 	);
}


########################################################
sub DESTROY {
	my($self) = @_;

	# Flush accesslog insert cache, if necessary.
	$self->_writeAccessLogCache;

	# Flush the querylog cache too, if necessary (see
	# Slash::DB::Utility).
	$self->_querylog_writecache;

	# Slash::Tagbox, a subclass of MySQL.pm, does this too:
	#	$self->{_dbh}->disconnect if $self->{_dbh} && !$ENV{MOD_PERL};
	# I'm not sure why we don't do that here instead.  I'm not sure
	# how often it actually happens that a MySQL.pm is destroyed by
	# slashd, and I don't know exactly how DBI.pm handles disconnects
	# for its connect_cached pool, but if DESTROY is called, wouldn't
	# it make sense to help mysqld manage its connections by releasing
	# a dbh?
	# - jamie 2008/08/04

	$self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
}

#!/usr/bin/perl

##################################################################
# TMB This sub returns stories with a pubdate newer than NOW().
sub getStoriesSince {
	my ($self, $dtime, $limit) = @_;

	my $mp_tid = getCurrentStatic('mainpage_nexus_tid');
	my @nexuses = $self->getNexusTids();
	my $nexus_clause = join ',', @nexuses, $mp_tid;

	$limit = $limit ? 'LIMIT ' . $limit : '';

	my $answer = $self->sqlSelectAllHashrefArray(
		'primaryskid, submitter, title, time',
		'stories, story_text, story_topics_rendered',
			"stories.stoid = story_topics_rendered.stoid
			AND stories.stoid = story_text.stoid
			AND time > NOW()
			AND story_topics_rendered.tid IN ($nexus_clause)
			AND in_trash = 'no'",
		"GROUP BY stories.stoid ORDER by time DESC $limit");
	formatDate($answer, 'time', 'time', '%m/%d  %H:%M');

	return $answer;
}

sub nickExists {
	my ($self, $nick) = @_;

	my $uid = $self->getUserUID($nick);
	return 0 if (! defined($uid)) || isAnon($uid);
	return 1;
}

##################################################################
# Database upgrades to core go here, keep this right below the bottom
#
# Feel free to use sqlDO in this section; upgrade methods are never
# called from the UI, only from the update-database utility.

sub upgradeCoreDB() {
	# Check the versions of stuff
	my ($self, $upgrade) = @_;
	my $schema_versions = $upgrade->getSchemaVersions();
	my $core_ver = $schema_versions->{core};
	my $upgrades_done = 0;
	my $constants = getCurrentStatic();
	
	if ($core_ver == 0) {
		# Every schema upgrade should have a comment as to why. In this case, initialize the
		# core version schema
		print "upgrading Core to v1 ...\n";
		if (!$self->sqlDo("UPDATE vars SET value = 'rehash_16_02' WHERE name = 'cvs_tag_currentcode'")) {
			return 0;
		};
		if (!$self->sqlDo("INSERT INTO site_info (name, value, description) VALUES ('db_schema_core', 1, 'Version of core database schema')")) {
			return 0;
		};
		$core_ver = 1;
		$upgrades_done++;
	}
	if ($core_ver == 1) {
		print "upgrading Core to v2 ...\n";
		if(!$self->sqlDo("DROP TABLE IF EXISTS users_comments_read_log")) {
			return 0;
		}
		if(!$self->sqlDo("CREATE TABLE users_comments_read_log (
			uid mediumint(8) unsigned NOT NULL,
			discussion_id mediumint(8) unsigned NOT NULL,
			cid_now int(10) unsigned NOT NULL,
			cid_new int(10) unsigned NOT NULL,
			ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
			PRIMARY KEY (discussion_id, uid)
			) ENGINE=ndbcluster DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci
		")) {
			return 0;
		}
		if (!$self->sqlDo("ALTER TABLE users_comments ADD highnew tinyint(4) NOT NULL default 1")) {
			return 0;
		}
		if (!$self->sqlDo("ALTER TABLE users_comments ADD dimread tinyint(4) NOT NULL default 1")) {
			return 0;
		}
		if (!$self->sqlDo("INSERT INTO vars (name, value, description) VALUES ('comment_read_max_age', '30', 'Number of days to save the read state of comments for a user+discussion.')")) {
			return 0;
		}
		if (!$self->sqlDo("DELETE FROM commentmodes where mode = 'nested' or mode = 'improvedthreaded' or mode = 'thread'")) {
			return 0;
		}
		if (!$self->sqlDo("INSERT INTO commentmodes (mode, name) VALUES ('threadtos', 'Threaded-TOS')")) {
			return 0;
		}
		if (!$self->sqlDo("INSERT INTO commentmodes (mode, name) VALUES ('threadtng', 'Threaded-TNG')")) {
			return 0;
		}
		if (!$self->sqlDo("ALTER TABLE users_comments ADD mode_new ENUM('flat', 'nocomment', 'threadtos', 'threadtng') NOT NULL DEFAULT 'threadtos'")) {
			return 0;
		}
		if (!$self->sqlDo("UPDATE users_comments SET mode_new = 'threadtos' WHERE mode = 'thread' OR mode = 'nested' OR mode = 'improvedthreaded'")) {
			return 0;
		}
		if (!$self->sqlDo("UPDATE users_comments SET mode_new = 'flat' WHERE mode = 'flat'")) {
			return 0;
		}
		if (!$self->sqlDo("UPDATE users_comments SET mode_new = 'nocomment' WHERE mode = 'nocomment'")) {
			return 0;
		}
		if (!$self->sqlDo("ALTER TABLE users_comments DROP mode")) {
			return 0;
		}
		if (!$self->sqlDo("ALTER TABLE users_comments CHANGE mode_new mode ENUM('flat', 'nocomment', 'threadtos', 'threadtng') NOT NULL DEFAULT 'threadtos'")) {
			return 0;
		}
		if (!$self->sqlDo("DELETE FROM vars WHERE name = 'comments_hardcoded'")) {
			return 0;
		}
		if (!$self->sqlDo("ALTER TABLE discussions ADD legacy ENUM('no', 'yes') NOT NULL DEFAULT 'yes'")) {
			return 0;
		}
		if (!$self->sqlDo("ALTER TABLE comments ADD opid INT(10) UNSIGNED NOT NULL DEFAULT 0 AFTER pid")) {
			return 0;
		}
		if (!$self->sqlDo("ALTER TABLE comments ADD children INT(10) UNSIGNED NOT NULL DEFAULT 0 AFTER opid")) {
			return 0;
		}
		my $newTag = $self->sqlSelect('value', 'vars', "name = 'approvedtags'")."|spoiler|del";
		if (!$self->sqlDo("UPDATE vars SET value = '$newTag' WHERE name = 'approvedtags'")) {
			return 0;
		}
		$newTag = $self->sqlSelect('value', 'vars', "name = 'approvedtags_visible'")."|spoiler|del";
		if (!$self->sqlDo("UPDATE vars SET value = '$newTag' WHERE name = 'approvedtags_visible'")) {
			return 0;
		}
		$newTag = $self->sqlSelect('value', 'vars', "name = 'approvedtags_break'")."|spoiler";
		if (!$self->sqlDo("UPDATE vars SET value = '$newTag' WHERE name = 'approvedtags_break'")) {
			return 0;
		}
		if (!$self->sqlDo("UPDATE site_info SET value = 2 WHERE name = 'db_schema_core'")) {
			return 0;
		}
		my $acid = $self->sqlSelect('value', 'vars', "name = 'anonymous_coward_uid'");
			if (!$self->sqlDo("UPDATE users_comments SET threshold  = 0 WHERE uid = $acid")) {
			return 0;
		}	
		if (!$self->sqlDo("UPDATE users_comments SET highlightthresh  = 2 WHERE uid = $acid")) {
			return 0;
		}
		if (!$self->sqlDo("INSERT INTO vars (name, value, description) VALUES ('story_more', '[Continues...]', 'Text for label when there is extended copy in stories')")) {
			return 0;
		}
		if (!$self->sqlDo("UPDATE vars SET value = 'rehash_17_02' WHERE name = 'cvs_tag_currentcode'")) {
			return 0;
		};
		if (!$self->sqlDo("DELETE FROM code_param WHERE type = 'sortcodes' AND code > 1")) {
			return 0;
		}
		if (!$self->sqlDo("UPDATE users_comments SET commentsort = 0 WHERE commentsort = 3 OR commentsort = 4")) {
			return 0;
		}
		if (!$self->sqlDo("UPDATE users_comments SET commentsort = 1 WHERE commentsort = 5")) {
			return 0;
		}
		$core_ver = 2;
		$upgrades_done++;
	}
	
	
	if ($core_ver < 3 ) {
		print "Upgrading Core to v3 ...\n";
		print "Running: UPDATE vars SET value = 'rehash_17_05' WHERE name = 'cvs_tag_currentcode' \n";
		if (!$self->sqlDo("UPDATE vars SET value = 'rehash_17_05' WHERE name = 'cvs_tag_currentcode'")) {
			return 0;
		}
		print "Running: UPDATE vars SET value = 'b|i|p|br|a|ol|ul|li|dl|dt|dd|em|strong|tt|blockquote|div|ecode|quote|sup|sub|abbr|sarc|sarcasm|user|spoiler|del|s|strike' WHERE name = 'approvedtags' OR name = 'approvedtags_visible' \n";
		if (!$self->sqlDo("UPDATE vars SET value = 'b|i|p|br|a|ol|ul|li|dl|dt|dd|em|strong|tt|blockquote|div|ecode|quote|sup|sub|abbr|sarc|sarcasm|user|spoiler|del|s|strike' WHERE name = 'approvedtags' OR name = 'approvedtags_visible'")) {
			return 0;
		}
		print "Set to version 3 \n";
		if (!$self->sqlDo("UPDATE site_info SET value = 3 WHERE name = 'db_schema_core'")) {
			return 0;
		}
		print "Upgrade complete \n";
		$core_ver = 3;
		$upgrades_done++;
	}

	if ($core_ver < 4) {
		print "Upgrading Core to v4 ...\n";
		print "Running: REPLACE INTO vars VALUES ('filters_extended_regexes', 0, 'Use extended regexes in Filters or not. Any setting other than 0 or unset counts as TRUE')\n";
		if(!$self->sqlDo("REPLACE INTO vars VALUES ('filters_extended_regexes', 0, 'Use extended regexes in Filters or not. Any setting other than 0 or unset counts as TRUE')")) {
			return 0;
		}
		print "Running: ALTER TABLE stories CHANGE COLUMN notes notes TEXT NULL DEFAULT NULL\n";
		if(!$self->sqlDo("ALTER TABLE stories CHANGE COLUMN notes notes TEXT NULL DEFAULT NULL")) {
			return 0;
		}
		print "Running: ALTER TABLE submissions CHANGE COLUMN comment comment TEXT NULL DEFAULT NULL\n";
		if(!$self->sqlDo("ALTER TABLE submissions CHANGE COLUMN comment comment TEXT NULL DEFAULT NULL")) {
			return 0;
		}
		print "Set version to 4\n";
		if (!$self->sqlDo("UPDATE site_info SET value = 4 WHERE name = 'db_schema_core'")) {
			return 0;
		}
		print "Upgrade complete \n";
		$core_ver = 4;
		$upgrades_done++;
	}

	if ($core_ver < 5) {
		my ($fulldays, $halfdays, $quarterdays) = ($constants->{bad_karma_full_weight}, $constants->{bad_karma_half_weight}, $constants->{bad_karma_quarter_weight});
		print "Upgrading Core to v5 ...\n";
		print "Running: REPLACE INTO vars VALUES ('bad_karma_full_weight', 7, 'Number of days comments negative karma should have full value for ipid/subnetid')\n";
		if(!$self->sqlDo("REPLACE INTO vars VALUES ('bad_karma_full_weight', 7, 'Number of days comments negative karma should have full value for ipid/subnetid')")) {
			return 0;
		}
		print "Running: REPLACE INTO vars VALUES ('bad_karma_half_weight', 14, 'Number of days comments negative karma should have half value for ipid/subnetid')\n";
		if(!$self->sqlDo("REPLACE INTO vars VALUES ('bad_karma_half_weight', 14, 'Number of days comments negative karma should have half value for ipid/subnetid')")) {
			return 0;
		}
		print "Running: REPLACE INTO vars VALUES ('bad_karma_quarter_weight', 30, 'Number of days comments negative karma should have quarter value for ipid/subnetid')\n";
		if(!$self->sqlDo("REPLACE INTO vars VALUES ('bad_karma_quarter_weight', 30, 'Number of days comments negative karma should have quarter value for ipid/subnetid')")) {
			return 0;
		}
		print "Running: REPLACE INTO vars VALUES ('bad_karma_zero_weight', 60, 'Number of days after which we stop reading ipid/subnetid karma, positive or negative')\n";
		if(!$self->sqlDo("REPLACE INTO vars VALUES ('bad_karma_zero_weight', 60, 'Number of days after which we stop reading ipid/subnetid karma, positive or negative')")) {
			return 0;
		}
		print "Set version to 5\n";
		if (!$self->sqlDo("UPDATE site_info SET value = 5 WHERE name = 'db_schema_core'")) {
			return 0;
		}
		print "Upgrade complete \n";
		$core_ver = 5;
		$upgrades_done++;
	}
			

	if (!$upgrades_done) {
		print "No upgrades needed for Core V$core_ver \n";
	}
	return 1;
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

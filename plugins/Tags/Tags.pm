# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Tags;

use strict;
use Date::Format qw( time2str );
use Slash;
use Slash::Display;
use Slash::Utility;
use Slash::DB::Utility;
use Apache::Cookie;
use vars qw($VERSION);
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# FRY: And where would a giant nerd be? THE LIBRARY!

#################################################################
sub new {
	my($class, $user) = @_;
	my $self = {};

	my $plugin = getCurrentStatic('plugin');
	return unless $plugin->{Tags};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect();

	return $self;
}

########################################################

# createTag's first argument is a hashref with three sets of
# named arguments.
# The first set is:
#       uid             User id creating the tag
#                       (optional, defaults to current user)
# The second set is exactly one of either:
#       name            Tagname (i.e. the text of the tag)
# or
#       tagnameid       Tagnameid (i.e. the tags.tagnameid of the tag)
# The third set is exactly one of either:
#       table           Maintable of the object being tagged (e.g. 'stories')
#       id              ID of the object in that table (e.g. a stoid)
# or
#       globjid         Global object ID of the object being tagged
#
# At present, no other named arguments are permitted in
# createTag's first argument.
#
# This method takes care of creating the tagname and/or globj, if they
# do not already exists, so that the tag may connect them.
#
# By default, this does not allow the same user to apply the same
# tagname to the same global object twice.  createTag's second
# argument is an option hashref.  Pass the field 'dupe_ok' with a
# true value to ignore this check.  Nor is it allowed for the same
# user to tag the same object with both a tag and its opposite, but
# 'opposite_ok' ignores that check.  At the moment we can't think
# of a good reason why one would ever want to ignore those checks
# but the options are there regardless.  Is this good design?
# Probably not.

sub _setuptag {
	my($self, $hr) = @_;
	my $tag = { -created_at => 'NOW()' };

        $tag->{uid} = $hr->{uid} || getCurrentUser('uid');

        if ($hr->{tagnameid}) {
                $tag->{tagnameid} = $hr->{tagnameid};
        } else {
                # Need to determine tagnameid from name.  We
                # create the new tag name if necessary.
                $tag->{tagnameid} = $self->getTagidCreate($hr->{name});
        }
        return 0 if !$tag->{tagnameid};

        if ($hr->{globjid}) {
                $tag->{globjid} = $hr->{globjid};
        } else {
		$tag->{globjid} = $self->getGlobjidCreate($hr->{table}, $hr->{id});
        }
	return 0 if !$tag->{globjid};

	return $tag;
}

sub createTag {
	my($self, $hr, $options) = @_;

	my $tag = $self->_setuptag($hr);
	return 0 if !$tag;

	# I'm not sure why a duplicate or opposite tag would ever be "OK"
	# in the tags table, but for now let's keep our options open in
	# case there's some reason we'd want "raw" tag inserting ability.
	# Maybe in the future we can eliminate these options.
	my $check_dupe = (!$options || !$options->{dupe_ok});
	my $check_opp = (!$options || !$options->{opposite_ok});
	my $opp_tagnameid = 0;
	if ($check_opp) {
		my $opp_tagname = '';
		if ($hr->{name}) {
			$opp_tagname = $self->getOppositeTagname($hr->{name});
		} else {
			my $tagdata = $self->getTagDataFromId($tag->{tagnameid});
			$opp_tagname = $self->getOppositeTagname($tagdata->{tagname});
		}
		$opp_tagnameid = $self->getTagidFromNameIfExists($opp_tagname);
	}

	$self->sqlDo('SET AUTOCOMMIT=0');
	my $rows = $self->sqlInsert('tags', $tag);
	my $tagid = $rows ? $self->getLastInsertId() : 0;

	if ($rows && $check_dupe) {
		# Check to make sure this user hasn't already tagged
		# this object with this tagname.  We do this by, in
		# a transaction, doing the insert and checking to see
		# whether there are 1 or more rows in the table
		# preceding the one just inserted with matching the
		# criteria.  If so, the insert is rolled back and
		# 0 is returned.
		# Because of the uid_globjid_tagnameid_active index,
		# this should, I believe, not even touch table data,
		# so it should be very fast.
		my $count = $self->sqlCount('tags',
			"uid		= $tag->{uid}
			 AND globjid	= $tag->{globjid}
			 AND tagnameid	= $tag->{tagnameid}
			 AND inactivated IS NULL
			 AND tagid < $tagid");
		if ($count == 0) {
			# This is the only tag, it's allowed.
			# Continue processing.
		} else {
			# Duplicate tag, not allowed.
			$self->sqlDo('ROLLBACK');
			$rows = 0;
		}
	}

	# If that has succeeded so far, then eliminate any opposites
	# of this tag which may exist earlier in the table.
	if ($rows && $check_opp && $opp_tagnameid) {
		my $opp_tag = {
			uid =>		$tag->{uid},
			globjid =>	$tag->{globjid},
			tagnameid =>	$opp_tagnameid
		};
		my $count = $self->deactivateTag($opp_tag, { tagid_prior_to => $tagid });
		$rows = 0 if $count > 1;
	}

	# If it passed all the tests, commit it.
	if ($rows) {
		$self->sqlDo('COMMIT');
	}

	# Return AUTOCOMMIT to its original state in any case.
	$self->sqlDo('SET AUTOCOMMIT=1');

	return $rows ? $tagid : 0;
}

sub deactivateTag {
        my($self, $hr, $options) = @_;
	my $tag = $self->_setuptag($hr);
	return 0 if !$tag;
	my $prior_clause = '';
	$prior_clause = " AND tagid < $options->{tagid_prior_to}" if $options->{tagid_prior_to};
	my $where_clause = "uid		= $tag->{uid}
			 AND globjid	= $tag->{globjid}
			 AND tagnameid	= $tag->{tagnameid}
			 AND inactivated IS NULL
			 $prior_clause";
	my $previously_active_tagids = $self->sqlSelectColArrayref('tagid', 'tags', $where_clause);
	my $count = $self->sqlUpdate('tags', { -inactivated => 'NOW()' }, $where_clause);
	if ($count > 1) {
		# Logic error, there should never be more than one
		# tag meeting those criteria.
		warn scalar(gmtime) . " $count deactivated tags id '$tag->{tagnameid}' for uid=$tag->{uid} on $tag->{globjid}";
	}
	if ($count && $previously_active_tagids && @$previously_active_tagids) {
		my $tagboxdb = getObject('Slash::Tagbox');
		$tagboxdb->logDeactivatedTags($previously_active_tagids);
	}
	return $count;
}

# Given a tagname, create it if it does not already exist.
# Whether it had existed or not, return its id.  E.g. turn
# 'omglol' into '17241' (a possibly new, possibly old ID).
#
# This method assumes that the tag may already exist, and
# thus the first action it tries is looking up that tag.
# If the caller knows that the tag does not exist or is
# highly unlikely to exist, this method will be less
# efficient than createTagName.

sub getTagidCreate {
	my($self, $name) = @_;
	return 0 if !$self->tagnameSyntaxOK($name);
	my $reader = getObject('Slash::Tags', { db_type => 'reader' });
	my $id = $reader->getTagidFromNameIfExists($name);
	return $id if $id;
	return $self->createTagName($name);
}

# Given a tagname, create it if it does not already exist.
# Whether it had existed or not, return its id.  E.g. turn
# 'omglol' into '17241' (a possibly new, possibly old ID).
#
# This method assumes that the tag does not already exist,
# and thus the first action it tries is creating that tag.
# If it is likely or even possible that the tag does
# already exist, this method will be less efficient than
# getTagidCreate.

sub createTagName {
        my($self, $name) = @_;
	return 0 if !$self->tagnameSyntaxOK($name);
        my $rows = $self->sqlInsert('tagnames', {
                        tagnameid =>	undef,
                        tagname =>	$name,
                }, { ignore => 1 });
        if (!$rows) {
                # Insert failed, presumably because this tag already
                # exists.  The caller should have checked for this
                # before attempting to create the tag, but maybe the
                # reader that was checked didn't have this tag
                # replicated yet.  Pull the information directly
                # from this writer DB.
                return $self->getTagidFromNameIfExists($name);
        }
        # The insert succeeded.  Return the ID that was just added.
        return $self->getLastInsertId();
}

# Given a tagname, get its id, e.g. turn 'omglol' into '17241'.
# If no such tagname exists, do not create it;  return 0.

sub getTagidFromNameIfExists {
	my($self, $name) = @_;
	my $constants = getCurrentStatic();
	return 0 if !$self->tagnameSyntaxOK($name);

	my $table_cache         = "_tagid_cache";
	my $table_cache_time    = "_tagid_cache_time";
	$self->_genericCacheRefresh('tagid', $constants->{tags_cache_expire});
	if ($self->{$table_cache_time} && $self->{$table_cache}{$name}) {
		return $self->{$table_cache}{$name};
	}

	my $mcd = $self->getMCD();
	my $mcdkey = "$self->{_mcd_keyprefix}:tagid:" if $mcd;
	if ($mcd) {
		my $id = $mcd->get("$mcdkey$name");
		if ($id) {
			if ($self->{$table_cache_time}) {
				$self->{$table_cache}{$name} = $id;
			}
			return $id;
		}
	}
	my $name_q = $self->sqlQuote($name);
	my $id = $self->sqlSelect('tagnameid', 'tagnames',
		"tagname=$name_q");
	return 0 if !$id;
	if ($self->{$table_cache_time}) {
		$self->{$table_cache}{$name} = $id;
	}
        $mcd->set("$mcdkey$name", $id, $constants->{memcached_exptime_tags}) if $mcd;
        return $id;
}

# Given a tagid, set (or clear) (some of) its parameters.
# Returns 1 if anything was changed, 0 if not.
#
# Setting a parameter's value to either undef or the empty string
# will delete that parameter from the params table.

sub setTag {
	my($self, $id, $params) = @_;
	return 0 if !$id || !$params || !%$params;

	my $changed = 0;
	for my $key (sort keys %$params) {
		next if $key =~ /^(tagid|tagname|tagnameid|globjid|uid|created|at|inactivated)$/; # don't get to override these
		my $value = $params->{$key};
		if (defined($value) && length($value)) {
			$changed = 1 if $self->sqlReplace('tag_params', {
				tagid =>	$id,
				name =>		$key,
				value =>	$value,
			});
		} else {
			my $key_q = $self->sqlQuote($key);
			$changed = 1 if $self->sqlDelete('tag_params',
				"tagid = $id AND name = $key_q"
			);
		}
	}

	if ($changed) {
		my $mcd = $self->getMCD();
		my $mcdkey = "$self->{_mcd_keyprefix}:tagid:" if $mcd;
		if ($mcd) {
			# The "3" means "don't accept new writes
			# to this key for 3 seconds."
			$mcd->delete("$mcdkey$id", 3);
		}
	}

	return $changed;
}

# Given a tagnameid, set (or clear) (some of) its parameters.
# Returns 1 if anything was changed, 0 if not.
#
# Setting a parameter's value to either undef or the empty string
# will delete that parameter from the params table.

sub setTagname {
	my($self, $id, $params) = @_;
	return 0 if !$id || !$params || !%$params;

	my $changed = 0;
	for my $key (sort keys %$params) {
		next if $key =~ /^tagname(id)?$/; # don't get to override these
		my $value = $params->{$key};
		if (defined($value) && length($value)) {
			$changed = 1 if $self->sqlReplace('tagname_params', {
				tagnameid =>	$id,
				name =>		$key,
				value =>	$value,
			});
		} else {
			my $key_q = $self->sqlQuote($key);
			$changed = 1 if $self->sqlDelete('tagname_params',
				"tagnameid = $id AND name = $key_q"
			);
		}
	}

	if ($changed) {
		my $mcd = $self->getMCD();
		my $mcdkey = "$self->{_mcd_keyprefix}:tagdata:" if $mcd;
		if ($mcd) {
			# The "3" means "don't accept new writes
			# to this key for 3 seconds."
			$mcd->delete("$mcdkey$id", 3);
		}
	}

	return $changed;
}

# Given a tagnameid, get its name, e.g. turn '17241' into
# { tagname => 'omglol', tag_clout => '0.5' }.
# If no such tag ID exists, return undef.

sub getTagDataFromId {
	my($self, $id) = @_;
	my $constants = getCurrentStatic();

	my $table_cache         = "_tagname_cache";
	my $table_cache_time    = "_tagname_cache_time";
	$self->_genericCacheRefresh('tagname', $constants->{tags_cache_expire});
	if ($self->{$table_cache_time} && $self->{$table_cache}{$id}) {
		return $self->{$table_cache}{$id};
	}

        my $mcd = $self->getMCD();
        my $mcdkey = "$self->{_mcd_keyprefix}:tagdata:" if $mcd;
        if ($mcd) {
                my $data = $mcd->get("$mcdkey$id");
		if ($data) {
			if ($self->{$table_cache_time}) {
				$self->{$table_cache}{$id} = $data;
			}
			return $data;
		}
        }
        my $id_q = $self->sqlQuote($id);
	my $data = { };
        $data->{tagname} = $self->sqlSelect('tagname', 'tagnames',
                "tagnameid=$id_q");
        return undef if !$data->{tagname};
	my $params = $self->sqlSelectAllKeyValue('name, value', 'tagname_params',
                "tagnameid=$id_q");
	for my $key (keys %$params) {
		next if $key =~ /^tagname(id)?$/; # don't get to override these
		$data->{$key} = $params->{$key};
	}
	if ($self->{$table_cache_time}) {
		$self->{$table_cache}{$id} = $data;
	}
        $mcd->set("$mcdkey$id", $data, $constants->{memcached_exptime_tags}) if $mcd;
        return $data;
}

# Given a name and id, return the arrayref of all tags on that
# global object.  Options change which tags are returned:
#
# uid:			only tags created by that uid
# include_inactive:	inactivated tags will also be returned
# days_back:		only tags created in the past n days
# tagnameid:		only tags matching tagnameid as well as globjid
#
# The columns in the tags table are returned, plus two bonus
# fields: created_at_ut, the unix timestamp of the created_at
# column, and tagname, the text string for the tagnameid column.
#
# Note that tag_params are not returned:  see e.g.
# addCloutsToTagArrayref().

sub getTagsByNameAndIdArrayref {
	my($self, $name, $target_id, $options) = @_;
	my $globjid = $self->getGlobjidFromTargetIfExists($name, $target_id);
	return $self->getTagsByGlobjid($globjid, $options);
}

sub getTagsByGlobjid {
	my($self, $globjid, $options) = @_;
	return [ ] unless $globjid;

	my $uid_where = '';
	if ($options->{uid}) {
		my $uid_q = $self->sqlQuote($options->{uid});
		$uid_where = " AND uid=$uid_q";
	}
	my $inactivated_where = $options && $options->{include_inactive}
		? ''
		: ' AND inactivated IS NULL';

	my $days_where = $options && $options->{days_back}
		? " AND created_at >= DATE_SUB(NOW(), INTERVAL $options->{days_back} DAY)"
		: '';

	my $tagnameid_where = $options && $options->{tagnameid}
		? " AND tagnameid = $options->{tagnameid}"
		: '';

	my $ar = $self->sqlSelectAllHashrefArray(
		'*, UNIX_TIMESTAMP(created_at) AS created_at_ut',
		'tags',
		"globjid=$globjid $inactivated_where $uid_where $days_where $tagnameid_where",
		'ORDER BY tagid');

	# Now add an extra field to every element returned:  the
	# tagname, as well as tagnameid.
	$self->addTagnamesToHashrefArray($ar);
	return $ar;
}

# Given an arrayref of hashrefs representing tags, such as that
# returned by getTagsByNameAndIdArrayref, add three fields to each
# hashref:  tag_clout, tagname_clout, user_clout.  Values default
# to 1.  "Rounded" means round to 3 decimal places.

sub addRoundedCloutsToTagArrayref {
	my($self, $ar) = @_;
	$self->addCloutsToTagArrayref($ar);
	for my $tag_hr (@$ar) {
		$tag_hr->{tag_clout}     = sprintf("%.3g", $tag_hr->{tag_clout});
		$tag_hr->{tagname_clout} = sprintf("%.3g", $tag_hr->{tagname_clout});
		$tag_hr->{user_clout}    = sprintf("%.3g", $tag_hr->{user_clout});
		$tag_hr->{total_clout}   = sprintf("%.3g", $tag_hr->{total_clout});
	}
}

sub addCloutsToTagArrayref {
	my($self, $ar) = @_;

	return if !$ar || !@$ar;

	# Pull values from tag params named 'tag_clout'
	my @tagids = sort { $a <=> $b } map { $_->{tagid} } @$ar;
	my $tagids_in_str = join(',', @tagids);
	my $tag_clout_hr = $self->sqlSelectAllKeyValue(
		'tagid, value', 'tag_params',
		"tagid IN ($tagids_in_str) AND name='tag_clout'");

	# Pull values from tagname params named 'tag_clout'
	my %tagnameid = map { ($_->{tagnameid}, 1) } @$ar;
	my @tagnameids = sort { $a <=> $b } keys %tagnameid;
	my $tagnameids_in_str = join(',', @tagnameids);
	my $tagname_clout_hr = $self->sqlSelectAllKeyValue(
		'tagnameid, value', 'tagname_params',
		"tagnameid IN ($tagnameids_in_str) AND name='tag_clout'");

	# Pull values from users_info.tag_clout
	my %uid = map { ($_->{uid}, 1) } @$ar;
	my @uids = sort { $a <=> $b } keys %uid;
	my $uids_in_str = join(',', @uids);
	my $uid_info_hr = $self->sqlSelectAllHashref(
		'uid',
		'users.uid AS uid, seclev, karma, tag_clout',
		'users, users_info',
		"users.uid=users_info.uid AND users.uid IN ($uids_in_str)");
	my $uid_clout_hr = { };
	# XXX hardcoded formula, this should be parameterized at least with vars
	for my $uid (keys %$uid_info_hr) {
		$uid_clout_hr->{$uid} = $uid_info_hr->{$uid}{karma} >= -3 ? log($uid_info_hr->{$uid}{karma}+10) : 0;
		$uid_clout_hr->{$uid} += 5 if $uid_info_hr->{$uid}{seclev} > 1;
		$uid_clout_hr->{$uid} *= $uid_info_hr->{$uid}{tag_clout};
	}

	for my $tag_hr (@$ar) {
		$tag_hr->{tag_clout}     = defined($tag_clout_hr    ->{$tag_hr->{tagid}})
						 ? $tag_clout_hr    ->{$tag_hr->{tagid}}
						 : 1;
		$tag_hr->{tagname_clout} = defined($tagname_clout_hr->{$tag_hr->{tagnameid}})
						 ? $tagname_clout_hr->{$tag_hr->{tagnameid}}
						 : 1;
		$tag_hr->{user_clout}    =	   $uid_clout_hr    ->{$tag_hr->{uid}};
		$tag_hr->{total_clout} = $tag_hr->{tag_clout} * $tag_hr->{tagname_clout} * $tag_hr->{user_clout};
	}
}

sub getAllTagsFromUser {
	my($self, $uid, $options) = @_;
	$options ||= {};
	return [ ] unless $uid;

	my $bookmark = getObject("Slash::Bookmark");

	my $orderby = $options->{orderby} || "tagid";
	my $limit   = $options->{limit} ? " LIMIT $options->{limit} " : "";
	my $orderdir = uc($options->{orderdir}) eq "DESC" ? "DESC" : "ASC";
	my $inact_clause = $options->{include_inactive} ? '' : ' AND inactivated IS NULL';

	my($table_extra, $where_extra) = ("","");

	if ($options->{type}) {
		my $globjtypes = $self->getGlobjTypes;
		my $id = $globjtypes->{$options->{type}};
		if ($id) {
			$table_extra .= ",globjs";
			my $id_q = $self->sqlQuote($id);
			$where_extra .= " AND globjs.globjid = tags.globjid AND globjs.gtid=$id_q ";
		}

		if ($options->{type} eq "urls" and $options->{only_bookmarked}) {
			$table_extra .= ", bookmarks",
			$where_extra .= " AND bookmarks.url_id = globjs.target_id";
		}
	}

	my $type_clause = "";
	my $uid_q = $self->sqlQuote($uid);
	my $ar = $self->sqlSelectAllHashrefArray(
		'tags.*',
		"tags $table_extra",
		"tags.uid = $uid_q $inact_clause $where_extra",
		"ORDER BY $orderby $orderdir $limit");
	return [ ] unless $ar && @$ar;
	$self->addTagnamesToHashrefArray($ar);
	$self->addGlobjTargetsToHashrefArray($ar);
	for my $hr (@$ar) {
		if ($hr->{globj_type} eq 'stories') {
			$hr->{story} = $self->getStory($hr->{globj_target_id});
		} elsif ($hr->{globj_type} eq 'urls') {
			$hr->{url} = $self->getUrl($hr->{globj_target_id});
			if ($bookmark) {
				$hr->{url}{bookmark} = $bookmark->getUserBookmarkByUrlId($uid, $hr->{url}{url_id});
			}
		
		}
	}
	return $ar;
}

sub getGroupedTagsFromUser {
	my($self, $uid, $options) = @_;
	my $all_ar = $self->getAllTagsFromUser($uid, $options);
	return { } unless $all_ar && @$all_ar;

	my %grouped = ( );
	my %tagnames = ( map { ($_->{tagname}, 1) } @$all_ar );
	for my $tagname (sort keys %tagnames) {
		$grouped{$tagname} ||= [ ];
		push @{$grouped{$tagname}},
			grep { $_->{tagname} eq $tagname }
			@$all_ar;
	}
	return \%grouped;
}

sub addTagnamesToHashrefArray {
	my($self, $ar) = @_;
	my %tagnameids = (
		map { ( $_->{tagnameid}, 1 ) }
		@$ar
	);
	# XXX This could/should be done more efficiently;  we need a
	# getTagDataFromIds method to do this in bulk and take
	# advantage of get_multi and put all the sqlSelects together.
	my %tagdata = (
		map { ( $_, $self->getTagDataFromId($_) ) }
		keys %tagnameids
	);
	for my $hr (@$ar) {
		my $id = $hr->{tagnameid};
		my $d = $tagdata{$id};
		for my $key (keys %$d) {
			$hr->{$key} = $d->{$key};
		}
	}
}

sub getUidsUsingTagname {
	my($self, $name) = @_;
	my $id = $self->getTagidFromNameIfExists($name);
	return [ ] if !$id;
	return $self->sqlSelectColArrayref('DISTINCT(uid)', 'tags',
		"tagnameid=$id AND inactivated IS NULL");
}

sub getAllObjectsTagname {
	my($self, $name) = @_;
	my $id = $self->getTagidFromNameIfExists($name);
	return [ ] if !$id;
	my $hr_ar = $self->sqlSelectAllHashrefArray(
		'*',
		'tags',
		"tagnameid=$id AND inactivated IS NULL",
		'ORDER BY tagid');
	$self->addGlobjEssentialsToHashrefArray($hr_ar);
	return $hr_ar;
}

sub getTagnameParams {
	my($self, $tagnameid) = @_;
	return $self->sqlSelectAllKeyValue('name, value', 'tagname_params',
		"tagnameid=$tagnameid");
}

sub getTagnameAdmincmds {
	my($self, $tagnameid) = @_;
	return [ ] if !$tagnameid;
	return $self->sqlSelectAllHashrefArray(
		"tagnameid, IF(globjid IS NULL, 'all', globjid) AS globjid,
		 cmdtype, created_at,
		 UNIX_TIMESTAMP(created_at) AS created_at_ut",
		'tagcommand_adminlog',
		"tagnameid=$tagnameid");
}

sub getExampleTagsForStory {
	my($self, $story) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $cur_time = $slashdb->getTime();
	my @examples = split / /,
		($cur_time lt $story->{time})
		? $constants->{tags_stories_examples_pre}
		: $constants->{tags_stories_examples};
	my $chosen_ar = $self->getTopiclistForStory($story->{stoid});
	$#$chosen_ar = 3 if $#$chosen_ar > 3;
	my $tree = $self->getTopicTree();
	push @examples,
		grep { $self->tagnameSyntaxOK($_) }
		map { $tree->{$_}{keyword} }
		@$chosen_ar;
	return @examples;
}

sub removeTagnameFromIndexTop {
	my($self, $tagname) = @_;
	my $tagid = $self->getTagidCreate($tagname);
	return 0 if !$tagid;

	my $changes = $self->setTagname($tagname, { noshow_index => 1 });
	return 0 if !$changes;

	# The tagname wasn't on the noshow_index list and now it is.
	# Force tags_update.pl to rebuild starting from the first use
	# of this tagname.
	my $min_tagid = $self->sqlSelect('MIN(tagid)', 'tags',
		"tagnameid=$tagid");
	$self->setLastscanned($min_tagid);
	return 1;
}

sub tagnameSyntaxOK {
	my($self, $tagname) = @_;
	return 0 unless defined($tagname) && length($tagname) > 0;
	my $constants = getCurrentStatic();
	my $regex = $constants->{tags_tagname_regex};
	return($tagname =~ /$regex/);
}

sub adminPseudotagnameSyntaxOK {
	my($self, $command) = @_;
	my($type, $tagname) = $self->getTypeAndTagnameFromAdminCommand($command);
	return 0 if !$type;
	return $self->tagnameSyntaxOK($tagname);
}

sub ajaxGetUserStory {
	my($self, $constants, $user, $form) = @_;

	my $sidenc = $form->{sidenc};
	my $sid = $sidenc; $sid =~ tr{:}{/};
	my $stoid = $self->getStoidFromSid($sid);
	my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });
#print STDERR scalar(localtime) . " ajaxGetUserStory for stoid=$stoid sidenc=$sidenc tr=$tags_reader\n";
	if (!$stoid || $stoid !~ /^\d+$/ || $user->{is_anon} || !$tags_reader) {
		return getData('error', {}, 'tags');
	}
	my $uid = $user->{uid};

	my $tags_ar = $tags_reader->getTagsByNameAndIdArrayref('stories', $stoid, { uid => $uid });
	my @tags = sort tagnameorder map { $_->{tagname} } @$tags_ar;
#print STDERR scalar(localtime) . " ajaxGetUserStory for stoid=$stoid uid=$uid tags: '@tags' tags_ar: " . Dumper($tags_ar);

	my @newtagspreload = @tags;
	push @newtagspreload,
		grep { $tags_reader->tagnameSyntaxOK($_) }
		split /[\s,]+/,
		($form->{newtagspreloadtext} || '');
	my $newtagspreloadtext = join ' ', @newtagspreload;

	return slashDisplay('tagsstorydivuser', {
		sidenc =>		$sidenc,
		newtagspreloadtext =>	$newtagspreloadtext,
	}, { Return => 1 });
}

sub ajaxGetUserUrls {
	my($self, $constants, $user, $form) = @_;

	my $id = $form->{id};
	my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });
#print STDERR scalar(localtime) . " ajaxGetUserUrls for url_id=$id tr=$tags_reader\n";
	if (!$id || $id !~ /^\d+$/ || $user->{is_anon} || !$tags_reader) {
		return getData('error', {}, 'tags');
	}
	my $uid = $user->{uid};

	my $tags_ar = $tags_reader->getTagsByNameAndIdArrayref('urls', $id, { uid => $uid });
	my @tags = sort map { $_->{tagname} } @$tags_ar;
#print STDERR scalar(localtime) . " ajaxGetUserStory for stoid=$stoid uid=$uid tags: '@tags' tags_ar: " . Dumper($tags_ar);

	my @newtagspreload = @tags;
	push @newtagspreload,
		grep { $tags_reader->tagnameSyntaxOK($_) }
		split /[\s,]+/,
		($form->{newtagspreloadtext} || '');
	my $newtagspreloadtext = join ' ', @newtagspreload;

	return slashDisplay('tagsurldivuser', {
		id =>		$id,
		newtagspreloadtext =>	$newtagspreloadtext,
	}, { Return => 1 });
}


sub ajaxGetAdminStory {
	my($slashdb, $constants, $user, $form) = @_;
	my $sidenc = $form->{sidenc};
	my $sid = $sidenc; $sid =~ tr{:}{/};

	if (!$sid || $sid !~ regexSid() || !$user->{is_admin}) {
		return getData('error', {}, 'tags');
	}

	return slashDisplay('tagsstorydivadmin', {
		sidenc =>		$sidenc,
		tags_admin_str =>	'',
	}, { Return => 1 });
}

sub ajaxGetAdminUrl {
	my($slashdb, $constants, $user, $form) = @_;
	my $id = $form->{id};
	if (!$id || !$user->{is_admin}) {
		return getData('error', {}, 'tags');
	}

	return slashDisplay('tagsurldivadmin', {
		id =>		$id,
		tags_admin_str =>	'',
	}, { Return => 1 });
}

#  XXX based off of ajaxCreateStory.  ajaxCreateStory should be updated to use this or something
#  similar soon, and after I've had time to test -- vroom 2006/03/21
sub setTagsForGlobj {
	my($self, $id, $table, $tag_string, $options) = @_;
	my $tags = getObject('Slash::Tags');
	$options ||= {};
	
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	
	my %new_tagnames =
		map { ($_, 1) }
		grep { $tags->tagnameSyntaxOK($_) }
		map { lc }
		split /[\s,]+/,
		($tag_string || $form->{tags} || '');
	my %new_tagnames_opposites = map { $tags->getOppositeTagname($_), 1 } keys %new_tagnames;

	my $uid = $options->{uid} || $user->{uid};
	my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });
	my $old_tags_ar = $tags_reader->getTagsByNameAndIdArrayref($table, $id, { uid => $uid });
	my %old_tagnames = ( map { ($_->{tagname}, 1) } @$old_tags_ar );

	# Create any tag specified but only if it does not already exist
	# and only if its opposite was not also specified (user can't
	# tag both "funny" and "!funny" at the same time).
	my @create_tagnames =		grep { !$old_tagnames{$_} && !$new_tagnames_opposites{$_} }
					sort keys %new_tagnames;
	# Deactivate any tag which existed before but either (a) is not
	# specified now or (b) the opposite of which is specified now.
	# (Actually, createTag() will automatically deactivate the
	# opposite of any tag specified, but it doesn't hurt to make a
	# pass through first.)
	my @deactivate_tagnames = (    (grep { !$new_tagnames{$_} } sort keys %old_tagnames),
				       (grep {  $old_tagnames{$_} } sort keys %new_tagnames_opposites) );

	my @deactivated_tagnames = ( );
	for my $tagname (@deactivate_tagnames) {
		push @deactivated_tagnames, $tagname
			if $tags->deactivateTag({
				uid =>		$uid,
				name =>		$tagname,
				table =>	$table,
				id =>		$id
			});
	}

	my @created_tagnames = ( );
	for my $tagname (@create_tagnames) {
		push @created_tagnames, $tagname
			if $tags->createTag({
				uid =>          $uid,
				name =>         $tagname,
				table =>        $table,
				id =>           $id
			});
	}
#print STDERR scalar(localtime) . " setTagsForGlobj $table : $id  3 old='@$old_tags_ar' created='@created_tagnames'\n";

	my $now_tags_ar = $tags->getTagsByNameAndIdArrayref($table, $id, { uid => $uid });
	my $newtagspreloadtext = join ' ', sort map { $_->{tagname} } @$now_tags_ar;

}

sub ajaxCreateForUrl {
	my($slashdb, $constants, $user, $form) = @_;
	my $id = $form->{id};
	my $tagsstring = $form->{tags};
	my $tags = getObject('Slash::Tags');
	my $newtagspreloadtext = $tags->setTagsForGlobj($id, "urls", $tagsstring);

	my $retval = slashDisplay('tagsurldivuser', {
		id => $id,
		newtagspreloadtext => $newtagspreloadtext,
	}, { Return => 1}
	);
	return $retval;
}

sub ajaxCreateForStory {
	my($slashdb, $constants, $user, $form) = @_;
	my $sidenc = $form->{sidenc};
	my $sid = $sidenc; $sid =~ tr{:}{/};
	my $tags = getObject('Slash::Tags');
	my $tagsstring = $form->{tags};
	if (!$sid || $sid !~ regexSid() || $user->{is_anon} || !$tags) {
		return getData('error', {}, 'tags');
	}
	my $stoid = $slashdb->getStoidFromSid($sid);
	if (!$stoid) {
		return getData('error', {}, 'tags');
	}
	
	my $newtagspreloadtext = $tags->setTagsForGlobj($stoid, "stories", $tagsstring);
	
	my $retval = slashDisplay('tagsstorydivuser', {
		sidenc =>		$sidenc,
		newtagspreloadtext =>	$newtagspreloadtext,
	}, { Return => 1 });
#print STDERR scalar(localtime) . " ajaxCreateForStory 4 for stoid=$stoid tagnames='@tagnames' newtagspreloadtext='$newtagspreloadtext' returning: $retval\n";
	return $retval;
}

sub ajaxProcessAdminTags {
	my($slashdb, $constants, $user, $form) = @_;
#print STDERR "ajaxProcessAdminTags\n";
	my $commands = $form->{commands};
	my $type = $form->{type} || "stories";
	my($id, $table, $sid, $sidenc);
	if ($type eq "stories") {
		$sidenc = $form->{sidenc};
		$sid = $sidenc; $sid =~ tr{:}{/};
		$id = $slashdb->getStoidFromSid($sid);
		$table = "stories";
	} elsif ($type eq "urls") {
		$table = "urls";
		$id = $form->{id};
	}
	
	my $tags = getObject('Slash::Tags');
	my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });
	my @commands =
		grep { $tags->adminPseudotagnameSyntaxOK($_) }
		split /[\s,]+/,
		($commands || '');
use Data::Dumper; print STDERR scalar(localtime) . " ajaxProcessAdminTags table=$table id=$id sid=$sid commands='$commands' commands='@commands' tags='$tags' form: " . Dumper($form);
	if (!$id || !$table || !@commands) {
		# Error, but we really have no way to return it...
		# return getData('tags_none_given', {}, 'tags');
	}

	my @tagnameids_affected = ( );
	for my $c (@commands) {
		my $tagnameid = $tags->processAdminCommand($c, $id, $table);
		push @tagnameids_affected, $tagnameid if $tagnameid;
	}
	if (@tagnameids_affected) {
		my $affected_str = join(',', @tagnameids_affected);
		my $reset_lastscanned = $tags->sqlSelect(
			'MIN(tagid)',
			'tags',
			"tagnameid IN ($affected_str)");
		$tags->setLastscanned($reset_lastscanned);
#print STDERR scalar(localtime) . " ajaxProcessAdminTags reset to " . ($reset_lastscanned-1) . " for '$affected_str'\n";
	}

	my $tags_admin_str = "Performed commands: '@commands'.";
	if ($type eq "stories") {
		return slashDisplay('tagsstorydivadmin', {
			sidenc =>		$sidenc,
			tags_admin_str =>	$tags_admin_str,
		}, { Return => 1 });
	} elsif ($type eq "urls") {
		return slashDisplay('tagsurldivadmin', {
			id 		=>	$id,
			tags_admin_str  =>	$tags_admin_str,
		}, { Return => 1 });
	}
}

sub ajaxTagHistory {
	my($slashdb, $constants, $user, $form) = @_;
	my $id;
	my $table;
	if ($form->{type} eq "stories") {
		my $sidenc = $form->{sidenc};
		my $sid = $sidenc; $sid =~ tr{:}{/};
		$id = $slashdb->getStoidFromSid($sid);
		$table = "stories"
	} elsif ($form->{type} eq "urls") {
		$table = "urls";	
	}
	$id ||= $form->{id};

	
	my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });
	my $tags_ar = [];
	$tags_ar = $tags_reader->getTagsByNameAndIdArrayref($table, $id, { include_inactive => 1 }) if $table && $id;
	$tags_reader->addRoundedCloutsToTagArrayref($tags_ar);
	slashDisplay('taghistory', { tags => $tags_ar }, { Return => 1 } );
}

{ # closure
my @clout_reduc_map = qw(  0.15  0.50  0.90  0.99  1.00  );
sub processAdminCommand {
	my($self, $c, $id, $table) = @_;

	my($type, $tagname) = $self->getTypeAndTagnameFromAdminCommand($c);
	return 0 if !$type;

	my $constants = getCurrentStatic();
	my $tagnameid = $self->getTagidCreate($tagname);

	my $systemwide = $type =~ /^\$/ ? 1 : 0;
	my $globjid = $systemwide ? undef : $self->getGlobjidCreate($table, $id);
	my $hashmark_count = $type =~ s/\#/\#/g;
	my $user_clout_reduction = $clout_reduc_map[$hashmark_count];
	$user_clout_reduction = 1 if $user_clout_reduction > 1;
	# Eventually we need to define FLOATs for clout and multiply
	# them together, but for now it's an overwrite.
	my $new_user_clout = 1-$user_clout_reduction;

	my $new_min_tagid = 0;

#print STDERR "type '$type' for c '$c' new_clout '$new_user_clout' for table $table id $id\n";
	if ($type eq '^') {
		# Set individual clouts to 0 for tags of this name on
		# this story that have already been applied.  Future
		# tags of this name on this story will apply with
		# their full clout.
		my $tags_ar = $self->getTagsByNameAndIdArrayref($table, $id);
		my @tags = grep { $_->{tagnameid} == $tagnameid } @$tags_ar;
#print STDERR "tags_ar '@$tags_ar' tags '@tags'\n";
		for my $tag (@tags) {
#print STDERR "setting $tag->{tagid} to 0\n";
			$self->setTag($tag->{tagid}, { tag_clout => 0 });
		}
	} else {
		if ($systemwide) {
			$self->setTagname($tagnameid, { tag_clout => 0 });
			$new_min_tagid = $self->sqlSelect('MIN(tagid)', 'tags',
				"tagnameid=$tagnameid");
			if ($new_user_clout < 1) {
				my $uids = $self->sqlSelectColArrayref('uid', 'tags',
					"tagnameid=$tagnameid AND inactivated IS NULL");
				if (@$uids) {
					my @uids_changed = ( );
					for my $uid (@$uids) {
						push @uids_changed, $uid
							if $self->setUser($uid, {
								-tag_clout => "LEAST(tag_clout, $new_user_clout)"
							});
					}
					my $uids_str = join(',', @uids_changed);
					my $user_min = $self->sqlSelect('MIN(tagid)', 'tags',
						"uid IN ($uids_str)");
					$new_min_tagid = $user_min if $user_min < $new_min_tagid;
				}
			}
		} else {
			# Just logging the command is enough to affect future tags
			# applied to this story (that's the way we're doing it now,
			# though I'm not really happy with this and it will
			# probably change).
			my $tags_ar = $self->getTagsByNameAndIdArrayref($table, $id);
			my @tags = grep { $_->{tagnameid} == $tagnameid } @$tags_ar;
			for my $tag (@tags) {
				$self->setTag($tag->{tagid}, { tag_clout => 0 });
			}
			$new_min_tagid = $self->sqlSelect('MIN(tagid)', 'tags',
				"tagnameid=$tagnameid AND globjid=$globjid");
			if ($new_user_clout < 1) {
				my $uids = $self->sqlSelectColArrayref('uid', 'tags',
					"tagnameid=$tagnameid AND inactivated IS NULL
					 AND globjid=$globjid");
				if (@$uids) {
					my @uids_changed = ( );
					for my $uid (@$uids) {
						push @uids_changed, $uid
							if $self->setUser($uid, {
								-tag_clout => "LEAST(tag_clout, $new_user_clout)"
							});
					}
					my $uids_str = join(',', @uids_changed);
					my $user_min = $self->sqlSelect('MIN(tagid)', 'tags',
						"uid IN ($uids_str)");
					$new_min_tagid = $user_min if $user_min < $new_min_tagid;
				}
			}
		}
	}

	$self->logAdminCommand($type, $tagname, $globjid);

	$self->setLastscanned($new_min_tagid);

	return $tagnameid;
}
} # closure

sub getTypeAndTagnameFromAdminCommand {
	my($self, $c) = @_;
	my($type, $tagname) = $c =~ /^(\^|\$?\_|\$?\#{1,5})(.+)$/;
#print STDERR scalar(gmtime) . " get c '$c' type='$type' tagname='$tagname'\n";
	return (undef, undef) if !$type || !$self->tagnameSyntaxOK($tagname);
	return($type, $tagname);
}

# $globjid should be the globjid specifically affected, or
# omitted (or false) when the type indicates a system-wide
# command.
sub logAdminCommand {
	my($self, $type, $tagname, $globjid) = @_;
	my $tagnameid = $self->getTagidFromNameIfExists($tagname);
	$self->sqlInsert('tagcommand_adminlog', {
		cmdtype =>	$type,
		tagnameid =>	$tagnameid,
		globjid =>	$globjid || undef,
		adminuid =>	getCurrentUser('uid'),
		-created_at =>	'NOW()',
	});
}

sub getOppositeTagname {
	my($self, $tagname) = @_;
	return substr($tagname, 0, 1) eq '!' ? substr($tagname, 1) : '!' . $tagname;
}

sub setLastscanned {
	my($self, $new_val) = @_;
	return if !$new_val;
	my $old_val = $self->sqlSelect('value', 'vars',
		"name='tags_stories_lastscanned'");
	return if $new_val > $old_val;
	$self->setVar('tags_stories_lastscanned', $new_val - 1);
}

sub listTagnamesAll {
	my($self, $options) = @_;
	my $tagname_ar;
	if ($options->{really_all}) {
		$tagname_ar = $self->sqlSelectColArrayref('tagname', 'tagnames',
			'',
			'ORDER BY tagname');
	} else {
		$tagname_ar = $self->sqlSelectColArrayref('tagname',
			"tagnames LEFT JOIN tagname_params
				ON (tagnames.tagnameid=tagname_params.tagnameid AND tagname_params.name='tag_clout')",
			'value IS NULL OR value > 0',
			'ORDER BY tagname');
	}
	@$tagname_ar = sort tagnameorder @$tagname_ar;
	return $tagname_ar;
}

sub listTagnamesActive {
	my($self, $seconds, $max_num) = @_;
	my $constants = getCurrentStatic();
	$max_num ||= 100;
	$seconds ||= 3600 * 6;
#print STDERR scalar(localtime) . " listTagnamesActive s=$seconds m=$max_num\n";
	# This seems like a horrendous query, but I _think_ it will run
	# in acceptable time, even under fairly heavy load.
	# Round off time to the last minute.
	my $the_time = $self->getTime({ unix_format => 1 });
	substr($the_time, -2) = '00';
	my $next_minute_q = $self->sqlQuote( time2str( '%Y-%m-%d %H:%M:00', $the_time + 60, 'GMT') );
	my $ar = $self->sqlSelectAllHashrefArray(
		"tagnames.tagname AS tagname,
		 UNIX_TIMESTAMP($next_minute_q) - UNIX_TIMESTAMP(tags.created_at) AS secsago,
		 karma,
		 IF(tagname_params.value IS NULL, 1, tagname_params.value) AS tnp_clout,
		 IF(tag_params.value     IS NULL, 1, tag_params.value)     AS tp_clout,
		 users_info.tag_clout AS user_clout",
		"users_info,
		 tags LEFT JOIN tag_params
		 	ON (tags.tagid=tag_params.tagid AND tag_params.name='tag_clout'),
		 tagnames LEFT JOIN tagname_params
			ON (tagnames.tagnameid=tagname_params.tagnameid AND tagname_params.name='tag_clout')",
		"tagnames.tagnameid=tags.tagnameid
		 AND tags.uid=users_info.uid
		 AND inactivated IS NULL
		 AND tags.created_at >= DATE_SUB($next_minute_q, INTERVAL $seconds SECOND)");
	return [ ] unless $ar && @$ar;

	# Sum up the clout for each tagname, and the median time it
	# was seen within the interval in question.
	# Very crude weighting algorithm that will change.
	my %tagname_count = ( );
	my %tagname_clout = ( );
	my %tagname_sumsqrtsecsago = ( );
	for my $hr (@$ar) {
		my $tagname = $hr->{tagname};
		# Tally it.
		$tagname_count{$tagname} ||= 0;
		$tagname_count{$tagname}++;
		# Add to its clout.
		my $user_clout = $hr->{user_clout} * ($hr->{karma} >= -3 ? log($hr->{karma}+10) : 0);
		my $clout = $user_clout * $hr->{tp_clout} * $hr->{tnp_clout};
		$tagname_clout{$tagname} ||= 0;
		$tagname_clout{$tagname} += $clout;
		# Adjust up its last seen time.
		$tagname_sumsqrtsecsago{$tagname} ||= 0;
		my $secsago = $hr->{secsago};
		$secsago = 0 if $secsago < 0;
		$tagname_sumsqrtsecsago{$tagname} += $secsago ** 0.5;
	}
	# Go by the square root of "seconds ago" so that a tag's
	# vector length will be less likely to _increase_ when old
	# entries drop off.
	my $max_sqrtsecs = $seconds ** 0.5;
	my %tagname_mediansqrtsecsago = ( );
	for my $tagname (keys %tagname_sumsqrtsecsago) {
		$tagname_mediansqrtsecsago{$tagname} = $tagname_sumsqrtsecsago{$tagname} / $tagname_count{$tagname};
	}

	# For now, do NOT make opposite tagnames counteract.  We'll
	# see if we want to do that in future.

	# Determine what the maximum clout is.
	my $max_clout = 0;
	for my $tagname (keys %tagname_clout) {
		$max_clout = $tagname_clout{$tagname} if $tagname_clout{$tagname} > $max_clout;
	}

	# List all tags with at least a minimum clout.
	my @tagnames = grep
		{ $tagname_clout{$_} >= $constants->{tags_stories_top_minscore} }
		keys %tagname_clout;

	# Sort by sum of normalized clout and (opposite of) last-seen time.
	my %tagname_sum = (
			map
			{ ($_, $tagname_clout{$_}/$max_clout - $tagname_mediansqrtsecsago{$_}/$max_sqrtsecs) }
			@tagnames
		);
#use Data::Dumper; print STDERR Dumper(\%tagname_sum);
	@tagnames = sort { $tagname_sum{$b} <=> $tagname_sum{$a} || $a cmp $b } @tagnames;

	$#tagnames = $max_num-1 if $#tagnames >= $max_num;

#print STDERR "tagnames='@tagnames'\n";

	return \@tagnames;
}

sub listTagnamesRecent {
	my($self, $seconds) = @_;
	my $recent_ar = $self->sqlSelectColArrayref(
		'DISTINCT tagnames.tagname',
		"users_info,
		 tags LEFT JOIN tag_params
		 	ON (tags.tagid=tag_params.tagid AND tag_params.name='tag_clout'),
		 tagnames LEFT JOIN tagname_params
			ON (tagnames.tagnameid=tagname_params.tagnameid AND tagname_params.name='tag_clout')",
		"tagnames.tagnameid=tags.tagnameid
		 AND inactivated IS NULL
		 AND tags.created_at >= DATE_SUB(NOW(), INTERVAL $seconds SECOND)
		 AND (tag_params.value IS NULL OR tag_params.value > 0)
		 AND (tagname_params.value IS NULL OR tagname_params.value > 0)
		 AND tags.uid=users_info.uid AND users_info.tag_clout > 0",
		'ORDER BY tagnames.tagname'
	);
	@$recent_ar = sort tagnameorder @$recent_ar;
	return $recent_ar;
}

# a sort order utility function
sub tagnameorder {
	my($a1, $a2) = $a =~ /(^\!)?(.*)/;
	my($b1, $b2) = $b =~ /(^\!)?(.*)/;
	$a2 cmp $b2 || $a1 cmp $b1;
}

#################################################################
sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if $self->{_dbh} && !$ENV{GATEWAY_INTERFACE};
}

1;

=head1 NAME

Slash::Tags - Slash Tags module

=head1 SYNOPSIS

	use Slash::Tags;

=head1 DESCRIPTION

This contains all of the routines currently used by Tags.

=head1 SEE ALSO

Slash(3).

=cut

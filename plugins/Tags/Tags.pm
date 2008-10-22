# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Tags;

use strict;
use Apache::Cookie;
use Date::Format qw( time2str );
use Slash;
use Slash::Display;
use Slash::Utility;

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

# FRY: And where would a giant nerd be? THE LIBRARY!

########################################################

# createTag's first argument is a hashref with four sets of
# named arguments, one of which is optional.
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
# The fourth is optional and defaults to false:
# 	private		If true, the created tag is private.
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
# 'opposite_ok' ignores that check.  The 'no_adminlog_check' field
# means to not scan tagcommand_adminlog to determine whether the
# tag should be created with an altered tag_clout param.  At the
# moment we can't think of a good reason why one would ever want
# to ignore those checks but the options are there regardless.  Is
# this good design?  Probably not.
#
# Note that there is no way to switch a tag from being public to being
# private except by deactivating and recreating it;  this is by design.
# (And at present there's no way to switch a tag from private to
# public, either -- that's by laziness.)
# Note incidentally both private and public tags will deactivate their
# opposites, whether the opposites are private or public;  the
# consequences of this may or may not be obvious I suppose.

sub _setuptag {
	my($self, $hr, $options) = @_;
	my $tag = { -created_at => 'NOW()' };

	$tag->{uid} = $hr->{uid} || getCurrentUser('uid');

	if ($hr->{tagnameid}) {
		$tag->{tagnameid} = $hr->{tagnameid};
	} else {
		# Need to determine tagnameid from name.  We
		# create the new tag name if necessary.
		$tag->{tagnameid} = $self->getTagnameidCreate($hr->{name});
	}
	return 0 if !$options->{tagname_not_required} && !$tag->{tagnameid};

	if ($hr->{globjid}) {
		$tag->{globjid} = $hr->{globjid};
	} else {
		$tag->{globjid} = $self->getGlobjidCreate($hr->{table}, $hr->{id});
	}
	return 0 if !$tag->{globjid};

	$tag->{private} = $hr->{private} ? 'yes' : 'no';

	return $tag;
}

sub createTag {
	my($self, $hr, $options) = @_;

	my $tag = $self->_setuptag($hr);
	return 0 if !$tag;

	# Anonymous users cannot tag.
	return 0 if isAnon($tag->{uid});

	# I'm not sure why a duplicate or opposite tag would ever be "OK"
	# in the tags table, but for now let's keep our options open in
	# case there's some reason we'd want "raw" tag inserting ability.
	# Maybe in the future we can eliminate these options.
	my $check_dupe = (!$options || !$options->{dupe_ok});
	my $check_opp = (!$options || !$options->{opposite_ok});
	my $check_aclog = (!$options || !$options->{no_adminlog_check});
	my $opp_tagnameids = [ ];
	if ($check_opp) {
		$opp_tagnameids = $self->getOppositeTagnameids($tag->{tagnameid});
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
		# Because of the uid_globjid_tagnameid_inactivated index,
		# this should, I believe, not even touch table data,
		# so it should be very fast.
		# XXX Might want to make it faster by doing this
		# select before the insert above, esp. with tagViewed().
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
	# of this tag which may have already been created.
	if ($rows && $check_opp && @$opp_tagnameids) {
		for my $opp_tagnameid (@$opp_tagnameids) {
			my $opp_tag = {
				uid =>		$tag->{uid},
				globjid =>	$tag->{globjid},
				tagnameid =>	$opp_tagnameid
			};
			my $count = $self->deactivateTag($opp_tag, { tagid_prior_to => $tagid });
			$rows = 0 if $count > 1; # values > 1 indicate a logic error
		}
	}

	# If all that was successful, add a tag_clout param if
	# necessary.
	if ($rows) {
		# Find any admin commands that set clout for this tagnameid.
		# We look for this globjid specifically, because any
		# commands for the tagnameid generally will already have
		# a tag_clout in tagname_params.
		my $admincmds_ar = $self->getTagnameAdmincmds(
			$tag->{tagnameid}, $tag->{globjid});
		for my $opp_tagnameid (@$opp_tagnameids) {
			my $opp_ar = $self->getTagnameAdmincmds(
				$opp_tagnameid, $tag->{globjid});
			push @$admincmds_ar, @$opp_ar;
		}
		# XXX Also, if the tag is on a project, check
		# getTagnameSfnetadmincmds().
		# Any negative admin command, to either this tagname or
		# its opposite, means clout must be set to 0.
		if (grep { $_->{cmdtype} =~ /^[_#]/ } @$admincmds_ar) {
			my $count = $self->sqlInsert('tag_params', {
				tagid =>	$tagid,
				name =>		'tag_clout',
				value =>	0,
			});
			$rows = 0 if $count < 1;
		}
	}

	# If it passed all the tests, commit it.  Otherwise rollback.
	if ($rows) {
		$self->sqlDo('COMMIT');
	} else {
		$self->sqlDo('ROLLBACK');
	}

	# Return AUTOCOMMIT to its original state in any case.
	$self->sqlDo('SET AUTOCOMMIT=1');

	return $rows ? $tagid : 0;
}

sub deactivateTag {
	my($self, $hr, $options) = @_;
	my $tag = $self->_setuptag($hr, { tagname_not_required => !$options->{tagname_required} });
	return 0 if !$tag;
	my $prior_clause = '';
	$prior_clause = " AND tagid < $options->{tagid_prior_to}" if $options->{tagid_prior_to};
	my $where_clause = "uid		= $tag->{uid}
			 AND globjid	= $tag->{globjid}
			 AND inactivated IS NULL
			 $prior_clause";
	$where_clause .= " AND tagnameid = $tag->{tagnameid}" if $tag->{tagnameid};
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
# This is usually what you want.  In rare cases, the caller
# may know that the tagname does not exist or is highly
# unlikely to exist, in which case this method will be
# less efficient than createTagname.

sub getTagnameidCreate {
	my($self, $name) = @_;
	return 0 if !$self->tagnameSyntaxOK($name);
	my $reader = getObject('Slash::Tags', { db_type => 'reader' });
	my $id = $reader->getTagnameidFromNameIfExists($name);
	return $id if $id;
	return $self->createTagname($name);
}

# Given a tagname, create it if it does not already exist.
# Whether it had existed or not, return its id.  E.g. turn
# 'omglol' into '17241' (a possibly new, possibly old ID).
#
# This method assumes that the tag does not already exist,
# and thus the first action it tries is creating that tag.
# If you _don't_ have reason to believe that the tag does
# _not_ already exist, this method will be less efficient
# than getTagnameidCreate.

sub createTagname {
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
		return $self->getTagnameidFromNameIfExists($name);
	}
	# The insert succeeded.  Return the ID that was just added.
	return $self->getLastInsertId();
}

# Given a tagname, get its id, e.g. turn 'omglol' into '17241'.
# If no such tagname exists, do not create it;  return 0.

sub getTagnameidFromNameIfExists {
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

	my $tagboxdb = getObject("Slash::Tagbox");
	my @feeder = ( );
	my $tagboxes = $tagboxdb->getTagboxes();
	my($globjid, $uid) = $self->sqlSelect('globjid, uid', 'tags', "tagid=$id");

	my $changed = 0;
	for my $key (sort keys %$params) {
		next if $key =~ /^(tagid|tagname|tagnameid|globjid|uid|created_at|inactivated|private)$/; # don't get to override existing fields
		my $value = $params->{$key};
		my $this_changed = 0;
		if (defined($value) && length($value)) {
			$this_changed = 1 if $self->sqlReplace('tag_params', {
				tagid =>	$id,
				name =>		$key,
				value =>	$value,
			});
		} else {
			my $key_q = $self->sqlQuote($key);
			$this_changed = 1 if $self->sqlDelete('tag_params',
				"tagid = $id AND name = $key_q"
			);
		}
		if ($this_changed) {
			for my $tagbox_hr (@$tagboxes) {
				my $tbid = $tagbox_hr->{tbid};
				my $affected = $tagbox_hr->{affected_type} eq 'user'
					? $uid : $globjid;
				$tagbox_hr->{object}->addFeederInfo({
					affected_id =>	$affected,
					importance =>	1,
					tagid =>	$id,
				});
			}
		}
		$changed ||= $this_changed;
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
	return 0 if !$id || $id !~ /^\d+$/ || !$params || !%$params;

	my $changed = 0;
	for my $key (sort keys %$params) {
		next if $key =~ /^tagname(id)?$/; # don't get to override existing fields
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

# Given a tagnameid, get its name and any param data that may exist for
# that tagname, e.g. turn '17241' into
# { tagname => 'omglol', tag_clout => '0.5' }.
# If no such tagname ID exists, return undef.

sub getTagnameDataFromId {
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

# getTagsByGlobjid is the main method, getTagsByNameAndIdArrayref
# is a convenience interface to it.
#
# Given a name and id, return the arrayref of all tags on that
# global object.  Options change which tags are returned:
#
# uid:			only tags created by that uid
# include_inactive:	inactivated tags will also be returned
# include_private:	private tags will also be returned
# XXX (should we have only_inactive and only_private options? I can't see a need right now)
# days_back:		only tags created in the past n days
# tagnameid:		only tags matching tagnameid as well as globjid
#
# The columns in the tags table are returned, plus two bonus
# fields: created_at_ut, the unix timestamp of the created_at
# column, and tagname, the text string for the tagnameid column.
#
# Note that tag_params are not returned:  see e.g.
# addCloutsToTagArrayref().  At the moment (Sept. 2006) we are not doing
# anything with tag_params except clouts so we're getting a performance
# advantage by basically ignoring them.  Eventually this should change.

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
	my $private_where = $options && $options->{include_private}
		? ''
		: " AND private='no'";

	my $days_where = $options && $options->{days_back}
		? " AND created_at >= DATE_SUB(NOW(), INTERVAL $options->{days_back} DAY)"
		: '';

	my $tagnameid_where = '';
	if ($options->{tagnameid}) {
		my $tagnameid_q = $self->sqlQuote($options->{tagnameid});
		$tagnameid_where = " AND tagnameid = $tagnameid_q";
	} elsif ($options->{limit_to_tagnames}) {
		my $in_clause = join ',', grep { $_ } map { $self->getTagnameidFromNameIfExists($_) } @{ $options->{limit_to_tagnames} };
		$tagnameid_where = " AND tagnameid IN ($in_clause)";
	}

	my $ar = $self->sqlSelectAllHashrefArray(
		'*, UNIX_TIMESTAMP(created_at) AS created_at_ut',
		'tags',
		"globjid=$globjid
		 $inactivated_where $private_where $uid_where $days_where $tagnameid_where",
		'ORDER BY tagid');

	$self->dataConversionForHashrefArray($ar);
	$self->addTagnameDataToHashrefArray($ar);
	return $ar;
}

# Given a tagnameid, return what clid type should be used for it
# (0 = unknown).

{ # closure
my($reason_names, $upvoteid, $downvoteid) = (undef, undef, undef);
sub getTagnameidClid {
	my($self, $tagnameid) = @_;
	if ($tagnameid !~ /^\d+$/) {
		warn "non-numeric tagnameid passed to getTagnameCloutType: $tagnameid";
		return 0;
	}
	my $constants = getCurrentStatic();

	my $mcd = $self->getMCD();
	my $mcdkey = undef;
	if ($mcd) {
		$mcdkey = "$self->{_mcd_keyprefix}:tanc:";
		my $value = $mcd->get("$mcdkey$tagnameid");
		return $value if defined $value;
	}

	my $clid = 0;
	my $tn_data = undef;
	my $types = $self->getCloutTypes();

	# Is it a vote?
	if ($types->{vote}) {
		if (!$clid) {
			$upvoteid   ||= $self->getTagnameidCreate($constants->{tags_upvote_tagname}   || 'nod');
			$clid = $types->{vote} if $tagnameid == $upvoteid;
		}
		if (!$clid) {
			$downvoteid ||= $self->getTagnameidCreate($constants->{tags_downvote_tagname} || 'nix');
			$clid = $types->{vote} if $tagnameid == $downvoteid;
		}
	}

	# Is it descriptive?
	# XXX this should be optimized by retrieving the list of _all_
	# descriptive tagnames in memcached or the local closure and
	# doing a lookup on that.
	if ($types->{describe} && !$clid) {
		$tn_data = $self->getTagnameDataFromId($tagnameid);
		$clid = $types->{describe} if $tn_data->{descriptive};
	}

	# Is it a moderation?
	if ($types->{moderate} && $constants->{m1} && $constants->{m1_pluginname}) {
		if (!$clid) {
			if (!$reason_names) {
				my $mod_db = getObject("Slash::$constants->{m1_pluginname}", { db_type => 'reader' });
				my $reasons = $mod_db->getReasons();
				$reason_names = {
					map { (lc($reasons->{$_}{name}), 1) }
					keys %$reasons
				};
			}
			$tn_data ||= $self->getTagnameDataFromId($tagnameid);
			$clid = $types->{moderate} if $reason_names->{ $tn_data->{tagname} };
		}
	}

	$mcd->set("$mcdkey$tagnameid", $clid, $constants->{memcached_exptime_tags}) if $mcd;

	return $clid;
}
} # end closure

# Given an arrayref of hashrefs representing tags, such as that
# returned by getTagsByNameAndIdArrayref, add three fields to each
# hashref:  tag_clout, tagname_clout, user_clout.  Values default
# to 1.  "Rounded" means round to 3 decimal places.

sub addRoundedCloutsToTagArrayref {
	my($self, $ar) = @_;
	$self->addCloutsToTagArrayref($ar);
	for my $tag_hr (@$ar) {
		$tag_hr->{tag_clout}     = sprintf("%.3f", $tag_hr->{tag_clout});
		$tag_hr->{tagname_clout} = sprintf("%.3f", $tag_hr->{tagname_clout});
		$tag_hr->{user_clout}    = sprintf("%.3f", $tag_hr->{user_clout});
		$tag_hr->{total_clout}   = sprintf("%.3f", $tag_hr->{total_clout});
	}
}

sub addCloutsToTagArrayref {
	my($self, $ar) = @_;

	return if !$ar || !@$ar;
	my $constants = getCurrentStatic();

	# Pull values from tag params named 'tag_clout'
	my @tagids = sort { $a <=> $b } map { $_->{tagid} } @$ar;
	my $tagids_in_str = join(',', @tagids);
	my $tag_clout_hr = $self->sqlSelectAllKeyValue(
		'tagid, value', 'tag_params',
		"tagid IN ($tagids_in_str) AND name='tag_clout'");

	# Pull values from tagname params named 'tag_clout'
	my $tagname_clout_hr = { };
	my %tagnameid = map { ($_->{tagnameid}, 1) } @$ar;
	for my $tagnameid (keys %tagnameid) {
		my $tn_data = $self->getTagnameDataFromId($tagnameid);
		$tagname_clout_hr->{$tagnameid} = $tn_data->{tag_clout} || 1;
	}

	# Record which clout type each tagname uses
	my $tagname_clid_hr = { };
	for my $tagnameid (keys %tagnameid) {
		my $clid = $self->getTagnameidClid($tagnameid);
		$tagname_clid_hr->{$tagnameid} = $clid;
	}

	# Tagnames with unspecified clout type get a reduced form
	# of some other clout type.
	my $default_clout_clid = $constants->{tags_unknowntype_default_clid} || 1;
	my $default_clout_mult = $constants->{tags_unknowntype_default_mult} || 0.3;

	# Get clouts for all users referenced.
	my $user_clout_hr = { };
	my %uid = map { ($_->{uid}, 1) } @$ar;
	for my $uid (keys %uid) {
		# XXX getUser($foo, 'clout') does not work at the moment,
		# so getUser($foo)->{clout} is used instead
		my $user = $self->getUser($uid);
		$user_clout_hr->{$uid} = $self->getUser($uid)->{clout} if $user;
	}


	my $clout_types = $self->getCloutTypes();
	for my $tag_hr (@$ar) {
		$tag_hr->{tag_clout}     = defined($tag_clout_hr    ->{$tag_hr->{tagid}})
						 ? $tag_clout_hr    ->{$tag_hr->{tagid}}
						 : 1;
		$tag_hr->{tagname_clout} = defined($tagname_clout_hr->{$tag_hr->{tagnameid}})
						 ? $tagname_clout_hr->{$tag_hr->{tagnameid}}
						 : 1;
		my $mult = 1;
		my $tagname_clid = $tagname_clid_hr->{$tag_hr->{tagnameid}};
		if (!$tagname_clid) {
			$mult = $default_clout_mult;
			$tagname_clid = $default_clout_clid;
		}
		my $tagname_clout_name = $clout_types->{ $tagname_clid };
		my $clout = $user_clout_hr->{$tag_hr->{uid}};
		my $clout_specific = $clout ? $clout->{$tagname_clout_name} : 0;
		$tag_hr->{user_clout}    = $mult * $clout_specific;
		$tag_hr->{total_clout} = $tag_hr->{tag_clout} * $tag_hr->{tagname_clout} * $tag_hr->{user_clout};
	}
}

sub getAllTagsFromUser {
	my($self, $uid, $options) = @_;
	$options ||= {};
	return [ ] unless $uid;

	my $bookmark = getObject("Slash::Bookmark");
	my $journal = getObject("Slash::Journal");

	my $orderby = $options->{orderby} || "tagid";
	my $limit   = $options->{limit} ? " LIMIT $options->{limit} " : "";
	my $orderdir = uc($options->{orderdir}) eq "DESC" ? "DESC" : "ASC";
	my $inact_clause =   $options->{include_inactive} ? '' : ' AND inactivated IS NULL';
	my $private_clause = $options->{include_private}  ? '' : " AND private='no'";
	my $tagname_clause = $options->{tagnameid}
		? ' AND tags.tagnameid=' . $self->sqlQuote($options->{tagnameid}) : '';

	my($table_extra, $where_extra) = ("","");
	my $uid_q = $self->sqlQuote($uid);

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
			$where_extra .= " AND bookmarks.url_id = globjs.target_id AND bookmarks.uid = $uid_q";
		}
	}

	my $type_clause = "";
	my $ar = $self->sqlSelectAllHashrefArray(
		'tags.*',
		"tags $table_extra",
		"tags.uid = $uid_q
		 $inact_clause $private_clause $tagname_clause $where_extra",
		"ORDER BY $orderby $orderdir $limit");
	return [ ] unless $ar && @$ar;
	$self->dataConversionForHashrefArray($ar);
	$self->addTagnameDataToHashrefArray($ar);
	$self->addGlobjTargetsToHashrefArray($ar);
	for my $hr (@$ar) {
		next unless $hr->{globj_type}; # XXX throw warning?
		if ($hr->{globj_type} eq 'stories') {
			$hr->{story} = $self->getStory($hr->{globj_target_id});
		} elsif ($hr->{globj_type} eq 'urls') {
			$hr->{url} = $self->getUrl($hr->{globj_target_id});
			if ($bookmark) {
				$hr->{url}{bookmark} = $bookmark->getUserBookmarkByUrlId($uid, $hr->{url}{url_id});
			}
		} elsif ($hr->{globj_type} eq 'journals') {
			$hr->{journal} = $journal->get($hr->{globj_target_id});
		} elsif ($hr->{globj_type} eq 'submissions') {
			$hr->{submission} = $journal->getSubmission($hr->{globj_target_id});
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

# The 'private' field is stored in SQL as 'no','yes' and used
# internally as '0','1'.  This method converts an arrayref of
# hashrefs from the SQL to the internal format.  If we end up
# having other similar conversions being necessary, they will
# be put here as well.

sub dataConversionForHashrefArray {
	my($self, $ar) = @_;
	for my $hr (@$ar) {
		$hr->{private} = $hr->{private} eq 'no' ? 0 : 1;
	}
}

# This takes an arrayref of hashrefs, and in each hashref, looks up the
# tagname and any other params corresponding to the tagnameid field and
# adds it/them to fields.  If the field already exists in the hashref
# it will not be overwritten.

sub addTagnameDataToHashrefArray {
	my($self, $ar) = @_;
	my %tagnameids = (
		map { ( $_->{tagnameid}, 1 ) }
		@$ar
	);
	# XXX This could/should be done more efficiently;  we need a
	# getTagnameDataFromIds method to do this in bulk and take
	# advantage of get_multi and put all the sqlSelects together.
	my %tagdata = (
		map { ( $_, $self->getTagnameDataFromId($_) ) }
		keys %tagnameids
	);
	for my $hr (@$ar) {
		my $id = $hr->{tagnameid};
		my $d = $tagdata{$id};
		for my $key (keys %$d) {
			next if exists $hr->{$key};
			$hr->{$key} = $d->{$key};
		}
	}
}

# XXX memcached here would be good

sub getUidsUsingTagname {
	my($self, $name, $options) = @_;
	my $private_clause = $options->{include_private} ? '' : " AND private='no'";
	my $id = $self->getTagnameidFromNameIfExists($name);
	return [ ] if !$id;
	return $self->sqlSelectColArrayref('DISTINCT(uid)', 'tags',
		"tagnameid=$id AND inactivated IS NULL $private_clause");
}

sub getAllObjectsTagname {
	my($self, $name, $options) = @_;
	my $constants = getCurrentStatic();
#	my $mcd = undef;
#	my $mcdkey = undef;
#	if (!$options->{include_private}) {
#		$mcd = $self->getMCD();
#	}
#	if ($mcd) {
#		$mcdkey = "$self->{_mcd_keyprefix}:taotn:";
#		my $value = $mcd->get("$mcdkey$name");
#		return $value if defined $value;
#	}
	$options = { } if !$options || !ref $options;
	my $private_clause = $options->{include_private} ? '' : " AND private='no'";
	my $id = $self->getTagnameidFromNameIfExists($name);
	return [ ] if !$id;
	# XXX make this degrade gracefully if plugins/FireHose not installed
	my $firehose_db = getObject('Slash::FireHose');
	my $min_pop = $options->{min_pop}
		|| $firehose_db->getMinPopularityForColorLevel( $constants->{tags_active_mincare} || 5 );
	# 117K rows unjoined, 7 seconds ; 10K rows unjoined, 3 seconds ; 10K rows joined, 18 seconds
	my $hr_ar = $self->sqlSelectAllHashrefArray(
		'*, UNIX_TIMESTAMP(created_at) AS created_at_ut',
		'tags, firehose',
		"tags.globjid=firehose.globjid AND popularity >= $min_pop
		 AND tagnameid=$id AND inactivated IS NULL $private_clause",
		'ORDER BY tagid DESC LIMIT 5000');
	# 117K rows, 6 minutes ; 10K rows, 30 seconds
	$self->addGlobjEssentialsToHashrefArray($hr_ar);
	# 117K rows, 8 minutes ; 10K rows, 60 seconds
	$self->addCloutsToTagArrayref($hr_ar);
#	if ($mcd) {
#		my $constants = getCurrentStatic();
#		my $secs = $constants->{memcached_exptime_tags_brief} || 300;
#		$mcd->set("$mcdkey$name", $hr_ar, $secs);
#	}
	return $hr_ar;
}

# XXX memcached here would be good

sub getTagnameParams {
	my($self, $tagnameid) = @_;
	return $self->sqlSelectAllKeyValue('name, value', 'tagname_params',
		"tagnameid=$tagnameid");
}

sub getWorstAdminCmdtype {
	my($self, $tagnameid, $globjid) = @_;
	$globjid ||= 0;
	my $ar = $self->getTagnameAdmincmds($tagnameid, $globjid);
	my $worst = '';
	my $worst_count = 0;
	for my $hr (@$ar) {
		my $cmdtype = $hr->{cmdtype};
		     if ($cmdtype eq '_' && $worst_count == 0) {
			$worst = '_';
		} elsif ($cmdtype =~ /^[*)]$/ && $worst eq '') {
			$worst = $cmdtype;
		} elsif ($cmdtype =~ /^\#+$/) {
			my $count = $cmdtype =~ tr/#/#/;
			if ($count > $worst_count) {
				$worst = $cmdtype;
				$worst_count = $count;
			}
		}
	}
	return $worst;
}

sub getTagnameAdmincmds {
	my($self, $tagnameid, $globjid) = @_;
	return [ ] if !$tagnameid;
	my $where_clause = "tagnameid=$tagnameid";
	$where_clause .= " AND globjid=$globjid" if $globjid;
	return $self->sqlSelectAllHashrefArray(
		"tagnameid, IF(globjid IS NULL, 'all', globjid) AS globjid,
		 cmdtype, created_at,
		 UNIX_TIMESTAMP(created_at) AS created_at_ut",
		'tagcommand_adminlog',
		$where_clause);
}

sub getTagnameSfnetadmincmds {
	my($self, $tagnameid, $globjid) = @_;
	return [ ] if !$tagnameid || !$globjid;
	my $where_clause = "tagnameid=$tagnameid AND globjid=$globjid";
	return $self->sqlSelectAllHashrefArray(
		"tagnameid, globjid, cmdtype, created_at,
		 UNIX_TIMESTAMP(created_at) AS created_at_ut",
		'tagcommand_adminlog_sfnet',
		$where_clause);
}

sub removeTagnameFromIndexTop {
	my($self, $tagname) = @_;
	my $tagid = $self->getTagnameidCreate($tagname);
	return 0 if !$tagid;

	my $changes = $self->setTagname($tagname, { noshow_index => 1 });
	return 0 if !$changes;

	# The tagname wasn't on the noshow_index list and now it is.
	# Force tags_update.pl to rebuild starting from the first use
	# of this tagname.
	# XXX this part isn't gonna work since tagboxes
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

sub sfnetadminPseudotagnameSyntaxOK {
	my($self, $command) = @_;
	my($type, $tagname) = $self->getTypeAndTagnameFromAdminCommand($command);
	return 0 if !$type || $type ne '_'; # only command sfnetadmins get is '_', for now
	return $self->tagnameSyntaxOK($tagname);
}

# XXX based off of ajaxCreateStory.  ajaxCreateStory should be updated to use this or something
# similar soon, and after I've had time to test -- vroom 2006/03/21
# XXX Tim, I need you to look this over. - Jamie 2006/09/19

sub setTagsForGlobj {
	my($self, $id, $table, $tag_string, $options) = @_;
	my $tags = getObject('Slash::Tags'); # XXX isn't this the same as $self? -Jamie
	$options ||= {};
	
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $priv_tagnames = $self->getPrivateTagnames();

	$tag_string ||= $form->{tags} || '';

	if ($user->{is_admin}) {
		my @admin_commands =
			grep { $tags->adminPseudotagnameSyntaxOK($_) }
			map { lc }
			split /[\s,]+/,
			$tag_string;
		for my $c (@admin_commands) {
			$self->processAdminCommand($c, $id, $table);
		}
	} elsif ($options->{is_sfnetadmin}) {
		my @admin_commands =
			grep { $tags->sfnetadminPseudotagnameSyntaxOK($_) }
			map { lc }
			split /[\s,]+/,
			$tag_string;
		for my $c (@admin_commands) {
			$self->processSfnetadminCommand($c, $id, $table);
		}
	}

	my %new_tagnames =
		map { ($_, 1) }
		grep { $tags->tagnameSyntaxOK($_) }
		map { lc }
		split /[\s,]+/,
		$tag_string;

	my $uid = $options->{uid} || $user->{uid};
	my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });
	# Don't include private tags in the list of old tags that we may delete.
	my $old_tags_ar = $tags_reader->getTagsByNameAndIdArrayref($table, $id, { uid => $uid });
	my %old_tagnames = ( map { ($_->{tagname}, 1) } @$old_tags_ar );

	# Create any tag specified but only if it does not already exist.
	my @create_tagnames	= grep { !$old_tagnames{$_} } sort keys %new_tagnames;

	my @deactivate_tagnames;
	if ( ! $options->{deactivate_by_operator} ) {
		# Deactivate any tags previously specified that were deleted from the tagbox.
		@deactivate_tagnames	= grep { !$new_tagnames{$_} } sort keys %old_tagnames;
	} else {
		# Deactivate any tags that are supplied as "-tag"
		@deactivate_tagnames =
			map { $1 if /^-(.+)/ }
			split /[\s,]+/,
			lc $tag_string;
	}
	for my $tagname (@deactivate_tagnames) {
		$tags->deactivateTag({
			uid =>		$uid,
			name =>		$tagname,
			table =>	$table,
			id =>		$id
		}, { tagname_required => $options->{tagname_required} });
	}

	my @created_tagnames = ( );
	for my $tagname (@create_tagnames) {
		my $private = 0;
		$private = 1 if $priv_tagnames->{$tagname};
		push @created_tagnames, $tagname
			if $tags->createTag({
				uid =>		$uid,
				name =>		$tagname,
				table =>	$table,
				id =>		$id,
				private =>	$private
			});
	}

	my $now_tags_ar = $tags->getTagsByNameAndIdArrayref($table, $id,
		{ uid => $uid, include_private => $options->{include_private} }); # don't list private tags unless forced
	my $newtagspreloadtext = join ' ', sort map { $_->{tagname} } @$now_tags_ar;
	return $newtagspreloadtext;
}

sub ajaxDeactivateTag {
	my($self, $constants, $user, $form) = @_;
	my $type = $form->{type} || "stories";
	my $tags = getObject('Slash::Tags'); # XXX isn't this the same as $self? -Jamie

	my ($table, $id);

	if ($type eq "firehose") {
		my $firehose = getObject("Slash::FireHose");
		my $item = $firehose->getFireHose($form->{id});
		($table, $id) = $tags->getGlobjTarget($item->{globjid});
	} else {
		# XXX doesn't work yet for stories or urls
		return;
	}

	$tags->deactivateTag({
		uid =>		$user->{uid},
		name =>		$form->{tag},
		table =>	$table,
		id =>		$id,
	});
}

sub ajaxSetGetCombinedTags {
	my($slashdb, $constants, $user, $form) = @_;

	my $key = $form->{key};
	my $key_type = $form->{key_type};

	my $firehose = getObject('Slash::FireHose');
	my ($globjid, $firehose_id, $firehose_item);

	if ( $key_type eq 'url' ) {
		$key = $firehose->getFireHoseIdFromUrl($key);
		$key_type = 'firehose-id';
	} elsif ( $key_type eq 'sid' ) {
		$key = $slashdb->getStoidFromSidOrStoid($key);
		$key_type = 'stoid';
	}

	if ( $key_type eq 'stoid' ) {
		$globjid = $slashdb->getGlobjidFromTargetIfExists('stories', $key);
		$firehose_id = $firehose->getFireHoseIdFromGlobjid($globjid);
		$firehose_item = $firehose->getFireHose($firehose_id);
	} elsif ( $key_type eq 'firehose-id' ) {
		$firehose_item = $firehose->getFireHose($key);
		$globjid = $firehose_item->{globjid} if $firehose_item;
		$firehose_id = $key;
	}

	my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });
	if (!$globjid || $globjid !~ /^\d+$/ || !$tags_reader) {
		return getData('error', {}, 'tags');
	}
	my($table, $item_id) = $tags_reader->getGlobjTarget($globjid);

	my $uid = $user && $user->{uid} || 0;

	# if we have to execute commands, do them _before_ we fetch any tag lists
	my $user_tags = '';
	if ( $form->{tags} ) {
		my $tags_writer = getObject('Slash::Tags');
		$user_tags = $tags_writer->setTagsForGlobj($item_id, $table, '', {
			deactivate_by_operator => 1,
			tagname_required => 1,
			include_private => 1
		});
		if ( $user->{is_admin} && $firehose_id ) {
			my $added_tags =
				join ' ',
				grep { /^[^-]/ }
				split /\s+/,
				lc $form->{tags};

			$firehose->setSectionTopicsFromTagstring($firehose_id , $added_tags);
			$firehose_item = $firehose->getFireHose($firehose_id);
		};
	} elsif ( ! $form->{global_tags_only} ) {
		my $current_tags_array = $tags_reader->getTagsByNameAndIdArrayref($table, $item_id, { uid => $uid, include_private => 1 });
		$user_tags = join ' ', sort map { $_->{tagname} } @$current_tags_array;
	}

	my ($datatype_tag, $top_tags, $section_tag, $topic_tags);
	if ( $firehose_item ) {
		$datatype_tag = $firehose_item->{type};
		$top_tags = $firehose_item->{toptags};

		my $skid = $firehose_item->{primaryskid};
		if ( $skid ) {
			if ( $skid != $constants->{mainpage_skid} ) {
				my $skin = $firehose->getSkin($skid);
				$section_tag = $skin->{name};
			} else {
				$section_tag = 'mainpage';
			}
		}

		my $tid = $firehose_item->{tid};
		if ( $tid ) {
			my $topic = $firehose->getTopic($tid);
			$topic_tags = $topic->{keyword};
		}
	}

	my $system_tags = $section_tag . ' ' . $topic_tags;

	my $response = '<datatype>' . $datatype_tag . '<system>' . $system_tags . '<top>'. $top_tags;
	$response .= '<user>' . $user_tags unless $form->{global_tags_only};

	return $response;
}

sub setGetCombinedTags {
	my($self, $key, $key_type, $user, $commands) = @_;

	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	my $options = {
		'key'		=> $key,
		'key_type'	=> $key_type,
	};
	$options->{global_tags_only} = 1 unless $user;
	$options->{tags} = $commands if $commands;

	my @tuples = split /<([\w:]*)>/, ajaxSetGetCombinedTags($slashdb, $constants, $user, $options);
	shift @tuples; # bogus empty first elem when capturing separators

	my $response = {};
	while ( @tuples ) {
		my $k = shift @tuples;
		$response->{$k} = shift @tuples || '' if $k;
#print STDERR "key => $key; value => $response->{$key}\n";
	}
#print STDERR "---------\n";

	return $response;
}

{
my %_adcmd_prefix = ( );
sub normalizeAndOppositeAdminCommands {
	my($self, @commands) = @_;
	if (!%_adcmd_prefix) {
		$_adcmd_prefix{0} = '_';
		for my $i (1..5) { $_adcmd_prefix{$i} = '#' x $i }
	}
	my @new = ( );
	my %count = ( );
	for my $c (@commands) {
		my($type, $tagname) = $self->getTypeAndTagnameFromAdminCommand($c);
		next unless $type;
		if ($type !~ /$(_|#+)/) {
			push @new, $c;
			next;
		}
		my $count = $type =~ tr/#/#/;
		$count{$tagname} ||= 0;
		$count{$tagname} = $count if $count{$tagname} < $count;
		my $opp = $self->getOppositeTagname($tagname);
		$count{$opp} ||= 0;
	}
	
	push @new, ( map { $_adcmd_prefix{$count{$_}} . $_ } sort keys %count );
	return @new;
}
}

sub ajaxTagHistory {
	my($slashdb, $constants, $user, $form) = @_;
	my $globjid;
	my $id;
	my $table;
	if ($form->{type} eq "stories") {
		my $sidenc = $form->{sidenc};
		my $sid = $sidenc; $sid =~ tr{-}{/};
		$id = $slashdb->getStoidFromSid($sid);
		$table = "stories"
	} elsif ($form->{type} eq "urls") {
		$table = "urls";	
	} elsif ($form->{type} eq "firehose") {
		my $itemid = $form->{id};
		my $firehose = getObject("Slash::FireHose");
		my $item = $firehose->getFireHose($itemid);
		if (!$item || !$item->{globjid}) {
			use Data::Dumper;
			my($i_d, $f_d) = (Dumper($item), Dumper($form));
			$i_d =~ s/\s+/ /g; $f_d =~ s/\s+/ /g;
			warn "ajaxTagHistory blank item or globjid: $i_d $f_d";
		}
		$globjid = $item->{globjid};
		my $tags = getObject("Slash::Tags");
		($table, $id) = $tags->getGlobjTarget($globjid);
	}
	$id ||= $form->{id};
	
	my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });
	$globjid ||= $tags_reader->getGlobjidFromTargetIfExists($table, $id);
	my $tags_ar = [];
	if ($table && $id) {
		$tags_ar = $tags_reader->getTagsByNameAndIdArrayref($table, $id,
			{ include_inactive => 1, include_private => 1 });
	}

	my $summ = { };

	# Don't list 'viewed' tags, just count them.
	my $viewed_tagname = $constants->{tags_viewed_tagname} || 'viewed';
	$summ->{n_viewed} = scalar grep { $_->{tagname} eq $viewed_tagname } @$tags_ar;
	$tags_ar = [ grep { $_->{tagname} ne $viewed_tagname } @$tags_ar ];

	$tags_reader->addRoundedCloutsToTagArrayref($tags_ar);

	my $clout_types = $tags_reader->getCloutTypes();
	for my $tag (@$tags_ar) {
		my $clid = $tags_reader->getTagnameidClid($tag->{tagnameid});
		$tag->{clout_code} = $clid
			? uc( substr( $clout_types->{$clid}, 0, 1) )
			: '';
		my $cmd = $tags_reader->getWorstAdminCmdtype($tag->{tagnameid}, $tag->{globjid});
		if (!$tag->{clout_code}) {
			$tag->{clout_code} = $cmd;
		} elsif ($cmd) {
			$tag->{clout_code} = "$tag->{clout_code} $cmd";
		}
	}

	my $tagboxdb = getObject('Slash::Tagbox');
	if (@$tags_ar && $globjid && $tagboxdb) {
		my $fhs = getObject('Slash::Tagbox::FireHoseScores');
		if ($fhs) {
			my $authors = $slashdb->getAuthors();
			my $starting_score =
				$fhs->run($globjid, { return_only => 1, starting_only => 1 });
			$summ->{up_pop}   = sprintf("%+0.2f",
				$fhs->run($globjid, { return_only => 1, upvote_only => 1 })
				- $starting_score );
			$summ->{down_pop} = sprintf("%0.2f",
				$fhs->run($globjid, { return_only => 1, downvote_only => 1 })
				- $starting_score );
			my $upvoteid   = $tags_reader->getTagnameidCreate($constants->{tags_upvote_tagname}   || 'nod');
			my $downvoteid = $tags_reader->getTagnameidCreate($constants->{tags_downvote_tagname} || 'nix');
			$summ->{up_count}      = scalar grep { $_->{tagnameid} == $upvoteid   } @$tags_ar;
			$summ->{down_count}    = scalar grep { $_->{tagnameid} == $downvoteid } @$tags_ar;
			$summ->{up_count_ed}   = scalar grep { $_->{tagnameid} == $upvoteid
							    && $authors->{ $_->{uid} }      }  @$tags_ar;
			$summ->{down_count_ed} = scalar grep { $_->{tagnameid} == $downvoteid
							    && $authors->{ $_->{uid} }      }  @$tags_ar;
		}
	}

	slashDisplay('taghistory', { tags => $tags_ar, summary => $summ }, { Return => 1 } );
}

sub ajaxListTagnames {
	my($slashdb, $constants, $user, $form) = @_;
	my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });

	$form->{prefix} ||= $form->{'q'} || '';

	my $prefix = '';
	$prefix = lc($1) if $form->{prefix} =~ /([A-Za-z0-9]{1,20})/;
	my $len = length($prefix);
	my $notize = $form->{prefix} =~ /^([-!])/ ? $1 : '';

	my $minlen = $constants->{tags_prefixlist_minlen} || 3;
	if ($len < $minlen) {
		# Too short to give a meaningful suggestion, and the
		# shorter the prefix the longer the DB query takes.
		return '';
	}

	my $tnhr = $tags_reader->listTagnamesByPrefix($prefix);

	my @priority =
		grep { substr($_, 0, $len) eq $prefix }
		split / /,
		$constants->{tags_prefixlist_priority};
	for my $priname (@priority) {
		# Don't reduce a tagname's value if it already exceeds the
		# hardcoded score value.
		next if $tnhr->{$priname} && $tnhr->{$priname} > $constants->{tags_prefixlist_priority_score};
		$tnhr->{$priname} = $constants->{tags_prefixlist_priority_score};
	}

	my $ret_str = '';
	for my $tagname (sort { $tnhr->{$b} <=> $tnhr->{$a} } keys %$tnhr) {
		$ret_str .= sprintf("%s%s\n", $notize, $tagname);
	}
#use Data::Dumper; print STDERR scalar(localtime) . " ajaxListTagnames uid=$user->{uid} prefix='$prefix' tnhr: " . Dumper($tnhr);
	return $ret_str;
}

{ # closure

my @clout_reduc_map = qw(  0.15  0.50  0.90  0.99  1.00  ); # should be a var

sub processAdminCommand {
	my($self, $c, $id, $table) = @_;

	my($type, $tagname) = $self->getTypeAndTagnameFromAdminCommand($c);
	return 0 if !$type;

	my $constants = getCurrentStatic();
	my $tagnameid = $self->getTagnameidCreate($tagname);
	my $opp_tagnameids = $self->getOppositeTagnameids($tagnameid);
	my %affected_tagnameid = (
		map { ( $_, 1 ) } ( $tagnameid, @$opp_tagnameids )
	);

	my $systemwide = $type =~ /^\$/ ? 1 : 0;
	my $globjid = $systemwide ? undef : $self->getGlobjidCreate($table, $id);

	my $hashmark_count = $type =~ s/\#/\#/g;
	my $user_clout_reduction = 0;
	$user_clout_reduction = $clout_reduc_map[$hashmark_count-1] if $hashmark_count;
	$user_clout_reduction = 1 if $user_clout_reduction > 1;

	my $new_user_clout = 1-$user_clout_reduction;

	if ($type eq '*') {
		# Asterisk means admin is saying this tagname is "OK",
		# which (at least so far, 2007/12) means it is not
		# malicious or stupid or pointless or etc.
		$self->setTagname($tagnameid, { admin_ok => 1 });
	} elsif ($type eq ')') {
		# Right-paren means admin is labelling this tagname as
		# descriptive.  Mnemonic: ")" looks like "D"
		$self->setTagname($tagnameid, { descriptive => 1 });
	} elsif ($type eq '^') {
		# Set individual clouts to 0 for tags of this name
		# (and its opposite) on this story that have already
		# been applied.  Future tags of this name (or its
		# opposite) on this story will apply with their full
		# clout.
		my $tags_ar = $self->getTagsByNameAndIdArrayref($table, $id);
		my @tags = grep { $affected_tagnameid{ $_->{tagnameid} } } @$tags_ar;
		for my $tag (@tags) {
			$self->setTag($tag->{tagid}, { tag_clout => 0 });
		}
	} else {
		if ($systemwide) {
			$self->setTagname($tagnameid, { tag_clout => 0 });
			if ($new_user_clout < 1) {
				my $uids = $self->sqlSelectColArrayref('uid', 'tags',
					"tagnameid=$tagnameid AND inactivated IS NULL");
				if (@$uids) {
					my @uids_changed = ( );
					for my $uid (@$uids) {
						my $max_clout = $self->getAdminCommandMaxClout($uid);
						$max_clout = $new_user_clout if $new_user_clout < $max_clout;
						push @uids_changed, $uid
							if $self->setUser($uid, {
								-tag_clout => "LEAST(tag_clout, $max_clout)"
							});
					}
					my $uids_str = join(',', @uids_changed);
					my $user_min = $self->sqlSelect('MIN(tagid)', 'tags',
						"uid IN ($uids_str)");
				}
			}
		} else {
			# Just logging the command is enough to affect future tags
			# applied to this story (that's the way we're doing it now,
			# though I'm not ecstatic about it and it may change).
			my $tags_ar = $self->getTagsByNameAndIdArrayref($table, $id, { include_private => 1 });
			my $opp_tagnameids = $self->getOppositeTagnameids($tagnameid);
			my @tags_to_zero = grep { $affected_tagnameid{ $_->{tagnameid} } } @$tags_ar;
			for my $tag (@tags_to_zero) {
				$self->setTag($tag->{tagid}, { tag_clout => 0 });
			}
			if ($new_user_clout < 1) {
				my $uids = $self->sqlSelectColArrayref('uid', 'tags',
					"tagnameid=$tagnameid AND inactivated IS NULL
					 AND globjid=$globjid");
				if (@$uids) {
					my @uids_changed = ( );
					for my $uid (@$uids) {
						my $max_clout = $self->getAdminCommandMaxClout($uid);
						$max_clout = $new_user_clout if $new_user_clout < $max_clout;
						$self->setUser($uid, {
							-tag_clout => "LEAST(tag_clout, $max_clout)"
						});
					}
				}
			}
		}
	}

	$self->logAdminCommand($type, $tagname, $globjid);

	my $tagboxdb = getObject('Slash::Tagbox');
	my $tagboxes = $tagboxdb->getTagboxes();
	for my $tagbox_hr (@$tagboxes) {
		my $field = $tagbox_hr->{affected_type} . 'id';
		$tagbox_hr->{object}->forceFeederRecalc($globjid);
	}

	return $tagnameid;
}

my @pound_exp_map = qw(  1.05  1.10  1.20  1.30  1.50  ); # should be a var

sub getAdminCommandMaxClout {
	my($self, $uid) = @_;
	my $count_hr = $self->getAdminCommandCountAffectingUID($uid);
#use Data::Dumper; $Data::Dumper::Sortkeys=1;
#print STDERR "getAdminCommandCountAffectingUID returns for $uid: " . Dumper($count_hr);
	return 1 if !keys %$count_hr;

	my $max_count = (sort { $b <=> $a } keys %$count_hr)[0];
	$count_hr->{$max_count}--;
	my $user_clout_reduction = 0;
	$user_clout_reduction = $clout_reduc_map[$max_count-1] if $max_count;
	$user_clout_reduction = 1 if $user_clout_reduction > 1;
	my $max_clout = 1-$user_clout_reduction;

	my $exponent = 1;
	for my $pound_count (keys %$count_hr) {
		$exponent += $pound_exp_map[$pound_count-1] ** $count_hr->{$pound_count}
			- 1;
#print STDERR "getAdminCommandCountAffectingUID exponent after key=$pound_count: $exponent\n";
	}
	$max_clout = $max_clout ** $exponent;
#print STDERR "getAdminCommandCountAffectingUID max_clout: $max_clout\n";

	return $max_clout;
}

sub processSfnetadminCommand {
	my($self, $c, $id, $table) = @_;

	return 0 if $table ne 'projects';

	my($type, $tagname) = $self->getTypeAndTagnameFromAdminCommand($c);
	return 0 if !$type || $type ne '_';

	my $user = getCurrentUser();
	return 0 if ! $self->sfuserIsAdminOnProject($user->{uid}, $id);

	my $constants = getCurrentStatic();
	my $tagnameid = $self->getTagnameidCreate($tagname);

	my $globjid = $self->getGlobjidCreate($table, $id);

	my $tags_ar = $self->getTagsByNameAndIdArrayref($table, $id, { include_private => 1 });
	my @tags = grep { $_->{tagnameid} == $tagnameid } @$tags_ar;
	for my $tag (@tags) {
		$self->setTag($tag->{tagid}, { tag_clout => 0 });
	}
	$self->logSfnetadminCommand($type, $tagname, $globjid);
	my $tagboxdb = getObject('Slash::Tagbox');
	my $tagboxes = $tagboxdb->getTagboxes();
	for my $tagbox_hr (@$tagboxes) {
		my $field = $tagbox_hr->{affected_type} . 'id';
		$tagbox_hr->{object}->forceFeederRecalc($globjid);
	}
}

} # closure

sub sfuserIsAdminOnProject {
	my($self, $uid, $project_id) = @_;

	# XXX For now, my belief is that only sf.net project admins
	# will be allowed to submit _ commands, and only on their
	# own projects, so any such commands by definition will be
	# authorized.  There's no great way to fill in the logic of
	# this method at the moment, but in the future we may need
	# to find a way.  - Jamie 2008-09-25

	return 1;
}

sub getTypeAndTagnameFromAdminCommand {
	my($self, $c) = @_;
	my($type, $tagname) = $c =~ /^(\^|\*|\)|\$?\_|\$?\#{1,5})(.+)$/;
#print STDERR scalar(gmtime) . " get c '$c' type='$type' tagname='$tagname'\n";
	return (undef, undef) if !$type || !$self->tagnameSyntaxOK($tagname);
	return($type, $tagname);
}

# $globjid should be the globjid specifically affected, or
# omitted (or false) when the type indicates a system-wide
# command.
sub logAdminCommand {
	my($self, $type, $tagname, $globjid) = @_;
	my $tagnameid = $self->getTagnameidFromNameIfExists($tagname);
	$self->sqlInsert('tagcommand_adminlog', {
		cmdtype =>	$type,
		tagnameid =>	$tagnameid,
		globjid =>	$globjid || undef,
		adminuid =>	getCurrentUser('uid'),
		-created_at =>	'NOW()',
	});
}

sub logSfnetadminCommand {
	my($self, $type, $tagname, $globjid) = @_;
	return 0 if !$globjid;
	my $tagnameid = $self->getTagnameidFromNameIfExists($tagname);
	$self->sqlInsert('tagcommand_adminlog_sfnet', {
		cmdtype =>		$type,
		tagnameid =>		$tagnameid,
		globjid =>		$globjid || undef,
		sfnetadminuid =>	getCurrentUser('uid'),
		-created_at =>		'NOW()',
	});
}

sub getAdminCommandCountAffectingUID {
	my($self, $uid) = @_;
	my $cmdtype_ar = $self->sqlSelectColArrayref(
		'cmdtype',
		'tagcommand_adminlog, tags',
		"tags.uid=$uid
		 AND tags.inactivated IS NULL
		 AND     tagcommand_adminlog.tagnameid = tags.tagnameid
		 AND ( ( tagcommand_adminlog.globjid = tags.globjid AND cmdtype LIKE '#%' )
		    OR ( tagcommand_adminlog.globjid IS NULL AND cmdtype LIKE '\$#%' )
		 )");
	my %pound_count = ( );
	for my $type (@$cmdtype_ar) {
		my $hashmark_count = $type =~ s/\#/\#/g;
		$pound_count{$hashmark_count}++;
	}
	return \%pound_count;
}

# This returns just the single tagname that is the opposite of
# another tagname, formed by prepending a "!" or removing an
# existing "!".  This is not guaranteed to be the only opposite
# of the given tagname.

sub getOppositeTagname {
	my($self, $tagname) = @_;
	return substr($tagname, 0, 1) eq '!' ? substr($tagname, 1) : '!' . $tagname;
}

# This returns an arrayref of tagnameids that are all the
# opposite of a given tagname or tagnameid (either works as
# input).  Or, an arrayref of tagname/tagnameids can be given
# as input and the returned arrayref will be tagnameids that
# are all the opposites of at least one of the inputs.

sub getOppositeTagnameids {
	my($self, $data, $create) = @_;

	my @tagnameids = ( );
	$data = [ $data ] if !ref($data);
	my %tagnameid = ( );
	for my $d (@$data) {
		next unless $d;
		if ($d =~ /^\d+$/) {
			$tagnameid{$d} = 1;
		} else {
			my $id = $self->getTagnameidFromNameIfExists($d);
			$tagnameid{$id} = 1 if $id;
		}
	}
	@tagnameids = keys %tagnameid;
	return [ ] if !@tagnameids;

	# Two ways to have an opposite of a tagname.  One is to prepend
	# an "!" or remove an existing prepended "!";  we convert IDs to
	# names and back to do this.  The other is to have an entry in
	# the tagnames_similar table with type=0 and simil=-1.
	# XXX Should probably recursively chase down type=0/simil=1
	# entries as being the same, and opposites-of-opposites etc.
	# Leave that for another day though.
	# Type one:
	my @tagnames =		map { $self->getTagnameDataFromId($_)->{tagname} }	@tagnameids;
	my @opp_tagnames =	map { $self->getOppositeTagname($_) }			@tagnames;
	my @opp_tagnameids_1 =	( );
	if ($create) {
		@opp_tagnameids_1 =
				map { $self->getTagnameidCreate($_) }			@opp_tagnames;
	} else {
		@opp_tagnameids_1 =
				grep { $_ }
				map { $self->getTagnameidFromNameIfExists($_) }		@opp_tagnames;
	}
	# Type two:
	my $src_tnids_str = join(',', @tagnameids);
	my $opp_tagnameids_2_ar = $self->sqlSelectColArrayref(
		'DISTINCT dest_tnid', 'tagnames_similar',
		"type=0 AND simil=-1 AND src_tnid IN ($src_tnids_str)");
	# Join them:
	my %opp_tagnameids = ( map { ($_, 1) } @opp_tagnameids_1, @$opp_tagnameids_2_ar );
	my @opp_tagnameids = sort { $a <=> $b } keys %opp_tagnameids;

	return \@opp_tagnameids;
}

# XXX this method isn't gonna work since tagboxes

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
	$options = { } if !$options || !ref $options;
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
	my($self, $options) = @_;
	my $constants = getCurrentStatic();
	$options = { } if !$options || !ref $options;
	my $max_num =         defined($options->{max_num})	   ? $options->{max_num} : 100;
	my $seconds =         defined($options->{seconds})	   ? $options->{seconds} : (3600*6);
	my $include_private = defined($options->{include_private}) ? $options->{include_private} : 0;
	my $min_slice =       defined($options->{min_slice})	   ? $options->{min_slice} : 0;
	my $min_clout =       defined($options->{min_clout})	   ? $options->{min_clout} : $constants->{tags_stories_top_minscore} || 0;
	$min_slice = 0 if !$constants->{plugin}{FireHose};

	# This seems like a horrendous query, but I _think_ it will run
	# in acceptable time, even under fairly heavy load.
	# (But see below, in listTagnamesRecent, for a possible
	# optimization.)

	# Round off time to the last minute.

	my $now_ut = $self->getTime({ unix_format => 1 });
	my $next_minute_ut = int($now_ut/60+1)*60;
	my $next_minute_q = $self->sqlQuote( time2str( '%Y-%m-%d %H:%M:00', $next_minute_ut, 'GMT') );
	my $private_clause = $include_private ? '' : " AND private='no'";

	# If we are asked to only look at tags on firehose items of a
	# particular color slice or better, then 
	my $slice_table_clause = '';
	my $slice_where_clause = '';
	if ($min_slice) {
		$slice_table_clause = ', firehose';
		my $firehose_reader = getObject('Slash::FireHose', { db_type => 'reader' });
		my $min_pop = $firehose_reader->getMinPopularityForColorLevel($min_slice);
		$slice_where_clause =
			"AND tags.globjid=firehose.globjid
			 AND firehose.popularity >= $min_pop";
	}

	my $ar = $self->sqlSelectAllHashrefArray(
		"tagnames.tagname AS tagname,
		 tags.tagid AS tagid,
		 tags.tagnameid AS tagnameid,
		 users_info.uid AS uid,
		 $next_minute_ut - UNIX_TIMESTAMP(tags.created_at) AS secsago",
		"users_info,
		 tags LEFT JOIN tag_params
		 	ON (tags.tagid=tag_params.tagid AND tag_params.name='tag_clout'),
		 tagnames LEFT JOIN tagname_params
			ON (tagnames.tagnameid=tagname_params.tagnameid AND tagname_params.name='tag_clout')
		 $slice_table_clause",
		"tagnames.tagnameid=tags.tagnameid
		 AND tags.uid=users_info.uid
		 AND inactivated IS NULL $private_clause
		 AND tags.created_at >= DATE_SUB($next_minute_q, INTERVAL $seconds SECOND)
		 AND users_info.tag_clout > 0
		 AND IF(tag_params.value     IS NULL, 1, tag_params.value)     > 0
		 AND IF(tagname_params.value IS NULL, 1, tagname_params.value) > 0
		 $slice_where_clause");
	return [ ] unless $ar && @$ar;
	$self->addCloutsToTagArrayref($ar);

	# Sum up the clout for each tagname, and the median time it
	# was seen within the interval in question.
	my %tagname_count = ( );
	my %tagname_clout = ( );
	my %tagname_sumsqrtsecsago = ( );
	for my $hr (@$ar) {
		my $tagname = $hr->{tagname};
		# Tally it.
		$tagname_count{$tagname} ||= 0;
		$tagname_count{$tagname}++;
		# Add to its clout.
		$tagname_clout{$tagname} ||= 0;
		$tagname_clout{$tagname} += $hr->{total_clout};
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
		{ $tagname_clout{$_} >= $min_clout }
		keys %tagname_clout;

	# Sort by sum of normalized clout and (opposite of) last-seen time.
	my %tagname_sum = (
			map
			{ ($_, $tagname_clout{$_}/$max_clout - $tagname_mediansqrtsecsago{$_}/$max_sqrtsecs) }
			@tagnames
		);
	@tagnames = sort { $tagname_sum{$b} <=> $tagname_sum{$a} || $a cmp $b } @tagnames;

	$#tagnames = $max_num-1 if $#tagnames >= $max_num;

	return \@tagnames;
}

sub listTagnamesRecent {
	my($self, $options) = @_;
	my $constants = getCurrentStatic();
	$options = { } if !$options || !ref $options;
	my $seconds =         $options->{seconds}         || (3600*6);
	my $include_private = $options->{include_private} || 0;
	my $private_clause = $include_private ? '' : " AND private='no'";

	# Previous versions of this method grabbed tagname string along
	# with tagnameid, and did a LEFT JOIN on tagname_params to exclude
	# tagname_params with tagname_clout=0.  Its performance was
	# acceptable up to about 50K tags, on the order of 1 tag insert/sec
	# at the time interval used.  But performance fell off a cliff
	# somewhere before 300K tags.  So I'm optimizing this to do an
	# initial select of more-raw data from the DB and then do a
	# second and third select to grab the full data set needed.
	# Early testing suggests this runs at least 10x faster.
	# - Jamie 2008-08-28

	my $tagnameids_ar = $self->sqlSelectColArrayref(
		'DISTINCT tags.tagnameid',
		"users_info, tags LEFT JOIN tag_params
			ON (tags.tagid=tag_params.tagid AND tag_params.name='tag_clout')",
		"inactivated IS NULL
		 $private_clause
		 AND tags.created_at >= DATE_SUB(NOW(), INTERVAL $seconds SECOND)
		 AND (tag_params.value IS NULL OR tag_params.value > 0)
		 AND tags.uid=users_info.uid AND users_info.tag_clout > 0"
	);

	# Eliminate any tagnameid's with a reduced tagname_clout.
	# This is probably smaller than the list of distinct tagnames
	# used in the past n hours, so it's probably faster (and should
	# never be noticeably slower) to grab them all and do a difference
	# on the two lists in perl instead of SQL.
	# XXX Not sure whether it's the best thing here to exclude all
	# tagnames with even slightly-reduced clout, but I think so.
	# Those tagnames probably aren't ones that would be valuable to
	# see in a list of recent tags.
	my $tagnameids_noclout_ar = $self->sqlSelectColArrayref(
		'tagnameid',
		'tagname_params',
		"name='tag_clout' AND value+0 < 1");
	my %noclout = ( map { $_, 1 } @$tagnameids_noclout_ar );
	$tagnameids_ar = [ grep { ! $noclout{$_} } @$tagnameids_ar ];

	# Get the tagnames for those id's.
	my $tagnameids_str = join(',', sort { $a <=> $b } @$tagnameids_ar);
	my $recent_ar = $self->sqlSelectColArrayref('tagname', 'tagnames',
		"tagnameid IN ($tagnameids_str)");
	@$recent_ar = sort tagnameorder @$recent_ar;
	return $recent_ar;
}

# a sort order utility function
sub tagnameorder {
	my($a1, $a2) = $a =~ /(^\!)?(.*)/;
	my($b1, $b2) = $b =~ /(^\!)?(.*)/;
	$a2 cmp $b2 || $a1 cmp $b1;
}

{ # closure
my $tagname_cache_lastcheck = 1;
sub listTagnamesByPrefix {
	my($self, $prefix_str, $options) = @_;
	my $constants = getCurrentStatic();
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $ret_hr;

	my $mcd = undef;
	$mcd = $self->getMCD() unless $options;
	my $mcdkey = "$self->{_mcd_keyprefix}:tag_prefx:";
	if ($mcd) {
		$ret_hr = $mcd->get("$mcdkey$prefix_str");
		return $ret_hr if $ret_hr;
	}

	# If the tagname_cache table has been filled, use it.
	# Otherwise, perform an expensive query directly.
	# The logic is that $tagname_cache_lastcheck stays a
	# large positive number (a timestamp) until we determine
	# that the table _does_ have rows, at which point that
	# number drops to 0.  Once its value hits 0, it is never
	# checked again.
	if ($tagname_cache_lastcheck > 0 && $tagname_cache_lastcheck < time()-3600) {
		my $rows = $reader->sqlCount('tagname_cache');
		$tagname_cache_lastcheck = $rows ? 0 : time;
	}
	my $use_cache_table = $tagname_cache_lastcheck ? 0 : 1;
	if ($use_cache_table) {
		$ret_hr = $self->listTagnamesByPrefix_cache($prefix_str, $options);
	} else {
		$ret_hr = $self->listTagnamesByPrefix_direct($prefix_str, $options);
	}

	if ($mcd) {
		# The expiration we use is much longer than the tags_cache_expire
		# var since the cache data changes only once a day.
		$mcd->set("$mcdkey$prefix_str", $ret_hr, 3600);
	}

	return $ret_hr;
}
}

# This is a quick-and-dirty (and not very accurate) estimate which
# is only performed for a site which has not built its tagname_cache
# table yet.  Hopefully most sites will use this the first day the
# Tags plugin is installed and then never again.

sub listTagnamesByPrefix_direct {
	my($self, $prefix_str, $options) = @_;
	my $constants = getCurrentStatic();
	my $like_str = $self->sqlQuote("$prefix_str%");
	my $minc = $self->sqlQuote($options->{minc} || $constants->{tags_prefixlist_minc} ||  4);
	my $mins = $self->sqlQuote($options->{mins} || $constants->{tags_prefixlist_mins} ||  3);
	my $num  = $options->{num}  || $constants->{tags_prefixlist_num};
	$num = 10 if !$num || $num !~ /^(\d+)$/ || $num < 1;

	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $ar = $reader->sqlSelectAllHashrefArray(
		'tagname,
		 COUNT(DISTINCT tags.uid) AS c,
		 SUM(tag_clout * IF(value IS NULL, 1, value)) AS s,
		 COUNT(DISTINCT tags.uid)/3 + SUM(tag_clout * IF(value IS NULL, 1, value)) AS sc',
		'tags, users_info, tagnames
		 LEFT JOIN tagname_params USING (tagnameid)',
		"tagnames.tagnameid=tags.tagnameid
		 AND tags.uid=users_info.uid
		 AND tagname LIKE $like_str",
		"GROUP BY tagname
		 HAVING c >= $minc AND s >= $mins
		 ORDER BY sc DESC, tagname ASC
		 LIMIT $num");
	my $ret_hr = { };
	for my $hr (@$ar) {
		$ret_hr->{ $hr->{tagname} } = $hr->{sc};
	}
	return $ret_hr;
}

sub listTagnamesByPrefix_cache {
	my($self, $prefix_str, $options) = @_;
	my $constants = getCurrentStatic();
	my $like_str = $self->sqlQuote("$prefix_str%");
	my $num  = $options->{num}  || $constants->{tags_prefixlist_num};
	$num = 10 if !$num || $num !~ /^(\d+)$/ || $num < 1;

	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $ret_hr = $reader->sqlSelectAllKeyValue(
		'tagname, weight',
		'tagname_cache',
		"tagname LIKE $like_str",
		"ORDER BY weight DESC LIMIT $num");
	return $ret_hr;
}

sub getPrivateTagnames {
	my($self) = @_;
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();

	my @private_tags = qw( metanod metanix );
	push @private_tags, ($constants->{tags_upvote_tagname} || "nod");
	push @private_tags, ($constants->{tags_downvote_tagname} || "nix");
	if ($user->{is_admin}) {
		push @private_tags, "quik", "hold", split(/\|/, $constants->{tags_admin_private_tags});
		if($constants->{submit_categories} && @{$constants->{submit_categories}}) {
			push @private_tags, @{$constants->{submit_categories}};
		}
	}
	my %private_tagnames = map {lc($_) => 1} @private_tags;
	return \%private_tagnames;
}

sub logSearch {
	my($self, $query, $options) = @_;
	$query =~ s/[^A-Z0-9'. :\/_]/ /gi; # see Search.pm _cleanQuery()
	my @poss_tagnames = split / /, $query;
	my $uid = $options->{uid} || getCurrentUser('uid');
	for my $tagname (@poss_tagnames) {
		my $tagnameid = $self->getTagnameidFromNameIfExists($tagname);
		next unless $tagnameid;
		$self->sqlInsert('tags_searched', {
			tagnameid =>	$tagnameid,
			-searched_at =>	'NOW()',
			uid =>		$uid,
		}, { delayed => 1 });
	}
}

sub markViewed {
	my($self, $uid, $globjid) = @_;
	return 0 if isAnon($uid) || !$globjid;
	$self->sqlInsert('globjs_viewed', {
		uid        => $uid,
		globjid    => $globjid,
		-viewed_at => 'NOW()',
	}, { ignore => 1, delayed => 1 });
}

sub getRecentTagnamesOfInterest {
	my($self, $options) = @_;
	my $constants = getCurrentStatic();
	my $max_num = $options->{max_num} || 10;
	my $min_weight = $options->{min_weight} || 1;

	# First, collect the list of all tagnames used recently.
	my $secsback = $options->{secsback} || 12 * 3600;
	my $tagname_recent_ar = $self->listTagnamesRecent({ seconds => $secsback });
	# If none, short-circuit out.
	return [ ] if !@$tagname_recent_ar;

	# Get their tagnameids.
	my $tagname_str = join(',', map { $self->sqlQuote($_) } sort @$tagname_recent_ar);
	my $tagnameid_to_name = $self->sqlSelectAllKeyValue(
		'tagnameid, tagname',
		'tagnames',
		"tagname IN ($tagname_str)");
	my $tagnameid_recent_ar = [ sort { $a <=> $b } keys %$tagnameid_to_name ];
	my $tagname_to_id = { reverse %$tagnameid_to_name };

	# Heuristic to optimize the selection process.  Right now we have
	# a list of many tagnameids (say, around 1000), most of which are
	# not new (were used prior to the time interval in question).
	# We eliminate those known not to be new by finding the newest
	# tagnameid for the day prior to the time interval, then grepping
	# out tagnameids in our list less than that.
	#
	# That should leave us with a much shorter list which will be
	# processed much faster.  On a non-busy site or during a
	# pathological case where nobody types in any new tagnames for an
	# entire day, the worst case here is that the processing is as
	# slow as it was prior to this optimization (up to a minute or so
	# on Slashdot).
	my $tagid_secsback = $self->sqlSelect('MIN(tagid)', 'tags',
		"created_at >= DATE_SUB(NOW(), INTERVAL $secsback SECOND)")
		|| 0;
	my $secsback_1moreday = $secsback + 86400;
	my $tagid_secsback_1moreday = $self->sqlSelect('MIN(tagid)', 'tags',
		"created_at >= DATE_SUB(NOW(), INTERVAL $secsback_1moreday SECOND)")
		|| 0;
	my $max_previously_known_tagnameid = $self->sqlSelect('MAX(tagnameid)', 'tags',
		"tagid BETWEEN $tagid_secsback_1moreday AND $tagid_secsback")
		|| 0;
	$tagnameid_recent_ar = [
		grep { $_ > $max_previously_known_tagnameid }
		@$tagnameid_recent_ar ]
		if $max_previously_known_tagnameid > 0;
	my $tagnameid_str = join(',', map { $self->sqlQuote($_) } @$tagnameid_recent_ar);

	# Now do the select to find the actually-new tagnameids.
	my $tagnameid_firstrecent_ar = $self->sqlSelectColArrayref(
		'DISTINCT tagnameid',
		'tags',
		"tagid >= $tagid_secsback AND tagnameid IN ($tagnameid_str)");

	# Run through the hash we built earlier to convert ids back to names.
	my $tagname_firstrecent_ar = [
		map { $tagnameid_to_name->{$_} }
		@$tagnameid_firstrecent_ar ];
	my %tagname_firstrecent = ( map { ($_, 1) } @$tagname_firstrecent_ar );

	# Build a regex that will identify tagnames that begin with an
	# author's name, and a hash matching recent tagnames.
	my $author_names = join('|', map { "\Q\L$_\E" } @{ $self->getAuthorNames() });
	my $author_regex = qr{^($author_names)};
	my %tagname_startauthor = ( map { ($_, 1) }
		grep { $_ =~ $author_regex } @$tagname_recent_ar );

	# Build a hash identifying those tagnames which have been
	# marked by an admin, at any time, as being "ok."
	my $tagnameid_ok_ar = $self->sqlSelectColArrayref(
		'DISTINCT tagnameid',
		'tagcommand_adminlog',
		"tagnameid IN ($tagnameid_str)
		 AND cmdtype='*'");
	my %tagname_adminok = ( map { ($tagnameid_to_name->{$_}, 1) } @$tagnameid_ok_ar );

	# Build a hash identifying those tagnames which have been
	# marked by an admin, at any time, as being bad (# etc.).
	my $tagnameid_bad_ar = $self->sqlSelectColArrayref(
		'DISTINCT tagnameid',
		'tagcommand_adminlog',
		"tagnameid IN ($tagnameid_str)
		 AND cmdtype REGEXP '#'");
	my %tagname_bad = ( map { ($tagnameid_to_name->{$_}, 1) } @$tagnameid_bad_ar );

	# Build a hash identifying topic tagnames.
	my $topics = $self->getTopics();
	my %tagname_topic = ( map { ($topics->{$_}{keyword}, 1) } keys %$topics );

	# Using the hashes, build a list of all recent tagnames which
	# are of interest.
	my @tagnames_of_interest = grep {
		   !$tagname_adminok{$_}
		&& !$tagname_topic{$_}
		&& (	   $tagname_bad{$_}
			|| $tagname_startauthor{$_}
			|| $tagname_firstrecent{$_}
		)
	} @$tagname_recent_ar;
	return [ ] if !@tagnames_of_interest;
	my @tagnameids_of_interest = map { $tagname_to_id->{$_} } @tagnames_of_interest;
	my $tagnameids_of_interest_str = join(',', map { $self->sqlQuote($_) }
		sort @tagnameids_of_interest);

	# Now sort the tagnames in order of the sum of their current
	# weights.  Exclude those with sum weight 0, because there's
	# no need for admins to evaluate those.
	my $tags_ar = $self->sqlSelectAllHashrefArray(
		'*',
		'tags',
		"tagnameid IN ($tagnameids_of_interest_str)
		 AND tagid >= $tagid_secsback");
	$self->addCloutsToTagArrayref($tags_ar);
	my %tagnameid_weightsum = ( );
	my %t_globjid_weightsum = ( );
	# Admins will care less about new tagnames applied to data types other
	# than stories, and less about poorly scored items.  Downweight tags
	# on such objects.
	my %type_wmult = ( submissions => 0.6, journals => 0.4, urls => 0.2 );
	my $firehose = getObject('Slash::FireHose');
	my $fh_min_score;
	if ($firehose) {
		$fh_min_score = $firehose->getMinPopularityForColorLevel($constants->{tags_rectn_mincare} || 5);
	}
	my $target_hr = $self->getGlobjTargets([ map { $_->{globjid} } @$tags_ar ]);
	for my $tag_hr (@$tags_ar) {
		my $tc = $tag_hr->{total_clout};
		next unless $tc;
		my $tagnameid = $tag_hr->{tagnameid};
		my $globjid = $tag_hr->{globjid};
		my $type = $target_hr->{$globjid}[0];
		if ($firehose) {
			my $fhid = $firehose->getFireHoseIdFromGlobjid($globjid);
			my $item = $firehose->getFireHose($fhid) if $fhid;
			$tc *= $constants->{tags_rectn_nocaremult}
				if $item && $item->{userpop} < $fh_min_score;
		}
		next unless $tc;
		$tc *= ($type_wmult{$type} || 1);
		$tagnameid_weightsum{ $tagnameid } ||= 0;
		$tagnameid_weightsum{ $tagnameid }  += $tc;
		$t_globjid_weightsum{ $tagnameid }{ $globjid } ||= 0;
		$t_globjid_weightsum{ $tagnameid }{ $globjid }  += $tc;
	}
	my @tagnameids_top =
		sort { $tagnameid_weightsum{$b} <=> $tagnameid_weightsum{$a}
			|| $b <=> $a }
		grep { $tagnameid_weightsum{$_} >= $min_weight }
		keys %tagnameid_weightsum;
	$#tagnameids_top = $max_num-1 if $#tagnameids_top > $max_num;

	# Now we just have to construct the data structure to return.
	my @rtoi = ( );
	my %globjid_linktext = ( );
	my $linktext_next = 'a'; # label the links simply 'a', 'b', etc.
	for my $tagnameid (@tagnameids_top) {
		my @globjids =
			sort { $t_globjid_weightsum{$tagnameid}{$b} <=> $t_globjid_weightsum{$tagnameid}{$a}
				|| $b <=> $a }
			keys %{$t_globjid_weightsum{$tagnameid}};
		$#globjids = $max_num-1 if $#globjids > $max_num;
		my @globjid_data = ( );
		for my $globjid (@globjids) {
			my $lt = $globjid_linktext{$globjid} || '';
			if (!$lt) {
				$lt = $globjid_linktext{$globjid} = $linktext_next;
				++$linktext_next;
			}
			push @globjid_data, {
				globjid => $globjid,
				linktext => $lt,
			};
		}
		$self->addGlobjEssentialsToHashrefArray(\@globjid_data);
		push @rtoi, {
			tagname =>	$tagnameid_to_name->{$tagnameid},
			globjs =>	\@globjid_data,
		};
	}

	return \@rtoi;
}

sub showRecentTagnamesBox {
	my($self, $options) = @_;
	$options ||= {};

	my $text = " ";
	
	unless ($options->{box_only}) {
		my $rtoi_ar = $self->getRecentTagnamesOfInterest();
		$text = slashDisplay('recenttagnamesbox', {
			rtoi => $rtoi_ar,
		}, { Return => 1 });
	}

	return $text if $options->{contents_only};

	my $updater = getData('recenttagnamesbox_js', { }, 'tags') if $options->{updater};
	slashDisplay('sidebox', {
		updater		=> $updater,
		title		=> 'Recent Tagnames',
		contents	=> $text,
		name		=> 'recenttagnames',
	}, { Return => 1 });
}

sub ajax_recenttagnamesbox {
	my $tagsdb = getObject("Slash::Tags");
	$tagsdb->showRecentTagnamesBox({ contents_only => 1});
}

sub getTagnameidsByParam {
	my($self, $name, $value) = @_;
	return $self->sqlSelectColArrayref('tagnameid', 'tagname_params',
		'name=' . $self->sqlQuote($name),
		'AND value=' . $self->sqlQuote($value)
	);
}

sub getTagnamesByParam {
	my($self, $name, $value) = @_;
	my $tagnameids = $self->getTagnameidsByParam($name, $value);
	return [ map { $self->getTagnameDataFromId($_)->{tagname} } @$tagnameids ];
}

sub getPopupTags {
	my($self) = @_;
	return $self->getTagnamesByParam('popup', '1');
}

sub limitToPopupTags {
	my($self, $tags) = @_;
	my $pop = $self->getPopupTags;

	my %tags = map { $_ => 0 } @$tags;
	for (@$pop) {
		$tags{$_} = 1 if exists $tags{$_};
	}
	$tags{$_} or delete $tags{$_} for keys %tags;
	@$tags = keys %tags;
}

sub getNegativePopupTags {
	my($self) = @_;
	my $neg = $self->getNegativeTags;
	$self->limitToPopupTags($neg);
	return $neg;
}

sub getPositivePopupTags {
	my($self) = @_;
	my $pos = $self->getPositiveTags;
	$self->limitToPopupTags($pos);
	return $pos;
}

sub getExcludedTags {
	my($self) = @_;
	return $self->getTagnamesByParam('exclude', '1');
}

sub getNegativeTags {
	my($self) = @_;
	return $self->getTagnamesByParam('posneg', '-');
}

sub getPositiveTags {
	my($self) = @_;
	return $self->getTagnamesByParam('posneg', '+');
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

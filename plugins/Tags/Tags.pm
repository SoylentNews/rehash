# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Tags;

use strict;
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

# createTag takes a hashref with four sets of named arguments.
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
# At present, no other named arguments are permitted.
#
# This method takes care of creating the tagname and/or globj, if they
# do not already exists, so that the tag may connect them.
#
# By default, this does not allow the same user to apply the same
# tagname to the same global object twice.  Pass the option hashref
# field 'dupe_ok' with a true value to ignore this check.

sub createTag {
        my($self, $hr, $options) = @_;

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

	my $check_dupe = (!$options || !$options->{dupe_ok});
	if ($check_dupe) {
		# Check to make sure this user hasn't already tagged
		# this object with this tagname.  We do this by, in
		# a transaction, doing the insert and checking to see
		# whether there are 1 or more rows in the table
		# preceding the one just inserted with matching the
		# criteria.  If so, the insert is rolled back and
		# 0 is returned.
		$self->sqlDo('SET AUTOCOMMIT=0');
	}

        my $rows = $self->sqlInsert('tags', $tag);

	if ($check_dupe) {
		my $tagid = $self->getLastInsertId();
		# Because of the uid_globjid_tagnameid index, this
		# should, I believe, not even touch table data, so
		# it should be very fast.
		my $count = $self->sqlCount('tags',
			"uid		= $tag->{uid}
			 AND globjid	= $tag->{globjid}
			 AND tagnameid	= $tag->{tagnameid}
			 AND tagid < $tagid");
		if ($count == 0) {
			# This is the only tag, it's allowed.
			$self->sqlDo('COMMIT');
		} else {
			# Duplicate tag, not allowed.
			$self->sqlDo('ROLLBACK');
			$rows = 0;
		}
		# Return AUTOCOMMIT to its original state in any case.
		$self->sqlDo('SET AUTOCOMMIT=1');
	}

        return $rows ? 1 : 0;
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

# Given a tagnameid, get its name, e.g. turn '17241' into 'omglol'.
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
# global object.  If the option uid is passed in, the returned
# tags will also be limited to those created by that uid.

sub getTagsByNameAndIdArrayref {
	my($self, $name, $target_id, $options) = @_;
	my $globjid = $self->getGlobjidFromTargetIfExists($name, $target_id);
	return [ ] unless $globjid;

	my $uid_where = '';
	if ($options->{uid}) {
		my $uid_q = $self->sqlQuote($options->{uid});
		$uid_where = " AND uid=$uid_q";
	}

	my $ar = $self->sqlSelectAllHashrefArray(
		'*',
		'tags',
		"globjid=$globjid$uid_where",
		'ORDER BY tagid');

	# Now add an extra field to every element returned:  the
	# tagname, as well as tagnameid.
	$self->addTagnamesToHashrefArray($ar);
	return $ar;
}

sub getAllTagsFromUser {
	my($self, $uid) = @_;
	return [ ] unless $uid;

	my $uid_q = $self->sqlQuote($uid);
	my $ar = $self->sqlSelectAllHashrefArray(
		'*',
		'tags',
		"uid = $uid_q",
		'ORDER BY tagid');
	return [ ] unless $ar && @$ar;
	$self->addTagnamesToHashrefArray($ar);
	return $ar;
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
		"tagnameid=$id");
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
	$self->setVar('tags_stories_lastscanned', $min_tagid - 1) if $min_tagid;
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
	my($self, $tagname) = @_;
	return 0 if substr($tagname, 0, 1) !~ /^[\&\_\#]$/;
	return $self->tagnameSyntaxOK(substr($tagname, 1));
}

sub ajaxGetUserStory {
	my($self, $constants, $user, $form) = @_;
	use Data::Dumper;
	print STDERR scalar(localtime) . " ajaxGetUserStory called, form: " . Dumper($form);

	my $stoid = $form->{stoid};
	my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });
use Data::Dumper;
print STDERR scalar(localtime) . " ajaxGetUserStory stoid='$stoid' user-is_anon='$user->{is_anon}' uid='$user->{uid}' tags_reader='$tags_reader' form: " . Dumper($form);
	if (!$stoid || $stoid !~ /^\d+$/ || $user->{is_anon} || !$tags_reader) {
		return getData('error', {}, 'tags');
	}
	my $uid = $user->{uid};

	my @newtagspreload =
		grep { $tags_reader->tagnameSyntaxOK($_) }
		split /[\s,]+/,
		($form->{newtagspreloadtext} || '');
	my $newtagspreloadtext = join ' ', @newtagspreload;

	my $tags_ar = $tags_reader->getTagsByNameAndIdArrayref('stories', $stoid, { uid => $uid });
	my @tags = sort map { $_->{tagname} } @$tags_ar;
print STDERR scalar(localtime) . " tagsGetUserStory for stoid=$stoid uid=$uid tags: '@tags' tags_ar: " . Dumper($tags_ar);
	my $tags_user_str = getData('tags_user', { tags => \@tags }, 'tags');

	return slashDisplay('tagsstorydivuser', {
		stoid =>		$stoid,
		tags_user_str =>	$tags_user_str,
		newtagspreloadtext =>	$newtagspreloadtext,
	}, { Return => 1 });
}

sub ajaxGetAdminStory {
	my($self, $constants, $user, $form) = @_;
	my $stoid = $form->{stoid};
	if (!$stoid || $stoid !~ /^\d+$/ || !$user->{is_admin}) {
		return getData('error', {}, 'tags');
	}

	return slashDisplay('tagsstorydivadmin', {
		stoid =>		$stoid,
		tags_admin_str =>	'',
	}, { Return => 1 });
}

sub ajaxCreateForStory {
	my($slashdb, $constants, $user, $form) = @_;
	my $stoid = $form->{stoid};
	my $tags = getObject('Slash::Tags');
print STDERR scalar(localtime) . " ajaxCreateForStory 1 stoid='$stoid' user-is='$user->{is_anon}' uid='$user->{uid}' tags='$tags'\n";
	if (!$stoid || $stoid !~ /^\d+$/ || $user->{is_anon} || !$tags) {
		return getData('error', {}, 'tags');
	}

	my @tagnames =
		grep { $tags->tagnameSyntaxOK($_) }
		split /[\s,]+/,
		($form->{tags} || '');
print STDERR scalar(localtime) . " ajaxCreateForStory 2 tagnames='@tagnames'\n";
	if (!@tagnames) {
		return getData('tags_none_given', {}, 'tags');
	}

	my $uid = $user->{uid};
	my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });
	my $old_tags_ar = $tags_reader->getTagsByNameAndIdArrayref('stories', $stoid, { uid => $uid });

	my @saved_tagnames = ( );
	for my $tagname (@tagnames) {
		push @saved_tagnames, $tagname
			if $tags->createTag({
				uid =>          $user->{uid},
				name =>         $tagname,
				table =>        'stories',
				id =>           $stoid
			});
	}
print STDERR scalar(localtime) . " ajaxCreateForStory 3 old='@$old_tags_ar' saved='@saved_tagnames'\n";

	my @new_tags = ( (sort map { $_->{tagname} } @$old_tags_ar), @saved_tagnames );
	my $tags_user_str = getData('tags_user', { tags => \@new_tags }, 'tags');

	my $retval = slashDisplay('tagsstorydivuser', {
		stoid =>		$stoid,
		tags_user_str =>	$tags_user_str,
	}, { Return => 1 });
print STDERR scalar(localtime) . " ajaxCreateForStory 3 for stoid=$stoid tagnames='@tagnames' new_tags='@new_tags' returning: $retval\n";
	return $retval;
}

sub ajaxProcessAdminTags {
	my($self, $constants, $user, $form) = @_;
	my $commands = $form->{commands};
print STDERR scalar(localtime) . " ajaxProcessAdminTags does nothing yet; stoid=$stoid commands='$commands'\n";
	my $stoid = $form->{stoid};
	my $tags = getObject('Slash::Tags', { db_type => 'reader' });
	my @commands =
		grep { $tags->adminPseudotagnameSyntaxOK($_) }
		split /[\s,]+/,
		($commands || '');
	if (!$stoid || @commands) {
		# Error, but we really have no way to return it...
		# return getData('tags_none_given', {}, 'tags');
	}

	my $tags_admin_str = "Saw commands: '@commands'.";

	return slashDisplay('tagsstorydivadmin', {
		stoid =>		$stoid,
		tags_admin_str =>	$tags_admin_str,
	}, { Return => 1 });
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

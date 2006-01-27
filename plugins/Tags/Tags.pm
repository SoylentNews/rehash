# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Tags;

use strict;
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

# createTag takes a hashref with three sets of named arguments.
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

sub createTag {
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

        my $rows = $self->sqlInsert('tags', $tag);
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
        my $rows = $self->sqlInsert('tag_names', {
                        tagnameid =>    undef,
                        name =>         $name,
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
	return 0 unless $name =~ /$constants->{tags_name_regex}/;

	my $table_cache         = "_tagid_cache";
	my $table_cache_time    = "_tagid_cache_time";
	$self->_genericCacheRefresh('tagid', $constants->{block_expire});
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
	my $id = $self->sqlSelect('tagnameid', 'tag_names',
		"name=$name_q");
	return 0 if !$id;
	if ($self->{$table_cache_time}) {
		$self->{$table_cache}{$name} = $id;
	}
        $mcd->set("$mcdkey$name", $id, $constants->{memcached_exptime_tags}) if $mcd;
        return $id;
}

# Given a tagnameid, get its name, e.g. turn '17241' into 'omglol'.
# If no such tag ID exists, return undef.

sub getTagNameFromId {
        my($self, $id) = @_;
        my $constants = getCurrentStatic();

	my $table_cache         = "_tagname_cache";
	my $table_cache_time    = "_tagname_cache_time";
	$self->_genericCacheRefresh('tagname', $constants->{block_expire});
	if ($self->{$table_cache_time} && $self->{$table_cache}{$id}) {
		return $self->{$table_cache}{$id};
	}

        my $mcd = $self->getMCD();
        my $mcdkey = "$self->{_mcd_keyprefix}:tagname:" if $mcd;
        if ($mcd) {
                my $name = $mcd->get("$mcdkey$id");
		if ($name) {
			if ($self->{$table_cache_time}) {
				$self->{$table_cache}{$id} = $name;
			}
			return $name;
		}
        }
        my $id_q = $self->sqlQuote($id);
        my $name = $self->sqlSelect('name', 'tag_names',
                "tagnameid=$id_q");
        return undef if !$name;
	if ($self->{$table_cache_time}) {
		$self->{$table_cache}{$id} = $name;
	}
        $mcd->set("$mcdkey$id", $name, $constants->{memcached_exptime_tags}) if $mcd;
        return $name;
}

# Given a name and id, return the arrayref of all tags on that
# object.

sub getTagsByNameAndIdArrayref {
	my($self, $name, $target_id) = @_;
	my $globjid = $self->getGlobjidFromTargetIfExists($name, $target_id);
	return [ ] unless $globjid;

	my $ar = $self->sqlSelectAllHashrefArray(
		'*',
		'tags',
		"globjid=$globjid",
		'ORDER BY tagid');

	# Now add an extra field to every element returned:  the
	# tagname, as well as tagnameid.
	my %tagnameids = (
		map { ( $_->{tagnameid}, 1 ) }
		@$ar
	);
	# XXX This could/should be done more efficiently;  we need a
	# getTagNamesFromIds method to do this in bulk and take
	# advantage of get_multi and put all the sqlSelects together.
	my %tagnames = (
		map { ( $_, $self->getTagNameFromId($_) ) }
		keys %tagnameids
	);
	for my $hr (@$ar) {
		$hr->{tagname} = $tagnames{ $hr->{tagnameid} };
	}
	return $ar;
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

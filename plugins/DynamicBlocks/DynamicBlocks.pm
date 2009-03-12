# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2009 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::DynamicBlocks;

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

# Update an existing block
sub setBlock {
        my ($self, $block) = @_;

        return if (!$block);

        my $slashdb = getCurrentDB();
        my $data = {};
        $data->{'block'} = $block->{block};
        $data->{'-last_update'} = 'NOW()';
        $slashdb->sqlUpdate('dynamic_user_blocks', $data, "name = " . $slashdb->sqlQuote($block->{'name'}));
}

# Returns all portal blocks.
sub getPortalBlocks {
        my ($self, $keyed_on, $options) = @_;

        my $slashdb = getCurrentDB();

        my $block_definition = $self->getBlockDefinition('', { type => 'portal', private => 'no'});
        my $where_clause = "type_id = '" . $block_definition->{type_id} . "'";
        if ($options->{uid}) {
                $where_clause .= " and uid = '" . $options->{uid} . "'";
        } else {
                $where_clause .= " and uid = '0'";
        }

        my $blocks = $slashdb->sqlSelectAllHashref($keyed_on, '*', 'dynamic_user_blocks', $where_clause);
        foreach my $block (keys %$blocks) {
                $blocks->{$block}{type} = $block_definition->{type};
                $blocks->{$block}{private} = $block_definition->{private};

                ($blocks->{$block}{block}, $blocks->{$block}{title}, $blocks->{$block}{url}) =
                        $self->getPortalBlockContent($blocks->{$block}{bid}, $slashdb);
        }

        return (keys %$blocks) ? $blocks : 0;
}

# Returns a hash of a particular user's friends' blocks.
# Does not return any admin blocks.
sub getFriendBlocks {
        my ($self, $keyed_on, $uid, $options) = @_;

        my $zoo = getObject("Slash::Zoo", { db_type => 'reader' });
        return 0 if !$zoo;

        my $friends = $zoo->getRelationships($uid, 1);
        my $blocks;
        foreach my $friend (@$friends) {
                my $friend_blocks = $self->getUserBlocks($keyed_on, $friend->[0], { friend => 1 });
                if ($friend_blocks) {
                        foreach my $friend_block (keys %$friend_blocks) {
                                $blocks->{$friend_block} = %$friend_blocks->{$friend_block};
                        }
                }
        }

        return (keys %$blocks) ? $blocks : 0;
}

# Returns a hash of a particular user's blocks.
# Includes their public and private admin blocks if they are an admin.
sub getUserBlocks {
        my ($self, $keyed_on, $uid, $options) = @_;

        my $slashdb = getCurrentDB();
        my $blocks;

        my $where_clause = "uid = '$uid'";
	# Only include public user and portal boxes if it's a friend lookup.
	if ($options->{friend}) {
                my $user_def = $self->getBlockDefinition('', { type => 'user', private => 'no'});
                my $portal_def = $self->getBlockDefinition('', { type => 'portal', private => 'no'});
                $where_clause .= ' and type_id IN(';
                $where_clause .= $user_def->{type_id} . ',' . $portal_def->{type_id};
                $where_clause .= ')';
        }

        my $user_blocks = $slashdb->sqlSelectAllHashref($keyed_on, '*', 'dynamic_user_blocks', $where_clause);

        my $user = $slashdb->getUser($uid);
        my $admin_blocks;
        if ($user->{seclev} >= 1000 and !$options->{friend}) {
                my $block_definition = $self->getBlockDefinition('', { type => 'admin', private => 'no'});
                my $where_clause = "type_id = '" . $block_definition->{type_id} . "'";
                $admin_blocks = $slashdb->sqlSelectAllHashref($keyed_on, '*', 'dynamic_user_blocks', $where_clause);
        }

        foreach my $admin_block (keys %$admin_blocks) {
                $admin_blocks->{$admin_block}{type} = 'admin';
                $blocks->{$admin_block} = $admin_blocks->{$admin_block};
        }

        foreach my $user_block (keys %$user_blocks) {
                my $block_definition = $self->getBlockDefinition($user_blocks->{$user_block}{type_id});
                $user_blocks->{$user_block}{type} = $block_definition->{type};
                $user_blocks->{$user_block}{private} = $block_definition->{private};

                if ($block_definition->{type} eq 'portal') {
                        ($user_blocks->{$user_block}{block}, $user_blocks->{$user_block}{title}, $user_blocks->{$user_block}{url}) =
                                $self->getPortalBlockContent($user_blocks->{$user_block}{bid}, $slashdb);
                }

                $blocks->{$user_block} = $user_blocks->{$user_block};
        }

        return (keys %$blocks) ? $blocks : 0;
}

# Returns the 3 main fields not normally mirrored in 'dynamic_user_blocks'
sub getPortalBlockContent {
        my ($self, $id, $slashdb) = @_;

        my @block_data = $slashdb->sqlSelect('block, title, url', 'blocks', "id = $id");
        return @block_data;
}

# Returns a hash describing a block type
# e.g. private/user, public/admin, public/portal
# 
# getBlockDefinition($type_id)
# getBlockDefinition("", { type => "admin", private => "no" })
# getBlockDefinition("", { type => "user", private => "yes" })
sub getBlockDefinition {
        my ($self, $id, $options) = @_;

        return 0 if !$id and !$options;

        my $slashdb = getCurrentDB();

        my $block_definition;
        my $where;
        if ($id) {
                $where .= "type_id = $id";
        } else {
                $where .= "private = '" . $options->{private} . "'";
                $where .= " and type = '" . $options->{type} . "'" if ($options->{type});
                $where .= " and type_id = " . $options->{type_id} if ($options->{type_id});
        }

        ($block_definition->{type_id}, $block_definition->{type}, $block_definition->{private}) =
                $slashdb->sqlSelect('type_id, type, private', 'dynamic_blocks', $where);

        return ($block_definition->{type_id}) ? $block_definition : 0;

}

# This is called periodically by certain tasks.
# It syncs 'blocks' and 'dynamic_user_blocks, but does
# not mirror certain fields (block, url, title).
sub syncPortalBlocks {
        my ($self, $name, $options) = @_;

        return if (!$name && !$options);

        my $slashdb = getCurrentDB();

        my $portal_block_definition = $self->getBlockDefinition('', { type => "portal", private => "no" } );

        my $names;
        if (!$name && $options->{all}) {
                $names = $slashdb->sqlSelectColArrayref('bid', 'blocks');
        } else {
                $names = [$name];
        }

        foreach my $name (@$names) {
                my $block_data;
                ($block_data->{id}, $block_data->{last_update},
                 $block_data->{shill_uid}, $block_data->{seclev}) =
                        $slashdb->sqlSelect('id, last_update, shill_uid, seclev', 'blocks', "bid = '$name'");

		# Check if this block already exists in dynamic_user_blocks
		my $dynb_id = $slashdb->sqlSelect('id', 'dynamic_user_blocks', "bid = " . $block_data->{id});

                my $data;
                if (!$dynb_id) {
                        $data = {
                                "bid"         => $block_data->{id},
                                "type_id"     => $portal_block_definition->{type_id},
                                "uid"         => $block_data->{shill_uid},
                                "name"        => $name,
                                "seclev"      => $block_data->{seclev},
                                "created"     => $block_data->{last_update},
                                "last_update" => $block_data->{last_update},
                        };
                        $slashdb->sqlInsert('dynamic_user_blocks', $data);
                } else {
                        $data = {
                                "last_update" => $block_data->{last_update}
                        };
                        $slashdb->sqlUpdate('dynamic_user_blocks', $data, "id = " . $dynb_id);
                }
        }
}

# Returns: a hash of blocks which have been updated between $options->{min_time} and now().
# Will return 0 on error or if no blocks will be updated.
# This will normally be used with an Ajax call. 
#
# $list: a comma delimited list of blocks to check.
# $options->{min_time}: yyyy-mm-dd hh:mm:ss format. The base time for which you'd like
# to check for updates.
#
# getBlocksEligibleForUpdate("foo,bar", { min_time => 'yyyy-mm-dd hh:mm:ss' });
sub getBlocksEligibleForUpdate {
        my ($self, $list, $options) = @_;

        my $constants = getCurrentStatic();
        return 0 if (!$constants->{dynamic_blocks} || !$options->{min_time} || !$options->{is_admin});

        my $slashdb = getCurrentDB();
        my $min_time = $options->{min_time};
        my $dynamic_blocks;
        foreach my $block (split(/,/, $list)) {
		# Need better use of an exclusion list here.
		next if ($block eq 'index_jobs');

		my ($bid, $type_id) = $slashdb->sqlSelect('bid, type_id', 'dynamic_user_blocks', "name = '$block' and last_update BETWEEN '$min_time' and NOW()");
                if ($bid) {
                        my $block_definition = $self->getBlockDefinition($type_id);

                        my ($block_data, $block_title, $block_url);
                        if ($block_definition->{type} eq "portal") {
                                ($block_data, $block_title, $block_url) =
                                        $self->getPortalBlockContent($bid, $slashdb);
                        } else {
                                ($block_data, $block_title, $block_url) =
                                        $slashdb->sqlSelect('block, title, url', 'dynamic_user_blocks', "bid = $bid");
                        }

                        if ($block_data) {
                                $dynamic_blocks->{$block}{block} = $block_data;
                                $dynamic_blocks->{$block}{title} = $block_title;
                                $dynamic_blocks->{$block}{url}   = $block_url;
                        }
                }
        }

        return (keys %$dynamic_blocks) ? $dynamic_blocks : 0;
}

sub DESTROY {
        my($self) = @_;
        $self->{_dbh}->disconnect if $self->{_dbh} && !$ENV{GATEWAY_INTERFACE};
}

1;

=head1 NAME

Slash::DynamicBlocks - Slash dynamic slashbox module

=head1 SYNOPSIS

        use Slash::DynamicBlocks;

=head1 DESCRIPTION

This contains all of the routines currently used by DynamicBlocks.

=head1 SEE ALSO

Slash(3).

=cut

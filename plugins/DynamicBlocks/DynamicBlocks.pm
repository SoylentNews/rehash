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

# Returns: a hash of blocks which have been updated between $options->{min_time} and now().
#       Will return 0 on error or if no blocks will be updated.
#
# $list: a comma delimited list of blocks to check.
# $options->{min_time}: yyyy-mm-dd hh:mm:ss format. The base time for which you'd like
#       to check for updates.
#
# getBlocksEligibleForUpdate("foo,bar", { min_time => 'yyyy-mm-dd hh:mm:ss' });
#
# This method eventually needs to use dynamic_user_blocks, not blocks.
sub getBlocksEligibleForUpdate {
        my ($self, $list, $options) = @_;

        my $constants = getCurrentStatic();
        return 0 if (!$constants->{dynamic_blocks} || !$options->{min_time} || !$options->{is_admin});

        my $slashdb = getCurrentDB();
        my $min_time = $options->{min_time};
        my $dynamic_blocks;
        foreach my $block (split(/,/, $list)) {
		# Need better use of an exclusion list here.
		next if ($block eq 'index_poll');

                my ($block_data, $block_title, $block_url) =
                        $slashdb->sqlSelect('block, title, url', 'blocks', "bid = '$block' and last_update BETWEEN '$min_time' and NOW()");

                if ($block_data) {
                        $dynamic_blocks->{$block}{block} = $block_data;
                        $dynamic_blocks->{$block}{title} = $block_title;
                        $dynamic_blocks->{$block}{url}   = $block_url;
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

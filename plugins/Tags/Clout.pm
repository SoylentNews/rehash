# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Clout;

use strict;
use warnings;
use Slash;
use Slash::Tags;
#use Slash::Clout::Describe;
#use Slash::Clout::Vote;
#use Slash::Clout::Moderate;

use base 'Slash::DB::Utility';
use base 'Slash::DB'; # hm, should this be Slash::DB::MySQL? either way it should be documented why. -Jamie

our $VERSION = $Slash::Constants::VERSION;

sub init {
	my($self) = @_;

warn "Clout.pm calling SUPER::init for $self: " . ($self->can('SUPER::init') ? 1 : 0);
	$self->SUPER::init() if $self->can('SUPER::init');
warn "Clout.pm called SUPER::init for $self";

	$self->{months_back} = 2; # default
	my $slashdb = getCurrentDB();
        my $info = $slashdb->getCloutInfo();
        for my $clid (keys %$info) {
                $self->{clid} = $clid if $info->{$clid}{class} eq ref($self);
        }
        warn "cannot find clid for $self" if !$self->{clid};

	my $constants = getCurrentStatic();
	my $tagsdb = getObject('Slash::Tags');
	$self->{nodid} = $tagsdb->getTagnameidCreate($constants->{tags_upvote_tagname}   || 'nod');
	$self->{nixid} = $tagsdb->getTagnameidCreate($constants->{tags_downvote_tagname} || 'nix');
	1;
}

1;


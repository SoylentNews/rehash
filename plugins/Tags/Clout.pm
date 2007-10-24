# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Clout;

use strict;
use warnings;
use Slash;
use Slash::Utility;
use Slash::Tags;
#use Slash::Clout::Describe;
#use Slash::Clout::Vote;
#use Slash::Clout::Moderate;

use base 'Slash::DB::Utility';
use base 'Slash::DB';

use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub init {
	my($self) = @_;

	$self->{months_back} = 4; # default
	my $slashdb = getCurrentDB();
        my $info = $slashdb->getCloutInfo();
        for my $clid (keys %$info) {
                $self->{clid} = $clid if $info->{$clid}{class} eq ref($self);
        }
        warn "cannot find clid for $self" if !$self->{clid};

	my $constants = getCurrentStatic();
	my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });
	$self->{nodid} = $tags_reader->getTagnameidCreate($constants->{tags_upvote_tagname}   || 'nod');
	$self->{nixid} = $tags_reader->getTagnameidCreate($constants->{tags_downvote_tagname} || 'nix');
	1;
}

#sub insert_nextgen {
#        my($g, $insert_ar) = @_;
#        my $slashdb = getCurrentDB();
#        for my $hr (@$insert_ar) {
#                $hr->{gen} = $g; 
#                $slashdb->sqlInsert('tags_peerweight', $hr);
#        }
#}       
#        
#sub update_tags_peerweight {
#        my($insert_ar) = @_;
#        for my $hr (@$insert_ar) {
#                $tags_peerweight->{ $hr->{uid} } = $hr->{weight}; 
#        } 
#}               
#                
#sub B_copy_peerweight_sql {
#        my $slashdb = getCurrentDB();
#        $slashdb->sqlDo("SET AUTOCOMMIT=0");
#        $slashdb->sqlDo("DELETE FROM users_param WHERE name='tagpeerval2'");
#        $slashdb->sqlDo("INSERT INTO users_param SELECT NULL, uid, 'tagpeerval2', ROUND(weight,6)+0 FROM tags_peerweight");
#        $slashdb->sqlDo("COMMIT");
#        $slashdb->sqlDo("SET AUTOCOMMIT=1");
#}

1;


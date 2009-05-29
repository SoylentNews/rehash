# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

# This overrides Games::WoW::Armory to fix some bugs.

package Slash::Custom::WoWArmory;

use strict;
use Carp qw( croak );
use base 'Games::WoW::Armory';
use vars qw($VERSION);

use Games::WoW::Armory;

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub fetch_data {
    my ( $self, $params ) = @_;
    $self->{ ua } = LWP::UserAgent->new() || croak $!;
    $self->{ ua }->agent(
        "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.1.1) Gecko/20061204 Firefox/2.0.0.1"
    );

    my $base_url;
    if ( $$params{ country } =~ /eu/i ) {
        $base_url = $Games::WoW::Armory::WOW_EUROPE;
    }
    elsif ( $$params{ country } =~ /us/i ) {
        $base_url = $Games::WoW::Armory::WOW_US;
    }
    else {
        croak "Unknown region code, please choose US or EU";
    }

    if ( defined $$params{ team } ) {
        $self->url( $base_url
                . $$params{ xml } . "?r="
                . $$params{ realm } . "&ts="
                . $$params{ ts } . "&t="
                . $$params{ team } );

    }
    else {
        $self->url( $base_url
                . $$params{ xml } . "?r="
                . $$params{ realm } . "&n="
                . $$params{ name } );

    }

    $self->{ resultat } = $self->{ ua }->get( $self->url );

    $self->{ xp }   = XML::Simple->new;
    $self->{ data } = undef;
    if ($self->{ resultat }->is_success()) {
	my $content = $self->{ resultat }->content;
	eval {
	    $self->{ data } = $self->{ xp }->XMLin( $content );
	};
	if ($@) {
	    my $err = $@;
	    chomp $err; $err =~ s/\s+/ /g;
	    my $context = 'unknown';
	    if (my($bytepos) = $err =~ /\bbyte (\d+)\b/) {
		my $start = $bytepos - 30; $start = 0 if $start < 0;
		my $len   =            60; $len = length($content)-$start if $start+$len > length($content);
		$context = substr($content, $start, $len);
		$context =~ s{\s+}{ }g;
	    }
	    warn('XMLin failed on ' . length($content) . " bytes ('$context'): '$err'");
	}
    }
}

sub search_character {
    my ( $self, $params ) = @_;

    my $xml = 'character-sheet.xml';

    croak "you need to specify a character name"
        unless defined $$params{ character };
    croak "you need to specify a realm" unless defined $$params{ realm };
    croak "you need to specify a country name"
        unless defined $$params{ country };

    $self->fetch_data(
        {   xml     => $xml,
            realm   => $$params{ realm },
            name    => $$params{ character },
            country => $$params{ country }
        }
    );

    return 0 if !$self->{ data };

    my $character     = $self->{ data }{ characterInfo }{ character };
    my $skill         = $self->{ data }{ characterInfo }{ skillTab };
    my $characterinfo = $self->{ data }{ characterInfo }{ characterTab };

    $self->character( Games::WoW::Armory::Character->new );
    $self->character->name( $$character{ name } );
    $self->character->class( $$character{ class } );
    $self->character->guildName( $$character{ guildName } );

    $self->character->battleGroup( $$character{ battleGroup } );
    $self->character->realm( $$character{ realm } );
    $self->character->race( $$character{ race } );
    $self->character->gender( $$character{ gender } );
    $self->character->faction( $$character{ faction } );
    $self->character->level( $$character{ level } );
    $self->character->lastModified( $$character{ lastModified } );
    $self->character->title( $$character{ title } );

    $self->character->skill( $skill );
    $self->character->characterinfo( $characterinfo );

    # Reputation information requires a separate XML file.
    $self->get_reputation( $params );

    $self->get_arena_teams( $params );

    1;
}

sub get_reputation {
    my ( $self, $params ) = @_;

    my $xml = 'character-reputation.xml';

    croak "you need to specify a character name"
        unless defined $$params{ character };
    croak "you need to specify a realm" unless defined $$params{ realm };
    croak "you need to specify a country name"
        unless defined $$params{ country };

    $self->fetch_data(
        {   xml     => $xml,
            realm   => $$params{ realm },
            name    => $$params{ character },
            country => $$params{ country }
        }
    );

    my $reputation = $self->{ data }{ characterInfo }{ reputationTab };

    # See https://rt.cpan.org/Ticket/Display.html?id=30329
    if (exists $reputation->{factionCategory}{name}) {
        # This is an invalid data structure.
	delete $reputation->{factionCategory}{name};
	my $key = ucfirst $reputation->{factionCategory}{key};
	$reputation->{factionCategory} = { $key => $reputation->{factionCategory} };
    }

    $self->character->reputation( $reputation );
    $self->get_heroic_access;
}

sub get_arena_teams {
    my ( $self, $params ) = @_;

    my $xml = 'character-arenateams.xml';

    croak "you need to specify a character name"
        unless defined $$params{ character };
    croak "you need to specify a realm" unless defined $$params{ realm };
    croak "you need to specify a country name"
        unless defined $$params{ country };

    $self->fetch_data(
        {   xml     => $xml,
            realm   => $$params{ realm },
            name    => $$params{ character },
            country => $$params{ country }
        }
    );

    my $arena_team
        = $self->{data}{characterInfo}{character}{arenaTeams}{arenaTeam};

    # XML::Simple will not divide team information up into keys
    # (based on team name) unless the character is a member of more
    # than one team.  The following logic tries to figure this out:
    my @teams = ( exists $$arena_team{name} )
              ? ( $arena_team )
              : map { $$arena_team{$_} } keys %{$arena_team};

    my @team_objs;
    foreach my $team ( @teams ){
        my $t = Games::WoW::Armory::Team->new;
        $t->name($$team{name});
        $t->seasonGamesPlayed($$team{seasonGamesPlayed});
        $t->size($$team{size});
        $t->rating($$team{rating});
        $t->battleGroup($$team{battleGroup});
        $t->realm($$team{realm});
        $t->lastSeasonRanking($$team{lastSeasonRanking});
        $t->factionId($$team{factionId});
        $t->ranking($$team{ranking});
        $t->seasonGamesWon($$team{seasonGamesWon});
        my @members = ( );

        my $members = $$team{members}{character};
	# See https://rt.cpan.org/Ticket/Display.html?id=30330
	# Each value in %$members is supposed to be a hashref
	# with information about one character.  If this is a
	# one-person arena team, then %$members is incorrectly
	# populated with the data about that sole character.
	# We work around this by moving it into place, then
	# resetting $members to point correctly.
	if (!ref $members->{name}) {
	    my %char_copy = %$members;
	    my $name = $members->{name};
            if (!$name) {
                $members = { };
            } else {
	        $team->{members}{character} = { $name => \%char_copy };
	        $members = $$team{members}{character};
            }
	}
        foreach my $member (keys %{$members}){
            my $m = Games::WoW::Armory::Character->new;
            $m->name($member);
            $m->race($$members{$member}{race});
            $m->seasonGamesPlayed($$members{$member}{seasonGamesPlayed});
            $m->teamRank($$members{$member}{teamRank});
            $m->race($$members{$member}{race});
            $m->gender($$members{$member}{gender});
            $m->seasonGamesWon($$members{$member}{seasonGamesWon});
            $m->guildName($$members{$member}{guild});
            $m->class($$members{$member}{class});
            push @members, $m;
        }
        $t->members(\@members);
        push @team_objs, $t;
    }
    $self->character->arenaTeams( \@team_objs );
}

sub get_heroic_access {
    my $self = shift;

    my @heroic_array = ( );
    return unless ref($self->character->reputation) eq 'HASH';
    foreach my $rep ( keys %{ $self->character->reputation } ) {
        next unless ref($self->character->reputation->{$rep}) eq 'HASH';
        foreach my $fac ( keys %{ $self->character->reputation->{ $rep } } ) {
            next unless ref($self->character->reputation->{$rep}{$fac}) eq 'HASH';
            foreach my $city (
                keys %{ $self->character->reputation->{ $rep }{ $fac }{ 'faction' } } )
            {
                next unless ref($self->character->reputation->{$rep}{$fac}{faction}) eq 'HASH';
                foreach my $r ( keys %{ $Games::WoW::Armory::HEROIC_REPUTATIONS } ) {
                    if (   $r eq $city
                        && $self->character->reputation->{ $rep }{ $fac }{ 'faction' }
                        { $city }{ 'reputation' } >= 21000 )
                    {
                        push @heroic_array, $$Games::WoW::Armory::HEROIC_REPUTATIONS{ $r };
                    }
                }
            }
        }
    }
    $self->character->heroic_access( \@heroic_array );
}

1;


# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2009 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::WoW;

use strict;

use Storable;
use Games::WoW::Armory;

use Slash;

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

sub getRealmidCreate {
	my($self, $countryname, $realmname) = @_;
	return     $self->getRealmidIfExists($countryname, $realmname)
		|| $self->createRealmid($countryname, $realmname);
}

sub getGuildidCreate {
	my($self, $realmid, $guildname) = @_;
	return     $self->getGuildidIfExists($realmid, $guildname)
		|| $self->createGuildid($realmid, $guildname);
}

sub getCharidCreate {
	my($self, $realmid, $charname) = @_;
	return     $self->getCharidIfExists($realmid, $charname)
		|| $self->createCharid($realmid, $charname);
}

sub getRealmidIfExists {
	my($self, $countryname, $realmname) = @_;

        my $constants = getCurrentStatic();
        my $table_cache         = "_realms_cache";
        my $table_cache_time    = "_realms_cache_time";
        $self->_genericCacheRefresh('realms', $constants->{block_expire});
        if ($self->{$table_cache_time} && $self->{$table_cache}{$countryname}{$realmname}) {
                return $self->{$table_cache}{$countryname}{$realmname};
        }

        my $mcd = $self->getMCD();
        my $mcdkey = "$self->{_mcd_keyprefix}:realmid:" if $mcd;
        if ($mcd) {
                my $realmid = $mcd->get("$mcdkey$countryname:$realmname");
                if ($realmid) {
                        if ($self->{$table_cache_time}) {
                                $self->{$table_cache}{$countryname}{$realmname} = $realmid;
                        }
                        return $realmid;
                }
        }

	my($countryname_q, $realmname_q) = ($self->sqlQuote($countryname), $self->sqlQuote($realmname));
	my $realmid = $self->sqlSelect('realmid', 'wow_realms',
		"realmname=$realmname_q AND countryname=$countryname_q");
	return 0 if !$realmid;

        $self->{$table_cache}{$countryname}{$realmname} = $realmid;
        $self->{$table_cache_time} ||= time;
        $mcd->set("$mcdkey$countryname:$realmname", $realmid, $constants->{block_expire}) if $mcd;
	return $realmid;
}

sub getGuildidIfExists {
	my($self, $realmid, $guildname) = @_;

        my $constants = getCurrentStatic();
        my $table_cache         = "_guilds_cache";
        my $table_cache_time    = "_guilds_cache_time";
        $self->_genericCacheRefresh('guilds', $constants->{block_expire});
        if ($self->{$table_cache_time} && $self->{$table_cache}{$realmid}{$guildname}) {
                return $self->{$table_cache}{$realmid}{$guildname};
        }

        my $mcd = $self->getMCD();
        my $mcdkey = "$self->{_mcd_keyprefix}:guildid:" if $mcd;
        if ($mcd) {
                my $guildid = $mcd->get("$mcdkey$realmid:$guildname");
                if ($guildid) {
                        if ($self->{$table_cache_time}) {
                                $self->{$table_cache}{$realmid}{$guildname} = $guildid;
                        }
                        return $guildid;
                }
        }

	my $guildname_q = $self->sqlQuote($guildname);
	my $guildid = $self->sqlSelect('guildid', 'wow_guilds',
		"guildname=$guildname_q AND realmid=$realmid");
	return 0 if !$guildid;

        $self->{$table_cache}{$realmid}{$guildname} = $guildid;
        $self->{$table_cache_time} ||= time;
        $mcd->set("$mcdkey$realmid:$guildname", $guildid, $constants->{block_expire}) if $mcd;
	return $guildid;
}

sub getCharidIfExists {
	my($self, $realmid, $charname) = @_;

        my $constants = getCurrentStatic();
        my $table_cache         = "_chars_cache";
        my $table_cache_time    = "_chars_cache_time";
        $self->_genericCacheRefresh('chars', $constants->{block_expire});
        if ($self->{$table_cache_time} && $self->{$table_cache}{$realmid}{$charname}) {
                return $self->{$table_cache}{$realmid}{$charname};
        }

        my $mcd = $self->getMCD();
        my $mcdkey = "$self->{_mcd_keyprefix}:charid:" if $mcd;
        if ($mcd) {
                my $charid = $mcd->get("$mcdkey$realmid:$charname");
                if ($charid) {
                        if ($self->{$table_cache_time}) {
                                $self->{$table_cache}{$realmid}{$charname} = $charid;
                        }
                        return $charid;
                }
        }

	my $charname_q = $self->sqlQuote($charname);
	my $charid = $self->sqlSelect('charid', 'wow_chars',
		"charname=$charname_q AND realmid=$realmid");
	return 0 if !$charid;

        $self->{$table_cache}{$realmid}{$charname} = $charid;
        $self->{$table_cache_time} ||= time;
        $mcd->set("$mcdkey$realmid:$charname", $charid, $constants->{block_expire}) if $mcd;
	return $charid;
}

sub createRealmid {
	my($self, $countryname, $realmname) = @_;
	my $rows = $self->sqlInsert('wow_realms', {
			countryname => $countryname,
			realmname => $realmname,
			type => undef,
		}, { ignore => 1 });
	if (!$rows) {
		# Insert failed, presumably because this realm already
		# exists.  Pull the information directly from this
		# writer DB.
		return $self->getRealmidIfExists($countryname, $realmname);
	}
	return $self->getLastInsertId();
}

sub createGuildid {
	my($self, $realmid, $guildname) = @_;
	my $rows = $self->sqlInsert('wow_guilds', {
			realmid => $realmid,
			guildname => $guildname,
		}, { ignore => 1 });
	if (!$rows) {
		# Insert failed, presumably because this realm already
		# exists.  Pull the information directly from this
		# writer DB.
		return $self->getGuildidIfExists($realmid, $guildname);
	}
	return $self->getLastInsertId();
}

sub createCharid {
	my($self, $realmid, $charname) = @_;
	my $rows = $self->sqlInsert('wow_chars', {
			realmid => $realmid,
			charname => $charname,
		}, { ignore => 1 });
	if (!$rows) {
		# Insert failed, presumably because this realm already
		# exists.  Pull the information directly from this
		# writer DB.
		return $self->getCharidIfExists($realmid, $charname);
	}
	return $self->getLastInsertId();
}

sub setChar {
	my($self, $charid, $data_hr) = @_;
	my $update_hr = { };
	for my $field (qw( guildid uid last_retrieval_attempt last_retrieval_success )) {
		if (exists($data_hr->{$field})) {
			$update_hr->{$field} = $data_hr->{$field};
		} elsif (exists($data_hr->{"-$field"})) {
			$update_hr->{"-$field"} = $data_hr->{"-$field"};
		}
	}
	if ($data_hr->{uid}) {
		my $chardata_hr = $self->getCharData($charid);
		if ($chardata_hr && $chardata_hr->{level} && $chardata_hr->{level} == 80) {
			my $achievements = getObject('Slash::Achievements');
			if ($achievements) {
				$achievements->setUserAchievement('wowlevel80', $data_hr->{uid},
					{ ignore_lookup => 1 });
			}
		}
	}
	my $rows = 0;
	$rows = $self->sqlUpdate('wow_chars', $update_hr, "charid=$charid") if keys %$update_hr;
	$rows;
}

# The metadata about the character includes such things as its name,
# realm and last data retrieval time.

sub getCharMetadata {
	my($self, $charid) = @_;
	return undef if $charid !~ /^\d+$/;
	my $char_hr = $self->sqlSelectHashref('*', 'wow_chars', "charid=$charid");
	return undef if !$char_hr || !$char_hr->{charname};
	$char_hr->{guildname} = $char_hr->{guildid}
		? $self->sqlSelect('guildname', 'wow_guilds', "guildid=$char_hr->{guildid}")
		: undef;
	($char_hr->{countryname}, $char_hr->{realmname}, $char_hr->{realm_type}, $char_hr->{realm_battlegroup})
		= $self->sqlSelect(
		'countryname, realmname, type, battlegroup',
		'wow_realms',
		"realmid=$char_hr->{realmid}");
	return $char_hr;
}

sub getCharData {
	my($self, $charid) = @_;
	return undef if $charid !~ /^\d+$/;
	return $self->sqlSelectAllKeyValue('name, value',
		'wow_char_types, wow_char_data',
		"charid=$charid AND wow_char_types.wcdtype=wow_char_data.wcdtype");
}

sub retrieveArmoryData {
	my($self, $charid) = @_;
	my $charmd_hr = $self->getCharMetadata($charid);
	return undef if !$charmd_hr;
	my $armory = Games::WoW::Armory->new();
	$armory->search_character({
		realm =>	$charmd_hr->{realmname},
		character =>	$charmd_hr->{charname},
		country =>	$charmd_hr->{countryname},
	});
	my $armory_hr = $armory->character();
	my $char_update = { -last_retrieval_attempt => 'NOW()' };
	$char_update->{-last_retrieval_success} = 'NOW()' if $armory_hr && $armory_hr->{name};
	$self->setChar($charid, $char_update);
	return $armory_hr;
}

sub logArmoryData {
	my($self, $charid, $armory_hr) = @_;
	return 0 if !$charid || $charid !~ /^\d+$/;
	my $frozenarmory = Storable::nfreeze($armory_hr);
	$self->sqlInsert('wow_char_armorylog', {
		charid =>	$charid,
		-ts =>		'NOW()',
		armorydata =>	$frozenarmory
	});
	$self->updateArmoryRecord($charid, $armory_hr);
}

sub getLatestArmoryRecord {
	my($self, $charid) = @_;
	return undef if !$charid || $charid !~ /^\d+$/;
	my $frozenarmory = $self->sqlSelect('armorydata', 'wow_char_armorylog',
		"charid=$charid", 'ORDER BY ts DESC LIMIT 1');
	return undef if !$frozenarmory;
	return Storable::thaw($frozenarmory);
}

sub updateArmoryRecord {
	my($self, $charid, $armory_hr) = @_;
	return 0 if !$charid || $charid !~ /^\d+$/;
	$armory_hr ||= $self->getLatestArmoryRecord($charid);
	return 0 if !$armory_hr;

	my $data = { };
	for my $field (qw( class faction gender level name race title guildName )) {
		$data->{$field} = $armory_hr->{$field};
	}
	my @fields = sort keys %$data;
	my $field_str = join(',', map { $self->sqlQuote($_) } @fields);
	my $wcd_conv = $self->sqlSelectAllKeyValue('name, wcdtype', 'wow_char_types',
		"name IN ($field_str)");
	$self->sqlDo('START TRANSACTION');
	for my $name (@fields) {
		$self->sqlReplace('wow_char_data', {
			charid =>	$charid,
			wcdtype =>	$wcd_conv->{$name},
			value =>	$armory_hr->{$name},
		});
	}
	$self->sqlDo('COMMIT');

	my $charmd_hr = undef;

	if ($armory_hr->{level} == 80) {
		my $achievements = getObject('Slash::Achievements');
		if ($achievements) {
			$charmd_hr ||= $self->getCharMetadata($charid);
			my $uid = $charmd_hr->{uid} || 0;
			if ($uid) {
				$achievements->setUserAchievement('wowlevel80', $uid,
					{ ignore_lookup => 1 });
			}
		}
	}

	if ($armory_hr->{guildName}) {
		$charmd_hr ||= $self->getCharMetadata($charid);
		my $guildid = $self->getGuildidCreate($charmd_hr->{realmid}, $armory_hr->{guildName})
			|| undef;
		$self->setChar($charid, { guildid => $guildid });
	}
}

sub getCharidsNeedingRetrieval {
	my($self) = @_;
	my $charids_ar = $self->sqlSelectColArrayref('charid', 'wow_chars',
		'last_retrieval_attempt IS NULL',
		'ORDER BY charid LIMIT 10');
	return $charids_ar if @$charids_ar;

	my $constants = getCurrentStatic();
	my $retry = $constants->{wow_retrieval_retry} || 10800;
	$charids_ar = $self->sqlSelectColArrayref('charid', 'wow_chars',
		"last_retrieval_success IS NULL
		 AND last_retrieval_attempt < DATE_SUB(NOW(), INTERVAL $retry SECOND)",
		'ORDER BY charid LIMIT 10');
	return $charids_ar if @$charids_ar;

	my $reload = $constants->{wow_retrieval_reload} || 608400;
	$charids_ar = $self->sqlSelectColArrayref('charid', 'wow_chars',
		"last_retrieval_attempt < DATE_SUB(NOW(), INTERVAL $reload SECOND)",
		'ORDER BY charid LIMIT 10');
	return $charids_ar if @$charids_ar;
	return [ ];
}

sub createRealmSelect {
	my($self, $realmid) = @_;
	$realmid ||= 0;
	my $str = '<select name="wow_realm">';
	$str .= '<option value="0"' . ($realmid == 0 ? ' selected' : '') . '>Choose realm</option>';
	my $rd = $self->sqlSelectAllHashref('realmid', 'realmid, countryname, realmname', 'wow_realms');
	my %realm = ( map { ($_, "$rd->{$_}{realmname} ($rd->{$_}{countryname})" ) } keys %$rd );
	my @ids = sort { $realm{$a} cmp $realm{$b} } keys %realm;
	for my $id (@ids) {
		my $sel = $realmid == $id ? ' selected' : '';
		$str .= qq{<option value="$id"$sel>$realm{$id}</option>};
	}
	$str .= '</select>';
	$str;
}

1;


CREATE TABLE wow_chars (
	charid			int unsigned not null auto_increment,
	realmid			smallint unsigned not null,
	charname		varchar(12) not null,
	guildid			int unsigned default null,
	uid			mediumint unsigned default null,
	last_retrieval_attempt	datetime default null,
	last_retrieval_success	datetime default null,
	PRIMARY KEY (charid),
	UNIQUE realm_name (realmid, charname),
	INDEX name (charname),
	INDEX uid (uid),
	INDEX last_retrieval_success (last_retrieval_success)
) ENGINE=InnoDB;

CREATE TABLE wow_realms (
	realmid		smallint unsigned not null auto_increment,
	countryname	varchar(2) not null,
	realmname	varchar(64) not null,
	type		enum('pve', 'pvp', 'rp', 'rppvp') not null default 'pve',
	battlegroup	varchar(16) default null,
	PRIMARY KEY (realmid),
	UNIQUE country_realm (countryname, realmname),
	INDEX battlegroup (countryname, battlegroup)
) ENGINE=InnoDB;

CREATE TABLE wow_guilds (
	guildid		int unsigned not null auto_increment,
	realmid		smallint unsigned not null,
	guildname	varchar(64) not null,
	PRIMARY KEY (guildid),
	UNIQUE idx_name (realmid, guildname)
) ENGINE=InnoDB;

CREATE TABLE wow_char_armorylog (
	arlid		int unsigned not null auto_increment,
	charid		int unsigned not null,
	ts		datetime not null,
	armorydata	mediumblob not null,
	raw_content	mediumblob default null,
	PRIMARY KEY (arlid),
	INDEX ts (ts),
	INDEX charid_ts (charid, ts)
) ENGINE=InnoDB;

CREATE TABLE wow_char_data (
	wcdid		int unsigned not null auto_increment,
	charid		int unsigned not null,
	wcdtype		smallint unsigned not null,
	value		varchar(100),
	PRIMARY KEY (wcdid),
	UNIQUE charid_wcdtype (charid, wcdtype)
) ENGINE=InnoDB;

CREATE TABLE wow_char_types (
	wcdtype		smallint unsigned not null auto_increment,
	name		varchar(100) not null,
	PRIMARY KEY (wcdtype),
	UNIQUE name (name)
) ENGINE=InnoDB;


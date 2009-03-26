CREATE TABLE wow_char (
	charid		int unsigned not null auto_increment,
	countryid	smallint not null,
	realmid		smallint not null,
	charname	varchar(64) not null,
	last_retrieval	datetime default null,
	PRIMARY KEY charid
	UNIQUE idx_name (countryid, realmid, charname),
	INDEX last_retrieval (last_retrieval)
) ENGINE=InnoDB;

CREATE TABLE wow_realm (
	realmid		smallint unsigned not null auto_increment,
	realmname	varchar(64) not null,
	PRIMARY KEY realmid
) ENGINE=InnoDB;

CREATE TABLE wow_country (
	countryid	smallint unsigned not null auto_increment,
	countryname	varchar(8) not null,
	PRIMARY KEY countryid
) ENGINE=InnoDB;

CREATE TABLE wow_guild (
	guildid		int unsigned not null auto_increment,
	realmid		smallint unsigned not null,
	guildname	varchar(64) not null,
	PRIMARY KEY guildid,
	UNIQUE idx_name (realmid, guildname)
) ENGINE=InnoDB;

CREATE TABLE `sphinx_counter` (
  `src` smallint(5) unsigned NOT NULL,
  `completion` int(10) unsigned default NULL,
  `last_seen` datetime NOT NULL,
  `started` datetime NOT NULL,
  `elapsed` int(10) unsigned default NULL,
  UNIQUE KEY `src_completion` (`src`,`completion`)
) ENGINE=InnoDB;

CREATE TABLE `sphinx_counter_archived` (
  `src` smallint(5) unsigned NOT NULL,
  `completion` int(10) unsigned NOT NULL,
  `last_seen` datetime NOT NULL,
  `started` datetime NOT NULL,
  `elapsed` int(10) unsigned default NULL,
  UNIQUE KEY `src_completion` (`src`,`completion`)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `sphinx_search` (
  `globjid` int(11) NOT NULL,
  `weight` int(11) NOT NULL,
  `query` varchar(3072) NOT NULL,
  `_sph_count` int(11) NOT NULL,
  KEY `query` (`query`)
) ENGINE=InnoDB;


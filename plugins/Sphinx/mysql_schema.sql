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

CREATE TABLE `sphinx_index` (
  `src` smallint(5) unsigned NOT NULL,
  `name` varchar(48) NOT NULL,
  `asynch` tinyint(3) unsigned NOT NULL default '1',
  `laststart` datetime NOT NULL default '2000-01-01 00:00:00',
  `frequency` int(10) unsigned NOT NULL default '86400',
  PRIMARY KEY  (`src`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB;


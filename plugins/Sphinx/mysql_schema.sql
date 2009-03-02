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


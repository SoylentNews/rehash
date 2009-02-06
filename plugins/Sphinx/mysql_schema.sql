CREATE TABLE `sphinx_counter` (
  `src` smallint(5) unsigned NOT NULL,
  `completion` int(10) unsigned NOT NULL,
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

CREATE TABLE `sphinx_search` (
  `globjid` int(11) NOT NULL,
  `weight` int(11) NOT NULL,
  `query` varchar(3072) NOT NULL,
  `_sph_count` int(11) NOT NULL,
  `createtime_ut` int(11) NOT NULL,
  `last_update_ut` int(11) NOT NULL,
  `gtid` int(11) NOT NULL,
  `type` int(11) NOT NULL,
  `popularity` int(11) NOT NULL,
  `editorpop` int(11) NOT NULL,
  `public` int(11) NOT NULL,
  `accepted` int(11) NOT NULL,
  `rejected` int(11) NOT NULL,
  `attention_needed` int(11) NOT NULL,
  `is_spam` int(11) NOT NULL,
  `category` int(11) NOT NULL,
  `offmainpage` int(11) NOT NULL,
  `primaryskid` int(11) NOT NULL,
  `uid` int(11) NOT NULL,
  KEY `query` (`query`)
) ENGINE=SPHINX;


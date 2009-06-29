CREATE TABLE `preview` (
  `preview_id` mediumint(8) unsigned NOT NULL auto_increment,
  `uid` mediumint(8) unsigned NOT NULL,
  `src_fhid` mediumint(8) unsigned NOT NULL default '0',
  `preview_fhid` mediumint(8) unsigned NOT NULL default '0',
  `introtext` text NOT NULL,
  `bodytext` text NOT NULL,
  `active` enum('no','yes') default 'yes',
  PRIMARY KEY  (`preview_id`),
  KEY `uid` (`uid`)
) ENGINE=InnoDB;

CREATE TABLE `preview_param` (
  `param_id` mediumint(8) unsigned NOT NULL auto_increment,
  `preview_id` mediumint(8) unsigned NOT NULL,
  `name` varchar(32) NOT NULL default '',
  `value` text NOT NULL,
  PRIMARY KEY  (`param_id`),
  UNIQUE KEY `submission_key` (`preview_id`,`name`)
) ENGINE=InnoDB;


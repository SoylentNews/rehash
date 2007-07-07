#
# $Id$
#
DROP TABLE IF EXISTS firehose;
CREATE TABLE firehose (
	id mediumint(8) unsigned NOT NULL auto_increment,
	uid mediumint(8) unsigned NOT NULL default '0',
	globjid int unsigned NOT NULL default '0',
	discussion mediumint UNSIGNED NOT NULL default '0',
	type ENUM("submission","journal","bookmark","feed", "story") default 'submission',
	createtime datetime NOT NULL default '0000-00-00 00:00:00',
	popularity float NOT NULL default '0',
	popularity2 float NOT NULL default '0',
	editorpop float NOT NULL default '0',
	activity float NOT NULL default '0',
	accepted enum('no','yes') default 'no',
	rejected enum('no','yes') default 'no',
	public enum('no','yes') default 'no',
	attention_needed enum('no','yes') default 'no',
	primaryskid smallint(5) default '0',
	tid smallint(6) default '0',
	srcid mediumint(8) unsigned NOT NULL default '0',
	url_id mediumint(8) unsigned NOT NULL default '0',
	toptags varchar(255) default '',
	email varchar(255) NOT NULL default '',
	emaildomain varchar(255) NOT NULL default '',
	name varchar(50) NOT NULL,
	dept VARCHAR(100) NOT NULL DEFAULT '',
	ipid varchar(32) NOT NULL default '',
	subnetid varchar(32) NOT NULL default '',
	category varchar(30) NOT NULL default '',
	last_update TIMESTAMP,
	signoffs VARCHAR(255) NOT NULL DEFAULT '',
	stoid MEDIUMINT UNSIGNED DEFAULT '0',
	body_length MEDIUMINT UNSIGNED DEFAULT 0 NOT NULL,
	word_count MEDIUMINT UNSIGNED DEFAULT 0 NOT NULL,
	srcname VARCHAR(32) NOT NULL DEFAULT '',
	PRIMARY KEY (id),
	UNIQUE globjid (globjid),
	KEY createtime (createtime),
	KEY popularity (popularity),
	KEY popularity2 (popularity2)
) TYPE=InnoDB; 

DROP TABLE IF EXISTS firehose_text;
CREATE TABLE firehose_text(
	id mediumint(8) unsigned NOT NULL auto_increment,
	title VARCHAR(80),
	introtext text,
	bodytext text,
	PRIMARY KEY (id)
) TYPE=InnoDB;

DROP TABLE IF EXISTS firehose_tab;
CREATE TABLE firehose_tab(
	tabid mediumint(8) unsigned NOT NULL auto_increment,
	uid MEDIUMINT UNSIGNED NOT NULL DEFAULT '0',
	tabname VARCHAR(16) NOT NULL DEFAULT 'unnamed',
	filter VARCHAR(255) NOT NULL DEFAULT '',
	orderby ENUM("popularity","createtime", "editorpop", "activity") DEFAULT "createtime",
	orderdir ENUM("ASC", "DESC") DEFAULT "DESC",
	color VARCHAR(16) NOT NULL DEFAULT '',
	mode ENUM("full", "fulltitle") DEFAULT "fulltitle",
	PRIMARY KEY (tabid),
	UNIQUE uid_tabname(uid,tabname)
) TYPE=InnoDB;

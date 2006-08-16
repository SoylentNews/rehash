#
# $Id$
#
DROP TABLE IF EXISTS firehose;
CREATE TABLE firehose (
	id mediumint(8) unsigned NOT NULL auto_increment,
	uid mediumint(8) unsigned NOT NULL default '0',
	globjid mediumint(8) unsigned NOT NULL default '0',
	type ENUM("submission","journal","bookmark","feed") default 'submission',
	createtime datetime NOT NULL default '0000-00-00 00:00:00',
	title varchar(80) NOT NULL default '',
	popularity float NOT NULL default '0',
	accepted enum('no','yes') default 'no',
	rejected enum('no','yes') default 'no',
	public enum('no','yes') default 'no',
	attention_needed enum('no','yes') default 'no',
	primaryskid smallint(5) default '0',
	tid smallint(6) default '0',
	srcid mediumint(8) unsigned NOT NULL default '0',
	url_id mediumint(8) unsigned NOT NULL default '0',
	note varchar(255) default '',
	toptags varchar(255) default '',
	PRIMARY KEY  (id)
) TYPE=InnoDB; 

DROP TABLE IF EXISTS firehose_text;
CREATE TABLE firehose_text(
	id mediumint(8) unsigned NOT NULL auto_increment,
	title VARCHAR(80),
	introtext text,
	bodytext text,
	PRIMARY KEY (id)
) TYPE=InnoDB;

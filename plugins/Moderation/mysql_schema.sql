#
# $Id$
#

CREATE TABLE IF NOT EXISTS moderatorlog (
	id int UNSIGNED NOT NULL auto_increment,
	ipid char(32) DEFAULT '' NOT NULL,
	subnetid char(32) DEFAULT '' NOT NULL,
	uid mediumint UNSIGNED NOT NULL,
	val tinyint DEFAULT '0' NOT NULL,
	sid mediumint UNSIGNED DEFAULT '0' NOT NULL,
	ts datetime DEFAULT '1970-01-01 00:00:00' NOT NULL,
	cid int UNSIGNED NOT NULL,
	cuid mediumint UNSIGNED NOT NULL,
	reason tinyint UNSIGNED DEFAULT '0',
	active tinyint DEFAULT '1' NOT NULL,
	spent tinyint DEFAULT '1' NOT NULL,
	points_orig tinyint DEFAULT NULL,
	PRIMARY KEY (id),
	KEY sid (sid,cid),
	KEY sid_2 (sid,uid,cid),
	KEY cid (cid),
	KEY ipid (ipid),
	KEY subnetid (subnetid),
	KEY uid (uid),
	KEY cuid (cuid),
	KEY ts_uid_sid (ts,uid,sid)
) TYPE=InnoDB;

CREATE TABLE IF NOT EXISTS modreasons (
	id tinyint UNSIGNED NOT NULL,
	name char(32) DEFAULT '' NOT NULL,
	m2able tinyint DEFAULT '1' NOT NULL,
	listable tinyint DEFAULT '1' NOT NULL,
	val tinyint DEFAULT '0' NOT NULL,
	karma tinyint DEFAULT '0' NOT NULL,
	fairfrac float DEFAULT '0.5' NOT NULL,
	unfairname varchar(32) DEFAULT '' NOT NULL,
	PRIMARY KEY (id)
) TYPE=InnoDB;


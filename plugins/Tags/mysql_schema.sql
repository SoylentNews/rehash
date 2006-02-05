#
# $Id$
#

DROP TABLE IF EXISTS tags;
CREATE TABLE tags (
	tagid		int UNSIGNED NOT NULL AUTO_INCREMENT,
	tagnameid	int UNSIGNED NOT NULL,
	globjid		int UNSIGNED NOT NULL,
	uid		mediumint UNSIGNED NOT NULL,
	created_at	datetime NOT NULL,
	PRIMARY KEY tagid (tagid),
	KEY tagnameid (tagnameid),
	KEY globjid (globjid),
	KEY uid (uid),
	KEY created_at (created_at)
) TYPE=InnoDB;

DROP TABLE IF EXISTS tagnames;
CREATE TABLE tagnames (
	tagnameid	int UNSIGNED NOT NULL AUTO_INCREMENT,
	tagname		VARCHAR(64) NOT NULL,
	PRIMARY KEY tagnameid (tagnameid),
	UNIQUE tagname (tagname)
) TYPE=InnoDB;
	
DROP TABLE IF EXISTS tagname_params;
CREATE TABLE tagname_params (
	tagnameid	int UNSIGNED NOT NULL,
	name		VARCHAR(32) DEFAULT '' NOT NULL,
	value		VARCHAR(64) DEFAULT '' NOT NULL,
	UNIQUE tagname_name (tagnameid, name)
) TYPE=InnoDB;

#DROP TABLE IF EXISTS tag_schedule;
#CREATE TABLE tag_schedule (
#	tsid		int UNSIGNED NOT NULL AUTO_INCREMENT,
#	type		ENUM('tagnameid', 'uid', 'globjid') NOT NULL,
#	id		int UNSIGNED NOT NULL,
#	importance	float UNSIGNED DEFAULT 1.0 NOT NULL,
#	created_at	datetime NOT NULL,
#	done		ENUM('no', 'yes') DEFAULT 'no' NOT NULL,
#	completed_at	datetime DEFAULT NULL,
#	duration	float DEFAULT NULL,
#	PRIMARY KEY tsid (tsid),
#	KEY need (done, importance)
#) TYPE=InnoDB;

ALTER TABLE users_info ADD COLUMN tag_clout FLOAT UNSIGNED NOT NULL DEFAULT 1.0 AFTER created_at;


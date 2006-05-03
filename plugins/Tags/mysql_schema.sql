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
	inactivated	datetime DEFAULT NULL,
	PRIMARY KEY tagid (tagid),
	KEY tagnameid (tagnameid),
	KEY globjid_tagnameid (globjid, tagnameid),
	KEY uid_globjid_tagnameid_inactivated (uid, globjid, tagnameid, inactivated),
	KEY created_at (created_at)
) TYPE=InnoDB;

DROP TABLE IF EXISTS tag_params;
CREATE TABLE tag_params (
	tagid		int UNSIGNED NOT NULL,
	name		VARCHAR(32) DEFAULT '' NOT NULL,
	value		VARCHAR(64) DEFAULT '' NOT NULL,
	UNIQUE tag_name (tagid, name)
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

DROP TABLE IF EXISTS tagcommand_adminlog;
CREATE TABLE tagcommand_adminlog (
	id		int UNSIGNED NOT NULL AUTO_INCREMENT,
	cmdtype		VARCHAR(6) NOT NULL,
	tagnameid	int UNSIGNED NOT NULL,
	globjid		int UNSIGNED DEFAULT NULL,
	adminuid	mediumint UNSIGNED NOT NULL,
	created_at	datetime NOT NULL,
	PRIMARY KEY id (id),
	KEY created_at (created_at),
	KEY tagnameid_globjid (tagnameid, globjid)
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

CREATE TABLE tagboxes (
	tbid			smallint UNSIGNED NOT NULL AUTO_INCREMENT,
	name			VARCHAR(32) DEFAULT '' NOT NULL,
	affected_type		ENUM('user', 'globj') NOT NULL,
	weight			FLOAT UNSIGNED DEFAULT 1.0 NOT NULL,
	last_tagid_logged	int UNSIGNED NOT NULL,
	last_run_completed	datetime,
	PRIMARY KEY tbid (tbid),
	UNIQUE name (name)
) TYPE=InnoDB;

CREATE TABLE tagbox_feederlog (
	tfid		int UNSIGNED NOT NULL AUTO_INCREMENT,
	created_at	datetime NOT NULL,
	tbid		smallint UNSIGNED NOT NULL,
	tagid		int UNSIGNED NOT NULL,
	affected_id	int UNSIGNED NOT NULL,
	importance	FLOAT UNSIGNED DEFAULT 1.0 NOT NULL,
	PRIMARY KEY tfid (tfid),
	KEY tbid_tagid (tbid, tagid),
	KEY tbid_affectedid (tbid, affected_id)
) TYPE=InnoDB;


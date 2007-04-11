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
	private		enum('yes', 'no') NOT NULL DEFAULT 'no',
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

ALTER TABLE users_info ADD COLUMN tag_clout FLOAT UNSIGNED NOT NULL DEFAULT 1.0 AFTER created_at;

CREATE TABLE tagboxes (
	tbid			smallint UNSIGNED NOT NULL AUTO_INCREMENT,
	name			VARCHAR(32) DEFAULT '' NOT NULL,
	affected_type		ENUM('user', 'globj') NOT NULL,
	weight			FLOAT UNSIGNED DEFAULT 1.0 NOT NULL,
	last_run_completed	datetime,
	last_tagid_logged	int UNSIGNED NOT NULL,
	last_tdid_logged	int UNSIGNED NOT NULL,
	last_tuid_logged	int UNSIGNED NOT NULL,
	PRIMARY KEY tbid (tbid),
	UNIQUE name (name)
) TYPE=InnoDB;

CREATE TABLE tagbox_userkeyregexes (
	name			varchar(32) NOT NULL,
	userkeyregex		varchar(255) NOT NULL,
	UNIQUE name_regex (name, userkeyregex)
) TYPE=InnoDB;

CREATE TABLE tagboxlog_feeder (
	tfid		int UNSIGNED NOT NULL AUTO_INCREMENT,
	created_at	datetime NOT NULL,
	tbid		smallint UNSIGNED NOT NULL,
	affected_id	int UNSIGNED NOT NULL,
	importance	FLOAT UNSIGNED DEFAULT 1.0 NOT NULL,
	tagid		int UNSIGNED DEFAULT NULL,
	tdid		int UNSIGNED DEFAULT NULL,
	tuid		int UNSIGNED DEFAULT NULL,
	PRIMARY KEY tfid (tfid),
	KEY tbid_tagid (tbid, tagid),
	KEY tbid_tdid  (tbid, tdid),
	KEY tbid_tuid  (tbid, tuid),
	KEY tbid_affectedid (tbid, affected_id)
) TYPE=InnoDB;

CREATE TABLE tags_deactivated (
	tdid		int UNSIGNED NOT NULL AUTO_INCREMENT,
	tagid		int UNSIGNED NOT NULL,
	PRIMARY KEY tdid (tdid),
	KEY tagid (tagid)
) TYPE=InnoDB;

CREATE TABLE tags_userchange (
	tuid		int UNSIGNED NOT NULL AUTO_INCREMENT,
	created_at	datetime NOT NULL,
	uid		mediumint UNSIGNED NOT NULL,
	user_key	varchar(32) NOT NULL,
	value_old	text,
	value_new	text,
	PRIMARY KEY tuid (tuid),
	KEY uid (uid)
) TYPE=InnoDB;

CREATE TABLE tags_peerweight (
	uid		mediumint UNSIGNED NOT NULL DEFAULT '0',
	gen		smallint UNSIGNED NOT NULL DEFAULT '0',
	weight		float NOT NULL DEFAULT '0',
	PRIMARY KEY (uid),
	KEY gen_uid (gen, uid)
) TYPE=InnoDB;

CREATE TABLE tagnames_similar (
	tsid		int UNSIGNED NOT NULL AUTO_INCREMENT,
	type		smallint UNSIGNED NOT NULL DEFAULT '0',
	src_tnid	int UNSIGNED NOT NULL DEFAULT '0',
	dest_tnid	int UNSIGNED NOT NULL DEFAULT '0',
	simil		float NOT NULL DEFAULT '0',
	PRIMARY KEY (tsid),
	UNIQUE type_src_dest (type, src_tnid, dest_tnid)
) TYPE=InnoDB;

CREATE TABLE tags_udc (
	hourtime	datetime NOT NULL,
	udc		float NOT NULL DEFAULT '0',
	PRIMARY KEY (hourtime)
) TYPE=InnoDB;

CREATE TABLE tags_hourofday (
	hour		tinyint UNSIGNED NOT NULL DEFAULT '0',
	proportion	float NOT NULL DEFAULT '0',
	PRIMARY KEY (hour)
) TYPE=InnoDB;

CREATE TABLE tags_dayofweek (
	day		tinyint UNSIGNED NOT NULL DEFAULT '0',
	proportion	float NOT NULL DEFAULT '0',
	PRIMARY KEY (day)
) TYPE=InnoDB;



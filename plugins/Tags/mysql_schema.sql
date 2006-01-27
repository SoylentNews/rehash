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

DROP TABLE IF EXISTS tag_names;
CREATE TABLE tag_names (
	tagnameid	int UNSIGNED NOT NULL AUTO_INCREMENT,
	name		VARCHAR(64) NOT NULL,
	PRIMARY KEY tagnameid (tagnameid),
	UNIQUE name (name)
) TYPE=InnoDB;
	


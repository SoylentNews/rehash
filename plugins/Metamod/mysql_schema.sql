#
# $Id$
#

ALTER TABLE users_info ADD COLUMN m2info varchar(64) DEFAULT '' NOT NULL AFTER lastgranted, ADD COLUMN lastm2 datetime DEFAULT '1970-01-01 00:00' NOT NULL AFTER totalcomments, ADD COLUMN m2_mods_saved varchar(120) DEFAULT '' NOT NULL AFTER lastm2;
ALTER TABLE users_info ADD COLUMN m2fair mediumint UNSIGNED DEFAULT '0' NOT NULL AFTER lastaccess, ADD COLUMN up_fair mediumint UNSIGNED DEFAULT '0' NOT NULL AFTER m2fair, ADD COLUMN down_fair mediumint UNSIGNED DEFAULT '0' NOT NULL AFTER up_fair, ADD COLUMN m2unfair mediumint UNSIGNED DEFAULT '0' NOT NULL AFTER down_fair, ADD COLUMN up_unfair mediumint UNSIGNED DEFAULT '0' NOT NULL AFTER m2unfair, ADD COLUMN down_unfair mediumint UNSIGNED DEFAULT '0' NOT NULL AFTER up_unfair, ADD COLUMN m2fairvotes mediumint UNSIGNED DEFAULT '0' NOT NULL AFTER down_unfair, ADD COLUMN m2voted_up_fair mediumint UNSIGNED DEFAULT '0' NOT NULL AFTER m2fairvotes, ADD COLUMN m2voted_down_fair mediumint UNSIGNED DEFAULT '0' NOT NULL AFTER m2voted_up_fair, ADD COLUMN m2unfairvotes mediumint UNSIGNED DEFAULT '0' NOT NULL AFTER m2voted_down_fair, ADD COLUMN m2voted_up_unfair mediumint UNSIGNED DEFAULT '0' NOT NULL AFTER m2unfairvotes, ADD COLUMN m2voted_down_unfair mediumint UNSIGNED DEFAULT '0' NOT NULL AFTER m2voted_up_unfair, ADD COLUMN m2voted_lonedissent mediumint UNSIGNED DEFAULT '0' NOT NULL AFTER m2voted_down_unfair, ADD COLUMN m2voted_majority mediumint UNSIGNED DEFAULT '0' NOT NULL AFTER m2voted_lonedissent;


#ALTER TABLE moderatorlog ADD COLUMN m2count mediumint UNSIGNED NOT NULL DEFAULT '0', ADD COLUMN m2needed mediumint UNSIGNED NOT NULL DEFAULT '0', ADD COLUMN m2status tinyint DEFAULT '0' NOT NULL, ADD INDEX m2stat_act (m2status,active);

DROP TABLE IF EXISTS metamodlog;
CREATE TABLE metamodlog (
	id int UNSIGNED NOT NULL AUTO_INCREMENT,
	mmid int UNSIGNED DEFAULT '0' NOT NULL,
	uid mediumint UNSIGNED DEFAULT '0' NOT NULL,
	val tinyint  DEFAULT '0' NOT NULL,
	ts datetime,
	active tinyint DEFAULT '1' NOT NULL,
	PRIMARY KEY id (id),
	INDEX byuser (uid),
	INDEX mmid (mmid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#ALTER TABLE metamodlog ADD FOREIGN KEY (mmid) REFERENCES moderatorlog(id);
#ALTER TABLE metamodlog ADD FOREIGN KEY (uid) REFERENCES users(uid);


#
# $Id$
#

DROP TABLE IF EXISTS ajax_ops;
CREATE TABLE ajax_ops (
	id mediumint(5) UNSIGNED NOT NULL auto_increment,
	op VARCHAR(50) DEFAULT '' NOT NULL,
	class VARCHAR(100) DEFAULT '' NOT NULL,
	subroutine VARCHAR(100) DEFAULT '' NOT NULL,
	reskey_name VARCHAR(64) DEFAULT '' NOT NULL,
	reskey_type VARCHAR(64) DEFAULT '' NOT NULL,
	PRIMARY KEY (id),
	UNIQUE op (op)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;


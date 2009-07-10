#
# $Id$
#

DROP TABLE IF EXISTS reskeys;
CREATE TABLE reskeys (
    rkid        INT NOT NULL AUTO_INCREMENT,
    reskey      CHAR(20) DEFAULT '' NOT NULL,	# unique resource key string
    rkrid       SMALLINT UNSIGNED NOT NULL,	# points to reskey_resources.rkrid

    uid         MEDIUMINT UNSIGNED DEFAULT 0 NOT NULL,
    srcid_ip    BIGINT UNSIGNED DEFAULT 0 NOT NULL,

    failures    TINYINT DEFAULT 0 NOT NULL,                          # number of failures of this key
    touches     TINYINT DEFAULT 0 NOT NULL,                          # number of touches (not including failures, or successful uses) of this key
    is_alive    ENUM('yes', 'no') DEFAULT 'yes' NOT NULL,

    create_ts   DATETIME DEFAULT '0000-00-00 00:00:00' NOT NULL,     # on create
    last_ts     DATETIME DEFAULT '0000-00-00 00:00:00' NOT NULL,     # last use
    submit_ts   DATETIME DEFAULT NULL,                               # on success

    PRIMARY KEY (rkid),
    UNIQUE reskey (reskey),
    KEY rkrid (rkrid),
    KEY uid (uid),
    KEY srcid_ip (srcid_ip),
    KEY create_ts (create_ts),
    KEY last_ts (last_ts),
    KEY submit_ts (submit_ts)
) TYPE=InnoDB;

DROP TABLE IF EXISTS reskey_failures;
CREATE TABLE reskey_failures (
    rkid        INT NOT NULL,
    failure     VARCHAR(255) DEFAULT '' NOT NULL,
    PRIMARY KEY (rkid)
) TYPE=InnoDB;

DROP TABLE IF EXISTS reskey_resources;
CREATE TABLE reskey_resources (
    rkrid       SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name        VARCHAR(64),
    static      ENUM('yes', 'no') DEFAULT 'no' NOT NULL,
    PRIMARY KEY (rkrid)
) TYPE=InnoDB;

DROP TABLE IF EXISTS reskey_resource_checks;
CREATE TABLE reskey_resource_checks (
    rkrcid      SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    rkrid       SMALLINT UNSIGNED NOT NULL,
    type        ENUM('create', 'touch', 'use', 'all') NOT NULL,
    class       VARCHAR(255),
    ordernum    SMALLINT UNSIGNED DEFAULT 0,
    PRIMARY KEY (rkrcid),
    UNIQUE rkrid_name (rkrid, type, class)
) TYPE=InnoDB;

DROP TABLE IF EXISTS reskey_vars;
CREATE TABLE reskey_vars (
    rkrid       SMALLINT UNSIGNED NOT NULL,
    name        VARCHAR(48) DEFAULT '' NOT NULL,
    value       TEXT,
    description VARCHAR(255),
    UNIQUE name_rkrid (name, rkrid)
) TYPE=InnoDB;

DROP TABLE IF EXISTS reskey_hourlysalt;
CREATE TABLE reskey_hourlysalt (
    ts          DATETIME DEFAULT '0000-00-00 00:00:00' NOT NULL,
    salt        VARCHAR(20) DEFAULT '' NOT NULL,
    UNIQUE ts (ts)
) TYPE=InnoDB;

DROP TABLE IF EXISTS reskey_sessions;
CREATE TABLE reskey_sessions (
    sessid int UNSIGNED NOT NULL auto_increment,
    reskey CHAR(20) DEFAULT '' NOT NULL,
    name   VARCHAR(48) DEFAULT '' NOT NULL,
    value  TEXT,
    PRIMARY KEY (sessid),
    INDEX (reskey),
    UNIQUE reskey_name (reskey, name)
) TYPE=InnoDB;


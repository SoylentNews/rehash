#
# $Id$
#

DROP TABLE IF EXISTS reskeys;
CREATE TABLE reskeys (
    rkid       INT NOT NULL AUTO_INCREMENT,
    reskey     VARCHAR(20) DEFAULT '' NOT NULL,  # unique resource key string
    rkrid      TINYINT UNSIGNED NOT NULL,        # points to reskey_resources.rkrid

    uid        MEDIUMINT UNSIGNED DEFAULT 0 NOT NULL,

    srcid_ip   BIGINT UNSIGNED DEFAULT 0 NOT NULL,


    failures   TINYINT DEFAULT 0 NOT NULL,                          # number of failures of this key
    touches    TINYINT DEFAULT 0 NOT NULL,                          # number of touches (not including failures, or successful uses) of this key
    is_alive   ENUM('yes', 'no') DEFAULT 'yes' NOT NULL,

    create_ts  DATETIME DEFAULT '0000-00-00 00:00:00' NOT NULL,     # on create
    last_ts    DATETIME DEFAULT '0000-00-00 00:00:00' NOT NULL,     # last use
    submit_ts  DATETIME DEFAULT NULL,                               # on success


    PRIMARY KEY (rkid),
    UNIQUE reskey (reskey),
    KEY rkrid (rkrid),
    KEY uid (uid),
    KEY srcid_ip (srcid_ip),
    KEY create_ts (create_ts),
    KEY last_ts (last_ts),
    KEY submit_ts (submit_ts)
);

DROP TABLE IF EXISTS reskey_resources;
CREATE TABLE reskey_resources (
    rkrid       TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name        VARCHAR(64),
    PRIMARY KEY (rkrid)
);

DROP TABLE IF EXISTS reskey_resource_checks;
CREATE TABLE reskey_resource_checks (
    rkrcid      SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    rkrid       TINYINT UNSIGNED NOT NULL,
    type        ENUM('create', 'touch', 'use') NOT NULL,
    class       VARCHAR(255),
    ordernum    SMALLINT UNSIGNED DEFAULT 0,
    PRIMARY KEY (rkrcid),
    UNIQUE rkrid_name (rkrid, type, class)
);


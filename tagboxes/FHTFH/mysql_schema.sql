CREATE TABLE firehose_tfh (
	uid		mediumint UNSIGNED NOT NULL,
	globjid		int UNSIGNED NOT NULL,
	UNIQUE uid_globjid (uid, globjid),
	INDEX globjid (globjid)
) ENGINE=InnoDB;


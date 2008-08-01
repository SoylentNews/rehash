CREATE TABLE tagbox_metamod_history (
	globjid		int UNSIGNED NOT NULL PRIMARY KEY,
	max_tagid_seen	int UNSIGNED NOT NULL,
	last_update	timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP
) ENGINE=InnoDB;


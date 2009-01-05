CREATE TABLE bpn_sources (
	name		VARCHAR(30) NOT NULL,
	active		ENUM('no', 'yes') NOT NULL DEFAULT 'yes',
	source		VARCHAR(255) NOT NULL DEFAULT '',
	regex		VARCHAR(255) NOT NULL DEFAULT '',
	al2name		VARCHAR(30) NOT NULL DEFAULT 'nopostanon',
	PRIMARY KEY name (name)
) TYPE=InnoDB;


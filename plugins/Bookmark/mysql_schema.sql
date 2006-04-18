DROP TABLE IF EXISTS bookmarks;
CREATE TABLE bookmarks (
	bookmark_id MEDIUMINT UNSIGNED NOT NULL auto_increment,
	uid MEDIUMINT UNSIGNED NOT NULL DEFAULT '0',
	url_id MEDIUMINT UNSIGNED NOT NULL,
	createdtime DATETIME NOT NULL,
	title VARCHAR(255),
	PRIMARY KEY(bookmark_id),
	UNIQUE url_id_uid (url_id, uid)
);

DROP TABLE IF EXISTS bookmark_feeds;
CREATE TABLE bookmark_feeds (
	id MEDIUMINT UNSIGNED NOT NULL auto_increment,
	uid MEDIUMINT UNSIGNED NOT NULL,
	feed VARCHAR(255),
	tags VARCHAR(255),
	PRIMARY KEY(id)
) TYPE=InnoDB;

# $Id$

DROP TABLE IF EXISTS uncommonstorywords;
CREATE TABLE uncommonstorywords (
	word VARCHAR(255) NOT NULL,
	PRIMARY KEY (word)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;


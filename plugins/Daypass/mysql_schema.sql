# Create a row in this table to indicate which daypass is available
# when.  Times are in GMT.

CREATE TABLE daypass_available (
	daid		SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
	adnum		SMALLINT NOT NULL DEFAULT 0,
	minduration	SMALLINT NOT NULL DEFAULT 0,
	starttime	DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
	endtime		DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
	aclreq		VARCHAR(32) DEFAULT NULL,
	PRIMARY KEY daid (daid)
) TYPE=InnoDB;

# Creating rows in this table can mark certain skins or stories as
# requiring a daypass (or subscription) to read.  Using this is
# optional (and currently there is no UI for admins to edit this
# data).  To mark a story as daypass/subscription only, add a row
# of type='article', data='[story sid]'.  To mark a skin such that
# only daypass and subscriber users can view its index page or any
# articles with that primaryskid, add a row of type='skin',
# data='[skid]'.  To mark the entire site as requiring a daypass
# to read, set type='site', and data does not matter.
# The restrictions will be enforced from the starttime to the endtime,
# or if endtime is NULL, from the starttime on.
# If this table is empty, daypasses will be optional (and actually
# that's all that is supported in the code right now).

CREATE TABLE daypass_needs (
	type		ENUM('skin', 'site', 'article') NOT NULL DEFAULT 'skin',
	data		VARCHAR(255) NOT NULL,
	starttime	DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
	endtime		DATETIME DEFAULT NULL
) TYPE=InnoDB;

# Here is where daypass keys are temporarily stored, while users are
# looking at the daypass page(s).  Once they have confirmed their key
# by completing the daypass page viewing, key_confirmed is set to
# non-NULL and a row for that user is created in daypass_users.
# Times are in GMT.

CREATE TABLE daypass_keys (
	dpkid			INT UNSIGNED NOT NULL AUTO_INCREMENT,
	daypasskey		CHAR(20) NOT NULL DEFAULT '',
	daid			SMALLINT UNSIGNED NOT NULL DEFAULT 0,
	key_given		DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
	earliest_confirmable	DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
	key_confirmed		DATETIME DEFAULT NULL,
	PRIMARY KEY dpkid (dpkid),
	UNIQUE daypasskey (daypasskey),
	KEY key_given (key_given)
) TYPE=InnoDB;

# Any user with a 'daypass_confcode' cookie in this table where the
# confcode >= NOW() is considered to have a daypass.  It does not
# matter whether the user is logged-in.  The time is in GMT.

CREATE TABLE daypass_confcodes (
	confcode	CHAR(20) NOT NULL DEFAULT '',
	gooduntil	DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
	PRIMARY KEY confcode (confcode)
) TYPE=InnoDB;


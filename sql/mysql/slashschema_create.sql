#	MySQL dump 8.10
#
# Host: localhost	  Database: dump
#--------------------------------------------------------
# Server version	3.23.26-beta
#
# $Id$
#

#
# Table structure for table 'abusers'
#

DROP TABLE IF EXISTS abusers;
CREATE TABLE abusers (
	abuser_id mediumint UNSIGNED NOT NULL auto_increment,
	uid mediumint UNSIGNED NOT NULL,
	ipid char(32) DEFAULT '' NOT NULL,
	subnetid char(32) DEFAULT '' NOT NULL,
	pagename varchar(20) DEFAULT '' NOT NULL,
	ts datetime DEFAULT '1970-01-01 00:00:00' NOT NULL,
	reason varchar(120) DEFAULT '' NOT NULL,
	querystring varchar(200) DEFAULT '' NOT NULL,
	PRIMARY KEY (abuser_id),
	KEY uid (uid),
	KEY ipid (ipid),
	KEY subnetid (subnetid),
	KEY reason (reason),
	KEY ts (ts)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

DROP TABLE IF EXISTS accesslog; 
CREATE TABLE accesslog (
	id int UNSIGNED NOT NULL auto_increment,
	host_addr char(39)	DEFAULT '' NOT NULL,
	subnetid char(39)	DEFAULT '' NOT NULL,
	op varchar(254) default NULL,
	dat varchar(254) default NULL,
	uid mediumint UNSIGNED NOT NULL,
	ts datetime DEFAULT '1970-01-01 00:00:00' NOT NULL,
	query_string varchar(254),
	user_agent varchar(50),
	skid SMALLINT UNSIGNED DEFAULT 0 NOT NULL,
	bytes mediumint UNSIGNED DEFAULT 0 NOT NULL,
	duration FLOAT DEFAULT 0.0 NOT NULL,
	pagemark bigint UNSIGNED DEFAULT 0 NOT NULL,
	local_addr VARCHAR(16) DEFAULT '' NOT NULL,
	static enum("yes","no") DEFAULT "yes",
	secure tinyint DEFAULT 0 NOT NULL,
	referer varchar(254),
	status smallint UNSIGNED DEFAULT 200 NOT NULL,
	INDEX host_addr_part (host_addr(16)),
	INDEX op_part (op(12), skid),
	INDEX ts (ts),
	PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

DROP TABLE IF EXISTS accesslog_admin;
CREATE TABLE accesslog_admin (
	id int UNSIGNED NOT NULL auto_increment,
	host_addr char(39)  DEFAULT '' NOT NULL,
	op varchar(254),
	dat varchar(254),
	uid mediumint UNSIGNED NOT NULL,
	ts datetime DEFAULT '1970-01-01 00:00:00' NOT NULL,
	query_string varchar(50),
	user_agent varchar(50),
	skid SMALLINT UNSIGNED DEFAULT 0 NOT NULL,
	bytes mediumint UNSIGNED DEFAULT 0 NOT NULL,
	form MEDIUMBLOB NOT NULL,
	secure tinyint DEFAULT 0 NOT NULL,
	status smallint UNSIGNED DEFAULT 200 NOT NULL,
	INDEX host_addr (host_addr),
	INDEX ts (ts),
	PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

DROP TABLE IF EXISTS ajax_ops;
CREATE TABLE ajax_ops (
	id mediumint(5) unsigned NOT NULL AUTO_INCREMENT,
	op varchar(50) NOT NULL DEFAULT '',
	class varchar(100) NOT NULL DEFAULT '',
	subroutine varchar(100) NOT NULL DEFAULT '',
	reskey_name varchar(64) NOT NULL DEFAULT '',
	reskey_type varchar(64) NOT NULL DEFAULT '',
	PRIMARY KEY (`id`),
	UNIQUE KEY op (op)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

DROP TABLE IF EXISTS accesslog_artcom;
CREATE TABLE accesslog_artcom (
	uid mediumint UNSIGNED NOT NULL,
	ts datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
	c smallint unsigned NOT NULL DEFAULT '0',
	INDEX uid (uid),
	INDEX ts (ts)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'al2'
# (The 'value' column could and should be of type BIT(32), if
# Slash required MySQL 5.0.5 or later.  Since we dont, the
# code in MySQL.pm treats the INT UNSIGNED like a bit field.)
#

DROP TABLE IF EXISTS al2;
CREATE TABLE al2 (
	srcid           BIGINT UNSIGNED NOT NULL DEFAULT '0',
	value           INT UNSIGNED NOT NULL DEFAULT '0',
	updatecount     INT UNSIGNED NOT NULL DEFAULT '0',
	PRIMARY KEY (srcid),
	INDEX value (value)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'al2_log'
#
DROP TABLE IF EXISTS al2_log;
CREATE TABLE al2_log (
	al2lid          INT UNSIGNED NOT NULL AUTO_INCREMENT,
	srcid           BIGINT UNSIGNED NOT NULL DEFAULT '0',
	ts              DATETIME NOT NULL DEFAULT '1970-01-01 00:00:00',
	adminuid        MEDIUMINT UNSIGNED NOT NULL DEFAULT '0',
	al2tid          TINYINT UNSIGNED NOT NULL DEFAULT '0',
	val             ENUM('set', 'clear') DEFAULT NULL,
	PRIMARY KEY (al2lid),
	INDEX ts (ts),
	INDEX srcid_ts (srcid, ts),
	INDEX al2tid_val_srcid (al2tid, val, srcid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'al2_log_comments'
#
DROP TABLE IF EXISTS al2_log_comments;
CREATE TABLE al2_log_comments (
	al2lid          INT UNSIGNED NOT NULL DEFAULT '0',
	comment         TEXT NOT NULL DEFAULT '',
	PRIMARY KEY (al2lid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'al2_types'
#
DROP TABLE IF EXISTS al2_types;
CREATE TABLE al2_types (
	al2tid          TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
	bitpos          TINYINT UNSIGNED DEFAULT NULL,
	name            VARCHAR(30) NOT NULL DEFAULT '',
	title           VARCHAR(64) NOT NULL DEFAULT '',
	PRIMARY KEY (al2tid),
	UNIQUE name (name),
	UNIQUE bitpos (bitpos)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'authors_cache'
#

DROP TABLE IF EXISTS authors_cache;
CREATE TABLE authors_cache (
	uid mediumint UNSIGNED NOT NULL auto_increment,
	nickname varchar(20) NOT NULL,
	fakeemail varchar(75) NOT NULL,
	homepage varchar(100) NOT NULL,
	storycount mediumint NOT NULL,
	bio text NOT NULL,
	author tinyint DEFAULT 0 NOT NULL,
	PRIMARY KEY (uid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'backup_blocks'
#

DROP TABLE IF EXISTS backup_blocks;
CREATE TABLE backup_blocks (
	bid varchar(30) DEFAULT '' NOT NULL,
	block text,
	PRIMARY KEY (bid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'badpasswords'
#

DROP TABLE IF EXISTS badpasswords;
CREATE TABLE badpasswords (
	uid mediumint(8) UNSIGNED NOT NULL DEFAULT 0,
	ip varchar(255) NOT NULL DEFAULT '',
	subnet varchar(255) NOT NULL DEFAULT '',
	password varchar(20) NOT NULL DEFAULT '',
	ts timestamp NOT NULL,
	realemail VARCHAR(50) NOT NULL DEFAULT '',
	INDEX uid (uid),
	INDEX ip (ip),
	INDEX subnet (subnet)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'blocks'
#

DROP TABLE IF EXISTS blocks;
CREATE TABLE blocks (
	id mediumint(8) UNSIGNED NOT NULL auto_increment,
	bid varchar(30) DEFAULT '' NOT NULL,
	block text,
	seclev mediumint UNSIGNED NOT NULL DEFAULT '0',
	type ENUM('static','portald') DEFAULT 'static' NOT NULL,
	description text,
	skin varchar(30) NOT NULL,
	ordernum tinyint DEFAULT '0',
	title varchar(128) NOT NULL,
	default_block tinyint UNSIGNED DEFAULT '0' NOT NULL,
	hidden tinyint UNSIGNED DEFAULT '0' NOT NULL,
	always_on tinyint UNSIGNED DEFAULT '0' NOT NULL,
	portal tinyint NOT NULL DEFAULT '0',
	url varchar(128),
	rdf varchar(255),
	retrieve tinyint NOT NULL DEFAULT '0',
	last_update timestamp NOT NULL,
	rss_template varchar(30),
	items smallint NOT NULL DEFAULT '0', 
	autosubmit ENUM('no','yes') DEFAULT 'no' NOT NULL,
	rss_cookie varchar(255),
	all_skins tinyint NOT NULL DEFAULT '0',
	shill enum('yes','no') NOT NULL default 'no',
	shill_uid mediumint(8) unsigned NOT NULL default '0',
	PRIMARY KEY (id),
	UNIQUE KEY bid (bid),
	KEY type (type),
	KEY skin (skin)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'classes'
#

DROP TABLE IF EXISTS classes;
CREATE TABLE classes (
	id mediumint UNSIGNED NOT NULL auto_increment,
	class varchar(255) NOT NULL,
	db_type enum("writer","reader","log","search") DEFAULT "writer" NOT NULL,
	fallback enum("writer","reader","log","search"),
	UNIQUE class_key (class),
	PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'clout_types'
#

DROP TABLE IF EXISTS clout_types;
CREATE TABLE clout_types (
	clid		smallint UNSIGNED NOT NULL AUTO_INCREMENT,
	name		varchar(16) NOT NULL,
	class		varchar(255) NOT NULL,
	PRIMARY KEY (clid),
	UNIQUE name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'code_param'
#

DROP TABLE IF EXISTS code_param;
CREATE TABLE code_param (
	param_id smallint UNSIGNED NOT NULL auto_increment,
	type varchar(24) NOT NULL,
	code tinyint DEFAULT '0' NOT NULL,
	name varchar(32) NOT NULL,
	UNIQUE code_key (type,code),
	PRIMARY KEY (param_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'commentmodes'
#

DROP TABLE IF EXISTS commentmodes;
CREATE TABLE commentmodes (
	mode varchar(16) DEFAULT '' NOT NULL,
	name varchar(32),
	description varchar(64),
	PRIMARY KEY (mode)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'comments'
#

DROP TABLE IF EXISTS comments;
CREATE TABLE comments (
	sid mediumint UNSIGNED NOT NULL,
	cid int UNSIGNED NOT NULL auto_increment,
	pid int UNSIGNED DEFAULT '0' NOT NULL,
	date datetime DEFAULT '1970-01-01 00:00:00' NOT NULL,
	last_update TIMESTAMP NOT NULL,
	ipid char(32) DEFAULT '' NOT NULL,
	subnetid char(32) DEFAULT '' NOT NULL,
	subject varchar(50) NOT NULL,
	subject_orig ENUM('no', 'yes') DEFAULT 'yes' NOT NULL,
	uid mediumint UNSIGNED NOT NULL,
	points tinyint DEFAULT '0' NOT NULL,
	pointsorig tinyint DEFAULT '0' NOT NULL,
	pointsmax tinyint DEFAULT '0' NOT NULL,
	lastmod mediumint UNSIGNED DEFAULT '0' NOT NULL,
	reason tinyint UNSIGNED DEFAULT '0' NOT NULL,
	signature char(32) DEFAULT '' NOT NULL,
	karma_bonus enum('yes', 'no') DEFAULT 'no' NOT NULL,
	len smallint UNSIGNED DEFAULT '0' NOT NULL,
	karma smallint DEFAULT '0' NOT NULL,
	karma_abs smallint UNSIGNED DEFAULT '0' NOT NULL,
	tweak_orig TINYINT NOT NULL DEFAULT 0,
	tweak TINYINT NOT NULL DEFAULT 0,
    badge_id tinyint NOT NULL DEFAULT 0,
	spam_flag tinyint NOT NULL DEFAULT 0,
	PRIMARY KEY (cid),
	KEY display (sid,points,uid),
	KEY byname (uid,points),
	KEY ipid (ipid),
	KEY subnetid (subnetid),
	KEY theusual (sid,uid,points,cid),
	KEY countreplies (pid,sid),
	KEY uid_date (uid,date),
	KEY date_sid (date,sid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'comment_log'
#

DROP TABLE IF EXISTS comment_log;

CREATE TABLE comment_log (
	id int UNSIGNED NOT NULL auto_increment,
	cid int UNSIGNED NOT NULL,
	logtext varchar(255) DEFAULT '' NOT NULL,
	ts datetime DEFAULT '1970-01-01 00:00:00' NOT NULL,
	INDEX ts (ts),
	PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'comment_promote_log'
#
DROP TABLE IF EXISTS comment_promote_log;

CREATE TABLE comment_promote_log (
	id int unsigned NOT NULL auto_increment,
	cid int unsigned NOT NULL default '0',
	ts datetime NOT NULL default '1970-01-01 00:00:00',
	PRIMARY KEY  (id),
	KEY cid (cid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci; 




#
# Table structure for table 'comment_text'
#

DROP TABLE IF EXISTS comment_text;
CREATE TABLE comment_text (
	cid int UNSIGNED NOT NULL,
	comment text NOT NULL,
	PRIMARY KEY (cid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'content_filters'
#

DROP TABLE IF EXISTS content_filters;
CREATE TABLE content_filters (
	filter_id tinyint UNSIGNED NOT NULL auto_increment,
	form varchar(20) DEFAULT '' NOT NULL,
	regex varchar(100) DEFAULT '' NOT NULL,
	modifier varchar(5) DEFAULT '' NOT NULL,
	field varchar(20) DEFAULT '' NOT NULL,
	ratio float(6,4) DEFAULT '0.0000' NOT NULL,
	minimum_match mediumint(6) DEFAULT '0' NOT NULL,
	minimum_length mediumint DEFAULT '0' NOT NULL,
	err_message varchar(150) DEFAULT '',
	PRIMARY KEY (filter_id),
	KEY form (form),
	KEY regex (regex),
	KEY field_key (field)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'css_type'
#
DROP TABLE IF EXISTS css_type;
CREATE TABLE css_type (
	ctid TINYINT(3) UNSIGNED NOT NULL AUTO_INCREMENT,
	name VARCHAR(32) NOT NULL DEFAULT '',
	ordernum TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',
	PRIMARY KEY  (ctid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'css'
#

DROP TABLE IF EXISTS css;
CREATE TABLE css (
	csid int(11) NOT NULL AUTO_INCREMENT,
	rel VARCHAR(32) DEFAULT 'stylesheet',
	type VARCHAR(32) DEFAULT 'text/css',
	media VARCHAR(32) DEFAULT 'screen, projection',
	file VARCHAR(64),
	title VARCHAR(32),
	skin VARCHAR(32) DEFAULT '',
	page VARCHAR(32) DEFAULT '',
	admin ENUM('no','yes') DEFAULT 'no',
	theme VARCHAR(32) DEFAULT '',
	ctid TINYINT(4) NOT NULL DEFAULT '0',
	ordernum int(11) DEFAULT '0',
	ie_cond VARCHAR(16) DEFAULT '',
	lowbandwidth ENUM('no','yes') DEFAULT 'no',
	layout VARCHAR(16) DEFAULT '',
	PRIMARY KEY  (csid),
	KEY ctid (ctid),
	KEY page_skin (page,skin),
	KEY skin_page (skin,page),
	KEY layout (layout)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'dateformats'
#

DROP TABLE IF EXISTS dateformats;
CREATE TABLE dateformats (
	id tinyint UNSIGNED DEFAULT '0' NOT NULL,
	format varchar(64),
	description varchar(64),
	PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'dbs'
#

DROP TABLE IF EXISTS dbs;
CREATE TABLE dbs (
	id mediumint UNSIGNED NOT NULL auto_increment,
	virtual_user varchar(100) NOT NULL,
	isalive enum("no","yes") DEFAULT "no" NOT NULL,
	type enum("writer","reader","log","search", "log_slave","querylog") DEFAULT "reader" NOT NULL,
	weight tinyint UNSIGNED NOT NULL DEFAULT 1,
	weight_adjust float UNSIGNED NOT NULL DEFAULT 1.0,
	PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'dbs_readerstatus'
#

DROP TABLE IF EXISTS dbs_readerstatus;
CREATE TABLE dbs_readerstatus (
	ts datetime DEFAULT '1970-01-01 00:00:00' NOT NULL,
	dbid mediumint UNSIGNED NOT NULL,
	was_alive enum("no","yes") DEFAULT "yes" NOT NULL,
	was_reachable enum("no","yes") DEFAULT "yes",
	was_running enum("no","yes") DEFAULT "yes",
	slave_lag_secs float DEFAULT '0',
	query_bog_secs float DEFAULT '0',
	bog_rsqid mediumint UNSIGNED DEFAULT NULL,
	had_weight tinyint UNSIGNED DEFAULT 1,
	had_weight_adjust float UNSIGNED DEFAULT 1,
	KEY ts_dbid (ts, dbid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'dbs_readerstatus_queries'
#

DROP TABLE IF EXISTS dbs_readerstatus_queries;
CREATE TABLE dbs_readerstatus_queries (
	rsqid mediumint UNSIGNED NOT NULL auto_increment,
	text varchar(255),
	PRIMARY KEY (rsqid),
	KEY text (text)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'discussions'
#

DROP TABLE IF EXISTS discussions;
CREATE TABLE discussions (
	id mediumint UNSIGNED NOT NULL auto_increment, 
	dkid TINYINT UNSIGNED NOT NULL DEFAULT 1,
	stoid mediumint UNSIGNED DEFAULT '0' NOT NULL,
	sid char(16) DEFAULT '' NOT NULL,
	title varchar(128) NOT NULL,
	url varchar(255) NOT NULL,
	topic int UNSIGNED NOT NULL,
	ts datetime DEFAULT '1970-01-01 00:00:00' NOT NULL,
	type ENUM("open","recycle","archived") DEFAULT 'open' NOT NULL,
	uid mediumint UNSIGNED NOT NULL,
	commentcount smallint UNSIGNED DEFAULT '0' NOT NULL,
	flags ENUM("ok","delete","dirty") DEFAULT 'ok' NOT NULL,
	primaryskid SMALLINT UNSIGNED,
	last_update timestamp NOT NULL,
	approved tinyint UNSIGNED DEFAULT 0 NOT NULL,
	commentstatus ENUM('disabled','enabled','friends_only','friends_fof_only','no_foe','no_foe_eof','logged_in') DEFAULT 'enabled' NOT NULL, /* Default is that we allow anyone to write */
	archivable ENUM("no","yes") DEFAULT "yes" NOT NULL,
	KEY (stoid),
	KEY (sid),
	KEY (topic),
	KEY (primaryskid,ts),
	INDEX (type,uid,ts),
	PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'discussion_kinds'
#

DROP TABLE IF EXISTS discussion_kinds;
CREATE TABLE discussion_kinds (
	dkid        TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
	name        VARCHAR(30) NOT NULL DEFAULT '',
	PRIMARY KEY (dkid),
	UNIQUE name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'dst'
#

DROP TABLE IF EXISTS dst;
CREATE TABLE dst (
	region        VARCHAR(32)   NOT NULL,
	selectable    TINYINT       DEFAULT 0 NOT NULL,
	start_hour    TINYINT       NOT NULL,
	start_wnum    TINYINT       NOT NULL,
	start_wday    TINYINT       NOT NULL,
	start_month   TINYINT       NOT NULL,
	end_hour      TINYINT       NOT NULL,
	end_wnum      TINYINT       NOT NULL,
	end_wday      TINYINT       NOT NULL,
	end_month     TINYINT       NOT NULL,
	PRIMARY KEY (region)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;


#
# Table structure for table 'file_queue'
#
DROP TABLE IF EXISTS file_queue;
CREATE TABLE file_queue (
	fqid int(10) unsigned NOT NULL auto_increment,
	stoid mediumint(8) unsigned default NULL,
	fhid mediumint(8) unsigned default NULL,
	file varchar(255) default NULL,
	action enum('upload','thumbnails','sprite') default NULL,
	blobid VARCHAR(32) DEFAULT "" NOT NULL,
	PRIMARY KEY  (fqid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'formkeys'
#

DROP TABLE IF EXISTS formkeys;
CREATE TABLE formkeys (
	formkey varchar(20) DEFAULT '' NOT NULL,
	formname varchar(32) DEFAULT '' NOT NULL,
	id varchar(30) DEFAULT '' NOT NULL,
	idcount mediumint UNSIGNED DEFAULT 0 NOT NULL,
	uid mediumint UNSIGNED NOT NULL,
	ipid	char(32) DEFAULT '' NOT NULL,
	subnetid	char(32) DEFAULT '' NOT NULL,
	value tinyint DEFAULT '0' NOT NULL,
	last_ts int UNSIGNED DEFAULT '0' NOT NULL,
	ts int UNSIGNED DEFAULT '0' NOT NULL,
	submit_ts int UNSIGNED DEFAULT '0' NOT NULL,
	content_length smallint UNSIGNED DEFAULT '0' NOT NULL,
	PRIMARY KEY (formkey),
	KEY formname (formname),
	KEY uid (uid),
	KEY ipid (ipid),
	KEY subnetid (subnetid),
	KEY idcount (idcount),
	KEY ts (ts),
	KEY last_ts (ts),
	KEY submit_ts (submit_ts)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'globjs' (global objects)
#

DROP TABLE IF EXISTS globjs;
CREATE TABLE globjs (
	globjid		int UNSIGNED NOT NULL auto_increment,
	gtid		smallint UNSIGNED NOT NULL,
	target_id	int UNSIGNED NOT NULL,
	PRIMARY KEY (globjid),
	UNIQUE target (gtid, target_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'globj_adminnotes'
#

DROP TABLE IF EXISTS globj_adminnotes;
CREATE TABLE globj_adminnotes (
	globjid		int UNSIGNED NOT NULL AUTO_INCREMENT,
	adminnote	varchar(255) NOT NULL DEFAULT '',
	PRIMARY KEY (globjid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'globj_types'
#

DROP TABLE IF EXISTS globj_types;
CREATE TABLE globj_types (
	gtid		smallint UNSIGNED NOT NULL auto_increment,
	maintable	VARCHAR(64) NOT NULL,
	PRIMARY KEY (gtid),
	UNIQUE maintable (maintable)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'globj_urls'
#

DROP TABLE IF EXISTS globj_urls;
CREATE TABLE globj_urls (
	id INT(10) UNSIGNED NOT NULL auto_increment,
	globjid INT UNSIGNED NOT NULL DEFAULT 0,
	url_id INT(10) UNSIGNED NOT NULL NOT NULL DEFAULT 0,
	PRIMARY KEY (id),
	UNIQUE globjid_url_id (globjid, url_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'hooks'
#

DROP TABLE IF EXISTS hooks;
CREATE TABLE hooks (
	id mediumint(5) UNSIGNED NOT NULL auto_increment,
	param varchar(50) DEFAULT '' NOT NULL,
	class varchar(100) DEFAULT '' NOT NULL,
	subroutine varchar(100) DEFAULT '' NOT NULL,
	PRIMARY KEY (id),
	UNIQUE hook_param (param,class,subroutine)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'menus'
#

DROP TABLE IF EXISTS menus;
CREATE TABLE menus (
	id mediumint(5) UNSIGNED NOT NULL auto_increment,
	menu varchar(20) DEFAULT '' NOT NULL,
	label varchar(255) DEFAULT '' NOT NULL,
	sel_label varchar(32) NOT NULL DEFAULT '',
	value text,
	seclev mediumint UNSIGNED NOT NULL,
	showanon tinyint DEFAULT '0' NOT NULL,
	menuorder mediumint(5),
	PRIMARY KEY (id),
	KEY page_labels (menu,label),
	UNIQUE page_labels_un (menu,label)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'misc_user_opts'
#

DROP TABLE IF EXISTS misc_user_opts;
CREATE TABLE misc_user_opts (
	name varchar(32) NOT NULL,
	optorder mediumint(5),
	seclev mediumint UNSIGNED NOT NULL,
	default_val text NOT NULL,
	vals_regex text,
	short_desc text,
	long_desc text,
	opts_html text,
	PRIMARY KEY (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'open_proxies'
#

DROP TABLE IF EXISTS open_proxies;
CREATE TABLE open_proxies (
        ip	VARCHAR(15) NOT NULL,
	port	SMALLINT UNSIGNED NOT NULL DEFAULT '0',
	dur	FLOAT DEFAULT NULL,
	ts	DATETIME NOT NULL DEFAULT '1970-01-01 00:00:00',
	xff	VARCHAR(40) DEFAULT NULL,
	ipid	CHAR(32) DEFAULT '' NOT NULL,
	PRIMARY KEY (ip),
	KEY ts (ts),
	KEY ipid (ipid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'pagemark'
#

DROP TABLE IF EXISTS pagemark;
CREATE TABLE pagemark (
	id		int UNSIGNED NOT NULL AUTO_INCREMENT,
	pagemark	bigint UNSIGNED DEFAULT 0 NOT NULL,
	ts		datetime NOT NULL DEFAULT '1970-01-01 00:00:00',
	dom		float DEFAULT 0 NOT NULL,
	js		float DEFAULT 0 NOT NULL,
	PRIMARY KEY id (id),
	UNIQUE pagemark (pagemark),
	KEY ts (ts)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'pollanswers'
#

DROP TABLE IF EXISTS pollanswers;
CREATE TABLE pollanswers (
	qid mediumint UNSIGNED NOT NULL,
	aid mediumint NOT NULL,
	answer char(255),
	votes mediumint,
	PRIMARY KEY (qid,aid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'pollquestions'
#

DROP TABLE IF EXISTS pollquestions;
CREATE TABLE pollquestions (
	qid mediumint UNSIGNED NOT NULL auto_increment,
	question char(255) NOT NULL,
	voters mediumint,
	topic smallint UNSIGNED NOT NULL,
	discussion mediumint UNSIGNED NULL,
	date datetime,
	uid mediumint UNSIGNED NOT NULL,
	primaryskid SMALLINT UNSIGNED,
	autopoll ENUM("no","yes") DEFAULT 'no' NOT NULL,
	flags ENUM("ok","delete","dirty") DEFAULT 'ok' NOT NULL,
	polltype enum('nodisplay','section','story') default 'section',
	PRIMARY KEY (qid),
	KEY uid (uid),
	KEY discussion (discussion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'pollvoters'
#

DROP TABLE IF EXISTS pollvoters;
CREATE TABLE pollvoters (
	qid mediumint NOT NULL,
	id char(35) NOT NULL,
	time datetime,
	uid mediumint UNSIGNED NOT NULL,
	KEY qid (qid,id,uid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'preview'
#

DROP TABLE IF EXISTS preview;
CREATE TABLE preview (
	preview_id mediumint UNSIGNED NOT NULL auto_increment,
	uid mediumint UNSIGNED NOT NULL,
	src_fhid mediumint UNSIGNED NOT NULL DEFAULT 0,
	preview_fhid mediumint UNSIGNED NOT NULL DEFAULT 0,
	title VARCHAR(255) NOT NULL DEFAULT '',
	introtext text NOT NULL,
	bodytext text NOT NULL,
	active ENUM("no","yes") DEFAULT "yes",
	PRIMARY KEY (preview_id),
	KEY uid (uid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;


#
# Table structure for table 'preview_param'
#

DROP TABLE IF EXISTS preview_param;
CREATE TABLE preview_param (
	param_id mediumint UNSIGNED NOT NULL auto_increment,
	preview_id mediumint UNSIGNED NOT NULL,
	name varchar(32) DEFAULT '' NOT NULL,
	value text NOT NULL,
	UNIQUE submission_key (preview_id,name),
	PRIMARY KEY (param_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;


DROP TABLE IF EXISTS projects;
CREATE TABLE projects (
	id mediumint UNSIGNED NOT NULL auto_increment,
	uid mediumint UNSIGNED NOT NULL DEFAULT 0,
	unixname varchar(24) NOT NULL DEFAULT '',
	textname varchar(64) NOT NULL DEFAULT '',
	url_id INT(10) UNSIGNED NOT NULL DEFAULT 0,
	createtime DATETIME DEFAULT '1970-01-01 00:00:00' NOT NULL,
	srcname varchar(32) NOT NULL DEFAULT 0,
	description         TEXT NOT NULL DEFAULT '',
	PRIMARY KEY (id),
	UNIQUE unixname (unixname)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'querylog'
#

DROP TABLE IF EXISTS querylog;
CREATE TABLE querylog (
	id int UNSIGNED NOT NULL auto_increment,
	type enum('SELECT','INSERT','UPDATE','DELETE','REPLACE') NOT NULL DEFAULT 'SELECT',
	thetables varchar(40) NOT NULL DEFAULT '',
	ts timestamp NOT NULL,
	package varchar(24) NOT NULL DEFAULT '',
	line mediumint UNSIGNED NOT NULL DEFAULT '0',
	package1 varchar(24) NOT NULL DEFAULT '',
	line1 mediumint UNSIGNED NOT NULL DEFAULT '0',
	duration float NOT NULL DEFAULT '0',
	PRIMARY KEY (id),
	KEY caller (package, line),
	KEY ts (ts),
	KEY type (type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

DROP TABLE IF EXISTS related_stories;
CREATE TABLE related_stories (
	id mediumint(8) unsigned NOT NULL auto_increment,
	stoid mediumint(8) unsigned default '0',
	rel_stoid mediumint(8) unsigned default '0',
	rel_sid varchar(16) NOT NULL default '',
	title varchar(255) default '',
	url varchar(255) default '',
	cid int(8) unsigned NOT NULL default '0',
	ordernum smallint unsigned NOT NULL default '0',
	fhid mediumint(8) unsigned NOT NULL default '0',
	PRIMARY KEY (id),
	KEY stoid (stoid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'rss_raw'
#

DROP TABLE IF EXISTS rss_raw;
CREATE TABLE rss_raw (
	id mediumint UNSIGNED NOT NULL auto_increment,
	link_signature char(32) DEFAULT '' NOT NULL,
	title_signature char(32) DEFAULT '' NOT NULL,
	description_signature char(32) DEFAULT '' NOT NULL,
	link varchar(255) NOT NULL,
	title varchar(255) NOT NULL,
	description text,
	subid mediumint UNSIGNED,
	bid varchar(30),
	created datetime, 
	processed ENUM("no","yes") DEFAULT 'no' NOT NULL,
	UNIQUE uber_signature (link_signature, title_signature, description_signature),
	PRIMARY KEY (id),
	KEY processed (processed)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'related_links'
#

DROP TABLE IF EXISTS related_links;
CREATE TABLE related_links (
	id smallint UNSIGNED NOT NULL auto_increment,
	keyword varchar(30) NOT NULL,
	name varchar(30) NOT NULL,
	link varchar(128) NOT NULL,
	KEY (keyword),
	PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'remarks'
#

DROP TABLE IF EXISTS remarks;
CREATE TABLE remarks (
	rid MEDIUMINT UNSIGNED NOT NULL auto_increment,
	uid MEDIUMINT UNSIGNED NOT NULL,
	stoid MEDIUMINT UNSIGNED NOT NULL,
	priority SMALLINT UNSIGNED NOT NULL DEFAULT 0,
	time DATETIME DEFAULT '1970-01-01 00:00:00' NOT NULL,
	type ENUM("system","user") DEFAULT "user",
	remark VARCHAR(100),
	PRIMARY KEY (rid),
	INDEX uid (uid),
	INDEX stoid (stoid),
	INDEX time (time),
	INDEX priority (priority)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'sessions'
#

DROP TABLE IF EXISTS sessions;
CREATE TABLE sessions (
	session mediumint UNSIGNED NOT NULL auto_increment,
	uid mediumint UNSIGNED,
	lasttime datetime,
	lasttitle varchar(50),
	last_subid mediumint UNSIGNED,
	last_sid varchar(16),
	last_fhid mediumint UNSIGNED,
	last_action varchar(16),
	UNIQUE (uid),
	PRIMARY KEY (session)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

DROP TABLE IF EXISTS shill_ids;
CREATE TABLE shill_ids (
	shill_id TINYINT UNSIGNED DEFAULT 0 NOT NULL PRIMARY KEY,
	user varchar(16) NOT NULL default ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

DROP TABLE IF EXISTS signoff;
CREATE TABLE signoff (
        soid 	MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	stoid		MEDIUMINT UNSIGNED NOT NULL DEFAULT '0',
  	uid 		MEDIUMINT UNSIGNED NOT NULL,
	signoff_time	TIMESTAMP,
	signoff_type	VARCHAR(16) DEFAULT '' NOT NULL,
	PRIMARY KEY(soid),
	INDEX (stoid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
				
#
# Table structure for table 'site_info'
#

DROP TABLE IF EXISTS site_info;
CREATE TABLE site_info (
	param_id mediumint UNSIGNED NOT NULL auto_increment,
	name varchar(50) NOT NULL,
	value varchar(200) NOT NULL,
	description varchar(255),
	UNIQUE site_keys (name,value),
	PRIMARY KEY (param_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'skins'
#

DROP TABLE IF EXISTS skins;
CREATE TABLE skins (
	skid SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
	nexus INT UNSIGNED NOT NULL,
	artcount_min MEDIUMINT UNSIGNED DEFAULT '10' NOT NULL,
	artcount_max MEDIUMINT UNSIGNED DEFAULT '30' NOT NULL,
	older_stories_max MEDIUMINT UNSIGNED DEFAULT '0' NOT NULL,
	name VARCHAR(30) NOT NULL,
	othername VARCHAR(30) NOT NULL DEFAULT '',
	title VARCHAR(64) DEFAULT '' NOT NULL,
	issue ENUM('no', 'yes') DEFAULT 'no' NOT NULL,
	submittable ENUM('no', 'yes') DEFAULT 'yes' NOT NULL,
	searchable ENUM('no', 'yes') DEFAULT 'yes' NOT NULL,
	storypickable ENUM('no', 'yes') DEFAULT 'yes' NOT NULL,
	skinindex ENUM('no', 'yes') DEFAULT 'yes' NOT NULL,
	url VARCHAR(255) DEFAULT '' NOT NULL,
	hostname VARCHAR(128) DEFAULT '' NOT NULL,
	cookiedomain VARCHAR(128) DEFAULT '' NOT NULL,
	index_handler VARCHAR(30) DEFAULT 'index.pl' NOT NULL,
	max_rewrite_secs MEDIUMINT UNSIGNED DEFAULT '3600' NOT NULL,
	last_rewrite timestamp NOT NULL,
	ac_uid mediumint UNSIGNED DEFAULT '0' NOT NULL,
	require_acl VARCHAR(32) DEFAULT '' NOT NULL,
	PRIMARY KEY (skid),
	UNIQUE name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'skin_colors'
#

DROP TABLE IF EXISTS skin_colors;
CREATE TABLE skin_colors (
	skid SMALLINT UNSIGNED NOT NULL,
	name VARCHAR(24) NOT NULL,
	skincolor CHAR(12) NOT NULL,
	UNIQUE skid_name (skid, name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'slashd_status'
#

DROP TABLE IF EXISTS slashd_status;
CREATE TABLE slashd_status (
	task VARCHAR(50) NOT NULL,
	hostname VARCHAR(255) NOT NULL DEFAULT '',
	next_begin DATETIME,
	in_progress TINYINT NOT NULL DEFAULT '0',
	last_completed DATETIME,
	summary VARCHAR(255) NOT NULL DEFAULT '',
	duration float(6,2) DEFAULT '0.00' NOT NULL,
	PRIMARY KEY (task)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'slashd_errnotes'
#

DROP TABLE IF EXISTS slashd_errnotes;
CREATE TABLE slashd_errnotes (
	ts DATETIME NOT NULL DEFAULT '1970-01-01 00:00:00',
	taskname VARCHAR(50) NOT NULL DEFAULT 'SLASHD',
	line MEDIUMINT UNSIGNED NOT NULL DEFAULT '0',
	errnote VARCHAR(255) NOT NULL DEFAULT '',
	moreinfo TEXT DEFAULT NULL,
	INDEX (ts),
	INDEX taskname_ts (taskname, ts)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'soap_methods'
#

DROP TABLE IF EXISTS soap_methods;
CREATE TABLE soap_methods (
        id MEDIUMINT(5) UNSIGNED NOT NULL AUTO_INCREMENT,
        class VARCHAR(100) NOT NULL,
        method VARCHAR(100) NOT NULL,
        seclev MEDIUMINT DEFAULT 1000 NOT NULL,
        subscriber_only TINYINT DEFAULT 0 NOT NULL,
        formkeys VARCHAR(255) DEFAULT '' NOT NULL,
        PRIMARY KEY (id),
        UNIQUE soap_method(class, method)
);

#
# Table structure for table 'spamarmors'
#

DROP TABLE IF EXISTS spamarmors;
CREATE TABLE spamarmors (
	armor_id mediumint UNSIGNED NOT NULL auto_increment,
	name varchar(40) default NULL,
	code text,
	active mediumint default '1',
	PRIMARY KEY  (armor_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;


#
# Table structure for table 'stories'
#

DROP TABLE IF EXISTS stories;
CREATE TABLE stories (
	stoid MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	sid CHAR(16) NOT NULL,
	uid MEDIUMINT UNSIGNED NOT NULL,
	dept VARCHAR(100),
	time DATETIME DEFAULT '1970-01-01 00:00:00' NOT NULL,
	hits MEDIUMINT UNSIGNED DEFAULT '0' NOT NULL,
	discussion MEDIUMINT UNSIGNED,
	primaryskid SMALLINT UNSIGNED,
	tid INT UNSIGNED,
	submitter MEDIUMINT UNSIGNED NOT NULL,
	commentcount SMALLINT UNSIGNED DEFAULT '0' NOT NULL,
	hitparade VARCHAR(64) DEFAULT '0,0,0,0,0,0,0' NOT NULL,
	is_archived ENUM('no', 'yes') DEFAULT 'no' NOT NULL,
	in_trash ENUM('no', 'yes') DEFAULT 'no' NOT NULL,
	day_published DATE DEFAULT '1970-01-01' NOT NULL,
	qid MEDIUMINT UNSIGNED DEFAULT NULL,
	last_update TIMESTAMP NOT NULL,
	body_length MEDIUMINT UNSIGNED DEFAULT 0 NOT NULL,
	word_count MEDIUMINT UNSIGNED DEFAULT 0 NOT NULL,
	archive_last_update DATETIME DEFAULT '1970-01-01 00:00:00' NOT NULL,
	notes VARCHAR(1023) NULL DEFAULT '',
	PRIMARY KEY (stoid),
	UNIQUE sid (sid),
	INDEX uid (uid),
	INDEX is_archived (is_archived),
	INDEX time (time),
	INDEX submitter (submitter),
	INDEX day_published (day_published),
	INDEX skidtid (primaryskid, tid),
	INDEX discussion_stoid (discussion, stoid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'story_dirty'
#

DROP TABLE IF EXISTS story_dirty;
CREATE TABLE story_dirty (
	stoid MEDIUMINT UNSIGNED NOT NULL,
	PRIMARY KEY (stoid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'story_render_dirty'
#

DROP TABLE IF EXISTS story_render_dirty;
CREATE TABLE story_render_dirty (
	stoid MEDIUMINT UNSIGNED NOT NULL,
	PRIMARY KEY (stoid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'story_text'
#

DROP TABLE IF EXISTS story_text;
CREATE TABLE story_text (
	stoid MEDIUMINT UNSIGNED NOT NULL,
	title VARCHAR(100) DEFAULT '' NOT NULL,
	introtext text,
	bodytext text,
	relatedtext text,
	rendered text,
	PRIMARY KEY (stoid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'story_param'
#

DROP TABLE IF EXISTS story_param;
CREATE TABLE story_param (
	param_id mediumint UNSIGNED NOT NULL auto_increment,
	stoid MEDIUMINT UNSIGNED NOT NULL,
	name varchar(32) DEFAULT '' NOT NULL,
	value text NOT NULL,
	UNIQUE story_key (stoid,name),
	PRIMARY KEY (param_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'story_topics_chosen'
#

DROP TABLE IF EXISTS story_topics_chosen;
CREATE TABLE story_topics_chosen (
	stoid MEDIUMINT UNSIGNED NOT NULL,
	tid INT(5) UNSIGNED NOT NULL,
	weight FLOAT DEFAULT 1 NOT NULL,
	UNIQUE story_topic (stoid, tid),
	INDEX tid_stoid (tid, stoid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'story_topics_rendered'
#

DROP TABLE IF EXISTS story_topics_rendered;
CREATE TABLE story_topics_rendered (
	stoid MEDIUMINT UNSIGNED NOT NULL,
	tid INT(5) UNSIGNED NOT NULL,
	UNIQUE story_topic (stoid, tid),
	INDEX tid_stoid (tid, stoid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;


#
# Table structure for table 'static_files'
#

DROP TABLE IF EXISTS static_files;
CREATE TABLE static_files(
	sfid mediumint unsigned NOT NULL auto_increment,
	stoid mediumint unsigned NOT NULL,
	fhid mediumint unsigned NOT NULL,
	filetype ENUM("file", "image", "audio") not null default "file",
	name varchar(255) default '' NOT NULL,
	width smallint unsigned not null default 0,
	height smallint unsigned not null default 0,
	PRIMARY KEY (sfid),
	INDEX stoid(stoid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'string_param'
#

DROP TABLE IF EXISTS string_param;
CREATE TABLE string_param (
	param_id smallint UNSIGNED NOT NULL auto_increment,
	type varchar(32) NOT NULL,
	code varchar(128) NOT NULL,
	name varchar(64) NOT NULL,
	UNIQUE code_key (type,code),
	PRIMARY KEY (param_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'submissions'
#

DROP TABLE IF EXISTS submissions;
CREATE TABLE submissions (
	subid mediumint UNSIGNED NOT NULL auto_increment,
	email varchar(255) DEFAULT '' NOT NULL,
	emaildomain varchar(255) DEFAULT '' NOT NULL,
	name varchar(50) NOT NULL,
	time datetime NOT NULL,
	subj varchar(100) NOT NULL,
	story text NOT NULL,
	tid int unsigned NOT NULL,
	note varchar(30) DEFAULT '' NULL,
	primaryskid SMALLINT UNSIGNED,
	comment varchar(1023) NULL DEFAULT '',
	uid mediumint UNSIGNED NOT NULL,
	ipid char(32) DEFAULT '' NOT NULL,
	subnetid char(32) DEFAULT '' NOT NULL,
	del tinyint DEFAULT '0' NOT NULL,
	weight float DEFAULT '0' NOT NULL, 
	signature varchar(32) NOT NULL,
	mediatype enum("text", "none", "video", "image", "audio") default "none" NOT NULL,
	PRIMARY KEY (subid),
	UNIQUE signature (signature),
	KEY emaildomain (emaildomain),
	KEY del (del),
	KEY uid (uid),
	KEY ipid (ipid),
	KEY subnetid (subnetid),
	KEY primaryskid_tid (primaryskid, tid),
	KEY tid (tid),
	KEY time_emaildomain (time, emaildomain)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;


#
# Table structure for table 'submission_param'
#

DROP TABLE IF EXISTS submission_param;
CREATE TABLE submission_param (
	param_id mediumint UNSIGNED NOT NULL auto_increment,
	subid mediumint UNSIGNED NOT NULL,
	name varchar(32) DEFAULT '' NOT NULL,
	value text NOT NULL,
	UNIQUE submission_key (subid,name),
	PRIMARY KEY (param_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'templates'
#
DROP TABLE IF EXISTS templates;
CREATE TABLE templates (
	tpid mediumint UNSIGNED NOT NULL auto_increment,
	name varchar(30) NOT NULL,
	page varchar(20) DEFAULT 'misc' NOT NULL,
	skin varchar(30) DEFAULT 'default' NOT NULL,
	lang char(5) DEFAULT 'en_US' NOT NULL,
	template text,
	seclev mediumint UNSIGNED NOT NULL,
	description text,
	title VARCHAR(128),
	last_update timestamp NOT NULL,
	PRIMARY KEY (tpid),
	UNIQUE true_template (name,page,skin,lang)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'topics'
#

DROP TABLE IF EXISTS topics;
CREATE TABLE topics (
	tid INT UNSIGNED NOT NULL AUTO_INCREMENT,
	keyword VARCHAR(20) NOT NULL,
	textname VARCHAR(80) NOT NULL,
	series ENUM('no', 'yes') DEFAULT 'no' NOT NULL,
	image VARCHAR(100) NOT NULL,
	width SMALLINT UNSIGNED NOT NULL DEFAULT 0,
	height SMALLINT UNSIGNED NOT NULL DEFAULT 0,
	submittable ENUM('no', 'yes') DEFAULT 'yes' NOT NULL,
	searchable ENUM('no', 'yes') DEFAULT 'yes' NOT NULL,
	storypickable ENUM('no', 'yes') DEFAULT 'yes' NOT NULL,
	usesprite ENUM("no","yes") DEFAULT "no" NOT NULL,
	PRIMARY KEY (tid),
	UNIQUE (keyword)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'topic_nexus'
#

DROP TABLE IF EXISTS topic_nexus;
CREATE TABLE topic_nexus (
	tid INT UNSIGNED NOT NULL,
	current_qid MEDIUMINT UNSIGNED DEFAULT NULL,
	PRIMARY KEY (tid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'topic_nexus_dirty'
#

DROP TABLE IF EXISTS topic_nexus_dirty;
CREATE TABLE topic_nexus_dirty (
	tid INT UNSIGNED NOT NULL,
	PRIMARY KEY (tid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'topic_nexus_extras'
#

DROP TABLE IF EXISTS topic_nexus_extras;
CREATE TABLE topic_nexus_extras (
	extras_id MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	tid INT UNSIGNED NOT NULL,
	extras_keyword VARCHAR(100) NOT NULL,
	extras_textname VARCHAR(100) NOT NULL,
	type ENUM('text', 'list') NOT NULL DEFAULT 'text',
	content_type ENUM('story', 'comment') NOT NULL DEFAULT 'story',
	required ENUM('no', 'yes') NOT NULL DEFAULT 'no',
	ordering TINYINT UNSIGNED NOT NULL DEFAULT 0,
	PRIMARY KEY (extras_id),
	UNIQUE tid_keyword (tid, extras_keyword)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'topic_param'
#

DROP TABLE IF EXISTS topic_param;
CREATE TABLE topic_param (
	param_id mediumint UNSIGNED NOT NULL auto_increment,
	tid INT UNSIGNED NOT NULL,
	name varchar(32) DEFAULT '' NOT NULL,
	value text NOT NULL,
	UNIQUE topic_key (tid,name),
	PRIMARY KEY (param_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'topic_parents'
#

DROP TABLE IF EXISTS topic_parents;
CREATE TABLE topic_parents (
	tid INT UNSIGNED NOT NULL,
	parent_tid INT UNSIGNED NOT NULL,
	min_weight FLOAT DEFAULT 10 NOT NULL,
	UNIQUE child_and_parent (tid, parent_tid),
	INDEX parent_tid (parent_tid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'tzcodes'
#

DROP TABLE IF EXISTS tzcodes;
CREATE TABLE tzcodes (
	tz            CHAR(4)	    NOT NULL,
	off_set       MEDIUMINT     NOT NULL, /* "offset" is a keyword in Postgres */
	description   VARCHAR(64),
	dst_region    VARCHAR(32),
	dst_tz        CHAR(4),
	dst_off_set   MEDIUMINT,
	PRIMARY KEY (tz)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'urls'
#

DROP TABLE IF EXISTS urls;
CREATE TABLE urls (
	url_id INT(10) UNSIGNED NOT NULL auto_increment,
	url_digest VARCHAR(32) NOT NULL,
	url TEXT NOT NULL,
	is_success TINYINT(4),
	createtime datetime,
	last_attempt datetime,
	last_success datetime,
	believed_fresh_until datetime,
	status_code SMALLINT(6),
	reason_phrase VARCHAR(30),
	content_type VARCHAR(60),
	initialtitle VARCHAR(255),
	validatedtitle VARCHAR(255),
	tags_top VARCHAR(255) DEFAULT '' NOT NULL,
	popularity float DEFAULT '0' NOT NULL,
	anon_bookmarks MEDIUMINT UNSIGNED DEFAULT 0 NOT NULL,
	PRIMARY KEY (url_id),
	UNIQUE url_digest (url_digest),
	INDEX bfu (believed_fresh_until)
);

#
# Table structure for table 'users'
#

DROP TABLE IF EXISTS users;
CREATE TABLE users (
	uid mediumint UNSIGNED NOT NULL auto_increment,
	nickname varchar(35) DEFAULT '' NOT NULL,
	realemail varchar(50) DEFAULT '' NOT NULL,
	fakeemail varchar(75),
	homepage varchar(100),
	passwd char(32) DEFAULT '' NOT NULL,
	sig varchar(200),
	seclev mediumint UNSIGNED DEFAULT '0' NOT NULL,	/* This is set to 0 as a safety factor */
	matchname varchar(35),
	newpasswd char(32),
	newpasswd_ts datetime,
	journal_last_entry_date datetime,
	author tinyint DEFAULT 0 NOT NULL,
	shill_id TINYINT UNSIGNED DEFAULT 0 NOT NULL,
	willing_to_vote TINYINT UNSIGNED DEFAULT 0 NOT NULL,
	PRIMARY KEY (uid),
	KEY login (nickname,uid,passwd),
	KEY chk4user (realemail,nickname),
	KEY chk4matchname (matchname),
	KEY author_lookup (author),
	KEY seclev (seclev)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'users_acl'
# (The redundant key on uid is there for when FOREIGN KEY starts
# working with InnoDB...)
#

DROP TABLE IF EXISTS users_acl;
CREATE TABLE users_acl (
	id mediumint UNSIGNED NOT NULL auto_increment,
	uid mediumint UNSIGNED NOT NULL,
	acl varchar(32) NOT NULL,
	UNIQUE uid_key (uid,acl),
	KEY uid (uid),
	KEY acl (acl),
	PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'users_clout'
#
drop table if exists users_clout;
CREATE TABLE users_clout (
	clout_id	int UNSIGNED NOT NULL AUTO_INCREMENT,
	uid		mediumint UNSIGNED NOT NULL,
	clid		smallint UNSIGNED NOT NULL,
	clout		float UNSIGNED DEFAULT NULL,
	PRIMARY KEY (clout_id),
	UNIQUE uid_clid (uid, clid),
	INDEX clid (clid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'users_comments'
#

DROP TABLE IF EXISTS users_comments;
CREATE TABLE users_comments (
	uid mediumint UNSIGNED NOT NULL,
	posttype mediumint DEFAULT '2' NOT NULL,
	defaultpoints tinyint DEFAULT '1' NOT NULL,
	highlightthresh tinyint DEFAULT '4' NOT NULL,
	maxcommentsize smallint UNSIGNED DEFAULT '4096' NOT NULL,
	hardthresh tinyint DEFAULT '0' NOT NULL,
	clbig smallint UNSIGNED DEFAULT '0' NOT NULL,
	clsmall smallint UNSIGNED DEFAULT '0' NOT NULL,
	reparent tinyint DEFAULT '1' NOT NULL,
	nosigs tinyint DEFAULT '0' NOT NULL,
	commentlimit smallint UNSIGNED DEFAULT '100' NOT NULL,
	commentspill smallint UNSIGNED DEFAULT '50' NOT NULL,
	commentsort tinyint DEFAULT '0' NOT NULL,
	noscores tinyint DEFAULT '0' NOT NULL,
	mode ENUM('flat', 'nested', 'nocomment', 'thread','improvedthreaded') DEFAULT 'improvedthreaded' NOT NULL,
	threshold tinyint DEFAULT '0' NOT NULL,
	PRIMARY KEY (uid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'users_comments_read_log'
#

DROP TABLE IF EXISTS users_comments_read_log;
CREATE TABLE users_comments_read_log (
	uid MEDIUMINT UNSIGNED NOT NULL,
	discussion_id MEDIUMINT UNSIGNED NOT NULL,
	cid INT UNSIGNED NOT NULL,
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;


#
# Table structure for table 'users_hits'
#

DROP TABLE IF EXISTS users_hits;
CREATE TABLE users_hits (
	uid mediumint UNSIGNED NOT NULL,
	lastclick timestamp,
	hits int DEFAULT '0' NOT NULL,
	PRIMARY KEY (uid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'users_index'
#

DROP TABLE IF EXISTS users_index;
CREATE TABLE users_index (
	uid mediumint UNSIGNED NOT NULL,
	story_never_topic text NOT NULL,
	story_never_author varchar(255) DEFAULT '' NOT NULL,
	story_never_nexus varchar(255) DEFAULT '' NOT NULL,
	story_always_topic text NOT NULL,
	story_always_author varchar(255) DEFAULT '' NOT NULL,
	story_always_nexus varchar(255) DEFAULT '' NOT NULL,
	story_full_brief_nexus varchar(255) DEFAULT '' NOT NULL,
	story_brief_always_nexus varchar(255) DEFAULT '' NOT NULL,
	story_full_best_nexus varchar(255) DEFAULT '' NOT NULL,
	story_brief_best_nexus varchar(255) DEFAULT '' NOT NULL,
	slashboxes text NOT NULL,
	maxstories tinyint UNSIGNED DEFAULT '30' NOT NULL,
	noboxes tinyint DEFAULT '0' NOT NULL,
	PRIMARY KEY (uid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'users_info'
#

DROP TABLE IF EXISTS users_info;
CREATE TABLE users_info (
	uid mediumint UNSIGNED NOT NULL,
	totalmods mediumint DEFAULT '0' NOT NULL,
	realname varchar(50),
	bio text NOT NULL,
	points smallint(5) NOT NULL DEFAULT 0,
	tokens mediumint DEFAULT '0' NOT NULL,
	lastgranted datetime DEFAULT '1970-01-01 00:00' NOT NULL,
	karma mediumint DEFAULT '0' NOT NULL,
	maillist tinyint DEFAULT '0' NOT NULL,
	totalcomments mediumint UNSIGNED DEFAULT '0',
	lastaccess date DEFAULT '1970-01-01' NOT NULL,
	upmods mediumint UNSIGNED DEFAULT '0' NOT NULL,
	downmods mediumint UNSIGNED DEFAULT '0' NOT NULL,
	stirred mediumint UNSIGNED DEFAULT '0' NOT NULL,
	session_login tinyint DEFAULT '0' NOT NULL,
	cookie_location enum("classbid","subnetid","ipid","none") DEFAULT "classbid" NOT NULL,
	registered tinyint UNSIGNED DEFAULT '1' NOT NULL,
	reg_id char(32) DEFAULT '' NOT NULL,
	expiry_days smallint UNSIGNED DEFAULT '1' NOT NULL,
	expiry_comm smallint UNSIGNED DEFAULT '1' NOT NULL,
	user_expiry_days smallint UNSIGNED DEFAULT '1' NOT NULL,
	user_expiry_comm smallint UNSIGNED DEFAULT '1' NOT NULL,
	initdomain VARCHAR(30) DEFAULT '' NOT NULL,
	created_ipid VARCHAR(32) DEFAULT '' NOT NULL,
	created_at datetime DEFAULT '1970-01-01 00:00' NOT NULL,
	people MEDIUMBLOB,
	lastaccess_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        skin varchar(255) DEFAULT NULL,
        mod_banned date DEFAULT '1000-01-01',
	PRIMARY KEY (uid),
	KEY (initdomain),
	KEY (created_ipid),
	KEY tokens (tokens)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'users_logtokens'
#

DROP TABLE IF EXISTS users_logtokens;
CREATE TABLE users_logtokens (
	lid MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	uid MEDIUMINT UNSIGNED NOT NULL DEFAULT '0',
	locationid CHAR(32) NOT NULL DEFAULT '',
	temp ENUM("yes","no") NOT NULL DEFAULT "no",
	public ENUM("yes","no") NOT NULL DEFAULT "no",
	expires DATETIME NOT NULL DEFAULT '2000-01-01 00:00:00',
	value CHAR(22) NOT NULL DEFAULT '',
	PRIMARY KEY (lid),
	UNIQUE uid_locationid_temp_public (uid, locationid, temp, public),
	KEY (locationid),
	KEY (temp),
	KEY (public)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'users_openid'
#

DROP TABLE IF EXISTS users_openid;
CREATE TABLE users_openid (
	openid_id int UNSIGNED NOT NULL auto_increment,
	openid_url VARCHAR(255) NOT NULL,
	uid mediumint UNSIGNED NOT NULL,
	PRIMARY KEY (openid_id),
	UNIQUE (openid_url),
	INDEX (uid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'users_openid_reskeys'
#

DROP TABLE IF EXISTS users_openid_reskeys;
CREATE TABLE users_openid_reskeys (
	oprid int UNSIGNED NOT NULL auto_increment,
	openid_url VARCHAR(255) NOT NULL,
	reskey CHAR(20) DEFAULT '' NOT NULL,
	PRIMARY KEY (oprid),
	INDEX (openid_url),
	INDEX (reskey)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'users_param'
#

DROP TABLE IF EXISTS users_param;
CREATE TABLE users_param (
	param_id int UNSIGNED NOT NULL auto_increment,
	uid mediumint UNSIGNED NOT NULL,
	name varchar(32) DEFAULT '' NOT NULL,
	value text NOT NULL,
	PRIMARY KEY (param_id),
	UNIQUE uid_key (uid,name),
	KEY name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'users_prefs'
#

DROP TABLE IF EXISTS users_prefs;
CREATE TABLE users_prefs (
	uid mediumint UNSIGNED NOT NULL,
	willing tinyint DEFAULT '1' NOT NULL,
	dfid tinyint UNSIGNED DEFAULT '0' NOT NULL,
	tzcode char(4) DEFAULT 'EST' NOT NULL,
	noicons tinyint DEFAULT '0' NOT NULL,
	light tinyint DEFAULT '0' NOT NULL,
	mylinks varchar(255) DEFAULT '' NOT NULL,
	lang char(5) DEFAULT 'en_US' NOT NULL,
	PRIMARY KEY (uid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

#
# Table structure for table 'vars'
#

DROP TABLE IF EXISTS vars;
CREATE TABLE vars (
	name varchar(48) DEFAULT '' NOT NULL,
	value text,
	description varchar(255),
	PRIMARY KEY (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

DROP TABLE IF EXISTS xsite_auth_log;
CREATE TABLE xsite_auth_log (
	site VARCHAR(30) DEFAULT '' NOT NULL,
	ts DATETIME DEFAULT '0000-00-00 00:00' NOT NULL,
	nonce VARCHAR(30) DEFAULT '' NOT NULL,
	UNIQUE KEY (site,ts,nonce)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;


#ALTER TABLE backup_blocks ADD FOREIGN KEY (bid) REFERENCES blocks(bid);
#ALTER TABLE comment_text ADD FOREIGN KEY (cid) REFERENCES comments(cid);
#ALTER TABLE discussions ADD FOREIGN KEY (topic) REFERENCES topics(tid);
# This doesn't work, since discussion may be 0.
#ALTER TABLE pollquestions ADD FOREIGN KEY (discussion) REFERENCES discussions(id);
# This doesn't work, since in the install pollquestions is populated before users, alphabetically
#ALTER TABLE pollquestions ADD FOREIGN KEY (uid) REFERENCES users(uid);
# This doesn't work, makes createStory die
#ALTER TABLE stories ADD FOREIGN KEY (uid) REFERENCES users(uid);
# These don't work, should check why...
#ALTER TABLE stories ADD FOREIGN KEY (tid) REFERENCES topics(tid);
#ALTER TABLE stories ADD FOREIGN KEY (qid) REFERENCES pollquestions(qid);
#ALTER TABLE story_text ADD FOREIGN KEY (stoid) REFERENCES stories(stoid);
#ALTER TABLE story_topics_chosen ADD FOREIGN KEY (tid) REFERENCES topics(tid);
#ALTER TABLE story_topics_rendered ADD FOREIGN KEY (tid) REFERENCES topics(tid);
#ALTER TABLE submissions ADD FOREIGN KEY (uid) REFERENCES users(uid);

# Commented-out foreign keys are ones which currently cannot be used
# because they refer to a primary key which is NOT NULL AUTO_INCREMENT
# and the child's key either has a default value which would be invalid
# for an auto_increment field, typically NOT NULL DEFAULT '0'.  Or,
# in some cases, the primary key is e.g. VARCHAR(20) NOT NULL and the
# child's key will be VARCHAR(20).  The possibility of NULLs negates
# the ability to add a foreign key.  <-- That's my current theory,
# but it doesn't explain why discussions.topic SMALLINT UNSIGNED NOT NULL
# DEFAULT '0' is able to be foreign-keyed to topics.tid SMALLINT UNSIGNED
# NOT NULL AUTO_INCREMENT.
# (And note that MySQL 4.0 allows an AUTO_INCREMENT column to be declared
# with a DEFAULT, but MySQL 4.1 throws an error on that formulation.)

#ALTER TABLE blocks ADD FOREIGN KEY (rss_template) REFERENCES templates(name);
#ALTER TABLE discussions ADD FOREIGN KEY (sid) REFERENCES stories(sid);
#ALTER TABLE discussions ADD FOREIGN KEY (stoid) REFERENCES stories(stoid);
#ALTER TABLE discussions ADD FOREIGN KEY (uid) REFERENCES users(uid);
#ALTER TABLE formkeys ADD FOREIGN KEY (uid) REFERENCES users(uid);
#ALTER TABLE pollanswers ADD FOREIGN KEY (qid) REFERENCES pollquestions(qid);
#ALTER TABLE pollvoters ADD FOREIGN KEY (uid) REFERENCES users(uid);
#ALTER TABLE pollvoters ADD FOREIGN KEY (qid) REFERENCES pollquestions(qid);
#ALTER TABLE rss_raw ADD FOREIGN KEY (subid) REFERENCES submissions(subid);
#ALTER TABLE rss_raw ADD FOREIGN KEY (bid) REFERENCES blocks(bid);
#ALTER TABLE sessions ADD FOREIGN KEY (uid) REFERENCES users(uid);
#ALTER TABLE sessions ADD FOREIGN KEY (last_subid) REFERENCES submissions(subid);
#ALTER TABLE story_topics ADD FOREIGN KEY (sid) REFERENCES stories(sid);
#ALTER TABLE submissions ADD FOREIGN KEY (tid) REFERENCES topics(tid);
#ALTER TABLE users_acl ADD FOREIGN KEY (uid) REFERENCES users(uid);
#ALTER TABLE users_comments ADD FOREIGN KEY (uid) REFERENCES users(uid);
#ALTER TABLE users_index ADD FOREIGN KEY (uid) REFERENCES users(uid);
#ALTER TABLE users_info ADD FOREIGN KEY (uid) REFERENCES users(uid);
#ALTER TABLE users_param ADD FOREIGN KEY (uid) REFERENCES users(uid);
#ALTER TABLE users_prefs ADD FOREIGN KEY (uid) REFERENCES users(uid);


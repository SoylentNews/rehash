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
	ts datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
	reason varchar(120) DEFAULT '' NOT NULL,
	querystring varchar(200) DEFAULT '' NOT NULL,
	PRIMARY KEY (abuser_id),
	KEY uid (uid),
	KEY ipid (ipid),
	KEY subnetid (subnetid),
	KEY reason (reason),
	KEY ts (ts)
) TYPE=InnoDB;

DROP TABLE IF EXISTS accesslist; 
CREATE TABLE accesslist (
	id mediumint(9) NOT NULL auto_increment,
	adminuid mediumint(8) unsigned NOT NULL default '0',
	uid mediumint(8) unsigned NOT NULL default '0',
	ipid varchar(32) default NULL,
	subnetid varchar(32) default NULL,
	ts datetime NOT NULL default '0000-00-00 00:00:00',
	reason varchar(255) NOT NULL default '',
	now_ban enum('no','yes') NOT NULL default 'no',
	now_nopost enum('no','yes') NOT NULL default 'no',
	now_nosubmit enum('no','yes') NOT NULL default 'no',
	now_norss enum('no','yes') NOT NULL default 'no',
	now_nopalm enum('no','yes') NOT NULL default 'no',
	now_proxy enum('no','yes') NOT NULL default 'no',
	now_trusted enum('no','yes') NOT NULL default 'no',
	was_ban enum('no','yes') NOT NULL default 'no',
	was_nopost enum('no','yes') NOT NULL default 'no',
	was_nosubmit enum('no','yes') NOT NULL default 'no',
	was_norss enum('no','yes') NOT NULL default 'no',
	was_nopalm enum('no','yes') NOT NULL default 'no',
	was_proxy enum('no','yes') NOT NULL default 'no',
	was_trusted enum('no','yes') NOT NULL default 'no',
	estimated_users smallint UNSIGNED default 1,
	PRIMARY KEY  (id),
	KEY uid (uid),
	KEY ipid (ipid),
	KEY subnetid (subnetid),
	KEY ts (ts),
	KEY now_ban (now_ban),
	KEY now_nopost (now_nopost),
	KEY now_nosubmit (now_nosubmit),
	KEY now_norss (now_norss),
	KEY now_proxy (now_proxy),
	KEY now_trusted (now_trusted)
) TYPE=InnoDB;

DROP TABLE IF EXISTS accesslog; 
CREATE TABLE accesslog (
	id int UNSIGNED NOT NULL auto_increment,
	host_addr char(32)	DEFAULT '' NOT NULL,
	subnetid char(32)	DEFAULT '' NOT NULL,
	op varchar(254),
	dat varchar(254),
	uid mediumint UNSIGNED NOT NULL,
	ts datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
	query_string varchar(50),
	user_agent varchar(50),
	skid SMALLINT UNSIGNED DEFAULT 0 NOT NULL,
	bytes mediumint UNSIGNED DEFAULT 0 NOT NULL,
	duration FLOAT DEFAULT 0.0 NOT NULL,
	local_addr VARCHAR(16) DEFAULT '' NOT NULL,
	static enum("yes","no") DEFAULT "yes",
	secure tinyint DEFAULT 0 NOT NULL,
	referer varchar(254),
	status smallint UNSIGNED DEFAULT 200 NOT NULL,
	INDEX host_addr_part (host_addr(16)),
	INDEX op_part (op(12), skid),
	INDEX ts (ts),
	PRIMARY KEY (id)
) TYPE=InnoDB;

DROP TABLE IF EXISTS accesslog_admin;
CREATE TABLE accesslog_admin (
	id int UNSIGNED NOT NULL auto_increment,
	host_addr char(15)  DEFAULT '' NOT NULL,
	op varchar(254),
	dat varchar(254),
	uid mediumint UNSIGNED NOT NULL,
	ts datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
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
) TYPE=InnoDB;

DROP TABLE IF EXISTS accesslog_artcom;
CREATE TABLE accesslog_artcom (
	uid mediumint UNSIGNED NOT NULL,
	ts datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
	c smallint unsigned NOT NULL DEFAULT '0',
	INDEX uid (uid),
	INDEX ts (ts)
) TYPE=InnoDB;

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
) TYPE=InnoDB;

#
# Table structure for table 'backup_blocks'
#

DROP TABLE IF EXISTS backup_blocks;
CREATE TABLE backup_blocks (
	bid varchar(30) DEFAULT '' NOT NULL,
	block text,
	PRIMARY KEY (bid)
) TYPE=InnoDB;

#
# Table structure for table 'badpasswords'
#

DROP TABLE IF EXISTS badpasswords;
CREATE TABLE badpasswords (
	uid mediumint(8) NOT NULL DEFAULT 0,
	ip varchar(15) NOT NULL DEFAULT '',
	subnet varchar(15) NOT NULL DEFAULT '',
	password varchar(20) NOT NULL DEFAULT '',
	ts timestamp(14) NOT NULL,
	realemail VARCHAR(50) NOT NULL DEFAULT '',
	INDEX uid (uid),
	INDEX ip (ip),
	INDEX subnet (subnet)
) TYPE=InnoDB;

#
# Table structure for table 'blocks'
#

DROP TABLE IF EXISTS blocks;
CREATE TABLE blocks (
	bid varchar(30) DEFAULT '' NOT NULL,
	block text,
	seclev mediumint UNSIGNED NOT NULL DEFAULT '0',
	type ENUM('static','portald') DEFAULT 'static' NOT NULL,
	description text,
	skin varchar(30) NOT NULL,
	ordernum tinyint DEFAULT '0',
	title varchar(128) NOT NULL,
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
	PRIMARY KEY (bid),
	KEY type (type),
	KEY skin (skin)
) TYPE=InnoDB;

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
) TYPE=InnoDB;

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
) TYPE=InnoDB;

#
# Table structure for table 'commentmodes'
#

DROP TABLE IF EXISTS commentmodes;
CREATE TABLE commentmodes (
	mode varchar(16) DEFAULT '' NOT NULL,
	name varchar(32),
	description varchar(64),
	PRIMARY KEY (mode)
) TYPE=InnoDB;

#
# Table structure for table 'comments'
#

DROP TABLE IF EXISTS comments;
CREATE TABLE comments (
	sid mediumint UNSIGNED NOT NULL,
	cid mediumint UNSIGNED NOT NULL auto_increment,
	pid mediumint UNSIGNED DEFAULT '0' NOT NULL,
	date datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
	ipid char(32) DEFAULT '' NOT NULL,
	subnetid char(32) DEFAULT '' NOT NULL,
	subject varchar(50) NOT NULL,
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
	PRIMARY KEY (cid),
	KEY display (sid,points,uid),
	KEY byname (uid,points),
	KEY ipid (ipid),
	KEY subnetid (subnetid),
	KEY theusual (sid,uid,points,cid),
	KEY countreplies (pid,sid),
	KEY uid_date (uid,date),
	KEY date_sid (date,sid)
) TYPE=MyISAM;

#
# Table structure for table 'comment_text'
#

DROP TABLE IF EXISTS comment_text;
CREATE TABLE comment_text (
	cid mediumint UNSIGNED NOT NULL,
	comment text NOT NULL,
	PRIMARY KEY (cid)
) TYPE=MyISAM;

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
) TYPE=InnoDB;

#
# Table structure for table 'dateformats'
#

DROP TABLE IF EXISTS dateformats;
CREATE TABLE dateformats (
	id tinyint UNSIGNED DEFAULT '0' NOT NULL,
	format varchar(32),
	description varchar(64),
	PRIMARY KEY (id)
) TYPE=InnoDB;

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
	PRIMARY KEY (id)
) TYPE=InnoDB;

#
# Table structure for table 'discussions'
#

DROP TABLE IF EXISTS discussions;
CREATE TABLE discussions (
	id mediumint UNSIGNED NOT NULL auto_increment, 
	stoid mediumint UNSIGNED DEFAULT '0' NOT NULL,
	sid char(16) DEFAULT '' NOT NULL,
	title varchar(128) NOT NULL,
	url varchar(255) NOT NULL,
	topic smallint UNSIGNED NOT NULL,
	ts datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
	type ENUM("open","recycle","archived") DEFAULT 'open' NOT NULL,
	uid mediumint UNSIGNED NOT NULL,
	commentcount smallint UNSIGNED DEFAULT '0' NOT NULL,
	flags ENUM("ok","delete","dirty") DEFAULT 'ok' NOT NULL,
	primaryskid SMALLINT UNSIGNED,
	last_update timestamp NOT NULL,
	approved tinyint UNSIGNED DEFAULT 0 NOT NULL,
	commentstatus ENUM('disabled','enabled','friends_only','friends_fof_only','no_foe','no_foe_eof') DEFAULT 'enabled' NOT NULL, /* Default is that we allow anyone to write */
	KEY (stoid),
	KEY (sid),
	KEY (topic),
	KEY (primaryskid,ts),
	INDEX (type,uid,ts),
	PRIMARY KEY (id)
) TYPE=InnoDB;

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
) TYPE=InnoDB;

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
) TYPE=InnoDB;

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
) TYPE=InnoDB;

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
) TYPE=InnoDB;

#
# Table structure for table 'metamodlog'
#

DROP TABLE IF EXISTS metamodlog;
CREATE TABLE metamodlog (
	id int UNSIGNED NOT NULL AUTO_INCREMENT,
	mmid int UNSIGNED DEFAULT '0' NOT NULL,
	uid mediumint UNSIGNED DEFAULT '0' NOT NULL,
	val tinyint  DEFAULT '0' NOT NULL,
	ts datetime,
	active tinyint DEFAULT '1' NOT NULL,
	INDEX byuser (uid),
	INDEX mmid (mmid),
	PRIMARY KEY (id)
) TYPE=InnoDB;

#
# Table structure for table 'misc_user_opts'
#

DROP TABLE IF EXISTS misc_user_opts;
CREATE TABLE misc_user_opts (
	name varchar(32) NOT NULL,
	optorder mediumint(5),
	seclev mediumint UNSIGNED NOT NULL,
	default_val text DEFAULT '' NOT NULL,
	vals_regex text DEFAULT '',
	short_desc text DEFAULT '',
	long_desc text DEFAULT '',
	opts_html text DEFAULT '',
	PRIMARY KEY (name)
) TYPE=InnoDB;

#
# Table structure for table 'moderatorlog'
#

DROP TABLE IF EXISTS moderatorlog;
CREATE TABLE moderatorlog (
	id int UNSIGNED NOT NULL auto_increment,
	ipid char(32) DEFAULT '' NOT NULL,
	subnetid char(32) DEFAULT '' NOT NULL,
	uid mediumint UNSIGNED NOT NULL,
	val tinyint DEFAULT '0' NOT NULL,
	sid mediumint UNSIGNED DEFAULT '' NOT NULL,
	ts datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
	cid mediumint UNSIGNED NOT NULL,
	cuid mediumint UNSIGNED NOT NULL,
	reason tinyint UNSIGNED DEFAULT '0',
	active tinyint DEFAULT '1' NOT NULL,
	spent tinyint DEFAULT '1' NOT NULL,
	m2count mediumint UNSIGNED DEFAULT '0' NOT NULL,
	m2needed mediumint UNSIGNED DEFAULT '0' NOT NULL,
	m2status tinyint DEFAULT '0' NOT NULL,
	points_orig tinyint DEFAULT NULL,
	PRIMARY KEY (id),
	KEY sid (sid,cid),
	KEY sid_2 (sid,uid,cid),
	KEY cid (cid),
	KEY ipid (ipid),
	KEY subnetid (subnetid),
	KEY uid (uid),
	KEY cuid (cuid),
	KEY m2stat_act (m2status,active),
	KEY ts_uid_sid (ts,uid,sid)
) TYPE=InnoDB;

#
# Table structure for table 'modreasons'
#

DROP TABLE IF EXISTS modreasons;
CREATE TABLE modreasons (
	id tinyint UNSIGNED NOT NULL,
	name char(32) DEFAULT '' NOT NULL,
	m2able tinyint DEFAULT '1' NOT NULL,
	listable tinyint DEFAULT '1' NOT NULL,
	val tinyint DEFAULT '0' NOT NULL,
	karma tinyint DEFAULT '0' NOT NULL,
	fairfrac float DEFAULT '0.5' NOT NULL,
	unfairname varchar(32) DEFAULT '' NOT NULL,
	PRIMARY KEY (id)
) TYPE=InnoDB;

#
# Table structure for table 'open_proxies'
#

DROP TABLE IF EXISTS open_proxies;
CREATE TABLE open_proxies (
        ip	VARCHAR(15) NOT NULL,
	port	SMALLINT UNSIGNED NOT NULL DEFAULT '0',
	ts	DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
	xff	VARCHAR(15) DEFAULT NULL,
	ipid char(32) DEFAULT '' NOT NULL,
	PRIMARY KEY (ip),
	KEY ts (ts),
	KEY ipid (ipid)
) TYPE=InnoDB;

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
) TYPE=InnoDB;

#
# Table structure for table 'pollquestions'
#

DROP TABLE IF EXISTS pollquestions;
CREATE TABLE pollquestions (
	qid mediumint UNSIGNED NOT NULL auto_increment,
	question char(255) NOT NULL,
	voters mediumint,
	topic smallint UNSIGNED NOT NULL,
	discussion mediumint,
	date datetime,
	uid mediumint UNSIGNED NOT NULL,
	primaryskid SMALLINT UNSIGNED,
	autopoll ENUM("no","yes") DEFAULT 'no' NOT NULL,
	flags ENUM("ok","delete","dirty") DEFAULT 'ok' NOT NULL,
	polltype enum('nodisplay','section','story') default 'section',
	PRIMARY KEY (qid)
) TYPE=MyISAM;

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
) TYPE=InnoDB;

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
) TYPE=InnoDB;

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
) TYPE=InnoDB;

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
) TYPE=InnoDB;

#
# Table structure for table 'sessions'
#

DROP TABLE IF EXISTS sessions;
CREATE TABLE sessions (
	session mediumint UNSIGNED NOT NULL auto_increment,
	uid mediumint UNSIGNED,
	logintime datetime,
	lasttime datetime,
	lasttitle varchar(50),
	last_subid mediumint UNSIGNED,
	last_sid varchar(16),
	INDEX (uid),
	PRIMARY KEY (session)
) TYPE=InnoDB;

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
) TYPE=InnoDB;

#
# Table structure for table 'skins'
#

DROP TABLE IF EXISTS skins;
CREATE TABLE skins (
	skid SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
	nexus SMALLINT UNSIGNED NOT NULL,
	artcount_min MEDIUMINT UNSIGNED DEFAULT '10' NOT NULL,
	artcount_max MEDIUMINT UNSIGNED DEFAULT '30' NOT NULL,
	name VARCHAR(30) NOT NULL,
	title VARCHAR(64) DEFAULT '' NOT NULL,
	issue ENUM('no', 'yes') DEFAULT 'no' NOT NULL,
	submittable ENUM('no', 'yes') DEFAULT 'yes' NOT NULL,
	url VARCHAR(255) DEFAULT '' NOT NULL,
	hostname VARCHAR(128) DEFAULT '' NOT NULL,
	cookiedomain VARCHAR(128) DEFAULT '' NOT NULL,
	index_handler VARCHAR(30) DEFAULT 'index.pl' NOT NULL,
	max_rewrite_secs MEDIUMINT UNSIGNED DEFAULT '3600' NOT NULL,
	last_rewrite TIMESTAMP NOT NULL,
	ac_uid mediumint UNSIGNED DEFAULT '0' NOT NULL,
	PRIMARY KEY (skid),
	UNIQUE name (name)
) TYPE=InnoDB;

#
# Table structure for table 'skin_colors'
#

DROP TABLE IF EXISTS skin_colors;
CREATE TABLE skin_colors (
	skid SMALLINT UNSIGNED NOT NULL,
	name VARCHAR(24) NOT NULL,
	hexcolor CHAR(6) NOT NULL,
	UNIQUE skid_name (skid, name)
) TYPE=InnoDB;

#
# Table structure for table 'slashd_status'
#

DROP TABLE IF EXISTS slashd_status;
CREATE TABLE slashd_status (
	task VARCHAR(50) NOT NULL,
	next_begin DATETIME,
	in_progress TINYINT NOT NULL DEFAULT '0',
	last_completed DATETIME,
	summary VARCHAR(255) NOT NULL DEFAULT '',
	duration float(6,2) DEFAULT '0.00' NOT NULL,
	PRIMARY KEY (task)
) TYPE=InnoDB;

#
# Table structure for table 'slashd_errnotes'
#

DROP TABLE IF EXISTS slashd_errnotes;
CREATE TABLE slashd_errnotes (
	ts DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
	taskname VARCHAR(50) NOT NULL DEFAULT 'SLASHD',
	line MEDIUMINT UNSIGNED NOT NULL DEFAULT '0',
	errnote VARCHAR(255) NOT NULL DEFAULT '',
	moreinfo TEXT DEFAULT NULL,
	INDEX (ts),
	INDEX taskname_ts (taskname, ts)
) TYPE=InnoDB;

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
) TYPE=InnoDB;


#
# Table structure for table 'stories'
#

DROP TABLE IF EXISTS stories;
CREATE TABLE stories (
	stoid MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	sid CHAR(16) NOT NULL,
	uid MEDIUMINT UNSIGNED NOT NULL,
	dept VARCHAR(100),
	time DATETIME DEFAULT '0000-00-00 00:00:00' NOT NULL,
	hits MEDIUMINT UNSIGNED DEFAULT '0' NOT NULL,
	discussion MEDIUMINT UNSIGNED,
	primaryskid SMALLINT UNSIGNED,
	tid SMALLINT UNSIGNED,
	submitter MEDIUMINT UNSIGNED NOT NULL,
	commentcount SMALLINT UNSIGNED DEFAULT '0' NOT NULL,
	hitparade VARCHAR(64) DEFAULT '0,0,0,0,0,0,0' NOT NULL,
	is_archived ENUM('no', 'yes') DEFAULT 'no' NOT NULL,
	in_trash ENUM('no', 'yes') DEFAULT 'no' NOT NULL,
	day_published DATE DEFAULT '0000-00-00' NOT NULL,
	qid MEDIUMINT UNSIGNED DEFAULT NULL,
	last_update TIMESTAMP NOT NULL,
	body_length MEDIUMINT UNSIGNED DEFAULT 0 NOT NULL,
	word_count MEDIUMINT UNSIGNED DEFAULT 0 NOT NULL,
	PRIMARY KEY (stoid),
	UNIQUE sid (sid),
	INDEX uid (uid),
	INDEX is_archived (is_archived),
	INDEX time (time),
	INDEX submitter (submitter),
	INDEX day_published (day_published),
	INDEX skidtid (primaryskid, tid),
	INDEX discussion_stoid (discussion, stoid)
) TYPE=InnoDB;

#
# Table structure for table 'story_dirty'
#

DROP TABLE IF EXISTS story_dirty;
CREATE TABLE story_dirty (
	stoid MEDIUMINT UNSIGNED NOT NULL,
	PRIMARY KEY (stoid)
) TYPE=InnoDB;

#
# Table structure for table 'story_render_dirty'
#

DROP TABLE IF EXISTS story_render_dirty;
CREATE TABLE story_render_dirty (
	stoid MEDIUMINT UNSIGNED NOT NULL,
	PRIMARY KEY (stoid)
) TYPE=InnoDB;

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
) TYPE=MyISAM;

#
# Table structure for table 'story_param'
#

DROP TABLE IF EXISTS story_param;
CREATE TABLE story_param (
	param_id mediumint UNSIGNED NOT NULL auto_increment,
	stoid MEDIUMINT UNSIGNED NOT NULL,
	name varchar(32) DEFAULT '' NOT NULL,
	value text DEFAULT '' NOT NULL,
	UNIQUE story_key (stoid,name),
	PRIMARY KEY (param_id)
) TYPE=InnoDB;

#
# Table structure for table 'story_topics_chosen'
#

DROP TABLE IF EXISTS story_topics_chosen;
CREATE TABLE story_topics_chosen (
	stoid MEDIUMINT UNSIGNED NOT NULL,
	tid SMALLINT(5) UNSIGNED NOT NULL,
	weight FLOAT UNSIGNED DEFAULT 1 NOT NULL,
	UNIQUE story_topic (stoid, tid),
	INDEX tid_stoid (tid, stoid)
) TYPE=InnoDB;

#
# Table structure for table 'story_topics_rendered'
#

DROP TABLE IF EXISTS story_topics_rendered;
CREATE TABLE story_topics_rendered (
	stoid MEDIUMINT UNSIGNED NOT NULL,
	tid SMALLINT(5) UNSIGNED NOT NULL,
	UNIQUE story_topic (stoid, tid),
	INDEX tid_stoid (tid, stoid)
) TYPE=InnoDB;

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
) TYPE=InnoDB;

#
# Table structure for table 'submissions'
#

DROP TABLE IF EXISTS submissions;
CREATE TABLE submissions (
	subid mediumint UNSIGNED NOT NULL auto_increment,
	email varchar(255) DEFAULT '' NOT NULL,
	name varchar(50) NOT NULL,
	time datetime NOT NULL,
	subj varchar(50) NOT NULL,
	story text NOT NULL,
	tid smallint NOT NULL,
	note varchar(30) DEFAULT '' NOT NULL,
	primaryskid SMALLINT UNSIGNED,
	comment varchar(255) NOT NULL,
	uid mediumint UNSIGNED NOT NULL,
	ipid char(32) DEFAULT '' NOT NULL,
	subnetid char(32) DEFAULT '' NOT NULL,
	del tinyint DEFAULT '0' NOT NULL,
	weight float DEFAULT '0' NOT NULL, 
	signature varchar(32) NOT NULL,
	PRIMARY KEY (subid),
	UNIQUE signature (signature),
	INDEX del (del),
	INDEX uid (uid),
	KEY ipid (ipid),
	KEY subnetid (subnetid),
	KEY primaryskid_tid (primaryskid, tid),
	KEY tid (tid)
) TYPE=InnoDB;


#
# Table structure for table 'submission_param'
#

DROP TABLE IF EXISTS submission_param;
CREATE TABLE submission_param (
	param_id mediumint UNSIGNED NOT NULL auto_increment,
	subid mediumint UNSIGNED NOT NULL,
	name varchar(32) DEFAULT '' NOT NULL,
	value text DEFAULT '' NOT NULL,
	UNIQUE submission_key (subid,name),
	PRIMARY KEY (param_id)
) TYPE=InnoDB;

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
) TYPE=InnoDB;

#
# Table structure for table 'topics'
#

DROP TABLE IF EXISTS topics;
CREATE TABLE topics (
	tid SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
	keyword VARCHAR(20) NOT NULL,
	textname VARCHAR(80) NOT NULL,
	series ENUM('no', 'yes') DEFAULT 'no' NOT NULL,
	image VARCHAR(100) NOT NULL,
	width SMALLINT UNSIGNED NOT NULL DEFAULT 0,
	height SMALLINT UNSIGNED NOT NULL DEFAULT 0,
	submittable ENUM('no', 'yes') DEFAULT 'yes' NOT NULL,
	PRIMARY KEY (tid)
) TYPE=InnoDB;

#
# Table structure for table 'topic_nexus'
#

DROP TABLE IF EXISTS topic_nexus;
CREATE TABLE topic_nexus (
	tid SMALLINT UNSIGNED NOT NULL,
	current_qid MEDIUMINT UNSIGNED DEFAULT NULL,
	PRIMARY KEY (tid)
) TYPE=InnoDB;

#
# Table structure for table 'topic_nexus_dirty'
#

DROP TABLE IF EXISTS topic_nexus_dirty;
CREATE TABLE topic_nexus_dirty (
	tid SMALLINT UNSIGNED NOT NULL,
	PRIMARY KEY (tid)
) TYPE=InnoDB;

#
# Table structure for table 'topic_nexus_extras'
#

DROP TABLE IF EXISTS topic_nexus_extras;
CREATE TABLE topic_nexus_extras (
	extras_id MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	tid SMALLINT UNSIGNED NOT NULL,
	extras_keyword VARCHAR(100) NOT NULL,
	extras_textname VARCHAR(100) NOT NULL,
	type ENUM('text', 'list') NOT NULL DEFAULT 'text',
	content_type ENUM('story', 'comment') NOT NULL DEFAULT 'story',
	PRIMARY KEY (extras_id),
	UNIQUE tid_keyword (tid, extras_keyword)
) TYPE=InnoDB;

#
# Table structure for table 'topic_param'
#

DROP TABLE IF EXISTS topic_param;
CREATE TABLE topic_param (
	param_id mediumint UNSIGNED NOT NULL auto_increment,
	tid SMALLINT UNSIGNED NOT NULL,
	name varchar(32) DEFAULT '' NOT NULL,
	value text DEFAULT '' NOT NULL,
	UNIQUE topic_key (tid,name),
	PRIMARY KEY (param_id)
) TYPE=InnoDB;

#
# Table structure for table 'topic_parents'
#

DROP TABLE IF EXISTS topic_parents;
CREATE TABLE topic_parents (
	tid SMALLINT UNSIGNED NOT NULL,
	parent_tid SMALLINT UNSIGNED NOT NULL,
	min_weight FLOAT UNSIGNED DEFAULT 1 NOT NULL,
	UNIQUE child_and_parent (tid, parent_tid),
	INDEX parent_tid (parent_tid)
) TYPE=InnoDB;

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
) TYPE=InnoDB;

#
# Table structure for table 'users'
#

DROP TABLE IF EXISTS users;
CREATE TABLE users (
	uid mediumint UNSIGNED NOT NULL auto_increment,
	nickname varchar(20) DEFAULT '' NOT NULL,
	realemail varchar(50) DEFAULT '' NOT NULL,
	fakeemail varchar(75),
	homepage varchar(100),
	passwd char(32) DEFAULT '' NOT NULL,
	sig varchar(160),
	seclev mediumint UNSIGNED DEFAULT '0' NOT NULL,	/* This is set to 0 as a safety factor */
	matchname varchar(20),
	newpasswd varchar(8),
	journal_last_entry_date datetime,
	author tinyint DEFAULT 0 NOT NULL,
	PRIMARY KEY (uid),
	KEY login (nickname,uid,passwd),
	KEY chk4user (realemail,nickname),
	KEY chk4matchname (matchname),
	KEY author_lookup (author)
) TYPE=MyISAM;

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
) TYPE=InnoDB;


#
# Table structure for table 'users_comments'
#

DROP TABLE IF EXISTS users_comments;
CREATE TABLE users_comments (
	uid mediumint UNSIGNED NOT NULL,
	points smallint UNSIGNED DEFAULT '0' NOT NULL,
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
	mode ENUM('flat', 'nested', 'nocomment', 'thread') DEFAULT 'thread' NOT NULL,
	threshold tinyint DEFAULT '0' NOT NULL,
	PRIMARY KEY (uid)
) TYPE=InnoDB;

#
# Table structure for table 'users_count'
#

DROP TABLE IF EXISTS users_count;
CREATE TABLE users_count (
	uid mediumint UNSIGNED NOT NULL,
	PRIMARY KEY (uid)
) TYPE=MyISAM;

#
# Table structure for table 'users_hits'
#

DROP TABLE IF EXISTS users_hits;
CREATE TABLE users_hits (
	uid mediumint UNSIGNED NOT NULL,
	lastclick TIMESTAMP,
	hits int DEFAULT '0' NOT NULL,
	PRIMARY KEY (uid)
) TYPE=InnoDB;

#
# Table structure for table 'users_index'
#

DROP TABLE IF EXISTS users_index;
CREATE TABLE users_index (
	uid mediumint UNSIGNED NOT NULL,
	story_never_topic text,
	story_never_author varchar(255),
	story_never_nexus varchar(255),
	story_always_topic text,
	story_always_author varchar(255),
	story_always_nexus varchar(255),
	exboxes varchar(255),
	maxstories tinyint UNSIGNED DEFAULT '30' NOT NULL,
	noboxes tinyint DEFAULT '0' NOT NULL,
	PRIMARY KEY (uid)
) TYPE=InnoDB;

#
# Table structure for table 'users_info'
#

DROP TABLE IF EXISTS users_info;
CREATE TABLE users_info (
	uid mediumint UNSIGNED NOT NULL,
	totalmods mediumint DEFAULT '0' NOT NULL,
	realname varchar(50),
	bio text,
	tokens mediumint DEFAULT '0' NOT NULL,
	lastgranted datetime DEFAULT '0000-00-00 00:00' NOT NULL,
	m2info varchar(64) DEFAULT '' NOT NULL,
	karma mediumint DEFAULT '0' NOT NULL,
	maillist tinyint DEFAULT '0' NOT NULL,
	totalcomments mediumint UNSIGNED DEFAULT '0',
	lastmm datetime DEFAULT '0000-00-00 00:00' NOT NULL,
	mods_saved varchar(120) DEFAULT '' NOT NULL,
	lastaccess date DEFAULT '0000-00-00' NOT NULL,
	m2fair mediumint UNSIGNED DEFAULT '0' NOT NULL,
	up_fair mediumint UNSIGNED DEFAULT '0' NOT NULL,
	down_fair mediumint UNSIGNED DEFAULT '0' NOT NULL,
	m2unfair mediumint UNSIGNED DEFAULT '0' NOT NULL,
	up_unfair mediumint UNSIGNED DEFAULT '0' NOT NULL,
	down_unfair mediumint UNSIGNED DEFAULT '0' NOT NULL,
	m2fairvotes mediumint UNSIGNED DEFAULT '0' NOT NULL,
	m2voted_up_fair mediumint UNSIGNED DEFAULT '0' NOT NULL,
	m2voted_down_fair mediumint UNSIGNED DEFAULT '0' NOT NULL,
	m2unfairvotes mediumint UNSIGNED DEFAULT '0' NOT NULL,
	m2voted_up_unfair mediumint UNSIGNED DEFAULT '0' NOT NULL,
	m2voted_down_unfair mediumint UNSIGNED DEFAULT '0' NOT NULL,
	m2voted_lonedissent mediumint UNSIGNED DEFAULT '0' NOT NULL,
	m2voted_majority mediumint UNSIGNED DEFAULT '0' NOT NULL,
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
	created_at datetime DEFAULT '0000-00-00 00:00' NOT NULL,
	people MEDIUMBLOB,
	PRIMARY KEY (uid),
	KEY (initdomain),
	KEY (created_ipid)
) TYPE=InnoDB;

#
# Table structure for table 'users_logtokens'
#

DROP TABLE IF EXISTS users_logtokens;
CREATE TABLE users_logtokens (
	lid MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	uid MEDIUMINT UNSIGNED NOT NULL DEFAULT '0',
	locationid CHAR(32) NOT NULL DEFAULT '',
	temp ENUM("yes","no") NOT NULL DEFAULT "no",
	expires DATETIME NOT NULL DEFAULT '2000-01-01 00:00:00',
	value CHAR(22) NOT NULL DEFAULT '',
	PRIMARY KEY (lid),
	UNIQUE uid_locationid_temp (uid, locationid, temp),
	KEY (locationid),
	KEY (temp)
) TYPE=InnoDB;

#
# Table structure for table 'users_param'
#

DROP TABLE IF EXISTS users_param;
CREATE TABLE users_param (
	param_id mediumint UNSIGNED NOT NULL auto_increment,
	uid mediumint UNSIGNED NOT NULL,
	name varchar(32) DEFAULT '' NOT NULL,
	value text DEFAULT '' NOT NULL,
	UNIQUE uid_key (uid,name),
	KEY (uid),
	PRIMARY KEY (param_id)
) TYPE=InnoDB;

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
) TYPE=InnoDB;

#
# Table structure for table 'vars'
#

DROP TABLE IF EXISTS vars;
CREATE TABLE vars (
	name varchar(48) DEFAULT '' NOT NULL,
	value text,
	description varchar(255),
	PRIMARY KEY (name)
) TYPE=InnoDB;

ALTER TABLE backup_blocks ADD FOREIGN KEY (bid) REFERENCES blocks(bid);
ALTER TABLE comment_text ADD FOREIGN KEY (cid) REFERENCES comments(cid);
ALTER TABLE discussions ADD FOREIGN KEY (topic) REFERENCES topics(tid);
ALTER TABLE metamodlog ADD FOREIGN KEY (mmid) REFERENCES moderatorlog(id);
#ALTER TABLE pollquestions ADD FOREIGN KEY (section) REFERENCES sections(section);
ALTER TABLE pollquestions ADD FOREIGN KEY (discussion) REFERENCES discussions(id);
ALTER TABLE pollquestions ADD FOREIGN KEY (uid) REFERENCES users(uid);
# Stories is now InnoDB and these other tables are still MyISAM,
# so no foreign keys between them.
#ALTER TABLE stories ADD FOREIGN KEY (uid) REFERENCES users(uid);
#ALTER TABLE stories ADD FOREIGN KEY (tid) REFERENCES topics(tid);
#ALTER TABLE stories ADD FOREIGN KEY (qid) REFERENCES pollquestions(qid);
ALTER TABLE story_text ADD FOREIGN KEY (stoid) REFERENCES stories(stoid);
ALTER TABLE story_topics_chosen ADD FOREIGN KEY (tid) REFERENCES topics(tid);
ALTER TABLE story_topics_rendered ADD FOREIGN KEY (tid) REFERENCES topics(tid);
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

#ALTER TABLE blocks ADD FOREIGN KEY (rss_template) REFERENCES templates(name);
#ALTER TABLE discussions ADD FOREIGN KEY (sid) REFERENCES stories(sid);
#ALTER TABLE discussions ADD FOREIGN KEY (stoid) REFERENCES stories(stoid);
#ALTER TABLE discussions ADD FOREIGN KEY (uid) REFERENCES users(uid);
#ALTER TABLE formkeys ADD FOREIGN KEY (uid) REFERENCES users(uid);
#ALTER TABLE metamodlog ADD FOREIGN KEY (uid) REFERENCES users(uid);
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

